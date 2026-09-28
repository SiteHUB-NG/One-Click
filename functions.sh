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
# === Build: Jan 2026 === # === Updated: Aug 2026 == # == Version#: 1.2.0 ==== #
# ====== One-Click ====== #
if [[ -f "$log_dir" ]]; then
  mkdir -p "${log_dir:-}"
  touch "${log_error_file:-}" "${log_file:-}"
fi
sensitive_ports_file="/etc/one-click/rule-engine/.sensitive.ports"
# ==== Build Essential Variables ====
build_vars() {
  nic=$(echo "$nic" | tr -d '\r' | head -n 1 | xargs)
  if ip link show br0 &> /dev/null; then
    if ! grep 'DOWN' <(ip link show br0) &> /dev/null; then
      nic=br0
    fi
  fi
  mapfile -t local_drives < <(lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk"{print $1,$2}')
  drives=($(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'))
  sys_ip=$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic") | head -1)
  sys_ipv6=$(awk '/inet6/ && $NF=="global" || $(NF-1)=="global" {split($2,arr,"/");print arr[1]}' <(ip -6 a s "$nic") | head -1)
  ipv6_gw="$(awk '$1=="default" {print $3}' <(ip -6 r))"
  path="$(realpath "$0")"
  os_ping_cmd="$(ping -c2 -W2 8.8.8.8 2>/dev/null || ping -c2 -W2 2606:4700:4700::1111)"
  net_config="/root/migration_network_config.sh"
  wg_file="/etc/wireguard/wg0.conf"
  net_repair="/etc/systemd/system/net-reconfigure.service"
  reinstall="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
  reinstall_secondary="https://as214354.network/reinstall.sh"
  base_dir="/etc/one-click"
  backup_dir="$base_dir/backups"
  snaps_dir="$base_dir/network-repair/snapshots"
  config_dir="$base_dir/configuration"
  service_restore="$base_dir/network-repair/service.restore"
  fleet_root="/etc/one-click/fleet"
  #sys_ip="${sys_ip:-$(hostname -I | awk '{print $1}')}"
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
  recovery_banner="ONE#CLICK#BOOT#BACKUP#AND#RECOVERY#TOOL"
  cron_banner="ONE#CLICK#CRON#AUTOMATION"
  log_banner="ONE#CLICK#LOG#BROWSER"
  ocb_banner="ONE#CLICK#SYSTEM#PERFORMANCE#BENCHMARK"
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
	/tmp/net-test.txt
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
           | | | | '_ \ / _ \     | |   | | |/ __| |/ /
           | |_| | | | |  __/     | |___| | | (__|   <
            \___/|_| |_|\___|      \____|_|_|\___|_|\_\

 _   _      _                      _      ____                  _
| \ | | ___| |___      _____  _ __| | __ |  _ \ ___ _ __   __ _(_)_ __
|  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ / | |_) / _ \ '_ \ / _` | | '__|
| |\  |  __/ |_ \ V  V / (_) | |  |   <  |  _ <  __/ |_) | (_| | | |
|_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ |_| \_\___| .__/ \__,_|_|_|
                                                   |_|

EOF
  )
  ocb_header=$(cat <<'EOF'
  ___                    ____ _ _      _
 / _ \ _ __   ___       / ___| (_) ___| | __
| | | | '_ \ / _ \     | |   | | |/ __| |/ /
| |_| | | | |  __/     | |___| | | (__|   <
 \___/|_| |_|\___|      \____|_|_|\___|_|\_\

         ____                  _
        | __ )  ___ _ __   ___| |__
        |  _ \ / _ \ '_ \ / __| '_ \
        | |_) |  __/ | | | (__| | | |
        |____/ \___|_| |_|\___|_| |_|

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
  wp_title=$(cat <<'EOF'
          ___                ____ _ _      _
         / _ \ _ __   ___   / ___| (_) ___| | __
        | | | | '_ \ / _ \ | |   | | |/ __| |/ /
        | |_| | | | |  __/ | |___| | | (__|   <
         \___/|_| |_|\___|  \____|_|_|\___|_|\_\

__        __            _
\ \      / /__  _ __ __| |_ __  _ __ ___  ___ ___
 \ \ /\ / / _ \| '__/ _` | '_ \| '__/ _ \/ __/ __|
  \ V  V / (_) | | | (_| | |_) | | |  __/\__ \__ \
   \_/\_/ \___/|_|  \__,_| .__/|_|  \___||___/___/
                         |_|
EOF
  )
}
mkdir -p "$log_dir"
# ==== End Essential Variables ==== #
collect_sysinfo() {
  whois_ip="$(sed -En '/inet /{s,^[^/]* ([^/]*).*,\1,p}' <(ip a s "$nic"))"
  whois_ipv6=$(sed -En '/inet6.*global/{s,^[^/]* ([^/]*/[0-9]+).*,\1,p}' <(ip a s "$nic"))
  sys_ip="$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic"))"
  if [[ -n "$sys_ip" ]]; then
    api_response=$(curl -sL https://ipinfo.io/${whois_ip}/json || true)
    api_response2=$(curl -sL https://ip-api.com/json/${whois_ip} || true)
    ip_upstream="$(jq -r '.org' <<< $api_response)"
    ip_country="$(jq -r '.country' <<< $api_response)"
    ip_asn="$(awk '{print $1}' <(jq -r '.org' <<< $api_response))"
  else
    api_response=$(curl -sL curl -s "https://ip.guide/${whois_ip}" || true)
    ip_upstream="$(jq -r '.network.autonomous_system.organization' <<< $api_response)"
    ip_country="$(jq -r '.network.autonomous_system.country' <<< $api_response)"
    ip_asn="$(jq -r '.network.autonomous_system.asn' <<< $api_response)"
  fi
  sys_gw="$(awk '$1 == "default" {print $3}' <(ip r &> /dev/null)|head -1)"
  drive_cap="$(awk 'NR==2' <(lsblk -o size))"
  ns=($(awk '$1 !~ "#" && /nameserver/ {print $2}' /etc/resolv.conf ))
  cpu_model="$(lscpu | awk -F: '/^Model name/ {print $2}' | sed 's/^ *//')"
  cpu="$(nproc)"
  cpu_cores=$(nproc)
  freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq " MHz"}' /proc/cpuinfo | sed 's/^[ \t]*//')
  location=$(jq -r '.region' <<< $api_response)
  magenta=$(tput setaf 5)
  country="$ip_country"
  uptime=$(sed 's/up //' <(uptime -p))
  distro=$(awk -F= '/PRETTY_NAME/{print $2}' /etc/os-release)
  kernel=$(uname -r)
  ram=$(awk '/Mem/{print $2}' <(free -h))B
  swap=$(awk '/Swap/{print $2}' <(free -h))B
  disk=($(awk -v blue="$blue" -v yellow=$(tput setaf 11) -v reset="$reset" 'NR != 1 && $1 ~ /vd|sd|nvme|xvd|mmcblk/{sub("/.*/","",$1);print yellow $1 blue " - " $2"iB#"}' <(df -h) | column -t))
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
add_keep_path() {
  local path="$1"
  local keep="$2"
  [[ -z "$path" ]] && return 0
  path="$(readlink -f "$path" 2>/dev/null || true)"
  [[ -z "$path" ]] && return 0
  echo "$path" >> "$keep_file"
}
# ==== End Immediate Initialization ==== #
# ==== Plain Text Security ====
init_secret_key() {
  secret_key="${base}/.backup_secret.key"
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
    find "$dir" -maxdepth 2 -not -path '*/.*' -printf "%p %k %TY-%Tm-%Td\n" |
    awk -v dir="$dir" '{
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
  rm -rf /etc/one-click/ocb/geekbench_*
  if [[ -S /run/dbus/system_bus_socket ]]; then
    systemctl daemon-reexec &> /dev/null
    systemctl daemon-reload &> /dev/null
  fi
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
# =============================================== Country Mapping ===========================================
expand_country() {
  local code="${1^^}"
  case "$code" in
    AF) country="Afghanistan"                        ;;
    AL) country="Albania"                            ;;
    DZ) country="Algeria"                            ;;
    AS) country="American Samoa"                     ;;
    AD) country="Andorra"                            ;;
    AO) country="Angola"                             ;;
    AI) country="Anguilla"                           ;;
    AQ) country="Antarctica"                         ;;
    AG) country="Antigua and Barbuda"                ;;
    AR) country="Argentina"                          ;;
    AM) country="Armenia"                            ;;
    AW) country="Aruba"                              ;;
    AU) country="Australia"                          ;;
    AT) country="Austria"                            ;;
    AZ) country="Azerbaijan"                         ;;
    BS) country="Bahamas"                            ;;
    BH) country="Bahrain"                            ;;
    BD) country="Bangladesh"                         ;;
    BB) country="Barbados"                           ;;
    BY) country="Belarus"                            ;;
    BE) country="Belgium"                            ;;
    BZ) country="Belize"                             ;;
    BJ) country="Benin"                              ;;
    BM) country="Bermuda"                            ;;
    BT) country="Bhutan"                             ;;
    BO) country="Bolivia"                            ;;
    BA) country="Bosnia and Herzegovina"             ;;
    BW) country="Botswana"                           ;;
    BR) country="Brazil"                             ;;
    IO) country="British Indian Ocean Territory"     ;;
    VG) country="British Virgin Islands"             ;;
    BN) country="Brunei"                             ;;
    BG) country="Bulgaria"                           ;;
    BF) country="Burkina Faso"                       ;;
    BI) country="Burundi"                            ;;
    CV) country="Cabo Verde"                         ;;
    KH) country="Cambodia"                           ;;
    CM) country="Cameroon"                           ;;
    CA) country="Canada"                             ;;
    KY) country="Cayman Islands"                     ;;
    CF) country="Central African Republic"           ;;
    TD) country="Chad"                               ;;
    CL) country="Chile"                              ;;
    CN) country="China"                              ;;
    CX) country="Christmas Island"                   ;;
    CC) country="Cocos (Keeling) Islands"            ;;
    CO) country="Colombia"                           ;;
    KM) country="Comoros"                            ;;
    CG) country="Congo (Brazzaville)"                ;;
    CD) country="Congo (Kinshasa)"                   ;;
    CK) country="Cook Islands"                       ;;
    CR) country="Costa Rica"                         ;;
    CI) country="Côte d’Ivoire"                      ;;
    HR) country="Croatia"                            ;;
    CU) country="Cuba"                               ;;
    CW) country="Curaçao"                            ;;
    CY) country="Cyprus"                             ;;
    CZ) country="Czechia"                            ;;
    DK) country="Denmark"                            ;;
    DJ) country="Djibouti"                           ;;
    DM) country="Dominica"                           ;;
    DO) country="Dominican Republic"                 ;;
    EC) country="Ecuador"                            ;;
    EG) country="Egypt"                              ;;
    SV) country="El Salvador"                        ;;
    GQ) country="Equatorial Guinea"                  ;;
    ER) country="Eritrea"                            ;;
    EE) country="Estonia"                            ;;
    SZ) country="Eswatini"                           ;;
    ET) country="Ethiopia"                           ;;
    FK) country="Falkland Islands"                   ;;
    FO) country="Faroe Islands"                      ;;
    FJ) country="Fiji"                               ;;
    FI) country="Finland"                            ;;
    FR) country="France"                             ;;
    GF) country="French Guiana"                      ;;
    PF) country="French Polynesia"                   ;;
    GA) country="Gabon"                              ;;
    GM) country="Gambia"                             ;;
    GE) country="Georgia"                            ;;
    DE) country="Germany"                            ;;
    GH) country="Ghana"                              ;;
    GI) country="Gibraltar"                          ;;
    GR) country="Greece"                             ;;
    GL) country="Greenland"                          ;;
    GD) country="Grenada"                            ;;
    GP) country="Guadeloupe"                         ;;
    GU) country="Guam"                               ;;
    GT) country="Guatemala"                          ;;
    GG) country="Guernsey"                           ;;
    GN) country="Guinea"                             ;;
    GW) country="Guinea-Bissau"                      ;;
    GY) country="Guyana"                             ;;
    HT) country="Haiti"                              ;;
    HN) country="Honduras"                           ;;
    HK) country="Hong Kong"                          ;;
    HU) country="Hungary"                            ;;
    IS) country="Iceland"                            ;;
    IN) country="India"                              ;;
    ID) country="Indonesia"                          ;;
    IR) country="Iran"                               ;;
    IQ) country="Iraq"                               ;;
    IE) country="Ireland"                            ;;
    IM) country="Isle of Man"                        ;;
    IL) country="Israel"                             ;;
    IT) country="Italy"                              ;;
    JM) country="Jamaica"                            ;;
    JP) country="Japan"                              ;;
    JE) country="Jersey"                             ;;
    JO) country="Jordan"                             ;;
    KZ) country="Kazakhstan"                         ;;
    KE) country="Kenya"                              ;;
    KI) country="Kiribati"                           ;;
    KW) country="Kuwait"                             ;;
    KG) country="Kyrgyzstan"                         ;;
    LA) country="Laos"                               ;;
    LV) country="Latvia"                             ;;
    LB) country="Lebanon"                            ;;
    LS) country="Lesotho"                            ;;
    LR) country="Liberia"                            ;;
    LY) country="Libya"                              ;;
    LI) country="Liechtenstein"                      ;;
    LT) country="Lithuania"                          ;;
    LU) country="Luxembourg"                         ;;
    MO) country="Macau"                              ;;
    MG) country="Madagascar"                         ;;
    MW) country="Malawi"                             ;;
    MY) country="Malaysia"                           ;;
    MV) country="Maldives"                           ;;
    ML) country="Mali"                               ;;
    MT) country="Malta"                              ;;
    MH) country="Marshall Islands"                   ;;
    MQ) country="Martinique"                         ;;
    MR) country="Mauritania"                         ;;
    MU) country="Mauritius"                          ;;
    YT) country="Mayotte"                            ;;
    MX) country="Mexico"                             ;;
    FM) country="Micronesia"                         ;;
    MD) country="Moldova"                            ;;
    MC) country="Monaco"                             ;;
    MN) country="Mongolia"                           ;;
    ME) country="Montenegro"                         ;;
    MS) country="Montserrat"                         ;;
    MA) country="Morocco"                            ;;
    MZ) country="Mozambique"                         ;;
    MM) country="Myanmar"                            ;;
    NA) country="Namibia"                            ;;
    NR) country="Nauru"                              ;;
    NP) country="Nepal"                              ;;
    NL) country="Netherlands"                        ;;
    NC) country="New Caledonia"                      ;;
    NZ) country="New Zealand"                        ;;
    NI) country="Nicaragua"                          ;;
    NE) country="Niger"                              ;;
    NG) country="Nigeria"                            ;;
    NU) country="Niue"                               ;;
    KP) country="North Korea"                        ;;
    MK) country="North Macedonia"                    ;;
    MP) country="Northern Mariana Islands"           ;;
    NO) country="Norway"                             ;;
    OM) country="Oman"                               ;;
    PK) country="Pakistan"                           ;;
    PW) country="Palau"                              ;;
    PS) country="Palestine"                          ;;
    PA) country="Panama"                             ;;
    PG) country="Papua New Guinea"                   ;;
    PY) country="Paraguay"                           ;;
    PE) country="Peru"                               ;;
    PH) country="Philippines"                        ;;
    PN) country="Pitcairn Islands"                   ;;
    PL) country="Poland"                             ;;
    PT) country="Portugal"                           ;;
    PR) country="Puerto Rico"                        ;;
    QA) country="Qatar"                              ;;
    RE) country="Réunion"                            ;;
    RO) country="Romania"                            ;;
    RU) country="Russia"                             ;;
    RW) country="Rwanda"                             ;;
    BL) country="Saint Barthélemy"                   ;;
    SH) country="Saint Helena"                       ;;
    KN) country="Saint Kitts and Nevis"              ;;
    LC) country="Saint Lucia"                        ;;
    MF) country="Saint Martin"                       ;;
    PM) country="Saint Pierre and Miquelon"          ;;
    VC) country="Saint Vincent and the Grenadines"   ;;
    WS) country="Samoa"                              ;;
    SM) country="San Marino"                         ;;
    ST) country="Sao Tome and Principe"              ;;
    SA) country="Saudi Arabia"                       ;;
    SN) country="Senegal"                            ;;
    RS) country="Serbia"                             ;;
    SC) country="Seychelles"                         ;;
    SL) country="Sierra Leone"                       ;;
    SG) country="Singapore"                          ;;
    SX) country="Sint Maarten"                       ;;
    SK) country="Slovakia"                           ;;
    SI) country="Slovenia"                           ;;
    SB) country="Solomon Islands"                    ;;
    SO) country="Somalia"                            ;;
    ZA) country="South Africa"                       ;;
    KR) country="South Korea"                        ;;
    SS) country="South Sudan"                        ;;
    ES) country="Spain"                              ;;
    LK) country="Sri Lanka"                          ;;
    SD) country="Sudan"                              ;;
    SR) country="Suriname"                           ;;
    SE) country="Sweden"                             ;;
    CH) country="Switzerland"                        ;;
    SY) country="Syria"                              ;;
    TW) country="Taiwan"                             ;;
    TJ) country="Tajikistan"                         ;;
    TZ) country="Tanzania"                           ;;
    TH) country="Thailand"                           ;;
    TL) country="Timor-Leste"                        ;;
    TG) country="Togo"                               ;;
    TO) country="Tonga"                              ;;
    TT) country="Trinidad and Tobago"                ;;
    TN) country="Tunisia"                            ;;
    TR) country="Turkey"                             ;;
    TM) country="Turkmenistan"                       ;;
    TC) country="Turks and Caicos Islands"           ;;
    TV) country="Tuvalu"                             ;;
    UG) country="Uganda"                             ;;
    UA) country="Ukraine"                            ;;
	AE) country="United Arab Emirates"               ;;
    GB) country="United Kingdom"                     ;;
    US) country="United States"                      ;;
    UY) country="Uruguay"                            ;;
    UZ) country="Uzbekistan"                         ;;
    VU) country="Vanuatu"                            ;;
    VA) country="Vatican City"                       ;;
    VE) country="Venezuela"                          ;;
    VN) country="Vietnam"                            ;;
    WF) country="Wallis and Futuna"                  ;;
    EH) country="Western Sahara"                     ;;
    YE) country="Yemen"                              ;;
    ZM) country="Zambia"                             ;;
    ZW) country="Zimbabwe"                           ;;
    *) country="$code"                               ;;
  esac
}
# =========================================== End Country Mapping ====================================================== #
# ============================================= ONE CLICK BENCH ==========================================================
fio_cpu_benchmark() {
  local duration threads output usr_cpu sys_cpu
  duration=10
  threads=$(nproc)
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}%-20s %-15s %-15s %-15s${reset}\n" \
    "│Test" "Threads" "User CPU %" "Sys CPU %                                       │"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ Fio CPU Benchmark                                                                                │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"
  output=$(fio \
    --name=cpu-test \
    --ioengine=cpuio \
    --cpuload=100 \
    --cpuchunks=10000 \
    --numjobs="$threads" \
    --time_based \
    --runtime="$duration" \
    --group_reporting \
    --output-format=json)
  usr_cpu=$(echo "$output" | awk -F: '/"usr_cpu"/ {gsub(/[ ,]/, "", $2); print $2; exit}')
  sys_cpu=$(echo "$output" | awk -F: '/"sys_cpu"/ {gsub(/[ ,]/, "", $2); print $2; exit}')
  printf "${blue}%-20s %-15s %-15s %-15s${reset}\n" \
    "│CPU workload" "$threads" "${usr_cpu}%" "${sys_cpu}%                                       │"
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
}
install_geekbench() {
  local url path archive version
  url="$1"
  path="$2"
  version="$3"
  archive="/tmp/geekbench_${version}.tar.gz"
  mkdir -p "$path" || exit 1
  curl -fSL "$url" -o "$archive" &> /dev/null || {
    error "Download failed"
    exit 1
  }
  tar -xzf "$archive" \
    --strip-components=1 \
    -C "$path" &> /dev/null || {
    error "Extraction failed"
    exit 1
  }
  chmod +x "$path"/geekbench* 2>/dev/null || true
}
get_latest_gb() {
  local arch_name arch_suffix major minor patch url
  arch_name="${ARCH:-${arch:-$(uname -m)}}"
  if [[ "$arch_name" =~ (aarch64|arm64|armv7|arm) ]]; then
    arch_suffix="LinuxARMPreview"
  else
    arch_suffix="Linux"
  fi
  major="$1"
  for ((minor=9; minor>=0; minor--)); do
    for ((patch=9; patch>=0; patch--)); do
      url="https://cdn.geekbench.com/Geekbench-${major}.${minor}.${patch}-${arch_suffix}.tar.gz"
      if curl -fsI --connect-timeout 3 "$url" >/dev/null 2>&1; then
        echo "$url"
        return 0
      fi
    done
  done
  return 1
}
geekbench_results() {
  local target_arg="${1:-all}"
  local result_file="/etc/one-click/ocb/ocb_results.txt"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  [ -f "/etc/one-click/fleet/controller.env" ] && . "/etc/one-click/fleet/controller.env"
  local controller_host="${CONTROLLER_NAME}"
  local ssh_key=""
  if [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  elif [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  fi
  local ssh_opts=("-o" "ConnectTimeout=5" "-o" "StrictHostKeyChecking=no")
  [ -n "$ssh_key" ] && ssh_opts+=("-i" "$ssh_key")
  local targets=()
  if [[ "$target_arg" == "all" ]]; then
    if [ -f "$inventory_file" ]; then
      mapfile -t targets < <(awk '/hosts:/,/^[^ ]/' "$inventory_file" | awk -F':' '/^    [a-zA-Z0-9_-]+:/ {gsub(/[ :]/, "", $1); print $1}')
    else
      targets=("$controller_host")
    fi
  else
    targets=("$target_arg")
  fi
  local int_cl
  for target_host in "${targets[@]}"; do
    local target_ip="$target_host"
    if [ -f "$inventory_file" ]; then
      local inv_ip
      inv_ip="$(grep -A 5 "$target_host:" "$inventory_file" | grep "ansible_host" | head -n 1 | awk '{print $2}')"
      [ -n "$inv_ip" ] && target_ip="$inv_ip"
    fi
    local results=""
    if [[ "$target_host" == "$controller_host" ]]; then
      int_cl=$(tput setaf 250)
      t_cl="${cyan}"
      results=$(cat "$result_file" 2>/dev/null)
    else
      int_cl="$lime"
      t_cl="${blue}"
      results=$((ssh -tt "${ssh_opts[@]}" "oneclick@${target_ip}" "cat $result_file 2>/dev/null" 2>/dev/null | tr -d '\r')||true)
    fi
    if [[ "$target_host" == "$CONTROLLER_NAME" ]]; then
      target_host=Controller
    fi
    printf "${int_cl}%s\n" \
      "========================================================================================================" \
      "                        ${orange}GEEKBENCH RESULTS: ${t_cl}${target_host^^}${int_cl}                        " \
      "========================================================================================================"
    if [ -z "$results" ]; then
      echo -e "${yellow}No benchmark results found on $target_host ($target_ip).${reset}\n"
      continue
    fi
    (
      echo "TIMESTAMP | SINGLE-CORE | MULTI-CORE | VER | BENCHMARK URL"
      echo "--------- | ----------- | ---------- | --- | -------------"
      echo "$results" | awk -F'|' 'NF==5 {sub(" .*","",$1); sub(".*/","https://results.oneclick.i.ng/results/",$(NF-1));sub("$",".html",$(NF-1)); printf "%s | %s | %s | %s | %s\n", $1, $2, $3, $5, $4}'
    ) | column -t -s '|'
  done
}
geekbench_table() {
  local version gb_path url gb_url gb_run gb_cmd local_curl test_url scores single multi dl_cmd
  if command -v curl >/dev/null 2>&1; then
    dl_cmd="curl -sL"
  elif command -v wget >/dev/null 2>&1; then
    dl_cmd="wget -qO-"
  else
    error "Neither curl nor wget found."
    return
  fi
  version="$1"
  gb_path="$2"
  gb_url=""
  gb_cmd=""
  gb_run="False"
  results_file="/etc/one-click/ocb/ocb_results.txt"
  # ==== Detect package ====
  if [[ $version == "7" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench7"
    gb_run="True"
  elif [[ $version == "6" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench6"
    gb_run="True"
  elif [[ $version == "5" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    if [[ -f "$gb_path/geekbench_x86_64" ]]; then
        gb_cmd="geekbench_x86_64"
    else
        gb_cmd="geekbench5"
    fi
    gb_run="True"
  else
    return
  fi
  [[ "${gb_run:-}" != "True" ]] && return
  # ==== Print table header ====
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}%-20s %-20s %-54s${reset}\n" \
    "│Benchmark" "Version" "Result                                                     │"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ Geekbench Benchmark $version                                                                            │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"
  printf "${green}│ %-96s${reset}\r" "Preparing Geekbench $version."
  install_geekbench "$gb_url" "$gb_path" "$version"
  if [[ ! -x "$gb_path/$gb_cmd" ]]; then
    printf "${red}%s${reset}\n" \
      "│ Geekbench binary missing or not executable: $gb_path/$gb_cmd                                     │"
	printf "${yellow}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return
  fi
  gb_log=$(mktemp)
  printf "${yellow}│ %-96s${reset}\r" "${green}Running GB$version benchmark.${yellow}"
  echo
  set +e
  bash -c "$gb_path/$gb_cmd" > "$gb_log" 2> /gb_error || true
  output=$(< "$gb_log")
  rm -f $gb_log
  set -e
  if [[ -z "$output" || ! "$output" =~ succeeded ]]; then
    sed -E "s/[^:]*:(.*)/${red}[ERROR]${magenta} \1${reset}/" gb_error
    rm -f gb_error
    printf "${blue}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return 1
  fi
  test_url=$(grep -Eom1 'https://browser\.geekbench\.com[^[:space:]]+' <<< "$output" || true)
  if [[ -z "$test_url" ]]; then
    printf "${blue}%-20s %-20s %-54s${reset}\n" \
      "│Geekbench" "GB${version}" "${red}Failed${blue}                                                    │"
    printf "${blue}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return 1
  fi
  sleep 2
  gb_id=$(sed 's/.*\///' <<< "$test_url")
  api_response=$(curl -s \
    -X POST http://api.oneclick.i.ng:3000/v1/geekbench/score \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$gb_id\",\"version\":$version}")
  if [[ -z "$api_response" ]]; then
    error "API error: empty response"
    return 1
  fi
  single=$(jq -r '.benchmark.single' <<< "$api_response")
  multi=$(jq -r '.benchmark.multi' <<< "$api_response")
  if [[ "$single" == "null" ]]; then
    single=0
  fi
  if [[ "$multi" == "null" ]]; then
    multi=0
  fi
  timestamp=$(date '+%F %T')
  # ==== Build Config File ====
  echo "single=$single" > /etc/one-click/ocb/meta.conf
  echo "multi=$multi" >> /etc/one-click/ocb/meta.conf
  echo "gb_id=$gb_id" >> /etc/one-click/ocb/meta.conf
  echo "gb_url=$test_url" >> /etc/one-click/ocb/meta.conf
  echo "timestamp=\"$timestamp\"" >> /etc/one-click/ocb/meta.conf
  if [[ ! -f "$results_file" || ! -s "$results_file" ]]; then
    first_run=1
    echo "$timestamp|$single|$multi|$test_url|GB$version" >> "$results_file"
    printf "${blue}│${yellow}%-20s %-20s %-56s${blue}│${reset}\n" \
      "Benchmark Status" "GB$version" "First benchmark run recorded"
  else
    first_run=0
    last_line=$(tail -1 "$results_file")
    IFS='|' read -r old_date old_single old_multi old_url gb_version <<< "$last_line"
    single_diff=$((single - old_single))
    multi_diff=$((multi - old_multi))
	if [[ "$old_single" -ne 0 ]]; then
      single_pct=$(awk -v single="$single" -v old="$old_single" "BEGIN {
        if (old == 0)
          print 0;
        else
          printf \"%.2f\", ((single - old) / old) * 100
      }")
	else
	  single_pct=0
	fi
	if [[ "$old_multi" -ne 0 ]]; then
      multi_pct=$(awk -v multi="$multi" -v old="$old_multi" "BEGIN {
        if (old == 0)
          print 0;
        else
          printf \"%.2f\", ((multi - old) / old) * 100
      }")
	else
	  multi_pct=0
	fi
    if (( single_diff > 0 )); then
      single_trend="Improved"
      single_symbol="+"
    elif (( single_diff < 0 )); then
      single_trend="Degraded"
      single_symbol=""
    else
      single_trend="No Change"
      single_symbol=""
    fi
    if (( multi_diff > 0 )); then
      multi_trend="Improved"
      multi_symbol="+"
    elif (( multi_diff < 0 )); then
      multi_trend="Degraded"
      multi_symbol=""
    else
      multi_trend="No Change"
      multi_symbol=""
    fi
    echo "$timestamp|$single|$multi|$test_url|GB$version" >> "$results_file"
  fi
  if [[ "$single" -le 0 ]]; then
    single="Results blocked by Cloudflare"
  fi
  if [[ "$multi" -le 0 ]]; then
    multi="Results blocked by Cloudflare"
  fi
  printf "${blue}│${green}%-20s %-20s %-56s${blue}│${reset}\n" \
    "Single Core" "GB$version" "$single" \
    "Multi Core" "GB$version" "$multi" \
    "Result URL" "GB$version" "$test_url"
  if (( first_run == 0 )); then
    printf "${blue}│${magenta}%-20s %-20s %-56s${blue}│${reset}\n" \
      "Previous Test" "$gb_version" "$old_date" \
      "Prev Single Core" "$gb_version" "$old_single" \
      "Prev Multi Core" "$gb_version" "$old_multi" \
      "Single Trend" "$gb_version" \
      "$single_trend (${single_symbol}${single_diff}, ${single_symbol}${single_pct}%)" \
      "Multi Trend" "$gb_version" "$multi_trend (${multi_symbol}${multi_diff}, ${multi_symbol}${multi_pct}%)"
  fi
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
}
detect_disk_type() {
  local file dev base bw rotational type
  file=$1
  dev=$(df -P "$file" | awk 'NR==2 {print $1}')
  base=$(basename "$dev")
  base=$(lsblk -no pkname "$dev" 2>/dev/null || echo "$base")
  if [[ "$base" == nvme* ]]; then
    echo "NVMe"
    return
  fi
  if [[ "$base" =~ ^vda|^vdb|^sda|^loop ]]; then
    dyn_type=$(fio --name=tmp --filename="$file" --size=64M --bs=64k \
      --rw=read --iodepth=4 --runtime=3 --time_based \
      --group_reporting --direct=0 --output-format=json 2>/dev/null)
    dyn_type=$(sed -n '/^{/,$p' <<< "$dyn_type")
    if [[ -z "$dyn_type" || "$dyn_type" == "{}" ]]; then
      echo "Unknown"
      return
    fi
    bw=$(jq -r '.jobs[0].read.bw_bytes // 0' <<< "$dyn_type")
    if (( bw > 300*1024*1024 )); then
      type="SSD"
    else
      type="HDD"
    fi
  elif [[ -f "${rotational:-}" ]]; then
    if [[ $(<"${rotational:-}") -eq 0 ]]; then
      type="SSD"
    else
      type="HDD"
    fi
  fi
  echo "${type:-???}"
  return
}
score_bw() {
  local type value
  type=$1
  value=$2
  case "$type" in
    NVMe)
      (( $(awk "BEGIN {print ($value < 800)}") )) && echo red && return
      (( $(awk "BEGIN {print ($value < 2000)}") )) && echo orange && return
      echo green
    ;;
    SSD)
      (( $(awk "BEGIN {print ($value < 200)}") )) && echo red && return
      (( $(awk "BEGIN {print ($value < 450)}") )) && echo orange && return
      echo green
    ;;
    HDD)
      (( $(awk "BEGIN {print ($value < 80)}") )) && echo red && return
      (( $(awk "BEGIN {print ($value < 160)}") )) && echo orange && return
       echo green
    ;;
    *)
      echo reset
    ;;
  esac
}
score_iops() {
  local type value
  type=$1
  value=$2
  case "$type" in
    NVMe)
      (( value < 10000 )) && echo red && return
      (( value < 50000 )) && echo orange && return
      echo green
    ;;
    SSD)
      (( value < 5000 )) && echo red && return
      (( value < 20000 )) && echo orange && return
      echo green
    ;;
    HDD)
      (( value < 100 )) && echo red && return
      (( value < 300 )) && echo orange && return
      echo green
    ;;
    *)
      echo reset
    ;;
  esac
}
fio_disk_benchmark() {
  local fio_file size duration real disk_type
  fio_file="/var/cache/one-click/fio-test.img"
  size="512M"
  duration=10
  mkdir -p /var/cache/one-click
  truncate -s "$size" "$fio_file"
  real=$(df -P "$fio_file" | awk 'NR==2 {print $1}')
  disk_type=$(detect_disk_type "$real")
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}%-12s %-22s %-22s %-22s %-22s${reset}\n" \
    "│Block" "4k" "64k" "512k" "1m                 │"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ Fio Sequential Disk Benchmark (${blue}Performance Based Guess: ${cyan}${disk_type}${yellow})                                     │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"
  human_bw() {
    local mb value unit
    mb="$1"
    if awk "BEGIN {exit !($mb >= 1048576)}"; then
      value=$(awk "BEGIN {printf \"%.2f\", $mb/1048576}")
      unit="TB/s"
    elif awk "BEGIN {exit !($mb >= 1024)}"; then
      value=$(awk "BEGIN {printf \"%.2f\", $mb/1024}")
      unit="GB/s"
    else
      value=$(awk "BEGIN {printf \"%.2f\", $mb}")
      unit="MB/s"
    fi
    printf "%s %s" "$value" "$unit"
  }
  human_iops() {
    local raw num multiplier value
    raw="$1"
    num=$(printf '%s' "$raw" | sed -E 's/[^0-9.].*//')
    suffix=$(printf '%s' "$raw" | sed -E 's/[0-9.]+//')
    case "$suffix" in
      k|K) multiplier=1000       ;;
      m|M) multiplier=1000000    ;;
      g|G) multiplier=1000000000 ;;
      *)   multiplier=1          ;;
    esac
    value=$(awk -v n="$num" -v m="$multiplier" 'BEGIN {printf "%.0f", n*m}')
    if (( value >= 1000000000 )); then
      awk -v v="$value" 'BEGIN {printf "%.2fG", v/1000000000}'
    elif (( value >= 1000000 )); then
      awk -v v="$value" 'BEGIN {printf "%.2fM", v/1000000}'
    elif (( value >= 1000 )); then
      awk -v v="$value" 'BEGIN {printf "%.1fk", v/1000}'
    else
      printf "%d" "$value"
    fi
  }
  format_cell() {
    local mb iops bw_color iops_color k_iops human
    mb="$1"
    iops="$2"
    bw_color=$(score_bw "$disk_type" "$mb")
    iops_color=$(score_iops "$disk_type" "$iops")
    human=$(human_bw "$mb")
    k_iops=$(awk "BEGIN {printf \"%.1fk\", $iops/1000}")
    iops_human=$(human_iops "$k_iops")
    printf "%b%10s%b %b(%6s)%b" \
      "${!bw_color}" "$human" "$reset" \
      "${!iops_color}" "$iops_human" "$reset"
  }
  get_vals() {
  local bs mode json bw iops mb ioengine direct
  bs="$1"
  mode="$2"
  ioengine="libaio"
  direct=1
  json=$(fio \
    --name=test \
    --filename="$fio_file" \
    --size="$size" \
    --bs="$bs" \
    --rw="$mode" \
    --iodepth=64 \
    --ioengine="$ioengine" \
    --direct="$direct" \
    --runtime="$duration" \
    --time_based \
    --group_reporting \
    --output-format=json 2>/dev/null | sed -n '/^{/,$p')
  if [[ -z "$json" ]]; then
    json=$(fio \
      --name=test \
      --filename="$fio_file" \
      --size="$size" \
      --bs="$bs" \
      --rw="$mode" \
      --iodepth=1 \
      --ioengine=sync \
      --direct=0 \
      --runtime="$duration" \
      --time_based \
      --group_reporting \
      --output-format=json 2>/dev/null | sed -n '/^{/,$p')
  fi
  bw=$(jq -r ".jobs[0].$mode.bw_bytes // 0" <<< "$json" 2>/dev/null)
  iops=$(jq -r ".jobs[0].$mode.iops // 0" <<< "$json" 2>/dev/null)
  [[ -z "$bw" || "$bw" == "null" ]] && bw=0
  [[ -z "$iops" || "$iops" == "null" ]] && iops=0
  mb=$(awk -v b="$bw" 'BEGIN {printf "%.2f", b/1048576}')
  printf "%s %s" "$mb" "$iops"
}
  fio_status() {
    local msg="$1"
    local dots=("." ".." "..." "...." ".....")
    local int=$((3 % 5))
    tput el
    tput cuu1
    printf "${yellow}│$green %-96s ${blue}│${reset}\n" "${msg}${dots[$int]}"
  }
  sanitize_int() {
    local val="$1"
    val=$(printf '%s\n' "$val" | grep -oE '[0-9]+' | head -n1)
    [[ -z "$val" ]] && val=0
    echo "$val"
  }
  printf "\r${yellow}│$green %-96s${reset}\n" "Initializing Fio Benchmark.                                                                    ${yellow}│$reset"
  sleep 2
  fio_status "Running read test (4k)."
  read r4_bw r4_iops <<< "$(get_vals 4k read)"
  r4_iops=$(sanitize_int "$r4_iops")
  fio_status "Running read test (64k)."
  read r64_bw r64_iops <<< "$(get_vals 64k read)"
  r64_iops=$(sanitize_int "$r64_iops")
  fio_status "Running read test (512k)."
  read r512_bw r512_iops <<< "$(get_vals 512k read)"
  r512_iops=$(sanitize_int "$r512_iops")
  fio_status "Running read test (1m)."
  read r1m_bw r1m_iops <<< "$(get_vals 1m read)"
  r1m_iops=$(sanitize_int "$r1m_iops")
  fio_status "Running write test (4k)."
  read w4_bw w4_iops <<< "$(get_vals 4k write)"
  w4_iops=$(sanitize_int "$w4_iops")
  fio_status "Running write test (64k)."
  read w64_bw w64_iops <<< "$(get_vals 64k write)"
  w64_iops=$(sanitize_int "$w64_iops")
  fio_status "Running write test (512k)."
  read w512_bw w512_iops <<< "$(get_vals 512k write)"
  w512_iops=$(sanitize_int "$w512_iops")
  fio_status "Running write test (1m)."
  read w1m_bw w1m_iops <<< "$(get_vals 1m write)"
  w1m_iops=$(sanitize_int "$w1m_iops")
  # ==== Totals ====
  t4_bw=$(awk "BEGIN {print $r4_bw + $w4_bw}")
  t64_bw=$(awk "BEGIN {print $r64_bw + $w64_bw}")
  t512_bw=$(awk "BEGIN {print $r512_bw + $w512_bw}")
  t1m_bw=$(awk "BEGIN {print $r1m_bw + $w1m_bw}")
  t4_iops=$((r4_iops + w4_iops))
  t64_iops=$((r64_iops + w64_iops))
  t512_iops=$((r512_iops + w512_iops))
  t1m_iops=$((r1m_iops + w1m_iops))
  printf "\r"
  tput el
  tput cuu1
  tput el
  printf "%-10s\t%-22s\t%-22s\t%-22s\t%-22s${blue}│${reset}\n" \
    "${blue}│${reset}Read" \
    "$(format_cell "$r4_bw" "$r4_iops")" \
    "$(format_cell "$r64_bw" "$r64_iops")" \
    "$(format_cell "$r512_bw" "$r512_iops")" \
    "$(format_cell "$r1m_bw" "$r1m_iops")"
  printf "%-10s\t%-22s\t%-22s\t%-22s\t%-22s${blue}│${reset}\n" \
    "${blue}│${reset}Write" \
    "$(format_cell "$w4_bw" "$w4_iops")" \
    "$(format_cell "$w64_bw" "$w64_iops")" \
    "$(format_cell "$w512_bw" "$w512_iops")" \
    "$(format_cell "$w1m_bw" "$w1m_iops")"
  printf "%-10s\t%-22s\t%-22s\t%-22s\t%-22s${blue}│${reset}\n" \
    "${blue}│${reset}Total" \
    "$(format_cell "$t4_bw" "$t4_iops")" \
    "$(format_cell "$t64_bw" "$t64_iops")" \
    "$(format_cell "$t512_bw" "$t512_iops")" \
    "$(format_cell "$t1m_bw" "$t1m_iops")"
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
  rm -f "$fio_file"
}
iperf_locs=( \
  #"1500.mtu.he.net" "5201-5205" "HE Net" "San Jose, CA, US (10G)" "IPv4|IPv6" \
  "la.speedtest.clouvider.net" "5200-5209" "Clouvider" "Los Angeles, CA, US (10G)" "IPv4|IPv6" \
  "speedtest.nyc1.us.leaseweb.net" "5201-5210" "Leaseweb" "NYC, NY, US (10G)" "IPv4|IPv6" \
  "lon.speedtest.clouvider.net" "5200-5209" "Clouvider" "London, UK (10G)" "IPv4|IPv6" \
  "speedtest.milkywan.fr" "9200-9240" "Milkywan" "Ile-de-France, FR (40G)" "IPv4|IPv6" \
  "iperf-ams-nl.eranium.net" "5201-5210" "Eranium" "Amsterdam, NL (100G)" "IPv4|IPv6" \
  "speedtest.extra.telia.fi" "5201-5208" "Telia" "Helsinki, FI (10G)" "IPv4" \
  "iperf.angolacables.co.ao" "9200-9240" "Angola Cable" "Luanda, Angola, AO (10G)" "IPv4|IPv6" \
  "speedtest.sin1.sg.leaseweb.net" "5201-5210" "Leaseweb" "Singapore, SG (10G)" "IPv4|IPv6" \
  "154.31.113.6" "5201-5210" "DMIT" "Shinagawa, TY, JP (10G)" "IPv4|IPv6" \
  "speedtest.uztelecom.uz" "5200-5209" "Uztelecom" "Tashkent, UZ (10G)" "IPv4|IPv6" \
  "speedtest.sao1.edgoo.net" "9204-9240" "Edgoo" "Sao Paulo, BR (1G)" "IPv4|IPv6" \
)
iperf_locs_num=$((${#iperf_locs[@]} / 5))
iperf_cmd=$(command -v iperf3 || echo "iperf3")
iperf_test() {
  local host ports flags mode port out val unit
  host=$1
  ports=$2
  flags=$3
  mode=$4
  port=$(shuf -i "$ports" -n 1)
  if [[ "$mode" == "recv" ]]; then
    out=$(timeout 15 "$iperf_cmd" $flags -c "$host" -p "$port" -P 8 -R 2>/dev/null)
  else
    out=$(timeout 15 "$iperf_cmd" $flags -c "$host" -p "$port" -P 8 2>/dev/null)
  fi
  val=$(echo "$out" | grep SUM | awk '/receiver/{print $6}')
  unit=$(echo "$out" | grep SUM | awk '/receiver/{print $7}')
  [[ -z $val || "$val" == "0.00" ]] && val="busy" && unit=""
  echo "$val $unit"
}
iperf_table() {
  local mode flags host portsprovider loc send recv test_clr
  mode=$1
  test_clr=$(tput setaf 206)
  [[ "$mode" == "IPv6" ]] && flags="-6" || flags="-4"
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}%-15s %-30s %-20s %-20s %-15s${reset}\n" \
    "│Provider" "Location (Link)" "Send Speed" "Recv Speed" "Ping        │"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ iperf3 Network Speed Tests (${cyan}${mode}${yellow})                                                                │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"
  for (( i = 0; i < iperf_locs_num; i++ )); do
    host="${iperf_locs[i*5]}"
    ports="${iperf_locs[i*5+1]}"
    provider="${iperf_locs[i*5+2]}"
    loc="${iperf_locs[i*5+3]}"
    printf "\r${green}│ Running iperf3 test to %-70s${reset}" "$loc"
    send=$(iperf_test "$host" "$ports" "$flags" "send")
    recv=$(iperf_test "$host" "$ports" "$flags" "recv")
    ping_val=$(awk '/time=/{gsub(/.*time=/,""); print}' <(ping -c1 "$host" 2>/dev/null))
    [[ -z $ping_val ]] && ping_val="--- "
    print_row() {
      printf "\r${blue}%-15s ${test_clr}%-30s ${blue}%-20s %-20s %-15s${reset}\n" \
        "│$provider" "$loc" "$send" "$recv" "${ping_val:0:4}ms      │"
    }
    if [[ "$send" =~ "busy" && "$recv" =~ "busy" ]]; then
      print_row() {
        printf "\r${blue}%-15s ${test_clr}%-30s ${red}%-20s %-20s ${blue}%-15s${reset}\n" \
          "│$provider" "$loc" "$send" "$recv" "${ping_val:0:4}ms      │"
      }
    elif [[ "$send" =~ "busy" ]]; then
      print_row() {
        printf "\r${blue}%-15s ${test_clr}%-30s ${red}%-20s ${blue}%-20s %-15s${reset}\n" \
          "│$provider" "$loc" "$send" "$recv" "${ping_val:0:4}ms      │"
      }
    elif [[ "$recv" =~ "busy" ]]; then
      print_row() {
        printf "\r${blue}%-15s ${test_clr}%-30s ${blue}%-20s ${red}%-20s ${blue}%-15s${reset}\n" \
          "│$provider" "$loc" "$send" "$recv" "${ping_val:0:4}ms      │"
      }
    fi
    print_row
  done
  printf "${blue}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
}
is_online() {
  if ping -4 -c 1 -W 2 8.8.8.8 &>/dev/null; then
    return 0
  else
    return 1
  fi
}
is_v6_online() {
  if ping -6 -c 1 -W 2 2001:4860:4860::8888 &>/dev/null; then
    return 0
  else
    return 1
  fi
}
total_time() {
  local key_width val_width start_time end_time total_width inner_width border msg msg1 min sec time_taken
  key_width=15
  val_width=78
  start_time=$1
  end_time=$2
  result=$3
  key=$4
  total_width=$((key_width + val_width + 7))
  inner_width=$((total_width - 2))
  border=$(printf '─%.0s' $(seq 1 "$inner_width"))
  time_taken=$(( end_time - start_time ))
  echo "time_taken=$time_taken" >> /etc/one-click/ocb/meta.conf
  msg1="One-Click Bench completed in ${time_taken} sec"
  msg2="Publish URL: $result"
  if (( ${time_taken} > 60 )); then
	min=$(( time_taken / 60 ))
    sec=$(( time_taken % 60 ))
	msg="One-Click Bench completed in ${min} min ${sec} sec"
	printf "${blue}┌%s┐${reset}\n" "$border"
	if [[ -n "$key" ]]; then
      printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg2"
	fi
    printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg"
    printf "${blue}└%s┘${reset}\n" "$border"
  else
    printf "${blue}┌%s┐${reset}\n" "$border"
	if [[ -n "$key" ]]; then
	  printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg2"
	fi
    printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg1"
    printf "${blue}└%s┘${reset}\n" "$border"
  fi
  return
}
# ============================================= End One-Click Bench ========================================= #
# ================================================= Fleet =================================================== #
fleet_init() {
  build_vars
  install_dep "bc" "command -v bc" "bc" "$pkg_mgr" true
  local_host=$(hostname -s)
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  build_vars
  info "Initialising Fleet and dependancies."
  mkdir -p \
    "$fleet_root/state" \
    "$fleet_root/playbooks" \
    "$fleet_root/keys" \
    "$fleet_root/audits" \
    "$fleet_root/benchmarks"
  fleet_write_inventory
  if [[ ! -f "$fleet_root/controller.env" ]]; then
    # ==== I must be the controller ====
    info "First-run setup detected. Establishing this machine as the central Fleet Controller."
    cat > "$fleet_root/controller.env" <<EOF
CONTROLLER_IP="${sys_ip:-${sys_ipv6}}"
CONTROLLER_NAME="$(hostname -s)"
ROLE_TYPE="controller"
IS_MASTER="true"
EOF
    . "$fleet_root/controller.env"
  fi
  mkdir -p $(dirname "$inventory_json")
  if ! command -v ansible >/dev/null 2>&1; then
    info "Installing Ansible"
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get install -y ansible
    elif command -v dnf >/dev/null 2>&1; then
      if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "rhel" || "$ID_LIKE" =~ "rhel" || "$ID_LIKE" =~ "centos" ]]; then
          info "RHEL family tree ecosystem detected ($PRETTY_NAME)."
          if ! command -v ansible &>/dev/null; then
            info "Ansible missing. Installing EPEL from source."
            local major_ver=$(echo "$VERSION_ID" | cut -d. -f1)
            dnf install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major_ver}.noarch.rpm" -y
            dnf makecache
            dnf install -y ansible-core || true
          else
            success "Ansible execution engine is already operational."
          fi
          return 0
        fi
      fi
    else
      error "Unsupported package manager"
      return 1
    fi
	if [[ -f "$fleet_root/state/${local_host}.conf" ]]; then
      source "$fleet_root/state/${local_host}.conf"
      if [[ -n "${NODE_PUBKEY:-}" ]]; then
        bash /etc/one-click/write_inventory.sh
        fleet_write_playbooks
        touch "$fleet_root/.initialized"
        success "Fleet initialized!"
        return 0
      fi
    fi
  fi
  [[ -f "$fleet_root/.initialized" ]] && return
  if [[ ! -f "$fleet_root/keys/id_ed25519" ]]; then
    ssh-keygen \
      -t ed25519 \
      -N "" \
      -f "$fleet_root/keys/id_ed25519"
  fi
  pubkey=$(tr -d '\n' < "$fleet_root/keys/id_ed25519.pub")
  if ! id "oneclick" &>/dev/null; then
    info "Creating 'oneclick' service account on $(hostname -s)."
    useradd -m -s /bin/bash oneclick
  fi
  mkdir -p /home/oneclick/.ssh
  mkdir -p /home/oneclick/.ansible/tmp
  if ! grep -qF "$pubkey" /home/oneclick/.ssh/authorized_keys 2>/dev/null; then
    echo "$pubkey" >> /home/oneclick/.ssh/authorized_keys
  fi
  chown -R oneclick:oneclick /home/oneclick/.ssh
  chown -R oneclick:oneclick /home/oneclick/.ansible
  chmod 700 /home/oneclick/.ssh
  chmod 700 /home/oneclick/.ansible /home/oneclick/.ansible/tmp
  chmod 600 /home/oneclick/.ssh/authorized_keys
  if [[ ! -f /etc/sudoers.d/oneclick ]]; then
    echo 'oneclick ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/oneclick
    chmod 440 /etc/sudoers.d/oneclick
  fi
  if [[ ! -f "$fleet_root/state/${local_host}.conf" ]]; then
    cat > "$fleet_root/state/${local_host}.conf" << EOF
HOSTNAME=$(hostname -s)
IP=${sys_ip:-${sys_ipv6}}
PUBKEY="$pubkey"
PORT=22
EOF
  fi
  bash /etc/one-click/write_inventory.sh
  fleet_write_playbooks
  touch "$fleet_root/.initialized"
  success "Fleet initialized!"
}
flbench_launch() {
  version="${1:-}"
  rm -f \
    /etc/one-click/ocb/benchmarks/COMPLETE \
    /etc/one-click/ocb/benchmarks/job.state \
    /etc/one-click/ocb/benchmarks/latest.json
	cat > /etc/one-click/flbench.sh << EOF
#!/bin/bash
# Written by Chike Egbuna for One-Click Toolkit
nohup sudo /bin/bash -c "/usr/local/bin/one-click fl "${version:-}" >> /var/log/one-click/one-click-bench-stream.log 2>&1" &
echo "STARTED" | sudo tee /etc/one-click/ocb/benchmarks/job.state
EOF
  sudo chmod +x /etc/one-click/flbench.sh
  sudo bash /etc/one-click/flbench.sh &
  sleep 1
  sudo rm -f /etc/one-click/flbench.sh
}
fleet_write_inventory() {
  mkdir -p "$base"
  cat > /etc/one-click/write_inventory.sh <<'EOF'
#!/usr/bin/env bash
# Written by Chike Egbuna for One-Click Toolkit
role_type="${1:-}"
private_ip="${2:-}"
fleet_static_root="/etc/one-click/fleet"
inventory="/etc/one-click/fleet/inventory.yml"
if [[ -f "$fleet_static_root/controller.env" ]]; then
  source "$fleet_static_root/controller.env"
fi
nic=$(ip route show default | awk '{print $5}')
if [[ -z "$nic" ]]; then
  nic=$(awk '{print $5}' <(ip -6 r s default))
fi
if ip link show br0 &> /dev/null; then
  if ! grep -q 'DOWN' <(ip link show br0); then
    nic=br0
  fi
fi
current_system_ip="$(awk '$1 == "inet" { split($2, arr, "/"); print arr[1] }; $1 == "inet6" { split($2, arr, "/"); print arr[1] }' <(ip a s "$nic") | head -1)"

if [[ -n "${CONTROLLER_IP:-}" ]]; then
  if [[ "$current_system_ip" != "$CONTROLLER_IP" ]]; then
    exit 0
  fi
fi
local_hostname=$(hostname -s)
live_wg_pubkey=""
if ip link show dev one-click &>/dev/null; then
  live_wg_pubkey=$(wg show one-click public-key 2>/dev/null || true)
  if [[ -n "$live_wg_pubkey" ]]; then
    echo "$live_wg_pubkey" > /etc/wireguard/oc_public.key
  fi
fi
if [[ -z "$live_wg_pubkey" && -f /etc/wireguard/oc_public.key ]]; then
  live_wg_pubkey=$(cat /etc/wireguard/oc_public.key)
fi
discovered_controller=""
for f in "$fleet_static_root"/state/*.conf; do
  [[ ! -f "$f" ]] && continue
  if ! grep -q '^HOSTNAME=' "$f" || ! grep -q '^IP=' "$f"; then
    continue
  fi
  if ! grep -q '^NODE_PUBKEY=' "$f"; then
    discovered_controller=$(basename "$f" .conf)
    break
  fi
done
node_private_key_path="/etc/one-click/fleet/keys/id_ed25519"
if [[ -f "$fleet_static_root/state/${local_hostname}.conf" ]]; then
  source "$fleet_static_root/state/${local_hostname}.conf"
  if [[ -n "${NODE_PUBKEY:-}" ]]; then
    node_private_key_path="/home/oneclick/.ssh/id_ed25519"
  fi
fi
cat > "$inventory" <<EOA
all:
  vars:
    ansible_user: oneclick
    ansible_become: true
    ansible_ssh_private_key_file: $node_private_key_path
  hosts:
EOA
master_pubkey=""
if [[ -n "$discovered_controller" && -f "$fleet_static_root/state/${discovered_controller}.conf" ]]; then
  master_pubkey=$(grep -w '^PUBKEY' "$fleet_static_root/state/${discovered_controller}.conf" | cut -d'"' -f2)
fi
if [[ -z "$master_pubkey" && -f "$fleet_static_root/keys/id_ed25519.pub" ]]; then
  master_pubkey=$(tr -d '\n' < "$fleet_static_root/keys/id_ed25519.pub")
fi
declare -A seen_ips
for file in /etc/one-click/fleet/state/*.conf; do
  [[ ! -f "$file" ]] && continue
  if ! grep -q '^HOSTNAME=' "$file" || ! grep -q '^IP=' "$file"; then
    continue
  fi
  if grep -q '^NODE_PUBKEY=' "$file"; then
     ip=$(grep '^IP=' "$file" | cut -d= -f2-)
     [[ -n "$ip" ]] && seen_ips[$ip]="$file"
  fi
done
for file in /etc/one-click/fleet/state/*.conf; do
  [[ ! -f "$file" ]] && continue
  if ! grep -q '^HOSTNAME=' "$file" || ! grep -q '^IP=' "$file"; then
    continue
  fi
  filename=$(basename "$file" .conf)
  host=$(grep '^HOSTNAME=' "$file" | cut -d= -f2-)
  ip=$(grep '^IP=' "$file" | cut -d= -f2-)
  port=$(grep '^PORT=' "$file" | cut -d= -f2-)
  [[ -z "$port" ]] && port=22
  [[ -z "$host" || -z "$ip" || "$host" == ":" ]] && continue
  if [[ -n "${seen_ips[$ip]}" && "${seen_ips[$ip]}" != "$file" && "$filename" != "$discovered_controller" ]]; then
     continue
  fi
  sed -Ei "/^HOSTNAME=/s/=.*/=$filename/" "$file"
  inventory_name="$filename"
  if grep -q '^NODE_PUBKEY=' "$file"; then
    node_key=$(grep '^NODE_PUBKEY=' "$file" | cut -d'"' -f2)
    if grep -qw '^PUBKEY' "$file"; then
      sed -Ei "s|^PUBKEY=.*|PUBKEY=\"$node_key\"|" "$file"
    else
      echo "PUBKEY=\"$node_key\"" >> "$file"
    fi
  else
    if [[ -n "$master_pubkey" && "$filename" == "$discovered_controller" ]]; then
      if grep -qw '^PUBKEY' "$file"; then
        sed -Ei "s|^PUBKEY=.*|PUBKEY=\"$master_pubkey\"|" "$file"
      else
        echo "PUBKEY=\"$master_pubkey\"" >> "$file"
      fi
    fi
  fi
  if [[ "$filename" == "$discovered_controller" && -n "$live_wg_pubkey" ]]; then
    if grep -q '^WG_PUBKEY=' "$file"; then
      sed -Ei "s|^WG_PUBKEY=.*|WG_PUBKEY=\"$live_wg_pubkey\"|" "$file"
    else
      echo "WG_PUBKEY=\"$live_wg_pubkey\"" >> "$file"
    fi
  fi
  target_ip="$ip"
  if [[ "$role_type" == "vps-peer" && "$filename" == "$local_hostname" ]]; then
    if [[ "$public_ip" == "" ]]; then
      target_ip="$private_ip"
    else
      target_ip="$public_ip"
    fi
  fi
  cat >> "$inventory" <<EOB
    $inventory_name:
      ansible_host: ${target_ip}
      ansible_port: $port
EOB
done
EOF
  chmod 755 /etc/one-click/write_inventory.sh
}
generate_node_credentials() {
  local node_name="$1"
  local node_state_file="$fleet_root/state/${node_name}.conf"
  local tmp_key_dir="/tmp/keys_${node_name}"
  mkdir -p "$tmp_key_dir"
  ssh-keygen -t ed25519 -N "" -f "$tmp_key_dir/id_ed25519" >/dev/null
  local private_b64 public_raw
  private_b64=$(base64 -w0 < "$tmp_key_dir/id_ed25519")
  public_raw=$(cat "$tmp_key_dir/id_ed25519.pub")
  cat >> "$node_state_file" <<EOF
NODE_PUBKEY="${public_raw}"
NODE_PRIVKEY_B64="${private_b64}"
EOF
  rm -rf "$tmp_key_dir"
}
fleet_migrate_controller() {
  local target_destination="$1"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local backup_ledger="/etc/one-click/virtualization/backup_ledger.json"
  local snapshot_ledger="/etc/one-click/virtualization/snapshot_ledger.json"
  local state_dir="/etc/one-click/state"
  if [[ -f "/etc/one-click/fleet/controller.env" ]]; then
    . "/etc/one-click/fleet/controller.env"
  else
    error "Missing core controller configuration profiles. Migration halted."
    return 1
  fi
  if [[ -z "$target_destination" ]]; then
    error "No target destination node specified."
    return 1
  fi
  if [[ "$target_destination" == "$CONTROLLER_NAME" ]]; then
    error "Target destination matches the current active controller. Migration Aborted."
    return 1
  fi
  info "Resolving target destination networking routes."
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  if [[ ! -f "$private_key" ]]; then
    private_key="/home/oneclick/.ssh/id_ed25519"
  fi
  local target_ip
  target_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$target_destination" 2>/dev/null | jq -r '.ansible_host // empty' | tr -d '[:space:]')
  if [[ -z "$target_ip" ]]; then
    target_ip="$target_destination"
  fi
  if ! ping -c 1 -W 2 "$target_ip" &>/dev/null; then
    error "Target node [$target_destination] ($target_ip) is unreachable. Aborting migration."
    return 1
  fi
  warn "${orange}CRITICAL ACTION INITIATED:${reset} Promoting cluster control to [$target_destination] ($target_ip)."
  read -p "${cyan}[USER]${reset} Are you absolutely sure you want to transfer controller authority? (y|n): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
    info "Migration canceled by operator."
    return 0
  fi
  sync_custom_ssh_keys "$target_ip" "$private_key"
  info "Staging WireGuard configurations for migration."
  sudo mkdir -p /etc/one-click/sync/wireguard
  cp -f /etc/wireguard/{one-click.conf,oc_*.key} /etc/one-click/sync/wireguard/ 2>/dev/null || true
  info "Demoting current wireguard controller"
  sed -Ei "s/${target_destination}/$(hostname -s)/g;" /etc/one-click/sync/wireguard/one-click.conf 2>/dev/null || true
  info "Packaging controller database, state logs, WireGuard assets, and automation playbooks."
  local migration_archive="/tmp/one-click-master-migration.tar.gz"
  rm -f "$migration_archive"
  local tar_targets=(
    "/etc/one-click/virtualization/allocated_ports.db"
    "/etc/one-click/fleet/inventory.yml"
    "/etc/one-click/fleet/playbooks"
    "/etc/one-click/fleet/keys"
    "/etc/one-click/virtualization/inventory.json"
    "/etc/one-click/virtualization/available_ips.txt"
    "/etc/one-click/virtualization/used_ips.txt"
    "/etc/one-click/virtualization/ports_pool.txt"
    "/etc/one-click/sync/wireguard"
  )
  mkdir -p /etc/one-click/sync
  [[ -f "$backup_ledger" ]] && raw_targets+=("${backup_ledger#/}")
  [[ -f "$snapshot_ledger" ]] && raw_targets+=("${snapshot_ledger#/}")
  [[ -d "$state_dir" ]] && raw_targets+=("etc/one-click/fleet/state")
  local valid_targets=()
  for path in "${raw_targets[@]}"; do
    if [[ -e "/$path" ]]; then
      tar_targets+=("$path")
    fi
  done
  if [[ ${#tar_targets[@]} -eq 0 ]]; then
    error "No valid controller configuration files found to archive."
    return 1
  fi
  tar --ignore-failed-read -czf "$migration_archive" -C / "${tar_targets[@]}" 2>/dev/null
  info "Pushing controller configuration to new master controller."
  cat "$migration_archive" | ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "cat > /tmp/migration.tar.gz"
  local transition_func
  transition_func=$(declare -f apply_node_firewall_transition)
  info "Unpacking states, modifying firewall, and elevating [$target_destination] to active cluster master."
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -s" << EOF
    $transition_func
    if ! command -v ansible &>/dev/null && command -v ansible-inventory &>/dev/null; then
      echo "${blue}[INFO]${reset} Ansible not found. Installing package on $target_destination."
      if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq ansible
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y -q ansible-core || sudo dnf install -y -q ansible
      elif command -v yum &>/dev/null; then
        sudo yum install -y -q ansible
      else
        echo "${red}[ERROR]${reset} Unable to detect package manager to install Ansible."
        return
      fi
    fi
    if ! command -v ansible &>/dev/null; then
      echo "${red}[ERROR]${reset} Ansible installation failed or binary is missing from PATH."
      return 1
    fi
    sudo mkdir -p /etc/one-click/sync
    sudo tar -xzf /tmp/migration.tar.gz -C /
    rm -f /tmp/migration.tar.gz
    if [[ -f /etc/wireguard/one-click.conf ]]; then
      sudo systemctl stop wg-quick@one-click 2>/dev/null || true
      mkdir -p /tmp/wireguard
      sudo mv -f /etc/wireguard/one-click.conf /tmp/wireguard/one-click.conf
      sudo sed -Ei 's/^(Endpoint = )[^:]*/\1${target_ip}/' /tmp/wireguard/one-click.conf 2>/dev/null || true
    fi
    if [[ -d /etc/one-click/sync/wireguard ]]; then
      sudo systemctl stop wg-quick@one-click 2>/dev/null || true
      sudo mkdir -p /etc/wireguard
      sudo cp -f /etc/one-click/sync/wireguard/* /etc/wireguard/ 2>/dev/null || true
      sudo chmod 600 /etc/wireguard/* 2>/dev/null || true
      sudo systemctl enable wg-quick@one-click 2>/dev/null || true
      sudo systemctl restart wg-quick@one-click 2>/dev/null || true
    fi
    sudo tee /etc/one-click/fleet/identity.conf > /dev/null <<EOT
ROLE=peer
FLEET_IDENTITY=\$(hostname)
STATUS=active
CONTROLLER_TARGET_IP=127.0.0.1
LAST_SYNC=\$(date +%s)
EOT
    sudo tee /etc/one-click/fleet/controller.env > /dev/null <<EOT
CONTROLLER_IP="${target_ip}"
CONTROLLER_NAME="${target_destination}"
ROLE_TYPE="controller"
IS_MASTER="true"
EOT
    apply_node_firewall_transition "promote_to_master" "${target_ip}"
EOF
  info "Grabbing new controller $(hostname -s)'s wireguard conf"
  scp -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}":/tmp/wireguard/one-click.conf /etc/wireguard/one-click.conf 2>/dev/null || true
  info "Updating WireGuard endpoints and configurations across remaining fleet peers."
  local fleet_hosts
  fleet_hosts=$(ansible all --list-hosts -i "$inventory_file" 2>/dev/null | grep -v "hosts (" | awk '{print $1}')
  for node in $fleet_hosts; do
    [[ "$node" == "$target_destination" || "$node" == "$CONTROLLER_NAME" ]] && continue
    local node_ip
    node_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$node" 2>/dev/null | jq -r '.ansible_host // empty' | tr -d '[:space:]')
    [[ -z "$node_ip" ]] && continue
    [[ "$node_ip" == "${sys_ip:-${sys_ipv6}}" ]] && continue
    if ! ping -c 1 -W 2 "$node_ip" &>/dev/null; then
      warn "Peer node [$node] ($node_ip) is unreachable. Skipping peer update."
      continue
    fi
    info "Updating Promoted WireGuard Controller endpoint and controller metadata on peer [$node] ($node_ip)."
    ssh -i "$private_key" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "oneclick@${node_ip}" "sudo bash -s" << EOF || { warn "Failed to update peer [$node] ($node_ip) over SSH. Moving to next node."; continue; }
      if [ -f /etc/one-click/fleet/controller.env ]; then
        sudo sed -i '/^CONTROLLER_IP=/d;/^CONTROLLER_NAME=/d;/^IS_MASTER=/d' /etc/one-click/fleet/controller.env
        echo "CONTROLLER_IP=\"${target_ip}\"" | sudo tee -a /etc/one-click/fleet/controller.env > /dev/null
        echo "CONTROLLER_NAME=\"${target_destination}\"" | sudo tee -a /etc/one-click/fleet/controller.env > /dev/null
        echo "IS_MASTER=\"false\"" | sudo tee -a /etc/one-click/fleet/controller.env > /dev/null
      fi
      if [ -f /etc/wireguard/one-click.conf ]; then
        sudo sed -Ei 's/^(Endpoint = )[^:]/\1${target_ip}/' /etc/wireguard/one-click.conf
        sudo systemctl restart wg-quick@one-click 2>/dev/null || true
      fi
      if ! sudo iptables -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
        sudo nft add table ip filter 2>/dev/null || true
        sudo nft add chain ip filter ONE-CLICK-FLEET 2>/dev/null || true
        if ! sudo nft list chain ip filter ONE-CLICK-FLEET 2>/dev/null | grep -q "ip saddr ${target_ip} tcp dport 22 accept"; then
          sudo nft insert rule ip filter ONE-CLICK-FLEET index 1 ip saddr "${target_ip}" tcp dport 22 accept 2>/dev/null || true
        fi
      else
        sudo iptables -N ONE-CLICK-FLEET 2>/dev/null || true
        sudo iptables -C ONE-CLICK-FLEET -s "${target_ip}" -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
        sudo iptables -I ONE-CLICK-FLEET 1 -s "${target_ip}" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
      fi
EOF
  done
  sudo tee /etc/one-click/fleet/identity.conf > /dev/null <<EOF
ROLE=peer
FLEET_IDENTITY=$(hostname | tr -d '[:space:]')
STATUS=managed
CONTROLLER_TARGET_IP=$target_ip
LAST_SYNC=$(date +%s)
EOF
  sudo tee /etc/one-click/fleet/controller.env > /dev/null <<EOF
CONTROLLER_IP="${target_ip}"
CONTROLLER_NAME="${target_destination}"
ROLE_TYPE="hypervisor-peer"
ORIGINAL_ROLE_TYPE="$ROLE_TYPE"
IS_MASTER="false"
EOF
  apply_node_firewall_transition "demote_to_peer" "$target_ip"
  info "Purging local assets."
  rm -rf /etc/one-click/sync/wireguard
  rm -f "$migration_archive"
  success "Migration process completed successfully!"
  success "Master dominance and WireGuard controller authority securely transferred to [$target_destination] ($target_ip)."
  warn "This node has dropped its encryption keyways and is operating as a standard cluster member."
}
fleet_rule_engine() {
  fleet_init
  build_vars
  . "$fleet_root/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    error "Security Block: Rule broadcasting must be initiated from the central Fleet Controller."
    return 1
  fi
  local target_host="$1"
  local rule_command="$2"
  for host_conf in "$fleet_root"/state/*.conf; do
    [[ ! -f "$host_conf" ]] && continue
    local current_slug
    current_slug=$(basename "$host_conf")
    local solved_ip
    solved_ip=$(grep '^IP=' "$host_conf" | cut -d= -f2-)
    if [[ -n "$solved_ip" ]]; then
      if [[ " $rule_command " =~ [[:space:]]${current_slug//.*}[[:space:]] ]]; then
        info "Resolving fleet name '${current_slug//.*}' to IP: ${solved_ip}"
        rule_command=$(echo "$rule_command" | sed "s/${current_slug//.*}/${solved_ip}/g")
      fi
    fi
  done
  if [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
    load_rule_engine
    rule_engine "$rule_command chain ONE-CLICK-FLEET" -y
  else
    info "Dispatching custom firewall instruction payload to target: $target_host."
    ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i "$fleet_root/inventory.yml" \
      -m shell -a "/usr/local/bin/one-click engine \"$rule_command chain ONE-CLICK-FLEET\" -y" 2>/dev/null
    fi
  success "Firewall rule dispatched and applied to execution path successfully."
}
fleet_write_playbooks() {
  # ==== Update Playbook ====
  cat > "$fleet_root/playbooks/update.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
- hosts: all
  become: true
  tasks:
    - name: Update One-Click ToolBox
      shell: /bin/bash -lc "one-click update-y"
EOF
  # ==== Audit Playbook ====
    cat > "$fleet_root/playbooks/audit.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
- hosts: all
  become: true
  gather_facts: true
  tasks:
    - name: Create Reference Manifest
      copy:
        content: |
          {
            "hostname": "{{ inventory_hostname }}",
            "distribution": "{{ ansible_distribution | default('Linux') }}",
            "version": "{{ ansible_distribution_version | default('Unknown') }}",
            "kernel": "{{ ansible_kernel | default('Unknown') }}",
            "cpus": "{{ ansible_processor_vcpus | default('?') }}",
            "load_1m": "{{ ansible_loadavg.1 | default('0.00') }}",
            "ram_total_gb": "{{ (ansible_memtotal_mb / 1024) | round(1) }}G",
            "ram_free_gb": "{{ (ansible_memfree_mb / 1024) | round(1) }}G",
            "disk_total_gb": "{{ (ansible_mounts | selectattr('mount', 'equalto', '/') | map(attribute='size_total') | first / 1024 / 1024 / 1024) | round(1) }}G",
            "disk_free_gb": "{{ (ansible_mounts | selectattr('mount', 'equalto', '/') | map(attribute='size_available') | first / 1024 / 1024 / 1024) | round(1) }}G"
          }
        dest: "/tmp/{{ inventory_hostname }}__audit.json"

    - name: Pull payloads back to fleet controller
      fetch:
        src: "/tmp/{{ inventory_hostname }}__audit.json"
        dest: "/etc/one-click/fleet/audits/{{ inventory_hostname }}.json"
        flat: true

    - name: Clean up remote audit files
      file:
        path: "/tmp/{{ inventory_hostname }}__audit.json"
        state: absent
EOF
  # ==== OCB Playbook ====
  cat > "$fleet_root/playbooks/bench.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- hosts: all
  become: true
  gather_facts: false
  any_errors_fatal: false
  tasks:
    - name: Remove stale state files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /etc/one-click/ocb/benchmarks/COMPLETE
        - /etc/one-click/ocb/benchmarks/job.state
        - /etc/one-click/ocb/benchmarks/latest.json
      ignore_unreachable: true
      ignore_errors: true

    - name: Launch OCB benchmark
      command: /usr/local/bin/one-click fl
      ignore_unreachable: true
      ignore_errors: true
EOF

  cat > "$fleet_root/playbooks/fetch_results.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- hosts: all
  become: true
  gather_facts: false

  tasks:

    - name: Check for COMPLETE flag
      stat:
        path: /etc/one-click/ocb/benchmarks/COMPLETE
      register: complete_file

    - name: Check for benchmark JSON
      stat:
        path: /etc/one-click/ocb/benchmarks/latest.json
      register: latest_file

    - name: Read benchmark results
      slurp:
        src: /etc/one-click/ocb/benchmarks/latest.json
      register: bench_json
      when:
        - complete_file.stat.exists
        - latest_file.stat.exists

    - name: Ensure archive directory exists
      delegate_to: localhost
      file:
        path: "{{ local_fleet_root }}/benchmarks/archive"
        state: directory
        mode: "0755"
      when:
        - bench_json is defined
        - bench_json.content is defined

    - name: Check for existing local result
      delegate_to: localhost
      stat:
        path: "{{ local_fleet_root }}/benchmarks/{{ inventory_hostname }}.json"
      register: existing_result
      when:
        - bench_json is defined
        - bench_json.content is defined

    - name: Archive previous result
      delegate_to: localhost
      command: >
        mv
        {{ local_fleet_root }}/benchmarks/{{ inventory_hostname }}.json
        {{ local_fleet_root }}/benchmarks/archive/{{ inventory_hostname }}-{{ lookup('pipe','date +%Y%m%d-%H%M%S') }}.json
      when:
        - bench_json is defined
        - bench_json.content is defined
        - existing_result.stat.exists | default(false)

    - name: Store latest benchmark locally
      delegate_to: localhost
      copy:
        content: "{{ bench_json.content | b64decode }}"
        dest: "{{ local_fleet_root }}/benchmarks/{{ inventory_hostname }}.json"
        mode: "0644"
      when:
        - bench_json is defined
        - bench_json.content is defined
EOF

  # ==== SSH Key Rotation ====
  cat > "$fleet_root/playbooks/key_rotation.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- hosts: all
  become: true
  gather_facts: false
  ignore_unreachable: true
  tasks:
    - name: Stage new public key into Authorized Keys layer
      authorized_key:
        user: oneclick
        state: present
        key: "{{ new_pub_key }}"
      when: rotation_phase == "stage"

    - name: Push down full-mesh matching private key identity
      copy:
        content: "{{ new_priv_key }}\n"
        dest: /home/oneclick/.ssh/id_ed25519
        owner: oneclick
        group: oneclick
        mode: '0600'
      when: rotation_phase == "stage"

    - name: Push down matching mesh public key identifier mapping
      copy:
        content: "{{ new_pub_key }}\n"
        dest: /home/oneclick/.ssh/id_ed25519.pub
        owner: oneclick
        group: oneclick
        mode: '0644'
      when: rotation_phase == "stage"

    - name: Purge specific old key record without dropping other active users
      authorized_key:
        user: oneclick
        state: absent
        key: "{{ old_pub_key }}"
      when: rotation_phase == "purge"
EOF
  # ==== WEBSITE MIGRATIONS ====
  cat > "$fleet_root/playbooks/restore_db_loop.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
vars:
  db_name_parsed: "{{ db_item.split(':')[0] }}"

tasks:
  - name: "Ensure Database Target Exists: {{ db_name_parsed }}"
    mysql_db:
      name: "{{ db_name_parsed }}"
      state: present

  - name: "Import SQL Data Layer Structure to: {{ db_name_parsed }}"
    mysql_db:
      name: "{{ db_name_parsed }}"
      state: import
      target: "/tmp/fleet-import-{{ domain }}/db_{{ db_name_parsed }}.sql"
EOF

  # ==== VPS Console Pre-Req ====
  cat > "$fleet_root/playbooks/vps_console.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Configure Hypervisors for Remote Console
  hosts: "{{ target }}"
  become: true
  gather_facts: true

  tasks:
    - name: Ensure Netcat is installed
      ansible.builtin.package:
        name: "{{ 'nc' if ansible_os_family in ['RedHat', 'Rocky', 'AlmaLinux'] else 'netcat-openbsd' }}"
        state: present

    - name: Add oneclick user to the libvirt group
      ansible.builtin.user:
        name: oneclick
        groups: libvirt
        append: yes

    - name: Configure libvirtd Unix socket
      ansible.builtin.lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?unix_sock_group\s*='
        line: 'unix_sock_group = "libvirt"'

    - name: Configure libvirtd socket permissions
      ansible.builtin.lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?unix_sock_rw_perms\s*='
        line: 'unix_sock_rw_perms = "0770"'

    - name: Bypass Polkit authentication
      ansible.builtin.lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?auth_unix_rw\s*='
        line: 'auth_unix_rw = "none"'

    - name: Stop libvirtd socket
      ansible.builtin.systemd:
        name: libvirtd.socket
        state: stopped

    - name: Restart Libvirt service daemon
      ansible.builtin.systemd:
        name: libvirtd
        state: restarted
        enabled: yes
EOF

  cat > "$fleet_root/playbooks/site_pull_import.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Pull-Based Cross-Peer Site Export
  hosts: "{{ source_peer }}"
  gather_facts: no
  become: yes
  vars:
    local_archive_path: "/tmp/{{ domain }}.tar.gz"

  tasks:
    - name: Package site export bundle
      shell: "/usr/local/bin/one-click site-export {{ domain }}"
      register: export_output
      environment:
        PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

    - name: Extract archive path from fleet peers
      set_fact:
        peer_archive_path: "{{ export_output.stdout_lines | last }}"

    - name: Pull the archive from fleet peers
      synchronize:
        src: "{{ peer_archive_path }}"
        dest: "{{ local_archive_path }}"
        mode: pull
      delegate_to: localhost
      become: no

    - name: Clean up temporary export
      file:
        path: "{{ peer_archive_path }}"
        state: absent

- name: Local Site Provisioning
  hosts: localhost
  connection: local
  become: yes
  vars:
    tmp_bundle_dir: "/tmp/fleet-import-{{ domain }}"
    local_archive_path: "/tmp/{{ domain }}.tar.gz"

  tasks:
    - name: Create temporary extraction directory
      file:
        path: "{{ tmp_bundle_dir }}"
        state: directory
        mode: '0700'
      delegate_to: localhost

    - name: Unpack dynamic site bundle
      unarchive:
        src: "{{ local_archive_path }}"
        dest: "{{ tmp_bundle_dir }}"
        remote_src: yes
      delegate_to: localhost

    - name: Parse manifest data
      slurp:
        src: "{{ tmp_bundle_dir }}/manifest.json"
      register: manifest_raw

    - name: Collect facts from manifest
      set_fact:
        cfg: "{{ manifest_raw.content | b64decode | from_json }}"

    - name: Ensure isolation system group
      group:
        name: "{{ cfg.site_group | default('www-data') }}"
        state: present

    - name: Ensure isolation system user
      user:
        name: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        shell: /usr/sbin/nologin
        system: yes
        create_home: yes
        state: present

    - name: Ensure target application path hierarchy exists
      file:
        path: "{{ cfg.site_dir }}"
        state: directory
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        mode: '0755'

    - name: Sync site core directory data files
      copy:
        src: "{{ tmp_bundle_dir }}/site_data/"
        dest: "{{ cfg.site_dir }}/"
        remote_src: yes
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        mode: preserve

    - name: Restore PHP config
      when: cfg.php is defined and (cfg.php.enabled | default(false) | bool)
      block:
        - name: Ensure target PHP pool configuration directory exists
          file:
            path: "{{ cfg.php.pool | dirname }}"
            state: directory
            owner: root
            group: root
            mode: '0755'
        - name: Provision custom dynamic PHP pool conf
          copy:
            src: "{{ tmp_bundle_dir }}/php-pool.conf"
            dest: "{{ cfg.php.pool }}"
            remote_src: yes
        - name: Restore PHP custom Systemd Vhost unit
          copy:
            src: "{{ tmp_bundle_dir }}/php-systemd.service"
            dest: "{{ cfg.php.vhost }}"
            remote_src: yes
          register: php_systemd_changed

    - name: Restore Redis custom instance configuration
      when: cfg.redis is defined and (cfg.redis.enabled | default(false) | bool)
      block:
        - name: Deploy isolated redis configuration
          copy:
            src: "{{ tmp_bundle_dir }}/redis.conf"
            dest: "{{ cfg.redis.conf }}"
            remote_src: yes
        - name: Deploy custom systemd redis overrides dir
          file:
            path: "{{ cfg.redis.service_conf | dirname }}"
            state: directory
        - name: Synchronize custom systemd runtime
          copy:
            src: "{{ tmp_bundle_dir }}/redis-service.conf"
            dest: "{{ cfg.redis.service_conf }}"
            remote_src: yes
          register: redis_systemd_changed

    - name: Restore Node.js/Generic App Worker Systemd Units
      copy:
        src: "{{ tmp_bundle_dir }}/systemd.service"
        dest: "{{ cfg.systemd_service.vhost }}"
        remote_src: yes
      when: cfg.systemd_service is defined and (cfg.systemd_service.enabled | default(false) | bool)
      register: app_systemd_changed

    - name: Trigger systemd reload
      systemd:
        daemon_reload: yes
      when: >
        (php_systemd_changed is defined and php_systemd_changed.changed) or
        (redis_systemd_changed is defined and redis_systemd_changed.changed) or
        (app_systemd_changed is defined and app_systemd_changed.changed)

    - name: Check for multi-database manifest
      stat:
        path: "{{ tmp_bundle_dir }}/db_manifest.txt"
      register: db_manifest_file

    - name: Check for single database dump file
      stat:
        path: "{{ tmp_bundle_dir }}/db.sql"
      register: db_sql_file

    - name: Single Database Restoration
      when:
        - cfg.database is defined and (cfg.database.enabled | default(false) | bool)
        - db_sql_file.stat.exists
      block:
        - name: Ensure target database exists
          command: mysql -e "CREATE DATABASE IF NOT EXISTS \`{{ cfg.database.primary.name | default(domain) }}\`;"
          register: db_create_result
          changed_when: false
          ignore_errors: yes

        - name: Import single database dump
          shell: mysql "{{ cfg.database.primary.name | default(domain) }}" < "{{ tmp_bundle_dir }}/db.sql"
          when: db_create_result is succeeded
          ignore_errors: yes

    - name: Multi-Database Direct Shell Restoration
      when: db_manifest_file.stat.exists and db_manifest_file.stat.size > 0
      block:
        - name: Parse lines from multi-database mapping text file
          slurp:
            src: "{{ tmp_bundle_dir }}/db_manifest.txt"
          register: db_lines_raw

        - name: Import multi-database SQL dumps
          shell: |
            DB_NAME=$(echo "{{ item }}" | awk '{print $1}')
            DB_FILE=$(echo "{{ item }}" | awk '{print $2}')
            mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
            if [ -f "{{ tmp_bundle_dir }}/${DB_FILE}" ]; then
              mysql "${DB_NAME}" < "{{ tmp_bundle_dir }}/${DB_FILE}"
            fi
          loop: "{{ (db_lines_raw.content | b64decode).splitlines() }}"
          ignore_errors: yes

    - name: Ensure webserver daemon
      service:
        name: "{{ cfg.webserver_service }}"
        state: started
        enabled: yes
      when: cfg.webserver_service is defined and cfg.webserver_service != 'null' and cfg.webserver_service != ''

    - name: Ensure webserver conf dir exists
      file:
        path: "{{ cfg.vhost | dirname }}"
        state: directory
        owner: root
        group: root
        mode: '0755'
      when: cfg.vhost is defined and cfg.vhost != 'null' and cfg.vhost != ''

    - name: Deploy Webserver Host Routing
      copy:
        src: "{{ tmp_bundle_dir }}/vhost.conf"
        dest: "{{ cfg.vhost }}"
        remote_src: yes
      register: web_vhost_copied
      when: cfg.vhost is defined and cfg.vhost != 'null' and cfg.vhost != ''

    - name: Establish Webserver Symbolic Links
      file:
        src: "{{ cfg.vhost }}"
        dest: "{{ cfg.vhost_link }}"
        state: link
      when:
        - web_vhost_copied is succeeded and web_vhost_copied.changed
        - cfg.vhost_link is defined and cfg.vhost_link != 'null' and cfg.vhost_link != ''

    - name: Reload/Restart Web Daemon
      service:
        name: "{{ cfg.webserver_service }}"
        state: reloaded
      when:
        - web_vhost_copied is succeeded and web_vhost_copied.changed
        - cfg.webserver_service is defined and cfg.webserver_service != 'null' and cfg.webserver_service != ''

    - name: Restart Application
      service:
        name: "{{ item }}"
        state: restarted
      loop:
        - "{{ (cfg.php is defined and cfg.php.service is defined) | ternary(cfg.php.service, '') }}"
        - "{{ (cfg.redis is defined and cfg.redis.service is defined) | ternary(cfg.redis.service, '') }}"
        - "{{ (cfg.systemd_service is defined and cfg.systemd_service.name is defined) | ternary(cfg.systemd_service.name, '') }}"
      when: item != ""

    - name: Clean up
      file:
        path: "{{ item }}"
        state: absent
      with_items:
        - "{{ tmp_bundle_dir }}"
        - "{{ local_archive_path }}"
EOF
  # ==== Site Migrator Between Fleet Members ====
  cat > "$fleet_root/playbooks/site_import.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Fleet Web Data Provisioning
  hosts: "{{ target_host }}"
  become: yes
  gather_facts: yes
  vars:
    tmp_bundle_dir: "/tmp/fleet-import-{{ domain }}"

  tasks:
    - name: Create temp extraction dir
      file:
        path: "{{ tmp_bundle_dir }}"
        state: directory
        mode: '0700'

    - name: Unpack bundle
      unarchive:
        src: "{{ remote_archive_path }}"
        dest: "{{ tmp_bundle_dir }}"
        remote_src: yes

    - name: Parse manifest
      slurp:
        src: "{{ tmp_bundle_dir }}/manifest.json"
      register: manifest_raw

    - name: Collect facts
      set_fact:
        cfg: "{{ manifest_raw.content | b64decode | from_json }}"

    - name: Normalize Webserver, Group, and Paths for Target OS
      set_fact:
        target_webserver_service: "{{ 'apache2' if ansible_os_family == 'Debian' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else ('httpd' if ansible_os_family == 'RedHat' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else cfg.webserver_service | default('nginx')) }}"
        target_webserver_group: "{{ 'www-data' if ansible_os_family == 'Debian' else ('apache' if ansible_os_family == 'RedHat' else cfg.site_group | default('www-data')) }}"
        target_vhost_dir: "{{ '/etc/apache2/sites-available' if ansible_os_family == 'Debian' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else ('/etc/httpd/conf.d' if ansible_os_family == 'RedHat' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else (cfg.vhost | default('/etc/nginx/sites-available/' + domain + '.conf')) | dirname) }}"
        target_vhost_link_dir: "{{ '/etc/apache2/sites-enabled' if ansible_os_family == 'Debian' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else '' }}"
        target_log_subfolder: "{{ 'apache2' if ansible_os_family == 'Debian' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else ('httpd' if ansible_os_family == 'RedHat' and (cfg.webserver_service in ['httpd', 'apache', 'apache2']) else 'nginx') }}"

    - name: Ensure target isolation group exists
      command: "groupadd -r {{ cfg.site_group }}"
      register: group_create
      failed_when: false
      changed_when: group_create.rc == 0

    - name: Ensure isolation user exists
      user:
        name: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        groups: "{{ target_webserver_group }}"
        append: yes
        shell: /usr/sbin/nologin
        system: yes
        create_home: no
        state: present

    - name: Ensure isolation user belongs to webserver group
      command: "usermod -aG {{ target_webserver_group }} {{ cfg.site_user }}"
      ignore_errors: yes

    - name: Update ownership on PHP library and session paths
      file:
        path: "/var/lib/one-click/{{ domain }}"
        state: directory
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: '0700'
        recurse: yes

    - name: Ensure application path exists
      file:
        path: "{{ cfg.site_dir }}"
        state: directory
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        mode: '0755'

    - name: Ensure correct ownership on site directory and data files
      file:
        path: "{{ item }}"
        owner: "{{ cfg.site_user }}"
        group: "{{ target_webserver_group }}"
        mode: '0755'
        recurse: yes
      loop:
        - "{{ cfg.site_dir }}"
        - "/var/log/one-click/{{ domain }}"
      ignore_errors: yes

    - name: Ensure correct ownership on runtime state paths (/var/lib and /run)
      file:
        path: "{{ item }}"
        owner: "{{ cfg.site_user }}"
        group: "{{ target_webserver_group }}"
        mode: '0770'
        recurse: yes
      loop:
        - "/var/lib/one-click/{{ domain }}"
        - "/run/one-click/{{ domain }}"
      ignore_errors: yes

    - name: Ensure DB manager runtime paths have readable permissions
      file:
        path: "{{ item }}"
        owner: "{{ cfg.site_user }}"
        group: "{{ target_webserver_group }}"
        mode: '0640'
      loop:
        - "/etc/one-click/db-manager/sites/{{ domain }}.json"
        - "/etc/one-click/db-manager/secrets/db/{{ domain }}.pass"
      ignore_errors: yes

    - name: Sync site directory
      copy:
        src: "{{ tmp_bundle_dir }}/site_data/"
        dest: "{{ cfg.site_dir }}/"
        remote_src: yes
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        mode: preserve

    - name: Ensure site log directories exist
      file:
        path: "/var/log/one-click/{{ domain }}/{{ target_log_subfolder }}"
        state: directory
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ target_webserver_group }}"
        mode: '0755'

    - name: Restore site logs if packed
      copy:
        src: "{{ tmp_bundle_dir }}/site_logs/"
        dest: "/var/log/one-click/{{ domain }}/"
        remote_src: yes
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ target_webserver_group }}"
      ignore_errors: yes

    - name: Ensure PHP runtime socket directory exists (/run)
      file:
        path: "/run/one-click/{{ domain }}"
        state: directory
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ target_webserver_group }}"
        mode: '0770'

    - name: Update ownership on PHP library and session paths
      file:
        path: "/var/lib/one-click/{{ domain }}"
        state: directory
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: '0700'
        recurse: yes

    - name: Ensure PHP session and tmp paths exist (/var/lib)
      file:
        path: "/var/lib/one-click/{{ domain }}/{{ item }}"
        state: directory
        owner: "{{ cfg.site_user | default('www-data') }}"
        group: "{{ cfg.site_group | default('www-data') }}"
        mode: '0770'
      loop:
        - sessions
        - tmp

    - name: Restore PHP config
      when: cfg.php is defined and (cfg.php.enabled | default(false) | bool)
      block:
        - name: Ensure PHP configuration directory exists
          file:
            path: "/etc/one-click/php/{{ domain }}"
            state: directory
            owner: root
            group: root
            mode: '0755'

        - name: Provision custom php-fpm.conf / php.conf
          copy:
            src: "{{ tmp_bundle_dir }}/php-fpm.conf"
            dest: "{{ cfg.php.fpm | default('/etc/one-click/php/' + domain + '/php-fpm.conf') }}"
            remote_src: yes

        - name: Provision custom PHP pool conf
          copy:
            src: "{{ tmp_bundle_dir }}/php-pool.conf"
            dest: "{{ cfg.php.pool | default('/etc/one-click/php/' + domain + '/pool.conf') }}"
            remote_src: yes

        - name: Normalize PHP Pool listen.group for Target OS
          replace:
            path: "{{ cfg.php.pool | default('/etc/one-click/php/' + domain + '/pool.conf') }}"
            regexp: '^\s*listen\.group\s*=.*$'
            replace: "listen.group = {{ target_webserver_group }}"

        - name: Provision custom php.ini drop-in tracking context
          copy:
            src: "{{ tmp_bundle_dir }}/php.ini"
            dest: "{{ cfg.php.ini | default('/etc/one-click/php/' + domain + '/php.ini') }}"
            remote_src: yes
          failed_when: false

        - name: Restore PHP Systemd Vhost definition
          copy:
            src: "{{ tmp_bundle_dir }}/php-systemd.service"
            dest: "{{ cfg.php.vhost }}"
            remote_src: yes
          register: php_systemd_changed

    - name: Restore PHP Systemd Vhost definition
      copy:
        src: "{{ tmp_bundle_dir }}/php-systemd.service"
        dest: "{{ cfg.php.vhost }}"
        remote_src: yes
      register: php_systemd_changed

    - name: Detect active PHP-FPM binary on target host
      shell: |
        if [[ -x /usr/sbin/php-fpm ]]; then
          echo "/usr/sbin/php-fpm"
        elif [[ -x /usr/bin/php-fpm ]]; then
          echo "/usr/bin/php-fpm"
        else
          find /usr/sbin -maxdepth 1 -name "php-fpm*" -executable | sort -V | tail -n 1
        fi
      register: target_php_bin
      changed_when: false

    - name: Adjust ExecStart in Systemd Unit to match target OS binary
      replace:
        path: "{{ cfg.php.vhost }}"
        regexp: '(ExecStart=)[^ \t]*'
        replace: '\1{{ target_php_bin.stdout | trim }}'
      when:
        - target_php_bin.stdout is defined
        - target_php_bin.stdout | trim != ''

    - name: Restore Redis instance
      when: cfg.redis is defined and (cfg.redis.enabled | default(false) | bool)
      block:
        - name: Deploy isolated redis instance
          copy:
            src: "{{ tmp_bundle_dir }}/redis.conf"
            dest: "{{ cfg.redis.conf }}"
            remote_src: yes

        - name: Deploy Redis systemd service directory
          file:
            path: "{{ cfg.redis.service_conf | dirname }}"
            state: directory

        - name: Synchronize systemd runtime
          copy:
            src: "{{ tmp_bundle_dir }}/redis-service.conf"
            dest: "{{ cfg.redis.service_conf }}"
            remote_src: yes
          register: redis_systemd_changed

    - name: Restore Node.js/Generic App
      copy:
        src: "{{ tmp_bundle_dir }}/systemd.service"
        dest: "{{ cfg.systemd_service.vhost }}"
        remote_src: yes
      when: cfg.systemd_service is defined and (cfg.systemd_service.enabled | default(false) | bool)
      register: app_systemd_changed

    - name: Trigger systemd reload
      systemd:
        daemon_reload: yes

    - name: Check for database dump file
      stat:
        path: "{{ tmp_bundle_dir }}/db.sql"
      register: db_sql_file

    - name: Restore Database
      when:
        - cfg.database is defined and (cfg.database.enabled | default(false) | bool)
        - db_sql_file.stat.exists
      block:
        - name: Ensure target database exists
          command: mysql -e "CREATE DATABASE IF NOT EXISTS \`{{ cfg.database.primary.name | default(domain) }}\`;"
          register: db_create_result
          changed_when: false
          ignore_errors: yes

        - name: Import database dump
          shell: mysql "{{ cfg.database.primary.name | default(domain) }}" < "{{ tmp_bundle_dir }}/db.sql"
          when: db_create_result is succeeded
          ignore_errors: yes

    - name: Framework tracking metadata directory
      file:
        path: "/etc/one-click/sites/{{ domain }}"
        state: directory
        owner: root
        group: root
        mode: '0755'

    - name: Restore meta.conf
      copy:
        src: "{{ tmp_bundle_dir }}/meta.conf"
        dest: "/etc/one-click/sites/{{ domain }}/meta.conf"
        remote_src: yes
        owner: root
        group: root
        mode: '0644'
      failed_when: false

    - name: Ensure target webserver configuration directory exists
      file:
        path: "{{ target_vhost_dir }}"
        state: directory
        owner: root
        group: root
        mode: '0755'

    - name: Deploy Primary Webserver VHost
      copy:
        src: "{{ tmp_bundle_dir }}/vhost.conf"
        dest: "{{ target_vhost_dir }}/{{ domain }}.conf"
        remote_src: yes
      register: web_vhost_copied

    - name: Check for SSL VHost file in bundle
      stat:
        path: "{{ tmp_bundle_dir }}/vhost-ssl.conf"
      register: ssl_vhost_file

    - name: Deploy SSL Webserver VHost
      copy:
        src: "{{ tmp_bundle_dir }}/vhost-ssl.conf"
        dest: "{{ target_vhost_dir }}/{{ domain }}-le-ssl.conf"
        remote_src: yes
      register: ssl_vhost_copied
      when: ssl_vhost_file.stat.exists

    - name: Align Webserver VHost Log Directory Path
      replace:
        path: "{{ target_vhost_dir }}/{{ item }}"
        regexp: '/var/log/one-click/{{ domain }}/(httpd|apache2)/'
        replace: "/var/log/one-click/{{ domain }}/{{ target_log_subfolder }}/"
      loop:
        - "{{ domain }}.conf"
        - "{{ domain }}-le-ssl.conf"
      ignore_errors: yes

    - name: Disable default Debian site configurations
      file:
        path: "/etc/apache2/sites-enabled/{{ item }}"
        state: absent
      loop:
        - "000-default.conf"
        - "default-ssl.conf"
      when: ansible_os_family == 'Debian' and target_webserver_service == 'apache2'
      ignore_errors: yes

    - name: Enable Apache2 Site Symlinks
      file:
        src: "{{ target_vhost_dir }}/{{ item }}"
        dest: "{{ target_vhost_link_dir }}/{{ item }}"
        state: link
      loop:
        - "{{ domain }}.conf"
        - "{{ (ssl_vhost_file is defined and ssl_vhost_file.stat.exists) | ternary(domain + '-le-ssl.conf', '') }}"
      when:
        - ansible_os_family == 'Debian'
        - target_vhost_link_dir != ''
        - item != ''

    - name: Ensure exact target framework tracking directory exists
      file:
        path: "/etc/one-click/{{ (cfg.meta_rel_path | default('sites/' + domain + '/meta.conf')) | dirname }}"
        state: directory
        owner: root
        group: root
        mode: '0755'

    - name: Restore meta.conf to original type path
      copy:
        src: "{{ tmp_bundle_dir }}/meta.conf"
        dest: "/etc/one-click/{{ cfg.meta_rel_path | default('sites/' + domain + '/meta.conf') }}"
        remote_src: yes
        owner: root
        group: root
        mode: '0644'
      ignore_errors: yes

    - name: Run One-Click permissions sync
      shell: "/usr/local/bin/one-click --permission-repair {{ domain }}"
      environment:
        PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      ignore_errors: yes

    - name: Enable and start isolated site PHP systemd unit
      systemd:
        name: "{{ (cfg.php.vhost | basename) if (cfg.php is defined and cfg.php.vhost is defined) else ('php-fpm@' + domain + '.service') }}"
        enabled: yes
        state: restarted
      when: cfg.php is defined and (cfg.php.enabled | default(false) | bool)

    - name: Reload Web Server
      service:
        name: "{{ target_webserver_service }}"
        state: reloaded

    - name: Restart Application Services
      service:
        name: "{{ 'apache2' if ansible_os_family == 'Debian' and item in ['apache', 'httpd', 'apache2'] else ('httpd' if ansible_os_family == 'RedHat' and item in ['apache', 'httpd', 'apache2'] else item) }}"
        state: restarted
      loop:
        - "{{ (cfg.php is defined and cfg.php.service is defined) | ternary(cfg.php.service, '') }}"
        - "{{ (cfg.redis is defined and cfg.redis.service is defined) | ternary(cfg.redis.service, '') }}"
        - "{{ (cfg.systemd_service is defined and cfg.systemd_service.name is defined) | ternary(cfg.systemd_service.name, '') }}"
      when:
        - item != ""
        - item != "null"
      ignore_errors: yes

    - name: Clean up temporary files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - "{{ tmp_bundle_dir }}"
        - "{{ remote_archive_path }}"
EOF
  # ==== Win ISO Push ====
  cat > "$fleet_root/playbooks/win_inv.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Esential Directories + File Push
  hosts: "{{ target_host }}"
  become: yes
  vars:
    fleet_root: /etc/one-click/fleet

  tasks:
    - name: Sync Inventory
      copy:
        src: "{{ fleet_root }}/inventory.yml"
        dest: "{{ fleet_root }}/inventory.yml"
        mode: "0644"

    - name: Check if local inventory file exists
      ansible.builtin.stat:
        path: "/etc/one-click/virtualization/inventory.json"
      delegate_to: localhost
      register: local_inventory_stat

    - name: Ensure target directory exists on fleet members
      ansible.builtin.file:
        path: "/etc/one-click/virtualization"
        state: directory
        mode: "0755"
      when: local_inventory_stat.stat.exists

    - name: Push Virtualization Inventory to fleet members
      ansible.builtin.copy:
        src: "/etc/one-click/virtualization/inventory.json"
        dest: "/etc/one-click/virtualization/inventory.json"
        mode: "0644"
      when: local_inventory_stat.stat.exists
EOF
  # ==== Cluster Mesh ====
  cat > "$fleet_root/playbooks/cluster_mesh.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Deterministic State-Driven Fleet Trust Mesh
  hosts: all
  become: yes
  gather_facts: yes

  vars:
    fleet_root: /etc/one-click/fleet
    fleet_user: oneclick
    active_controller: "{{ controller_name | default('localhost') }}"
    ansible_connection: "{{ 'local' if (inventory_hostname == 'localhost' or inventory_hostname == active_controller) else 'ssh' }}"

  tasks:
    - name: Ensure One-Click binary
      stat:
        path: /usr/local/bin/one-click
      register: ocb_binary

    - name: Install One-Click if missing
      shell: |
        curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh
        bash /tmp/one-click.sh setup
        rm -f /tmp/one-click.sh
      when: not ocb_binary.stat.exists

    - name: Ensure fleet root exists
      file:
        path: "{{ fleet_root }}/state"
        state: directory
        recurse: yes

    - name: Check fleet public key
      stat:
        path: "{{ fleet_root }}/keys/id_ed25519.pub"
      register: fleet_pubkey

    - name: Initialize fleet identity if key missing
      command: /usr/local/bin/one-click fleet --init
      when:
        - not fleet_pubkey.stat.exists
        - inventory_hostname == 'localhost' or inventory_hostname == active_controller

    - name: Push Controller configuration profile to fleet peers
      copy:
        src: "{{ fleet_root }}/state/{{ active_controller }}.conf"
        dest: "{{ fleet_root }}/state/{{ active_controller }}.conf"
        mode: "0644"
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Synchronize fleet state profiles to all peers
      copy:
        src: "{{ fleet_root }}/state/"
        dest: "{{ fleet_root }}/state/"
        mode: "0644"
      when: inventory_hostname != active_controller

    - name: Push Inventory to fleet members
      copy:
        src: "{{ fleet_root }}/inventory.yml"
        dest: "{{ fleet_root }}/inventory.yml"
        mode: "0644"
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Push Virtualization Inventory to fleet members
      copy:
        src: "/etc/one-click/virtualization/inventory.json"
        dest: "/etc/one-click/virtualization/inventory.json"
        mode: "0644"
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Set inventory private key path
      lineinfile:
        path: /etc/one-click/fleet/inventory.yml
        regexp: '^\s*ansible_ssh_private_key_file:'
        line: '    ansible_ssh_private_key_file: /home/oneclick/.ssh/id_ed25519'
        backrefs: no
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Rebuild inventory from synchronized state
      shell: |
        bash /etc/one-click/write_inventory.sh
      args:
        executable: /bin/bash
      when: inventory_hostname == 'localhost' or inventory_hostname == active_controller

    - name: Ensure .ssh directory structure exists
      file:
        path: /home/oneclick/.ssh
        state: directory
        owner: oneclick
        group: oneclick
        mode: "0700"

    - name: Deploy identity credentials onto fleet peer
      shell: |
        NODE_FILE="{{ fleet_root }}/state/{{ inventory_hostname }}.conf"
        if [ -f "$NODE_FILE" ]; then
            . "$NODE_FILE"
            if [ -n "$NODE_PRIVKEY_B64" ] && [ -n "$NODE_PUBKEY" ]; then
                echo "$NODE_PRIVKEY_B64" | base64 -d > /home/oneclick/.ssh/id_ed25519
                echo "$NODE_PUBKEY" > /home/oneclick/.ssh/id_ed25519.pub

                chown oneclick:oneclick /home/oneclick/.ssh/id_ed25519*
                chmod 600 /home/oneclick/.ssh/id_ed25519
                chmod 644 /home/oneclick/.ssh/id_ed25519.pub
            fi
        fi
      args:
        executable: /bin/bash
      ignore_unreachable: yes
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Capture host key fingerprints
      shell: |
        ssh-keyscan -H {{ ansible_default_ipv4.address }} 2>/dev/null
      register: host_scan
      changed_when: false

    - name: Store host fingerprint configurations
      set_fact:
        fleet_host_fingerprint: "{{ host_scan.stdout_lines | join('\n') }}"
      when: host_scan.stdout_lines is defined

    - name: Generate authorized_keys mesh
      run_once: true
      delegate_to: localhost
      copy:
        dest: /tmp/fleet-authorized_keys.mesh
        mode: "0644"
        content: |
          {% if lookup('file', fleet_root + '/keys/id_ed25519.pub', errors='ignore') %}
          {{ lookup('file', fleet_root + '/keys/id_ed25519.pub') | trim }}
          {% endif %}
          {% for h in ansible_play_hosts %}
          {% if h != 'localhost' and h != active_controller %}
          {% set state_key = lookup('ini', 'NODE_PUBKEY type=properties file=' + fleet_root + '/state/' + h + '.conf', errors='ignore') | replace('\"', '') | trim %}
          {% if state_key %}
          {{ state_key }}
          {% endif %}
          {% endif %}
          {% endfor %}

    - name: Generate known_hosts mesh
      run_once: true
      delegate_to: localhost
      copy:
        dest: /tmp/fleet-known_hosts.mesh
        mode: "0644"
        content: |
          {% if hostvars['localhost'].fleet_host_fingerprint is defined %}
          {{ hostvars['localhost'].fleet_host_fingerprint }}
          {% elif hostvars[active_controller].fleet_host_fingerprint is defined %}
          {{ hostvars[active_controller].fleet_host_fingerprint }}
          {% endif %}
          {% for h in ansible_play_hosts %}
          {% if hostvars[h].fleet_host_fingerprint is defined %}
          {{ hostvars[h].fleet_host_fingerprint }}
          {% endif %}
          {% endfor %}

    - name: Push compiled authorized_keys mesh to fleet peers
      copy:
        src: /tmp/fleet-authorized_keys.mesh
        dest: /tmp/fleet-authorized_keys.mesh
        mode: "0644"

    - name: Push compiled known_hosts mesh to fleet peers
      copy:
        src: /tmp/fleet-known_hosts.mesh
        dest: /tmp/fleet-known_hosts.mesh
        mode: "0644"

    - name: Merge authorized_keys entries
      shell: |
        touch /home/oneclick/.ssh/authorized_keys
        cat /tmp/fleet-authorized_keys.mesh >> /home/oneclick/.ssh/authorized_keys
        sort -u /home/oneclick/.ssh/authorized_keys -o /home/oneclick/.ssh/authorized_keys
        chown oneclick:oneclick /home/oneclick/.ssh/authorized_keys
        chmod 600 /home/oneclick/.ssh/authorized_keys
      args:
        executable: /bin/bash

    - name: Merge known_hosts entries
      shell: |
        touch /home/oneclick/.ssh/known_hosts
        cat /tmp/fleet-known_hosts.mesh >> /home/oneclick/.ssh/known_hosts
        sort -u /home/oneclick/.ssh/known_hosts -o /home/oneclick/.ssh/known_hosts
        chown oneclick:oneclick /home/oneclick/.ssh/known_hosts
        chmod 644 /home/oneclick/.ssh/known_hosts
      args:
        executable: /bin/bash

    - name: Fix .ssh folder ownership boundaries
      file:
        path: /home/oneclick/.ssh
        state: directory
        recurse: yes
        owner: oneclick
        group: oneclick
EOF
}
fleet_add() {
  local ip="$1"
  local host="$2"
  local port="${3:-22}"
  local server_type="${4:-hypervisor}"
  local private_ip="${5:-}"
  local add_hypervisor="${6:-}"
  local role_type="${7:-hypervisor-peer}"
  build_vars
  . "$fleet_root/controller.env"
  local virt_dir="/etc/one-click/virtualization"
  local FLEET_AVAILABLE_IPS_FILE="${virt_dir}/available_ips.txt"
  local FLEET_USED_IPS_FILE="${virt_dir}/used_ips.txt"
  local hypervisor_wg_file="/etc/one-click/fleet/hypervisor_assigned_wg_ips.json"
  local master_wg_config="/etc/wireguard/one-click.conf"
  trap 'fleet_remove "$host"' ERR
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    warn "Only the controller can add and remove peers."
	return 1
  fi
  [[ -z "$ip" || -z "$host" ]] && {
    error "Usage: fleet add <ip> <hostname> [port]"
    return 1
  }
  export FLEET_AVAILABLE_IPS_FILE="${virt_dir}/available_ips.txt"
  export FLEET_USED_IPS_FILE="${virt_dir}/used_ips.txt"
  touch "$FLEET_USED_IPS_FILE"
  if [[ ! -s "$FLEET_AVAILABLE_IPS_FILE" ]]; then
    info "Generating internal cluster mesh IP block tracking pools."
    local tmp_pool
    tmp_pool=$(mktemp)
    for b in {1..40}; do
      for c in {1..250}; do
        echo "10.10.${b}.${c}" >> "$tmp_pool"
      done
    done
    mv "$tmp_pool" "$FLEET_AVAILABLE_IPS_FILE"
    chmod 600 "$FLEET_AVAILABLE_IPS_FILE"
  fi
  if [[ "$role_type" != "vps-peer" ]]; then
    info "Configuring trust to this device. Please accept the prompt"
    path_msg="Please copy + paste the following guide on $host and run to set up the cross-fleet trust:"
  else
    info "Configuring trust to this device. Please wait while trust is established."
    path_msg="Please wait while trust is established with $host"
  fi
  one-click engine "accept all from ${private_ip:-${ip}}" -y
  if [[  $(sed -En '/# One-Click Routing/p' /etc/hosts) != "# One-Click Routing" ]]; then
    echo "# One-Click Routing" >> /etc/hosts
    echo -e "${ip}\t${host}" >> /etc/hosts
  elif ! grep -q "$host" /etc/hosts; then
    sed -Ei.one-click_bak -e "/# One-Click/{a\ ${ip}\t${host}" -e '}' /etc/hosts
  fi
  fleet_init
  bash /etc/one-click/write_inventory.sh "$role_type" "${private_ip:-}" "${ip:-}"
  echo "${orange}[${red}[${reset}$host IS BEING ADDED TO THE FLEET${red}]${orange}]"
  cat <<EOF
This tool will allow the micro management and overview of your remote fleet and fleet owned VMs.
You can run mass updates of the One-Click tool with a single click ${yellow}:)${reset}.
You can also run OCB benchmark on your fleet and poll the results for a single view.

One-Click Binary will also be installed if it is not already enabled. This may take some time...

$path_msg

${magenta}======================================================================================
$(tput setaf 113)  ___  _   _ _____       ____ _     ___ ____ _  __
 / _ \\| \\ | | ____|     / ___| |   |_ _/ ___| |/ /
| | | |  \\| |  _| _____| |   | |    | | |   | ' /
| |_| | |\\  | |__|_____| |___| |___ | | |___| . \\
 \\___/|_| \\_|_____|     \\____|_____|___\\____|_|\\_\\

       _____ _     _____ _____ _____
     |  ___| |   | ____| ____|_   _|
     | |_  | |   |  _| |  _|   | |
     |  _| | |___| |___| |___  | |
     |_|   |_____|_____|_____| |_|${reset}

${orange}useradd $(tput setaf 111)-m -s $(tput setaf 116)/bin/bash oneclick
${orange}mkdir $(tput setaf 111)-p $(tput setaf 116)/home/oneclick/.ssh

${orange}echo $(tput setaf 116)'$(cat "$fleet_root/keys/id_ed25519.pub")' $(tput setaf 111)>> $(tput setaf 116)/home/oneclick/.ssh/authorized_keys

${orange}chown $(tput setaf 111)-R $(tput setaf 116)oneclick:oneclick /home/oneclick/.ssh
${orange}chmod $(tput setaf 161)700 $(tput setaf 116)/home/oneclick/.ssh
${orange}chmod $(tput setaf 161)600 $(tput setaf 116)/home/oneclick/.ssh/authorized_keys

${orange}echo $(tput setaf 116)'oneclick ALL=(ALL) NOPASSWD:ALL' $(tput setaf 111)> $(tput setaf 116)/etc/sudoers.d/oneclick
${orange}chmod $(tput setaf 161)440 $(tput setaf 116)/etc/sudoers.d/oneclick

${orange}iptables $(tput setaf 111)-t $(tput setaf 116)filter $(tput setaf 111)-I $(tput setaf 116)INPUT $(tput setaf 111)-s $(tput setaf 116)${sys_ip:-${sys_ipv6}} $(tput setaf 111)-j ${magenta}ACCEPT

${blue}## $(tput setaf 129)Or alternatively
${blue}## ${orange}one-click $(tput setaf 116)engine "allow all from ${sys_ip:-${sys_ipv6}}" $(tput setaf 111)-y
${blue}## $(tput setaf 129)If One-click is already installed on $host
${magenta}======================================================================================
$(tput bold)$(tput setaf 113)THANK YOU FOR CHOOSING ONE-CLICK${reset}

EOF
  if [[ "$role_type" != "vps-peer" ]]; then
    local msg="The engine is waiting for you to apply the snippet above to [${yellow}$host ($ip)${reset}]."
  else
    local msg="Awaiting automated trust confirmation from [${yellow}$host (${private_ip:-${ip}})${reset}]."
  fi
  generate_node_credentials "$host"
  info "Waiting for $host remote host configuration." \
    "$msg" \
    "Press ${yellow}Ctrl+C${reset} at any time to cancel this setup block safely." \
    "Checking connectivity status"
  if [[ "$server_type" == "hypervisor" && "$role_type" == "vps-peer" ]]; then
    connect_ip="${private_ip}"
  else
    connect_ip="$ip"
  fi
  if [ -n "${port:-}" ]; then
    porto=(-p "$port")
  else
    porto=()
  fi
  set +e
  local saved_err_trap
  saved_err_trap=$(trap -p ERR)
  trap '' ERR
  while true; do
    ssh \
      -n \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o ConnectTimeout=1 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      ${porto:+"${porto[@]}"} \
      "oneclick@$connect_ip" \
      "echo ready" >/dev/null 2>&1;
    if [[ $? -eq 0 ]]; then
      success "Key handshake established!"
      break
    else
      echo -n "."
      sleep 5
    fi
  done
  if [[ -n "$saved_err_trap" ]]; then
    eval "$saved_err_trap"
  else
    trap - ERR
  fi
  set -e
  # ==== Fleet Mesh Trust ====
  info "New fleet peer registered. Spawning cluster key cross-trust."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible-playbook \
      "$fleet_root/playbooks/cluster_mesh.yml" \
      -i "$fleet_root/inventory.yml" \
      -u oneclick \
      -b \
	  -e "controller_name=$CONTROLLER_NAME" </dev/null 2>/dev/null | sed -E "
	  s/$(hostname -s)/Controller {&}/
      /^($|TASK|PLAY)/ {
	    s/[^[]*\[([^]]*).*/\1/;
		h;
		d
	  };
      /^ok/ {
		G;
		s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/
	  };
      /^changed/ {
		G;
		s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/
	  };
      /^skipping/ {
		G;
		s/^(skipping.*)\n(.*)/$(tput setaf 45)\1 ->${magenta} \2${reset}/
	  };
      /^(failed|fatal)/ {
		G;
	    s/^((failed|fatal)[^>]*> )[^F]*(.*):.*/${red}\1 ->${magenta} \3${reset}/;
		s/ => //
	  };
	  /^\[/d;
      s/${host}|localhost/$(tput setaf 111)&/;
	  s/failed=[1-9][0-9]*/${red}&${reset}/g;
	  s/skipped=[1-9][0-9]*/$(tput setaf 45)&${reset}/g;
	  s/changed=[1-9][0-9]*/${orange}&${reset}/g;
	  s/ok=[1-9][0-9]*/${green}&${reset}/g;
	  /unreachable=[1-9][0-9]*/s/.*/${red}&${reset}/;
	  /^(ok|changed|skipping|fatal)/! {
	    s/^[[:alnum:].:_-]+/${blue}&${reset}/
	  };
	  /^ok/s/] ->/${green}&${magenta}/;
	  /^skipping/s/] ->/$(tput setaf 45)&${magenta}/;
	  /^changed/s/] ->/${orange}&${magenta}/;
	  /^fatal/s/(\[)([^]]*)/${red}\1${blue}\2${red}/;
  " || true
  if [[ "$server_type" == "hypervisor" && "$role_type" != "vps-peer" ]]; then
  # ==== Configure WG on new peer ====
    local target_host_ip=$(ansible-inventory -i /etc/one-click/fleet/inventory.yml --host $host | jq -r '.ansible_host')
    warn "Fleet Hypervisor Member. Preparing node."
	  # ==== Hypervisor Path ====
      local hv_node_name="${host}"
      if [[ -z "$hv_node_name" ]]; then
        error "Hypervisor target identifier is undefined."
        return 1
      fi
	  if [[ "$server_type" == "hypervisor" ]]; then
        info "Allocating Private Node IP from pool for hypervisor: $hv_node_name"
        hv_private_ip=$(head -n 1 "$FLEET_AVAILABLE_IPS_FILE")
        if [[ -z "$hv_private_ip" ]]; then
          error "IP Pool Exhausted! Unable to register hypervisor network mesh tunnel."
          return 1
        fi
        cat > "$fleet_root/state/$host.conf" <<EOF
HOSTNAME=$host
IP=${private_ip:-${ip}}
NAT_IP=${local_ip:-${remote_vps_ip:-$ip}}
MESH_IP=${hv_private_ip:-${vps_private_ip:-}}
PORT=$port
EOF
        info "Generating Wireguard Cryptographic Keys locally on Controller for $hv_node_name."
        local hv_private_key hv_public_key hv_preshared_key master_pub_key
        hv_private_key=$(wg genkey)
        hv_public_key=$(echo "$hv_private_key" | wg pubkey)
        hv_preshared_key=$(wg genpsk)
        if [[ -f /etc/wireguard/oc_public.key ]]; then
          master_pub_key=$(cat /etc/wireguard/oc_public.key)
        else
          if ! command -v wg &> /dev/null; then
            if command -v apt > /dev/null; then
              apt -y install wireguard-tools &> /dev/null
            else
              dnf -y install wireguard-tools &> /dev/null
            fi
          fi
        fi
        if [[ ! -f "$master_wg_config" ]]; then
          info "Constructing controller WireGuard interface configuration profile."
          mkdir -p /etc/wireguard
          chmod 700 /etc/wireguard
          local master_priv master_pub
          master_priv=$(wg genkey)
          master_pub=$(echo "$master_priv" | wg pubkey)
          echo "$master_pub" > /etc/wireguard/oc_public.key
          echo "$master_priv" > /etc/wireguard/oc_private.key
          master_pub_key="$master_pub"
          local controller_outbound_nic
          controller_outbound_nic=$(awk 'NR==1{print $5}' <(ip -4 -6 route show default | grep -v "virbr"))
          # ==== Configure Controller Firewall ====
          if command -v nft >/dev/null 2>&1; then
            FW_POSTUP="
              #PostUp = nft add rule inet filter forward iifname \"one-click\" oifname \"${controller_outbound_nic}\" accept
              #PostUp = nft add rule inet filter forward iifname \"${controller_outbound_nic}\" oifname \"one-click\" ct state related,established accept
              PostUp = nft add table ip wg-nat
              PostUp = nft flush table ip wg-nat
              PostUp = nft add chain ip wg-nat postrouting '{ type nat hook postrouting priority 100; }'
              PostUp = nft add rule ip wg-nat postrouting oifname \"${controller_outbound_nic}\" masquerade
              PostUp = nft add table ip6 wg-nat6
              PostUp = nft flush table ip6 wg-nat6
              PostUp = nft add chain ip6 wg-nat6 postrouting '{ type nat hook postrouting priority 100; }'
              PostUp = nft add rule ip6 wg-nat6 postrouting oifname \"${controller_outbound_nic}\" masquerade
              PostUp = nft add rule ip6 wg-nat6 postrouting ip6 saddr fd00:99aa::/64 oifname \"${controller_outbound_nic}\" masquerade
            "
            FW_PREDOWN="
              #PreDown = nft delete rule inet filter forward iifname \"one-click\" oifname \"${controller_outbound_nic}\" accept
              #PreDown = nft delete rule inet filter forward iifname \"${controller_outbound_nic}\" oifname \"one-click\" ct state related,established accept
              PreDown = nft delete table ip wg-nat
              PreDown = nft delete table ip6 wg-nat6
            "
          elif command -v iptables >/dev/null 2>&1; then
            FW_POSTUP="
              #PostUp = iptables -A FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
              #PostUp = iptables -A FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
              PostUp = iptables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
              PostUp = ip6tables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
              PostUp = ip6tables -t nat -I POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE
            "
            FW_PREDOWN="
              #PreDown = iptables -D FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
              #PreDown = iptables -D FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
              PreDown = iptables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
              PreDown = ip6tables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
              PreDown = ip6tables -t nat -D POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE
            "
          else
            error "Neither iptables nor nftables is installed. A firewall backend is required for NAT."
            exit 1
          fi
          [[ -z "$controller_outbound_nic" ]] && controller_outbound_nic="eth0"
          cat > "$master_wg_config" <<EOF
[Interface]
Address = 10.10.0.1/16
MTU = 1412
SaveConfig = false
ListenPort = 51821
PrivateKey = ${master_priv}

PostUp = sysctl -w net.ipv4.conf.all.forwarding=1
PostUp = sysctl -w net.ipv4.conf.default.forwarding=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1
PostUp = sysctl -w net.ipv6.conf.default.forwarding=1

PreDown = true
# ==== Layer-3 Forwarding Pipelines ====
${FW_POSTUP}

${FW_PREDOWN}

EOF
          chmod 600 "$master_wg_config"
          systemctl stop wg-quick@one-click &>/dev/null || true
          ip link delete dev one-click &>/dev/null || true
          systemctl daemon-reload &>/dev/null
          systemctl enable --now wg-quick@one-click &>/dev/null
        else
          master_pub_key=$(cat /etc/wireguard/oc_public.key)
        fi
      fi
      info "Registering Tunnel Endpoint locally in Controller configuration files."
      cat >> "$master_wg_config" <<EOF

# ==== Hypervisor Cluster Node: $hv_node_name ====
[Peer]
PublicKey = ${hv_public_key}
PresharedKey = ${hv_preshared_key}
AllowedIPs = ${hv_private_ip}/32
PersistentKeepalive = 25
EOF
      local port_state_file="/etc/one-click/virtualization/allocated_ports.db"
      local port_pool_file="/etc/one-click/virtualization/ports_pool.txt"
      local remote_env_file=/tmp/env_file
      mkdir -p "$(dirname "$port_pool_file")"
      if [ ! -f "$port_pool_file" ]; then
        info "Initializing port pool file."
        seq 51821 80000 > "$port_pool_file"
        touch "$port_state_file"
      fi
      local wg_peer_port=""
      while IFS= read -r wg_port; do
        sed -i "1d" "$port_pool_file" || true
        if ss -tuln | grep -q ":${wg_port}\b"; then
          continue
        fi
        if iptables -t nat -S | grep -q "dport ${wg_port}\b"; then
          continue
        fi
        if grep -q "${wg_port}" "$port_state_file" 2>/dev/null; then
          continue
        fi
        wg_peer_port="$wg_port"
        break
      done < "$port_pool_file"
      local hv_resolved_public_ip
      hv_resolved_public_ip="${ip}"
      export WG_HIDE_KEYS=never
      echo "$hv_preshared_key" | wg set one-click peer "$hv_public_key" preshared-key /dev/stdin allowed-ips "${hv_private_ip}/32" endpoint "${hv_resolved_public_ip}:${wg_peer_port}"
      sed -i "1d" "$FLEET_AVAILABLE_IPS_FILE"
      echo "$hv_private_ip" >> "$FLEET_USED_IPS_FILE"
      local hv_wg_stage="/tmp/wg_build_${hv_node_name}.conf"
      info "Rendering WireGuard interface credentials into staging layout."
      if [[ "$IPv6_ONLY_2_v4" == true ]]; then
        dns_guard="DNS = 10.10.0.1"
        ANSIBLE_HOST_KEY_CHECKING=False \
        ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
        ansible "$host" \
          -i /etc/one-click/fleet/inventory.yml \
          -u oneclick --become \
          -m shell -a "
            sudo systemctl enable --now systemd-resolved &> /dev/null || true
          " &> /dev/null
      fi
      cat > "$hv_wg_stage" <<EOF
[Interface]
Address = ${hv_private_ip}/16
MTU = 1412
SaveConfig = true
${dns_guard:-}
PrivateKey = ${hv_private_key}
ListenPort = ${wg_peer_port}

[Peer]
PublicKey = ${master_pub_key}
PresharedKey = ${hv_preshared_key}
AllowedIPs = 10.10.0.0/16
Endpoint = ${CONTROLLER_IP}:51821
PersistentKeepalive = 25
EOF
      chmod 600 "$hv_wg_stage"
      cat > "$remote_env_file" <<EOF
CONTROLLER_IP="$CONTROLLER_IP"
CONTROLLER_NAME="$CONTROLLER_NAME"
ROLE_TYPE="$role_type"
IS_MASTER="false"
EOF
      info "Wireguard config prepared and shared out to target machine [$host]."
      ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
	    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	    ansible "$host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m copy -a "src=$hv_wg_stage dest=/etc/wireguard/one-click.conf owner=root group=root mode=0600" &>/dev/null
      rm -f "$hv_wg_stage"
      info "Pushing Controller env file [$host]."
      ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
	    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	    ansible "$host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m copy -a "src=$remote_env_file dest=/etc/one-click/fleet/controller.env owner=root group=root mode=0600" &>/dev/null
      rm -f "$remote_env_file"
	  mkdir -p "$(dirname "$hypervisor_wg_file")"
      if [[ ! -f "$hypervisor_wg_file" ]] || [[ ! -s "$hypervisor_wg_file" ]] || ! jq empty "$hypervisor_wg_file" 2>/dev/null; then
          echo "{}" > "$hypervisor_wg_file"
      fi
      jq --arg hv "$host" --arg ip "$hv_private_ip" \
         '.[$hv] = $ip' "$hypervisor_wg_file" > "${hypervisor_wg_file}.tmp" && mv "${hypervisor_wg_file}.tmp" "$hypervisor_wg_file"
      info "Invoking runtime network shifts and restarting service on hypervisor host."
	  set +e
      ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	    ansible "$host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "
	      if ! command -v wg > /dev/null; then
		    if command -v apt > /dev/null; then
		      apt -y install wireguard-tools &> /dev/null
		    else
		      dnf -y install wireguard-tools &> /dev/null
		    fi
          fi
	      sysctl -w net.ipv4.ip_forward=1 && \
          echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-oneclick-vps-routing.conf && \
		  echo 'net.ipv4.conf.all.rp_filter=2' > /etc/sysctl.d/99-oneclick-vps-routing.conf && \
          echo 'net.ipv4.conf.default.rp_filter=2' > /etc/sysctl.d/99-oneclick-vps-routing.conf && \
          echo 'net.ipv4.conf.one-click.rp_filter=2' > /etc/sysctl.d/99-oneclick-vps-routing.conf && \
          (if command -v iptables >/dev/null; then
            iptables -C INPUT -p udp --dport 51821 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 51821 -j ACCEPT 2>/dev/null || true;
            iptables -C INPUT -p udp --dport 67 --sport 68 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 67 --sport 68 -j ACCEPT 2>/dev/null || true;
            iptables -C OUTPUT -p udp --dport 68 --sport 67 -j ACCEPT 2>/dev/null || iptables -I OUTPUT -p udp --dport 68 --sport 67 -j ACCEPT 2>/dev/null || true;
		    iptables -C INPUT -p udp --dport 53 --sport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 --sport 53 -j ACCEPT 2>/dev/null || true;
		    iptables -C INPUT -p udp --dport 53 --sport 53 -j ACCEPT 2>/dev/null || iptables -I OUTPUT -p udp --dport 53 --sport 53 -j ACCEPT 2>/dev/null || true;
          fi) && \
          (if command -v firewall-cmd >/dev/null; then
            local fw_changed=0;
            if ! firewall-cmd --zone=public --query-port=51821/udp --permanent &>/dev/null; then
              firewall-cmd --zone=public --add-port=51821/udp --permanent &>/dev/null && fw_changed=1 || true;
            fi;
            if ! firewall-cmd --zone=public --query-rich-rule='rule family=\"ipv4\" protocol=\"udp\" port port=\"67\" source-port=\"68\" accept' --permanent &>/dev/null; then
              firewall-cmd --zone=public --add-rich-rule='rule family=\"ipv4\" protocol=\"udp\" port port=\"67\" source-port=\"68\" accept' --permanent &>/dev/null && fw_changed=1 || true;
            fi;
            if ! firewall-cmd --zone=public --query-rich-rule='rule family=\"ipv4\" protocol=\"udp\" port port=\"68\" source-port=\"67\" accept' --permanent &>/dev/null; then
              firewall-cmd --zone=public --add-rich-rule='rule family=\"ipv4\" protocol=\"udp\" port port=\"68\" source-port=\"67\" accept' --permanent &>/dev/null && fw_changed=1 || true;
            fi;
            if [ \"\$fw_changed\" -eq 1 ]; then
              firewall-cmd --reload &>/dev/null || true;
            fi;
          fi) && \
          systemctl daemon-reload && \
          systemctl enable wg-quick@one-click 2>/dev/null && \
          systemctl restart wg-quick@one-click 2>/dev/null
        " &>/dev/null
	  set -e
      success "Hypervisor mesh pipe successfully initialized. Interface link live at:$(tput setaf 97) $hv_private_ip ${reset}"
  else
    info "Initialization path. Progressing with setup."
    success "Fleet Member initialized successfully."
  fi
  if bash /etc/one-click/write_inventory.sh ; then
	if [[ -d "/etc/bind/zones" ]]; then
      info "Updating active DNS cluster mesh authority mappings."
      for meta in /etc/one-click/dns/domains/*/meta.conf; do
        if [[ -f "$meta" ]]; then
          local active_dom
          active_dom=$(grep '^DOMAIN=' "$meta" | cut -d= -f2-)
          local active_prov
          active_prov=$(grep '^PROVIDER=' "$meta" | cut -d= -f2-)
          if [[ "$active_prov" == "bind" ]]; then
            dns_bind_create_zone "$active_dom"
          fi
        fi
      done
	else
	  fleet_dns_cluster
    fi
    success "Cluster mesh successfully updated. Each peer now shares mutual rootless trust."
	fleet_rule_engine_init
  else
    error "Failed to mesh peer authentication keys."
    return 1
  fi
  trap - ERR
}
# ==== DNS BRIDGE ====
fleet_dns_cluster() {
  . "/etc/one-click/fleet/controller.env"
  local bind_domains=()
  for meta in /etc/one-click/dns/domains/*/meta.conf; do
    if [[ -f "$meta" ]]; then
      local active_dom active_prov
      active_dom=$(grep '^DOMAIN=' "$meta" | cut -d= -f2-)
      active_prov=$(grep '^PROVIDER=' "$meta" | cut -d= -f2-)
      if [[ "$active_prov" == "bind" && -n "$active_dom" ]]; then
        bind_domains+=("$active_dom")
      fi
    fi
  done
  if [[ ${#bind_domains[@]} -eq 0 ]]; then
    info "No active BIND database registries to sync across the cluster."
    return 0
  fi
  local domain_list_string="${bind_domains[*]}"
  local install_needed=0
  if [[ "${server_type:-}" == "vps" ]]; then
    type_target=$host
	member_stat=$host
	sync_fleet="to $host"
	bind_avail="on $host"
  else
    type_target=all
	member_stat="some fleet members"
	sync_fleet="across the fleet"
	bind_avail="across all fleet secondary nodes"
  fi
  info "Checking for BIND daemon availability $bind_avail."
  if ! ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible $type_target -e "ansible_ignore_unreachable=True" -i /etc/one-click/fleet/inventory.yml -u oneclick --become \
    -m shell -a "command -v named" &> /dev/null; then
    install_needed=1
  fi
  if [[ $install_needed -eq 1 ]]; then
    warn "Missing BIND configurations detected on $member_stat." \
	  "Initiating installation routine."
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible $type_target \
	  -e "ansible_ignore_unreachable=True" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        if ! command -v bind9 &> /dev/null || command -v named &> /dev/null; then
          if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y bind9 dnsutils
          elif command -v dnf & >/dev/null; then
            dnf install -y bind bind-utils
		  elif command -v yum & >/dev/null; then
            dnf install -y bind bind-utils
          fi
		fi
		if [ $(pgrep -af named | wc -l) -gt 1 ]; then
		  pkill named
		  systemctl start named
        fi
      " 2> /dev/null | sed -En "
      /^($|TASK|PLAY)/ {
	    s/[^[]*\[([^]]*).*/\1/;
		h;
		d
	  };
      /^ok/ {
		G;
		s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/
	  };
      /^changed/I {
		G;
		s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/I
	  };
      /^skipping/ {
		G;
		s/^(skipping.*)\n(.*)/$(tput setaf 45)\1 ->${magenta} \2${reset}/
	  };
      /^(failed|fatal)/ {
		G;
	    s/^((failed|fatal)[^>]*> )[^F]*(.*):.*/${red}\1 ->${magenta} \3${reset}/;
		s/ => //
	  };
	  /^\[/d;
      s/${host}|localhost/${yellow}&/;
	  s/failed=[1-9][0-9]*/${red}&${reset}/g;
	  s/skipped=[1-9][0-9]*/$(tput setaf 45)&${reset}/g;
	  s/changed=[1-9][0-9]*/${orange}&${reset}/g;
	  s/ok=[1-9][0-9]*/${green}&${reset}/g;
	  /unreachable=[1-9][0-9]*/s/.*/${red}&${reset}/;
	  /^(ok|changed|skipping|fatal)/! {
	    s/^[[:alnum:].:_-]+/${blue}&${reset}/
	  };
	  /^ok/s/\] ->/${green}&${magenta}/;
	  /^skipping/s/\] ->/$(tput setaf 45)&${magenta}/;
	  /^changed/s/\] ->/${orange}&${magenta}/;
	  /^fatal/s/(\[)([^]]*)/${red}\1${blue}\2${red}/;
    " || true
  else
    success "BIND infrastructure validated."
  fi
  info "Synchronizing DNS zone registries (${#bind_domains[@]} domains) $sync_fleet."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible $type_target \
    -e "ansible_ignore_unreachable=True" \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a "
      named_local=\"/etc/bind/named.conf.local\"
      zone_dest_dir=\"/var/cache/bind\"
      if [ ! -f \"\$named_local\" ] && [ -f \"/etc/named.conf\" ]; then
        named_local=\"/etc/named.conf\"
        zone_dest_dir=\"/var/named/slaves\"
      fi
      systemctl enable --now bind9 2>/dev/null || systemctl enable --now named 2>/dev/null
      mkdir -p \"\$zone_dest_dir\"
      registry_updated=0
      for target_domain in $domain_list_string; do
        if ! grep -q \"zone \\\"\$target_domain\\\"\" \"\$named_local\"; then
          cat >> \"\$named_local\" <<EOF

zone \"\$target_domain\" {
    type slave;
    file \"\${zone_dest_dir}/db.\$target_domain\";
    masters { ${CONTROLLER_IP}; };
};
EOF
          registry_updated=1
        fi
      done
      if [ \$registry_updated -eq 1 ]; then
        systemctl reload bind9 2>/dev/null || systemctl reload named 2>/dev/null
      fi
  " &> /dev/null || true
  success "DNS secondary database registries successfully synchronized!"
}
dns_bind_create_zone() {
  local domain="$1"
  local zone_file
  . /etc/one-click/fleet/controller.env
  zone_file="$(dns_bind_zone_file "$domain")"
  local peer_ips=()
  for file in "/etc/one-click/fleet/state"/*.conf; do
    [[ ! -f "$file" ]] && continue
    local p_ip
    p_ip=$(grep '^IP=' "$file" | cut -d= -f2-)
    [[ -n "$p_ip" && "$p_ip" != "${CONTROLLER_IP:-}" ]] && peer_ips+=("$p_ip")
  done
  local allow_transfer_string="none;"
  local also_notify_line=""
  if [[ ${#peer_ips[@]} -gt 0 ]]; then
    allow_transfer_string="$(printf '%s; ' "${peer_ips[@]}")"
    also_notify_line="also-notify { ${allow_transfer_string} };"
  fi
  mkdir -p /etc/bind/zones
  cat > "$zone_file" <<EOF
\$TTL 3600
@ IN SOA ns1.${domain}. admin.${domain}. (
    $(date +%Y%m%d01) ; Serial
    3600             ; Refresh
    1800             ; Retry
    604800           ; Expire
    86400            ; Minimum TTL
)

@   IN NS ns1.${domain}.
EOF
  printf "%-12s IN A    %s\n" "ns1" "$CONTROLLER_IP" >> "$zone_file"
  local idx=2
  for p_ip in "${peer_ips[@]}"; do
    printf "@   IN NS ns${idx}.${domain}.\n" >> "$zone_file"
    printf "%-12s IN A    %s\n" "ns${idx}" "$p_ip" >> "$zone_file"
    ((idx++))
  done
  local named_local="/etc/bind/named.conf.local"
  if [[ -f "$named_local" ]]; then
    if ! grep -q "zone \"$domain\"" "$named_local"; then
      info "Registering Primary zone '$domain' inside named.conf.local."
      cat >> "$named_local" <<EOF

zone "$domain" {
    type master;
    file "$zone_file";
    allow-transfer { ${allow_transfer_string} };
    ${also_notify_line}
};
EOF
      command -v systemctl &>/dev/null && sudo systemctl reload bind9 &>/dev/null || sudo systemctl reload named &>/dev/null
    fi
  fi
  if [[ -f "$named_local" ]]; then
    local needs_reload=0
    while read -r target_zone; do
      [[ -z "$target_zone" ]] && continue
      local current_acl
      current_acl=$(sed -n "/zone \"$target_zone\"/,/};/ { /allow-transfer/p }" "$named_local")
      if [[ "$current_acl" == *"$allow_transfer_string"* ]]; then
        continue
      fi
      printf "$(tput setaf 197)[DNS]: ${reset}%s\n" "Synchronizing zones for '$target_zone' to $host"
      sed -i "/zone \"$target_zone\"/,/};/ {
        s/allow-transfer {[^}]*}/allow-transfer { ${allow_transfer_string} }/
        s/also-notify {[^}]*}/also-notify { ${allow_transfer_string} }/
      }" "$named_local"
      needs_reload=1
    done < <(grep '^zone ' "$named_local" | awk -F'"' '{print $2}')
    if [[ "$needs_reload" -eq 1 ]]; then
      command -v systemctl &>/dev/null && sudo systemctl reload bind9 &>/dev/null || sudo systemctl reload named &>/dev/null
    fi
  fi
  # ==== Fleet Sync ====
}
dns_bind_zone_file() {
  echo "/etc/bind/zones/db.$1"
}
#========= END BRIDGE ==========
fleet_update_keys() {
  . "$fleet_root/controller.env"
  build_vars
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    warn "Only the controller can update cluster keys."
    return 1
  fi
  fleet_init
  local key_dir="$fleet_root/keys"
  local current_key="$key_dir/id_ed25519"
  local backup_key="$key_dir/id_ed25519.old"
  local stage_key="$key_dir/id_ed25519.tmp"
  if [[ ! -f "$current_key" ]]; then
    error "No active SSH key found at $current_key to rotate from."
    return 1
  fi
  printf "${green}[localhost ${magenta}1/${blue}4${green}]${reset} %s\n" "Generating fresh staging full-mesh keypair."
  rm -f "$stage_key" "${stage_key}.pub"
  ssh-keygen -t ed25519 -N "" -f "$stage_key" | sed -Eun '/The key fingerprint is:/{:a;n;p;ba}'
  local old_pub new_pub new_priv
  old_pub=$(cat "${current_key}.pub")
  new_pub=$(cat "${stage_key}.pub")
  new_priv=$(cat "${stage_key}")
  printf "${green}[localhost ${magenta}2/${blue}4${green}]${reset} %s\n" "Authorizing new key across remote fleet cluster."
  (ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook \
    -i "$fleet_root/inventory.yml" \
    -u oneclick --become \
    "$fleet_root/playbooks/key_rotation.yml" \
    -e "rotation_phase=stage" \
    -e "new_pub_key='$new_pub'" \
    -e "new_priv_key='$new_priv'" 2> /dev/null | \
      sed -En "
        /PLAY RECAP/ {
          :a;
          n;
          s/^([[:alnum:]]+)[ \t]+/[\1] /;
          /ok=[1-9]/I{s/[^:]*|ok=[1-9]/${green}&${reset}/g};
          /(unreachable|failed)=[1-9]/I{s/[^:]*|(unreachable|failed)=[1-9]/${red}&${reset}/g};
          s/changed=[1-9]/${orange}&${reset}/;
          s/skipped=[1-9]/${blue}&${reset}/;
          s/rescued=[1-9]/${magenta}&${reset}/;
          p;
          ba
        }
      " ) || {
      error "Key staging failed! Aborting rotation to prevent lockouts."
      rm -f "$stage_key" "${stage_key}.pub"
      return 1
    }
  printf "${green}[localhost ${magenta}3/${blue}4${green}]${reset} %s\n" "Promoting staging keys to primary on controller."
  cp "$current_key" "$backup_key"
  cp "${current_key}.pub" "${backup_key}.pub"
  mv "$stage_key" "$current_key"
  mv "${stage_key}.pub" "${current_key}.pub"
  chmod 600 "$current_key"
  chmod 644 "${current_key}.pub"
  printf "${green}[localhost ${magenta}4/${blue}4${green}]${reset} %s\n" "Safely purging old stale cluster keys from remote nodes."
  (ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook \
    -i "$fleet_root/inventory.yml" \
    -u oneclick --become \
    "$fleet_root/playbooks/key_rotation.yml" \
    -e "rotation_phase=purge" \
    -e "old_pub_key='$old_pub'" 2> /dev/null | \
      sed -En "
        /PLAY RECAP/ {
          :a;
          n;
          s/^([[:alnum:]]+)[ \t]+/[\1] /;
          /ok=[1-9]/I{s/[^:]*|ok=[1-9]/${green}&${reset}/g};
          /(unreachable|failed)=[1-9]/I{s/^[[:alnum:]]+|(unreachable|failed)=[1-9]/${red}&${reset}/g};
          s/changed=[1-9]/${orange}&${reset}/;
          s/skipped=[1-9]/${blue}&${reset}/;
          s/rescued=[1-9]/${magenta}&${reset}/;
          p;
          ba
        }
      " ) || {
      warn "Purge sweep encountered an issue. Old key may still be authorized on some hosts."
      return 0
    }
  rm -f "$backup_key" "${backup_key}.pub"
  success "SSH Key rotation completed successfully! Cross-trust mesh is fully unblocked."
}
fleet_remove() {
  local host="$1"
  . "$fleet_root/controller.env"
  build_vars
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    warn "Only the controller can add and remove peers."
    return 1
  fi
  [[ -z "$host" ]] && {
    error "Usage: fleet remove <hostname>"
    return 1
  }
  local target_conf="$fleet_root/state/$host.conf"
  if [[ ! -f "$target_conf" ]]; then
    info "Host $host is not present in active fleet state."
    return 0
  fi
  rm -f "$target_conf"
  bash /etc/one-click/write_inventory.sh
  info "Removed $host locally from state configurations."
  info "Synchronizing fleet state. Purging $host from fleet trust mesh."
  ANSIBLE_HOST_KEY_CHECKING=False \
  ANSIBLE_SSH_TIMEOUT=3 \
  ANSIBLE_GATHERING=explicit \
  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
  ansible-playbook \
    "$fleet_root/playbooks/cluster_mesh.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    -b \
    -e "controller_name=$CONTROLLER_IP" &>/dev/null || true
  bash /etc/one-click/write_inventory.sh
  if [[ -d "/etc/bind/zones" ]]; then
    info "Purging removed peer from DNS cluster authority mappings."
    for meta in /etc/one-click/dns/domains/*/meta.conf; do
      if [[ -f "$meta" ]]; then
        local active_dom active_prov
        active_dom=$(grep '^DOMAIN=' "$meta" | cut -d= -f2-)
        active_prov=$(grep '^PROVIDER=' "$meta" | cut -d= -f2-)
        if [[ "$active_prov" == "bind" && -n "$active_dom" ]]; then
          dns_bind_create_zone "$active_dom" 2>/dev/null || true
        fi
      fi
    done
  fi
  printf "${red}[${green}[SUCCESS]${red}] %s\n" "Successfully isolated and removed $host from the fleet network.${reset}"
}
fleet_purge_hypervisor() {
  local vps_name="$1"
  local target_host="$2"
  [[ -z "$vps_name" || -z "$target_host" ]] && return 1
  local clean_vps_name="${vps_name//_win_path/}"
  local vg_name="one_click_vg"
  local lv_name="lv_${clean_vps_name}"
  local lv_path="/dev/${vg_name}/${lv_name}"
  local dm_device="${vg_name}-${lv_name//-/--}"
  info "Removing '$vps_name' (LV: $lv_name) on [$target_host] and associated objects."
  local cleanup_payload
  cleanup_payload=$(cat << 'EOF'
clean_vps_name="%NAME%"
target_name="%RAW_NAME%"
virsh destroy "${target_name}" 2>/dev/null || true
virsh destroy "${clean_vps_name}" 2>/dev/null || true
virsh undefine "${target_name}" --remove-all-storage 2>/dev/null || true
virsh undefine "${clean_vps_name}" --remove-all-storage 2>/dev/null || true
rm -f /var/lib/libvirt/images/${target_name}_cloudinit.iso
rm -f /var/lib/libvirt/images/${clean_vps_name}_cloudinit.iso
rm -f /var/lib/libvirt/images/${clean_vps_name}.qcow2
rm -f /var/lib/libvirt/images/${clean_vps_name}.raw
rm -rf /tmp/build_${clean_vps_name} /tmp/build_${target_name}
rm -f /tmp/${clean_vps_name}_user_data.yml /tmp/${clean_vps_name}_meta_data.yml /tmp/${clean_vps_name}_network_config.yml
rm -f /tmp/unattend_${clean_vps_name}.xml

VG_NAME="one_click_vg"
LV_NAME="lv_${clean_vps_name}"
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"

if lvdisplay "${LV_PATH}" &>/dev/null; then
  lvchange -an "${LV_PATH}" 2>/dev/null || true
  dmsetup remove -f "${VG_NAME}-${LV_NAME//-/--}" 2>/dev/null || true
  lvremove -f -y "${LV_PATH}" 2>/dev/null || true
fi

if lvdisplay "/dev/${VG_NAME}/lv_${target_name}" &>/dev/null; then
  lvchange -an "/dev/${VG_NAME}/lv_${target_name}" 2>/dev/null || true
  lvremove -f -y "/dev/${VG_NAME}/lv_${target_name}" 2>/dev/null || true
fi
EOF
  )
  cleanup_payload="${cleanup_payload//%NAME%/$clean_vps_name}"
  cleanup_payload="${cleanup_payload//%RAW_NAME%/$vps_name}"
  local local_hostname
  local_hostname=$(hostname -s 2>/dev/null || echo "localhost")
  if [[ "$target_host" == "$local_hostname" || "$target_host" == "127.0.0.1" || "$target_host" == "localhost" ]]; then
    eval "$cleanup_payload"
  else
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=5 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "$cleanup_payload" &>/dev/null || true
  fi
  rm -rf "/etc/one-click/virtualization/deployments/${clean_vps_name}" 2>/dev/null || true
  rm -rf "/etc/one-click/virtualization/staging/${clean_vps_name}" 2>/dev/null || true
}
fleet_list() {
  local inventory_file="$fleet_root/inventory.yml"
  if [[ ! -f "$inventory_file" ]]; then
    error "Missing asset registry file matrix at $inventory_file"
	info "Run $(tput setaf 227)one-click fleet verify${reset} to generate."
    return 1
  fi
  (printf "%s\t%s\t%s\n" "${blue}HOSTNAME" "IP" "PORT${reset}"
  printf "%s\t%s\t%s\n" "${magenta}--------" "${green}--" "${yellow}----${reset}"
  awk '
    /^[[:space:]]*(all|vars|hosts):/ { next }
    /^[[:space:]]*[^:]+:[[:space:]]*$/ {
      gsub(/[[:space:]:]/, "", $1)
      current_host = $1
      next
    }
    /ansible_host:/ {
      gsub(/[[:space:]]/, "", $2)
      current_ip = $2
      next
    }
    /ansible_port:/ {
      gsub(/[[:space:]]/, "", $2)
      if (current_host != "" && current_ip != "") {
        printf "'"${magenta}"'%s\t'"${green}"'%s\t'"${yellow}"'%s'"${reset}"'\n", current_host, current_ip, $2
        current_host = ""; current_ip = ""
      }
    }
  ' "$inventory_file") | column -t -s $'\t'
}
fleet_verify() {
  fleet_init
  local_host=$(hostname -s)
  build_vars
  . "$fleet_root/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
     info "Verifying connection to controller ($CONTROLLER_IP) and to fleet peers"
  fi
  echo ${orange}====================================${reset}
  while IFS=' ' read -r hostname ip port; do
    (
      if ssh \
        -n \
        -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
        -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
        -o ConnectTimeout=1 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
		-p "${port:-22}" \
        "oneclick@$ip" \
        "echo alive" >/dev/null 2>&1;
      then
        printf "%b%s%b | %bONLINE%b\n" \
          "$magenta" "$hostname" "$reset" \
          "$green" "$reset"
      else
        printf "%b%s%b | %bOFFLINE%b\n" \
          "$orange" "$hostname" "$reset" \
          "$red" "$reset"
      fi
    ) &
  done < <(
    awk '
      /^[[:space:]]*(all|vars|hosts):/ { next }
      /^[[:space:]]*[^:]+:[[:space:]]*$/ {
        gsub(/[[:space:]:]/, "", $1)
        current_host = $1
        next
      }
      /ansible_host:/ {
        gsub(/[[:space:]]/, "", $2)
        if (current_host != "") {
          print current_host, $2
          current_host = ""
        }
      }
	  /ansible_port:/ {
        gsub(/[[:space:]]/, "", $2)
        if (current_host != "" && current_ip != "") {
          print current_host, current_ip, $2
          current_host = ""
          current_ip = ""
        }
      }
    ' "$fleet_root/inventory.yml"
  ) | sort -t'|' -k2 -r | column -t
  wait
  echo ${orange}====================================${reset}
}
fleet_update() {
  . "$fleet_root/controller.env"
  build_vars
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    warn "Only the controller can run a fleet update. Please either run a local update or use the controller $CONTROLLER_IP"
	return 1
  fi
  fleet_init
  tmux new-session -d -s "oneclick-update-local" "/usr/local/bin/one-click update-y"
  echo "${green}ok: [localhost]${reset}"
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    "$fleet_root/playbooks/update.yml" 2> /dev/null | sed -Eun "
      {
        s/^(ok[^]]*\]):.*/${green}\1${reset}/
      };
      {
        s/^(fatal[^]]*\]):.*/${red}\1${reset}/p
      };
    "
}
fleet_audit() {
  fleet_init
  local local_host
  local_host=$(hostname -s)
  local f_root="/etc/one-click/fleet"
  local audit_dir="$f_root/audits"
  mkdir -p "$audit_dir"
  build_vars
  if [[ -f "$f_root/controller.env" ]]; then
    source "$f_root/controller.env"
  else
    error "Missing controller configuration tracker. Run fleet init first."
    return 1
  fi
  rm -f "$audit_dir"/*.json
  info "Auditing local metrics context."
  (
    local cpus_count l_load os_name version_id kernel_release
    cpus_count=$(nproc 2>/dev/null || echo "?")
    l_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    [[ -f /etc/os-release ]] && source /etc/os-release
    os_name="${NAME:-Linux}"
    version_id="${VERSION_ID:-Unknown}"
    kernel_release=$(uname -r)
	c_model=$(sed -En '/^[ \t]*Model name/I{s/[^(]*[ \t]+([^@]*).*/\1/p}' <(lscpu 2>/dev/null) | xargs)
    [[ -z "$c_model" ]] && c_model="Unknown"
    local r_total r_free d_total d_free
    r_total=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
    r_free=$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
    d_total=$(df / | awk 'NR==2 {printf "%.1f", $2/1024/1024}')
    d_free=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
    cat > "${audit_dir}/${local_host}.json" <<EOF
{
  "hostname": "${local_host}",
  "distribution": "${os_name}",
  "version": "${version_id}",
  "kernel": "${kernel_release}",
  "cpus": "${cpus_count}",
  "load_1m": "${l_load}",
  "ram_total_gb": "${r_total}G",
  "ram_free_gb": "${r_free}G",
  "disk_total_gb": "${d_total}G",
  "disk_free_gb": "${d_free}G",
  "cpu_model": "${c_model}"
}
EOF
  )
  if [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
    info "Auditing remote fleet cluster via raw mesh orchestration."
    local private_key="$f_root/keys/id_ed25519"
    [[ ! -f "$private_key" ]] && private_key="/home/oneclick/.ssh/id_ed25519"
    for file in "$f_root/state"/*.conf; do
      [[ ! -f "$file" ]] && continue
      local peer_target
      peer_target=$(basename "$file" .conf)
      [[ "$peer_target" == "$local_host" ]] && continue
      local peer_ip
      peer_ip=$(grep '^IP=' "$file" | cut -d= -f2- | tr -d '[:space:]')
      [[ -z "$peer_ip" ]] && continue
      set +e
      ssh -i "$private_key" -o StrictHostKeyChecking=no -o ConnectTimeout=3 "oneclick@${peer_ip}" "sudo bash -s" 2>/dev/null > "${audit_dir}/${peer_target}.json" << 'EOF'
        cpus=$(nproc 2>/dev/null || echo '?')
        load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
        [ -f /etc/os-release ] && . /etc/os-release
        os=${NAME:-Linux}
        ver=${VERSION_ID:-Unknown}
        kern=$(uname -r)
		mod_name=$(sed -En '/^[ \t]*Model name/I{s/[^(]*[ \t]+([^@]*).*/\1/p}' <(lscpu 2>/dev/null) | xargs)
        [ -z "$mod_name" ] && mod_name="Unknown"
        r_tot=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
        r_fr=$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
        d_tot=$(df / | awk 'NR==2 {printf "%.1f", $2/1024/1024}')
        d_fr=$(df / | awk 'NR==2 {printf "%.1f", $4/1024/1024}')
        cat <<EOX
{
  "hostname": "$(hostname -s)",
  "distribution": "$os",
  "version": "$ver",
  "kernel": "$kern",
  "cpus": "$cpus",
  "load_1m": "$load",
  "ram_total_gb": "${r_tot}G",
  "ram_free_gb": "${r_fr}G",
  "disk_total_gb": "${d_tot}G",
  "disk_free_gb": "${d_fr}G",
  "cpu_model": "${mod_name}"
}
EOX
EOF
      set -e
      [[ ! -s "${audit_dir}/${peer_target}.json" ]] && rm -f "${audit_dir}/${peer_target}.json"
    done
  else
    local remote_files
    remote_files=$(ssh -i /home/oneclick/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "oneclick@${CONTROLLER_IP}" "sudo find $audit_dir/ -maxdepth 1 -name '*.json' -printf '%f\n'" 2>/dev/null)
    if [[ -n "$remote_files" ]]; then
      for f in $remote_files; do
        [[ "$f" == "${local_host}.json" ]] && continue
        ssh -i /home/oneclick/.ssh/id_ed25519 -o StrictHostKeyChecking=no "oneclick@${CONTROLLER_IP}" "sudo cat ${audit_dir}/$f" > "${audit_dir}/$f" 2>/dev/null
      done
    fi
  fi
  echo -e "\n${blue}============================================================= ${orange}FLEET AUDIT REPORT${blue} ====================================================================${reset}"
echo
(
  echo -e "${yellow}--------\t---------\t-------\t------\t----\t-------\t---------------\t----------------\t---------${reset}"
  echo -e "${magenta}HOSTNAME\tOS_DISTRO\tVERSION\tKERNEL\tCPUS\tLOAD_1M\tRAM(FREE/TOTAL)\tDISK(FREE/TOTAL)\tCPU_MODEL${reset}"
  echo -e "${yellow}--------\t---------\t-------\t------\t----\t-------\t---------------\t----------------\t---------${reset}"
  if [[ -f "${audit_dir}/${local_host}.json" ]]; then
    eval "$(jq -r '@sh "h=\(.hostname) d=\(.distribution) v=\(.version) k=\(.kernel) c=\(.cpus) l=\(.load_1m) rf=\(.ram_free_gb) rt=\(.ram_total_gb) df=\(.disk_free_gb) dt=\(.disk_total_gb) m=\(.cpu_model)"' "${audit_dir}/${local_host}.json")"
    [[ -z "$m" || "$m" == "null" ]] && m="-"
    local c_color="${reset}"
    if [[ "$c" != "?" && -n "$l" ]]; then
      local load_pct
      load_pct=$(echo "scale=4; ($l / $c) * 100" | bc 2>/dev/null)
      if (( $(echo "$load_pct >= 80" | bc -l) )); then c_color="${red}"
      elif (( $(echo "$load_pct >= 60" | bc -l) )); then c_color="${yellow}";
      else c_color="$green"; fi
    fi
    local r_color="${reset}"
    local raw_rf="${rf%G}" raw_rt="${rt%G}"
    if [[ -n "$raw_rf" && -n "$raw_rt" && "$raw_rt" != "0.0" ]]; then
      local ram_used ram_pct
      ram_used=$(echo "$raw_rt - $raw_rf" | bc 2>/dev/null)
      ram_pct=$(echo "scale=4; ($ram_used / $raw_rt) * 100" | bc 2>/dev/null)
      if (( $(echo "$ram_pct >= 80" | bc -l) )); then r_color="${red}"
      elif (( $(echo "$ram_pct >= 60" | bc -l) )); then r_color="${yellow}";
      else r_color="$green"; fi
    fi
    local d_color="${reset}"
    local raw_df="${df%G}" raw_dt="${dt%G}"
    if [[ -n "$raw_df" && -n "$raw_dt" && "$raw_dt" != "0.0" ]]; then
      local disk_used disk_pct
      disk_used=$(echo "$raw_dt - $raw_df" | bc 2>/dev/null)
      disk_pct=$(echo "scale=4; ($disk_used / $raw_dt) * 100" | bc 2>/dev/null)
      if (( $(echo "$disk_pct >= 80" | bc -l) )); then d_color="${red}"
      elif (( $(echo "$disk_pct >= 60" | bc -l) )); then d_color="${yellow}";
      else d_color="$green"; fi
    fi
    echo -e "$(tput setaf 227)$h${reset}\t  $d\t  $v\t  $k\t  $c\t  ${c_color}$l${reset}\t    ${r_color}${rf}/${rt}${reset}\t      ${d_color}${df}/${dt}${reset}\t        $(tput setaf 222)$m${reset}"
  else
    echo -e "$local_host\t${red}LOCAL_ERROR${reset}\t-\t-\t-\t-\t-\t-\t-"
  fi
  for host_conf in "$f_root/state"/*.conf; do
    [[ ! -f "$host_conf" ]] && continue
    local current_target
    current_target=$(basename "$host_conf" .conf)
    [[ "$current_target" == "$local_host" ]] && continue
    local json_file="${audit_dir}/${current_target}.json"
    if [[ -f "$json_file" && -s "$json_file" ]]; then
      eval "$(jq -r '@sh "h=\(.hostname) d=\(.distribution) v=\(.version) k=\(.kernel) c=\(.cpus) l=\(.load_1m) rf=\(.ram_free_gb) rt=\(.ram_total_gb) df=\(.disk_free_gb) dt=\(.disk_total_gb) m=\(.cpu_model)"' "$json_file")"
      [[ -z "$m" || "$m" == "null" ]] && m="-"
      local c_color="${reset}"
      if [[ "$c" != "?" && -n "$l" ]]; then
        local load_pct
        load_pct=$(echo "scale=4; ($l / $c) * 100" | bc 2>/dev/null)
        if (( $(echo "$load_pct >= 80" | bc -l) )); then c_color="${red}"
        elif (( $(echo "$load_pct >= 60" | bc -l) )); then c_color="${yellow}";
        else c_color="${green}"; fi
      fi
      local r_color="${reset}"
      local raw_rf="${rf%G}" raw_rt="${rt%G}"
      if [[ -n "$raw_rf" && -n "$raw_rt" && "$raw_rt" != "0.0" ]]; then
        local ram_used ram_pct
        ram_used=$(echo "$raw_rt - $raw_rf" | bc 2>/dev/null)
        ram_pct=$(echo "scale=4; ($ram_used / $raw_rt) * 100" | bc 2>/dev/null)
        if (( $(echo "$ram_pct >= 80" | bc -l) )); then r_color="${red}"
        elif (( $(echo "$ram_pct >= 60" | bc -l) )); then r_color="${yellow}";
        else r_color="${green}"; fi
      fi
      local d_color="${reset}"
      local raw_df="${df%G}" raw_dt="${dt%G}"
      if [[ -n "$raw_df" && -n "$raw_dt" && "$raw_dt" != "0.0" ]]; then
        local disk_used disk_pct
        disk_used=$(echo "$raw_dt - $raw_df" | bc 2>/dev/null)
        disk_pct=$(echo "scale=4; ($disk_used / $raw_dt) * 100" | bc 2>/dev/null)
        if (( $(echo "$disk_pct >= 80" | bc -l) )); then d_color="${red}"
        elif (( $(echo "$disk_pct >= 60" | bc -l) )); then d_color="${yellow}";
        else d_color="${green}"; fi
      fi
      echo -e "$(tput setaf 227)$h${reset}\t  $d\t  $v\t  $k\t  $c\t  ${c_color}$l${reset}\t    ${r_color}${rf}/${rt}${reset}\t      ${d_color}${df}/${dt}${reset}\t        $(tput setaf 222)$m${reset}"
    fi
  done
  echo -e "${yellow}--------\t---------\t-------\t------\t----\t-------\t---------------\t----------------\t---------${reset}"
) | column -t -s $'\t'
echo -e "${blue}===================================================================================================================================================${reset}\n"
}
fleet_bench() {
  fleet_init
  version="${1:-7}"
  local_host=$(hostname -s)
  local excluded=${2:-}
  build_vars
  if [[ -f "$fleet_root/controller.env" ]]; then
    . "$fleet_root/controller.env"
    if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
      error "'fleet bench' can only be executed from the central Fleet Controller $CONTROLLER_IP."
      return 1
    fi
  fi
  local -a excluded_vms=()
  if [[ -n "$excluded" ]]; then
    # Split by comma and trim whitespace around each excluded host name
    IFS=',' read -r -a raw_excluded <<< "$excluded"
    for item in "${raw_excluded[@]}"; do
      excluded_vms+=("$(echo "$item" | xargs)")
    done
  fi
  host_is_excluded() {
    local target_vm="$1"
    [[ -z "$target_vm" ]] && return 1
    for ex in "${excluded_vms[@]}"; do
      if [[ "$ex" == "$target_vm" ]]; then
        return 0
      fi
    done
    return 1
  }
  info "Checking fleet for active benchmark jobs."
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  [[ ! -f "$private_key" ]] && private_key="/home/oneclick/.ssh/id_ed25519"
  local tmp_check_dir="/tmp/fleet_bench_check_${local_host}"
  rm -rf "$tmp_check_dir" &> /dev/null
  mkdir -p "$tmp_check_dir"
  shopt -s nullglob
  local target_configs=("${fleet_root}/state"/*.conf)
  shopt -u nullglob
  for file in "${target_configs[@]}"; do
    [[ ! -f "$file" ]] && continue
    (
      eval "$(sed 's/=[[:space:]]*/=/g' "$file")"
      local host="$HOSTNAME"
      local peer_ip="$IP"
      local filename="${file##*/}"
      local vm_name="${filename%.conf}"
      if [[ -z "$peer_ip" || "$peer_ip" == "null" ]]; then
        return 0
      fi
      if ssh -n \
        -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
        -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes -o ConnectTimeout=1 \
        -o ConnectionAttempts=1 -o UserKnownHostsFile=/dev/null "oneclick@${peer_ip}" \
        "if ! command -v one-click &> /dev/null; then
           curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh && \\
             bash /tmp/one-click.sh setup && \\
             rm -f /tmp/one-click.sh &> /dev/null
         fi
         if [[ -f /etc/one-click/ocb/benchmarks/job.state && \$(cat /etc/one-click/ocb/benchmarks/job.state) == "RUNNING" ]]; then
           file_age=\$((\$(date +%s) - \$(stat -c %Y /etc/one-click/ocb/benchmarks/job.state)))
           if [[ \$file_age -lt 3600 ]]; then
             exit 0
           else
             sudo rm -f /etc/one-click/ocb/benchmarks/job.state
             exit 1
           fi
         else
           export DEBIAN_FRONTEND=noninteractive
           export NEEDRESTART_MODE=a
           if command -v apt-get &> /dev/null; then
             apt_lock=\"/var/lib/dpkg/lock-frontend\"
             if [ -f \"\$apt_lock\" ]; then
               pid=\$(sudo fuser \"\$apt_lock\" 2>/dev/null | awk '{print \$1}')
               [ -z \"\$pid\" ] && pid=\$(lsof -t \"\$apt_lock\" 2>/dev/null)
               if [ ! -z \"\$pid\" ]; then
                 sudo kill -9 \"\$pid\" 2>/dev/null
                 sleep 1
               fi
               sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock
             fi
             debconf_lock=\"/var/cache/debconf/config.dat-lock\"
             if [ -f \"\$debconf_lock\" ] || sudo fuser \"/var/cache/debconf/config.dat\" &> /dev/null; then
               d_pid=\$(sudo fuser \"/var/cache/debconf/config.dat\" 2>/dev/null | awk '{print \$1}')
               if [ ! -z \"\$d_pid\" ]; then
                 sudo kill -9 \"\$d_pid\" 2>/dev/null
                 sleep 1
               fi
               sudo rm -f /var/cache/debconf/config.dat-lock
               sudo rm -f /var/cache/debconf/passwords.dat-lock
             fi
             sudo dpkg --configure -a --force-confdef --force-confold &> /dev/null
             sudo apt-get update -y &> /dev/null
             sudo apt-get install -f -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" &> /dev/null
             sudo apt-get install -f -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" iperf3 fio &> /dev/null
           fi
           if command -v dnf &> /dev/null || command -v yum &> /dev/null; then
             dnf_lock=\"/var/run/dnf.pid\"
             [ ! -f \"\$dnf_lock\" ] && dnf_lock=\"/var/run/yum.pid\"
             if [ -f \"\$dnf_lock\" ]; then
               pid=\$(cat \"\$dnf_lock\" 2>/dev/null)
               if [ ! -z \"\$pid\" ] && kill -0 \"\$pid\" &> /dev/null; then
                 sudo kill -9 \"\$pid\" 2>/dev/null
                 sleep 1
               fi
               sudo rm -f /var/run/dnf.pid /var/run/yum.pid /var/lib/dnf/lock /var/lib/rpm/.rpm.lock
             fi
             pkg_mgr=\$(command -v dnf || command -v yum)
             sudo \$pkg_mgr clean all &> /dev/null
             if command -v dnf &> /dev/null; then
               sudo dnf history redo last -y &> /dev/null || true
             fi
             sudo \$pkg_mgr makecache &> /dev/null
             sudo \$pkg_mgr check-update -y &> /dev/null || [ \$? -eq 100 ]
             sudo \$pkg_mgr install -y --setopt=install_weak_deps=False iperf3 fio &> /dev/null
           fi
           exit 1
         fi" 2>/dev/null; then
         echo "$host" > "${tmp_check_dir}/${host}.active"
      fi
    ) &
  done
  wait
  local active_hosts=""
  if [ -d "$tmp_check_dir" ]; then
    shopt -s nullglob
    local active_files=("${tmp_check_dir}"/*.active)
    shopt -u nullglob
    if [[ ${#active_files[@]} -gt 0 ]]; then
      active_hosts=$(cat "${active_files[@]}" | xargs)
    fi
    rm -rf "$tmp_check_dir"
  fi
  info "Preparing local environment. Flushing stale metrics sheets."
  mkdir -p "$fleet_root/benchmarks/archive"
  local archive_ts=$(date +%Y%m%d-%H%M%S)
  if [[ -f "$fleet_root/benchmarks/localhost.json" ]]; then
    mv "$fleet_root/benchmarks/localhost.json" "$fleet_root/benchmarks/archive/localhost-${archive_ts}.json"
  fi
  set +e
  for host_conf in "${target_configs[@]}"; do
    [[ ! -f "$host_conf" ]] && continue
    (
      local filename="${host_conf##*/}"
      local vm_name="${filename%.conf}"
      if host_is_excluded "$vm_name"; then
        return 0
      fi
      eval "$(sed 's/=[[:space:]]*/=/g' "$host_conf")"
      if [[ -f "$fleet_root/benchmarks/${HOSTNAME}.json" ]]; then
        mv "$fleet_root/benchmarks/${HOSTNAME}.json" "$fleet_root/benchmarks/archive/${HOSTNAME}-${archive_ts}.json"
      fi
    )
  done
  info "Preparing fleet environment. Flushing stale metrics sheets."
  ansible-inventory -i /etc/one-click/fleet/inventory.yml --list | \
  jq -r '._meta.hostvars | to_entries[] | "\(.key) \(.value.ansible_host)"' | \
  while read -r name ip; do
    # FIX: Use continue instead of return 0 to avoid breaking out of the while loop entirely
    if host_is_excluded "$name"; then
      warn "$name has been excluded from this run"
      continue
    fi
    [[ "$ip" == "$CONTROLLER_IP" ]] && continue
    if [[ " $active_hosts " == *" $name "* ]]; then
      echo -e "${red}[$(tput setaf 216)[$name]${red}]:${reset} Benchmark already running on ${red}${name}${reset}. Skipping."
      continue
    fi
    if ! ping -c1 $ip &> /dev/null; then
      echo "${red}[$name]:${reset} $name is unresponsive. Skipping."
      continue
    fi
    echo "$(tput setaf 216)[$name]:$(tput sgr 0) Preparing remote files"
    scp -r \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o StrictHostKeyChecking=no \
      -o BatchMode=yes \
      -o ConnectTimeout=1 \
      -o ConnectionAttempts=1 \
      -o UserKnownHostsFile=/dev/null \
      /var/cache/one-click/* \
      "oneclick@${ip}:/home/oneclick/" &> /dev/null || true
    scp \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o StrictHostKeyChecking=no \
      -o BatchMode=yes \
      -o ConnectTimeout=1 \
      -o ConnectionAttempts=1 \
      -o UserKnownHostsFile=/dev/null \
      /usr/local/bin/one-click \
      "oneclick@${ip}:/home/oneclick/one-click" &> /dev/null || true
    echo "$(tput setaf 216)[$name]:$(tput sgr 0) Spawning background benchmark on $name"
    ssh -f \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "oneclick@$ip" "
        echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf > /dev/null
        echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf > /dev/null
        if [ ! -f /usr/local/bin/one-click ]; then
          sudo mkdir -p /var/log/one-click/
          sudo bash /home/oneclick/one-click setup
        fi
        if ! command -v iperf3 &> /dev/null; then
          if command -v apt &> /dev/null; then
            sudo apt -y update
            echo 'iperf3 iperf3/start_daemon boolean false' | sudo debconf-set-selections
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -y iperf3
          else
            sudo dnf -y install iperf3
          fi
        fi
        if ! command -v fio &> /dev/null; then
          if ! command -v apt &> /dev/null; then
            sudo apt -y update
            echo 'fio fio/start_daemon boolean false' | sudo debconf-set-selections
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -y fio
            DEBIAN_FRONTEND=noninteractive sudo apt-get install -y sysbench
          else
            sudo dnf -y install fio
            sudo dnf -y install sysbench
          fi
        fi
        sudo mkdir -p /var/cache/one-click
        sudo mv -f /home/oneclick/*.sh /var/cache/one-click/
        bench_dir='/etc/one-click/ocb/benchmarks'
        sudo mkdir -p \"\$bench_dir/archive\"
        ts=\$(date +%Y%m%d-%H%M%S)
        if [ -f \"\$bench_dir/latest.json\" ]; then
          sudo mv \"\$bench_dir/latest.json\" \"\$bench_dir/archive/latest-\${ts}.json\"
        fi
        sudo rm -f \"\$bench_dir/COMPLETE\" \"\$bench_dir/job.state\" \"/etc/one-click/ocb/benchmarks/latest.json\"
        echo 'RUNNING' | sudo tee /etc/one-click/ocb/benchmarks/job.state
        sudo nohup /bin/bash -lc \"TERM=xterm-256color /usr/local/bin/one-click fl ${version:-}\"  > /dev/null 2>&1 &
        sudo cp \"/etc/one-click/ocb/benchmarks/latest.json\" \"/etc/one-click/fleet/benchmarks/localhost.json\" &> /dev/null & || true
        rm -f /home/oneclick/one-click /home/oneclick/*.sh
    " < /dev/null &> /dev/null || true
    success "$name ($ip) is now running One-Click Bench!"
  done
  set -e
  if host_is_excluded "$(hostname -s)"; then
    warn "Controller has been excluded from benchmark"
    success "${green}All benchmark jobs dispatched successfully!${reset}"
    info "Run ${orange}'one-click fleet status'${reset} to check on progress or find logs in '$fleet_root/benchmarks/'"
    return
  fi
  fleet_local_bench "${version:-}"
}
fleet_local_bench() {
  version="${1:-7}"
  if [[ -f /etc/one-click/ocb/benchmarks/job.state ]]; then
    if [[ $(cat /etc/one-click/ocb/benchmarks/job.state) == "RUNNING" ]]; then
	  echo "${red}[$(tput setaf 216)[$(hostname -s)]${red}]${reset}: A benchmark is already running on the Controller"
      return 1
    fi
  fi
  echo "$(tput setaf 216)[$(hostname -s)]:$(tput sgr 0) Spawning background benchmark on Controller"
  mkdir -p /var/log/one-click/
  rm -f /etc/one-click/ocb/benchmarks/COMPLETE \
    /etc/one-click/ocb/benchmarks/job.state \
    /etc/one-click/ocb/benchmarks/latest.json
  if ! command -v iperf3 &> /dev/null; then
	if command -v apt &> /dev/null; then
	  apt -y update
      echo 'iperf3 iperf3/start_daemon boolean false' | debconf-set-selections
      DEBIAN_FRONTEND=noninteractive apt-get install -y iperf3
    else
	  dnf -y install iperf3
    fi
  fi
  if ! command -v fio &> /dev/null; then
	if command -v apt &> /dev/null; then
	  (sudo apt -y update
      echo 'iperf3 iperf3/start_daemon boolean false' | sudo debconf-set-selections
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y fio) &> /dev/null
	else
	  (dnf -y install iperf3
      dnf -y install fio) &> /dev/null
	fi
  fi
  mkdir -p /etc/one-click/ocb/benchmarks/
  nohup /bin/bash -lc "TERM=xterm-256color /usr/local/bin/one-click fl ${version:-}" < /dev/null &> /dev/null &
  if pgrep -af '/usr/local/bin/one-click fl' &> /dev/null; then
    echo "RUNNING" > /etc/one-click/ocb/benchmarks/job.state
    success "Controller (${sys_ip:-${sys_ipv6:-}}) is now running One-Click Bench!"
    cp "/etc/one-click/ocb/benchmarks/latest.json" "/etc/one-click/fleet/benchmarks/localhost.json" &> /dev/null || true
    success "${green}All benchmark jobs dispatched successfully!${reset}"
    info "Run ${orange}'one-click fleet status'${reset} to check on progress or find logs in '$fleet_root/benchmarks/'"
	return 0
  else
    error "Failed to run local benchmark"
	rm -f /etc/one-click/ocb/benchmarks/job.state
	return 1
  fi
}
fleet_status() {
  fleet_init
  local local_host=$(hostname -s)
  build_vars
  local bench_dir="$fleet_root/benchmarks"
  mkdir -p "$bench_dir"
  local CONTROLLER_IP=""
  if [[ -f "$fleet_root/controller.env" ]]; then
    . "$fleet_root/controller.env"
  fi
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    local remote_bench_files
    remote_bench_files=$(ssh \
      -n \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o ConnectTimeout=1 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      oneclick@"$CONTROLLER_IP" \
      "sudo find $bench_dir/ -maxdepth 1 -name '*.json' -printf '%f\n'" 2>/dev/null)
    if [[ -n "$remote_bench_files" ]]; then
      for f in $remote_bench_files; do
        [[ "$f" == "${local_host}.json" ]] && continue
        ssh \
          -n \
          -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
          -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
          -o ConnectTimeout=1 \
          -o BatchMode=yes \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          oneclick@"$CONTROLLER_IP" \
          "sudo cat $bench_dir/$f" > "$bench_dir/$f" 2>/dev/null
      done
    fi
  else
    set +e
    ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible-playbook \
      -i "$fleet_root/inventory.yml" \
      -u oneclick \
      -e "local_fleet_root=$fleet_root" \
      "$fleet_root/playbooks/fetch_results.yml" &> /dev/null
	set -e
  fi
  local local_status="IDLE"
  local is_local_active=false
  if grep -q "$local_host" "$fleet_root/inventory.yml" 2>/dev/null || [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
    is_local_active=true
    if [[ -f /etc/one-click/ocb/benchmarks/job.state ]]; then
      local_status=$(cat /etc/one-click/ocb/benchmarks/job.state 2>/dev/null)
    elif [[ -f /etc/one-click/ocb/benchmarks/COMPLETE ]]; then
      local_status="COMPLETE"
    else
      local_status=IDLE
    fi
  fi
  shopt -s nullglob
  local target_configs=("$fleet_root"/state/*.conf)
  shopt -u nullglob
  echo
  echo -e "${magenta}================================================ ${orange}FLEET BENCHMARK STATUS REPORT${magenta} ==========================================================${reset}"
  echo
  (
    echo -e "FLEET\tHOSTNAME\tSTATUS\tSINGLE_CORE\tMULTI_CORE\tTOTAL_TIME\tTIMESTAMP\tONE-CLICK URL\tGEEKBENCH URL"
    if [ "$is_local_active" = true ]; then
      local grid_l_color="${orange}"
      if [[ "$local_status" == "COMPLETE" ]]; then
	    grid_l_color="${green}"
      elif [[ "$local_status" == "RUNNING" ]]; then
	    grid_l_color="$(tput setaf 119)"
      elif [[ "$local_status" == "FAILED" ]]; then
	    grid_l_color="${red}"
	  fi
      if [[ -f "$bench_dir/${local_host}.json" ]]; then
        jq -r --arg f_name "${local_host}" \
          --arg green "${green}" \
          --arg red "${red}" \
          --arg orange "$(tput setaf 227)" \
          --arg yellow "${yellow}" \
          --arg reset "${reset}" '[
          $yellow + "Controller" + $reset,
          $orange + "  " + $f_name + $reset,
          (if .status == "COMPLETE" then $green + "    " + .status + $reset elif .status == "FAILED" then $red + "    " + .status + $reset else $orange + "    " + .status + $reset end),
          "      " + (."Single Core Score" // "-"),
          "      " + (."Multi Core Score" // "-"),
          (if ."Total Time Taken" then "      " + ((."Total Time Taken" | tonumber) as $s | "\(($s / 60 | floor)):\(($s % 60 | tostring | if length == 1 then "0"+. else . end))") else "-" end),
          "      " + (.timestamp // "-"),
          "      " + (."One-Click Results" // "-"),
          "      " + (."GeekBench Results" // "-")
        ] | @tsv' "$bench_dir/${local_host}.json" 2>/dev/null || echo -e "${yellow}Controller\t$(tput setaf 227)${local_host}\t${grid_l_color}${local_status}${reset}\t  -\t  -\t  -\t  -\t  -\t  -"
      else
        echo -e "${yellow}Controller\t$(tput setaf 227)${local_host}\t${grid_l_color}${local_status}${reset}\t  -\t  -\t  -\t  -\t  -\t  -"
      fi
    fi
    for host_conf in "${target_configs[@]}"; do
      [[ ! -f "$host_conf" ]] && continue
      local current_target=$(basename "$host_conf" .conf)
      [[ "$local_host" == "$current_target" ]] && continue
      (
        eval "$(sed 's/=[[:space:]]*/=/g' "$host_conf")"
        local lookup_target="$HOSTNAME"
        local target_ip="$IP"
        if ! grep -q "$lookup_target" "$fleet_root/inventory.yml" 2>/dev/null; then
          exit 0
		fi
		fleet_c="$lookup_target"
        local local_json="$bench_dir/${lookup_target}.json"
        local live_p_check
		set +e
        live_p_check=$(ssh -n -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
		  -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=2 "oneclick@${target_ip}" "
          if [ -f /etc/one-click/ocb/benchmarks/job.state ]; then
		    cat /etc/one-click/ocb/benchmarks/job.state
		  elif [ -f /etc/one-click/ocb/benchmarks/COMPLETE ]; then
		    echo 'COMPLETE'
		  else
		    echo 'IDLE'
		  fi
		" 2>/dev/null)
		set -e
        live_p_check=${live_p_check:-OFFLINE}
        local c_lbl="${orange}"
        if echo "$live_p_check" | grep -q 'RUNNING'; then
		  c_lbl="$(tput setaf 119)"
        elif echo "$live_p_check" | grep -q 'COMPLETE'; then
		  c_lbl="${green}"
        elif echo "$live_p_check" | grep -q 'IDLE'; then
		  c_lbl="${orange}"
        else
		  c_lbl="${red}"
		fi
        local parsed_status="IDLE"
        if echo "$live_p_check" | grep -q 'RUNNING'; then
		  parsed_status="RUNNING"
		fi
        if [[ -f "$local_json" && -s "$local_json" && "$parsed_status" != "RUNNING" ]]; then
          jq -r --arg f_name "$lookup_target" --arg f_c "$fleet_c" --arg green "${green}" --arg red "${red}" --arg orange "$(tput setaf 227)" --arg yellow "${yellow}" --arg reset "${reset}" '[
            $yellow + $f_c + $reset,
            $orange + "  " + $f_name,
            (if .status == "COMPLETE" then $green + "  " + .status + $reset elif .status == "FAILED" then $red + "  " + .status + $reset else $orange + "  " + .status + $reset end),
            "    " + (."Single Core Score" // "-"),
            "    " + (."Multi Core Score" // "-"),
            (if ."Total Time Taken" then "    " + ((."Total Time Taken" | tonumber) as $s | "\(($s / 60 | floor)):\(($s % 60 | tostring | if length == 1 then "0"+. else . end))") else "-" end),
            "    " + (.timestamp // "-"),
            "    " + (."One-Click Results" // "-"),
            "    " + (."GeekBench Results" // "-")
          ] | @tsv' "$local_json" 2>/dev/null || echo -e "${yellow}${fleet_c}\t$(tput setaf 227)${lookup_target}\t${c_lbl}${live_p_check}${reset}\t  -\t  -\t  -\t  -\t  -\t  -"
        else
          echo -e "${yellow}${fleet_c}\t$(tput setaf 227)${lookup_target}\t${c_lbl}${live_p_check}${reset}\t  -\t  -\t  -\t  -\t  -\t  -"
        fi
      )
    done
  ) | sed -e "1s/\(.*\)/${magenta}\1${reset}/" \
          -e "1i\\\\${yellow}-----\t--------\t------\t-----------\t----------\t----------\t---------\t-------------\t-------------${reset}" \
          -e "2i\\\\${yellow}-----\t--------\t------\t-----------\t----------\t----------\t---------\t-------------\t-------------${reset}" \
          -e "s/\t/\t/g" \
          -e "\$ a\\\\${yellow}-----\t--------\t------\t-----------\t----------\t----------\t---------\t-------------\t-------------${reset}" | column -t -s $'\t'
  return
}
fleet_put() {
  local host="$1"
  local src="$2"
  local dest="$3"
  [[ -z "$host" || -z "$src" || -z "$dest" ]] && {
    error "Usage: fleet put <hostname> <local_src> <remote_dest>"
    return 1
  }
  fleet_init
  info "Transferring '$src' to '$host:$dest'."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$host" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
	--become \
    -m copy \
    -a "src=$src dest=$dest mode=preserve"  | sed -En "
      /\| changed/I {
        s,([^{]*).*,${orange}\1${reset},;
        s,$,${green}SUCCESS ${orange}=>${green} $src exported to $dest on ${host}${reset},;
        s/^/${magenta}[EXEC]${reset} /gp
      };
      /\| success/I {
        s,([^{]*).*,${green}\1${reset},;
        s,$,${orange}EXISTS ${green}=>${orange} $dest already exists and is unchanged.${reset},;
        s/^/${magenta}[EXEC]${reset} /gp
      }
    "
}
fleet_get() {
  local host="$1"
  local src="$2"
  local dest="$3"
  [[ -z "$host" || -z "$src" || -z "$dest" ]] && {
    error "Usage: fleet get <hostname> <remote_src> <local_dest>"
    return 1
  }
  fleet_init
  info "Fetching '$host:$src' to '$dest'."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$host" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
	--become \
    -m fetch \
    -a "src=$src dest=$dest flat=yes" 2> /dev/null | sed -En "
      /\| changed/I {
        s/^/${magenta}[EXEC]${reset} /;
        s,([^{]*).*,${orange}\1${reset},;
        s,$,${green}SUCCESS ${orange}=>${green} $src imported to $dest from ${host}${reset},;
        s/^/${magenta}[EXEC]${reset} /gp
      };
      /\| success/I {
        s,([^{]*).*,${green}\1${reset},;
        s,$,${orange}EXIST ${green}=>${orange} $dest already exist and is unchanged.${reset},;
        s/^/${magenta}[EXEC]${reset} /gp
      }
    "
}
fleet_dir() {
  local host="$1"
  local dir="$2"
  [[ -z "$host" || -z "$dir" ]] && {
    error "Usage: fleet list <hostname> <remote_directory>"
    return 1
  }
  fleet_init
  info "Listing '$host:$dir'."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$host" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
	--become \
    -m shell \
    -a "find '$dir' -maxdepth 1 -printf '%M %u %g %10s %TY-%Tm-%Td %TH:%TM %f\n' 2>/dev/null | sort" \
    2>/dev/null
}
fleet_raw() {
  local host="$1"
  shift
  local cmds="$*"
  [[ -z "$host" ]] && {
    error "Usage: fleet raw <hostname> [commands...]"
    return 1
  }
  fleet_init
  local target_ip=""
  if command -v ansible &>/dev/null && [[ -f "$fleet_root/inventory.yml" ]]; then
    target_ip=$(ansible "$host" -i "$fleet_root/inventory.yml" --list-hosts 2>/dev/null | grep -v "hosts (" | awk '{print $1}' | head -n 1)
  fi
  [[ -z "$target_ip" ]] && target_ip="$host"
  local ssh_key_opts=()
  if [[ -f "/home/oneclick/.ssh/id_ed25519" ]]; then
    ssh_key_opts+=("-i" "/home/oneclick/.ssh/id_ed25519")
  fi
  if [[ -f "/etc/one-click/fleet/keys/id_ed25519" ]]; then
    ssh_key_opts+=("-i" "/etc/one-click/fleet/keys/id_ed25519")
  fi
  if [[ -z "$cmds" ]]; then
    info "Opening interactive session for '$host' ($target_ip)."
    ssh -t \
        "${ssh_key_opts[@]}" \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "oneclick@${target_ip}" \
        "
          echo \"\$(tput setaf 211)You are now in a remote session on $host\"
          sleep 2
          sudo -i
        "
  else
    info "Executing raw command on '$host' ($target_ip) and retaining interactive control..."
    ssh -t \
        "${ssh_key_opts[@]}" \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "oneclick@${target_ip}" \
        "
          echo \"\$(tput setaf 211)You are now in a remote session on $host\"
          sleep 2
          sudo /bin/bash -lc '$cmds'
          exec sudo -i
        "
  fi
}
site_export() {
  local domain="$1"
  [[ -z "$domain" ]] && { error "Usage: site-export <domain>"; return 1; }
  local meta_file=""
  for path in "/etc/one-click/sites/$domain/meta.conf" \
    "/etc/one-click/wordpress/$domain/meta.conf" \
    "/etc/one-click/nextcloud/$domain/meta.conf" \
    "/etc/one-click/apps/nodejs/$domain/meta.conf"; do
      [[ -f "$path" ]] && meta_file="$path" && break
  done
  if [[ -z "$meta_file" ]]; then
    meta_file=$(find /etc/one-click -path "*/$domain/meta.conf" -print -quit 2>/dev/null)
  fi
  [[ -z "$meta_file" || ! -f "$meta_file" ]] && {
    error "'meta.conf' for $domain not found."
    return 1
  }
  local host_line
  parse_key() { awk -F '=' -v k="$1" '$1==k {print $2}' "$meta_file" | tr -d '"' | tr -d "'" | tail -n1; }
  local site_dir=$(parse_key "SITE_DIR")
  local site_user=$(parse_key "SITE_USER")
  local site_group=$(parse_key "SITE_GROUP")
  local webserver=$(parse_key "WEBSERVER")
  local webserver_service=$(parse_key "WEBSERVER_SERVICE")
  local vhost=$(parse_key "VHOST")
  local vhost_link=$(parse_key "VHOST_LINK")
  [[ -z "$site_dir" || ! -d "$site_dir" ]] && { error "Resolved SITE_DIR '$site_dir' does not exist."; return 1; }
  local bundle_root="/tmp/fleet-site-$domain"
  rm -rf "$bundle_root" && mkdir -p "$bundle_root"
  info "Packing site source directory files."
  cp -a "$site_dir" "$bundle_root/site_data"
  [[ -f "$vhost" ]] && cp "$vhost" "$bundle_root/vhost.conf"
  if [[ -n "$vhost" ]]; then
    local vhost_dir=$(dirname "$vhost")
    local ssl_vhost="${vhost_dir}/${domain}-le-ssl.conf"
    [[ -f "$ssl_vhost" ]] && cp "$ssl_vhost" "$bundle_root/vhost-ssl.conf"
  fi
  if [[ -d "/var/log/one-click/$domain" ]]; then
    cp -a "/var/log/one-click/$domain" "$bundle_root/site_logs"
  fi
  local php_enabled=$(parse_key "PHP_SYSTEMD_ENABLED")
  local php_pool=$(parse_key "PHP_POOL_CONF")
  local php_fpm=$(parse_key "PHP_FPM_CONF")
  local php_ini=$(parse_key "PHP_INI_FILE")
  local php_vhost=$(parse_key "PHP_SYSTEMD_VHOST")
  local php_service=$(parse_key "PHP_SYSTEMD_SERVICE_NAME")
  if [[ "$php_enabled" == "true" || -n "$php_pool" || -n "$php_fpm" ]]; then
    php_enabled="true"
    [[ -f "$php_pool" ]] && cp "$php_pool" "$bundle_root/php-pool.conf"
    [[ -f "$php_fpm" ]]  && cp "$php_fpm"  "$bundle_root/php-fpm.conf"
    [[ -f "$php_ini" ]]  && cp "$php_ini"  "$bundle_root/php.ini"
    [[ -f "$php_vhost" ]] && cp "$php_vhost" "$bundle_root/php-systemd.service"
  else
    php_enabled="false"
  fi
  local redis_enabled=$(parse_key "REDIS_ENABLED")
  local redis_conf=$(parse_key "REDIS_CONF")
  local redis_srv_conf=$(parse_key "REDIS_SERVICE_CONF")
  local redis_service=$(parse_key "REDIS_SERVICE")
  if [[ "$redis_enabled" == "true" ]]; then
    [[ -f "$redis_conf" ]] && cp "$redis_conf" "$bundle_root/redis.conf"
    [[ -f "$redis_srv_conf" ]] && cp "$redis_srv_conf" "$bundle_root/redis-service.conf"
  else
    redis_enabled="false"
  fi
  local systemd_enabled=$(parse_key "SYSTEMD_ENABLED")
  local systemd_vhost=$(parse_key "SYSTEMD_VHOST")
  local systemd_name=$(parse_key "SYSTEMD_SERVICE_NAME")
  if [[ "$systemd_enabled" == "true" ]]; then
    [[ -f "$systemd_vhost" ]] && cp "$systemd_vhost" "$bundle_root/systemd.service"
  else
    systemd_enabled="false"
  fi
  extract_databases "$meta_file" "$bundle_root"
  local rel_meta_path
  rel_meta_path=$(sed 's|^/etc/one-click/||' <<< "$meta_file")
  cat <<EOF > "$bundle_root/manifest.json"
{
  "domain": "$domain",
  "meta_rel_path": "$rel_meta_path",
  "site_user": "$site_user",
  "site_group": "$site_group",
  "site_dir": "$site_dir",
  "webserver_service": "${webserver_service:-$webserver}",
  "vhost": "$vhost",
  "vhost_link": "$vhost_link",
  "hosts_entry": "${hosts_line:-null}",
  "php": {
    "enabled": $php_enabled,
    "service": "$php_service",
    "pool": "$php_pool",
    "fpm": "$php_fpm",
    "ini": "$php_ini",
    "vhost": "$php_vhost"
  },
  "redis": {
    "enabled": $redis_enabled,
    "service": "$redis_service",
    "conf": "$redis_conf",
    "service_conf": "$redis_srv_conf"
  },
  "systemd_service": {
    "enabled": $systemd_enabled,
    "name": "$systemd_name",
    "vhost": "$systemd_vhost"
  }
}
EOF
  cp "$meta_file" "$bundle_root/meta.conf"
  local registry_json="/etc/one-click/db-manager/sites/${domain}.json"
  [[ -f "$registry_json" ]] && cp "$registry_json" "$bundle_root/registry.json"
  local archive="/tmp/${domain}.tar.gz"
  tar -czf "$archive" -C "$bundle_root" .
  rm -rf "$bundle_root"
  echo "$archive"
}
clone_site() {
  set -o pipefail
  local domain="$1"
  local host="$2"
  [[ -z "$domain" || -z "$host" ]] && {
    error "Usage: fleet clone-site <domain> <hostname>"
    return 1
  }
  local archive
  archive=$(site_export "$domain")
  [[ $? -ne 0 || -z "$archive" ]] && {
    error "Export failed. Cancelling migration pipeline."
    return 1
  }
  local remote_archive="/tmp/$(basename "$archive")"
  info "Uploading packaged configurations and services to $host."
  fleet_put "$host" "$archive" "$remote_archive"
  local registry_json="/etc/one-click/db-manager/sites/${domain}.json"
  local fallback_meta="/etc/one-click/sites/${domain}/meta.conf"
  local target_site_root="" vhost_path="" vhost_link="" webserver_service=""
  local db_enabled="false" db_name="null" db_user="null" site_user="www-data" site_group="www-data"
  if [[ -f "$registry_json" ]]; then
    target_site_root=$(jq -r '.site.root' "$registry_json")
    site_user=$(jq -r '.site.user // "www-data"' "$registry_json")
    site_group=$(jq -r '.site.group // "www-data"' "$registry_json")
    db_enabled=$(jq -r '.database.enabled // false' "$registry_json")
    if [[ $(jq -r '.nginx.enabled // false' "$registry_json") == "true" ]]; then
      vhost_path=$(jq -r '.nginx.vhost // empty' "$registry_json")
      vhost_link=$(jq -r '.nginx.vhost_link // empty' "$registry_json")
      webserver_service=$(jq -r '.nginx.service_name // "nginx"' "$registry_json")
    elif [[ $(jq -r '.apache.enabled // false' "$registry_json") == "true" ]]; then
      vhost_path=$(jq -r '.apache.vhost // empty' "$registry_json")
      vhost_link=$(jq -r '.apache.vhost_link // empty' "$registry_json")
      webserver_service=$(jq -r '.apache.service_name // "apache2"' "$registry_json")
    fi
    if [[ "$db_enabled" == "true" ]]; then
      db_name=$(jq -r '.database.primary.name // empty' "$registry_json")
      db_user=$(jq -r '.database.primary.user // empty' "$registry_json")
      [[ -z "$db_name" || "$db_name" == "null" ]] && db_name=$(jq -r '.database.databases[0].name // empty' "$registry_json")
    fi
  elif [[ -f "$fallback_meta" ]]; then
    source "$fallback_meta"
    target_site_root="$SITE_DIR"
    vhost_path="$VHOST"
    vhost_link="$VHOST_LINK"
    webserver_service="${SERVICE_NAME:-$WEBSERVER}"
    site_user="$SITE_USER"
    site_group="$SITE_GROUP"
    if [[ -n "$DB_USER" ]]; then
      db_enabled="true"
      db_user="$DB_USER"
      db_name="${DB_NAME:-$DB_USER}"
    fi
  fi

  local cyan green orange red magenta yellow reset
  cyan=$(tput setaf 45)
  green=$(tput setaf 2)
  orange=$(tput setaf 208)
  red=$(tput setaf 1)
  magenta=$(tput setaf 5)
  yellow=$(tput setaf 3)
  reset=$(tput sgr0)

  info "Beginning remote deployment tasks on $host."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible-playbook "$fleet_root/playbooks/site_import.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    -b \
    --extra-vars "target_host=$host domain=$domain remote_archive_path=$remote_archive target_site_root=$target_site_root target_vhost_path=$vhost_path target_vhost_link=$vhost_link webserver_service_name=$webserver_service db_enabled=$db_enabled db_name=$db_name db_user=$db_user site_user=$site_user site_group=$site_group" | sed -E "
      /^($|TASK|PLAY)/ {
        s/[^[]*\[([^]]*).*/\1/;
        h;
        d
      };
      /^ok/ {
        G;
        s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/
        s/ok=[1-9]+/${green}&${reset}/g
      };
      /^changed/ {
        G;
        s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/
        s/changed=[1-9]+/${orange}&${reset}/g
      };
      /^skipping/ {
        G;
        s/^(skipping.*)\n(.*)/${cyan}\1 ->${magenta} \2${reset}/
        s/skipped=[1-9]+/${cyan}&${reset}/g
      };
      /^failed/ {
        G;
        s/^(failed.*)\n(.*)/${red}\1 ->${magenta} \2${reset}/
        s/failed=[1-9]+/${red}&${reset}/g
      };
      s/${domain}/${yellow}&/
    "
  if [[ $? -eq 0 ]]; then
    rm -f "$archive"
    success "$domain has successfully completed cloning on $host."
  else
    error "Cloning Failed."
    return 1
  fi
}
site_import() {
  set -o pipefail
  local target_domain="$1"
  local source_peer="$2"
  [[ -z "$target_domain" ]] && {
    error "Usage: fleet site-import <domain> [source_peer_or_local_file_path]"
    return 1
  }

  local cyan green orange red magenta yellow reset
  cyan=$(tput setaf 45)
  green=$(tput setaf 2)
  orange=$(tput setaf 208)
  red=$(tput setaf 1)
  magenta=$(tput setaf 5)
  yellow=$(tput setaf 3)
  reset=$(tput sgr0)

  if [[ -f "$target_domain" ]]; then
    local absolute_archive=$(realpath "$target_domain")
    local domain=$(basename "$absolute_archive" .tar.gz)
    info "Initiating standalone local archive restore pipeline for $domain."
    ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible-playbook "$fleet_root/playbooks/site_import.yml" \
      -i "localhost," \
      -c local \
      -b \
      --extra-vars "target_host=localhost domain=$domain remote_archive_path=$absolute_archive db_enabled=true" | sed -E "
      /^($|TASK|PLAY)/ {
        s/[^[]*\[([^]]*).*/\1/;
        h;
        d
      };
      /^ok/ {
        G;
        s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/
        s/ok=[1-9]+/${green}&${reset}/g
      };
      /^changed/ {
        G;
        s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/
        s/changed=[1-9]+/${orange}&${reset}/g
      };
      /^skipping/ {
        G;
        s/^(skipping.*)\n(.*)/${cyan}\1 ->${magenta} \2${reset}/
        s/skipped=[1-9]+/${cyan}&${reset}/g
      };
      /^failed/ {
        G;
        s/^(failed.*)\n(.*)/${red}\1 ->${magenta} \2${reset}/
        s/failed=[1-9]+/${red}&${reset}/g
      };
      s/${domain}/${yellow}&/
    "
    return $?
  fi
  [[ -z "$source_peer" ]] && {
    error "Error: You must provide either a valid local tarball file path or a remote peer name (e.g., work1)"
    return 1
  }
  info "Initiating cross-peer migration pull sequence. Fetching $target_domain from peer: $source_peer."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible-playbook "$fleet_root/playbooks/site_pull_import.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    --extra-vars "source_peer=$source_peer domain=$target_domain" | sed -E "
      /^($|TASK|PLAY)/ {
        s/[^[]*\[([^]]*).*/\1/;
        h;
        d
      };
      /^ok/ {
        G;
        s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/;
        s/ok=[1-9]+/${green}&${reset}/g
      };
      /^changed/ {
        G;
        s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/
        s/changed=[1-9]+/${orange}&${reset}/g
      };
      /^skipping/ {
        G;
        s/^(skipping.*)\n(.*)/${cyan}\1 ->${magenta} \2${reset}/
        s/skipped=[1-9]+/${cyan}&${reset}/g
      };
      /^failed/ {
        G;
        s/^(failed.*)\n(.*)/${red}\1 ->${magenta} \2${reset}/
        s/failed=[1-9]+/${red}&${reset}/g
      };
      s/${source_peer}|localhost/${yellow}&/
    "
  if [[ $? -eq 0 ]]; then
    success "Successfully pulled, imported, and deployed $target_domain from peer node ($source_peer)."
  else
    error "Cross-peer migration pull pipeline encountered an error."
    return 1
  fi
}
migrate_dir() {
  local src_dir="$1"
  local dest_peer="$2"
  local dest_dir="${3:-$src_dir}"
  [[ -z "$src_dir" || -z "$dest_peer" ]] && {
    error "Usage: fleet migrate-dir <src_directory> <peer_host> [dest_directory]"
    return 1
  }
  if [[ ! -d "$src_dir" ]]; then
    error "Local source directory does not exist or is unreadable: $src_dir"
    return 1
  fi
  local dir_name
  dir_name=$(basename "$src_dir")
  local archive="/tmp/fleet-raw-dir-${dir_name}-$(date +%s).tar.gz"
  local remote_archive="/tmp/$(basename "$archive")"
  info "Compressing raw directory: $src_dir."
  tar -czf "$archive" -C "$(dirname "$src_dir")" "$dir_name"
  info "Shipping archive to peer node: $dest_peer."
  fleet_put "$dest_peer" "$archive" "$remote_archive"
  info "Extracting payload onto $dest_peer into destination: $dest_dir."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$dest_peer" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    -b \
    -m shell \
    -a "
      mkdir -p '$(dirname "$dest_dir")' && \
      tar -xzf '$remote_archive' -C '$(dirname "$dest_dir")' && \
      if [ '$(basename "$src_dir")' != '$(basename "$dest_dir")' ]; then
        mv '$(dirname "$dest_dir")/$(basename "$src_dir")' '$dest_dir';
      fi && \
      rm -f '$remote_archive'
    " | sed -E "
      /^($|TASK|PLAY)/ {
	    s/[^[]*\[([^]]*).*/\1/;
		h;
		d
	  };
      /^ok/ {
		G;
		s/^(ok.*)\n(.*)/${green}\1 ->${magenta} \2${reset}/
		s/ok=[1-9]+/${green}&${reset}/g
	  };
      /^changed/ {
		G;
		s/^(changed.*)\n(.*)/${orange}\1 ->${magenta} \2${reset}/
		s/changed=[1-9]+/${orange}&${reset}/g
	  };
      /^skipping/ {
		G;
		s/^(skipping.*)\n(.*)/$(tput setaf 45)\1 ->${magenta} \2${reset}/
		s/skipped=[1-9]+/$(tput setaf 45)&${reset}/g
	  };
      /^failed/ {
		G;
	    s/^(failed.*)\n(.*)/${red}\1 ->${magenta} \2${reset}/
		s/failed=[1-9]+/${red}&${reset}/g
	  };
      s/${dest_peer}/${yellow}&/
    "
  rm -f "$archive"
  if [[ $? -eq 0 ]]; then
    success "Successfully migrated $src_dir to $dest_peer:$dest_dir"
  else
    error "An error occurred during remote extraction on the peer."
    return 1
  fi
}
extract_databases() {
  local meta_file="$1"
  local bundle_root="$2"
  local current_name="" current_user="" current_pass=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(echo "$line" | tr -d '"' | tr -d "'")
    case "$line" in
      DB_NAME=*) current_name="${line#*=}" ;;
      DB_USER=*) current_user="${line#*=}" ;;
      DB_PASS=*)
        current_pass="${line#*=}"
        if [[ -n "$current_name" ]]; then
          info "Dumping dynamic database sequence target: $current_name"
          mysqldump -u"$current_user" -p"$current_pass" --single-transaction "$current_name" > "$bundle_root/db_${current_name}.sql" 2>/dev/null
          echo "$current_name:$current_user" >> "$bundle_root/db_manifest.txt"
          current_name="" ; current_user="" ; current_pass=""
        fi
        ;;
    esac
  done < "$meta_file"
}
valid_ipv4() {
  local ip="$1"
  if getent ahostsv4 "$ip" | grep -qE '^[0-9.]+'; then
    return 0
  else
    return 1
  fi
}
valid_ipv6() {
  local ip="$1"
  if getent ahostsv6 "$ip" | grep -qE '^[0-9a-fA-F:]+'; then
    return 0
  else
    return 1
  fi
}
is_any_ip() {
  local input="$1"
  if valid_ipv4 "$input" || valid_ipv6 "$input"; then
    return 0
  else
    return 1
  fi
}
# ==== Fleet Hypervisor ====
fleet_vps_init() {
  if [[ "$ENABLE_VPS" == "false" ]]; then
    warn "VPS functionality has not been enabled" \
	  "Please enable first in the config file"
	exit 1
  fi
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ ! -f /etc/one-click/virtualization/.initialized ]]; then
    warn "Fleet VPS module has not been initialized"
	read -rp "Are you sure you want to initialize VPS functionality (y|N)? " vps_init
	vps_init="${vps_init,,}"
	if [[ "$vps_init" != "yes" && "$vps_init" != "y" ]]; then
	  error "VPS initialization cancelled"
	  exit 0
	fi
    touch /etc/one-click/virtualization/.initialized
  fi
  if command -v apt-get &>/dev/null; then
    apt-get update &>/dev/null && apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst iptables curl jq network-manager 2> /dev/null
  elif command -v dnf &>/dev/null; then
    dnf install -y qemu-kvm libvirt libvirt-client virt-install bridge-utils iptables curl jq NetworkManager 2> /dev/null
    systemctl enable --now NetworkManager &>/dev/null
  fi
  info "Configuring local Master Controller virtualization tracking ledgers."
  local wg_env_dir="/etc/one-click/dns/modules"
  local virt_dir="/etc/one-click/virtualization"
  local target_wg_port="${WG_PORT:-51821}"
  mkdir -p "$wg_env_dir" "$virt_dir/images" "$virt_dir/staging" "$virt_dir/secrets"
  local wg_env_file="${wg_env_dir}/wireguard_pool.env"
  if [[ ! -f "$wg_env_file" ]]; then
    cat > "$wg_env_file" <<EOF
export FLEET_AVAILABLE_IPS_FILE="${virt_dir}/available_ips.txt"
export FLEET_USED_IPS_FILE="${virt_dir}/used_ips.txt"
EOF
  fi
  . "$wg_env_file"
  touch "$FLEET_USED_IPS_FILE"
  if [[ ! -s "$FLEET_AVAILABLE_IPS_FILE" ]]; then
    info "Generating internal cluster mesh IP block tracking pools."
    local tmp_pool
    tmp_pool=$(mktemp)
    for b in {1..40}; do
      for c in {1..250}; do
        echo "10.10.${b}.${c}" >> "$tmp_pool"
      done
    done
    mv "$tmp_pool" "$FLEET_AVAILABLE_IPS_FILE"
    chmod 600 "$FLEET_AVAILABLE_IPS_FILE"
  fi
  local master_wg_config="/etc/wireguard/one-click.conf"
  if [[ ! -f "$master_wg_config" ]]; then
    info "Constructing controller WireGuard interface configuration profile."
    mkdir -p /etc/wireguard
    chmod 700 /etc/wireguard
    local master_priv master_pub
    master_priv=$(wg genkey)
    master_pub=$(echo "$master_priv" | wg pubkey)
    echo "$master_pub" > /etc/wireguard/oc_public.key
    echo "$master_priv" > /etc/wireguard/oc_private.key
    local controller_outbound_nic
    controller_outbound_nic=$(awk 'NR==1{print $5}' <(ip -4 -6 route show default | grep -v "virbr"))
    # ==== Configure Controller Firewall ====
    if command -v nft >/dev/null 2>&1; then
      FW_POSTUP="
        #PostUp = nft add rule inet filter forward iifname \"one-click\" oifname \"${controller_outbound_nic}\" accept
        #PostUp = nft add rule inet filter forward iifname \"${controller_outbound_nic}\" oifname \"one-click\" ct state related,established accept
        PostUp = nft add table ip wg-nat
        PostUp = nft flush table ip wg-nat
        PostUp = nft add chain ip wg-nat postrouting '{ type nat hook postrouting priority 100; }'
        PostUp = nft add rule ip wg-nat postrouting oifname \"${controller_outbound_nic}\" masquerade
        PostUp = nft add table ip6 wg-nat6
        PostUp = nft flush table ip6 wg-nat6
        PostUp = nft add chain ip6 wg-nat6 postrouting '{ type nat hook postrouting priority 100; }'
        PostUp = nft add rule ip6 wg-nat6 postrouting oifname \"${controller_outbound_nic}\" masquerade
        PostUp = nft add rule ip6 wg-nat6 postrouting ip6 saddr fd00:99aa::/64 oifname \"${controller_outbound_nic}\" masquerade
      "
      FW_PREDOWN="
        #PreDown = nft delete rule inet filter forward iifname \"one-click\" oifname \"${controller_outbound_nic}\" accept
        #PreDown = nft delete rule inet filter forward iifname \"${controller_outbound_nic}\" oifname \"one-click\" ct state related,established accept
        PreDown = nft delete table ip wg-nat
        PreDown = nft delete table ip6 wg-nat6
      "
    elif command -v iptables >/dev/null 2>&1; then
      FW_POSTUP="
        #PostUp = iptables -A FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
        #PostUp = iptables -A FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
        PostUp = iptables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
        PostUp = ip6tables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
        PostUp = ip6tables -t nat -I POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE
      "
      FW_PREDOWN="
        #PreDown = iptables -D FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
        #PreDown = iptables -D FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
        PreDown = iptables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
        PreDown = ip6tables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
        PreDown = ip6tables -t nat -D POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE
      "
    else
      error "Neither iptables nor nftables is installed. A firewall backend is required for NAT."
      exit 1
    fi
    [[ -z "$controller_outbound_nic" ]] && controller_outbound_nic="eth0"
    cat > "$master_wg_config" <<EOF
[Interface]
Address = 10.10.0.1/16
MTU = 1412
SaveConfig = false
ListenPort = 51821
PrivateKey = ${master_priv}

PostUp = sysctl -w net.ipv4.conf.all.forwarding=1
PostUp = sysctl -w net.ipv4.conf.default.forwarding=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1
PostUp = sysctl -w net.ipv6.conf.default.forwarding=1

PreDown = true
# ==== Layer-3 Forwarding Pipelines ====
${FW_POSTUP}

${FW_PREDOWN}

# ==== One-Click Fleet Peers ====
EOF
    chmod 600 "$master_wg_config"
    systemctl stop wg-quick@one-click &>/dev/null || true
    ip link delete dev one-click &>/dev/null || true
    systemctl daemon-reload &>/dev/null
    systemctl enable --now wg-quick@one-click &>/dev/null
  fi
  info "Validating CPU hardware virtualization compatibility across the fleet."
  local hardware_capable=1
  if [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
    if ! grep -Ec '(vmx|svm)' /proc/cpuinfo &>/dev/null; then
	  hardware_capacle=0
	fi
    info '> Verifying KVM internal NAT network infrastructure switches.'
    if ! virsh net-info oneclick-nat &>/dev/null; then
      warn '> Compiling and defining default NAT network infrastructure.'
        cat > /tmp/kvm_default_nat.xml <<EOF
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0' connections='3'>
  <name>oneclick-nat</name>
  <forward mode='nat'/>
  <bridge name='ocbr0' stp='on' delay='0'/>
  <dns>
    <forwarder addr='1.1.1.1'/>
    <forwarder addr='8.8.8.8'/>
	<forwarder addr='2606:4700:4700::1111'/>
    <forwarder addr='2001:4860:4860::8888'/>
  </dns>
  <ip address='192.168.250.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.250.2' end='192.168.250.254'/>
    </dhcp>
  </ip>
  <ip family='ipv6' address='fd00:99aa::1' prefix='64'>
    <dhcp>
      <range start='fd00:99aa::2' end='fd00:99aa::ffff'/>
    </dhcp>
  </ip>
  <dnsmasq:options>
    <dnsmasq:option value='port=0'/>
	<dnsmasq:option value='dhcp-option=6,1.1.1.1,8.8.8.8'/>
	<dnsmasq:option value='dhcp-option=option6:dns-server,[2606:4700:4700::1111],[2001:4860:4860::8888]'/>
  </dnsmasq:options>
</network>
EOF
      virsh net-define /tmp/kvm_default_nat.xml &>/dev/null
      rm -f /tmp/kvm_default_nat.xml
    fi
	if ! virsh net-info oneclick-public &> /dev/null; then
  	  cat > /tmp/kvm_public.xml <<EOF
<network>
  <name>oneclick-public</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
EOF
      systemctl enable --now libvirtd &> /dev/null || error "Libvirt not started"
      virsh net-define /tmp/kvm_public.xml &> /dev/null
	  rm -f /tmp/kvm_public.xml
	fi
    if [ "$(virsh net-info oneclick-nat 2>/dev/null | grep -E '^Active:' | awk '{print $2}')" != "yes" ]; then
      info '> Activating default NAT hypervisor bridge (ocbr0).'
      virsh net-start oneclick-nat &>/dev/null
    fi
	if [ "$(virsh net-info oneclick-public 2>/dev/null | grep -E '^Active:' | awk '{print $2}')" != "yes" ]; then
      info '> Activating default PUBLIC hypervisor bridge (br0).'
      virsh net-start oneclick-public &>/dev/null
    fi
    virsh net-autostart oneclick-nat &>/dev/null
	virsh net-autostart oneclick-public &>/dev/null
    local physical_nic=$(ip route show default | awk '{print $5}')
	if [[ -z "$physical_nic" ]]; then
	  physical_nic=$(awk '{print $5}' <(ip -6 r s default))
	fi
    if [ -n "$physical_nic" ] && [ ! -d "/sys/class/net/br0" ]; then
      if nmcli dev status &>/dev/null; then
        info "> NetworkManager active: Re-wiring interface $physical_nic to public bridge br0."
        ip_addr=$(ip -o -4 addr show dev $physical_nic | awk '{print $4}' | head -n 1)
        gateway=$(ip route show default | awk '{print $3}')
        nameservers=$(grep -i nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ' | sed 's/ \$//')
        old_conn=${physical_nic}
        nmcli connection add type bridge con-name br0 ifname br0 ip4 "$ip_addr" gw4 "$gateway" &>/dev/null
        nmcli connection modify br0 ipv4.dns "1.1.1.1 8.8.8.8" ipv6.dns "2606:4700:4700::1111 2001:4860:4860::8888" &>/dev/null || nmcli connection modify br0 ipv4.dns "$nameservers" &>/dev/null
        nmcli connection modify br0 bridge.stp no bridge.forward-delay 0 &>/dev/null
        nmcli connection add type ethernet con-name br0-slave ifname "$physical_nic" master br0 &>/dev/null
        [ -n "$old_conn" ] && nmcli connection delete "$old_conn" &>/dev/null
        nmcli connection up br0 &>/dev/null
        nmcli connection up br0-slave &>/dev/null
        sleep 10
        if ping -c2 "$gateway" >/dev/null 2>&1; then
          [ -n "$old_conn" ] && nmcli connection delete "$old_conn" || true
          info '> Public Layer-2 bridge br0 online and routing successfully.'
        else
          error '> Bridge validation failed. Original profile retained.'
        fi
      elif command -v netplan &>/dev/null; then
        netplan_file=\"/etc/netplan/50-cloud-init.yaml\"
        [ ! -f "$netplan_file" ] && netplan_file=$(ls /etc/netplan/*.yaml | head -n 1)
        if [ -f "$netplan_file" ] && ! grep -q "br0" "$netplan_file"; then
          info "> Netplan active: Writing configuration matrix definitions for br0."
          cp "$netplan_file" "${netplan_file}.bak"
          ip_addr=$(ip -o -4 addr show dev $physical_nic | awk '{print $4}' | head -n 1)
          gateway=$(ip route show default | awk '{print $3}')
          nameservers=$(grep -i nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,\$//')
          cat > "$netplan_file" <<EOF
network:
  version: 2
  ethernets:
    \${physical_nic}:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      interfaces: [\${physical_nic}]
      dhcp4: false
      addresses: [\${ip_addr}]
      routes:
        - to: default
          via: \${gateway}
      nameservers:
        addresses: [\${nameservers}]
      parameters:
        stp: false
        forward-delay: 0
EOF
        netplan apply &>/dev/null
        info '> Netplan profile applied: Public bridge br0 activated.'
        fi
      fi
    fi
  elif ! ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible ${target_host} -i /etc/one-click/fleet/inventory.yml -u oneclick --become \
    -m shell -a "grep -Ec '(vmx|svm)' /proc/cpuinfo" &>/dev/null; then
    hardware_capable=0
  fi
  if [[ $hardware_capable -eq 0 ]]; then
    error "One or more fleet nodes do not support or have disabled Hardware Virtualization (VT-x/AMD-V) in BIOS."
    return 1
  fi
  success "Hardware virtualization capabilities verified."
  local private_subnet="192.168.250.0/24"
  local ipv6_private_subnet=fd00:99aa::/64
  info "Deploying KVM core hypervisor frameworks and building cross-platform file structures."
  set +e
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible ${target_host:-all} \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a "
      echo '>>> Initializing virtualization target tracking paths.'
      mkdir -p /etc/one-click/virtualization/images
	  touch /etc/one-click/virtualization/.initialized
      mkdir -p /var/lib/libvirt/images
      chmod 755 /etc/one-click/virtualization/images
      echo '>>> Syncing required system repository packages framework.'
      if command -v apt-get &>/dev/null; then
        apt-get update &>/dev/null && apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst iptables curl jq network-manager &>/dev/null
      elif command -v dnf &>/dev/null; then
        dnf install -y qemu-kvm libvirt libvirt-client virt-install bridge-utils iptables curl jq NetworkManager &>/dev/null
        systemctl enable --now NetworkManager &>/dev/null
      fi
      systemctl start libvirtd &>/dev/null || true
	  echo 'Creating table 200 Masquerade'
	  ip rule add from 192.168.250.0/24 pref 25000 table main
      ip rule add from 192.168.250.0/24 pref 25001 table 200
	  ip -6 rule add from fd00:99aa::/64 pref 25000 table main
      ip -6 rule add from fd00:99aa::/64 pref 25001 table 200
      private_subnet="192.168.250.0/24"
	  ipv6_private_subnet=fd00:99aa::/64
      if ! iptables -t nat -C POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
        if ! iptables -t nat -I POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
          nft add table ip nat 2>/dev/null || true
		  nft add table ipv6 nat 2>/dev/null || true
          nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat \; policy accept \; }' 2>/dev/null
		  nft add chain ipv6 nat POSTROUTING '{ type nat hook postrouting priority srcnat \; policy accept \; }' 2>/dev/null
          if ! nft list chain ip nat POSTROUTING | grep -q \"ip saddr $private_subnet ip daddr != $private_subnet masquerade\"; then
            nft add rule ip nat POSTROUTING ip saddr \"$private_subnet\" ip daddr != \"$private_subnet\" masquerade 2>/dev/null
			nft add rule ip6 nat POSTROUTING ip saddr \"$ipv6_private_subnet\" ip daddr != \"$ipv6_private_subnet\" masquerade 2>/dev/null
          fi
        fi
      fi
      echo '>>> Verifying KVM internal NAT network infrastructure switches.'
      if ! virsh net-info oneclick-nat &>/dev/null; then
        echo '>>> Compiling and defining missing default NAT network XML infrastructure.'
        cat > /tmp/kvm_default_nat.xml <<EOF
<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0' connections='3'>
  <name>oneclick-nat</name>
  <forward mode='nat'/>
  <bridge name='ocbr0' stp='on' delay='0'/>
  <dns>
    <forwarder addr='1.1.1.1'/>
    <forwarder addr='8.8.8.8'/>
	<forwarder addr='2606:4700:4700::1111'/>
    <forwarder addr='2001:4860:4860::8888'/>
  </dns>
  <ip address='192.168.250.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.250.2' end='192.168.250.254'/>
    </dhcp>
  </ip>
  <ip family='ipv6' address='fd00:99aa::1' prefix='64'>
    <dhcp>
      <range start='fd00:99aa::2' end='fd00:99aa::ffff'/>
    </dhcp>
  </ip>
  <dnsmasq:options>
    <dnsmasq:option value='port=0'/>
	<dnsmasq:option value='dhcp-option=6,1.1.1.1,8.8.8.8'/>
	<dnsmasq:option value='dhcp-option=option6:dns-server,[2606:4700:4700::1111],[2001:4860:4860::8888]'/>
  </dnsmasq:options>
</network>
EOF

        virsh net-define /tmp/kvm_default_nat.xml &>/dev/null
        rm -f /tmp/kvm_default_nat.xml
      fi
      if ! virsh net-info oneclick-public &> /dev/null; then
		cat > /tmp/kvm_public.xml <<EOF
<network>
  <name>oneclick-public</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
EOF
        virsh net-define /tmp/kvm_public.xml &> /dev/null
		rm -f /tmp/kvm_public.xml
	  fi
      if [ \"\$(virsh net-info oneclick-nat 2>/dev/null | grep -E '^Active:' | awk '{print \$2}')\" != \"yes\" ]; then
        echo '>>> Activating default NAT hypervisor bridge (ocbr0).'
        virsh net-start oneclick-nat &>/dev/null
      fi
	  if [ \"\$(virsh net-info oneclick-public 2>/dev/null | grep -E '^Active:' | awk '{print \$2}')\" != \"yes\" ]; then
        echo '>>> Activating default PUBLIC hypervisor bridge (br0).'
        virsh net-start oneclick-public &>/dev/null
      fi
      virsh net-autostart oneclick-nat &>/dev/null
	  virsh net-autostart oneclick-public &>/dev/null
      physical_nic=\$(ip route show default | awk '{print \$5}')
	  if [[ -z \"\$physical_nic\" ]]; then
	    physical_nic=\$(awk '{print \$5}' <(ip -6 r s default))
	  fi
      if [ -n \"\$physical_nic\" ] && [ ! -d \"/sys/class/net/br0\" ]; then
        if nmcli dev status &>/dev/null; then
          echo \">>> NetworkManager active: Re-wiring interface \$physical_nic to public bridge br0.\"
          ip_addr=\$(ip -o -4 addr show dev \$physical_nic | awk '{print \$4}' | head -n 1)
          gateway=\$(ip route show default | awk '{print \$3}')
          nameservers=\$(grep -i nameserver /etc/resolv.conf | awk '{print \$2}' | tr '\n' ' ' | sed 's/ \$//')
          old_conn=\$(nmcli -g NAME connection show --active | grep -E \"(\$physical_nic|Wired)\" | head -n 1)
          nmcli connection add type bridge con-name br0 ifname br0 ip4 \"\$ip_addr\" gw4 \"\$gateway\" &>/dev/null
          nmcli connection modify br0 ipv4.dns \"1.1.1.1 8.8.8.8\" ipv6.dns \"2606:4700:4700::1111 2001:4860:4860::8888\" &>/dev/null || nmcli connection modify br0 ipv4.dns \"\$nameservers\" &>/dev/null
          nmcli connection modify br0 bridge.stp no bridge.forward-delay 0 &>/dev/null
          nmcli connection add type ethernet con-name br0-slave ifname \"\$physical_nic\" master br0 &>/dev/null
          [ -n \"\$old_conn\" ] && nmcli connection delete \"\$old_conn\" &>/dev/null
          nmcli connection up br0 &>/dev/null
          nmcli connection up br0-slave &>/dev/null
          sleep 10
          if ping -c2 "\$gateway" >/dev/null 2>&1; then
            [ -n "\$old_conn" ] && nmcli connection delete "\$old_conn"
            echo '>>> Public Layer-2 bridge br0 online and routing successfully.'
          else
            echo '>>> Bridge validation failed. Original profile retained.'
          fi
        elif command -v netplan &>/dev/null; then
          netplan_file=\"/etc/netplan/50-cloud-init.yaml\"
          [ ! -f \"\$netplan_file\" ] && netplan_file=\$(ls /etc/netplan/*.yaml | head -n 1)
          if [ -f \"\$netplan_file\" ] && ! grep -q \"br0\" \"\$netplan_file\"; then
            echo \">>> Netplan active: Writing configuration matrix definitions for br0.\"
            cp \"\$netplan_file\" \"\${netplan_file}.bak\"
            ip_addr=\$(ip -o -4 addr show dev \$physical_nic | awk '{print \$4}' | head -n 1)
            gateway=\$(ip route show default | awk '{print \$3}')
            nameservers=\$(grep -i nameserver /etc/resolv.conf | awk '{print \$2}' | tr '\n' ',' | sed 's/,\$//')
            cat > \"\$netplan_file\" <<EOF
network:
  version: 2
  ethernets:
    \${physical_nic}:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      interfaces: [\${physical_nic}]
      dhcp4: false
      addresses: [\${ip_addr}]
      routes:
        - to: default
          via: \${gateway}
      nameservers:
        addresses: [\${nameservers}]
      parameters:
        stp: false
        forward-delay: 0
EOF
            netplan apply &>/dev/null
            echo '>>> Netplan profile applied: Public bridge br0 activated.'
          fi
        fi
      fi
      echo '>>> Enabling and initializing background hypervisor libvirtd engines.'
      sysctl -w net.ipv4.ip_forward=1 &>/dev/null
      if [ -d \"/etc/sysctl.d\" ]; then
        echo \"net.ipv4.ip_forward=1\" > /etc/sysctl.d/99-oneclick-virtualization.conf
      else
        echo \"net.ipv4.ip_forward=1\" >> /etc/sysctl.conf
      fi
      systemctl enable --now libvirtd 2>/dev/null
      modprobe kvm
      modprobe kvm_intel 2>/dev/null || modprobe kvm_amd 2>/dev/null || modprobe kvm-intel 2>/dev/null || modprobe kvm-amd 2>/dev/null
      echo '>>> Virtualization system environment configured.'
    executable=/bin/bash" 2> /dev/null | sed -E '
    /changed=/d;
    /SUCCESS/d;
    s/^([a-zA-Z0-9.-]+)[[:space:]]*\|[[:space:]]*CHANGED[[:space:]]*\|.*rc=0[[:space:]]*>>/[\1]/g;
    s/>>>[[:space:]]*/  -> /g;
  '
  set -e
  success "Hypervisor nodes successfully provisioned and directory structures created."
}
write_peer_vps_vg_allocation() {
  rm -f "$storage_script"
  mkdir -p "$(dirname "$storage_script")"
  cat > "$storage_script" << 'EOF'
#!/usr/bin/env bash
# Written by Chike Egbuna for One-Click Panel
set -e
info() { echo -e "\e[34m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
error() { echo -e "\e[31m[ERROR]\e[0m $1" >&2; }
success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
disk_size="$1"
storage_dir="$3"
vm_name="$2"
VG_ALLOC="$4"
ALLOC_THRESHOLD="${5:-5120}"
vg_name=one_click_vg
if [ -z "$storage_dir" ]; then
  storage_dir="/etc/one-click/virtualization/images/fleet_storage.img"
fi
thin_pool="one_click_pool"
loop_file="${storage_dir}/fleet_storage.img"
vm_lv_name="lv_${vm_name}"
if ! command -v pvcreate &>/dev/null || ! command -v vgcreate &>/dev/null; then
  info "Installing LVM infrastructure dependencies on host node."
  if command -v apt-get &> /dev/null; then
    apt-get update -y &> /dev/null
    apt-get upgrade -y &> /dev/null
    apt-get -y install lvm2 &> /dev/null
  else
    dnf -y install lvm2 &> /dev/null || yum -y install lvm2 &> /dev/null
  fi
fi
mkdir -p "$storage_dir"
if ! vgdisplay "$vg_name" &>/dev/null; then
  warn "Volume Group '$vg_name' not detected. Initiating ${VG_ALLOC}% Host Allocation Engine."
  target_drive=""
  drive_count=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | wc -l)
  primary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | head -n 1 | awk '{print $1}')
  if [ -z "$primary_drive" ] || [ "$primary_drive" = "null" ]; then
    primary_drive=$(lsblk -no PKNAME $(findmnt -vno SOURCE /) | head -n 1)
  fi
  if [ "$drive_count" -gt 1 ]; then
    secondary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | sed -n '2p' | awk '{print $1}')
    target_drive="/dev/${secondary_drive}"
    if mount | grep -q "$target_drive"; then
      mount_point=$(mount | grep "$target_drive" | awk '{print $3}' | head -n 1)
      loop_file="${mount_point}/fleet_storage.img"
    fi
  else
    target_drive="/dev/${primary_drive}"
  fi
  target_dir_path=$(dirname "$loop_file")
  free_kb=$(df -k "$target_dir_path" | awk 'NR==2 {print $4}')
  alloc_mb=$(( (free_kb * 60) / 100 / 1024 ))
  if [ "$alloc_mb" -lt "$ALLOC_THRESHOLD" ]; then
    error "Less than 5GB of RAM available. Aborting LVM provisioning."
    return 1
  fi
  if [ ! -f "$loop_file" ]; then
    info "Allocating ${alloc_mb}MB storage pool."
    if ! fallocate -l "${alloc_mb}M" "$loop_file"; then
      error "Failed allocate container space."
      exit 1
    fi
  fi
  target_loop=$(losetup -j "$loop_file" | awk -F: '{print $1}' | head -n 1)
  if [ -z "$target_loop" ]; then
    target_loop=$(losetup -f)
    if ! losetup "$target_loop" "$loop_file"; then
      error "Failed to attach loop controller."
      rm -f "$loop_file"
      exit 1
    fi
  fi
  pvscan --cache "$target_loop" &>/dev/null || true
  if ! vgdisplay "$vg_name" &>/dev/null; then
    pvcreate "$target_loop" -y &>/dev/null
    if vgcreate "$vg_name" "$target_loop" -y &>/dev/null; then
      info "Spawning underlying thin pool at ${VG_ALLOC}% VG capacity."
      lvcreate -l ${VG_ALLOC}%VG --thinpool "$thin_pool" "$vg_name" -y &>/dev/null
    else
      error "Unable to initialize LVM volume group mappings."
      exit 1
    fi
  fi
  if [ -f /etc/lvm/lvm.conf ]; then
    sed -i 's/^[[:space:]]*#*[[:space:]]*thin_pool_autoextend_threshold[[:space:]]*=.*/    thin_pool_autoextend_threshold = 80/' /etc/lvm/lvm.conf 2>/dev/null || true
    sed -i 's/^[[:space:]]*#*[[:space:]]*thin_pool_autoextend_percent[[:space:]]*=.*/    thin_pool_autoextend_percent = 20/' /etc/lvm/lvm.conf 2>/dev/null || true
    systemctl enable --now lvm2-monitor 2>/dev/null || true
    vgchange --monitor y "$vg_name" &>/dev/null || true
  fi
  if [ -f /etc/rc.local ] && ! grep -q "$loop_file" /etc/rc.local; then
    sed -i -e '$i \losetup -f '"$loop_file"' \&\& vgchange -ay '"$vg_name"'\n' /etc/rc.local
  elif [ ! -f /etc/rc.local ]; then
    echo -e "#!/bin/sh -e\nlosetup -f ${loop_file} && vgchange -ay ${vg_name}\nexit 0" > /etc/rc.local
    chmod +x /etc/rc.local
  fi
fi
if ! lvdisplay "${vg_name}/${vm_lv_name}" &>/dev/null; then
  if [ -z "$vm_name" ]; then
    error "Deployment Error: A unique VM Name must be passed to provision an independent thin block device."
    exit 1
  fi
  info "Allocating dedicated target block device for ${vm_name} (${disk_size})."
  if sudo lvcreate -V "$disk_size" --thin -n "$vm_lv_name" "${vg_name}/${thin_pool}" -y &>/dev/null; then
    success "Successfully provisioned block path: /dev/${vg_name}/${vm_lv_name}"
  else
    error "Failed to allocate thin volume space for ${vm_name}."
    exit 1
  fi
else
  info "Target block device /dev/${vg_name}/${vm_lv_name} already exists."
fi
rm -f "$0"
EOF
  chmod +x "$storage_script"
}
vps_vg_allocation() {
  local disk_size="$1"
  local vm_name="$2"
  local vg_name="one_click_vg"
  local thin_pool="one_click_pool"
  local storage_dir="$IMG_STORAGE_PATH"
  local loop_file="${storage_dir}/fleet_storage.img"
  if ! command -v pvcreate &>/dev/null || ! command -v vgcreate &>/dev/null || ! command -v parted &>/dev/null; then
    info "Installing LVM dependencies."
    install_dep "lvm2" "type lvm2" "lvm2" "$pkg_mgr"
    install_dep "parted" "type parted" "parted" "$pkg_mgr"
  fi
  mkdir -p "$storage_dir"
  if ! vgdisplay "$vg_name" &>/dev/null; then
    warn "Volume Group '$vg_name' not detected. Initiating ${VG_ALLOC}% Host Allocation Engine."
    local target_drive=""
    local drive_count
    drive_count=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | wc -l)
    local primary_drive
    primary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | head -n 1 | awk '{print $1}')
    if [ -z "$primary_drive" ] || [ "$primary_drive" = "null" ]; then
      primary_drive=$(lsblk -no PKNAME $(findmnt -vno SOURCE /) | head -n 1)
    fi
    if [ "$drive_count" -gt 1 ]; then
      local secondary_drive
      secondary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme|virtblk" | sed -n '2p' | awk '{print $1}')
      target_drive="/dev/${secondary_drive}"
      if mount | grep -q "$target_drive"; then
        local mount_point
        mount_point=$(mount | grep "$target_drive" | awk '{print $3}' | head -n 1)
        loop_file="${mount_point}/fleet_storage.img"
      fi
    else
      target_drive="/dev/${primary_drive}"
    fi
    local target_dir_path
    target_dir_path=$(dirname "$loop_file")
    local free_kb
    free_kb=$(df -k "$target_dir_path" | awk 'NR==2 {print $4}')
    local alloc_mb
    alloc_mb=$(( (free_kb * 92) / 100 / 1024 ))
    if [ ! -f "$loop_file" ]; then
      info "Allocating ${alloc_mb}MB storage pool."
      if ! fallocate -l "${alloc_mb}M" "$loop_file"; then
        error "Failed to pre-allocate container space."
        return 1
      fi
    fi
    local target_loop
    target_loop=$(losetup -j "$loop_file" | awk -F: '{print $1}' | head -n 1)
    if [ -z "$target_loop" ]; then
      target_loop=$(losetup -f)
      if ! losetup "$target_loop" "$loop_file"; then
        error "Failed to attach loop controller."
        rm -f "$loop_file"
        return 1
      fi
    fi
    pvscan --cache "$target_loop"
    if ! vgdisplay "$vg_name" &>/dev/null; then
      pvcreate "$target_loop" -y &>/dev/null
      if vgcreate "$vg_name" "$target_loop" -y &>/dev/null; then
        info "Spawning underlying thin pool at ${VG_ALLOC}% VG capacity."
        lvcreate -l ${VG_ALLOC}%VG --thinpool "$thin_pool" "$vg_name" -y &>/dev/null
      else
        error "Unable to initialize LVM volume group mappings."
        return 1
      fi
    fi
    if [ -f /etc/lvm/lvm.conf ]; then
      sed -i 's/^[[:space:]]*#*[[:space:]]*thin_pool_autoextend_threshold[[:space:]]*=.*/    thin_pool_autoextend_threshold = 80/' /etc/lvm/lvm.conf 2>/dev/null || true
      sed -i 's/^[[:space:]]*#*[[:space:]]*thin_pool_autoextend_percent[[:space:]]*=.*/    thin_pool_autoextend_percent = 20/' /etc/lvm/lvm.conf 2>/dev/null || true
      systemctl enable --now lvm2-monitor 2>/dev/null || true
      vgchange --monitor y "$vg_name" &>/dev/null || true
    fi
    if [ -f /etc/rc.local ] && ! grep -q "$loop_file" /etc/rc.local; then
      sed -i -e '$i \losetup -f '"$loop_file"' \&\& vgchange -ay '"$vg_name"'\n' /etc/rc.local
    elif [ ! -f /etc/rc.local ]; then
      echo -e "#!/bin/sh -e\nlosetup -f ${loop_file} && vgchange -ay ${vg_name}\nexit 0" > /etc/rc.local
      chmod +x /etc/rc.local
    fi
  fi
  if [ -z "$vm_name" ]; then
    error "Deployment Error: A unique VM Name must be passed to provision an independent thin block device."
    return 1
  fi
  local vm_lv_name="lv_${vm_name}"
  if ! lvdisplay "${vg_name}/${vm_lv_name}" &>/dev/null; then
    info "Allocating dedicated target block device for ${vm_name} (${disk_size})."
    if lvcreate -V "$disk_size" --thin -n "$vm_lv_name" "${vg_name}/${thin_pool}" -y &>/dev/null; then
      success "Successfully provisioned block path: /dev/${vg_name}/${vm_lv_name}"
    else
      error "Failed to allocate thin volume space for ${vm_name}."
      return 1
    fi
  else
    info "Target block device /dev/${vg_name}/${vm_lv_name} already exists."
  fi
}
# ==== One-Click Fleet VPS Migration Engine ====
fleet_vps_migrate() {
  local target_vm="" dest_host=""
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local dest_host="$1"
  local target_vm="$2"
  local source_host vps_ip
  source_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null | head -1)
  vps_ip=$(jq -r ".[] | select(.name == \"$target_vm\") | .cluster_private_ip" "$inventory_json" 2>/dev/null)
  if [[ -z "$source_host" || "$source_host" == "null" ]]; then
    error "Target VM '$target_vm' could not be resolved to a valid source hypervisor."
    return 1
  fi
  if [[ "$source_host" == "$dest_host" ]]; then
    error "Target VM '$target_vm' is already running on $dest_host."
    return 1
  fi
  info "Resolving routing paths for cluster nodes."
  local source_ip dest_ip
  source_ip=$(ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' ansible-inventory -i "$inventory_file" --host "$source_host" 2> /dev/null | jq -r '.ansible_host // empty')
  dest_ip=$(ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' ansible-inventory -i "$inventory_file" --host "$dest_host" 2> /dev/null | jq -r '.ansible_host // empty')
  if [[ -z "$source_ip" || -z "$dest_ip" ]]; then
    error "Network Resolution Fault: Could not map cluster host names to valid target IPs."
    echo "Source [$source_host]: ${source_ip:-UNKNOWN}"
    echo "Destination [$dest_host]: ${dest_ip:-UNKNOWN}"
    return 1
  fi
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  if [[ ! -f "$private_key" ]]; then
    private_key="/home/oneclick/.ssh/id_ed25519"
  fi
  info "Begining migrating from $source_host ($source_ip) => $dest_host ($dest_ip)" \
    "Extracting live instance XML definition blueprint structure."
  local xml_blueprint
  xml_blueprint=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "sudo virsh dumpxml $target_vm" 2>/dev/null)
  if [[ -z "$xml_blueprint" || "$xml_blueprint" != *"<domain"* ]]; then
    error "Critical Fault: Failed to capture valid KVM configuration blueprint metadata."
    return 1
  fi
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "sudo virsh shutdown $target_vm" &>/dev/null || true
  info "Staging operational storage parameters on destination node."
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo bash -c '
    mkdir -p /var/lib/libvirt/images
    if ! mountpoint -q /var/lib/libvirt/images; then
      mount /dev/one_click_vg/one_click_repo /var/lib/libvirt/images 2>/dev/null || true
    fi
    if lvs /dev/one_click_vg/one_click_pool &>/dev/null; then
      lvextend -l +100%FREE /dev/one_click_vg/one_click_pool 2>/dev/null || true
    fi
    if lvs /dev/one_click_vg/one_click_repo &>/dev/null; then
      lvextend -l +100%FREE -r /dev/one_click_vg/one_click_repo 2>/dev/null || true
    fi
    rm -f /tmp/${target_vm}.xml /var/lib/libvirt/images/${target_vm}.qcow2 /var/lib/libvirt/images/${target_vm}_cloudinit.iso
  '" &>/dev/null
  echo "$xml_blueprint" | ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "cat > /tmp/${target_vm}.xml"
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo chown root:root /tmp/${target_vm}.xml && sudo chmod 600 /tmp/${target_vm}.xml" &>/dev/null
  info "Replicating disk block to $dest_host ($dest_ip)." \
    "[ $source_host ] => [ $dest_host ]"
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "sudo chown -R oneclick:oneclick /var/lib/libvirt/images" &>/dev/null
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo chown oneclick:oneclick /var/lib/libvirt/images" &>/dev/null
  ssh -t -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "bash -s" << EOF
    sync_success=1
    for node_key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
      if [ ! -e "\$node_key" ]; then continue; fi
      rsync -avz --progress --no-implied-dirs \
        -e "ssh -i \$node_key -o StrictHostKeyChecking=no -o ConnectTimeout=10" \
        --include="${target_vm}.qcow2" \
        --include="${target_vm}_cloudinit.iso" \
		--include="${target_vm}.*" \
        --exclude="*" \
        /var/lib/libvirt/images/ oneclick@${dest_ip}:/var/lib/libvirt/images/
      if [ \$? -eq 0 ]; then
        sync_success=0
        break
      fi
    done
    exit \$sync_success
EOF
  local sync_status=$?
  if [[ $sync_status -eq 0 ]]; then
    success "Data block synchronization completed successfully."
    ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "sudo bash -c '
      virsh undefine $target_vm 2>/dev/null || true
      rm -f /var/lib/libvirt/images/${target_vm}.qcow2 /var/lib/libvirt/images/${target_vm}_cloudinit.iso
      chown -R root:root /var/lib/libvirt/images
    '" &>/dev/null
  else
    error "Data stream broken. Reverting source file access locks."
    ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${source_ip}" "sudo chown -R root:root /var/lib/libvirt/images" &>/dev/null
    return 1
  fi
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo bash -c '
    chown root:root /var/lib/libvirt/images
    chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/${target_vm}.qcow2 2>/dev/null || true
    chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/${target_vm}_cloudinit.iso 2>/dev/null || true
    chmod 644 /var/lib/libvirt/images/${target_vm}.qcow2 2>/dev/null || true
    chmod 644 /var/lib/libvirt/images/${target_vm}_cloudinit.iso 2>/dev/null || true
  '" &>/dev/null
  info "Registering runtime boundaries and starting VM on $dest_host."
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo bash -c '
    virsh define /tmp/${target_vm}.xml
    virsh autostart $target_vm &> /dev/null
    sleep 2
	virsh start $target_vm &> /dev/null || die "Failed to start $vps_name"
    rm -f /tmp/${target_vm}.xml
  '" &>/dev/null
  info "Updating dynamic network routing ledger in virtualization inventory."
  if jq --arg vm "$target_vm" \
        --arg new_host "$dest_host" \
        --arg new_ip "$dest_ip" \
       'map(if .name == $vm then .host = $new_host | .host_ip = $new_ip else . end)' \
       "$inventory_json" > "${inventory_json}.tmp"; then
     mv "${inventory_json}.tmp" "$inventory_json"
     success "Virtualization state ledger successfully updated."
  else
     error "Critical Failure: Failed to update virtualization inventory ledger state."
     rm -f "${inventory_json}.tmp"
     return 1
  fi
  success "Migration process complete. $target_vm is now active on $dest_host."
}
# ==== Fleet VPS Snapshot ====
fleet_vps_snapshot() {
  local action="" target_vm="" snap_name=""
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local ledger_json="/etc/one-click/virtualization/snapshot_ledger.json"
  . "/etc/one-click/fleet/controller.env"
  action="$1"
  target_vm="$2"
  snap_name="$3"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: Snapshot management can only be initiated from the Controller."
    return 1
  fi
  if [[ -z "$action" || -z "$target_vm" || -z "$snap_name" ]]; then
    error "Usage: one-click fleet snapshot --action <create|restore|delete> --target <vm_name> --name <snapshot_name>"
    return 1
  fi
  if [[ ! -f "$ledger_json" ]]; then
    echo "[]" > "$ledger_json"
    chmod 644 "$ledger_json"
  fi
  local target_host
  target_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null | head -1)
  if [[ -z "$target_host" || "$target_host" == "null" ]]; then
    error "Target VM '$target_vm' not found in active asset ledger."
    return 1
  fi
  local virsh_cmd=""
  case "$action" in
    create)
      info "Capturing live disk snapshot state of '$target_vm' on [$target_host]."
      virsh_cmd="virsh snapshot-create-as --domain $target_vm --name \"$snap_name\" --description \"Automated Fleet Snapshot\" --disk-only --atomic"
	  stat_error="Creation of snapshot $snap_name has failed on [$target_host]. Please review the logs on $target_host"
	  stat_success="The snapshot $snap_name has successfully been created on [$target_host]"
      ;;
    restore)
      warn "Reverting '$target_vm' to snapshot '$snap_name'. The VM will be restarted."
      virsh_cmd="virsh destroy $target_vm 2>/dev/null || true; virsh snapshot-revert --domain $target_vm --snapshotname \"$snap_name\" --current; virsh start $target_vm"
	  stat_error="Restoration of snapshot $snap_name has failed on [$target_host]. Please review the logs on $target_host"
	  stat_success="The snapshot $snap_name has successfully been restored on [$target_host]"
      ;;
    delete)
      warn "Deleting snapshot metadata."
      virsh_cmd="virsh snapshot-delete --domain $target_vm --snapshotname \"$snap_name\""
	  stat_error="Deletion of snapshot $snap_name has failed on [$target_host]. Please review the logs on $target_host"
	  stat_success="The snapshot $snap_name has successfully been deleted on [$target_host]"
      ;;
    *)
      error "Invalid action parameter. Must be: create, restore, or delete."
      return 1
      ;;
  esac
  if ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$target_host" \
    -i "$inventory_file" \
    -u oneclick --become \
    -m shell -a "$virsh_cmd" </dev/null 2> /dev/null; then
	local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [[ "$action" == "create" ]]; then
      jq ". += [{ \"name\": \"$snap_name\", \"vm\": \"$target_vm\", \"host\": \"$target_host\", \"created_at\": \"$timestamp\" }]" "$ledger_json" > "${ledger_json}.tmp" && mv "${ledger_json}.tmp" "$ledger_json"
    elif [[ "$action" == "delete" ]]; then
      jq "del(.[] | select(.name == \"$snap_name\" and .vm == \"$target_vm\"))" "$ledger_json" > "${ledger_json}.tmp" && mv "${ledger_json}.tmp" "$ledger_json"
    fi
  else
    error "$stat_error"
    return 1
  fi | sed -Eun "s/changed/${orange}&/I;s/failed/${red}&/I;N;s/([^|]*) \| ([^|]*) .*\n(.*)/[\2] \1 ${blue}=> ${magenta}\3${reset}/p;"
  printf "$(tput setaf 152)[SNAP]${reset} %s\n" \
	"${green}┌──────────────────────────────────────────────────────────┐${reset}" \
    "  ${blue}Operation:${reset}     Snapshot ${action^^}" \
    "  ${blue}Target VM:${reset}     $target_vm" \
    "  ${blue}Snapshot Name:${reset} $snap_name" \
    "  ${blue}Host Node:${reset}     $target_host" \
    "${green}└──────────────────────────────────────────────────────────┘${reset}"
  success "$stat_success"
}
# ==== VPS Backup ====
fleet_vps_backup() {
  local action="" target_vm="" backup_name=""
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local backup_ledger="/etc/one-click/virtualization/backup_ledger.json"
  . "/etc/one-click/fleet/controller.env"
  action="$1"
  target_vm="$2"
  backup_name="$3"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Backup orchestration must be initiated from the central Controller."
    return 1
  fi
  if [[ -z "$action" || -z "$target_vm" || -z "$backup_name" ]]; then
    error "Usage: one-click fleet backup <create|restore|delete> --target <vm_name> --name <backup_name>"
    return 1
  fi
  if [[ ! -f "$backup_ledger" ]]; then
    echo "[]" > "$backup_ledger"
    chmod 644 "$backup_ledger"
  fi
  local target_host
  target_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null | head -1)
  if [[ -z "$target_host" || "$target_host" == "null" ]]; then
    error "Target VM '$target_vm' not found in active asset ledger."
    return 1
  fi
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  if [[ ! -f "$private_key" ]]; then
    private_key="/home/oneclick/.ssh/id_ed25519"
  fi
  local target_ip
  target_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$target_host" 2>/dev/null | jq -r '.ansible_host // empty')
  if [[ -z "$target_ip" ]]; then
    error "Network Routing Fault: Failed to locate IP route for host [$target_host]."
    return 1
  fi
  local remote_backup_base="/etc/one-click/virtualization/backups"
  local remote_host_dir="${remote_backup_base}/${target_vm}"
  local lvm_archive="${remote_host_dir}/${target_vm}_${backup_name}.lvm.gz"
  local target_lv="/dev/one_click_vg/one_click_repo"
  case "$action" in
    create)
      info "Initiating backup for $target_vm on [$target_host]."
      ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo virsh domfsfreeze $target_vm 2>/dev/null" &>/dev/null || true
      local raw_lv_bytes
      raw_lv_bytes=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo lvs --units b --noheadings -o lv_size $target_lv" 2>/dev/null | tr -d '[:space:]B')
      if [[ -z "$raw_lv_bytes" || ! "$raw_lv_bytes" =~ ^[0-9]+$ ]]; then
        raw_lv_bytes=""
      fi
      info "Compressing backup $backup_name."
      if [[ -n "$raw_lv_bytes" ]]; then
        ssh -t -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo mkdir -p $remote_host_dir && sudo dd if=$target_lv bs=1M status=none | pv -s $raw_lv_bytes | gzip -c | sudo tee $lvm_archive 2> /var/log/one-click/virt/error.log"
      else
        ssh -t -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo mkdir -p $remote_host_dir && sudo dd if=$target_lv bs=1M status=none | pv | gzip -c | sudo tee $lvm_archive 2> /var/log/one-click/virt/error.log"
      fi
      local run_status=$?
      ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo virsh domfsthaw $target_vm 2>/dev/null" &>/dev/null || true
      local remote_file_check
      remote_file_check=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "[ -s \"$lvm_archive\" ] && echo 'OK' || echo 'FAIL'")
      if [[ $run_status -eq 0 && "$remote_file_check" == "OK" ]]; then
        success "The LVM backup has successfully been compressed and stored on [$target_host]."
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq ". += [{ \"name\": \"$backup_name\", \"vm\": \"$target_vm\", \"host\": \"$target_host\", \"file\": \"$lvm_archive\", \"created_at\": \"$timestamp\" }]" "$backup_ledger" > "${backup_ledger}.tmp" && mv "${backup_ledger}.tmp" "$backup_ledger"
      else
        ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo rm -f $lvm_archive" &>/dev/null
        error "Creation of hypervisor-local block archive backup $backup_name failed."
        return 1
      fi
      ;;
    restore)
      warn "Restoring '$backup_name'."
      local remote_file_check
      remote_file_check=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "[ -f \"$lvm_archive\" ] && echo 'OK' || echo 'FAIL'")
      if [[ "$remote_file_check" == "FAIL" ]]; then
        error "Backup file not found on target hypervisor path: $lvm_archive"
        return 1
      fi
      info "Stopping $target_vm for restoration activity."
      ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo virsh destroy $target_vm 2>/dev/null" &>/dev/null || true
      local compressed_bytes
      compressed_bytes=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo stat -c%s $lvm_archive" 2>/dev/null | tr -d '[:space:]')
      info "Decompressing and unpacking block matrices natively on target hypervisor storage disk."
      if [[ -n "$compressed_bytes" && "$compressed_bytes" =~ ^[0-9]+$ ]]; then
        ssh -t -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -c 'cat $lvm_archive | pv -s $compressed_bytes | gzip -dc | dd of=$target_lv bs=1M status=none'"
      else
        ssh -t -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -c 'cat $lvm_archive | pv | gzip -dc | dd of=$target_lv bs=1M status=none'"
      fi
      local restore_status=$?
      if [[ $restore_status -eq 0 ]]; then
        info "Restarting virtual machine."
        ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo virsh start $target_vm" &>/dev/null
        success "The local LVM volume $backup_name has successfully been restored on [$target_host]."
      else
        error "Restoration of local LVM snapshot $backup_name has failed."
        return 1
      fi
      ;;
    delete)
      warn "Deleting backup $backup_name from [$target_host]."
      ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo rm -f $lvm_archive" &>/dev/null
      jq "del(.[] | select(.name == \"$backup_name\" and .vm == \"$target_vm\"))" "$backup_ledger" > "${backup_ledger}.tmp" && mv "${backup_ledger}.tmp" "$backup_ledger"
      success "Backup $backup_name has been deleted."
      ;;
    *)
      error "Invalid action parameter. Must be: create, restore, or delete."
      return 1
      ;;
  esac
  printf "$(tput setaf 152)[BACKUP]${reset} %s\n" \
    "${green}┌──────────────────────────────────────────────────────────┐${reset}" \
    "  ${blue}Operation:${reset}     LVM Backup ${action^^}" \
    "  ${blue}Target VM:${reset}     $target_vm" \
    "  ${blue}Backup Name:${reset}   $backup_name" \
    "  ${blue}Host Node:${reset}     $target_host" \
    "  ${blue}Storage Target:${reset} [$target_host] $remote_host_dir" \
    "${green}└──────────────────────────────────────────────────────────┘${reset}"
}
# ==== One-Click Fleet Snapshot Viewer ====
fleet_snapshot_viewer() {
  local ledger_json="/etc/one-click/virtualization/snapshot_ledger.json"
  if [[ ! -f "$ledger_json" || "$(jq '. | length' "$ledger_json" 2>/dev/null)" -eq 0 ]]; then
    warn "Snapshot Ledger is empty. No cluster recovery records registered."
    return 0
  fi
  printf "${blue}┌──────────────────────┬──────────────────────┬──────────────────────┬──────────────────────┐${reset}\n"
  printf "${blue}│ %-30s │ %-30s │ %-30s │ %-30s │${reset}\n" "${yellow}SNAPSHOT NAME${blue}" "${yellow}TARGET VM${blue}" "${yellow}HYPERVISOR HOST${blue}" "${yellow}CREATION DATE (UTC)${blue}"
  printf "${blue}├──────────────────────┼──────────────────────┼──────────────────────┼──────────────────────┤${reset}\n"
  while IFS=$'\t' read -r name vm host created_at; do
    printf "${blue}│ %-20s │ %-20s │ %-20s │ %-20s │${reset}\n" "$name" "$vm" "$host" "$created_at"
  done < <(jq -r '.[] | "\(.name)\t\(.vm)\t\(.host)\t\(.created_at)"' "$ledger_json" 2>/dev/null)
  printf "${blue}└──────────────────────┴──────────────────────┴──────────────────────┴──────────────────────┘${reset}\n"
}
# ==== One-Click Fleet Power Management Subsystem ====
fleet_vps_power_control() {
  build_vars
  local action="$1"
  local target_vm="$2"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6:-}}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: Power control actions can only be initialized from the Controller."
    return 1
  fi
  if [[ -z "$target_vm" ]]; then
    error "Usage: one-click fleet $action <virtual_machine_name>"
    return 1
  fi
  if [[ ! -f "$inventory_json" ]]; then
    error "Inventory database missing at $inventory_json. Cannot resolve cluster bindings."
    return 1
  fi
  local target_host
  target_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null)
  if [[ -z "$target_host" || "$target_host" == "null" ]]; then
    error "Target VM '$target_vm' is not a VPS managed by a fleet hypervisor."
    return 1
  fi
  local virsh_cmd
  if [[ "$action" == "start" ]]; then
    virsh_cmd="virsh start $target_vm"
	local state="${green}started${reset}"
	local la=has
  elif [[ "$action" == "stop" ]]; then
    virsh_cmd="virsh shutdown $target_vm"
	local state="${red}stopped${reset}"
	local la=is
  else
    error "Internal Error: Invalid action wrapper parameters passed."
    return 1
  fi
  local ansible_output
  if ! ansible_output=$(ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$target_host" \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a "$virsh_cmd" 2>&1); then
      printf "$(tput setaf 48)[POWER]${reset} %s\n" \
	    "$target_vm $la already $state"
      return
  fi
  printf "$(tput setaf 48)[POWER]${reset} %s\n" \
    "Power directive '$action' successfully completed for $target_vm."
}
# ==== Fleet HAProxy Edge ====
fleet_proxy_provision() {
  target_vm="$1"
  website="${2:-}"
  proto="${3:-}"
  src_port="${4:-}"
  dest_port="${5:-}"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local identity_key_dir="/etc/one-click/fleet/keys"
  local identity_key_file="${identity_key_dir}/id_ed25519"
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: Proxy routing can only be initiated from the Controller."
    return 1
  fi
  if [[ -z "$target_vm" ]]; then
    error "Usage: one-click fleet proxy --target <vm> [--website <domain> --proto <http/https>] [--source <backend_port> --port <frontend_port>]"
    return 1
  fi
  if [[ ! -f "$inventory_json" ]]; then
    error "Inventory matrix not found. Cannot determine network pipeline hooks."
    return 1
  fi
  local target_host vps_internal_ip
  target_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null | head -1)
  host_ip=$(jq -r ".[] | select(.name == \"$target_vm\") | .host_ip" "$inventory_json" 2>/dev/null | head -1)
  vps_internal_ip=$(jq -r ".[] | select(.name == \"$target_vm\") | .nat_ip" "$inventory_json" 2>/dev/null | tail -1)
  if [[ "$vps_internal_ip" == "null" || -z "$vps_internal_ip" ]]; then
    mac=$(awk 'NR==3{print $5}' <(virsh domiflist "$target_vm"))
    vps_internal_ip=$(virsh net-dhcp-leases oneclick-nat | awk -v mac=$mac '$3 == mac && $4 == "ipv4" {sub("/.*","",$5);print $5}')
    if [[ "$target_host" == "null" || -z "$target_host" ]]; then
      target_host="$CONTROLLER_NAME"
    fi
  fi
  cluster_ip=$(jq -r ".[] | select(.name == \"$target_vm\") | .cluster_private_ip" "$inventory_json" 2>/dev/null | tail -1)
  if [[ -z "$target_host" || "$target_host" == "null" || -z "$vps_internal_ip" || "$vps_internal_ip" == "null" ]]; then
    if [[ -z "$vps_internal_ip" ]]; then
      error "Target VM '$target_vm' does not exist in active registry mapping."
      return 1
    fi
  fi
  local haproxy_payload=""
  if [[ -n "$website" ]]; then
    # ==== Shared web ports ====
    info "Compiling HTTP/HTTPS reverse proxy block for $website -> $target_vm ($vps_internal_ip)."
    local backend_name="be_${target_vm}_${website//./_}"
    haproxy_payload="
      mkdir -p /etc/haproxy/errors
      if ! grep -q 'frontend http_front' /etc/haproxy/haproxy.cfg; then
        cat >> /etc/haproxy/haproxy.cfg <<EOF

frontend http_front
    bind *:80
    mode http
EOF
      fi
      if ! grep -q 'backend $backend_name' /etc/haproxy/haproxy.cfg; then
        sed -i '/frontend http_front/a \    use_backend $backend_name if { hdr(host) -i $website }' /etc/haproxy/haproxy.cfg
        cat >> /etc/haproxy/haproxy.cfg <<EOF

backend $backend_name
    mode http
    balance roundrobin
    server $target_vm ${vps_internal_ip}:${src_port:-80} check
EOF
      fi
    "
  elif [[ -n "$src_port" && -n "$dest_port" ]]; then
    info "Compiling TCP proxy map for custom port: $target_host:$dest_port -> $target_vm:$src_port."
    local stream_name="tcp_stream_${target_vm}_${dest_port}"
    haproxy_payload="
listen $stream_name
    bind *:${dest_port}
    mode tcp
    balance roundrobin
    server $target_vm ${vps_internal_ip}:${src_port} check
    "
  else
    error "Invalid parameters. Specify either a --website config string or a --source/--port mapping."
    return 1
  fi
  info "Connecting to Hypervisor Node [$target_host] to apply proxy."
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  if [[ ! -f "$private_key" ]]; then
    private_key="/home/oneclick/.ssh/id_ed25519"
  fi
  local target_ip
  target_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "${target_host:-$CONTROLLER_NAME}" 2>/dev/null | jq -r '.ansible_host // empty')
  if [[ -z "$target_ip" ]]; then
    error "Network Routing Fault: Could not map host '$target_host' to an active IP matrix."
    return 1
  fi
  info "Orchestrating network proxy configurations on [$target_host] ($target_ip)."
  local local_tmp_payload="/tmp/haproxy_payload_${target_vm}.tmp"
  echo "$haproxy_payload" > "$local_tmp_payload"
  cat "$local_tmp_payload" | ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" \
    "TARGET_PORT='$dest_port' WEBSITE_FLAG='$website' sudo -E bash -c '
    cat > /tmp/haproxy_append.cfg
    if ! command -v haproxy &>/dev/null; then
      if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update && apt-get install -y haproxy
      elif command -v dnf &>/dev/null; then
        dnf install -y haproxy
      elif command -v yum &>/dev/null; then
        yum install -y haproxy
      else
        echo \"CRITICAL: Operational package manager not found on target host subsystem.\" >&2
        exit 1
      fi
      systemctl enable haproxy
    fi
    if [ -f /tmp/haproxy_append.cfg ] && [ -s /tmp/haproxy_append.cfg ]; then
      cat /tmp/haproxy_append.cfg >> /etc/haproxy/haproxy.cfg
      rm -f /tmp/haproxy_append.cfg
    else
      echo \"CRITICAL: Proxy configuration stream data arrived empty on target node.\" >&2
      exit 1
    fi
    apply_firewall_rule() {
      local port=\"\$1\"
	  source /etc/os-release
      if ! iptables -I ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
        echo \">>> \$PRETTY_NAME Detected: Executing native nftables check-and-insert sequence.\"
        nft add table ip filter 2>/dev/null || true
        nft add chain ip filter ONE-CLICK-FLEET 2>/dev/null || true
        if ! nft list chain ip filter ONE-CLICK-FLEET | grep -q \"tcp dport \$port accept\"; then
          nft insert rule ip filter ONE-CLICK-FLEET tcp dport \"\$port\" accept 2>/dev/null
        fi
      else
        echo \">>> Standard iptables environment active. Executing legacy sequence.\"
        iptables -N ONE-CLICK-FLEET 2>/dev/null || true
        iptables -C ONE-CLICK-FLEET -p tcp --dport \"\$port\" -j ACCEPT 2>/dev/null || \
        iptables -I ONE-CLICK-FLEET 1 -p tcp --dport \"\$port\" -j ACCEPT 2>/dev/null
      fi
      if command -v firewall-cmd &>/dev/null; then
        if ! firewall-cmd --zone=public --query-port=\"\${port}\"/tcp --permanent &>/dev/null; then
          firewall-cmd --zone=public --add-port=\"\${port}\"/tcp --permanent &>/dev/null && firewall-cmd --reload &>/dev/null || true
        fi
      fi
    }
    if [ -n \"\$TARGET_PORT\" ]; then
      apply_firewall_rule \"\$TARGET_PORT\"
    elif [ -z \"\$WEBSITE_FLAG\" ]; then
      for p in 80 443; do
        apply_firewall_rule \"\$p\"
      done
    fi
    if haproxy -c -f /etc/haproxy/haproxy.cfg &>/dev/null; then
      systemctl reload haproxy || systemctl restart haproxy
    else
      echo \"CRITICAL: HAProxy configuration syntax validation failure.\" >&2
      exit 1
    fi
  '"
  local run_status=$?
  rm -f "$local_tmp_payload"
  if [[ $run_status -ne 0 ]]; then
    error "Failed to successfully orchestrate proxy services on [$target_host]."
    return 1
  fi
  if [[ "$src_port" -ne 3389 ]]; then
    printf "$(tput setaf 173)[KEY] $(tput setaf 208)%s\n" \
      "┌─── SECURITY GATEWAY: TARGET TARGET ACCESS VERIFICATION ──────────┐" \
      "│$(tput sgr0) To bridge access, please create a key-pair on your endpoint using$(tput setaf 208)│" \
      "│$(tput setaf 119) ssh-keygen -t ed25519 -C "${target_vm}-endpoint"                     $(tput setaf 208)│" \
      "│$(tput sgr0) Extract and paste the public key below with:                     $(tput setaf 208)│" \
      "│$(tput setaf 119) cat ~/.ssh/id_ed25519.pub                                        $(tput setaf 208)│" \
      "└───[$(tput setaf 111) PUBLIC KEY BLOCK $(tput setaf 208)]───────────────────────────────────────────┘"
    read -rp "$(tput setaf 152)[WAIT]${reset} Paste your public key here: " public_key
    if [[ -z "$public_key" ]]; then
      error "Provisioning Aborted: Cryptographic authority entry appears to be empty."
      return 1
    else
      info "Injecting public key into $target_vm"
      if [[ -n "$cluster_ip" ]]; then
        ssh_target="oneclick@$cluster_ip"
      fi
      for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
        [[ -e "$key" ]] || continue
        ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 "$ssh_target" \
          "echo $public_key >> ~/.ssh/authorized_keys" 2> /dev/null || true
        if [[ $? -eq 0 ]]; then
          break
        fi
      done
    fi
    success "Public Key Added to $target_vm."
    read -rp "Press Enter after you have added the key: "
    success "Proxy initialization completed on [$target_host]."
  fi
  if [[ $? -eq 0 ]]; then
    printf "$(tput setaf 103)[PROXY]${reset}%s\n" \
	  "${green}┌──────────────────────────────────────────────────────────┐${reset}" \
      "${green}│       ONE-CLICK FLEET PROXY CONFIGURATION LIVE           │${reset}" \
      "${green}└──────────────────────────────────────────────────────────┘${reset}" \
      "  ${blue}Target VM:${reset}          $target_vm" \
      "  ${blue}Hypervisor Node:${reset}    $target_host" \
      "  ${blue}Tunnel Mesh IP:${reset}     $vps_internal_ip" \
	  "  ${blue}Internal NAT IP:${reset}    $cluster_ip" \
      "  $(tput setaf 11)──────────────────────────────────────────────────────────${reset}"
    if [[ -n "$website" ]]; then
      printf "$(tput setaf 103)[PROXY]${reset}%s\n" \
	    "  ${orange}Proxy Type:${reset}             HTTP/HTTPS Reverse Proxy" \
        "  ${orange}HTTP Public Domain:${reset}     ${cyan}http://$website${reset}  -> Port 80" \
        "  ${orange}HTTPS Public Domain:${reset}    ${cyan}https://$website${reset} -> Port 443" \
        "  ${orange}Forward Path:${reset}           $vps_internal_ip:${src_port:-80}"
    else
      printf "$(tput setaf 103)[PROXY]${reset}%s\n" \
	    "  ${orange}Proxy Type:${reset}      Raw TCP Stream Layer 4" \
        "  ${orange}Public Entry:${reset}    ${cyan}$host_ip:$dest_port${reset}" \
        "  ${orange}Forward Path:${reset}    $vps_internal_ip -p $src_port"
    fi
	echo -e "$(tput setaf 103)[PROXY]${reset}  $(tput setaf 11)──────────────────────────────────────────────────────────${reset}"
	echo -e "$(tput setaf 103)[PROXY]${reset}  ${magenta}Access cmd:${reset}     ${cyan} ssh oneclick@$host_ip:$dest_port${reset}"
    echo -e "$(tput setaf 103)[PROXY]${reset}  ${green}──────────────────────────────────────────────────────────${reset}"
    success "Edge proxy configurations successfully synchronized on $target_host for $target_vm."
  else
    error "HAProxy update validation failed on remote hypervisor node. Modifications aborted."
    return 1
  fi
}
fleet_validate_hypervisor_resources() {
  local target_host="$1"
  local req_ram_mb="$2"
  local req_cpus="$3"
  local req_disk_gb="$4"
  local vg_name="${5:-one_click_vg}"
  local thin_pool="${6:-one_click_pool}"
  local storage_script="/etc/one-click/virtualization/initialize_storage.sh"
  local dest_dir="/etc/one-click/virtualization/images"
  vg_name="one_click_vg"
  info "Vaidating resource availability on hypervisor [$target_host]."
  local ram_needed=${req_ram_mb//[!0-9]/}
  [[ "$req_ram_mb" =~ [Gg] ]] && ram_needed=$((ram_needed * 1024))
  local disk_needed=${req_disk_gb//[!0-9]/}
  if [[ -z "$ram_needed" || -z "$req_cpus" || -z "$disk_needed" ]]; then
    error "Invalid build parameters supplied: RAM=${req_ram_mb}, CPU=${req_cpus}, DISK=${req_disk_gb}"
    return 1
  fi
  local actual_ram_required=$(( (ram_needed * 300) / 1024 ))
  local host_safety_buffer=256
  local check_payload
  check_payload=$(cat << EOF
    FREE_RAM_MB=\$(free -m | awk '/^Mem:/ {print \$7}')
    POOL_LINE=\$(lvs --noheadings --units g --nosuffix -o vg_name,lv_name,lv_size,data_percent "${vg_name}/${thin_pool}" 2>/dev/null | tr -s ' ' | sed 's/^ //')
    if [[ -z "\$POOL_LINE" ]]; then
      echo "\$(tput setaf 1)[ERROR]\$(tput sgr 0) LVM Thin Pool ${vg_name}/${thin_pool} not found on host."
      exit 10
    fi
    POOL_SIZE_GB=\$(echo "\$POOL_LINE" | cut -d' ' -f3 | cut -d. -f1)
    POOL_USED_PCT=\$(echo "\$POOL_LINE" | cut -d' ' -f4 | cut -d. -f1)
    VG_FREE_GB=\$(vgs --noheadings --units g --nosuffix -o vg_free "${vg_name}" 2>/dev/null | tr -d ' ' | cut -d. -f1)
    echo "{\\"free_ram_mb\\":\$FREE_RAM_MB,\\"pool_size_gb\\":\$POOL_SIZE_GB,\\"pool_used_pct\\":\$POOL_USED_PCT,\\"vg_free_gb\\":\$VG_FREE_GB}"
EOF
  )
  local host_metrics
  local local_hostname
  local_hostname=$(hostname -s)
  local ssh_key=""
  if [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  elif [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  fi
  local ssh_key_arg=""
  if [ -n "$ssh_key" ]; then
    ssh_key_arg="-i ${ssh_key}"
  fi
  local target_ip="$target_host"
  if [ -f "/etc/one-click/fleet/inventory.yml" ]; then
    local inv_ip
    if [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
      inv_ip="$CONTROLLER_IP"
    else
      inv_ip="$(grep -A 5 "$target_host" /etc/one-click/fleet/inventory.yml | grep ansible_host | head -n 1 | awk '{print $2}')"
    fi
    if [ -n "$inv_ip" ]; then
      target_ip="$inv_ip"
    fi
  fi
  if [[ "$target_host" == "$local_hostname" || "$target_host" == "127.0.0.1" || "$target_host" == "localhost" ]]; then
    if ! vgdisplay "$vg_name" &>/dev/null; then
      write_peer_vps_vg_allocation
      bash "$storage_script" "$req_disk_gb" "$vps_name" "$dest_dir" "$VG_ALLOC" "$ALLOC_THRESHOLD"
    fi
    host_metrics=$(eval "$check_payload" 2>/dev/null)
  else
    write_peer_vps_vg_allocation
    if [[ "$target_ip" =~ : ]]; then
      target_ip="[$target_ip]"
    fi
    scp -o StrictHostKeyChecking=no $ssh_key_arg "$storage_script" "oneclick@${target_ip}:/home/oneclick/vg.sh" &>/dev/null
    ssh -o StrictHostKeyChecking=no $ssh_key_arg "oneclick@${target_ip//[][]}" \
      "if ! sudo vgs 2> /dev/null | grep -q one_click_vg; then
        sudo bash vg.sh $req_disk_gb $vps_name $dest_dir $VG_ALLOC $ALLOC_THRESHOLD
      fi"
    local ssh_key=""
    if [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
      ssh_key="/home/oneclick/.ssh/id_ed25519"
    elif [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
      ssh_key="/etc/one-click/fleet/keys/id_ed25519"
    fi
    local target_ip="$target_host"
    if [ -f "/etc/one-click/fleet/inventory.yml" ]; then
      local inv_ip
      inv_ip="$(grep -A 5 "$target_host" /etc/one-click/fleet/inventory.yml | grep ansible_host | head -n 1 | awk '{print $2}')"
      if [ -n "$inv_ip" ]; then
        target_ip="$inv_ip"
      fi
    fi
    host_metrics=$(ssh -o StrictHostKeyChecking=no ${ssh_key:+-i "$ssh_key"} "oneclick@${target_ip//[][]}" "sudo bash -s" << 'EOF'
FREE_RAM_MB=$(free -m | grep -i Mem: | tr -s ' ' | cut -d' ' -f7)
FREE_RAM_MB=${FREE_RAM_MB:-0}

POOL_LINE=$(sudo lvs --noheadings --units g --nosuffix -o vg_name,lv_name,lv_size,data_percent "one_click_vg/one_click_pool" 2>/dev/null | tr -s ' ' | sed 's/^ //')
if [ -z "$POOL_LINE" ]; then
  POOL_SIZE_GB=0
  POOL_USED_PCT=0
else
  POOL_SIZE_GB=$(echo "$POOL_LINE" | cut -d' ' -f3 | cut -d. -f1)
  POOL_USED_PCT=$(echo "$POOL_LINE" | cut -d' ' -f4 | cut -d. -f1)
fi

POOL_SIZE_GB=${POOL_SIZE_GB:-0}
POOL_USED_PCT=${POOL_USED_PCT:-0}

VG_FREE_GB=$(sudo vgs --noheadings --units g --nosuffix -o vg_free "one_click_vg" 2>/dev/null | tr -d ' ' | cut -d. -f1)
VG_FREE_GB=${VG_FREE_GB:-0}

echo "{\"free_ram_mb\":${FREE_RAM_MB},\"pool_size_gb\":${POOL_SIZE_GB},\"pool_used_pct\":${POOL_USED_PCT},\"vg_free_gb\":${VG_FREE_GB}}"
EOF
)
  fi
  if [[ -z "$host_metrics" ]]; then
    error "Failed to retrieve resource metrics from hypervisor [$target_host]."
    return 1
  fi
  local free_ram_mb pool_size_gb pool_used_pct vg_free_gb
  free_ram_mb=$(echo "$host_metrics" | jq -r '.free_ram_mb')
  pool_size_gb=$(echo "$host_metrics" | jq -r '.pool_size_gb')
  pool_used_pct=$(echo "$host_metrics" | jq -r '.pool_used_pct')
  vg_free_gb=$(echo "$host_metrics" | jq -r '.vg_free_gb')
  info "Metrics [$target_host] -> Host Free RAM: ${free_ram_mb}MB | Ballooned Req: ${actual_ram_required}MB | Thin Pool Used: ${pool_used_pct}% | VG Free: ${vg_free_gb}GB"
  local failure=0
  local min_ram_needed=$((actual_ram_required + host_safety_buffer))
  if (( free_ram_mb < min_ram_needed )); then
    error "Physical RAM critical on [$target_host]: Required Ballooned=${actual_ram_required}MB (+${host_safety_buffer}MB buffer), Available=${free_ram_mb}MB"
    failure=1
  fi
  if (( pool_used_pct >= 95 )); then
    error "CRITICAL: Thin Pool '${thin_pool}' on [$target_host] is full (${pool_used_pct}% utilized)."
    failure=1
  fi
  if (( pool_used_pct > 85 )) && (( vg_free_gb < disk_needed )); then
    error "CRITICAL: Storage overcommitted on [$target_host]. Thin pool at ${pool_used_pct}% and VG free space (${vg_free_gb}GB) cannot allocate ${disk_needed}GB."
    failure=1
  fi
  if [[ "$failure" -eq 1 ]]; then
    error "Validation ${red}failed${reset} for [$target_host]. Aborting deployment."
    return 1
  fi
  success "Validation ${green}passed${reset} for [$target_host] (Provisioning ${req_ram_mb} RAM / ${req_disk_gb} Disk)."
  return 0
}
cleanup_poisoned_session() {
  local exit_code=$?
  [[ "$exit_code" -eq 0 ]] && exit 0
  local clean_vps_name="${vps_name:-}"
  clean_vps_name="${clean_vps_name//_win_path/}"
  if [[ -z "$clean_vps_name" ]]; then
    echo "${lime}[CLEANUP]${red} Cleanup triggered, but VPS name is unassigned. Aborting state purge."
    exit "$exit_code"
  fi
  echo "${lime}[CLEANUP]${yellow} Deployment interrupted or failed. Purging corrupted state for '${clean_vps_name}'."
  local inventory_yaml="/etc/one-click/fleet/inventory.yml"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local available_ips_file="/etc/one-click/virtualization/available_ips.txt"
  local port_state_file="/etc/one-click/virtualization/allocated_ports.db"
  local port_pool_file="/etc/one-click/virtualization/ports_pool.txt"
  if [[ -n "${target_host:-}" ]]; then
    echo "${lime}[CLEANUP]${green} Purging thin LVM, Libvirt VM, and storage on hypervisor [$target_host]."
    local purge_payload
    purge_payload=$(cat << 'EOF'
clean_vps_name="%NAME%"
if virsh destroy "${clean_vps_name}" &> /dev/null; then
  echo "${lime}[CLEANUP]${green} Domain '$clean_vps_name' destroyed."
fi
if virsh destroy "${clean_vps_name}_win_path" &> /dev/null; then
  echo "${lime}[CLEANUP]${green} Domain '$clean_vps_name' destroyed."
fi
sleep 5
if virsh undefine "${clean_vps_name}" --remove-all-storage &> /dev/null; then
  echo "${lime}[CLEANUP]${green} Domain '$clean_vps_name' has been undefined."
fi
if virsh undefine "${clean_vps_name}_win_path" --remove-all-storage &> /dev/null; then
  echo "${lime}[CLEANUP]${green} Domain '$clean_vps_name' has been undefined."
fi
rm -f /var/lib/libvirt/images/${clean_vps_name}_cloudinit.iso
rm -f /var/lib/libvirt/images/${clean_vps_name}.qcow2
rm -rf /tmp/build_${clean_vps_name}
VG_NAME="one_click_vg"
LV_NAME="lv_${clean_vps_name}"
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"
if lvdisplay "$LV_PATH" &> /dev/null; then
  lvchange -an "$LV_PATH" &> /dev/null || true
  dmsetup remove -f "${VG_NAME}-${LV_NAME}" &> /dev/null || true
  printf "${lime}[CLEANUP]${green} "
  lvremove -f -y "$LV_PATH" &> /dev/null || true
fi
EOF
    )
    purge_payload="${purge_payload//%NAME%/$clean_vps_name}"
    local local_hostname
    local_hostname=$(hostname -s 2>/dev/null || echo "localhost")
    if [[ "$target_host" == "$local_hostname" || "$target_host" == "127.0.0.1" || "$target_host" == "localhost" ]]; then
      eval "$purge_payload"
    else
      ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=5 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "$purge_payload" &>/dev/null || true
    fi
  fi
  if [[ -f "$inventory_json" ]]; then
    local tmp_json
    tmp_json=$(mktemp "/etc/one-click/virtualization/inventory.XXXXXX.json" 2>/dev/null || echo "${inventory_json}.tmp")
    if jq --arg name "$clean_vps_name" 'map(select(.name != $name and .name != ($name + "_win_path")))' "$inventory_json" > "$tmp_json" 2>/dev/null; then
      mv -f "$tmp_json" "$inventory_json"
      chmod 644 "$inventory_json"
      echo "${lime}[CLEANUP]${green} Removed ${clean_vps_name} from JSON inventory ledger."
    else
      rm -f "$tmp_json"
      python3 -c "
import json, os
p = '$inventory_json'
n = '$clean_vps_name'
if os.path.exists(p):
    try:
        with open(p, 'r') as f: data = json.load(f)
        filtered = [x for x in data if x.get('name') not in (n, f'{n}_win_path')]
        with open(p + '.tmp', 'w') as f: json.dump(filtered, f, indent=2)
        os.replace(p + '.tmp', p)
    except Exception: pass
" 2>/dev/null || true
    fi
  fi
  if [[ -f "$inventory_yaml" ]]; then
    sed -i "/^[[:space:]]*${clean_vps_name}:/,+2d" "$inventory_yaml" 2>/dev/null || true
    sed -i "/^[[:space:]]*${clean_vps_name}_win_path:/,+2d" "$inventory_yaml" 2>/dev/null || true
  fi
  if [[ -f "$port_state_file" ]]; then
    local assigned_port
    assigned_port=$(grep -E "^(${clean_vps_name}|${clean_vps_name}_win_path):" "$port_state_file" | cut -d: -f2 | head -n 1 || true)
    if [[ -n "$assigned_port" ]]; then
      sed -i -E "/^(${clean_vps_name}|${clean_vps_name}_win_path):/d" "$port_state_file" 2>/dev/null || true
      if [[ -f "$port_pool_file" ]] && ! grep -q "^${assigned_port}$" "$port_pool_file"; then
        echo "$assigned_port" >> "$port_pool_file"
        echo "${lime}[CLEANUP]${green} Released proxy port $assigned_port back to $port_pool_file"
      fi
    fi
  fi
  if [[ -f /etc/wireguard/one-click.conf ]] && grep -q "# ==== Peer Node: ${clean_vps_name} ====" /etc/wireguard/one-click.conf; then
    sed -i "/# ==== Peer Node: ${clean_vps_name} ====/,+7d" /etc/wireguard/one-click.conf 2>/dev/null || true
    wg syncconf one-click <(wg-quick strip one-click 2>/dev/null) &>/dev/null || true
  fi
  rm -rf "/etc/one-click/virtualization/deployments/${clean_vps_name}" 2>/dev/null || true
  rm -rf "/etc/one-click/virtualization/staging/${clean_vps_name}" 2>/dev/null || true
  if [[ -f "/etc/one-click/fleet/state/${clean_vps_name}.conf" ]]; then
    fleet_remove "$clean_vps_name" &>/dev/null || true
  fi
  local ip_to_restore="${vps_private_ip:-${primary_ip:-}}"
  if [[ -n "$ip_to_restore" && -f "$available_ips_file" ]]; then
    if ! grep -q "^${ip_to_restore}$" "$available_ips_file"; then
      echo "$ip_to_restore" >> "$available_ips_file"
      echo "${lime}[CLEANUP]${green} Recovered IP $ip_to_restore back into $available_ips_file"
    fi
  fi
  echo "${lime}[CLEANUP]${green} Sanitization complete. Hypervisor and fleet footprints cleaned.${reset}"
  exit 0
}
fleet_vps_provision() {
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller ($CONTROLLER_IP)"
  fi
  local vps_name="$1"
  local target_host="$2"
  local network_mode="${3:-nat}"
  local base_image_name="$4"
  local disk_size="$5"
  local raw_password="$6"
  local vps_ram="${7:-1024}"
  vps_ram=$(normalize_memory "$vps_ram")
  local vps_cpu="${8:-2}"
  local public_ip="${9:-}"
  local virtual_mac="${10:-}"
  install_dep "ipcalc" "type ipcalc" "ipcalc" "$pkg_mgr" true
  local target_wg_port
  local is_windows=0
  if [[ "$base_image_name" =~ windows|win ]]; then
    is_windows=1
  fi
  local storage_script="/etc/one-click/virtualization/initialize_storage.sh"
  local inventory_file="/etc/one-click/virtualization/inventory.json"
  port_pool_file="/etc/one-click/virtualization/ports_pool.txt"
  port_state_file="/etc/one-click/virtualization/allocated_ports.db"
  local name_exists
  name_exists=$(jq --arg name "$vps_name" 'any(.[] ; .name == $name)' "$inventory_file" 2>/dev/null || true)
  fleet_validate_hypervisor_resources "$target_host" "$vps_ram" "$vps_cpu" "$disk_size"
  warn "VPS Deployment initializing."
  local name_exists
  trap cleanup_poisoned_session EXIT INT TERM ERR
  if ! command -v wg > /dev/null; then
    $pkg_mgr install -y wireguard-tools
  fi
  rm -f "$storage_script"
  . "/etc/one-click/fleet/controller.env"
  if [[ -f /etc/one-click/dns/modules/wireguard_pool.env ]]; then
    . "/etc/one-click/dns/modules/wireguard_pool.env"
  fi
  mkdir -p "$(dirname "$port_pool_file")"
  if [ ! -f "$port_pool_file" ]; then
    info "Initializing port pool file."
    seq 51821 80000 > "$port_pool_file"
    touch "$port_state_file"
  fi
  local wg_peer_port=""
  while IFS= read -r wg_port; do
    sed -i "1d" "$port_pool_file"
    if ss -tuln | grep -q ":${wg_port}\b"; then
      continue
    fi
    if iptables -t nat -S | grep -q "dport ${wg_port}\b"; then
      continue
    fi
    if grep -q "${wg_port}" "$port_state_file" 2>/dev/null; then
      continue
    fi
    wg_peer_port="$wg_port"
    break
  done < "$port_pool_file"
  if [ -z "$wg_peer_port" ]; then
    error "No available wireguard ports found on $vps_name." >&2
    return 1
  fi
  echo "${vps_name}:${wg_peer_port}" >> "$port_state_file"
  if [[ ! -f /etc/one-click/virtualization/.initialized ]]; then
    fleet_vps_init
  fi
  if [[ -z "$vps_name" || -z "$target_host" || -z "$base_image_name" || -z "$disk_size" ]]; then
    error "Usage: fleet_vps_provision <vps_name> <target_host> <nat|public> <base_image> <disk_size>"
    return 1
  fi
  local master_image_source="/etc/one-click/virtualization/images/${base_image_name}"
  if [[ ! -f "$master_image_source" ]]; then
    error "Base image not found: $base_image_name not found in master storage."
    return 1
  fi
  local vps_private_ip
  vps_private_ip=$(head -n 1 "$FLEET_AVAILABLE_IPS_FILE" | tr -d ' ')
  if [[ -z "$vps_private_ip" ]]; then
    error "IP Pool Exhausted! No available IPs remaining for fleet compute allocation."
    return 1
  fi
  local pass_cloud_init=""
  if [[ -n "$raw_password" ]]; then
    local encrypted_hash
    encrypted_hash=$(openssl passwd -6 "$raw_password")
    pass_cloud_init="passwd: '${encrypted_hash}'"
  else
    pass_cloud_init="lock_passwd: true"
    raw_password="[Password Disabled - Locked to SSH Key Only]"
  fi
  local vps_private_key vps_public_key vps_preshared_key master_pub_key
  vps_private_key=$(wg genkey)
  vps_public_key=$(echo "$vps_private_key" | wg pubkey)
  vps_preshared_key=$(wg genpsk)
  if [[ $(echo "$vps_private_key" | wg pubkey) != "$vps_public_key" ]]; then
    error "Key generation mismatch detected!"
    return 1
  fi
  if [[ "$network_mode" != "public" ]]; then
    info "Allocating Private Node IP: $vps_private_ip to $vps_name"
    local host_public_ip=""
    if [[ "$target_host" == "$(hostname -s)" || "$target_host" == "127.0.0.1" ]]; then
      local mode=hypervisor
      host_public_ip="127.0.0.1"
    else
      local mode=vps
      host_public_ip=$(ansible-inventory -i /etc/one-click/fleet/inventory.yml --list | jq -r "._meta.hostvars.\"${target_host}\".ansible_host // empty")
      if [[ -z "$host_public_ip" || "$host_public_ip" == "null" ]]; then
        error "Hypervisor target '$target_host' not found inside inventory registry."
        return 1
      fi
    fi
    info "Configuring Wireguard interface"
    if [[ ! -f /etc/wireguard/one-click.conf ]]; then
      touch /etc/wireguard/one-click.conf
    fi
    if ip link show dev one-click &>/dev/null; then
      info "'one-click' interface is operational."
      wg syncconf one-click <(sudo wg-quick strip one-click 2>/dev/null) &>/dev/null || true
    else
      info "Starting one-click interface."
      if ! wg-quick up one-click 2>/tmp/wg_start_error.log; then
        local error_msg
        error_msg=$(cat /tmp/wg_start_error.log 2>/dev/null)
        warn "wg-quick up encountered a hook error: ${error_msg:-Unknown fault}"
        info "Executing emergency link override to save the deployment."
        sudo ip link add dev one-click type wireguard &>/dev/null || true
        sudo wg setconf one-click /etc/wireguard/one-click.conf &>/dev/null || true
        sudo ip link set dev one-click mtu 1412 &>/dev/null || true
        sudo ip addr add 10.10.0.1/16 dev one-click &>/dev/null || true
        sudo ip link set dev one-click up &>/dev/null || true
      else
        success "Master WireGuard interface successfully brought online via wg-quick."
      fi
      rm -f /tmp/wg_start_error.log
    fi
    echo -e "\n# Peer IP Assignment: ${vps_name}" >> /etc/wireguard/one-click.conf
    cat >> /etc/wireguard/one-click.conf <<EOF

# ==== Peer Node: ${vps_name} ====
[Peer]
PublicKey = ${vps_public_key}
PresharedKey = ${vps_preshared_key}
AllowedIPs = ${vps_private_ip}/32
PersistentKeepalive = 25
EOF
    export WG_HIDE_KEYS=never
    if [[ "$network_mode" == "public" ]]; then
      echo "$vps_preshared_key" | wg set one-click peer "$vps_public_key" preshared-key /dev/stdin allowed-ips "${vps_private_ip}/32" endpoint "${public_ip}:${target_wg_port}"
    else
      if [[ "$target_host" == "$(hostname -s)" || "$target_host" == "127.0.0.1" ]]; then
        echo "$vps_preshared_key" | wg set one-click peer "$vps_public_key" preshared-key /dev/stdin allowed-ips "${vps_private_ip}/32"
      else
        echo "$vps_preshared_key" | wg set one-click peer "$vps_public_key" preshared-key /dev/stdin allowed-ips "${vps_private_ip}/32" endpoint "${host_public_ip}:${wg_peer_port}"
      fi
    fi
  else
    iface=$(ip link show | awk '$2 ~ /^e/ {sub(":","",$2);print $2}' | head -1)
	gateway=$(python3 -c "import ipaddress; net = ipaddress.ip_network('$public_ip', strict=False); print(list(net.hosts())[0])" 2>/dev/null)
    info "Allocating Public Node IP: $public_ip to $vps_name"
	if [[ "$target_host" == "$(hostname -s)" || "$target_host" == "127.0.0.1" ]]; then
      local mode=hypervisor
      host_public_ip="127.0.0.1"
    else
      local mode=vps
      host_public_ip=$(ansible-inventory -i /etc/one-click/fleet/inventory.yml --list | jq -r "._meta.hostvars.\"${target_host}\".ansible_host // empty")
      if [[ -z "$host_public_ip" || "$host_public_ip" == "null" ]]; then
        error "Hypervisor target '$target_host' not found inside inventory registry."
        return 1
      fi
    fi
    if ip link show dev br0 &>/dev/null; then
      info "'br0' bridge interface is operational."
    else
      info "Bringing up bridge br0."
      if ! ip link show dev "$iface" master br0 &>/dev/null; then
        sudo ip link set dev "$iface" master br0 || {
          error "Failed to attach $iface to br0"
          return 1
        }
      fi
      sudo ip addr flush dev "$iface" &>/dev/null || true
      sudo ip addr replace "$public_ip" dev br0 || {
        error "Failed to assign public IP $public_ip to br0"
        return 1
      }
      sudo ip link set dev "$iface" up
      sudo ip link set dev br0 up
      if [ -n "$gateway" ]; then
        sudo ip route replace default via "$gateway" dev br0
      fi
      success "Public bridge interface (br0) successfully configured and online."
    fi
  fi
  info "Creating directory paths"
  local stage_dir="/etc/one-click/virtualization/staging/${vps_name}"
  mkdir -p "$stage_dir"
  local archive_dir="/etc/one-click/virtualization/deployments/${vps_name}"
  mkdir -p "$archive_dir"
  local user_data_file="${stage_dir}/user_data.yml"
  local network_config_file="${stage_dir}/network-config.yml"
  local archive_user_data="${archive_dir}/user_data.yml"
  local archive_net_config="${archive_dir}/network-config.yml"
  local vps_wg_file="${archive_dir}/one-click.conf"
  if [[ "$network_mode" != "public" ]]; then
    master_priv_key=$(awk '/PrivateKey/{print $3}' /etc/wireguard/one-click.conf)
    master_pub_key=$(echo "$master_priv_key" | wg pubkey)
    if [[ "$IPv6_ONLY_2_v4" == true ]]; then
      dns_guard="DNS = 10.10.0.1"
      ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "
          sudo systemctl enable --now systemd-resolved &> /dev/null || true
        " &> /dev/null
    fi
    info "Creating Peer Wireguard Configuration"
    cat > "$vps_wg_file" <<EOF
[Interface]
Address = ${vps_private_ip}/16
MTU = 1412
SaveConfig = false
${dns_guard:-}
PrivateKey = ${vps_private_key}

#PostUp = ip rule add table 200 from ${vps_private_ip}
#PostUp = ip route add table 200 default via 192.168.250.1
#PostUp = ip route add 10.10.0.0/16 dev one-click scope link src ${vps_private_ip}
#PreDown = ip rule del table 200 from ${vps_private_ip}
#PreDown = ip route del table 200 default via 192.168.250.1
#PostDown = ip route del 10.10.0.0/16 dev one-click

[Peer]
PublicKey = ${master_pub_key}
PresharedKey = ${vps_preshared_key}
AllowedIPs = 10.10.0.0/16
Endpoint = ${CONTROLLER_IP}:51821
PersistentKeepalive = 25
EOF
    chmod 600 "$vps_wg_file"
  fi
  local host_ssh_key=""
  [[ -f "/etc/one-click/fleet/keys/id_ed25519.pub" ]] && host_ssh_key=$(cat /etc/one-click/fleet/keys/id_ed25519.pub)
  if [[ "${mode:-}" == "hypervisor" ]]; then
    target_ssh_key=$(cat /etc/one-click/fleet/keys/id_ed25519.pub)
  else
    local node_state_file="$fleet_root/state/${target_host}.conf"
    local private_key="/etc/one-click/fleet/keys/id_ed25519"
    private_b64=$(grep "^NODE_PRIVKEY_B64=" "$node_state_file" | cut -d= -f2- | tr -d '"')
    public_raw=$(grep "^NODE_PUBKEY=" "$node_state_file" | cut -d= -f2- | tr -d '"')
    if ! target_ssh_key=$(ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "
          if ! cat /home/oneclick/.ssh/id_ed25519.pub; then
            mkdir -p /home/oneclick/.ssh
            chmod 700 /home/oneclick/.ssh
            echo \"$private_b64\" | base64 -d > /home/oneclick/.ssh/id_ed25519
            echo \"$public_raw\" > /home/oneclick/.ssh/id_ed25519.pub
            chown -R oneclick:oneclick /home/oneclick/.ssh
            chmod 600 /home/oneclick/.ssh/id_ed25519
            chmod 644 /home/oneclick/.ssh/id_ed25519.pub
            cat /home/oneclick/.ssh/id_ed25519.pub
          fi
        " 2>/dev/null | sed -n '/ssh/p'); then
      error "Peer: $target_host is unresponsive"
      return 1
    fi
  fi
  master_pub_key=$(cat /etc/wireguard/oc_public.key)
  # ==== cloud-config ====
  local os_family=""
  if [[ "${base_image_name,,}" =~ http://|https:// ]]; then
    if [[ "${base_image_name,,}" =~ \.iso ]]; then
      os_family="custom_iso"
    else
      os_family="custom_cloudimg"
    fi
  elif [[ "${base_image_name,,}" =~ (nixos|nix-os) ]]; then
    case "${base_image_name,,}" in
      *26.05*|*2605*)       os_model="26.05" ;;
      *25.11*|*2511*)       os_model="25.11" ;;
      *25.05*|*2505*)       os_model="25.05" ;;
      *24.11*|*2411*)       os_model="24.11" ;;
      *24.05*|*2405*)       os_model="24.05" ;;
      *unstable*|*edge*) os_model="unstable" ;;
      *)                    os_model="26.05" ;;
    esac
    os_family="nixos"
    os_version="nixos-${os_model}"
  elif [[ "${base_image_name,,}" =~ alpine ]]; then
    case "${base_image_name,,}" in
      *3.24*|*324*) os_model="3.24"    ;;
      *3.23*|*323*) os_model="3.23"    ;;
      *3.22*|*322*) os_model="3.22"    ;;
      *3.21*|*321*) os_model="3.21"    ;;
      *3.20*|*320*) os_model="3.20"    ;;
      *edge*|*latest*) os_model="edge" ;;
      *)            os_model="3.24"    ;;
    esac
    os_family="alpine"
    os_version="alpinelinux-${os_model}"
  elif [[ "${base_image_name,,}" =~ (alma|rhel|centos|fedora|el)([0-9]+) ]]; then
    if [[ "${BASH_REMATCH[1]}" == "alma" ]]; then
      el=almalinux
    elif [[ "${BASH_REMATCH[1]}" == "centos" ]]; then
      el=centos-stream
    elif [[ "${BASH_REMATCH[1]}" == "el" ]]; then
      el=rhel
    else
      el="${BASH_REMATCH[1]}"
    fi
    os_family="$el"
    os_version="${os_family}${BASH_REMATCH[2]}"
  elif [[ "${base_image_name,,}" =~ (rocky)([0-9]+) ]]; then
    os_family="rocky"
    os_version="${os_family}${BASH_REMATCH[2]}"
  elif [[ "${base_image_name,,}" =~ (debian|deb)([0-9]+) ]]; then
    os_family="debian"
    os_version="${os_family}${BASH_REMATCH[2]}"
  elif [[ "${base_image_name,,}" =~ (ubuntu)([0-9]+) ]]; then
    case "${base_image_name,,}" in
      *26*) os_model="26.04" ;;
      *24*) os_model="24.04" ;;
      *22*) os_model="22.04" ;;
      *20*) os_model="20.04" ;;
      *)    os_model="24.04" ;;
    esac
    os_family="ubuntu"
    os_version="${os_family}${os_model}"
  elif [[ "${base_image_name,,}" =~ (win|windows)([0-9]+) ]]; then
    case "${base_image_name,,}" in
      *2025*|*25*) os_model="2k25" ;;
      *2022*|*22*) os_model="2k22" ;;
      *2019*|*19*) os_model="2k19" ;;
      *2016*|*16*) os_model="2k16" ;;
      *)           os_model="2k22" ;;
    esac
    os_family="win"
    os_version="${os_family}${os_model}"
  fi
  if [[ "$os_version" =~ (ubuntu26\.04|nixos|alpine) ]]; then
    os_version=generic
  fi
  if [[ "$IPv6_ONLY_2_v4" == true ]]; then
    dns_guard="DNS = 10.10.0.1"
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        sudo systemctl enable --now systemd-resolved &> /dev/null || true
      " &> /dev/null
  fi
  ips_allowed="AllowedIPs = 10.10.0.0/16"
  case "$os_family" in
    nixos)
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
fqdn: ${vps_name}

users:
  - name: oneclick
    uid: 1000
    groups: [ wheel, docker ]
    shell: /run/current-system/sw/bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

write_files:
  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - /run/current-system/sw/bin/sysctl --system
  - /run/current-system/sw/bin/systemctl start wg-quick-one-click 2>/dev/null || true

final_message: "OneClick NixOS cloud-init configurations staged."
EOF
      ;;
    alpine)
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
fqdn: ${vps_name}

users:
  - name: oneclick
    gecos: OneClick Administrator
    groups: wheel,users
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: false

write_files:
  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system
  - apk update
  - apk add wireguard-tools curl qemu-guest-agent iptables bash sudo
  - rc-update add qemu-guest-agent default 2>/dev/null || true
  - ln -s /usr/libexec/qemu-guest-agent /etc/init.d/qemu-guest-agent 2>/dev/null || true
  - rc-service qemu-guest-agent start 2>/dev/null || true
  - rc-update add wg-quick default 2>/dev/null || true

final_message: "OneClick Alpine provisioning completed."
EOF
      ;;
    custom_cloudimg)
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
fqdn: ${vps_name}
package_update: false
package_upgrade: false

users:
  - default
  - name: oneclick
    gecos: OneClick Administrator
    groups: [wheel, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: false

write_files:
  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system
  - |
    if command -v apt-get >/dev/null; then
      apt-get update && apt-get install -y wireguard-tools curl qemu-guest-agent iptables
    elif command -v dnf >/dev/null; then
      dnf install -y wireguard-tools curl qemu-guest-agent iptables-services
    fi

final_message: "Custom Cloud Image initialized cleanly."
EOF
      ;;
    "${el:-}")
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
fqdn: ${vps_name}
create_hostname_file: true
preserve_hostname: false
package_update: false
package_upgrade: false

users:
  - default

  - name: oneclick
    gecos: OneClick Administrator
    groups:
      - wheel

    shell: /bin/bash

    sudo: ALL=(ALL) NOPASSWD:ALL

    lock_passwd: false

    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: false

write_files:

  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key:-}

      [Peer]
      PublicKey = ${master_pub_key:-}
      PresharedKey = ${vps_preshared_key:-}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system

final_message: "OneClick provisioning completed."

EOF
      ;;
    rocky)
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
fqdn: ${vps_name}
create_hostname_file: true
preserve_hostname: false
package_update: false
package_upgrade: false

bootcmd:
  - echo 'GRUB_TERMINAL="serial"' >> /etc/default/grub
  - echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
  - sed -i 's/GRUB_CMDLINE_LINUX="[^"]*/& console=ttyS0,115200n8/' /etc/default/grub
  - grub2-mkconfig -o /boot/grub2/grub.cfg

users:
  - name: oneclick
    gecos: OneClick Administrator
    groups: [wheel]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: false

write_files:
  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key:-}

      [Peer]
      PublicKey = ${master_pub_key:-}
      PresharedKey = ${vps_preshared_key:-}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system
  - |
    for i in {1..30}; do
      if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then break; fi
      sleep 2
    done
  - dnf config-manager --setopt=max_parallel_downloads=2 --save || true
  - dnf config-manager --setopt=zchunk=False --save || true
  - echo "metadata_expire=86400" >> /etc/dnf/dnf.conf
  - dnf clean all
  - dnf install -y epel-release || true
  - dnf install -y wireguard-tools curl qemu-guest-agent iptables
  - command -v firewall-cmd >/dev/null && firewall-cmd --zone=public --add-port=51821/udp --permanent && firewall-cmd --reload 2>/dev/null || true
  - systemctl daemon-reload
  - systemctl enable --now qemu-guest-agent 2>/dev/null || true
  - systemctl enable --now wg-quick@one-click 2>/dev/null || true

final_message: "OneClick Rocky provisioning completed."
EOF
      ;;
    debian)
      cat > "$user_data_file" <<EOF
#cloud-config

hostname: ${vps_name}
preserve_hostname: false
package_update: false
package_upgrade: false

users:
  - default

  - name: oneclick
    gecos: OneClick Administrator
    groups:
      - sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: false

write_files:

  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key:-}
      #DNS = 10.10.0.1,8.8.8.8

      [Peer]
      PublicKey = ${master_pub_key:-}
      PresharedKey = ${vps_preshared_key:-}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system

final_message: "OneClick provisioning completed."
EOF
      ;;
    ubuntu)
      cat > "$user_data_file" <<EOF
#cloud-config

updates:
  network:
    when: ['boot', 'boot-new-instance']

hostname: ${vps_name}
manage_resolv_conf: true
package_upgrade: false
package_update: false

bootcmd:
  - mkdir -p /etc/systemd/resolved.conf.d
  - echo -e "[Resolve]\nDNS=1.1.1.1 8.8.8.8\nDomains=~." > /etc/systemd/resolved.conf.d/dns_override.conf
  - echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf
  - chattr +i /etc/resolv.conf 2>/dev/null || true

write_files:
  - path: /etc/sysctl.d/99-oneclick-vps-routing.conf
    owner: root:root
    permissions: '0644'
    content: |
      net.ipv4.ip_forward=1

  - path: /etc/wireguard/one-click.conf
    owner: root:root
    permissions: '0600'
    content: |
      [Interface]
      Address = ${vps_private_ip}/16
      MTU = 1412
      ${dns_guard:-}
      ListenPort = ${wg_peer_port}
      PrivateKey = ${vps_private_key}
      #DNS = 10.10.0.1,8.8.8.8

      #PostUp = ip rule add table 200 from ${vps_private_ip}
      #PreDown = ip rule del table 200 from ${vps_private_ip}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      $ips_allowed
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

users:
  - name: oneclick
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ${pass_cloud_init}
    ssh_authorized_keys:
      - ${host_ssh_key}
      - ${target_ssh_key}

chpasswd:
  list:
    - oneclick:${raw_password}
  expire: False

runcmd:
  - sysctl --system
  - |
    while ! getent hosts archive.ubuntu.com >/dev/null 2>&1 && ! getent hosts google.com >/dev/null 2>&1; do
      sleep 2
    done
  - |
    if command -v apt-get >/dev/null; then
      while fuser /var/lib/dpkg/lock-frontends >/dev/null 2>&1; do sleep 2; done
      apt-get update -y
      apt-get install -y wireguard-tools curl qemu-guest-agent iptables
    elif command -v dnf >/dev/null; then
      dnf install -y wireguard-tools curl qemu-guest-agent
    elif command -v yum >/dev/null; then
      yum install -y wireguard-tools curl qemu-guest-agent
    fi
  - command -v iptables >/dev/null && iptables -I INPUT -p udp --dport 51821 -j ACCEPT 2>/dev/null || true
  - command -v iptables >/dev/null && iptables -I OUTPUT -p udp --dport 51821 -j ACCEPT 2>/dev/null || true
  - command -v firewall-cmd >/dev/null && firewall-cmd --zone=public --add-port=51821/udp --permanent && firewall-cmd --reload 2>/dev/null || true
  - systemctl daemon-reload
  - systemctl enable --now qemu-guest-agent 2>/dev/null || true
  - systemctl enable --now wg-quick@one-click 2>/dev/null || true
EOF
    ;;
    win)
    cat > "$user_data_file" <<EOF
Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#ps1_sysnative
\$ErrorActionPreference = "SilentlyContinue"

Rename-Computer -NewName "${vps_name:0:15}" -Force -ErrorAction SilentlyContinue

if (-not (Get-LocalUser -Name "oneclick" -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name "oneclick" -Password (ConvertTo-SecureString "${raw_password}" -AsPlainText -Force) -FullName "OneClick Administrator" -PasswordNeverExpires \$true
    Add-LocalGroupMember -Group "Administrators" -Member "oneclick"
} else {
    Set-LocalUser -Name "oneclick" -Password (ConvertTo-SecureString "${raw_password}" -AsPlainText -Force) -PasswordNeverExpires \$true
}

Set-LocalUser -Name "Administrator" -Password (ConvertTo-SecureString "${raw_password}" -AsPlainText -Force) -PasswordNeverExpires \$true

Get-NetAdapter | Enable-NetAdapter -Confirm:\$false -ErrorAction SilentlyContinue
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

EOF

    if [[ "$network_mode" == "public" ]]; then
      cat >> "$user_data_file" <<EOF
\$adapter = Get-NetAdapter |
    Where-Object { \$_.Status -eq "Up" } |
    Select-Object -First 1

if (\$adapter) {
    \$ifIndex = \$adapter.ifIndex

    Set-NetIPInterface \`
        -InterfaceIndex \$ifIndex \`
        -AddressFamily IPv4 \`
        -Dhcp Disabled \`
        -ErrorAction SilentlyContinue

    Get-NetIPAddress \`
        -InterfaceIndex \$ifIndex \`
        -AddressFamily IPv4 \`
        -ErrorAction SilentlyContinue |
        Where-Object { \$_.PrefixOrigin -ne "WellKnown" } |
        Remove-NetIPAddress -Confirm:\$false -ErrorAction SilentlyContinue

    Get-NetRoute \`
        -InterfaceIndex \$ifIndex \`
        -AddressFamily IPv4 \`
        -ErrorAction SilentlyContinue |
        Where-Object { \$_.DestinationPrefix -eq "0.0.0.0/0" } |
        Remove-NetRoute -Confirm:\$false -ErrorAction SilentlyContinue

    New-NetIPAddress \`
        -InterfaceIndex \$ifIndex \`
        -IPAddress "${public_ip%%/*}" \`
        -PrefixLength "${public_ip##*/}" \`
        -DefaultGateway "${host_gateway}" \`
        -ErrorAction Stop

    Set-DnsClientServerAddress \`
        -InterfaceIndex \$ifIndex \`
        -ServerAddresses @("1.1.1.1","8.8.8.8") \`
        -ErrorAction SilentlyContinue
}

EOF

    else
      cat >> "$user_data_file" <<'EOF'
Get-NetAdapter | ForEach-Object {
    Set-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -Dhcp Enabled -ErrorAction SilentlyContinue
    Set-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv6 -RouterDiscovery Enabled -Dhcp Enabled -ErrorAction SilentlyContinue
}

ipconfig /renew | Out-Null

EOF
    fi

    cat >> "$user_data_file" <<EOF
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Core Networking Diagnostic - ICMPv4-In" -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WireGuard UDP 51821" -Direction Inbound -Action Allow -Protocol UDP -LocalPort 51821 -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "WireGuard UDP Peer Port ${wg_peer_port}" -Direction Inbound -Action Allow -Protocol UDP -LocalPort ${wg_peer_port} -ErrorAction SilentlyContinue

if (Test-Path "C:\Drivers\guest-agent\qemu-ga-x86_64.msi") {
    Start-Process msiexec.exe -ArgumentList "/i \`"C:\Drivers\guest-agent\qemu-ga-x86_64.msi\`" /qn /norestart" -Wait
    Start-Service -Name "qemu-ga" -ErrorAction SilentlyContinue
    Set-Service -Name "qemu-ga" -StartupType Automatic -ErrorAction SilentlyContinue
}

\$wgExe = "C:\Program Files\WireGuard\wireguard.exe"

if (!(Test-Path \$wgExe) -and (Test-Path "C:\WireGuard\wireguard-amd64.msi")) {
    Start-Process msiexec.exe \`
        -ArgumentList "/i \`"C:\WireGuard\wireguard-amd64.msi\`" /qn /norestart DO_NOT_LAUNCH=1" \`
        -Wait
}

if (Test-Path \$wgExe) {
    \$configDir = "C:\Program Files\WireGuard\Data\Configurations"
    New-Item -Path \$configDir -ItemType Directory -Force | Out-Null

    \$wgConfPath = "\$configDir\one-click.conf"

    @'
[Interface]
Address = ${vps_private_ip}/16
MTU = 1412
ListenPort = ${wg_peer_port}
PrivateKey = ${vps_private_key}

[Peer]
PublicKey = ${master_pub_key}
PresharedKey = ${vps_preshared_key}
$ips_allowed
Endpoint = ${CONTROLLER_IP}:51821
PersistentKeepalive = 25
'@ | Set-Content -Path \$wgConfPath -Encoding UTF8

    Start-Process -FilePath \$wgExe \`
        -ArgumentList "/installtunnelservice \`"\$wgConfPath\`"" \`
        -Wait
}

Write-Output "OneClick Windows Provisioning Complete."
--==BOUNDARY==--
EOF
    ;;
  custom_iso|*)
      cat > "$user_data_file" <<EOF
#cloud-config
hostname: ${vps_name}
EOF
    ;;
  esac
  cp "$user_data_file" "$archive_user_data"
  info "Configuring peer VPS networking"
  if [[ "$is_windows" -eq 1 ]]; then
    local win_mac=$(echo "$vps_name" | md5sum | sed -E 's/^(..)(..)(..).*$/52:54:00:\1:\2:\3/')
    local net_flag="--network network=oneclick-nat,model=virtio --boot uefi --clock offset=localtime,hypervclock_present=yes,rtc_tickpolicy=catchup,pit_tickpolicy=delay,hpet_present=no --features hyperv.relaxed.state=on,hyperv.vapic.state=on,hyperv.spinlocks.state=on,hyperv.spinlocks.retries=8191,hyperv.synic.state=on,hyperv.stimer.state=on,hyperv.reset.state=on,hyperv.frequencies.state=on --sound model=ich9"
    host_gateway=$(ip route show default | awk '{print $3; exit}')
  else
    local net_flag="--network network=oneclick-nat,model=virtio"
  fi
  local cloud_init_net_argument="--cloud-init user-data=$user_data_file"
  if [[ "$network_mode" == "public" ]]; then
    local net_mac_block=""
	local host_gateway
    host_gateway=$(ip route show default | awk '{print $3}')
    if [[ -n "$virtual_mac" ]]; then
      if [[ "$is_windows" -eq 1 ]]; then
        net_flag="--network network=oneclick-nat,model=e1000e,mac=$virtual_mac --boot uefi --clock offset=localtime,hypervclock_present=yes,rtc_tickpolicy=catchup,pit_tickpolicy=delay,hpet_present=no --features hyperv.relaxed.state=on,hyperv.vapic.state=on,hyperv.spinlocks.state=on,hyperv.spinlocks.retries=8191,hyperv.synic.state=on,hyperv.stimer.state=on,hyperv.reset.state=on,hyperv.frequencies.state=on --sound model=ich9"
        host_gateway=$(ip route show default | awk '{print $3; exit}')
      else
        net_flag="--network bridge=br0,mac=${virtual_mac},model=virtio"
        net_mac_block="match:\n macaddress: \"${virtual_mac}\""
        cat > "$network_config_file" <<EOF
version: 2
ethernets:
  pub_iface:
    match:
      macaddress: "${virtual_mac,,}"
    set-name: eth0
    dhcp4: false
    dhcp6: false
    addresses:
      - ${public_ip}
    routes:
      - to: 0.0.0.0/0
        via: ${host_gateway}
    nameservers:
      addresses: [1.1.1.1, 8.8.8.8]
EOF
      fi
    else
      net_flag="--network bridge=br0,model=virtio"
      net_mac_block="match:\n name: \"e*\""
      cat > $network_config_file <<EOF
version: 2
renderer: networkd
ethernets:
  eth_main:
    match:
      name: "e*"
    dhcp4: false
    dhcp6: false
    addresses:
      - ${public_ip}
    routes:
      - to: default
        via: ${host_gateway}
    nameservers:
      addresses:
        - 1.1.1.1
        - 8.8.8.8
EOF
    fi
    cp "$network_config_file" "$archive_net_config"
    cloud_init_net_argument="--cloud-init user-data=$user_data_file,network-config=$network_config_file"
  fi
  local disk_path="/var/lib/libvirt/images/${vps_name}.qcow2"
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    fleet_vps_init
	mkdir -p "$stage_dir"
	if ! command -v virt-install >/dev/null 2>&1; then
      if command -v dnf >/dev/null 2>&1; then
        dnf groupinstall -y "Virtualization Host"
        dnf install -y libvirt-daemon-kvm qemu-kvm libvirt
      elif command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y libvirt-daemon-system libvirt-clients bridge-utils
      else
        return 1
      fi
    fi
    local meta_data_file="${stage_dir}/meta-data"
	iso_path="/var/lib/libvirt/images/${vps_name}_cloudinit.iso"
	work_dir="/tmp/build_${vps_name}"
    mkdir -p "$work_dir"
	echo "instance-id: ${vps_name}-$(date +%s)" > "$meta_data_file"
    echo "local-hostname: ${vps_name}" >> "$meta_data_file"
    vps_vg_allocation "$disk_size" "$vps_name"
    info "Targeting local Controller hypervisor interface."
	cp "$master_image_source" "$disk_path"
	if ! command -v qemu-img > /dev/null; then
	  if command -v apt > /dev/null; then
	    $pkg_mgr update
		$pkg_mgr install -y qemu-utils
	  else
        "$pkg_mgr" -y install qemu-img
	  fi
	fi
	if ! command -v iptables &> /dev/null; then
	  if command -v apt &> /dev/null; then
	    sudo apt-get update
        $pkg_mgr install -y iptables iptables-persistent
	  else
	    $pkg_mgr install -y iptables iptables-nft iptables-services
	  fi
	fi
	v4_int=$(ip route show default | awk '/default/ {print $5; exit}')
	v6_int=$(ip -6 route show default | awk '/default/ {print $5; exit}')
	local private_subnet="192.168.250.0/24"
	local ipv6_private_subnet=fd00:99aa::/64
	if [[ "$network_mode" == "public" ]]; then
	  local sub="${public_ip}/24"
	else
	  local sub="${private_subnet}/24"
	fi
    qemu-img resize "$disk_path" "${disk_size}" &>/dev/null || true
	if ! ip rule show | grep -q "from $sub lookup 200"; then
      ip route add "$sub" dev ocbr0 proto kernel scope link table 200 2>/dev/null || true
      if [[ -n "${ipv6_private_subnet:-}" ]]; then
        ip -6 route add "$ipv6_private_subnet" dev ocbr0 proto kernel scope link table 200 2>/dev/null || true
      fi
      ip rule add from "$sub" table 200 2>/dev/null || true
      if [[ -n "${ipv6_private_subnet:-}" ]]; then
        ip -6 rule add from "$ipv6_private_subnet" table 200 2>/dev/null || true
      fi
      if [[ -n ${v4_init:-} ]]; then
	    iptables -I FORWARD -i ocbr0 -o ${v4_int} -j ACCEPT
	    if ! iptables -C INPUT -i ocbr0 -j ACCEPT 2>/dev/null; then
          iptables -I INPUT -i ocbr0 -j ACCEPT
        fi
        if ! iptables -C OUTPUT -o ocbr0 -j ACCEPT 2>/dev/null; then
          iptables -I OUTPUT -o ocbr0 -j ACCEPT
        fi
	  fi
	  if [[ -n "${v6_init:-}" ]]; then
  	    ip6tables -I FORWARD -i ocbr0 -o ${v6_int} -j ACCEPT
  	    if ! ip6tables -C INPUT -i ocbr0 -j ACCEPT 2>/dev/null; then
          ip6tables -I INPUT -i ocbr0 -j ACCEPT
        fi
        if ! ip6tables -C OUTPUT -o ocbr0 -j ACCEPT 2>/dev/null; then
          ip6tables -I OUTPUT -o ocbr0 -j ACCEPT
        fi
	  fi
      if [[ "$network_mode" != "public" ]]; then
        if ! iptables -t nat -C POSTROUTING -s "$private_subnet" ! -d "$private_subnet" -j MASQUERADE 2>/dev/null; then
          nft add table ip nat 2>/dev/null || true
          nft add table ip6 nat 2>/dev/null || true
          nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat ; policy accept ; }' 2>/dev/null
          nft add chain ip6 nat POSTROUTING '{ type nat hook postrouting priority srcnat ; policy accept ; }' 2>/dev/null
          nft add table ip filter 2>/dev/null || true
          nft add chain ip filter FORWARD '{ type filter hook forward priority filter; policy accept; }' 2>/dev/null || true
          nft add chain ip filter INPUT '{ type filter hook input priority filter; policy accept; }' 2>/dev/null || true
          nft add chain ip filter OUTPUT '{ type filter hook output priority filter; policy accept; }' 2>/dev/null || true
          if ! nft list chain ip filter INPUT | grep -q "iifname \"ocbr0\" accept"; then
            nft add rule ip filter INPUT iifname "ocbr0" accept
          fi
          if ! nft list chain ip filter OUTPUT | grep -q "iifname \"ocbr0\" accept"; then
            nft add rule ip filter OUTPUT iifname "ocbr0" accept
          fi
          if ! nft list chain ip nat POSTROUTING | grep -q "ip saddr $private_subnet ip daddr != $private_subnet masquerade"; then
            nft add rule ip nat POSTROUTING ip saddr "$private_subnet" ip daddr != "$private_subnet" masquerade 2>/dev/null
            nft add rule ip6 nat POSTROUTING ip6 saddr "$ipv6_private_subnet" ip6 daddr != "$ipv6_private_subnet" masquerade 2>/dev/null
          fi
        fi
      fi
      ip rule add from "$sub" table 200 2>/dev/null || true
	  ip -6 rule add from fd00:99aa::/64 table 200 2>/dev/null || true
    fi
    virsh destroy "$vps_name" 2>/dev/null || true
    virsh undefine "$vps_name" 2>/dev/null || true
	if ! command -v genisoimage &>/dev/null; then
      if command -v apt-get &>/dev/null; then
        apt-get update
		apt-get install -y genisoimage &>/dev/null
      elif command -v dnf &>/dev/null; then
	    if ! dnf install -y genisoimage &> /dev/null; then
          dnf install -y cdrkit-genisoimage &>/dev/null || dnf -y install xorriso &> /dev/null
		fi
		if command -v xorrisofs &> /dev/null; then
		  ln -s /usr/bin/xorrisofs /usr/bin/genisoimage 2>/dev/null
		  systemctl enable --now virtqemud.socket
          systemctl enable --now virtqemud-ro.socket
          systemctl enable --now virtqemud-admin.socket
          systemctl enable --now virtnetworkd.socket
          systemctl enable --now virtstoraged.socket
          systemctl enable --now virtnodedevd.socket
          systemctl enable --now virtqemud.service
		fi
      fi
    fi
	cp "$meta_data_file" "$work_dir/meta-data"
    cp "$user_data_file" "$work_dir/user-data"
    rm -f "$iso_path"
	if command -v genisoimage &> /dev/null; then
      if [[ "$is_windows" -eq 1 ]]; then
        mkisofs -o "$iso_path" -V cidata -J -r -iso-level 1 "$work_dir/"
      elif [[ -f "$network_config_file" ]]; then
        cp "$network_config_file" "$work_dir/network-config"
        genisoimage -output "$iso_path" -volid CIDATA -joliet -rock "$work_dir/user-data" "$work_dir/meta-data" "$work_dir/network-config"
      else
        genisoimage -output "$iso_path" -volid CIDATA -joliet -rock "$work_dir/user-data" "$work_dir/meta-data"
      fi
	else
	  error "genisoimage has not been installed properly."
	fi
    sync
    sleep 1
    if [ ! -s "$iso_path" ]; then
      error '=== ISO GENERATION CRASH: File not written or empty ===' >&2
      return 1
    fi
    VIRT_TYPE_FLAG="--virt-type kvm"
    if virt-install --help 2>&1 | grep -q -- '\-\-type'; then
      if ! virt-install --help 2>&1 | grep -q -- '\-\-virt-type'; then
        VIRT_TYPE_FLAG="--type kvm"
      fi
    fi
	if ! command -v virt-install >/dev/null 2>&1; then
      if command -v dnf >/dev/null 2>&1; then
        dnf groupinstall -y "Virtualization Host"
        dnf install -y libvirt-daemon-kvm qemu-kvm libvirt
      elif command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y libvirt-daemon-system libvirt-clients bridge-utils
      else
        return 1
      fi
    fi
	install_dep "virt-install" "type virt-install" "virt-install" "$pkg_mgr" true
	mkdir -p /var/log/one-click/${vps_name}/virt-engine
    virt-install \
      --name "$vps_name" \
      --memory $vps_ram \
      --vcpus $vps_cpu \
      --cpu host-passthrough \
      --disk path="$disk_path",format=qcow2,bus=virtio,boot.order=1 \
      --disk path="$iso_path",device=cdrom,format=raw,boot.order=2 \
      $net_flag \
      $VIRT_TYPE_FLAG \
      --osinfo $os_version \
      --import \
      --graphics vnc,listen=0.0.0.0 \
      --console pty,target_type=serial \
      --noautoconsole | tee "/var/log/one-click/virt-engine/${vps_name}-virtoutput.log"
	rm -f /tmp/${vps_name}_user_data.yml /tmp/${vps_name}_meta_data.yml
  else
    info "Preparing ${target_host}'s LVM script."
	local remote_target_script="/etc/one-click/virtualization/initialize_storage.sh"
    local meta_data_file="${stage_dir}/meta-data"
	write_peer_vps_vg_allocation
	info "Pushing VG creation script to [$target_host] hypervisor."
	remote_dest_dir=$(dirname "$remote_target_script")
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_INTERPRETER_DISCOVERY=ignore \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m command \
      -a "mkdir -p $remote_dest_dir $IMG_STORAGE_PATH" 2>/dev/null | sed -En "{
	    s/([^|]*) \| ([^|!=]*) .*/${orange}[\2] Controller => \1 ${magenta}Ensuring directories exist on $vps_name.${reset}/p
      }
	"
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_INTERPRETER_DISCOVERY=ignore \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$storage_script dest=$remote_target_script mode=0755" 2> /dev/null | sed -En "{
	    s/([^|]*) \| ([^|!=]*) .*/${orange}[\2] Controller => \1 ${magenta}LVM preparation on $vps_name currently processing.${reset}/p
      }
	"
	info "Preparing LVM partitioning on [$target_host]."
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_INTERPRETER_DISCOVERY=ignore \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "sudo bash $remote_target_script $disk_size $vps_name $IMG_STORAGE_PATH $VG_ALLOC" 2> /dev/null | sed -E "{
	    /changed/I s/([^|]*) \| ([^|!=]*) .*/${orange}[\2] Controller => \1 ${magenta}Preparing logical volume for $vps_name on $target_host.${reset}/
      }
    "
    echo "instance-id: ${vps_name}" > "$meta_data_file"
    ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$user_data_file dest=/tmp/${vps_name}_user_data.yml" &> /dev/null
    echo "${orange}[CHANGED]${yellow} Controller => $target_host ${magenta} Copied $user_data_file to /tmp/${vps_name}_user_data.yml${reset}"
	ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$meta_data_file dest=/tmp/${vps_name}_meta_data.yml" &> /dev/null
    echo "${orange}[CHANGED]${yellow} Controller => $target_host ${magenta} Copied $meta_data_file to /tmp/${vps_name}_meta_data.yml${reset}"
    if [[ "$network_mode" == "public" ]]; then
      info "Syncing static Netplan network configuration matrix metadata."
      ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
		ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m copy -a "src=$network_config_file dest=/tmp/${vps_name}_network_config.yml" &> /dev/null
	  echo "${orange}[CHANGED]${yellow} Controller => $target_host ${magenta} Copied $network_config_file to /tmp/${vps_name}_network_config.yml${reset}"
    fi
    info "Streaming OS image to $target_host."
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$master_image_source dest=$disk_path" &> /dev/null
    echo "${orange}[CHANGED]${yellow} Controller => $target_host ${magenta} Copied $master_image_source to $disk_path ${reset}"
    info "Deploying server with cloud-init on $target_host hypervisor"
	local private_subnet="192.168.250.0/24"
	local ipv6_private_subnet=fd00:99aa::/64
	if [[ "$network_mode" == "public" ]]; then
	  local sub="${public_ip}/24"
	else
	  local sub="${private_subnet}/24"
	fi
	mkdir -p /var/log/one-click/virt-engine/
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        qemu-img resize \"$disk_path\" \"${disk_size}\" 2>/dev/null
        if ! ip rule show | grep -q \"$sub table 200\"; then
          ip route add \"$sub\" dev ocbr0 proto kernel scope link table 200 2>/dev/null || true
          if [[ -n \"${ipv6_private_subnet:-}\" ]]; then
            ip -6 route add "$ipv6_private_subnet" dev ocbr0 proto kernel scope link table 200 2>/dev/null || true
          fi
          ip rule add from \"$sub\" table 200 2>/dev/null || true
          if [[ -n \"${ipv6_private_subnet:-}\" ]]; then
            ip -6 rule add from \"$ipv6_private_subnet\" table 200 2>/dev/null || true
          fi
		  iptables -I FORWARD -i ocbr0 -o $(ip route show default | awk '/default/ {print $5; exit}') -j ACCEPT 2>/dev/null || true
		  ip6tables -I FORWARD -i ocbr0 -o $(ip -6 route show default | awk '/default/ {print $5; exit}') -j ACCEPT 2>/dev/null || true
          #iptables -I FORWARD -i $(ip route show default | awk '/default/ {print $5; exit}') -o ocbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT
          if ! iptables -t nat -C POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
            if ! iptables -t nat -I POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
              nft add table ip nat 2>/dev/null || true
			  nft add table ip6 nat 2>/dev/null || true
              nft add chain ip nat POSTROUTING '{ type nat hook postrouting priority srcnat \; policy accept \; }' 2>/dev/null
			  nft add chain ip6 nat POSTROUTING '{ type nat hook postrouting priority srcnat \; policy accept \; }' 2>/dev/null
              if ! nft list chain ip nat POSTROUTING | grep -q \"ip saddr $private_subnet ip daddr != $private_subnet masquerade\"; then
                nft add rule ip nat POSTROUTING ip saddr \"$private_subnet\" ip daddr != \"$private_subnet\" masquerade 2>/dev/null
				nft add rule ip6 nat POSTROUTING ip saddr \"$ipv6_private_subnet\" ip daddr != \"$ipv6_private_subnet\" masquerade 2>/dev/null
              fi
            fi
          fi
          ip rule add from 192.168.250.0/24 table 200 2>/dev/null || true
		  ip -6 rule add from fd00:99aa::/64 table 200 2>/dev/null || true
        fi
        virsh destroy \"$vps_name\" 2>/dev/null || true
        virsh undefine \"$vps_name\" 2>/dev/null || true
        work_dir=\"/tmp/build_${vps_name}\"
        mkdir -p \"\$work_dir\"
		if ! command -v genisoimage &>/dev/null; then
          if command -v apt-get &>/dev/null; then
            sudo apt-get update
		    sudo apt-get install -y genisoimage &>/dev/null
          elif command -v dnf &>/dev/null; then
            if ! sudo dnf install -y genisoimage &> /dev/null; then
              sudo dnf install -y cdrkit-genisoimage &>/dev/null || dnf -y install xorriso &> /dev/null
		    fi
		    if command -v xorrisofs &> /dev/null; then
              sudo ln -s /usr/bin/xorrisofs /usr/bin/genisoimage 2>/dev/null
              sudo systemctl enable --now virtqemud.socket
              sudo systemctl enable --now virtqemud-ro.socket
              sudo systemctl enable --now virtqemud-admin.socket
              sudo systemctl enable --now virtnetworkd.socket
              sudo systemctl enable --now virtstoraged.socket
              sudo systemctl enable --now virtnodedevd.socket
              sudo systemctl enable --now virtqemud.service
		    fi
          fi
        fi
        cp /tmp/${vps_name}_user_data.yml \"\$work_dir/user-data\"
        cp /tmp/${vps_name}_meta_data.yml \"\$work_dir/meta-data\"
        iso_path=\"/var/lib/libvirt/images/${vps_name}_cloudinit.iso\"
        rm -f \"\$iso_path\"
		if [ -f "/tmp/${vps_name}_network_config.yml" ]; then
          cp /tmp/${vps_name}_network_config.yml \"\$work_dir/network-config\"
          genisoimage -output \"\$iso_path\" -volid CIDATA -joliet -rock \"\$work_dir/user-data\" \"\$work_dir/meta-data\" \"\$work_dir/network-config\" #&>/dev/null
        else
          genisoimage -output \"\$iso_path\" -volid CIDATA -joliet -rock \"\$work_dir/user-data\" \"\$work_dir/meta-data\" #&>/dev/null
        fi
        sync
		chmod 644 \"\$iso_path\"
        sleep 1
        if [ ! -s \"\$iso_path\" ]; then
          echo '=== ISO GENERATION CRASH: File not written or empty ===' >&2
          exit 1
        fi
        VIRT_TYPE_FLAG=\"--virt-type kvm\"
        if virt-install --help 2>&1 | grep -q -- '--type'; then
          if ! virt-install --help 2>&1 | grep -q -- '--virt-type'; then
            VIRT_TYPE_FLAG=\"--type kvm\"
          fi
        fi
        mkdir -p /var/log/one-click/${vps_name}/virt-engine
        virt-install \
          --name \"$vps_name\" \
          --memory $vps_ram \
          --vcpus $vps_cpu \
          --cpu host-passthrough \
          --disk path=\"$disk_path\",format=qcow2,bus=virtio \
          --disk path=\"\$iso_path\",device=cdrom \
          $net_flag \
          \$VIRT_TYPE_FLAG \
          --osinfo $os_version \
          --import \
          --graphics vnc,listen=0.0.0.0 \
          --console pty,target_type=serial \
          --noautoconsole
        rm -rf \"\$work_dir\"
        rm -f /tmp/${vps_name}_user_data.yml /tmp/${vps_name}_meta_data.yml
      " | tee "/var/log/one-click/virt-engine/${vps_name}-virtoutput.log" | sed -En '/Starting install./,$p'
  fi
  virt_error=$(sed -n "/ERROR/s/ERROR/${red}[&]${reset}/p" "/var/log/one-click/virt-engine/${vps_name}-virtoutput.log")
  if [[ -z "$virt_error" ]]; then
    success "VPS successfully deployed."
  else
    echo "$virt_error"
    if [[ "$virt_error" =~ "Unknown OS name" ]]; then
      warn "Deployment failed due to unknown OS release."
    fi
    error "VPS deployement failed!"
	return 1
  fi
  if [[ "$is_windows" -eq 1 ]]; then
    info "Launching VNC console"
    fleet_vps_web_console "$vps_name" "$target_host"
  fi
  if [[ "$network_mode" != "public" ]]; then
    info "Aquiring IP."
    sed -i "1d" "$FLEET_AVAILABLE_IPS_FILE"
    echo "$vps_private_ip" >> "$FLEET_USED_IPS_FILE"
    rm -rf "$stage_dir"
  else
    info "Configured IP for public build: ${public_ip%%/*}"
    echo "${public_ip%%/*}" >> "$FLEET_USED_IPS_FILE"
  fi
  local ledger_file="/etc/one-click/virtualization/inventory.json"
  [[ ! -f "$ledger_file" ]] && echo "[]" > "$ledger_file"
  if [[ "$network_mode" == "public" ]]; then
    local mode_ip="$public_ip"
	local mode_int="br0"
  else
    local mode_ip="$vps_private_ip"
	local mode_int="oneclick-nat"
  fi
  [[ "$network_mode" == "public" ]] && mode_ip="$public_ip"
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    local_vps_ip=$(while true; do
      if virsh list --state-running --name | grep -q "^$vps_name$"; then
        break
      else
        sleep 2
      fi
    done
    mac=$(virsh domiflist "$vps_name" | awk -v intf="$mode_int" '$0 ~ intf {print $5}')
    echo "$mac" > macfile
    vps_f_ip=""
    while [ -z "$vps_f_ip" ]; do
	  if [[ "$network_mode" == "public" ]]; then
	    vps_f_ip="${public_ip%%/*}"
	  else
        vps_f_ip=$(virsh net-dhcp-leases "$mode_int" | awk -v m="$mac" '$3==m && $5 !~ ":" {sub("/24","",$5);print $5}')
	  fi
      [ -n "$vps_f_ip" ] && break
      sleep 2
    done
    echo "$vps_f_ip" | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
  else
    remote_vps_ip=$(ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
        ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "
		target_mac=\$(virsh domiflist \"$vps_name\" | awk -v intf=\"$mode_int\" '\$0 ~ intf {print \$5}')
		virsh net-dhcp-leases \"$mode_int\" | awk -v m=\"\$target_mac\" '\$3==m && \$5 !~ \":\" {sub(\"/24\",\"\",\$5);print \$5}'
	  " 2> /dev/null
	)
  fi
  [[ "$network_mode" == "public" ]] && path_ip=public_ip || path_ip=nat_ip
  local updated_json
  updated_json=$(jq ". += [{
    \"name\": \"$vps_name\",
    \"host\": \"$target_host\",
    \"mode\": \"$network_mode\",
    \"primary_ip\": \"$mode_ip\",
    \"password\": \"$raw_password\",
    \"cluster_private_ip\": \"${vps_private_ip:-N/A}\",
    \"$path_ip\": \"${remote_vps_ip:-${local_vps_ip:-N/A}}\",
    \"ram\": \"${vps_ram}MB\",
    \"cpu\": \"$vps_cpu\",
    \"disk\": \"$disk_size\",
    \"image\": \"$base_image_name\",
    \"created_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
  }]" "$ledger_file")
  echo "$updated_json" > "$ledger_file"
  if [[ "$network_mode" == "public" ]]; then
    local_vps_ip="${public_ip%%/*}"
    remote_vps_ip="${public_ip%%/*}"
  fi
  if [ -z "${remote_vps_ip:-${local_vps_ip:-}}" ]; then
    error "Failed to capture allocation state for $vps_name"
    exit 1
  fi
  if [[ "$target_host" == "$CONTROLLER_NAME" ]]; then
    while true; do
      vm_state=$(virsh list --state-running --name 2> /dev/null)
      if echo "$vm_state" | grep -q "$vps_name"; then
        success "Hypervisor state active: QEMU container has successfully locked hardware."
        break
      fi
      printf "\r$(tput setaf 79)[PROBE]${reset}    -> Probing hypervisor state."
      sleep 3
    done
  else
    while true; do
      local vm_state=$(ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
	    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	    ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "sudo virsh -c qemu:///system list --name --state-running 2>/dev/null | sed '/^\$/d' | xargs")
      if echo "$vm_state" | grep -q "$vps_name"; then
        success "Hypervisor state active: QEMU container has successfully locked hardware."
        break
      fi
      printf "\r$(tput setaf 79)[PROBE]${reset}    -> Probing hypervisor state."
      sleep 3
    done
  fi
  echo
  if [[ -z "$public_ip" ]]; then
    local info_msg="Polling hypervisor DHCP table for dynamic MAC allocation."
  else
    local info_msg="Aquiring MAC if virtual MAC was not provided"
  fi
  info "$info_msg"
  if [[ -z "$virtual_mac" ]]; then
    if [[ "$target_host" == "$(hostname -s)" ]]; then
      local target_mac=$(cat macfile)
      rm -f macfile
    else
      local target_mac=$(ANSIBLE_HOST_KEY_CHECKING=False \
        ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
        ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "virsh domiflist '$vps_name' | awk -v intf=\"$mode_int\" '\$0 ~ intf {print \$5}'" 2>/dev/null \
        | grep -E -o "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | head -n 1)
    fi
  else
    local target_mac="$virtual_mac"
  fi
  if [ -z "$target_mac" ]; then
    error "Unable to resolve interface MAC link layer."
    exit 1
  fi
  remote_vps_ip=""
  local_vps_ip=""
  local loop_counter=0
  set +e
  local saved_err_trap
  saved_err_trap=$(trap -p ERR)
  trap '' ERR
  while [ $loop_counter -lt 45 ]; do
    if [[ "$network_mode" != "public" ]]; then
      if [[ "$target_host" == "$(hostname -s)" ]]; then
        local_vps_ip=$(virsh net-dhcp-leases "$mode_int" | awk -v m="$target_mac" '$3==m {print $5}' | cut -d'/' -f1 | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
	  else
        printf "\r$(tput setaf 49)[POLL]${reset} Querying network lease table (Attempt $((loop_counter + 1))/45).$(tput el)"
        remote_vps_ip=$(ANSIBLE_HOST_KEY_CHECKING=False \
	      ANSIBLE_SSH_TIMEOUT=3 \
          ANSIBLE_GATHERING=explicit \
          ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
          ansible "$target_host" \
            -i /etc/one-click/fleet/inventory.yml \
            -u oneclick --become \
            -m shell -a "virsh net-dhcp-leases \"$mode_int\" | awk -v m='$target_mac' '\$3==m {print \$5}' | cut -d'/' -f1" 2>/dev/null \
            | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
	  fi
	fi
	if [[ "$network_mode" != "public" ]]; then
      if [ -n "${remote_vps_ip:-${local_vps_ip}}" ]; then
        break
      fi
	else
  	  if [[ -n "$public_ip" ]]; then
	    break
	  fi
	fi
    loop_counter=$((loop_counter + 1))
    sleep 2
  done
  if [[ -n "$saved_err_trap" ]]; then
    eval "$saved_err_trap"
  else
    trap - ERR
  fi
  set -e
  if [[ "$network_mode" != "public" ]]; then
    target_vps_ip="${local_vps_ip:-${remote_vps_ip:-${vps_private_ip:-}}}"
  else
    target_vps_ip="${public_ip///*}"
  fi
  if [[ -z "$target_vps_ip" ]]; then
    if [[ "$network_mode" == "public" ]]; then
	  error "Failed to bond $target_vps_ip"
	else
      error "Target failed to broadcast a DHCP lease request in time."
	fi
    exit 1
  fi
  echo
  if [[ "$network_mode" != "public" ]]; then
    success "Captured Target DHCP Allocated Address: [$target_vps_ip]"
  else
    success "IP [$target_vps_ip] will be binded to the build"
  fi
  sleep 2
  info "Finalizing the build of $vps_name ($target_vps_ip)"
  set +e
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    info "Initiating local hypervisor deployment for ${vps_name}."
	virsh autostart $vps_name &> /dev/null || true
    sleep 2
    if sudo virsh start $vps_name &> /dev/null; then
      sleep 20
      ssh_ready=0
    else
      sleep 20
      if ! ping -c1 ${target_vps_ip%%/*} &> /dev/null; then
        error "$vps_name is down"
        return 1
      fi
    fi
    sleep 15
    ssh_ready=0
    counter=0
    local_reset_check="/tmp/reset-check-${vps_name}"
    if [[ -z "$target_vps_ip" ]]; then
      error "Failed to resolve valid target IP address mapping properties for ${vps_name}"
      return 1
    fi
    warn "Please wait! This may take some time."
    while [ $counter -lt 50 ]; do
      if ssh -i /etc/one-click/fleet/keys/id_ed25519 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=2 \
        -o PasswordAuthentication=no \
         oneclick@"$target_vps_ip" "echo HEALTH_CHECK_OK" &> /dev/null; then
          ssh_ready=1
          break
      else
        if [[ ! -f "$local_reset_check" ]]; then
          touch "$local_reset_check"
          virsh reset "$vps_name"
          sleep 20
        fi
      fi
      counter=$((counter + 1))
      sleep 2
    done
    rm -f "$local_reset_check"
    if [ "$ssh_ready" -ne 1 ]; then
      error "Local boot validation timed out. Target guest $vps_name is unresponsive."
      return 1
    fi
    success "Guest network active. Executing payload."
    ssh \
      -i /etc/one-click/fleet/keys/id_ed25519 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
        oneclick@"$target_vps_ip" << EOC
if command -v apt-get >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y -o DPkg::Lock::Timeout=120 \
    wireguard-tools \
    curl \
    qemu-guest-agent \
    iptables
elif command -v dnf >/dev/null; then
  sudo dnf clean all
  sudo dnf -y install epel-release || true
  sudo dnf -y config-manager --set-enabled crb 2>/dev/null || true
  sudo dnf makecache
  sudo dnf install -y \
    wireguard-tools \
    curl \
    qemu-guest-agent \
    iptables-services
elif command -v yum >/dev/null; then
  sudo yum install -y \
    epel-release || true
  sudo yum install -y \
    wireguard-tools \
    curl \
    qemu-guest-agent \
    iptables-services
fi
sudo systemctl daemon-reload
echo "$(cat $fleet_root/keys/id_ed25519.pub)" >> /home/oneclick/.ssh/authorized_keys
sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
sudo systemctl enable --now wg-quick@one-click 2>/dev/null || true
EOC

    success "Local guest kvm node ${vps_name} deployed successfully!"
  else
    info "Initiating remote hypervisor deployment for ${vps_name}."
    warn "Please wait! This may take some time."
    ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        sudo virsh autostart $vps_name &> /dev/null || true
        sleep 2
        if sudo virsh start $vps_name &> /dev/null; then
          sleep 20
          ssh_ready=0
        else
          if ! ping -c1 $remote_vps_ip &> /dev/null; then
            echo \"[ERROR] $vps_name is down\"
          fi
        fi
        counter=0
        while [ \$counter -lt 30 ]; do
          if ssh -i /home/oneclick/.ssh/id_ed25519 \\
            -o StrictHostKeyChecking=no \\
            -o UserKnownHostsFile=/dev/null \\
            -o ConnectTimeout=2 \\
            -o PasswordAuthentication=no \\
             oneclick@$remote_vps_ip \"echo HEALTH_CHECK_OK\" &> /dev/null; then
              ssh_ready=1
              break
          else
            if [[ ! -f reset-check ]]; then
              touch reset-check
			  echo \"Health Check \$counter\"
			  if [[ \"\$counter\" =~ ^[2468]\$ || \"\$counter\" =~ ^[0-9][24680] ]]; then
                sudo virsh reset $vps_name
			  fi
              sleep 20
            fi
          fi
          counter=\$((\$counter + 1))
          sleep 2
        done
        rm -f reset-check
        ssh \\
          -i /home/oneclick/.ssh/id_ed25519 \\
          -o StrictHostKeyChecking=no \\
          -o UserKnownHostsFile=/dev/null \\
          oneclick@$remote_vps_ip << 'EOC'
if command -v apt-get >/dev/null; then
  while sudo fuser /var/lib/dpkg/lock-frontends >/dev/null 2>&1; do
    sleep 2
  done
  sudo apt-get update -y
  sudo apt-get install -y -o DPkg::Lock::Timeout=120 \
    wireguard-tools \
    curl \
    qemu-guest-agent \
    iptables
elif command -v dnf >/dev/null; then
  sudo dnf clean all
  sudo dnf -y install epel-release || true
  sudo dnf -y config-manager --set-enabled crb 2>/dev/null || true
  sudo dnf makecache
  sudo dnf install -y \
    wireguard-tools \
    curl \
    qemu-guest-agent\
    iptables-services
elif command -v yum >/dev/null; then
  while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do
    sleep 2
  done
  sudo yum install -y \
    epel-release || true
  sudo yum install -y \
    wireguard-tools \
    curl \
    qemu-guest-agent \
    iptables-services
fi
sudo systemctl daemon-reload
sudo systemctl enable --now qemu-guest-agent 2> /dev/null || true
sudo systemctl enable --now wg-quick@one-click 2> /dev/null || true
sudo wg-quick up one-click 2> /dev/null || true
echo \"$(cat $fleet_root/keys/id_ed25519.pub)\" >> /home/oneclick/.ssh/authorized_keys
echo \"${green}[SUCCESS]${reset} Remote guest kvm node ${vps_name} deployed successfully!\"
EOC
      " 2> /dev/null
  fi
  success "$vps_name built on $target_host successfully."
  sleep 5
  info "Adding $vps_name to fleet"
  fleet_add "$target_vps_ip" "$vps_name" 22 "" "$vps_private_ip" no "vps-peer"
  for current_domain in "${domains_to_provision[@]}"; do
    dns_bind_create_zone "$current_domain"
  done
  if [[ "${is_windows:-}" -eq 1 ]]; then
    while ! nc -z -w2 "$target_vps_ip" 22 &> /dev/null; do
      sleep 2
    done
    info "SSH connection established. Provisioning dependencies."
    warn "Reinstalling to Windows"
    fleet_vps_reinstall ${vps_name} $win_base_image_name $raw_password ${lanuage:-en-GB} $target_vps_ip 1
    info "Tracking Windows installation output for $vps_name."
    if [[ "${sys_ip:-${sys_ipv6}}" == "$CONTROLLER_IP" ]]; then
      console_cmd=(virsh console "$vps_name")
    else
      console_cmd=(virsh -c "qemu+ssh://oneclick@${target_host}/system?keyfile=/etc/one-click/fleet/keys/id_ed25519&no_verify=1" console "$vps_name")
    fi
    "${console_cmd[@]}" 2>&1 | while IFS= read -r line; do
      echo "$line"
      if [[ "$line" == "ONE-CLICK-REINSTALL-COMPLETE" ]]; then
        pkill -f "virsh.*console $vps_name" 2>/dev/null || true
        break
      fi
    done
    set -e
    printf "${cyan}[$(tput setaf 177)WINDOWS${reset}-$(tput setaf 197)VPS${cyan}] ${blue}%s${reset}\n" \
      "=================================================================" \
      "             ${green}WINDOWS SERVER VPS DEPLOYED${reset}" \
      "=================================================================" \
      "${cyan}Instance Name:${reset}     $vps_name" \
      "${cyan}Hypervisor Node:${reset}   $target_host" \
      "${cyan}Operating System${reset}   $base_image_name" \
      "${cyan}Target IP:${reset}         $target_vps_ip" \
      "${cyan}Cluster Mesh IP:${reset}   $vps_private_ip" \
      "${cyan}Remote Desktop:${reset}    RDP Port 3389" \
      "${cyan}User Account:${reset}      Administrator" \
      "${cyan}Access Password:${reset}   $raw_password" \
      "================================================================="
    success "Windows Virtual Private Server $vps_name successfully spawned on target host: $target_host!"
    info "" "Preparing visual finalization of $vps_name installation."
    fleet_vps_web_console "$vps_name" "$target_host"
    return 0
  else
    info "Ensuring One-Click Binaries on $vps_name"
    printf "${cyan}[$(tput setaf 177)ONE-CLICK${reset}-$(tput setaf 197)DEPLOY${cyan}] ${blue}%s${reset}\n" \
      "=================================================================" \
      "         ${lime}INSTALLING ONE-CLICK ON $vps_name${reset}" \
      "================================================================="
    set +e
    fl_ssh "${vps_private_ip:-${target_vps_ip}}"
    set -e
    sleep 5
    clear
    printf "$(tput setaf 197)[VPS] ${blue}%s${reset}\n" \
      "=================================================================" \
      "                ${green}VIRTUAL PRIVATE SERVER DEPLOYED${reset}" \
      "=================================================================" \
      "${cyan}Instance Name:${reset}     $vps_name" \
      "${cyan}Hypervisor Node:${reset}   $target_host" \
      "${cyan}Operating System${reset}   $base_image_name" \
      "${cyan}Network Profile:${reset}   ${network_mode^^}"
    if [[ "$network_mode" == "public" ]]; then
      echo -e "$(tput setaf 197)[VPS] ${cyan}Public Static IP:${reset}  ${public_ip%%/*}"
    else
      echo -e "$(tput setaf 197)[VPS] ${cyan}NAT Internal IP:${reset}   ${remote_vps_ip:-${local_vps_ip}}"
    fi
    printf "$(tput setaf 197)[VPS] ${blue}%s${reset}\n" \
      "${cyan}Cluster Mesh IP:${reset}   $vps_private_ip" \
      "${cyan}Mesh Routing GW:${reset}   10.10.0.1" \
      "${cyan}Resource Profile:${reset}  $vps_cpu Cores / $vps_ram MB RAM / $disk_size Disk" \
      "${cyan}User Account:${reset}      oneclick" \
      "${cyan}Access Password:${reset}   $raw_password" \
      "================================================================="
    success "Virtual private server $vps_name successfully spawned on target host: $target_host!"
    exit 0
  fi
  rm -f "/tmp/build_${clean_vps_name}" 2>/dev/null || true
}
write_win_files() {
  local dir="$1"
  pass_admin="$2"
  mkdir -p "$dir/payload/winpe" "$dir/payload/windows"
  cat > "$dir/payload/winpe/Autounattend.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Prepare One-Click Windows boot files</Description>
          <Path>cmd.exe /c "for %D in (D: E: F: G: H: I: J: K: L: M:) do @if exist %D\oneclick-winpe.cmd call %D\oneclick-winpe.cmd"</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
</unattend>
EOF
  cat > "$dir/payload/winpe/oneclick-winpe.cmd" <<'EOF'
@echo off
setlocal EnableExtensions
echo [ONECLICK] Preparing Windows UEFI boot environment.
> X:\oneclick-diskpart.txt echo select disk 0
>>X:\oneclick-diskpart.txt echo select partition 1
>>X:\oneclick-diskpart.txt echo assign letter=S
>>X:\oneclick-diskpart.txt echo select partition 3
>>X:\oneclick-diskpart.txt echo assign letter=W
>>X:\oneclick-diskpart.txt echo exit
diskpart /s X:\oneclick-diskpart.txt
if errorlevel 1 goto :fail
if not exist W:\Windows\System32\winload.efi goto :fail
bcdboot W:\Windows /s S: /f UEFI /l en-US
if errorlevel 1 goto :fail
if not exist S:\EFI\Microsoft\Boot\bootmgfw.efi goto :fail
mkdir S:\EFI\Boot 2>nul
copy /y S:\EFI\Microsoft\Boot\bootmgfw.efi S:\EFI\Boot\bootx64.efi >nul
if errorlevel 1 goto :fail
if not exist S:\EFI\Microsoft\Boot\BCD goto :fail
if not exist S:\EFI\Boot\bootx64.efi goto :fail
> W:\OneClick\BCD_READY echo OK
echo [ONECLICK] BCD and UEFI loader created successfully.
wpeutil shutdown
exit /b 0
:fail
echo [ONECLICK] ERROR: Failed to prepare Windows boot files.
if exist W:\OneClick (
  > W:\OneClick\BUILD_FAILED echo WinPE BCDBoot stage failed.
)
wpeutil shutdown
exit /b 1
EOF
  cat > "$dir/payload/windows/Unattend.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <ComputerName>*</ComputerName>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>${pass_admin}</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <AutoLogon>
        <Password>
          <Value>${pass_admin}</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <Username>Administrator</Username>
        <LogonCount>1</LogonCount>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Provision One-Click master image</Description>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\OneClick\setup.ps1</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
EOF
  cat > "$dir/payload/windows/setup.ps1" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Root = "C:\OneClick"
$Log  = Join-Path $Root "setup.log"
function Log([string]$Message) {
    $line = "$(Get-Date -Format s) $Message"
    $line | Tee-Object -FilePath $Log -Append
}
try {
    Log "Starting One-Click master provisioning."
    if (Test-Path "$Root\VirtIO") {
        Log "Installing staged VirtIO drivers into the Windows driver store."

        $driverInfs = Get-ChildItem "$Root\VirtIO" -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue

        if (!$driverInfs) {
            throw "No staged VirtIO INF files were found."
        }

        foreach ($inf in $driverInfs) {
            Log "Installing VirtIO driver: $($inf.FullName)"

            $p = Start-Process pnputil.exe `
                -ArgumentList "/add-driver `"$($inf.FullName)`" /install" `
                -Wait -PassThru -NoNewWindow

            Log "pnputil exit code for $($inf.Name): $($p.ExitCode)"

            if ($p.ExitCode -notin @(0, 259, 1641, 3010)) {
                throw "VirtIO driver installation failed: $($inf.FullName) [$($p.ExitCode)]"
            }
        }
    }
    $qemuGa = Get-ChildItem "$Root\guest-agent" -Filter "qemu-ga-x86_64.msi" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -First 1
    if ($qemuGa) {
        Log "Installing QEMU Guest Agent."
        $p = Start-Process msiexec.exe `
            -ArgumentList "/i `"$qemuGa`" /qn /norestart /l*v `"$Root\qemu-ga.log`"" `
            -Wait -PassThru
        if ($p.ExitCode -notin @(0, 1641, 3010)) {
            throw "QEMU Guest Agent installation failed: $($p.ExitCode)"
        }
    }
    $wgMsi = Get-ChildItem "$Root\WireGuard" -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -First 1
    if ($wgMsi) {
        Log "Installing staged WireGuard package."
        $p = Start-Process msiexec.exe `
            -ArgumentList "/i `"$wgMsi`" /qn /norestart DO_NOT_LAUNCH=1 /l*v `"$Root\wireguard.log`"" `
            -Wait -PassThru
        if ($p.ExitCode -notin @(0, 1641, 3010)) {
            throw "WireGuard installation failed: $($p.ExitCode)"
        }
    }
    $cloudbaseMsi = Join-Path $Root "CloudbaseInitSetup_Stable_x64.msi"
    if (!(Test-Path $cloudbaseMsi)) {
        throw "Cloudbase-Init MSI is missing: $cloudbaseMsi"
    }
    Log "Installing Cloudbase-Init."
    $p = Start-Process msiexec.exe `
        -ArgumentList "/i `"$cloudbaseMsi`" /qn /norestart RUNSERVICEASLOCALSYSTEM=1 /l*v `"$Root\cloudbase-init.log`"" `
        -Wait -PassThru
    Log "Cloudbase-Init installer exit code: $($p.ExitCode)"
    if ($p.ExitCode -notin @(0, 1641, 3010)) {
        throw "Cloudbase-Init installation failed: $($p.ExitCode)"
    }

    $cbRoot = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
    if (!(Test-Path $cbRoot)) {
        $cbRoot = "C:\Program Files (x86)\Cloudbase Solutions\Cloudbase-Init"
    }
    if (!(Test-Path $cbRoot)) {
        throw "Cloudbase-Init installation directory was not found."
    }
    $service = Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue
    if ($service) {
        Set-Service -Name cloudbase-init -StartupType Automatic
    }
    try {
        Get-NetConnectionProfile -ErrorAction Stop |
            Where-Object { $_.NetworkCategory -eq 'Public' } |
            Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
    }
    catch {
        Log "Network profile was not ready yet: $_"
    }
    Enable-NetFirewallRule -DisplayGroup "Core Networking" -ErrorAction SilentlyContinue
    Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -ErrorAction SilentlyContinue
    $finalize = Join-Path $Root "finalize.ps1"
    if (!(Test-Path $finalize)) {
        throw "Finalization script is missing: $finalize"
    }
    Log "Registering boot-validation/finalization task."
    $taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$finalize`""
    & schtasks.exe /Create /TN "OneClickFinalize" /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCommand /F | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create OneClickFinalize scheduled task."
    }
    "OK" | Set-Content "$Root\STAGE1_READY"
    Log "Stage 1 complete. Shutting down for fresh-NVRAM/VirtIO validation."
    shutdown.exe /s /t 3 /f
}
catch {
    Log "FATAL: $_"
    "$_" | Set-Content "$Root\BUILD_FAILED"
    shutdown.exe /s /t 5 /f
    exit 1
}
EOF
  cat > "$dir/payload/windows/finalize.ps1" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$Root = "C:\OneClick"
$Log  = Join-Path $Root "finalize.log"
function Log([string]$Message) {
    $line = "$(Get-Date -Format s) $Message"
    $line | Tee-Object -FilePath $Log -Append
}
try {
    Log "Fresh-NVRAM/VirtIO boot reached Windows successfully."

    if (!(Test-Path "$Root\STAGE1_READY")) {
        throw "STAGE1_READY marker is missing."
    }
    & schtasks.exe /Delete /TN "OneClickFinalize" /F 2>$null | Out-Null
    $virtioDisk = Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Model -match 'VirtIO|Red Hat' -or
            $_.PNPDeviceID -match 'VEN_1AF4'
        }
    if (!$virtioDisk -and (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
        $virtioDisk = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FriendlyName -match 'VirtIO|Red Hat' -or
                $_.InstanceId -match '^PCI\\VEN_1AF4'
            }
    }
    if (!$virtioDisk) {
        throw "No active VirtIO storage device was detected during validation boot."
    }
    "OK" | Set-Content "$Root\VIRTIO_BOOT_OK"
    $cbRoot = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
    if (!(Test-Path $cbRoot)) {
        $cbRoot = "C:\Program Files (x86)\Cloudbase Solutions\Cloudbase-Init"
    }
    if (!(Test-Path $cbRoot)) {
        throw "Cloudbase-Init directory is missing."
    }
    $cloudbaseUnattend = "$Root\CloudbaseUnattend.xml"
    if (!(Test-Path $cloudbaseUnattend)) {
        throw "One-Click Sysprep unattend file is missing."
    }
    if (!(Test-Path $cloudbaseUnattend)) {
        throw "No Cloudbase/Sysprep unattend file is available."
    }
    Remove-Item "C:\Windows\Panther\Unattend.xml" -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\System32\Sysprep\unattend.xml" -Force -ErrorAction SilentlyContinue
    Log "Running Sysprep /generalize /oobe /quit."
    $sysprep = "$env:WINDIR\System32\Sysprep\Sysprep.exe"
    $args = "/generalize /oobe /quit /quiet /unattend:`"$cloudbaseUnattend`""
    $p = Start-Process $sysprep -ArgumentList $args -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "Sysprep failed with exit code $($p.ExitCode)."
    }
    "OK" | Set-Content "$Root\MASTER_READY"
    Log "Sysprep completed successfully. Master is sealed."
    Log "Powering off without another boot."
    shutdown.exe /s /t 3 /f
}
catch {
    Log "FATAL: $_"
    "$_" | Set-Content "$Root\BUILD_FAILED"
    shutdown.exe /s /t 5 /f
    exit 1
}
EOF
  cat > "$dir/payload/windows/CloudbaseUnattend.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend"
          xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="generalize">
    <component name="Microsoft-Windows-PnpSysprep"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Deployment"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Cloudbase-Init specialize</Description>
          <Path>cmd.exe /c &quot;&quot;C:\Program Files\Cloudbase Solutions\Cloudbase-Init\Python\Scripts\cloudbase-init.exe&quot; --config-file &quot;C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf&quot;&quot;</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="oobeSystem">
      <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
        <SkipMachineOOBE>true</SkipMachineOOBE>
        <SkipUserOOBE>true</SkipUserOOBE>
      </OOBE>
    </component>
  </settings>
</unattend>
EOF
}
prep_windows() {
  . "/etc/one-click/fleet/controller.env"
  local win_iso_url="${1:?Windows ISO URL is required}"
  local out_name="${2:-win2022}"
  local target_host="${3:?Target host is required}"
  local dest_dir="/etc/one-click/virtualization/images"
  local build_dir="/etc/one-click/tmp/win_builder_${out_name}"
  local password="$4"
  local required_gb="${5:-${REQ_BUFFER:-50}}"
  local storage_script="/etc/one-click/virtualization/initialize_storage.sh"
  local virtio_iso_url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.262-1/virtio-win.iso"
  local cloudbase_url="https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
  local local_remote_script="/tmp/oneclick_remote_build_${out_name}.sh"
  local clean_dest_dir="${dest_dir%/}"
  local ssh_key=""
  local ssh_key_arg=()
  local target_ip="$target_host"
  local inv_ip=""
  local free_kb free_gb build_pid
  mkdir -p "$build_dir" "$dest_dir"
  vg_name=one_click_vg
  if ! vgdisplay "$vg_name" &>/dev/null; then
    write_peer_vps_vg_allocation
    bash "$storage_script" \
      "$disk_size" \
      "$vps_name" \
      "$dest_dir" \
      "$VG_ALLOC" \
      "$ALLOC_THRESHOLD"
  fi
  if [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  elif [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  fi
  [ -n "$ssh_key" ] && ssh_key_arg=(-i "$ssh_key")
  if [ -f "/etc/one-click/fleet/inventory.yml" ]; then
    inv_ip="$(grep -A 5 "$target_host" /etc/one-click/fleet/inventory.yml | grep ansible_host | head -n1 | awk '{print $2}')"
    [ -n "$inv_ip" ] && target_ip="$inv_ip"
  fi
  info "Checking disk space in $dest_dir on $target_host."
  if [[ "$target_host" == "$(hostname -s)" || "${target_ip//[][]}" == "${CONTROLLER_IP:-}" ]]; then
    free_kb=$(df -kP "$dest_dir" | awk 'NR==2 {print $4}')
  else
    free_kb=$(ssh -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" "oneclick@${target_ip//[][]}" \
      "df -kP '$dest_dir' | awk 'NR==2 {print \\$4}'") || return 1
  fi
  free_gb=$(( free_kb / 1024 / 1024 ))
  info "Free space on $target_host: ${free_gb} GB | Required buffer: ${required_gb} GB"
  if [ "$free_gb" -lt "$required_gb" ]; then
    error "Insufficient disk space in $dest_dir on $target_host to build $out_name template!"
    return 1
  fi
  success "Adequate disk space for $out_name verified."
  write_win_files "$build_dir" "$password" || {
    error "Failed to generate Windows build files."
    return 1
  }
  cat > "$local_remote_script" <<'REMOTE_SCRIPT_EOF'
#!/usr/bin/env bash
# Written by Chike Egbuna for One-Click ToolBox
set -euo pipefail
BUILD_DIR="$1"
DEST_DIR="$2"
OUT_NAME="$3"
WIN_ISO_URL="$4"
VIRTIO_ISO_URL="$5"
CLOUDBASE_URL="$6"
DISK_SIZE="$7"
TARGET_HOST="$8"
VM_NAME="builder-${OUT_NAME}"
RAW_IMAGE="${BUILD_DIR}/builder_raw.qcow2"
FINAL_IMAGE="${DEST_DIR}/${OUT_NAME}.qcow2"
ISO_CACHE_DIR="/etc/one-click/iso_cache"
OEM_ISO="${BUILD_DIR}/oneclick-winpe.iso"
NOPROMPT_ISO="${BUILD_DIR}/windows-noprompt.iso"
NBD_DEV=""
red=$(tput setaf 1 2>/dev/null || true)
green=$(tput setaf 2 2>/dev/null || true)
blue=$(tput setaf 4 2>/dev/null || true)
lime=$(tput setaf 193 2>/dev/null || true)
yellow=$(tput setaf 3 2>/dev/null || true)
cyan=$(tput setaf 6 2>/dev/null || true)
reset=$(tput sgr0 2>/dev/null || true)
log()  { echo "${blue}[INFO]${lime} $*"; }
ok()   { echo "${green}[OK]${lime} $*"; }
warn() { echo "${yellow}[WARN]${lime} $*"; }
fail() { echo "${red}[ERROR]${lime} $*" >&2; exit 1; }
cleanup() {
  sudo virsh destroy "$VM_NAME" 2>/dev/null || true
  sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
  if [ -n "${NBD_DEV:-}" ]; then
    sudo umount "${BUILD_DIR}/sys_mnt" 2>/dev/null || true
    sudo umount "${BUILD_DIR}/efi_mnt" 2>/dev/null || true
    sudo qemu-nbd --disconnect "$NBD_DEV" 2>/dev/null || true
  fi
  sudo umount "${BUILD_DIR}/win_mnt" 2>/dev/null || true
  sudo umount "${BUILD_DIR}/virtio_mnt" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
install_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y \
      qemu-utils qemu-system-x86 libvirt-clients virtinst ovmf \
      wimtools ntfs-3g dosfstools parted curl xorriso
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y \
      qemu-img qemu-kvm libvirt-client virt-install edk2-ovmf \
      ntfs-3g dosfstools parted curl xorriso
    if ! command -v wimapply >/dev/null 2>&1 && ! command -v wimlib-imagex >/dev/null 2>&1; then
      sudo dnf install -y wimlib wimlib-tools 2>/dev/null || true
    fi
  fi
  for c in qemu-img qemu-nbd virt-install virsh parted mkfs.vfat mkfs.ntfs curl; do
    command -v "$c" >/dev/null 2>&1 || fail "Required command missing: $c"
  done
  if command -v wimapply >/dev/null 2>&1; then
    WIMAPPLY=(/usr/local/bin/wimapply)
    WIMINFO=(wiminfo)
  elif command -v wimlib-imagex >/dev/null 2>&1; then
    WIMAPPLY=(wimlib-imagex apply)
    WIMINFO=(wimlib-imagex info)
  else
    fail "wimlib/wimtools is required."
  fi
}
wait_shutoff() {
  local label="$1"
  local timeout="${2:-10000}"
  local state=""
  local seen_domain=0
  local elapsed=0
  local i
  log "Waiting for $label VM to initialize."
  for i in {1..120}; do
    if sudo virsh dominfo "$VM_NAME" &>/dev/null; then
      seen_domain=1
      state=$(sudo virsh domstate "$VM_NAME" 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs || true)
      echo "${green}[READY]${lime} $label VM initialized (${state:-unknown}).${reset}"
      break
    fi
    sleep 1
  done
  if [ "$seen_domain" -ne 1 ]; then
    fail "$label VM failed to initialize within 120 seconds."
  fi
  log "Waiting for $label to power off."
  while true; do
    state=$(sudo virsh domstate "$VM_NAME" 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs || true)
    case "$state" in
      "shut off")
        ok "$label powered off."
        return 0
        ;;
      "crashed")
        fail "$label crashed."
        ;;
      "")
        sleep 2
        if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
          fail "$label disappeared unexpectedly."
        fi
        ;;
    esac
    if [ "$elapsed" -ge "$timeout" ]; then
      fail "$label timed out after ${timeout} seconds."
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}
mount_image() {
  sudo modprobe nbd max_part=16 2>/dev/null || true
  NBD_DEV=""
  local dev
  for dev in /dev/nbd{0..15}; do
    if sudo qemu-nbd --connect="$dev" --format=qcow2 "$RAW_IMAGE" 2>/dev/null; then
      NBD_DEV="$dev"
      break
    fi
  done
  [ -n "$NBD_DEV" ] || fail "No free NBD device."
  sudo partprobe "$NBD_DEV" || true
  sleep 2
}
unmount_image() {
  sync
  sudo umount "${BUILD_DIR}/sys_mnt" 2>/dev/null || true
  sudo umount "${BUILD_DIR}/efi_mnt" 2>/dev/null || true
  sudo qemu-nbd --disconnect "$NBD_DEV"
  NBD_DEV=""
}
check_marker() {
  local marker="$1"
  mount_image
  sudo mount "${NBD_DEV}p3" "${BUILD_DIR}/sys_mnt"
  if [ ! -f "${BUILD_DIR}/sys_mnt/OneClick/${marker}" ]; then
    if [ -f "${BUILD_DIR}/sys_mnt/OneClick/BUILD_FAILED" ]; then
      echo "----- Windows build failure -----"
      sudo cat "${BUILD_DIR}/sys_mnt/OneClick/BUILD_FAILED" || true
      echo "---------------------------------"
    fi
    unmount_image
    fail "Windows marker missing: ${marker}"
  fi
  unmount_image
  ok "Verified Windows marker: ${marker}"
}
printf "%s\n" \
  "${lime}=================================================================" \
  "${cyan}[SYSPREP]${lime} Starting Windows Gold $OUT_NAME Template Builder" \
  "${yellow}[WARN]${lime} This will create a Windows Gold image for future use" \
  "=================================================================${reset}"
echo "${blue}[INFO]${lime} Installing required disk/servicing tools on target hypervisor."
install_deps
sudo mkdir -p "$BUILD_DIR" "$DEST_DIR" "$ISO_CACHE_DIR"
sudo chown -R "$(id -u):$(id -g)" "$BUILD_DIR" "$DEST_DIR"
mkdir -p "$BUILD_DIR/win_mnt" "$BUILD_DIR/virtio_mnt" "$BUILD_DIR/sys_mnt" "$BUILD_DIR/efi_mnt"
log "Downloading/caching installation media."
if [ ! -s "$ISO_CACHE_DIR/${OUT_NAME}.iso" ]; then
  sudo curl -fL --retry 5 --retry-delay 3 -o "$ISO_CACHE_DIR/${OUT_NAME}.iso.part" "$WIN_ISO_URL" 2> /dev/null
  sudo mv "$ISO_CACHE_DIR/${OUT_NAME}.iso.part" "$ISO_CACHE_DIR/${OUT_NAME}.iso"
fi
if [ ! -s "$ISO_CACHE_DIR/virtio-win.iso" ]; then
  sudo curl -fL --retry 5 --retry-delay 3 -o "$ISO_CACHE_DIR/virtio-win.iso.part" "$VIRTIO_ISO_URL"
  sudo mv "$ISO_CACHE_DIR/virtio-win.iso.part" "$ISO_CACHE_DIR/virtio-win.iso"
fi
if [ ! -s "$BUILD_DIR/payload/windows/CloudbaseInitSetup_Stable_x64.msi" ]; then
  curl -fL --retry 5 --retry-delay 3 -o "$BUILD_DIR/payload/windows/CloudbaseInitSetup_Stable_x64.msi" "$CLOUDBASE_URL"
fi
sudo mount -o loop,ro "$ISO_CACHE_DIR/${OUT_NAME}.iso" "$BUILD_DIR/win_mnt"
sudo mount -o loop,ro "$ISO_CACHE_DIR/virtio-win.iso" "$BUILD_DIR/virtio_mnt"
WIM_FILE=$(find "$BUILD_DIR/win_mnt/sources" -maxdepth 1 -type f \( -iname install.wim -o -iname install.esd \) -print -quit)
[ -f "$WIM_FILE" ] || fail "install.wim/install.esd was not found."
WIM_INDEX="${WIM_INDEX:-2}"
"${WIMINFO[@]}" "$WIM_FILE" "$WIM_INDEX" >/dev/null 2>&1 || {
  "${WIMINFO[@]}" "$WIM_FILE" || true
  fail "WIM index $WIM_INDEX does not exist. Set WIM_INDEX explicitly."
}
log "Creating ${DISK_SIZE}G GPT QCOW2 master workspace."
rm -f "$RAW_IMAGE" "$FINAL_IMAGE"
qemu-img create -f qcow2 "$RAW_IMAGE" "${DISK_SIZE}G"
mount_image
sudo parted -s "$NBD_DEV" mklabel gpt
sudo parted -s "$NBD_DEV" mkpart ESP fat32 1MiB 261MiB
sudo parted -s "$NBD_DEV" set 1 esp on
sudo parted -s "$NBD_DEV" mkpart MSR 261MiB 277MiB
sudo parted -s "$NBD_DEV" set 2 msftres on
sudo parted -s "$NBD_DEV" mkpart Primary ntfs 277MiB 100%
sudo parted -s "$NBD_DEV" set 3 msftdata on
sudo partprobe "$NBD_DEV"
sleep 2
sudo mkfs.vfat -F32 -n EFI "${NBD_DEV}p1"
sudo mkfs.ntfs -f -L Windows "${NBD_DEV}p3"
log "Applying Windows WIM index $WIM_INDEX."
sudo "${WIMAPPLY[@]}" "$WIM_FILE" "$WIM_INDEX" "${NBD_DEV}p3" 2> /dev/null
sudo mount "${NBD_DEV}p3" "$BUILD_DIR/sys_mnt"
sudo mount "${NBD_DEV}p1" "$BUILD_DIR/efi_mnt"
[ -f "$BUILD_DIR/sys_mnt/Windows/System32/winload.efi" ] || fail "Applied image is missing winload.efi."
log "Staging provisioning payload."
sudo mkdir -p \
  "$BUILD_DIR/sys_mnt/OneClick/VirtIO" \
  "$BUILD_DIR/sys_mnt/OneClick/guest-agent" \
  "$BUILD_DIR/sys_mnt/OneClick/WireGuard" \
  "$BUILD_DIR/sys_mnt/Windows/Panther"
sudo cp -f "$BUILD_DIR/payload/windows/Unattend.xml" "$BUILD_DIR/sys_mnt/Windows/Panther/Unattend.xml"
sudo cp -f "$BUILD_DIR/payload/windows/setup.ps1" "$BUILD_DIR/sys_mnt/OneClick/setup.ps1"
sudo cp -f "$BUILD_DIR/payload/windows/finalize.ps1" "$BUILD_DIR/sys_mnt/OneClick/finalize.ps1"
sudo cp -f "$BUILD_DIR/payload/windows/CloudbaseUnattend.xml" "$BUILD_DIR/sys_mnt/OneClick/CloudbaseUnattend.xml"
sudo cp -f "$BUILD_DIR/payload/windows/CloudbaseInitSetup_Stable_x64.msi" "$BUILD_DIR/sys_mnt/OneClick/CloudbaseInitSetup_Stable_x64.msi"
case "${OUT_NAME,,}" in
  *2025*) VIRTIO_WINVER="2k25" ;;
  *)      VIRTIO_WINVER="2k22" ;;
esac
log "Staging VirtIO drivers for ${VIRTIO_WINVER}/amd64 only."
for driver in viostor vioscsi NetKVM vioserial Balloon; do
  src="$BUILD_DIR/virtio_mnt/$driver/$VIRTIO_WINVER/amd64"
  if [ -d "$src" ]; then
    sudo mkdir -p "$BUILD_DIR/sys_mnt/OneClick/VirtIO/$driver"
    sudo cp -a "$src/." "$BUILD_DIR/sys_mnt/OneClick/VirtIO/$driver/"
  else
    warn "VirtIO driver path not present: $driver/$VIRTIO_WINVER/amd64"
  fi
done
[ -f "$BUILD_DIR/sys_mnt/OneClick/VirtIO/viostor/viostor.inf" ] ||   fail "Required VirtIO storage driver was not staged."
qga=$(find "$BUILD_DIR/virtio_mnt" -type f -iname 'qemu-ga-x86_64.msi' -print -quit)
[ -n "$qga" ] && sudo cp -f "$qga" "$BUILD_DIR/sys_mnt/OneClick/guest-agent/"
log "Downloading current WireGuard Windows MSI for the gold image."
wg_index=$(curl -fsSL "https://download.wireguard.com/windows-client/")
wg_msi=$(printf '%s\n' "$wg_index" |
  grep -oE 'wireguard-amd64-[0-9.]+\.msi' |
  sort -Vu |
  tail -n1)
if [ -n "$wg_msi" ]; then
  curl -fL --retry 5 --retry-delay 3     -o "$BUILD_DIR/sys_mnt/OneClick/WireGuard/$wg_msi"     "https://download.wireguard.com/windows-client/$wg_msi"
else
  fail "Could not discover the current WireGuard amd64 MSI."
fi
sync
unmount_image
log "Preparing no-prompt UEFI Windows media for Stage 1."
NOPROMPT_BOOT="$(
  find "$BUILD_DIR/win_mnt" -type f -iname 'efisys_noprompt.bin' -print -quit
)"
[ -n "$NOPROMPT_BOOT" ] || \
  fail "Microsoft efisys_noprompt.bin was not found in the supplied Windows ISO."
NOPROMPT_REL="${NOPROMPT_BOOT#"$BUILD_DIR/win_mnt/"}"
ETFSBOOT="$(
  find "$BUILD_DIR/win_mnt" -type f -iname 'etfsboot.com' -print -quit
)"
rm -f "$NOPROMPT_ISO"
if [ -n "$ETFSBOOT" ]; then
  ETFSBOOT_REL="${ETFSBOOT#"$BUILD_DIR/win_mnt/"}"
  log "Creating BIOS/UEFI no-prompt Stage-1 Windows ISO."
  xorriso -as mkisofs -quiet \
    -iso-level 3 \
    -J -joliet-long -R \
    -V ONECLICK_WIN \
    -b "$ETFSBOOT_REL" \
    -no-emul-boot \
    -boot-load-size 8 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e "$NOPROMPT_REL" \
    -no-emul-boot \
    -o "$NOPROMPT_ISO" \
    "$BUILD_DIR/win_mnt"
else
  log "Creating UEFI-only no-prompt Stage-1 Windows ISO."
  xorriso -as mkisofs -quiet \
    -iso-level 3 \
    -J -joliet-long -R \
    -V ONECLICK_WIN \
    -eltorito-platform efi \
    -e "$NOPROMPT_REL" \
    -no-emul-boot \
    -o "$NOPROMPT_ISO" \
    "$BUILD_DIR/win_mnt"
fi
[ -s "$NOPROMPT_ISO" ] || \
  fail "Failed to create the no-prompt Stage-1 Windows ISO."
ok "No-prompt Windows Stage-1 ISO created."
sudo umount "$BUILD_DIR/win_mnt"
sudo umount "$BUILD_DIR/virtio_mnt"
log "Creating WinPE helper ISO."
rm -rf "$BUILD_DIR/winpe_iso_root"
mkdir -p "$BUILD_DIR/winpe_iso_root"
cp -f "$BUILD_DIR/payload/winpe/Autounattend.xml" "$BUILD_DIR/winpe_iso_root/Autounattend.xml"
cp -f "$BUILD_DIR/payload/winpe/oneclick-winpe.cmd" "$BUILD_DIR/winpe_iso_root/oneclick-winpe.cmd"
xorriso -as mkisofs -quiet \
  -o "$OEM_ISO" \
  -V ONECLICK \
  -J -R \
  "$BUILD_DIR/winpe_iso_root"
printf "%s\n" \
  "${cyan}=================================================================${reset}" \
  "${green}                  WINDOWS BOOT PREPARATION                   ${reset}" \
  "${cyan}=================================================================${reset}" \
  "Stage:           ${yellow}1 of 3${reset}" \
  "Action:          ${yellow}Generate Windows BCD from WinPE${reset}" \
  "Disk Bus:        ${yellow}SATA${reset}" \
  "Firmware:        ${yellow}UEFI${yellow}" \
  "TO TRACK SETUP, CLICK ${lime}Ctrl + b + d${yellow} TO DETACH THE TMUX SESSION" \
  "RUN THE FOLLOWING COMMAND TO LAUNCH A VNC SESSION" \
  "${lime}one-click --vnc "$VM_NAME" $TARGET_HOST" \
  "${cyan}=================================================================${reset}"
log "Boot 1/3: creating Windows BCD from WinPE."
sudo virsh destroy "$VM_NAME" 2>/dev/null || true
sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
sudo virt-install \
  --name "$VM_NAME" \
  --memory 4096 \
  --vcpus 4 \
  --cpu host-passthrough \
  --os-variant win2k22 \
  --disk "path=$RAW_IMAGE,format=qcow2,bus=sata,boot_order=3" \
  --disk "path=$NOPROMPT_ISO,device=cdrom,bus=sata,boot_order=1" \
  --disk "path=$OEM_ISO,device=cdrom,bus=sata,boot_order=2" \
  --boot uefi \
  --graphics vnc,listen=127.0.0.1 \
  --noautoconsole \
  --wait -1 &
P1=$!
wait_shutoff "WinPE BCDBoot stage"
wait "$P1" 2>/dev/null || true
sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
check_marker BCD_READY
printf "%s\n" \
  "${cyan}=================================================================${reset}" \
  "${green}                WINDOWS MASTER PROVISIONING                  ${reset}" \
  "${cyan}=================================================================${reset}" \
  "Stage:           ${yellow}2 of 3${reset}" \
  "Action:          ${yellow}Install injected One-Click components${reset}" \
  "Storage Bus:     ${yellow}SATA${reset}" \
  "Network Model:   ${yellow}e1000e" \
  "TO TRACK SETUP, CLICK ${lime}Ctrl + b + d${yellow} TO DETACH THE TMUX SESSION" \
  "RUN THE FOLLOWING COMMAND TO LAUNCH A VNC SESSION" \
  "${lime}one-click --vnc "$VM_NAME" $TARGET_HOST" \
  "${cyan}=================================================================${lime}"
log "Boot 2/3: provisioning Windows master."
VIRTIO_TEST_DISK="$BUILD_DIR/virtio_test.qcow2"
rm -f "$VIRTIO_TEST_DISK"
qemu-img create -f qcow2 "$VIRTIO_TEST_DISK" 1G
sudo virt-install \
  --name "$VM_NAME" \
  --memory 4096 \
  --vcpus 4 \
  --cpu host-passthrough \
  --os-variant win2k22 \
  --disk "path=$RAW_IMAGE,format=qcow2,bus=sata,boot_order=1" \
  --disk "path=$VIRTIO_TEST_DISK,format=qcow2,bus=virtio" \
  --boot uefi \
  --network network=oneclick-nat,model=e1000e \
  --graphics vnc,listen=127.0.0.1 \
  --noautoconsole \
  --import \
  --wait -1 &
P2=$!
wait_shutoff "Windows provisioning stage"
wait "$P2" 2>/dev/null || true
rm -f "$VIRTIO_TEST_DISK"
sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
check_marker STAGE1_READY
printf "%s\n" \
  "${cyan}=================================================================${reset}" \
  "${green}             FRESH UEFI / VIRTIO VALIDATION BOOT             ${reset}" \
  "${cyan}=================================================================${reset}" \
  "Stage:           ${yellow}3 of 3${reset}" \
  "Action:          ${yellow}Validate, Generalize and Seal Master${reset}" \
  "Storage Bus:     ${yellow}VirtIO${reset}" \
  "NVRAM:           ${yellow}Fresh${reset}" \
  "Install Media:   ${yellow}Detached" \
  "TO TRACK SETUP, CLICK ${lime}Ctrl + b + d${yellow} TO DETACH THE TMUX SESSION" \
  "RUN THE FOLLOWING COMMAND TO LAUNCH A VNC SESSION" \
  "${lime}one-click --vnc "$VM_NAME" $TARGET_HOST" \
  "${cyan}=================================================================${lime}"
log "Boot 3/3: fresh-NVRAM + VirtIO validation and final Sysprep."
sudo virt-install \
  --name "$VM_NAME" \
  --memory 4096 \
  --vcpus 4 \
  --cpu host-passthrough \
  --os-variant win2k22 \
  --disk "path=$RAW_IMAGE,format=qcow2,bus=virtio,boot_order=1" \
  --boot uefi \
  --network network=oneclick-nat,model=virtio \
  --graphics vnc,listen=127.0.0.1 \
  --noautoconsole \
  --import \
  --wait -1 &
P3=$!
wait_shutoff "fresh-NVRAM/VirtIO validation + Sysprep"
wait "$P3" 2>/dev/null || true
sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null || true
check_marker VIRTIO_BOOT_OK
check_marker MASTER_READY
log "Validating uncompressed source image."
qemu-img check "$RAW_IMAGE"
threads=$(( $(nproc) / 2 ))
[ "$threads" -lt 1 ] && threads=1
log "Compressing final master image."
qemu-img convert -p -m "$threads" -f qcow2 -O qcow2 -c "$RAW_IMAGE" "$FINAL_IMAGE"
qemu-img check "$FINAL_IMAGE"
qemu-img info "$FINAL_IMAGE"
[ -s "$FINAL_IMAGE" ] || fail "Final QCOW2 was not created."
printf '%s\n' \
  "${cyan}=================================================================${reset}" \
  "${green}                 MASTER IMAGE BUILD SUMMARY                  ${reset}" \
  "${cyan}=================================================================${reset}" \
  "Image:           ${yellow}${FINAL_IMAGE}${reset}" \
  "BCD:             ${green}VERIFIED${reset}" \
  "Fresh UEFI:      ${green}VERIFIED${reset}" \
  "VirtIO Storage:  ${green}VERIFIED${reset}" \
  "Cloudbase-Init:  ${green}INSTALLED${reset}" \
  "Sysprep:         ${green}GENERALIZED${reset}" \
  "Format:          ${yellow}QCOW2 Compressed${reset}" \
  "${cyan}=================================================================${reset}"
echo "${green}[SUCCESS]${lime} Windows Master Template Created Successfully!${reset}"
trap - EXIT INT TERM
cleanup
rm -rf "$BUILD_DIR"
exit 0
REMOTE_SCRIPT_EOF
  chmod +x "$local_remote_script"
  local is_local=0
  if [[ "$target_host" == "$(hostname -s)" || "${target_ip//[][]}" == "${CONTROLLER_IP:-}" ]]; then
    is_local=1
  fi
  if (( is_local )); then
    info "Launching local Windows master build."
    bash "$local_remote_script" \
      "$build_dir" \
      "$clean_dest_dir" \
      "$out_name" \
      "$win_iso_url" \
      "$virtio_iso_url" \
      "$cloudbase_url" \
      "$REQ_BUFFER" \
      "$target_host" || {
        error "Windows master-image build failed."
        rm -f "$local_remote_script"
        return 1
      }
  else
    info "Transferring Windows build payload to $target_host."
    ssh -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" "oneclick@${target_ip//[][]}" \
      "sudo mkdir -p '$build_dir/payload/winpe' '$build_dir/payload/windows' && sudo chown -R oneclick:oneclick '$build_dir'" || return 1
    scp -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" \
      "$build_dir/payload/winpe/Autounattend.xml" \
      "$build_dir/payload/winpe/oneclick-winpe.cmd" \
      "oneclick@${target_ip//[][]}:$build_dir/payload/winpe/" || return 1
    scp -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" \
      "$build_dir/payload/windows/Unattend.xml" \
      "$build_dir/payload/windows/setup.ps1" \
      "$build_dir/payload/windows/finalize.ps1" \
      "$build_dir/payload/windows/CloudbaseUnattend.xml" \
      "oneclick@${target_ip//[][]}:$build_dir/payload/windows/" || return 1
    if [ -d "$build_dir/wireguard_staged" ]; then
      scp -r -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" \
        "$build_dir/wireguard_staged" \
        "oneclick@${target_ip//[][]}:$build_dir/" || return 1
    fi
    scp -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" \
      "$local_remote_script" \
      "oneclick@${target_ip//[][]}:/tmp/remote_build.sh" || return 1
    info "Launching remote Windows master build."
    ssh -tt -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" "oneclick@${target_ip//[][]}" \
      "sudo bash /tmp/remote_build.sh \
        '$build_dir' \
        '$clean_dest_dir' \
        '$out_name' \
        '$win_iso_url' \
        '$virtio_iso_url' \
        '$cloudbase_url'" || {
          error "Remote Windows master-image build failed."
          rm -f "$local_remote_script"
          return 1
        }
    ssh -o StrictHostKeyChecking=no "${ssh_key_arg[@]}" "oneclick@${target_ip//[][]}" \
      "sudo rm -f /tmp/remote_build.sh" 2>/dev/null || true
  fi
  rm -f "$local_remote_script"
  printf "$(tput setaf 166)[SYSPREP]${reset} %s\n" \
    "=================================================================" \
    "${green}Gold $out_name Template Created:${reset}" \
    "Location: ${dest_dir}/${out_name}.qcow2" \
    "Host: $target_host" \
    "Format: QCOW2 Compressed" \
    "BCD: Verified" \
    "UEFI: Fresh NVRAM Verified" \
    "VirtIO: Boot Verified" \
    "Sysprep: Generalized" \
    "================================================================="
  return 0
}
fleet_vps_web_console() {
  . "/etc/one-click/fleet/controller.env"
  local vps_name="$1"
  local target_host="${2:-}"
  local inventory_file=/etc/one-click/fleet/inventory.yml
  if [[ -z "$target_host" ]]; then
    local json_inv="/etc/one-click/virtualization/inventory.json"
    local target_host
    target_host=$(jq -r --arg vm "${vps_name:-$target}" '.[] | select(.name == $vm) | .host' "$json_inv")
    local facts=$(ansible-inventory -i "${inventory:-${inventory_file}}" --list) || true
    if [[ -z "$target_host" ]]; then
      warn "$vps_name is not a VM"
      return 1
    fi
  fi
  local session_timeout="${VNC_WEB_TIMEOUT}"
  local inventory_file=/etc/one-click/fleet/inventory.yml
  info "Initializing ephemeral Web VNC console for $vps_name on $target_host."
  if ! command -v websockify &> /dev/null; then
    info "Installing Websockify."
    if command -v apt-get &> /dev/null; then
      "$pkg_mgr" update -qq
      "$pkg_mgr" install -y novnc websockify &> /dev/null
    else
      "$pkg_mgr" install -y novnc python3-websockify &> /dev/null
    fi
  fi
  local vnc_display
  if [[ "$target_host" == $(hostname -s) ]]; then
    vnc_display=$(virsh vncdisplay $vps_name 2>/dev/null | sed -E 's/^([^:]*)?(:[0-9]+)/\2/' | tr -d ' \r\n')
  else
    vnc_display=$(ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "virsh vncdisplay $vps_name 2>/dev/null" 2>/dev/null | grep -E '^:[0-9]+' | tr -d ' \r\n')
  fi
  if [[ -z "$vnc_display" ]]; then
    error "VM $vps_name has no active graphical display."
    return 1
  fi
  local display_num="${vnc_display#:}"
  local remote_vnc_port=$((5900 + display_num))
  local target_ip
  target_ip=$(awk -v host="$target_host" '
    $0 ~ "^[[:space:]]*" host ":" { found=1; next }
    found && /^[[:space:]]*ansible_host:/ { print $2; exit }
    found && /^[[:space:]]*[A-Za-z0-9_-]+:/ && !/ansible_/ { found=0 }
  ' "$inventory_file" | tr -d ' "\027')
  if [[ -z "$target_ip" ]]; then
    error "Could not resolve IP for $target_host in $inventory_file"
    return 1
  fi
  local proxy_port tunnel_port
  proxy_port=$(shuf -i 5900-5999 -n 1)
  while fuser "${proxy_port}/tcp" &>/dev/null; do
    proxy_port=$(shuf -i 5900-5999 -n 1)
  done
  tunnel_port=$(shuf -i 59000-59999 -n 1)
  while fuser "${tunnel_port}/tcp" &>/dev/null; do
    tunnel_port=$(shuf -i 59000-59999 -n 1)
  done
  local token
  token=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24)
  info "Establishing internal tunnel (127.0.0.1:$tunnel_port -> $target_ip:$remote_vnc_port)."
  ssh -f -N -L "127.0.0.1:${tunnel_port}:127.0.0.1:${remote_vnc_port}" \
    -i /etc/one-click/fleet/keys/id_ed25519 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "oneclick@${target_ip}"
  local token_dir="/etc/one-click/vnc_tokens"
  mkdir -p "$token_dir"
  echo "${token}: 127.0.0.1:${tunnel_port}" > "${token_dir}/${token}.tokens"
  nohup websockify \
    --web /usr/share/novnc \
    --token-plugin TokenFile \
    --token-source "${token_dir}/${token}.tokens" \
    --timeout "${session_timeout}" \
    --heartbeat 30 \
    "[::]:$proxy_port" &>/dev/null &
  local ws_pid=$!
  cleanup_vnc() {
    cleanup_session_pid "${ws_pid:-}"
    cleanup_session_port "${proxy_port:-}"
    cleanup_session_port "${tunnel_port:-}"
    [[ -n "${token:-}" ]] && rm -f "${token_dir}/${token}.tokens"
    [[ -n "${proxy_port:-}" ]] && cleanup_firewall_rules "$proxy_port"
  }
  trap cleanup_vnc ERR INT TERM
  (
    sleep "$session_timeout"
    cleanup_session_pid "$ws_pid"
    cleanup_session_port "$proxy_port"
    cleanup_session_port "$tunnel_port"
    rm -f "${token_dir}/${token}.tokens"
    cleanup_firewall_rules "$proxy_port"
  ) &>/dev/null & disown
  local controller_ip=$CONTROLLER_IP
  read -rp "${cyan}[USER] ${orange}WOULD YOU LIKE TO LOCK DOWN THE VNC SESSION TO A SPECIFIC IP:${reset} " lock_vnc
  lock_vnc="${lock_vnc,,}"
  load_rule_engine
  if [[ "$lock_vnc" =~ ^(y|yes)$ ]]; then
    recorded_ip="$(awk '{print $1}' <<< $SSH_CLIENT)"
    read -p "Please enter the IP address to grant access to or press enter to use your IP $recorded_ip: " rec_ip
    if [[ -z "$rec_ip" ]]; then
      source_ip="$recorded_ip"
    else
      source_ip="$rec_ip"
    fi
    rule_engine "allow all from ${source_ip} to port ${proxy_port}" -y
    rule_engine "drop port $proxy_port" -y
  else
    rule_engine "allow all to port ${proxy_port}" -y
  fi
  if [[ "$controller_ip" =~ : ]]; then
    controller_ip="[$controller_ip]"
  fi
  info "Starting Web Console proxy on port $proxy_port."
  printf '%s\n' \
    "${cyan}=================================================================${reset}" \
    "${green}               SECURE WEB VNC SESSION INITIALIZED            ${reset}" \
    "${cyan}=================================================================${reset}" \
    "Instance Name:   ${yellow}${vps_name}${reset}" \
    "Hypervisor:      ${yellow}${target_host} (${target_ip})${reset}" \
    "Session Timeout: ${yellow}${session_timeout} seconds${reset}" "" \
    "Access the live console in your web browser via this one-time URL:" \
    "${cyan}http://${controller_ip}:${proxy_port}/vnc.html?path=websockify?token=${token}&autoconnect=true${reset}" \
    "${cyan}=================================================================${reset}" \
    "${yellow}Note: This viewer port will automatically self-destruct after timeout.${reset}" ""
}
cleanup_firewall_session() {
  local session_id="$1"
  local fw line
  [[ -z "$session_id" ]] && return 0
  for fw in iptables ip6tables; do
    command -v "$fw" &>/dev/null || continue
    while :; do
      line=$(
        "$fw" -L INPUT -n --line-numbers 2>/dev/null |
          awk -v tag="oneclick:${session_id}" '
            index($0, tag) {
              print $1
            }
          ' |
          sort -rn |
          head -n1
      )
      [[ -n "$line" ]] || break
      "$fw" -D INPUT "$line" 2>/dev/null || break
    done
  done
}
cleanup_session_port() {
  local port="$1"
  [[ -n "$port" ]] &&
    fuser -k "${port}/tcp" &>/dev/null || true
}
cleanup_session_pid() {
  local pid="$1"
  [[ -n "$pid" ]] &&
    kill "$pid" &>/dev/null || true
}
cleanup_vnc_session() {
  local ws_pid="$1"
  local proxy_port="$2"
  local tunnel_port="$3"
  local token_file="$4"
  local firewall_session="$5"
  cleanup_session_pid "$ws_pid"
  cleanup_session_port "$proxy_port"
  cleanup_session_port "$tunnel_port"
  [[ -n "$token_file" ]] && rm -f "$token_file"
  cleanup_firewall_session "$firewall_session"
}
fleet_vps_reinstall() {
  local vps_name="$1"
  local target_image="$2"
  local raw_password="$3"
  local win_language="${4:-}"
  local target_vps_ip="${5:-}"
  local is_windows=${6:-0}
  local inventory="/etc/one-click/fleet/inventory.yml"
  local clean_os=""
  local os_version_raw=""
  local parsed_string="${target_image,,}"
  local keys=$(sed -En '/ssh_authorized_keys:/{:a;n;/ssh-/{s/[ \t]+- //p};ba}' /etc/one-click/virtualization/deployments/${vps_name}/user_data.yml)
  local archive_dir="/etc/one-click/virtualization/deployments/${vps_name}"
  local archive_dir="/etc/one-click/virtualization/deployments/${vps_name}"
  local local_wg_src="${archive_dir}/one-click.conf"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  parsed_string="${parsed_string#netboot_}"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  ###===SYS-MDDE===###
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller (${sys_ip:-${sys_ipv6}})"
  fi
  ###===END-SYS-MODE===###
  if [[ ! -f "${archive_dir}/user_data.yml" ]]; then
    error "Staged template file missing: ${archive_dir}/user_data.yml"
    return 1
  fi
  if [[ "$parsed_string" =~ ^(windows|win)([0-9]+)$ ]]; then
    clean_os="windows"
    os_version_raw="${BASH_REMATCH[2]}"
    is_windows=1
  elif [[ "$parsed_string" =~ ^([a-zA-Z\.]+)([0-9\.]+)$ ]]; then
    clean_os="${BASH_REMATCH[1]}"
    os_version_raw="${BASH_REMATCH[2]}"
  else
    clean_os="$parsed_string"
    os_version_raw=""
  fi
  declare -A os_map=(
    [anolis]="7.9 8.8 23"
    [opencloudos]="8.8 9.2 23"
    [rocky]="8.10 9.4 10.0"
    [oracle]="8.10 9.4 10.0"
    [almalinux]="8.10 9.4 10.0"
    [centos]="9 10"
    [fnos]="1"
    [nixos]="25.11"
    [fedora]="42 43"
    [debian]="9 10 11 12 13"
    [alpine]="3.20 3.21 3.22 3.23"
    [opensuse]="15.6 16.0 tumbleweed"
    [openeuler]="20.03 22.03 24.03 25.09"
    [ubuntu]="16.04 18.04 20.04 22.04 24.04 25.10"
    [windows]="2012 2016 2019 2022 2025"
    [redhat]="7.9 8.10 9.4"
    [netboot.xyz]=""
    [kali]=""
    [arch]=""
    [gentoo]=""
    [aosc]=""
  )
  if [[ -z "${os_map[$clean_os]+_}" ]]; then
    error "Requested OS flavor '$clean_os' falls outside native platform support bounds."
    return 1
  fi
  local os_version=""
  if [[ -n "$os_version_raw" && -n "${os_map[$clean_os]}" ]]; then
    if grep -qw "$os_version_raw" <<< "${os_map[$clean_os]}"; then
      os_version="$os_version_raw"
    else
      os_version=$(echo "${os_map[$clean_os]}" | tr ' ' '\n' | grep "${os_version_raw}" | sort -V | tail -n 1)
      if [[ -z "$os_version" ]]; then
        os_version=$(echo "${os_map[$clean_os]}" | tr ' ' '\n' | sort -V | tail -n 1)
      fi
    fi
  else
    os_version="$os_version_raw"
  fi
  local iso_name=""
  local iso_url=""
  local WIN_LANG="en-US"
  if [[ "$is_windows" -eq 1 ]]; then
    case "$os_version" in
      2012)
        iso_name="Windows Server 2012 R2 SERVERSTANDARD"
        iso_url="https://software-static.download.prss.microsoft.com/pr/9600.16384.WINBLUE_RTM.130821-1623_X64FRE_SERVER_EVAL_EN-US-IRM_SSS_X64FREE_EN-US_DV5.ISO"
        ;;
      2016)
        iso_name="Windows Server 2016 SERVERSTANDARD"
        iso_url="https://software-static.download.prss.microsoft.com/pr/14393.0.160715-1616.RS1_RELEASE_SERVER_EVAL_X64FRE_EN-US.ISO"
        ;;
      2019)
        iso_name="Windows Server 2019 SERVERSTANDARD"
        iso_url="https://software-static.download.prss.microsoft.com/pr/17763.737.190906-1024.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
        ;;
      2022)
        iso_name="Windows Server 2022 SERVERSTANDARD"
        iso_url="https://software-download.microsoft.com/download/sg/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
        ;;
      2025)
        iso_name="Windows Server 2025 SERVERSTANDARD"
        iso_url="https://software-static.download.prss.microsoft.com/db_stuff/26100.1.240331-1435.ge_release_SERVER_EVAL_x64FRE_en-us.iso"
        ;;
      *) error "Invalid Fleet Windows version context: $os_version"; return 1 ;;
    esac
    case "${win_language,,}" in
      english-us|en-us|us|usa) WIN_LANG="en-US" ;;
      english|en-gb|uk)        WIN_LANG="en-GB" ;;
      chinese|zh-cn)           WIN_LANG="zh-CN" ;;
      zh-tw)                   WIN_LANG="zh-TW" ;;
      french|fr|fr-fr)         WIN_LANG="fr-FR" ;;
      germany|de|de-de)        WIN_LANG="de-DE" ;;
      spain|es|es-es)          WIN_LANG="es-ES" ;;
      japan|jp|ja-jp)          WIN_LANG="ja-JP" ;;
      korea|hr|ko-kr)          WIN_LANG="ko-KR" ;;
      *)                       warn "Invalid language input '$win_language'. Defaulting to en-US." ;;
    esac
  fi
  if [[ ! -f "$local_wg_src" ]]; then
    error "WireGuard configuration profile missing at $local_wg_src. Cannot proceed."
    return 1
  fi
  local install_cmd=""
  info "Packaging WireGuard profile for Linux target [$vps_name]."
    scp -i /etc/one-click/fleet/keys/id_ed25519 \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "$local_wg_src" "oneclick@$target_vps_ip:/tmp/one-click.conf"
  if [[ "$clean_os" == "netboot.xyz" || -z "$os_version" ]]; then
    install_cmd="sudo bash reinstall.sh ${clean_os} \"/tmp/one-click.conf\""
  elif [[ "$is_windows" -eq 1 ]]; then
    install_cmd="sudo bash reinstall.sh windows --image-name \"${iso_name}\" \
      --username \"onclick-admin\" \
      --password \"${raw_password}\" \
      --lang \"${WIN_LANG}\" \
      --iso \"${iso_url}\" \
      --rdp-port 3389"
  else
    install_cmd="sudo bash reinstall.sh ${clean_os} ${os_version} --ssh-key \"${keys}\" \"/tmp/one-click.conf\""
  fi
  info "Resolved Targeting Parameter Context: [${clean_os} ${os_version}]"
  local pass="$target_vps_ip"
  if [[ -z "$pass" ]]; then
    pass=$(awk -v target="$vps_name" '
      $0 ~ "^[[:space:]]*" target ":" {found=1; next}
      found && /^[[:space:]]*ansible_host:/ {print $2; exit}
      found && /^[[:space:]]*[A-Za-z0-9_-]+:/ && !/ansible_/ {found=0}
    ' "$inventory" | tr -d ' "\027')
  fi
  if [[ -z "$pass" ]]; then
    error "Could not resolve operational IP address tracking context for ${vps_name}."
    return 1
  fi
  if [[ -f "$inventory_json" ]] && command -v jq &>/dev/null; then
    local is_vm
    is_vm=$(jq -r --arg target "$vps_name" '
      any(.[];
        (.name == $target or .primary_ip == $target or .cluster_private_ip == $target or .nat_ip == $target)
        and (.host != null and .host != "")
      )
    ' "$inventory_json" 2>/dev/null)
    if [[ "$is_vm" == "true" ]]; then
      local mode=vps
    else
      local mode=hypervisor
    fi
  fi
  info "Triggering unattended target re-image sequence on ${vps_name} [${pass}]."
  local ssh_opts=(
    -i /etc/one-click/fleet/keys/id_ed25519
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout=5
    -q -T
  )
  local ssh_success=1
  ssh "${ssh_opts[@]}" "oneclick@${pass//[][]}" << EOF
    set -e
    rm -f reinstall || true
    cat > reinstall << RST
    (curl -O -s https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -qO- https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh > reinstall.sh ) \
      || { echo "Download failed"; exit 1; }
    chmod +x reinstall.sh || { echo "chmod failed"; exit 1; }
    ${install_cmd} \
      | sed -Eu '/(Password: .)....(.).*/s//\1xxxx\2x/' \
      | sed -Eu "N;s,\nUsername:,\n                         _ _      _    \n  ___  _ __   ___    ___\| \(_\) ___\| \| __\n / _ \\\| '_ \\\ / _ \\\  / __\| \| \|/ __\| \|/ /\n\| \(_\) \| \| \| \|  __/ \| \(__\| \| \| \(__\|   < \n \\\___/\|_\| \|_\|\\\___\|  \\\___\|_\|_\|\\\___\|_\|\\\_\\\&,"

      echo "ONE-CLICK IS AWAITING A REBOOT"
      sleep 3 && sudo reboot || true
RST
      bash reinstall
EOF
  if [[ "$?" -eq 0 ]]; then
    ssh_success=0
  fi
  if [[ "$ssh_success" -eq 0 ]]; then
    success "Fleet peer ${vps_name} has successfully restarteds."
    info "Please use the following VNC console settings to track the rest of the installation." \
      "Or start a new session with ${lime}one-click --vnc $vps_name${reset} to configure Windows if the session has expired."
  else
    error "Reinstall script pipeline failed. Validation barriers refused payload."
    return 1
  fi
  fleet_vps_web_console "$vps_name"
  warn "Tracking live installation."
  fleet_console "$vps_name"
  if [[ "$is_windows" -eq 0 ]]; then
    info "Reconfiguring $vps_name to add back to the fleet"
    while ! nc -z -w2 "$target_vps_ip" 22 &> /dev/null; do
      sleep 2
    done
    info "SSH connection established."
    fleet_vps_peer_reconfigure "$vps_name" "$mode" "$os_version" "$raw_password" "${is_windows:-}"
  fi
}
# ==== Reconfigure Fleet Member ====
fleet_vps_peer_reconfigure() {
  local vps_name="$1"
  local mode="${2:-vps}"
  local new_image_name="$3"
  local fresh_install_pass="$4"
  local is_windows="$5"
  local ledger_file="/etc/one-click/virtualization/inventory.json"
  local archive_dir="/etc/one-click/virtualization/deployments/${vps_name}"
  local local_wg_src="${archive_dir}/one-click.conf"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller (${sys_ip:-${sys_ipv6}})"
  fi
  if [[ ! -f "${archive_dir}/user_data.yml" ]]; then
    error "Staged template file missing: ${archive_dir}/user_data.yml"
    return 1
  fi
  if [[ ! -f "$ledger_file" ]]; then
    error "Central database ledger missing at $ledger_file."
    return 1
  fi
  if [[ -z "$fresh_install_pass" ]]; then
    error "Logic Breach: A valid runtime password must be passed to authenticate post-reinstall."
    return 1
  fi
  if [[ "$is_windows" -eq 1 ]]; then
    info "Target OS is Windows. Waiting for RDP / WinRM port 3389 to initialize."
    ANSIBLE_HOST_KEY_CHECKING=False \
    ansible "$target_host_name" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        until virsh domstate $vps_name | grep -q 'running'; do
          sleep 2
        done
        while ! nc -z $target_vps_nat_ip 3389; do
          sleep 5
        done
        sudo virsh autostart $vps_name &> /dev/null || true
      " &>/dev/null
    success "Windows installation completed. RDP Service active on port 3389."
  else
  # -----------------------------
  info "Harvesting operational metrics and WireGuard configurations."
  local vps_private_ip=$(jq -r ".[] | select(.name == \"$vps_name\") | .cluster_private_ip // empty" "$ledger_file")
  local target_host_ip=$(jq -r ".[] | select(.name == \"$vps_name\") | .host_ip // empty" "$ledger_file")
  local target_vps_nat_ip=$(jq -r ".[] | select(.name == \"$vps_name\") | .nat_ip // empty" "$ledger_file")
  local target_host_name=$(jq -r ".[] | select(.name == \"$vps_name\") | .host // empty" "$ledger_file")
  if [[ ! -f "$local_wg_src" ]]; then
    error "WireGuard configuration profile missing at $local_wg_src. Restoration aborted."
    return 1
  fi
  local controller_pub_key=""
  [[ -f "/etc/one-click/fleet/keys/id_ed25519.pub" ]] && controller_pub_key=$(cat /etc/one-click/fleet/keys/id_ed25519.pub)
  local fleet_target_ip="$target_vps_nat_ip"
  [[ "${mode^^}" == "HYPERVISOR" ]] && fleet_target_ip="$target_host_ip"
  if [[ "${mode,,}" == "vps" ]]; then
    info "Targeting remote hypervisor peer [${target_host_ip}] to coordinate trusted key injection."
    local raw_wg_contents=$(cat "$local_wg_src")

    ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible "$target_host_name" \
	  -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
	    until virsh domstate $vps_name | grep -q 'running'; do
          echo -n '.'
          sleep 2
        done
        while ! nc -z $target_vps_nat_ip 22; do
          sleep 2
        done
		sudo virsh autostart $vps_name &> /dev/null || true
		sleep 2
        if sudo virsh start $vps_name &> /dev/null; then
          sleep 20
          ssh_ready=0
        else
          if ! ping -c1 $remote_vps_ip &> /dev/null; then
            echo \"[ERROR] $vps_name is down\"
          fi
        fi
        sleep 15
        if ! command -v sshpass &>/dev/null; then
		  if command -v apt; then
		    apt-get update
		  fi
		  install_dep "sshpass" "command -v sshpass" "sshpass" "$pkg_mgr"
        fi
        local_hypervisor_pub_key=\$(cat /home/oneclick/.ssh/id_ed25519.pub 2>/dev/null)
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 root@$target_vps_nat_ip << 'EOF'
          mkdir -p /home/oneclick/.ssh /etc/wireguard
          echo 'nameserver 1.1.1.1' > /etc/resolv.conf
          if ! id oneclick &>/dev/null; then
            useradd -m -s /bin/bash oneclick || useradd -m -g wheel oneclick 2>/dev/null
          fi
          echo \"oneclick:${fresh_install_pass}\" | chpasswd
          if getent group wheel &>/dev/null; then
            usermod -aG wheel oneclick
            echo 'oneclick ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/oneclick
          else
            usermod -aG sudo oneclick 2>/dev/null
            echo 'oneclick ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/oneclick
          fi
          echo \"${controller_pub_key}\" >> /home/oneclick/.ssh/authorized_keys
          if [ -n \"\$local_hypervisor_pub_key\" ]; then
            echo \"\$local_hypervisor_pub_key\" >> /home/oneclick/.ssh/authorized_keys
          fi
          echo \"${raw_wg_contents}\" > /etc/wireguard/one-click.conf
          chown -R oneclick /home/oneclick/.ssh 2>/dev/null || chown -R oneclick:wheel /home/oneclick/.ssh
          chmod 700 /home/oneclick/.ssh
          chmod 600 /home/oneclick/.ssh/authorized_keys /etc/wireguard/one-click.conf
          echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-oneclick-vps-routing.conf
          sysctl --system &>/dev/null
          if command -v apt-get >/dev/null; then
            while fuser /var/lib/dpkg/lock-frontends >/dev/null 2>&1; do sleep 2; done
            apt-get update -y
            apt-get install -y wireguard-tools curl qemu-guest-agent iptables &>/dev/null
          elif command -v dnf >/dev/null; then
            dnf clean all
            dnf -y install epel-release || true
            dnf install -y wireguard-tools curl qemu-guest-agent iptables-services &>/dev/null
          elif command -v yum >/dev/null; then
            yum install -y epel-release || true
            yum install -y wireguard-tools curl qemu-guest-agent iptables-services &>/dev/null
          fi
          command -v iptables >/dev/null && iptables -I INPUT -p udp --dport 51821 -j ACCEPT 2>/dev/null || true
          command -v firewall-cmd >/dev/null && firewall-cmd --zone=public --add-port=51821/udp --permanent && firewall-cmd --reload &>/dev/null || true
          systemctl daemon-reload
          systemctl enable --now qemu-guest-agent 2>/dev/null || true
          systemctl enable --now wg-quick@one-click 2>/dev/null || true
EOF
      " &>/dev/null
  fi
  success "Deployment complete."
  info "Adding back to fleet"
  fleet_add "$fleet_target_ip" "$vps_name" 22 "" "$vps_nat_ip" no "vps-peer"
  info "Synchronizing target configuration definitions in database ledger."
  #------------------
  fi
  local updated_json
  if [[ "$is_windows" -eq 1 ]]; then
    updated_json=$(jq "map(if .name == \"$vps_name\" then . + {
      \"image\": \"$new_image_name\",
      \"password\": \"$fresh_install_pass\",
      \"updated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    } else . end)" "$ledger_file")
  else
    updated_json=$(jq "map(if .name == \"$vps_name\" then . + {
      \"image\": \"$new_image_name\",
      \"password\": \"$fresh_install_pass\",
      \"updated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    } else . end)" "$ledger_file")
  fi
  echo "$updated_json" > "$ledger_file"
  sleep 5
  clear
  printf "$(tput setaf 197)[VPS] ${blue}%s${reset}\n" \
    "=================================================================" \
    "                ${green}VIRTUAL PRIVATE SERVER DEPLOYED${reset}" \
    "=================================================================" \
    "${cyan}Instance Name:${reset}     $vps_name" \
    "${cyan}Operating System${reset}   $new_image_name"
  if [[ "$network_mode" == "public" ]]; then
    echo -e "$(tput setaf 197)[VPS] ${cyan}Public Static IP:${reset}  $public_ip"
  else
    echo -e "$(tput setaf 197)[VPS] ${cyan}NAT Internal IP:${reset}   $vps_private_ip"
  fi
  printf "$(tput setaf 197)[VPS] ${blue}%s${reset}\n" \
    "${cyan}Cluster Mesh IP:${reset}   $vps_nat_ip" \
    "${cyan}Mesh Routing GW:${reset}   10.10.0.1" \
    "${cyan}User Account:${reset}      oneclick" \
    "${cyan}Access Password:${reset}   $fresh_install_pass" \
    "================================================================="
  success "Reconfiguration finalized. ${vps_name} has brought up its mesh interface and rejoined the fleet!"
}
# ==== Fleet SSH Login To Peer ====
fleet_ssh() {
  local target="$1"
  local port="${2:-}"
  . "/etc/one-click/fleet/controller.env"
  local inventory="/etc/one-click/fleet/inventory.yml"
  if [[ ! -f "$inventory" ]]; then
    error "Inventory file missing at $inventory"
    return 1
  fi
  local host_details
  host_details=$(awk -v target="$target" '
    $0 ~ "^[[:space:]]*" target ":" { found=1; next }
    found && /^[[:space:]]*ansible_host:/ { host=$2 }
    found && /^[[:space:]]*ansible_port:/ { port=$2 }
    found && /^[[:space:]]*[A-Za-z0-9_-]+:/ && !/ansible_/ { found=0 }
    END { if (host) print host, (port ? port : "22") }
  ' "$inventory" | tr -d '"\027')
  local ip
  local port
  ip=$(echo "$host_details" | awk '{print $1}')
  port=$(echo "$host_details" | awk '{print $2}')
  local ssh_target
  if [[ -n "$ip" ]]; then
    ssh_target="oneclick@$ip"
  else
    ssh_target="oneclick@$target"
    port="22"
  fi
  set +e
  for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
    [[ -e "$key" ]] || continue
    ssh -i "$key" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 "$ssh_target" 2> /dev/null
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  done
  set -e
  if [[ -z "$ip" ]]; then
    error "No mapped IP found for $target."
    return 1
  fi
  error "Trust mesh execution failure: Connection timed out or credentials rejected by $target on port $port."
  return 1
}
fl_ssh() {
  local target="$1"
  local port="${2:-22}"
  . "/etc/one-click/fleet/controller.env"
  local inventory="/etc/one-click/fleet/inventory.yml"
  if [[ ! -f "$inventory" ]]; then
    error "Inventory file missing at $inventory"
    return 1
  fi
  local host_details
  host_details=$(awk -v target="$target" '
    $0 ~ "^[[:space:]]*" target ":" { found=1; next }
    found && /^[[:space:]]*ansible_host:/ { host=$2 }
    found && /^[[:space:]]*ansible_port:/ { port=$2 }
    found && /^[[:space:]]*[A-Za-z0-9_-]+:/ && !/ansible_/ { found=0 }
    END { if (host) print host, (port ? port : "22") }
  ' "$inventory" | tr -d '"\027')
  local ip
  local port
  ip=$(echo "$host_details" | awk '{print $1}')
  port=$(echo "$host_details" | awk '{print $2}')
  local ssh_target
  if [[ -n "$ip" ]]; then
    ssh_target="oneclick@$ip"
  else
    ssh_target="oneclick@$target"
    port="22"
  fi
  for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
    [[ -e "$key" ]] || continue
    ssh -tt -i "$key" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "$ssh_target" "
      echo -e \"nameserver 10.10.0.1\\nnameserver 8.8.8.8\\nnameserver 1.1.1.1\\nnameserver fd00:99aa::1\\nnameserver 2001:4860:4860::8888\" | sudo tee -a /etc/resolv.conf >/dev/null
	  if [[ -d /tmp ]]; then
	    oc_path=/tmp/one-click.sh
	  else
        oc_path=/root/one-click.sh
	  fi
	  if [ ! -f /usr/local/bin/one-click ]; then
	    sudo curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o \"\$oc_path\" && \
          sudo bash \"\$oc_path\" setup && \
          sudo rm -f \"\$oc_path\"
	  fi
	  exit 0
	"
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  done
  error "Trust mesh execution failure: Connection timed out or credentials rejected by $target on port $port."
  return 1
}
fleet_console() {
  local target port
  target="$1"
  port="${2:-}"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  inventory="/etc/one-click/fleet/inventory.yml"
  json_inv="/etc/one-click/virtualization/inventory.json"
  if [[ ! -f "$inventory" ]]; then
    error "Inventory file missing at $inventory"
    return 1
  fi
  local parent_host
  parent_host=$(jq -r --arg vm "$target" '.[] | select(.name == $vm) | .host' "$json_inv")
  local facts=$(ansible-inventory -i "$inventory" --list)
  if [[ -z "$parent_host" ]]; then
    warn "$target is not a VM"
	return 1
  fi
  local host_details hypervisor
  local hypervisor=$(echo "$facts" | jq -r --arg host "$parent_host" '._meta.hostvars[$host].ansible_host // empty')
  host_details=$(awk -v target="$target" '
    $0 ~ "^[[:space:]]*" target ":" { found=1; next }
    found && /^[[:space:]]*ansible_host:/ { host=$2 }
    found && /^[[:space:]]*ansible_port:/ { port=$2 }
    found && /^[[:space:]]*[A-Za-z0-9_-]+:/ && !/ansible_/ { found=0 }
    END { if (host) print host, (port ? port : "22") }
  ' "$inventory" | tr -d '"\027')
  local ip
  local port
  ip=$(echo "$host_details" | awk '{print $1}')
  if [[ "$hypervisor" =~ : ]]; then
    hypervisor="[${hypervisor}]"
  fi
  port=$(echo "$host_details" | awk '{print $2}')
  info "Prepaing Console permissions on hypervisor host: ($parent_host - $hypervisor)"
  if [[ "$parent_host" == $(hostname -s) && "$hypervisor" == "$CONTROLLER_IP" ]]; then
    active=$(if [[ "$(id)" =~ libvirt ]]; then echo yes; fi)
  else
    active=$(ssh -i /etc/one-click/fleet/keys/id_ed25519 -o StrictHostKeyChecking=no oneclick@${hypervisor//[][]} "if [[ \"\$(id)\" =~ libvirt ]]; then echo yes; fi")
  fi
  if [[ "$active" != "yes" ]]; then
    ANSIBLE_HOST_KEY_CHECKING=False
    ANSIBLE_SSH_TIMEOUT=5
    ansible-playbook -i /etc/one-click/fleet/inventory.yml /etc/one-click/fleet/playbooks/vps_console.yml -e "target=$parent_host" &> /dev/null | sed -En "/task/I {
	    N;
		s/.*\[([^]]*).*\n(.*)/$(tput setaf 244)\2 ${blue}=> ${magenta}\1${reset}/p
	  };
	"
  fi
  if ! command -v virsh > /dev/null; then
    if command -v apt > /dev/null; then
      apt -y update | sed -En "s/.*/$(tput setaf 196)[VIRSH] $(tput setaf 277)=> ${magenta} Virsh unavailable. Installing.${reset}/p"
	  apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virsh &> /dev/null
    else
      dnf groupinstall -y "Virtualization Host" &> /dev/vull
      dnf install -y libvirt-client | sed -En "s/.*/$(tput setaf 196)[VIRSH] $(tput setaf 277)=> ${magenta} Virsh unavailable. Installing./p"
    fi
  fi
  for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
    [[ -e "$key" ]] || continue
	if [[ "${ip}" == "$CONTROLLER_IP" ]]; then
      virsh console "$target"
	  if [[ $? -eq 0 ]]; then
        return 0
      fi
	else
      virsh -c "qemu+ssh://oneclick@${hypervisor}/system?keyfile=${key}&no_verify=1" console "$target"
      if [[ $? -eq 0 ]]; then
        return 0
      fi
	fi
  done
  if [[ -z "$ip" ]]; then
    error "No mapped IP found for $target."
    return 1
  fi
  error "Trust mesh execution failure: Connection timed out or credentials rejected by $target on port $port."
  return 1
}
fleet_vps_destroy() {
  local vps_name="$1"
  local target_host="${2:-}"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller (${sys_ip:-${sys_ipv6}})"
  fi
  if [[ -f "/etc/one-click/dns/modules/wireguard_pool.env" ]]; then
    . "/etc/one-click/dns/modules/wireguard_pool.env"
  fi
  if [[ -z "$vps_name" ]]; then
    error "Usage: one-click vps delete -n <vps_name> [-t <target_host>]"
    return 1
  fi
  local clean_vps_name="${vps_name//_win_path/}"
  local ledger_file="/etc/one-click/virtualization/inventory.json"
  local inventory_yaml="/etc/one-click/fleet/inventory.yml"
  local port_state_file="/etc/one-click/virtualization/allocated_ports.db"
  local port_pool_file="/etc/one-click/virtualization/ports_pool.txt"
  if [[ -z "$target_host" ]]; then
    if [[ ! -f "$ledger_file" ]]; then
      error "Inventory ledger file not found at $ledger_file."
      return 1
    fi
    local matching_hosts=()
    mapfile -t matching_hosts < <(jq -r ".[] | select(.name == \"$clean_vps_name\" or .name == \"${clean_vps_name}_win_path\") | .host" "$ledger_file" 2>/dev/null || true)
    if [[ ${#matching_hosts[@]} -eq 0 ]]; then
      error "No records found for VPS '$clean_vps_name' inside inventory ledger."
      return 1
    elif [[ ${#matching_hosts[@]} -eq 1 ]]; then
      target_host="${matching_hosts[0]}"
      info "Detected instance '$clean_vps_name' on hypervisor [$target_host]"
    else
      error "Duplicate instances detected for '$clean_vps_name'. Specify target host with -t."
      return 1
    fi
  fi
  fleet_purge_hypervisor "$clean_vps_name" "$target_host"
  local vps_ip
  vps_ip=$(awk -v name="$clean_vps_name" '/# ==== Peer Node: '"$clean_vps_name"' ====/ {flag=1; next} flag && /AllowedIPs/ {print $3; flag=0}' /etc/wireguard/one-click.conf | cut -d/ -f1)
  if [[ -z "$vps_ip" ]]; then
    vps_ip=$(grep -B 2 -A 2 "$clean_vps_name" /etc/wireguard/one-click.conf 2>/dev/null | grep "AllowedIPs" | awk '{print $3}' | cut -d/ -f1 || true)
  fi
  if [[ -n "$vps_ip" ]]; then
    local peer_key
    peer_key=$(wg show one-click peers 2>/dev/null | grep -B 1 "$vps_ip" | head -n 1 || true)
    if [[ -n "$peer_key" ]]; then
      wg set one-click peer "$peer_key" remove 2>/dev/null || true
    fi
    sed -i "/# ==== Peer Node: ${clean_vps_name} ====/,+7d" /etc/wireguard/one-click.conf 2>/dev/null || true
    wg syncconf one-click <(wg-quick strip one-click 2>/dev/null) &>/dev/null || true
    sed -i "/^${vps_ip}$/d" "${FLEET_USED_IPS_FILE:-/dev/null}" 2>/dev/null || true
    if [[ -f "${FLEET_AVAILABLE_IPS_FILE:-}" ]] && ! grep -q "^${vps_ip}$" "$FLEET_AVAILABLE_IPS_FILE"; then
      echo "$vps_ip" >> "$FLEET_AVAILABLE_IPS_FILE"
      success "Private IP address resource $vps_ip recovered back into master pool."
    fi
  fi
  if [[ -f "$port_state_file" ]]; then
    local assigned_port
    assigned_port=$(grep -E "^(${clean_vps_name}|${clean_vps_name}_win_path):" "$port_state_file" | cut -d: -f2 | head -n 1 || true)
    if [[ -n "$assigned_port" ]]; then
      sed -i -E "/^(${clean_vps_name}|${clean_vps_name}_win_path):/d" "$port_state_file" 2>/dev/null || true
      if [[ -f "$port_pool_file" ]] && ! grep -q "^${assigned_port}$" "$port_pool_file"; then
        echo "$assigned_port" >> "$port_pool_file"
        info "Released proxy port $assigned_port back to $port_pool_file"
      fi
    fi
  fi
  if [[ -f "$ledger_file" ]]; then
    local tmp_json
    tmp_json=$(mktemp "/etc/one-click/virtualization/inventory.XXXXXX.json" 2>/dev/null || echo "${ledger_file}.tmp")
    if jq --arg name "$clean_vps_name" 'map(select(.name != $name and .name != ($name + "_win_path")))' "$ledger_file" > "$tmp_json" 2>/dev/null; then
      mv -f "$tmp_json" "$ledger_file"
      chmod 644 "$ledger_file"
    else
      rm -f "$tmp_json"
      python3 -c "
import json, os
p = '$ledger_file'
n = '$clean_vps_name'
if os.path.exists(p):
    try:
        with open(p, 'r') as f: data = json.load(f)
        filtered = [x for x in data if x.get('name') not in (n, f'{n}_win_path')]
        with open(p + '.tmp', 'w') as f: json.dump(filtered, f, indent=2)
        os.replace(p + '.tmp', p)
    except Exception: pass
" 2>/dev/null || true
    fi
  fi
  if [[ -f "$inventory_yaml" ]]; then
    sed -i "/^[[:space:]]*${clean_vps_name}:/,+2d" "$inventory_yaml" 2>/dev/null || true
    sed -i "/^[[:space:]]*${clean_vps_name}_win_path:/,+2d" "$inventory_yaml" 2>/dev/null || true
  fi
  if [[ -f "/etc/one-click/fleet/state/${clean_vps_name}.conf" ]]; then
    fleet_remove "$clean_vps_name" &>/dev/null || true
  fi
  rm -rf "/etc/one-click/virtualization/deployments/${clean_vps_name}" 2>/dev/null || true
  rm -rf "/etc/one-click/virtualization/staging/${clean_vps_name}" 2>/dev/null || true
  success "VPS instance $clean_vps_name successfully destroyed and erased from footprint."
}
normalize_memory() {
  local mem="$1"
  case "$mem" in
    *G|*g)
      echo $(( ${mem%[Gg]} * 1024 ))
      ;;
    *M|*m)
      echo "${mem%[Mm]}"
      ;;
    *)
      echo "$mem"
      ;;
  esac
}
fleet_vps_image_fetch() {
  local image_url="$1"
  local custom_name="${2:-}"
  local is_windows="${3:-}"
  local host="${4:-}"
  local password="$5"
  local storage_dir="/etc/one-click/virtualization/images"
  mkdir -p "$storage_dir"
  local file_name
  if [[ -n "$custom_name" ]]; then
    file_name="$custom_name"
  else
    file_name=$(basename "$image_url")
  fi
  local destination_path="${storage_dir}/${file_name}"
  if [[ -f "$destination_path" ]]; then
    warn "Image asset '$file_name' is already available in the local cache. Skipping download."
    return 0
  fi
  info "Fetching base cloud image asset from: $image_url"
  printf "${cyan}[DOWNLOAD]${blue} Saving target destination to: ${magenta}${destination_path}${reset}\n"
  if [[ "$is_windows" -eq 1 ]]; then
    prep_windows "$image_url" "${custom_name/.*}" "$host" "$password"
  else
    if curl -L -o "$destination_path" "$image_url"; then
      chmod 644 "$destination_path"
      success "Image '$file_name' successfully fetched and registered into local master storage."
    else
      error "Failed to download cloud image from the remote provider."
      rm -f "$destination_path"
      return 1
    fi
  fi
}
fleet_vps_modify() {
  local vps_name="$1"
  local target_host="$2"
  if [[ -z "$vps_name" || -z "$target_host" ]]; then
    error "Usage: fleet_vps_modify <vps_name> <target_host> [options]"
    echo "Options: -r <ram_mb>  -c <cpu_cores>  -d <expand_size_or_percentage>"
    return 1
  fi
  shift 2
  local new_ram="" new_cpu="" expand_disk=""
  local OPTIND opt
  while getopts "r:c:d:" opt; do
    case "$opt" in
      r) new_ram="$OPTARG"     ;;
      c) new_cpu="$OPTARG"     ;;
      d) expand_disk="$OPTARG" ;;
      *) error "Invalid hardware modification option specified."; return 1 ;;
    esac
  done
  . "/etc/one-click/fleet/controller.env"
  info "Initiating target configuration adjustments for instance: $vps_name."
  local libvirt_cmds=""
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    info "Executing local configuration updates."
    local local_fail=0
    if [[ -n "$new_ram" ]]; then
      local ram_kb=$((new_ram * 1024))
      virsh setmaxmem "$vps_name" "$ram_kb" --config || local_fail=1
      virsh setmem "$vps_name" "$ram_kb" --config || local_fail=1
    fi
    if [[ -n "$new_cpu" ]]; then
      virsh setvcpus "$vps_name" "$new_cpu" --config --maximum || local_fail=1
      virsh setvcpus "$vps_name" "$new_cpu" --config || local_fail=1
    fi
    if [[ -n "$expand_disk" ]]; then
      local target_disk_path="/var/lib/libvirt/images/${vps_name}.qcow2"
      if [[ -f "$target_disk_path" ]]; then
        local current_virtual_bytes
        current_virtual_bytes=$(qemu-img info --output=json "$target_disk_path" | jq -r '."virtual-size"')
        local requested_bytes
        requested_bytes=$(numfmt --from=iec "$expand_disk" 2>/dev/null)
        if [[ -z "$requested_bytes" ]]; then
          error "Invalid storage formatting suffix token passed: $expand_disk (Use format like 20G, 100G)"
          return 1
        fi
        if [[ "$requested_bytes" -le "$current_virtual_bytes" ]]; then
          error "Storage Fault: Shrinking QCOW2 virtual disks is completely blocked to prevent volume corruption."
          echo "Current Virtual Size: $(numfmt --to=iec --format="%.1f" "$current_virtual_bytes")"
          echo "Requested Size:       $(numfmt --to=iec --format="%.1f" "$requested_bytes")"
          return 1
        fi
      fi
      qemu-img resize "$target_disk_path" "$expand_disk" || local_fail=1
      virsh blockresize "$vps_name" "$target_disk_path" "$expand_disk" || local_fail=1
    fi
    if [[ "$local_fail" -eq 0 ]] && virsh list --all | grep -q " $vps_name "; then
      warn "Hardware modifications written locally to XML storage. Please power cycle the VM to apply changes."
    else
      error "Configuration persistence validation failure. One or more local virsh subcommands crashed."
      return 1
    fi
  else
    info "Relaying configuration payload to remote node [$target_host]."
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=5 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "${libvirt_cmds}" &>/dev/null
    success "Configuration adjustments sent successfully to compute target host node [$target_host]."
  fi
}
fleet_vps_list() {
  local json_inventory="/etc/one-click/virtualization/inventory.json"
  if [[ ! -f "$json_inventory" ]]; then
    echo -e "${red}Error: JSON inventory file not found at $json_inventory${reset}"
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    echo -e "${red}Error: 'jq' is required to parse $json_inventory${reset}"
    return 1
  fi
  local vps_names=()
  local hypervisors=()
  local ip_addrs=()
  while IFS='|' read -r v_name h_host v_ip; do
    [[ -n "$v_name" ]] || continue
    vps_names+=("$v_name")
    hypervisors+=("$h_host")
    ip_addrs+=("$v_ip")
  done < <(jq -r '.[] | "\(.name)|\(.host // "N/A")|\(.primary_ip // "N/A")"' "$json_inventory")
  local total_nodes="${#vps_names[@]}"
  if [[ "$total_nodes" -eq 0 ]]; then
    echo -e "${yellow}No VPS instances found in $json_inventory.${reset}"
    return 0
  fi
  printf "${blue}┌──────┬───────────────────┬──────────────────────────┬────────────────────┐${reset}\n"
  printf "${blue}│ %-14s │ %-27s │ %-34s │ %-28s │${reset}\n" \
    "${magenta}#${blue}" "${yellow}VPS NAME${blue}" "${yellow}HYPERVISOR HOST${blue}" "${yellow}IP ADDRESS${blue}"
  printf "${blue}├──────┼───────────────────┼──────────────────────────┼────────────────────┤${reset}\n"
  for ((i = 0; i < total_nodes; i++)); do
    local index=$((i + 1))
    printf "${blue}│ %-14s │ %-27s │ %-34s │ %-28s │${reset}\n" \
      "${magenta}${index}${blue}" \
      "${blue}${vps_names[i]}${blue}" \
      "${blue}${hypervisors[i]}${blue}" \
      "${blue}${ip_addrs[i]}${blue}"
  done
  printf "${blue}│ %-14s │ %-27s │ %-24s │ %-18s │${reset}\n" \
    "${magenta}0${blue}" "${blue}Back to Main Menu${blue}"
  printf "${blue}└──────┴───────────────────┴──────────────────────────┴────────────────────┘${reset}\n"
  local selection
  while true; do
    read -rp "Select a VPS number [0-${total_nodes}] to view it's information: " selection
    if [[ "$selection" == "0" ]]; then
      return 0
    elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= total_nodes )); then
      local selected_vps="${vps_names[$((selection - 1))]}"
      echo -e "${green}Selected VPS:${reset} $selected_vps"
      fleet_vps_info "$selected_vps"
      break
    else
      echo -e "${red}Invalid selection. Please enter a number between 0 and ${total_nodes}.${reset}"
    fi
  done
}
fleet_vps_info() {
  local target_vm="$1"
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local target_host
  target_host=$(jq -r ".[] | select(.name == \"$target_vm\") | .host" "$inventory_json" 2>/dev/null | head -1)
  if [[ -z "$target_host" || "$target_host" == "null" ]]; then
    error "Target VM '$target_vm' could not be resolved to an active cluster hypervisor."
    return 1
  fi
  info "Collecting operational metrics for $target_vm from $target_host."
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  if [[ ! -f "$private_key" ]]; then
    private_key="/home/oneclick/.ssh/id_ed25519"
  fi
  local target_ip
  target_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$target_host" 2>/dev/null | jq -r '.ansible_host // empty')
  if [[ -z "$target_ip" ]]; then
    error "Network Routing Fault: Could not map host '$target_host' to an active IP matrix."
    return 1
  fi
  local metric_payload
  metric_payload=$(ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -c '
    VM_STATE=\$(virsh domstate \"$target_vm\" 2>/dev/null || echo \"UNKNOWN\")
    if [ \"\$VM_STATE\" = \"UNKNOWN\" ]; then
      echo \"ERROR: VM not registered on this node core layer.\"
      exit 1
    fi
    LIVE_MEM=\$(virsh dominfo \"$target_vm\" | grep \"Used memory:\" | awk \"{print \\\$3}\" | tr -d \"[:space:]\")
    CONF_MEM=\$(virsh dominfo \"$target_vm\" | grep \"Max memory:\" | awk \"{print \\\$3}\" | tr -d \"[:space:]\")
    VCPUS=\$(virsh dominfo \"$target_vm\" | grep \"CPU(s):\" | awk \"{print \\\$2}\" | tr -d \"[:space:]\")
    REBOOT_PENDING=\"NO\"
    if [ \"\$VM_STATE\" = \"running\" ] && [ -n \"\$LIVE_MEM\" ] && [ -n \"\$CONF_MEM\" ] && [ \"\$LIVE_MEM\" -ne \"\$CONF_MEM\" ]; then
      REBOOT_PENDING=\"YES\"
    fi
    DISK_PATH=\"/var/lib/libvirt/images/${target_vm}.qcow2\"
    VIRT_SIZE=\"0\"
    DISK_SIZE=\"0\"
    if [ -f \"\$DISK_PATH\" ]; then
      VIRT_SIZE=\$(qemu-img info --output=json \"\$DISK_PATH\" | jq -r \".\\\"virtual-size\\\"\")
      DISK_SIZE=\$(qemu-img info --output=json \"\$DISK_PATH\" | jq -r \".\\\"actual-size\\\"\")
    fi
    VNET_INT=\$(virsh domiflist \"$target_vm\" | grep \"vnet\" | awk \"{print \\\$1}\" | head -n 1)
    RX_BYTES=0
    TX_BYTES=0
    if [ -n \"\$VNET_INT\" ] && [ \"\$VM_STATE\" = \"running\" ]; then
      RX_BYTES=\$(virsh domifstat \"$target_vm\" \"\$VNET_INT\" | grep \"rx bytes\" | awk \"{print \\\$3}\")
      TX_BYTES=\$(virsh domifstat \"$target_vm\" \"\$VNET_INT\" | grep \"tx bytes\" | awk \"{print \\\$3}\")
    fi
    echo \"STATE=\\\"\$VM_STATE\\\"\"
    echo \"LIVEMEM=\\\"\${LIVE_MEM:-0}\\\"\"
    echo \"CONFMEM=\\\"\${CONF_MEM:-0}\\\"\"
    echo \"VCPUS=\\\"\${VCPUS:-0}\\\"\"
    echo \"REBOOT=\\\"\$REBOOT_PENDING\\\"\"
    echo \"VIRTSIZE=\\\"\${VIRT_SIZE:-0}\\\"\"
    echo \"DISKSIZE=\\\"\${DISK_SIZE:-0}\\\"\"
    echo \"RXBYTES=\\\"\${RX_BYTES:-0}\\\"\"
    echo \"TXBYTES=\\\"\${TX_BYTES:-0}\\\"\"
  '")
  if [[ $? -ne 0 || "$metric_payload" == *"ERROR"* ]]; then
    error "Failed to retrieve real-time data metrics from target host subsystem."
    echo "$metric_payload"
    return 1
  fi
  local STATE LIVEMEM CONFMEM VCPUS REBOOT VIRTSIZE DISKSIZE RXBYTES TXBYTES
  eval "$(echo "$metric_payload" | grep -E '^(STATE|LIVEMEM|CONFMEM|VCPUS|REBOOT|VIRTSIZE|DISKSIZE|RXBYTES|TXBYTES)=')"
  local formatted_live_mem="0 KB (VM Offline)"
  if [[ "$LIVEMEM" =~ ^[0-9]+$ ]] && [[ "$LIVEMEM" -gt 0 ]]; then
    formatted_live_mem=$(numfmt --to=iec --from-unit=1024 "$LIVEMEM")
  fi
  local formatted_conf_mem="0 KB"
  if [[ "$CONFMEM" =~ ^[0-9]+$ ]] && [[ "$CONFMEM" -gt 0 ]]; then
    formatted_conf_mem=$(numfmt --to=iec --from-unit=1024 "$CONFMEM")
  fi
  local formatted_virt_disk="0 KB"
  if [[ "$VIRTSIZE" =~ ^[0-9]+$ ]] && [[ "$VIRTSIZE" -gt 0 ]]; then
    formatted_virt_disk=$(numfmt --to=iec "$VIRTSIZE")
  fi
  local formatted_phys_disk="0 KB"
  if [[ "$DISKSIZE" =~ ^[0-9]+$ ]] && [[ "$DISKSIZE" -gt 0 ]]; then
    formatted_phys_disk=$(numfmt --to=iec "$DISKSIZE")
  fi
  local formatted_rx="0 B"
  if [[ "$RXBYTES" =~ ^[0-9]+$ ]] && [[ "$RXBYTES" -gt 0 ]]; then
    formatted_rx=$(numfmt --to=iec "$RXBYTES")
  fi
  local formatted_tx="0 B"
  if [[ "$TXBYTES" =~ ^[0-9]+$ ]] && [[ "$TXBYTES" -gt 0 ]]; then
    formatted_tx=$(numfmt --to=iec "$TXBYTES")
  fi
  local state_color="${red}"
  if [[ "$STATE" == "running" ]]; then
    state_color="${green}"
    STATE="RUNNING"
  else
    state_color="${red}"
    STATE="POWERED OFF"
  fi
  local reboot_output="${green}NO (Persistent Config Synced)${reset}"
  if [[ "$REBOOT" == "YES" ]]; then
    reboot_output="${red}YES (Pending Power Cycle to apply hardware edits)${reset}"
  fi
  clear
  printf '%s\n' \
    "${blue}======================================================================${reset}" \
    "  ${magenta}VIRTUAL SERVER SPECIFICATION LEDGER:${reset}  ${yellow}$target_vm${reset}" \
    "${blue}======================================================================${reset}"

  printf "%-30s %s\n" \
    "Hypervisor Host Location:" "$target_host ($target_ip)" \
    "Current Execution State:" "${state_color}${STATE}${reset}" \
    "Compute Allocation (vCPUs):" "$VCPUS Cores" \
    "Active Running Memory (RAM):" "$formatted_live_mem" \
    "Scheduled Boot Memory (RAM):" "$formatted_conf_mem" \
    "Storage Allocation (Virtual):" "$formatted_virt_disk" \
    "Storage Physical Footprint:" "$formatted_phys_disk (Thin-Pool Sliced)" \
    "Network Traffic Ingress (RX):" "$formatted_rx" \
    "Network Traffic Egress (TX):" "$formatted_tx"

  echo -e "${blue}----------------------------------------------------------------------${reset}"
  printf "%-30s %b\n" "Pending Reboot State:" "$reboot_output"
  echo -e "${blue}======================================================================${reset}"
}
# ==== One-Click Fleet Patching ====
fleet_vps_patch() {
  local target_scope="$1"
  local force_flag="${2:-}"
  . "/etc/one-click/fleet/controller.env"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: Patch operations can only be executed directly from the Controller."
    return 1
  fi
  local ansible_target=""
  if [[ "$target_scope" == "all" ]]; then
    ansible_target="all"
    info "Preparing fleet-wide maintenance across all active peer members."
  else
    ansible_target="$target_scope"
    info "Preparing system maintenance for fleet member: [$ansible_target]."
  fi
  local patch_cmd=""
  if [[ "$force_flag" == "-f" ]]; then
    warn "Full systems patch flag detected (${orange}-f${reset})."
    patch_cmd="
      if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update && apt-get dist-upgrade -y -o Dpkg::Options::='--force-confold'
      elif command -v dnf &>/dev/null; then
        dnf upgrade -y
      elif command -v yum &>/dev/null; then
        yum update -y
      fi
    "
  else
    warn "Security only patches have been selected!"
    patch_cmd="
      if command -v apt-get &>/dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update && apt-get install -y unattended-upgrades && unattended-upgrade -v
      elif command -v dnf &>/dev/null; then
        dnf upgrade --security -y
      elif command -v yum &>/dev/null; then
        yum update --security -y
      fi
    "
  fi
  info "Carrying out paching update to [$1]."
  if ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$ansible_target" \
    -i "$inventory_file" \
    -u oneclick --become \
    -m shell -a "$patch_cmd" < /dev/null 2> /dev/null; then
    success "Maintenance pipeline complete. Target scope [$target_scope] updated successfully."
  else
    error "Patch execution pipeline completed with unhandled host runtime exceptions."
    return 1
  fi
}
# ==== Wireguard For External Devices ====
fleet_wg_add_user() {
  local user_json="/etc/one-click/fleet/wg_user_ledger.json"
  local wg_interface_cfg="/etc/wireguard/one-click.conf"
  if [[ ! -f "/etc/one-click/fleet/controller.env" ]]; then
    error "Please run ${orange}one-click fleet --init${reset} first"
	return 1
  fi
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: User profile allocations must be generated directly on the Controller."
    return 1
  fi
  if [[ ! -f "$user_json" ]]; then
    echo "[]" > "$user_json"
    chmod 600 "$user_json"
  fi
  local user_name="" user_pubkey=""
  while [[ -z "$user_name" ]]; do
    read -rp "${cyan}[USER]:${reset} Enter Username/Identifier for this profile: " user_name
    user_name="${user_name// /_}"
  done
  if jq -e ".[] | select(.username == \"$user_name\")" "$user_json" &>/dev/null; then
    error "An active configuration assignment already exists for user '$user_name'."
    return 1
  fi
  while [[ -z "$user_pubkey" || ${#user_pubkey} -ne 44 ]]; do
    read -rp "${cyan}[USER]:${reset} Paste ${user_name}'s WireGuard Public Key (e.g. from Windows Client): " user_pubkey
  done
  local controller_pubkey
  controller_pubkey=$(wg show one-click public-key 2>/dev/null)
  if [[ -z "$controller_pubkey" && -f "/etc/wireguard/public.key" ]]; then
    controller_pubkey=$(cat /etc/wireguard/public.key)
  fi
  if [[ -z "$controller_pubkey" ]]; then
    error "Failed to read Controller WireGuard public key from system interfaces."
    return 1
  fi
  local allocated_ip=""
  local ip_octet
  info "Scanning subnet registry for free IPs"
  for ip_octet in {1..254}; do
    local test_ip="10.10.255.${ip_octet}"
    if ! jq -e ".[] | select(.allocated_ip == \"$test_ip\")" "$user_json" &>/dev/null; then
      allocated_ip="$test_ip"
      break
    fi
  done
  if [[ -z "$allocated_ip" ]]; then
    error "Subnet Exhaustion: The carved user /24 scope allocation block ($10.10.255.0/24$) has no free IPs remaining."
	info "You can increase  the allocation in $user_json"
    return 1
  fi
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  if jq --arg name "$user_name" --arg ip "$allocated_ip" --arg pub "$user_pubkey" --arg time "$timestamp" \
     '. += [{ "username": $name, "allocated_ip": $ip, "public_key": $pub, "assigned_at": $time }]' \
     "$user_json" > "${user_json}.tmp"; then
     mv "${user_json}.tmp" "$user_json"
  else
     error "Database update failed. Aborting client creation."
     return 1
  fi
  if [[ -f "$wg_interface_cfg" ]]; then
    info "Appending peer configuration block to local interface infrastructure."
    if [[ "$IPv6_ONLY_2_v4" == true ]]; then
      dns_guard="DNS = 10.10.0.1"
    fi
    cat >> "$wg_interface_cfg" <<EOF

# Peer allocation for user: ${user_name}
[Peer]
PublicKey = ${user_pubkey}
AllowedIPs = ${allocated_ip}/32
EOF
    if command -v wg &>/dev/null; then
      wg set one-click peer "$user_pubkey" allowed-ips "${allocated_ip}/32"
    fi
  fi
  printf '%s\n' \
    "${green}┌──────────────────────────────────────────────────────────────────────────────┐${reset}" \
    "  ${yellow}COPY AND PASTE THIS CONFIGURATION INTO THE ENDPOINT CLIENT:${reset}" \
    "${green}└──────────────────────────────────────────────────────────────────────────────┘${reset}\n"

  cat <<EOF
[Interface]
PrivateKey = <User or client generated local private key match>
Address = ${allocated_ip}/16
ListenPort = ${wg_peer_port}
MTU = 1412
${dns_guard:-}

[Peer]
PublicKey = ${controller_pubkey}
Endpoint = ${CONTROLLER_IP}:51821
AllowedIPs = 10.10.0.0/16
PersistentKeepalive = 1
EOF

  echo -e "\n${green}────────────────────────────────────────────────────────────────────────────────${reset}"
  success "Profile for '$user_name' successfully bound to address $allocated_ip/16"
}
fleet_wg_add() {
  local member_target="${1:-}"
  local user_name="${2:-}"
  local user_json="/etc/one-click/fleet/wg_user_ledger.json"
  local ip_pool_file="/etc/one-click/virtualization/available_ips.txt"
  local controller_wg_cfg="/etc/wireguard/one-click.conf"
  if [[ -z "$member_target" || -z "$user_name" ]]; then
    error "Adding hypervisor to fleet failed: Missing target IP or system name."
    return 1
  fi
  if [[ ! -f "/etc/one-click/fleet/controller.env" ]]; then
    error "Please run ${orange}one-click fleet init${reset} first"
    return 1
  fi
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6:-}}" != "${CONTROLLER_IP:-}" ]]; then
    error "Remote allocations must be initiated directly from the Controller."
    return 1
  fi
  if [[ ! -f "$ip_pool_file" ]]; then
    error "IP Pool File missing: Expected to find IP list at $ip_pool_file"
    return 1
  fi
  user_name="${user_name// /_}"
  if [[ ! -f "$user_json" ]]; then
    echo "[]" > "$user_json"
    chmod 600 "$user_json"
  fi
  if jq -e ".[] | select(.username == \"$user_name\")" "$user_json" &>/dev/null; then
    error "An active configuration assignment already exists for user '$user_name'."
    return 1
  fi
  local key_file=""
  if [[ -f "/etc/one-click/fleet/keys/id_ed25519" ]]; then
    key_file="/etc/one-click/fleet/keys/id_ed25519"
  else
    key_file="/home/oneclick/.ssh/id_ed25519"
  fi
  local controller_pubkey=""
  if [[ -f "/etc/wireguard/public.key" ]]; then
    controller_pubkey=$(cat /etc/wireguard/public.key)
  elif command -v wg &>/dev/null && ip link show dev one-click &>/dev/null; then
    controller_pubkey=$(wg show one-click public-key 2>/dev/null)
  fi
  if [[ -z "$controller_pubkey" ]]; then
    error "Failed to retrieve local Controller WireGuard public key from storage."
    return 1
  fi
  info "Connecting to remote fleet member ($member_target) to check environment."
  local remote_pubkey
  remote_pubkey=$(ssh -i "$key_file" "oneclick@$member_target" "sudo wg show one-click public-key 2>/dev/null || sudo cat /etc/wireguard/oneclick-public.key 2>/dev/null" || true)
  if [[ -z "$remote_pubkey" ]]; then
    info "WireGuard not configured on remote host. Running setup."
    ssh -i "$key_file" "oneclick@$member_target" "
    if ! command -v wg &>/dev/null; then
      if command -v apt > /dev/null; then
        sudo apt update -y
	    sudo apt install -y wireguard-tools
      else
        sudo dnf -y install wireguard-tools
      fi
    fi
    mkdir -p /etc/wireguard
    sudo wg genkey | sudo tee /etc/wireguard/oneclick-private.key | sudo wg pubkey | sudo tee /etc/wireguard/oneclick-public.key
    sudo chmod 600 /etc/wireguard/oneclick-private.key
    "
    remote_pubkey=$(ssh -i "$key_file" "oneclick@$member_target" "sudo cat /etc/wireguard/oneclick-public.key")
	remote_privkey=$(ssh -i "$key_file" "oneclick@$member_target" "sudo cat /etc/wireguard/oneclick-private.key")
  fi
  if [[ -z "$remote_pubkey" ]]; then
    error "Failed to generate or read WireGuard public key on remote member host."
    return 1
  fi
  local allocated_ip=""
  local test_ip
  while IFS= read -r test_ip || [[ -n "$test_ip" ]]; do
    test_ip=$(echo "$test_ip" | tr -d '\r' | xargs)
    [[ -z "$test_ip" || "$test_ip" =~ ^# ]] && continue
    if ! jq -e ".[] | select(.allocated_ip == \"$test_ip\")" "$user_json" &>/dev/null; then
      allocated_ip="$test_ip"
      break
    fi
  done < "$ip_pool_file"
  if [[ -z "$allocated_ip" ]]; then
    error "IP Pool Exhaustion: No unassigned IPs remaining inside $ip_pool_file."
    return 1
  fi
  if [[ "$IPv6_ONLY_2_v4" == true ]]; then
    dns_guard="DNS = 10.10.0.1"
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible "$member_target" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        sudo systemctl enable --now systemd-resolved &> /dev/null || true
      " &> /dev/null
  fi
  ips_allowed="AllowedIPs = 10.10.0.0/16"
  info "Provisioning WireGuard interface configuration on remote node ($allocated_ip)."
  if ssh -i "$key_file" "oneclick@$member_target" \
    WG_INTERFACE_CFG="/etc/wireguard/one-click.conf" \
    ALLOCATED_IP="$allocated_ip" \
    CONTROLLER_IP="$CONTROLLER_IP" \
    CONTROLLER_PUBKEY="$controller_pubkey" \
	REMOTE_PRIVATE_KEY="$remote_privkey" \
	IPS_ALLOWED="$ips_allowed" 'bash -s' << 'EOF'

      wg_content=$(cat <<_CONTENT_
[Interface]
PrivateKey = ${REMOTE_PRIVATE_KEY}
Address = ${ALLOCATED_IP}/16
ListenPort = 51821
MTU = 1412
${dns_guard:-}

[Peer]
PublicKey = ${CONTROLLER_PUBKEY}
Endpoint = ${CONTROLLER_IP}:51821
$IPS_ALLOWED
PersistentKeepalive = 25
_CONTENT_
)
    echo "$wg_content" | sudo tee "$WG_INTERFACE_CFG" > /dev/null
	if sudo ip link show dev one-click &>/dev/null; then
      sudo wg-quick down one-click &>/dev/null || true
    fi
    sudo wg-quick up one-click &>/dev/null || true
EOF
  then
    info "Remote node up. Adding peer routing definitions on local Controller."
    if [[ -f "$controller_wg_cfg" ]]; then
      cat >> "$controller_wg_cfg" <<EOF

# Fleet Member: ${user_name} (${member_target})
[Peer]
PublicKey = ${remote_pubkey}
AllowedIPs = ${allocated_ip}/32
EOF
      if ip link show dev one-click &>/dev/null; then
        wg set one-click peer "$remote_pubkey" allowed-ips "${allocated_ip}/32"
      fi
    fi
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq --arg name "$user_name" --arg ip "$allocated_ip" --arg pub "$remote_pubkey" --arg time "$timestamp" --arg node "$member_target" \
       '. += [{ "username": $name, "allocated_ip": $ip, "public_key": $pub, "assigned_at": $time, "remote_node": $node }]' \
       "$user_json" > "${user_json}.tmp" && mv "${user_json}.tmp" "$user_json"
    info "Purging $allocated_ip from pool."
    sed -i "/^${allocated_ip}$/d" "$ip_pool_file"
    success "Fleet member '$user_name' successfully added at $allocated_ip"
  else
    error "Configuration deployment handshake failed on remote target node."
    return 1
  fi
  printf '%s\n' \
    "${green}┌──────────────────────────────────────────────────────────────────────────────┐${reset}" \
    "        ${yellow}WIREGUARD CONNECTIVITY INFO FOR: $member_target${reset}" \
    "${green}└──────────────────────────────────────────────────────────────────────────────┘${reset} "

  cat <<EOF
Host: $user_name
Peer WG Mesh IP: $allocated_ip
EOF

  echo -e "\n${green}────────────────────────────────────────────────────────────────────────────────${reset}"
  sleep 10
  return 0
}
fleet_wg_list_users() {
  local user_json="/etc/one-click/fleet/wg_user_ledger.json"
  if [[ ! -f "/etc/one-click/fleet/controller.env" ]]; then
    error "Please run ${orange}one-click fleet init${reset} first"
	return 1
  fi
  if [[ ! -f "$user_json" || "$(jq '. | length' "$user_json")" -eq 0 ]]; then
    warn "No user allocations found."
    return 0
  fi
  printf "${blue}┌──────────────────────┬──────────────────────┬──────────────────────────────────────────────┐${reset}\n"
  printf "${blue}│ %-30s │ %-30s │ %-54s │${reset}\n" "${yellow}IDENTIFIER / USER${blue}" "${yellow}ALLOCATED IP${blue}" "${yellow}CLIENT PUBLIC KEY${blue}"
  printf "${blue}├──────────────────────┼──────────────────────┼──────────────────────────────────────────────┤${reset}\n"
  while IFS=$'\t' read -r name ip pub; do
    printf "${blue}│ %-20s │ %-20s │ %-44s │${reset}\n" "$name" "$ip" "$pub"
  done < <(jq -r '.[] | "\(.username)\t\(.allocated_ip)\t\(.public_key)"' "$user_json")
  printf "${blue}└──────────────────────┴──────────────────────┴──────────────────────────────────────────────┘${reset}\n"
}
fleet_wg_remove_user() {
  local user_json="/etc/one-click/fleet/wg_user_ledger.json"
  local wg_interface_cfg="/etc/wireguard/wg0.conf"
  if [[ ! -f "/etc/one-click/fleet/controller.env" ]]; then
    error "Please run ${orange}one-click fleet init${reset} first"
	return 1
  fi
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-}" != "${CONTROLLER_IP:-}" ]]; then
    error "Security Violation: User profile de-allocations must be executed directly on the Controller."
    return 1
  fi
  if [[ ! -f "$user_json" || "$(jq '. | length' "$user_json" 2>/dev/null)" -eq 0 ]]; then
    warn "User allocation ledger is empty. No active profiles available for deletion."
    return 0
  fi
  echo -e "\n${orange}--- ACTIVE WIREGUARD USER PROFILES ---${reset}"
  fleet_wg_list_users
  echo
  local target_user=""
  read -rp "${cyan}[USER]:${reset} Enter the Username/Identifier to permanently remove: " target_user
  target_user="${target_user// /_}"
  local user_pubkey
  user_pubkey=$(jq -r ".[] | select(.username == \"$target_user\") | .public_key" "$user_json" 2>/dev/null)
  if [[ -z "$user_pubkey" || "$user_pubkey" == "null" ]]; then
    error "Deletion Failure: User profile matching identifier '$target_user' not found in active ledger."
    return 1
  fi
  read -rp "${yellow}[WARN]:${reset} Are you sure you want to permanently revoke access for '$target_user'? (y|N): " confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { info "De-allocation aborted."; return 0; }
  if command -v wg &>/dev/null; then
    info "Live-purging cryptographic credentials from running network interface."
    wg set wg0 peer "$user_pubkey" remove 2>/dev/null || true
  fi
  if [[ -f "$wg_interface_cfg" ]]; then
    info "Excising configuration block records from static filesystem."
    sed -i "/# Peer allocation for user: ${target_user}/,/^$/{d}" "$wg_interface_cfg"
    sed -i '/^$/N;/^\n$/D' "$wg_interface_cfg"
  fi
  info "Updating allocation ledger tracking maps."
  if jq --arg name "$target_user" 'del(.[] | select(.username == $name))' "$user_json" > "${user_json}.tmp"; then
    mv "${user_json}.tmp" "$user_json"
    success "User context records successfully stripped from management tracking layer."
  else
    error "Failed to safely rewrite tracking ledger databases."
    rm -f "${user_json}.tmp"
    return 1
  fi
  success "Access credentials for '$target_user' have been completely revoked from the fleet."
}
# ================================================ End Of Fleet ============================================== #
# ============================================== Directory Listing ============================================
ls_table() {
  set +u
  local show_all=false
  local OPTIND=1
  while getopts "a" opt; do
    case "$opt" in
      a) show_all=true ;;
      *) return 1 ;;
    esac
  done
  shift $((OPTIND-1))
  local target_path="${1:-.}"
  local items_to_process=()
  # ===== COLLECTION =====
  if [[ -d "$target_path" ]]; then
    while IFS= read -r -d '' entry; do
      items_to_process+=("$entry")
    done < <(find "$target_path" -maxdepth 3 -mindepth 1 -print0 2>/dev/null | sort -z)
  elif [[ -e "$target_path" || -L "$target_path" ]]; then
    items_to_process+=("$target_path")
  fi
  # ===== DATA EXTRACTION =====
  local names=() types=() sizes=() perms=()
  for item in "${items_to_process[@]}"; do
    local base="$(basename "$item")"
    if [[ "$show_all" == "false" && ! -d "$item" ]]; then
      [[ "$base" =~ [0-9_] ]] || continue
    fi
    names+=( "${item#./}" )
    if [[ -L "$item" ]]; then types+=(Symlink)
    elif [[ -d "$item" ]]; then types+=(Directory)
    else types+=(File); fi
    sizes+=( "$(stat -c '%s' "$item" 2>/dev/null || echo 0)" )
    perms+=( "$(stat -c '%A' "$item" 2>/dev/null || echo '?????????')" )
  done
  # ===== TABLE RENDER =====
  [[ ${#names[@]} -eq 0 ]] && { echo "No files found."; set -u; return; }
  local utf8=true
  [[ "${LC_ALL:-}${LANG:-}" =~ UTF-8|utf8 ]] || utf8=false
  local blue reset; blue="$(tput setaf 4 2>/dev/null || true)"; reset="$(tput sgr0 2>/dev/null || true)"
  local TL TR BL BR HL VL TM BM LM RM MM
  if $utf8; then
    TL="╔"; TR="╗"; BL="╚"; BR="╝"; HL="═"; VL="║"; TM="╦"; BM="╩"; LM="╠"; RM="╣"; MM="╬"
  else
    TL="+"; TR="+"; BL="+"; BR="+"; HL="-"; VL="|"; TM="+"; BM="+"; LM="+"; RM="+"; MM="+"
  fi
  repeat() { local out=""; for ((i=0; i<$1; i++)); do out+="$2"; done; printf "%s" "$out"; }
  local w_n=4 w_t=4 w_s=4 w_p=5
  for i in "${!names[@]}"; do
    ((${#names[i]} > w_n)) && w_n=${#names[i]}
    ((${#types[i]} > w_t)) && w_t=${#types[i]}
    ((${#sizes[i]} > w_s)) && w_s=${#sizes[i]}
    ((${#perms[i]} > w_p)) && w_p=${#perms[i]}
  done
  local cn=$((w_n+2)) ct=$((w_t+2)) cs=$((w_s+2)) cp=$((w_p+2))
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$TL" "$(repeat $cn $HL)" "$TM" "$(repeat $ct $HL)" "$TM" "$(repeat $cs $HL)" "$TM" "$(repeat $cp $HL)" "$TR$reset"
  printf "%s %-${w_n}s %s %-${w_t}s %s %${w_s}s %s %-${w_p}s %s\n" "$blue$VL" "Path" "$VL" "Type" "$VL" "Size" "$VL" "Perms" "$VL$reset"
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$LM" "$(repeat $cn $HL)" "$MM" "$(repeat $ct $HL)" "$MM" "$(repeat $cs $HL)" "$MM" "$(repeat $cp $HL)" "$RM$reset"
  for i in "${!names[@]}"; do
    printf "%s %-${w_n}s %s %-${w_t}s %s %${w_s}s %s %-${w_p}s %s\n" "$blue$VL" "${names[i]}" "$VL" "${types[i]}" "$VL" "${sizes[i]}" "$VL" "${perms[i]}" "$VL$reset"
  done
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$BL" "$(repeat $cn $HL)" "$BM" "$(repeat $ct $HL)" "$BM" "$(repeat $cs $HL)" "$BM" "$(repeat $cp $HL)" "$BR$reset"
  set -u
}
ls_table_all() {
  set +u
  local target="/etc/one-click//network-repair/backups"
  if [[ -z "$target" ]]; then
    echo "Error: No path provided."
    return 1
  fi
  local paths=() types=() sizes=() perms=()
  while IFS= read -r -d '' item; do
    paths+=("$item")
    if [[ -L "$item" ]]; then types+=(Symlink)
    elif [[ -d "$item" ]]; then types+=(Directory)
    else types+=(File); fi
    sizes+=("$(stat -c '%s' "$item" 2>/dev/null || echo 0)")
    perms+=("$(stat -c '%A' "$item" 2>/dev/null || echo '?????????')")
  done < <(find "$target" -maxdepth 3 -mindepth 1 -print0 2>/dev/null | sort -z)
  [[ ${#paths[@]} -eq 0 ]] && { echo "No items found in $target"; set -u; return; }
  local utf8=true
  [[ "${LC_ALL:-}${LANG:-}" =~ UTF-8|utf8 ]] || utf8=false
  local blue="$(tput setaf 4 2>/dev/null || true)"
  local reset="$(tput sgr0 2>/dev/null || true)"
  local TL="╔" TR="╗" BL="╚" BR="╝" HL="═" VL="║" TM="╦" BM="╩" LM="╠" RM="╣" MM="╬"
  $utf8 || { TL="+"; TR="+"; BL="+"; BR="+"; HL="-"; VL="|"; TM="+"; BM="+"; LM="+"; RM="+"; MM="+"; }
  repeat() { local out=""; for ((i=0; i<$1; i++)); do out+="$2"; done; printf "%s" "$out"; }
  local w_p=4 w_t=4 w_s=4 w_m=5
  for i in "${!paths[@]}"; do
    ((${#paths[i]} > w_p)) && w_p=${#paths[i]}
    ((${#types[i]} > w_t)) && w_t=${#types[i]}
    ((${#sizes[i]} > w_s)) && w_s=${#sizes[i]}
    ((${#perms[i]} > w_m)) && w_m=${#perms[i]}
  done
  local cp=$((w_p+2)) ct=$((w_t+2)) cs=$((w_s+2)) cm=$((w_m+2))
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$TL" "$(repeat $cp $HL)" "$TM" "$(repeat $ct $HL)" "$TM" "$(repeat $cs $HL)" "$TM" "$(repeat $cm $HL)" "$TR$reset"
  printf "%s %-${w_p}s %s %-${w_t}s %s %${w_s}s %s %-${w_m}s %s\n" "$blue$VL" "Full Path" "$VL" "Type" "$VL" "Size" "$VL" "Perms" "$VL$reset"
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$LM" "$(repeat $cp $HL)" "$MM" "$(repeat $ct $HL)" "$MM" "$(repeat $cs $HL)" "$MM" "$(repeat $cm $HL)" "$RM$reset"
  for i in "${!paths[@]}"; do
    printf "%s %-${w_p}s %s %-${w_t}s %s %${w_s}s %s %-${w_m}s %s\n" \
      "$blue$VL" "${paths[i]}" "$VL" "${types[i]}" "$VL" "${sizes[i]}" "$VL" "${perms[i]}" "$VL$reset"
  done
  printf "%s%s%s%s%s%s%s%s%s\n" "$blue$BL" "$(repeat $cp $HL)" "$BM" "$(repeat $ct $HL)" "$BM" "$(repeat $cs $HL)" "$BM" "$(repeat $cm $HL)" "$BR$reset"
  set -u
}
config_table() {
  set +u
  local cfg="$1"
  [[ -r "$cfg" ]] || { echo "Cannot read $cfg" >&2; return 1; }
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
      req) key="key_req"             ;;
      pass) key="encrypted_password" ;;
      key) key="ssh_key_path"        ;;
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
  read -rp "${cyan}[USER]:${reset} Please enter the IP of the destination server: " destination_server
  if ! is_ipv4 "$destination_server"; then
    echo "The IP is ${red}INVALID${reset}! Please try again."
    v4
  fi
}
# ========================================== End Of Directory Listing =========================================== #
# ========================================== Ensure password is secure ============================================
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
# =========================================== End Of Secure Password ============================================== #
# =============================================== Rule Engine =======================================================
fleet_rule_engine_init() {
  local_host=$(hostname -s)
  local now=$(date +%F)
  build_vars
  . "$fleet_root/controller.env"
  has_ipv4=false
  has_ipv6=false
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    error "Security Block: Firewall orchestration must be executed from the central Fleet Controller."
    return 1
  fi
  info "Compiling authorized IP mesh."
  local authorized_ips=()
  for file in "$fleet_root"/state/*.conf; do
    [[ ! -f "$file" ]] && continue
    local peer_ip
    peer_ip=$(grep '^IP=' "$file" | cut -d= -f2-)
    [[ -n "$peer_ip" ]] && authorized_ips+=("$peer_ip")
  done
  [[ ${#authorized_ips[@]} -eq 0 ]] && authorized_ips+=("$CONTROLLER_IP")
  local ip_list_string="${authorized_ips[*]}"
  if [[ "$CONTROLLER_IP" =~ : ]]; then
    has_ipv6=true
  else
    has_ipv4=true
  fi
  for check_ip in $ip_list_string; do
    if [[ "$check_ip" =~ : ]]; then
      has_ipv6=true
    else
      has_ipv4=true
    fi
  done
  info "Configuring remote GUARD and ONE-CLICK-FLEET firewall chain configurations to remote peers."
  source /etc/os-release
  # ==== Fleet Peers ====
  inventory_file="/etc/one-click/fleet/inventory.yml"
  ansible-inventory -i "$inventory_file" --list | \
  jq -r --arg current "$local_host" '._meta.hostvars | keys[] | select(. != $current)' | \
  while read -r host_name; do
    connect_ip=$(ansible-inventory -i "$inventory_file" --host "$host_name" 2>/dev/null | jq -r '.ansible_host // .inventory_hostname')
    [[ -z "$connect_ip" || "$connect_ip" == "null" ]] && connect_ip="$host_name"
    info "Applying firewall policies to remote host: $host_name ($connect_ip)"
    if ! ssh \
      -n \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${porto[@]}" \
      "oneclick@$connect_ip" "
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_FAMILY_CHECK=\"\${ID_LIKE:-\${ID}}\"
      fi
      nic=\$(ip route show default | awk '{print \$5}')
      if [[ \"\$OS_FAMILY_CHECK\" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
        echo \">>> \$PRETTY_NAME / Firewalld environment detected. Applying rules.\"
        sudo firewall-cmd --permanent --zone=trusted --add-interface=ocbr0 2>/dev/null || true
        sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-nat 2>/dev/null || true
        sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-public 2>/dev/null || true
        ACTIVE_GW_ZONE=\$(sudo firewall-cmd --get-active-zones | head -n 1)
        sudo firewall-cmd --permanent --zone=\"\${ACTIVE_GW_ZONE:-public}\" --add-masquerade 2>/dev/null || true
        sudo firewall-cmd --zone=public --add-port=51821/udp --permanent 2>/dev/null || true
        sudo firewall-cmd --reload &>/dev/null
      elif ! sudo iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
        echo \">>> \$PRETTY_NAME / Pure nftables environment detected. Applying native hybrid oneclick_filter structure.\"
        sudo nft add table inet oneclick_filter 2>/dev/null || true
        sudo nft add chain inet oneclick_filter INPUT '{ type filter hook input priority 0 \; policy accept \; }' 2>/dev/null || true
        sudo nft add chain inet oneclick_filter POSTROUTING '{ type nat hook postrouting priority 100 \; }' 2>/dev/null || true
        sudo nft add chain inet oneclick_filter FORWARD '{ type filter hook forward priority 0 \; policy accept \; }' 2>/dev/null || true
        sudo nft add rule inet oneclick_filter FORWARD iifname \"one-click\" oifname \"one-click\" accept 2>/dev/null || true
        sudo nft add table ip oneclick_nat_ipv4 2>/dev/null || true
        sudo nft add chain ip oneclick_nat_ipv4 POSTROUTING '{ type nat hook postrouting priority 100 \; }' 2>/dev/null || true
        sudo nft add rule ip oneclick_nat_ipv4 POSTROUTING ip saddr 192.168.250.0/24 oifname \"\$nic\" masquerade 2>/dev/null || true
        sudo nft add table ip6 oneclick_nat_ipv6 2>/dev/null || true
        sudo nft add chain ip6 oneclick_nat_ipv6 POSTROUTING '{ type nat hook postrouting priority 100 \; }' 2>/dev/null || true
        sudo nft add rule ip6 oneclick_nat_ipv6 POSTROUTING ip6 saddr fd00:99aa::/64 oifname \"\$nic\" masquerade 2>/dev/null || true
        sudo nft add chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null || true
        if ! nft list chain inet oneclick_filter INPUT 2>/dev/null | grep -q 'jump ONE-CLICK-FLEET'; then
          sudo nft insert rule inet oneclick_filter INPUT index 1 jump ONE-CLICK-FLEET 2>/dev/null || true
        fi
        sudo nft flush chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null || true
        sudo nft insert rule inet oneclick_filter ONE-CLICK-FLEET udp dport 51821 accept 2>/dev/null || true
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname \"ocbr0\" udp sport 68 udp dport 67 accept 2>/dev/null || true
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname \"lo\" accept 2>/dev/null || true
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ct state established,related accept 2>/dev/null || true
        sudo nft insert rule inet oneclick_filter ONE-CLICK-FLEET udp sport 53 accept 2>/dev/null || true
        if [ \"$has_ipv4\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip protocol icmp accept 2>/dev/null || true
        fi
        if [ \"$has_ipv6\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET meta l4proto icmpv6 accept 2>/dev/null || true
        fi
        if [[ \"$CONTROLLER_IP\" =~ : ]]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"$CONTROLLER_IP\" tcp dport 22 accept 2>/dev/null || true
        else
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"$CONTROLLER_IP\" tcp dport 22 accept 2>/dev/null || true
        fi
        if [ \"$has_ipv4\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr 10.10.0.1 tcp dport 1-65535 accept 2>/dev/null || true
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr 192.168.250.1 accept 2>/dev/null || true
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr 192.168.250.1 tcp dport 22 accept 2>/dev/null || true
        fi
        for target_ip in $ip_list_string; do
          if [[ \"\$target_ip\" =~ : ]]; then
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"\$target_ip\" accept 2>/dev/null || true
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"\$target_ip\" tcp dport 22 accept 2>/dev/null || true
          else
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"\$target_ip\" accept 2>/dev/null || true
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"\$target_ip\" tcp dport 22 accept 2>/dev/null || true
          fi
        done
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET drop 2>/dev/null || true
      else
        echo \">>> (\$PRETTY_NAME) Legacy iptables engine active. Applying dual-stack legacy ruleset.\"
        if [ \"$has_ipv4\" = true ]; then
          sudo iptables -P FORWARD ACCEPT
          sudo iptables -P OUTPUT ACCEPT
          sudo iptables -A FORWARD -i one-click -o one-click -j ACCEPT 2>/dev/null || true
          sudo iptables -N ONE-CLICK-FLEET 2>/dev/null || true
          if ! sudo iptables -C INPUT -j ONE-CLICK-FLEET 2>/dev/null; then
            sudo iptables -I INPUT 1 -j ONE-CLICK-FLEET
          fi
          sudo iptables -F ONE-CLICK-FLEET
          sudo iptables -A ONE-CLICK-FLEET -i lo -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -p icmp -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -p udp --sport 53 -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -p udp --dport 51821 -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -i ocbr0 -p udp --sport 68 --dport 67 -j ACCEPT
          sudo iptables -t nat -A POSTROUTING -s 192.168.250.0/24 -o \"\$nic\" -j MASQUERADE 2>/dev/null || true
          if [[ ! \"$CONTROLLER_IP\" =~ : ]]; then
            sudo iptables -A ONE-CLICK-FLEET -s \"$CONTROLLER_IP\" -p tcp --dport 22 -j ACCEPT
          fi
          sudo iptables -A ONE-CLICK-FLEET -s 10.10.0.1 -p tcp --dport 1:65535 -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -s 192.168.250.1 -j ACCEPT
          sudo iptables -A ONE-CLICK-FLEET -s 192.168.250.1 -p tcp --dport 22 -j ACCEPT
        fi
        if [ \"$has_ipv6\" = true ] && command -v ip6tables >/dev/null 2>&1; then
          sudo ip6tables -P FORWARD ACCEPT
          sudo ip6tables -P OUTPUT ACCEPT
          sudo ip6tables -A FORWARD -i one-click -o one-click -j ACCEPT 2>/dev/null || true
          sudo ip6tables -N ONE-CLICK-FLEET 2>/dev/null || true
          if ! sudo ip6tables -C INPUT -j ONE-CLICK-FLEET 2>/dev/null; then
            sudo ip6tables -I INPUT 1 -j ONE-CLICK-FLEET
          fi
          sudo ip6tables -F ONE-CLICK-FLEET
          sudo ip6tables -A ONE-CLICK-FLEET -i lo -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p icmpv6 -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p udp --sport 53 -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p udp --dport 51821 -j ACCEPT
          sudo ip6tables -t nat -A POSTROUTING -s fd00:99aa::/64 -o \"\$nic\" -j MASQUERADE 2>/dev/null || true
          if [[ \"$CONTROLLER_IP\" =~ : ]]; then
            sudo ip6tables -A ONE-CLICK-FLEET -s \"$CONTROLLER_IP\" -p tcp --dport 22 -j ACCEPT
          fi
        fi
        for target_ip in $ip_list_string; do
          if [[ \"\$target_ip\" =~ : ]]; then
            if [ \"$has_ipv6\" = true ] && command -v ip6tables >/dev/null 2>&1; then
              sudo ip6tables -A ONE-CLICK-FLEET -s \"\$target_ip\" -j ACCEPT
              sudo ip6tables -A ONE-CLICK-FLEET -s \"\$target_ip\" -p tcp --dport 22 -j ACCEPT
            fi
          else
            if [ \"$has_ipv4\" = true ]; then
              sudo iptables -A ONE-CLICK-FLEET -s \"\$target_ip\" -j ACCEPT
              sudo iptables -A ONE-CLICK-FLEET -s \"\$target_ip\" -p tcp --dport 22 -j ACCEPT
            fi
          fi
        done
        if [ \"$has_ipv4\" = true ]; then
          sudo iptables -A ONE-CLICK-FLEET -j DROP
        fi
        if [ \"$has_ipv6\" = true ] && command -v ip6tables >/dev/null 2>&1; then
           sudo ip6tables -A ONE-CLICK-FLEET -j DROP
        fi
      fi
    " 2>/dev/null | sed -En "s/>>> (.*)/${orange}changed: [Controller => $host_name ($connect_ip)] ->${magenta} \1${reset}/p"; then
      error "Host $host_name ($connect_ip) is unresponsive or SSH failed."
    fi
  done
  # ==== Fleet Controller Local Section ====
  info "Applying isolated base guard config to local controller."
  {
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      OS_FAMILY_CHECK="${ID_LIKE:-${ID}}"
    fi
    if [[ "$OS_FAMILY_CHECK" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
	  printf "${orange}[CHANGED]${magenta} %s\n" '=> firewalld environment detected. Applying rules.'
      sudo firewall-cmd --permanent --zone=trusted --add-interface=ocbr0 2>/dev/null || true
      sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-nat 2>/dev/null || true
	  sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-public 2>/dev/null || true
      ACTIVE_GW_ZONE=$(sudo firewall-cmd --get-active-zones | head -n 1)
      sudo firewall-cmd --permanent --zone="${ACTIVE_GW_ZONE:-public}" --add-masquerade 2>/dev/null || true
	  sudo firewall-cmd --zone=public --add-port=51821/udp --permanent
      sudo firewall-cmd --reload &>/dev/null
    elif ! iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
      printf "${orange}[CHANGED]${magenta} %s\n" '=> nftables environment detected. Applying hybrid oneclick_filter structure.'
      nft add table inet oneclick_filter 2>/dev/null || true
      nft add chain inet oneclick_filter INPUT '{ type filter hook input priority 0 ; policy accept ; }' 2>/dev/null || true
      nft add chain inet oneclick_filter FORWARD '{ type filter hook forward priority 0 ; policy accept ; }' 2>/dev/null || true
      nft add rule inet oneclick_filter FORWARD iifname "one-click" oifname "one-click" accept 2>/dev/null || true
	  nft add rule inet oneclick_filter FORWARD ct state established,related accept 2>/dev/null || true
      nft add table ip oneclick_nat_ipv4 2>/dev/null || true
      nft add chain ip oneclick_nat_ipv4 POSTROUTING '{ type nat hook postrouting priority 100 ; }' 2>/dev/null || true
      nft add rule ip oneclick_nat_ipv4 POSTROUTING ip saddr 192.168.250.0/24 oifname "$nic" masquerade
      nft add table ip6 oneclick_nat_ipv6 2>/dev/null || true
      nft add chain ip6 oneclick_nat_ipv6 POSTROUTING '{ type nat hook postrouting priority 100 ; }' 2>/dev/null || true
      nft add rule ip6 oneclick_nat_ipv6 POSTROUTING ip6 saddr fd00:99aa::/64 oifname "$nic" masquerade
      nft add chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null || true
      if ! nft list chain inet oneclick_filter INPUT | grep -q 'jump ONE-CLICK-FLEET'; then
        nft insert rule inet oneclick_filter INPUT jump ONE-CLICK-FLEET
      fi
      nft flush chain inet oneclick_filter ONE-CLICK-FLEET
      nft add rule inet oneclick_filter ONE-CLICK-FLEET udp dport 51821 accept
      nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname "ocbr0" udp sport 68 udp dport 67 accept
      nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname "lo" accept
      nft add rule inet oneclick_filter ONE-CLICK-FLEET ct state established,related accept
      nft add rule inet oneclick_filter ONE-CLICK-FLEET udp sport 53 accept
      if [ "$has_ipv4" = true ]; then
        nft add rule inet oneclick_filter ONE-CLICK-FLEET ip protocol icmp accept
      fi
      if [ "$has_ipv6" = true ]; then
        nft add rule inet oneclick_filter ONE-CLICK-FLEET meta l4proto icmpv6 accept
      fi
      if [[ "$CONTROLLER_IP" =~ : ]]; then
        nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr "$CONTROLLER_IP" tcp dport 22 accept
      else
        nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr "$CONTROLLER_IP" tcp dport 22 accept
      fi
      if [ "$has_ipv4" = true ]; then
        nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr 10.10.0.1 tcp dport 1-65535 accept
      fi
      for target_ip in $ip_list_string; do
        if [[ "$target_ip" =~ : ]]; then
          nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr "$target_ip" accept
          nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr "$target_ip" tcp dport 22 accept
        else
          nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr "$target_ip" accept
          nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr "$target_ip" tcp dport 22 accept
        fi
      done
      if command -v firewall-cmd > /dev/null; then
        if systemctl is-active firewalld > /dev/null; then
          firewall-cmd --zone=public --add-port=51821/udp --permanent
          firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i one-click -o one-click -j ACCEPT 2>/dev/null || true
          firewall-cmd --reload
        fi
      fi
    else
      printf "${orange}[CHANGED]${magenta} %s\n" '=> Legacy iptables detected. Applying dual-stack legacy ruleset.'
      if [ "$has_ipv4" = true ]; then
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -A FORWARD -i one-click -o one-click -j ACCEPT 2>/dev/null || true
        iptables -N ONE-CLICK-FLEET 2>/dev/null || true
        if ! iptables -C INPUT -j ONE-CLICK-FLEET 2>/dev/null; then
          iptables -I INPUT 1 -j ONE-CLICK-FLEET
        fi
        iptables -F ONE-CLICK-FLEET
        iptables -A ONE-CLICK-FLEET -i lo -j ACCEPT
        iptables -A ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -A ONE-CLICK-FLEET -p icmp -j ACCEPT
        iptables -A ONE-CLICK-FLEET -p udp --sport 53 -j ACCEPT
        iptables -A ONE-CLICK-FLEET -p udp --dport 51821 -j ACCEPT
        iptables -A ONE-CLICK-FLEET -i ocbr0 -p udp --sport 68 --dport 67 -j ACCEPT
        ip6tables -t nat -A POSTROUTING -s fd00:99aa::/64 -o $nic -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 192.168.250.0/24 -o "$nic" -j MASQUERADE
        if [[ ! "$CONTROLLER_IP" =~ : ]]; then
          iptables -A ONE-CLICK-FLEET -s "$CONTROLLER_IP" -p tcp --dport 22 -j ACCEPT
        fi
        iptables -A ONE-CLICK-FLEET -s 10.10.0.1 -p tcp --dport 1:65535 -j ACCEPT
      fi
      if [ "$has_ipv6" = true ] && command -v ip6tables >/dev/null 2>&1; then
        ip6tables -P FORWARD ACCEPT
        ip6tables -P OUTPUT ACCEPT
        ip6tables -A FORWARD -i one-click -o one-click -j ACCEPT 2>/dev/null || true
        ip6tables -N ONE-CLICK-FLEET 2>/dev/null || true
        if ! ip6tables -C INPUT -j ONE-CLICK-FLEET 2>/dev/null; then
          ip6tables -I INPUT 1 -j ONE-CLICK-FLEET
        fi
        ip6tables -F ONE-CLICK-FLEET
        ip6tables -A ONE-CLICK-FLEET -i lo -j ACCEPT
        ip6tables -A ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        ip6tables -A ONE-CLICK-FLEET -p icmpv6 -j ACCEPT
        ip6tables -A ONE-CLICK-FLEET -p udp --sport 53 -j ACCEPT
        ip6tables -A ONE-CLICK-FLEET -p udp --dport 51821 -j ACCEPT
        if [[ "$CONTROLLER_IP" =~ : ]]; then
          ip6tables -A ONE-CLICK-FLEET -s "$CONTROLLER_IP" -p tcp --dport 22 -j ACCEPT
        fi
      fi
      for target_ip in $ip_list_string; do
        if [[ "$target_ip" =~ : ]]; then
          if [ "$has_ipv6" = true ] && command -v ip6tables >/dev/null 2>&1; then
            ip6tables -A ONE-CLICK-FLEET -s "$target_ip" -j ACCEPT
            ip6tables -A ONE-CLICK-FLEET -s "$target_ip" -p tcp --dport 22 -j ACCEPT
          fi
        else
          if [ "$has_ipv4" = true ]; then
            iptables -A ONE-CLICK-FLEET -s "$target_ip" -j ACCEPT
            iptables -A ONE-CLICK-FLEET -s "$target_ip" -p tcp --dport 22 -j ACCEPT
          fi
        fi
      done
      if command -v firewall-cmd > /dev/null; then
        if systemctl is-active firewalld > /dev/null; then
		  firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i one-click -o one-click -j ACCEPT 2>/dev/null || true
          firewall-cmd --zone=public --add-port=51821/udp --permanent
          firewall-cmd --reload
        fi
      fi
    fi
  } &>/dev/null
  success "Global fleet baseline security deployed securely!"
  return
}
sync_fleet_controller_authority() {
  if [[ -f "/etc/one-click/fleet/controller.env" ]]; then
    . "/etc/one-click/fleet/controller.env"
  else
    error "Not controller node. Synchronization aborted."
    return 1
  fi
  if [[ -z "${CONTROLLER_IP:-}" || -z "${CONTROLLER_NAME:-}" ]]; then
    error "Controller identity (CONTROLLER_IP or CONTROLLER_NAME) is incomplete."
    return 1
  fi
  info "Initializing fleet controller authority synchronization."
  set +e
  ANSIBLE_HOST_KEY_CHECKING=False \
  ANSIBLE_INTERPRETER_DISCOVERY=ignore \
  ANSIBLE_SSH_TIMEOUT=3 \
  ANSIBLE_GATHERING=explicit \
  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible all \
    -e "ansible_ignore_unreachable=True" \
    -e "MASTER_IP=${CONTROLLER_IP}" \
    -e "MASTER_NAME=${CONTROLLER_NAME}" \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a '
      env_file="/etc/one-click/fleet/controller.env"
      identity_file="/etc/one-click/fleet/identity.conf"
      local_ip=$(hostname -I | awk "{print \$1}")
      node_name=$(hostname -s)
      mkdir -p "/etc/one-click/fleet"
      if [[ "$local_ip" == "{{ MASTER_IP }}" || "$node_name" == "{{ MASTER_NAME }}" ]]; then
        is_master="true"
        role_type="controller"
        status="active"
        target_ip="127.0.0.1"
      else
        is_master="false"
        role_type="hypervisor-peer"
        status="managed"
        target_ip="{{ MASTER_IP }}"
      fi
      cat <<EOF > "$identity_file"
ROLE=peer
FLEET_IDENTITY=$node_name
STATUS=$status
CONTROLLER_TARGET_IP=$target_ip
LAST_SYNC=$(date +%s)
EOF
      touch "$env_file"
      sed -i "/^CONTROLLER_IP=/d; /^CONTROLLER_NAME=/d; /^IS_MASTER=/d; /^ROLE_TYPE=/d" "$env_file"
      {
        echo "CONTROLLER_IP=\"{{ MASTER_IP }}\""
        echo "CONTROLLER_NAME=\"{{ MASTER_NAME }}\""
        echo "ROLE_TYPE=\"$role_type\""
        echo "IS_MASTER=\"$is_master\""
      } >> "$env_file"
      chmod 600 "$identity_file" "$env_file"
      echo "ALIGNED: Node $node_name pinned to controller {{ MASTER_NAME }} ({{ MASTER_IP }}), IS_MASTER=$is_master."
    ' 2>/dev/null | sed -En "
      /^\[/ {
        /\|/ {
          N;
          s/^([^|]*) \| ([^|!]*) .*\n([^.]*).*/[[\2]\1] => \3/
        };
      };
      /^\[/p;
      /UNREACHABLE|ERROR/s/([^!=>]*).*/${red}\1${reset}/p;
      /ok/I s/.*/${green}&${reset}/p
    "
  set -e
  success "Global fleet mesh synchronization complete. Authority enforced."
}
sync_custom_ssh_keys() {
  local target_ip="$1"
  local private_key="${2:-}"

  info "Preserving user-added SSH authorized keys across transition."

  # Dynamically resolve working private key if none provided or provided key is missing/unusable
  if [[ -z "$private_key" || ! -f "$private_key" ]] || ! ssh -i "$private_key" -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no "oneclick@${target_ip}" "true" &>/dev/null; then
    local candidate_keys=(
      "/etc/one-click/fleet/keys/id_ed25519"
      "/home/oneclick/.ssh/id_ed25519"
      "/etc/one-click/fleet/keys/id_rsa"
      "/home/oneclick/.ssh/id_rsa"
    )

    private_key=""
    for key in "${candidate_keys[@]}"; do
      if [[ -f "$key" ]]; then
        if ssh -i "$key" -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=no "oneclick@${target_ip}" "true" &>/dev/null; then
          private_key="$key"
          info "Successfully authenticated using key: [$private_key]"
          break
        fi
      fi
    done

    if [[ -z "$private_key" ]]; then
      error "Could not establish SSH connection to [$target_ip] using any key in fleet or home directories."
      return 1
    fi
  fi

  local tmp_user_auth="/tmp/user_auth_keys.tmp"
  local tmp_root_auth="/tmp/root_auth_keys.tmp"

  [[ -f /home/oneclick/.ssh/authorized_keys ]] && cp /home/oneclick/.ssh/authorized_keys "$tmp_user_auth"
  [[ -f /root/.ssh/authorized_keys ]] && sudo cp /root/.ssh/authorized_keys "$tmp_root_auth"

  if [[ -f "$tmp_user_auth" ]]; then
    scp -i "$private_key" -o StrictHostKeyChecking=no "$tmp_user_auth" "oneclick@${target_ip}:/tmp/incoming_user_keys"
    ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -s" << 'EOF'
      mkdir -p /home/oneclick/.ssh
      touch /home/oneclick/.ssh/authorized_keys
      cat /tmp/incoming_user_keys >> /home/oneclick/.ssh/authorized_keys
      sort -u /home/oneclick/.ssh/authorized_keys -o /home/oneclick/.ssh/authorized_keys
      chmod 600 /home/oneclick/.ssh/authorized_keys
      chown -R oneclick:oneclick /home/oneclick/.ssh
      rm -f /tmp/incoming_user_keys
EOF
  fi

  if [[ -f "$tmp_root_auth" ]]; then
    scp -i "$private_key" -o StrictHostKeyChecking=no "$tmp_root_auth" "oneclick@${target_ip}:/tmp/incoming_root_keys"
    ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -s" << 'EOF'
      mkdir -p /root/.ssh
      touch /root/.ssh/authorized_keys
      cat /tmp/incoming_root_keys >> /root/.ssh/authorized_keys
      sort -u /root/.ssh/authorized_keys -o /root/.ssh/authorized_keys
      chmod 600 /root/.ssh/authorized_keys
      rm -f /tmp/incoming_root_keys
EOF
  fi

  rm -f "$tmp_user_auth" "$tmp_root_auth"
}
apply_node_firewall_transition() {
  local mode="$1"
  local target_controller_ip="$2"
  local nic
  . "/etc/one-click/fleet/controller.env"
  . "/etc/os-release"
  nic=$(ip route show default | awk '{print $5}')
  local source_os=""
  [[ -f /etc/os-release ]] && source /etc/os-release
  if [[ "$mode" == "promote_to_master" ]]; then
    echo "${lime}>>>${reset} Promoting $node to CONTROLLER. Removing fleet-peer drop rules."
    if [[ "$ID_LIKE" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
      firewall-cmd --zone=public --add-port=22/tcp --permanent 2>/dev/null || true
      firewall-cmd --zone=public --add-port=51821/udp --permanent 2>/dev/null || true
      firewall-cmd --reload &>/dev/null || true
    elif ! iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
      local drop_handle
      drop_handle=$(sudo nft -a list chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null | grep "drop" | awk '{print $NF}')
      if [[ -n "$drop_handle" ]]; then
        nft delete rule inet oneclick_filter ONE-CLICK-FLEET handle "$drop_handle" 2>/dev/null || true
      fi
      nft add rule inet oneclick_filter ONE-CLICK-FLEET tcp dport 22 accept 2>/dev/null || true
    else
      iptables -D ONE-CLICK-FLEET -j DROP 2>/dev/null || true
      ip6tables -D ONE-CLICK-FLEET -j DROP 2>/dev/null || true
      iptables -A ONE-CLICK-FLEET -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
    fi
  elif [[ "$mode" == "demote_to_peer" ]]; then
    echo "${lime}>>>${reset} Demoting $(hostname -s) to HYPERVISOR-PEER. Applying fleet-peer DROP rules."
    if [[ "${ID_LIKE:-$ID}" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
      sudo firewall-cmd --zone=public --remove-port=22/tcp --permanent 2>/dev/null || true
      sudo firewall-cmd --reload &>/dev/null || true
    elif ! sudo iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
      sudo nft add table inet oneclick_filter 2>/dev/null || true
      sudo nft add chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null || true
      if [[ "$target_controller_ip" =~ : ]]; then
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr "$target_controller_ip" tcp dport 22 accept 2>/dev/null || true
      else
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr "$target_controller_ip" tcp dport 22 accept 2>/dev/null || true
      fi
      sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET drop 2>/dev/null || true
    else
      sudo iptables -D ONE-CLICK-FLEET -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
      if [[ ! "$target_controller_ip" =~ : ]]; then
        sudo iptables -A ONE-CLICK-FLEET -s "$target_controller_ip" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
      fi
      sudo iptables -A ONE-CLICK-FLEET -j DROP 2>/dev/null || true
      if command -v ip6tables &>/dev/null; then
        sudo ip6tables -A ONE-CLICK-FLEET -j DROP 2>/dev/null || true
      fi
    fi
  fi
}
dry_run() {
  local cmds ns critical_ports broken check_list ssh_port target_ports used_ports=()
  cmds=("$@")
  ns="one-click_dry-run_namespace"
  broken=0
  target_ports=$(grep -oE '[0-9]{1,5}' <<< "${cmds[*]}")
  ssh_port=$(awk '/\./{split($5,a,":");print a[2]}' <(ss -taulpn | grep -i ssh))
  check_list=("${ssh_port}:SSH" "53:DNS" "80:HTTP" "443:HTTPS")
  printf '%s\n' "${magenta}[DRY-RUN]${reset} Preparing dry run isolated environment for safe testing."
  # ==== Setup Isolated Namespace ====
  ip netns add "$ns" 2>/dev/null || true
  ip -n "$ns" link set lo up
  ip link add oneclick_vetdry type veth peer name oneclick_vethst 2>/dev/null || true
  ip link set oneclick_vetdry netns "$ns"
  ip addr add 10.200.200.1/24 dev oneclick_vethst 2>/dev/null || true
  ip link set oneclick_vethst up
  ip -n "$ns" addr add 10.200.200.2/24 dev oneclick_vetdry
  ip -n "$ns" link set oneclick_vetdry up
  ip -n "$ns" route add default via 10.200.200.1
  # ==== Initialize Backend Ruleset inside Namespace ====
  case "${firewall_backend:-iptables}" in
    nft)
      ip netns exec "$ns" nft flush ruleset 2>/dev/null || true
      ip netns exec "$ns" nft add table inet filter
      ip netns exec "$ns" nft add chain inet filter input \{ type filter hook input priority 0 \; policy accept \; \}
      ;;
    *)
      ip netns exec "$ns" iptables -F 2>/dev/null || true
      ip netns exec "$ns" iptables -X 2>/dev/null || true
      ;;
  esac
  # ==== Apply & Test Rules in Isolated Namespace ====
  for cmd in "${cmds[@]}"; do
    cmd="${cmd#raw: }"
    case "${firewall_backend:-iptables}" in
      ufw)
        if ! ufw --dry-run $cmd &>/dev/null; then
          printf '%s\n' "${red}[DRY-RUN]${reset} Invalid UFW rule syntax: $cmd"
          broken=1
        fi
        local port_num proto_type
        port_num=$(grep -oE '[0-9]{1,5}' <<< "$cmd" | head -n1)
        proto_type=$(grep -oE 'tcp|udp' <<< "$cmd" || echo "tcp")
        if [[ "$cmd" =~ deny|reject|block ]]; then
          ip netns exec "$ns" iptables -A INPUT -p "$proto_type" --dport "$port_num" -j DROP &>/dev/null || true
        elif [[ "$cmd" =~ allow|permit ]]; then
          ip netns exec "$ns" iptables -I INPUT -p "$proto_type" --dport "$port_num" -j ACCEPT &>/dev/null || true
        fi
        ;;
      firewalld)
        if ! firewall-cmd --check-config &>/dev/null; then
          printf '%s\n' "${red}[DRY-RUN]${reset} Firewalld configuration error detected."
          broken=1
        fi
        local port_num proto_type
        port_num=$(grep -oE '[0-9]{1,5}' <<< "$cmd" | head -n1)
        proto_type=$(grep -oE 'tcp|udp' <<< "$cmd" || echo "tcp")
        if [[ "$cmd" =~ drop|reject ]]; then
          ip netns exec "$ns" iptables -A INPUT -p "$proto_type" --dport "$port_num" -j DROP &>/dev/null || true
        else
          ip netns exec "$ns" iptables -I INPUT -p "$proto_type" --dport "$port_num" -j ACCEPT &>/dev/null || true
        fi
        ;;
      nft)
        if ! ip netns exec "$ns" eval "$cmd" &>/dev/null; then
          printf '%s\n' "${red}[DRY-RUN]${reset} Failed to apply nftables rule in namespace: $cmd"
          broken=1
        fi
        ;;
      iptables|*)
        read -r -a arr <<< "$cmd"
        if ! ip netns exec "$ns" "${arr[@]}" &>/dev/null; then
          printf '%s\n' "${red}[DRY-RUN]${reset} Failed to apply iptables rule in namespace: $cmd"
          broken=1
        fi
        ;;
    esac
  done
  # ==== Test Connectivity in Namespace ====
  local check_list=()
  mapfile -t check_list < <(
    ss -taulpn | awk '/\(/{print $NF}' | awk -F'"' '{print $2}' | while read -r line; do
        awk -v service="$line" '/\./{split($5,a,":"); print a[2]":"service}' <(ss -taulpn | grep -i "$line")
    done | sort -u
  )
  printf '%s\n' "${magenta}[DRY-RUN]${reset} Verifying system accessibility."
  if ! ip netns exec "$ns" ping -c 1 -W 1 127.0.0.1 &>/dev/null; then
    printf "${magenta}[DRY-RUN]${reset} %s\n" "${red}Loopback (lo) is BLOCKED!${reset}"
    broken=1
  fi
  for entry in "${check_list[@]}"; do
    local c_port="${entry%%:*}"
    local c_name="${entry##*:}"
    local is_user_targeted=0
    [[ -z "$c_port" ]] && continue
    if grep -qw "$c_port" <<< "$target_ports"; then
      is_user_targeted=1
    fi
    ip netns exec "$ns" timeout 2 nc -l -p "$c_port" &
    local nc_pid=$!
    sleep 0.2
    if ! nc -zv -w 1 10.200.200.2 "$c_port" &>/dev/null; then
      if [[ "$c_port" == "22" || "$c_name" == "sshd" ]]; then
        printf "${magenta}[DRY-RUN]${red}[FAIL] %s${reset}\n" "FATAL: $c_name (Port $c_port) will be BLOCKED! This will cause a lockout if applied."
        broken=1
      elif [[ "$is_user_targeted" -eq 0 ]]; then
        if [[ "$c_name" =~ (mariadb|mysql|redis|nginx|httpd) ]]; then
          printf "${magenta}[DRY-RUN]${red}[FAIL] %s${reset}\n" "Critical service $c_name (Port $c_port) will be accidentally blocked!"
          broken=1
        else
          printf "${magenta}[DRY-RUN]${yellow}[WARN] %s${reset}\n" "Service $c_name (Port $c_port) will become unreachable."
        fi
      else
        printf "${magenta}[DRY-RUN]${green}[SUCCESS] %s${reset}\n" "Port $c_port ($c_name) will successfully remain filtered/blocked."
      fi
    else
      if [[ "$is_user_targeted" -eq 1 ]]; then
        printf "${magenta}[DRY-RUN]${yellow}[WARN] %s${reset}\n" "Logic Error: You tried to block $c_port, but it will remain OPEN."
      else
        printf "${magenta}[DRY-RUN]${green}[SUCCESS] %s${reset}\n" "Service $c_name (Port $c_port) remains accessible."
      fi
    fi
    kill "$nc_pid" 2>/dev/null || true
  done
  ip link delete oneclick_vethst 2>/dev/null || true
  ip netns delete "$ns" 2>/dev/null || true
  if [[ "$broken" -eq 1 ]]; then
    printf '%s\n' "${magenta}[DRY-RUN]${red}[FAIL] Firewall rules failed dry-run test.${reset}"
    return 1
  fi
  printf '%s\n' "${magenta}[DRY-RUN]${green}[SUCCESS] Rules passed dry-run test.${reset}"
  if [[ "${y_interactive:-}" -eq 1 ]]; then
    apply_rules="y"
  else
    read -rp "${cyan}[USER]${reset} Would you like to apply these rules now? (y|n): " apply_rules
    apply_rules="${apply_rules,,}"
    if [[ "$apply_rules" =~ ^(y|yes)$ ]]; then
      return 0
    else
      warn "Rule Engine will now abort!"
      return 1
    fi
  fi
}
match_rule_handles() {
  local backend="$1" chain="${2:-INPUT}" action="$3" proto="$4" port="$5" src_ip="$6"
  local matches=()
  case "$backend" in
    iptables|ip6tables)
      local tbl="filter"
      local chain_upper="${chain^^}"
      local line_num=1
      while read -r line; do
        [[ -z "$line" || "$line" =~ ^Chain|^pkts ]] && continue
        local matches_rule=1
        if [[ -n "$action" ]]; then
          [[ "$line" != *"$action"* ]] && matches_rule=0
        fi
        if [[ -n "$proto" ]]; then
          [[ "$line" != *"$proto"* && "$line" != *"all"* ]] && matches_rule=0
        fi
        if [[ -n "$port" ]]; then
          [[ "$line" != *"dpt:$port"* && "$line" != *"dports $port"* && "$line" != *":$port"* ]] && matches_rule=0
        fi
        if [[ -n "$src_ip" ]]; then
          [[ "$line" != *"$src_ip"* ]] && matches_rule=0
        fi
        if [[ "$matches_rule" -eq 1 ]]; then
          matches+=("$line_num")
        fi
        ((line_num++))
      done < <(${fw_bin:-iptables} -L "$chain_upper" -n --line-numbers 2>/dev/null)
      if (( ${#matches[@]} > 0 )); then
        printf "%s\n" "${matches[@]}" | sort -rn
      fi
      ;;
    nft)
      local chain_lower="${chain,,}"
      local matches_nft=()
      while read -r line; do
        if [[ "$line" =~ handle[[:space:]]+([0-9]+) ]]; then
          local handle="${BASH_REMATCH[1]}"
          local matches_rule=1
          [[ -n "$action" ]] && [[ "${line,,}" != *"${action,,}"* ]] && matches_rule=0
          [[ -n "$proto" ]]  && [[ "$line" != *"$proto"* ]] && matches_rule=0
          [[ -n "$port" ]]   && [[ "$line" != *"dport $port"* ]] && matches_rule=0
          [[ -n "$src_ip" ]] && [[ "$line" != *"$src_ip"* ]] && matches_rule=0
          if [[ "$matches_rule" -eq 1 ]]; then
            matches_nft+=("$handle")
          fi
        fi
      done < <(nft -a list chain inet filter "$chain_lower" 2>/dev/null)
      if (( ${#matches_nft[@]} > 0 )); then
        printf "%s\n" "${matches_nft[@]}"
      fi
      ;;
    ufw)
      ufw status numbered 2>/dev/null | grep -E '^\[[ 0-9]+\]' | while read -r line; do
        local num=$(echo "$line" | grep -oP '\[\s*\K[0-9]+')
        local matches_rule=1
        [[ -n "$action" ]] && [[ "${line,,}" != *"${action,,}"* ]] && matches_rule=0
        [[ -n "$port" ]]   && [[ "$line" != *"$port"* ]] && matches_rule=0
        if [[ "$matches_rule" -eq 1 ]]; then
          echo "$num"
        fi
      done | sort -rn
      ;;
  esac
}
detect_firewall_backend() {
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    firewall_backend="firewalld"
  elif systemctl is-active --quiet ufw 2>/dev/null || ufw status 2>/dev/null | grep -q "active"; then
    firewall_backend="ufw"
  elif command -v nft >/dev/null 2>&1 && systemctl is-active --quiet nftables 2>/dev/null; then
    firewall_backend="nft"
  elif command -v iptables >/dev/null 2>&1; then
    firewall_backend="iptables"
  else
    firewall_backend="none"
  fi
  if command -v ip6tables >/dev/null 2>&1; then
    ipv6_available=1
  else
    ipv6_available=0
  fi
}
valid_ipv6() {
  [[ $1 =~ ^([0-9a-fA-F:]+:+)+[0-9a-fA-F]+(/[0-9]{1,3})?$ ]]
}
valid_ip() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]
}
valid_port() {
  [[ $1 =~ ^[0-9]{1,5}(-[0-9]{1,5})?$ ]] && return 0
  return 1
}
valid_range() {
  local start end
  if [[ $1 =~ ^([0-9]{1,5}):([0-9]{1,5})$ ]]; then
    start="${BASH_REMATCH[1]}"
    end="${BASH_REMATCH[2]}"
    valid_port "$start" || return 1
    valid_port "$end"   || return 1
    (( start <= end )) || return 1
    return 0
  fi
  return 1
}
check_firewall_available() {
  if [[ -z "${pkg_mgr:-}" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      pkg_mgr="apt"
    elif command -v dnf >/dev/null 2>&1; then
      pkg_mgr="dnf"
    elif command -v yum >/dev/null 2>&1; then
      pkg_mgr="yum"
    elif command -v pacman >/dev/null 2>&1; then
      pkg_mgr="pacman"
    elif command -v zypper >/dev/null 2>&1; then
      pkg_mgr="zypper"
    fi
  fi
  if [[ -z "${firewall_backend:-}" ]]; then
    if command -v nft >/dev/null 2>&1; then
      firewall_backend="nft"
    elif command -v iptables >/dev/null 2>&1; then
      firewall_backend="iptables"
    elif command -v firewalld >/dev/null 2>&1 || command -v firewall-cmd >/dev/null 2>&1; then
      firewall_backend="firewalld"
    elif command -v ufw >/dev/null 2>&1; then
      firewall_backend="ufw"
    else
      firewall_backend="none"
    fi
  fi
  install_iptables_for_os() {
    case "$pkg_mgr" in
      apt)
        install_dep "iptables" "type iptables" "iptables" "$pkg_mgr"
        ;;
      dnf|yum)
        install_dep "iptables" "type iptables" "iptables" "$pkg_mgr"
        install_dep "iptables-services" "type iptables-services" "iptables-services" "$pkg_mgr"
        ;;
      pacman)
        install_dep "iptables" "type iptables" "iptables" "$pkg_mgr"
        ;;
      zypper)
        install_dep "iptables" "type iptables" "iptables-utils" "$pkg_mgr"
        ;;
      *)
        die "Unsupported package manager." "Cannot install iptables automatically."
        ;;
    esac
  }
  if [[ "$firewall_backend" == "iptables" ]]; then
    if ! command -v iptables >/dev/null 2>&1; then
      install_iptables_for_os
    fi
    return 0
  elif [[ "$firewall_backend" == "nft" || "$firewall_backend" == "firewalld" || "$firewall_backend" == "ufw" ]]; then
    if ! command -v iptables >/dev/null 2>&1; then
      warn "$firewall_backend detected. Installing iptables compatibility layer."
      install_iptables_for_os
      firewall_backend="iptables"
    fi
    return 0
  else
    read -rp "${cyan}[USER]:${reset} No firewall installed. Install iptables? (y|n): " confirm
    confirm="${confirm,,}"
    if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
      install_iptables_for_os
      firewall_backend="iptables"
    else
      die "Firewall required." "No firewall installed."
    fi
  fi
}
build_native_cmd() {
  local backend="$1" action="$2" proto="$3" port="$4" src_ip="$5" chain="$6"
  case "$backend" in
    iptables)
      echo "iptables -A ${chain:-INPUT} -p $proto --dport $port ${src_ip:+-s $src_ip} -j $action"
      ;;
    nft)
      local nft_action="drop"
      [[ "$action" == "ACCEPT" ]] && nft_action="accept"
      echo "nft add rule inet filter ${chain,,:-input} ${src_ip:+ip saddr $src_ip} $proto dport $port $nft_action"
      ;;
    ufw)
      local ufw_action="deny"
      [[ "$action" == "ACCEPT" ]] && ufw_action="allow"
      echo "ufw $ufw_action proto $proto ${src_ip:+from $src_ip} to any port $port"
      ;;
    firewalld)
      if [[ -n "$src_ip" ]]; then
        local rich_action="drop"
        [[ "$action" == "ACCEPT" ]] && rich_action="accept"
        echo "firewall-cmd --zone=public --add-rich-rule='rule family=\"ipv4\" source address=\"$src_ip\" port port=\"$port\" protocol=\"$proto\" $rich_action'"
      else
        echo "firewall-cmd --zone=public --add-port=$port/$proto"
      fi
      ;;
  esac
}
backup_firewall() {
  local backend timestamp outfile engine_backup_dir
  engine_backup_dir="/etc/one-click/rule-engine/"
  mkdir -p "$engine_backup_dir"
  backend="$firewall_backend"
  timestamp="$(date +%Y-%m-%d-%H%M%S)"
  case "$backend" in
    nft)       ext="nft-$timestamp.backup"; nft list ruleset > "${engine_backup_dir}${ext}" 2>/dev/null || return 1                ;;
    iptables)  ext="iptables-$timestamp.backup";${fw_bin:-iptables}-save > "${engine_backup_dir}${ext}" 2>/dev/null || return 1    ;;
    ufw)       ext="ufw-$timestamp.backup"; ufw status verbose > "${engine_backup_dir}${ext}" 2>/dev/null || return 1              ;;
    firewalld) ext="firewalld-$timestamp.backup"; firewall-cmd --runtime-to-permanent >/dev/null 2>&1
               firewall-cmd --permanent --list-all --zone=public > "${engine_backup_dir}${ext}" 2>/dev/null || return 1            ;;
    *)         die "Unsupported firewall backend."                                                                                 ;;
  esac
  outfile="${engine_backup_dir}${ext}"
  chmod 600 "${outfile}" 2>/dev/null
  success "Firewall configuration saved to ${outfile}"
  exit 0
}
delete_firewall_backups() {
  local engine_backup_dir backups selected bak_num file_name
  engine_backup_dir="/etc/one-click/rule-engine"
  # ==== List Backup Files ====
  mapfile -t backups < <(ls -1 "$engine_backup_dir"/*.backup 2>/dev/null)
  if [[ ${#backups[@]} -eq 0 ]]; then
    warn "No firewall backups found in $engine_backup_dir"
    return 1
  fi
  # ==== Show Backups ====
  echo
  echo -e "\e[34m┌───────────────────────────────────────────┐\e[0m"
  echo -e "\e[34m│ $(tput setaf 203)Available Firewall Backups \e[34m               │\e[0m"
  echo -e "\e[34m├─────┬─────────────────────────────────────┤\e[0m"
  printf "\e[34m│ %-3s │ %-35s │\e[0m\n" "No." "File"
  echo -e "\e[34m├─────┼─────────────────────────────────────┤\e[0m"
  for i in "${!backups[@]}"; do
    file_name="$(basename "${backups[$i]}")"
    printf "\e[34m│ %-3s │ %-35s │\e[0m\n" "$((++i))" "$file_name"
  done
  echo -e "\e[34m└─────┴─────────────────────────────────────┘\e[0m"
  echo
  # ==== Select Backup ====
  read -rp "${cyan}[USER]: ${reset}Enter the number of the backup you want to delete: " bak_num
  if ! [[ "$bak_num" =~ ^[0-9]+$ ]] || (( bak_num < 1 || bak_num > ${#backups[@]} )); then
    warn "Invalid selection."
    return 1
  fi
  selected="${backups[$((bak_num-1))]}"
  # ==== Confirm Deletion ====
  read -rp "${cyan}[USER]: ${reset}Are you sure you want to permanently delete $(basename "$selected")? (y|n): " confirm
  confirm="${confirm,,}"
  if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
    rm -f "$selected" && success "Deleted firewall backup: $(basename "$selected")" || warn "Failed to delete $selected"
  else
    die "Deletion cancelled."
  fi
}
restore_firewall() {
  local engine_backup_dir backups selected bak_num backend file_name
  engine_backup_dir="/etc/one-click/rule-engine"
  mapfile -t backups < <(ls -1 "$engine_backup_dir"/*.backup 2>/dev/null)
  if [[ ${#backups[@]} -eq 0 ]]; then
    warn "No firewall backups found in $engine_backup_dir"
    return 1
  fi
  if [[ ${#backups[@]} -gt 1 ]]; then
    echo
    echo -e "\e[34m┌───────────────────────────────────────────┐\e[0m"
    echo -e "\e[34m│ $(tput setaf 203)Available Firewall Backups \e[34m                │\e[0m"
    echo -e "\e[34m├─────┬─────────────────────────────────────┤\e[0m"
    printf "\e[34m│ %-3s │ %-35s │\e[0m\n" "No." "File"
    echo -e "\e[34m├─────┼─────────────────────────────────────┤\e[0m"
    for i in "${!backups[@]}"; do
      file_name="$(basename "${backups[$i]}")"
      printf "\e[34m│ %-3s │ %-35s │\e[0m\n" "$((i+1))" "$file_name"
    done
    echo -e "\e[34m└─────┴─────────────────────────────────────┘\e[0m"
    echo
    read -rp "${cyan}[USER]: ${reset}Enter the number of the backup you want to restore: " bak_num
    if ! [[ "$bak_num" =~ ^[0-9]+$ ]] || (( bak_num < 1 || bak_num > ${#backups[@]} )); then
      warn "Invalid selection."
      return 1
    fi
    selected="${backups[$((bak_num-1))]}"
  else
    selected="${backups[0]}"
    info "One backup found: $(basename "$selected")"
  fi
  file_name=$(basename "$selected")
  case "$file_name" in
    nft-*)       backend="nft"       ;;
    iptables-*)  backend="iptables"  ;;
    ufw-*)       backend="ufw"       ;;
    firewalld-*) backend="firewalld" ;;
    *)           backend="${firewall_backend:-iptables}" ;;
  esac
  warn "Validating and restoring firewall from $(basename "$selected")."
  read -rp "${cyan}[USER]: ${reset}Please confirm you'd like to proceed (y|n): " fw_confirm
  [[ "${fw_confirm,,}" =~ ^(y|yes)$ ]] || { warn "Restore cancelled."; return 0; }
  case "$backend" in
    nft)
      if nft --check -f "$selected" &>/dev/null; then
        nft flush ruleset
        if nft -f "$selected"; then
          success "nftables ruleset restored successfully."
        else
          error "Failed to commit nftables ruleset."
          return 1
        fi
      else
        error "nftables backup contains syntax errors! Aborting restore."
        nft --check -f "$selected"
        return 1
      fi
      ;;
    ufw)
      ufw disable >/dev/null 2>&1
      local skipped_rules=0
      while IFS= read -r rule; do
        [[ -z "$rule" || "$rule" =~ ^# ]] && continue
        if ufw --dry-run $rule &>/dev/null; then
          ufw $rule >/dev/null 2>&1
        else
          warn "Skipping corrupt UFW rule: $rule"
          ((skipped_rules++))
        fi
      done < "$selected"
      ufw enable >/dev/null 2>&1
      success "UFW ruleset restored ($skipped_rules corrupt rules skipped)."
      ;;
    firewalld)
      if firewall-cmd --check-config &>/dev/null; then
        firewall-cmd --permanent --load-config="$selected" &>/dev/null || return 1
        firewall-cmd --reload >/dev/null 2>&1
        success "Firewalld configuration restored successfully."
      else
        error "Firewalld backup file failed validation test! Aborting restore."
        return 1
      fi
      ;;
    iptables|ip6tables|*)
      sanitize_and_restore_iptables "$selected" || return 1
      ;;
  esac
  return 0
}
sanitize_and_restore_iptables() {
  local backup_file="$1"
  local cleaned_file fw_restore_bin
  [[ ! -f "$backup_file" ]] && { warn "Backup file not found: $backup_file"; return 1; }
  cleaned_file=$(mktemp /tmp/fw_clean.XXXXXX)
  fw_restore_bin="${fw_bin:-iptables}-restore"
  awk '
    BEGIN { buf = "" }
    {
      sub(/\r$/, "")
      if (buf != "" && $0 !~ /^(\*|:|-A|-I|-N|-X|-P|COMMIT|#|\[)/) {
        buf = buf " " $0
      } else {
        if (buf != "") print buf
        buf = $0
      }
    }
    END { if (buf != "") print buf }
  ' "$backup_file" \
  | grep -E '^(\*filter|\*nat|\*mangle|\*raw|\*security|:|-A|-I|-N|-X|-P|COMMIT|#|\[[0-9]+:[0-9]+\])' > "$cleaned_file"
  if ! $fw_restore_bin --test < "$cleaned_file" &>/dev/null; then
    error "Snapshot file contains syntax errors! Dry-run restore failed."
    $fw_restore_bin --test < "$cleaned_file"
    rm -f "$cleaned_file"
    return 1
  fi
  if $fw_restore_bin < "$cleaned_file" &>/dev/null; then
    rm -f "$cleaned_file"
    return 0
  else
    error "Failed to commit restored ruleset to kernel."
    rm -f "$cleaned_file"
    return 1
  fi
}
display_alias_ui() {
  local alias_file="/etc/one-click/rule-engine/.alias.conf"
  local i=1
  [[ -f "$alias_file" ]] || { warn "No aliases found."; return 1; }
  echo
  printf '%s\n' " " \
    "${blue}┌───┬───────────────┬──────────────────────────────────────────────────┐" \
    "${blue}│${yellow}ID ${blue}│ ${cyan}ALIAS NAME    ${blue}│ ${cyan}MAPPED IP(S)                                     ${blue}│${reset}" \
    "${blue}├───┼───────────────┼──────────────────────────────────────────────────┤${reset}"
  while IFS='=' read -r name ips; do
    [[ -z "$name" || "$name" =~ ^# ]] && continue
    local display_ips="${ips//,/ }"
    printf "${blue}│${reset} %-1s ${blue}│${reset} %-13s ${blue}│${reset} %-48s ${blue}│${reset}\n" "$i" "$name" "$display_ips"
    ((i++))
  done < "$alias_file"
  printf '%s\n' "${blue}└───┴───────────────┴──────────────────────────────────────────────────┘${reset}" " "
}
delete_alias() {
  [[ -f "$alias_file" ]] || { warn "No aliases to delete."; return 1; }
  mapfile -t alias_names < <(cut -d'=' -f1 "$alias_file" | grep -v '^#')
  if [[ ${#alias_names[@]} -eq 0 ]]; then
    warn "Alias file is empty."
    return 1
  fi
  display_alias_ui
  read -rp "${cyan}[USER]: ${reset}Enter the number of the alias to delete: " choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#alias_names[@]} )); then
    local target="${alias_names[$((choice-1))]}"
    read -rp "${red}[CONFIRM]:${reset} Permanently delete alias '$target'? (y|n): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
      sed -i "/^${target}=/d" "$alias_file"
      success "Alias '$target' removed."
      load_host_aliases
    fi
  else
    error "Invalid selection."
  fi
}
remove_ip_from_alias() {
  local alias_name ip_to_remove alias_file
  alias_name="$1"
  ip_to_remove="$2"
  alias_file="/etc/one-click/rule-engine/.alias.conf"
  if [[ -z "$alias_name" || -z "$ip_to_remove" ]]; then
    error "Usage: alias-prune [alias] [IP]"
    return 1
  fi
  if grep -q "^$alias_name=" "$alias_file"; then
    if ! grep -q "$ip_to_remove" "$alias_file"; then
	  warn "$alias_name does not contain $ip_to_remove in it's array"
	  return 1
	fi
    sed -Ei "/^$alias_name=/ {
	  s/(=)${ip_to_remove},|,${ip_to_remove}(,|$)/\1\2/g;
	}" "$alias_file"
    if grep -q "^$alias_name=$" "$alias_file"; then
      warn "Alias '$alias_name' is now empty. Deleting alias entry entirely."
      sed -i "/^$alias_name=$/d" "$alias_file"
    else
      success "IP $ip_to_remove removed from $alias_name."
    fi
  else
    error "Alias '$alias_name' not found."
  fi
}
record_event() {
  local file ip proto port reason user ts
  file="$1"
  ip="$2"
  proto="$3"
  port="$4"
  reason="$5"
  user="$6"
  ts=$(date +%s)
  echo "{\"ts\":$ts,\"ip\":\"$ip\",\"proto\":\"$proto\",\"port\":\"$port\",\"reason\":\"$reason\",\"user\":\"$user\"}" >> "$file"
}
alert_if_threshold() {
  local ip file threshold message count
  ip="$1"
  file="$2"
  threshold="$3"
  message="$4"
  count=$(grep -c "\"ip\":\"$ip\"" "$file")
  if (( count >= threshold )); then
    printf '[ALERT] %s for IP %s (%d occurrences)\n' "$message" "$ip" "$count"
  fi
}
apply_block() {
  local ip proto port action duration file
  ip="$1"
  proto="$2"
  port="$3"
  action="$4"
  duration="$5"
  file="$6"
  $fw_bin -I INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action"
  local ts
  ts=$(date +%s)
  echo "{\"ts\":$ts,\"ip\":\"$ip\",\"proto\":\"$proto\",\"port\":\"$port\",\"action\":\"$action\",\"duration\":$duration}" >> "$monitor_history_file"
  (
    sleep "$duration"
    if $fw_bin -C INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action" &>/dev/null; then
        $fw_bin -D INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action"
        echo "{\"ts\":$(date +%s),\"ip\":\"$ip\",\"action\":\"UNBLOCKED\",\"reason\":\"Timeout\"}" >> "$monitor_history_file"
    fi
  ) &
}
# ==== Dispatcher ====
start_journal_dispatcher() {
  local pid_file="/var/run/one_click_journal.pid"
  touch "$monitor_ssh_file"
  if [[ -f "$pid_file" ]]; then
    local old_pid=($(cat "$pid_file"))
	local service_name=$(awk 'NR==2{print $NF}' <(ps -p "$old_pid"))
    if ps -p "${old_pid[@]}" > /dev/null 2>&1; then
	  if [[ "$service_name" != "journalctl" ]]; then
	    awk '{print $1}' <(pgrep -af journalctl) | while read line; do
		  kill "$line"
		  rm "$pid_file"
		done
	  fi
    fi
  fi
  if [[ -f /etc/redhat-release ]]; then
    ssh_service=sshd.service
  else
    ssh_service=ssh.service
  fi
  journalctl -fn0 -u $ssh_service 2>/dev/null | while read -r line; do
    if [[ "$line" =~ "Failed password" ]]; then
	  guard_ssh "$line"
	fi
  done &
  awk '{print $1}' <(pgrep -af journalctl) > "$pid_file"
}
toggle_mitigation() {
  echo -e "${cyan}--- Mitigation Settings ---${reset}"
  echo "Current Mode: $( (( auto_mitigate == 1 )) && echo -e "${red}AUTOMATIC${reset}" || echo -e "${yellow}PASSIVE (Alert Only)${reset}" )"
  read -p "Enable automatic IP blocking? (y|n): " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    auto_mitigate=1
    echo "auto_mitigate=1" > "$guard_file"
    echo -e "${green}Automatic mitigation enabled.${reset}"
  else
    auto_mitigate=0
    echo "auto_mitigate=0" > "$guard_file"
    echo -e "${yellow}Passive mode enabled.${reset}"
  fi
}
show_mitigation_audit() {
  local ts ip act dur date
  printf '%s\n' "${blue}╔══════════════════════════════════════════════════════════╗"
  printf "║ ${magenta}ACTIVE MITIGATION LOGS (Last 10 Blocks)${blue}                  ║\n"
  printf '╚══════════════════════════════════════════════════════════╝%s\n' "${reset}"
  for file in "$monitor_ssh_file" "$monitor_ddos_file"; do
    [[ ! -f "$file" ]] && continue
    echo -e "${yellow}[ Source: $(basename "$file") ]${reset}"
    tail -n 20 "$file" | grep "\"action\":" | while read -r line; do
    ts=$(sed -E 's/.*"ts":([0-9]+).*/\1/' <<< "$line")
    ip=$(sed -E 's/.*"ip":"([^"]+)".*/\1/' <<< "$line")
    act=$(sed -E 's/.*"action":"([^"]+)".*/\1/' <<< "$line")
    dur=$(sed -E 's/.*"duration":([0-9]+).*/\1/' <<< "$line")
    date_str=$(date -d @"$ts" "+%H:%M:%S")
    printf "  ${cyan}%s${reset} | IP: ${red}%-15s${reset} | Action: ${yellow}%-5s${reset} | Duration: %ss\n" \
      "$date_str" "$ip" "$act" "$dur"
    done
  done
  echo ""
}
# ==== SSH Monitor ====
guard_ssh() {
  local line ip user fail_threshold
  line="$1"
  fail_threshold=5
  ip=$(sed -E 's/.*from ([0-9.]+|[0-9:a-fA-F:]+).*/\1/' <<< "$line")
  user=$(sed -E 's/.*for (invalid user )?([a-zA-Z0-9_-]+).*/\2/' <<< "$line")
  [[ -z "$ip" ]] && return
  record_event "$monitor_ssh_file" "$ip" "tcp" 22 "SSH failed login" "$user"
  if (( auto_mitigate == 1 )); then
    apply_block "$ip" "tcp" 22 "DROP" 300 "$monitor_ssh_file"
  fi
}
# ==== DDoS Monitor ====
monitor_ddos() {
  [[ -f /var/run/monitor_ddos.pid ]] && return
  touch "$monitor_ddos_file"
  while true; do
    ss -Htn src : | awk '{print $5}' | sort | uniq -c | while read -r count ip; do
      (( count > 50 )) || continue
      record_event "$monitor_ddos_file" "$ip" "tcp" "any" "High connection rate ($count)"
      alert_if_threshold "$ip" "$monitor_ddos_file" 50 "Possible DDoS detected"
    done
      sleep 1
  done &
  echo $! > /var/run/monitor_ddos.pid
}
start_monitors() {
  start_journal_dispatcher
  monitor_ddos
}
view_ssh_stats() {
  local last_view_ts=$(cat "$last_audit" 2>/dev/null || echo 0)
  local current_ts=$(date +%s)
  printf '%s\n' " " "Take action against brute force attempts with useful insight into the actor and hintable patterns" \
    "You can drop malicious actors at the firewall with ${cyan}one-click engine 'audit drop <ID number>'${reset}" \
	"If a row has a background color, the IP is already in the drop list" " "
  printf "${blue}%s${reset}\n" \
    "╔══════╦═════════════════╦═════════╦══════════════════════════════════════════════════════════╦═════════════╗" \
    "║ ${magenta}ID${blue}   ║ ${magenta}IP${blue}              ║ ${magenta}COUNT${blue}   ║ ${magenta}USERS${blue}                                                    ║ ${magenta}LAST SEEN${blue}   ║" \
    "╠══════╬═════════════════╬═════════╬══════════════════════════════════════════════════════════╬═════════════╣"
  local id_counter=1
  set +o pipefail
  jq -r '[.ip, .user, .ts] | @tsv' "$monitor_ssh_file" 2>/dev/null | \
  awk -F'\t' '
    {
      count[$1]++;
      if ($2 != "" && $2 != "null") users[$1] = (users[$1] == "" ? $2 : users[$1] "," $2);
      if ($3 > last[$1]) last[$1] = $3;
    }
    END {
      for (ip in count) {
        split(users[ip], a, ",");
        delete u;
        u_list="";
        for (i in a) if (!(a[i] in u)) { u[i]; u_list = (u_list == "" ? a[i] : u_list "," a[i]) };
        print ip "\t" count[ip] "\t" u_list "\t" last[ip]
      }
    }' | sort -rnk2 | sed -E '
	  :a;
	  s/([^,]*,)([a-z_]*,)?\1/\2/;
	  ta
	' | while IFS=$'\t' read -r ip count users last; do
      local d_last=$(date -d @"$last" "+%m-%d %H:%M")
      local display_users="${users:0:53}"; [[ ${#users} -gt 53 ]] && display_users="${display_users}.."
	  cln_ip="$ip"
	  if (( count <= 5 )); then
	    ip="${green}${ip}${reset}"
        count="${green}${count}${reset}"
	    display_users="${green}${display_users}${reset}"
  	    d_last="${green}${d_last}${reset}"
		colored=234
      elif (( count > 5 && count <= 20 )); then
	    ip="${yellow}${ip}${reset}"
        count="${yellow}${count}${reset}"
	    display_users="${yellow}${display_users}${reset}"
	    d_last="${yellow}${d_last}${reset}"
		colored=197
      else
	    ip="${red}${ip}${reset}"
        count="${red}${count}${reset}"
	    display_users="${red}${display_users}${reset}"
	    d_last="${red}${d_last}${reset}"
		colored=208
      fi
	  t_flag=0
	  blocked_ips=($( sed -En '/[0-9a-fA-F]+[.:]/{/reject|drop/{s/[^.:]* ([0-9.:a-fA-F]+).*/\1/p}}' <(nft list ruleset 2> /dev/null) <(iptables -S) <(ip6tables -S)))
	  for rejected in "${blocked_ips[@]}"; do
	    if [[ "$cln_ip" =~ "$rejected" ]]; then
		  t_flag=1
		fi
	  done
	  if [[ "$t_flag" -eq 1 ]]; then
        local colored_id=$(printf "$(tput setab $colored)${magenta}%-4s$(tput sgr0)" "$id_counter")
		local colored_ip=$(printf "$(tput setab $colored)${magenta}%-27s$(tput sgr0)" "$ip")
		local colored_count=$(printf "$(tput setab $colored)${magenta}%-19s$(tput sgr0)" "$count")
		local colored_users=$(printf "$(tput setab $colored)${magenta}%-68s$(tput sgr0)" "$display_users")
		local colored_last=$(printf "$(tput setab $colored)${magenta}%-23s$(tput sgr0)" "$d_last")
        printf "${blue}║${reset} %b ${blue}║${reset} %b ${blue}║${reset} %b ${blue}║${reset} %b ${blue}║${reset} %b ${blue}║${reset}\n" \
          "$colored_id" "$colored_ip" "$colored_count" "$colored_users" "$colored_last"
      else
        printf "${blue}║${reset} %-16s ${blue}║${reset} %-27s ${blue}║${reset} %-19s ${blue}║${reset} %-68s ${blue}║${reset} %-23s ${blue}║${reset}\n" \
          "${magenta}$id_counter${reset}" "$ip" "$count" "$display_users" "$d_last"
      fi
      ((id_counter++))
    done
  printf "${blue}%s${reset}\n" "╚══════╩═════════════════╩═════════╩══════════════════════════════════════════════════════════╩═════════════╝${reset}"
  date +%s > "$last_audit"
  set -o pipefail
}
show_rules() {
  local fw_bin total_blocked_pkts total_blocked_bytes clean_rule clean_src clean_dst clean_pkts color table_output tables chains p_count ips
  fw_bin="${fw_bin:-iptables}"
  total_blocked_pkts=0
  total_blocked_bytes=0
  clean_pkts=0
  local track_flag=0
  local cnt=1
  last_view_ts=$(cat "$last_audit" 2>/dev/null || echo 0)
  individual_table_rules() {
    if command -v nft >/dev/null; then
      printf '%s\n' \
        "${blue}╔══════════════════════════════╗" \
        "║ ${cyan}Transverse NFTables (F2B)    ${blue}║" \
        "╚══════════════════════════════╝${reset}"
      while read -r _ family table_name <&3; do
        [[ -z "$table_name" ]] && continue
        printf '%s\n' "  [ TABLE: ${yellow}${table_name^^}${reset} ]"
        table_output=$(nft list table "$family" "$table_name" 2>/dev/null)
		printf '%s\n' "          │" "          ├─▶ Chain: ${magenta}${family^^}${reset}"
        while read -r line; do
		  [[ -z "$line" || "$line" == "{" || "$line" == "}" ]] && continue
          color=$reset
          [[ "$line" == *"accept"* ]] && color="${green}ACCEPT${reset}"
          [[ "$line" == *"drop"* || "$line" == *"reject"* ]] && color="${red}REJECT${reset}"
          [[ "$line" == *"log"* ]] && color="${yellow}RETURN${reset}"
		  p_count=0
		  current_pkts=0
          if [[ "$line" == *"packets"* ]]; then
            p_count=$(echo "$line" | grep -oP 'packets \K[0-9]+')
			current_pkts=${p_count:-0}
            (( total_blocked_pkts += current_pkts )) || true
          fi
          if [[ "$line" == *"reject"* || "$line" == *"drop"* ]]; then
            printf "          │    └── [${cnt}] $current_pkts pkts ▶ %b%s%b\n" "$color " "$(echo "$line" | sed 's/^[ \t]*//')" "$reset"
            ((cnt++))
		  fi
          if [[ "$line" == *"@addr-set"* ]]; then
            local set_name=$(echo "$line" | grep -oP '@\K[a-zA-Z0-9_-]+')
             ips=$((nft list set "$family" "$table_name" "$set_name" 2>/dev/null | grep -oP '(\d{1,3}\.){3}\d{1,3}') || true)
             for ip in $ips; do
               printf "          │    └── [${cnt}] $current_pkts pkts ▶ ${red}Banned IP:${reset} %s\n" "$ip"
			   ((cnt++))
             done
          fi
        done <<< "$table_output"
      done 3< <(nft list tables)
    fi
    tables=($((${fw_bin:-iptables}-save 2>/dev/null | grep '^*' | cut -d'*' -f2) || true))
	set +o pipefail
    printf '%s\n' \
      "${blue}╔══════════════════════════════╗" \
      "║ ${cyan}Transverse Legacy Tables     ${blue}║" \
      "╚══════════════════════════════╝${reset}"
    for tbl in "${tables[@]}"; do
      if ! $fw_bin -t "$tbl" -S 2>/dev/null | grep -qE "^-A"; then
        continue
      fi
      printf '%s\n' "  [ TABLE: ${yellow}${tbl^^}${reset} ]"
      chains=$( $fw_bin -t "$tbl" -L 2>/dev/null | grep "Chain" | awk '{print $2}' )
      for chain in $chains; do
        local rules=$($fw_bin -t "$tbl" -vnL "$chain" --line-numbers 2>/dev/null | grep -E "^[0-9]")
        [[ -z "$rules" ]] && continue
        # ==== One-Click Fleet Chain ====
		if [[ "$chain" == "ONE-CLICK-FLEET" ]]; then
          printf '%s\n' "          │" "          ├─▶ Chain: ${magenta}${chain} ${green}[ONE-CLICK MESH]${reset}"
          while read -r num pkts bytes target prot opt in out src dst rest; do
            clean_src=$( [[ "$src" == "0.0.0.0/0" ]] && echo "anywhere" || echo "$src" )
            clean_dst=$( [[ "$dst" == "0.0.0.0/0" ]] && echo "anywhere" || echo "$dst" )
            local color=$reset
            local label_suffix=""
            if [[ "$target" == "ACCEPT" ]]; then
              color=$green
              [[ "$clean_src" != "anywhere" ]] && label_suffix=" ${cyan}[FLEET NODE]${reset}"
            elif [[ "$target" == "DROP" || "$target" == "REJECT" ]]; then
              color=$red
              label_suffix=" ${red}[CATCH-ALL BARRIER]${reset}"
              clean_pkts=$(echo "$pkts" | sed 's/[KMG]//g; s/\..*//; s/[^0-9]//g')
              [[ "$pkts" == *K* ]] && clean_pkts=$((clean_pkts * 1000))
              [[ "$pkts" == *M* ]] && clean_pkts=$((clean_pkts * 1000000))
              (( total_blocked_pkts += ${clean_pkts:-0} )) || true
            fi
            printf '%s\n' "          │    └── [${num}] ${pkts} pkts ▶ ${color}${target}${reset} (${clean_src} → ${clean_dst}${label_suffix} ${rest})"
          done <<< "$rules"
          continue
        fi
        printf '%s\n' "          │" "          ├─▶ Chain: ${magenta}${chain}${reset}"
        while read -r num pkts bytes target prot opt in out src dst rest; do
          clean_pkts=$(echo "$pkts" | sed 's/[KMG]//g; s/\..*//; s/[^0-9]//g')
          [[ "$pkts" == *K* ]] && clean_pkts=$((clean_pkts * 1000))
          [[ "$pkts" == *M* ]] && clean_pkts=$((clean_pkts * 1000000))
          clean_src=$( [[ "$src" == "0.0.0.0/0" ]] && echo "anywhere" || echo "$src" )
          clean_dst=$( [[ "$dst" == "0.0.0.0/0" ]] && echo "anywhere" || echo "$dst" )
          color=$reset
          [[ "$target" == "ACCEPT" ]] && color=$green
          [[ "$target" == "DROP" || "$target" == "REJECT" ]] && color=$red
          printf '%s\n' "          │    └── [${num}] ${pkts} pkts ▶ ${color}${target}${reset} (${clean_src} → ${clean_dst} ${rest})"
          if [[ "$target" == "DROP" || "$target" == "REJECT" ]]; then
            (( total_blocked_pkts += ${clean_pkts:-0} )) || true
          fi
        done <<< "$rules"
      done
    done
    printf '%s\n' "  ▼───────┴──────────▼" "  │ END OF TRAVERSAL │" "  └──────────────────┘"
    width=82
    printf "${blue}╔%s╗${reset}\n" "$(printf '═%.0s' $(seq 1 $width))"
    local audit_line="[AUDIT]: Your security rules intercepted ${total_blocked_pkts} packets today."
    local clean_audit=$(echo -e "$audit_line" | sed "s/\x1B\[[0-9;]*[mK]//g")
    local padding=$((width - ${#clean_audit} - 1))
    printf "${blue}║ ${yellow}[AUDIT]:${reset} Your security rules intercepted ${red}${total_blocked_pkts}${reset} packets today.%${padding}s${blue}║${reset}\n" ""
    for file in "$monitor_ssh_file" "$monitor_ddos_file"; do
      [[ ! -f "$file" ]] && continue
      local count=$(wc -l < "$file")
      local fname=$(basename "$file")
      local file_line="[AUDIT]: $count malicious $fname events recorded."
      local clean_file=$(echo "$file_line")
      local f_padding=$((width - ${#clean_file} - 1))
      printf "${blue}║ ${yellow}[AUDIT]:${reset} %s malicious ${cyan}%s${reset} events recorded.%${f_padding}s${blue}║${reset}\n" \
        "$count" "$fname" ""
    done
	if [[ -f "/var/log/one-click/events.json" ]]; then
	date_time=$(grep "integrity_mismatch" /var/log/one-click/system_events.log | jq -r '.datetime + " -> " + .data.file')
    crit_count=$(grep -c "integrity_mismatch" /var/log/one-click/events.json)
      if [[ $crit_count -gt 0 ]]; then
        warn "${red}SCANNER ALERT:${yellow} ${crit_count} binary tampering events detected!${reset}"
      fi
    fi
	printf "${blue}╚%s╝${reset}\n" "$(printf '═%.0s' $(seq 1 $width))"
    if command -v start_monitors >/dev/null; then
	  start_monitors
	fi
	set -o pipefail
	return
  }
  individual_table_rules
  return
}
view_guard_history() {
  local ts ip act rea d_str
  [[ ! -s "$monitor_history_file" ]] && echo "No history found." && return
  printf "${blue}%s${reset}\n" \
    "╔══════════════════╦═════════════════╦═════════════════════════════════╗" \
    "║ ${yellow}TIMESTAMP${blue}        ║ ${yellow}IP${blue}              ║ ${yellow}ACTION${blue}                          ║" \
    "╠══════════════════╬═════════════════╬═════════════════════════════════╣"
  tail -n 15 "$monitor_history_file" | while read -r line; do
    ts=$(echo "$line" | jq -r '.ts')
    ip=$(echo "$line" | jq -r '.ip')
    act=$(echo "$line" | jq -r '.action')
    rea=$(echo "$line" | jq -r '.reason')
    d_str=$(date -d @"$ts" "+%m-%d %H:%M:%S")
    printf "${blue}║${reset} %-16s ${blue}║${reset} %-15s ${blue}║${reset} %-31s ${blue}║${reset}\n" \
      "$d_str" "$ip" "$act ($rea)"
  done
  printf "${blue}╚══════════════════╩═════════════════╩═════════════════════════════════╝${reset}\n"
}
add_fail2ban_jail() {
  local name="$1" port="$2" maxretry="$3" bantime="$4"
  local log_path
  if [[ -f /var/log/auth.log ]]; then
    log_path="/var/log/auth.log"
  elif [[ -f /var/log/secure ]]; then
    log_path="/var/log/secure"
  else
    log_path="/var/log/auth.log"
  fi
  [[ ! -f /etc/fail2ban/action.d/one-click_abuseipdb-report.conf ]] && setup_abuse_reporting
  cat <<EOF >> "$f2b_conf"
[$name]
enabled = true
port    = $port
filter  = sshd
logpath = ${log_path:-/var/log/secure}
maxretry = $maxretry
bantime  = $bantime
action   = iptables-multiport[name=$name, port="$port", protocol=tcp]
           abuseipdb-report[name=$name]
EOF
  success "Jail '$name' added."
}
setup_abuse_reporting() {
  cat << EOF > /etc/fail2ban/action.d/one-click_abuseipdb-report.conf
[Definition]
actionban = curl https://api.abuseipdb.com/api/v2/report \
  --data-urlencode "ip=<ip>" \
  --data-urlencode "categories=18,22" \
  --data-urlencode "comment=Brute force detected by One-Click Rule-Engine Guard" \
  -H "Key: $(cat /etc/one-click/rule-engine/guard/abuseipdb.key)" \
  -H "Accept: application/json"
EOF
}
view_global_banlist() {
    printf "${blue}%s\n${reset}" \
	  "╔═══════════════════════════════════════════════════════════════╗" \
      "║ ${cyan}RuleEngine Guard${blue} + Fail2Ban ${magenta}Banlist${blue}                           ║" \
      "╠══════════════════╦═════════════════╦══════════════╦═══════════╣" \
      "║ ${yellow}SOURCE${blue}           ║ ${yellow}IP${blue}              ║ ${yellow}JAIL/REASON${blue}  ║ ${yellow}STATUS${blue}    ║" \
      "╠══════════════════╬═════════════════╬══════════════╬═══════════╣"
	set +e
    fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:" | sed 's/.*list://' | tr ' ' '\n' | grep -v '^$' | while read -r f2b_ip; do
      printf "${blue}║ ${yellow}%-16s${blue} ║${reset} %-15s${blue} ║${reset} %-12s${blue} ║ ${red}%-9s${blue} ║${reset}\n" "Fail2Ban" "$f2b_ip" "sshd" "BANNED"
    done
	set -e
	if [[ -s "$monitor_history_file" ]]; then
      jq -r -s 'map(select(.action == "DROP" or .action == "BLOCKED")) | unique_by(.ip) | .[] | [.ip, (.reason // "Brute Force"), .ts] | @tsv' "$monitor_history_file" 2>/dev/null |
      while IFS=$'\t' read -r g_ip g_reason g_drop_ts; do
      g_reason="${g_reason:-Brute Force}"
      g_unblock_ts=$(jq -r --arg ip "$g_ip" 'select(.ip==$ip and .action=="UNBLOCKED") | .ts' "$monitor_history_file" 2>/dev/null | tail -n1)
      status="BANNED"
      color="${red}"
      if [[ -n "$g_unblock_ts" && "$g_unblock_ts" -gt "$g_drop_ts" ]]; then
        status="UNBLOCKED"
        color="${green}"
      fi
      printf "${blue}║ ${magenta}%-16s${blue} ║${reset} %-15s${blue} ║${reset} %-12s${blue} ║ ${color}%-9s${blue} ║${reset}\n" \
        "RuleEngine" "$g_ip" "${g_reason:0:12}" "$status"
    done
	fi
    printf "${blue}╚══════════════════╩═════════════════╩══════════════╩═══════════╝${reset}\n"
	return
}
check_ip_reputation() {
  local ip key_file api_key response score usage country color
  ip="$1"
  key_file="/etc/one-click/rule-engine/guard/abuseipdb.key"
  [[ ! -f "$key_file" ]] && echo "Error: API Key not set." && return
  api_key=$(cat "$key_file")
  info "${cyan}Querying AbuseIPDB for IP:${reset} $ip"
  response=$(curl -sG https://api.abuseipdb.com/api/v2/check \
    --data-urlencode "ipAddress=$ip" \
    -H "Key: $api_key" \
    -H "Accept: application/json")
  score=$(echo "$response" | jq -r '.data.abuseConfidenceScore')
  usage=$(echo "$response" | jq -r '.data.usageType // "Unknown"')
  country=$(echo "$response" | jq -r '.data.countryCode // "??"')
  color=$green
  (( score > 20 )) && color=$yellow
  (( score > 50 )) && color=$red
  info "  > ${cyan}Country:${reset} $country" \
    "  > ${cyan}Usage:${reset}   $usage" \
    "  > ${cyan}Abuse Score:${reset} ${color}${score}%${reset}"
  if (( score > 75 )); then
    error "${red}Highly malicious source detected!${reset}"
  fi
}
get_existing_rules() {
  local backend="$1"
  case "$backend" in
    nft)
      nft list ruleset
      ;;
    iptables)
      ${fw_bin:-iptables}-save
      ;;
    ufw)
      ufw status numbered
      ;;
    firewalld)
      firewall-cmd --list-all --zone=public
      ;;
    *)
      die "Unsupported firewall backend."
      ;;
  esac
}
apply_rule() {
  local backend="${firewall_backend:-iptables}"
  for cmd_str in "${generated_cmds[@]}"; do

    if [[ "$backend" == "iptables" || "$backend" == "ip6tables" ]]; then
      read -r -a fw_cmd <<< "$cmd_str"
      if rule_exists_iptables "${fw_cmd[@]}"; then
        warn "Duplicate rule detected: $cmd_str"
        continue
      fi
    fi
    if [[ "$CONFIRM_APPLY" == "1" ]]; then
      if eval "$cmd_str" &>/dev/null; then
        success "Rule applied: $cmd_str"
      else
        warn "Failed to apply rule: $cmd_str"
      fi
    fi
  done
}
display_iptables_ui() {
  local tbl mode title i total_width id_col_width rule_col_width
  tbl="$1"
  mode="$2"
  title="$3"
  i=1
  total_width=115
  id_col_width=5
  rule_col_width=$((total_width - id_col_width - 3))
  mapfile -t lines < <(
    $fw_bin -t "$tbl" $mode 2>/dev/null \
    | awk 'NF && $1 !~ /Chain|pkts|^$/ {print}'
  )
  echo
  printf "\e[34m┌%*s┐\e[0m\n" "$total_width" "───────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
  printf "\e[34m│ $(tput setaf 203)%-*s \e[34m│\e[0m\n" 113 "${title^^}: ${tbl^^} TABLE"
  printf "\e[34m├─────┬%*s┤\e[0m\n" $((rule_col_width)) "─────────────────────────────────────────────────────────────────────────────────────────────────────────────"
  printf "\e[34m│ %-3s │ %-*s │\e[0m\n" "#" $rule_col_width "FIREWALL RULE DEFINITION"
  printf "\e[34m├─────┼%*s┤\e[0m\n" $rule_col_width "─────────────────────────────────────────────────────────────────────────────────────────────────────────────"
  if [[ ${#lines[@]} -eq 0 ]]; then
    printf "\e[34m│ %-3s │ %-*s │\e[0m\n" "--" $rule_col_width "No active rules found in this table."
  else
    for line in "${lines[@]}"; do
      local rule_display="${line//$'\t'/ }"
      rule_display="$(echo "$rule_display" | tr -s ' ')"
      if (( ${#rule_display} > rule_col_width )); then
        rule_display="${rule_display:0:rule_col_width-3}."
      fi
      printf "\e[34m│ %-3s │ %-*s │\e[0m\n" "$i" $rule_col_width "$rule_display"
      ((i++))
    done
  fi
  printf "\e[34m└─────┴%*s┘\e[0m\n" $rule_col_width "─────────────────────────────────────────────────────────────────────────────────────────────────────────────"
  echo
}
rule_exists_iptables() {
  local cmd fw_bin
  cmd=("$@")
  # ==== Check v4 or v6 ====
  fw_bin="${cmd[0]:-}"
  [[ "$fw_bin" != "iptables" && "$fw_bin" != "ip6tables" ]] && fw_bin="iptables"
  if [[ "${cmd[0]:-}" == "$fw_bin" ]]; then
    cmd=("${cmd[@]:1}")
  fi
  if "$fw_bin" -C "${cmd[@]}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}
rule_exists_backend() {
  local backend="$1" proto="$2" port="$3" src_ip="$4" action="$5" chain="${6:-INPUT}"
  case "$backend" in
    iptables|ip6tables)
      local cmd=("$fw_bin" -C "${chain^^}" -p "$proto" --dport "$port")
      [[ -n "$src_ip" ]] && cmd+=("-s" "$src_ip")
      [[ -n "$action" ]] && cmd+=("-j" "$action")
      "${cmd[@]}" &>/dev/null
      return $?
      ;;
    ufw)
      local ufw_act="ALLOW"
      [[ "$action" == "DROP" || "$action" == "REJECT" || "$action" == "DENY" ]] && ufw_act="DENY"
      if [[ -n "$src_ip" ]]; then
        ufw status | grep -E -q "${port}/${proto}.*${ufw_act}.*${src_ip}"
      else
        ufw status | grep -E -q "${port}/${proto}.*${ufw_act}.*ANYWHERE"
      fi
      return $?
      ;;
    nft)
      local nft_act="accept"
      [[ "$action" == "DROP" || "$action" == "REJECT" ]] && nft_act="drop"
      if [[ -n "$src_ip" ]]; then
        nft list ruleset 2>/dev/null | grep -E -q "ip saddr ${src_ip}.*${proto} dport ${port}.*${nft_act}"
      else
        nft list ruleset 2>/dev/null | grep -E -q "${proto} dport ${port}.*${nft_act}"
      fi
      return $?
      ;;
    firewalld)
      if [[ -n "$src_ip" ]]; then
        local rich_act="accept"
        [[ "$action" == "DROP" || "$action" == "REJECT" ]] && rich_act="drop"
        firewall-cmd --zone=public --query-rich-rule="rule family=\"ipv4\" source address=\"$src_ip\" port port=\"$port\" protocol=\"$proto\" $rich_act" &>/dev/null
      else
        firewall-cmd --zone=public --query-port="${port}/${proto}" &>/dev/null
      fi
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}
clean_duplicate_rules() {
  local backend="${firewall_backend:-iptables}"
  local dup_tmpfile dup_cleanfile
  dup_tmpfile=$(mktemp)
  dup_cleanfile=$(mktemp)
  case "$backend" in
    nft)
      nft list ruleset 2>/dev/null > "$dup_tmpfile"
      grep -E '^\s*(ip|tcp|udp|udp|icmp|ct|meta)' "$dup_tmpfile" \
        | sed -E 's/comment ".*"//g; s/\s+/ /g; s/^\s+//; s/\s+$//' \
        | sort | uniq -c | awk '$1 > 1' > "$dup_cleanfile" || true
      ;;
    ufw)
      ufw status numbered 2>/dev/null > "$dup_tmpfile"
      grep -E '^\[' "$dup_tmpfile" \
        | sed -E 's/^\[\s*[0-9]+\]\s+//' \
        | tr -s ' ' \
        | sort | uniq -c | awk '$1 > 1' > "$dup_cleanfile" || true
      ;;
    firewalld)
      {
        firewall-cmd --zone=public --list-ports 2>/dev/null | tr ' ' '\n'
        firewall-cmd --zone=public --list-rich-rules 2>/dev/null
      } | grep -v '^$' | sort | uniq -c | awk '$1 > 1' > "$dup_cleanfile" || true
      ;;
    iptables|ip6tables|*)
      ${fw_bin:-iptables}-save 2>/dev/null > "$dup_tmpfile"
      grep '^-A' "$dup_tmpfile" \
        | sed -E 's/^-A/iptables -A/; s/\[[0-9]+:[0-9]+\] //g' \
        | sort | uniq -c | awk '$1 > 1' > "$dup_cleanfile" || true
      ;;
  esac
  if [[ ! -s "$dup_cleanfile" ]]; then
    if [[ "${dry_run:-0}" -eq 1 ]]; then
      printf "${magenta}[DRY-RUN]${reset} %s\n" "No existing duplicate rules found in active ruleset."
    else
      success "No duplicate rules found in active ruleset."
    fi
    rm -f "$dup_tmpfile" "$dup_cleanfile"
    return 0
  fi
  # ==== Display Duplicate Rules ====
  echo
  warn "Existing duplicate rules detected in active firewall ($backend):"
  echo "====================================================================="
  while read -r count rule; do
    printf "  ${red}(%d copies)${reset} %s\n" "$count" "$rule"
  done < "$dup_cleanfile"
  echo "====================================================================="
  echo
  if [[ "${y_interactive:-}" -eq 1 ]]; then
    clean_rules=y
  else
    read -rp "${cyan}[USER]:${reset} Would you like to purge duplicates retaining one copy of each? (y|n): " clean_rules
    clean_rules="${clean_rules,,}"
    if [[ "$clean_rules" != "y" && "$clean_rules" != "yes" ]]; then
      warn "Cleanup cancelled."
      rm -f "$dup_tmpfile" "$dup_cleanfile"
      return 0
    fi
  fi
  warn "Cleaning duplicate rules."
  case "$backend" in
    nft)
      awk '
        /^\s*(ip|tcp|udp|icmp|ct|meta)/ {
          norm = $0; gsub(/\s+/, " ", norm); gsub(/^\s+|\s+$/, "", norm);
          if (seen[norm]++) next
        }
        { print }
      ' "$dup_tmpfile" > "${dup_tmpfile}.deduped"
      nft -f "${dup_tmpfile}.deduped" 2>/dev/null || { warn "Failed to reload nftables."; rm -f "$dup_tmpfile" "$dup_cleanfile" "${dup_tmpfile}.deduped"; return 1; }
      ;;

    ufw)
      mapfile -t dup_rules < <(grep -E '^\[' "$dup_tmpfile" | sed -E 's/^\[\s*([0-9]+)\].*/\1/')
      declare -A seen_ufw
      for idx in "${dup_rules[@]}"; do
        rule_str=$(sed -n "${idx}p" "$dup_tmpfile")
        if [[ -n "${seen_ufw[$rule_str]:-}" ]]; then
          echo "y" | ufw delete "$idx" &>/dev/null
        else
          seen_ufw[$rule_str]=1
        fi
      done
      ;;
    firewalld)
      while read -r count rule; do
        if [[ "$rule" =~ ^rule ]]; then
          firewall-cmd --zone=public --remove-rich-rule="$rule" &>/dev/null
          firewall-cmd --zone=public --add-rich-rule="$rule" &>/dev/null
        else
          firewall-cmd --zone=public --remove-port="$rule" &>/dev/null
          firewall-cmd --zone=public --add-port="$rule" &>/dev/null
        fi
      done < "$dup_cleanfile"
      ;;
    iptables|ip6tables|*)
      awk '
        /^-A/ {
          rule_body = $0
          sub(/^\[[0-9]+:[0-9]+\] /, "", rule_body)
          if (seen[rule_body]++) next
        }
        { print }
      ' "$dup_tmpfile" > "${dup_tmpfile}.deduped"
        ${fw_bin:-iptables}-restore < "${dup_tmpfile}.deduped" 2>/dev/null || {
        warn "Restore failed using ${fw_bin:-iptables}-restore."
        rm -f "$dup_tmpfile" "$dup_cleanfile" "${dup_tmpfile}.deduped" || true
        return 1
      }
      ;;
  esac
  rm -f "$dup_tmpfile" "$dup_cleanfile" "${dup_tmpfile}.deduped" 2>/dev/null
  success "Duplicate cleanup complete." "Retained exactly one copy of each rule."
}
load_sensitive_ports() {
  sensitive_ports=("${!default_sensitive_ports[@]}")
  if [[ -f "$sensitive_ports_file" ]]; then
    while IFS= read -r s_port; do
      [[ -z "$s_port" ]] && continue
      [[ "$s_port" =~ ^# ]] && continue
      sensitive_ports+=("$s_port")
    done < "$sensitive_ports_file"
  fi
  # ==== Remove Duplicates ====
  declare -A _seen
  _unique_sensitive_ports=()
  for unique in "${sensitive_ports[@]}"; do
    if [[ -z "${_seen[$unique]:-}" ]]; then
      _unique_sensitive_ports+=("$unique")
      _seen[$unique]=1
    fi
  done
  sensitive_ports=("${_unique_sensitive_ports[@]}")
  }
save_sensitive_ports() {
  mkdir -p "$(dirname "$sensitive_ports_file")"
  printf "%s\n" "${sensitive_ports[@]}" > "$sensitive_ports_file"
}
check_sensitive_ports() {
  local proto current_action
  proto="$1"
  local -n ports_ref="$2"
  current_action="$3"
  load_sensitive_ports
  for p in "${ports_ref[@]}"; do
    if [[ -n "${alerted_ports[$p]:-}" ]]; then
      continue
    fi
    if [[ -n "${default_sensitive_ports[$p]:-}" ]]; then
      local service_desc alert1 alert2 len1 len2 width border border2
	  service_desc="${default_sensitive_ports[$p]}"
	  if [[ "$dry_run" -eq 1 ]]; then
        alert1="${magenta}[DRY-RUN]${reset} Action: $current_action detected on Port $p ($service_desc)."
        alert2="${magenta}[DRY-RUN]${reset} This is a CORE SERVICE. Proceeding may cause connectivity issues! "
	  else
        alert1="${yellow}[ALERT]${reset} Action: $current_action detected on Port $p ($service_desc)."
        alert2="${yellow}[ALERT]${reset} This is a CORE SERVICE. Proceeding may cause connectivity issues! "
	  fi
      len1=${#alert1}
      len2=${#alert2}
      width=$(( len1 > len2 ? len1 : len2 ))
      border=$(printf '═%.0s' $(seq 1 "$(((width + 2)-12))"))
	  border2=$(printf '═%.0s' $(seq 1 "$(((width / 2)-16))"))
      case "$current_action" in
        DROP|REJECT|DELETE)
          echo -e "${red}╔${border2} ${yellow}[ CRITICAL WARNING ]${red} ${border2}╗${reset}"
          printf "${red}║${reset} %-*s ${red}║${reset}\n" "$width" "$alert1"
          printf "${red}║${reset} %-*s ${red}║${reset}\n" "$width" "$alert2"
          echo -e "${red}╚${border}╝${reset}"
          alerted_ports[$p]=1
          ;;
        ACCEPT|OPEN|ALLOW)
          warn "Note: You are opening $p ($service_desc). Ensure this is intended."
		  alerted_ports[$p]=1
          ;;
        LOG)
          info "Monitoring $service_desc activity."
		  alerted_ports[$p]=1
          ;;
      esac
    fi
  done
}
parse_firewall_command() {
  export TERM=xterm-256color
  local rule rule_lower action port port_range src_ip dst_ip proto chain mode table del_line fw_bin ip_version
  fw_bin="iptables"
  ip_version="ipv4"
  rule="$1"
  inherited_proto="$2"
  action=""
  port=""
  ports=""
  port_range=""
  src_ip=""
  dst_ip=""
  proto="tcp"
  chain=""
  mode="-I"
  table="filter"
  last_audit="/etc/one-click/rule-engine/guard/last_audit"
  del_line=""
  rule_lower="${rule,,}"
  f2b_conf="/etc/fail2ban/jail.local"
  abuse_conf="/etc/one-click/rule-engine/guard/abuseipdb.key"
  guard_dir="/etc/one-click/rule-engine/guard/"
  monitor_ddos_file="/etc/one-click/rule-engine/guard/ddos"
  monitor_ssh_file="/etc/one-click/rule-engine/guard/ssh"
  monitor_history_file="/etc/one-click/rule-engine/guard/history"
  auto_mitigate="$AUTO_MITIGATION"
  mkdir -p "$guard_dir"
  # ==== Guard Conf ====
  guard_file="${guard_dir}/guard.conf"
  load_config() {
    [[ -f "$guard_file" ]] && source "$guard_file"
  }
  start_monitors
  # ==== Collect AbuseIPDB Key ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+(set|key|set-abuse-key)[[:space:]]+([a-zA-Z0-9]+) ]]; then
    echo "${BASH_REMATCH[2]}" > "$abuse_conf"
    chmod 600 "$abuse_conf"
    success "AbuseIPDB API Key stored securely."
    exit 0
  fi
  if [[ "$rule_lower" =~ ^audit[[:space:]]+(set|key|set-abuse-key)$ ]]; then
     printf '%s\n' "${red}╔═════════════════════ [ ERROR ] ════════════════════╗${reset}" \
      "${red}║${reset} Incomplete Command:                                ${red}║${reset}" \
      "${red}║${reset} Usage: one-click engine 'audit key <IPDB API Key>' ${red}║${reset}" \
      "${red}╚════════════════════════════════════════════════════╝${reset}"
    exit 1
  fi
  # ==== Add Sensitive Ports ====
  if [[ "$rule_lower" =~ ^sensitive: ]]; then
    load_sensitive_ports
    local new_ports
    new_ports=($(grep -oE '[0-9]{1,5}' <<< "$rule"))
    for p in "${new_ports[@]}"; do
      if valid_port "$p"; then
        if ! [[ " ${sensitive_ports[*]} " =~ " $p " ]]; then
          sensitive_ports+=("$p")
        fi
      else
        warn "Ignored invalid port: $p"
      fi
    done
    save_sensitive_ports
    info "Sensitive ports updated: ${sensitive_ports[*]}"
    exit 0
  fi
  # ==== Remove Sensitive Ports ====
  if [[ "$rule_lower" =~ ^sensitive-remove: ]]; then
    load_sensitive_ports
    local remove_ports
    remove_ports=($(grep -oE '[0-9]{1,5}' <<< "$rule"))
    for p in "${remove_ports[@]}"; do
      sensitive_ports=("${sensitive_ports[@]/$p}")
    done
    save_sensitive_ports
    info "Sensitive ports updated (after removal): ${sensitive_ports[*]}"
    exit 0
  fi
  # ==== List Server Ports ====
  if [[ "$rule_lower" =~ ^sensitive-list ]]; then
    load_sensitive_ports
    if (( ${#sensitive_ports[@]} == 0 )); then
      info "No sensitive ports configured."
    else
      info "Current sensitive ports:"
	  printf "$(tput setaf 267)[$(tput setaf 299)SENSITIVE PORT$(tput setaf 267)]${reset} %s\n" "${sensitive_ports[@]}"
    fi
    exit 0
  fi
  # ==== Detect Append Alias ====
  if [[ "$rule_lower" =~ ^(alias-append):?[[:space:]]+([a-z0-9_-]+)[[:space:]]+([0-9./:]+([[:space:]]+[0-9./:]+)*) ]]; then
    local alias_name new_ips_raw existing_ips new_ips_comma combined_list
	alias_name="${BASH_REMATCH[2]}"
    new_ips_raw="${BASH_REMATCH[3]}"
    if [[ ! -f "$alias_file" ]] || ! grep -q "^${alias_name}=" "$alias_file"; then
      error "Alias '$alias_name' does not exist. Use 'alias-create' to create it first."
      exit 1
    fi
    existing_ips=$(sed -n "s/^${alias_name}=//p" "$alias_file")
    new_ips_comma=$(echo "$new_ips_raw" | tr ' ' ',')
    combined_list=$(echo "${existing_ips},${new_ips_comma}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//;s/^,//')
    sed -Ei "s|^(${alias_name}=).*|\1${combined_list}|" "$alias_file"
    success "Alias '$alias_name' updated. Total IPs: $(echo "$combined_list" | tr ',' ' ')"
    exit 0
  fi
  # ==== Detect System Scan ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+scan(ner)?$ ]]; then
    python3 /var/cache/one-click/scanner.py
	exit 0
  fi
  if [[ "$rule_lower" =~ ^audit[[:space:]]+scan(ner)?[[:space:]]+--init$ ]]; then
    python3 /var/cache/one-click/scanner.py --init
	exit 0
  fi
  if [[ "$rule_lower" =~ ^audit[[:space:]]+scan(ner)?[[:space:]]+--deep$ ]]; then
    python3 /var/cache/one-click/scanner.py --deep
	exit 0
  fi
  if [[ "$rule_lower" =~ ^audit[[:space:]]+scan(ner)?[[:space:]]+--remediate$ ]]; then
    python3 /var/cache/one-click/scanner.py --remediate
	exit 0
  fi
  if [[ "$rule_lower" =~ ^audit[[:space:]]+scan(ner)?([[:space:]]+(--deep))?[[:space:]]+-y$ ]]; then
    deep="${BASH_REMATCH[3]}"
	if [[ -z "${BASH_REMATCH[3]}" ]]; then
      python3 /var/cache/one-click/scanner.py -y
	else
	  python3 /var/cache/one-click/scanner.py "$deep" -y
	fi
	exit 0
  fi
  # ==== Detect Guard Jail ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+jail[[:space:]]+([a-z0-9]+)[[:space:]]+port[[:space:]]+([0-9]+)[[:space:]]+retry[[:space:]]+([0-9]+) ]]; then
    local j_name="${BASH_REMATCH[1]}"
    local j_port="${BASH_REMATCH[2]}"
    local j_retry="${BASH_REMATCH[3]}"
    add_fail2ban_jail "$j_name" "$j_port" "$j_retry" "3600"
	systemctl restart fail2ban
    exit 0
  fi
  # ==== Detect Banlist ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+banlist ]]; then
    view_global_banlist
    exit 0
  fi
  # ==== Detect Lookup ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+lookup[[:space:]]+([0-9.]+) ]]; then
    check_ip_reputation "${BASH_REMATCH[1]}"
    exit 0
  fi
  # ==== Detect Guard Unblock ====
  if [[ "$rule_lower" =~ ^(audit|ssh)[[:space:]]+(unblock|unlock|release)[[:space:]]+([0-9]+)$ ]]; then
    local target_id="${BASH_REMATCH[3]}"
    local target_ip=$(jq -r -s 'group_by(.ip) | .[] | [.[0].ip, length] | @tsv' "$monitor_ssh_file" | sort -rnk2 | sed -n "${target_id}p" | awk '{print $1}')
    if [[ -z "$target_ip" ]]; then
      error "Invalid ID: $target_id"
      exit 1
    fi
    $fw_bin -D INPUT -p tcp --dport 22 -s "$target_ip" -j DROP &>/dev/null
    echo "{\"ts\":$(date +%s),\"ip\":\"$target_ip\",\"action\":\"UNBLOCKED\",\"reason\":\"Manual Override\"}" >> "$monitor_history_file"
    success "IP $target_ip has been manually unblocked and history updated."
    exit 0
  fi
  # ==== Detect Guard Block ====
  if [[ "$rule_lower" =~ ^(audit|ssh)[[:space:]]+(delete|drop|block|reject)[[:space:]]+(guard[[:space:]]+)?([0-9]+) ]]; then
    local target_id="${BASH_REMATCH[4]}"
	local duration=3600
    local target_ip=$(
	  jq -r '[.ip, .user, .ts] | @tsv' "$monitor_ssh_file" |   awk -F'\t' '
        {
          count[$1]++;
          if ($2 != "" && $2 != "null") users[$1] = (users[$1] == "" ? $2 : users[$1] "," $2);
          if ($3 > last[$1]) last[$1] = $3;
        }
        END {
          for (ip in count) {
            split(users[ip], a, ",");
            delete u;
            u_list="";
            for (i in a) if (!(a[i] in u)) { u[i]; u_list = (u_list == "" ? a[i] : u_list "," a[i]) };
            print ip "\t" count[ip] "\t" u_list "\t" last[ip]
          }
        }
	  ' | sort -rnk2 | sed -E '
	    :a;
		s/([^,]*,)([a-z_]*,)?\1/\2/;
		ta
	  ' | awk -v w="${target_id}" 'NR == w{print $1}'
	)
	if [[ -z "$target_ip" ]]; then
      error "Invalid Guard ID: $target_id. Check 'audit ssh' for valid IDs."
      exit 1
    fi
	info "Mitigating Guard ID $target_id: Blocking IP $target_ip"
	if [[ "$rule_lower" =~ (dur=|duration=)([0-9]+) ]]; then
      duration="${BASH_REMATCH[2]}"
    fi
	if [[ "$rule_lower" =~ (perm|permanent) ]]; then
      duration=315360000
    fi
	total_seconds="$duration"
    h=$(( total_seconds / 3600 ))
    m=$(( (total_seconds % 3600) / 60 ))
    s=$(( total_seconds % 60 ))
	convert_duration=$(printf "%02d Hour %02d Minutes %02d Seconds\n" $h $m $s)
    apply_block "$target_ip" "tcp" 22 "DROP" "$duration" "$monitor_ssh_file"
    success "IP $target_ip has been dropped and logged for $duration seconds ($convert_duration)."
    exit 0
  fi
  # ==== Detect Guard History ====
  if [[ "$rule_lower" =~ ^(audit|ssh)[[:space:]]+(guard[[:space:]]+)?history ]]; then
    view_guard_history
    exit 0
  fi
  # ==== Detect Audit ====
  if [[ "$rule_lower" =~ ^audit$ ]]; then
    guard_dir="/etc/one-click/rule-engine/guard/"
    monitor_ddos_file="/etc/one-click/rule-engine/guard/ddos"
    monitor_ssh_file="/etc/one-click/rule-engine/guard/ssh"
    auto_mitigate=0
    mkdir -p "$guard_dir"
    info "Starting Deep Traffic Intelligence Audit."
    local total_conns=$(ss -tun | grep -c "ESTAB")
    echo -e "${cyan}Active Connections:${reset} $total_conns"
    echo -e "${cyan}Top Listening Services:${reset}"
    ss -ltpn | grep "LISTEN" | awk '{print $4}' | cut -d: -f2 | sort -n | uniq -c | awk '{print "  Port "$2" ("$1" instances)"}'
    show_rules
    exit 0
  fi
  # ==== Detect SSH Audit ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+ssh$ ]]; then
    view_ssh_stats
	exit 0
  fi
  # ==== Detect Alias Management ====
  if [[ "$rule_lower" =~ (list|display|view)[[:space:]]+(alias|aliases|names) ]]; then
    display_alias_ui
    exit 0
  fi
  if [[ "$rule_lower" =~ (delete|remove|purge|forget)[[:space:]]+(alias|aliases|name) ]]; then
    delete_alias
    exit 0
  fi
  # ==== ICMP Alias ====
  if grep -Eqi "\becho\b" <<< "$rule_lower"; then
    rule_lower="icmp"
  fi
  if grep -Eq "\b(masquerade|mask|hide|snat|dnat)\b" <<< "$rule_lower"; then
    skip_service_ports=1
  fi
  # ==== Raw Iptables ====
  if [[ "$rule_lower" =~ ^raw: ]]; then
      local raw_cmd
      raw_cmd="${rule#raw: }"
    # ==== Detect ip6tables ====
    if grep -Eq "\bip6tables\b" <<< "$raw_cmd"; then
      fw_bin="ip6tables"
    else
      fw_bin="iptables"
    fi
    # ==== Split Into Array ====
    read -r -a fw_cmd <<< "$raw_cmd"
    # ==== Prevent Dups ====
    if rule_exists_iptables "${fw_cmd[@]}"; then
      warn "Duplicate raw rule detected: ${fw_cmd[*]}"
      duplicate_skipped=1
      return 0
    fi
    generated_cmds+=("${fw_cmd[*]}")
    return 0
  fi
  # ==== Detect Backup ====
  if [[ "$rule_lower" =~ (backup|save|retain|copy|export|dump|snapshot)([[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy))? ]]; then
    backup_firewall
    exit 0
  fi
  # ==== Detect Restore ====
  if [[ "$rule_lower" =~ (restore|revive|recreate|regenerate|repair|import|reinstate)([[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy))? ]]; then
    restore_firewall
    exit 0
  fi
  # ==== Detect Delete Backup ====
  if [[ "$rule_lower" =~ (delete|remove|purge)[[:space:]]+(firewall|config|configuration|file|rules|ruleset|policy) ]]; then
    delete_firewall_backups
    exit 0
  fi
  # ==== Create custom chain ====
  if [[ "$rule_lower" =~ chain[[:space:]]+create[[:space:]]+([a-zA-Z0-9.+-]+) ]]; then
    new_chain="${BASH_REMATCH[1]}"
	new_chain="${new_chain^^}"
	if ! "$fw_bin" -N "$new_chain" 2>/dev/null; then
	  error "Chain already exists."
	  exit 1
	else
	  info "The following command has been applied"
	  echo "${cyan}[COMMAND] iptables -N $new_chain"
	  sleep 2
	  success "$new_chain chain created"
	  exit 0
	fi
  fi
  # ==== Detect Interface ====
  if [[ "$rule_lower" =~ (interface|iface)[[:space:]]+([a-zA-Z0-9.+]+) ]]; then
    in_interface="${BASH_REMATCH[2]}"
  elif grep -Eq "\blo\b" <<< "$rule_lower"; then
    in_interface="lo"
  fi
  # ==== Detect Custom Chain ====
  if [[ "$rule_lower" =~ chain[[:space:]]+([a-zA-Z0-9.+-]+) ]]; then
    custom_chain="${BASH_REMATCH[1]}"
	custom_chain="${custom_chain:-}"
	custom_chain="${custom_chain^^}"
  fi
  # ==== Detect Table ====
  if grep -Eqi "\bnat\b" <<< "$rule_lower"; then
    table="nat"
  elif grep -Eqi "\bmangle\b" <<< "$rule_lower"; then
    table="mangle"
  elif grep -Eqi "\braw\b" <<< "$rule_lower"; then
    table="raw"
  elif grep -Eqi "\bsecurity\b" <<< "$rule_lower"; then
    table="security"
  elif grep -Eq "\blog\b" <<< "$rule_lower"; then
    action="LOG"
  elif grep -Eq "\bmasquerade\b" <<< "$rule_lower"; then
    action="MASQUERADE"
  elif grep -Eq "\bsnat\b" <<< "$rule_lower"; then
    action="SNAT"
  elif grep -Eq "\bdnat\b" <<< "$rule_lower"; then
    action="DNAT"
  else
    table="filter"
  fi
  # ==== Detect Control ====
  if grep -Eqi "(^|[ ]+)(list|show|open|display)[ \t]?" <<< "$rule_lower"; then
    local view_mode="-L -n -v"
    local view_header="Table Listing"
    if grep -Eqi "\bnat\b" <<< "$rule_lower"; then
      table="nat"
    elif grep -Eqi "\bmangle\b" <<< "$rule_lower"; then
      table="mangle"
    elif grep -Eqi "\braw\b" <<< "$rule_lower"; then
      table="raw"
    elif grep -Eqi "\bsecurity\b" <<< "$rule_lower"; then
      table="security"
	elif [[ "$rule_lower" =~ table[[:space:]]+([a-zA-Z0-9.+]+) ]]; then
      table="${BASH_REMATCH[1]}"
    fi
    if grep -Eqi "\b(rules|script|save|raw-view)\b" <<< "$rule_lower"; then
      view_mode="-S"
      view_header="Rule Definitions"
    fi
	if grep -Eqi "\ball\b" <<< "$rule_lower"; then
      {
        for t in filter nat mangle raw; do
          display_iptables_ui "$t" "$view_mode" "$view_header"
          echo ""
        done
      } | less -RXE
      exit 0
    fi
    display_iptables_ui "$table" "$view_mode" "$view_header" | less -RXE
    exit 0
  fi
  # ==== Detect Negation ====
  src_neg=""
  if grep -Eq "\b(not|except|but not|!)\b" <<< "$rule_lower"; then
     src_neg="!"
  fi
  # ==== Detect Reject Type ====
  reject_with=""
  if [[ "$rule_lower" =~ (prohibited|host[ -]prohibited|admin[ -]prohibited|not[ -]allowed) ]]; then
    reject_with="icmp-host-prohibited"
    action="REJECT"
  fi
  # ==== Detect Default Policy ====
  if grep -Eq "\b(default|policy)\b" <<< "$rule_lower"; then
    generated_cmds+=("$fw_bin -t $table -P $chain $action")
    return 0
  fi
  # ==== Detect Chain ====
  case "$table" in
    filter)
	  if [[ -n "${custom_chain:-}" ]]; then
	    chain="${custom_chain^^}"
	  else
	    chain="INPUT"
	  fi
	  ;;
    nat|mangle|raw) chain="PREROUTING" ;;
    security)       chain="INPUT"      ;;
  esac
  if grep -Eqi "\boutput\b" <<< "$rule_lower"; then
    chain="OUTPUT"
  fi
  if grep -Eqi "\bforward\b" <<< "$rule_lower"; then
    chain="FORWARD"
  fi
  if grep -Eqi "\bprerouting\b" <<< "$rule_lower"; then
    chain="PREROUTING"
  fi
  if grep -Eqi "\bpostrouting\b" <<< "$rule_lower"; then
    chain="POSTROUTING"
  fi
  # ==== Detect Audit ====
  if [[ "$rule_lower" =~ ^audit$ ]]; then
    guard_dir="/etc/one-click/rule-engine/guard/"
    monitor_ddos_file="/etc/one-click/rule-engine/guard/ddos"
    monitor_ssh_file="/etc/one-click/rule-engine/guard/ssh"
    auto_mitigate=0
    mkdir -p "$guard_dir"
	touch "$monitor_ssh_file" "$monitor_ddos_file"
    info "Starting Deep Traffic Intelligence Audit."
    local total_conns=$(ss -tun | grep -c "ESTAB")
    echo -e "${cyan}Active Connections:${reset} $total_conns"
    echo -e "${cyan}Top Listening Services:${reset}"
    ss -ltpn | grep "LISTEN" | awk '{print $4}' | cut -d: -f2 | sort -n | uniq -c | awk '{print "  Port "$2" ("$1" instances)"}'
    show_rules
    exit 0
  fi
  # ==== Detect SSH Audit ====
  if [[ "$rule_lower" =~ ^audit[[:space:]]+ssh$ ]]; then
    view_ssh_stats
	exit 0
  fi
  # ==== Detect Action ====
  if grep -Eq "\b(drop|deny|block|stop|close|exclude)\b" <<< "$rule_lower"; then
    action="DROP"; mode="-A"
  elif grep -Eq "\b(reject|decline|bounce)\b" <<< "$rule_lower"; then
    action="REJECT"
  elif grep -Eq "\b(open|allow|permit|accept|add|include)\b" <<< "$rule_lower"; then
    action="ACCEPT"; mode="-I"
  elif grep -Eq "\b(masquerade|mask|hide)\b" <<< "$rule_lower"; then
    action="MASQUERADE"
  elif grep -Eq "\b(log)\b" <<< "$rule_lower"; then
    action="LOG"
  elif grep -Eq "\b(snat)\b" <<< "$rule_lower"; then
    action="SNAT"
  elif grep -Eq "\b(dnat)\b" <<< "$rule_lower"; then
    action="DNAT"
  elif grep -Eq "\b(mark)\b" <<< "$rule_lower"; then
    action="MARK"
  elif grep -Eq "\b(redirect)\b" <<< "$rule_lower"; then
    action="REDIRECT"
  elif grep -Eq "\b(tcpmss)\b" <<< "$rule_lower"; then
    action="TCPMSS"
  elif grep -Eq "\b(delete|remove)\b" <<< "$rule_lower"; then
    action="DELETE"; mode="-D"
  elif [[ -n "$last_action" ]]; then
    action="$last_action"
    [[ "$action" == "DROP" ]] && mode="-A"
    [[ "$action" == "ACCEPT" ]] && mode="-I"
    [[ "$action" == "DELETE" ]] && mode="-D"
  fi
  # ==== MASQUERADE / MASK / HIDE ====
  if grep -Eq "\b(masquerade|mask|hide)\b" <<< "$rule_lower"; then
    table="nat"
    chain="POSTROUTING"
    mode="-A"
    fw_bin="iptables"
    if [[ "$rule_lower" =~ from[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?) ]]; then
        src_ip="${BASH_REMATCH[1]}"
    fi
    fw_cmd=("$fw_bin" -t "$table" "$mode" "$chain")
    [[ -n "$src_ip" ]] && fw_cmd+=("-s" "$src_ip")
    fw_cmd+=("-j" "MASQUERADE")
    generated_cmds+=("${fw_cmd[*]}")
    return 0
  fi
  # ==== Detect flush / clear / reset ====
  if grep -Eqi "\b(flush|clear|reset)\b" <<< "$rule_lower"; then
    declare -a tables_to_flush=("filter" "nat" "mangle" "raw" "security")
    for tbl in "${tables_to_flush[@]}"; do
      if grep -Eqi "\b$tbl\b" <<< "$rule_lower"; then
        tables_to_flush=("$tbl")
        break
      fi
    done
    if grep -Eqi "\b(ipv6|ip6tables)\b" <<< "$rule_lower"; then
      fw_bin="ip6tables"
	  nf_bin="ip6"
    else
      fw_bin="iptables"
	  nf_bin="ip"
    fi
    if grep -Eqi "\ball\b" <<< "$rule_lower"; then
      info "Flushing all tables: ${tables_to_flush[*]} ($fw_bin)"
    else
      info "Flushing table(s): ${tables_to_flush[*]} ($fw_bin)"
    fi
    for tbl in "${tables_to_flush[@]}"; do
      generated_cmds+=("$fw_bin -t $tbl -F")
    done
    return 0
  fi
  # ==== Detect Protocol ====
  if grep -Eqi "\budp\b" <<< "$rule_lower"; then
    proto="udp"
  elif grep -Eqi "\btcp\b" <<< "$rule_lower"; then
    proto="tcp"
  elif grep -Eqi "\bicmp\b" <<< "$rule_lower" || grep -Eqi "\becho\b" <<< "$rule_lower"; then
    proto="icmp"
  elif grep -Eq "\bmultiport\b" <<< "$rule_lower"; then
    proto="tcp"
  fi
  # ==== Detect and trap invalid IP ====
  if [[ "$rule_lower" =~ ^\b(alias-create)\b[[:space:]]+([a-z0-9_-]+)[[:space:]]+?$ ]]; then
    local cmd_type="${BASH_REMATCH[1]}"
    local alias_name="${BASH_REMATCH[2]}"
    printf '%s\n' "${red}╔═════════════════════ [ ERROR ] ════════════════════╗${reset}" \
      "${red}║${reset} Incomplete Command: ${yellow}$cmd_type $alias_name${reset}                ${red}║${reset}" \
      "${red}║${reset} You must provide at least one or more IP addresses.${red}║${reset}" \
      "${red}║${reset} Usage: ${cyan}$cmd_type $alias_name ${yellow}1.2.3.4${red}                     ${red}║${reset}" \
      "${red}╚════════════════════════════════════════════════════╝${reset}"
    exit 1
  fi
  # ==== Detect Invalid Range ====
  if [[ "$rule_lower" =~ (^|[[:space:]]+)range[[:space:]]+?$ || "$rule_lower" =~ ^range ]]; then
    printf '%s\n' "${red}╔═══════════════════════ [ ERROR ] ══════════════════════╗${reset}" \
      "${red}║${reset} Incomplete Command! Allow, drop or reject not detected ${red}║${reset}" \
      "${red}║${reset} You must provide a range of ports with -               ${red}║${reset}" \
      "${red}║${reset} Usage: ${cyan}allow range 2000-3000                           ${red}║${reset}" \
      "${red}╚════════════════════════════════════════════════════════╝${reset}"
    exit 1
  fi
  # ==== Detect Passthroughs ====
  if [[ "$rule_lower" =~ ^[[:space:]]+?(multiport|alias|disable|enable|drop|allow|filter|nat|mangle)[[:space:]]+?$ ]]; then
    cmd="${BASH_REMATCH[1]}"
    printf '%s\n' \
	  "${red}╔═══════════════════════ [ ERROR ] ══════════════════════╗${reset}" \
      "${red}║${reset} Incomplete Command!                                    ${red}║${reset}" \
      "${red}║${reset} ${cyan}${cmd}${reset} requires a valid arguement                     ${red}║${reset}" \
      "${red}╚════════════════════════════════════════════════════════╝${reset}"
    exit 1
  fi
  # ==== Detect Alias ====
  if [[ "$rule_lower" =~ ^(alias-create)[[:space:]]+([a-z0-9_-]+)[[:space:]]+([0-9./:]+([[:space:]]+[0-9./:]+)+?) ]]; then
    local alias_name alias_ip alias_mapped
	alias_name="${BASH_REMATCH[2]}"
    alias_ip="${BASH_REMATCH[3]}"
	alias_mapped=$(sed -n "/$alias_name/s/[^=]*=//p" "$alias_file")
	alias_ip=$(echo "$alias_ip" | tr ' ' ',')
    if [[ -f "$alias_file" ]] && grep -q "^${alias_name}=" "$alias_file"; then
	  warn "$alias_name has already been defined and maps to $alias_mapped"
	  read -rp "Replace $alias_mapped with ${alias_ip} [y|n]: " rep_alias
	  rep_alias="${rep_alias,,}"
	  if [[ "$rep_alias" == "y" || "$rep_alias" == "yes" ]]; then
        local tmp_alias=$(mktemp)
        sed -i "s|^${alias_name}=.*|${alias_name}=${alias_ip}|" "$alias_file"
        info "Alias updated: $alias_name → $alias_ip"
	  fi
    else
      echo "${alias_name}=${alias_ip}" >> "$alias_file"
      info "Alias Added: $alias_name → $alias_ip"
    fi
    exit 0
  fi
  # ==== Detect IP Removal from Alias ====
  if [[ "$rule_lower" =~ ^(alias-remove|alias-delete|alias-prune)([[:space:]]+[a-zA-Z0-9_-]+|$)[[:space:]]*$ ]]; then
    die "Usage: alias-prune [alias] [IP]"
    return 1
  fi
  if [[ "$rule_lower" =~ ^(alias-remove|alias-delete|alias-prune)[[:space:]]+([a-zA-Z0-9_-]+)[[:space:]]+([a-fA-F0-9./:]+)$ ]]; then
    local alias_name="${BASH_REMATCH[2]}"
    local ip_to_remove="${BASH_REMATCH[3]}"
    if [[ -f "$alias_file" ]] && grep -q "^${alias_name}=" "$alias_file"; then
      if sed -n "/^${alias_name}=.*${ip_to_remove}/p" "$alias_file" &> /dev/null; then
        info "Detecting $ip_to_remove in $alias_name. initiating removal."
        remove_ip_from_alias "$alias_name" "$ip_to_remove"
      else
        error "IP $ip_to_remove not found in alias $alias_name"
      fi
    else
      error "Alias $alias_name does not exist."
    fi
    exit 0
  fi
  # ==== Detect connection state ====
  conn_state=""
  if grep -Eqi "\bestablished\b" <<< "$rule_lower"; then
    conn_state="ESTABLISHED"
  fi
  if grep -Eqi "\brelated\b" <<< "$rule_lower"; then
    if [[ -n "$conn_state" ]]; then conn_state+=",RELATED"; else conn_state="RELATED"; fi
  fi
  if grep -Eqi "\bnew\b" <<< "$rule_lower"; then
    if [[ -n "$conn_state" ]]; then conn_state+=",NEW"; else conn_state="NEW"; fi
  fi
  if grep -Eqi "\binvalid\b" <<< "$rule_lower"; then
    if [[ -n "$conn_state" ]]; then conn_state+=",INVALID"; else conn_state="INVALID"; fi
  fi
  # ==== Detect Source IP ====
  if [[ "$rule_lower" =~ from[[:space:]]+([0-9a-fA-F:./]+(/[0-9]+)?) ]]; then
    src_ip="${BASH_REMATCH[1]}"
    valid_ip "$src_ip" && ip_version="ipv4"
    valid_ipv6 "$src_ip" && { ip_version="ipv6"; fw_bin="ip6tables"; }
  fi
  if [[ "$rule_lower" =~ from[[:space:]]+([a-zA-Z0-9._:/-]+(/[0-9]+)?) ]]; then
    src_ip="${BASH_REMATCH[1]}"
    if [[ -n "${host_aliases[$src_ip]:-}" ]]; then
      local alias_val="${host_aliases[$src_ip]}"
	  if [[ "$alias_val" == *","* ]]; then
        IFS=',' read -ra addr_list <<< "$alias_val"
        for ip in "${addr_list[@]}"; do
          parse_firewall_command "${rule/from $src_ip/from $ip}" "$inherited_proto"
        done
        return 0
      else
	    src_ip="$alias_val"
        valid_ip "$src_ip" && ip_version="ipv4"
        valid_ipv6 "$src_ip" && { ip_version="ipv6"; fw_bin="ip6tables"; }
	  fi
    else
      if valid_ip "$src_ip"; then
        ip_version="ipv4"
      elif valid_ipv6 "$src_ip"; then
        ip_version="ipv6"
        fw_bin="ip6tables"
      else
        echo -e "${red}[ERROR]:${reset} Unknown host/alias '$src_ip'. Command aborted."
        exit 1
      fi
	fi
  fi
  # ==== Detect Destination IP ====
  if [[ "$rule_lower" =~ (to|dst|destination)[[:space:]]+([0-9a-fA-F:.\/]+) ]]; then
    dst_ip="${BASH_REMATCH[2]}"
    valid_ip "$dst_ip" && ip_version="ipv4"
    valid_ipv6 "$dst_ip" && { ip_version="ipv6"; fw_bin="ip6tables"; }
  fi
  # ==== Detect Delete Line ====
  if [[ "$mode" == "-D" ]]; then
    if [[ "$rule_lower" =~ (line|number)[^0-9]*([0-9]+) ]]; then
      del_line="${BASH_REMATCH[2]}"
    else
      die "Delete requires line, number, firewall or alias arguements."
    fi
  fi
  # ==== Service Name Mapping ====
  raw_services="tcpmux:1 echo:7 discard:9 systat:11 daytime:13 qotd:17 chargen:19 ftp-data:20 ftp:21 ssh:22 telnet:23 smtp:25 time:37 whois:43 tacacs:49 dhcp-server:67 dhcp-client:68 tftp:69 gopher:70 finger:79 http:80 kerberos:88 pop3:110 sunrpc:111 ident:113 nntp:119 ntp:123 imap:143 snmp:udp:161,tcp:161 snmptrap:udp:162,tcp:162 bgp:179 irc:194 ldap:389 https:443 microsoft-ds:445 smtps:465 syslog:udp:514,tcp:514 ldaps:636 ftps-data:989 ftps:990 imaps:993 pop3s:995 rsync:873 mysql:3306 postgresql:5432 rdp:3389 vnc:5900 redis:6379 mongodb:27017 sip:udp:5060,tcp:5060 sips:udp:5061,tcp:5061 pptp:1723 l2tp:1701 ipsec-isakmp:500 openvpn:udp:1194,tcp:1194 docker:2375 docker-tls:2376 kubernetes-api:6443 etcd:2379 grafana:3000 prometheus:9090 elasticsearch:9200 kibana:5601 zabbix-agent:10050 zabbix-server:10051 jenkins:8080 tomcat:8080 http-alt:8080 https-alt:8443 webmin:10000 cockpit:9090 cassandra:9042 memcached:11211 rabbitmq:5672 amqp:5672 mqtt:1883 mqtts:8883 git:9418 svn:3690 teamspeak:9987 minecraft:25565 wireguard:51820 one-click-wg:51821 plex:32400 nfs:2049 samba:137 samba-nbt:138 samba-ssn:139 cups:631 tor:9001 tor-socks:9050 rdp-alt:3390 oracle:1521 ms-sql:1433 ms-sql-browser:1434 radius:1812 radius-acct:1813 freeipa-ldap:7389 freeipa-ldaps:7636 xmpp-client:5222 xmpp-server:5269 asterisk:5038 iscsi:3260 glusterfs:24007 vault:8200 consul:8500 dns:tcp:53,udp:53 apache:tcp:80,tcp:443 nginx:tcp:80,tcp:443 bind9:tcp:53,udp:53 haproxy:tcp:80,tcp:443 postfix:tcp:25 dovecot:tcp:143,tcp:993 cyrus-imap:tcp:143,tcp:993"
  declare -A service_ports
  for entry in $raw_services; do
    service="${entry%%:*}"
    ports="${entry#*:}"
    service_ports[$service]="${ports//,/ }"
  done
  tcp_ports=()
  udp_ports=()
  port_range=""
  port=""
  ports=""
  # ==== ICMP / echo handling ====
  if grep -Eqi "\b(icmp|echo)\b" <<< "$rule_lower"; then
    proto="icmp"
    [[ "$ip_version" == "ipv6" ]] && proto="icmpv6"
    chain=${chain:-INPUT}
    if grep -Eq "\benable\b" <<< "$rule_lower"; then
        action="ACCEPT"
        mode="-I"
    elif grep -Eq "\bdisable\b" <<< "$rule_lower"; then
        action="DROP"
        mode="-A"
    fi
    fw_cmd=("$fw_bin" -t "$table" "$mode" "$chain" -p "$proto")
    [[ -n "$src_ip" ]] && fw_cmd+=(-s "$src_ip")
    [[ -n "$dst_ip" ]] && fw_cmd+=(-d "$dst_ip")
    [[ -n "$conn_state" ]] && fw_cmd+=(-m state --state "$conn_state")
    [[ -n "$action" ]] && fw_cmd+=(-j "$action")
    generated_cmds+=("${fw_cmd[*]}")
    skip_service_ports=1
    return 0
  fi
  # ==== Service Name Mapping ====
  if [[ -z "${skip_service_ports:-}" ]]; then
    for service in "${!service_ports[@]}"; do
      if grep -Eq "\b$service\b" <<< "$rule_lower"; then
        ports="${service_ports[$service]}"
        for entry in $ports; do
          if [[ "$entry" == *:* ]]; then
            proto="${entry%%:*}"
            port_only="${entry##*:}"
          else
            proto="tcp"
            port_only="$entry"
          fi
          if [[ "$proto" == "tcp" ]]; then
            tcp_ports+=("$port_only")
          elif [[ "$proto" == "udp" ]]; then
            udp_ports+=("$port_only")
          fi
        done
      fi
    done
  fi
  # ==== Remove Duplicate Ports ====
  tcp_ports=($(printf "%s\n" "${tcp_ports[@]}" | sort -n | uniq))
  udp_ports=($(printf "%s\n" "${udp_ports[@]}" | sort -n | uniq))
  # ==== Parse explicit numeric ports ====
  # ==== Determine requested protocol first ====
  if grep -Eqi "\budp\b" <<< "$rule_lower"; then
    requested_proto="udp"
  elif grep -Eqi "\btcp\b" <<< "$rule_lower"; then
    requested_proto="tcp"
  elif grep -Eqi "\bicmp\b" <<< "$rule_lower"; then
    requested_proto="icmp"
  else
    requested_proto="tcp"
  fi
  # ==== Extract all numeric ports from human input ====
  rule_ports_only="$rule_lower"
  rule_ports_only=$(sed -E 's/\b(to|from)[[:space:]]+[0-9a-fA-F:./]+(\/[0-9]+)?\b//g' <<< "$rule_ports_only")
  rule_ports_only=$(sed -E 's/\b(to|dst|destination)[[:space:]]+(address[[:space:]]+)?[0-9a-fA-F:./]+(\/[0-9]+)?\b//g' <<< "$rule_ports_only")
  mapfile -t all_ports < <(grep -oE '[0-9]{1,5}-[0-9]{1,5}|[0-9]{1,5}' <<< "$rule_ports_only")
  for p in "${all_ports[@]}"; do
    if valid_port "$p"; then
      case "$requested_proto" in
        udp) udp_ports+=("$p") ;;
        tcp) tcp_ports+=("$p") ;;
        icmp)                  ;;
        *) tcp_ports+=("$p")   ;;
      esac
    fi
  done
  # ==== ICMP / echo handling ====
  if grep -Eqi "\b(icmp|echo)\b" <<< "$rule_lower"; then
    proto="icmp"
    [[ "$ip_version" == "ipv6" ]] && proto="icmpv6"
    chain=${chain:-INPUT}
    if grep -Eq "\benable\b" <<< "$rule_lower"; then
      action="ACCEPT"
      mode="-I"
    elif grep -Eq "\bdisable\b" <<< "$rule_lower"; then
      action="DROP"
      mode="-A"
    fi
    skip_service_ports=1
  fi
  # ==== Build Port Args ====
  build_port_args() {
    local proto="$1"
    local -n ports_ref="$2"
    local args=()
    if (( ${#ports_ref[@]} == 0 )); then
      return
    fi
    local formatted_ports
    formatted_ports=$(IFS=,; echo "${ports_ref[*]}")
    formatted_ports="${formatted_ports//-/:}"
    if [[ "$formatted_ports" == *","* ]] || [[ "$formatted_ports" == *":"* ]]; then
      args+=("-m" "multiport" "--dports" "$formatted_ports")
    else
      args+=("--dport" "$formatted_ports")
    fi
    echo "${args[@]}"
  }
  tcp_port_args=()
  udp_port_args=()
  if [[ "$ip_version" == "ipv6" && "$ipv6_available" -ne 1 ]]; then
    die "ip6tables not available on this system."
  fi
  # ==== Duplicate Prevention ====
  if [[ "$mode" == "-A" || "$mode" == "-I" ]]; then
    local is_duplicate=0
    if (( ${#tcp_ports[@]} > 0 )); then
      for p in "${tcp_ports[@]}"; do
        if rule_exists_backend "$firewall_backend" "tcp" "$p" "$src_ip" "${action:-ACCEPT}" "$chain"; then
          warn "Duplicate rule detected for TCP port $p on backend '$firewall_backend'."
          is_duplicate=1
        fi
      done
    fi
    if (( ${#udp_ports[@]} > 0 )); then
      for p in "${udp_ports[@]}"; do
        if rule_exists_backend "$firewall_backend" "udp" "$p" "$src_ip" "${action:-ACCEPT}" "$chain"; then
          warn "Duplicate rule detected for UDP port $p on backend '$firewall_backend'."
          is_duplicate=1
        fi
      done
    fi
    if [[ "$is_duplicate" -eq 1 ]]; then
      warn "Skipping adding duplicate entry."
      duplicate_skipped=1
      return 0
    fi
  fi
  if (( ${#tcp_ports[@]} > 0 )); then
    check_sensitive_ports "tcp" tcp_ports "${action:-ACCEPT}"
  fi
  if (( ${#udp_ports[@]} > 0 )); then
    check_sensitive_ports "udp" udp_ports "${action:-ACCEPT}"
  fi
  # ==== FINAL COMMAND CONSTRUCTION ====
  if [[ "$mode" == "-D" ]]; then
    if [[ "$firewall_backend" == "iptables" ]]; then
      generated_cmds+=("$fw_bin -t $table -D $chain $del_line")
    elif [[ "$firewall_backend" == "ufw" ]]; then
      generated_cmds+=("ufw delete $del_line")
    elif [[ "$firewall_backend" == "nft" ]]; then
      generated_cmds+=("nft delete rule inet filter ${chain,,:-input} handle $del_line")
    fi
    return 0
  fi
  if [[ -n "${is_policy_change:-}" ]]; then
    if [[ "$firewall_backend" == "iptables" ]]; then
      generated_cmds+=("$fw_bin -t $table -P $chain $action")
    elif [[ "$firewall_backend" == "ufw" ]]; then
      local ufw_pol="deny"
      [[ "$action" == "ACCEPT" ]] && ufw_pol="allow"
      generated_cmds+=("ufw default $ufw_pol ${chain,,:-incoming}")
    fi
    return 0
  fi
  if [[ "$firewall_backend" != "iptables" ]]; then
    if (( ${#tcp_ports[@]} > 0 )); then
      for p in "${tcp_ports[@]}"; do
        generated_cmds+=("$(build_native_cmd "$firewall_backend" "${action:-ACCEPT}" "tcp" "$p" "$src_ip" "$chain")")
      done
    fi
    if (( ${#udp_ports[@]} > 0 )); then
      for p in "${udp_ports[@]}"; do
        generated_cmds+=("$(build_native_cmd "$firewall_backend" "${action:-ACCEPT}" "udp" "$p" "$src_ip" "$chain")")
      done
    fi
    if (( ${#tcp_ports[@]} == 0 )) && (( ${#udp_ports[@]} == 0 )); then
      generated_cmds+=("$(build_native_cmd "$firewall_backend" "${action:-ACCEPT}" "${proto:-tcp}" "any" "$src_ip" "$chain")")
    fi
    return 0
  fi
  # ==== LEGACY IPTABLES FALLBACK ====
  if (( ${#tcp_ports[@]} == 0 )) && (( ${#udp_ports[@]} == 0 )) && [[ "${skip_service_ports:-}" != "1" ]]; then
    local cmd=("$fw_bin" -t "$table" "$mode" "$chain")
    [[ -n "${in_interface:-}" ]] && cmd+=("-i" "${in_interface:-}")
    [[ -n "$src_ip" ]] && { [[ -n "$src_neg" ]] && cmd+=("!"); cmd+=("-s" "$src_ip"); }
    [[ -n "$dst_ip" ]] && cmd+=("-d" "$dst_ip")
    [[ -n "$proto" && "$proto" != "tcp" ]] && cmd+=("-p" "$proto")
    [[ -n "$conn_state" ]] && cmd+=("-m" "state" "--state" "$conn_state")
    if [[ "$action" == "REJECT" && -n "$reject_with" ]]; then
        cmd+=("-j" "REJECT" "--reject-with" "$reject_with")
    else
        [[ -n "$action" ]] && cmd+=("-j" "$action")
    fi
    generated_cmds+=("${cmd[*]}")
    return 0
  fi
  if (( ${#tcp_ports[@]} > 0 )); then
    local tcp_args=$(build_port_args "tcp" tcp_ports)
    local cmd=("$fw_bin" -t "$table" "$mode" "$chain" -p tcp)
    [[ -n "${in_interface:-}" ]] && cmd+=("-i" "${in_interface:-}")
    [[ -n "$src_ip" ]] && { [[ -n "$src_neg" ]] && cmd+=("!"); cmd+=("-s" "$src_ip"); }
    [[ -n "$dst_ip" ]] && cmd+=("-d" "$dst_ip")
    [[ -n "$conn_state" ]] && cmd+=("-m" "state" "--state" "$conn_state")
    cmd+=($tcp_args)
    [[ -n "$action" ]] && cmd+=("-j" "$action")
    generated_cmds+=("${cmd[*]}")
  fi
  if (( ${#udp_ports[@]} > 0 )); then
    local udp_args=$(build_port_args "udp" udp_ports)
    local cmd=("$fw_bin" -t "$table" "$mode" "$chain" -p udp $udp_args)
    [[ -n "${in_interface:-}" ]] && cmd+=("-i" "${in_interface:-}")
    [[ -n "$src_ip" ]] && { [[ -n "$src_neg" ]] && cmd+=("!"); cmd+=("-s" "$src_ip"); }
    [[ -n "$dst_ip" ]] && cmd+=("-d" "$dst_ip")
    [[ -n "$conn_state" ]] && cmd+=("-m" "state" "--state" "$conn_state")
    [[ -n "$action" ]] && cmd+=("-j" "$action")
    generated_cmds+=("${cmd[*]}")
  fi
}
# =========================================== End Of Rule Engine ================================================== #
# ===================================== Display Table For Boot Recovery =============================================
print_blue_table() {
  local dir="$1"
  local BLUE="\033[34m"
  local RESET="\033[0m"
  [[ -d "$dir" ]] || {
    echo "Directory not found: $dir" >&2
    return 1
  }
  mapfile -t rows < <(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
  (( ${#rows[@]} == 0 )) && {
    echo "No entries found in $dir"
    return 0
  }
  local max=0
  for r in "${rows[@]}"; do
    (( ${#r} > max )) && max=${#r}
  done
  pad() { printf "%-*s" "$max" "$1"; }
  printf "${BLUE}┌────┬─%s─┐${RESET}\n" "$(printf '─%.0s' $(seq 1 $max))"
  local i=1
  for r in "${rows[@]}"; do
    printf "${BLUE}│ %2d │ ${RESET}%s${BLUE} │${RESET}\n" "$i" "$(pad "$r")"
    ((i++))
  done
  printf "${BLUE}└────┴─%s─┘${RESET}\n" "$(printf '─%.0s' $(seq 1 $max))"
}
# ===================================================End Of Boot Recovery ================================================= #
# ===================================================== Log Browser =========================================================
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
	printf "║ %-46s ║\n" " [3]. Live Web Log Viewer"
	printf "║ %-46s ║\n" " [4]. Live Log Viewer"
	printf "║ %-46s ║\n" " [5]. SSH Login Logs"
    printf "║ %-46s ║\n" " [0]. Exit"
    echo "╚════════════════════════════════════════════════╝"
    tput sgr0
    set +e
    avail_logs=$(find /var/log/{nginx,apache2,httpd,one-click}/ -type f \( -name ".log" -o -name "access.log" \) \
      ! -name "*.gz" ! -name "*.xz" ! -name "*[0-9]*" 2>/dev/null)
    set -e
    read -rp "${cyan}[USER]: ${reset}Select option: " choice
    case "$choice" in
      1) browse_files       ;;
      2) browse_journal     ;;
	  3)
	    if [[ -z "$avail_logs" ]]; then
	      error "There are no web logs available!"
	      sleep 4
	      continue
        fi
        live_journal_view      ;;
      4) live_system_logs_view ;;
      5) live_ssh_view         ;;
      0) exit                  ;;
    esac
  done
}
install_goaccess() {
  if command -v goaccess &>/dev/null; then
    return 0
  fi
  info "Installing Goaccess"
  if command -v apt &>/dev/null; then
    wget -O - https://deb.goaccess.io/gnugpg.key | gpg --dearmor | sudo tee /usr/share/keyrings/goaccess.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/goaccess.gpg] https://deb.goaccess.io/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/goaccess.list
    sudo apt update && sudo apt install goaccess -y
  elif command -v dnf &>/dev/null; then
    sudo dnf install goaccess -y
  else
    error "Unsupported package manager. Please install GoAccess manually."
    return 1
  fi
}
get_free_port() {
  local port
  while true; do
    port=$(shuf -i 10000-65000 -n 1)
    if ! ss -tuln | grep -q ":${port} "; then
      echo "$port"
      return 0
    fi
  done
}
setup_log_viewer_vhost() {
  local session_token="$1"
  local web_port="$2"
  local ws_port="$3"
  local output_dir="/etc/one-click/log_viewer/analytics"
  if [[ -z "$session_token" || -z "$web_port" || -z "$ws_port" ]]; then
    error "Missing parameters in setup_log_viewer_vhost."
    return 1
  fi
  if command -v nginx &>/dev/null; then
    local conf_file="/etc/nginx/conf.d/sess_${session_token}.conf"

    cat <<EOF | sudo tee "$conf_file" >/dev/null
server {
    listen ${web_port};
    listen [::]:${web_port};
    server_name _;

    location / {
        return 403;
    }

    location /${session_token}/ {
        alias ${output_dir}/${session_token}/;
        index index.html;
    }

    location /${session_token}/ws {
        proxy_pass http://127.0.0.1:${ws_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
EOF
    reload_webserver
  elif command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
    local apache_conf_dir="/etc/apache2/sites-available"
    local is_debian=true
    if [[ ! -d "$apache_conf_dir" ]]; then
      apache_conf_dir="/etc/httpd/conf.d"
      is_debian=false
    fi
    local conf_file="${apache_conf_dir}/sess_${session_token}.conf"
    if $is_debian; then
      sudo a2enmod proxy proxy_http proxy_wstunnel rewrite &>/dev/null || true
    fi
    local ports_conf="/etc/apache2/ports.conf"
    [[ ! -f "$ports_conf" ]] && ports_conf="/etc/httpd/conf/httpd.conf"
    if ! grep -q "Listen ${web_port}" "$ports_conf" 2>/dev/null; then
      echo "Listen ${web_port}" | sudo tee -a "$ports_conf" >/dev/null
    fi

    cat <<EOF | sudo tee "$conf_file" >/dev/null
<VirtualHost *:${web_port}>
    Alias /${session_token} "${output_dir}/${session_token}"

    <Directory "${output_dir}/${session_token}">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ProxyRequests Off
    ProxyPreserveHost On

    ProxyPass /${session_token}/ws ws://127.0.0.1:${ws_port}/
    ProxyPassReverse /${session_token}/ws ws://127.0.0.1:${ws_port}/
</VirtualHost>
EOF

    reload_webserver
  else
    error "Neither Nginx nor Apache was found. Please install a web server."
    return 1
  fi
}
live_journal_view() {
  build_vars
  install_goaccess
  local session_minutes="${LOG_VIEWER_SESSION}"
  local excluded_hosts=()
  if [[ -n "${2:-}" ]]; then
    IFS=',' read -r -a excluded_hosts <<< "$2"
  fi
  local session_seconds=$((session_minutes * 60))
  local session_token=$(openssl rand -hex 16)
  local output_dir="/etc/one-click/log_viewer/analytics"
  local output_html="${output_dir}/${session_token}/index.html"
  local available_ports_dir="/etc/one-click/log_viewer/ports"
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  mkdir -p "${output_dir}/${session_token}" "$available_ports_dir"
  if [[ "${SSH_CLIENT:-}" =~ : ]]; then
    ui_target="$sys_ipv6"
  else
    ui_target="$sys_ip"
  fi
  if [[ "$ui_target" =~ : ]]; then
    ui_target="[$ui_target]"
  fi
  local web_port ws_port
  web_port=$(get_free_port)
  ws_port=$(get_free_port)
  while [[ "$web_port" == "$ws_port" ]]; do
    ws_port=$(get_free_port)
  done
  echo "$web_port" > "${available_ports_dir}/current_web_port"
  echo "$ws_port" > "${available_ports_dir}/current_ws_port"
  local client_ip
  client_ip=$(echo "${SSH_CLIENT:-}" | awk '{print $1}')
  if [[ -z "$client_ip" ]]; then
    client_ip=$(who am i 2>/dev/null | awk '{print $5}' | tr -d '()')
  fi
  if [[ -n "$client_ip" && "$client_ip" != "127.0.0.1" ]]; then
    info "Enforcing firewall lockdown exclusively to requesting client IP: ${client_ip}"
    iptables -I INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
    iptables -I INPUT -p tcp --dport "$ws_port" -s 127.0.0.1 -j ACCEPT 2>/dev/null || true
    iptables -A INPUT -p tcp --dport "$ws_port" -j DROP 2>/dev/null || true
  fi
  setup_log_viewer_vhost "$session_token" "$web_port" "$ws_port" || return 1
  local ws_url="ws://${ui_target}:${web_port}/${session_token}/ws"
  local raw_targets=()
  if [[ -f "$inventory_file" ]] && command -v ansible &>/dev/null; then
    info "Running discovery from fleet peer inventory."
    local host_info
    host_info=$(ansible all -m debug -a "var=ansible_host" -i "$inventory_file" 2>/dev/null | \
      awk '/SUCCESS/ {host=$1} /ansible_host/ {print host ":" $2}' | tr -d '"')
    for entry in $host_info; do
      IFS=":" read -r host ip <<< "$entry"
      [[ "$ip" == "VARIABLE" || -z "$ip" ]] && ip="$host"
      raw_targets+=("${host}:${ip}")
    done
  fi
  local local_hostname local_ip
  local_hostname=$(hostname -s)
  if [[ "${SSH_CLIENT:-}" =~ : ]]; then
    local_ip="${sys_ipv6}"
  else
    local_ip="${sys_ip}"
  fi
  raw_targets+=("${local_hostname}:${local_ip}")
  local remote_targets=()
  local seen_labels=()
  for item in "${raw_targets[@]}"; do
    IFS=":" read -r label target_type <<< "$item"

    if [[ " ${seen_labels[*]} " =~ " ${label} " ]]; then
      continue
    fi
    local skip=0
    for ex in "${excluded_hosts[@]}"; do
      if [[ "$label" == "$ex" ]]; then
        skip=1
        warn "Excluding host from stream: ${label}"
        break
      fi
    done
    [[ $skip -eq 1 ]] && continue
    seen_labels+=("$label")
    local log_path="/var/log/one-click/log_viewer/${label}/access.log"
    mkdir -p "/var/log/one-click/log_viewer/${label}"

    if [[ "${target_type//*@}" == "$local_ip" ]] || [[ "$target_type" == "local" ]]; then
      remote_targets+=("${label}:local:${log_path}:${target_type}")
    else
      remote_targets+=("${label}:oneclick@${label}:${log_path}:${target_type}")
    fi
  done
  if [ ${#remote_targets[@]} -eq 0 ]; then
    error "No hosts available to stream logs after applying exclusions. Aborting session."
    cleanup_session_port "$web_port"
    cleanup_session_port "$ws_port"
    cleanup_firewall_rules "$web_port"
    cleanup_firewall_rules "$ws_port"
    return 1
  fi
  local ssh_key=""
  if [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  elif [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  fi
  local ssh_opts=("-o" "ConnectTimeout=5" "-o" "StrictHostKeyChecking=no" "-o" "BatchMode=yes")
  [ -n "$ssh_key" ] && ssh_opts+=("-i" "$ssh_key")
  local log_format='%v %h %^[%d:%t %^] "%r" %s %b "%R" "%u"'
  local date_format='%d/%b/%Y'
  local time_format='%H:%M:%S'
  info "Initializing ${session_minutes}-minute cluster-wide log viewer session."
  info "Active Peer Targets (${#remote_targets[@]}):"
  local reset=$(tput sgr0 2>/dev/null || echo "")
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label _ _ <<< "$target"
    printf "$(tput setaf 148)%s\n${reset}" "- ${label}"
  done
  info "Session Token: ${session_token}"
  local tmp_dir
  tmp_dir=$(mktemp -d /tmp/goaccess_sess_XXXXXX)
  cleanup() {
    warn "Session expired or terminated. Cleaning up streams, vhost, and security rules."
    kill $(jobs -p) 2>/dev/null || true
    if [[ -n "$session_token" ]]; then
      rm -f "/etc/nginx/conf.d/sess_${session_token}.conf"
      if command -v apache2 &>/dev/null; then
        sudo a2dissite "sess_${session_token}.conf" &>/dev/null || true
        rm -f "/etc/apache2/sites-available/sess_${session_token}.conf"
      fi
      rm -f "/etc/httpd/conf.d/sess_${session_token}.conf"
    fi
    reload_webserver
    if [[ -n "$client_ip" && "$client_ip" != "${sys_ip:-${sys_ipv6}}" ]]; then
      iptables -D INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
      iptables -D INPUT -p tcp --dport "$ws_port" -s 127.0.0.1 -j ACCEPT 2>/dev/null || true
      iptables -D INPUT -p tcp --dport "$ws_port" -j DROP 2>/dev/null || true
    fi
    cleanup_session_port "$web_port"
    cleanup_session_port "$ws_port"
    cleanup_firewall_rules "$web_port"
    cleanup_firewall_rules "$ws_port"
    rm -rf "$tmp_dir"
    rm -rf "${output_dir}/${session_token}"
    rm -f "${available_ports_dir}/current_web_port" "${available_ports_dir}/current_ws_port"
    info "Cleanup complete. Security rules and vhost destroyed."
  }
  trap cleanup EXIT
  local fifo_list=()
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label ssh_target _ host_ip <<< "$target"
    local fifo="${tmp_dir}/${label}.fifo"
    mkfifo "$fifo"
    set +e
    local log_stream_cmd='
      LOG_FILES=$(find /var/log/{httpd,apache2,nginx,one-click} -type f \( -name "*.log" -o -name "access.log" \) \
        ! -name "*.gz" ! -name "*.xz" ! -name "*[0-9]*" 2>/dev/null)
      if [ -n "$LOG_FILES" ]; then
        tail -F -n +1 $LOG_FILES 2>/dev/null
      fi
    '
    set -e
    if [[ "$ssh_target" == "local" ]] || [[ "$host_ip" == "$local_ip" ]]; then
      bash -c "$log_stream_cmd" | sed -u "s/^/${label} /" > "$fifo" &
    else
      ssh "${ssh_opts[@]}" "$ssh_target" "$log_stream_cmd" sed -u "s/^/${label} /" > "$fifo" 2>/dev/null &
    fi
    fifo_list+=("$fifo")
  done
  local timer_pid=$!
  local goaccess_fifo_in="${tmp_dir}/goaccess_in.fifo"
  local goaccess_fifo_out="${tmp_dir}/goaccess_out.fifo"
  mkfifo "$goaccess_fifo_in" "$goaccess_fifo_out"
  cat "${fifo_list[@]}" | goaccess - \
    --log-format="$log_format" \
    --date-format="$date_format" \
    --time-format="$time_format" \
    --invalid-requests=/dev/null \
    --output="$output_html" \
    --real-time-html \
    --port="$ws_port" \
    --ws-url="$ws_url" \
    --fifo-in="$goaccess_fifo_in" \
    --fifo-out="$goaccess_fifo_out" &
  info "Dashboard (Restricted to ${client_ip:-All}) will expire at: $(date -d "now + $session_minutes minutes")"
  success "Access Live Console Here: ${orange}http://${ui_target}:${web_port}/${session_token}/${reset}"
  (
    sleep "$session_seconds"
    cleanup_session_port "$web_port"
    cleanup_session_port "$ws_port"
    cleanup_firewall_rules "$web_port"
    cleanup_firewall_rules "$ws_port"
    kill -SIGTERM $$ 2>/dev/null
  ) &
  info "Session active in background (PID: ${timer_pid})."
  info "${yellow}To terminate early, run: kill ${timer_pid}${reset}"
  disown "$timer_pid" 2>/dev/null || true
  read -rp "Press Enter to continue..."
  cleanup
  trap - EXIT
  return 0
}
generate_dashboard_html() {
  local target_html="$1"
  local session_token="$2"
  local session_minutes="${3:-20}"
  local expire_ts
  expire_ts=$(date -d "now + ${session_minutes} minutes" +%s)
  cat <<EOF > "$target_html"
<!DOCTYPE html>
<html lang="en" class="h-full bg-slate-950 text-slate-100">
<head>
  <meta charset="UTF-8">
  <title>One-Click Log Browser</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    .log-line:hover { background-color: rgba(255,255,255,0.05); }
    .log-error { color: #f87171; font-weight: 600; background-color: rgba(153, 27, 27, 0.2); border-left: 3px solid #ef4444; }
    .log-warn  { color: #fbbf24; font-weight: 600; background-color: rgba(146, 64, 14, 0.2); border-left: 3px solid #f59e0b; }
    .log-info  { color: #38bdf8; }
  </style>
</head>
<body class="h-full flex flex-col font-mono text-sm">
  <!-- Top Navigation & Controls Header -->
  <header class="bg-slate-900 border-b border-slate-800 p-4 flex flex-wrap items-center justify-between gap-4">
    <div class="flex items-center gap-4">
      <div class="flex items-center gap-3">
        <span class="inline-block w-3 h-3 rounded-full bg-emerald-500 animate-pulse"></span>
        <h1 class="font-bold text-lg tracking-wide text-slate-100">One-Click System Logs</h1>
      </div>
      <div id="session-timer" class="bg-slate-950 border border-slate-800 rounded px-3 py-1 text-xs text-emerald-400 font-semibold flex items-center gap-2">
        <span>Session Expires In:</span>
        <span id="timer-countdown" class="font-mono text-slate-200">--:--</span>
      </div>
    </div>
    <div id="host-tabs" class="flex items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800"></div>
    <div class="flex items-center gap-2">
      <input type="text" id="search-input" placeholder="Search logs (regex/text)..."
        class="bg-slate-950 border border-slate-800 rounded px-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-slate-600 w-64">
      <select id="level-filter" class="bg-slate-950 border border-slate-800 rounded px-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-slate-600">
        <option value="ALL">All Levels</option>
        <option value="ERROR">Errors Only</option>
        <option value="WARN">Warnings & Errors</option>
        <option value="INFO" selected>Info & Higher</option>
      </select>
      <button id="auto-scroll-btn" class="bg-slate-800 hover:bg-slate-700 px-3 py-1.5 rounded text-xs font-semibold text-slate-300 transition">
        Pause Auto-Scroll
      </button>
    </div>
  </header>
  <main id="log-console" class="flex-1 overflow-y-auto p-4 space-y-1 bg-slate-950 selection:bg-slate-800 selection:text-slate-200"></main>
  <script>
    let activeHost = '';
    let autoScroll = true;
    let rawLogLines = [];
    let isFetching = false;
    const hosts = [];
    const expireTimestamp = ${expire_ts};
    const countdownEl = document.getElementById('timer-countdown');
    const timerBadge = document.getElementById('session-timer');
    function updateTimer() {
      const now = Math.floor(Date.now() / 1000);
      const remainingSeconds = Math.max(0, expireTimestamp - now);
      const minutes = Math.floor(remainingSeconds / 60);
      const seconds = remainingSeconds % 60;
      countdownEl.innerText = \`\${String(minutes).padStart(2, '0')}:\${String(seconds).padStart(2, '0')}\`;
      if (remainingSeconds <= 120 && remainingSeconds > 0) {
        timerBadge.className = "bg-red-950/50 border border-red-800 rounded px-3 py-1 text-xs text-red-400 font-semibold flex items-center gap-2 animate-pulse";
      }
      if (remainingSeconds <= 0) {
        timerBadge.className = "bg-red-950 border border-red-800 rounded px-3 py-1 text-xs text-red-500 font-bold flex items-center gap-2";
        countdownEl.innerText = "EXPIRED";
        document.getElementById('log-console').innerHTML = '<div class="text-red-500 font-bold p-6 text-center text-base">Session expired. Security rules and background log streaming destroyed.</div>';
      }
    }
    setInterval(updateTimer, 1000);
    updateTimer();
    const basePath = window.location.pathname.endsWith('/')
      ? window.location.pathname
      : window.location.pathname + '/';
    async function init() {
      try {
        const res = await fetch(basePath + 'hosts.json?t=' + Date.now());
        if (!res.ok) throw new Error('HTTP status ' + res.status);
        const hostList = await res.json();
        const tabContainer = document.getElementById('host-tabs');
        tabContainer.innerHTML = '';
        if (!Array.isArray(hostList) || hostList.length === 0) {
          document.getElementById('log-console').innerHTML =
            '<div class="text-amber-400 p-4">No host nodes registered in session metadata.</div>';
          return;
        }
        hostList.forEach((host, idx) => {
          hosts.push(host);
          const btn = document.createElement('button');
          btn.className = \`px-3 py-1 rounded text-xs font-medium transition \${
            idx === 0 ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-slate-200'
          }\`;
          btn.innerText = host;
          btn.onclick = () => switchHost(host, btn);
          tabContainer.appendChild(btn);
        });

        activeHost = hostList[0];
        fetchCurrentLog();
      } catch(e) {
        console.error('Failed to initialize dashboard:', e);
        document.getElementById('log-console').innerHTML =
          \`<div class="text-red-400 p-4 font-bold">Failed to load host index: \${e.message}</div>\`;
      }
    }
    async function fetchCurrentLog() {
      if (!activeHost || isFetching) return;
      isFetching = true;
      try {
        const res = await fetch(basePath + activeHost + '.log?t=' + Date.now());
        if (res.ok) {
          const text = await res.text();
          rawLogLines = text.split('\n').filter(l => l.trim().length > 0);
          renderLogs();
        } else {
          document.getElementById('log-console').innerHTML =
            \`<div class="text-amber-400 italic p-4">Waiting for log stream initialization from \${activeHost}...</div>\`;
        }
      } catch(e) {
        console.error('Error fetching stream for ' + activeHost, e);
      } finally {
        isFetching = false;
      }
    }
    function renderLogs() {
      const consoleEl = document.getElementById('log-console');
      const searchTerm = document.getElementById('search-input').value.toLowerCase();
      const levelFilter = document.getElementById('level-filter').value;

      if (rawLogLines.length === 0) {
        consoleEl.innerHTML = \`<div class="text-slate-500 italic p-4">Connected to \${activeHost}. Log file awaiting output...</div>\`;
        return;
      }
      const fragment = document.createDocumentFragment();
      let matchedCount = 0;
      rawLogLines.forEach(line => {
        const isError = /error|fail|failed|critical|exception|denied|fatal|panic|\b(err)\b/i.test(line);
        const isWarn  = /warn|warning|notice|alert|deprecated/i.test(line);
        const isInfo  = /info|information|status|systemd|started|session|connected|ok|success/i.test(line) || (!isError && !isWarn);
        if (levelFilter === 'ERROR' && !isError) return;
        if (levelFilter === 'WARN' && !isError && !isWarn) return;
        if (levelFilter === 'INFO' && !isError && !isWarn && !isInfo) return;
        if (searchTerm && !line.toLowerCase().includes(searchTerm)) return;
        matchedCount++;
        const div = document.createElement('div');
        div.className = 'log-line whitespace-pre-wrap break-all py-1 px-2.5 rounded font-mono text-xs leading-relaxed transition';
        if (isError) {
          div.classList.add('log-error');
        } else if (isWarn) {
          div.classList.add('log-warn');
        } else {
          div.classList.add('log-info');
        }
        div.innerText = line;
        fragment.appendChild(div);
      });
      consoleEl.innerHTML = '';
      if (matchedCount === 0) {
        consoleEl.innerHTML = \`<div class="text-amber-500/70 italic p-4">No log lines match current search/filter criteria on \${activeHost} (\${rawLogLines.length} total lines received).</div>\`;
      } else {
        consoleEl.appendChild(fragment);
      }
      if (autoScroll) {
        consoleEl.scrollTop = consoleEl.scrollHeight;
      }
    }
    function switchHost(host, btnEl) {
      activeHost = host;
      document.querySelectorAll('#host-tabs button').forEach(b => {
        b.className = 'px-3 py-1 rounded text-xs font-medium transition text-slate-400 hover:text-slate-200';
      });
      btnEl.className = 'px-3 py-1 rounded text-xs font-medium transition bg-indigo-600 text-white';
      rawLogLines = [];
      document.getElementById('log-console').innerHTML = \`<div class="text-slate-500 italic p-4">Harvesting log data from \${host}.</div>\`;
      fetchCurrentLog();
    }
    setInterval(fetchCurrentLog, 1500);
    document.getElementById('search-input').addEventListener('input', renderLogs);
    document.getElementById('level-filter').addEventListener('change', renderLogs);
    document.getElementById('auto-scroll-btn').addEventListener('click', (e) => {
      autoScroll = !autoScroll;
      e.target.innerText = autoScroll ? 'Pause Auto-Scroll' : 'Resume Auto-Scroll';
      e.target.classList.toggle('bg-indigo-600', !autoScroll);
    });
    init();
  </script>
</body>
</html>
EOF
}
setup_native_system_log_vhost() {
  local session_token="$1"
  local web_port="$2"
  local logs_mount_dir="$3"
  local conf_file
  chmod -R 755 "$logs_mount_dir" 2>/dev/null || true
  if command -v nginx &>/dev/null; then
    conf_file="/etc/nginx/conf.d/sys_sess_${session_token}.conf"
    cat <<EOF | sudo tee "$conf_file" >/dev/null
server {
    listen ${web_port};
    listen [::]:${web_port};
    server_name _;

    root ${logs_mount_dir};
    index index.html;

    location / {
        return 403;
    }

    location /${session_token}/ {
        alias ${logs_mount_dir}/;
        index index.html;
        default_type text/plain;
        add_header Access-Control-Allow-Origin "*";
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
EOF
    sudo nginx -t &>/dev/null && sudo systemctl reload nginx || { error "Nginx reload failed."; return 1; }
  elif command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
    local apache_conf_dir="/etc/apache2/sites-available"
    local is_debian=true
    [[ ! -d "$apache_conf_dir" ]] && { apache_conf_dir="/etc/httpd/conf.d"; is_debian=false; }
    conf_file="${apache_conf_dir}/sys_sess_${session_token}.conf"
    $is_debian && sudo a2enmod alias headers rewrite &>/dev/null || true
    local ports_conf="/etc/apache2/ports.conf"
    [[ ! -f "$ports_conf" ]] && ports_conf="/etc/httpd/conf/httpd.conf"
    if ! grep -q "Listen ${web_port}" "$ports_conf" 2>/dev/null; then
      echo "Listen ${web_port}" | sudo tee -a "$ports_conf" >/dev/null
    fi
    cat <<EOF | sudo tee "$conf_file" >/dev/null
<VirtualHost *:${web_port}>
    DocumentRoot "${logs_mount_dir}"

    Alias /${session_token} "${logs_mount_dir}"

    <Directory "${logs_mount_dir}">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
        DirectoryIndex index.html
        DirectorySlash On

        <IfModule mod_headers.c>
            Header set Access-Control-Allow-Origin "*"
            Header set Cache-Control "no-cache, no-store, must-revalidate"
        </IfModule>
    </Directory>
</VirtualHost>
EOF
    reload_webserver
  fi
}
live_system_logs_view() {
  build_vars
  local session_minutes="${LOG_VIEWER_SESSION}"
  local excluded_hosts=()
  if [[ -n "${2:-}" ]]; then
    IFS=',' read -r -a excluded_hosts <<< "$2"
  fi
  local session_seconds=$((session_minutes * 60))
  local session_token=$(openssl rand -hex 16)
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  if [[ "${SSH_CLIENT:-}" =~ : ]]; then
    ui_target="$sys_ipv6"
  else
    ui_target="$sys_ip"
  fi
  if [[ "$ui_target" =~ : ]]; then
    ui_target="[$ui_target]"
  fi
  local web_port
  web_port=$(get_free_port)
  local client_ip
  client_ip=$(echo "${SSH_CLIENT:-}" | awk '{print $1}')
  [[ -z "$client_ip" ]] && client_ip=$(who am i 2>/dev/null | awk '{print $5}' | tr -d '()')
  if [[ -n "$client_ip" && "$client_ip" != "127.0.0.1" && "$client_ip" != "::1" ]]; then
    info "Locking session access exclusively to requesting IP: ${client_ip}"
    if [[ "$client_ip" =~ : ]]; then
      ip6tables -I INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
      ip6tables -A INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
    else
      iptables -I INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
      iptables -A INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
    fi
  fi
  local raw_targets=()
  if [[ -f "$inventory_file" ]] && command -v ansible &>/dev/null; then
    info "Discovering fleet members from Ansible inventory."
    local host_list
    host_list=$(ansible all --list-hosts -i "$inventory_file" 2>/dev/null | grep -v "hosts (" | awk '{print $1}')
    for host in $host_list; do
      raw_targets+=("${host}:${host}")
    done
  fi
  local local_hostname
  local_hostname=$(hostname -s)
  raw_targets+=("${local_hostname}:local")
  local remote_targets=()
  local seen_labels=()
  for item in "${raw_targets[@]}"; do
    IFS=":" read -r label target_type <<< "$item"
    if [[ " ${seen_labels[*]} " =~ " ${label} " ]]; then
      continue
    fi
    local skip=0
    for ex in "${excluded_hosts[@]}"; do
      if [[ "$label" == "$ex" ]]; then
        skip=1
        warn "Excluding host from stream: ${label}"
        break
      fi
    done
    [[ $skip -eq 1 ]] && continue
    seen_labels+=("$label")
    if [[ "${target_type//*@}" == "$local_hostname" ]] || [[ "$target_type" == "local" ]]; then
      remote_targets+=("${label}:local")
    else
      remote_targets+=("${label}:oneclick@${label}")
    fi
  done
  if [ ${#remote_targets[@]} -eq 0 ]; then
    error "No hosts available to stream system logs. Aborting."
    cleanup_session_port "$web_port"
    cleanup_firewall_rules "$web_port"
    return 1
  fi
  local logs_mount_dir="/etc/one-click/logs/${session_token}"
  mkdir -p "$logs_mount_dir"
  generate_dashboard_html "${logs_mount_dir}/index.html" "$session_token" "$session_minutes"
  local host_json_items=""
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label _ <<< "$target"
    if [[ -z "$host_json_items" ]]; then
      host_json_items="\"${label}\""
    else
      host_json_items="${host_json_items}, \"${label}\""
    fi
  done
  echo "[ ${host_json_items} ]" > "${logs_mount_dir}/hosts.json"
  setup_native_system_log_vhost "$session_token" "$web_port" "$logs_mount_dir" || {
    cleanup_session_port "$web_port"
    cleanup_firewall_rules "$web_port"
    return 1
  }
  local ssh_key=""
  if [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  elif [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  fi
  local ssh_opts=("-o" "ConnectTimeout=5" "-o" "StrictHostKeyChecking=no" "-o" "BatchMode=yes")
  [ -n "$ssh_key" ] && ssh_opts+=("-i" "$ssh_key")
  info "Initializing ${session_minutes}-minute Native System Log Session across cluster nodes:"
  local reset=$(tput sgr0 2>/dev/null || echo "")
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label _ <<< "$target"
    printf "$(tput setaf 148)%s\n${reset}" "- ${label}"
  done
  local log_stream_cmd='
    if command -v journalctl &>/dev/null; then
      stdbuf -oL journalctl -f -n 100 2>/dev/null
    else
      LOG_FILES=$(find /var/log -type f \( -name "messages" -o -name "secure" -o -name "auth*" -o -name "syslog*" \) \
        ! -name "*.gz" ! -name "*.xz" ! -name "*[0-9]*" 2>/dev/null);
      if [ -n "$LOG_FILES" ]; then
        stdbuf -oL tail -f -n 100 $LOG_FILES 2>/dev/null
      fi
    fi
  '
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label ssh_target <<< "$target"
    local host_log_file="${logs_mount_dir}/${label}.log"
    echo "[SYSTEM] Initializing live log stream for host: ${label}" > "$host_log_file"
    if [[ "$ssh_target" == "local" ]] || [[ "${ssh_target//*@}" == "$local_hostname" ]]; then
      stdbuf -oL bash -c "$log_stream_cmd" >> "$host_log_file" &
    else
      stdbuf -oL ssh "${ssh_opts[@]}" "$ssh_target" "$log_stream_cmd" >> "$host_log_file" 2>/dev/null &
    fi
  done
  local timer_pid=$!
  trap "
    warn 'Cleaning up Native System Log session.'
    kill $timer_pid 2>/dev/null || true
    rm -f '/etc/nginx/conf.d/sys_sess_${session_token}.conf'
    if command -v apache2 &>/dev/null; then
      sudo a2dissite 'sys_sess_${session_token}.conf' &>/dev/null || true
      rm -f '/etc/apache2/sites-available/sys_sess_${session_token}.conf'
    fi
    rm -f '/etc/httpd/conf.d/sys_sess_${session_token}.conf'
    if systemctl list-unit-files nginx.service | grep -q nginx.service && systemctl is-active --quiet nginx; then
      sudo systemctl reload nginx 2>/dev/null || true
    elif systemctl list-unit-files apache2.service | grep -q apache2.service && systemctl is-active --quiet apache2; then
      sudo systemctl reload apache2 2>/dev/null || true
    elif systemctl list-unit-files httpd.service | grep -q httpd.service && systemctl is-active --quiet httpd; then
      sudo systemctl reload httpd 2>/dev/null || true
    fi
    if [[ -n '${client_ip}' && '${client_ip}' != '127.0.0.1' && '${client_ip}' != '::1' ]]; then
      if [[ '${client_ip}' =~ : ]]; then
        sudo ip6tables -D INPUT -p tcp --dport '${web_port}' -s '${client_ip}' -j ACCEPT 2>/dev/null || true
        sudo ip6tables -D INPUT -p tcp --dport '${web_port}' -s '${client_ip}' -j DROP 2>/dev/null || true
      else
        sudo iptables -D INPUT -p tcp --dport '${web_port}' -s '${client_ip}' -j ACCEPT 2>/dev/null || true
        sudo iptables -D INPUT -p tcp --dport '${web_port}' -s '${client_ip}' -j DROP 2>/dev/null || true
      fi
    fi
    cleanup_session_port '${web_port}'
    cleanup_firewall_rules '${web_port}'
    info 'Native System Log session destroyed.'
  " EXIT
  info "Dashboard (Restricted to ${client_ip:-All}) will expire at: $(date -d "now + $session_minutes minutes")"
  success "Access Live Console Here: ${orange}http://${ui_target}:${web_port}/${session_token}/${reset}"
  (
    sleep "$session_seconds"
    cleanup_session_port "$web_port"
    cleanup_firewall_rules "$web_port"
    kill -SIGTERM $$ 2>/dev/null
  ) &
  info "Session active in background for ${session_minutes} minutes."
  info "To terminate early, run: kill ${timer_pid}"
  disown "$timer_pid" 2>/dev/null || true
  read -rp "Press Enter to continue..."
  cleanup_session_port "$web_port"
  cleanup_firewall_rules "$web_port"
  trap - EXIT
}
browse_files() {
  mapfile -t logs < <(
    sudo find / \
      \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \
      -type f -name "*.log" -print 2>/dev/null
  )
  [[ ${#logs[@]} -eq 0 ]] && {
    warn "No logs found."
    read -rp "${cyan}[USER]: ${reset}Press Enter to return..."
    return
  }
  list=()
  total_size=0
  for file in "${logs[@]}"; do
    base=$(basename "$file")
    group="/$(echo "$file" | cut -d/ -f2)"
    size_bytes=$(sudo stat -c%s "$file" 2>/dev/null || echo 0)
    total_size=$((total_size + size_bytes))
    size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null)
    if [[ "$file" == /var/log/one-click/* ]]; then
      priority="0"
      group="\033[1;34m$group\033[0m"
    else
      priority="1"
    fi
    list+=("$priority\t$group\t$base\t$size_human\t$file")
  done
  total_human=$(numfmt --to=iec --suffix=B "$total_size")
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
          --with-nth=1,2,3 \
          --preview 'sudo tail -n 200 {4}' \
          --preview-window=right:60%:wrap \
          --expect=enter,ctrl-e,ctrl-f,ctrl-a \
          --header="ENTER=open | CTRL-F=delete | CTRL-A=clean all | CTRL-E=back | Total: $total_human"
    )
    [[ -z "$selected" ]] && return
    key=$(echo "$selected" | head -n1)
    line=$(echo "$selected" | tail -n1)
    file=$(echo "$line" | awk -F'\t' '{print $4}')
    case "$key" in
      ctrl-f)
        read -rp "${cyan}[USER]: ${reset}Delete $(basename "$file")? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          truncate -s 0 "$file"
          success "Log cleared."
          sleep 1
        fi
        continue
        ;;
      ctrl-a)
        read -rp "${yellow}[WARNING]: ${reset}Clear ALL ${#logs[@]} logs (~$total_human)? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          for f in "${logs[@]}"; do
            truncate -s 0 "$f" 2>/dev/null
          done
          success "All logs cleared."
          sleep 2
        fi
        continue
        ;;
      ctrl-e)
        return
        ;;
      enter)
        clear
        sudo less -R "$file"
        clear
        ;;
    esac
  done
}
browse_journal() {
  while true; do
    journal_usage=$(journalctl --disk-usage 2>/dev/null | awk '{print $3,$4}')
    selection=$(
      systemctl list-units --type=service --no-legend \
        | awk '{print $1}' \
        | fzf \
            --height=85% \
            --border \
            --preview 'sudo journalctl -u {} -n 200 --no-pager' \
            --preview-window=right:60%:wrap \
            --expect=enter,ctrl-e,ctrl-f,ctrl-a \
            --header="ENTER=view | CTRL-F=clear service | CTRL-A=vacuum all | CTRL-E=back | Journal: $journal_usage"
    )
    [[ -z "$selection" ]] && return
    key=$(echo "$selection" | head -n1)
    unit=$(echo "$selection" | tail -n1)
    case "$key" in
      enter)
        clear
        sudo journalctl -u "$unit" --no-pager | less -R
        clear
        ;;
      ctrl-f)
        read -rp "${yellow}[WARNING]: ${reset}Clear journal for $unit? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          journalctl --unit="$unit" --rotate
          journalctl --unit="$unit" --vacuum-time=1s
          success "Journal for $unit cleared."
          sleep 2
        fi
        ;;
      ctrl-a)
        read -rp "${yellow}[WARNING]: ${reset}Vacuum ALL journal logs ($journal_usage)? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          journalctl --rotate
          journalctl --vacuum-time=1s
          success "All journal logs cleared."
          sleep 2
        fi
        ;;
      ctrl-e)
        return
        ;;
    esac
  done
}
reload_webserver() {
  local service_name=""
  if command -v nginx &>/dev/null; then
    service_name="nginx"
  elif command -v apache2 &>/dev/null; then
    service_name="apache2"
  elif command -v httpd &>/dev/null; then
    service_name="httpd"
  else
    error "No supported web server installed."
    return 1
  fi
  if systemctl is-active --quiet "$service_name"; then
    info "Web server '$service_name' is active. Testing configuration."
    if "$service_name" -t &>/dev/null || apachectl configtest &>/dev/null; then
      systemctl reload "$service_name"
      echo "Successfully reloaded $service_name."
    else
      error "Configuration test failed! Skipping reload."
      return 1
    fi
  else
    warn "Installing '$service_name'"
    "$pkg_mgr" install -y "$service_name"
    systemctl enable "$service_name" --now
  fi
}
# ==== Faileld Log ins ====
live_ssh_view() {
  build_vars
  local session_minutes="${LOG_VIEWER_SESSION:-10}"
  local excluded_hosts=()
  if [[ -n "${2:-}" ]]; then
    IFS=',' read -r -a excluded_hosts <<< "$2"
  fi
  local session_seconds=$((session_minutes * 60))
  local session_token=$(openssl rand -hex 16)
  local expire_ts=$(date -d "now + $session_minutes minutes" +%s)
  local inventory_file="/etc/one-click/fleet/inventory.yml"
  local available_ports_dir="/etc/one-click/log_viewer/ports"
  mkdir -p "$available_ports_dir"
  if [[ "${SSH_CLIENT:-}" =~ : ]]; then
    ui_target="$sys_ipv6"
  else
    ui_target="$sys_ip"
  fi
  if [[ "$ui_target" =~ : ]]; then
    ui_target="[$ui_target]"
  fi
  local web_port
  web_port=$(get_free_port)
  echo "$web_port" > "${available_ports_dir}/current_web_port"
  local client_ip
  client_ip=$(echo "${SSH_CLIENT:-}" | awk '{print $1}')
  [[ -z "$client_ip" ]] && client_ip=$(who am i 2>/dev/null | awk '{print $5}' | tr -d '()')
  if [[ -n "$client_ip" && "$client_ip" != "127.0.0.1" && "$client_ip" != "::1" ]]; then
    info "Locking session access exclusively to requesting IP: ${client_ip}"
    if [[ "$client_ip" =~ : ]]; then
      ip6tables -I INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
      ip6tables -A INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
    else
      iptables -I INPUT -p tcp --dport "$web_port" -s "$client_ip" -j ACCEPT 2>/dev/null || true
      iptables -A INPUT -p tcp --dport "$web_port" -j DROP 2>/dev/null || true
    fi
  fi
  local raw_targets=()
  if [[ -f "$inventory_file" ]] && command -v ansible &>/dev/null; then
    info "Discovering fleet members from Ansible inventory."
    local host_list
    host_list=$(ansible all --list-hosts -i "$inventory_file" 2>/dev/null | grep -v "hosts (" | awk '{print $1}')
    for host in $host_list; do
      raw_targets+=("${host}:${host}")
    done
  fi
  local local_hostname
  local_hostname=$(hostname -s)
  raw_targets+=("${local_hostname}:local")
  local remote_targets=()
  local seen_labels=()
  for item in "${raw_targets[@]}"; do
    IFS=":" read -r label target_type <<< "$item"
    if [[ " ${seen_labels[*]} " =~ " ${label} " ]]; then
      continue
    fi
    local skip=0
    for ex in "${excluded_hosts[@]}"; do
      if [[ "$label" == "$ex" ]]; then
        skip=1
        warn "Excluding host from stream: ${label}"
        break
      fi
    done
    [[ $skip -eq 1 ]] && continue
    seen_labels+=("$label")
    if [[ "${target_type//*@}" == "$local_hostname" ]] || [[ "$target_type" == "local" ]]; then
      remote_targets+=("${label}:local")
    else
      remote_targets+=("${label}:oneclick@${label}")
    fi
  done
  if [ ${#remote_targets[@]} -eq 0 ]; then
    error "No hosts available to stream SSH logs. Aborting."
    return 1
  fi
  local ssh_key=""
  if [ -f "/home/oneclick/.ssh/id_ed25519" ]; then
    ssh_key="/home/oneclick/.ssh/id_ed25519"
  elif [ -f "/etc/one-click/fleet/keys/id_ed25519" ]; then
    ssh_key="/etc/one-click/fleet/keys/id_ed25519"
  fi
  local ssh_opts=("-o" "ConnectTimeout=5" "-o" "StrictHostKeyChecking=no" "-o" "BatchMode=yes")
  [ -n "$ssh_key" ] && ssh_opts+=("-i" "$ssh_key")
  local tmp_dir
  tmp_dir=$(mktemp -d /tmp/custom_ssh_sess_XXXXXX)
  local logs_dir="${tmp_dir}/logs"
  mkdir -p "$logs_dir"
  local log_read_cmd='
    log_path="/etc/one-click/rule-engine/guard/ssh"
    if [ -d "$log_path" ]; then
      cat "$log_path"/*.log 2>/dev/null
    elif [ -f "$log_path" ]; then
      cat "$log_path" 2>/dev/null
    fi
  '
  local log_tail_cmd='
    log_path="/etc/one-click/rule-engine/guard/ssh"
    if [ -d "$log_path" ]; then
      stdbuf -oL tail -q -n 0 -F "$log_path"/*.log 2>/dev/null
    elif [ -f "$log_path" ]; then
      stdbuf -oL tail -n 0 -F "$log_path" 2>/dev/null
    fi
  '
  info "Pre-seeding historical metrics across ${#remote_targets[@]} fleet nodes..."
  local node_list=()
  local raw_history="${tmp_dir}/raw_history.tmp"
  touch "$raw_history"
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label ssh_target <<< "$target"
    node_list+=("$label")
    touch "${logs_dir}/${label}.json"
    if [[ "$ssh_target" == "local" ]] || [[ "${ssh_target//*@}" == "$local_hostname" ]]; then
      bash -c "$log_read_cmd" 2>/dev/null | jq -c --arg h "$label" 'select(.ip != null) | {node: $h, ip: .ip, user: (.user // "unknown")}' >> "$raw_history" &
    else
      ssh "${ssh_opts[@]}" "$ssh_target" "$log_read_cmd" 2>/dev/null | jq -c --arg h "$label" 'select(.ip != null) | {node: $h, ip: .ip, user: (.user // "unknown")}' >> "$raw_history" &
    fi
  done
  wait
  python3 - "$raw_history" "${tmp_dir}/summary.json" <<'EOF'
import sys, json

raw_file, out_file = sys.argv[1], sys.argv[2]
all_ips, all_users = {}, {}
hosts = {}

try:
    with open(raw_file, 'r') as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                ip = data.get('ip')
                user = data.get('user') or 'unknown'
                node = data.get('node') or 'local'

                if ip:
                    all_ips[ip] = all_ips.get(ip, 0) + 1
                    all_users[user] = all_users.get(user, 0) + 1

                    if node not in hosts:
                        hosts[node] = {'ips': {}, 'users': {}}
                    hosts[node]['ips'][ip] = hosts[node]['ips'].get(ip, 0) + 1
                    hosts[node]['users'][user] = hosts[node]['users'].get(user, 0) + 1
            except Exception:
                pass
except Exception:
    pass

res = {
    "all": {"ips": all_ips, "users": all_users},
    "hosts": hosts
}

with open(out_file, 'w') as f:
    json.dump(res, f)
EOF
  for target in "${remote_targets[@]}"; do
    IFS=":" read -r label ssh_target <<< "$target"
    local node_file="${logs_dir}/${label}.json"
    if [[ "$ssh_target" == "local" ]] || [[ "${ssh_target//*@}" == "$local_hostname" ]]; then
      stdbuf -oL bash -c "$log_tail_cmd" 2>/dev/null | jq --unbuffered -c --arg h "$label" 'select(.ip != null) | . + {node: $h}' >> "$node_file" &
    else
      stdbuf -oL ssh "${ssh_opts[@]}" "$ssh_target" "$log_tail_cmd" 2>/dev/null | jq --unbuffered -c --arg h "$label" 'select(.ip != null) | . + {node: $h}' >> "$node_file" &
    fi
  done
  printf '%s\n' "${node_list[@]}" > "${tmp_dir}/nodes.txt"
  cat << 'EOF' > "${tmp_dir}/server.py"
import os, sys, time, json
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
PORT = int(sys.argv[1])
SESSION_TOKEN = sys.argv[2]
TMP_DIR = sys.argv[3]
LOGS_DIR = os.path.join(TMP_DIR, "logs")
SUMMARY_FILE = os.path.join(TMP_DIR, "summary.json")
EXPIRE_TS = int(sys.argv[4])
with open(os.path.join(TMP_DIR, "nodes.txt")) as f:
    NODES = [line.strip() for line in f if line.strip()]

HTML_CONTENT = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>One-Click Log Browser</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body {{ background: #0f172a; color: #f8fafc; font-family: system-ui, sans-serif; margin: 0; padding: 24px; }}
    header {{ display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 1px solid #334155; padding-bottom: 16px; }}
    h1 {{ color: #38bdf8; margin: 0; font-size: 1.5rem; }}
    .header-info {{ display: flex; gap: 12px; align-items: center; }}
    #status {{ font-size: 0.875rem; font-weight: 600; padding: 6px 12px; background: #1e293b; border: 1px solid #334155; border-radius: 6px; color: #94a3b8; }}
    #timer {{ font-size: 0.875rem; font-weight: 700; padding: 6px 12px; background: #0f172a; border: 1px solid #eab308; border-radius: 6px; color: #eab308; font-family: monospace; }}
    .host-tabs {{ display: flex; gap: 8px; margin-bottom: 20px; border-bottom: 2px solid #334155; padding-bottom: 8px; overflow-x: auto; }}
    .tab-btn {{ background: #1e293b; color: #94a3b8; border: 1px solid #334155; padding: 8px 16px; border-radius: 6px; font-weight: 600; font-size: 0.85rem; cursor: pointer; white-space: nowrap; }}
    .tab-btn.active {{ background: #38bdf8; color: #0f172a; border-color: #38bdf8; font-weight: bold; }}
    .toolbar {{ display: flex; gap: 12px; margin-bottom: 24px; flex-wrap: wrap; }}
    .btn {{ background: #1e293b; color: #38bdf8; border: 1px solid #38bdf8; padding: 8px 16px; border-radius: 6px; font-weight: 600; font-size: 0.85rem; cursor: pointer; }}
    .btn:hover {{ background: #38bdf8; color: #0f172a; }}
    .btn-danger {{ color: #ef4444; border-color: #ef4444; }}
    .section-card {{ background: #1e293b; padding: 20px; border-radius: 10px; border: 1px solid #334155; margin-bottom: 24px; }}
    .section-title {{ font-size: 1.1rem; color: #f1f5f9; margin-top: 0; margin-bottom: 16px; }}
    .chart-box {{ position: relative; width: 100%; min-height: 300px; }}
    .console-box {{ background: #090d16; border: 1px solid #334155; border-radius: 6px; padding: 12px; height: 180px; overflow-y: auto; font-family: monospace; font-size: 0.825rem; }}
    .log-line {{ border-bottom: 1px solid #1e293b; padding: 4px 0; display: flex; gap: 12px; }}
    .log-ts {{ color: #64748b; }}
    .log-node {{ color: #a855f7; font-weight: bold; width: 110px; }}
    .log-ip {{ color: #ef4444; font-weight: bold; width: 130px; }}
    .log-user {{ color: #38bdf8; width: 110px; }}
  </style>
</head>
<body>
  <header>
    <h1>SSH Guard - Failed Login Logs</h1>
    <div class="header-info">
      <div id="timer">Expires in: --:--</div>
      <div id="status">Connecting...</div>
    </div>
  </header>
  <div class="host-tabs" id="hostTabContainer"></div>
  <div class="toolbar">
    <button class="btn btn-danger" onclick="exportIptablesBlocklist()">🛡️ Export IPTables Blocklist Script</button>
    <button class="btn" onclick="copyTopIPs()">📋 Copy Top 10 IPs to Clipboard</button>
    <button class="btn" onclick="exportCSV()">📊 Export CSV Report</button>
  </div>
  <div class="section-card">
    <div class="section-title">🚨 Offending IP Address Count<span id="nodeSubtitle" style="color: #94a3b8; font-size: 0.9rem;">(All Nodes)</span></div>
    <div class="chart-box"><canvas id="ipChart"></canvas></div>
  </div>
  <div class="section-card">
    <div class="section-title">👤 Most Used Usernames</div>
    <div class="chart-box"><canvas id="userChart"></canvas></div>
  </div>
  <div class="section-card">
    <div class="section-title">⚡ Live SSH Activity Tracker</div>
    <div class="console-box" id="consoleFeed"><div style="color: #64748b;">Connecting...</div></div>
  </div>
  <script>
    const expireTimestamp = {EXPIRE_TS};
    const nodes = {json.dumps(NODES)};
    let activeTab = 'ALL';
    let evtSource = null;
    let ipCounts = {{}};
    let userCounts = {{}};
    let initialClusterData = {{}};
    function updateCountdown() {{
      const now = Math.floor(Date.now() / 1000);
      const remaining = Math.max(0, expireTimestamp - now);
      const timerElem = document.getElementById('timer');
      if (remaining <= 0) {{
        timerElem.innerText = 'Session Expired';
        timerElem.style.borderColor = '#ef4444';
        timerElem.style.color = '#ef4444';
        return;
      }}
      const m = Math.floor(remaining / 60);
      const s = remaining % 60;
      timerElem.innerText = `Expires in: ${{String(m).padStart(2,'0')}}:${{String(s).padStart(2,'0')}}`;
      if (remaining <= 60) {{
        timerElem.style.borderColor = '#ef4444';
        timerElem.style.color = '#ef4444';
      }}
    }}
    updateCountdown();
    setInterval(updateCountdown, 1000);
    const tabContainer = document.getElementById('hostTabContainer');
    tabContainer.innerHTML = `<button class="tab-btn active" id="tab-ALL" onclick="switchTab('ALL')">🌐 OC Fleet (Aggregated)</button>`;
    nodes.forEach(n => {{
      tabContainer.innerHTML += `<button class="tab-btn" id="tab-${{n}}" onclick="switchTab('${{n}}')">🖥️ ${{n}}</button>`;
    }});
    const ipCtx = document.getElementById('ipChart').getContext('2d');
    const userCtx = document.getElementById('userChart').getContext('2d');
    const ipChart = new Chart(ipCtx, {{
      type: 'bar',
      data: {{ labels: [], datasets: [{{ label: 'Failed Attempts', data: [], backgroundColor: [], barThickness: 12 }}] }},
      options: {{ responsive: true, maintainAspectRatio: false, plugins: {{ legend: {{ display: false }} }} }}
    }});
    const userChart = new Chart(userCtx, {{
      type: 'bar',
      data: {{ labels: [], datasets: [{{ label: 'Target Attempts', data: [], backgroundColor: '#8b5cf6', barThickness: 10 }}] }},
      options: {{ indexAxis: 'y', responsive: true, maintainAspectRatio: false, plugins: {{ legend: {{ display: false }} }} }}
    }});
    function getColors(data) {{
      return data.map(v => v >= 3000 ? '#ef4444' : (v >= 1000 ? '#eab308' : '#3b82f6'));
    }}
    let updateScheduled = false;
    function scheduleChartUpdate() {{
      if (updateScheduled) return;
      updateScheduled = true;
      requestAnimationFrame(() => {{
        const sortedIPs = Object.entries(ipCounts).sort((a,b) => b[1]-a[1]).slice(0, 50);
        ipChart.data.labels = sortedIPs.map(e => e[0]);
        ipChart.data.datasets[0].data = sortedIPs.map(e => e[1]);
        ipChart.data.datasets[0].backgroundColor = getColors(sortedIPs.map(e => e[1]));
        ipChart.update('none');
        const sortedUsers = Object.entries(userCounts).sort((a,b) => b[1]-a[1]).slice(0, 50);
        userChart.data.labels = sortedUsers.map(e => e[0]);
        userChart.data.datasets[0].data = sortedUsers.map(e => e[1]);
        userChart.update('none');
        updateScheduled = false;
      }});
    }}
    function switchTab(node) {{
      activeTab = node;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.getElementById(`tab-${{node}}`).classList.add('active');
      document.getElementById('nodeSubtitle').innerText = node === 'ALL' ? '(All Nodes)' : `(Node: ${{node}})`;
      if (node === 'ALL' && initialClusterData.all) {{
        ipCounts = Object.assign({{}}, initialClusterData.all.ips);
        userCounts = Object.assign({{}}, initialClusterData.all.users);
      }} else if (initialClusterData.hosts && initialClusterData.hosts[node]) {{
        ipCounts = Object.assign({{}}, initialClusterData.hosts[node].ips);
        userCounts = Object.assign({{}}, initialClusterData.hosts[node].users);
      }} else {{
        ipCounts = {{}};
        userCounts = {{}};
      }}
      document.getElementById('consoleFeed').innerHTML = '';
      scheduleChartUpdate();
      if (evtSource) evtSource.close();
      connectStream(node);
    }}
    function connectStream(node) {{
      document.getElementById('status').innerText = `Connected: ${{node}}`;
      evtSource = new EventSource(`/{SESSION_TOKEN}/stream/${{node}}`);
      evtSource.onmessage = (e) => {{
        try {{
          const payload = JSON.parse(e.data);
          if (payload.type === 'init') {{
            initialClusterData = payload;
            if (activeTab === 'ALL' && payload.all) {{
              ipCounts = Object.assign({{}}, payload.all.ips);
              userCounts = Object.assign({{}}, payload.all.users);
            }} else if (payload.hosts && payload.hosts[activeTab]) {{
              ipCounts = Object.assign({{}}, payload.hosts[activeTab].ips);
              userCounts = Object.assign({{}}, payload.hosts[activeTab].users);
            }}
            scheduleChartUpdate();
            return;
          }}
          if (payload.type === 'live' && payload.data.ip) {{
            const item = payload.data;
            ipCounts[item.ip] = (ipCounts[item.ip] || 0) + 1;
            userCounts[item.user || 'unknown'] = (userCounts[item.user || 'unknown'] || 0) + 1;
            scheduleChartUpdate();
            const feed = document.getElementById('consoleFeed');
            const row = document.createElement('div');
            row.className = 'log-line';
            row.innerHTML = `<span class="log-ts">[${{new Date().toLocaleTimeString()}}]</span>` +
                            `<span class="log-node">[${{item.node || 'local'}}]</span>` +
                            `<span class="log-ip">${{item.ip}}</span>` +
                            `<span class="log-user">user: ${{item.user || 'unknown'}}</span>`;
            feed.insertBefore(row, feed.firstChild);
            if (feed.children.length > 100) feed.removeChild(feed.lastChild);
          }}
        }} catch(err) {{}}
      }};
    }}
    function exportIptablesBlocklist() {{
      const offenders = Object.entries(ipCounts).filter(e => e[1] >= 1000).map(e => e[0]);
      if (!offenders.length) return alert('No IPs over threshold (1000).');
      let script = `#!/bin/bash\\n# Blocklist for ${{activeTab}}\\n`;
      offenders.forEach(ip => script += `iptables -A INPUT -s ${{ip}} -j DROP\\n`);
      download(script, `blocklist_${{activeTab}}.sh`);
    }}
    function copyTopIPs() {{
      const top = Object.entries(ipCounts).sort((a,b) => b[1]-a[1]).slice(0, 10).map(e => e[0]).join('\\n');
      navigator.clipboard.writeText(top).then(() => alert('Top 10 copied!'));
    }}
    function exportCSV() {{
      let csv = 'IP,Attempts,Risk\\n';
      Object.entries(ipCounts).sort((a,b) => b[1]-a[1]).forEach(([ip, c]) => {{
        csv += `${{ip}},${{c}},${{c>=3000?'CRITICAL':(c>=1000?'HIGH':'MODERATE')}}\\n`;
      }});
      download(csv, `report_${{activeTab}}.csv`);
    }}
    function download(content, name) {{
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob = new Blob([content]));
      a.download = name;
      a.click();
    }}
    connectStream('ALL');
  </script>
</body>
</html>"""
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
class SSEHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path == f"/{SESSION_TOKEN}":
            body = HTML_CONTENT.encode('utf-8')
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if clean_path.startswith(f"/{SESSION_TOKEN}/stream/"):
            target_node = clean_path.split('/')[-1]
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            if os.path.exists(SUMMARY_FILE):
                try:
                    with open(SUMMARY_FILE, "r") as sf:
                        summary_data = sf.read().strip()
                        if summary_data:
                            init_payload = json.dumps({"type": "init", **json.loads(summary_data)})
                            self.wfile.write(f"data: {init_payload}\n\n".encode('utf-8'))
                            self.wfile.flush()
                except Exception:
                    pass

            if target_node == "ALL":
                target_files = [os.path.join(LOGS_DIR, f) for f in os.listdir(LOGS_DIR) if f.endswith('.json')]
            else:
                target_files = [os.path.join(LOGS_DIR, f"{target_node}.json")]

            handles = []
            for tf in target_files:
                if os.path.exists(tf):
                    h = open(tf, "r")
                    h.seek(0, os.SEEK_END)
                    handles.append(h)

            try:
                while True:
                    read_any = False
                    for h in handles:
                        line = h.readline()
                        if line:
                            read_any = True
                            line_str = line.strip()
                            if line_str:
                                live_payload = json.dumps({"type": "live", "data": json.loads(line_str)})
                                self.wfile.write(f"data: {live_payload}\n\n".encode('utf-8'))
                                self.wfile.flush()
                    if not read_any:
                        time.sleep(0.1)
            except (OSError, BrokenPipeError):
                pass
            finally:
                for h in handles:
                    h.close()
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    server = ThreadedHTTPServer(('0.0.0.0', PORT), SSEHandler)
    server.serve_forever()
EOF
  cleanup() {
    warn "Cleaning up SSH Log Visualizer session."
    kill $(jobs -p) 2>/dev/null || true
    if [[ -n "${client_ip}" && "${client_ip}" != '127.0.0.1' && "${client_ip}" != '::1' ]]; then
      if [[ "${client_ip}" =~ : ]]; then
        ip6tables -D INPUT -p tcp --dport "${web_port}" -s "${client_ip}" -j ACCEPT 2>/dev/null || true
        ip6tables -D INPUT -p tcp --dport "${web_port}" -j DROP 2>/dev/null || true
      else
        iptables -D INPUT -p tcp --dport "${web_port}" -s "${client_ip}" -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -p tcp --dport "${web_port}" -j DROP 2>/dev/null || true
      fi
    fi
    cleanup_session_port "$web_port"
    cleanup_firewall_rules "$web_port"
    rm -rf "$tmp_dir"
    rm -f "${available_ports_dir}/current_web_port"
    info "SSH Log Visualizer session destroyed."
  }
  trap cleanup EXIT
  python3 "${tmp_dir}/server.py" "$web_port" "$session_token" "$tmp_dir" "$expire_ts" &
  local timer_pid=$!
  info "Dashboard (Restricted to ${client_ip:-All}) will expire at: $(date -d "@$expire_ts")"
  success "Access Live Console Here: http://${ui_target}:${web_port}/${session_token}/"
  (
    sleep "$session_seconds"
    cleanup_session_port "$web_port"
    cleanup_firewall_rules "$web_port"
    kill -SIGTERM $$ 2>/dev/null
  ) &
  info "Session active in background for ${session_minutes} minutes."
  info "To terminate early, run: kill ${timer_pid}"
  disown "$timer_pid" 2>/dev/null || true
  read -rp "Press Enter to continue..."
}
# ============================================== End Of Log Browser ======================================================
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
    echo "$(date) - Network down, waiting 10s."
    sleep 10
  done
  info "Network detected. Starting rsync."
}
remove_service() {
    if [[ -f "$service_file" ]]; then
        warn "Removing systemd service $service_file"
        sudo systemctl disable "$service_name" >/dev/null || true
        sudo rm -f "$service_file"
        sudo systemctl daemon-reload
    fi
}
