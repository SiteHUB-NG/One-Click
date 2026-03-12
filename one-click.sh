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
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
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
base="/etc/one-click"
deps_ok="${base}/.deps_ok"
path="$(realpath "$0")"
# ==== Help Menu ====
if [[ "$#" -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  printf '%s\n' \
    "$(tput smul)Usage:$(tput rmul) $(tput setaf 11)one-click$(tput sgr 0) $(tput setaf 4)[ARG]$(tput sgr 0)" \
    " " "$(tput smul)Options:$(tput rmul)                $(tput smul)Description$(tput rmul)" \
    "  reinstall               OS reinstallation" \
    "  backup                  Backup with rsync + rclone" \
    "  bench                   Benchmarking tool automates the execution of tests" \
    "  (engine|rule-engine)    Converts natural language into iptables commands. RuleEngine is an atomic firewall wrapper that supports transaction commits with a self healing 10 second rollback if confirmation is not received." \
    "      $(tput smul)subcommands:$(tput rmul)        Subcommands are delimited by $(tput setaf 373)and$(tput sgr 0) and $(tput setaf 373),$(tput sgr 0)(comma) can be chained e.g '$(tput setaf 228)allow udp port 100 and reject 200 output and tcp 300$(tput sgr0)'." \
    "      --dry-run           Show what commands would be executed without applying them." \
    "      (open|show)<alias>? Opens firewall table view. Can optionally be extended by specifying the $(tput setaf 228)table arg$(tput sgr0) or with the '$(tput setaf 228)all$(tput sgr0)' flag." \
    "      flush <table>       Flush rules in specified table e.g '$(tput setaf 228)flush mangle$(tput sgr0)'." \
    "      flush all           Flush all tables e.g '$(tput setaf 228)one-click firewall flush all$(tput sgr0)'." \
    "      (backup|save)       Create a backup file of the firewall configuration e.g '$(tput setaf 228)one-click engine backup$(tput sgr0)'." \
    "      restore             Restore firewall configuration from an available backup e.g '$(tput setaf 228)one-click engine restore$(tput sgr0)'." \
    "      allow <arg>         (ACCEPT) Open ports e.g '$(tput setaf 228)allow 443$(tput sgr0)' or  '$(tput setaf 228)allow apache$(tput sgr0)' to accept packets on ports 80 and 443" \
    "      (deny|drop) <arg>   (DROP) Drop packets e.g '$(tput setaf 228)deny https$(tput sgr0)' or '$(tput setaf 228)close smtp$(tput sgr0)' or '$(tput setaf 228)drop smtp$(tput sgr0)'" \
    "      (reject|decline)    (REJECT) Reject packets e.g '$(tput setaf 228)bounce https$(tput sgr0)' or '$(tput setaf 228)reject 22$(tput sgr0)'" \
    "      (delete|remove)     (DELETE) Delete rule entries from tables, firewall backups and alias mapping e.g '$(tput setaf 228)remove line 3 nat$(tput sgr0)' or '$(tput setaf 228) delete firewall$(tput sgr0)' or '$(tput setaf 228) delete alias$(tput sgr0)'. Use '$(tput setaf 228)open$(tput sgr0)' command first when removing firewall tables to know the exact line number." \
    "      (mask|hide)         (MASQUERADE) e.g 'hide from 1.1.1.1'" \
    "      enable (icmp|echo)  Enable ICMP protocol e.g '$(tput setaf 228)allow enable echo$(tput sgr0)'" \
    "      disable (icmp|echo) Disable ICMP protocol e.g '$(tput setaf 228)disable icmp$(tput sgr0)'" \
    "      raw: <iptables cmd> Enter raw commands for extended functionality" \
    "      alias-create        The alias-create command allows you to create custom aliases for IP addresses. Instead of typing a long string of numbers every time, you can give an IP (or a group of IPs) a name like office, home, or blacklist e.g '$(tput setaf 228)one-click engine 'include drop_list 92.23.34.56 18.23.45.54 1.23.1.21 2.1.3.22$(tput sgr 0)' and use it with e.g '$(tput setaf 228)one-click engine 'drop ssh from drop_list and allow ssh from office$(tput sgr 0)'" \
    "      alias-append        Add additional IPs mapped to aliases to extend batch processing functionality. Key alias must already exist else use the alias-create command first." \
    "      alias-prune         Remove IPs from an aliases array e.g '$(tput setaf 228)alias-prune home 1.2.3.4$(tput sgr0)'" \
    "      multiport           Multiple Ports e.g '$(tput setaf 228)bounce https multiport 50 556 4000$(tput sgr0)'" \
    "      range               A range of ports e.g '$(tput setaf 228)range 1000-2000$(tput sgr0)'" \
    "      sensitive:          Add ports to the sensitive list to be alerted before carrying out actions on them e.g '$(tput setaf 228)sensitive: 3306 8080 8443$(tput sgr0)'." \
    "      sensitive-list      List all of the ports in the sensitive list." \
    "      sensitive-remove:   Remove ports from the sensitive list" \
    "      audit               Visual inspection of active rules, drops and intrusion attempts." \
    "      audit ssh           View Brute Force attempts on port 22 with a count of attempts, the usernames tried, IP and last seen." \
    "      audit block <ID>    Drop brute force detected users. ID must be taken from the '$(tput setaf 228)audit ssh$(tput sgr0)' table" \
    "      audit block ID perm Rather than a 60 minute block, this will ban the IP permanently." \
    "      audit unblock <ID>  Revert the blocking of detected brute force IP." \
    "      audit history       View persisted history of brute force users who have has action taken against them." \
    "      audit key <KEY>     Used to integrate reporting and banning of IPs with AbuseIPDB. Insert AbuseIPDB API key only with this command." \
    "      audit lookup <IP>   Check an IPs reputation before acting on it. AbuseIPDB needs to be added beforehand." \
    "      audit banlist       View IPs that have been ban both by RuleEngine and Fail2ban." \
    "      audit jail <args>   Add a new jail '$(tput setaf 228)Usage: audit jail [name] port [port] retry [count]$(tput sgr0)'" \
    "      from                From source IP" \    
    "      to                  To destination IP " \
    "      $(tput smul)Protocols:$(tput rmul) " \
    "      tcp                 TCP Traffic is the deafult for most chains" \
    "      udp                 UDP Traffic '$(tput setaf 228)allow udp port 100$(tput sgr0)'" \
    "  migrator                System migration tool. Rsync + DD options." \
    "  recovery                Boot partition backup + recovery tool (BIOS, UEFI, GRUB)" \
    "  repair                  Repair network (Includes snapshots and backup of network files)" \
    "  rule-engine             Converts human-readable commands into iptables commands" \
    "  (system|sys-info)       System Information" \
    "  (logs|log-browser)      System Log File Browswer" \
    "  cron                    Configure a cron job" \
    "  help                    Show this help message" \
    "  uninstall               Remove one-click and all associated files and configurations." \
    "  --version               Check version" \
    "  --dry-run               Check the effect of rules before globally applying" \
    " " "$(tput smul)Examples:$(tput rmul)" \
    "  $(tput setaf 3)one-click $(tput setaf 4)repair$(tput sgr 0)        Run network repair" \
    "  $(tput setaf 3)one-click $(tput setaf 4)backup$(tput sgr 0)        Backup + Restore Tool" 
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
# ==== Initialize these variables and functions immediately ====
rsync_backup_dir="${base}/backup-tool"
profiles="${rsync_backup_dir}/profiles/"
log_dir="/var/log/one-click"
log_file="${log_dir}/one-click.log"
log_error_file="${log_dir}/one-click-error.log"
recovery_base="${base}/boot-recovery-tool"
recovery_config="${recovery_base}/structure.conf"
secret_key="${base}/.backup_secret.key"
nic="$(awk -F"[: ]" '/state UP/{print $3}' <(ip link))"
updated="March 2026"
version="1.1.8"
service_name="resumable-rsync-$(date +%s)"
service_file="/etc/systemd/system/${service_name}.service"
man_dir="/usr/local/share/man/man1/"
tab_complete="/etc/bash_completion.d/one-click"
tab_complete2="/usr/share/bash-completion/completions/one-click"
one_click_1="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.1"
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
orange=$(tput setaf 208)
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
check_for_updates() {
  local version_check current_version 
  current_version="$version"
  version_check="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh"
  remote_version=$(sed -En '/\<version="([0-9.]+)"/s//\1/p' <(curl -sL --connect-timeout 2 "$version_check"))
  if [[ -z "$remote_version" ]]; then
    return 0
  fi
  if [[ "$remote_version" != "$current_version" ]]; then
    printf '%s\n' "${yellow}╔══════════════════════════════════════════════════════════════════╗${reset}" \
      "${yellow}║ [UPDATE] A newer version ($remote_version) is available!                   ║${reset}" \
      "${yellow}║ Run 'one-click update' to get the latest features.               ║${reset}" \
      "${yellow}╚══════════════════════════════════════════════════════════════════╝${reset}" " "
  fi
}
check_for_updates
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
    # ==== Try and pull from a214354.network ====
    if curl -fsSL --connect-timeout 5 --max-time 10 \
         "$url" -o "$cache_file.tmp" &> /dev/null; then
        mv -f "$cache_file.tmp" "$cache_file"
    # ==== Try Github if primary fails ====
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
  source "$cache_file"
}
# ==== Load Without Calling ====
# ==== Functions ====
func_url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/functions.sh"
backup_func_url=""
# ==== Alt Mirror ====
#backup_func_url="https://as214354.network/functions.sh"
func_cache_dir="/var/cache/one-click/"
func_cache_file="${func_cache_dir:-}/functions.sh"
load_body "$func_url" "$backup_func_url" "$func_cache_dir" "$func_cache_file"
# ==== Cron Logic ====
cron_url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/cron.sh"
backup_cron_url=""
# ==== Alt Mirror ====
#backup_cron_url="https://as214354.network/cron.sh"
cron_cache_dir="/var/cache/one-click/"
cron_cache_file="${cron_cache_dir}/cron.sh"
load_body "$cron_url" "$backup_cron_url" "$cron_cache_dir" "$cron_cache_file"
# ==== None Essential Modules ====
# ==== Network Repair ====
load_net_repair() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/net-recovery.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/net-recovery.sh"
  local cache_dir="/var/cache/one-click"
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
  local cache_dir="/var/cache/one-click"
  local cache_file="${cache_dir}/sys-info.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
# ==== Boot Recovery ====
load_recovery() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/boot-recovery.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/boot-recovery.sh"
  local cache_dir="/var/cache/one-click"
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
  local cache_dir="/var/cache/one-click"
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
  local cache_dir="/var/cache/one-click"
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
  local cache_dir="/var/cache/one-click"
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
  local cache_dir="/var/cache/one-click"
  local cache_file="${cache_dir}/ocb.sh"
  collect_sysinfo
  load_body "$url" "$backup_url" "$cache_dir" "$cache_file"
}
load_rule_engine() {
  local url="https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/rule_engine.sh"
  local backup_url=""
  # ==== Alt Mirror ====
  #local bacup_url="https://as214354.network/rule_engine.sh"
  local cache_dir="/var/cache/one-click"
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
    cmds["uninstall"]=""
    cmds["--version"]=""

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
    cmds["rule-engine:audit"]=
    cmds["rule-engine:--dry-run"]=""

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
    cmds["engine:audit"]=
    cmds["engine:--dry-run"]=""
    
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
    cmds["uninstall"]=""
    cmds["--version"]=""
    
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
    cmds["rule-engine:audit"]=
    cmds["rule-engine:--dry-run"]=""

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
    cmds["engine:--dry-run"]=""
    
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
      backup)      echo "--backup"    ;;
      bench)       echo "--bench"     ;;
      engine)      echo "$i"          ;;
      migrator)    echo "--migrator"  ;;
      net-repair)  echo "--repair"    ;;
      reinstall)   echo "--reinstall" ;;
      recovery)    echo "--recovery"  ;;
      rule-engine) echo "$i"          ;;
      cron)        echo "--cron"      ;;
      logs)        echo "--log"       ;;
      log-browser) echo "--log"       ;;
      uninstall)   echo "--uninstall" ;;
      update)       echo "--update"    ;;
      *)           echo "$i"          ;;
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
  install_self
  exec '/usr/local/bin/one-click' "$@"
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
      run_ocb
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
        mkdir -p /etc/one-click/upgrade-staging/
        warn "This will update one-click to the latest version $remote_version"
        read -rp "Please confirm you are happy to proceed? (y|n): " update_version
        update_version="${update_version,,}"
        if [[ "$update_version" == "y" || "$update_version" == "yes" ]]; then
          mv -f /usr/local/bin/one-click /etc/one-click/upgrade-staging/one-click
          mv -f "$manpage" /etc/one-click/upgrade-staging$(basename "$manpage")
          cp -R /var/cache/one-click/* /etc/one-click/upgrade-staging/ 2>/dev/null
          rm -rf /var/cache/one-click
          if curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /usr/local/bin/one-click ; then
            if [[ ! -s "$manpage" ]]; then
              wget -P "$man_dir" "$one_click_1" &> /dev/null
              mandb -q &> /dev/null
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
        warn "This will completely remove One-Click and all related files."
        read -rp "${cyan}Are you sure? ${yellow}[y|n]:${reset} " uninstall_confirm
        uninstall_confirm=${uninstall_confirm,,}
        if [[ "$uninstall_confirm" == "y" || "$uninstall_confirm" == "yes" ]]; then
          if [[ -d "/usr/share/bash-completion/bash_completion.d" ]]; then
            rm -rf "$log_dir" "$base" "$manpage" "$tab_complete" "/var/cache/one-click" "$(command -v one-click)"
          elif [[ -d "/usr/share/bash-completion/completions/" ]]; then
            rm -rf "$log_dir" "$base" "$manpage" "$tab_complete2" "/var/cache/one-click" "$(command -v one-click)"
          fi
          rm -rf "$log_dir" "$base" "$manpage" "${tab_complete:-${tab_complete2:-}}" "/var/cache/one-click" "$(command -v one-click)"
          printf "${green}[SUCCESS]${reset}%s\n" "One-Click has been uninstalled."
          complete -r one-click
          unset -f _one-click
          exit 0
        else
          die "Uninstall aborted."
        fi
      fi
      ;;
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ##
    -x) backup_all_configs ;; ### ### ###  ### #   # ### # #          ##
    -y) recovery_backup    ;; # # # # ###  #   #   # #   ##           ##
    -z) backup             ;; ### # # ###  ### ### # ### # #          ##
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ##
    *)
      if [[ "$1" == "setup" ]]; then
        printf '%s\n' \
"  ___                    ____ _ _      _    
 / _ \ _ __   ___       / ___| (_) ___| | __
| | | | '_ \ / _ \_____| |   | | |/ __| |/ /
| |_| | | | |  __/_____| |___| | | (__|   < 
 \___/|_| |_|\___|      \____|_|_|\___|_|\\_\\
                                            
 ___           _        _ _          _ 
|_ _|_ __  ___| |_ __ _| | | ___  __| |
 | || '_ \\/ __| __/ _\` | | |/ _ \\/ _\` |
 | || | | \\__ \\ || (_| | | |  __/ (_| |
|___|_| |_|___/\\__\\__,_|_|_|\\___|\\__,_|"
        success "Setup Completed Successfully"
      else
        error "Unknown option: $1"
      fi
      printf '%s\n' \
        "$(tput smul)Usage:$(tput rmul) $(tput setaf 11)one-click$(tput sgr 0) $(tput setaf 4)[ARG]$(tput sgr 0)" \
        " " "$(tput smul)Options:$(tput rmul)                $(tput smul)Description$(tput rmul)" \
        "  reinstall               OS reinstallation" \
        "  backup                  Backup with rsync + rclone" \
        "  bench                   Benchmarking tool automates the execution of tests" \
        "  (engine|rule-engine)    Converts natural language into iptables commands" \
        "  migrator                System migration tool. Rsync + DD options." \
        "  recovery                Boot partition backup + recovery tool (BIOS, UEFI, GRUB)" \
        "  repair                  Repair network (Includes snapshots and backup of network files)" \
        "  (system|sys-info)       System Information" \
        "  (log-browser|logs)      System Log File Browswer" \
        "  cron                    Configure a cron job" \
        "  help                    Show this help message" \
        "  uninstall               Remove one-click and all associated files and configurations." \
        "  --version               Check version" \
        "  --dry-run               Check the effect of rules before globally applying" \
        " " "$(tput smul)Examples:$(tput rmul)" \
        "  $(tput setaf 3)one-click $(tput setaf 4)repair$(tput sgr 0)        Run network repair" \
        "  $(tput setaf 3)one-click $(tput setaf 4)backup$(tput sgr 0)        Backup + Restore Tool"
        exit 1
      ;;
  esac
fi
