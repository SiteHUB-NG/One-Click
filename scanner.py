#!/usr/bin/env python3
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK MULTI TOOLBOX * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ===== IDS Scanner ===== #
import sys, threading, os, psutil, hashlib, gzip, pwd, json, shutil, subprocess, time, stat, argparse, socket
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
# ==== Configuration ====
backup_dir = "/etc/one-click/backup/guard"
binaries_dir = os.path.join(backup_dir, "binaries")
baseline_file = os.path.join(backup_dir, "system_baseline.json")
quarantine_dir = os.path.join(backup_dir, "quarantine")
log_file = "/var/log/one-click/system_scans.log"
event_log = "/var/log/one-click/system_events.log"
hash_lock = threading.Lock()
retention_days = 30
protected_files = [
    "/bin/bash", "/bin/login", "/bin/ps", "/bin/netstat",
    "/usr/bin/top", "/usr/bin/sudo", "/usr/bin/ssh",
    "/usr/sbin/sshd", "/usr/bin/find", "/usr/bin/ss", "/bin/ls"
]
critical_auth = ["/bin/login", "/usr/bin/passwd", "/bin/bash", "/usr/sbin/sshd"]
monitor_dirs = ["/bin", "/usr/bin", "/usr/sbin"]
risk_zones = ["/tmp", "/dev/shm", "/var/tmp", "/var/www/", "/root", "/etc/ssh/", "/etc/passwd", "/etc/shadow", "/etc/pam"]
reset, blue, yellow, green, red = "\033[0m", "\033[94m", "\033[93m", "\033[92m", "\033[91m"
# ==== Display & Logging ==== 
def display(msg, level="INFO"):
    colors = {"ERROR": red, "INFO": blue, "WARN": yellow, "SUCCESS": green, "ALERT": red, "CRITICAL": red}
    print(f"{colors.get(level, blue)}[{level}]{reset} {msg}")
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    with open(log_file, "a") as f:
        f.write(f"[{datetime.now()}] [{level}] {msg}\n")
def emit_event(event_type, data):
    event = {
        "timestamp": int(time.time()), 
        "datetime": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "type": event_type, 
        "data": data
    }
    print(json.dumps(event))
    os.makedirs(os.path.dirname(event_log), exist_ok=True)
    with open(event_log, "a") as f:
        f.write(json.dumps(event) + "\n")
# ==== Confirmation ====
def confirm_action(prompt_text):
    prompt = f"{yellow}[CONFIRM]{reset} {prompt_text} (y|n): "
    while True:
        choice = input(prompt).lower().strip()
        if choice in ['y', 'yes']:
            return True
        if choice in ['n', 'no']:
            display("Action cancelled by user.", "ERROR")
            return False
        print(f"{red}Please enter 'y' or 'n'.{reset}")
# ==== Hashing ====
def sha256_file(path):
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                h.update(chunk)
        return h.hexdigest()
    except:
        return None
# ==== Permissions Check =====
def check_permissions(path):
    try:
        st = os.stat(path)
        if st.st_uid != 0:
            display(f"{path} not owned by root", "CRITICAL")
        if st.st_mode & stat.S_IWOTH:
            display(f"{path} world writable", "CRITICAL")
    except Exception as e:
        display(f"Permission check failed for {path}: {e}", "WARN")
# ==== Active Sessions ====
def active_ssh_sessions():
    for proc in psutil.process_iter(['name', 'uids']):
        try:
            if proc.info['name'] in ['ssh', 'sshd', 'scp', 'sftp']:
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return False
def recent_ssh_logins():
    try:
        out = subprocess.check_output(["last", "-F", "-n", "10"]).decode()
        return any("ssh" in line.lower() for line in out.splitlines())
    except:
        return False
def active_ssh_sessions_full():
    if active_ssh_sessions():
        return True
    return recent_ssh_logins()
# ==== Reinstall Packages ====
def reinstall_from_package(path):
    pkg_mgr = "apt-get" if shutil.which("apt-get") else "dnf" if shutil.which("dnf") else None
    if not pkg_mgr:
        display("No supported package manager found.", "CRITICAL")
        return False
    try:
        pkg_name = None
        if pkg_mgr == "apt-get":
            pkg = subprocess.check_output(["dpkg", "-S", path]).decode()
            pkg_name = pkg.split(":")[0].split()[0].strip()
            subprocess.call(["apt-get", "update", "-qq"])
            subprocess.call(["apt-get", "install", "--reinstall", "-y", pkg_name])
        else:
            pkg = subprocess.check_output(["rpm", "-qf", path]).decode()
            pkg_name = pkg.strip()
            subprocess.call(["dnf", "reinstall", "-y", pkg_name])
        display(f"Package {pkg_name} reinstalled", "SUCCESS")
        return True
    except Exception as e:
        display(f"Package reinstall failed for {path}: {e}", "CRITICAL")
        return False
# ==== Sanitize ====
def sanitize_file(file_path, stored_hash):
    if file_path in critical_auth and active_ssh_sessions_full():
        display(f"Skipping auto-restoration of {file_path} due to active session", "WARN")
        return False
    if os.path.exists(file_path):
        quarantine(file_path)
    clean_name = file_path.lstrip("/").replace("/", "_")
    backup_path = os.path.join(binaries_dir, clean_name)
    if not stored_hash:
        display(f"No stored hash for {file_path}, skipping restore", "WARN")
        return False
    if os.path.exists(backup_path) and sha256_file(backup_path) == stored_hash:
        try:
            shutil.copy2(backup_path, file_path)
            display(f"Restored {file_path} from local backup", "SUCCESS")
            return True
        except Exception as e:
            display(f"Local restore failed: {e}", "WARN")
    if not active_ssh_sessions_full():
        return reinstall_from_package(file_path)
    display(f"Could not safely restore {file_path}", "CRITICAL")
    return False
# ==== Cleanup ====
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
        except:
            pass
# ==== Log Rotate ====
def rotate_logs(target_file, max_backups=5):
    if not os.path.exists(target_file) or os.path.getsize(target_file) < 10 * 1024 * 1024:
        return
    display(f"Rotating log file: {target_file}", "INFO")
    for i in range(max_backups - 1, 0, -1):
        s = f"{target_file}.{i}.gz"
        d = f"{target_file}.{i+1}.gz"
        if os.path.exists(s):
            os.rename(s, d)
    with open(target_file, 'rb') as f_in:
        with gzip.open(f"{target_file}.1.gz", 'wb') as f_out:
            shutil.copyfileobj(f_in, f_out)
    open(target_file, 'w').close()
# ==== Discovery ====
def scan_temp():
    display("Performing deep temp folder scan...", "SUCCESS")
    for zone in risk_zones:
        display(f"Scanning zone: {zone}", "INFO")
        if os.path.isfile(zone):
            files = [os.path.basename(zone)]
            root = os.path.dirname(zone)
            for f in files:
                p = os.path.join(root, f)
                try:
                    msg = f"Scanning {p} ..."
                    if os.access(p, os.X_OK):
                        msg += " [EXECUTABLE]"
                    display(msg, "INFO")
                    if os.access(p, os.X_OK):
                        display(f"Executable found: {p}", "ALERT")
                    if f.startswith(".") and os.access(p, os.X_OK):
                        display(f"Hidden executable found: {p}", "ALERT")
                except Exception as e:
                    display(f"Failed to scan {p}: {e}", "WARN")
        else:
            for root, dirs, files in os.walk(zone):
                for f in files:
                    p = os.path.join(root, f)
                    try:
                        msg = f"Scanning {p} ..."
                        if os.access(p, os.X_OK):
                            msg += " [EXECUTABLE]"
                        display(msg, "INFO")
                        if os.access(p, os.X_OK):
                            display(f"Executable found: {p}", "ALERT")
                        if f.startswith(".") and os.access(p, os.X_OK):
                            display(f"Hidden executable found: {p}", "ALERT")
                    except Exception as e:
                        display(f"Failed to scan {p}: {e}", "WARN")
# ==== Deep Checks ====
def rootkit_checks():
    if os.path.exists("/etc/ld.so.preload"):
        display("Possible LD_PRELOAD rootkit detected", "CRITICAL")
def check_path():
    path_env = os.environ.get("PATH", "")
    for p in path_env.split(":"):
        if p in ["/tmp", "/dev/shm", "/var/tmp"]:
            display(f"Unsafe PATH detected: {p}", "CRITICAL")
# ==== Cron Checks ====
def check_cron_systemd():
    cron_dirs = ["/etc/cron.d", "/var/spool/cron"]
    for d in cron_dirs:
        if os.path.exists(d):
            for f in os.listdir(d):
                display(f"Cron entry detected: {f}", "INFO")
    systemd_path = "/etc/systemd/system"
    if os.path.exists(systemd_path):
        for f in os.listdir(systemd_path):
            if f.endswith(".service"):
                display(f"Systemd service: {f}", "INFO")
# ==== Cron Automation ====
def initialize_automation():
    cron_path = "/etc/cron.d/one-click-scanner"
    script_path = os.path.abspath(__file__)
    # ==== Cron Runs Every Hour ====
    cron_entry = f"0 * * * * root /usr/bin/python3 {script_path} --deep -y\n"
    try:
        if os.path.exists(cron_path):
            subprocess.call(["chattr", "-i", cron_path], stderr=subprocess.DEVNULL)
        with open(cron_path, "w") as f:
            f.write(cron_entry)
        os.chmod(cron_path, 0o644)
        display(f"Automation established at {cron_path}", "SUCCESS")
    except Exception as e:
        display(f"Failed to initialize automation: {e}", "CRITICAL")
# ==== SSH & SUID ====
def check_ssh_keys():
    for u in pwd.getpwall():
        home = u.pw_dir
        auth = os.path.join(home, ".ssh", "authorized_keys")
        if os.path.exists(auth):
            display(f"SSH key found: {auth}", "INFO")
def check_suid():
    for d in ["/bin","/usr/bin","/usr/sbin"]:
        for root, dirs, files in os.walk(d):
            for f in files:
                p = os.path.join(root,f)
                try:
                    st = os.stat(p)
                    if st.st_mode & stat.S_ISUID:
                        display(f"SUID binary: {p}", "INFO")
                except:
                    pass
# ==== Listeners ====
def check_ports():
    try:
        subprocess.check_output(["ss","-tuln"], stderr=subprocess.DEVNULL)
        display("Listening ports detected", "INFO")
    except:
        pass
# ==== File Integrity ====
def check_integrity(baseline):
    for f in protected_files:
        check_permissions(f)
        current_hash = sha256_file(f)
        stored_hash = baseline["hashes"].get(f)
        if current_hash != stored_hash:
            display(f"Integrity failure: {f}", "CRITICAL")
            emit_event("binary_integrity_failure", {"file": f})
            sanitize_file(f, stored_hash)
        else:
            display(f"Verified {f}", "SUCCESS")
# ==== Uninstall ====
def uninstall():
    """Systematically removes all IDS components and automation."""
    display("Starting uninstallation process...", "WARN")
    cron_path = "/etc/cron.d/one-click-scanner"
    if os.path.exists(cron_path):
        try:
            subprocess.call(["chattr", "-i", cron_path], stderr=subprocess.DEVNULL)
            os.remove(cron_path)
            display("Removed cron automation.", "SUCCESS")
        except Exception as e:
            display(f"Failed to remove cron: {e}", "ERROR")
    if os.path.exists(baseline_file):
        try:
            subprocess.call(["chattr", "-i", baseline_file], stderr=subprocess.DEVNULL)
            os.remove(baseline_file)
            display("Removed system baseline.", "SUCCESS")
        except Exception as e:
            display(f"Failed to remove baseline: {e}", "ERROR")
    if os.path.exists(backup_dir):
        if confirm_action("Delete all binary backups and quarantined files?"):
            try:
                shutil.rmtree(backup_dir)
                display("Deleted backup and quarantine directories.", "SUCCESS")
            except Exception as e:
                display(f"Failed to delete backups: {e}", "ERROR")
    display("Uninstallation complete. Logs remain at /var/log/one-click/.", "SUCCESS")
# ==== Baseline ====
def create_baseline():
    os.makedirs(backup_dir, exist_ok=True)
    os.makedirs(quarantine_dir, exist_ok=True)
    os.makedirs(binaries_dir, exist_ok=True)
    hashes = {}
    display(f"Starting baseline creation. Scanning directories: {', '.join(monitor_dirs)}", "INFO")
    def process_file(p):
        try:
            h = sha256_file(p)
            if h:
                with hash_lock:
                    hashes[p] = h  # thread-safe update
                if os.path.dirname(p) in ["/bin","/usr/bin","/usr/sbin"]:
                    clean_name = p.lstrip("/").replace("/", "_")
                    backup_path = os.path.join(binaries_dir, clean_name)
                    shutil.copy2(p, backup_path)
                display(f"Hashed: {p}", "INFO")
        except Exception as e:
            display(f"Failed to process {p}: {e}", "WARN")
    for d in monitor_dirs:
        for root, dirs, files in os.walk(d):
            if os.path.abspath(root).startswith(os.path.abspath(backup_dir)):
                continue
            file_paths = [os.path.join(root, f) for f in files]
            with ThreadPoolExecutor(max_workers=12) as executor:
                executor.map(process_file, file_paths)
    users = {u.pw_name: u.pw_uid for u in pwd.getpwall()}
    with open(baseline_file, "w") as f:
        json.dump({"hashes": hashes, "users": users}, f, indent=4)
    display(f"Baseline successfully created at {baseline_file}", "SUCCESS")
    try:
        subprocess.call(["chattr","+i",baseline_file])
        display("Baseline file locked with chattr +i", "INFO")
    except Exception as e:
        display(f"Failed to lock baseline file: {e}", "WARN")
# ==== Logical Scan ====
def scan(deep=False):
    rotate_logs(log_file)
    rotate_logs(event_log)
    if not os.path.exists(baseline_file):
        display("Baseline missing. Run with --init first", "CRITICAL")
        return
    with open(baseline_file) as f:
        baseline = json.load(f)
    display("--- Scan Initiated ---", "INFO")
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
# ==== Main Scan ====
if __name__=="__main__":
    if os.getuid()!=0:
        print(f"{red}[ERROR]{reset} Root required.")
        sys.exit(1)
    print(f"""{yellow}
==============================
ONE-CLICK SYSTEM IDS SCANNER
==============================
This is a lightweight Linux Host Intrusion Detection System (HIDS).
It will perform the following actions:

- Check system binaries for integrity
- Quarantine suspicious files
- Attempt safe self-healing of critical binaries
- Check active SSH sessions to avoid lockouts
- Inspect cron/systemd persistence
- Detect SUID binaries and listening ports
- Optionally perform deep temp folder scans
- Maintain a baseline for future comparisons

All actions are logged at {log_file}.
Quarantined files will be stored in {quarantine_dir}.
Backups of protected binaries are stored in {binaries_dir}.
{reset}
""")
    parser = argparse.ArgumentParser()
    parser.add_argument("--init", action="store_true")
    parser.add_argument("--deep", action="store_true")
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--yes", "-y", action="store_true", help="Proceed without confirmation")
    args = parser.parse_args()
    if args.uninstall:
        if args.yes or confirm_action("This will remove all security backups and automation. Proceed?"):
            uninstall()
        sys.exit(0)
    if not args.yes:
        action_desc = "initialize baseline (this modifies/creates files)" if args.init else "start system scan"
        if not confirm_action(f"Do you wish to proceed with {action_desc}?"):
            sys.exit(0)
    if args.init:
        if os.path.exists(baseline_file):
            try:
                ts = os.path.getmtime(baseline_file)
                created_str = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
            except:
                created_str = "unknown"
            msg = f"Baseline already exists at {baseline_file} (created/modified: {created_str}). Cannot initialize again."
            display(msg, "WARN")
        else:
            display("Creating baseline. This may take several minutes...", "INFO")
            create_baseline()
            if args.yes or confirm_action("Would you like to schedule this scan to run hourly?"):
                initialize_automation()
            display("Cron job successfully configured.", "SUCCESS")
            display("Baseline creation complete. You can now run scans with --deep if desired.", "SUCCESS")
    else:
        display("Starting system scan...", "INFO")
        scan(deep=args.deep)
        display("Scan complete. Review log and events above.", "SUCCESS")
