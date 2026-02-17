#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK MULIPLE TOOLS * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== Initialization ==== 
export TERM="${TERM:-xterm}"
export LC_ALL=C
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
    "  migrator                System migration tool. Rsync + DD options." \
    "  recovery                Boot partition backup + recovery tool (BIOS, UEFI, GRUB)" \
    "  repair                  Repair network (Includes snapshots and backup of network files)" \
    "  sys-info                System Information" \
    "  system                  System Information" \
    "  logs                    System Log File Browswer" \
    "  log-browser             System Log File Browswer" \
    "  cron                    Configure a cron job" \
    "  help                    Show this help message" \
    "  uninstall               Remove one-click and all associated files and configurations." \
    "  --version               Check version" \
    " " "$(tput smul)Examples:$(tput rmul)" \
    "  $(tput setaf 3)one-click $(tput setaf 4)repair$(tput sgr 0)       Run network repair" \
    "  $(tput setaf 3)one-click $(tput setaf 4)backup$(tput sgr 0)        Backup + Restore Tool"
  exit 0
fi
# ==== Install Dependancies ====
if command -v dnf >/dev/null 2>&1; then
  pkg_mgr="dnf"
elif command -v yum >/dev/null 2>&1; then
  pkg_mgr="yum"
elif command -v zypper >/dev/null 2>&1; then
  pkg_mgr="zypper"
elif command -v apt-get >/dev/null 2>&1; then
  pkg_mgr="apt"
fi
install_dep() {
  local dep_name
  local check_cmd
  local pkg_name
  local pkg_manager
  local fatal
  dep_name="${1:-}"
  check_cmd="$2"
  pkg_name="${3:-$dep_name}"
  pkg_manager="$4"
  fatal="${5:-}"
  # ==== Check if dependency is already installed ====
  if ! eval "$check_cmd" &> /dev/null; then
    echo "Installing dependency ${dep_name}"
    for ((i=0;i<4;i++)); do printf '.'; sleep 0.3; done
    echo -e '\n'
    sleep 0.5
    if ! $pkg_manager -y install "$pkg_name" &> /dev/null; then
      if [[ "$fatal" == true ]]; then
        echo "Dependency ${dep_name} failed to install"
      else
        echo "Dependency ${dep_name} failed to install"
      fi
    fi
  fi
}
install_dependancies() {
  for id in "${ids[@]}"; do
    case "$id" in
      debian)
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
        ;;
      *)
        printf '%s\n' "Unknown OS: $id"
        ;;
    esac
  done
}
if [[ ! -f "$deps_ok" ]]; then
  install_dependancies
  mkdir -p "$base"
  touch "$deps_ok"
fi
# ==== End Of Dependancies ==== #
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
updated="Feb 2026"
version="1.2.5"
man_dir="/usr/local/share/man/man1/"
tab_complete="/etc/bash_completion.d/one-click"
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
bold="$(tput bold)"
reset="$(tput sgr 0)"
ul="$(tput smul)"
ul_reset="$(tput rmul)"
spinner_frames=( '\' '-' '/' '|' )
r1=( '|' '/' '-' '\' )
r2=( '-' '/' '|' '\' )
r3=( '|' '\' '-' '/' )
sed -Ei "13 {s/(Updated: )[^=]* /\1${updated} /;s/(Version#: )[^=]* /\1${version} /}" "$path"
# ==== Load Source Body ====
warn() {
  printf "$yellow[WARN]:$reset %s\n" "$@" >&2;
  _log_write "$yellow[WARN]$reset $*" >&2;
}
# ==== Loader Body ====
load_body() {
  local url=${1:-}
  local backup_url=${2:-}
  local cache_dir="${3:-}"
  local cache_file="${4:-}"
  local ttl=$((24 * 3600))
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
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
# ==== System Info Dashboard - Skip TMUX and root checks ====
if [[ "${1:-}" == "-s" || "${1:-}" == "--sys-info" || "${1:-}" == "system-info" || "${1:-}" == "system" ]]; then
  load_system
  sys_info
  shift
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
if [[ "$1" == "--version" ]]; then
  echo "$version"
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
# ==== Check root ====
if [ "$EUID" -ne 0 ]; then
  die "This script must be run as root."
fi
# ==== Module Tab Complete ====
if [[ ! -f "$tab_complete" ]]; then
  cat <<'EOF'> "$tab_complete"
_one_click() {
  local cur
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=( $(compgen -W "
    backup
    cron
    migrator
    net-repair
    reinstall
    recovery
    system
    system-info
    logs
    log-browser
    help
    uninstall
  " -- "$cur") )
}
complete -F _one_click one-click
EOF
fi
map_one_click() {
  for i in "$@"; do
    case "$i" in
      backup)      echo "--backup"    ;;
      migrator)    echo "--migrator"  ;;
      net-repair)  echo "--repair"    ;;
      reinstall)   echo "--reinstall" ;;
      recovery)    echo "--recovery"  ;;
      cron)        echo "--cron"      ;;
      logs)        echo "--log"       ;;
      log-browser) echo "--log"       ;;
      uninstall)   echo "--uninstall" ;;
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
    exec 'one-click' "$@"
fi
set -- $(map_one_click "$@")
source "$tab_complete"
# ==== Install dependancies ====
#dependancies
mkdir -p "${log_dir:-}" "${base:-}"
touch "$secret_key" "$manpage" "$tab_complete" "${log_error_file:-}" "${log_file:-}"
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
  chmod +x "${path:?Path not set}"
  printf '%s' "Launching a TMUX session for One-Click"
  for i in {1..13}; do printf '.'; sleep 0.3; done
  echo
  tmux new-session -d -s "$session" "env $flag=1 bash '${path}' '$arg'; exec bash"
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
    -d|--pv-drain)
      load_pv_drain
      load_pv_drain
      shift
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
    -u|--uninstall)
      if command -v one-click >/dev/null 2>&1; then
        warn "This will completely remove One-Click and all related files."
        read -rp "Are you sure? [y/n]: " uninstall_confirm
        uninstall_confirm=${uninstall_confirm,,}
        if [[ "$uninstall_confirm" == "y" || "$uninstall_confirm" == "yes" ]]; then
          rm -rf "$log_dir" "$base" "$manpage" "$tab_complete" "${cache_dir:-}" "$(command -v one-click)"
          success "One-Click has been uninstalled."
          exit 0
        else
          die "Uninstall aborted."
        fi
      fi
      ;;
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ==== ##
    -x) backup_all_configs ;; ### ### ###  ### #   # ### # #               ##
    -y) recovery_backup    ;; # # # # ###  #   #   # #   ##                ##
    -z) backup             ;; ### # # ###  ### ### # ### # #               ##
    # ==== [INFORMATIONAL]: AUTOMATION CALLS. DOES NOT FIRE FROM HERE ==== ##
    *)
      if [[ "$1" == "setup" ]]; then
        success "Setup Completed Successfully"
      else
        error "Unknown option: $1"
      fi
      printf '%s\n' \
        "$(tput smul)Usage:$(tput rmul) $(tput setaf 11)one-click$(tput sgr 0) $(tput setaf 4)[ARG]$(tput sgr 0)" \
        " " "$(tput smul)Options:$(tput rmul)                $(tput smul)Description$(tput rmul)" \
        "  reinstall               OS reinstallation" \
        "  backup                  Backup with rsync + rclone" \
        "  migrator                System migration tool. Rsync + DD options." \
        "  recovery                Boot partition backup + recovery tool (BIOS, UEFI, GRUB)" \
        "  repair                  Repair network (Includes snapshots and backup of network files)" \
        "  sys-info                System Information" \
        "  system                  System Information" \
        "  logs                    System Log File Browswer" \
        "  log-browser             System Log File Browswer" \
        "  cron                    Configure a cron job" \
        "  help                    Show this help message" \
        "  uninstall               Remove one-click and all associated files and configurations." \
        "  --version               Check version" \
        " " "$(tput smul)Examples:$(tput rmul)" \
        "  $(tput setaf 3)one-click $(tput setaf 4)repair$(tput sgr 0)       Run network repair" \
        "  $(tput setaf 3)one-click $(tput setaf 4)backup$(tput sgr 0)        Backup + Restore Tool"
      exit 1
      ;;
  esac
fi
