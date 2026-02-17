#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK BACK-UP TOOL  * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ========================== #================================================ #
# ==== One-Click Backup ==== #
mkdir -p "${log_dir:-}"
touch "${log_error_file:-}" "${log_file:-}"
# ==== Build Essential Variables ====
build_vars() {
  mapfile -t local_drives < <(lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk"{print $1,$2}')
  drives=($(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'))
  sys_ipv6="$(awk '/inet6/ && $NF=="global" || $(NF-1)=="global" {split($2,arr,"/");print arr[1]}' <(ip -6 a s "$nic"))"
  ipv6_gw="$(awk '$1=="default" {print $3}' <(ip -6 r))"
  path="$(realpath "$0")"
  os_ping_cmd="$(ping -c2 -W2 8.8.8.8)"
  net_config="/root/migration_network_config.sh"
  wg_file="/etc/wireguard/wg0.conf"
  net_repair="/etc/systemd/system/net-reconfigure.service"
  reinstall="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
  reinstall_secondary="https://as214354.network/reinstall.sh"
  base_dir="/etc/one-click/network-repair"
  backup_dir="$base_dir/backups"
  snaps_dir="$base_dir/snapshots"
  config_dir="$base_dir/configuration"
  service_restore="$base_dir/service.restore"
  cron_flag="$base_dir/.cron_installed"
  nrepair_log_file="/var/log/one-click/network-repair.log"
  log_dir="/var/log/one-click"
  kern="$(uname -r)"
  term_width="$(tput cols)"
  rows="$(tput lines)"
  row="$(( rows / 2 ))"
  cols="$(tput cols)"
  i=0
  repeat=10
  TABLE_WIDTH=62
  seq="$(date +'%M')"
  seq="${seq:1}"
  net_repair_banner="NETWORK#REPAIR#AND#CONNECTIVITY#MONITOR"
  wizard="WELCOME#TO#THE#ONE-CLICK#MIGRATION#WIZARD"
  os_reinstall="REINSTALL#ANY#OS#EASILY#-#REINSTALL"
  r_backup="ONE#CLICK#BACKUP#-#RSYNC#+#RCLONE"
  recovery_banner="BOOT#BACKUP#AND#RECOVERY#TOOL"
  cron_banner="AUTOMATE#CRON#JOBS#EASILY"
  log_banner="LOG#BROWSER"
  trap=(
    $(basename "$reinstall")
    reinstall.log
    $net_config
    all_dirs.txt
    /root/rsync-services-running.txt
    all_dirs.txt
    /root/rsync-etc-exclude.txt
    /root/rsync-services-exclude.txt
    /etc/fstab.migrator-backup
    /etc/resolv.conf.migrator-backup
    /etc/hosts.migrator-backup
    one-click.sh
  )
  os_title=$(cat <<'EOF'
  ___                ____ _ _      _       ___  ____  
 / _ \ _ __   ___   / ___| (_) ___| | __  / _ \/ ___| 
| | | | '_ \ / _ \ | |   | | |/ __| |/ / | | | \___ \ 
| |_| | | | |  __/ | |___| | | (__|   <  | |_| |___) |
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\  \___/|____/ 
                                                      
 ____  _____ ___ _   _ ____ _____  _    _     _     
|  _ \| ____|_ _| \ | / ___|_   _|/ \  | |   | |    
| |_) |  _|  | ||  \| \___ \ | | / _ \ | |   | |    
|  _ <| |___ | || |\  |___) || |/ ___ \| |___| |___ 
|_| \_\_____|___|_| \_|____/ |_/_/   \_\_____|_____|

EOF
  )
  raw_title=$(cat <<'EOF'
  ___                ____ _ _      _    
 / _ \ _ __   ___   / ___| (_) ___| | __
| | | | '_ \ / _ \ | |   | | |/ __| |/ /
| |_| | | | |  __/ | |___| | | (__|   < 
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\
                                        
 __  __ _                 _             
|  \/  (_) __ _ _ __ __ _| |_ ___  _ __ 
| |\/| | |/ _` | '__/ _` | __/ _ \| '__|
| |  | | | (_| | | | (_| | || (_) | |   
|_|  |_|_|\__, |_|  \__,_|\__\___/|_|   
          |___/                     
EOF
  )
  backup_title=$(cat <<'EOF'
  ___                ____ _ _      _      ____             _                
 / _ \ _ __   ___   / ___| (_) ___| | __ | __ )  __ _  ___| | ___   _ _ __  
| | | | '_ \ / _ \ | |   | | |/ __| |/ / |  _ \ / _` |/ __| |/ / | | | '_ \ 
| |_| | | | |  __/ | |___| | | (__|   <  | |_) | (_| | (__|   <| |_| | |_) |
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\ |____/ \__,_|\___|_|\_\\__,_| .__/ 
                                                                     |_|   
EOF
  )
  net_repair_title=$(cat <<'EOF'
             ___                    ____ _ _      _
            / _ \ _ __   ___       / ___| (_) ___| | __
           | | | | '_ \ / _ \_____| |   | | |/ __| |/ /
           | |_| | | | |  __/_____| |___| | | (__|   <
            \___/|_| |_|\___|      \____|_|_|\___|_|\_\

 _   _      _                      _      ____                  _
| \ | | ___| |___      _____  _ __| | __ |  _ \ ___ _ __   __ _(_)_ __
|  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ / | |_) / _ \ '_ \ / _` | | '__|
| |\  |  __/ |_ \ V  V / (_) | |  |   <  |  _ <  __/ |_) | (_| | | |
|_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ |_| \_\___| .__/ \__,_|_|_|
                                                   |_|

EOF
  )
  recovery_header=$(cat <<'EOF'
  ___                ____ _ _      _    
 / _ \ _ __   ___   / ___| (_) ___| | __
| | | | '_ \ / _ \ | |   | | |/ __| |/ /
| |_| | | | |  __/ | |___| | | (__|   < 
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\
                                        
 ____                                    
|  _ \ ___  ___ _____   _____ _ __ _   _ 
| |_) / _ \/ __/ _ \ \ / / _ \ '__| | | |
|  _ <  __/ (_| (_) \ V /  __/ |  | |_| |
|_| \_\___|\___\___/ \_/ \___|_|   \__, |
                                   |___/ 
EOF
  )
  cron_title=$(cat <<'EOF'
  ___                ____ _ _      _       ____                 
 / _ \ _ __   ___   / ___| (_) ___| | __  / ___|_ __ ___  _ __  
| | | | '_ \ / _ \ | |   | | |/ __| |/ / | |   | '__/ _ \| '_ \ 
| |_| | | | |  __/ | |___| | | (__|   <  | |___| | | (_) | | | |
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\  \____|_|  \___/|_| |_|
                                                                
EOF
  )
  log_title=$(cat <<'EOF'
          ___                ____ _ _      _    
         / _ \ _ __   ___   / ___| (_) ___| | __
        | | | | '_ \ / _ \ | |   | | |/ __| |/ /
        | |_| | | | |  __/ | |___| | | (__|   < 
         \___/|_| |_|\___|  \____|_|_|\___|_|\_\
                                                
 _                  ____                                  
| |    ___   __ _  | __ ) _ __ _____      _____  ___ _ __ 
| |   / _ \ / _` | |  _ \| '__/ _ \ \ /\ / / __|/ _ \ '__|
| |__| (_) | (_| | | |_) | | | (_) \ V  V /\__ \  __/ |   
|_____\___/ \__, | |____/|_|  \___/ \_/\_/ |___/\___|_|   
            |___/ 
EOF
  )
}
# ==== End Essential Variables ==== #
collect_sysinfo() {
  whois_ip="$(sed -En '/inet /{s,^[^/]* ([^/]*).*,\1,p}' <(ip a s "$nic"))"
  sys_ip="$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic"))"
  sys_gw="$(awk '$1 == "default" {print $3}' <(ip r))"
  ip_upstream="$(awk '$1 == "NetName:" || $1 == "netname:" {print $2}' <(whois "$whois_ip" | tac) | head -1)"
  ip_country="$(awk '$1 == "Country:" || $1 == "country:" {print $2}' <(whois "$whois_ip" | tac) | head -1)"
  ip_asn="$(awk '$1 == "Origin:" || $1 == "origin:" {print $2}' <(whois "$whois_ip" | tac) | head -1)"
  drive_cap="$(awk 'NR==2' <(lsblk -o size))"
  ns=($(awk '$1 !~ "#" && /nameserver/ {print $2}' /etc/resolv.conf ))
  cpu_model="$(lscpu | awk -F: '/Model name/ {print $2}' | sed 's/^ *//')"
  cpu="$(nproc)"
  HOSTNAME="$(hostname)"
}
_log_write() { printf "[%s] %s\n" "${yellow}[${reset}$(date '+%F %T')${yellow}]${reset}" "$*" >> "$log_file"; }
_log_write_error() { printf "${red}[${reset}%s${red}]${reset} %s\n" "${yellow}[${red}$(date '+%F %T')${yellow}]${reset}" "$*" >> "$log_error_file"; }
info() {
  printf "$blue[INFO]:$reset %s\n" "$@" >&2;
  _log_write "$blue[INFO]$reset $*" >&2;
}
success() {
  printf "$green[SUCCESS]:$reset %s\n" "$@" >&2;
  _log_write "$green[SUCCESS]$reset $*" >&2;
}
warn() {
  printf "$yellow[WARN]:$reset %s\n" "$@" >&2;
  _log_write "$yellow[WARN]$reset $*" >&2;
}
error() {
  printf "$red[ERROR]:$reset  %s\n" "$@" >&2
  _log_write_error "$red[ERROR]$reset $*" >&2;
}
die() {
  error "${1:-}"
  _log_write_error "$red[FATAL]$reset $*"
  printf '%s' "Now Exiting"
  for n in {1..13}; do
    printf '%s' '.'
  done
  exit 1
}
install_self() {
  local install_path="/usr/local/bin"
  local bin_name="one-click"
  local target="${install_path}/${bin_name}"
  if command -v "$bin_name" >/dev/null 2>&1; then
    return 0
  fi
  install -m 0755 "$0" "$target" 
}
# ==== End Immediate Initialization ==== #
# ==== Plain Text Security ====
init_secret_key() {
  secret_key="${base}.backup_secret.key" 
  cipher="aes-256-cbc"
  kdf_iter=100000
  if [[ ! -s "$secret_key" ]]; then
    umask 077
    openssl rand -base64 32 > "$secret_key"
  fi
}
encrypt_password() {
  local plaintext
  plaintext="$1"
  init_secret_key
  openssl enc -"$cipher" -a -salt \
    -pbkdf2 -iter "$kdf_iter" \
    -pass file:"$secret_key" <<< "$plaintext"
}
decrypt_password() {
  local encrypted
  encrypted="$1"
  init_secret_key
  openssl enc -"$cipher" -a -d \
    -pbkdf2 -iter "$kdf_iter" \
    -pass file:"$secret_key" <<< "$encrypted"
}
# ==== End Text Security ==== #
# ==== Main/Help Menu ====
dir_contents() {
  local dir menu
  dir="${1:-}"
  function_menu="${2:-}"
  clear
  (
    echo "FILE_PATH SIZE DATE"
    echo "------------- ---- ----"
    # Find directories up to 2 levels deep
    find "$dir" -maxdepth 2 -not -path '*/.*' -printf "%p %k %TY-%Tm-%Td\n" | 
    awk -v dir="$dir" '{
      # Remove the base directory path to make it cleaner
      sub(dir"/", "", $1); 
      if ($1 != dir) print $1, $2"KB", $3 
    }'
  ) | column -t
  sleep 3
  clear
  "$function_menu"
}
# ==== Trap Cleanup ====
cleanup() {
  rm -f "${trap[@]}"
  systemctl daemon-reexec
  systemctl daemon-reload
  if [[ -n "${TMUX:-}" ]]; then
    printf '%s\n' "To exit from TMUX, please type $(tput setab 4)exit${reset:-}"
    return
  fi
  if [[ -z "${TMUX:-}" ]]; then
    if tmux ls >/dev/null 2>&1; then
        printf '%s\n' "Detached TMUX session(s) detected. Reattach with: $(tput setab 4)tmux attach${reset:-} then type $(tput setab 4)exit${reset:-} to exit"
        return
    fi
  fi
}
trap cleanup EXIT
# ==== Directtory Listing ====
ls_table() {
  # ---- safety for set -euo pipefail ----
  set +u
  local dir="${1:-.}"
  # ===== UTF-8 detection =====
  local utf8=true
  [[ "${LC_ALL:-}${LANG:-}" =~ UTF-8|utf8 ]] || utf8=false
  # ===== Colors =====
  local blue reset
  blue="$(tput setaf 4 2>/dev/null || true)"
  reset="$(tput sgr0 2>/dev/null || true)"
  # ===== Borders =====
  local TL TR BL BR HL VL TM BM LM RM MM
  if $utf8; then
    TL="╔"; TR="╗"; BL="╚"; BR="╝"
    HL="═"; VL="║"
    TM="╦"; BM="╩"; LM="╠"; RM="╣"; MM="╬"
  else
    TL="+"; TR="+"; BL="+"; BR="+"
    HL="-"; VL="|"
    TM="+"; BM="+"; LM="+"; RM="+"; MM="+"
  fi
  # ===== UTF-8 safe repeat =====
  repeat() {
    local count="$1" char="$2" out=""
    for ((i=0; i<count; i++)); do
      out+="$char"
    done
    printf "%s" "$out"
  }
  # ===== Data arrays =====
  local names=() types=() sizes=() perms=()
  while IFS= read -r -d '' item; do
    local base
    base="$(basename "$item")"
    [[ "$base" =~ [0-9_] ]] || continue
    names+=( "$base" )
    if [[ -d "$item" ]]; then
      types+=(Directory)
    elif [[ -L "$item" ]]; then
      types+=(Symlink)
    else
      types+=(File)
    fi
    sizes+=( "$(stat -c '%s' "$item" 2>/dev/null || echo 0)" )
    perms+=( "$(stat -c '%A' "$item" 2>/dev/null || echo '?????????')" )
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)
  # ===== Minimum header widths =====
  local w_name=4 w_type=4 w_size=4 w_perm=5
  # ===== Compute content widths =====
  local i
  for i in "${!names[@]}"; do
    (( ${#names[i]} > w_name )) && w_name=${#names[i]}
    (( ${#types[i]} > w_type )) && w_type=${#types[i]}
    (( ${#sizes[i]} > w_size )) && w_size=${#sizes[i]}
    (( ${#perms[i]} > w_perm )) && w_perm=${#perms[i]}
  done
  # ===== Padding (1 space left + right) =====
  local pad=2
  local cw_name=$((w_name + pad))
  local cw_type=$((w_type + pad))
  local cw_size=$((w_size + pad))
  local cw_perm=$((w_perm + pad))
  # ===== Top border =====
  printf "%s%s%s%s%s%s%s%s%s\n" \
    "$blue$TL" "$(repeat "$cw_name" "$HL")" "$TM" \
    "$(repeat "$cw_type" "$HL")" "$TM" \
    "$(repeat "$cw_size" "$HL")" "$TM" \
    "$(repeat "$cw_perm" "$HL")" "$TR$reset"
  # ===== Header =====
  printf "%s %-${w_name}s %s %-${w_type}s %s %${w_size}s %s %-${w_perm}s %s\n" \
    "$blue$VL" "Name" "$VL" "Type" "$VL" "Size" "$VL" "Perms" "$VL$reset"
  # ===== Header separator =====
  printf "%s%s%s%s%s%s%s%s%s\n" \
    "$blue$LM" "$(repeat "$cw_name" "$HL")" "$MM" \
    "$(repeat "$cw_type" "$HL")" "$MM" \
    "$(repeat "$cw_size" "$HL")" "$MM" \
    "$(repeat "$cw_perm" "$HL")" "$RM$reset"
  # ===== Rows =====
  for i in "${!names[@]}"; do
    printf "%s %-${w_name}s %s %-${w_type}s %s %${w_size}s %s %-${w_perm}s %s\n" \
      "$blue$VL" "${names[i]}" "$VL" "${types[i]}" "$VL" \
      "${sizes[i]}" "$VL" "${perms[i]}" "$VL$reset"
  done
  # ===== Bottom border =====
  printf "%s%s%s%s%s%s%s%s%s\n" \
    "$blue$BL" "$(repeat "$cw_name" "$HL")" "$BM" \
    "$(repeat "$cw_type" "$HL")" "$BM" \
    "$(repeat "$cw_size" "$HL")" "$BM" \
    "$(repeat "$cw_perm" "$HL")" "$BR$reset"
  # ---- restore strict mode ----
  set -u
}
config_table() {
  set +u
  local cfg="$1"
  [[ -r "$cfg" ]] || { echo "Cannot read $cfg" >&2; return 1; }
  # ===== Colors =====
  local blue reset
  blue="$(tput setaf 4 2>/dev/null || true)"
  reset="$(tput sgr0 2>/dev/null || true)"
  # ===== UTF-8 borders =====
  local TL TR BL BR HL VL TM BM LM RM MM
  TL="╔"; TR="╗"; BL="╚"; BR="╝"
  HL="═"; VL="║"; TM="╦"; BM="╩"; LM="╠"; RM="╣"; MM="╬"
  repeat() {
    local count="$1" char="$2" out=""
    for ((i=0;i<count;i++)); do out+="$char"; done
    printf "%s" "$out"
  }
  # ===== Parse config =====
  local keys=() vals=() coms=()
  local w_key=3 w_val=5 w_com=7
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    IFS='#' read -r left comment <<< "$line"
    IFS='=' read -r key val <<< "$left"
    key="${key%%[[:space:]]*}"
    case "$key" in
      req) key="key_req" ;;
      pass) key="encrypted_password" ;;
      key) key="ssh_key_path" ;;
    esac
    keys+=("$key")
    vals+=("$val")
    coms+=("${comment:-}")
    (( ${#key} > w_key )) && w_key=${#key}
    (( ${#val} > w_val )) && w_val=${#val}
    (( ${#comment} > w_com )) && w_com=${#comment}
  done < "$cfg"
  # ===== Add padding =====
  local pad=2
  local cw_key=$((w_key + pad))
  local cw_val=$((w_val + pad))
  local cw_com=$((w_com + pad))
  # ===== Top =====
  printf "%s%s%s%s%s%s%s\n" \
    "$blue$TL" "$(repeat $cw_key $HL)" "$TM" \
    "$(repeat $cw_val $HL)" "$TM" \
    "$(repeat $cw_com $HL)" "$TR$reset"
  # ===== Header =====
  printf "%s %-${w_key}s %s %-${w_val}s %s %-${w_com}s %s\n" \
    "$blue$VL" "Key" "$VL" "Value" "$VL" "Comment" "$VL$reset"
  # ===== Header separator =====
  printf "%s%s%s%s%s%s%s\n" \
    "$blue$LM" "$(repeat $cw_key $HL)" "$MM" \
    "$(repeat $cw_val $HL)" "$MM" \
    "$(repeat $cw_com $HL)" "$RM$reset"
  # ===== Rows =====
  for i in "${!keys[@]}"; do
    printf "%s %-${w_key}s %s %-${w_val}s %s %-${w_com}s %s\n" \
      "$blue$VL" "${keys[i]}" "$VL" "${vals[i]}" "$VL" "${coms[i]}" "$VL$reset"
  done
  # ===== Bottom =====
  printf "%s%s%s%s%s%s%s\n" \
    "$blue$BL" "$(repeat $cw_key $HL)" "$BM" \
    "$(repeat $cw_val $HL)" "$BM" \
    "$(repeat $cw_com $HL)" "$BR$reset"
  set -u
}
# ==== Header/Banner ====
header_notice() {
  local header header_title header_banner
  header_title="${1:-}"
  header_banner="${2:-}"
  af="${3:-}"
  ab="${4:-}"
  header=$(printf "%s" "$header_title" | tr -d '\r' | sed $'s/\t/        /g')
  line_count=$(printf "%s\n" "$header" | wc -l)
  maxlen=0
  while IFS= read -r line; do
    len=${#line}
    (( len > maxlen )) && maxlen=$len
  done <<< "$header"
  start_row=$(( (rows - line_count) / 2 ))
  start_col=$(( (cols - maxlen) / 2 ))
  (( start_row < 0 )) && start_row=0
  (( start_col < 0 )) && start_col=0
  clear
  row=$start_row
  # ==== BANNER ====
  while IFS= read -r line; do
    printf -v padded "%-*s" "$maxlen" "$line"
    tput cup "$row" "$start_col"
    printf "%s\n" "$padded"
    ((row++))
  done <<< "$header"
  sleep 3
  clear
  offset=$(( (cols - ${#header_banner}) / 2 ))
  row=$(( rows / 2 ))
  tput cup "$row" "$offset"
  # ==== Notice Main ====
  while IFS= read -r line; do
    printf '%s' "$(tput setaf $af)$(tput setab $ab)${line//#/ }${reset}"
    sleep 0.1
  done < <(sed 's/./&\n/g' <<< "$header_banner")
  echo
  sleep 0.6
}
complete_migration_banner() {
  local len
  len="${#destination_server}"
  banner="\"=======MIGRATION TO $destination_server COMPLETE=======\""
  declare -A colors pads_M pads_E
  colors=(
    [14]="$red"
    [13]="$green"
    [12]="$warning"
    [11]="$blue"
    [10]="$(tput setaf 5)"
    [9]="$cyan"
    [8]="$(tput setaf 7)"
    [7]="$grey"
    [6]="$(tput setaf 9)"
  )
  pads_M=(
    [14]=""
    [13]=""
    [12]="="
    [11]="="
    [10]="=="
    [9]="=="
    [8]="==="
    [7]="==="
    [6]="===="
  )
  pads_E=(
    [14]=""
    [13]="="
    [12]="="
    [11]="=="
    [10]="=="
    [9]="==="
    [8]="==="
    [7]="===="
    [6]="===="
  )
  if [[ -n "${colors[$len]}" ]]; then
    banner="${colors[$len]}$(sed -E "s/(=M)/${pads_M[$len]}\1/;s/(E=)/\1${pads_E[$len]}/" <<< "$banner")${reset}"
  fi
}
# ==== End Initialization ==== #
# ==== IPv4 Validator ====
is_ipv4() {
  local ip=$1
  local IFS=.
  local -a octets=($ip)
  [[ ${#octets[@]} -eq 4 ]] || return 1
  for o in "${octets[@]}"; do
    [[ $o =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}
v4() {
  read -rp "Please enter the IP of the destination server: " destination_server
  if ! is_ipv4 "$destination_server"; then
    echo "The IP is ${red}INVALID${reset}! Please try again."
    v4
  fi
}
# ==== Ensure password is secure ====
password_strength() {
  local password
  password="${1:-}"
  # ==== Check pw length ====
  if [ ${#password} -le 7 ]; then
      error "${red}Weak${reset}: Password must be more than 7 characters."
      set_password
  fi
  # ==== Ensure uppercase present ====
  if ! [[ "$password" =~ [A-Z] ]]; then
      error "${red}Weak${reset}: Must contain at least one uppercase letter."
      set_password
  fi
  # ==== Ensure lowercase present ====
  if ! [[ "$password" =~ [a-z] ]]; then
      error "${red}Weak${reset}: Must contain at least one lowercase letter."
      set_password
  fi
  # ==== Ensure integers are present ====
  if [[ ! "$password" =~ [0-9] ]]; then
      error "${red}Weak${reset}: Must contain at least one digit."
      set_password
  fi
  # ==== Ensure special characters are present ====
  if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
      error "${red}Weak${reset}: Must contain at least one special character."
      set_password
  fi
  success "${green}Strong${reset}: Password meets all requirements."
  return 0
}
# ==== End Of Secure Password ==== #
# ==== Display Table For Boot Recovery ====
print_blue_table() {
  local dir="$1"
  local BLUE="\033[34m"
  local RESET="\033[0m"
  [[ -d "$dir" ]] || {
    echo "Directory not found: $dir" >&2
    return 1
  }
  # read entries safely
  mapfile -t rows < <(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
  (( ${#rows[@]} == 0 )) && {
    echo "No entries found in $dir"
    return 0
  }
  # calculate max width
  local max=0
  for r in "${rows[@]}"; do
    (( ${#r} > max )) && max=${#r}
  done
  # helper for padding
  pad() { printf "%-*s" "$max" "$1"; }
  # top border
  printf "${BLUE}┌────┬─%s─┐${RESET}\n" "$(printf '─%.0s' $(seq 1 $max))"
  local i=1
  for r in "${rows[@]}"; do
    printf "${BLUE}│ %2d │ ${RESET}%s${BLUE} │${RESET}\n" "$i" "$(pad "$r")"
    ((i++))
  done
  # bottom border
  printf "${BLUE}└────┴─%s─┘${RESET}\n" "$(printf '─%.0s' $(seq 1 $max))"
}
# ==== Log Browser ====
log_browser_menu() {
  header_notice "$log_title" "$log_banner" "12" "7"
  while true; do
    clear
    tput setaf 4; tput bold
    echo "╔════════════════════════════════════════════════╗"
    printf "║ %-46s ║\n" "One-Click Log Browser"
    echo "╠════════════════════════════════════════════════╣"
    printf "║ %-46s ║\n" " [1]. Browse Log Files"
    printf "║ %-46s ║\n" " [2]. Browse Journalctl (Services)"
    printf "║ %-46s ║\n" " [3]. Exit"
    echo "╚════════════════════════════════════════════════╝"
    tput sgr0
    read -rp "Select option: " choice
    case "$choice" in
      1) browse_files   ;;
      2) browse_journal ;;
      0) exit           ;;
    esac
  done
}
browse_files() {
  mapfile -t logs < <(
    sudo find / \
      \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
      -type f -name "*.log" -print 2>/dev/null
    )
    [[ ${#logs[@]} -eq 0 ]] && {
        warn "No logs found."
        read -rp "Press Enter to return..."
        return
  }
  list=()
  for file in "${logs[@]}"; do
    base=$(basename "$file")
    group="/$(echo "$file" | cut -d/ -f2)"
    if [[ "$file" == /var/log/one-click/* ]]; then
      priority="0"
      group="\033[1;34m$group\033[0m"
    else
      priority="1"
    fi
    list+=("$priority\t$group\t$base\t$file")
  done
  while true; do
    selected=$(
      printf "%b\n" "${list[@]}" \
      | sort -t$'\t' -k1,1 -k2,2 -k3,3 \
      | cut -f2- \
      | fzf \
          --ansi \
          --height=90% \
          --layout=reverse \
          --border \
          --delimiter=$'\t' \
          --with-nth=1,2 \
          --preview 'sudo tail -n 200 {3}' \
          --preview-window=right:60%:wrap \
          --expect=ctrl-d \
          --header="ENTER=open | CTRL-D=delete | Type to search"
    )
    [[ -z "$selected" ]] && return
    key=$(echo "$selected" | head -n1)
    line=$(echo "$selected" | tail -n1)
    file=$(echo "$line" | awk -F'\t' '{print $3}')
    if [[ "$key" == "ctrl-d" ]]; then
      read -rp "Delete $(basename "$file")? [y/N]: " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo rm -f "$file"
        error "Deleted."
        sleep 1
      fi
      continue
    fi
    sudo less -R "$file"
  done
}
browse_journal() {
  while true; do
    unit=$(systemctl list-units --type=service --no-legend \
      | awk '{print $1}' \
      | fzf \
        --height=85% \
        --border \
        --preview 'sudo journalctl -u {} -n 200 --no-pager' \
        --preview-window=right:60%:wrap \
        --header="ENTER=open | CTRL-C=back")
    [[ -z "$unit" ]] && return
    sudo journalctl -u "$unit" | less -R
  done
}
# ==== End Of Log Browser ====
create_service() {
  rsync_cmd="${1:-}"
  job="${2:-}"
  cat << EOF > "$service_file"
[Unit]
Description=Resumable RSYNC Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '
info "Resuming job: \$job"
\$rsync_cmd
rm -f "$service_file"
systemctl daemon-reload
success "Rsync job completed and service removed: \$job"
'
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable "$service_name"
}
wait_for_network() {
  while ! ping -c1 -W1 8.8.8.8 &>/dev/null; do
    echo "$(date) - Network down, waiting 10s..."
    sleep 10
  done
  info "Network detected. Starting rsync..."
}
remove_service() {
    if [[ -f "$service_file" ]]; then
        warn "Removing systemd service $service_file"
        sudo systemctl disable "$service_name" >/dev/null || true
        sudo rm -f "$service_file"
        sudo systemctl daemon-reload
    fi
}

