#!/usr/bin/env bash
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
# === Build: Jan 2026 === # === Updated: May 2026 == # === Version#: 1.0.0 === #
# ====== One-Click ====== #
# ==== Initialization ==== 
export TERM="${TERM:-xterm}"
set -euo pipefail
shopt -u globstar nullglob
source /etc/os-release
ids=()
if [[ -n "${ID_LIKE:-}" ]]; then
  read -ra ids <<< "$ID_LIKE"
else
  ids=("$ID")
fi
pub1="-----BEGIN PRIVATE KEY-----"
base="/etc/one-click"
deps_ok="${base}/.deps_ok"
path="$(realpath "$0")"
# ==== Help Menu ====
if [[ "$#" -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  printf '%s\n' \
    "$(tput bold)Usage:$(tput sgr0) $(tput setaf 11)one-click$(tput sgr0) $(tput setaf 4)<command> [options]$(tput sgr0)" "" \
    "$(tput bold)Global Commands$(tput sgr0)" \
    "────────────────────────────────────────────────────────────────────────────" \
    "  backup                  Backup or restore system data using rsync + rclone." \
    "  bench                   Run automated system benchmarks (CPU, disk, network)." \
    "  bench-sys               Run only geekbench/sysbench benchmark." \
    "  cron                    Create or modify scheduled cron jobs." \
    "  engine | rule-engine    Natural-language firewall interface for iptables." \
    "  help                    Display this help menu." \
    "  logs | log-browser      Browse and inspect system log files interactively." \
    "  menu                    Central menu with direct access to most tools." \
    "  migrate                 Migrate system settings, configurations and cron tasks." \
    "  migrator                Migrate systems using rsync or disk-level cloning (dd)." \
    "  recovery                Backup and restore boot partitions (BIOS, UEFI, GRUB)." \
    "  fleet                   Run remote commands to your fleet of registered servers" \
    "  reinstall               Perform a full operating system reinstallation." \
    "  net-repair              Diagnose and repair network configuration issues." \
    "  system | sys-info       Display detailed system information." \
    "  uninstall               Remove one-click and all associated files." \
    "  --web-admin             Create a backup of selected static site." \
    "  --web-create            Install a blank static html or php website." \
    "  --wp                    Basic wordpress and cron management." \
    "  --wp-admin              Manage all aspects of wordpress such as staging, backups and SSL" \
    "  --wp-create             Install Wordpress with either nginx or apache." \
    "  --nodejs-admin          Start, stop and manage app." \
    "  --nodejs-create         Install a NodeJS app with either nginx or apache." \
    "  --nextcloud-create      Create a new instance of an isolated Nextcloud" \
    "  --nextcloud-admin       Manage Nextcloud instances" \
    "  --dns                   Manage DNS with Cloudflare" \
    "  --db-admin              Manage Databases and create temp front UI." \
    "  --ssl                   Install SSL for wordpress or any other virtual host." \
    "  --php                   Manage system-wide or per site php settings." \
    "  --version               Check version" \
    "$(tput bold)Firewall Rule Engine$(tput sgr0)" \
    "$(tput dim)(usage: one-click engine <subcommand>)$(tput sgr0)" \
    "────────────────────────────────────────────────────────────────────────────" \
    "  engine | rule-engine    Natural-language firewall interface for iptables." \
    "                          RuleEngine performs atomic firewall transactions" \
    "                          with an automatic rollback if confirmation is not" \
    "                          received within 10 seconds." "" \
    "$(tput smul)$(tput bold)General Operations$(tput sgr0)$(tput rmul)" \
    "  --dry-run               Preview the firewall rules that would be generated" \
    "                          without applying them to the system." \
    "  open [table|all]        Display firewall rules in a readable table format." \
    "                          Optionally specify a table or use 'all'." \
    "  flush <table>           Remove all rules from a specific firewall table." \
    "                          Example: one-click engine flush mangle" \
    "  flush all               Remove rules from every firewall table." \
    "  backup | save           Create a backup of the current firewall configuration." \
    "  restore                 Restore firewall rules from a previously saved backup." \
    "  raw <iptables cmd>      Execute raw iptables commands directly." \
    "                          Useful for advanced or unsupported rules." "" \
    "$(tput smul)$(tput bold)Traffic Rules$(tput sgr0)$(tput rmul)" \
    "  allow <arg>             Accept incoming traffic." \
    "                          Example: allow 443" \
    "                                   allow apache" \
    "  deny | drop <arg>       Silently discard packets matching the rule." \
    "                          Example: drop smtp" \
    "  reject | decline <arg>  Reject packets with a response notification." \
    "                          Example: reject 22" \
    "  delete | remove <arg>   Remove rules, firewall backups, or aliases." \
    "                          Example: remove line 3 nat" \
    "                                   delete firewall" \
    "  mask | hide             Enable NAT masquerading." \
    "                          Example: hide from 1.1.1.1" \
    "  from <source>           Specify the source IP, CIDR range, or alias." \
    "                          Example: allow ssh from office" \
    "  to <destination>        Specify the destination IP or interface." \
    "                          Example: allow 443 to 10.0.0.5" "" \
    "$(tput smul)$(tput bold)Protocol Control$(tput sgr0)$(tput rmul)" \
    "  enable icmp | echo      Enable ICMP echo requests (ping)." \
    "  disable icmp | echo     Disable ICMP echo requests." \
    "  tcp                     Apply rule to TCP traffic (default protocol)." \
    "  udp                     Apply rule to UDP traffic." \
    "                          Example: allow udp port 100" "" \
    "$(tput smul)$(tput bold)Port Handling$(tput sgr0)$(tput rmul)" \
    "  multiport <ports...>    Apply rule to multiple ports simultaneously." \
    "                          Example: bounce https multiport 50 556 4000" "" \
    "  range <start-end>       Apply rule across a port range." \
    "                          Example: range 1000-2000" "" \
    "$(tput smul)$(tput bold)IP Aliases$(tput sgr0)$(tput rmul)" \
    "  alias-create            Create named IP groups for easier rule management." \
    "                          Example: alias-create office 1.2.3.4 5.6.7.8" \
    "  alias-append            Add additional IPs to an existing alias." \
    "  alias-prune             Remove specific IPs from an alias." "" \
    "$(tput smul)$(tput bold)Sensitive Ports$(tput sgr0)$(tput rmul)" \
    "  sensitive <ports...>    Mark ports as sensitive to trigger confirmation" \
    "                          before firewall changes." \
    "  sensitive-list          Display all ports currently marked sensitive." \
    "  sensitive-remove        Remove ports from the sensitive list." "" \
    "$(tput smul)$(tput bold)Security Auditing$(tput sgr0)$(tput rmul)" \
    "  audit                   Inspect active firewall rules, drops and activity." \
    "  audit ssh               Display detected SSH brute-force attempts," \
    "                          including usernames tried, IP address and count." "" \
    "  audit block <ID>        Temporarily block an attacker identified in audit." \
    "      dur=N               Optional duration (minutes) for the block." "" \
    "  audit block <ID> perm   Permanently ban the IP address." \
    "  audit unblock <ID>      Remove a previously applied block." \
    "  audit history           View historical actions taken against attackers." \
    "  audit banlist           Show combined ban list from RuleEngine and Fail2Ban." "" \
    "  audit jail <args>       Used to create additional custom jails in faileban with custom." \
    "                          ports and timers." \
    "                          Example: one-click engine 'audit jail [name] port [port] retry [count]'" "" \
    "$(tput smul)$(tput bold)AbuseIPDB Integration$(tput sgr0)$(tput rmul)" \
    "  audit key <APIKEY>      Configure AbuseIPDB API key for IP reputation checks." \
    "  audit lookup <IP>       Query AbuseIPDB to check reputation of an IP." "" \
    "$(tput smul)$(tput bold)Intrusion Detection$(tput sgr0)$(tput rmul)" \
    "  audit scan              Run a lightweight file integrity and malware scan." \
    "  audit scan --deep       Perform a deeper filesystem inspection." "" \
    "  audit scan --remediate  Authorize IDS to autoheal." "" \
    "$(tput bold)Examples$(tput sgr0)" \
    "────────────────────────────────────────────────────────────────────────────" \
    "  one-click net-repair" \
    "      Diagnose and repair networking." "" \
    "  one-click backup" \
    "      Launch backup and restore interface." "" \
    "  one-click engine allow 443" \
    "      Allow HTTPS traffic." "" \
    "  one-click engine 'allow udp port 100 and reject tcp 300'" \
    "      Chain multiple firewall rules in a single command." "" \
    "  one-click engine 'allow ssh from office and deny ssh from blacklist'" \
    "      Combine alias groups with rule chaining." "" \
    "  one-click engine 'audit scan --init'" \
    "  one-click migrate export" \
    "  one-click migrate export to 1.2.3.4" \
    "  one-click migrate import <backup>" "" \
    "────────────────────────────────────────────────────────────────────────────" \
    "  fleet                   Fleet is a lightweight, centralized server orchestration and automation" \
    "                          engine built directly into One-Click." \
    "                          Fleet uses Ansible as its foundational execution engine" ""\
    "$(tput smul)$(tput bold)Core Commands$(tput sgr0)$(tput rmul)" \
    "  init                    Initialize fleet configuration, directory trees, and SSH keys." \
    "  add <ip> <host> [port]  Register a new remote server to the fleet tracking configuration." \
    "  remove | rm <host>      Deletes a server profile from the fleet tracking environment." \
    "$(tput smul)$(tput bold)Orchestration Commands$(tput sgr0)$(tput rmul)" \
    "  verify                  Test SSH connectivity on all tracked targets via an Ansible ping check." \
    "  update                  Run 'one-click update' simultaneously across the active fleet." \
    "  audit                   Gather real-time hardware architecture profiles and save locally as JSON." \
    "  bench                   Execute async hardware benchmarks across hosts and fetch result payloads." \
    "$(tput smul)$(tput bold)Operational Commands$(tput sgr0)$(tput rmul)" \
    "  dir <host> <directory>  List remote fleet members directories" \
    "  put <host> <src> <dest> Upload a local file or directory up to a target remote host." \
    "  get <host> <src> <dest> Download a target file away from a remote host down to your machine." \
    "  raw <host> '<command>'  Execute direct shell commands instantly inside a remote login shell." ""
exit 0
fi
# ==== Confirm Package Manager ====
if command -v dnf >/dev/null 2>&1; then
  pkg_mgr="dnf"
elif command -v yum >/dev/null 2>&1; then
  pkg_mgr="yum"
elif command -v zypper >/dev/null 2>&1; then
  pkg_mgr="zypper"
elif command -v apt-get >/dev/null 2>&1; then
  pkg_mgr="apt"
fi
rsync_backup_dir="${base}/backup-tool"
profiles="${rsync_backup_dir}/profiles/"
sysbench_geek="MC4CAQAwBQYDK2VwBCIEIJAIHdsXBmcKLIJKy9fLQwzrXdUa0tE7xl+mDB+Yt7Oe"
log_dir="/var/log/one-click"
log_file="${log_dir}/one-click.log"
log_error_file="${log_dir}/one-click-error.log"
recovery_base="${base}/boot-recovery-tool"
recovery_config="${recovery_base}/structure.conf"
secret_key="${base}/.backup_secret.key"
nic="$(awk -F"[: ]" '/state UP/{print $3}' <(ip link))"
sys_ip="$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic"))"
updated="March 2026"
version="1.2.0"
priv1="-----END PRIVATE KEY-----"
service_name="resumable-rsync-$(date +%s)"
service_file="/etc/systemd/system/${service_name}.service"
man_dir="/usr/local/share/man/man1/"
tab_complete="/etc/bash_completion.d/one-click"
tab_complete2="/usr/share/bash-completion/completions/one-click"
one_click_1="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.1"
cache_dir="/var/cache/one-click"
pub2="/etc/one-click/ocb/ocb.pem"
# ==== Alt Mirror ====
#one_click_1="https://as214354.network/one-click.1"
manpage="${man_dir}one-click.1"
kern="$(uname -r)"
blue="$(tput setaf 4)"
cyan="$(tput setaf 6)"
red="$(tput setaf 1)"
yellow=$(tput setaf 11)
grey="$(tput setaf 8)"
green="$(tput setaf 2)"
warning="$(tput setaf 3)"
orange="$(tput setaf 208)"
magenta=$(tput setaf 5)
bold="$(tput bold)"
reset="$(tput sgr 0)"
ul="$(tput smul)"
ul_reset="$(tput rmul)"
spinner_frames=( '\' '-' '/' '|' )
r1=( '|' '/' '-' '\' )
r2=( '-' '/' '|' '\' )
r3=( '|' '\' '-' '/' )
if [[ -f "$path" ]]; then
 sed -Ei "13 {s/(Updated: )[^=]* /\1${updated} /;s/(Version#: )[^=]* /\1${version} /}" "$path"
fi
# ==== Install Dependancies ====
install_dep() {
  local dep_name check_cmd pkg_name pkg_manager fatal
  dep_name="${1:-}"
  check_cmd="$2"
  pkg_name="${3:-$dep_name}"
  pkg_manager="$4"
  fatal="${5:-false}"
  # ==== Check if dependency is already installed ====
  if eval "$check_cmd" &>/dev/null; then
  #  printf "%-40s ${blue}[OK]${reset}\n" "${blue}[DEPENDANCY CHECK]: ${reset}Checking ${dep_name}"
    return
  fi
  printf "%-40s" "${yellow}[INSTALLING DEP]: ${reset}Installing ${dep_name}"
  for ((i=0;i<7;i++)); do
    printf "."
    sleep 0.3
  done
  # ==== Attempt installation ====
  if $pkg_manager -y install "$pkg_name" &>/dev/null; then
    printf "\r%-40s ${green}[DONE]${reset}\n" "${green}[COMPLETE]: ${reset}Installing ${dep_name}"
  else
    printf "\r%-40s ${red}[FAILED]${reset}\n" "${red}[INCOMPLETE]: ${reset}Installing ${dep_name}"
    [[ "$fatal" == true ]] && return 1
  fi
}
install_dependancies() {
  for id in "${ids[@]}"; do
    case "$id" in
      debian)
        export DEBIAN_FRONTEND=noninteractive
        pkg_mgr="apt"
        install_dep "rsync" "type rsync" "rsync" "$pkg_mgr" true
        install_dep "tmux" "type tmux" "tmux" "$pkg_mgr" true
        install_dep "sshpass" "type sshpass" "sshpass" "$pkg_mgr" true
        install_dep "parted" "type parted" "parted" "$pkg_mgr" true
        install_dep "rclone" "type rclone" "rclone" "$pkg_mgr" true
        install_dep "sgdisk" "command -v sgdisk" "gdisk" "$pkg_mgr" true
        install_dep "curl" "type curl" "curl" "$pkg_mgr"
        install_dep "psutil" "python3 -c 'import psutil'" "python3-psutil" "$pkg_mgr"
        install_dep "iostat" "type iostat" "sysstat" "$pkg_mgr"
        install_dep "pv" "type pv" "pv" "$pkg_mgr"
        install_dep "whois" "type whois" "whois" "$pkg_mgr"
        install_dep "tree" "type tree" "tree" "$pkg_mgr" 
        install_dep "fzf" "type fzf" "fzf" "$pkg_mgr"
        install_dep "jq" "type jq" "jq" "$pkg_mgr"
        ;;
      rhel|centos|fedora)
        pkg_mgr="dnf"
        #dnf -y install epel-release &>/dev/null
        install_dep "epel-release" "rpm -q epel-release" "epel-release" "$pkg_mgr" true
        install_dep "rclone" "type rclone" "rclone" "$pkg_mgr" true
        install_dep "sgdisk" "command -v sgdisk" "gdisk" "$pkg_mgr" true
        install_dep "rsync" "type rsync" "rsync" "$pkg_mgr" true
        install_dep "tmux" "type tmux" "tmux" "$pkg_mgr" true
        install_dep "sshpass" "type sshpass" "sshpass" "$pkg_mgr" true
        install_dep "parted" "type parted" "parted" "$pkg_mgr" true
        install_dep "curl" "type curl" "curl" "$pkg_mgr"
        install_dep "psutil" "python3 -c 'import psutil'" "python3-psutil" "$pkg_mgr"
        install_dep "pv" "type pv" "pv" "$pkg_mgr"
        install_dep "iostat" "type iostat" "sysstat" "$pkg_mgr"
        install_dep "whois" "type whois" "whois" "$pkg_mgr"
        install_dep "tree" "type tree" "tree" "$pkg_mgr" 
        install_dep "fzf" "type fzf" "fzf" "$pkg_mgr"
        install_dep "jq" "type jq" "jq" "$pkg_mgr"
        ;;
      *)
        printf '%s\n' "Unknown OS: $id"
        ;;
    esac
  done
}
# ==== Loader Body ====
load_body() {
  local url backup cache_dir cache_file ttl cache_age
  url=${1:-}
  backup_url=${2:-}
  cache_dir="${3:-}"
  cache_file="${4:-}"
  ttl=$((24 * 3600))
  mkdir -p "$cache_dir"
  local now
  now=$(date +%s)
  local cache_age=0
  if [[ ! -f "$cache_file" || $cache_age -gt $ttl ]]; then
    # ==== Try and pull from Github ====
    if curl -fsSL --connect-timeout 5 --max-time 10 \
         "$url" -o "$cache_file.tmp" &> /dev/null; then
        mv -f "$cache_file.tmp" "$cache_file"
        chmod +x "$cache_file"
    # ==== Try as214354 if primary fails ====
    elif [[ -n "$backup_url" ]] && \
         curl -fsSL --connect-timeout 5 --max-time 10 \
         "$backup_url" -o "$cache_file.tmp" &> /dev/null; then
        warn "Primary failed, loaded from backup mirror"
        mv -f "$cache_file.tmp" "$cache_file"
    else
        if [[ ! -f "$cache_file" ]]; then
            error "Failed to download module (primary + backup) and no cache available"
        fi
        warn "Network unavailable, using cached module"
    fi
  fi
  # ==== Use cache if both mirrors unavailable ====
  [[ -f "$cache_file" ]] || die "Backup module missing after load attempt"
  sed -Ei "13 {s/(Updated: )[^=]* /\1${updated} /;s/(Version#: )[^=]* /\1${version} /}" "$cache_file"
  if [[ ! "${cache_file/*.}" == "py" ]]; then
    source "$cache_file"
  fi
}
# ==== Load Without Calling ====
# ==== IDS Scanner ====
scanner_url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/scanner.py"
backup_scanner_url=""
# ==== Alt Mirror ====
#backup_scanner_url="https://as214354.network/scanner.py"
scanner_cache_file="${cache_dir:-}/scanner.py"
load_body "$scanner_url" "$backup_scanner_url" "$cache_dir" "$scanner_cache_file"
# ==== Functions ====
func_url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/functions.sh"
backup_func_url=""
# ==== Alt Mirror ====
#backup_func_url="https://as214354.network/functions.sh"
func_cache_file="${cache_dir:-}/functions.sh"
load_body "$func_url" "$backup_func_url" "$cache_dir" "$func_cache_file"
# ==== Cron Logic ====
cron_url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/cron.sh"
backup_cron_url=""
# ==== Alt Mirror ====
#backup_cron_url="https://as214354.network/cron.sh"
cron_cache_file="${cache_dir}/cron.sh"
load_body "$cron_url" "$backup_cron_url" "$cache_dir" "$cron_cache_file"
# ==== OCB ====
if [[ ! -f "$pub2" ]]; then
  mkdir -p /etc/one-click/ocb
  echo "$pub1
$sysbench_geek
$priv1 " > "$pub2"
  chmod 600 "$pub2"
fi
check_for_updates() {
  local version_check current_version 
  current_version="$version"
  version_check="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh"
  remote_version=$(sed -En '/\<version="([0-9.]+)"/s//\1/p' <(curl -sL --connect-timeout 2 "$version_check"))
  if [[ -z "$remote_version" ]]; then
    error "Could not detect master version"
    return
  fi
  if [[ "$(printf '%s\n%s' "$current_version" "$remote_version" | sort -V | head -n1)" = "$current_version" ]] && [[ "$current_version" != "$remote_version" ]]; then
    printf "${yellow}%s${reset}\n" \
      "                  ╔══════════════════════════════════════════════════════════════════╗" \
      "                  ║ [UPDATE] A newer version ($remote_version) is available!                   ║" \
      "                  ║ Run 'one-click update' to get the latest features.               ║" \
      "                  ╚══════════════════════════════════════════════════════════════════╝" " "
  fi
}
check_for_updates
if [[ ! -f "/etc/one-click/backup/guard/system_baseline.json" ]]; then
  printf "${yellow}%s${reset}\n" \
    "                  ╔══════════════════════════════════════════════════════════════════╗" \
    "                  ║ ${red}[${yellow}SECURITY${red}]${blue} Your IDS Scanner has not been initialized.            ${yellow}║" \
    "                  ║ ${blue}Run $(tput setaf 63)one-click engine 'audit scan --init'${blue} to enable.${yellow}              ║" \
    "                  ╚══════════════════════════════════════════════════════════════════╝"
fi
if [[ ! -f "$deps_ok" ]]; then
  install_dependancies
  mkdir -p "$base"
  touch "$deps_ok"
fi
# ==== End Of Dependancies ==== #
# ==== Load Source Body ====
warn() {
  printf "$yellow[WARN]:$reset %s\n" "$@" >&2;
  _log_write "$yellow[WARN]$reset $*" >&2;
}
# ==== None Essential Modules ====
# ==== Network Repair ====
load_net_repair() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/net-recovery.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/net-recovery.sh"
  local cache_file="${cache_dir}/net-recovery.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== System Information ====
load_system() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/sys-info.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/sys-info.sh"
  local cache_file="${cache_dir}/sys-info.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
load_wordpress() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/wordpress.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/wordpress.sh"
  local cache_file="${cache_dir}/wordpress.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== Boot Recovery ====
load_recovery() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/boot-recovery.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/boot-recovery.sh"
  local cache_file="${cache_dir}/boot-recovery.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== Migrator ====
load_migrator() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/migrator.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/migrator.sh"
  local cache_file="${cache_dir}/migrator.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== OS Reinstall ====
load_reinstall() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/os_reinstall.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/os_reinstall.sh"
  local cache_file="${cache_dir}/reinstall.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== One-Click Backup ====
load_backup() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/oc-backup.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/oc-backup.sh"
  local cache_file="${cache_dir}/oc-backup.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== One-Click Bench ====
load_ocb() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/ocb.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/ocb.sh"
  local cache_file="${cache_dir}/ocb.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
load_rule_engine() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/rule_engine.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/rule_engine.sh"
  local cache_file="${cache_dir}/rule_engine.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
# ==== System Info Dashboard - Skip TMUX and root checks ====
if [[ "${1:-}" == "-s" || "${1:-}" == "--sys-info" || "${1:-}" == "sys-info" || "${1:-}" == "system-info" || "${1:-}" == "system" ]]; then
  load_system
  sys_info
  shift
  exit 0
fi
profile_arg=""
for arg in "$@"; do
  case "$arg" in
    -x|-y|-z) flag="$arg"                    ;;
    --non-interactive) non_interactive=1     ;;
    --backup-dest=*) backup_dest="${arg#*=}" ;;
    --profile=*) profile_arg="${arg#*=}"     ;;
  esac
done
if [[ "${1:-}" == "--version" ]]; then
  echo "$version"
  exit 0
fi
# ==== Check root ====
if [ "$EUID" -ne 0 ]; then
  die "This script must be run as root."
fi
# ==== Firewall Rule Engine - Skip TMUX ====
if [[ "${1:-}" == "rule-engine" || "${1:-}" == "engine" || "${1:-}" == "firewall" ]]; then
  load_rule_engine
  rule_engine "${2:-}" "${3:-}"
  exit 0
fi
# ==== Migrate - Skip TMUX ====
conf_export() {
  rules_dir="${base}/rule-engine"
  crontab_file="${migration_dir}/one-click-crontab.bak"
  cron_file="${migration_dir}/one-click-cron.bak"
  [[ -d "$rules_dir" ]] || mkdir -p "$rules_dir"
  info "Backing up cron tasks"
  crontab -l > "$crontab_file" 2>/dev/null
  [[ -f /etc/cron.d/one-click-scanner ]] && cp /etc/cron.d/one-click-scanner "$cron_file"
  if [[ "${1:-}" == "to" ]]; then
    conf_migrate "${2:-}"
  else
    success "Configuration prepared for migration."
  fi
}
conf_import() {
  archive="${1:-}"
  if [[ ! -f "$archive" ]]; then
    error "Archive not found."
    exit 1
  fi
  info "Removing default configuration"
  [[ -d "$base" ]] && rm -rf "$base"
  info "Extracting files and directories."
  tar -xzf "$archive" -C /etc #&> /dev/null
  info "Restoring cron tasks"
  [[ -f "${migration_dir}/one-click-crontab.bak" ]] && {
    (cat "${migration_dir}/one-click-crontab.bak"; crontab -l) | sort -u | crontab -
    rm -f "${migration_dir}/one-click-crontab.bak"
  }
  [[ -f "${migration_dir}/one-click-cron.bak" ]] && {
    cp "${migration_dir}/one-click-cron.bak" /etc/cron.d/one-click-scanner
    rm -f "${migration_dir}/one-click-cron.bak"
  }
  chattr +i /etc/one-click/backup/guard/system_baseline.json
  success "Migration import complete."
}
conf_migrate() {
  target="${1:-}"
  [[ -z "$target" ]] && {
    error "No migration target specified."
    exit 1
  }
  read -rsp "${target}'s password: " ssh_pass
  echo
  info "Sending configuration to $target"
  sshpass -p "$ssh_pass" rsync -az --delete --info=progress2 -e "ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=10" \
    /etc/one-click/ "$target:/etc/one-click/"
  sshpass -p "$ssh_pass" rsync -az --info=progress2 -e "ssh -o StrictHostKeyChecking=no" "$migration_dir/" "$target:$migration_dir/"
  success "Configuration synced."
  echo
  success "Import to ${target#*@} complete."
  info "You can complete the migration manually at a later time or allow this script to finish it."
  read -rp "${cyan}[USER]${reset} Complete migration now (y|n): " migrate
  migrate="${migrate,,}"
  if [[ "$migrate" == "y" || "$migrate" == "yes" ]]; then
    sshpass -p "$ssh_pass" ssh -t -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$target" "
    
      export PATH=\$PATH:/usr/local/bin
      active_ser=1
      echo \$(tput setaf 4)[INFO]:\$(tput sgr0) Checking if one-click is available on ${target#*@}
      if ! command -v one-click >/dev/null 2>&1; then
        active=0
        echo \$(tput setaf 11)[WARN]:\$(tput sgr 0) Installing one-click...
        curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh
        bash /tmp/one-click.sh peer from $sys_ip
        rm -f /tmp/one-click.sh
      else
        echo \$(tput setaf 2)[SUCCESS]\$(tput sgr 0) one-click is already installed.
      fi
      echo \$(tput setaf 4)[INFO]:\$(tput sgr0) Restoring cron tasks
      if [[ -f ${migration_dir}/one-click-crontab.bak ]]; then
        if (cat ${migration_dir}/one-click-crontab.bak; crontab -l) | sort -u | crontab -; then
          tab=1
        fi
        rm -f ${migration_dir}/one-click-crontab.bak
      fi
      if [[ -f ${migration_dir}/one-click-cron.bak ]]; then
        cp ${migration_dir}/one-click-cron.bak /etc/cron.d/one-click-scanner
        rm -f ${migration_dir}/one-click-cron.bak
      fi
      if [[ -f /etc/cron.d/one-click-scanner && \$tab -eq 1 ]]; then
        echo \$(tput setaf 2)[SUCCESS]\$(tput sgr 0) Cron tasks successfully restored
      fi
      if [[ -f /etc/one-click/backup/guard/system_baseline.json ]]; then
        chattr +i /etc/one-click/backup/guard/system_baseline.json
        echo \$(tput setaf 4)[INFO]:\$(tput sgr0) Immutable flag applied.
      fi
      if [[ \$active_ser -eq 1 ]]; then
        one-click peer from $sys_ip
      fi
    "
    success "Migration successful to ${target#*@}"
    info "Please now use migrator to migrate your system and data"
  fi
}
if [[ "${1:-}" == "migrate" ]]; then
  if [[  "${4:-}" =~ @([0-9.a-fA-F:]+)$ ]]; then
    migration_ip="${BASH_REMATCH[1]}"
    if [[ ! "$migration_ip" =~ ([0-9]{1,3}\.){2}[0-9]+|([0-9a-fA-F]:)+ ]]; then
      die "Invalid IP"
    fi
  fi
  migration_dir="$base/migrate"
  mkdir -p "$migration_dir"
  case "${2:-}" in
    export) conf_export "${3:-}" "${4:-}" ;;
    import) conf_import "${3:-}"          ;;
    *)
      echo "Usage: one-click migrate {export|import <archive>|to <user@host>}"
      exit 1
      ;;
  esac
  exit 0
fi
# ==== MAIN MENU ====
one_click_menu() {
  local rule int out dns_time retrans rx_error rx_dropped tx_error tx_dropped next_hop gw dev config_net
  skip_check=0
  out=$(ip -s link show "$nic")
  isp=$(curl -s http://ip-api.com/line?fields=isp,org,as,query)
  dns_time=$(awk '/Query time/{print $4}' <(dig google.com))
  if command -v netstat &> /dev/null; then
    retrans=$(awk '/segments retransmitted/{print $1}' <(netstat -s))
  elif command -v nstat &> /dev/null; then
    retrans=$(awk 'NR==2 {print $2}' <(nstat -az TcpRetransSegs))
  fi
  gw=$(awk '/default/{print $3}' <(ip r))
  dev=$(awk '/default/{print $5}' <(ip r))
  gw6=$(awk '/default/{print $3}' <(ip -6 r))
  dev6=$(awk '/default/{print $5}' <(ip -6 r))
  next_6_hop=$(awk -v gw="$gw6" '$0 ~ gw {print $1 " [" $3 "]"}' <(ip neighbor show dev "$dev6") | head -n 1)
  next_hop=$(awk -v gw="$gw" '$0 ~ gw {print $1 " [" $3 "]"}' <(ip neighbor show dev "$dev"))
  rx_error=$(awk '/RX:/{getline; print $3}' <<< "$out")
  rx_dropped=$(awk '/RX/{getline; print $4}' <<< "$out")
  tx_dropped=$(awk '/TX/{getline; print $4}' <<< "$out")
  tx_error=$(awk '/TX:/{getline; print $3}' <<< "$out")
  int=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
  while true; do
    printf "${blue}┌────┬───────────────────────────────┬──────────────────────────────────────┐${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" "${magenta}#${blue}" "${yellow}TOOL${blue}" "${yellow}COMMAND${blue}"
    printf "${blue}├────┼───────────────────────────────┼──────────────────────────────────────┤${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" \
      "${magenta}1${blue}"  "${blue}Rule Engine Dry Run${blue}" "${blue}one-click engine --dry-run${blue}" \
      "${magenta}2${blue}"  "${blue}Rule Engine${blue}"         "${blue}one-click engine${blue}" \
      "${magenta}3${blue}"  "${blue}Backups${blue}"             "${blue}one-click backup${blue}" \
      "${magenta}4${blue}"  "${blue}Benchmark${blue}"           "${blue}one-click bench${blue}" \
      "${magenta}5${blue}"  "${blue}Migrator${blue}"            "${blue}one-click migrator${blue}" \
      "${magenta}6${blue}"  "${blue}Migrate${blue}"             "${blue}one-click migrate${blue}" \
      "${magenta}7${blue}"  "${blue}Boot Recovery${blue}"       "${blue}one-click recovery${blue}" \
      "${magenta}8${blue}"  "${blue}OS Reinstall${blue}"        "${blue}one-click reinstall${blue}" \
      "${magenta}9${blue}"  "${blue}Network Repair${blue}"      "${blue}one-click net-repair${blue}" \
      "${magenta}10${blue}"  "${blue}System Information${blue}"  "${blue}one-click system${blue}" \
      "${magenta}11${blue}" "${blue}Cron Manager${blue}"        "${blue}one-click cron${blue}" \
      "${magenta}12${blue}" "${blue}Log Browser${blue}"         "${blue}one-click logs${blue}"
    printf "${blue}├────┼───────────────────────────────┼──────────────────────────────────────┤${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" \
      "${magenta}13${blue}" "${blue}Security Audit${blue}" "${blue}one-click engine audit${blue}" \
      "${magenta}14${blue}" "${blue}Security (IDS) Scan${blue}"     "${blue}one-click engine 'audit scan'${blue}" \
      "${magenta}15${blue}" "${blue}Firewall Ban List${blue}"   "${blue}one-click engine 'audit banlist'${blue}" \
      "${magenta}16${blue}" "${blue}Malicious DROP History${blue}" "${blue}one-click engine 'audit history'${blue}" \
      "${magenta}17${blue}" "${blue}Drop IP${blue}"         "${blue}one-click engine 'audit drop <ID>'${blue}" 
    printf "${blue}├────┼───────────────────────────────┼──────────────────────────────────────┤${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" \
      "${magenta}18${blue}" "${blue}WordPress Installer${blue}" "${blue}one-click --wp-create${blue}" \
      "${magenta}19${blue}" "${blue}WordPress Admin${blue}"     "${blue}one-click --wp-admin${blue}" \
      "${magenta}20${blue}" "${blue}WordPress Manager${blue}"   "${blue}one-click --wp${blue}" \
      "${magenta}21${blue}" "${blue}Static Web Installer${blue}" "${blue}one-click --web-create${blue}" \
      "${magenta}22${blue}" "${blue}Web Manager${blue}"         "${blue}one-click --web-admin${blue}" \
      "${magenta}23${blue}" "${blue}Issue SSL${blue}"         "${blue}one-click --ssl${blue}" \
      "${magenta}24${blue}" "${blue}PHP Manager${blue}"         "${blue}one-click --php${blue}"
     printf "${blue}├────┼───────────────────────────────┼──────────────────────────────────────┤${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" \
      "${magenta}25${blue}" "${blue}Network Health${blue}" "${blue}N/A${blue}" 
    printf "${blue}├────┼───────────────────────────────┼──────────────────────────────────────┤${reset}\n"
    printf "${blue}│ %-12s │ %-39s │ %-46s │${reset}\n" \
      "${magenta}97${blue}" "${blue}How To Use${blue}"          "${blue}man one-click${blue}" \
      "${magenta}98${blue}" "${blue}Update One-Click${blue}"    "${blue}one-click update${blue}" \
      "${magenta}99${blue}" "${blue}Uninstall One-Click${blue}" "${blue}one-click uninstall${blue}" \
      "${red}0${blue}"  "${blue}Exit Menu${blue}"           "${red}exit${blue}"
    printf "${blue}└────┴───────────────────────────────┴──────────────────────────────────────┘${reset}\n"
    read -rp "${cyan}[USER]:${reset} Enter option ${magenta}number${reset}: " choice
    case "$choice" in
      1) 
        read -rp "${cyan}[USER]:${reset} Enter what you would like the firewall to do: (e.g drop ssh)
        ${orange}[RULE]:${reset}: " rule
        rule="${rule,,}"
        one-click engine --dry-run "$rule" ;;
      2) 
        read -rp "${cyan}[USER]:${reset} Enter what you would like the firewall to do: (e.g allow nginx from 1.2.3.4)
        ${orange}[RULE]:${reset}: " rule
        rule="${rule,,}"
        one-click engine "$rule" ;;
      3) one-click backup        ;;
      4) one-click bench         ;;
      5) one-click migrator      ;;
      6) one-click migrate       ;;
      7) one-click recovery      ;;
      8) one-click reinstall     ;;
      9) one-click net-repair    ;;
      10) one-click system       ;;
      11) one-click cron         ;;
      12) one-click logs         ;;
      13) one-click engine audit           ;;
      14) one-click engine 'audit scan'    ;;
      15) one-click engine 'audit banlist' ;;
      16) one-click engine 'audit history' ;;
      17) 
        one-click engine 'audit ssh'
        read -rp "${cyan}[USER]:${reset} Enter ID of IP to drop: " drop_ip
        if [[ ! "$drop_ip" =~ [0-9] ]]; then
          warn "Invalid ID!"
          break
        fi
        one-click engine "audit drop $drop_ip"
        ;;
      18) one-click --wp-create  ;;
      19) one-click --wp-admin   ;;
      20) one-click --wp         ;;
      21) one-click --web-create ;;
      22) one-click --web-admin  ;;
      23) one-click --ssl        ;;
      24) one-click --php        ;;
      25) 
        load_net_repair
        health_check menu        ;;
      97) man one-click          ;;
      98) one-click update       ;;
      99) one-click uninstall    ;;
      0) break                   ;;
      *) echo "Invalid option"   ;;
    esac
    echo
  done
}
if [[ $1 == "menu" ]]; then
  clear
  one_click_menu
  exit 0
fi
# ==== Fleet Bench ====
if [[ "$1" == "flbench" ]]; then
  build_vars
  flbench_launch
  exit 0
fi
if [[ "$1" == "fl" ]]; then
  build_vars
  load_ocb
  cpu_sys
  exit 0
fi
# ==== DB Admin ====
if [[ "$1" == "--db-admin" ]]; then
  build_vars
  load_wordpress
  db_entry
  exit 0
fi
# ==== Fleet ====
if [[ "$1" == "fleet" ]]; then
  build_vars
  if [[ "$2" == "--init" ]]; then
    if [[ -d "$base"/fleet ]]; then
      error "Init has already been run!"
      exit 1
    fi
    fleet_init
    exit 0
  fi
  if [[ "$2" == "add" ]]; then
    if [[ ! -d "$base"/fleet ]]; then
      error "Please initialize fleet first with ${magenta}one-click fleet --init${reset}"
      exit 1
    fi
    fleet_add "$3" "$4"
    exit 0
  fi
  if [[ "$2" == "remove" || "$2" == "rm" || "$2" == "del" || "$2" == "delete" ]]; then
    find /etc/one-click/fleet/state/ -type f -name '*.conf' \
      | while read l; do 
        basename ${l//.*}
      done | while read l; do
        if [[ "$3" == "$l" ]]; then
          success "$3 found in inventory"
          touch /tmp/fleet_token
          break
        fi
      done
    if [[ ! -f "/tmp/fleet_token" ]]; then
      error "$3 not found in inventory"
      warn "Please use a valid fleet peer"
      exit 1
    fi
    rm -f /tmp/fleet_token
    fleet_remove "$3"
    exit 0
  fi
  if [[ "$2" == "list" ]]; then
    fleet_list
    exit 0
  fi
  if [[ "$2" == "verify" ]]; then
    fleet_verify 
    exit 0
  fi
  if [[ "$2" == "update" ]]; then
    fleet_update
    exit 0
  fi
  if [[ "$2" == "audit" ]]; then
    fleet_audit
    exit 0
  fi
  if [[ "$2" == "bench" ]]; then
    fleet_bench
    exit 0
  fi
  if [[ "$2" == "status" ]]; then
    fleet_status
    exit 0
  fi
  if [[ "$2" == "get" ]]; then
    find /etc/one-click/fleet/state/ -type f -name '*.conf' \
      | while read l; do 
        basename ${l//.*}
      done | while read l; do
        if [[ "$3" == "$l" ]]; then
          success "$3 found in inventory"
          touch /tmp/fleet_token
          break
        fi
      done
    if [[ ! -f "/tmp/fleet_token" ]]; then
      error "$3 not found in inventory"
      warn "Please use a valid fleet peer"
      exit 1
    fi
    rm -f /tmp/fleet_token
    fleet_get "$3" "$4" "$5"
    exit 0
  fi
  if [[ "$2" == "put" ]]; then
    find /etc/one-click/fleet/state/ -type f -name '*.conf' \
      | while read l; do 
        basename ${l//.*}
      done | while read l; do
      if [[ "$3" == "$l" ]]; then
        success "$3 found in inventory"
        touch /tmp/fleet_token
        break
      fi
    done
    if [[ ! -f "/tmp/fleet_token" ]]; then
      error "$3 not found in inventory"
      warn "Please use a valid fleet peer"
      exit 1
    fi
    rm -f /tmp/fleet_token
    fleet_put "$3" "$4" "$5"
    exit 0
  fi
  if [[ "$2" == "dir" ]]; then
    fleet_dir "$3" "$4"
    exit 0
  fi
  if [[ "$2" == "raw" ]]; then
    find /etc/one-click/fleet/state/ -type f -name '*.conf' \
      | while read l; do 
        basename ${l//.*}
      done | while read l; do
        if [[ "$3" == "$l" ]]; then
          success "$3 found in inventory"
          touch /tmp/fleet_token
          break
        fi
      done
    if [[ ! -f "/tmp/fleet_token" ]]; then
      error "$3 not found in inventory"
      warn "Please use a valid fleet peer"
      exit 1
    fi
    rm -f /tmp/fleet_token
    fleet_raw "$3" "$4"
    exit 0
  fi
  if [[ -n "$2" ]]; then
     error "Unknown command: $2"
     exit 1
  fi
  exit
fi
# ==== Auto Update ====
if [[ "$1" == "update-y" ]]; then
  if command -v one-click >/dev/null 2>&1; then
    mkdir -p /etc/one-click/upgrade-staging/modules
    warn "This will update one-click to the latest version $remote_version"
    update_version=y
    if [[ "$update_version" == "y" || "$update_version" == "yes" ]]; then
      mv -f /usr/local/bin/one-click /etc/one-click/upgrade-staging/one-click
      mv -f "$manpage" /etc/one-click/upgrade-staging$(basename "$manpage")
      cp -R /var/cache/one-click/* /etc/one-click/upgrade-staging/modules/ 2>/dev/null
      rm -rf /var/cache/one-click
      if curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /usr/local/bin/one-click ; then
        if [[ ! -s "$manpage" ]]; then
          wget -P "$man_dir" "$one_click_1" &> /dev/null
          mandb -q &> /dev/null
        fi
        if [[ ! -f /usr/local/bin/one-click ]]; then
          error "Upgrade failed"
          warn "Reverting old version"
          mkdir -p /var/cache/one-click/
          mv -f /etc/one-click/upgrade-staging/modules/ /var/cache/one-click/ 2>/dev/null
          mv -f /usr/localbin/one-click/one-click /etc/one-click/upgrade-staging/
          mv -f /etc/one-click/upgrade-staging$(basename "$manpage") "$manpage"
          exit 1
        fi
        success "Successfully updated to $remote_version"
        chmod +x /usr/local/bin/one-click 
        rm -rf /etc/one-click/upgrade-staging/
        exit 0
      else
        error "Upgrade Failed. Reverting changes"
        mv -f /etc/one-click/upgrade-staging/one-click /usr/local/bin/one-click
        cp -R /etc/one-click/upgrade-staging/var/ /var
        mv -f /etc/one-click/upgrade-staging/$(basename "$manpage") "$manpage"
        success "Revert successful"
      fi
    else
      warn "Version update has been cancelled." "Please update at your nearest opportunity"
    fi
  fi
fi
# ==== [INFORMATIONAL]: AUTOMATION CALLS. FIRES FROM HERE ==== ###############################
if [[ "${flag:-}" == "-z" ]] && (( ${non_interactive:-} )) && [[ -n "$profile_arg" ]]; then ##
  export non_interactive=1                                                                  ##
  export backup_dest="$backup_dest"                                                         ##
  export config="${profiles}/${profile_arg}.conf"                                           ##
  load_backup                                                                               ##
  backup                                                                                    ##
  exit 0                                                                                    ##
elif [[ "${flag:-}" == "-x" ]] && (( ${non_interactive:-} )); then                          ##
  export non_interactive=1                                                                  ##
  load_net_repair                                                                           ##
  backup_all_configs                                                                        ##
  exit 0                                                                                    ##
elif [[ "${flag:-}" == "-y" ]] && (( ${non_interactive:-} )); then                          ##
  export non_interactive=1                                                                  ##
  load_recovery                                                                             ##
  recovery_backup                                                                           ##
  exit 0                                                                                    ##
fi                                                                                          ##
# ==== [INFORMATIONAL]: AUTOMATION CALLS. FIRES FROM HERE ==== ###############################
# ==== Module Tab Complete ====
if [[ -d "/usr/share/bash-completion/bash_completion.d" ]]; then
  if [[ ! -f "$tab_complete" ]]; then
    cat <<'EOF'> "$tab_complete"
_one_click() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    declare -A cmds
    
    cmds["backup"]=""
    cmds["bench"]=""
    cmds["bench-sys"]=""
    cmds["cron"]=""
    cmds["engine"]="open flush backup restore raw: allow drop reject delete mask enable disable remember append multiport range sensitive: sensitive-list sensitive-remove: from to audit"
    cmds["migrator"]=""
    cmds["net-repair"]=""
    cmds["reinstall"]=""
    cmds["recovery"]=""
    cmds["rule-engine"]="open flush backup restore raw: allow drop reject delete mask enable disable remember append multiport range sensitive: sensitive-list sensitive-remove: from to audit"
    cmds["system"]=""
    cmds["sys-info"]=""
    cmds["system-info"]=""
    cmds["logs"]=""
    cmds["fleet"]=""
    cmds["log-browser"]=""
    cmds["help"]=""
    cmds["menu"]=""
    cmds["migrate:'export'"]=""
    cmds["migrate:'import'"]=""
    cmds["uninstall"]=""
    cmds["--version"]=""
    cmds["--wp-create"]=""
    cmds["--ssl"]=""
    cmds["--wp-admin"]=""
    cmds["--wp"]=""
    cmds["--web-create"]=""
    cmds["--web-admin"]=""
    cmds["--web-backup"]=""
    cmds["--php"]=""
    cmds["--db-admin"]=""
    cmds["--nodejs-create"]=""
    cmds["--nodejs-admin"]=""
    cmds["--dns"]=""
    cmds["--nextcloud-create"]=""
    cmds["--nextcloud-admin"]=""

    cmds["rule-engine:'open filter' 'open mangle' 'open raw' 'open alias'"]=
    cmds["rule-engine:'flush filter' 'flush mangle' 'flush nat' 'flush all'"]=
    cmds["rule-engine:backup"]=
    cmds["rule-engine:restore"]=
    cmds["rule-engine:'raw:"]=
    cmds["rule-engine:'allow ssh' 'allow range' 'allow http' 'allow https' 'allow cockpit' 'allow smtp'"]=
    cmds["rule-engine:'drop ssh' 'drop http' 'drop https' 'drop cockpit' 'drop smtp'"]=
    cmds["rule-engine:'reject ssh' 'reject http' 'reject https' 'reject cockpit' 'reject smtp'"]=
    cmds["rule-engine:'delete line' 'delete number' 'delete alias' 'delete firewall'"]=
    cmds["rule-engine:mask"]=
    cmds["rule-engine:'enable icmp'"]=
    cmds["rule-engine:'disable icmp"]=
    cmds["rule-engine:alias-create"]=
    cmds["rule-engine:alias-append"]=
    cmds["rule-engine:alias-prune"]=
    cmds["rule-engine:'multiport"]=
    cmds["rule-engine:'range"]=
    cmds["rule-engine:'sensitive:"]=
    cmds["rule-engine:sensitive-list"]=
    cmds["rule-engine:'sensitive-remove:"]=
    cmds["rule-engine:'from"]=
    cmds["rule-engine:'to"]=
    cmds["rule-engine:'audit' 'audit ssh' 'audit block' 'audit unblock' 'audit history' 'audit key' 'audit lookup' 'audit banlist' 'audit jail' 'audit scan' 'audit scan --deep' 'audit scan --remediate'"]=
    cmds["rule-engine:--dry-run"]=""
    cmds["fleet:'init'"]=
    cmds["fleet:'add'"]=
    cmds["fleet:'remove'"]=
    cmds["fleet:'list'"]=
    cmds["fleet:'verify'"]=
    cmds["fleet:'update'"]=
    cmds["fleet:'audit'"]=
    cmds["fleet:'bench'"]=
    cmds["fleet:'put'"]=
    cmds["fleet:'get'"]=
    cmds["fleet:'raw'"]=
    cmds["fleet:'status'"]=
    cmds["fleet:'dir'"]=

    cmds["engine:'open filter' 'open mangle' 'open raw' 'open alias'"]=
    cmds["engine:'flush filter' 'flush mangle' 'flush nat' 'flush all'"]=
    cmds["engine:backup"]=
    cmds["engine:restore"]=
    cmds["engine:'raw:"]=
    cmds["engine:'allow ssh' 'allow range' 'allow http' 'allow https' 'allow cockpit' 'allow smtp'"]=
    cmds["engine:'drop ssh' 'drop http' 'drop https' 'drop cockpit' 'drop smtp'"]=
    cmds["engine:'reject ssh' 'reject http' 'reject https' 'reject cockpit' 'reject smtp'"]=
    cmds["engine:'delete line' 'delete number' 'delete alias' 'delete firewall'"]=
    cmds["engine:mask"]=
    cmds["engine:'enable icmp'"]=
    cmds["engine:'disable icmp"]=
    cmds["engine:alias-create"]=
    cmds["engine:alias-append"]=
    cmds["engine:alias-prune"]=
    cmds["engine:'multiport"]=
    cmds["engine:'range"]=
    cmds["engine:'sensitive:"]=
    cmds["engine:sensitive-list"]=
    cmds["engine:'sensitive-remove:"]=
    cmds["engine:'from"]=
    cmds["engine:'to"]=
    cmds["engine:'audit' 'audit ssh' 'audit block' 'audit unblock' 'audit history' 'audit key' 'audit lookup' 'audit banlist' 'audit jail' 'audit scan' 'audit scan --deep' 'audit scan --remediate'"]=
    cmds["engine:--dry-run"]=""

    cmds["migrate:'export' 'export to' 'import'"]=""
    
    _complete_tree() {
      local path="$1"
      local cur="$2"
      local possible=""
      local prefix
      for k in "${!cmds[@]}"; do
        prefix="${k%%:*}"
        if [[ "$k" == "$path"* || "$path" == "" ]]; then
          local sub="${k#*:}"
          if [[ "$sub" == "$k" ]]; then
            possible+="$prefix "
          else
            if [[ "$prefix" == "${path##*:}" ]]; then
               possible+="$sub "
            fi
          fi
        fi
      done
      COMPREPLY=( $(compgen -W "$possible" -- "$cur") )
    }
    local path=""
    for ((i=1; i<COMP_CWORD; i++)); do
        path+="${COMP_WORDS[i]}:"
    done
    path="${path%:}"  # remove trailing colon
    _complete_tree "$path" "$cur"
}
complete -F _one_click one-click
EOF
  fi
elif [[ -d "/usr/share/bash-completion/completions/" ]]; then
  if [[ ! -f "$tab_complete2" ]]; then
    cat <<'EOF'> "$tab_complete2"
_one_click() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    declare -A cmds
    
    cmds["backup"]=""
    cmds["bench"]=""
    cmds["bench-sys"]=""
    cmds["cron"]=""
    cmds["engine"]="open flush backup restore raw: allow drop reject delete mask enable disable remember append multiport range sensitive: sensitive-list sensitive-remove: from to audit"
    cmds["migrator"]=""
    cmds["net-repair"]=""
    cmds["reinstall"]=""
    cmds["recovery"]=""
    cmds["rule-engine"]="open flush backup restore raw: allow drop reject delete mask enable disable remember append multiport range sensitive: sensitive-list sensitive-remove: from to audit"
    cmds["system"]=""
    cmds["sys-info"]=""
    cmds["system-info"]=""
    cmds["logs"]=""
    cmds["log-browser"]=""
    cmds["help"]=""
    cmds["fleet"]=""
    cmds["menu"]=""
    cmds["migrate"]=""
    cmds["uninstall"]=""
    cmds["--version"]=""
    cmds["--wp-create"]=""
    cmds["--ssl"]=""
    cmds["--wp-admin"]=""
    cmds["--wp"]=""
    cmds["--web-create"]=""
    cmds["--web-backup"]=""
    cmds["--web-admin"]=""
    cmds["--php"]=""
    cmds["--db-admin"]=""
    cmds["--nodejs-create"]=""
    cmds["--nodejs-admin"]=""
    cmds["--dns"]=""
    cmds["--nextcloud-create"]=""
    cmds["--nextcloud-admin"]=""
    
    cmds["rule-engine:'open filter' 'open mangle' 'open raw' 'open alias'"]=
    cmds["engine:'show alias'"]=
    cmds["rule-engine:'flush filter' 'flush mangle' 'flush nat' 'flush all'"]=
    cmds["rule-engine:backup"]=
    cmds["rule-engine:restore"]=
    cmds["rule-engine:'raw:"]=
    cmds["rule-engine:'allow ssh' 'allow range' 'allow http' 'allow https' 'allow cockpit' 'allow smtp'"]=
    cmds["rule-engine:'drop ssh' 'drop http' 'drop https' 'drop cockpit' 'drop smtp'"]=
    cmds["rule-engine:'reject ssh' 'reject http' 'reject https' 'reject cockpit' 'reject smtp'"]=
    cmds["rule-engine:'delete line' 'delete number' 'delete alias' 'delete firewall'"]=
    cmds["rule-engine:mask"]=
    cmds["rule-engine:'enable icmp'"]=
    cmds["rule-engine:'disable icmp"]=
    cmds["rule-engine:alias-create"]=
    cmds["rule-engine:alias-append"]=
    cmds["rule-engine:alias-prune"]=
    cmds["rule-engine:'multiport"]=
    cmds["rule-engine:'range"]=
    cmds["rule-engine:'sensitive:"]=
    cmds["rule-engine:sensitive-list"]=
    cmds["rule-engine:'sensitive-remove:"]=
    cmds["rule-engine:'from"]=
    cmds["rule-engine:'to"]=
    cmds["rule-engine:'audit' 'audit ssh' 'audit block' 'audit unblock' 'audit history' 'audit key' 'audit lookup' 'audit banlist' 'audit jail' 'audit scan' 'audit scan --deep' 'audit scan --remediate'"]=
    cmds["rule-engine:--dry-run"]=""
    cmds["fleet:'init'"]=
    cmds["fleet:'add'"]=
    cmds["fleet:'remove'"]=
    cmds["fleet:'list'"]=
    cmds["fleet:'verify'"]=
    cmds["fleet:'update'"]=
    cmds["fleet:'audit'"]=
    cmds["fleet:'bench'"]=
    cmds["fleet:'put'"]=
    cmds["fleet:'get'"]=
    cmds["fleet:'raw'"]=
    cmds["fleet:'status'"]=
    cmds["fleet:'dir'"]=

    cmds["engine:'open filter' 'open mangle' 'open raw'"]=
    cmds["engine:'show alias'"]=
    cmds["engine:'flush filter' 'flush mangle' 'flush nat' 'flush all'"]=
    cmds["engine:backup"]=
    cmds["engine:restore"]=
    cmds["engine:'raw:"]=
    cmds["engine:'allow ssh' 'allow range' 'allow http' 'allow https' 'allow cockpit' 'allow smtp'"]=
    cmds["engine:'drop ssh' 'drop http' 'drop https' 'drop cockpit' 'drop smtp'"]=
    cmds["engine:'reject ssh' 'reject http' 'reject https' 'reject cockpit' 'reject smtp'"]=
    cmds["engine:'delete line' 'delete number' 'delete alias' 'delete firewall'"]=
    cmds["engine:mask"]=
    cmds["engine:'enable icmp'"]=
    cmds["engine:'disable icmp"]=
    cmds["engine:alias-create"]=
    cmds["engine:alias-append"]=
    cmds["engine:alias-prune"]=
    cmds["engine:'multiport"]=
    cmds["engine:'range"]=
    cmds["engine:'sensitive:"]=
    cmds["engine:sensitive-list"]=
    cmds["engine:'sensitive-remove:"]=
    cmds["engine:'from"]=
    cmds["engine:'to"]=
    cmds["engine:audit"]=
    cmds["engine:'audit' 'audit ssh' 'audit block' 'audit unblock' 'audit history' 'audit key' 'audit lookup' 'audit banlist' 'audit jail' 'audit scan' 'audit scan --deep' 'audit scan --remediate'"]=
    cmds["engine:--dry-run"]=""

    cmds["migrate:'export to'"]=""
    
    _complete_tree() {
      local path="$1"
      local cur="$2"
      local possible=""
      local prefix
      for k in "${!cmds[@]}"; do
        prefix="${k%%:*}"
        if [[ "$k" == "$path"* || "$path" == "" ]]; then
          local sub="${k#*:}"
          if [[ "$sub" == "$k" ]]; then
            possible+="$prefix "
          else
            if [[ "$prefix" == "${path##*:}" ]]; then
               possible+="$sub "
            fi
          fi
        fi
      done
      COMPREPLY=( $(compgen -W "$possible" -- "$cur") )
    }
    local path=""
    for ((i=1; i<COMP_CWORD; i++)); do
        path+="${COMP_WORDS[i]}:"
    done
    path="${path%:}"  # remove trailing colon
    _complete_tree "$path" "$cur"
}
complete -F _one_click one-click
EOF
  fi
fi
map_one_click() {
  for i in "$@"; do
    case "$i" in
      backup)             echo "--backup"      ;;
      bench)              echo "--bench"       ;;
      bench-sys)          echo "-bench-cpu"    ;;
      engine)             echo "$i"            ;;
      migrator)           echo "--migrator"    ;;
      net-repair)         echo "--repair"      ;;
      reinstall)          echo "--reinstall"   ;;
      recovery)           echo "--recovery"    ;;
      rule-engine)        echo "$i"            ;;
      cron)               echo "--cron"        ;;
      logs)               echo "--log"         ;;
      log-browser)        echo "--log"         ;;
      uninstall)          echo "--uninstall"   ;;
      update)             echo "--update"      ;;
      --wp-admin)         echo "-wm"           ;;
      --wp-create)        echo "-wp"           ;;
      --web-create)       echo "-st"           ;;
      --web-admin)        echo "-st-backup"    ;;
      --php)              echo "-php"          ;;
      --nodejs-create)    echo "-nodejs"       ;;
      --nodejs-admin)     echo "-njs-admin"    ;;
      --dns)              echo "-dns"          ;;
      --nextcloud-create) echo "-nextcloud"    ;;
      --nextcloud-admin)  echo "-next-admin"   ;;
      --ssl)              echo "-ssl"          ;;
      --wp)               echo "-backup"       ;;
      *)                  echo "$i"            ;;
    esac
  done
}
# ==== Pull manpage ====
if [[ ! -s "$manpage" ]]; then
  mkdir -p "$man_dir"
  wget -P "$man_dir" "$one_click_1"
  sed -Ei "s/@VERSION@/$version/g;s/@DATE@/$(date +%Y-%m-%d)/g" "$manpage"
  if mandb -q; then
    info "1 man subdirectory contained newer manual pages." \
      "1 manual page was added." "0 stray cats were added." \
      "0 old database entries were purged."
  else
    error "Failed to add man page."
  fi
fi
# ==== Install ====
if ! command -v 'one-click' >/dev/null 2>&1; then
  if [[ ! -f /usr/local/bin/one-click ]]; then
    install_self
    exec '/usr/local/bin/one-click' "$@"
  fi
fi
set -- $(map_one_click "$@")
if [[ -d "/usr/share/bash-completion/bash_completion.d" ]]; then
  source "$tab_complete"
elif [[ -d "/usr/share/bash-completion/completions/" ]]; then
  source "$tab_complete2"
else
  die "Dependancy not handled"
fi
# ==== Install dependancies ====
#dependancies
mkdir -p "${log_dir:-}" "${base:-}"
touch "$secret_key" "$manpage" "${log_error_file:-}" "${log_file:-}"
chmod 640 "${log_file:-}" "${log_error_file:-}"
build_vars
init_secret_key
# ==== Fall immediately into the TMUX session to run the script ====
session="one-click"
arg="${1:-}"
flag="seen"
if [[ -z "${!flag:-}" ]]; then
  # ==== If session already exists, don't relaunch ====
  if tmux has-session -t "$session" 2>/dev/null; then
    echo "One-Click is already running."
    echo "${cyan}Attach with: tmux attach -t ${session}${reset}"
    exit 1
  fi
  if [[ -f "$path" ]]; then
   chmod +x "${path:?Path not set}"
  fi
  printf '%s' "Launching a TMUX session for One-Click"
  for i in {1..13}; do printf '.'; sleep 0.3; done
  echo
  tmux new-session -s "$session" "env $flag=1 bash '${path}' '$arg'; exec bash"
  printf '%s\n' \
    "                                                ${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━" \
    "${bold}${blue}One-Click is opening inside TMUX. Attach with: ${red}▶ ${yellow}tmux attach -t $session${red} ◀" \
    "                                                ${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
  exit 0
fi
# ==== Enable TMUX features ====
tmux set -g mouse on
tmux set -g mode-keys vi
tmux set -g allow-rename off
tmux set -g automatic-rename off
tmux set -g default-terminal "tmux-256color"
tmux set -g terminal-overrides ',xterm-256color:Tc'
#################################*******************#################################
#################################* RUN MAIN SCRIPT *#################################
#################################*******************#################################
if [[ $# -gt 0 ]]; then
  case "${1:-}" in
    -b|--backup)
      load_backup
      rsync_rclone
      shift
      ;;
    -c|--bench)
      load_ocb
      run_ocb_pipe
      shift
      ;;
    -bench-cpu)
      load_ocb
      cpu_sys
      shift
      ;;
    -d|--pv-drain)
      load_pv_drain
      load_pv_drain
      shift
      ;;
    -e|--engine)
      load_rule_engine
      rule_engine
      ;;
    -i|--reinstall)
      load_reinstall
      os_reinstall_run
      shift
      ;;
    -r|--repair)
      load_net_repair
      fix_network
      shift
      ;;
    -m|--migrator)
      load_migrator
      migration
      shift
      ;;
    -p|--recovery)
      load_recovery
      recovery_menu
      shift
      ;;
    --log)  log_browser_menu ;;
    --cron) cron_menu        ;;
    -r|--update) 
      if command -v one-click >/dev/null 2>&1; then
        mkdir -p /etc/one-click/upgrade-staging/modules
        warn "This will update one-click to the latest version $remote_version"
        read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed? (y|n): " update_version
        update_version="${update_version,,}"
        rm -f /tmp/skip_prompt
        if [[ "$update_version" == "y" || "$update_version" == "yes" ]]; then
          mv -f /usr/local/bin/one-click /etc/one-click/upgrade-staging/one-click
          mv -f "$manpage" /etc/one-click/upgrade-staging$(basename "$manpage")
          cp -R /var/cache/one-click/* /etc/one-click/upgrade-staging/modules/ 2>/dev/null
          rm -rf /var/cache/one-click
          if curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /usr/local/bin/one-click ; then
            if [[ ! -s "$manpage" ]]; then
              wget -P "$man_dir" "$one_click_1" &> /dev/null
              mandb -q &> /dev/null
            fi
            if [[ ! -f /usr/local/bin/one-click ]]; then
              error "Upgrade failed"
              warn "Reverting old version"
              mkdir -p /var/cache/one-click/
              mv -f /etc/one-click/upgrade-staging/modules/ /var/cache/one-click/ 2>/dev/null
              mv -f /usr/localbin/one-click/one-click /etc/one-click/upgrade-staging/
              mv -f /etc/one-click/upgrade-staging$(basename "$manpage") "$manpage"
              exit 1
            fi
            success "Successfully updated to $remote_version"
            chmod +x /usr/local/bin/one-click
            rm -rf /etc/one-click/upgrade-staging/
            exit 0
          else
            error "Upgrade Failed. Reverting changes"
            mv -f /etc/one-click/upgrade-staging/one-click /usr/local/bin/one-click
            cp -R /etc/one-click/upgrade-staging/var/ /var
            mv -f /etc/one-click/upgrade-staging/$(basename "$manpage") "$manpage"
            success "Revert successful"
          fi
        else
          warn "Version update has been cancelled." "Please update at your nearest opportunity"
        fi
      fi
      ;;
    -u|--uninstall)
      if command -v one-click >/dev/null 2>&1; then
        keep_file="$(mktemp)"
        remove_file="$(mktemp)"
        catch() {
          rm -f "$keep_file" "$remove_file" 
        }
        trap catch EXIT
        state_dir="${base}/state"
        warn "This will completely remove One-Click and all related files."
        read -rp "${cyan}Are you sure? ${yellow}[y|n]:${reset} " uninstall_confirm
        uninstall_confirm=${uninstall_confirm,,}
        if [[ "$uninstall_confirm" == "y" || "$uninstall_confirm" == "yes" ]]; then
          warn "Migrating sites and apps to /var/www. Please manually delete if data is no longer needed"
          rsync -a "$base/wordpress/" /var/www/
          rsync -a "$base/sites/" /var/www/
          rsync -a "$base/apps/nodejs/" /var/www/
          warn "Reinstating default webserver configs"
          if [[ -d /etc/nginx ]]; then
            if mv -f /etc/nginx/nginx.conf.one-click.bak /etc/nginx/nginx.conf &> /dev/null; then
              info "Nginx default conf restored"
            else 
              error "Default conf file has been moved! Please manually replace"
            fi
          elif [[ -d /etc/apache2 ]]; then
            if mv -f /etc/apache2/apache2.conf.one-click.bak /etc/apache2/apache2.conf &> /dev/null; then
              info "Nginx default conf restored"
            else 
              error "Default conf file has been moved! Please manually replace"
            fi
          elif [[ -d /etc/httpd ]]; then
            if mv -f /etc/httpd/httpd.conf.one-click.bak /etc/httpd/httpd.conf &> /dev/null; then
              info "Nginx default conf restored"
            else 
              error "Default conf file has been moved! Please manually replace"
            fi
          fi
          info "Loading protected paths from state files..."
          find "$state_dir" -type f | while read -r state; do
            while read -r line; do
              [[ -z "$line" ]] && continue
              for token in $line; do
                if [[ "$token" == /* ]]; then
                  add_keep_path "$token" "$keep_file"
                fi
              done
            done < "$state"
          done
          add_keep_path "$base" "$keep_file"
          add_keep_path "$state_dir" "$keep_file"
          sort -u "$keep_file" -o "$keep_file"
          info "Protected paths loaded: $(wc -l < "$keep_file")"
          echo "Scanning One-Click managed areas..."
          scan_paths=(
            "/etc"
            "/var"
            "/run"
            "/opt"
            "/srv"
          )
          for root in "${scan_paths[@]}"; do
            [[ ! -d "$root" ]] && continue
            find "$root" \( \
              -iname '*one-click*' -o \
              -path '/etc/nginx/sites-enabled/*' -o \
              -path '/etc/nginx/conf.d/*' -o \
              -path '/etc/apache2/sites-enabled/*' -o \
              -path '/etc/httpd/conf.d/*' \
            \) 2>/dev/null >> "$remove_file"
          done
          sort -u "$remove_file" -o "$remove_file"
          info "Filtering protected entries..."
          filtered="$(mktemp)"
          trap 'rm -f "$filtered"' EXIT
          while read -r path; do
            keep=0
            while read -r protected; do
              if [[ "$path" == "$protected" ]]; then
                keep=1
                break
              fi
            done < "$keep_file"
            if [[ $keep -eq 0 ]]; then
              printf "${magenta}[DELETE?]${green} %s\n" "$path" >> "$filtered"
            fi
          done < "$remove_file"
          sort -u "$filtered" -o "$filtered"
          printf '%s\n' \
            "${magenta}=================================================" \
            "${orange}[PREVIEW] ${yellow}Paths scheduled for removal" \
            "${magenta}=================================================${reset}"
          cat "$filtered"
          echo
          read -rp "${cyan}[USER]${reset} Proceed with deletion? (y|n): " confirm
          confirm="${confirm,,}"
          if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
            error "Aborted."
          exit 0
        fi
        warn "Removing unmanaged One-Click artifacts..."
        while read -r target; do
          [[ -z "$target" ]] && continue
            if [[ -e "$target" ]]; then
              echo "[REMOVE] $target"
              rm -rf --one-file-system "$target"
            fi
          done < "$filtered"
          warn "Removing IDS Scanner"
          python3 /var/cache/one-click/scanner.py --uninstall
          warn "Removing One-Click owned files and directories"
          if [[ -d "/usr/share/bash-completion/bash_completion.d" ]]; then
            rm -rf "$base" "$manpage" "$tab_complete" "/var/cache/one-click" "$(command -v one-click)"
          elif [[ -d "/usr/share/bash-completion/completions/" ]]; then
            rm -rf "$base" "$manpage" "$tab_complete2" "/var/cache/one-click" /etc/nginx/one-click "$(command -v one-click)"
          fi
          rm -rf "$base" "$manpage" "${tab_complete:-${tab_complete2:-}}" "/var/cache/one-click" "$(command -v one-click)"
          find /etc /var /run -type f -name '*one-click*' | while read line; do
            rm -f "$line"
          done
          success "One-Click has been uninstalled."
          complete -r one-click
          unset -f _one-click
          exit 0
        else
          die "Uninstall aborted."
        fi
      fi
      ;;
    -backup)
      load_wordpress
      wp_backup_interactive
      exit 0
      ;;
    -restore)
      load_wordpress
      wp_restore_interactive
      exit 0
      ;;
    -wp)
      load_wordpress
      run_script
      exit 0
      ;;
    -st)
      load_wordpress
      create_static_site
      exit 0
      ;;
    -wm)
      load_wordpress
      wp_menu
      exit 0
      ;;
    -st-backup)
      load_wordpress
      static_backup_interactive
      exit 0
      ;;
    -st-restore)
      load_wordpress
      static_restore_interactive
      exit 0
      ;;
    -nodejs)
      load_wordpress
      app_create_nodejs
      exit 0
      ;;
    -njs-admin)
      load_wordpress
      apps_menu nodejs
      exit 0
      ;;
    -nextcloud)
      load_wordpress
      install_nextcloud
      ;;
    -next-admin)
      load_wordpress
      used_app=nextcloud
      nextcloud_menu
      ;;
    -ssl)
      load_wordpress
      install_letsencrypt
      exit 0
      ;;
    -dns)
      load_wordpress
      dns_menu
      exit 0
      ;;
    -php)
      load_wordpress
      php_menu
      exit 0
      ;;
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ##
    -x) backup_all_configs ;; ### ### ###  ### #   # ### # #          ##
    -y) recovery_backup    ;; # # # # ###  #   #   # #   ##           ##
    -z) backup             ;; ### # # ###  ### ### # ### # #          ##
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ##
    *)
      if [[ "$1" == "setup" ]]; then
        exit_code=0
        preinstall_state="$base/state"
        mkdir -p "$preinstall_state"
        if [[ "$pkg_mgr" == "apt" ]]; then
          dpkg-query -W > "$preinstall_state/packages.state"
        else
          rpm -qa > "$preinstall_state/packages.state"
        fi
        if [[ -d /etc/nginx ]]; then
          find /etc/nginx -type f -print0 \
            | sort -z \
            | xargs -0 sha256sum \
          > "$preinstall_state/nginx.state"
        elif [[ -d /etc/apache2 ]]; then
          find /etc/apache2 -type f -print0 \
            | sort -z \
            | xargs -0 sha256sum \
          > "$preinstall_state/apache2.state"
        elif [[ -d /etc/httpd ]]; then
          find /etc/httpd -type f -print0 \
            | sort -z \
            | xargs -0 sha256sum \
          > "$preinstall_state/httpd.state"
        fi
        systemctl list-unit-files > "$preinstall_state/services.state"
        ls -1 /etc/systemd/system > "$preinstall_state/systemd_paths.state"
        getent passwd > "$preinstall_state/users.state"
        getent group > "$preinstall_state/groups.state"
        crontab -l > "$preinstall_state/cron.state" || true
        if command -v iptables &> /dev/null; then
          iptables-save > "$preinstall_state/iptables.state"
        fi
        if command -v nft &> /dev/null; then
          nft list ruleset > "$preinstall_state/nft.state"
        fi
        printf '%s\n' \
"  ___                 ____ _ _      _    
 / _ \ _ __   ___    / ___| (_) ___| | __
| | | | '_ \ / _ \  | |   | | |/ __| |/ /
| |_| | | | |  __/  | |___| | | (__|   < 
 \___/|_| |_|\___|   \____|_|_|\___|_|\\_\\
                                            
 ___           _        _ _          _ 
|_ _|_ __  ___| |_ __ _| | | ___  __| |
 | || '_ \\/ __| __/ _\` | | |/ _ \\/ _\` |
 | || | | \\__ \\ || (_| | | |  __/ (_| |
|___|_| |_|___/\\__\\__,_|_|_|\\___|\\__,_|"
        success "Setup Completed Successfully"
      elif [[ "${1:-}" == "peer" ]]; then
        success "Import of backup successful to $sys_ip"
        sleep 5
        ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
      else
        exit_code=1
        error "Unknown option: $1"
      fi
      printf '%s\n' \
        "$(tput smul)Usage:$(tput rmul) $(tput setaf 11)one-click$(tput sgr 0) $(tput setaf 4)[ARG]$(tput sgr 0)" \
        " " "$(tput smul)Options:$(tput rmul)                $(tput smul)Description$(tput rmul)" \
        "  reinstall               OS reinstallation" \
        "  backup                  Backup with rsync + rclone" \
        "  bench                   Benchmarking tool automates the execution of tests" \
        "  bench-sys               Run only geekbench/sysbench benchmark." \
        "  (engine|rule-engine)    Converts natural language into iptables commands" \
        "  menu                    Central menu with direct access to most tools." \
        "  migrator                System migration tool. Rsync + DD options." \
        "  recovery                Boot partition backup + recovery tool (BIOS, UEFI, GRUB)" \
        "  fleet                   Run remote commands to your fleet of registered servers" \
        "  net-repair              Repair network (Includes snapshots and backup of network files)" \
        "  (system|sys-info)       System Information" \
        "  (log-browser|logs)      System Log File Browswer" \
        "  cron                    Configure a cron job" \
        "  help                    Show this help message" \
        "  uninstall               Remove one-click and all associated files and configurations." \
        "  --web-admin             Create a backup of selected static site." \
        "  --web-create            Install a blank static html or php website." \
        "  --wp                    Basic wordpress and cron management." \
        "  --wp-admin              Manage all aspects of wordpress such as staging, backups and SSL" \
        "  --wp-create             Install Wordpress with either nginx or apache." \
        "  --nodejs-admin          Start, stop and manage app." \
        "  --nodejs-create         Install a NodeJS app with either nginx or apache." \
        "  --nextcloud-create      Create a new instance of an isolated Nextcloud" \
        "  --nextcloud-admin       Manage Nextcloud instances" \
        "  --db-admin              Manage Databases and create temp front end if needed." \
        "  --dns                   Manage DNS with Cloudflare" \
        "  --ssl                   Install SSL for wordpress or any other virtual host." \
        "  --php                   Manage system-wide or per site php settings." \
        "  --version               Check version" \
        " " "$(tput smul)Examples:$(tput rmul)" \
        "  $(tput setaf 3)one-click $(tput setaf 4)net-repair$(tput sgr 0)    Run network repair" \
        "  $(tput setaf 3)one-click $(tput setaf 4)backup$(tput sgr 0)        Backup + Restore Tool" " " "Version: $version"
        exit "$exit_code"
      ;;
  esac
fi
