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
# === Build: Jan 2026 === # === Updated: May 2026 == # === Version#: 1.5.0 === #
# ===== IDS Scanner ===== #

import sys, threading, os, psutil, hashlib, gzip, pwd, json, shutil, subprocess, time, stat, argparse, tempfile
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
# ==== CONFIG ====
backup_dir = "/etc/one-click/backup/guard"
binaries_dir = os.path.join(backup_dir, "binaries")
baseline_file = os.path.join(backup_dir, "system_baseline.json")
baseline_hash_file = os.path.join(backup_dir, "system_baseline.json.sha256")
quarantine_dir = os.path.join(backup_dir, "quarantine")
log_file = "/var/log/one-click/system_scans.log"
event_log = "/var/log/one-click/system_events.log"
retention_days = 30
NEW_FILE_AGE_THRESHOLD_SEC = 86400  # 24 Hours filtering for scan_temp()
hash_lock = threading.Lock()
log_lock = threading.RLock()
baseline_lock = threading.Lock()
protected_files = [
    "/bin/bash",
    "/bin/login",
    "/bin/ps",
    "/usr/bin/top",
    "/usr/bin/sudo",
    "/usr/bin/ssh",
    "/usr/sbin/sshd",
    "/usr/bin/find",
    "/usr/bin/ss",
    "/bin/ls"
]
critical_auth = [
    "/bin/login",
    "/usr/bin/passwd",
    "/bin/bash",
    "/usr/sbin/sshd"
]
monitor_dirs = [
    "/bin",
    "/usr/bin",
    "/usr/sbin"
]
risk_zones = [
    "/tmp",
    "/dev/shm",
    "/var/tmp",
    "/var/www",
    "/root",
    "/etc/ssh"
]
reset = "\033[0m"
blue = "\033[94m"
yellow = "\033[93m"
green = "\033[92m"
red = "\033[91m"
# ==== CACHED ENVIRONMENT CHECKS ====
HAS_CHATTR = shutil.which("chattr") is not None
HAS_RESTORECON = shutil.which("restorecon") is not None
HAS_SS = shutil.which("ss") is not None
HAS_LSOF = shutil.which("lsof") is not None
HAS_DPKGQUERY = shutil.which("dpkg-query") is not None
HAS_DPKG = shutil.which("dpkg") is not None
HAS_APT_GET = shutil.which("apt-get") is not None
HAS_RPM = shutil.which("rpm") is not None
HAS_DNF = shutil.which("dnf") is not None
ALLOW_REMEDIATION = False
# ==== LOGGING ====
def secure_log_permissions(path):
    try:
        if os.path.exists(path):
            os.chown(path, 0, 0)
            os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)
    except Exception:
        pass
def display(msg, level="INFO"):
    colors = {
        "ERROR": red,
        "INFO": blue,
        "WARN": yellow,
        "SUCCESS": green,
        "ALERT": red,
        "CRITICAL": red
    }
    with log_lock:
        print(f"{colors.get(level, blue)}[{level}]{reset} {msg}")
        try:
            os.makedirs(os.path.dirname(log_file), mode=0o700, exist_ok=True)
            with open(log_file, "a") as f:
                f.write(f"[{datetime.now().isoformat()}] [{level}] {msg}\n")
            secure_log_permissions(log_file)
        except Exception as e:
            print(f"{red}[ERROR]{reset} Logging failure: {e}")
def emit_event(event_type, data):
    event = {
        "timestamp": int(time.time()),
        "datetime": datetime.now().isoformat(),
        "type": event_type,
        "data": data
    }
    with log_lock:
        print(json.dumps(event))
        try:
            os.makedirs(os.path.dirname(event_log), mode=0o700, exist_ok=True)
            with open(event_log, "a") as f:
                f.write(json.dumps(event) + "\n")
            secure_log_permissions(event_log)
        except Exception as e:
            print(f"{red}[ERROR]{reset} Event logging failure: {e}")
# ==== CONFIRMATION ====
def confirm_action(prompt_text):
    prompt = f"{yellow}[CONFIRM]{reset} {prompt_text} (y|n): "
    while True:
        try:
            choice = input(prompt).lower().strip()
            if choice in ["y", "yes"]:
                return True
            if choice in ["n", "no"]:
                display("Action cancelled by user.", "WARN")
                return False
            print(f"{red}Please enter y or n.{reset}")
        except (KeyboardInterrupt, EOFError):
            print()
            return False
# ==== HASHING ====
def sha256_file(path):
    try:
        if not os.path.exists(path):
            return None
        if os.path.islink(path):
            return None
        st = os.stat(path)
        if not stat.S_ISREG(st.st_mode):
            return None
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception as e:
        display(f"Hashing failed for {path}: {e}", "WARN")
        return None
# ==== BASELINE INTEGRITY ====
def write_baseline_hash():
    immutable_hash_removed = False
    try:
        if HAS_CHATTR and os.path.exists(baseline_hash_file):
            subprocess.call(["chattr", "-i", baseline_hash_file], stderr=subprocess.DEVNULL)
            immutable_hash_removed = True
        baseline_hash = sha256_file(baseline_file)
        if not baseline_hash:
            return False
        with open(baseline_hash_file, "w") as f:
            f.write(baseline_hash)
            f.flush()
            os.fsync(f.fileno())
        secure_log_permissions(baseline_hash_file)
        return True
    except Exception as e:
        display(f"Baseline hash write failed: {e}", "ERROR")
        return False
    finally:
        if immutable_hash_removed and HAS_CHATTR:
            subprocess.call(["chattr", "+i", baseline_hash_file], stderr=subprocess.DEVNULL)
def verify_baseline_integrity():
    try:
        if not os.path.exists(baseline_hash_file):
            display("Baseline hash verification snapshot missing", "CRITICAL")
            return False
        with open(baseline_hash_file, "r") as f:
            stored = f.read().strip()
        current = sha256_file(baseline_file)
        if stored != current:
            # FIX 3: Downgraded to warning to allow degraded execution state models
            display("Baseline integrity verification verification checksum mismatch. System tracking running in DEGRADED mode.", "WARN")
            emit_event("baseline_integrity_degraded", {})
            return False
        return True
    except Exception as e:
        display(f"Baseline integrity check execution failed: {e}", "CRITICAL")
        return False
# ==== PACKAGE VALIDATION ====
def get_dpkg_package_owner(path):
    try:
        cmd = ["dpkg-query", "-S", "--", path] if HAS_DPKGQUERY else ["dpkg", "-S", path]
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode()
        line = out.splitlines()[0]
        pkg = line.split(":")[0].split(",")[0].strip()
        if "diversion by" in pkg or "diverted by" in pkg:
            parts = line.split()
            for part in parts:
                if "/" not in part and ":" not in part and part != "by":
                    pkg = part
                    break
        return pkg
    except Exception:
        return None
def compare_with_fresh_package(path):
    tmpdir = None
    try:
        path = os.path.realpath(path)
        if not (HAS_DPKG and HAS_APT_GET):
            return False
        pkg = get_dpkg_package_owner(path)
        if not pkg:
            return False
        tmpdir = tempfile.mkdtemp(prefix="pkgcheck_")
        res = subprocess.run(
            ["apt-get", "-o", "Acquire::Retries=0", "download", pkg],
            cwd=tmpdir,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
            env={"DEBIAN_FRONTEND": "noninteractive"}
        )
        if res.returncode != 0:
            display(f"Package download failed for {pkg}", "WARN")
            return False
        debs = [f for f in os.listdir(tmpdir) if f.startswith(pkg) and f.endswith(".deb")]
        if not debs:
            return False
        extract_dir = os.path.join(tmpdir, "extract")
        os.makedirs(extract_dir, exist_ok=True)
        subprocess.run(
            ["dpkg-deb", "-x", debs[0], extract_dir],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
            check=True
        )
        clean_path = os.path.join(extract_dir, path.lstrip("/"))
        return sha256_file(path) == sha256_file(clean_path)
    except Exception:
        return False
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)
def verify_binary_with_package_manager(path):
    try:
        path = os.path.realpath(path)
        if HAS_DPKG:
            pkg = get_dpkg_package_owner(path)
            if not pkg:
                return False
            out = subprocess.run(
                ["dpkg", "-V", pkg],
                capture_output=True,
                text=True,
                timeout=15
            ).stdout
            for line in out.splitlines():
                parts = line.split(maxsplit=1)
                if len(parts) != 2:
                    continue
                flags, file_path = parts
                if file_path.strip() == path:
                    # FIX 7: Explicit positional non-dot verification prevents evasion
                    if any(c != "." for c in flags):
                        return False
            return True
        elif HAS_RPM:
            pkg = subprocess.check_output(
                ["rpm", "-qf", path],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            out = subprocess.run(
                ["rpm", "-V", pkg],
                capture_output=True,
                text=True,
                timeout=15
            ).stdout
            for line in out.splitlines():
                if path in line:
                    return False
            return True
    except Exception:
        return False
    return False
# ==== PERMISSIONS ====
def check_permissions(path):
    try:
        st = os.stat(path)
        if st.st_uid != 0:
            display(f"{path} not owned by root", "CRITICAL")
        if st.st_mode & stat.S_IWOTH:
            display(f"{path} is world writable", "CRITICAL")
    except Exception as e:
        display(f"Permission check failed for {path}: {e}", "WARN")
# ==== SSH ENVIRONMENT SAFETY ====
def active_ssh_sessions():
    try:
        # FIX 4: Upgraded system connections collection logic mapping to prevent capability restriction aborts
        sshd_pids = {p.pid for p in psutil.process_iter(['name']) if p.info['name'] == 'sshd'}
        if not sshd_pids:
            return False
        for conn in psutil.net_connections(kind='tcp'):
            if conn.status == 'ESTABLISHED' and conn.pid in sshd_pids:
                return True
        return False
    except Exception:
        return False
def recent_ssh_logins():
    try:
        out = subprocess.check_output(
            ["last", "-n", "10"],
            stderr=subprocess.DEVNULL
        ).decode(errors="ignore")
        return "still logged in" in out.lower()
    except Exception:
        return False
def active_ssh_sessions_full():
    return active_ssh_sessions() or recent_ssh_logins()
# ==== PACKAGE REINSTALL ====
def reinstall_from_package(path):
    try:
        path = os.path.realpath(path)
        if HAS_APT_GET and HAS_DPKG:
            pkg = get_dpkg_package_owner(path)
            if not pkg:
                return False
            subprocess.run(
                ["apt-get", "install", "--reinstall", "-y", pkg],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=300,
                check=True
            )
            display(f"Reinstalled package: {pkg}", "SUCCESS")
            return True
        elif HAS_DNF and HAS_RPM:
            pkg = subprocess.check_output(
                ["rpm", "-qf", path],
                stderr=subprocess.DEVNULL
            ).decode().strip()
            subprocess.run(
                ["dnf", "reinstall", "-y", pkg],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=300,
                check=True
            )
            display(f"Reinstalled package: {pkg}", "SUCCESS")
            return True
    except Exception as e:
        display(f"Package reinstall execution pipeline dropped: {e}", "ERROR")
    return False
# ==== QUARANTINE ====
def quarantine_file(file_path):
    try:
        if not os.path.exists(file_path):
            return None
        os.makedirs(quarantine_dir, exist_ok=True)
        clean_name = file_path.lstrip("/").replace("/", "_")
        dest = os.path.join(quarantine_dir, f"{clean_name}.{int(time.time())}")
        shutil.copy2(file_path, dest)
        os.chown(dest, 0, 0)
        os.chmod(dest, 0o600)
        display(f"Quarantined copy created: {dest}", "WARN")
        return dest
    except Exception as e:
        display(f"Quarantine failed for {file_path}: {e}", "ERROR")
        return None
# ==== BASELINE UPDATE ====
def update_baseline_hash(file_path, new_hash):
    if not ALLOW_REMEDIATION:
        display(f"Baseline signature modification update bypassed for {file_path} (IDS running in strict --scan-only mode).", "WARN")
        return False
    with baseline_lock:
        immutable_file_removed = False
        immutable_hash_removed = False
        try:
            if not os.path.exists(baseline_file):
                return False
            if HAS_CHATTR:
                if os.path.exists(baseline_file):
                    subprocess.call(["chattr", "-i", baseline_file], stderr=subprocess.DEVNULL)
                    immutable_file_removed = True
                if os.path.exists(baseline_hash_file):
                    subprocess.call(["chattr", "-i", baseline_hash_file], stderr=subprocess.DEVNULL)
                    immutable_hash_removed = True
            with open(baseline_file, "r") as f:
                data = json.load(f)
            data["hashes"][file_path] = new_hash
            tmp = baseline_file + ".tmp"
            with open(tmp, "w") as f:
                json.dump(data, f, indent=4)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, baseline_file)
            write_baseline_hash()
            return True
        except Exception as e:
            display(f"Baseline update failed: {e}", "ERROR")
            return False
        finally:
            if HAS_CHATTR:
                if immutable_file_removed:
                    subprocess.call(["chattr", "+i", baseline_file], stderr=subprocess.DEVNULL)
                if immutable_hash_removed:
                    subprocess.call(["chattr", "+i", baseline_hash_file], stderr=subprocess.DEVNULL)
# ==== SANITIZE ====
def sanitize_file(path, stored_hash, current_hash):
    if not ALLOW_REMEDIATION:
        display(f"Remediation target execution bypassed for modified binary {path} (IDS executing under --scan-only profiles).", "WARN")
        return False
    display(f"Remediation started: {path}", "WARN")
    if path in critical_auth and active_ssh_sessions_full():
        display("Blocked remediation: critical auth binary + active session", "CRITICAL")
        emit_event("remediation_blocked_active_ssh", {"file": path})
        return False
    if verify_binary_with_package_manager(path):
        display(f"Verified clean via package manager: {path}", "SUCCESS")
        update_baseline_hash(path, current_hash)
        return True
    if compare_with_fresh_package(path):
        display(f"Verified against upstream package: {path}", "SUCCESS")
        update_baseline_hash(path, current_hash)
        return True
    quarantine_file(path)
    backup = os.path.join(binaries_dir, path.lstrip("/").replace("/", "_"))
    if stored_hash and os.path.exists(backup):
        backup_hash = sha256_file(backup)
        if backup_hash == stored_hash:
            tmp_swap = None
            try:
                fd_check = os.open(path, os.O_PATH | os.O_NOFOLLOW)
                try:
                    orig_stat = os.fstat(fd_check)
                    if stat.S_ISLNK(orig_stat.st_mode):
                        display(f"Refusing restore to symlink target profile: {path}", "CRITICAL")
                        return False
                    if not stat.S_ISREG(orig_stat.st_mode):
                        display(f"Refusing restore to non-regular target file format: {path}", "CRITICAL")
                        return False
                finally:
                    os.close(fd_check)
                swap_dir = os.path.dirname(path)
                fd, tmp_swap = tempfile.mkstemp(prefix=".ids_swap_", dir=swap_dir)
                os.close(fd)
                shutil.copy2(backup, tmp_swap)
                tmp_stat = os.lstat(tmp_swap)
                if not stat.S_ISREG(tmp_stat.st_mode):
                    os.remove(tmp_swap)
                    return False
                os.chown(tmp_swap, orig_stat.st_uid, orig_stat.st_gid)
                os.chmod(tmp_swap, stat.S_IMODE(orig_stat.st_mode))
                parent_fd = os.open(swap_dir, os.O_DIRECTORY | os.O_RDONLY)
                try:
                    final_stat = os.lstat(path)
                    if final_stat.st_ino != orig_stat.st_ino or final_stat.st_dev != orig_stat.st_dev:
                        display(f"TOCTOU race modification pattern detected during fallback verification pass: {path}", "CRITICAL")
                        os.remove(tmp_swap)
                        return False
                    dir_stat = os.fstat(parent_fd)
                    current_dir_stat = os.lstat(swap_dir)
                    if dir_stat.st_ino != current_dir_stat.st_ino or dir_stat.st_dev != current_dir_stat.st_dev:
                        display(f"TOCTOU baseline folder mutation attack detected on directory path context: {swap_dir}", "CRITICAL")
                        os.remove(tmp_swap)
                        return False
                    os.replace(tmp_swap, path)
                finally:
                    os.close(parent_fd)
                if HAS_RESTORECON:
                    subprocess.call(["restorecon", "-F", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                display(f"Restored from backup: {path}", "SUCCESS")
                emit_event("restored_from_backup", {"file": path})
                return True
            except Exception as e:
                display(f"Restore failed: {e}", "ERROR")
            finally:
                if tmp_swap and os.path.exists(tmp_swap):
                    try:
                        os.remove(tmp_swap)
                    except Exception:
                        pass
    if not active_ssh_sessions_full():
        if reinstall_from_package(path):
            # FIX 2: Post-Remediation Verification hash re-checks prevent faulty recovery loops
            post_repair_hash = sha256_file(path)
            if post_repair_hash and (post_repair_hash == stored_hash or verify_binary_with_package_manager(path)):
                update_baseline_hash(path, post_repair_hash)
                emit_event("reinstalled_package_verified", {"file": path})
                return True
            else:
                display(f"CRITICAL: Package replacement execution sequence finished but the binary signature for {path} remains invalid!", "CRITICAL")
                emit_event("reremediation_verification_failed", {"file": path})
                return False

    display(f"Remediation failed: {path}", "CRITICAL")
    emit_event("remediation_failed", {"file": path})
    return False
# ==== CLEANUP ====
def cleanup_quarantine():
    if not os.path.exists(quarantine_dir):
        return
    now = time.time()
    for f in os.listdir(quarantine_dir):
        f_path = os.path.join(quarantine_dir, f)
        try:
            if os.stat(f_path).st_mtime < now - (retention_days * 86400):
                os.remove(f_path)
                display(f"Purged old quarantine file: {f}", "INFO")
        except Exception:
            pass
# ==== LOG ROTATION ====
def rotate_logs(target_file, max_backups=5):
    try:
        if not os.path.exists(target_file):
            return
        if os.path.getsize(target_file) < 10 * 1024 * 1024:
            return
        display(f"Rotating log: {target_file}", "INFO")
        with log_lock:
            for i in range(max_backups - 1, 0, -1):
                src = f"{target_file}.{i}.gz"
                dst = f"{target_file}.{i + 1}.gz"
                if os.path.exists(src):
                    os.rename(src, dst)
            gz_file = f"{target_file}.1.gz"
            with open(target_file, "rb") as f_in:
                with gzip.open(gz_file, "wb") as f_out:
                    shutil.copyfileobj(f_in, f_out)
            secure_log_permissions(gz_file)
            with open(target_file, "w") as f:
                f.truncate(0)
            secure_log_permissions(target_file)
    except Exception as e:
        display(f"Log rotation failure: {e}", "ERROR")
# ==== DISCOVERY ====
def scan_temp():
    display("Performing deep risk-zone scan...", "INFO")
    ignore_ext = [".swp", ".tmp", ".lock"]
    now = time.time()
    for zone in risk_zones:
        if not os.path.exists(zone):
            continue
        display(f"Scanning zone: {zone}", "INFO")
        try:
            if os.path.isfile(zone):
                targets = [zone]
            else:
                targets = []
                for root, _, files in os.walk(zone):
                    for f in files:
                        targets.append(os.path.join(root, f))
            for p in targets:
                try:
                    if os.path.islink(p):
                        continue
                    if any(p.endswith(x) for x in ignore_ext):
                        continue
                    f_stat = os.lstat(p)
                    if (now - f_stat.st_mtime) > NEW_FILE_AGE_THRESHOLD_SEC:
                        continue
                    executable = os.access(p, os.X_OK)
                    if executable:
                        display(f"Newly modified execution candidate discovered: {p}", "ALERT")
                    if os.path.basename(p).startswith(".") and executable:
                        display(f"Hidden newly modified executable discovered: {p}", "ALERT")
                except Exception as e:
                    display(f"Failed to inspect {p}: {e}", "WARN")
        except Exception as e:
            display(f"Risk zone scan failure: {e}", "WARN")
# ==== ROOTKIT CHECKS ====
def rootkit_checks():
    try:
        preload = "/etc/ld.so.preload"
        if os.path.exists(preload):
            if os.path.getsize(preload) > 0:
                display("Non-empty /etc/ld.so.preload detected", "CRITICAL")
    except Exception as e:
        display(f"Rootkit check failure: {e}", "WARN")
# ==== PATH CHECK ====
def check_path():
    try:
        path_env = os.environ.get("PATH", "")
        risky = ["/tmp", "/dev/shm", "/var/tmp"]
        for p in path_env.split(":"):
            if not p:
                continue
            if any(p.startswith(r) for r in risky):
                display(f"Unsafe PATH entry: {p}", "CRITICAL")
    except Exception as e:
        display(f"PATH validation failure: {e}", "WARN")
# ==== CRON + SYSTEMD ====
def check_cron_systemd():
    cron_dirs = [
        "/etc/cron.d",
        "/var/spool/cron",
        "/etc/cron.daily",
        "/etc/cron.hourly"
    ]
    for d in cron_dirs:
        if not os.path.exists(d):
            continue
        try:
            for f in os.listdir(d):
                display(f"Cron persistence entry: {os.path.join(d, f)}", "INFO")
        except Exception:
            pass
    systemd_path = "/etc/systemd/system"
    if os.path.exists(systemd_path):
        try:
            for f in os.listdir(systemd_path):
                if f.endswith(".service"):
                    display(f"Systemd service detected: {f}", "INFO")
        except Exception:
            pass
# ==== SSH KEYS ====
def check_ssh_keys():
    for u in pwd.getpwall():
        try:
            auth = os.path.join(u.pw_dir, ".ssh", "authorized_keys")
            if os.path.exists(auth):
                display(f"SSH authorized_keys present: {auth}", "INFO")
        except Exception:
            pass
# ==== SUID ====
def check_suid():
    for d in ["/bin", "/usr/bin", "/usr/sbin"]:
        for root, _, files in os.walk(d):
            for f in files:
                p = os.path.join(root, f)
                try:
                    if os.path.islink(p):
                        continue
                    st = os.stat(p)
                    if st.st_mode & stat.S_ISUID:
                        display(f"SUID binary detected: {p}", "INFO")
                except Exception:
                    pass
# ==== PORTS ====
def check_ports():
    try:
        if HAS_SS:
            subprocess.check_output(["ss", "-tuln"], stderr=subprocess.DEVNULL)
            display("Listening sockets inspected", "INFO")
    except Exception:
        pass
# ==== DELETED BINARIES ====
def check_deleted_binaries():
    try:
        if not HAS_LSOF:
            return
        out = subprocess.run(
            ["lsof", "-nP"],
            capture_output=True,
            text=True,
            timeout=15
        ).stdout

        for line in out.splitlines():
            if "deleted" not in line.lower():
                continue
            if any(x in line for x in [".log", "anon_inode", "memfd:"]):
                continue
            display(f"Running deleted binary detected: {line}", "CRITICAL")
    except Exception:
        pass
# ==== FILE INTEGRITY ====
def check_integrity(baseline):
    for f in protected_files:
        try:
            if not os.path.exists(f):
                display(f"Protected file missing: {f}", "CRITICAL")
                emit_event("protected_file_missing", {"file": f})
                continue
            check_permissions(f)
            current_hash = sha256_file(f)
            stored_hash = baseline.get("hashes", {}).get(f) if baseline else None
            if not stored_hash:
                display(f"Baseline lookup context absent for path {f}. Attempting direct package metadata verification passes.", "WARN")
                if not verify_binary_with_package_manager(f):
                    display(f"Integrity violation flagged on unindexed target file path: {f}", "CRITICAL")
                    sanitize_file(f, None, current_hash)
                continue
            if current_hash != stored_hash:
                display(f"Integrity violation detected: {f}", "CRITICAL")
                emit_event("integrity_violation", {"file": f})
                sanitize_file(f, stored_hash, current_hash)
            else:
                display(f"Verified: {f}", "SUCCESS")
        except Exception as e:
            display(f"Integrity check failure for {f}: {e}", "ERROR")
# ==== AUTOMATION ====
def initialize_automation():
    cron_path = "/etc/cron.d/one-click-scanner"
    script_path = os.path.abspath(__file__)
    python_bin = sys.executable or "/usr/bin/python3"
    try:
        parent_dir = os.path.dirname(script_path)
        while parent_dir and parent_dir != "/":
            p_stat = os.stat(parent_dir)
            if p_stat.st_uid != 0 or (p_stat.st_mode & stat.S_IWGRP) or (p_stat.st_mode & stat.S_IWOTH):
                display(f"Automation blocked: {parent_dir} not secure", "CRITICAL")
                return
            parent_dir = os.path.dirname(parent_dir)
        st = os.stat(script_path)
        if st.st_uid != 0:
            display("Script is not root-owned", "CRITICAL")
            return
        cron_entry = f"0 * * * * root {python_bin} {script_path} --deep --remediate -y\n"
        if os.path.exists(cron_path):
            with open(cron_path, "r") as cf:
                if cf.read() == cron_entry:
                    display("Cron entry is identical and already present. Initialization bypassed.", "SUCCESS")
                    return
        with open(cron_path, "w") as f:
            f.write(cron_entry)
        os.chmod(cron_path, 0o644)
        display(f"Automation initialized cleanly: {cron_path}", "SUCCESS")
    except Exception as e:
        display(f"Automation setup failed: {e}", "ERROR")
# ==== UNINSTALL ====
def uninstall():
    display("Starting uninstall process...", "WARN")
    cron_path = "/etc/cron.d/one-click-scanner"
    if os.path.exists(cron_path):
        try:
            os.remove(cron_path)
            display("Removed cron automation", "SUCCESS")
        except Exception as e:
            display(f"Failed removing cron: {e}", "ERROR")
    for f in [baseline_file, baseline_hash_file]:
        if os.path.exists(f):
            try:
                if HAS_CHATTR:
                    subprocess.call(["chattr", "-i", f], stderr=subprocess.DEVNULL)
                os.remove(f)
                display(f"Removed: {f}", "SUCCESS")
            except Exception as e:
                display(f"Failed removing {f}: {e}", "ERROR")
    if os.path.exists(backup_dir):
        if confirm_action("Delete all backups and quarantine data?"):
            try:
                if HAS_CHATTR:
                    subprocess.call(["chattr", "-i", backup_dir], stderr=subprocess.DEVNULL)
                shutil.rmtree(backup_dir)
                display("Backup storage removed", "SUCCESS")
            except Exception as e:
                display(f"Backup removal failure: {e}", "ERROR")
    display("Uninstall complete", "SUCCESS")
# ==== BASELINE CREATION ====
def create_baseline():
    if HAS_CHATTR:
        if os.path.exists(baseline_file):
            subprocess.call(["chattr", "-i", baseline_file], stderr=subprocess.DEVNULL)
        if os.path.exists(baseline_hash_file):
            subprocess.call(["chattr", "-i", baseline_hash_file], stderr=subprocess.DEVNULL)
    os.makedirs(backup_dir, exist_ok=True)
    os.makedirs(quarantine_dir, exist_ok=True)
    os.makedirs(binaries_dir, exist_ok=True)
    hashes = {}
    display(f"Creating baseline across: {', '.join(monitor_dirs)}", "INFO")
    def process_file(path):
        try:
            st = os.lstat(path)
            if not stat.S_ISREG(st.st_mode):
                return
            if not os.access(path, os.X_OK):
                return
            h = sha256_file(path)
            if not h:
                return
            with hash_lock:
                hashes[path] = h
            clean_name = path.lstrip("/").replace("/", "_")
            backup_path = os.path.join(binaries_dir, clean_name)
            shutil.copy2(path, backup_path)
        except Exception as e:
            display(f"Failed processing {path}: {e}", "WARN")
    def fast_scandir(target_dir):
        paths = []
        try:
            for entry in os.scandir(target_dir):
                if entry.is_symlink():
                    continue
                if entry.is_file():
                    paths.append(entry.path)
                elif entry.is_dir(follow_symlinks=False):
                    if os.path.abspath(entry.path).startswith(os.path.abspath(backup_dir)):
                        continue
                    paths.extend(fast_scandir(entry.path))
        except Exception:
            pass
        return paths
    cpu_count = os.cpu_count() or 2
    max_workers = cpu_count * 2
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        for d in monitor_dirs:
            file_paths = fast_scandir(d)
            list(executor.map(process_file, file_paths))
    users = {u.pw_name: u.pw_uid for u in pwd.getpwall()}
    data = {
        "hashes": hashes,
        "users": users,
        "created": datetime.now().isoformat()
    }
    tmp = baseline_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=4)
        f.flush()
        os.fsync(f.fileno())
    immutable_applied = False
    try:
        os.replace(tmp, baseline_file)
        write_baseline_hash()
        if HAS_CHATTR:
            subprocess.call(["chattr", "+i", baseline_file], stderr=subprocess.DEVNULL)
            immutable_applied = True
    finally:
        if not immutable_applied and HAS_CHATTR and os.path.exists(baseline_file):
            subprocess.call(["chattr", "+i", baseline_file], stderr=subprocess.DEVNULL)
    display(f"Baseline created: {baseline_file}", "SUCCESS")
# ==== SCAN ====
def scan(deep=False):
    rotate_logs(log_file)
    rotate_logs(event_log)
    baseline = None
    if not os.path.exists(baseline_file):
        display("Baseline missing. Initializing runtime under independent verification modes.", "WARN")
    else:
        # Verify hash parameters to detect internal database manipulation vectors
        verify_baseline_integrity()
        try:
            with open(baseline_file, "r") as f:
                baseline = json.load(f)
        except Exception as e:
            display(f"Failed loading baseline: {e}. Running checks via fallback manager definitions.", "WARN")
    display("=== Scan Started ===", "INFO")
    cleanup_quarantine()
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
    display("=== Scan Complete ===", "SUCCESS")
# ==== MAIN ====
if __name__ == "__main__":
    if os.getuid() != 0:
        print(f"{red}[ERROR]{reset} Root privileges required.")
        sys.exit(1)

    print(f"""{yellow}
==================================================
ONE-CLICK SYSTEM HARDENED HOST IDS
==================================================
{reset}""")

    parser = argparse.ArgumentParser()
    parser.add_argument("--init", action="store_true")
    parser.add_argument("--deep", action="store_true")
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--scan-only", action="store_true", help="Perform scanning and validations without mutations")
    parser.add_argument("--remediate", action="store_true", help="Authorize automated healing and recovery actions")
    parser.add_argument(
        "--yes", "-y",
        action="store_true",
        help="Proceed without confirmation prompts"
    )
    args = parser.parse_args()
    if args.remediate and not args.scan_only:
        ALLOW_REMEDIATION = True
    else:
        ALLOW_REMEDIATION = False

    if args.uninstall:
        if args.yes or confirm_action("This removes IDS configuration and backups. Continue?"):
            uninstall()
        sys.exit(0)
    if not args.yes:
        action_desc = "initialize baseline" if args.init else "run security scan"
        if not confirm_action(f"Proceed and {action_desc}?"):
            sys.exit(0)
    if args.init:
        if os.path.exists(baseline_file):
            try:
                ts = os.path.getmtime(baseline_file)
                created = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
            except Exception:
                created = "unknown"
            display(f"Baseline already exists ({created})", "WARN")
        else:
            # Temporarily allow remediation scope to execute initial structural creations
            ALLOW_REMEDIATION = True
            create_baseline()
            if args.yes or confirm_action("Enable hourly automation?"):
                initialize_automation()
            display("Initialization complete", "SUCCESS")
    else:
        display(f"Starting tracking scanner pass (Remediation Mode: {'ACTIVE' if ALLOW_REMEDIATION else 'DISABLED'})...", "INFO")
        scan(deep=args.deep)
        display("Scan finalized", "SUCCESS")
