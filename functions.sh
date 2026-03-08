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
mkdir -p "${log_dir:-}"
touch "${log_error_file:-}" "${log_file:-}"
sensitive_ports_file="/etc/one-click/rule-engine/.sensitive.ports"
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
}
# ==== End Essential Variables ==== #
collect_sysinfo() {
  whois_ip="$(sed -En '/inet /{s,^[^/]* ([^/]*).*,\1,p}' <(ip a s "$nic"))"
  api_response=$(curl -sL https://ipinfo.io/${whois_ip}/json)
  api_response2=$(curl -sL http://ip-api.com/json/${whois_ip})
  sys_ip="$(awk '$1 == "inet" {split($2,arr,"/"); print arr[1]}' <(ip a s "$nic"))"
  sys_gw="$(awk '$1 == "default" {print $3}' <(ip r))"
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
  rm -rf /etc/one-click/ocb/geekbench_*
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
# ============================================= End Script Helpers ======================================== #
# =============================================== Country Mapping ===========================================
expand_country() {
  local code="${1^^}"  # uppercase input
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
  (
    mkdir -p "$path"
    curl -sL "$url" -o "$archive" || exit 1
    tar -xzf "$archive" --strip-components=1 -C "$path" &> /dev/null || exit 1
        chmod +x "$path/$gb_cmd"
  ) &    
  gb_pid="$!"
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
  # ==== Detect package ====
  if [[ $version == "6" ]]; then
    if [[ "${arch:-}" == *aarch64* || "${ARCH:-}" == *arm* ]]; then
      gb_url="https://cdn.geekbench.com/Geekbench-6.5.0-LinuxARMPreview.tar.gz"
    else
      gb_url="https://cdn.geekbench.com/Geekbench-6.5.0-Linux.tar.gz"
    fi
    gb_cmd="geekbench6"
    gb_run="True"
  elif [[ $version == "5" ]]; then
    if [[ "${arch:-}" == *aarch64* || "${arch:-}" == *arm* ]]; then
      gb_url="https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz"
    else
      gb_url="https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz"
    fi
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
  # ==== Check earlier download ====
  if [[ -n "$gb_pid" ]]; then
    if ! wait "$gb_pid"; then
      printf "${red}%s${reset}\n" \
        "│ Geekbench failed to install                                                                      │"
      printf "${yellow}%s${reset}\n" \
        "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
      return
    fi
  fi
  if [[ ! -x "$gb_path/$gb_cmd" ]]; then
    printf "${red}%s${reset}\n" \
      "│ Geekbench binary missing or not executable: $gb_path/$gb_cmd                                     │"
	printf "${yellow}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return
  fi
  printf "${yellow}│ %-96s${reset}\r" "${green}Running GB$version benchmark...${yellow}"
  test_url=$("$gb_path/$gb_cmd" --upload 2>/dev/null | grep -m1 https://browser | xargs)
  if [[ -z "$test_url" ]]; then
    printf "${blue}%-20s %-20s %-54s${reset}\n" \
      "│Geekbench" "GB${version}" "${red}Failed${blue}                                                    │"
    printf "${blue}%s${reset}\n" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    return
  fi
  wait "$gb_pid"
  sleep 2
  scores=$(sed -En \
    "/<div class='score-container score-container-1 desktop'>|<div class='score-container desktop'>/ {
	  n;
	  s/[^>]*>([0-9]+).*/\1/p
	}" <($dl_cmd "$test_url")
  )
  single=$(head -1 <<< "$scores")
  multi=$(tail -1 <<<  "$scores")
  printf "${blue}│${green}%-20s %-20s %-56s${blue}│${reset}\n" \
    "Single Core" "GB$version" "$single"
  printf "${blue}│${green}%-20s %-20s %-56s${blue}│${reset}\n" \
    "Multi Core" "GB$version" "$multi"
  printf "${blue}│${cyan}%-20s %-20s %-56s${blue}│${reset}\n" \
    "Result URL" "GB$version" "$test_url"
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
  "1500.mtu.he.net" "5201-5205" "HE Net" "San Jose, CA, US (10G)" "IPv4|IPv6" \
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
    return 0  # online
  else
    return 1  # offline
  fi
}
is_v6_online() {
  if ping -6 -c 1 -W 2 2001:4860:4860::8888 &>/dev/null; then
    return 0  # online
  else
    return 1  # offline
  fi
}
total_time() {
  local key_width val_width start_time end_time total_width inner_width border msg msg1 min sec time_taken
  key_width=15
  val_width=78
  start_time=$1
  end_time=$2
  total_width=$((key_width + val_width + 7))
  inner_width=$((total_width - 2))
  border=$(printf '─%.0s' $(seq 1 "$inner_width"))
  time_taken=$(( end_time - start_time ))
  msg1="One-Click Bench completed in ${time_taken} sec"
  if (( ${time_taken} > 60 )); then
	min=$(( time_taken / 60 ))
    sec=$(( time_taken % 60 ))
	msg="One-Click Bench completed in ${min} min ${sec} sec"
	printf "${blue}┌%s┐${reset}\n" "$border"
    printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg"
    printf "${blue}└%s┘${reset}\n" "$border"
  else
    printf "${blue}┌%s┐${reset}\n" "$border"
    printf "${blue}│ %-*s │${reset}\n" "$((total_width - 4))" "$msg1"
    printf "${blue}└%s┘${reset}\n" "$border"
  fi
}
# ============================================= End One-Click Bench ========================================= #
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
  # ==== Typing Header Notification ====
  #offset=$(( (cols - ${#header_banner}) / 2 ))
  #row=$(( rows / 2 ))
  #tput cup "$row" "$offset"
  # ==== Notice Main ====
  #while IFS= read -r line; do
  #  printf '%s' "$(tput setaf $af)$(tput setab $ab)${line//#/ }${reset}"
  #  sleep 0.1
  #done < <(sed 's/./&\n/g' <<< "$header_banner")
  #echo
  #sleep 0.6
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
    iptables)  ext="iptables-$timestamp.backup";iptables-save > "${engine_backup_dir}${ext}" 2>/dev/null || return 1    ;;
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
        iptables-restore < "$selected" || return 1
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
get_existing_rules() {
  local backend="$1"
  case "$backend" in
    nft)
      nft list ruleset
      ;;
    iptables)
      iptables-save
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
  iptables-save | sed '/^\[.*\]$/d' > "$tmpfile"
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
    success "No duplicate rules found."
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
  read -rp "${cyan}[USER]:${reset} $msg" clean_rules
  clean_rules="${clean_rules,,}"
  [[ "$clean_rules" != "y" && "$clean_rules" != "yes" ]] && {
    warn "Cleanup cancelled."
    rm -f "$tmpfile" "$cleanfile"
    return 0
  }
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
  iptables-restore < "${tmpfile}.deduped" || {
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
	  alert1="[ALERT] Action: $current_action detected on Port $p ($service_desc)."
      alert2="[ALERT] This is a CORE SERVICE. Proceeding may cause connectivity issues! "
      len1=${#alert1}
      len2=${#alert2}
      width=$(( len1 > len2 ? len1 : len2 ))
      border=$(printf '═%.0s' $(seq 1 "$((width + 2))"))
	  border2=$(printf '═%.0s' $(seq 1 "$(((width / 2)-10))"))
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
  del_line=""
  rule_lower="${rule,,}"
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
  # ==== Detect Interface ====
  if [[ "$rule_lower" =~ (interface|iface)[[:space:]]+([a-zA-Z0-9.+]+) ]]; then
    in_interface="${BASH_REMATCH[2]}"
  elif grep -Eq "\blo\b" <<< "$rule_lower"; then
    in_interface="lo"
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
  if grep -Eqi "\b(list|show|open|display)\b" <<< "$rule_lower"; then
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
    filter)         chain="INPUT"      ;;
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
    else
      fw_bin="iptables"
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
  #proto="tcp"
  if grep -Eqi "\budp\b" <<< "$rule_lower"; then
    proto="udp"
  elif grep -Eqi "\btcp\b" <<< "$rule_lower"; then
    proto="tcp"
  elif grep -Eqi "\bicmp\b" <<< "$rule_lower" || grep -Eqi "\becho\b" <<< "$rule_lower"; then
    proto="icmp"
  elif grep -Eq "\bmultiport\b" <<< "$rule_lower"; then
    proto="tcp"
  fi
  # ==== Detect Alias ====
  if [[ "$rule_lower" =~ ^(remember|include)[[:space:]]+([a-z0-9_-]+)[[:space:]]+([0-9./:]+([[:space:]]+[0-9./:]+)+?) ]]; then
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
  if [[ "$rule_lower" =~ from[[:space:]]+([0-9a-fA-F:.\/]+) ]]; then 
    src_ip="${BASH_REMATCH[1]}"
    valid_ip "$src_ip" && ip_version="ipv4"
    valid_ipv6 "$src_ip" && { ip_version="ipv6"; fw_bin="ip6tables"; }
  fi
  if [[ "$rule_lower" =~ from[[:space:]]+([a-zA-Z0-9._:-]+) ]]; then
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
      die "Delete requires line number."
    fi
  fi
  # ==== Service Name Mapping ====
  raw_services="tcpmux:1 echo:7 discard:9 systat:11 daytime:13 qotd:17 chargen:19 ftp-data:20 ftp:21 ssh:22 telnet:23 smtp:25 time:37 whois:43 tacacs:49 dhcp-server:67 dhcp-client:68 tftp:69 gopher:70 finger:79 http:80 kerberos:88 pop3:110 sunrpc:111 ident:113 nntp:119 ntp:123 imap:143 snmp:udp:161,tcp:161 snmptrap:udp:162,tcp:162 bgp:179 irc:194 ldap:389 https:443 microsoft-ds:445 smtps:465 syslog:udp:514,tcp:514 ldaps:636 ftps-data:989 ftps:990 imaps:993 pop3s:995 rsync:873 mysql:3306 postgresql:5432 rdp:3389 vnc:5900 redis:6379 mongodb:27017 sip:udp:5060,tcp:5060 sips:udp:5061,tcp:5061 pptp:1723 l2tp:1701 ipsec-isakmp:500 openvpn:udp:1194,tcp:1194 docker:2375 docker-tls:2376 kubernetes-api:6443 etcd:2379 grafana:3000 prometheus:9090 elasticsearch:9200 kibana:5601 zabbix-agent:10050 zabbix-server:10051 jenkins:8080 tomcat:8080 http-alt:8080 https-alt:8443 webmin:10000 cockpit:9090 cassandra:9042 memcached:11211 rabbitmq:5672 amqp:5672 mqtt:1883 mqtts:8883 git:9418 svn:3690 teamspeak:9987 minecraft:25565 wireguard:51820 plex:32400 nfs:2049 samba:137 samba-nbt:138 samba-ssn:139 cups:631 tor:9001 tor-socks:9050 rdp-alt:3390 oracle:1521 ms-sql:1433 ms-sql-browser:1434 radius:1812 radius-acct:1813 freeipa-ldap:7389 freeipa-ldaps:7636 xmpp-client:5222 xmpp-server:5269 asterisk:5038 iscsi:3260 glusterfs:24007 vault:8200 consul:8500 dns:tcp:53,udp:53 apache:tcp:80,tcp:443 nginx:tcp:80,tcp:443 bind9:tcp:53,udp:53 haproxy:tcp:80,tcp:443 postfix:tcp:25 dovecot:tcp:143,tcp:993 cyrus-imap:tcp:143,tcp:993"
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
  rule_ports_only=$(sed -E 's/\b(to|from)[[:space:]]+[0-9a-fA-F:.\/]+\b//g' <<< "$rule_ports_only")
  rule_ports_only=$(sed -E 's/\b(to|dst|destination)[[:space:]]+(address[[:space:]]+)?[0-9a-fA-F:.\/]+\b//g' <<< "$rule_ports_only")
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
    skip_service_ports=1   # prevent TCP/UDP port logic
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
    [[ -n "$in_interface" ]] && cmd+=("-i" "$in_interface")
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
    # Get total journal disk usage
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
