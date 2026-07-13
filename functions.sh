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
# === Build: Jan 2026 === # === Updated: July 2026 == # == Version#: 1.2.0 === #
# ====== One-Click ====== #
mkdir -p "${log_dir:-}"
touch "${log_error_file:-}" "${log_file:-}"
sensitive_ports_file="/etc/one-click/rule-engine/.sensitive.ports"
# ==== Build Essential Variables ====
build_vars() {
  mapfile -t local_drives < <(lsblk -dn -o NAME,SIZE,TYPE | awk '$3=="disk"{print $1,$2}')
  drives=($(lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}'))
  if ip link show br0 &> /dev/null; then
    nic=br0
  else
    nic="$nic"
  fi
  sys_ipv6="$(awk '/inet6/ && $NF=="global" || $(NF-1)=="global" {split($2,arr,"/");print arr[1]}' <(ip -6 a s "$nic"))"
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
  snaps_dir="$base_dir/snapshots"
  config_dir="$base_dir/configuration"
  service_restore="$base_dir/service.restore"
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
# ==== End Essential Variables ==== #
collect_sysinfo() {
  whois_ip="$(sed -En '/inet /{s,^[^/]* ([^/]*).*,\1,p}' <(ip a s "$nic"))"
  whois_ipv6=$(sed -En '/inet6.*global/{s,^[^/]* ([^/]*/[0-9]+).*,\1,p}' <(ip a s "$nic"))
  api_response=$(curl -sL https://ipinfo.io/${whois_ip}/json || true)
  api_response2=$(curl -sL http://ip-api.com/json/${whois_ip} || true)
  sys_ip="$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic"))"
  sys_gw="$(awk '$1 == "default" {print $3}' <(ip r &> /dev/null)|head -1)"
  ip_upstream="$(jq -r '.org' <<< $api_response)"
  ip_country="$(jq -r '.country' <<< $api_response)"
  ip_asn="$(jq -r '.as' <<< $api_response2)"
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
  local url path archive gb_cmd
  url="$1"
  path="$2"
  version="$3"
  gb_cmd="geekbench${version}"
  archive="/tmp/geekbench_${version}.tar.gz"
  mkdir -p "$path" || exit 1
  curl -fSL "$url" -o "$archive" &> /dev/null|| {
    error "Download failed"
    exit 1
  }
  tar -xzf "$archive" \
    --strip-components=1 \
    -C "$path" &> /dev/null || {
    error "Extraction failed"
    exit 1
  }
  chmod +x "$path/$gb_cmd" || {
    echo "[GB] chmod failed"
    exit 1
  }
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
  if [[ $version == "6" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench6"
    gb_run="True"
  elif [[ $version == "5" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench5"
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
  printf "${green}│ %-96s${reset}\r" "Preparing Geekbench $version..."
  install_geekbench "$gb_url" "$gb_path" "$version"
  if [[ ! -x "$gb_path/$gb_cmd" ]]; then
    printf "${red}%s${reset}\n" \
      "│ Geekbench binary missing or not executable: $gb_path/$gb_cmd                                     │"
	printf "${yellow}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return
  fi
  printf "${yellow}│ %-96s${reset}\r" "${green}Running GB$version benchmark...${yellow}"
  output=$("$gb_path/$gb_cmd" 2>&1)
  test_url=$(grep -Eom1 'https://browser\.geekbench\.com[^[:space:]]+' <<< "$output" || true)
  if [[ -z "$test_url" ]]; then
    printf "${blue}%-20s %-20s %-54s${reset}\n" \
      "│Geekbench" "GB${version}" "${red}Failed${blue}                                                    │"
    printf "${blue}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return
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
  timestamp=$(date '+%F %T')
  # ==== Build Config File ====
    echo "single=$single" > /etc/one-click/ocb/meta.conf
	echo "multi=$multi" >> /etc/one-click/ocb/meta.conf
	echo "gb_id=$gb_id" >> /etc/one-click/ocb/meta.conf
	echo "gb_url=$test_url" >> /etc/one-click/ocb/meta.conf
	echo "timestamp=\"$timestamp\"" >> /etc/one-click/ocb/meta.conf
  if [[ ! -f "$results_file" || ! -s "$results_file" ]]; then
    first_run=1
    echo "$timestamp|$single|$multi|$test_url" >> "$results_file"
    printf "${blue}│${yellow}%-20s %-20s %-56s${blue}│${reset}\n" \
      "Benchmark Status" "GB$version" "First benchmark run recorded"
  else
    first_run=0
    last_line=$(tail -1 "$results_file")
    IFS='|' read -r old_date old_single old_multi old_url <<< "$last_line"
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
    echo "$timestamp|$single|$multi|$test_url" >> "$results_file"
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
      "Previous Test" "GB$version" "$old_date" \
      "Prev Single Core" "GB$version" "$old_single" \
      "Prev Multi Core" "GB$version" "$old_multi" \
      "Single Trend" "GB$version" \
      "$single_trend (${single_symbol}${single_diff}, ${single_symbol}${single_pct}%)" \
      "Multi Trend" "GB$version" "$multi_trend (${multi_symbol}${multi_diff}, ${multi_symbol}${multi_pct}%)"
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
    local bs mode json
    bs=$1
    mode=$2
    json=$(fio \
      --name=test \
      --filename="$fio_file" \
      --size="$size" \
      --bs="$bs" \
      --rw="$mode" \
      --iodepth=64 \
      --ioengine=libaio \
      --direct=1 \
      --runtime="$duration" \
      --time_based \
      --group_reporting \
      --output-format=json 2>/dev/null | sed -n '/^{/,$p')
    bw=$(jq -r ".jobs[0].$mode.bw_bytes" <<< "$json")
    iops=$(jq -r ".jobs[0].$mode.iops" <<< "$json")
    mb=$(awk "BEGIN {printf \"%.2f\", $bw/1048576}")
    printf "%s MB/s (%s)" "$mb" "$iops"
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
  printf "\r${yellow}│$green %-96s${reset}\n" "Initializing Fio Benchmark...                                                                    ${yellow}│$reset"
  sleep 2
  fio_status "Running read test (4k)..."
  read r4_bw r4_iops <<< "$(get_vals 4k read)"
  r4_iops=$(sanitize_int "$r4_iops")
  fio_status "Running read test (64k)..."
  read r64_bw r64_iops <<< "$(get_vals 64k read)"
  r64_iops=$(sanitize_int "$r64_iops")
  fio_status "Running read test (512k)..."
  read r512_bw r512_iops <<< "$(get_vals 512k read)"
  r512_iops=$(sanitize_int "$r512_iops")
  fio_status "Running read test (1m)..."
  read r1m_bw r1m_iops <<< "$(get_vals 1m read)"
  r1m_iops=$(sanitize_int "$r1m_iops")
  fio_status "Running write test (4k)..."
  read w4_bw w4_iops <<< "$(get_vals 4k write)"
  w4_iops=$(sanitize_int "$w4_iops")
  fio_status "Running write test (64k)..."
  read w64_bw w64_iops <<< "$(get_vals 64k write)"
  w64_iops=$(sanitize_int "$w64_iops")
  fio_status "Running write test (512k)..."
  read w512_bw w512_iops <<< "$(get_vals 512k write)"
  w512_iops=$(sanitize_int "$w512_iops")
  fio_status "Running write test (1m)..."
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
}
# ============================================= End One-Click Bench ========================================= #
# ================================================= Fleet =================================================== #
fleet_init() {
  install_dep "bc" "command -v bc" "bc" "$pkg_mgr" true
  local_host=$(hostname -s)
  local inventory_json="/etc/one-click/virtualization/inventory.json"
  build_vars
  info "Initialising Fleet and dependancies..."
  mkdir -p \
    "$fleet_root/state" \
    "$fleet_root/playbooks" \
    "$fleet_root/keys" \
    "$fleet_root/audits" \
    "$fleet_root/benchmarks"
  fleet_write_inventory
  if [[ -f "$fleet_root/controller.env" ]]; then
    . "$fleet_root/controller.env"
	# ==== Do we have management? ====
    if [[ "${ROLE_TYPE:-}" == "peer" && -n "$CONTROLLER_IP" && "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
      warn "This server is already actively locked to Controller ($CONTROLLER_IP)."
      error "To reassign this server, you must manually delete '$fleet_root/controller.env' on this host first."
      return 1
    fi
  else
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
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    cat > "$fleet_root/controller.env" <<EOF
CONTROLLER_IP="$CONTROLLER_IP"
CONTROLLER_NAME="$CONTROLLER_NAME"
ROLE_TYPE="peer"
IS_MASTER="false"
EOF
    . "$fleet_root/controller.env"
  fi
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
            dnf install -y ansible-core
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
}
flbench_launch() {
  rm -f \
    /etc/one-click/ocb/benchmarks/COMPLETE \
    /etc/one-click/ocb/benchmarks/job.state \
    /etc/one-click/ocb/benchmarks/latest.json
	cat > /etc/one-click/flbench.sh << EOF
#!/bin/bash
# Written by Chike Egbuna for One-Click Toolkit
nohup sudo /bin/bash -c "/usr/local/bin/one-click fl >> /var/log/one-click/one-click-bench-stream.log 2>&1" &
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
fleet_static_root="/etc/one-click/fleet"
inventory="/etc/one-click/fleet/inventory.yml"
if [[ -f "$fleet_static_root/controller.env" ]]; then
  source "$fleet_static_root/controller.env"
fi
nic=$(ip route show default | awk '{print $5}')
if [[ -z "$nic" ]]; then
  nic=$(awk '{print $5}' <(ip -6 r s default))
fi
if ip link show br0 > /dev/null; then
    nic=br0
  else
    nic="$nic"
  fi
current_system_ip="$(awk '$1 == "inet" { split($2, arr, "/"); print arr[1] }; $1 == "inet6" { split($2, arr, "/"); print arr[1] }' <(ip a s "$nic") | head -1)"
if [[ -n "${CONTROLLER_IP:-}" ]]; then
  if [[ "$current_system_ip" != "$CONTROLLER_IP" ]]; then
    exit 0
  fi
fi
local_hostname=$(hostname -s)
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
is_peer_node=false
if [[ "$current_system_ip" != "$CONTROLLER_IP" ]]; then
  node_private_key_path="/home/oneclick/.ssh/id_ed25519"
else
  node_private_key_path="/etc/one-click/fleet/keys/id_ed25519"
fi
if [[ -f "$fleet_static_root/state/${local_hostname}.conf" ]]; then
  source "$fleet_static_root/state/${local_hostname}.conf"
  if [[ -n "${NODE_PUBKEY:-}" ]]; then
    is_peer_node=true
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
  filename=$(basename "$file")
  filename="${filename%.conf}"
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
  cat >> "$inventory" <<EOB
    $inventory_name:
      ansible_host: $ip
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
  # ==== Audit Playbook
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
- name: Configure Hypervisors for Remote Virsh Console Access
  hosts: "{{ target }}"
  become: true
  gather_facts: false

  tasks:
    - name: Ensure netcat-openbsd is installed for socket tunneling
      apt:
        name: netcat-openbsd
        state: present
        update_cache: yes

    - name: Add oneclick user to the libvirt system group
      user:
        name: oneclick
        groups: libvirt
        append: yes

    - name: Configure libvirtd Unix socket group ownership
      lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?unix_sock_group\s*='
        line: 'unix_sock_group = "libvirt"'

    - name: Configure libvirtd Unix socket permissions
      lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?unix_sock_rw_perms\s*='
        line: 'unix_sock_rw_perms = "0770"'

    - name: Bypass Polkit authentication for group members
      lineinfile:
        path: /etc/libvirt/libvirtd.conf
        regexp: '^#?auth_unix_rw\s*='
        line: 'auth_unix_rw = "none"'

    - name: Stop libvirtd socket to release file descriptors
      systemd:
        name: libvirtd.socket
        state: stopped

    - name: Restart Libvirt service daemon to apply socket permissions
      systemd:
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
        name: "{{ cfg.site_group }}"
        state: present

    - name: Ensure isolation system user
      user:
        name: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        shell: /usr/sbin/nologin
        system: yes
        create_home: yes
        state: present

    - name: Ensure target application path hierarchy exists
      file:
        path: "{{ cfg.site_dir }}"
        state: directory
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: '0755'

    - name: Sync site core directory data files
      copy:
        src: "{{ tmp_bundle_dir }}/site_data/"
        dest: "{{ cfg.site_dir }}/"
        remote_src: yes
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: preserve

    - name: Restore PHP config
      when: cfg.php.enabled | bool
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
      when: cfg.redis.enabled | bool
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
      when: cfg.systemd_service.enabled | bool
      register: app_systemd_changed

    - name: Trigger systemd reload
      systemd:
        daemon_reload: yes
      when: (php_systemd_changed is defined and php_systemd_changed.changed) or
            (redis_systemd_changed is defined and redis_systemd_changed.changed) or
            (app_systemd_changed is defined and app_systemd_changed.changed)

    - name: Detect dynamic multi-database dump manifest profiles
      stat:
        path: "{{ tmp_bundle_dir }}/db_manifest.txt"
      register: db_manifest_file

    - name: Detect dynamic multi-database dump manifest profiles
      stat:
        path: "{{ tmp_bundle_dir }}/db_manifest.txt"
      register: db_manifest_file

    - name: Multi-Database Restoration
      when: db_manifest_file.stat.exists and db_manifest_file.stat.size > 0
      block:
        - name: Ensure target database management binaries are installed
          package:
            name:
              - mariadb-server
              - python3-mysqldb
            state: present

        - name: Ensure target database system daemon is enabled and active
          service:
            name: mariadb
            state: started
            enabled: yes

        - name: Parse lines from multi-database mapping text file
          slurp:
            src: "{{ tmp_bundle_dir }}/db_manifest.txt"
          register: db_lines_raw

        - name: Complete parallel restore loops against verified targeted dumps
          include_tasks: restore_db_loop.yml
          vars:
            db_item: "{{ item }}"
          loop: "{{ (db_lines_raw.content | b64decode).splitlines() }}"

    - name: Ensure webserver daemon
      service:
        name: "{{ cfg.webserver_service }}"
        state: started
        enabled: yes
      when: cfg.webserver_service != 'null' and cfg.webserver_service != ''

    - name: Ensure webserver is installed
      package:
        name: "{{ cfg.webserver_service }}"
        state: present
      when: cfg.webserver_service != 'null' and cfg.webserver_service != ''
      register: webserver_installed

    - name: Ensure webserver conf dir exists
      file:
        path: "{{ cfg.vhost | dirname }}"
        state: directory
        owner: root
        group: root
        mode: '0755'
      when: cfg.vhost != 'null' and cfg.vhost != ''

    - name: Deploy Webserver Host Routing
      copy:
        src: "{{ tmp_bundle_dir }}/vhost.conf"
        dest: "{{ cfg.vhost }}"
        remote_src: yes
      register: web_vhost_copied
      when: cfg.vhost != 'null' and cfg.vhost != ''

    - name: Establish Webserver Symbolic Links
      file:
        src: "{{ cfg.vhost }}"
        dest: "{{ cfg.vhost_link }}"
        state: link
      when:
        - web_vhost_copied is succeeded and web_vhost_copied.changed
        - cfg.vhost_link != 'null' and cfg.vhost_link != ''

    - name: Reload/Restart Web Daemon
      service:
        name: "{{ cfg.webserver_service }}"
        state: "{{ 'restarted' if webserver_installed.changed else 'reloaded' }}"
      when: web_vhost_copied is succeeded and web_vhost_copied.changed

    - name: Restart Application
      service:
        name: "{{ item }}"
        state: restarted
      loop:
        - "{{ cfg.php.service | default(omit) }}"
        - "{{ cfg.redis.service | default(omit) }}"
        - "{{ cfg.systemd_service.name | default(omit) }}"
      when: item != "" and item != omit

    - name: Clean up
      file:
        path: "{{ item }}"
        state: absent
      with_items:
        - "{{ tmp_bundle_dir }}"
        - "{{ local_archive_path }}"
EOF
  cat > "$fleet_root/playbooks/site_import.yml" <<'EOF'
# Written by Chike Egbuna for One-Click ToolBox
---
- name: Fleet Web Data Provisioning
  hosts: "{{ target_host }}"
  become: yes
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

    - name: Ensure isolation group exists
      group:
        name: "{{ cfg.site_group }}"
        state: present

    - name: Ensure isolation user exists
      user:
        name: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        shell: /usr/sbin/nologin
        system: yes
        create_home: yes
        state: present

    - name: Ensure application path exists
      file:
        path: "{{ cfg.site_dir }}"
        state: directory
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: '0755'

    - name: Sync site directory
      copy:
        src: "{{ tmp_bundle_dir }}/site_data/"
        dest: "{{ cfg.site_dir }}/"
        remote_src: yes
        owner: "{{ cfg.site_user }}"
        group: "{{ cfg.site_group }}"
        mode: preserve

    - name: Restore PHP config
      when: cfg.php.enabled | bool
      block:
        - name: Ensure PHP pool configuration exists
          file:
            path: "{{ cfg.php.pool | dirname }}"
            state: directory
            owner: root
            group: root
            mode: '0755'

        - name: Provision custom PHP pool conf
          copy:
            src: "{{ tmp_bundle_dir }}/php-pool.conf"
            dest: "{{ cfg.php.pool }}"
            remote_src: yes

        - name: Provision custom php.ini drop-in tracking context
          copy:
            src: "{{ tmp_bundle_dir }}/php.ini"
            dest: "{{ cfg.php.ini }}"
            remote_src: yes
          failed_when: false

        - name: Restore PHP Systemd Vhost definition
          copy:
            src: "{{ tmp_bundle_dir }}/php-systemd.service"
            dest: "{{ cfg.php.vhost }}"
            remote_src: yes
          register: php_systemd_changed

    - name: Restore Redis instance
      when: cfg.redis.enabled | bool
      block:
        - name: Deploy isolated redis instance
          copy:
            src: "{{ tmp_bundle_dir }}/redis.conf"
            dest: "{{ cfg.redis.conf }}"
            remote_src: yes

        - name: Deploy Redis systemd service
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
      when: cfg.systemd_service.enabled | bool
      register: app_systemd_changed

    - name: Trigger systemd reload
      systemd:
        daemon_reload: yes
      when: (php_systemd_changed is defined and php_systemd_changed.changed) or
            (redis_systemd_changed is defined and redis_systemd_changed.changed) or
            (app_systemd_changed is defined and app_systemd_changed.changed)

    - name: Detect multi-database
      stat:
        path: "{{ tmp_bundle_dir }}/db_manifest.txt"
      register: db_manifest_file

    - name: Detect dynamic multi-database dump manifest profiles
      stat:
        path: "{{ tmp_bundle_dir }}/db_manifest.txt"
      register: db_manifest_file

    - name: Framework tracking metadata
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

    - name: Ensure target webserver configuration exists
      file:
        path: "{{ cfg.vhost | dirname }}"
        state: directory
        owner: root
        group: root
        mode: '0755'
      when: cfg.vhost != 'null' and cfg.vhost != ''

    - name: Deploy Webserver Host Routing
      copy:
        src: "{{ tmp_bundle_dir }}/vhost.conf"
        dest: "{{ cfg.vhost }}"
        remote_src: yes
      register: web_vhost_copied
      when: cfg.vhost != 'null' and cfg.vhost != ''

    - name: Establish Webserver Symbolic Links
      file:
        src: "{{ cfg.vhost }}"
        dest: "{{ cfg.vhost_link }}"
        state: link
      when:
        - web_vhost_copied is succeeded and web_vhost_copied.changed
        - cfg.vhost_link != 'null' and cfg.vhost_link != ''

	- name: Configure local network lookup routing in /etc/hosts
      when:
        - cfg.hosts_entry is defined
        - cfg.hosts_entry != 'null'
        - cfg.hosts_entry != ''
      lineinfile:
        path: /etc/hosts
        regexp: "^.*\\s{{ domain | regexp_escape }}$"
        line: "{{ cfg.hosts_entry }}"
        state: present
        backup: yes
        owner: root
        group: root
        mode: '0644'

    - name: Reload Web Server
      service:
        name: "{{ cfg.webserver_service }}"
        state: reloaded
      when: web_vhost_copied is succeeded and web_vhost_copied.changed

    - name: Restart Application
      service:
        name: "{{ item }}"
        state: restarted
      loop:
        - "{{ cfg.php.service | default(omit) }}"
        - "{{ cfg.redis.service | default(omit) }}"
        - "{{ cfg.systemd_service.name | default(omit) }}"
      when: item != "" and item != omit

    - name: Clean up
      file:
        path: "{{ item }}"
        state: absent
      with_items:
        - "{{ tmp_bundle_dir }}"
        - "{{ remote_archive_path }}"
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

    - name: Push Controller IP Environment to fleet peers
      copy:
        src: "{{ fleet_root }}/controller.env"
        dest: "{{ fleet_root }}/controller.env"
        mode: "0644"
      when: inventory_hostname != 'localhost' and inventory_hostname != active_controller

    - name: Push Inventory to fleet members
      copy:
        src: "{{ fleet_root }}/inventory.yml"
        dest: "{{ fleet_root }}/inventory.yml"
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
  local server_type="${4:-}"
  local private_ip="${5:-}"
  build_vars
  . "$fleet_root/controller.env"
  local virt_dir="/etc/one-click/virtualization"
  local FLEET_AVAILABLE_IPS_FILE="${virt_dir}/available_ips.txt"
  local FLEET_USED_IPS_FILE="${virt_dir}/used_ips.txt"
  local hypervisor_wg_file="/etc/one-click/fleet/hypervisor_assigned_wg_ips.json"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    warn "Only the controller can add and remove peers."
	return 1
  fi
  [[ -z "$ip" || -z "$host" ]] && {
    error "Usage: fleet add <ip> <hostname> [port]"
    return 1
  }
  info "Configuring trust to this device. Please accept the prompt"
  one-click engine "accept all from $ip" -y
  fleet_init
  cat > "$fleet_root/state/$host.conf" <<EOF
HOSTNAME=$host
IP=$ip
NAT_IP=$private_ip
PORT=$port
EOF
  bash /etc/one-click/write_inventory.sh
  info "Added $host"
  cat <<EOF
This tool will allow the micro management and overview of your remote fleet and fleet owned VMs.
You can run mass updates of the One-Click tool with a single click ${yellow}:)${reset}.
You can also run OCB benchmark on your fleet and poll the results for a single view.

One-Click Binary will also be installed if it is not already enabled. This may take some time...

Please copy + paste the following guide on $host and run to set up the cross-fleet trust:

${magenta}======================================================================================
$(tput setaf 113)  ___  _   _ _____       ____ _     ___ ____ _  __
 / _ \| \ | | ____|     / ___| |   |_ _/ ___| |/ /
| | | |  \| |  _| _____| |   | |    | | |   | ' / 
| |_| | |\  | |__|_____| |___| |___ | | |___| . \ 
 \___/|_| \_|_____|     \____|_____|___\____|_|\_\

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
  generate_node_credentials "$host"
  info "Waiting for $host remote host configuration." \
    "The engine is waiting for you to apply the snippet above to [${yellow}$host ($ip)]${reset}." \
    "Press ${yellow}Ctrl+C${reset} at any time to cancel this setup block safely." \
    "Checking connectivity status"
  if [[ "$server_type" == "hypervisor" ]]; then
    connect_ip="$private_ip"
  else
    connect_ip="$ip"
  fi
  if [ -n "${port:-}" ]; then
    porto=(-p "$port")
  else
    porto=()
  fi
  set +e
  while true; do
    ssh \
        -n \
        -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
        -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
        -o ConnectTimeout=1 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
		${porto[@]} \
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
	  -e "controller_name=$(hostname -s)" </dev/null 2>/dev/null | sed -E "
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
  if [[ "$server_type" == "init" || "$server_type" == "hypervisor" ]]; then
    info "Initialization path. Progressing with setup."
	# ==== Configure WG on new peer ====
    local target_host_ip=$(ansible-inventory -i /etc/one-click/fleet/inventory.yml --host $host | jq -r '.ansible_host')
    #fleet_wg_add $target_host_ip $host
    warn "Fleet Hypervisor Member. Preparing node."
	# == Hypervisor Path ===
    local hv_node_name="${host}"
    if [[ -z "$hv_node_name" ]]; then
      error "Hypervisor target identifier is undefined."
      return 1
    fi
    info "Allocating Private Node IP from pool for hypervisor: $hv_node_name"
    hv_private_ip=$(head -n 1 "$FLEET_AVAILABLE_IPS_FILE")
    if [[ -z "$hv_private_ip" ]]; then
      error "IP Pool Exhausted! Unable to register hypervisor network mesh tunnel."
      return 1
    fi
    info "Generating Wireguard Cryptographic Keys locally on Controller for $hv_node_name."
    local hv_private_key hv_public_key hv_preshared_key master_pub_key
    hv_private_key=$(wg genkey)
    hv_public_key=$(echo "$hv_private_key" | wg pubkey)
    hv_preshared_key=$(wg genpsk)
    master_pub_key=$(cat /etc/wireguard/public.key)
    info "Registering Tunnel Endpoint locally in Controller configuration files."
    cat >> /etc/wireguard/one-click.conf <<EOF

# ==== Hypervisor Cluster Node: $hv_node_name ====
[Peer]
PublicKey = ${hv_public_key}
PresharedKey = ${hv_preshared_key}
AllowedIPs = ${hv_private_ip}/32
PersistentKeepalive = 25
EOF
    local hv_resolved_public_ip
    hv_resolved_public_ip="${ip}"
    export WG_HIDE_KEYS=never
    echo "$hv_preshared_key" | wg set one-click peer "$hv_public_key" preshared-key /dev/stdin allowed-ips "${hv_private_ip}/32" endpoint "${hv_resolved_public_ip}:51821"
    sed -i "1d" "$FLEET_AVAILABLE_IPS_FILE"
    echo "$hv_private_ip" >> "$FLEET_USED_IPS_FILE"
    local hv_wg_stage="/tmp/wg_build_${hv_node_name}.conf"
    info "Rendering WireGuard interface credentials into staging layout."
    cat > "$hv_wg_stage" <<EOF
[Interface]
Address = ${hv_private_ip}/16
MTU = 1412
SaveConfig = true
#DNS = 10.10.0.1,8.8.8.8
PrivateKey = ${hv_private_key}
ListenPort = 51821

[Peer]
PublicKey = ${master_pub_key}
PresharedKey = ${hv_preshared_key}
AllowedIPs = 10.10.0.0/16
Endpoint = ${CONTROLLER_IP}:51821
PersistentKeepalive = 25
EOF
    chmod 600 "$hv_wg_stage"
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
  elif [[  "$server_type" == "vps" ]]; then
    info "VPS path deployment."
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        sed -Ei '/^dns =/I{s/8\.8\.8\.8/10.10.0.1/}' /etc/wireguard/one-click.conf
		wg-quick down one-click && wg-quick up one-click
	" &> /dev/null
  else
    sed -Ei '/^dns =/I{s/8\.8\.8\.8/10.10.0.1/}' /etc/wireguard/one-click.conf
	wg-quick down one-click && wg-quick up one-click
  fi
  bash /etc/one-click/write_inventory.sh
  if [[ $? -eq 0 ]]; then
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
  info "Synchronizing DNS zone registries (${#bind_domains[@]} domains) $sync_fleet..."
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
      info "Registering Primary zone '$domain' inside named.conf.local..."
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
  #fleet_dns_cluster
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
  printf "${green}[localhost ${magenta}1/${blue}4${green}]${reset} %s\n" "Generating fresh staging full-mesh keypair..."
  rm -f "$stage_key" "${stage_key}.pub"
  ssh-keygen -t ed25519 -N "" -f "$stage_key" | sed -Eun '/The key fingerprint is:/{:a;n;p;ba}'
  local old_pub new_pub new_priv
  old_pub=$(cat "${current_key}.pub")
  new_pub=$(cat "${stage_key}.pub")
  new_priv=$(cat "${stage_key}")
  printf "${green}[localhost ${magenta}2/${blue}4${green}]${reset} %s\n" "Authorizing new key across remote fleet cluster..."
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
  printf "${green}[localhost ${magenta}3/${blue}4${green}]${reset} %s\n" "Promoting staging keys to primary on controller..."
  cp "$current_key" "$backup_key"
  cp "${current_key}.pub" "${backup_key}.pub"
  mv "$stage_key" "$current_key"
  mv "${stage_key}.pub" "${current_key}.pub"
  chmod 600 "$current_key"
  chmod 644 "${current_key}.pub"
  printf "${green}[localhost ${magenta}4/${blue}4${green}]${reset} %s\n" "Safely purging old stale cluster keys from remote nodes..."
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
  if [[ ! -f "$fleet_root/state/$host.conf" ]]; then
    echo "$host already removed"
    return
  fi
  rm -f "$fleet_root/state/$host.conf"
  bash /etc/one-click/write_inventory.sh
  info "Removed $host locally"
  info "Synchronizing fleet state. Purging $host from fleet trust mesh."
  (ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook \
    "$fleet_root/playbooks/cluster_mesh.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    -b \
    -e "controller_name=$(hostname -s)" >/dev/null 2>&1 | sed -E "
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
      s/${host}|localhost/${yellow}&/
    ") &
  bash /etc/one-click/write_inventory.sh
  if [[ -d "/etc/bind/zones" ]]; then
    info "Purging removed peer from DNS cluster authority mappings..."
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
  fi
  success "Successfully isolated and removed $host from the fleet network."
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
  local_host=$(hostname -s)
  build_vars
  if [[ -f "$fleet_root/controller.env" ]]; then
    . "$fleet_root/controller.env"
    if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
      error "'fleet bench' can only be executed from the central Fleet Controller $CONTROLLER_IP."
      return 1
    fi
  fi
  info "Checking fleet for active benchmark jobs..."
  local private_key="/etc/one-click/fleet/keys/id_ed25519"
  [[ ! -f "$private_key" ]] && private_key="/home/oneclick/.ssh/id_ed25519"
  local tmp_check_dir="/tmp/fleet_bench_check_${local_host}"
  rm -rf "$tmp_check_dir" && mkdir -p "$tmp_check_dir"
  shopt -s nullglob
  local target_configs=("$fleet_root"/state/*.conf)
  shopt -u nullglob
  for file in "${target_configs[@]}"; do
    [[ ! -f "$file" ]] && continue
    (
      eval "$(sed 's/=[[:space:]]*/=/g' "$file")"
      local host="$HOSTNAME"
      local peer_ip="$IP"
      if [[ -z "$peer_ip" || "$peer_ip" == "null" ]]; then
        exit 0
      fi
      if ssh -n \
        -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
        -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes -o ConnectTimeout=1 \
        -o ConnectionAttempts=1 -o UserKnownHostsFile=/dev/null "oneclick@${peer_ip}" \
        "if ! command -v one-click; then
		   curl -fsSL https://raw.githubusercontent.com/SiteHUB-NG/One-Click/main/one-click.sh -o /tmp/one-click.sh && \\
             bash /tmp/one-click.sh setup && \\
             rm -f /tmp/one-click.sh
         fi
		 if [[ -f /etc/one-click/ocb/benchmarks/job.state ]]; then
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
             sudo dpkg --configure -a --force-confdef --force-confold
             sudo apt-get update -y
             sudo apt-get install -f -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\"
			 sudo apt-get install -f -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" iperf3 fio
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
             sudo \$pkg_mgr clean all
             if command -v dnf &> /dev/null; then
               sudo dnf history redo last -y &> /dev/null || true
             fi
             sudo \$pkg_mgr makecache
             sudo \$pkg_mgr check-update -y || [ \$? -eq 100 ]
			 sudo \$pkg_mgr install -y --setopt=install_weak_deps=False iperf3 fio
           fi
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
  for host_conf in "${target_configs[@]}"; do
    [[ ! -f "$host_conf" ]] && continue
    (
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
    [[ "$ip" == "$CONTROLLER_IP" ]] && continue
    if [[ " $active_hosts " == *" $name "* ]]; then
      echo -e "${red}[$(tput setaf 216)[$name]${red}]:${reset} Benchmark already running on ${red}${name}${reset}. Skipping..."
      continue
    fi
    if ! ping -c1 $ip &> /dev/null; then
      echo "${red}[$name]:${reset} $name is unresponsive. Skipping..."
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
          if ! command -v apt &> /dev/null; then
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
        sudo nohup /bin/bash -lc \"TERM=xterm-256color /usr/local/bin/one-click fl\"  > /dev/null 2>&1 &
        sudo cp \"/etc/one-click/ocb/benchmarks/latest.json\" \"/etc/one-click/fleet/benchmarks/localhost.json\" &> /dev/null & || true
        rm -f /home/oneclick/one-click /home/oneclick/*.sh
    " < /dev/null &> /dev/null || true
    success "$name ($ip) is now running One-Click Bench!"
  done
  fleet_local_bench
}
fleet_local_bench() {
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
  echo "RUNNING" > /etc/one-click/ocb/benchmarks/job.state
  nohup /bin/bash -lc "TERM=xterm-256color one-click fl" < /dev/null &> /dev/null &
  success "Controller (${sys_ip:-${sys_ipv6:-}}) is now running One-Click Bench!"
  cp "/etc/one-click/ocb/benchmarks/latest.json" "/etc/one-click/fleet/benchmarks/localhost.json" &> /dev/null || true
  success "${green}All benchmark jobs dispatched successfully!${reset}"
  info "Run ${orange}'one-click fleet status'${reset} to check on progress or find logs in '$fleet_root/benchmarks/'"
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
  info "Transferring '$src' to '$host:$dest'..."
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
  info "Fetching '$host:$src' to '$dest'..."
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
  info "Listing '$host:$dir'..."
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
  local cmds="$2"
  [[ -z "$host" || -z "$cmds" ]] && {
    error "Usage: fleet raw <hostname> '<commands>'"
    return 1
  }
  fleet_init
  info "Executing raw command on '$host'."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$host" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
	--become \
    -m shell \
    -a "/bin/bash -lc '$cmds'"
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
    error "Absolute source of truth file 'meta.conf' for $domain could not be resolved."
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
  host_line=$(parse_key "$HOSTS_ENTRY")
  local vhost_link=$(parse_key "VHOST_LINK")
  [[ -z "$site_dir" || ! -d "$site_dir" ]] && { error "Resolved SITE_DIR '$site_dir' does not exist."; return 1; }
  local bundle_root="/tmp/fleet-site-$domain"
  rm -rf "$bundle_root" && mkdir -p "$bundle_root"
  info "Packing site source directory files..."
  cp -a "$site_dir" "$bundle_root/site_data"
  [[ -f "$vhost" ]] && cp "$vhost" "$bundle_root/vhost.conf"
  local php_enabled=$(parse_key "PHP_SYSTEMD_ENABLED")
  local php_pool=$(parse_key "PHP_POOL_CONF")
  local php_fpm=$(parse_key "PHP_FPM_CONF")
  local php_ini=$(parse_key "PHP_INI_FILE")
  local php_vhost=$(parse_key "PHP_SYSTEMD_VHOST")
  local php_service=$(parse_key "PHP_SYSTEMD_SERVICE_NAME")
  if [[ "$php_enabled" == "true" || -n "$php_pool" ]]; then
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
  cat <<EOF > "$bundle_root/manifest.json"
{
  "domain": "$domain",
  "site_user": "${site_user:-www-data}",
  "site_group": "${site_group:-www-data}",
  "site_dir": "$site_dir",
  "webserver_service": "${webserver_service:-$webserver}",
  "vhost": "$vhost",
  "vhost_link": "$vhost_link",
  "hosts_entry": "${hosts_line:-null}",
  "php": {
    "enabled": $php_enabled,
    "service": "$php_service",
    "pool": "$php_pool",
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
  info "Uploading packaged configurations and services to $host..."
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
    if [[ $(jq -r '.nginx.enabled' "$registry_json") == "true" ]]; then
      vhost_path=$(jq -r '.nginx.vhost // empty' "$registry_json")
      vhost_link=$(jq -r '.nginx.vhost_link // empty' "$registry_json")
      webserver_service=$(jq -r '.nginx.service_name // "nginx"' "$registry_json")
    elif [[ $(jq -r '.apache.enabled' "$registry_json") == "true" ]]; then
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
  info "Beginning remote deployment tasks on $host..."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook "$fleet_root/playbooks/site_import.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    -b \
    --extra-vars "{
      'target_host': '$host',
      'domain': '$domain',
      'remote_archive_path': '$remote_archive',
      'target_site_root': '$target_site_root',
      'target_vhost_path': '$vhost_path',
      'target_vhost_link': '$vhost_link',
      'webserver_service_name': '$webserver_service',
      'db_enabled': $db_enabled,
      'db_name': '$db_name',
      'db_user': '$db_user',
      'site_user': '$site_user',
      'site_group': '$site_group'
    }" | sed -E "
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
  local target_domain="$1"
  local source_peer="$2"
  [[ -z "$target_domain" ]] && {
    error "Usage: fleet site-import <domain> [source_peer_or_local_file_path]"
    return 1
  }
  if [[ -f "$target_domain" ]]; then
    local absolute_archive=$(realpath "$target_domain")
    local domain=$(basename "$absolute_archive" .tar.gz)
    info "Initiating standalone local archive restore pipeline for $domain..."
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible-playbook "$fleet_root/playbooks/site_import.yml" \
      -i "localhost," \
      -c local \
      -b \
      --extra-vars "{
        'target_host': 'localhost',
        'domain': '$domain',
        'remote_archive_path': '$absolute_archive',
        'db_enabled': true
      }" 2> /dev/null | sed -E "
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
      s/${source_peer}/${yellow}&/
    "
    return $?
  fi
  [[ -z "$source_peer" ]] && {
    error "Error: You must provide either a valid local tarball file path or a remote peer name (e.g., work1)"
    return 1
  }
  info "Initiating cross-peer migration pull sequence. Fetching $target_domain from peer: $source_peer..."
  ANSIBLE_HOST_KEY_CHECKING=False \ 
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible-playbook "$fleet_root/playbooks/site_pull_import.yml" \
    -i "$fleet_root/inventory.yml" \
    -u oneclick \
    --extra-vars "{
      'source_peer': '$source_peer',
      'domain': '$target_domain'
    }" | sed -E "
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
		s/^(skipping.*)\n(.*)/$(tput setaf 45)\1 ->${magenta} \2${reset}/
		s/skipped=[1-9]+/$(tput setaf 45)&${reset}/g
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
  info "Compressing raw directory: $src_dir..."
  tar -czf "$archive" -C "$(dirname "$src_dir")" "$dir_name"
  info "Shipping archive to peer node: $dest_peer..."
  fleet_put "$dest_peer" "$archive" "$remote_archive"
  info "Extracting payload onto $dest_peer into destination: $dest_dir..."
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
    warn "Fleet VPS module has not been initialized" \
	  "This module will allocate 70% of your available storage to LVM on single drive systems." \
	  "If there is a secondary drive, 100% of the storage will be partitioned"
	read -rp "Are you sure you want to initialize VPS functionality (y|N)? " vps_init
	vps_init="${vps_init,,}"
	if [[ "$vps_init" != "yes" && "$vps_init" != "y" ]]; then
	  error "VPS initialization cancelled"
	  exit 0
	fi
    touch /etc/one-click/virtualization/.initialized
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
    info "Generating internal cluster mesh IP block tracking pools (10,000 addresses)."
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
    echo "$master_pub" > /etc/wireguard/public.key
    echo "$master_priv" > /etc/wireguard/private.key
    local controller_outbound_nic
    controller_outbound_nic=$(awk 'NR==1{print $5}' <(ip route show default | grep -v "virbr"))
    [[ -z "$controller_outbound_nic" ]] && controller_outbound_nic="eth0"
    cat > "$master_wg_config" <<EOF
[Interface]
Address = 10.10.0.1/16
MTU = 1412
SaveConfig = false
ListenPort = ${target_wg_port}
PrivateKey = ${master_priv}

PostUp = sysctl -w net.ipv4.conf.all.forwarding=1
PostUp = sysctl -w net.ipv4.conf.default.forwarding=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1
PostUp = sysctl -w net.ipv6.conf.default.forwarding=1

PreDown = true
# ==== Layer-3 Forwarding Pipelines ====
#PostUp = iptables -A FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
#PostUp = iptables -A FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
PostUp = iptables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE

#PreDown = iptables -D FORWARD -i one-click -o ${controller_outbound_nic} -j ACCEPT
#PreDown = iptables -D FORWARD -i ${controller_outbound_nic} -o one-click -m state --state RELATED,ESTABLISHED -j ACCEPT
PreDown = iptables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
PreDown = ip6tables -t nat -D POSTROUTING -o ${controller_outbound_nic} -j MASQUERADE
PreDown = ip6tables -t nat -I POSTROUTING -s fd00:99aa::/64 -o ${controller_outbound_nic} -j MASQUERADE

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
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible ${target_host:-all} \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a "
      echo '>>> Initializing virtualization target tracking paths...'
      mkdir -p /etc/one-click/virtualization/images
	  touch /etc/one-click/virtualization/.initialized
      mkdir -p /var/lib/libvirt/images
      chmod 755 /etc/one-click/virtualization/images
      echo '>>> Syncing required system repository packages framework...'
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
          nft add chain ip nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
		  nft add chain ipv6 nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
          if ! nft list chain ip nat POSTROUTING | grep -q \"ip saddr $private_subnet ip daddr != $private_subnet masquerade\"; then
            nft add rule ip nat POSTROUTING ip saddr \"$private_subnet\" ip daddr != \"$private_subnet\" masquerade 2>/dev/null
			nft add rule ipv6 nat POSTROUTING ip saddr \"$ipv6_private_subnet\" ip daddr != \"$ipv6_private_subnet\" masquerade 2>/dev/null
          fi
        fi
      fi
      echo '>>> Verifying KVM internal NAT network infrastructure switches...'
      if ! virsh net-info oneclick-nat &>/dev/null; then
        echo '>>> Compiling and defining missing default NAT network XML infrastructure...'
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
      if [ \"\$(virsh net-info oneclick-nat 2>/dev/null | grep -E '^Active:' | awk '{print \$2}')\" != \"yes\" ]; then
        echo '>>> Activating default NAT hypervisor bridge (ocbr0)...'
        virsh net-start oneclick-nat &>/dev/null
      fi
      virsh net-autostart oneclick-nat &>/dev/null
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
            echo \">>> Netplan active: Writing configuration matrix definitions for br0...\"
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
      echo '>>> Enabling and initializing background hypervisor libvirtd engines...'
      sysctl -w net.ipv4.ip_forward=1 &>/dev/null
      if [ -d \"/etc/sysctl.d\" ]; then
        echo \"net.ipv4.ip_forward=1\" > /etc/sysctl.d/99-oneclick-virtualization.conf
      else
        echo \"net.ipv4.ip_forward=1\" >> /etc/sysctl.conf
      fi
      systemctl enable --now libvirtd 2>/dev/null
      modprobe kvm
      modprobe kvm_intel 2>/dev/null || modprobe kvm_amd 2>/dev/null
      echo '>>> Virtualization system environment configured.'
    executable=/bin/bash" 2> /dev/null | sed -E '
    /changed=/d;
    /SUCCESS/d;
    s/^([a-zA-Z0-9.-]+)[[:space:]]*\|[[:space:]]*CHANGED[[:space:]]*\|.*rc=0[[:space:]]*>>/[\1]/g;
    s/>>>[[:space:]]*/  -> /g;
  '
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
storage_script="/etc/one-click/virtualization/initialize_storage.sh"
storage_dir="$2"
mount_target="/var/lib/libvirt/images"
loop_file="$storage_dir/fleet_storage.img"
disk_size="$1"
vg_name="one_click_vg"
thin_pool="one_click_pool"
repo_lv="one_click_shared_lv"
mkdir -p "$(dirname "$storage_script")"
if ! command -v pvcreate &>/dev/null || ! command -v vgcreate &>/dev/null; then
  info "Installing LVM infrastructure dependencies on host node."
  if command -v apt-get &> /dev/null; then
    apt-get update -y
  fi
  install_dep "lvm2" "type lvm2" "lvm2" "$pkg_mgr"
fi
mkdir -p "$storage_dir"
if ! vgdisplay "$vg_name" &>/dev/null; then
  warn "Volume Group '$vg_name' not detected. Initiating safe allocation engine."
  target_drive=""
  drive_count=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme" | wc -l)
  primary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme" | head -n 1 | awk '{print $1}')
  if [ "$drive_count" -gt 1 ]; then
    secondary_drive=$(lsblk -dn -o NAME,TYPE | grep -E "disk|nvme" | sed -n '2p' | awk '{print $1}')
    target_drive="/dev/${secondary_drive}"
    info "Secondary storage asset detected at $target_drive. Routing allocations."   
    if mount | grep -q "$target_drive"; then
      mount_point=$(mount | grep "$target_drive" | awk '{print $3}' | head -n 1)
      loop_file="${mount_point}/fleet_storage.img"
    fi
  else
    target_drive="/dev/${primary_drive}"
    info "Single storage drive array active ($target_drive). Calculating allocation boundaries."
  fi
  target_dir_path=$(dirname "$loop_file")
  free_kb=$(df -k "$target_dir_path" | awk 'NR==2 {print $4}')
  alloc_mb=$(( (free_kb * 70) / 100 / 1024 ))
  if [ "$alloc_mb" -lt "$ALLOC_THRESHOLD" ]; then
    error "Less than 5GB of computed free space available. Aborting LVM provisioning."
    return 1
  fi
  if [ ! -f "$loop_file" ]; then
    info "Carving out ${alloc_mb}MB loop allocation table safely on host filesystem."
    if ! fallocate -l "${alloc_mb}M" "$loop_file"; then
      error "Storage Fault: Failed to pre-allocate container space via fallocate."
      return 1
    fi
  fi
  target_loop=$(losetup -j "$loop_file" | awk -F: '{print $1}' | head -n 1)
  if [ -z "$target_loop" ]; then
    target_loop=$(losetup -f)
    if ! losetup "$target_loop" "$loop_file"; then
      error "Storage Fault: Failed to attach mapping matrix to loop controller $target_loop"
      rm -f "$loop_file"
      return 1
    fi
  else
    info "File already cleanly mapped to existing controller path: $target_loop"
  fi
  info "Initializing raw LVM hardware translation maps on $target_loop."
  pvscan --cache "$target_loop" 2>/dev/null || true
  if ! vgdisplay "$vg_name" &>/dev/null; then
    pvcreate "$target_loop" -y &>/dev/null
    if vgcreate "$vg_name" "$target_loop" -y &>/dev/null; then
      success "Volume Group '$vg_name' successfully spawned and mounted at block layer."
      info "Creating Thin Pool."
      lvcreate -L "$disk_size" --thinpool "$thin_pool" "$vg_name" -y &>/dev/null
    else
      error "Unable to initialize cluster bindings."
      losetup -d "$target_loop" 2>/dev/null
      return 1
    fi
  fi
else
  info "Volume Group '$vg_name' baseline infrastructure already active and running."
fi
if ! lvdisplay "${vg_name}/${repo_lv}" &>/dev/null; then
  info "Allocating master shared virtual storage partition layout."
  base_raw=$(echo "$disk_size" | tr -dc '0-9')
  overprovision=$(( base_raw * 110 / 100 ))
  lvcreate -V ${overprovision}G --thin -n "$repo_lv" "${vg_name}/${thin_pool}" -y &>/dev/null
  info "Formatting storage filesystem overlay with high-performance ext4."
  mkfs.ext4 -F "/dev/${vg_name}/${repo_lv}" &>/dev/null
  success "Shared Thin Volume Storage layer successfully initialized."
else
  info "Shared Master Volume space configuration online."
fi
if ! mountpoint -q "$mount_target"; then
  info "Mounting shared storage repository matrix directly onto $mount_target."
  vgchange -ay "$vg_name" &>/dev/null
  mount "/dev/${vg_name}/${repo_lv}" "$mount_target"
  if ! grep -q "$repo_lv" /etc/fstab; then
    echo "/dev/${vg_name}/${repo_lv} ${mount_target} ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  if [ -f /etc/rc.local ] && ! grep -q "$loop_file" /etc/rc.local; then
    sed -i -e '$i \losetup -f '"$loop_file"' \&\& vgchange -ay '"$vg_name"' \&\& mount -a\n' /etc/rc.local
  elif [ ! -f /etc/rc.local ]; then
    echo -e "#!/bin/sh -e\nlosetup -f ${loop_file} && vgchange -ay ${vg_name} && mount -a\nexit 0" > /etc/rc.local
    chmod +x /etc/rc.local
  fi
  success "Native block storage environment is initialized and online!"
else
  info "Master shared filesystem volume cleanly mounted and accepting file allocation targets."
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
    warn "Volume Group '$vg_name' not detected. Initiating 95% Host Allocation Engine."
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
      info "Allocating ${alloc_mb}MB massive storage pool loop-file."
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
        info "Spawning underlying thin pool at 95% VG capacity..."
        lvcreate -l 95%VG --thinpool "$thin_pool" "$vg_name" -y &>/dev/null
      else
        error "Unable to initialize LVM volume group mappings."
        return 1
      fi
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
  info "Registering runtime boundaries and starting VM on $dest_host..."
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${dest_ip}" "sudo bash -c '
    virsh define /tmp/${target_vm}.xml
    virsh autostart $target_vm
	virsh start $target_vm
    rm -f /tmp/${target_vm}.xml
  '" &>/dev/null
  info "Updating dynamic network routing ledger in virtualization inventory..."
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
      return 1
  fi
  printf "$(tput setaf 48)[POWER]${reset} %s\n" \
    "Power directive '$action' successfully completed for $target_vm."
}
# ==== Fleet HAProxy Edge ====
fleet_proxy_provision() {
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
  cluster_ip=$(jq -r ".[] | select(.name == \"$target_vm\") | .cluster_private_ip" "$inventory_json" 2>/dev/null | tail -1)
  if [[ -z "$target_host" || "$target_host" == "null" || -z "$vps_internal_ip" || "$vps_internal_ip" == "null" ]]; then
    error "Target VM '$target_vm' does not exist in active registry mapping."
    return 1
  fi
  local haproxy_payload=""
  if [[ -n "$website" ]]; then
    # ==== Shared web ports ====
    info "Compiling HTTP/HTTPS reverse proxy block for $website -> $target_vm ($vps_internal_ip)..."
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
    info "Compiling TCP proxy map for custom port: Host:$dest_port -> $target_vm:$src_port."
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
  target_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$target_host" 2>/dev/null | jq -r '.ansible_host // empty')
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
fleet_vps_provision() {
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller (${sys_ip:-${sys_ipv6}})"
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
  local LOCK_FILE="/tmp/vps_ip_allocation.lock"
  local target_wg_port
  local storage_script="/etc/one-click/virtualization/initialize_storage.sh"
  local inventory_file="/etc/one-click/virtualization/inventory.json"
  warn "VPS Deployment initializing."
  local name_exists
  name_exists=$(jq --arg name "$vps_name" 'any(.[] ; .name == $name)' "$inventory_file" 2>/dev/null || true)
  cleanup_poisoned_session() {
    local exit_code=$?
	local inventory_file=/etc/one-click/fleet/inventory.yml
	local inventory_json="/etc/one-click/virtualization/inventory.json"
    if [[ "$exit_code" -ne 0 ]]; then
      local exists_in_yaml=false
      if [[ -f "$inventory_file" ]] && [[ -n "$vps_name" ]]; then
        if grep -E -q "^[[:space:]]*${vps_name}:" "$inventory_file"; then
          exists_in_yaml=true
        fi
      fi
      warn "Deployment interrupted or timed out. Purging corrupted hypervisor states."
	  if [[ -f "$inventory_file" ]] && [[ -n "$vps_name" ]]; then
        sed -i "/^[[:space:]]*${vps_name}:/,+2d" "$inventory_file"
      fi
	  if [[ -n "${vps_private_ip:-}" ]]; then
        warn "Rolling back IP $vps_private_ip to available pool."
        #exec 9>"/tmp/vps_ip_allocation.lock"
        #flock -x 9
		sed -Ei "1a\ ${vps_private_ip:-}" /etc/one-click/virtualization/available_ips.txt
        echo "$vps_private_ip" >> "/etc/one-click/virtualization/available_ips.txt"
        #flock -u 9
        #exec 9>&-
      fi
	  if [[ "$exists_in_yaml" = false ]]; then
	    jq --arg name "$vps_name" 'del(.[] | select(.name == $name))' "$inventory_json" > "$inventory_json.tmp" && mv "$inventory_json.tmp" "$inventory_json"
	  fi
      if [[ "$target_host" == "$(hostname -s)" || "$target_host" == "127.0.0.1" ]]; then
        virsh destroy "$vps_name" 2>/dev/null || true
        virsh undefine "$vps_name" --remove-all-storage 2>/dev/null || true
        rm -f "/var/lib/libvirt/images/${vps_name}_cloudinit.iso" 2>/dev/null || true
      else
        ANSIBLE_HOST_KEY_CHECKING=False \
		  ANSIBLE_SSH_TIMEOUT=3 \
          ANSIBLE_GATHERING=explicit \
		  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
		  ansible "$target_host" \
          -i /etc/one-click/fleet/inventory.yml \
          -u oneclick --become \
          -m shell -a "
            virsh destroy \"$vps_name\" 2>/dev/null || true
            virsh undefine \"$vps_name\" --remove-all-storage 2>/dev/null || true
            rm -f /var/lib/libvirt/images/${vps_name}_cloudinit.iso 2>/dev/null || true
			rm -f /var/lib/libvirt/images/${vps_name}.qcow2 2>/dev/null || true
          " &>/dev/null || true
          one-click fleet rm "$vps_name"
      fi
      error "Cleanup complete. Hypervisor state sanitized."
	  exit 1
    fi
  }
  trap cleanup_poisoned_session EXIT INT TERM
  if ! wg > /dev/null; then
    $pkg_mgr install -y wireguard-tools
  fi
  if [[ "$name_exists" == "true" ]]; then
    error "An instance named '$vps_name' already exists in the fleet."
    local conflicting_host
    conflicting_host=$(jq -r ".[] | select(.name == \"$vps_name\") | .host" "$inventory_file" 2>/dev/null)
    echo "Active Location: Currently assigned to hypervisor node [$conflicting_host]"
    return 1
  fi
  if [[ ! -f /etc/one-click/virtualization/wg_ports.db ]]; then
    echo "51821" > /etc/one-click/virtualization/wg_ports.db
  fi
  rm -f "$storage_script"
  target_wg_port=$(( $(tail -n1 /etc/one-click/virtualization/wg_ports.db) + 1 ))
  echo "$target_wg_port" >> /etc/one-click/virtualization/wg_ports.db
  . "/etc/one-click/fleet/controller.env"
  if [[ -f /etc/one-click/dns/modules/wireguard_pool.env ]]; then
    . "/etc/one-click/dns/modules/wireguard_pool.env"
  else
    fleet_vps_init
  fi
  if [[ -z "$vps_name" || -z "$target_host" || -z "$base_image_name" || -z "$disk_size" ]]; then
    error "Usage: fleet_vps_provision <vps_name> <target_host> <nat|public> <base_image> <disk_size>"
    return 1
  fi
  local master_image_source="/etc/one-click/virtualization/images/${base_image_name}"
  if [[ ! -f "$master_image_source" ]]; then
    error "Base image tracking failure: $base_image_name not found in master storage."
    return 1
  fi
  local vps_private_ip
  #exec 9>"$LOCK_FILE"
  #flock -x 9
  vps_private_ip=$(head -n 1 "$FLEET_AVAILABLE_IPS_FILE" | tr -d ' ')
  if [[ -z "$vps_private_ip" ]]; then
    error "IP Pool Exhausted! No available IPs remaining for fleet compute allocation."
	flock -u 9
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
  info "Allocating Private Node IP: $vps_private_ip to $vps_name"
  local vps_private_key vps_public_key vps_preshared_key master_pub_key
  vps_private_key=$(wg genkey)
  vps_public_key=$(echo "$vps_private_key" | wg pubkey)
  vps_preshared_key=$(wg genpsk)
  master_pub_key=$(cat /etc/wireguard/public.key)
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
      info "Executing emergency link override to save the deployment..."
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
      echo "$vps_preshared_key" | wg set one-click peer "$vps_public_key" preshared-key /dev/stdin allowed-ips "${vps_private_ip}/32" endpoint "${host_public_ip}:${target_wg_port}"
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
  info "Creating Peer Wireguard Configuration"
  cat > "$vps_wg_file" <<EOF
[Interface]
Address = ${vps_private_ip}/16
MTU = 1412
SaveConfig = true
#DNS = 10.10.0.1,8.8.8.8,8.8.4.4
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
  local host_ssh_key=""
  [[ -f "/etc/one-click/fleet/keys/id_ed25519.pub" ]] && host_ssh_key=$(cat /etc/one-click/fleet/keys/id_ed25519.pub)
  if [[ "$mode" == "hypervisor" ]]; then
    target_ssh_key=$(cat /etc/one-click/fleet/keys/id_ed25519.pub)
  else
    target_ssh_key=$(ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "cat /home/oneclick/.ssh/id_ed25519.pub" 2>/dev/null | sed -n '/ssh/p')
  fi
  # ==== cloud-config ====
  local os_family=""
  if [[ "${base_image_name,,}" =~ (alma|rhel|centos|fedora|el)([0-9]+) ]]; then
    os_family="el"
    #os_version="${os_family}${BASH_REMATCH[2]}"
    os_version="ubuntu24.04"
  elif [[ "${base_image_name,,}" =~ (rocky)([0-9]+) ]]; then
    os_family="rocky"
    os_version="${os_family}${BASH_REMATCH[2]}"
  elif [[ "${base_image_name,,}" =~ (debian|deb)([0-9]+) ]]; then
    os_family="debian"
    os_version="${os_family}${BASH_REMATCH[2]}"
  elif [[ "${base_image_name,,}" =~ (ubuntu)([0-9]+) ]]; then
    if [[ "${BASH_REMATCH[2]}" == 26 ]]; then
      os_model="26.04"
    elif [[ "${BASH_REMATCH[2]}" == 24 ]]; then
      os_model="24.04"
    elif [[ "${BASH_REMATCH[2]}" == 22 ]]; then
      os_model="22.04"
    elif [[ "${BASH_REMATCH[2]}" == 20 ]]; then
      os_model="20.04"
    fi
    os_family="ubuntu"
    os_version="${os_family}${os_model}"
  fi
  case "$os_family" in
    el)
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
      ListenPort = 51821
      PrivateKey = ${vps_private_key}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      AllowedIPs = 10.10.0.0/16
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
      ListenPort = 51821
      PrivateKey = ${vps_private_key}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      AllowedIPs = 10.10.0.0/16
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
      ListenPort = 51821
      PrivateKey = ${vps_private_key}
      #DNS = 10.10.0.1,8.8.8.8

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      AllowedIPs = 10.10.0.0/16
      Endpoint = ${CONTROLLER_IP}:51821
      PersistentKeepalive = 25

runcmd:
  - sysctl --system

final_message: "OneClick provisioning completed."

EOF
      ;;
    ubuntu|*)
      cat > "$user_data_file" <<EOF
#cloud-config

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
      ListenPort = 51821
      PrivateKey = ${vps_private_key}
      #DNS = 10.10.0.1,8.8.8.8

      #PostUp = ip rule add table 200 from ${vps_private_ip}
      #PreDown = ip rule del table 200 from ${vps_private_ip}

      [Peer]
      PublicKey = ${master_pub_key}
      PresharedKey = ${vps_preshared_key}
      AllowedIPs = 10.10.0.0/16
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
  esac
  cp "$user_data_file" "$archive_user_data"
  info "Configuring peer VPS networking"
  local net_flag="network network=oneclick-nat"
  local cloud_init_net_argument="--cloud-init user-data=$user_data_file"
  if [[ "$network_mode" == "public" ]]; then
    if [[ -z "$public_ip" ]]; then
      error "Public networking mode requested, but no manual --ip assignment address was passed."
      return 1
    fi
    net_flag="network bridge=br0"
    local host_gateway
    host_gateway=$(ip route show default | awk '{print $3}')
    cat > "$network_config_file" <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
      - ${public_ip}/24
    routes:
      - to: default
        via: ${host_gateway}
    nameservers:
      addresses: [1.1.1.1, 8.8.8.8]
EOF
    cp "$network_config_file" "$archive_net_config"
    cloud_init_net_argument="--cloud-init user-data=$user_data_file,network-config=$network_config_file"
  fi
  local disk_path="/var/lib/libvirt/images/${vps_name}.qcow2"
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    fleet_vps_init
	mkdir -p "$stage_dir"
    local meta_data_file="${stage_dir}/meta-data"
	iso_path="/var/lib/libvirt/images/${vps_name}_cloudinit.iso"
	work_dir="/tmp/build_${vps_name}"
    mkdir -p "$work_dir"
	echo "instance-id: ${vps_name}" > "$meta_data_file"
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
	if ! command -v iptables > /dev/null; then
	  if command -v apt > /dev/null; then
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
    qemu-img resize "$disk_path" "${disk_size}" &>/dev/null
	if ! ip rule show | grep -q '192.168.250.0/24 table 200'; then
      ip route add table 200 192.168.250.0/24 dev ocbr0 proto kernel scope link 2>/dev/null || true
	  ip -6 route add table 200 fd00:99aa::/64 dev ocbr0 proto kernel scope link 2>/dev/null || true
	  if [[ -n ${v4_init:-} ]]; then
	    iptables -I FORWARD -i ocbr0 -o ${v4_int} -j ACCEPT
	  fi
	  if [[ -n "${v6_init:-}" ]]; then
  	    ip6tables -I FORWARD -i ocbr0 -o ${v6_int} -j ACCEPT
	  fi
      #iptables -I FORWARD -i ${v4_int:-${v6_int}} -o ocbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2> /dev/null || iptables -I FORWARD -i br0 -o ocbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
      if ! iptables -t nat -C POSTROUTING -s "$private_subnet" ! -d "$private_subnet" -j MASQUERADE 2>/dev/null; then
        if ! iptables -t nat -I POSTROUTING -s "$private_subnet" ! -d "$private_subnet" -j MASQUERADE 2>/dev/null; then
          nft add table ip nat 2>/dev/null || true
          nft add chain ip nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
		  nft add chain ipv6 nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
          if ! nft list chain ip nat POSTROUTING | grep -q "ip saddr $private_subnet ip daddr != $private_subnet masquerade"; then
            nft add rule ip nat POSTROUTING ip saddr "$private_subnet" ip daddr != "$private_subnet" masquerade 2>/dev/null
			nft add rule ipv6 nat POSTROUTING ipv6 saddr "$ipv6_private_subnet" ipv6 daddr != "$ipv6_private_subnet" masquerade 2>/dev/null
          fi
        fi
      fi
      ip rule add from 192.168.250.0/24 table 200 2>/dev/null || true
	  ip -6 rule add from fd00:99aa::/64 table 200 2>/dev/null || true
    fi
    virsh destroy "$vps_name" 2>/dev/null || true
    virsh undefine "$vps_name" 2>/dev/null || true
	install_dep "genisoimage" "command -v genisoimage" "genisoimage" "$pkg_mgr" true
	cp "$meta_data_file" "$work_dir/meta-data"
    cp "$user_data_file" "$work_dir/user-data"
    rm -f "$iso_path"
    genisoimage -output "$iso_path" -volid CIDATA -joliet -rock "$work_dir/user-data" "$work_dir/meta-data" &>/dev/null
    sync
    sleep 1
    if [ ! -s "$iso_path" ]; then
      error '=== ISO GENERATION CRASH: File not written or empty ===' >&2
      return 1
    fi
    VIRT_TYPE_FLAG="--virt-type kvm"
    if virt-install --help 2>&1 | grep -q -- '--type'; then
      if ! virt-install --help 2>&1 | grep -q -- '--virt-type'; then
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
    virt-install \
      --name "$vps_name" \
      --memory $vps_ram \
      --vcpus $vps_cpu \
      --disk path="$disk_path",format=qcow2,bus=virtio,boot.order=1 \
      --disk path="$iso_path",device=cdrom,format=raw,boot.order=2 \
      --network network=oneclick-nat,model=virtio \
      $VIRT_TYPE_FLAG \
      --osinfo generic \
      --import \
      --graphics none \
      --console pty,target_type=serial \
      --boot hd,cdrom \
      --noautoconsole &> /dev/null
	rm -f /tmp/${vps_name}_user_data.yml /tmp/${vps_name}_meta_data.yml
  else
    info "Preparing ${target_host}'s LVM script."
	local remote_target_script="/etc/one-click/virtualization/initialize_storage.sh"
    local meta_data_file="${stage_dir}/meta-data"
	write_peer_vps_vg_allocation
	info "Pushing VG creation script to [$target_host]..."
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_INTERPRETER_DISCOVERY=ignore \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$storage_script dest=$remote_target_script mode=0755" 2> /dev/null | sed -En "{
	    s/([^|]*) \| ([^|]*) .*/${orange}[\2] Controller => \1 ${magenta}LVM preparation on $vps_name currently processing.${reset}/p
      }
	"
	info "preparing LVM partitioning on [$target_host]." 
    ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_INTERPRETER_DISCOVERY=ignore \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
	    bash $remote_target_script $disk_size $IMG_STORAGE_PATH
	  " 2> /dev/null | sed -En "{
	    s/([^|]*) \| ([^|]*) .*/${orange}[\2] Controller => \1 ${magenta}Cooking LV play./
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
      -m copy -a "src=$user_data_file dest=/tmp/${vps_name}_user_data.yml" 2> /dev/null | sed -En "/Changed/I {
		s,(.*),${orange}[CHANGED]${yellow} Controller => $target_host ${magenta} Copied $user_data_file to /tmp/${vps_name}_user_data.yml${reset},p;
	  };
	  /SUCCESS/I {
		s,(.*),${green}[OK]${yellow} Controller => $target_host ${magenta}Copied $user_data_file to /tmp/${vps_name}_user_data.yml${reset},p;
	  };
	  /Error/I {
	    s/Error[ \t]+(.*)/${red}[ERROR]${yellow} Controller => $target_host ${magenta} \1${reset}/p;
	  }"
	ANSIBLE_HOST_KEY_CHECKING=False \
	ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$meta_data_file dest=/tmp/${vps_name}_meta_data.yml" 2> /dev/null | sed -En "/Changed/I {
		s,(.*),${orange}[CHANGED]${yellow} Controller => $target_host ${magenta}Copied $meta_data_file to /tmp/${vps_name}_meta_data.yml${reset},p;
	  };
	  /SUCCESS/I {
		s,(.*),${green}[OK]${yellow} Controller => $target_host ${magenta}Copied $meta_data_file to /tmp/${vps_name}_meta_data.yml${reset},p;
	  };
	  /Error/I {
	    s/Error[ \t]+(.*)/${red}[ERROR]${yellow} Controller => $target_host ${magenta} \1${reset}/p;
	  }"
    if [[ "$network_mode" == "public" ]]; then
      info "Syncing static Netplan network configuration matrix metadata..."
      ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
		ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m copy -a "src=$network_config_file dest=/tmp/${vps_name}_network_config.yml" 2> /dev/null | sed -En "/Changed/I {
		s,(.*),${orange}[CHANGED]${yellow} Controller => $target_host ${magenta}Copied $network_config_file to /tmp/${vps_name}_network_config.yml${reset},p;
	  };
	  /SUCCESS/I {
		s,(.*),${green}[OK]${yellow} Controller => $target_host ${magenta}Copied $network_config_file to /tmp/${vps_name}_network_config.yml${reset},p;
	  };
	  /Error/I {
	    s/Error[ \t]+(.*)/${red}[ERROR]${yellow} Controller => $target_host ${magenta} \1${reset}/p;
	  }"
    fi
    info "Streaming OS image to $target_host..."
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m copy -a "src=$master_image_source dest=$disk_path" 2> /dev/null | sed -En "/Changed/I {
		s,(.*),${orange}[CHANGED]${yellow} Controller => $target_host ${magenta}Copied $master_image_source to $disk_path ${reset},p;
	  };
	  /SUCCESS/I {
		s,(.*),${green}[OK]${yellow} Controller => $target_host ${magenta}Copied $master_image_source to $disk_path ${reset},p;
	  };
	  /Error/I {
	    s/Error[ \t]+(.*)/${red}[ERROR]${yellow} Controller => $target_host ${magenta} \1${reset}/p;
	  }"
    info "Deploying server with cloud-init on $target_host hypervisor"
	local private_subnet="192.168.250.0/24"
	local ipv6_private_subnet=fd00:99aa::/64
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        qemu-img resize \"$disk_path\" \"${disk_size}\" 2>/dev/null
        if ! ip rule show | grep -q '192.168.250.0/24 table 200'; then
          ip route add table 200 192.168.250.0/24 dev ocbr0 proto kernel scope link 2>/dev/null || true
		  ip -6 route add table 200 fd00:99aa::/64 dev ocbr0 proto kernel scope link 2>/dev/null || true
		  iptables -I FORWARD -i ocbr0 -o $(ip route show default | awk '/default/ {print $5; exit}') -j ACCEPT 2>/dev/null || true
		  ip6tables -I FORWARD -i ocbr0 -o $(ip -6 route show default | awk '/default/ {print $5; exit}') -j ACCEPT 2>/dev/null || true
          #iptables -I FORWARD -i $(ip route show default | awk '/default/ {print $5; exit}') -o ocbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT
          if ! iptables -t nat -C POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
            if ! iptables -t nat -I POSTROUTING -s \"$private_subnet\" ! -d \"$private_subnet\" -j MASQUERADE 2>/dev/null; then
              nft add table ip nat 2>/dev/null || true
			  nft add table ipv6 nat 2>/dev/null || true
              nft add chain ip nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
			  nft add chain ipv6 nat POSTROUTING { type nat hook postrouting priority srcnat \; policy accept \; } 2>/dev/null
              if ! nft list chain ip nat POSTROUTING | grep -q \"ip saddr $private_subnet ip daddr != $private_subnet masquerade\"; then
                nft add rule ip nat POSTROUTING ip saddr \"$private_subnet\" ip daddr != \"$private_subnet\" masquerade 2>/dev/null
				nft add rule ipv6 nat POSTROUTING ip saddr \"$ipv6_private_subnet\" ip daddr != \"$ipv6_private_subnet\" masquerade 2>/dev/null
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
            sudo apt-get update && sudo apt-get install -y genisoimage &>/dev/null
          elif command -v dnf &>/dev/null; then
            sudo dnf install -y cdrkit-genisoimage &>/dev/null
          fi
        fi
        cp /tmp/${vps_name}_user_data.yml \"\$work_dir/user-data\"
        cp /tmp/${vps_name}_meta_data.yml \"\$work_dir/meta-data\"
        iso_path=\"/var/lib/libvirt/images/${vps_name}_cloudinit.iso\"
        rm -f \"\$iso_path\"
        genisoimage -output \"\$iso_path\" -volid CIDATA -joliet -rock \"\$work_dir/user-data\" \"\$work_dir/meta-data\" &>/dev/null
        sync
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
        virt-install \
          --name \"$vps_name\" \
          --memory $vps_ram \
          --vcpus $vps_cpu \
          --disk path=\"$disk_path\",format=qcow2,bus=virtio,boot.order=1 \
          --disk path=\"\$iso_path\",device=cdrom,format=raw,boot.order=2 \
          --network network=oneclick-nat,model=virtio \
          \$VIRT_TYPE_FLAG \
          --osinfo detect=on,require=off \
          --import \
          --graphics none \
          --console pty,target_type=serial \
          --boot hd,cdrom \
          --noautoconsole
        rm -rf \"\$work_dir\"
        rm -f /tmp/${vps_name}_user_data.yml /tmp/${vps_name}_meta_data.yml
      " #2> /dev/null | sed -En "/Changed/ {
#		s,(.*),${orange}[CHANGED]${yellow} localhost => $target_host ${magenta}Created KVM on $target_host hypervisor...${reset},p;
#	  };
#	  /SUCCESS/ {
#		s,(.*),${green}[OK]${yellow} localhost => $target_host ${magenta}Created KVM on $target_host hypervisor...${reset},p;
#	  };
#	  /Error/ {
#	    s/Error[ \t]+(.*)/${red}[ERROR]${yellow} localhost => $target_host ${magenta} \1${reset}/p;
#	  }"
  fi
  if [[ "$?" -eq 0 ]]; then
    success "VPS successfully deployed." 
    info "Aquiring IP."
  else
    error "Deployement failed!"
	return 1
  fi
  sed -i "1d" "$FLEET_AVAILABLE_IPS_FILE"
  #flock -u 9
  #exec 9>&-
  echo "$vps_private_ip" >> "$FLEET_USED_IPS_FILE"
  rm -rf "$stage_dir"
  local ledger_file="/etc/one-click/virtualization/inventory.json"
  [[ ! -f "$ledger_file" ]] && echo "[]" > "$ledger_file"
  local mode_ip="$vps_private_ip"
  [[ "$network_mode" == "public" ]] && mode_ip="$public_ip"
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    local_vps_ip=$(while true; do
      if virsh list --state-running --name | grep -q "^$vps_name$"; then break; fi
      sleep 2
    done
    mac=$(virsh domiflist "$vps_name" | awk '/oneclick-nat/{print $5}')
    vps_ip=""
    while [ -z "$vps_ip" ]; do
      vps_ip=$(virsh net-dhcp-leases oneclick-nat | awk -v m="$mac" '$3==m {print $5}' | cut -d'/' -f1 | head -n 1)
      [ -n "$vps_ip" ] && break
      sleep 1
    done
    echo "$vps_ip" | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
  else
    remote_vps_ip=$(ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
        ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "
		target_mac=\$(virsh domiflist \"$vps_name\" | awk '/oneclick-nat/{print \$5}' | grep -E -o \"([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\" | head -n 1)
		virsh net-dhcp-leases oneclick-nat | awk -v m=\"\$target_mac\" '\$3==m {print \$5}' | cut -d'/' -f1 2>/dev/null \
        | grep -E -o \"([0-9]{1,3}\.){3}[0-9]{1,3}\" | head -n 1
	  " 2> /dev/null
	)
  fi
  local updated_json
  updated_json=$(jq ". += [{
    \"name\": \"$vps_name\",
    \"host\": \"$target_host\",
    \"mode\": \"$network_mode\",
    \"primary_ip\": \"$mode_ip\",
    \"password\": \"$raw_password\",
    \"cluster_private_ip\": \"${vps_private_ip:-N/A}\",
    \"nat_ip\": \"${local_vps_ip:-N/A}\",
    \"ram\": \"${vps_ram}MB\",
    \"cpu\": \"$vps_cpu\",
    \"disk\": \"$disk_size\",
    \"image\": \"$base_image_name\",
    \"created_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
  }]" "$ledger_file")
  echo "$updated_json" > "$ledger_file"
  if [ -z "${remote_vps_ip:-${local_vps_ip:-}}" ]; then
    error "Failed to capture allocation state for $vps_name"
    exit 1
  fi
  while true; do
    local vm_state=$(ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "virsh list --state-running --name" 2>/dev/null)
    if echo "$vm_state" | grep -q "^$vps_name$"; then
      success "Hypervisor state active: QEMU container has successfully locked hardware."
      break
    fi
    echo "    -> Synchronizing disk allocation buffers."
    sleep 3
  done
  info "Polling hypervisor DHCP table for dynamic MAC allocation."
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    local target_mac=$(virsh domiflist "$vps_name" | awk '/oneclick-nat/{print $5}' \
	  | grep -E -o "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | head -n 1)
  else
    local target_mac=$(ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
      ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "virsh domiflist '$vps_name' | awk '/oneclick-nat/{print \$5}'" 2>/dev/null \
      | grep -E -o "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | head -n 1)
  fi
  if [ -z "$target_mac" ]; then
    error "Unable to resolve interface MAC link layer."
    exit 1
  fi
  remote_vps_ip=""
  local_vps_ip=""
  local loop_counter=0
  set +e
  while [ $loop_counter -lt 45 ]; do
    if [[ "$target_host" == "$(hostname -s)" ]]; then
      local_vps_ip=$(virsh net-dhcp-leases oneclick-nat | awk -v m="$target_mac" '$3==m {print $5}' | cut -d'/' -f1 | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
	else
      printf "\r$(tput setaf 49)[POLL]${reset} Querying network lease table (Attempt $((loop_counter + 1))/45).$(tput el)"
      remote_vps_ip=$(ANSIBLE_HOST_KEY_CHECKING=False \
	    ANSIBLE_SSH_TIMEOUT=3 \
        ANSIBLE_GATHERING=explicit \
        ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
        ansible "$target_host" \
        -i /etc/one-click/fleet/inventory.yml \
        -u oneclick --become \
        -m shell -a "virsh net-dhcp-leases oneclick-nat | awk -v m='$target_mac' '\$3==m {print \$5}' | cut -d'/' -f1" 2>/dev/null \
        | grep -E -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n 1)
	fi	
    if [ -n "${remote_vps_ip:-${local_vps_ip}}" ]; then
      break
    fi
    loop_counter=$((loop_counter + 1))
    sleep 2
  done
  echo
  set -e
  if [ -z "${remote_vps_ip:-${local_vps_ip}}" ]; then
    error "Target failed to broadcast a DHCP lease request in time."
    exit 1
  fi
  success "Captured Target DHCP Allocated Address: [${remote_vps_ip:-${local_vps_ip}}]"
  sleep 2
  info "Finalizing the build of $vps_name (${remote_vps_ip:-${local_vps_ip:-$vps_private_ip}})"
  set +e
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    info "Initiating local hypervisor deployment for ${vps_name}."
	virsh shutdown $vps_name &> /dev/null
	sleep 15
    virsh autostart "$vps_name" &> /dev/null || true
	virsh start "$vps_name" &> /dev/null || true
    sleep 15
    ssh_ready=0
    counter=0
    local_reset_check="/tmp/reset-check-${vps_name}"
    target_vps_ip="${local_vps_ip:-${vps_private_ip:-${remote_vps_ip:-}}}"
    if [[ -z "$target_vps_ip" ]]; then
      error "Failed to resolve valid target IP address mapping properties for ${vps_name}"
      return 1
    fi
    while [ $counter -lt 30 ]; do
      if ssh -i /etc/one-click/fleet/keys/id_ed25519 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=2 \
        -o PasswordAuthentication=no \
         oneclick@"${remote_vps_ip:-${local_vps_ip:-$vps_private_ip}}" "echo HEALTH_CHECK_OK" &> /dev/null; then
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
      oneclick@"${remote_vps_ip:-${local_vps_ip:-$vps_private_ip}}" << EOC
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
		echo '$(cat "$fleet_root/keys/id_ed25519.pub")' >> /home/oneclick/.ssh/authorized_keys
        sudo systemctl enable --now qemu-guest-agent 2>/dev/null || true
        sudo systemctl enable --now wg-quick@one-click 2>/dev/null || true
EOC
    success "Local guest kvm node ${vps_name} deployed successfully!"
  else
    ANSIBLE_HOST_KEY_CHECKING=False \
      ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
      ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
	    sudo virsh shutdown $vps_name &> /dev/null
	    sudo virsh autostart $vps_name &> /dev/null
        sudo virsh start $vps_name &> /dev/null
	    sleep 20
        ssh_ready=0
        counter=0
        while [ \$counter -lt 30 ]; do
          if ssh -i /home/oneclick/.ssh/id_ed25519 \\
            -o StrictHostKeyChecking=no \\
            -o UserKnownHostsFile=/dev/null \\
            -o ConnectTimeout=2 \\
            -o PasswordAuthentication=no \\
             oneclick@${remote_vps_ip:-${local_vps_ip:-$vps_private_ip}} \"echo HEALTH_CHECK_OK\" &> /dev/null; then
              ssh_ready=1
              break
          else
            if [[ ! -f reset-check ]]; then
              touch reset-check
			  echo \"Health Check \$counter\"
			  if [[ \"\$counter\" =~ ^[2468]\$ || \"\$counter\" =~ ^[0-9][24680] ]]; then
                virsh reset $vps_name
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
          oneclick@${remote_vps_ip:-${local_vps_ip:-$vps_private_ip}} << 'EOC'
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
            echo '$(cat "$fleet_root/keys/id_ed25519.pub")' >> /home/oneclick/.ssh/authorized_keys
EOC
      " 2> /dev/null
  fi
  set -e
  success "$vps_name built on $target_host successfully."
  sleep 5
  info "Adding $vps_name to fleet"
  fleet_add "${vps_private_ip:-${public_ip}}" "$vps_name" 22 "${mode}" "${remote_vps_ip:-${local_vps_ip}}"
  for current_domain in "${domains_to_provision[@]}"; do
    dns_bind_create_zone "$current_domain"
  done
  info "Ensuring One-Click Binaries"
  fl_ssh "${vps_private_ip:-${public_ip}}"
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
    echo -e "$(tput setaf 197)[VPS] ${cyan}Public Static IP:${reset}  $public_ip"
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
}
fleet_vps_reinstall() {
  local vps_name="$1"
  local target_image="$2" 
  local raw_password="$3"
  local win_language="${4:-}"
  local target_vps_ip="${5:-}"
  local inventory="/etc/one-click/fleet/inventory.yml"
  local clean_os=""
  local os_version_raw=""
  local is_windows=0
  local parsed_string="${target_image,,}"
  local keys=$(sed -En '/ssh_authorized_keys:/{:a;n;/ssh-/{s/[ \t]+- //p};ba}' /etc/one-click/virtualization/deployments/near-golding109/user_data.yml)
  local archive_dir="/etc/one-click/virtualization/deployments/${vps_name}"
  parsed_string="${parsed_string#netboot_}"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  if [[ "${sys_ip:-${sys_ipv6}}" != "$CONTROLLER_IP" ]]; then
    die "Can only be managed by the controller (${sys_ip:-${sys_ipv6}})"
  fi
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
  declare -A valid_os_map=(
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
  if [[ -z "${valid_os_map[$clean_os]+_}" ]]; then
    error "Requested OS flavor '$clean_os' falls outside native platform support bounds."
    return 1
  fi
  local os_version=""
  if [[ -n "$os_version_raw" && -n "${valid_os_map[$clean_os]}" ]]; then
    if grep -qw "$os_version_raw" <<< "${valid_os_map[$clean_os]}"; then
      os_version="$os_version_raw"
    else
      os_version=$(echo "${valid_os_map[$clean_os]}" | tr ' ' '\n' | grep "^${os_version_raw}" | sort -V | tail -n 1)
      if [[ -z "$os_version" ]]; then
        os_version=$(echo "${valid_os_map[$clean_os]}" | tr ' ' '\n' | sort -V | tail -n 1)
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
        iso_url="https://software-download.microsoft.com/download/pr/9600.16384.WINBLUE_RTM.130821-1623_X64FRE_SERVER_EVAL_EN-US-IRM_SSS_X64FREE_EN-US_DV5.ISO" 
        ;;
      2016) 
        iso_name="Windows Server 2016 SERVERSTANDARD"
        iso_url="https://software-download.microsoft.com/download/pr/14393.0.160715-1616.X64FRE_SERVER_EVAL_EN-US_AMD64_.ISO" 
        ;;
      2019) 
        iso_name="Windows Server 2019 SERVERSTANDARD"
        iso_url="https://software-download.microsoft.com/download/pr/17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" 
        ;;
      2022) 
        iso_name="Windows Server 2022 SERVERSTANDARD"
        iso_url="https://software-download.microsoft.com/download/pr/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" 
        ;;
      2025) 
        iso_name="Windows Server 2025 SERVERSTANDARD"
        iso_url="https://software-download.microsoft.com/download/pr/26100.1742.240906-2144.ge_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso" 
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
  local install_cmd=""
  if [[ "$clean_os" == "netboot.xyz" || -z "$os_version" ]]; then
    install_cmd="sudo bash reinstall.sh ${clean_os}"
  elif [[ "$is_windows" -eq 1 ]]; then
    install_cmd="sudo bash reinstall.sh windows --image-name \"${iso_name}\" --iso \"${iso_url}\" --password \"${raw_password}\" --lang \"${WIN_LANG}\" --rdp-port 3389"
  else
	install_cmd="sudo bash reinstall.sh ${clean_os} ${os_version} --ssh-key \"${keys}\""
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
  if [[ "$pass" =~ ^10\.10 ]]; then
    local mode=vps
  else
    local mode=hypervisor
  fi
  info "Triggering unattended target re-image sequence on ${vps_name} [${pass}]..."
  local ssh_success=1
  for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
    [[ -f "$key" ]] || continue
    ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "oneclick@$pass" << EOF
	  set -e
      (curl -O -s https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -qO- https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh > reinstall.sh ) \
	    || { echo "Download failed"; exit 1; }
      chmod +x reinstall.sh || { echo "chmod failed"; exit 1; }
      ${install_cmd} \
        | sed -Eu '/(Password: .)....(.).*/s//\1xxxx\2x/' \
        | sed -Eu "N;s,\nUsername:,\n                         _ _      _    \n  ___  _ __   ___    ___\| \(_\) ___\| \| __\n / _ \\\| '_ \\\ / _ \\\  / __\| \| \|/ __\| \|/ /\n\| \(_\) \| \| \| \|  __/ \| \(__\| \| \| \(__\|   < \n \\\___/\|_\| \|_\|\\\___\|  \\\___\|_\|_\|\\\___\|_\|\\\_\\\&,"
        
      sleep 3 && sudo reboot || true
EOF
      if [[ $? -eq 0 ]]; then
	    ssh_success=0
        break
	  fi
  done
  if [[ "$ssh_success" -eq 0 ]]; then
    success "Fleet peer ${vps_name} has successfully written its target boot image entries."
    info "The instance is performing a hard restart to process its new configurations."
  else
    error "Reinstall script pipeline failed. Validation barriers refused payload."
    return 1
  fi
  info "Reconfiguring $vps_name to add back to the fleet"
  fleet_vps_peer_reconfigure "$vps_name" "$mode" "$os_version" "$raw_password"
}
# ==== Reconfigure Fleet Member ====
fleet_vps_peer_reconfigure() {
  local vps_name="$1" 
  local mode="${2:-vps}"
  local new_image_name="$3"
  local fresh_install_pass="$4"
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
  info "Harvesting operational metrics and WireGuard configurations..."
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
		sudo virsh autostart $vps_name &> /dev/null
        sudo virsh start $vps_name &>/dev/null
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
  fleet_add "$fleet_target_ip" "$vps_name" 22 "${mode,,}"
  info "Synchronizing target configuration definitions in database ledger..."
  local updated_json
  updated_json=$(jq "map(if .name == \"$vps_name\" then . + {
    \"image\": \"$new_image_name\",
    \"password\": \"$fresh_install_pass\",
    \"updated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
  } else . end)" "$ledger_file")
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
  for key in /home/oneclick/.ssh/id_ed25519 /etc/one-click/fleet/keys/id_ed25519; do
    [[ -e "$key" ]] || continue
    ssh -i "$key" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 "$ssh_target"
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  done
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
    ssh -t -i "$key" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 "$ssh_target" "
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
	"
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  done
  error "Trust mesh execution failure: Connection timed out or credentials rejected by $target on port $port."
  return 1
}
fleet_console() {
  local target="$1"
  local port="${2:-}"
  build_vars
  . "/etc/one-click/fleet/controller.env"
  local inventory="/etc/one-click/fleet/inventory.yml"
  local json_inv="/etc/one-click/virtualization/inventory.json"
  local parent_host=$(jq -r --arg vm "$target" '.[] | select(.name == $vm) | .host' "$json_inv")
  local facts=$(ansible-inventory -i "$inventory" --list)
  local hypervisor=$(echo "$facts" | jq -r --arg host "$parent_host" '._meta.hostvars[$host].ansible_host // empty')
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
  info "Prepaing Console permissions on hypervisor host: ($parent_host - $hypervisor)"
  active=$(ssh -i /etc/one-click/fleet/keys/id_ed25519 -o StrictHostKeyChecking=no oneclick@${hypervisor} "if [[ \"\$(id)\" =~ libvirt ]]; then echo yes; fi")
  if [[ "$active" != "yes" ]]; then
    ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_SSH_TIMEOUT=5 ansible-playbook -i /etc/one-click/fleet/inventory.yml /etc/one-click/fleet/playbooks/vps_console.yml -e "target=$parent_host" \
	  2> /dev/null | sed -En "/task/I {
	    N;
		s/.*\[([^]]*).*\n(.*)/$(tput setaf 244)\2 ${blue}=> ${magento}\1${reset}/p
	  };
	"
  fi
  if ! command -v virsh > /dev/null; then
    if command -v apt > /dev/null; then
      apt -y update | sed -En "s/.*/$(tput setaf 196)[VIRSH] $(tput setaf 277)=> ${magenta} Virsh unavailable. Installing...${reset}/p"
	  apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virsh &> /dev/null
    else
      dnf groupinstall -y "Virtualization Host" &> /dev/vull
      dnf install -y libvirt-client | sed -En "s/.*/$(tput setaf 196)[VIRSH] $(tput setaf 277)=> ${magenta} Virsh unavailable. Installing.../p"
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
  . "/etc/one-click/dns/modules/wireguard_pool.env"
  if [[ -z "$vps_name" ]]; then
    error "Usage: one-click vps delete -n <vps_name> [-t <target_host>]"
    return 1
  fi
  local ledger_file="/etc/one-click/virtualization/inventory.json"
  if [[ -z "$target_host" ]]; then
    if [[ ! -f "$ledger_file" ]]; then
      error "Inventory ledger file not found at $ledger_file. Cannot auto-detect target host."
      return 1
    fi
    local matching_hosts=()
    mapfile -t matching_hosts < <(jq -r ".[] | select(.name == \"$vps_name\") | .host" "$ledger_file")
    if [[ ${#matching_hosts[@]} -eq 0 ]]; then
      error "No records found for a VPS named '$vps_name' inside the inventory ledger."
      return 1
    elif [[ ${#matching_hosts[@]} -eq 1 ]]; then
      target_host="${matching_hosts[0]}"
      info "Auto-detected instance location: '$vps_name' resides on hypervisor [$target_host]"
    else
      error "Duplicate instances detected! A VPS named '$vps_name' is deployed on multiple hosts:"
      for host in "${matching_hosts[@]}"; do
        echo "  - $host"
      done
      info "Please resolve this conflict by passing the explicit target host using the -t/--target flag."
      return 1
    fi
  fi
  info "Extracting execution records and purging hypervisor instance from [$target_host]..."
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    virsh destroy "$vps_name" &>/dev/null || true
    virsh undefine "$vps_name" --remove-all-storage &>/dev/null || true
  else
    ANSIBLE_HOST_KEY_CHECKING=False \
	  ANSIBLE_SSH_TIMEOUT=3 \
      ANSIBLE_GATHERING=explicit \
	  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	  ansible "$target_host" \
      -i /etc/one-click/fleet/inventory.yml \
      -u oneclick --become \
      -m shell -a "
        virsh destroy \"$vps_name\" &>/dev/null || true
        virsh undefine \"$vps_name\" --remove-all-storage &>/dev/null || true
        rm -f /tmp/${vps_name}_user_data.yml
      " 2> /dev/null
  fi
  local vps_ip
  vps_ip=$(grep -B 2 -A 2 "$vps_name" /etc/wireguard/one-click.conf 2>/dev/null | grep "AllowedIPs" | awk '{print $3}' | cut -d/ -f1)
  if [[ -n "$vps_ip" ]]; then
    local peer_key
    peer_key=$(wg show one-click peers | grep -B 1 "$vps_ip" | head -n 1)
    if [[ -n "$peer_key" ]]; then
      wg set one-click peer "$peer_key" remove
    fi
    #sed -i "/# Peer Node Allocation: ${vps_name}/,+4d" /etc/wireguard/one-click.conf
    sed -i "/^${vps_ip}$/d" "$FLEET_USED_IPS_FILE"
    echo "$vps_ip" >> "$FLEET_AVAILABLE_IPS_FILE"
    success "Private IP address resource $vps_ip recovered back into the system master pool."
  fi
  if [[ -f "$ledger_file" ]]; then
    local cleaned_json
    cleaned_json=$(jq "del(.[] | select(.name == \"$vps_name\" and .host == \"$target_host\"))" "$ledger_file")
    echo "$cleaned_json" > "$ledger_file"
  fi
  success "VPS instance $vps_name successfully destroyed and erased from the deployment footprint."
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
  if curl -L -o "$destination_path" "$image_url"; then
    chmod 644 "$destination_path"
    success "Image '$file_name' successfully fetched and registered into local master storage."
  else
    error "Failed to download cloud image from the remote provider."
    rm -f "$destination_path"
    return 1
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
  info "Initiating target configuration adjustments for instance: $vps_name..."
  local libvirt_cmds=""
  if [[ "$target_host" == "$(hostname -s)" ]]; then
    info "Executing local configuration updates..."
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
    info "Preparing system maintenance for fleet member: [$ansible_target]..."
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
    error "Please run ${orange}one-click fleet init${reset} first"
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
    info "Appending peer configuration block to local interface infrastructure..."
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
ListenPort = 51821
MTU = 1412

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
  info "Provisioning WireGuard interface configuration on remote node ($allocated_ip)..."
  if ssh -i "$key_file" "oneclick@$member_target" \
    WG_INTERFACE_CFG="/etc/wireguard/one-click.conf" \
    ALLOCATED_IP="$allocated_ip" \
    CONTROLLER_IP="$CONTROLLER_IP" \
    CONTROLLER_PUBKEY="$controller_pubkey" \
	REMOTE_PRIVATE_KEY="$remote_privkey" 'bash -s' << 'EOF'
      
      wg_content=$(cat <<_CONTENT_
[Interface]
PrivateKey = ${REMOTE_PRIVATE_KEY}
Address = ${ALLOCATED_IP}/16
ListenPort = 51821
MTU = 1412
#DNS = 10.10.0.1

[Peer]
PublicKey = ${CONTROLLER_PUBKEY}
Endpoint = ${CONTROLLER_IP}:51821
AllowedIPs = 10.10.0.0/16
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
    warn "No user allocations found inside the carved /24 space."
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
    info "Live-purging cryptographic credentials from running network interface..."
    wg set wg0 peer "$user_pubkey" remove 2>/dev/null || true
  fi
  if [[ -f "$wg_interface_cfg" ]]; then
    info "Excising configuration block records from static filesystem..."
    sed -i "/# Peer allocation for user: ${target_user}/,/^$/{d}" "$wg_interface_cfg"
    sed -i '/^$/N;/^\n$/D' "$wg_interface_cfg"
  fi
  info "Updating allocation ledger tracking maps..."
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
    ssh \
      -n \
      -o IdentityFile=/home/oneclick/.ssh/id_ed25519 \
      -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519 \
      -o ConnectTimeout=1 \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
	  ${porto[@]} \
      "oneclick@$connect_ip" "
	  if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_FAMILY_CHECK=\"\${ID_LIKE:-$ID}\"
      else
        OS_FAMILY_CHECK=\"debian\"
      fi
      if [[ \"\$OS_FAMILY_CHECK\" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
	    echo \">>> $PRETTY_NAME / Firewalld environment detected. Applying rules.\"
        sudo firewall-cmd --permanent --zone=trusted --add-interface=ocbr0 2>/dev/null || true
        sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-nat 2>/dev/null || true
        ACTIVE_GW_ZONE=\$(sudo firewall-cmd --get-active-zones | head -n 1)
        sudo firewall-cmd --permanent --zone="\${ACTIVE_GW_ZONE:-public}" --add-masquerade 2>/dev/null || true
		sudo firewall-cmd --zone=public --add-port=51821/udp --permanent
        sudo firewall-cmd --reload &>/dev/null
      elif ! sudo iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
        echo \">>> $PRETTY_NAME / Pure nftables environment detected. Applying native hybrid oneclick_filter structure.\"
        sudo nft add table inet oneclick_filter 2>/dev/null || true
        sudo nft add chain inet oneclick_filter INPUT { type filter hook input priority 0 \; policy accept \; } 2>/dev/null
        sudo nft add chain inet oneclick_filter POSTROUTING '{ type nat hook postrouting priority 100 \; }'
        sudo nft add chain inet oneclick_filter FORWARD '{ type filter hook forward priority 0 \; policy accept \; }' 2>/dev/null || true
        sudo nft add rule inet oneclick_filter FORWARD iifname "one-click" oifname "one-click" accept 2>/dev/null || true
        sudo nft add table ip oneclick_nat_ipv4 2>/dev/null || true
        sudo nft add chain ip oneclick_nat_ipv4 POSTROUTING '{ type nat hook postrouting priority 100 \; }' 2>/dev/null || true
        sudo nft add rule ip oneclick_nat_ipv4 POSTROUTING ip saddr 192.168.250.0/24 oifname \"$nic\" masquerade
        sudo nft add table ip6 oneclick_nat_ipv6 2>/dev/null || true
        sudo nft add chain ip6 oneclick_nat_ipv6 POSTROUTING '{ type nat hook postrouting priority 100 \; }' 2>/dev/null || true
        sudo nft add rule ip6 oneclick_nat_ipv6 POSTROUTING ip6 saddr fd00:99aa::/64 oifname \"$nic\" masquerade
        sudo nft add chain inet oneclick_filter ONE-CLICK-FLEET 2>/dev/null || true
        if ! nft list chain inet oneclick_filter INPUT | grep -q 'jump ONE-CLICK-FLEET'; then
          sudo nft insert rule inet oneclick_filter INPUT index 1 jump ONE-CLICK-FLEET
        fi
        sudo nft flush chain inet oneclick_filter ONE-CLICK-FLEET
        sudo nft insert rule inet oneclick_filter ONE-CLICK-FLEET udp dport 51821 accept
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname \"ocbr0\" udp sport 68 udp dport 67 accept
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET iifname \"lo\" accept
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ct state established,related accept
        sudo nft insert rule inet oneclick_filter ONE-CLICK-FLEET udp sport 53 accept
        if [ \"$has_ipv4\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip protocol icmp accept
        fi
        if [ \"$has_ipv6\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET meta l4proto icmpv6 accept
        fi
        if [ \"$CONTROLLER_IP\" =~ : ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"$CONTROLLER_IP\" tcp dport 22 accept
        else
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"$CONTROLLER_IP\" tcp dport 22 accept
        fi
        if [ \"$has_ipv4\" = true ]; then
          sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr 10.10.0.1 tcp dport 1-65535 accept
        fi
        for target_ip in $ip_list_string; do
          if [ \"\$target_ip\" =~ : ]; then
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"\$target_ip\" accept
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip6 saddr \"\$target_ip\" tcp dport 22 accept
          else
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"\$target_ip\" accept
            sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET ip saddr \"\$target_ip\" tcp dport 22 accept
          fi
        done
        sudo nft add rule inet oneclick_filter ONE-CLICK-FLEET drop
        if command -v firewall-cmd > /dev/null; then
          if systemctl is-active firewalld > /dev/null; then
            firewall-cmd --zone=public --add-port=51821/udp --permanent
            # INTEGRATION: firewalld policy configuration to allow spoke-to-spoke forward paths
            firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i one-click -o one-click -j ACCEPT 2>/dev/null || true
            firewall-cmd --reload
          fi
        fi
      else
        echo \">>> ($PRETTY_NAME) Legacy iptables engine active. Applying dual-stack legacy ruleset.\"
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
          sudo ip6tables -t nat -A POSTROUTING -s fd00:99aa::/64 -o \"$nic\" -j MASQUERADE
          sudo iptables -t nat -A POSTROUTING -s 192.168.250.0/24 -o \"$nic\" -j MASQUERADE
          if [[ ! \"$CONTROLLER_IP\" =~ : ]]; then
            sudo iptables -A ONE-CLICK-FLEET -s \"$CONTROLLER_IP\" -p tcp --dport 22 -j ACCEPT
          fi
          sudo iptables -A ONE-CLICK-FLEET -s 10.10.0.1 -p tcp --dport 1:65535 -j ACCEPT
        fi
        if [ \"$has_ipv6\" = true ] && command -v ip6tables >/dev/null 2>&1; then
          sudo ip6tables -P FORWARD ACCEPT
          sudo ip6tables -P OUTPUT ACCEPT
          sudo ip6tables -A FORWARD -i one-click -o one-click -j ACCEPT 2>/dev/null || true
          sudo ip6tables -N ONE-CLICK-FLEET 2>/dev/null || true
          if ! ip6tables -C INPUT -j ONE-CLICK-FLEET 2>/dev/null; then
            sudo ip6tables -I INPUT 1 -j ONE-CLICK-FLEET
          fi
          sudo ip6tables -F ONE-CLICK-FLEET
          sudo ip6tables -A ONE-CLICK-FLEET -i lo -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p icmpv6 -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p udp --sport 53 -j ACCEPT
          sudo ip6tables -A ONE-CLICK-FLEET -p udp --dport 51821 -j ACCEPT
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
        if command -v firewall-cmd > /dev/null; then
          if systemctl is-active firewalld > /dev/null; then
            firewall-cmd --zone=public --add-port=51821/udp --permanent
            firewall-cmd --reload
          fi
        fi
      fi
    " 2> /dev/null | sed -En "s/>>> (.*)/${orange}changed: $(tput setaf 227)[$(hostname -s) => $host_name] ->${magenta} \1${reset}/p"
  done
  # ==== Fleet Controller Local Section ====
  info "Applying isolated base guard config to local controller."
  {
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      OS_FAMILY_CHECK="${ID_LIKE:-$ID}"
    else
      OS_FAMILY_CHECK="debian"
    fi
    if [[ "$OS_FAMILY_CHECK" =~ (rhel|centos|fedora|alma|rocky) ]] && systemctl is-active --quiet firewalld; then
	  printf "${orange}[CHANGED]${magenta} %s\n" '=> firewalld environment detected. Applying rules.'
      sudo firewall-cmd --permanent --zone=trusted --add-interface=ocbr0 2>/dev/null || true
      sudo firewall-cmd --permanent --zone=trusted --add-interface=oneclick-nat 2>/dev/null || true
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
  if [[ -z "${CONTROLLER_IP:-}" ]]; then
    error "Controller identity not available."
    info "Will check source of truth and generate/synchronise."
  fi
  info "Initializing controller identity synchronisation."
  ANSIBLE_HOST_KEY_CHECKING=False \
  ANSIBLE_INTERPRETER_DISCOVERY=ignore \
  ANSIBLE_SSH_TIMEOUT=3 \
  ANSIBLE_GATHERING=explicit \
  ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
    ansible all \
    -e "ansible_ignore_unreachable=True" \
    -i /etc/one-click/fleet/inventory.yml \
    -u oneclick --become \
    -m shell -a "
      env_file=\"/etc/one-click/fleet/controller.env\"
      controller=\$(iptables -S ONE-CLICK-FLEET 2>/dev/null | grep -B 1 '10.10.0.1' | head -n 1 | awk '{print \$4}' | cut -d/ -f1)
      if [ \"\$controller\" == \"${CONTROLLER_IP}\" && \"${CONTROLLER_IP}\" == \"${sys_ip}\" ]; then
	    success \"$(hostname -s) is the verified controller!\"
	  elif [ \"\$controller\" != \"$CONTROLLER_IP\" ]; then
        warn \"Conflicting Controller Detected! Firewall points to \$controller. Fixing identity now...\"
        mkdir -p \"/etc/one-click/fleet\"
        cat > \"/etc/one-click/fleet/identity.conf\" <<EOF
ROLE=peer
FLEET_IDENTITY=$(hostname -s)
STATUS=managed
CONTROLLER_TARGET_IP=\$controller
LAST_SYNC=\$(date +%s)
EOF
        if [ -f \"\$env_file\" ]; then
          sed -i '
		    /^CONTROLLER_IP=/d;
            /^ROLE_TYPE=/d;
            /^IS_MASTER=/d;
			/^SERVER_NAME/d
		  ' \"\$env_file\"
        fi
        echo \"CONTROLLER_IP=\$controller\" >> \"\$env_file\"
		echo \"SERVER_NAME=$(hostname -s)\" >> \"\$env_file\"
        echo \"ROLE_TYPE=peer\" >> \"\$env_file\"
        echo \"IS_MASTER=false\" >> \"\$env_file\"
        chmod 600 \"/etc/one-click/fleet/identity.conf\" \"\$env_file\"
        printf \"\$(tput setaf 111)[SYNC]:\$(tput sgr 0)\" \
		  \"Demoted rogue controller instance to clean node managed state matching firewall authority.\"
        exit 0
      else
        echo \"$(tput setaf 2)OK: Node alignment verified and pinned to the master controller [\$controller].$(tput sgr 0)\"
        exit 0
      fi
    " 2> /dev/null | sed -En "
	  /^\[/ {
	    /\|/ {
		  N;
	      s/^([^|]*) \| ([^|!]*) .*\n([^.]*).*/[[\2]\1] => \3/
		};
	  };
	  /^\[/p;
	  /UNREACHABLE|ERROR/s/.*/${red}&${reset}/p
	  /ok/I s/.*/${green}&${reset}/p
	"
  success "Global fleet mesh synchronization complete. Net-immutable authorization enforced."
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
  if [[ "$target_destination" == "$CONTROLLER_IP" || "$target_destination" == "$(hostname)" || "$target_destination" == "$(hostname -s)" ]]; then
    error "Target destination matches the current active master. Migration Aborted."
    return 1
  fi
  info "Resolving target destination networking routes..."
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
  warn "CRITICAL ACTION INITIATED: Shifting cluster control dominance to [$target_destination] ($target_ip)."
  read -p "Are you absolutely sure you want to transfer master authority? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
    info "Migration canceled by operator."
    return 0
  fi
  info "Capturing iptables security snapshots across the transfer matrix..."
  local local_fw_snap="/tmp/source_iptables.rules"
  sudo iptables-save > "$local_fw_snap"
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo iptables-save" > /tmp/dest_iptables.rules
  info "Packaging controller database matrices, state logs, and automation playbooks..."
  local migration_archive="/tmp/one-click-master-migration.tar.gz"
  rm -f "$migration_archive"
  local tar_targets=(
    "fleet/wg_user_ledger.json"
    "fleet/inventory.yml"
    "fleet/playbooks"
    "fleet/keys"
    "virtualization/inventory.json"
    "virtualization/available_ips.txt"
    "virtualization/used_ips.txt"
  )
  [[ -f "$backup_ledger" ]] && tar_targets+=("virtualization/backup_ledger.json")
  [[ -f "$snapshot_ledger" ]] && tar_targets+=("virtualization/snapshot_ledger.json")
  [[ -d "$state_dir" ]] && tar_targets+=("state")
  tar -czf "$migration_archive" -C /etc "${tar_targets[@]}" 2>/dev/null
  info "Streaming configuration payload to new master controller..."
  cat "$migration_archive" | ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "cat > /tmp/migration.tar.gz"
  info "Unpacking states and elevating [$target_destination] to active cluster master..."
  ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${target_ip}" "sudo bash -s" << EOF
    tar -xzf /tmp/migration.tar.gz -C /etc/
    rm -f /tmp/migration.tar.gz
    cat > /etc/one-click/fleet/identity.conf <<EOT
ROLE=peer
FLEET_IDENTITY=\$(hostname)
STATUS=active
CONTROLLER_TARGET_IP=127.0.0.1
LAST_SYNC=\$(date +%s)
EOT
    if [ -f /etc/one-click/fleet/controller.env ]; then
      sed -i '/^CONTROLLER_IP=/d' /etc/one-click/fleet/controller.env
      sed -i '/^IS_MASTER=/d' /etc/one-click/fleet/controller.env
      echo "CONTROLLER_IP=$target_ip" >> /etc/one-click/fleet/controller.env
      echo "IS_MASTER=true" >> /etc/one-click/fleet/controller.env
    fi
    if [ -f /etc/one-click/fleet/keys/id_ed25519.pub ]; then
      mkdir -p /home/oneclick/.ssh
      cat /etc/one-click/fleet/keys/id_ed25519.pub >> /home/oneclick/.ssh/authorized_keys
      sort -u /home/oneclick/.ssh/authorized_keys -o /home/oneclick/.ssh/authorized_keys
      chmod 600 /home/oneclick/.ssh/authorized_keys
      chown -R oneclick:oneclick /home/oneclick/.ssh
    fi
    if ! iptables -I ONE-CLICK-FLEET -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
      echo ">>> RHEL 10 Detected: Applying rule additions natively."
      nft add table ip filter 2>/dev/null || true
      nft add chain ip filter ONE-CLICK-FLEET 2>/dev/null || true
      nft insert rule ip filter ONE-CLICK-FLEET ip saddr 127.0.0.1 tcp dport 22 accept
      nft insert rule ip filter ONE-CLICK-FLEET ip saddr "$target_ip" tcp dport 22 accept
      nft insert rule ip filter ONE-CLICK-FLEET udp dport 51821 accept
    else
      echo ">>> Standard iptables environment active. Applying classic ruleset."
      iptables -N ONE-CLICK-FLEET 2>/dev/null || true
      iptables -I ONE-CLICK-FLEET -s 127.0.0.1 -p tcp --dport 22 -j ACCEPT
      iptables -I ONE-CLICK-FLEET -s "$target_ip" -p tcp --dport 22 -j ACCEPT
	  iptables -I ONE-CLICK-FLEET -p udp -m udp --dport 51821 -j ACCEPT 
    fi
EOF
  info "Transferring updated firewall rules to remaining peers."
  local fleet_hosts
  fleet_hosts=$(ansible all --list-hosts -i "$inventory_file" 2>/dev/null | grep -v "hosts (" | awk '{print $1}')
  for node in $fleet_hosts; do
    [[ "$node" == "$target_destination" ]] && continue
    local node_ip
    node_ip=$(ANSIBLE_SSH_ARGS="-C -o IdentityFile=$private_key" ansible-inventory -i "$inventory_file" --host "$node" 2>/dev/null | jq -r '.ansible_host // empty' | tr -d '[:space:]')
    [[ -z "$node_ip" ]] && continue
    ssh -i "$private_key" -o StrictHostKeyChecking=no "oneclick@${node_ip}" "sudo bash -s" << EOF
      if [ -f /etc/one-click/fleet/controller.env ]; then
        sed -i "s/^CONTROLLER_IP=.*/CONTROLLER_IP=$target_ip/" /etc/one-click/fleet/controller.env
      fi
      if [ -f /etc/one-click/fleet/identity.conf ]; then
        sed -i "s/^CONTROLLER_TARGET_IP=.*/CONTROLLER_TARGET_IP=$target_ip/" /etc/one-click/fleet/identity.conf
      fi
      if ! iptables -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -c 0 0 2>/dev/null; then
        echo ">>> RHEL 10 Detected: Executing native nftables check-and-insert sequence."
        nft add table ip filter 2>/dev/null || true
        nft add chain ip filter ONE-CLICK-FLEET 2>/dev/null || true
        if ! nft list chain ip filter ONE-CLICK-FLEET | grep -q "ip saddr $target_ip tcp dport 22 accept"; then
          nft insert rule ip filter ONE-CLICK-FLEET index 1 ip saddr "$target_ip" tcp dport 22 accept 2>/dev/null
        fi
        handle=$(nft -a list chain ip filter ONE-CLICK-FLEET | grep "ip saddr $CONTROLLER_IP tcp dport 22 accept" | awk '{print $NF}')
        if [ -n "$handle" ]; then
          nft delete rule ip filter ONE-CLICK-FLEET handle "$handle" 2>/dev/null
        fi
      else
        echo ">>> Standard iptables environment active. Executing legacy sequence..."
        iptables -N ONE-CLICK-FLEET 2>/dev/null || true
        iptables -C ONE-CLICK-FLEET -s "$target_ip" -p tcp --dport 22 -j ACCEPT 2>/dev/null || \
        iptables -I ONE-CLICK-FLEET 1 -s "$target_ip" -p tcp --dport 22 -j ACCEPT 2>/dev/null
        iptables -D ONE-CLICK-FLEET -s "$CONTROLLER_IP" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
      fi
EOF
  done
  info "Demoting local system parameters to managed peer status."
ROLE=peer
FLEET_IDENTITY=$(hostname | tr -d '[:space:]')
STATUS=managed
CONTROLLER_TARGET_IP=$target_ip
LAST_SYNC=$(date +%s)
EOF
  sed -i "s/^CONTROLLER_IP=.*/CONTROLLER_IP=$target_ip/" /etc/one-click/fleet/controller.env
  sed -i "s/^IS_MASTER=.*/IS_MASTER=false/" /etc/one-click/fleet/controller.env
  if command -v iptables &>/dev/null; then
    iptables -I ONE-CLICK-FLEET 1 -s "$target_ip" -p tcp --dport 22 -j ACCEPT 2>/dev/null || true
  fi
  info "Purging local key assets, master files, and playbooks to ensure clean state separation..."
  rm -rf /etc/one-click/fleet/keys
  rm -rf /etc/one-click/fleet/playbooks
  rm -f "$inventory_json" "$backup_ledger" "$snapshot_ledger"
  rm -f /etc/one-click/virtualization/available_ips.txt /etc/one-click/virtualization/used_ips.txt
  rm -f "$migration_archive"
  success "Migration process completed successfully!"
  success "Master dominance authority securely transferred to [$target_destination] ($target_ip)."
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
  info "Dispatching custom firewall instruction payload to target: $target_host..."
  ANSIBLE_HOST_KEY_CHECKING=False \
    ANSIBLE_SSH_TIMEOUT=3 \
    ANSIBLE_GATHERING=explicit \
    ANSIBLE_SSH_ARGS='-C -o IdentityFile=/home/oneclick/.ssh/id_ed25519 -o IdentityFile=/etc/one-click/fleet/keys/id_ed25519' \
	ansible "$target_host" \
    -i "$fleet_root/inventory.yml" \
    -m shell -a "/usr/local/bin/one-click engine \"$rule_command chain ONE-CLICK-FLEET\" -y" 2>/dev/null
  success "Firewall rule dispatched and applied to execution path successfully."
}
dry_run() {
  local cmds ns critical_ports broken check_list ssh_port
  cmds=("$@")
  ns="one-click_dry-run_namespace"
  broken=0
  target_ports=$(grep -oE '[0-9]{1,5}' <<< "${cmds[*]}")
  ssh_port=$(awk '/\./{split($5,a,":");print a[2]}' <(ss -taulpn | grep -i ssh))
  check_list=("${ssh_port}:SSH" "53:DNS" "80:HTTP" "443:HTTPS")
  printf '%s\n' "${magenta}[DRY-RUN]${reset} Preparing dry run isolated environment for safe testing..."
  ip netns add "$ns"
  ip -n "$ns" link set lo up
  ip link add oneclick_vetdry type veth peer name oneclick_vethst
  ip link set oneclick_vetdry netns "$ns"
  ip addr add 10.200.200.1/24 dev oneclick_vethst
  ip link set oneclick_vethst up
  ip -n "$ns" addr add 10.200.200.2/24 dev oneclick_vetdry
  ip -n "$ns" link set oneclick_vetdry up
  ip -n "$ns" route add default via 10.200.200.1
  ip netns exec "$ns" iptables -F
  ip netns exec "$ns" iptables -X
  # ==== Isolated Dry Run ====
  for cmd in "${cmds[@]}"; do
    cmd="${cmd#raw: }"
    # ==== Handle RAW Entries ====
    cmd=$(
      sed -E '
        s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
        s/input|output|forward|prerouting/\U&/g;
      ' <<< "$cmd"
	)
    read -r -a arr <<< "$cmd"
	used_port=$(sed -E 's/.*port ([0-9]+).*/\1/' <<< "$cmd")
	used_ports+=($used_port)
	if ! ip netns exec "$ns" "${arr[@]}"; then
      printf '%s\n' "${red}[DRY-RUN]${reset}  Failed to apply rule in namespace: $cmd"
      broken=1
    fi
  done
  # ==== Test connectivity in namespace ====
  local check_list=()
  mapfile -t check_list < <(
    ss -taulpn | awk '/\(/{print $NF}' | awk -F'"' '{print $2}' | while read -r line; do
        awk -v service="$line" '/\./{split($5,a,":"); print a[2]":"service}' <(ss -taulpn | grep -i "$line")
    done | sort -u
  )
  printf '%s\n' "${magenta}[DRY-RUN]${reset} Verifying system accessibility..."
  if ! ip netns exec "$ns" ping -c 1 -W 1 127.0.0.1 &>/dev/null; then
    printf "${magenta}[DRY-RUN]${reset} %s\n" "${red}Loopback (lo) is BLOCKED!${reset}"
    broken=1
  fi
  for entry in "${check_list[@]}"; do
    local c_port="${entry%%:*}"
    local c_name="${entry##*:}"
    local is_user_targeted=0
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
        printf "${magenta}[DRY-RUN]${green}[SUCCESS] %s${reset}\n" " Port $c_port ($c_name) will successfully remain filtered/blocked."
      fi
    else
      if [[ "$is_user_targeted" -eq 1 ]]; then
        printf "${magenta}[DRY-RUN]${yellow}[WARN] %s${reset}\n" "Logic Error: You tried to block $c_port, but it will remain OPEN."
      else
        printf "${magenta}[DRY-RUN]${green}[SUCCESS] %s${reset}\n" "Service $c_name (Port $c_port) remains accessible."
      fi
    fi
    kill "$nc_pid" 2>/dev/null
  done
  ip link delete oneclick_vethst 2>/dev/null || true
  ip netns delete "$ns" 2>/dev/null
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
detect_firewall_backend() {
  if command -v iptables >/dev/null 2>&1; then
    firewall_backend="iptables"
  elif command -v nft >/dev/null 2>&1; then
    firewall_backend="nft"
  elif command -v ufw > /dev/null 2>&1; then
    firewall_backend="ufw"
  elif command -v firewall-cmd &> /dev/null; then
    firewall_backend="firewalld"
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
  if [[ "$firewall_backend" == "iptables" ]]; then
    return 0
  elif [[ "$firewall_backend" == "nft" ]]; then
    if ! command -v iptables >/dev/null 2>&1; then
      warn "$firewall_backend installed. Installing iptables compatibility layer..."
      install_dep "iptables" "type iptables" "iptables" "$pkg_mgr"
	  if [[ "$pkg_mgr" == "dnf" ]]; then
        install_dep "iptables-services" "type iptables-services" "iptables-services" "$pkg_mgr"
	  fi
      firewall_backend="iptables"
    fi
    return 0
  else
    read -rp "${cyan}[USER]:${reset} No firewall installed. Install iptables? (y|n): " confirm
    confirm="${confirm,,}"
    if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
      install_dep "iptables" "type iptables" "iptables" "$pkg_mgr"
      if [[ "$pkg_mgr" == "dnf" ]]; then
        install_dep "iptables-services" "type iptables-services" "iptables-services" "$pkg_mgr"
	  fi
      firewall_backend="iptables"
    else
      die "Firewall required." "No firewall installed."
    fi
  fi
}
backup_firewall() {
  local backend timestamp outfile engine_backup_dir
  engine_backup_dir="/etc/one-click/rule-engine/"
  mkdir -p "$engine_backup_dir"
  backend="$firewall_backend"
  timestamp="$(date +%Y-%m-%d-%H%M%S)"
  case "$backend" in
    nft)       ext="nft-$timestamp.backup"; nft list ruleset > "${engine_backup_dir}${ext}" 2>/dev/null || return 1     ;;
    iptables)  ext="iptables-$timestamp.backup";${fw_bin:-iptables}-save > "${engine_backup_dir}${ext}" 2>/dev/null || return 1    ;;
    ufw)       ext="ufw-$timestamp.backup"; ufw status verbose > "${engine_backup_dir}${ext}" 2>/dev/null || return 1   ;;
    firewalld) ext="firewalld-$timestamp.backup"; firewall-cmd --runtime-to-permanent >/dev/null 2>&1
               firewall-cmd --permanent --list-all --zone=public > "${engine_backup_dir}${ext}" 2>/dev/null || return 1 ;;
    *)         die "Unsupported firewall backend."                                                                      ;;
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
  # ==== List Backup Files ====
  mapfile -t backups < <(ls -1 "$engine_backup_dir"/*.backup 2>/dev/null)
  if [[ ${#backups[@]} -eq 0 ]]; then
    warn "No firewall backups found in $engine_backup_dir"
    return 1
  fi
  # ==== Show Backups ====
  if [[ ${#backups[@]} -gt 1 ]]; then
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
  # ==== Determine Backend ====
  backend="$firewall_backend"
  select=$(basename "$selected")
  case "$select" in
    nft-*)       backend="nft"       ;;
    iptables-*)  backend="iptables"  ;;
    ufw-*)       backend="ufw"       ;;
    firewalld-*) backend="firewalld" ;;
    *) die "Unknown backup type."    ;;
  esac
  # ==== Restore ====
  warn "Restoring firewall from $selected ..."
  read -rp  "${cyan}[USER]: ${reset}Please confirm you'd like to proceed: " fw_confirm
  fw_confirm="${fw_confirm,,}"
  if [[ "$fw_confirm" == "y" || "$fw_confirm" == "yes" ]]; then
    case "$backend" in
      nft)
        nft flush ruleset
        nft -f "$selected" || return 1
        ;;
      iptables)
        ${fw_bin:-iptables}-restore < "$selected" || return 1
        ;;
      ufw)
        ufw disable >/dev/null 2>&1
        while IFS= read -r rule; do
          ufw $rule >/dev/null 2>&1
        done < "$selected"
        ufw enable >/dev/null 2>&1
        ;;
      firewalld)
        firewall-cmd --permanent --load-config="$selected" || return 1
        firewall-cmd --reload >/dev/null 2>&1
        ;;
      *)
        die "Unsupported firewall backend."
        ;;
    esac
    success "Firewall restored successfully from $(basename "$selected")"
    exit 0
  else
    die "Restore not confirmed" "Aborting..."
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
    read -rp "${red}[CONFIRM]:${reset} Permanently delete alias '$target'? (y/n): " confirm
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
  read -p "Enable automatic IP blocking? (y/n): " choice
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
    tables=($(${fw_bin:-iptables}-save 2>/dev/null | grep '^*' | cut -d'*' -f2))
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
    fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:" | sed 's/.*list://' | tr ' ' '\n' | grep -v '^$' | while read -r f2b_ip; do
      printf "${blue}║ ${yellow}%-16s${blue} ║${reset} %-15s${blue} ║${reset} %-12s${blue} ║ ${red}%-9s${blue} ║${reset}\n" "Fail2Ban" "$f2b_ip" "sshd" "BANNED"
    done
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
  local backend="${firewall_backend:-}"
  for cmd_str in "${generated_cmds[@]}"; do
    read -r -a fw_cmd <<< "$cmd_str"
    if [[ "$backend" == "iptables" || "$backend" == "ip6tables" ]]; then
      if rule_exists_iptables "${fw_cmd[@]}"; then
        warn "Duplicate rule detected: ${fw_cmd[*]}"
        continue
      fi
    fi
    if [[ "$CONFIRM_APPLY" == "1" ]]; then
      if "${fw_cmd[@]}"; then
        success "Rule applied: ${fw_cmd[*]}"
      else
        warn "Failed to apply rule: ${fw_cmd[*]}"
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
        rule_display="${rule_display:0:rule_col_width-3}..."
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
clean_duplicate_rules() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
    install_dep "iptables-services" "type iptables-services" "iptables-services" "$pkg_mgr" true
  fi
  local tmpfile cleanfile
  tmpfile=$(mktemp)
  cleanfile=$(mktemp)
  # ==== Save Rules ====
  ${fw_bin:-iptables}-save | sed '/^\[.*\]$/d' > "$tmpfile"
  # ==== Extract Duplicate ====
  { grep '^-A' "$tmpfile" || true; } | sort | uniq -c | awk '$1 > 1' > "$cleanfile"
  cnt=$(awk '{print $1}' "$cleanfile" | head -1)
  if [[ "$cnt" -eq 1 ]]; then
    rule_plural=rule
	msg="Would you like to remove the duplicate $rule_plural? (y|n): "
  else
    rule_plural=rules
	msg="Would you like to clean the duplicate $rule_plural retaining one copy of each? (y|n): "
  fi
  if [[ ! -s "$cleanfile" ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      printf "${magenta}[DRY-RUN]${reset} %s\n" "No duplicate rules found."
	else
      success "No duplicate rules found."
	fi
    rm -f "$tmpfile" "$cleanfile"
    return 0
  fi
  echo
  warn "Duplicate "$rule_plural" detected:"
  echo "========================================="
  while read -r count rule; do
    printf "  (%d copies) %s\n" "$count" "$rule"
  done < "$cleanfile"
  echo "========================================="
  echo
  if [[ "${y_interactive:-}" -eq 1 ]]; then
    clean_rules=y
  else
    read -rp "${cyan}[USER]:${reset} $msg" clean_rules
    clean_rules="${clean_rules,,}"
    [[ "$clean_rules" != "y" && "$clean_rules" != "yes" ]] && {
      warn "Cleanup cancelled."
      rm -f "$tmpfile" "$cleanfile"
      return 0
    }
  fi
  warn "Rebuilding firewall without duplicates..."
  # ==== Rebuild Ruleset ====
  awk '
    /^-A/ {
        if (!seen[$0]++) print
        next
    }
    { print }
  ' "$tmpfile" > "${tmpfile}.deduped"
  # ==== Attempt Restore ====
  ${fw_bin:-iptables}-restore < "${tmpfile}.deduped" || {
    warn "Restore failed." "Firewall has not been changed."
    rm -f "$tmpfile" "$cleanfile" "${tmpfile}.deduped"
    return 1
  }
  rm -f "$tmpfile" "$cleanfile" "${tmpfile}.deduped"
  success "Duplicate cleanup complete." "Firewall reconfigured retaining one copy of each duplicate."
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
          info "Monitoring $service_desc activity..."
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
    auto_mitigate=0  # Flag: 0 = passive, 1 = auto mitigation
    mkdir -p "$guard_dir"
    info "Starting Deep Traffic Intelligence Audit..."
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
    info "Starting Deep Traffic Intelligence Audit..."
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
        info "Detecting $ip_to_remove in $alias_name... initiating removal."
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
  if [[ "$fw_bin" == "iptables" || "$fw_bin" == "ip6tables" ]]; then
    if [[ "$mode" == "-A" || "$mode" == "-I" ]]; then
      if rule_exists_iptables "${fw_cmd[@]}"; then
        warn "The rule being added already exists." \
	    "Skipping adding duplicate entry"
        duplicate_skipped=1
        return 0
      fi
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
    generated_cmds+=("$fw_bin -t $table -D $chain $del_line")
    return 0
  fi
  if [[ -n "${is_policy_change:-}" ]]; then
    generated_cmds+=("$fw_bin -t $table -P $chain $action")
    return 0
  fi
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
	printf "║ %-46s ║\n" " [3]. Live Journalctl Filter"
    printf "║ %-46s ║\n" " [4]. Exit"
    echo "╚════════════════════════════════════════════════╝"
    tput sgr0
    read -rp "${cyan}[USER]: ${reset}Select option: " choice
    case "$choice" in
      1) browse_files       ;;
      2) browse_journal     ;;
	  3) live_journal_view  ;;
      4) exit               ;;
    esac
  done
}
live_journal_view() {
  while true; do
    journal_usage=$(journalctl --disk-usage 2>/dev/null | awk '{print $3,$4}')
    selection=$(
      fzf --height=85% \
          --border \
          --ansi \
          --prompt="Type service or keyword: " \
          --preview 'sudo journalctl -u {q} -n 200 --no-pager' \
          --preview-window=right:60%:wrap \
          --expect=enter,ctrl-e \
          --header="ENTER=view | CTRL-E=back | Live filter journal | Total usage: $journal_usage"
    )
    [[ -z "$selection" ]] && return
    key=$(echo "$selection" | head -n1)
    query=$(echo "$selection" | tail -n1)
    case "$key" in
      enter)
        read -rp "${cyan}[USER]: ${reset}Live tail $query? [y/N]: " live
        if [[ "$live" =~ ^[Yy]$ ]]; then
          clear
          echo "Live tailing '$query'... Press Ctrl-C to exit"
          sudo journalctl -u "$query" -f --no-pager
          clear
        else
          clear
          sudo journalctl -u "$query" --no-pager | less -R
          clear
        fi
        ;;
      ctrl-e)
        return
        ;;
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
          sudo truncate -s 0 "$file"
          success "Log cleared."
          sleep 1
        fi
        continue
        ;;
      ctrl-a)
        read -rp "${yellow}[WARNING]: ${reset}Clear ALL ${#logs[@]} logs (~$total_human)? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          for f in "${logs[@]}"; do
            sudo truncate -s 0 "$f" 2>/dev/null
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
          sudo journalctl --unit="$unit" --rotate
          sudo journalctl --unit="$unit" --vacuum-time=1s
          success "Journal for $unit cleared."
          sleep 2
        fi
        ;;
      ctrl-a)
        read -rp "${yellow}[WARNING]: ${reset}Vacuum ALL journal logs ($journal_usage)? [y|n]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          sudo journalctl --rotate
          sudo journalctl --vacuum-time=1s
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
