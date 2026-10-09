#!/usr/bin/env python3
# ============================================================================ #
# ************************** Migrator / OS Reinstallation multipurpose Tool.   #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK MULTI TOOLBOX * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Oct 2026 == # === Version#: 1.5.0 === #
# ===== IDS Scanner ===== #
import argparse
import fcntl
from contextlib import contextmanager
import gzip
import hashlib
import json
import os
import pwd
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
try:
    import psutil
except ImportError:
    psutil = None

VERSION = '1.2.2'
backup_dir = '/etc/one-click/backup/guard'
binaries_dir = os.path.join(backup_dir, 'binaries')  
baseline_file = os.path.join(backup_dir, 'system_baseline.json')
baseline_hash_file = os.path.join(backup_dir, 'system_baseline.json.sha256')
quarantine_dir = os.path.join(backup_dir, 'quarantine')  
log_file = '/var/log/one-click/system_scans.log'
event_log = '/var/log/one-click/system_events.log'
retention_days = 30
NEW_FILE_AGE_THRESHOLD_SEC = 86400
protected_files = ['/bin/bash', '/bin/login', '/bin/ps', '/usr/bin/top',
                   '/usr/bin/sudo', '/usr/bin/ssh', '/usr/sbin/sshd',
                   '/usr/bin/find', '/usr/bin/ss', '/bin/ls']
critical_auth = ['/bin/login', '/usr/bin/passwd', '/bin/bash', '/usr/sbin/sshd']
monitor_dirs = ['/bin', '/usr/bin', '/usr/sbin']
risk_zones = ['/tmp', '/dev/shm', '/var/tmp', '/var/www', '/root', '/etc/ssh']
reset, blue, yellow, green, red = '\033[0m', '\033[94m', '\033[93m', '\033[92m', '\033[91m'
HAS_CHATTR = shutil.which('chattr') is not None
HAS_RESTORECON = shutil.which('restorecon') is not None
HAS_SS = shutil.which('ss') is not None
HAS_LSOF = shutil.which('lsof') is not None
HAS_DPKGQUERY = shutil.which('dpkg-query') is not None
HAS_DPKG = shutil.which('dpkg') is not None
HAS_APT_GET = shutil.which('apt-get') is not None
HAS_RPM = shutil.which('rpm') is not None
HAS_DNF = shutil.which('dnf') is not None
ALLOW_REMEDIATION = False  
log_lock = threading.RLock()
COUNTS = Counter()
SCANNED = Counter()
CRITICAL_PATHS = {os.path.realpath(p) for p in critical_auth}

def report_path():
    return os.path.join(backup_dir, 'last_scan.json')

def schedule_path():
    return '/etc/cron.d/one-click-scanner'

def secure_dirs():
    for folder in (backup_dir, os.path.dirname(log_file)):
        if os.path.islink(folder):
            raise RuntimeError(f'Refusing symlinked state/log directory: {folder}')
        os.makedirs(folder, mode=0o700, exist_ok=True)
        os.chmod(folder, 0o700)

@contextmanager
def state_lock():
    """Process-wide exclusion for scans, evidence cleanup, baseline and recovery."""
    secure_dirs()
    location = os.path.join(backup_dir, '.scanner.lock')
    fd = os.open(location, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another One-Click IDS operation is running; no changes made.')
        yield
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)

def atomic_bytes(path, contents, mode=0o600):
    folder = os.path.dirname(path)
    if os.path.islink(path) or os.path.islink(folder):
        raise RuntimeError(f'Refusing symlinked output: {path}')
    os.makedirs(folder, mode=0o700, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.oneclick-', dir=folder)
    try:
        with os.fdopen(fd, 'wb') as output:
            output.write(contents)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
        dirfd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dirfd)
        finally:
            os.close(dirfd)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

def secure_log_permissions(path):
    try:
        if os.path.isfile(path) and not os.path.islink(path):
            os.chmod(path, 0o600)
    except OSError:
        pass

def display(msg, level='INFO'):
    colors = {'ERROR': red, 'INFO': blue, 'WARN': yellow,
              'SUCCESS': green, 'ALERT': red, 'CRITICAL': red}
    with log_lock:
        COUNTS[level] += 1
        print(f'{colors.get(level, blue)}[{level}]{reset} {msg}', flush=True)
        try:
            secure_dirs()
            if os.path.islink(log_file):
                raise OSError('log is a symlink')
            with open(log_file, 'a', encoding='utf-8') as out:
                out.write(f'[{datetime.now().isoformat()}] [{level}] {msg}\n')
            secure_log_permissions(log_file)
        except OSError as exc:
            print(f'{red}[ERROR]{reset} Logging failure: {exc}', file=sys.stderr)

def emit_event(event_type, data, severity='INFO'):
    event = {'timestamp': int(time.time()), 'datetime': datetime.now().isoformat(),
             'type': event_type, 'data': data, 'severity': severity}
    with log_lock:
        print(json.dumps(event, sort_keys=True), flush=True)
        try:
            secure_dirs()
            if os.path.islink(event_log):
                raise OSError('event log is a symlink')
            with open(event_log, 'a', encoding='utf-8') as out:
                out.write(json.dumps(event, sort_keys=True) + '\n')
            secure_log_permissions(event_log)
        except OSError as exc:
            print(f'{red}[ERROR]{reset} Event logging failure: {exc}', file=sys.stderr)

def confirm_action(prompt_text):
    while True:
        try:
            answer = input(f'{yellow}[CONFIRM]{reset} {prompt_text} (y|n): ').strip().lower()
            if answer in ('y', 'yes'):
                return True
            if answer in ('n', 'no'):
                display('Action cancelled by user.', 'WARN')
                return False
        except (EOFError, KeyboardInterrupt):
            print()
            return False

def sha256_file(path):
    try:
        st = os.lstat(path)
        if not stat.S_ISREG(st.st_mode):
            return None
        digest = hashlib.sha256()
        with open(path, 'rb') as source:
            for block in iter(lambda: source.read(128 * 1024), b''):
                digest.update(block)
        return digest.hexdigest()
    except (OSError, ValueError):
        return None

def canonical(path):
    return os.path.realpath(path)

def _can_read_baseline_hash():
    try:
        if os.path.islink(baseline_file) or os.path.islink(baseline_hash_file):
            return False, 'symlinked baseline data'
        st, sigst = os.lstat(baseline_file), os.lstat(baseline_hash_file)
        if not stat.S_ISREG(st.st_mode) or not stat.S_ISREG(sigst.st_mode):
            return False, 'baseline or checksum is not a regular file'
        if st.st_uid != 0 or sigst.st_uid != 0 or st.st_mode & 0o022 or sigst.st_mode & 0o022:
            return False, 'baseline or checksum ownership/permissions insecure'
        stored = Path(baseline_hash_file).read_text(encoding='ascii').strip()
        if not re.fullmatch(r'[0-9a-f]{64}', stored):
            return False, 'invalid checksum format'
        if sha256_file(baseline_file) != stored:
            return False, 'baseline checksum mismatch'
        return True, 'checksum verified (local corruption check, not a signature)'
    except (OSError, UnicodeError) as exc:
        return False, str(exc)

def verify_baseline_integrity(verbose=True):
    ok, detail = _can_read_baseline_hash()
    if verbose:
        display(f'Baseline integrity: {detail}', 'SUCCESS' if ok else 'CRITICAL')
        if not ok:
            emit_event('baseline_integrity_degraded', {'reason': detail}, 'CRITICAL')
    return ok

def load_baseline(verbose=True):
    if not verify_baseline_integrity(verbose):
        return None
    try:
        data = json.loads(Path(baseline_file).read_text(encoding='utf-8'))
        if not isinstance(data, dict) or not isinstance(data.get('hashes'), dict):
            raise ValueError('invalid baseline schema')
        if any(not isinstance(k, str) or not re.fullmatch(r'[0-9a-f]{64}', v or '')
               for k, v in data['hashes'].items()):
            raise ValueError('invalid baseline path/hash entry')
        return data
    except (OSError, ValueError, TypeError) as exc:
        if verbose:
            display(f'Baseline rejected: {exc}', 'CRITICAL')
        return None

def write_baseline_hash():
    digest = sha256_file(baseline_file)
    if not digest:
        return False
    atomic_bytes(baseline_hash_file, (digest + '\n').encode('ascii'))
    return True

def publish_baseline(payload):
    """Best-effort atomic file pair update with rollback and immutable-state restoration.

    Local checksum is NOT an attacker-resistant signature or external trust anchor.
    """
    paths = (baseline_file, baseline_hash_file)
    previous = {}
    sealed = []
    try:
        for file in paths:
            if os.path.islink(file):
                raise OSError(f'refusing symlinked baseline path: {file}')
            previous[file] = Path(file).read_bytes() if os.path.exists(file) else None
            if HAS_CHATTR and os.path.exists(file) and shutil.which('lsattr'):
                attr = subprocess.run(['lsattr', '-d', file], capture_output=True, text=True, timeout=5)
                if attr.returncode == 0 and attr.stdout and 'i' in attr.stdout.split()[0]:
                    result = subprocess.run(['chattr', '-i', file], capture_output=True, timeout=5)
                    if result.returncode:
                        raise OSError(f'cannot unseal immutable baseline: {file}')
                    sealed.append(file)
        atomic_bytes(baseline_file, payload)
        if not write_baseline_hash():
            raise OSError('checksum seal failed')
        if not _can_read_baseline_hash()[0]:
            raise OSError('new baseline failed verification')
        return True
    except (OSError, subprocess.TimeoutExpired) as exc:
        display(f'Baseline transaction failed: {exc}', 'CRITICAL')
        for file in paths:
            try:
                if file not in previous:
                    continue
                if previous[file] is None:
                    if os.path.exists(file):
                        os.unlink(file)
                else:
                    atomic_bytes(file, previous[file])
            except OSError as undo:
                display(f'CRITICAL: could not roll back {file}: {undo}', 'CRITICAL')
        return False
    finally:
        for file in sealed:
            if os.path.exists(file):
                result = subprocess.run(['chattr', '+i', file], capture_output=True)
                if result.returncode:
                    display(f'Failed to reapply immutable bit to {file}', 'CRITICAL')

def get_dpkg_package_owner(path):
    if not (HAS_DPKGQUERY or HAS_DPKG):
        return None
    try:
        result = subprocess.run(['dpkg-query', '-S', '--', path] if HAS_DPKGQUERY else ['dpkg', '-S', path],
                                capture_output=True, text=True, timeout=15)
        if result.returncode != 0 or not result.stdout.strip():
            return None
        line = result.stdout.splitlines()[0]
        pkg = line.partition(': ')[0].split(',')[0].strip()
        return pkg if re.fullmatch(r'[A-Za-z0-9.+:~-]+', pkg) else None
    except (OSError, subprocess.TimeoutExpired):
        return None

def verify_binary_with_package_manager(path):
    """Conservative yes/no; failures or unavailable metadata NEVER mean verified."""
    path = canonical(path)
    try:
        if HAS_DPKG:
            pkg = get_dpkg_package_owner(path)
            if not pkg:
                return False
            result = subprocess.run(['dpkg', '-V', pkg], capture_output=True, text=True, timeout=30)
            return result.returncode == 0 and not result.stdout.strip() and not result.stderr.strip()
        if HAS_RPM:
            owner = subprocess.run(['rpm', '-qf', path], capture_output=True, text=True, timeout=15)
            if owner.returncode != 0 or not owner.stdout.strip():
                return False
            pkg = owner.stdout.splitlines()[0].strip()
            result = subprocess.run(['rpm', '-V', pkg], capture_output=True, text=True, timeout=30)
            return result.returncode == 0 and not result.stdout.strip() and not result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    return False

def iter_monitored_files():
    seen = set()
    for base in monitor_dirs:
        if not os.path.isdir(base):
            continue
        for root, dirs, files in os.walk(base, followlinks=False):
            dirs[:] = sorted(d for d in dirs if not os.path.islink(os.path.join(root, d)))
            for name in sorted(files):
                item = os.path.join(root, name)
                if os.path.islink(item):
                    continue
                try:
                    st = os.lstat(item)
                    if not stat.S_ISREG(st.st_mode) or not st.st_mode & 0o111:
                        continue
                except OSError:
                    continue
                real = canonical(item)
                if real not in seen:
                    seen.add(real)
                    yield real

def safe_backup_name(path):
    label = os.path.basename(path).replace('/', '_')[:72]
    return hashlib.sha256(path.encode('utf-8', errors='surrogateescape')).hexdigest()[:40] + '-' + label

def legacy_backup_name(path):
    return path.lstrip('/').replace('/', '_')

def list_ssh_keys():
    found = {}
    for user in pwd.getpwall():
        p = os.path.join(user.pw_dir, '.ssh', 'authorized_keys')
        if not os.path.islink(p) and os.path.isfile(p):
            found[p] = sha256_file(p)
    return found

def list_persistence_files():
    found = {}
    bases = ['/etc/cron.d', '/etc/cron.daily', '/etc/cron.hourly',
             '/etc/cron.weekly', '/etc/cron.monthly', '/var/spool/cron',
             '/etc/systemd/system']
    for base in bases:
        if not os.path.isdir(base):
            continue
        for root, dirs, files in os.walk(base, followlinks=False):
            dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
            for name in files:
                p = os.path.join(root, name)
                try:
                    if os.path.islink(p):
                        found[p] = 'symlink:' + os.readlink(p)
                    elif os.path.isfile(p):
                        found[p] = sha256_file(p)
                except OSError:
                    continue
    return found

def list_ports():
    if not HAS_SS:
        return None
    try:
        result = subprocess.run(['ss', '-H', '-lntup'], capture_output=True, text=True, timeout=15)
        if result.returncode != 0:
            return None
        ports = set()
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) < 5:
                continue
            protocol, local = parts[0], parts[4]
            if protocol.startswith(('tcp', 'udp')):
                ports.add(f'{protocol}:{local}')
        return sorted(ports)
    except (OSError, subprocess.TimeoutExpired):
        return None

def collect_inventory():
    return {'ssh_keys': list_ssh_keys(), 'persistence': list_persistence_files(),
            'ports': list_ports()}

def compare_inventory(old, new):
    for key, desc in (('ssh_keys', 'SSH authorised key file'), ('persistence', 'Persistence configuration')):
        previous = old.get(key)
        if not isinstance(previous, dict):
            display(f'No {desc.lower()} inventory in legacy baseline; rebaseline to enable comparison.', 'WARN')
            continue
        latest = new[key]
        for path in sorted(previous.keys() - latest.keys()):
            display(f'{desc} removed: {path}', 'WARN')
            emit_event('inventory_removed', {'kind': key, 'file': path}, 'WARN')
        for path in sorted(latest.keys() - previous.keys()):
            display(f'{desc} added: {path}', 'ALERT')
            emit_event('inventory_added', {'kind': key, 'file': path}, 'ALERT')
        for path in sorted(latest.keys() & previous.keys()):
            if latest[path] != previous[path]:
                display(f'{desc} modified: {path}', 'ALERT')
                emit_event('inventory_modified', {'kind': key, 'file': path}, 'ALERT')
    previous_ports, current_ports = old.get('ports'), new.get('ports')
    if previous_ports is None or current_ports is None:
        display('Port inventory comparison unavailable.', 'WARN')
    else:
        added, removed = sorted(set(current_ports) - set(previous_ports)), sorted(set(previous_ports) - set(current_ports))
        for port in added:
            display(f'New listening socket: {port}', 'WARN')
            emit_event('listening_socket_added', {'socket': port}, 'WARN')
        for port in removed:
            display(f'Listening socket removed: {port}', 'INFO')
            emit_event('listening_socket_removed', {'socket': port})
        SCANNED['new_ports'] = len(added)

def create_baseline():
    """Versioned evidence set: copy and verify BEFORE recording hashes."""
    secure_dirs()
    os.makedirs(os.path.join(backup_dir, 'sets'), mode=0o700, exist_ok=True)
    name = datetime.now().strftime('%Y%m%dT%H%M%S') + f'-{os.getpid()}-{time.time_ns()}'
    staged = tempfile.mkdtemp(prefix='.baseline-', dir=os.path.join(backup_dir, 'sets'))
    completed_set = os.path.join(backup_dir, 'sets', name)
    entries = list(iter_monitored_files())
    try:
        estimated = sum(os.lstat(path).st_size for path in entries)
        available = shutil.disk_usage(backup_dir).free
        if available < estimated * 1.10 + 64 * 1024 * 1024:
            display(f'Insufficient backup disk space: need at least {int(estimated*1.10 + 64*1024*1024)} bytes, available {available}.', 'ERROR')
            shutil.rmtree(staged, ignore_errors=True)
            return False
    except OSError as exc:
        display(f'Baseline disk preflight failed: {exc}', 'ERROR')
        shutil.rmtree(staged, ignore_errors=True)
        return False
    if not entries:
        display('No executable files found; refusing empty baseline.', 'ERROR')
        shutil.rmtree(staged, ignore_errors=True)
        return False
    stats = Counter()
    hashes = {}
    metadata = {}
    display(f'Creating verified baseline of {len(entries)} executable files.', 'INFO')

    def copy_one(path):
        destination = os.path.join(staged, safe_backup_name(path))
        try:
            st = os.lstat(path)
            if not stat.S_ISREG(st.st_mode):
                return path, None
            before = sha256_file(path)
            if not before:
                return path, None
            shutil.copy2(path, destination, follow_symlinks=False)
            if sha256_file(destination) != before or sha256_file(path) != before:
                return path, None
            return path, before
        except (OSError, ValueError):
            return path, None

    try:
        with ThreadPoolExecutor(max_workers=min(8, max(1, os.cpu_count() or 1))) as pool:
            for path, digest in pool.map(copy_one, entries):
                if digest:
                    hashes[path] = digest
                    st = os.lstat(path)
                    metadata[path] = {'uid': st.st_uid, 'gid': st.st_gid, 'mode': stat.S_IMODE(st.st_mode), 'size': st.st_size}
                    stats['verified'] += 1
                else:
                    stats['failed'] += 1
        if stats['failed']:
            display(f'Baseline aborted: {stats["failed"]} files could not be copied and verified.', 'CRITICAL')
            return False
        inventory = collect_inventory()
        data = {'version': 2, 'created': datetime.now().isoformat(),
                'hashes': hashes, 'metadata': metadata, 'users': {u.pw_name: u.pw_uid for u in pwd.getpwall()},
                'inventory': inventory, 'backup_set': name}
        os.replace(staged, completed_set)
        staged = None
        payload = (json.dumps(data, indent=2, sort_keys=True) + '\n').encode()
        if not publish_baseline(payload):
            display('Failed to publish verified baseline; prior state restoration attempted.', 'CRITICAL')
            return False
        display(f'Baseline created: {len(hashes)} backed-up and hashed executables', 'SUCCESS')
        emit_event('baseline_created', {'files': len(hashes), 'backup_set': name})
        return True
    except (OSError, ValueError) as exc:
        display(f'Baseline creation failed: {exc}', 'CRITICAL')
        return False
    finally:
        if staged and os.path.isdir(staged):
            shutil.rmtree(staged)

def check_permissions(path):
    try:
        st = os.lstat(path)
        if st.st_uid != 0:
            display(f'Protected executable not root-owned: {path}', 'CRITICAL')
        if st.st_mode & 0o022:
            display(f'Protected executable writable by group/others: {path}', 'CRITICAL')
    except OSError as exc:
        display(f'Permission check failed for {path}: {exc}', 'WARN')

def check_integrity(baseline):
    if baseline is None:
        display('Trusted baseline unavailable: skipping baseline comparison and ALL recovery.', 'CRITICAL')
        SCANNED['baseline_trusted'] = 0
        for path in protected_files:
            if not os.path.isfile(path):
                display(f'Protected executable missing: {path}', 'CRITICAL')
            elif not verify_binary_with_package_manager(path):
                display(f'Package verification unavailable or inconclusive: {path}', 'WARN')
        return
    SCANNED['baseline_trusted'] = 1
    prior = baseline['hashes']
    current = set(iter_monitored_files())
    known = set(prior)
    SCANNED['baseline_files'] = len(prior)
    SCANNED['checked_files'] = len(current & known)
    for path in sorted(known - current):
        display(f'Baseline executable missing: {path}', 'CRITICAL')
        emit_event('protected_file_missing', {'file': path}, 'CRITICAL')
        SCANNED['missing'] += 1
    for path in sorted(current - known):
        if verify_binary_with_package_manager(path):
            display(f'New executable (package verified; review/rebaseline): {path}', 'WARN')
        else:
            display(f'New unindexed executable: {path}', 'ALERT')
            emit_event('unindexed_executable', {'file': path}, 'ALERT')
        SCANNED['new_files'] += 1
    critical = {canonical(p) for p in protected_files}
    saved_metadata = baseline.get('metadata', {})
    if not saved_metadata:
        display('Legacy baseline lacks file permission metadata; rebaseline to monitor metadata changes.', 'WARN')
    for path in sorted(current & known):
        current_hash = sha256_file(path)
        if current_hash != prior[path]:
            if current_hash and verify_binary_with_package_manager(path):
                display(f'Changed executable verified by installed package (review/rebaseline): {path}', 'WARN')
                emit_event('verified_package_change', {'file': path}, 'WARN')
                SCANNED['verified_updates'] += 1
            else:
                display(f'Integrity violation: {path}', 'CRITICAL')
                emit_event('integrity_violation', {'file': path}, 'CRITICAL')
                SCANNED['modified'] += 1
        expected_meta = saved_metadata.get(path)
        if isinstance(expected_meta, dict):
            try:
                st = os.lstat(path)
                actual = {'uid': st.st_uid, 'gid': st.st_gid,
                          'mode': stat.S_IMODE(st.st_mode), 'size': st.st_size}
                if any(actual[k] != expected_meta.get(k) for k in actual):
                    display(f'Executable ownership, mode or size changed: {path}', 'CRITICAL')
                    emit_event('executable_metadata_changed', {'file': path, 'expected': expected_meta, 'current': actual}, 'CRITICAL')
                    SCANNED['metadata_changed'] += 1
            except OSError as exc:
                display(f'Cannot inspect executable metadata: {path}: {exc}', 'WARN')
        if path in critical:
            check_permissions(path)
    for path in protected_files:
        real = canonical(path)
        if not os.path.exists(path):
            if real not in known:
                display(f'Protected executable missing: {path}', 'CRITICAL')
        elif real not in known:
            display(f'Protected executable lacks baseline entry: {path}', 'WARN')
    compare_inventory(baseline.get('inventory', {}), collect_inventory())

def check_path():
    for entry in os.environ.get('PATH', '').split(':'):
        if not entry or any(entry == p or entry.startswith(p + '/') for p in ('/tmp', '/dev/shm', '/var/tmp')):
            display(f'Unsafe/empty PATH component: {entry!r}', 'CRITICAL')

def rootkit_checks():
    path = '/etc/ld.so.preload'
    try:
        if os.path.isfile(path) and os.path.getsize(path) > 0:
            display(f'Non-empty {path} detected; review contents carefully.', 'CRITICAL')
    except OSError as exc:
        display(f'Rootkit check unavailable: {exc}', 'WARN')

def check_cron_systemd():
    display('Cron, systemd units and timers inventoried for comparison.', 'INFO')

def check_ssh_keys():
    display(f'SSH authorized_keys files inventoried: {len(list_ssh_keys())}', 'INFO')

def check_ports():
    ports = list_ports()
    display(f'Listening sockets inventoried: {len(ports)}' if ports is not None
            else 'Listening socket inventory unavailable.', 'INFO' if ports is not None else 'WARN')

def check_suid():
    seen = set()
    for base in monitor_dirs:
        if not os.path.isdir(base):
            continue
        for root, dirs, files in os.walk(base, followlinks=False):
            dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
            for name in files:
                try:
                    path = os.path.join(root, name)
                    if not os.path.islink(path) and os.lstat(path).st_mode & stat.S_ISUID:
                        seen.add(canonical(path))
                except OSError:
                    continue
    display(f'SUID executable inventory: {len(seen)} entries (changes covered by executable hashes).', 'INFO')

def scan_temp():
    count = 0
    cutoff = time.time() - NEW_FILE_AGE_THRESHOLD_SEC
    for zone in risk_zones:
        if not os.path.exists(zone):
            continue
        display(f'Scanning risk zone: {zone}', 'INFO')
        for root, dirs, files in os.walk(zone, followlinks=False):
            dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
            for name in files:
                path = os.path.join(root, name)
                try:
                    st = os.lstat(path)
                    if (stat.S_ISREG(st.st_mode) and st.st_mtime >= cutoff and
                            st.st_mode & 0o111 and not name.endswith(('.swp', '.tmp', '.lock'))):
                        count += 1
                        display(f'Recent executable in risk zone: {path}', 'ALERT')
                except OSError:
                    pass
    SCANNED['risk_executables'] = count

def check_deleted_binaries():
    if not HAS_LSOF:
        display('Deleted-running-binary check skipped: lsof unavailable.', 'WARN')
        return
    try:
        out = subprocess.run(['lsof', '-nP'], capture_output=True, text=True, timeout=20)
        if out.returncode not in (0, 1):
            display('Deleted-running-binary check inconclusive.', 'WARN')
            return
        for line in out.stdout.splitlines():
            if 'deleted' in line.lower() and not any(s in line for s in ('.log', 'anon_inode', 'memfd:')):
                display(f'Running deleted binary candidate: {line[:350]}', 'WARN')
    except (OSError, subprocess.TimeoutExpired):
        display('Deleted-running-binary check unavailable.', 'WARN')

def quarantine_file(file_path):
    """Evidence COPY only, does not remove or neutralise the source."""
    if os.path.islink(file_path) or not os.path.isfile(file_path):
        return None
    os.makedirs(quarantine_dir, mode=0o700, exist_ok=True)
    dst = os.path.join(quarantine_dir, f'{safe_backup_name(file_path)}.{time.time_ns()}')
    try:
        shutil.copy2(file_path, dst, follow_symlinks=False)
        os.chmod(dst, 0o600)
        display(f'Evidence copy saved (source unchanged): {dst}', 'WARN')
        return dst
    except OSError as exc:
        display(f'Evidence capture failed: {exc}', 'ERROR')
        return None

def active_ssh_sessions_full():
    """True means active OR state uncertain. Fail closed for auth recovery."""
    if psutil is None:
        return True
    try:
        sshd_pids = {proc.pid for proc in psutil.process_iter(['name'])
                     if (proc.info.get('name') or '').lower().startswith('sshd')}
        for conn in psutil.net_connections(kind='tcp'):
            if conn.status == 'ESTABLISHED' and (conn.pid in sshd_pids or
                   (conn.laddr and conn.laddr.port == 22)):
                return True
        return False
    except (OSError, psutil.Error):
        return True

def reinstall_from_package(path):
    """Only called by an explicitly authorised recovery operation."""
    if HAS_DPKG and HAS_APT_GET:
        pkg = get_dpkg_package_owner(path)
        if not pkg:
            return False
        command = ['apt-get', 'install', '--reinstall', '-y', pkg]
    elif HAS_RPM and HAS_DNF:
        result = subprocess.run(['rpm', '-qf', path], capture_output=True, text=True, timeout=15)
        if result.returncode or not result.stdout.strip():
            return False
        command = ['dnf', 'reinstall', '-y', result.stdout.splitlines()[0].strip()]
    else:
        return False
    try:
        result = subprocess.run(command, timeout=300)
        return result.returncode == 0 and verify_binary_with_package_manager(path)
    except (OSError, subprocess.TimeoutExpired):
        return False

def recover_file(path, source='backup'):
    baseline = load_baseline()
    if baseline is None:
        display('Recovery blocked: baseline cannot be trusted.', 'CRITICAL')
        return False
    path = os.path.abspath(path)
    if os.path.islink(path) or not os.path.isfile(path):
        display(f'Recovery blocked: target missing or symlinked: {path}', 'ERROR')
        return False
    resolved = canonical(path)
    if resolved not in baseline['hashes']:
        display(f'Recovery blocked: target is not tracked: {path}', 'ERROR')
        return False
    original = os.lstat(path)
    if original.st_nlink != 1 or not stat.S_ISREG(original.st_mode):
        display('Recovery blocked: unsafe hardlink or special target.', 'ERROR')
        return False
    if resolved in CRITICAL_PATHS and active_ssh_sessions_full():
        display('Recovery blocked: authentication binary while SSH may be active.', 'CRITICAL')
        return False
    evidence = quarantine_file(path)
    if not evidence:
        display('Recovery blocked: pre-change evidence copy failed.', 'ERROR')
        return False
    if source == 'package':
        ok = reinstall_from_package(path)
        if not ok:
            display('Explicit package reinstall unsuccessful or unverifiable.', 'CRITICAL')
        else:
            display('Package reinstall verified. Review and explicitly rebaseline if expected.', 'SUCCESS')
        emit_event('manual_package_recovery', {'file': path, 'success': ok}, 'INFO' if ok else 'CRITICAL')
        return ok
    backup_set = baseline.get('backup_set')
    if backup_set and (not re.fullmatch(r'[A-Za-z0-9_-]+', backup_set)):
        display('Recovery blocked: unsafe backup-set identifier.', 'CRITICAL')
        return False
    backup = (os.path.join(backup_dir, 'sets', backup_set, safe_backup_name(resolved))
              if backup_set else os.path.join(binaries_dir, legacy_backup_name(resolved)))
    if sha256_file(backup) != baseline['hashes'][resolved]:
        display('Recovery blocked: saved copy is missing or fails baseline checksum.', 'CRITICAL')
        return False
    temp = None
    try:
        fd, temp = tempfile.mkstemp(prefix='.oneclick-recover-', dir=os.path.dirname(path))
        os.close(fd)
        shutil.copy2(backup, temp, follow_symlinks=False)
        meta = baseline.get('metadata', {}).get(resolved, {})
        os.chown(temp, meta.get('uid', original.st_uid), meta.get('gid', original.st_gid))
        os.chmod(temp, meta.get('mode', stat.S_IMODE(original.st_mode)))
        if sha256_file(temp) != baseline['hashes'][resolved]:
            raise OSError('temporary recovery copy hash mismatch')
        now = os.lstat(path)
        if now.st_ino != original.st_ino or now.st_dev != original.st_dev or now.st_nlink != 1:
            raise OSError('target changed during recovery; refusing replacement')
        os.replace(temp, path)
        temp = None
        if HAS_RESTORECON:
            subprocess.run(['restorecon', '-F', path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        if sha256_file(path) != baseline['hashes'][resolved]:
            display('Recovery applied but post-replacement hash verification FAILED.', 'CRITICAL')
            return False
        display(f'Explicit backup recovery succeeded: {path}', 'SUCCESS')
        emit_event('restored_from_backup', {'file': path, 'evidence': evidence})
        return True
    except (OSError, subprocess.TimeoutExpired) as exc:
        display(f'Explicit backup recovery failed: {exc}', 'ERROR')
        return False
    finally:
        if temp and os.path.exists(temp):
            os.unlink(temp)

def cleanup_quarantine():
    if not os.path.isdir(quarantine_dir) or os.path.islink(quarantine_dir):
        return 0
    removed = 0
    cutoff = time.time() - retention_days * 86400
    for entry in os.scandir(quarantine_dir):
        try:
            if entry.is_file(follow_symlinks=False) and entry.stat(follow_symlinks=False).st_mtime < cutoff:
                os.unlink(entry.path)
                removed += 1
        except OSError as exc:
            display(f'Failed to purge evidence file: {exc}', 'WARN')
    display(f'Explicit evidence cleanup: {removed} files older than {retention_days} days removed.', 'INFO')
    return removed

def rotate_logs(target_file, max_backups=5):
    if os.path.islink(target_file) or not os.path.isfile(target_file):
        return
    if os.path.getsize(target_file) < 10 * 1024 * 1024:
        return
    with log_lock:
        for i in range(max_backups - 1, 0, -1):
            src, dst = f'{target_file}.{i}.gz', f'{target_file}.{i+1}.gz'
            if os.path.exists(src):
                os.replace(src, dst)
        with open(target_file, 'rb') as f_in, gzip.open(f'{target_file}.1.gz', 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
        with open(target_file, 'w', encoding='utf-8'):
            pass
        secure_log_permissions(target_file)

def initialize_automation():
    """Hourly SCAN ONLY. No --remediate, cleanup or baseline mutation."""
    script_path = os.path.realpath(__file__)
    st = os.stat(script_path)
    if st.st_uid != 0 or st.st_mode & 0o022:
        display('Scheduling blocked: scanner must be root-owned and not writable by group/others.', 'CRITICAL')
        return False
    folder = os.path.dirname(script_path)
    while folder != '/':
        parent = os.stat(folder)
        if parent.st_uid != 0 or parent.st_mode & 0o022:
            display(f'Scheduling blocked: unsafe parent folder {folder}', 'CRITICAL')
            return False
        folder = os.path.dirname(folder)
    entry = f'0 * * * * root {sys.executable} {script_path} --deep --scan-only\n'
    if os.path.isfile(schedule_path()) and Path(schedule_path()).read_text() == entry:
        display('Read-only hourly schedule already installed.', 'SUCCESS')
        return True
    atomic_bytes(schedule_path(), entry.encode('utf-8'), mode=0o644)
    display('Read-only hourly schedule installed.', 'SUCCESS')
    return True

def disable_automation():
    if os.path.islink(schedule_path()):
        display('Refusing symlinked cron entry.', 'ERROR')
        return False
    if os.path.exists(schedule_path()):
        os.unlink(schedule_path())
    display('One-Click IDS hourly schedule disabled.', 'SUCCESS')
    return True

def uninstall():
    disable_automation()
    display('Scheduled monitoring disabled. Evidence, baselines and logs preserved.', 'SUCCESS')
    display('Use --cleanup for age-based evidence pruning. No data is silently erased.', 'INFO')

def _read_json(path):
    try:
        if os.path.islink(path):
            return None
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None

def events_summary(hours=24, limit=5000):
    counts = Counter()
    cutoff = time.time() - hours * 3600
    try:
        with open(event_log, encoding='utf-8') as f:
            from collections import deque
            for line in deque(f, maxlen=limit):
                try:
                    event = json.loads(line)
                    if float(event.get('timestamp', 0)) >= cutoff:
                        counts[event.get('severity', 'INFO')] += 1
                except (ValueError, TypeError):
                    continue
    except OSError:
        pass
    return dict(counts)

def system_stats():
    results = {}
    if psutil:
        try:
            results = {'cpu_percent': psutil.cpu_percent(interval=0.1),
                       'memory_percent': psutil.virtual_memory().percent,
                       'memory_used_bytes': psutil.virtual_memory().used,
                       'disk_root_percent': psutil.disk_usage('/').percent,
                       'disk_root_free_bytes': psutil.disk_usage('/').free,
                       'uptime_seconds': round(time.time() - psutil.boot_time())}
        except (OSError, psutil.Error):
            results = {'status': 'system metrics unavailable'}
    else:
        results = {'status': 'install psutil to enable CPU, memory and disk metrics'}
    return results

def scheduler_mode():
    path = schedule_path()
    if not os.path.isfile(path) or os.path.islink(path):
        return 'disabled' if not os.path.lexists(path) else 'untrusted schedule file'
    try:
        text = Path(path).read_text(encoding='utf-8')
        if '--remediate' in text or '--recover-file' in text:
            return 'UNSAFE: legacy unattended remediation configured'
        if '--scan-only' in text and '--deep' in text:
            return 'scan-only'
        return 'unrecognised schedule; review configuration'
    except OSError:
        return 'unreadable schedule file'

def stats_data():
    ok, reason = _can_read_baseline_hash()
    baseline = load_baseline(verbose=False) if ok else None
    last = _read_json(report_path())
    return {'version': VERSION, 'baseline_integrity': 'verified' if ok else 'untrusted',
            'baseline_detail': reason, 'baseline_created': baseline.get('created') if baseline else None,
            'baseline_executables': len(baseline['hashes']) if baseline else None,
            'last_scan': last, 'event_counts_24h': events_summary(),
            'scheduler_enabled': os.path.isfile(schedule_path()),
            'scheduler_mode': scheduler_mode(),
            'recovery_policy': 'manual per-file approval; never scheduled',
            'system': system_stats()}

def show_stats(as_json=False):
    data = stats_data()
    if as_json:
        print(json.dumps(data, indent=2, sort_keys=True))
        return
    print(f'{yellow}===================================================={reset}')
    print(f'{yellow} ONE-CLICK HOST SECURITY | STATUS & STATS v{VERSION}{reset}')
    print(f'{yellow}===================================================={reset}')
    print(f'  Baseline            : {data["baseline_integrity"]} ({data["baseline_executables"]} executables)')
    print(f'  Baseline Created    : {data["baseline_created"] or "not available"}')
    print(f'  Scheduled Monitoring: {data["scheduler_mode"]}')
    last = data['last_scan'] or {}
    print(f'  Last Scan           : {last.get("completed", "none")}; {last.get("result", "unknown")}')
    for key in ('checked_files', 'new_files', 'missing', 'modified', 'metadata_changed', 'verified_updates', 'new_ports'):
        print(f'  {key.replace("_", " ").title():20}: {last.get("metrics", {}).get(key, "-")}')
    system = data['system']
    for key in ('cpu_percent', 'memory_percent', 'disk_root_percent', 'disk_root_free_bytes', 'uptime_seconds'):
        if key in system:
            print(f'  {key.replace("_", " ").title():20}: {system[key]}')
    print(f'  Security Events (24h): {data["event_counts_24h"]}')
    print(f'  Recovery            : {data["recovery_policy"]}')

def show_events(limit):
    from collections import deque
    try:
        with open(event_log, encoding='utf-8') as f:
            for line in deque(f, maxlen=limit):
                print(line.rstrip())
    except OSError:
        print('No recorded security events.')

def print_summary(result):
    print(f'\n{yellow}===================================================={reset}')
    print(f'{yellow} ONE-CLICK HOST IDS | SCAN SUMMARY{reset}')
    print(f'{yellow}===================================================={reset}')
    for label, val in (('Baseline Integrity', 'verified' if SCANNED['baseline_trusted'] else 'UNTRUSTED'),
                       ('Executables Checked', SCANNED['checked_files']),
                       ('New Executables', SCANNED['new_files']),
                       ('Missing Executables', SCANNED['missing']),
                       ('Integrity Violations', SCANNED['modified']),
                       ('Metadata Changes', SCANNED['metadata_changed']),
                       ('Verified Package Changes', SCANNED['verified_updates']),
                       ('New Listening Sockets', SCANNED['new_ports']),
                       ('Critical Findings', COUNTS['CRITICAL']),
                       ('Alerts', COUNTS['ALERT']),
                       ('Warnings', COUNTS['WARN']),
                       ('Remediation', 'DISABLED')):
        print(f'  {label:26}: {val}')
    print(f'  Result                    : {result.upper()}')
    print(f'{yellow}===================================================={reset}')

def scan(deep=False):
    COUNTS.clear()
    SCANNED.clear()
    started = datetime.now().isoformat()
    baseline = load_baseline()
    display('=== Scan Started (read-only, no remediation) ===', 'INFO')
    if scheduler_mode().startswith('UNSAFE'):
        display('Legacy cron enables unattended remediation. Run --disable-schedule, then --schedule.', 'CRITICAL')
    check_path()
    rootkit_checks()
    check_cron_systemd()
    check_ssh_keys()
    check_ports()
    check_suid()
    check_integrity(baseline)
    if deep:
        scan_temp()
        check_deleted_binaries()
    result = ('critical' if COUNTS['CRITICAL'] else
              'attention' if COUNTS['WARN'] or COUNTS['ALERT'] else 'clean')
    display(f'=== Scan Complete: {result.upper()} ===', 'SUCCESS' if result == 'clean' else 'WARN')
    record = {'started': started, 'completed': datetime.now().isoformat(),
              'result': result, 'deep': deep, 'metrics': dict(SCANNED),
              'severity_counts': dict(COUNTS), 'remediation': 'disabled'}
    try:
        secure_dirs()
        atomic_bytes(report_path(), (json.dumps(record, indent=2, sort_keys=True) + '\n').encode())
    except OSError as exc:
        display(f'Failed to save scan summary: {exc}', 'WARN')
        record['result'] = 'incomplete'
    print_summary(record['result'])
    return 2 if result == 'critical' else 1 if result == 'attention' else 0

def main(argv=None):
    parser = argparse.ArgumentParser(description='One-Click Host IDS — safer file integrity and security monitoring')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--init', action='store_true', help='Create baseline if absent (does not enable cron)')
    group.add_argument('--rebaseline', action='store_true', help='Explicitly replace trusted baseline after reviewed changes')
    group.add_argument('--stats', action='store_true', help='Show host, baseline, last scan and 24-hour alert statistics')
    group.add_argument('--status', action='store_true', help='Alias for --stats')
    group.add_argument('--verify-baseline', action='store_true', help='Verify saved baseline digest and structure')
    group.add_argument('--events', action='store_true', help='Show the latest structured security events')
    group.add_argument('--schedule', action='store_true', help='Install read-only hourly scan schedule')
    group.add_argument('--disable-schedule', action='store_true', help='Disable scheduled scans')
    group.add_argument('--cleanup', action='store_true', help='Explicitly prune evidence older than retention window')
    group.add_argument('--uninstall', action='store_true', help='Remove automation; preserve baseline and evidence')
    group.add_argument('--recover-file', metavar='ABSOLUTE_PATH', help='Manually recover ONE tracked file')
    parser.add_argument('--recovery-source', choices=('backup', 'package'), default='backup')
    parser.add_argument('--approve-recovery', action='store_true', help='Explicit authorisation required for recovery')
    parser.add_argument('--deep', action='store_true', help='Include risk-zone and deleted-binary checks')
    parser.add_argument('--scan-only', action='store_true', help='Explicitly disable recovery (default scan behaviour)')
    parser.add_argument('--remediate', action='store_true', help='Compatibility switch; requires --recover-file and --approve-recovery')
    parser.add_argument('--yes', '-y', action='store_true', help='Confirm explicitly requested maintenance (never enables automatic repair)')
    parser.add_argument('--json', action='store_true', help='Machine-readable output for --stats/--status')
    parser.add_argument('--limit', type=int, default=25, help='Number of event lines for --events (1-1000)')
    parser.add_argument('--version', action='version', version=f'One-Click Host IDS {VERSION}')
    args = parser.parse_args(argv)
    if os.geteuid() != 0:
        print(f'{red}[ERROR]{reset} Root privileges required.', file=sys.stderr)
        return 3
    if args.scan_only and (args.init or args.rebaseline or args.schedule or args.disable_schedule or args.cleanup or args.uninstall or args.recover_file):
        parser.error('--scan-only cannot be combined with any maintenance or recovery action')
    if args.recovery_source != 'backup' and not args.recover_file:
        parser.error('--recovery-source requires --recover-file')
    if args.json and not (args.stats or args.status):
        parser.error('--json requires --stats or --status')
    if args.approve_recovery and not args.recover_file:
        parser.error('--approve-recovery requires --recover-file')
    if args.remediate and not args.recover_file:
        parser.error('--remediate is NOT unattended; supply --recover-file and --approve-recovery')
    if args.stats or args.status:
        show_stats(as_json=args.json)
        return 0
    if args.events:
        if not 1 <= args.limit <= 1000:
            parser.error('--limit must be between 1 and 1000')
        show_events(args.limit)
        return 0
    try:
        with state_lock():
            return _run_locked(args, parser)
    except (OSError, RuntimeError) as exc:
        print(f'{red}[ERROR]{reset} {exc}', file=sys.stderr)
        return 2

def _run_locked(args, parser):
    if args.recover_file:
        if args.scan_only or not args.approve_recovery:
            parser.error('recovery requires --approve-recovery and cannot combine with --scan-only')
        if not os.path.isabs(args.recover_file):
            parser.error('--recover-file must be an absolute path')
        if not (args.yes or confirm_action(f'RECOVER {args.recover_file} via {args.recovery_source}?')):
            return 1
        return 0 if recover_file(args.recover_file, args.recovery_source) else 2
    if args.verify_baseline:
        return 0 if load_baseline() is not None else 2
    if args.init or args.rebaseline:
        if args.init and os.path.exists(baseline_file):
            display('Baseline already exists; use --rebaseline after reviewing changes.', 'WARN')
            return 1
        if not (args.yes or confirm_action('Create a new trusted host baseline?')):
            return 1
        return 0 if create_baseline() else 2
    if args.schedule:
        if not (args.yes or confirm_action('Enable HOURLY scan-only automation?')):
            return 1
        return 0 if initialize_automation() else 2
    if args.disable_schedule:
        return 0 if disable_automation() else 2
    if args.cleanup:
        if not (args.yes or confirm_action('Delete evidence older than retention period?')):
            return 1
        cleanup_quarantine()
        rotate_logs(log_file)
        rotate_logs(event_log)
        return 0
    if args.uninstall:
        if not (args.yes or confirm_action('Disable hourly schedule but preserve all data?')):
            return 1
        uninstall()
        return 0
    return scan(deep=args.deep)

if __name__ == '__main__':
    sys.exit(main())
