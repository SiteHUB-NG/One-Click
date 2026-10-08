#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK CRONS  MODULE * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ======================= # ======================== # ======================= #
# === Build: Jan 2026 === # === Updated: Oct 2026 == # == Version#: 1.0.0 ==== #
# ====== One-Click ====== ## ==== NodeJS ==== ## ==== DNS ==== # ==== SSL ==== #
# ==== WordPress ==== # ==== PHP ==== ## ==== NexCloud ==== # ==== Static ==== #
. /etc/os-release
web_dependency_bootstrap() {
  local mode_arg="${1:-}"
  local major_ver
  . /etc/os-release
  case "${pkg_mgr:-}" in
    apt|apt-get)
      dig_pkg="dnsutils"
      if ! "$pkg_mgr" -y install \
        php php-cli php-fpm php-curl php-gd php-mbstring php-xml php-zip php-mysql \
        git "$dig_pkg" bzip2 >/dev/null 2>&1; then
        error "Failed to install required web-hosting dependencies with $pkg_mgr."
        return 1
      fi
      ;;
    dnf|yum)
      dig_pkg="bind-utils"
      major_ver="${VERSION_ID%%.*}"
      if [[ ! -f /etc/one-click/.deps_wordpress && "${pkg_mgr}" == "dnf" ]]; then
        "$pkg_mgr" install -y epel-release >/dev/null 2>&1 || true
        "$pkg_mgr" install -y \
          "https://rpms.remirepo.net/enterprise/remi-release-${major_ver}.rpm" \
          >/dev/null 2>&1 || true
      fi
      if ! "$pkg_mgr" -y install \
        php php-cli php-fpm php-curl php-gd php-mbstring php-xml php-zip php-mysqlnd php-process \
        git "$dig_pkg" bzip2 >/dev/null 2>&1; then
        error "Failed to install required web-hosting dependencies with $pkg_mgr."
        return 1
      fi
      touch /etc/one-click/.deps_wordpress
      ;;
    *)
      error "Unsupported package manager '${pkg_mgr:-unknown}' for the web-hosting module."
      return 1
      ;;
  esac
  return 0
}
web_dependency_bootstrap "${1:-}"
if [[ "$1" != "--monitor" ]]; then
  install_dep "git" "command -v git" "git" "$pkg_mgr" true || true
  install_dep "dig" "command -v dig" "$dig_pkg" "$pkg_mgr" true || true
  install_dep "bzip2" "command -v bzip2" "bzip2" "$pkg_mgr" true || true
fi
. /etc/os-release
base_dir="/etc/one-click"
config_dir="$base_dir/configuration"
db_manager_dir=/etc/one-click/db-manager
sitectl_dir="${db_manager_dir}/sites"
mkdir -p \
  "${db_manager_dir}/sites" \
  "${db_manager_dir}/runtime/db" \
  "${db_manager_dir}/runtime/sessions" \
  "${db_manager_dir}/runtime/locks" \
  "${db_manager_dir}/runtime/temp" \
  "${db_manager_dir}/runtime/tokens" \
  "${db_manager_dir}/logs" \
  "${db_manager_dir}/backups" \
  "${db_manager_dir}/cache" \
  "${db_manager_dir}/templates" \
  "${db_manager_dir}/secrets/db" \
  "${db_manager_dir}/secrets/db-users"
chown -R root:root "$db_manager_dir"
chmod 0755 "$db_manager_dir"
chmod 0755 \
  "${db_manager_dir}/sites" \
  "${db_manager_dir}/runtime" \
  "${db_manager_dir}/runtime/db" \
  "${db_manager_dir}/runtime/sessions" \
  "${db_manager_dir}/runtime/locks" \
  "${db_manager_dir}/runtime/temp" \
  "${db_manager_dir}/logs" \
  "${db_manager_dir}/backups" \
  "${db_manager_dir}/cache" \
  "${db_manager_dir}/templates"
chmod 0711 \
  "${db_manager_dir}/runtime/tokens" \
  "${db_manager_dir}/secrets" \
  "${db_manager_dir}/secrets/db" \
  "${db_manager_dir}/secrets/db-users"
cat > /etc/cron.d/db-manager <<'EOF'
*/10 * * * * root find /etc/one-click/db-manager/runtime/tokens -type f -mmin +30 -delete
EOF
chmod 0644 /etc/cron.d/db-manager
secret_key="/etc/one-click.backup_secret.key"
current_profile_file="$config_dir/current_profile"
webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
centos_ver=$(grep -Eo [0-9]+ /etc/centos-release 2> /dev/null || true)
app_dir="/etc/one-click/apps"
app_port_start=15000
app_port_end=15999
dns_api_root="/etc/one-click/dns"
dns_provider_root="${dns_api_root}/providers"
dns_domain_root="${dns_api_root}/domains"
dns_master_key="/etc/one-click/.dns.key"
mkdir -p "$dns_provider_root" "$dns_domain_root" "/etc/one-click"
if [[ "$ID" == "debian" ]]; then
  php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
fi
dns_check() {
  local domain_name="${1:-${domain:-}}"
  local local_v4="${sys_ip:-}"
  local local_v6="${sys_ipv6:-}"
  local_v6="${local_v6%%/*}"
  local -a root_answers=() www_answers=()
  local answer
  local root_ok=1 www_ok=1
  if [[ -z "$domain_name" ]]; then
    error "DNS validation requires a domain name."
    return 0
  fi
  if [[ -z "$local_v4" && -z "$local_v6" ]]; then
    error "DNS validation could not determine a local IPv4 or IPv6 address."
    return 0
  fi
  while IFS= read -r answer; do
    [[ -n "$answer" ]] && root_answers+=("$answer")
  done < <({ dig +short A "$domain_name" 2>/dev/null; dig +short AAAA "$domain_name" 2>/dev/null; } | sort -u)
  while IFS= read -r answer; do
    [[ -n "$answer" ]] && www_answers+=("$answer")
  done < <({ dig +short A "www.$domain_name" 2>/dev/null; dig +short AAAA "www.$domain_name" 2>/dev/null; } | sort -u)
  dns="${root_answers[*]:-}"
  dns_www="${www_answers[*]:-}"
  for answer in "${root_answers[@]}"; do
    if [[ -n "$local_v4" && "$answer" == "$local_v4" ]] || \
       [[ -n "$local_v6" && "$answer" == "$local_v6" ]]; then
      root_ok=0
      break
    fi
  done
  for answer in "${www_answers[@]}"; do
    if [[ -n "$local_v4" && "$answer" == "$local_v4" ]] || \
       [[ -n "$local_v6" && "$answer" == "$local_v6" ]]; then
      www_ok=0
      break
    fi
  done
  if (( root_ok != 0 || www_ok != 0 )); then
    warn "Domain does not fully resolve to this server (${local_v4:-${local_v6}})."
    [[ $root_ok -ne 0 ]] && warn "$domain_name -> ${dns:-NO MATCHING RECORD}"
    [[ $www_ok -ne 0 ]] && warn "www.$domain_name -> ${dns_www:-NO MATCHING RECORD}"
  fi
  return 0
}
resolve_type() {
  local domain="$1"
  local matches=()
  [[ -e "/etc/one-click/wordpress/$domain" ]] && matches+=("wordpress")
  [[ -e "/etc/one-click/sites/$domain" ]] && matches+=("sites")
  [[ -e "/etc/one-click/apps/nodejs/$domain" ]] && matches+=("apps/nodejs")
  [[ -e "/etc/one-click/nextcloud/$domain" ]] && matches+=("nextcloud")
  case "${#matches[@]}" in
    0)
      type="unknown"
      return 1
      ;;
    1)
      type="${matches[0]}"
      return 0
      ;;
    *)
      error "Ambiguous domain '$domain': ${matches[*]}"
      return 2
      ;;
  esac
}
# ==== Wordpress Backup ====
wp_backup() {
  local domain base site backup timestamp config_path
  domain="${1:-}"
  resolve_profile "$domain" || return 1
  base="/etc/one-click/wordpress"
  site="$base/$domain/www"
  . "${base}/${domain}/meta.conf"
  config_path="$base/$domain/wp-config.php"
  timestamp=$(date +%Y%m%d-%H%M%S)
  web_user="$SITE_USER"
  snap="${3:-}"
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  if [[ -n "${2:-}" ]];then
    if [[ ! "${2:-}" == "ran" ]]; then
      [[ ! -f "$config_path" ]] && {
        error "wp-config.php missing"
        return 1
      }
    fi
  fi
  if [[ -n "$snap" ]]; then
    backup="$base/rollback/$domain"
    info "Creating rollback snapshot"
    mkdir -p "$backup/$timestamp"
    backup_role=Rollback
  else
    backup="$base/backups/$domain"
    info "Creating site backup for $domain"
    mkdir -p "$backup/$timestamp"
    backup_role=Backup
  fi
  info "Creating WordPress backup for $domain"
  mkdir -p "$backup/$timestamp"
  local db_name db_user db_pass
  db_name=$(grep DB_NAME "$config_path" | cut -d"'" -f4)
  db_user=$(grep DB_USER "$config_path" | cut -d"'" -f4)
  db_pass=$(grep DB_PASSWORD "$config_path" | cut -d"'" -f4)
  info "Dumping Database"
  mysqldump -u"$db_user" -p"$db_pass" "$db_name" | pv | gzip > "$backup/$timestamp/db.sql.gz"
  info "Archiving files."
  tar -czf "$backup/$timestamp/files.tar.gz" -C "$site" . -C "$(dirname "$config_path")" "wp-config.php"
  info "Building manifest"
  # ==== Metadata ====
  info "Building metadata"
  cat > "$backup/$timestamp/meta.conf" <<EOF
DOMAIN=$domain
DB_NAME=$db_name
DB_USER=$db_user
TIMESTAMP=$timestamp
POOL=enabled
SLICE=enabled
EOF
  # ==== Manifest ====
  cat > "$backup/$timestamp/manifest.txt" <<EOF
TYPE=$( [[ -f "$backup/$timestamp/db.sql.gz" ]] && echo wordpress || echo static )
DOMAIN=$domain
TIMESTAMP=$timestamp
HOSTNAME=$(hostname)
BACKUP_VERSION=1.0
EOF
  chown "$web_user":"$web_user" "$backup/$timestamp/meta.conf"
  update_profile_field "$profile" "LAST_BACKUP" "$timestamp"
  if [[ "$remote_enabled" == "true" ]]; then
    mirror_backup "$domain" "$backup/$timestamp" "$timestamp"
  fi
  success "$backup_role stored at $backup/$timestamp"
  sleep 2
}
wp_restore() {
  local domain base site_dir backup_dir db_name db_user db_pass
  local loc dest
  domain="${domain:-${1}}"
  resolve_profile "$domain" || return 1
  warn "Beginning WordPress restore"
  create_rollback_snapshot "$domain" "wordpress"
  backup_dir="${2:-${backup_dir}}"
  base="/etc/one-click/wordpress"
  site_dir="$base/$domain/www"
  config_path="$base/$domain/wp-config.php"
  loc="local"
  dest="$HOSTNAME"
  read -rp "${cyan}[USER]${yellow} This will overwrite the current $domain. Continue? (y|n): " confirm
  [[ "$confirm" != "y" ]] && return 1
  [[ -z "$backup_dir" ]] && {
    die "Backup directory not provided"
  }
  [[ ! -d "$site_dir" ]] && {
    die "Invalid site_dir"
  }
  if [[ "$remote_enabled" == "true" ]]; then
    loc="remote"
    dest="$profile_host"
    info "Fetching remote backup from $profile_host."
    run_rsync \
      "${profile_user}@${profile_host}:${profile_base}/${domain}/" \
      "$backup_dir/"
  fi
  info "Loading metadata."
  . "$backup_dir/meta.conf" 2>/dev/null
  . "$base/$domain/meta.conf" 2>/dev/null

  info "Clearing current site directory."
  find "$site_dir" -mindepth 1 -delete
  rm -f "$config_path"
  info "Restoring from $loc ($dest) -> $backup_dir"
  # ==== Restore files ====
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  # ==== Relocate wp-config ====
  if [[ -f "$site_dir/wp-config.php" ]]; then
    info "Relocating wp-config.php to secure parent directory."
    mv "$site_dir/wp-config.php" "$config_path"
  fi
  # ==== Restore database ====
  info "Restoring database."
  db_name=$(grep DB_NAME "$config_path" | cut -d"'" -f4)
  db_user=$(grep DB_USER "$config_path" | cut -d"'" -f4)
  db_pass=$(grep DB_PASSWORD "$config_path" | cut -d"'" -f4)
  pv "$backup_dir/db.sql.gz" | gunzip | mysql -u"$db_user" -p"$db_pass" "$db_name"
  # ==== Fix permissions ====
  chown -R "$web_user":"$SITE_GROUP" "$site_dir"
  chown "$web_user":"$SITE_GROUP" "$config_path"
  chmod 644 "$config_path"
  success "Restore complete for $domain"
}
wp_backup_scheduler() {
  local wp_domain="${1:-${domain:-}}"
  [[ "$wp_domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || {
    error "Cannot schedule WordPress backup without a valid domain."
    return 1
  }
  cat <<EOF >"/etc/cron.d/one-click-wp-backups-$wp_domain"
0 2 * * * root bash /var/cache/one-click/wordpress.sh -wpback $wp_domain    #One-Click WP Backup
30 2 * * * root bash /var/cache/one-click/wordpress.sh -wprotate $wp_domain #One-Click WP Rotate
EOF
}
wp_backup_rotate() {
  local domain backup
  domain="${domain:-${1}}"
  backup="/etc/one-click/wordpress/backups/$domain"
  find "$backup" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
}
select_wp_domain() {
  local base sites i choice
  mode="${1}"
  if [[ "${2:-}" == "profile" ]]; then
    type=profile
  elif [[ "${2:-}" == "WordPress" ]]; then
    type="$2"
  elif [[ "${2:-}" == "rollback" ]]; then
    type=restore
  else
    type=site
  fi
  base="/etc/one-click/wordpress/"
  mapfile -t sites < <(sed -n '/\./p' <(find "$base" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2> /dev/null))
  if [[ ${#sites[@]} -eq 0 ]]; then
    error "No WordPress sites found in $base." "Please install a wordpress instance first with ${yellow}one-click --wp-create${reset}"
    sleep 5
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
  fi
  printf '%s\n' "${blue}Available WordPress sites:${reset}" " "
  printf "${magenta}%-3s${blue} | ${yellow}%s${reset}\n" "No" "Domain"
  echo "${blue}------------------------${reset}"
  for i in "${!sites[@]}"; do
    printf "${magenta}%-3s ${blue}| ${yellow}%s${reset}\n" "$((i+1))" "$(basename "${sites[$i]}")"
  done
  printf "${magenta}%-3s ${blue}| ${yellow}%s${reset}\n" "0" "${red}Exit"
  read -rp "${cyan}[USER] ${blue}Select a $type to $mode by number: ${reset}" choice
  if [[ "$choice" -eq 0 ]]; then
    central_menu
  fi
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#sites[@]})); then
    error "Invalid selection"
    return 1
  fi
  domain=$(basename "${sites[$((choice-1))]}")
  export domain
}
wp_backup_interactive() {
  central_menu wordpress
}
################################### MENUS ####################################
web_logs() {
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK WEB LOGS${blue}                      ║" \
      "╠════╦═══════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Access Logs${blue}                                       ║" \
      "║ ${magenta}2${blue}  ║ ${green}Error Logs${blue}                                        ║" \
      "║ ${magenta}3${blue}  ║ ${green}Filter 200 Response Code${blue}                          ║" \
      "║ ${magenta}4${blue}  ║ ${green}Filter Response Codes${blue}                             ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit${blue}                                              ║" \
      "╚════╩═══════════════════════════════════════════════════╝${reset}") <(get_current_profile "$domain")
    read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) web_log_view "$domain" access     ;;
      2) web_log_view "$domain" error      ;;
      3) web_log_view "$domain" access 200 ;;
      4)
        while true; do
          read -rp "${cyan}[USER]${reset} Enter the port number to filter: " filter_port
          if [[ ! "$filter_port" =~ ^[0-9]+$ ]]; then
            error "Please enter an integer"
          else
            break
          fi
        done
          web_log_view "$domain" access view "$filter_port"
        ;;
      0) clear; return 0                 ;;
      *) error "Invalid option"          ;;
    esac
  done
}
profiles_board() {
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK PROFILES MANAGER${blue}                  ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Switch Profiles${blue}                                       ║" \
      "║ ${magenta}2${blue}  ║ ${green}List Profiles ${blue}                                        ║" \
      "║ ${magenta}3${blue}  ║ ${green}Add Profile ${blue}                                          ║" \
      "║ ${magenta}4${blue}  ║ ${green}Delete Profile ${blue}                                       ║" \
      "║ ${magenta}5${blue}  ║ ${green}Test Profile Connection ${blue}                              ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back ${blue}                                                 ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}") <(get_current_profile "$domain" || true)
    read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) profile_switch
        read -rp "${cyan}[USER]${blue} Press Enter to continue" ;;
      2) profile_list               ;;
      3) profile_add                ;;
      4) profile_delete             ;;
      5) remote_profile_test        ;;
      0) clear; return 0            ;;
      *) error "Invalid option"     ;;
    esac
  done
}
backup_board() {
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK WEB BACKUP MANAGER${blue}                ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1 ${blue} ║ ${green}Local Backup  ${blue}                                        ║" \
      "║ ${magenta}2 ${blue} ║ ${green}Local Restore ${blue}                                        ║" \
      "║ ${magenta}3 ${blue} ║ ${green}Remote Backup ${blue}                                        ║" \
      "║ ${magenta}4 ${blue} ║ ${green}Remote Restore ${blue}                                       ║" \
      "║ ${magenta}5 ${blue} ║ ${green}Rollback Restore ${blue}                                     ║" \
      "║ ${magenta}6 ${blue} ║ ${green}List Local Backups ${blue}                                   ║" \
      "║ ${magenta}7 ${blue} ║ ${green}List Remote Backups ${blue}                                  ║" \
      "║ ${magenta}8 ${blue} ║ ${green}List Rollbacks ${blue}                                       ║" \
      "║ ${magenta}0 ${blue} ║ ${green}Back ${blue}                                                 ║" \
      "╚════╩═══════════════════════════════════════════════════════╝") <(get_current_profile "$domain")

  read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1)
        if [[ "$wpstatic" == "wordpress" ]]; then
          if [[ -z "${domain:-}" ]]; then
            warn "Please create a vhost before proceeding"
            read -rp "${cyan}[USER]${reset} Press Enter to continue"
            run_script
          fi
          resolve_profile "$domain"
          wp_backup "$domain"
        else
          if [[ -z "${domain:-}" ]]; then
            warn "Please create a vhost before proceeding"
            read -rp "${cyan}[USER]${reset} Press Enter to continue"
            create_static_site
          fi
          resolve_profile "$domain"
          static_backup "$domain"
        fi
        ;;
      2)
        if [[ "$wpstatic" == "wordpress" ]]; then
          resolve_profile "$domain"
          wp_restore_int
        else
          static_restore_int "$domain"
        fi
        ;;
      3) remote_backup "$domain" "$wpstatic"    ;;
      4) remote_restore "$domain" "$wpstatic"   ;;
      5) rollback_restore "$domain" "$wpstatic" ;;
      6)
        local_list "$domain" "$wpstatic"
        read -rp "${cyan}[USER]${blue} Press Enter to continue"
        ;;
      7)
        resolve_profile "$domain"
        profile_pass_enc=$(awk -v p="[$profile]" '
          $0==p {f=1; next}
          /^\[/ {f=0}
          f && /^E-PASSWD=/ {
            print substr($0,10)
            exit
          }
        ' "$profiles_file")
        if [[ -n "$profile_pass_enc" ]]; then
          d_pass=$(decrypt_password "$profile_pass_enc")
        else
          d_pass=""
        fi
        remote_list "$domain" "$d_pass"
        read -rp "${cyan}[USER]${blue} Press Enter to continue"
        ;;
      8) rollback_list "$domain" ;;
      0) clear; return 0         ;;
      *) error "Invalid option"  ;;
    esac
  done
}
main_board() {
  if [[ -z "${domain:-}" ]]; then
    select_domain || return 1
  fi
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK WEB ADMIN         ${blue}                ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Backup Restores & Rollback  ${blue}                          ║" \
      "║ ${magenta}2${blue}  ║ ${green}Manage Profiles  ${blue}                                     ║" \
      "║ ${magenta}3${blue}  ║ ${green}Manage Redis  ${blue}                                        ║" \
      "║ ${magenta}4${blue}  ║ ${green}Cron   ${blue}                                               ║" \
      "║ ${magenta}5${blue}  ║ ${green}Change Domain   ${blue}                                      ║" \
      "║ ${magenta}6${blue}  ║ ${green}Clone Domain   ${blue}                                       ║" \
      "║ ${magenta}7${blue}  ║ ${green}Guard   ${blue}                                              ║" \
      "║ ${magenta}8${blue}  ║ ${green}Generate Sitemap + Robots   ${blue}                          ║" \
      "║ ${magenta}9${blue}  ║ ${green}Check/Fix Permissions${blue}                                 ║" \
      "║ ${magenta}10${blue} ║ ${green}Delete Site${blue}                                           ║" \
      "║ ${magenta}11${blue} ║ ${green}Web Logs${blue}                                              ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit  ${blue}                                                ║" \
      "╚════╩═══════════════════════════════════════════════════════╝") <(get_current_profile "$domain")
  read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) backup_board   ;;
      2) profiles_board ;;
      3)\
        if [[ -f /etc/redis/one-click/${domain}.conf ]]; then
          redis_menu
          exit 0
        fi
        error "$domain does not have Redis configured"
        ;;
      4)
        if [[ "$wpstatic" == "wordpress" ]]; then
          install_wp_cron "-wpback" "One-Click WordPress Backup" "$domain"
        else
          install_wp_cron "-staticback" "One-Click Static Backup" "$domain"
        fi
        ;;
      5) select_domain           ;;
      6)
        if [[ "$wpstatic" == "wordpress" ]]; then
          error "This tool cannot be used for Wordpress sites" \
            "Please use ${magenta}one-click --wp-admin${reset}"
        fi
        clone_static_site "$domain"
        ;;
      7) view_security "$domain" ;;
      8)
        if [[ "$wpstatic" == "wordpress" ]]; then
          die "This can not be used for Wordpress sites"
        fi
        if [[ -f /etc/cron.d/one-click-sitemap_robots ]];then
          warn "Sitemap automation is already enabled"
          while true; do
            printf "${magenta}[SITEMAP]${reset} %s\n" \
              "====================================" \
              "        SITEMAP GENERATOR" \
              "====================================" \
              "1) Remove automation, sitemap and robots" \
              "2) Regenerate sitemap and robots" \
              "3) Go back" \
              "===================================="
            read -rp "${cyan}[USER]${reset} Select an option [1-3]: " choice
            case "$choice" in
              1)
                warn "${yellow}[*]${yellow} Removing automation."
                rm -f /etc/cron.d/one-click-sitemap_robots
                rm -f "/etc/one-click/sites/${domain}/www/sitemap.xml"
                rm -f "/etc/one-click/sites/${domain}/www/robots.txt"
                success "${green}[+]${reset} Automation removed"
                ;;
              2)
                warn "${yellow}[*]${reset} Regenerating sitemap and robots site."
                sitemap_robots "$domain" "/etc/one-click/sites/${domain}/www"
                success "${green}[+]${reset} Regeneration complete"
                ;;
              3)
                warn "${yellow}[*] Going back${red}.${magenta}.${orange}.${reset}"
                break
                ;;
              *)
                error "[!] Invalid option. Please choose 1-3."
                ;;
            esac
            echo ""
          done
        else
          read -rp "${cyan}[USER]${reset} Please confirm you'd like to generate a robots and sitemap file and automate crawling weekly to check for updates to submit to Google (y|n): " add_sitemap
          add_sitemap="${add_sitemap,,}"
          if [[ "$add_sitemap" == "y" || "$add_sitemap" == "yes" ]]; then
            sitemap_robots $domain /etc/one-click/sites/${domain}/www
          fi
        fi
        ;;
      9) check_permissions "$domain" "${wpstatic:-}" ;;
      10) delete_site "$domain" ;;
      11) web_logs ;;
      0)
        error "Exiting."
        ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
        ;;
      *) error "Invalid option" ;;
    esac
  done
}
central_menu() {
  local choice
  wpstatic="${1:-}"
  if [[ "${wpstatic:-}" == "wordpress" ]]; then
    config_dir="$base/wordpress/config"
    profiles_file="$config_dir/remotes.conf"
    map_file="$config_dir/domain_map.conf"
    current_profile_file="$config_dir/current_profile"
    mkdir -p "$config_dir" && touch "$map_file" "$profiles_file"
  else
    config_dir="$base/sites/config"
    profiles_file="$config_dir/remotes.conf"
    map_file="$config_dir/domain_map.conf"
    current_profile_file="$config_dir/current_profile"
    mkdir -p "$config_dir" && touch "$map_file" "$profiles_file"
  fi
  main_board
}
wp_restore_interactive() {
  central_menu wordpress
}
wp_restore_int() {
  local backup_base backups i choice
  backup_base="/etc/one-click/wordpress/backups/$domain"
  mapfile -t backups < <(find "$backup_base" -mindepth 1 -maxdepth 1 -type d | sort)
  if [[ ${#backups[@]} -eq 0 ]]; then
    error "No backups found for $domain"
    return 1
  fi
  printf '%s\n'  " " " " "${blue}Available backups for $domain:${reset}" " "
  printf "${magenta}%-3s ${blue}|${yellow} %s${reset}\n" "No" "Timestamp"
  echo "${blue}------------------------${reset}"
  for i in "${!backups[@]}"; do
    printf "${magenta}%-3s${blue} | ${yellow}%s${reset}\n" "$((i+1))" "$(basename "${backups[$i]}")"
  done
  read -rp "${cyan}[USER]${blue} Select a backup number to restore: ${reset}" choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#backups[@]})); then
    error "Invalid selection"
    return 1
  fi
  backup_dir="${backups[$((choice-1))]}"
  wp_restore "$domain" "$backup_dir"
}
# ==== Install WP-CLI ====
install_wp_cli() {
  # The WP-CLI invocation in One-Click always uses this managed PHAR location.
  # Do not treat a different `wp` executable in PATH as proof it exists here.
  local target="/usr/local/bin/wp" tmp=""
  if [[ -s "$target" ]]; then
    php "$target" --info >/dev/null 2>&1 || {
      error "Installed WP-CLI PHAR at $target failed validation. It was not overwritten."
      return 1
    }
    return 0
  fi
  tmp="$(mktemp /tmp/one-click-wp-cli.XXXXXXXX.phar)" || return 1
  if ! curl -fLsS --retry 2 \
       https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
       -o "$tmp" || [[ ! -s "$tmp" ]] || ! php "$tmp" --info >/dev/null 2>&1; then
    rm -f -- "$tmp"
    error "WP-CLI download/PHAR validation failed; refusing to install an unusable executable."
    return 1
  fi
  if ! install -m 0755 "$tmp" "$target"; then
    rm -f -- "$tmp"
    error "Could not install WP-CLI at $target."
    return 1
  fi
  rm -f -- "$tmp"
}

# ==== Configure DB ====
install_db() {
  info "Updating System"
  "$pkg_mgr" -y update 2> /dev/null
  info "Installing dependencies"
  "$pkg_mgr" install -y \
   mariadb-server \
  php-fpm \
  php-posix \
  unzip \
  curl &> /dev/null
}
configure_nc_db() {
  provision_success=0
  local nc_db="one_click:${domain//./-}:$(openssl rand -hex 4):$nc_db_user"
  local user_exists
  local sql_password="${nc_db_pass//\\/\\\\}"
  sql_password="${sql_password//\'/\'\'}"
  [[ -n "$nc_db_user" && -n "$nc_db_pass" ]] || {
    error "Nextcloud database credentials are incomplete."
    return 1
  }
  if grep -q '^DB_NAME=' "/etc/one-click/nextcloud/$domain/meta.conf"; then
    sed -i "s|^DB_NAME=.*|DB_NAME=$nc_db|" "/etc/one-click/nextcloud/$domain/meta.conf"
  else
    echo "DB_NAME=$nc_db" >> "/etc/one-click/nextcloud/$domain/meta.conf"
  fi
  install_db
  systemctl is-enabled --quiet mariadb || systemctl enable mariadb
  systemctl is-active --quiet mariadb || systemctl start mariadb
  mysql -e "CREATE DATABASE IF NOT EXISTS \`$nc_db\`;"
  user_exists="$(mysql -sN -e "SELECT 1 FROM mysql.user WHERE user='${nc_db_user}' AND host='localhost' LIMIT 1;")"
  if [[ "$user_exists" != "1" ]]; then
    mysql -e "CREATE USER '${nc_db_user}'@'localhost' IDENTIFIED BY '${sql_password}';"
  fi
  if ! mysql -e "GRANT ALL PRIVILEGES ON \`$nc_db\`.* TO '${nc_db_user}'@'localhost'; FLUSH PRIVILEGES;"; then
    warn "$nc_db_user already has required privileges on $nc_db"
  fi
  db_write_user_password "$domain" "$nc_db_user" "$nc_db_pass" || return 1
  db_write_password "$domain" "$nc_db_pass" || return 1
  sed -i '/^DB_PASS=/d;/^NC_PASS=/d' "/etc/one-click/nextcloud/$domain/meta.conf"
}
configure_db() {
  provision_success=0
  local db="one_click:${domain}:$(openssl rand -hex 4):$dbuser"
  local user_exists="" sql_password="" meta="/etc/one-click/wordpress/$domain/meta.conf"
  # Protect the SQL identifier and literal contexts without changing the
  # existing One-Click database naming convention.
  if [[ ! "$dbuser" =~ ^[A-Za-z0-9_]+$ || -z "$dbpass" || ${#db} -gt 64 ]]; then
    error "Invalid database user/password or generated database name is longer than 64 characters."
    return 1
  fi
  sql_password="${dbpass//\\/\\\\}"
  sql_password="${sql_password//\'/\'\'}"
  [[ -f "$meta" ]] || { error "WordPress metadata is missing: $meta"; return 1; }
  if ! systemctl is-active --quiet mariadb && ! systemctl start mariadb; then
    error "MariaDB could not be started."
    return 1
  fi
  if mysql -Nse "SELECT SCHEMA_NAME FROM information_schema.schemata WHERE SCHEMA_NAME='$db'" | grep -Fxq "$db"; then
    error "The generated WordPress database already exists. Refusing to reuse it."
    return 1
  fi
  if ! mysql -e "CREATE DATABASE \`$db\`;"; then
    error "Could not create the WordPress database."
    return 1
  fi
  ONECLICK_WP_CREATED_DB="$db"
  user_exists="$(mysql -sN -e "SELECT 1 FROM mysql.user WHERE user='${dbuser}' AND host='localhost' LIMIT 1;")" || return 1
  if [[ "$user_exists" != "1" ]]; then
    if ! mysql -e "CREATE USER '${dbuser}'@'localhost' IDENTIFIED BY '${sql_password}';"; then
      error "Could not create the WordPress database account."
      return 1
    fi
    ONECLICK_WP_CREATED_DB_USER="$dbuser"
  fi
  if ! mysql -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '${dbuser}'@'localhost'; FLUSH PRIVILEGES;"; then
    error "Could not grant WordPress database privileges."
    return 1
  fi
  # Authentication must work before WP-CLI attempts the core installation.
  if ! MYSQL_PWD="$dbpass" mysql -h localhost -u "$dbuser" -Nse 'SELECT 1' "$db" >/dev/null; then
    error "WordPress database account cannot authenticate to its database."
    return 1
  fi
  db_write_user_password "$domain" "$dbuser" "$dbpass" || return 1
  db_write_password "$domain" "$dbpass" || return 1
  if grep -q '^DB_NAME=' "$meta"; then
    sed -i "s|^DB_NAME=.*|DB_NAME=$db|" "$meta" || return 1
  else
    printf 'DB_NAME=%s\n' "$db" >> "$meta" || return 1
  fi
  sed -i '/^DB_PASS=/d' "$meta" || return 1
  DB_NAME="$db"
  return 0
}

# ==== Download WP ====
download_wp() {
  . /etc/one-click/wordpress/$domain/meta.conf
  if [[ -f "${site}/wp-config.php" ]]; then
    warn "WordPress already exists at $site"
    read -rp "${cyan}[USER]${reset} Skip WP installation and continue (y|n)? " choice
    choice="${choice,,}"
    [[ "$choice" =~ ^[Yy]$ || "$choice" == "yes" ]] && return
    info "Backing up existing wp-config.php"
    cp "$site/wp-config.php" "$site/wp-config.php.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$site"
  sed -Ei 's/(memory_limit = ).*/\11024M/' /etc/one-click/php/${domain}/php.ini
  chown "$web_user":"${webserver_user:-${webserver}}" "$site"
  cd "$site" || return
  if [[ ! -f "${site}/wp-config.php" ]]; then
    if ! $wp_cmd core download ; then
      error "wp core download failed to unpack."
      return 1
    fi
  fi
  # ==== Ensure mysqli in the isolated site runtime ====
  local site_php_cli
  site_php_cli="$(site_php_cli_bin "$domain")" || return 1
  if ! "$site_php_cli" -m | grep -qi '^mysqli$'; then
    error "The isolated PHP runtime for $domain does not provide mysqli."
    return 1
  fi
  # ==== Configure WP ====
  if ! $wp_cmd config create \
    --dbname="$DB_NAME" \
    --dbuser="$dbuser" \
    --dbpass="$dbpass"; then
    error "WP-CLI could not write wp-config.php."
    return 1
  fi
}
# ==== Install ====
install_wp() {
  if $wp_cmd core is-installed >/dev/null 2>&1; then
    warn "WordPress already installed, skipping install"
  else
    if ! $wp_cmd core install \
      --url="http://$domain" \
      --title="$title" \
      --admin_user="$admin" \
      --admin_password="$pass" \
      --admin_email="$email"; then
      error "WP-CLI core install failed."
      return 1
    fi
  fi
  if ! $wp_cmd core is-installed >/dev/null 2>&1; then
    error "WordPress did not pass the installation verification."
    return 1
  fi
}
# ==== Harden ====
harden_wp() {
  $wp_cmd config set DISALLOW_FILE_EDIT true --raw
  $wp_cmd config shuffle-salts
  chown -R "$web_user":"$webserver_user" /etc/one-click/wordpress/$domain/www
  find /etc/one-click/wordpress/$domain/www -type d -exec chmod 755 {} \;
  find /etc/one-click/wordpress/$domain/www -type f -exec chmod 644 {} \;
}
####################### MOVE TO FUNCTIONS ############################
draw_box() {
  local title line max_len lines width bar
  title="$1"
  shift
  lines=("$@")
  max_len=${#title}
  for line in "${lines[@]}"; do
    (( ${#line} > max_len )) && max_len=${#line}
  done
  width=$((max_len + 25))
  printf -v bar '%*s' "$width" ''
  bar=${bar// /═}
  echo -e "\e[34m╔${bar}╗\e[0m"
  printf "\e[34m║ %-*s ║\e[0m\n" "$((width+13))" "$title"
  echo -e "\e[34m╠${bar}╣\e[0m"
  for line in "${lines[@]}"; do
    printf "\e[34m║ %-*s ║\e[0m\n" "$((width+13))" "$line"
  done
  echo -e "\e[34m╚${bar}╝\e[0m"
}
####################################
# ==== Plugins ====
wp_plugins() {
  if ! $wp_cmd plugin install wordfence wp-super-cache --activate; then
    warn "Failed to install one or more baseline WordPress plugins."
  fi
  if [[ "${enable_redis,,}" != "y" && "${enable_redis,,}" != "yes" ]]; then
    return 0
  fi
  info "Installing and configuring isolated Redis/Valkey for $domain."
  setup_redis "$domain" || return 1
  redis_service "$domain" || return 1
  systemctl enable --now "$service" || {
    error "Failed to start isolated Redis service $service."
    journalctl -u "$service" -n 30 --no-pager 2>/dev/null || true
    return 1
  }
  for _ in {1..20}; do
    [[ -S "$sock" ]] && break
    sleep 0.25
  done
  [[ -S "$sock" ]] || {
    error "Redis socket was not created: $sock"
    return 1
  }
  if ! REDISCLI_AUTH="$redis_pw" \
    "$(command -v redis-cli || command -v valkey-cli)" \
    -s "$sock" ping 2>/dev/null | grep -qx 'PONG'; then
    error "Isolated Redis/Valkey instance failed its readiness check."
    return 1
  fi
  $wp_cmd plugin install redis-cache --activate || warn "Redis cache plugin installation failed."
  $wp_cmd config set WP_REDIS_SCHEME unix || warn "Could not set WP_REDIS_SCHEME."
  $wp_cmd config set WP_REDIS_PATH "$sock" || warn "Could not set WP_REDIS_PATH."
  $wp_cmd config set WP_REDIS_PASSWORD "$redis_pw" || warn "Could not set WP_REDIS_PASSWORD."
  systemctl restart "php-fpm@${domain}.service" || warn "Could not restart the site PHP-FPM service after Redis configuration."
  if ! $wp_cmd redis enable; then
    warn "WordPress Redis object cache could not be enabled."
  fi
  success "Isolated Redis/Valkey cache configured for $domain."
}
# ==== REDIS ====
setup_redis() {
  local domain="$1"
  local meta=""
  local engine=""
  local redis_root="/etc/one-click/redis"
  local config_root=""
  local data_dir=""
  local runtime_root=""
  local native_conf=""
  local native_data=""
  [[ -n "$domain" ]] || {
    error "Redis setup requires a domain."
    return 1
  }
  [[ -n "${web_user:-}" ]] && id "$web_user" >/dev/null 2>&1 || {
    error "Redis setup requires a valid site runtime user."
    return 1
  }
  if [[ -f "/etc/one-click/wordpress/${domain}/meta.conf" ]]; then
    meta="/etc/one-click/wordpress/${domain}/meta.conf"
  elif [[ -f "/etc/one-click/nextcloud/${domain}/meta.conf" ]]; then
    meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  else
    error "No supported site metadata found for Redis runtime: $domain"
    return 1
  fi
  if command -v redis-server >/dev/null 2>&1; then
    engine="redis"
  elif command -v valkey-server >/dev/null 2>&1; then
    engine="valkey"
  else
    if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
      "$pkg_mgr" install -y redis-server >/dev/null 2>&1 || \
      "$pkg_mgr" install -y valkey >/dev/null 2>&1 || {
        error "Failed to install Redis or Valkey."
        return 1
      }
    else
      "$pkg_mgr" install -y redis >/dev/null 2>&1 || \
      "$pkg_mgr" install -y valkey >/dev/null 2>&1 || {
        error "Failed to install Redis or Valkey."
        return 1
      }
    fi
    command -v redis-server >/dev/null 2>&1 && engine="redis"
    [[ -z "$engine" ]] && command -v valkey-server >/dev/null 2>&1 && engine="valkey"
  fi
  case "$engine" in
    redis)
      redis_execstart="$(command -v redis-server)"
      redis_user="redis"
      config_root="/etc/redis/one-click"
      data_dir="/var/lib/redis/one-click/${domain}"
      runtime_root="/run/one-click-redis-${domain}"
      native_conf="/etc/redis/redis.conf"
      native_data="/var/lib/redis"
      ;;
    valkey)
      redis_execstart="$(command -v valkey-server)"
      redis_user="valkey"
      config_root="/etc/valkey/one-click"
      data_dir="/var/lib/valkey/one-click/${domain}"
      runtime_root="/run/one-click-redis-${domain}"
      native_conf="/etc/valkey/valkey.conf"
      native_data="/var/lib/valkey"
      ;;
    *)
      error "No Redis-compatible server executable is available."
      return 1
      ;;
  esac
  getent passwd "$redis_user" >/dev/null 2>&1 || {
    error "Runtime account '$redis_user' was not created by the package."
    return 1
  }
  site_php_install_redis_extension "$domain" || return 1
  redis_pw="${redis_pw:-$(openssl rand -base64 32 | tr -d '\n')}"
  service="redis-${domain}"
  conf="${config_root}/${domain}.conf"
  sock="${runtime_root}/redis.sock"
  redis_password_file="${redis_root}/${domain}.pass"
  install -d -m 0700 -o root -g root "$redis_root"
  install -d -m 0750 -o root -g "$redis_user" "$config_root"
  install -d -m 0750 -o "$redis_user" -g "$web_user" "$data_dir"
  printf '%s\n' "$redis_pw" > "$redis_password_file"
  chown root:root "$redis_password_file"
  chmod 0600 "$redis_password_file"
  cat > "$conf" <<EOF
bind 127.0.0.1
port 0
protected-mode yes
requirepass $redis_pw
unixsocket $sock
unixsocketperm 0770
dir $data_dir
maxmemory 512mb
maxmemory-policy allkeys-lru
daemonize no
supervised systemd
EOF
  chown "$redis_user:root" "$conf"
  chmod 0600 "$conf"
  if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
    if command -v restorecon >/dev/null 2>&1; then
      restorecon -RF "$config_root" "$data_dir" >/dev/null 2>&1 || true
    fi
    if command -v chcon >/dev/null 2>&1; then
      [[ -e "$native_conf" ]] && chcon --reference="$native_conf" "$config_root" "$conf" >/dev/null 2>&1 || true
      [[ -e "$native_data" ]] && chcon --reference="$native_data" "$data_dir" >/dev/null 2>&1 || true
    fi
  fi
  [[ -r "$conf" ]] || {
    error "Redis/Valkey configuration is not readable: $conf"
    return 1
  }
  for pair in \
    "REDIS_ENABLED=true" \
    "REDIS_ENGINE=$engine" \
    "REDIS_USER=$redis_user" \
    "REDIS_SERVICE=$service" \
    "REDIS_CONF=$conf" \
    "REDIS_SOCK=$sock" \
    "REDIS_PASS_FILE=$redis_password_file" \
    "REDIS_DATA_DIR=$data_dir"; do
    key="${pair%%=*}"
    if grep -q "^${key}=" "$meta"; then
      sed -i "s|^${key}=.*|${pair}|" "$meta"
    else
      echo "$pair" >> "$meta"
    fi
  done
  return 0
}
redis_service() {
  local domain="$1"
  local unit="/etc/systemd/system/redis-${domain}.service"
  [[ -n "${redis_execstart:-}" && -x "${redis_execstart:-}" ]] || {
    error "Redis/Valkey executable has not been resolved."
    return 1
  }
  [[ -n "${conf:-}" && -f "${conf:-}" ]] || {
    error "Redis/Valkey configuration is missing."
    return 1
  }
  [[ -n "${redis_user:-}" && -n "${web_user:-}" ]] || {
    error "Redis runtime ownership is incomplete."
    return 1
  }
  cat > "$unit" <<EOF
[Unit]
Description=One-Click Redis-compatible instance for ${domain}
After=network.target

[Service]
Type=notify
ExecStart=$redis_execstart $conf
User=$redis_user
Group=$web_user
SupplementaryGroups=$redis_user
RuntimeDirectory=one-click-redis-${domain}
RuntimeDirectoryMode=0770
ExecStartPre=/usr/bin/test -r $conf
UMask=0007
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload || return 1
}
redis_menu() {
  local instance_service="redis-${domain}"
  local meta=""
  local instance_sock=""
  local instance_conf=""
  local passfile=""
  local password=""
  local cli=""
  if [[ -f "/etc/one-click/wordpress/${domain}/meta.conf" ]]; then
    meta="/etc/one-click/wordpress/${domain}/meta.conf"
  elif [[ -f "/etc/one-click/nextcloud/${domain}/meta.conf" ]]; then
    meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  else
    error "Redis metadata not found for $domain."
    return 0
  fi
  . "$meta"
  instance_service="${REDIS_SERVICE:-$instance_service}"
  instance_sock="${REDIS_SOCK:-}"
  instance_conf="${REDIS_CONF:-}"
  passfile="${REDIS_PASS_FILE:-/etc/one-click/redis/${domain}.pass}"
  [[ -S "$instance_sock" || -n "$instance_sock" ]] || {
    error "Redis socket path is not configured for $domain."
    return 0
  }
  [[ -f "$instance_conf" ]] || {
    error "Redis configuration not found: $instance_conf"
    return 0
  }
  [[ -f "$passfile" ]] && password="$(<"$passfile")"
  if command -v redis-cli >/dev/null 2>&1; then
    cli="$(command -v redis-cli)"
  elif command -v valkey-cli >/dev/null 2>&1; then
    cli="$(command -v valkey-cli)"
  else
    error "No Redis-compatible CLI is available."
    return 0
  fi
  while true; do
    local status_raw status_tbl usage max_mem
    status_raw="$(systemctl is-active "$instance_service" 2>/dev/null || true)"
    max_mem="$(awk '$1=="maxmemory"{print $2; exit}' "$instance_conf" 2>/dev/null)"
    max_mem="${max_mem:-N/A}"
    if [[ "$status_raw" == "active" ]]; then
      status_tbl="${green}ACTIVE${reset}"
      usage="$(
        REDISCLI_AUTH="$password" "$cli" -s "$instance_sock" info memory 2>/dev/null |
          awk -F: '/^used_memory_human:/{gsub("\r","",$2);print $2;exit}'
      )"
      usage="${usage:-N/A}"
    else
      status_tbl="${red}INACTIVE${reset}"
      usage="N/A"
    fi
    clear
    printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
    printf "${blue}║${reset}  ${magenta}REDIS MANAGEMENT:${reset} %-49s ${blue}║${reset}\n" "$domain"
    printf "${blue}╠══════════════════════╦══════════════════════╦════════════════════════╣${reset}\n"
    printf "${blue}║${reset} ${cyan}STATUS:${reset} %-22b ${blue}║${reset} ${cyan}USED:${reset} %-14s ${blue}║${reset} ${cyan}LIMIT:${reset} %-15s ${blue}║${reset}\n" \
      "$status_tbl" "$usage" "${max_mem^^}"
    printf "${blue}╚══════════════════════╩══════════════════════╩════════════════════════╝${reset}\n"
    printf '%s\n' \
      "  ${yellow}1)${reset} Start Instance        ${yellow}5)${reset} Edit Config (Manual)" \
      "  ${yellow}2)${reset} Stop Instance         ${yellow}6)${reset} Set Max Memory" \
      "  ${yellow}3)${reset} Restart Instance      ${yellow}7)${reset} Flush All Cache" \
      "  ${yellow}4)${reset} View Live Logs        ${yellow}0)${reset} Back"
    read -rp "Select an option: " rchoice
    case "$rchoice" in
      1) systemctl start "$instance_service" ;;
      2) systemctl stop "$instance_service" ;;
      3) systemctl restart "$instance_service" ;;
      4)
        journalctl -u "$instance_service" -n 50 --no-pager
        read -rp "Press Enter to continue."
        ;;
      5)
        nano "$instance_conf" && systemctl restart "$instance_service"
        ;;
      6)
        read -rp "Enter new memory limit (e.g. 256mb): " new_limit
        if [[ ! "$new_limit" =~ ^[1-9][0-9]*(kb|mb|gb)$ ]]; then
          error "Invalid memory value."
        else
          sed -i "s/^maxmemory .*/maxmemory $new_limit/" "$instance_conf"
          systemctl restart "$instance_service" && success "Memory updated to $new_limit"
        fi
        ;;
      7)
        if [[ "$status_raw" == "active" ]]; then
          if REDISCLI_AUTH="$password" "$cli" -s "$instance_sock" flushall >/dev/null; then
            success "Redis cache for $domain cleared."
          else
            error "Redis cache flush failed."
          fi
        else
          error "Cannot flush: Service is not running."
        fi
        sleep 1
        ;;
      0) return 0 ;;
      *) invalid_opt ;;
    esac
  done
}
# ==== WP Staging ====
# Clone WordPress into a private temporary directory, then publish it only after
# its database and core have been verified.  A pre-existing stage is never overwritten.
wp_staging() (
  local domain="${1:-${domain:-}}"
  local prod="/etc/one-click/wordpress/$domain"
  local staging_root="/etc/one-click/wordpress/staging"
  local stage="$staging_root/$domain"
  local meta="$prod/meta.conf"
  local work_dir="" dump="" db_user="" db_host="" stage_db="" existing=""
  local user="" group="" db_created=0 committed=0

  if [[ ! "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ || "$domain" == *..* ]]; then
    error "Invalid WordPress domain for staging."
    return 1
  fi
  if [[ ! -s "$prod/www/wp-load.php" || ! -s "$prod/wp-config.php" || ! -f "$meta" ]]; then
    error "Production WordPress core, wp-config.php or metadata is missing for $domain; no staging changes made."
    return 1
  fi
  if [[ -e "$stage" || -L "$stage" ]]; then
    error "Staging path already exists at $stage. It was left untouched; inspect or delete it using the staging menu before recreating."
    return 1
  fi
  # Metadata is created by the original One-Click WordPress installer.
  . "$meta"
  user="${SITE_USER:-}"
  group="${SITE_GROUP:-${webserver_user:-}}"
  if [[ -z "$user" || -z "$group" ]] || ! id "$user" >/dev/null 2>&1; then
    error "Missing or invalid WordPress staging owner/group for $domain."
    return 1
  fi
  if ! wp_staging_cli "$domain" "$user" "$prod/www" core is-installed >/dev/null 2>&1; then
    error "Production WordPress is not installed or WP-CLI cannot load it. Aborting before cloning."
    return 1
  fi
  db_user="$(wp_staging_cli "$domain" "$user" "$prod/www" config get DB_USER --type=constant 2>/dev/null)" || return 1
  db_host="$(wp_staging_cli "$domain" "$user" "$prod/www" config get DB_HOST --type=constant 2>/dev/null)" || return 1
  case "$db_host" in
    localhost|127.0.0.1|localhost:3306|127.0.0.1:3306) ;;
    *) error "Staging currently requires a local MariaDB database; DB_HOST=$db_host. No changes made."; return 1 ;;
  esac
  if [[ -z "$db_user" || ! "$db_user" =~ ^[A-Za-z0-9_@.%+-]+$ ]]; then
    error "The production database account cannot be safely resolved."
    return 1
  fi
  mkdir -p "$staging_root" || return 1
  work_dir="$(mktemp -d "$staging_root/.${domain}.build.XXXXXXXX")" || return 1
  # Only the temporary directory and database created in this invocation may
  # be cleaned up on failure; production and existing staging are never deleted.
  trap 'if (( ! committed )); then
          [[ -z "$work_dir" || ! -d "$work_dir" ]] || rm -rf -- "$work_dir"
          if (( db_created )) && [[ "$stage_db" =~ ^stage_[a-f0-9]{12}$ ]]; then
            mysql -e "DROP DATABASE IF EXISTS \`$stage_db\`" >/dev/null 2>&1 || true
          fi
        fi' EXIT
  info "Copying production WordPress files to a temporary staging location"
  if ! rsync -a -- "$prod/" "$work_dir/"; then
    error "Staging file copy failed. Production has not been modified."
    return 1
  fi
  chmod 0700 "$work_dir" || return 1
  chown -R "$user:$group" "$work_dir" || return 1
  if [[ ! -s "$work_dir/www/wp-load.php" || ! -s "$work_dir/wp-config.php" ]]; then
    error "Staging file copy is incomplete: WordPress core or configuration is missing."
    return 1
  fi
  dump="$work_dir/.one-click-source.sql"
  if ! wp_staging_cli "$domain" "$user" "$prod/www" db export "$dump" || [[ ! -s "$dump" ]]; then
    error "Production database export failed; no database has been created."
    return 1
  fi
  stage_db="stage_$(openssl rand -hex 6)" || return 1
  if [[ ! "$stage_db" =~ ^stage_[a-f0-9]{12}$ ]]; then
    error "Invalid generated staging database name."
    return 1
  fi
  if ! mysql -e "CREATE DATABASE \`$stage_db\`"; then
    error "Could not create a staging database; no existing database was overwritten."
    return 1
  fi
  db_created=1
  if ! mysql -e "GRANT ALL PRIVILEGES ON \`$stage_db\`.* TO '$db_user'@'localhost'"; then
    error "Staging database grant failed. Database will be removed."
    return 1
  fi
  # Critical ordering: change the *cloned* wp-config.php before importing,
  # otherwise WP-CLI would import into the production database.
  if ! wp_staging_cli "$domain" "$user" "$work_dir/www" config set DB_NAME "$stage_db" --type=constant; then
    error "Could not point the cloned WordPress configuration at the staging database."
    return 1
  fi
  existing="$(wp_staging_cli "$domain" "$user" "$work_dir/www" config get DB_NAME --type=constant 2>/dev/null)" || return 1
  if [[ "$existing" != "$stage_db" ]]; then
    error "Staging wp-config.php did not retain the new database; import aborted to protect production."
    return 1
  fi
  if ! wp_staging_cli "$domain" "$user" "$work_dir/www" db import "$dump"; then
    error "Staging database import failed. Production is untouched."
    return 1
  fi
  if ! wp_staging_cli "$domain" "$user" "$work_dir/www" core is-installed >/dev/null 2>&1; then
    error "Cloned WordPress did not pass the core installation check."
    return 1
  fi
  # HTTP must be valid even when the staging DNS/ACME check is unavailable.
  if ! wp_staging_cli "$domain" "$user" "$work_dir/www" search-replace "https://$domain" "http://staging.$domain" --skip-columns=guid ||
     ! wp_staging_cli "$domain" "$user" "$work_dir/www" search-replace "http://$domain" "http://staging.$domain" --skip-columns=guid ||
     ! wp_staging_cli "$domain" "$user" "$work_dir/www" option update home "http://staging.$domain" ||
     ! wp_staging_cli "$domain" "$user" "$work_dir/www" option update siteurl "http://staging.$domain"; then
    error "Staging URL migration failed. Incomplete stage will not be published."
    return 1
  fi
  # The managed WordPress configuration may pin its content URL separately.
  if grep -q 'WP_CONTENT_URL' "$work_dir/wp-config.php"; then
    if ! wp_staging_cli "$domain" "$user" "$work_dir/www" config set WP_CONTENT_URL "http://staging.$domain/wp-content" --type=constant; then
      error "Could not update the cloned content URL."
      return 1
    fi
  fi
  rm -f -- "$dump"
  chmod 0755 "$work_dir" || return 1
  if ! mv -- "$work_dir" "$stage"; then
    error "Could not publish the verified staging directory."
    return 1
  fi
  committed=1
  success "Staging WordPress and isolated database created at $stage (HTTP; HTTPS is a separate step)."
  return 0
)
wp_staging_push() {
  # Previous implementation rsync --delete'd the stage over production and
  # then exported/imported production's own DB, risking irreversible loss.
  # No destructive action is allowed until push has a verified transaction.
  error "Staging push is disabled: the legacy implementation can overwrite production with incomplete staging data."
  warn "No production files or databases were changed. Use verified backup/restore procedures instead."
  return 0
}

staging_vhost_nginx() {
  local domain="$1"
  local stage_root="/etc/one-click/wordpress/staging/$domain/www"
  local conf enabled_conf=""
  [[ -d "$stage_root" ]] || {
    error "Staging document root is missing: $stage_root"
    return 1
  }
  if [[ -d /etc/nginx/sites-available ]]; then
    conf="/etc/nginx/sites-available/staging.${domain}.conf"
    enabled_conf="/etc/nginx/sites-enabled/staging.${domain}.conf"
  else
    conf="/etc/nginx/conf.d/staging.${domain}.conf"
  fi
  mkdir -p "/var/log/one-click/${domain}/nginx"
  cat > "$conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name staging.$domain;

    access_log /var/log/one-click/${domain}/nginx/staging_access.log oneclick;
    error_log /var/log/one-click/${domain}/nginx/staging_error.log warn;

    root $stage_root;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/one-click/${domain}/php.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires max;
        log_not_found off;
    }
}
EOF
  [[ -n "$enabled_conf" ]] && ln -sfn "$conf" "$enabled_conf"
  if ! nginx -t >/dev/null 2>&1; then
    rm -f "$conf"
    [[ -n "$enabled_conf" ]] && rm -f "$enabled_conf"
    error "Staging Nginx configuration failed validation."
    return 1
  fi
  systemctl reload nginx >/dev/null 2>&1 || return 1
  return 0
}
enable_staging_ssl() {
  local domain="$1"
  local staging_domain="staging.$domain"
  local local_v4="${sys_ip:-}"
  local local_v6="${sys_ipv6:-}"
  local_v6="${local_v6%%/*}"
  local matched=0 answer plugin service le_email="${email:-}" dns_records=""
  dns_records="$({ dig +short A "$staging_domain" 2>/dev/null; dig +short AAAA "$staging_domain" 2>/dev/null; } | sort -u)"
  if [[ -z "$dns_records" ]]; then
    warn "$staging_domain has no public A/AAAA DNS record; HTTPS provisioning deferred."
    return 1
  fi
  while IFS= read -r answer; do
    if [[ -n "$local_v4" && "$answer" == "$local_v4" ]] || \
       [[ -n "$local_v6" && "$answer" == "$local_v6" ]]; then
      matched=1
      break
    fi
  done <<< "$dns_records"
  if (( ! matched )); then
    warn "$staging_domain resolves through other IPs (possible proxy/NAT). Attempting ACME instead of incorrectly rejecting DNS."
  fi
  if [[ -z "$le_email" && -f "/etc/one-click/wordpress/$domain/meta.conf" ]]; then
    . "/etc/one-click/wordpress/$domain/meta.conf"
    if [[ -n "${SITE_USER:-}" ]]; then
      local wp_cmd="$(site_wp_cli_command "$domain" "$SITE_USER" "/etc/one-click/wordpress/$domain/www")" || return 1
      le_email=$($wp_cmd option get admin_email 2>/dev/null || true)
    fi
  fi
  while [[ -z "$le_email" || ! "$le_email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; do
    read -rp "${cyan}[USER]${blue} Email for staging certificate:${reset} " le_email
  done
  "$pkg_mgr" install -y certbot >/dev/null 2>&1 || {
    error "Failed to install Certbot."
    return 1
  }
  case "$webserver" in
    nginx)
      plugin="python3-certbot-nginx"
      service="nginx"
      "$pkg_mgr" install -y "$plugin" >/dev/null 2>&1 || return 1
      certbot --nginx -d "$staging_domain" --non-interactive --agree-tos \
        -m "$le_email" --redirect || return 1
      nginx -t >/dev/null 2>&1 || return 1
      ;;
    apache|apache2|httpd)
      plugin="python3-certbot-apache"
      "$pkg_mgr" install -y "$plugin" >/dev/null 2>&1 || return 1
      certbot --apache -d "$staging_domain" --non-interactive --agree-tos \
        -m "$le_email" --redirect || return 1
      if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
        service="apache2"
        apache2ctl configtest >/dev/null 2>&1 || return 1
      else
        service="httpd"
        httpd -t >/dev/null 2>&1 || return 1
      fi
      ;;
    *)
      error "Unsupported webserver '$webserver' for staging SSL."
      return 1
      ;;
  esac
  systemctl reload "$service" >/dev/null 2>&1 || return 1
  letsencrypt_autorenew
  return 0
}
default_nginx() {
  local conf enabled_conf=""
  mkdir -p /etc/ssl/private /etc/ssl/certs
  if [[ -d /etc/nginx/sites-available ]]; then
    conf="/etc/nginx/sites-available/00-default.conf"
    enabled_conf="/etc/nginx/sites-enabled/00-default.conf"
    mkdir -p /etc/nginx/sites-enabled
  else
    conf="/etc/nginx/conf.d/00-default.conf"
  fi
  if [[ ! -s /etc/ssl/private/ssl-cert-default_site.key || \
        ! -s /etc/ssl/certs/ssl-cert-default_site.pem ]]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
      -keyout /etc/ssl/private/ssl-cert-default_site.key \
      -out /etc/ssl/certs/ssl-cert-default_site.pem \
      -subj "/CN=localhost" >/dev/null 2>&1 || {
        error "Failed to create the default Nginx certificate."
        return 1
      }
    chmod 600 /etc/ssl/private/ssl-cert-default_site.key
    chmod 644 /etc/ssl/certs/ssl-cert-default_site.pem
  fi
  cat > "$conf" <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}

server {
    listen 443 default_server ssl;
    listen [::]:443 default_server ssl;
    server_name _;
    ssl_certificate /etc/ssl/certs/ssl-cert-default_site.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-default_site.key;
    return 444;
}
EOF
  [[ -n "$enabled_conf" ]] && ln -sfn "$conf" "$enabled_conf"
  for i in /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/nginx/conf.d; do
    [[ -d "$i" ]] || continue
    find "$i" -maxdepth 1 -type l -name '*default*' ! -name '00-default.conf' -delete 2>/dev/null || true
  done
  if ! nginx -t >/dev/null 2>&1; then
    error "Default Nginx configuration failed validation."
    return 1
  fi
  systemctl enable --now nginx >/dev/null 2>&1 || return 1
  systemctl reload nginx >/dev/null 2>&1 || return 1
  return 0
}

staging_vhost_apache() {
  local domain="$1"
  local stage_root="/etc/one-click/wordpress/staging/$domain/www"
  local conf service
  [[ -d "$stage_root" ]] || {
    error "Staging document root is missing: $stage_root"
    return 1
  }
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    conf="/etc/apache2/sites-available/staging.${domain}.conf"
    service="apache2"
    mkdir -p "/var/log/one-click/${domain}/apache2"
    apache_log_dir="/var/log/one-click/${domain}/apache2"
  else
    conf="/etc/httpd/conf.d/staging.${domain}.conf"
    service="httpd"
    mkdir -p "/var/log/one-click/${domain}/httpd"
    apache_log_dir="/var/log/one-click/${domain}/httpd"
  fi
  cat > "$conf" <<EOF
<VirtualHost *:80>
    ServerName staging.$domain
    DocumentRoot $stage_root

    <Directory $stage_root>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/staging_error.log
    CustomLog ${apache_log_dir}/staging_access.log combined
</VirtualHost>
EOF
  if [[ "$service" == "apache2" ]]; then
    a2ensite "staging.${domain}.conf" >/dev/null 2>&1 || {
      rm -f "$conf"
      return 1
    }
    if ! apache2ctl configtest >/dev/null 2>&1; then
      a2dissite "staging.${domain}.conf" >/dev/null 2>&1 || true
      rm -f "$conf"
      error "Staging Apache configuration failed validation."
      return 1
    fi
  else
    if ! httpd -t >/dev/null 2>&1; then
      rm -f "$conf"
      error "Staging HTTPD configuration failed validation."
      return 1
    fi
  fi
  systemctl reload "$service" >/dev/null 2>&1 || return 1
  return 0
}
# Allow the WordPress staging document root through the *same site's*
# open_basedir and systemd sandbox. Existing PHP isolation remains in place.
wp_staging_runtime_access() {
  local domain="$1"
  local path="/etc/one-click/wordpress/staging/$domain"
  local pool="/etc/one-click/php/$domain/pool.conf"
  local unit="/etc/systemd/system/php-fpm@$domain.service"
  local backup="" changed=0
  [[ -d "$path/www" && -f "$pool" && -f "$unit" ]] || {
    error "Cannot verify PHP-FPM sandbox configuration for staging.$domain."
    return 1
  }
  grep -q '^php_admin_value\[open_basedir\] = ' "$pool" || {
    error "Missing site open_basedir configuration; refusing to weaken the sandbox."
    return 1
  }
  grep -q '^ReadWritePaths=' "$unit" || {
    error "Missing PHP-FPM read-write path configuration; refusing to change the sandbox."
    return 1
  }
  backup="$(mktemp -d)" || return 1
  chmod 0700 "$backup"
  cp -a "$pool" "$backup/pool.conf" && cp -a "$unit" "$backup/php-fpm.service" || {
    rm -rf -- "$backup"
    return 1
  }
  if ! grep -Fq "$path/:" "$pool"; then
    sed -i "s|^php_admin_value\[open_basedir\] = |php_admin_value[open_basedir] = ${path}/:|" "$pool" || return 1
    changed=1
  fi
  if ! grep -Fq -- "-$path" "$unit"; then
    sed -i "s|^ReadWritePaths=|ReadWritePaths=-${path} |" "$unit" || return 1
    changed=1
  fi
  # Restart also when a directory was newly created after the first FPM
  # start; this refreshes systemd's read-only /etc bind-mount rules.
  if ! systemctl daemon-reload || ! systemctl restart "php-fpm@$domain" ||
     ! systemctl is-active --quiet "php-fpm@$domain"; then
    cp -a "$backup/pool.conf" "$pool"
    cp -a "$backup/php-fpm.service" "$unit"
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart "php-fpm@$domain" >/dev/null 2>&1 || true
    rm -rf -- "$backup"
    error "Staging PHP-FPM sandbox update failed and original configuration was restored."
    return 1
  fi
  rm -rf -- "$backup"
  return 0
}
wp_staging_enable() {
  local domain="$1"
  local meta="/etc/one-click/wordpress/$domain/meta.conf"
  [[ -f "$meta" ]] && . "$meta"
  webserver="${WEBSERVER:-${webserver:-}}"
  if [[ ! -d "/etc/one-click/wordpress/staging/$domain/www" ]]; then
    wp_staging "$domain" || return 0
  fi
  local stage_site="/etc/one-click/wordpress/staging/$domain/www"
  local stage_user="${SITE_USER:-${web_user:-}}"
  if [[ ! -s "$stage_site/wp-load.php" || ! -s "/etc/one-click/wordpress/staging/$domain/wp-config.php" ]] ||
     [[ -z "$stage_user" ]] ||
     ! wp_staging_cli "$domain" "$stage_user" "$stage_site" core is-installed >/dev/null 2>&1; then
    error "Staging WordPress is incomplete. Refusing to activate a broken vhost."
    return 0
  fi
  # FPM is sandboxed: stage/www must be allowed both in open_basedir and
  # systemd ReadWritePaths before any staging PHP request can succeed.
  if ! wp_staging_runtime_access "$domain"; then
    error "Staging vhost was not activated because PHP-FPM cannot access the staging tree."
    return 0
  fi
  case "$webserver" in
    nginx) staging_vhost_nginx "$domain" || return 0 ;;
    apache|apache2|httpd) staging_vhost_apache "$domain" || return 0 ;;
    *) error "Unable to determine webserver for $domain."; return 0 ;;
  esac
  if ! enable_staging_ssl "$domain"; then
    warn "Staging HTTP vhost is active, but HTTPS provisioning was not completed for staging.$domain."
    return 0
  fi
  if ! wp_staging_cli "$domain" "$stage_user" "$stage_site" option update home "https://staging.$domain" ||
     ! wp_staging_cli "$domain" "$stage_user" "$stage_site" option update siteurl "https://staging.$domain"; then
    warn "TLS is active, but WordPress URL migration to HTTPS failed."
    return 0
  fi
  if grep -q 'WP_CONTENT_URL' "/etc/one-click/wordpress/staging/$domain/wp-config.php"; then
    wp_staging_cli "$domain" "$stage_user" "$stage_site" config set WP_CONTENT_URL "https://staging.$domain/wp-content" --type=constant || warn "Could not adjust the staging content URL for HTTPS."
  fi
  success "Staging enabled at ${cyan}https://staging.$domain${reset}"
  return 0
}
wp_staging_disable() {
  local domain="$1"
  local meta="/etc/one-click/wordpress/$domain/meta.conf"
  local service=""
  [[ -f "$meta" ]] && . "$meta"
  webserver="${WEBSERVER:-${webserver:-}}"
  rm -f \
    "/etc/nginx/sites-enabled/staging.${domain}.conf" \
    "/etc/nginx/sites-available/staging.${domain}.conf" \
    "/etc/nginx/conf.d/staging.${domain}.conf" \
    "/etc/nginx/sites-enabled/staging.${domain}-le-ssl.conf" \
    "/etc/nginx/sites-available/staging.${domain}-le-ssl.conf" \
    "/etc/nginx/conf.d/staging.${domain}-le-ssl.conf" \
    2>/dev/null || true

  if [[ -d /etc/apache2/sites-available ]]; then
    a2dissite "staging.${domain}.conf" >/dev/null 2>&1 || true
    a2dissite "staging.${domain}-le-ssl.conf" >/dev/null 2>&1 || true
  fi
  rm -f \
    "/etc/apache2/sites-enabled/staging.${domain}.conf" \
    "/etc/apache2/sites-available/staging.${domain}.conf" \
    "/etc/apache2/sites-enabled/staging.${domain}-le-ssl.conf" \
    "/etc/apache2/sites-available/staging.${domain}-le-ssl.conf" \
    "/etc/httpd/conf.d/staging.${domain}.conf" \
    "/etc/httpd/conf.d/staging.${domain}-le-ssl.conf" \
    2>/dev/null || true
  case "$webserver" in
    nginx)
      nginx -t >/dev/null 2>&1 || return 0
      service="nginx"
      ;;
    apache|apache2|httpd)
      if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
        apache2ctl configtest >/dev/null 2>&1 || return 0
        service="apache2"
      else
        httpd -t >/dev/null 2>&1 || return 0
        service="httpd"
      fi
      ;;
  esac
  if [[ -n "$service" ]]; then
    systemctl reload "$service" >/dev/null 2>&1 || {
      error "Failed to reload $service after disabling staging."
      return 0
    }
  fi
  success "Staging disabled for $domain"
  return 0
}
# The old menu referenced wp_staging_delete without implementing it.
# Quarantine instead of permanently deleting an unverified stage/database.
wp_staging_delete() {
  local domain="$1"
  local stage="/etc/one-click/wordpress/staging/$domain"
  local archived="/etc/one-click/wordpress/staging/.${domain}.quarantined.$(date +%Y%m%d%H%M%S).$$"
  local confirm=""
  if [[ ! "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ || "$domain" == *..* || ! -d "$stage" || -L "$stage" ]]; then
    error "No safe staging directory found for $domain."
    return 0
  fi
  warn "Delete Staging will disable the vhost and archive its files; it will NOT remove the staging database."
  read -rp "Type QUARANTINE to archive staging.$domain (anything else cancels): " confirm
  [[ "$confirm" == 'QUARANTINE' ]] || { info "Staging archive cancelled."; return 0; }
  wp_staging_disable "$domain"
  if ! mv -- "$stage" "$archived"; then
    error "Could not archive the staging files."
    return 0
  fi
  chmod 0700 "$archived" || warn "Could not restrict archived staging directory permissions."
  success "Staging files archived at $archived. The staging database, if any, was NOT deleted."
  return 0
}
staging_status() {
  local domain="$1"
  local stage_root="/etc/one-click/wordpress/staging/$domain/www"
  if [[ ! -d "$stage_root" ]]; then
    echo "OFF"
    return 0
  fi
  if [[ -f "/etc/nginx/sites-enabled/staging.${domain}.conf" || \
        -f "/etc/nginx/conf.d/staging.${domain}.conf" || \
        -f "/etc/apache2/sites-enabled/staging.${domain}.conf" || \
        -f "/etc/httpd/conf.d/staging.${domain}.conf" ]]; then
    echo "ON"
    return 0
  fi
  echo "OFF"
  return 0
}
# ===== WordPress main menu =====
wp_menu() {
  select_wp_domain manage "WordPress site"
  config_dir="$base/wordpress/config"
  web_user="$(get_site_user "$domain")"
  profiles_file="$config_dir/remotes.conf"
  map_file="$config_dir/domain_map.conf"
  current_profile_file="$config_dir/current_profile"
  site="/etc/one-click/wordpress/$domain/www"
  [[ -n "$web_user" && -s "$site/wp-load.php" && -s "/etc/one-click/wordpress/$domain/wp-config.php" ]] || {
    error "WordPress core, configuration or site account is missing for $domain."
    return 0
  }
  wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$site")" || { error "Unable to resolve the site PHP/WP-CLI runtime."; return 0; }
  mkdir -p "$config_dir" && touch "$map_file" "$profiles_file"
  wp_submenu "$domain"
}
wp_submenu() {
  local domain="$1"
  options=(
    "${magenta}1${green}  WP Plugin Manager${blue}"
    "${magenta}2${green}  Manage Profiles${blue}"
    "${magenta}3${green}  Backup Site${blue}"
    "${magenta}4${green}  Restore Backup${blue}"
    "${magenta}5${green}  Staging Menu${blue}"
    "${magenta}6${green}  Rollback Snapshots${blue}"
    "${magenta}7${green}  Push Staging${blue}"
    "${magenta}8${green}  Delete Site${blue}"
    "${magenta}9${green}  Reset Password${blue}"
    "${magenta}10${green} Web Logs${blue}"
    "${magenta}0${green}  Exit${blue}"
  )
  local choice
  while true; do
    paste <(draw_box "${magenta}Managing WordPress:${yellow} $domain${blue}" "${options[@]}") <(get_current_profile "$domain")
    read -rp "${cyan}[USER]${reset} Select an option: " choice
    case "$choice" in
      1) wp_plugin_manager "$domain" ;;
      2) profiles_board              ;;
      3) wp_backup "$domain"         ;;
      4)
        resolve_profile "$domain"
        wp_restore_int "$domain"     ;;
      5) wp_staging_menu "$domain"   ;;
      6) wp_rollback_menu "$domain"  ;;
      7) wp_staging_push "$domain"   ;;
      8) delete_site "$domain"       ;;
      9) wp_magic_login "$domain"    ;;
      10) web_logs                   ;;
      0) echo "Exiting..."
        ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
        ;;
      *) error "Invalid choice"     ;;
    esac
  done
}
# ===== Staging submenu =====
wp_staging_menu() {
  local domain="$1"
  options=(
    "${magenta}1${green}  Create Staging${blue}"
    "${magenta}2${green}  Enable Staging${blue}"
    "${magenta}3${green}  Disable Staging${blue}"
    "${magenta}4${green}  Delete Staging${blue}"
    "${magenta}0${green}  Back${blue}"
  )
  local choice
  while true; do
    draw_box "${magenta}Managing WordPress:${yellow} $domain${blue}" "${options[@]}"
    read -rp "${cyan}[USER]${reset} Select an option: " choice
    case "$choice" in
      1) wp_staging "$domain"         ;;
      2) wp_staging_enable "$domain"  ;;
      3) wp_staging_disable "$domain" ;;
      4) wp_staging_delete "$domain"  ;;
      0) clear; wp_submenu "$domain"  ;;
      *) error "Invalid choice"       ;;
    esac
  done
}
wp_rollback_menu() {
  local domain="$1"
  options=(
    "${magenta}1${green}  Create Snapshot${blue}"
    "${magenta}2${green}  Restore Snapshot${blue}"
    "${magenta}3${green}  List Snapshots${blue}"
    "${magenta}0${green}  Back${blue}"
  )
  local choice
  while true; do
    draw_box "${magenta}Managing WordPress:${yellow} $domain${blue}" "${options[@]}"
    read -rp "${cyan}[USER]${reset} Select an option: " choice
    case "$choice" in
      1) create_rollback_snapshot "$domain" wordpress ;;
      2) rollback_restore "$domain" wordpress         ;;
      3) rollback_list "$domain"                      ;;
      0) clear; wp_submenu "$domain"                  ;;
      *) error "Invalid choice"                       ;;
    esac
  done
}
# ==== Install Webserver ====
install_webserver() {
  local mode="$1"
  local target_domain="${2:-}"
  local requested_site_dir="${3:-}"
  local requested_hsts="${4:-${enable_hsts:-}}"
  local service=""
  [[ -z "$target_domain" ]] && {
    error "install_webserver requires a domain."
    return 1
  }
  domain="$target_domain"
  case "$mode" in
    wordpress)
      mode_ver="wordpress"
      site_dir="/etc/one-click/wordpress/$domain/www"
      [[ "$requested_site_dir" =~ ^(yes|no|y|n)$ ]] && requested_hsts="$requested_site_dir"
      ;;
    nodejs)
      mode_ver="apps/nodejs"
      if [[ -d "/etc/one-click/apps/nodejs/$domain/app/public" ]]; then
        site_dir="/etc/one-click/apps/nodejs/$domain/app/public"
      else
        site_dir="/etc/one-click/apps/nodejs/$domain/app"
      fi
      ;;
    nextcloud)
      mode_ver="nextcloud"
      site_dir="${requested_site_dir:-/etc/one-click/nextcloud/$domain/www}"
      ;;
    static|sites)
      mode_ver="sites"
      site_dir="${requested_site_dir:-/etc/one-click/sites/$domain/www}"
      ;;
    *)
      error "Unsupported web-hosting mode '$mode'."
      return 1
      ;;
  esac
  [[ "$requested_site_dir" == "site_dir" ]] && site_dir="/etc/one-click/${mode_ver}/$domain/www"
  if [[ "${requested_hsts,,}" =~ ^(y|yes)$ ]]; then
    enable_hsts="yes"
  else
    enable_hsts="no"
  fi
  mkdir -p "/var/log/one-click/${domain}/${webserver}/"
  case "$webserver" in
    nginx)
      if systemctl is-active --quiet apache2; then
        systemctl disable --now apache2 >/dev/null 2>&1 || return 1
      fi
      if systemctl is-active --quiet httpd; then
        systemctl disable --now httpd >/dev/null 2>&1 || return 1
      fi
      "$pkg_mgr" install -y nginx >/dev/null 2>&1 || {
        error "Failed to install Nginx."
        return 1
      }
      if [[ -f /etc/nginx/nginx.conf ]]; then
        mkdir -p /etc/nginx/one-click
        if [[ ! -f /etc/nginx/one-click/logging.conf ]]; then
          cat > /etc/nginx/one-click/logging.conf <<'EOF'
log_format oneclick '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" "$host"';
EOF
        fi
        if ! grep -Fq 'include /etc/nginx/one-click/*.conf;' /etc/nginx/nginx.conf; then
          cp -a /etc/nginx/nginx.conf /etc/nginx/nginx.conf.one-click-bak
          sed -i '/^[[:space:]]*http[[:space:]]*{/a\    include /etc/nginx/one-click/*.conf;' /etc/nginx/nginx.conf
        fi
      fi
      if [[ ! -f /etc/nginx/sites-enabled/00-default.conf && \
            ! -f /etc/nginx/conf.d/00-default.conf ]]; then
        default_nginx || return 1
      fi
      case "$mode" in
        wordpress) nginx_conf "$enable_hsts" || return 1 ;;
        nextcloud) nc_nginx_conf "$enable_hsts" || return 1 ;;
        nodejs) : ;; # Node.js installs its own reverse proxy after backend creation.
        *) nginx_static_conf "$domain" "$site_dir" "$enable_hsts" || return 1 ;;
      esac
      if [[ "$mode" == "nextcloud" && -f /etc/nginx/mime.types ]] && \
         ! grep -qE 'text/javascript[[:space:]]+mjs;' /etc/nginx/mime.types; then
        sed -i '/^[[:space:]]*types[[:space:]]*{/a\    text/javascript mjs;' /etc/nginx/mime.types
      fi
      nginx -t >/dev/null 2>&1 || {
        error "Nginx configuration validation failed for $domain."
        return 1
      }
      systemctl enable --now nginx >/dev/null 2>&1 || return 1
      systemctl reload nginx >/dev/null 2>&1 || return 1
      ;;
    apache|apache2|httpd)
      if systemctl is-active --quiet nginx; then
        systemctl disable --now nginx >/dev/null 2>&1 || return 1
      fi
      if [[ "$mode" != "nodejs" ]]; then
        install_php_mods || return 1
      fi
      case "$mode" in
        wordpress) apache_conf "$enable_hsts" || return 1 ;;
        nextcloud) nc_apache_conf "$enable_hsts" || return 1 ;;
        nodejs) : ;; # Node.js installs its own reverse proxy after backend creation.
        *) apache_static_conf "$domain" "$site_dir" "$enable_hsts" || return 1 ;;
      esac
      if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
        a2ensite "${domain}.conf" >/dev/null 2>&1 || return 1
        apache2ctl configtest >/dev/null 2>&1 || {
          error "Apache configuration validation failed for $domain."
          return 1
        }
        service="apache2"
      else
        httpd -t >/dev/null 2>&1 || {
          error "HTTPD configuration validation failed for $domain."
          return 1
        }
        service="httpd"
      fi
      systemctl enable --now "$service" >/dev/null 2>&1 || return 1
      systemctl reload "$service" >/dev/null 2>&1 || return 1
      ;;
    *)
      error "Unsupported webserver '$webserver'."
      return 1
      ;;
  esac
  return 0
}

# ==== Webservers Configs ====
install_php_mods() {
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    if ! "$pkg_mgr" install -y \
      apache2 \
      libapache2-mod-php \
      php \
      php-fpm \
      php-mysql \
      php-curl \
      php-gd \
      php-mbstring \
      php-xml \
      php-zip \
      php-common \
      bzip2; then
      error "Failed to install Apache/PHP modules."
      return 1
    fi
    a2enmod rewrite ssl headers proxy proxy_fcgi >/dev/null 2>&1 || return 1
    [[ -n "${domain:-}" ]] && a2ensite "${domain}.conf" >/dev/null 2>&1 || true

  elif [[ "$pkg_mgr" == "dnf" || "$pkg_mgr" == "yum" ]]; then
    if ! "$pkg_mgr" install -y \
      httpd \
      mod_ssl \
      php \
      php-fpm \
      php-mysqlnd \
      php-gd \
      php-mbstring \
      php-xml \
      php-json \
      php-process \
      bzip2; then
      error "Failed to install HTTPD/PHP modules."
      return 1
    fi
  else
    error "Unsupported package manager '$pkg_mgr'."
    return 1
  fi
  return 0
}
# ==== Nginx ====
nginx_conf() {
  enable_hsts="${1:-}"
  mkdir -p /var/log/one-click/${domain}/nginx
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  fi
  echo "VHOST=$nginx_conf_file" >> /etc/one-click/${mode_ver}/${domain}/meta.conf
  mkdir -p /var/log/one-click/${domain}/nginx
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root /etc/one-click/$mode_ver/$domain/www;
    index index.php index.html;

    access_log /var/log/one-click/${domain}/nginx/access.log oneclick;
    error_log /var/log/one-click/${domain}/nginx/error.log warn;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/one-click/${domain}/php.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}
EOF
  if [[ "$pkg_mgr" == "apt" && -d /etc/nginx/sites-available ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  sed -Ei.one-click.bak '/log_format|access_log/{s/main/oneclick/}' /etc/nginx/nginx.conf
  for i in /etc/nginx/sites-enabled/ /etc/nginx/sites-available /etc/nginx/con.d/ ; do
    if [[ ! -d "$i" ]]; then
      continue
    fi
    find "$i" -type l -name '*default*' '!' -name 00-default.conf -delete
  done
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -Ei '
     N;/add_header.*\n$/ {
    p;s/add_header.*\n/add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload" always;/;
    }' "$nginx_conf_file"
  fi
  nginx -t
  systemctl enable nginx --now
  systemctl reload nginx
}
# ==== NextCloud Nginx Conf ====
nc_nginx_conf() {
  enable_hsts="${1:-no}"
  mkdir -p /var/log/one-click/${domain}/nginx
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  fi
  echo "VHOST=$nginx_conf_file" >> /etc/one-click/${mode_ver}/${domain}/meta.conf
  mkdir -p /var/log/one-click/${domain}/nginx
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root /etc/one-click/$mode_ver/$domain/www;
    index index.php index.html;

    client_max_body_size 512M;
    fastcgi_buffers 64 4K;
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    add_header Referrer-Policy "no-referrer" always;
    add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Permitted-Cross-Domain-Policies "none" always;
    add_header X-Robots-Tag "noindex, nofollow" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Download-Options "noopen" always;

    fastcgi_hide_header X-Powered-By;

    location ^~ /.well-known/ {
        location ^~ /.well-known/carddav   { return 301 https://\$host/remote.php/dav/; }
        location ^~ /.well-known/caldav    { return 301 https://\$host/remote.php/dav/; }
        location ^~ /.well-known/webfinger { return 301 https://\$host/index.php/.well-known/webfinger; }
        location ^~ /.well-known/nodeinfo  { return 301 https://\$host/index.php/.well-known/nodeinfo; }

        try_files \$uri \$uri/ /index.php\$request_uri;
    }

    location ~ ^\/(?:\\.user\\.ini|\\.htaccess|\\.git|\\.data|autotest|occ|issue|indie|db_|gpl-3.0\\.txt) {
        deny all;
    }

    location / {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }

    location ^~ /ocm-provider/ {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }

    location ^~ /ocs-provider/ {
        try_files \$uri \$uri/ /index.php\$request_uri;
    }

    location ~ ^\/(?:updater|ocm-provider|ocs-provider)(?:\$|\/) {
        try_files \$uri/ =404;
        index index.php;
    }

    location ~ ^\/(?:index|remote|public|cron|core\/ajax\/update|status|updater|ocm-provider|ocs-provider)\\.php(?:\$|\/) {
        include fastcgi_params;
        fastcgi_split_path_info ^(.+?\\.php)(\/.*)\$;
        try_files \$fastcgi_script_name =404;

        fastcgi_pass unix:/run/one-click/${domain}/php.sock;
        fastcgi_index index.php;

        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;

        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ \\.php(?:\$|/) {
      fastcgi_split_path_info ^(.+?\\.php)(/.*)\$;
      set \$path_info \$fastcgi_path_info;
      try_files \$fastcgi_script_name =404;

      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_param PATH_INFO \$path_info;
      fastcgi_param HTTPS on;
      fastcgi_param modHeadersAvailable true;
      fastcgi_param front_controller_active true;

      fastcgi_pass unix:/run/one-click/${domain}/php.sock;
      fastcgi_intercept_errors on;
      fastcgi_request_buffering off;
    }

    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?|mp4|ogg)\$ {
        expires 6M;
        access_log off;
        log_not_found off;
    }
}
EOF
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -Ei '
     N;/add_header.*\n$/ {
    p;s/add_header.*\n/add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload" always;/;
    }' "$nginx_conf_file"
  fi
  if [[ "$pkg_mgr" == "apt" && -d /etc/nginx/sites-available ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  sed -Ei.one-click.bak '/log_format|access_log/{s/main/oneclick/}' /etc/nginx/nginx.conf
  for i in /etc/nginx/sites-enabled/ /etc/nginx/sites-available /etc/nginx/conf.d/ ; do
    if [[ ! -d "$i" ]]; then
      continue
    fi
    find "$i" -type l -name '*default*' '!' -name 00-default.conf -delete
  done
  nginx -t
  systemctl enable nginx --now
  systemctl reload nginx
}
# ==== NextCloud Apache Conf ====
nc_apache_conf() {
  local enable_hsts="${1:-no}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_confi="/etc/apache2/sites-available/$domain.conf"
    apache_log_dir="/var/log/one-click/${domain}/apache2"
    mkdir -p /var/log/one-click/${domain}/apache2
  else
    apache_confi="/etc/httpd/conf.d/$domain.conf"
    apache_log_dir="/var/log/one-click/${domain}/httpd"
    mkdir -p /var/log/one-click/${domain}/httpd
  fi
  echo "VHOST=$apache_confi" >> "/etc/one-click/${mode_ver}/${domain}/meta.conf"
  mkdir -p "/run/one-click/${domain}"
  mkdir -p "$apache_log_dir"
  chown -R www-data:www-data "/run/one-click/${domain}" 2>/dev/null || true
  if command -v a2enmod &>/dev/null; then
    a2enmod proxy proxy_fcgi rewrite headers env dir mime &>/dev/null || true
  fi
  cat << EOF > "$apache_confi"
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain

    DocumentRoot /etc/one-click/$mode_ver/$domain/www

    <Directory /etc/one-click/${mode_ver}/${domain}/www>
        Options +FollowSymlinks -Indexes
        AllowOverride All
        Require all granted

        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        SetEnv HOME /etc/one-click/${mode_ver}/${domain}/www
        SetEnv HTTP_HOME /etc/one-click/${mode_ver}/${domain}/www
    </Directory>

    <FilesMatch "\.php$">
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    Header always set Referrer-Policy "no-referrer"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Permitted-Cross-Domain-Policies "none"
    Header always set X-Robots-Tag "noindex, nofollow"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Download-Options "noopen"

    RewriteEngine On
    RewriteRule ^/\.well-known/carddav /remote.php/dav/ [R=301,L]
    RewriteRule ^/\.well-known/caldav /remote.php/dav/ [R=301,L]
    RewriteRule ^/\.well-known/webfinger /index.php/.well-known/webfinger [R=301,L]
    RewriteRule ^/\.well-known/nodeinfo /index.php/.well-known/nodeinfo [R=301,L]

    ErrorLog ${apache_log_dir}/error.log
    CustomLog ${apache_log_dir}/access.log combined
</VirtualHost>
EOF
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -i '/Header always set X-Download-Options/a \    Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"' "$apache_confi"
  fi
  if [[ "$pkg_mgr" == "apt" && -d /etc/apache2/sites-available ]]; then
    ln -sf "/etc/apache2/sites-available/$domain.conf" "/etc/apache2/sites-enabled/$domain.conf"
  fi
  if command -v systemctl &>/dev/null; then
    if [[ "$pkg_mgr" == "apt" ]]; then
      apachectl configtest
      systemctl reload apache2
    else
      if ! systemctl is-active httpd &> /dev/null; then
        systemctl start httpd 2> /dev/null
        apachectl configtest
        systemctl reload httpd
      else
        apachectl configtest
        systemctl reload httpd
      fi
    fi
  fi
}
# ==== Apache ====
apache_conf() {
  enable_hsts="${1:-}"
  if [[ "$mode" == "static" ]]; then
    mode="sites"
  fi
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_confi=/etc/apache2/sites-available/$domain.conf
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    apache_confi=/etc/httpd/conf.d/$domain.conf
  fi
  echo "VHOST=$apache_confi" >> /etc/one-click/${mode_ver}/${domain}/meta.conf
  if [[ -d /etc/apache2 ]]; then
    apache_log_dir="/var/log/one-click/${domain}/apache2"
    mkdir -p /var/log/one-click/${domain}/apache2
  else
    apache_log_dir="/var/log/one-click/${domain}/httpd"
    mkdir -p /var/log/one-click/${domain}/httpd
  fi
  cat << EOF > "$apache_confi"
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain
    #Redirect permanent / https://$domain/

    DocumentRoot /etc/one-click/$mode_ver/$domain/www

    <Directory /etc/one-click/${mode_ver}/${domain}/www>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/error.log
    CustomLog ${apache_log_dir}/access.log combined
</VirtualHost>
EOF
  install_php_mods
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -i '/Header always set X-Download-Options/a \    Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"' "$apache_confi"
  fi
}
install_self_signed_certificate() {
  local domain="$1"
  local cert_dir dir meta cert_file key_file
  if [[ -d "/etc/one-click/wordpress/$domain" ]]; then
    dir="/etc/one-click/wordpress/$domain"
  elif [[ -d "/etc/one-click/sites/$domain" ]]; then
    dir="/etc/one-click/sites/$domain"
  elif [[ -d "/etc/one-click/nextcloud/$domain" ]]; then
    dir="/etc/one-click/nextcloud/$domain"
  elif [[ -d "/etc/one-click/apps/nodejs/$domain" ]]; then
    dir="/etc/one-click/apps/nodejs/$domain"
  else
    error "Unable to locate site metadata for $domain."
    return 1
  fi
  meta="$dir/meta.conf"
  [[ -f "$meta" ]] && . "$meta"
  webserver="${WEBSERVER:-${webserver:-}}"
  cert_dir="$dir/cert"
  cert_file="$cert_dir/${domain}-oneclick_selfsigned-fullchain.pem"
  key_file="$cert_dir/${domain}-oneclick_selfsigned-privkey.key"
  mkdir -p "$cert_dir"
  openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout "$key_file" \
    -out "$cert_file" \
    -subj "/CN=$domain" >/dev/null 2>&1 || return 1
  chown root:root "$cert_file" "$key_file"
  chmod 644 "$cert_file"
  chmod 600 "$key_file"
  case "$webserver" in
    nginx) webroot_nginx_template "$cert_file" "$key_file" || return 1 ;;
    apache|apache2|httpd) apache_ssl_conf "$cert_file" "$key_file" || return 1 ;;
    *) error "Unsupported webserver '$webserver' for self-signed TLS."; return 1 ;;
  esac
  success "Self-signed certificate installed for $domain."
  return 0
}
apache_ssl_conf() {
  local cert_file="${1:-/etc/letsencrypt/live/$domain/fullchain.pem}"
  local key_file="${2:-/etc/letsencrypt/live/$domain/privkey.pem}"
  local base_conf ssl_apache_conf service
  [[ -s "$cert_file" && -s "$key_file" ]] || {
    error "TLS certificate or key is missing for $domain."
    return 1
  }
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    base_conf="/etc/apache2/sites-available/$domain.conf"
    ssl_apache_conf="/etc/apache2/sites-available/${domain}-oneclick-ssl.conf"
    service="apache2"
  else
    base_conf="/etc/httpd/conf.d/$domain.conf"
    ssl_apache_conf="/etc/httpd/conf.d/${domain}-oneclick-ssl.conf"
    service="httpd"
  fi
  [[ -f "$base_conf" ]] || {
    error "Apache vhost missing: $base_conf"
    return 1
  }
  sed -E 's/<VirtualHost \*:80>/<VirtualHost *:443>/' "$base_conf" > "$ssl_apache_conf" || return 1
  sed -i "/^[[:space:]]*ServerAlias[[:space:]]/a\\    SSLEngine on\\n    SSLCertificateFile $cert_file\\n    SSLCertificateKeyFile $key_file" "$ssl_apache_conf"
  if [[ "$service" == "apache2" ]]; then
    a2enmod ssl >/dev/null 2>&1 || true
    a2ensite "$(basename "$ssl_apache_conf")" >/dev/null 2>&1 || return 1
    if ! apache2ctl configtest >/dev/null 2>&1; then
      a2dissite "$(basename "$ssl_apache_conf")" >/dev/null 2>&1 || true
      rm -f "$ssl_apache_conf"
      error "Generated Apache TLS vhost failed validation."
      return 1
    fi
  else
    if ! httpd -t >/dev/null 2>&1; then
      rm -f "$ssl_apache_conf"
      error "Generated HTTPD TLS vhost failed validation."
      return 1
    fi
  fi
  systemctl reload "$service" >/dev/null 2>&1 || return 1
  return 0
}
webroot_nginx_template() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  fi
  sed -Ei '/listen (\[::\]:)?80;|^\}/d;' "$nginx_conf_file"
  cat << EOF >> "$nginx_conf_file"
    listen 443 ssl; # Managed By One-Click
    listen [::]:443 ssl; # Managed By One-Click
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem; # Managed By One-Click
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem; # Managed By One-Click

}
server {
    if (\$host = www.$domain) {
        return 301 https://\$host\$request_uri;
    } # Managed By One-Click


    if (\$host = $domain) {
        return 301 https://\$host\$request_uri;
    } # Managed By One-Click


    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    return 404; # Managed By One-Click
}
EOF

}
# ==== Intro Message ====
start_screen() {
  local mode default_site site
  clear
  mode="$1"
  if [[ "$mode" == "wordpress" ]]; then
    default_site="ONE-CLICK WORDPRESS INSTALLER"
    site=wordpress
  elif [[ "$mode" == "nextcloud" ]]; then
    default_site="ONE-CLICK NEXTCLOUD INSTALLER"
    site=nextcloud
    wp_title=$(cat <<'EOF'
  ___                    ____ _ _      _
 / _ \ _ __   ___       / ___| (_) ___| | __
| | | | '_ \ / _ \_____| |   | | |/ __| |/ /
| |_| | | | |  __/_____| |___| | | (__|   <
 \___/|_| |_|\___|      \____|_|_|\___|_|\_\

 _   _           _    ____ _                 _
| \ | | _____  _| |_ / ___| | ___  _   _  __| |
|  \| |/ _ \ \/ / __| |   | |/ _ \| | | |/ _` |
| |\  |  __/>  <| |_| |___| | (_) | |_| | (_| |
|_| \_|\___/_/\_\\__|\____|_|\___/ \__,_|\__,_|

EOF
  )
  else
    default_site="ONE-CLICK STATIC INSTALLATION"
    site="html site"
    wp_title=$(cat <<'EOF'
  ___                ____ _ _      _      ____  _ _
 / _ \ _ __   ___   / ___| (_) ___| | __ / ___|(_) |_ ___  ___
| | | | '_ \ / _ \ | |   | | |/ __| |/ / \___ \| | __/ _ \/ __|
| |_| | | | |  __/ | |___| | | (__|   <   ___) | | ||  __/\__ \
 \___/|_| |_|\___|  \____|_|_|\___|_|\_\ |____/|_|\__\___||___/

EOF
  )
  fi
  header_notice "$wp_title" "${wp_banner:-}" "188" "40"
  printf "${blue}%s${reset}\n" " " \
    "┌───────────────────────────────────────────────────────────────────────────────────┐" \
    "│${yellow}                     $default_site                                 ${blue}│" \
    "├───────────────────────────────────────────────────────────────────────────────────┤" \
    "│                                                                                   │" \
    "│${yellow}${ul}Overview:${ul_reset}${blue}                                                                          │" \
    "│  This tool will install a fully functional $site installation with:           │" \
    "│    - Database setup                                                               │" \
    "│    - Nginx or Apache configuration                                                │" \
    "│    - PHP & required extensions                                                    │" \
    "│    - Optional Redis caching                                                       │" \
    "│    - Let's Encrypt SSL                                                            │" \
    "│                                                                                   │" \
    "│${yellow}Important DNS Note:${reset}${blue}                                                                │" \
    "│  Before proceeding, make sure your domain's DNS A records point to this server:   │" \
    "│    - ${yellow}yourdomain.com${blue}                                                               │" \
    "│    - ${yellow}www.yourdomain.com${blue}                                                           │" \
    "│  Without this, SSL installation and WordPress https URL setup may fail.           │" \
    "│                                                                                   │"
  read -rp  "│${yellow}Press ENTER to continue when ready...${blue}                                              │
└───────────────────────────────────────────────────────────────────────────────────┘${reset}"
  export mode
  return 0
}
# ==== LetsEncrypt ====
install_letsencrypt() {
  local mode="${1:-}"
  local site="" meta="" webroot="" plugin="" service=""
  local bot_installed=0 choice action
  if [[ -z "${domain:-}" ]]; then
    select_domain
  fi
  [[ -n "${domain:-}" ]] || {
    error "No domain selected for SSL provisioning."
    return 0
  }
  case "$mode" in
    wordpress)
      meta="/etc/one-click/wordpress/$domain/meta.conf"
      webroot="/etc/one-click/wordpress/$domain/www"
      ;;
    nextcloud)
      meta="/etc/one-click/nextcloud/$domain/meta.conf"
      webroot="/etc/one-click/nextcloud/$domain/www"
      ;;
    nodejs)
      meta="/etc/one-click/apps/nodejs/$domain/meta.conf"
      if [[ -d "/etc/one-click/apps/nodejs/$domain/app/public" ]]; then
        webroot="/etc/one-click/apps/nodejs/$domain/app/public"
      else
        webroot="/etc/one-click/apps/nodejs/$domain/app"
      fi
      ;;
    static|sites|"")
      meta="/etc/one-click/sites/$domain/meta.conf"
      webroot="/etc/one-click/sites/$domain/www"
      ;;
  esac
  [[ -f "$meta" ]] && . "$meta"
  webserver="${WEBSERVER:-${webserver:-}}"
  web_user="${SITE_USER:-${web_user:-}}"
  if [[ -z "${email:-}" && "$mode" == "wordpress" && -n "$web_user" ]]; then
    local wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$webroot" 2>/dev/null || true)"
    [[ -z "$wp_cmd" ]] || email=$($wp_cmd option get admin_email 2>/dev/null || true)
  fi
  while [[ -z "${email:-}" || ! "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; do
    read -rp "${cyan}[USER]${blue} Please provide an email address for Let's Encrypt:${reset} " email
  done
  while true; do
    info "Starting Let's Encrypt SSL setup."
    if ! dns_check "$domain"; then
      warn "DNS does not point both $domain and www.$domain to this server."
      read -rp "${cyan}[USER]${reset} Fix DNS and press ENTER to retry (or type 'skip'): " action
      [[ "$action" == "skip" ]] && return 0
      continue
    fi
    "$pkg_mgr" install -y certbot >/dev/null 2>&1 || {
      error "Failed to install Certbot."
      return 0
    }
    case "$webserver" in
      nginx)
        plugin="python3-certbot-nginx"
        service="nginx"
        "$pkg_mgr" install -y "$plugin" >/dev/null 2>&1 || true
        if command -v certbot >/dev/null 2>&1 && \
           certbot --nginx -d "$domain" -d "www.$domain" \
             --non-interactive --agree-tos -m "$email" --redirect; then
          bot_installed=1
        fi
        ;;
      apache|apache2|httpd)
        plugin="python3-certbot-apache"
        "$pkg_mgr" install -y "$plugin" >/dev/null 2>&1 || true
        if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
          service="apache2"
        else
          service="httpd"
        fi
        if command -v certbot >/dev/null 2>&1 && \
           certbot --apache -d "$domain" -d "www.$domain" \
             --non-interactive --agree-tos -m "$email" --redirect; then
          bot_installed=1
        fi
        ;;
      *)
        error "Unable to determine a supported webserver for SSL provisioning."
        return 0
        ;;
    esac
    if (( bot_installed == 1 )); then
      if [[ "$mode" == "wordpress" ]]; then
        local wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$webroot" 2>/dev/null || true)"
        [[ -z "$wp_cmd" ]] || $wp_cmd option update home "https://$domain" >/dev/null || warn "Could not update WordPress home URL after SSL installation."
        [[ -z "$wp_cmd" ]] || $wp_cmd option update siteurl "https://$domain" >/dev/null || warn "Could not update WordPress site URL after SSL installation."
      fi
      letsencrypt_autorenew
      success "SSL successfully installed for $domain."
      return 0
    fi
    warn "Certbot webserver integration failed."
    printf '%s\n' \
      "Options:" \
      "  [1] Try webroot installation" \
      "  [2] Change email" \
      "  [3] Skip SSL setup" \
      "  [4] Install Self-Signed Certificate" \
      "  [5] View logs"
    read -rp "${cyan}[USER]${reset} Choose an option: " choice
    case "$choice" in
      1)
        [[ -d "$webroot" ]] || {
          error "Webroot does not exist: $webroot"
          continue
        }
        if certbot certonly --webroot -w "$webroot" \
          -d "$domain" -d "www.$domain" \
          --non-interactive --agree-tos -m "$email"; then
          if [[ "$webserver" == "nginx" ]]; then
            webroot_nginx_template || warn "SSL certificate was issued but Nginx SSL wiring could not be completed automatically."
          else
            apache_ssl_conf || warn "SSL certificate was issued but Apache SSL wiring could not be completed automatically."
          fi

          if [[ "$mode" == "wordpress" ]]; then
            local wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$webroot" 2>/dev/null || true)"
            [[ -z "$wp_cmd" ]] || $wp_cmd option update home "https://$domain" >/dev/null || warn "Could not update WordPress home URL after SSL installation."
            [[ -z "$wp_cmd" ]] || $wp_cmd option update siteurl "https://$domain" >/dev/null || warn "Could not update WordPress site URL after SSL installation."
          fi

          letsencrypt_autorenew
          success "SSL successfully installed for $domain."
          return 0
        fi
        ;;
      2)
        email=""
        while [[ -z "$email" || ! "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; do
          read -rp "${cyan}[USER]${blue} Enter new email: ${reset}" email
        done
        ;;
      3)
        warn "Skipping SSL setup."
        return 0
        ;;
      4)
        install_self_signed_certificate "$domain"
        return $?
        ;;
      5)
        less /var/log/letsencrypt/letsencrypt.log 2>/dev/null || true
        ;;
      *)
        warn "Invalid option"
        ;;
    esac
  done
}
letsencrypt_autorenew() {
  info "Configuring Let's Encrypt auto-renewal"
  cat > /etc/cron.d/one-click-letsencrypt <<'EOF'
0 3 * * * root certbot renew --quiet --deploy-hook "systemctl reload nginx >/dev/null 2>&1 || systemctl reload apache2 >/dev/null 2>&1 || systemctl reload httpd >/dev/null 2>&1" # One-Click TLS renewal
EOF
  chmod 644 /etc/cron.d/one-click-letsencrypt
  success "Auto-renew enabled"
  return 0
}
# === Run Script ====
run_script() {
  start_screen wordpress
  echo
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  local provision_success=0
  while true; do
    local br=0
    read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to use for this installation: " domain
    if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      echo "Invalid domain name"
      br=1
    fi
    if [[ -n "$domain" && "$br" -ne 1 ]]; then
      export domain
      break
    fi
    echo "Domain cannot be empty!"
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Site Title: " title
    [[ -n "$title" ]] && break
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin User: " admin
    [[ -n "$admin" ]] && break
  done
  while true; do
    read -rsp "${cyan}[USER]${reset} Please provide the Admin Password: " pass
    echo
    if [[ ${#pass} -lt 12 ]]; then
      echo "Password too short! Must be at least 12 characters."
      continue
    fi
    if ! [[ "$pass" =~ [A-Z] ]]; then
      echo "Password must contain at least one uppercase letter."
      continue
    fi
    if ! [[ "$pass" =~ [a-z] ]]; then
      echo "Password must contain at least one lowercase letter."
      continue
    fi
    if ! [[ "$pass" =~ [0-9] ]]; then
      echo "Password must contain at least one number."
      continue
    fi
    read -rsp "${cyan}[USER]${blue} Confirm Password: " pass_confirm
    echo
    if [[ "$pass" != "$pass_confirm" ]]; then
      echo "Passwords do not match. Try again."
      continue
    fi
    break
  done
  pass_confirm=
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Database User: " dbuser
    [[ -n "$dbuser" ]] && break
  done
  while true; do
    read -rsp "${cyan}[USER]${reset} Please provide the Database Password: " dbpass
    echo
    if [[ ${#dbpass} -lt 12 ]]; then
      echo "Password too short! Must be at least 12 characters."
      continue
    fi
    if ! [[ "$dbpass" =~ [A-Z] ]]; then
      echo "Password must contain at least one uppercase letter."
      continue
    fi
    if ! [[ "$dbpass" =~ [a-z] ]]; then
      echo "Password must contain at least one lowercase letter."
      continue
    fi
    if ! [[ "$dbpass" =~ [0-9] ]]; then
      echo "Password must contain at least one number."
      continue
    fi
    read -rsp "${cyan}[USER]${blue} Confirm Password: " pass_confirm
    echo
    if [[ "$dbpass" != "$pass_confirm" ]]; then
      echo "Passwords do not match. Try again."
      continue
    fi
    break
  done
  # Never adopt an existing/partial installation and then run the cleanup
  # trap over it. Recovery of an existing site is a separate, manual action.
  if [[ -e "/etc/one-click/wordpress/$domain" || -L "/etc/one-click/wordpress/$domain" ]]; then
    error "WordPress path already exists for $domain. Existing data was not changed."
    return 0
  fi
  web_user="${admin:4}_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  export admin web_user
  site="/etc/one-click/wordpress/$domain/www"
  # No site files, metadata or accounts are created before confirmation.
  # Resolve WP-CLI only after create_isolated_php_runtime has selected the
  # site's PHP version. Resolving before it captured the system PHP instead.
  echo
  if [[ "$centos_ver" -lt 10 ]]; then
    while true; do
      read -rp "${cyan}[USER]${reset} Enable Redis (y|n): " enable_redis
      if [[ "$enable_redis" =~ ^[Y|y|yes|Yes|n|N|no|No]$ ]]; then
        break
      fi
      warn "Please enter y or n"
    done
  else
    warn "CentOS $centos_ver does not support redis"
    enable_redis=n
  fi
  #read -rp "${cyan}[USER]${reset} Enable Cloudflare (y|n): " enable_cloudflare
  while true; do
    read -rp "${cyan}[USER]${reset} Enable Staging? (y|n) " enable_staging
    if [[ "$enable_staging" =~ ^[Y|y|yes|Yes|n|N|no|No]$ ]]; then
      break
    fi
    warn "Please enter y or n"
  done
  printf '%s\n' "Which webserver would you like to configure?" \
    "[1] Nginx" \
    "[2] Apache"
  while true; do
    read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver
    [[ -n "$webserver" ]] && break
  done
  case "$webserver" in
    1)
      webserver="nginx"
      if command -v apt &> /dev/null; then
        webserver_user="www-data"
      else
        webserver_user="nginx"
      fi
      ;;
    2)
      webserver="apache"
      if command -v apt &> /dev/null; then
        webserver_user="www-data"
      else
        webserver_user="apache"
      fi
      ;;
    *)
      echo "Invalid selection"
      ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1 ;;
  esac
  read -rp "${cyan}[USER]${blue} Enable HSTS: ${reset}" enable_hsts
  if [[ "${enable_hsts,,}" =~ ^(y|yes)$ ]]; then
    enable_hsts="yes"
  fi

  # ==== Selection Summary Confirmation ====
  [[ "$enable_redis" == "n" ]] && redis=No || redis=Yes
  [[ "$enable_staging" == "n" ]] && staging_status=No || staging_status=Yes
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────┐" \
    "│                       ${yellow}CONFIRMATION DETAILS${blue}           │" \
    "├──────────────────────────────────────────────────────┤"
  printf "${blue}│ %-19s : %-40s │\n" \
    "Domain Name" "${yellow}${domain}${blue}" \
    "Site Title" "${yellow}${title}${blue}" \
    "Admin User" "${yellow}${admin}${blue}" \
    "Admin Password" "${yellow}$(sed -E ':a;s/([[:alnum:]]([[:alnum:]*]+)?)[][:alnum:]!"%£+=_&^@$.-[]/\1*/;ta' <<< $pass)${blue}" \
    "Admin Email" "${yellow}${email}${blue}" \
    "Database User" "${yellow}${dbuser}${blue}" \
    "Database Password" "${yellow}$(sed -E ':a;s/([[:alnum:]]([[:alnum:]*]+)?)[][:alnum:]!"%£+=_&^@$.-[]/\1*/;ta' <<< $dbpass)${blue}" \
    "Use Redis" "${yellow}${redis}${blue}" \
    "Enable Staging" "${yellow}${staging_status}${reset}" \
    "Webserver" "${yellow}${webserver}${blue}"
  printf '%s\n' "└──────────────────────────────────────────────────────┘${reset}"
  while true; do
    read -rp "${cyan}[USER]${reset} Are these details correct? (y|n): " proceed
    [[ -n "$proceed" ]] && break
  done
  proceed="${proceed,,}"
  echo
  if [[ "$proceed" == "n" || "$proceed" == "no" ]]; then
    warn "Deployment cancelled"
    exit 1
  fi
  trap "cleanup_failed_provision  $provision_success wordpress" EXIT INT TERM ERR
  # Provisioning now begins; nothing is changed when the user cancels.
  if ! mkdir -p "$site" || ! touch "/etc/one-click/wordpress/$domain/meta.conf"; then
    error "Could not create the new WordPress site directory."
    return 1
  fi
  if ! id "$web_user" >/dev/null 2>&1; then
    if ! useradd -r -m -s /usr/sbin/nologin "$web_user"; then
      error "Could not create the WordPress site account."
      return 1
    fi
    ONECLICK_WP_CREATED_USER=1
  fi
  echo "$web_user" > /tmp/web-user
  cat >> "/etc/one-click/wordpress/$domain/meta.conf" <<EOF
SITE_USER=$web_user
SITE_DIR=$site
SITE_GROUP=$webserver_user
WEBSERVER=$webserver
DB_USER=$dbuser
DB_ENABLED=true
TYPE=wordpress
WEBSERVER_SERVICE=$webserver
EOF
  # ==== Install Dependancies ====
  if [[ "$proceed" == "y" || "$proceed" == "yes" ]]; then
    info "Updating System"
    "$pkg_mgr" -y update
    info "Installing dependencies"
    "$pkg_mgr" install -y \
    mariadb-server \
    php-fpm \
    php-posix \
    unzip \
    curl
  fi
  source_config="/etc/one-click/wordpress/${domain}/www/wp-config.php"
  dest_config="/etc/one-click/wordpress/${domain}/wp-config.php"
  if ! install_wp_cli; then
    error "WordPress installation stopped: WP-CLI is unavailable."
    return 1
  fi
  info "Installing $webserver"
  if ! install_webserver wordpress "$domain" "site_dir"; then
    error "WordPress installation stopped: webserver configuration failed."
    return 1
  fi
  info "Creating resource slice for $domain"
  info "Configuring PHP-FPM"
  if ! create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "wordpress"; then
    error "WordPress installation stopped: isolated PHP-FPM runtime failed."
    return 1
  fi
  info "Enabling PHP"
  check_permissions "$domain"
  # The matching site PHP CLI is available only after FPM runtime creation.
  wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$site")" || {
    error "Unable to resolve the installed site's PHP/WP-CLI runtime."
    return 1
  }
  systemctl enable php-fpm@${domain}.service --now
  info "Confguring MariaDB"
  if ! configure_db; then
    error "WordPress installation stopped: database provisioning failed."
    return 1
  fi
  dns_check
  info "Downloading Wordpress"
  if ! download_wp; then
    error "WordPress download or configuration failed. Provisioning cannot continue."
    return 1
  fi
  info "Installing Wordpress"
  if ! install_wp; then
    error "WordPress core install failed. Provisioning cannot continue."
    return 1
  fi
  # Preserve the original One-Click config template and substitute BOTH
  # placeholder forms. WP-CLI writes each constant before the normal
  # wp-settings.php bootstrap instead of appending it at end-of-file.
  if ! wp_staging_cli "$domain" "$web_user" "$site" config set ONECLICK_PLATFORM_BOOTSTRAP true --raw --type=constant ||
     ! wp_staging_cli "$domain" "$web_user" "$site" config set FS_METHOD direct --type=constant ||
     ! wp_staging_cli "$domain" "$web_user" "$site" config set WP_CONTENT_DIR "ABSPATH . 'wp-content'" --raw --type=constant ||
     ! wp_staging_cli "$domain" "$web_user" "$site" config set WP_CONTENT_URL 'https://DOMAIN_REPLACE/wp-content' --type=constant ||
     ! wp_staging_cli "$domain" "$web_user" "$site" config set WP_TEMP_DIR '/var/lib/one-click/ONECLICK-DOMAIN_REPLACE/tmp' --type=constant; then
    error "WordPress bootstrap configuration failed."
    return 1
  fi
  # Substitute the long token first, so replacing the short token cannot
  # corrupt ONECLICK-DOMAIN_REPLACE into ONECLICK-example.org.
  if ! sed -i -e "s|ONECLICK-DOMAIN_REPLACE|$domain|g" -e "s|DOMAIN_REPLACE|$domain|g" "$source_config"; then
    error "WordPress domain-template substitution failed."
    return 1
  fi
  if grep -q 'DOMAIN_REPLACE' "$source_config"; then
    error "Unresolved WordPress domain placeholder; installation cannot proceed."
    return 1
  fi
  info "Hardening installation"
  harden_wp
  if [ -f "$dest_config" ]; then
    warn "A file already exists at $dest_config. Move aborted to prevent data loss."
    exit 1
  fi
  if [ -f "$source_config" ]; then
    warn "wp-config.php moving 1 level up!."
    if mv "$source_config" "$dest_config"; then
      info "Applying permissions to wp-config"
      chown "$web_user:$webserver_user" "$dest_config" || return 1
      chmod 0600 "$dest_config" || return 1
      success "wp-config.php moved outside the webroot with owner-only permissions."
    else
      error "Failed to move file. Check permissions and global server settings then try again."
      exit 1
    fi
  fi
  mkdir -p /etc/one-click/wordpress/backups
  chmod -R 700 /etc/one-click/wordpress/backups
  chown "$web_user":"$webserver_user" /etc/one-click/wordpress/backups
  chown "$web_user":"$webserver_user" /etc/one-click/wordpress/$domain/meta.conf
  # ==== Open Firewall ====
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver" -y
  info "Installing Plugins"
  wp_plugins
  if ! $wp_cmd core is-installed >/dev/null 2>&1; then
    error "WordPress could not be loaded after moving wp-config.php; refusing to report success."
    return 1
  fi
  info "Configuring SSL"
  install_letsencrypt wordpress
  set +o pipefail
  if [[ "${manual_install:-}" -eq 1 ]]; then
    webroot_nginx_template
  fi
  set -o pipefail
  wp_backup_scheduler "$domain" || warn "Could not schedule automatic WordPress backups."
  systemctl restart "$webserver"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_wp-web-monitor_$domain
  info "Fixing permissions"
  sleep 1
  check_permissions "$domain"
  provision_success=1
  trap - EXIT INT TERM ERR
  success "One-Click Wordpress has now been installed!"
  if [[ "$enable_staging" =~ ^[y|Y|yes|Yes]$ ]]; then
    wp_staging_enable "$domain"
  fi
  info "Access the site from ${magenta}https://${domain}${reset}"
  info "You can access the admin from: ${magenta}https://${domain}/wp-admin${reset}"
}
wp_plugin_manager() {
  local domain base_dir site_dir config_file
  domain="$1"
  base_dir="/etc/one-click/wordpress/$domain"
  site_dir="$base_dir/www"
  config_file="$base_dir/wp-config.php"
  web_user=$(get_site_user $domain)
  wp_cmd="$(site_wp_cli_command "$domain" "$web_user" "$site_dir")" || { error "Unable to resolve the site PHP/WP-CLI runtime."; return 0; }
  [[ ! -f "$config_file" ]] && { error "wp-config.php not found at $config_file"; return 1; }
  cd "$site_dir" || return 1
  while true; do
    echo -e "\e[34m╔════╦══════════════════════════════╗\e[0m"
    echo -e "\e[34m║ ${magenta}ID${blue} ║ ${yellow}WP Plugin Manager${blue}            ║\e[0m"
    echo -e "\e[34m╠════╬══════════════════════════════╣\e[0m"
    echo -e "\e[34m║${magenta} 1 ${blue} ║ ${green}List & Toggle Status${blue}         ║\e[0m"
    echo -e "\e[34m║${magenta} 2 ${blue} ║ ${green}Search & Install Plugin${blue}      ║\e[0m"
    echo -e "\e[34m║${magenta} 3 ${blue} ║ ${green}Update All Plugins${blue}           ║\e[0m"
    echo -e "\e[34m║${magenta} 4 ${blue} ║ ${green}Delete plugin  ${blue}              ║\e[0m"
    echo -e "\e[34m║${magenta} 0 ${blue} ║ ${green}Back ${blue}                        ║\e[0m"
    echo -e "\e[34m╚════╩══════════════════════════════╝\e[0m"
    read -rp "${cyan}[USER]${blue} Select an option: ${reset}" choice
    case "$choice" in
      1)
        mapfile -t plugins < <($wp_cmd plugin list --fields=name,status --format=csv | tail -n +2)
        if [[ ${#plugins[@]} -eq 0 ]]; then
          error "No plugins found."
          continue
        fi
        echo -e "\e[34m╔════╦══════════════════════════════════════════════════╦════════════╗\e[0m"
        echo -e "\e[34m║ ${magenta}ID${blue} ║${yellow} Plugin${blue}                                           ║ ${yellow}Status${blue}     ║\e[0m"
        echo -e "\e[34m╠════╬══════════════════════════════════════════════════╬════════════╣\e[0m"
        i=1
        for p in "${plugins[@]}"; do
          slug=$(echo "$p" | cut -d',' -f1)
          status=$(echo "$p" | cut -d',' -f2)
          printf "\e[34m║ \e[35m%-2s\e[34m ║ %-48s ║ %-10s ║\e[0m\n" "$i" "$slug" "$status"
          ((i++))
        done
        echo -e "\e[34m╚════╩══════════════════════════════════════════════════╩════════════╝\e[0m"
        read -rp "${cyan}[USER]${blue} Select ID to toggle (0 to cancel): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#plugins[@]} )); then
          selected="${plugins[$((choice-1))]}"
          slug=$(echo "$selected" | cut -d',' -f1)
          status=$(echo "$selected" | cut -d',' -f2)
          if [[ "$status" == "active" ]]; then
            info "Deactivating $slug."
            $wp_cmd plugin deactivate "$slug"
          else
            info "Activating $slug."
            $wp_cmd plugin activate "$slug"
          fi
        elif [[ "$choice" == "0" ]]; then
          info "Action cancelled."
        else
          error "Invalid selection."
        fi
        ;;
      2)
        read -rp "${cyan}[USER]${blue} Search for plugin: " search_term
        info "Searching WordPress.org."
        mapfile -t slugs < <($wp_cmd plugin search "$search_term" --field=slug --per-page=20)
        if [[ ${#slugs[@]} -eq 0 ]]; then
          error "No plugins found for '$search_term'"
          continue
        fi
        echo -e "\e[34m╔════╦══════════════════════════════════════════════════╗\e[0m"
        echo -e "\e[34m║ ${magenta}ID${blue} ║${yellow} Plugin Slug${blue}                                      ║\e[0m"
        echo -e "\e[34m╠════╬══════════════════════════════════════════════════╣\e[0m"
        local i=1
        for s in "${slugs[@]}"; do
          if [[ ! "$s" =~ Success: ]]; then
            printf "\e[34m║ \e[35m%-2s\e[34m ║ %-48s ║\e[0m\n" "$i" "$s"
            ((i++))
          fi
        done
        echo -e "\e[34m╚════╩══════════════════════════════════════════════════╝\e[0m"
        read -rp "${cyan}[USER]${blue} Select ID to install (0 to cancel): " s_choice
        if [[ "$s_choice" =~ ^[0-9]+$ ]] && (( s_choice >= 1 && s_choice <= ${#slugs[@]} )); then
          local selected_slug="${slugs[$((s_choice-1))]}"
          info "Installing $selected_slug."
          $wp_cmd plugin install "$selected_slug" --activate
        elif [[ "$s_choice" == "0" ]]; then
          info "Installation cancelled."
        else
          error "Invalid selection."
        fi
        ;;
      3)
        $wp_cmd plugin update --all
        ;;
      4)
        info "Fetching installed plugins."
        mapfile -t installed < <($wp_cmd plugin list --field=name)
        echo -e "\n\e[34m╔════╦══════════════════════════════════════════════════╗\e[0m"
        echo -e "\e[34m║ ${magenta}ID${blue} ║ ${yellow}Installed Plugin Name (Slug) ${blue}                    ║\e[0m"
        echo -e "\e[34m╠════╬══════════════════════════════════════════════════╣\e[0m"
        local j=1
        for p in "${installed[@]}"; do
          printf "\e[34m║ \e[35m%-2s\e[34m ║ %-48s ║\e[0m\n" "$j" "$p"
          ((j++))
        done
        echo -e "\e[34m╚════╩══════════════════════════════════════════════════╝\e[0m"
        read -rp "${cyan}[USER]${blue} Select ID to DELETE (0 to cancel): " d_choice
        if [[ "$d_choice" =~ ^[0-9]+$ ]] && (( d_choice >= 1 && d_choice <= ${#installed[@]} )); then
          local del_slug="${installed[$((d_choice-1))]}"
          read -rp "${cyan}[USER]${reset} Confirm deletion of $del_slug? (y|n): " confirm
          [[ "$confirm" == "y" ]] && $wp_cmd plugin delete "$del_slug"
        fi
        ;;
      0) return                 ;;
      *) error "Invalid choice" ;;
    esac
  done
}
wp_generate_magic_link() {
  local domain site meta_file user key url
  domain="$1"
  site="/etc/one-click/wordpress/${domain}/www"
  meta_file="/etc/one-click/wordpress/${domain}/.fp.conf"
  [[ ! -d "$site" ]] && { error "Site not found"; return 1; }
  cd "$site" || return 1
  user=$($wp_cmd user list --role=administrator --field=user_login | head -n1)
  [[ -z "$user" ]] && { error "No admin user found"; return 1; }
  key=$($wp_cmd eval "echo get_password_reset_key(get_user_by('login','$user'));" 2>/dev/null)
  [[ -z "$key" ]] && { error "Failed to generate reset key"; return 1; }
  url="https://$domain/wp-login.php?action=rp&key=$key&login=$user"
  mkdir -p "$(dirname "$meta_file")"
  enc_url=$(encrypt_password "$url")
  grep -v "^WP_MAGIC_LINK=" "$meta_file" 2>/dev/null > /tmp/meta.tmp || true
  echo "WP_MAGIC_LINK=$enc_url" >> /tmp/meta.tmp
  mv /tmp/meta.tmp "$meta_file"
  info "Password Change URL:${magenta} $url${reset}"
}
wp_get_magic_link() {
  local domain meta_file
  domain="$1"
  meta_file="/etc/one-click/wordpress/${domain}/.fp.conf"
  [[ ! -f "$meta_file" ]] && { error "No metadata found"; return 1; }
  enc_url=$(awk -F= '/^WP_MAGIC_LINK=/{print $2}' "$meta_file")
  [[ -z "$enc_url" ]] && {
    error "No stored magic link"
    return 1
  }
  url=$(decrypt_password "$enc_url")
  success "Magic login link:"
  echo "$url"
}
wp_magic_login() {
  local domain="$1"
  url=$(wp_get_magic_link "$domain" 2>/dev/null || true)
  if [[ -n "$url" ]]; then
    success "Using stored magic link"
    echo "$url"
    return
  fi
  warn "No valid link found, generating new one."
  wp_generate_magic_link "$domain"
}
get_site_user() {
  local domain meta
  domain="$1"
  meta="/etc/one-click/wordpress/$domain/meta.conf"
  [[ -f "$meta" ]] || meta="/etc/one-click/sites/$domain/meta.conf"
  sed -En 's/^SITE_USER=(.*)/\1/p' "$meta"
}
check_permissions() {
  local domain="${1:-}" site_kind="${2:-}" meta=""
  local site_dir="" expected_user="" expected_group=""
  local candidate key value
  local -a found=()
  local bad=0 fixed=0 checked=0

  [[ -n "$domain" ]] || { error "No site selected for permissions check."; return 1; }
  # The selected menu is authoritative. Do not depend on stale global variables
  # or load unrelated Node.js metadata over WordPress/static metadata.
  case "$site_kind" in
    static|sites) site_kind="sites" ;;
    nodejs|apps/nodejs) site_kind="apps/nodejs" ;;
    wordpress|nextcloud|"") ;;
    *) error "Unsupported site type: $site_kind"; return 1 ;;
  esac
  if [[ -z "$site_kind" ]]; then
    for candidate in "${mode_ver:-}" "${type:-}" "${wpstatic:-}"; do
      case "$candidate" in
        static|sites) candidate="sites" ;;
        nodejs|apps/nodejs) candidate="apps/nodejs" ;;
        wordpress|nextcloud) ;;
        *) continue ;;
      esac
      if [[ -f "/etc/one-click/$candidate/$domain/meta.conf" ]]; then
        site_kind="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$site_kind" ]]; then
    for candidate in wordpress sites nextcloud apps/nodejs; do
      [[ -f "/etc/one-click/$candidate/$domain/meta.conf" ]] && found+=("$candidate")
    done
    if (( ${#found[@]} != 1 )); then
      error "Cannot identify an unambiguous site for $domain (${#found[@]} matching metadata files)."
      return 1
    fi
    site_kind="${found[0]}"
  fi

  meta="/etc/one-click/$site_kind/$domain/meta.conf"
  if [[ ! -f "$meta" ]]; then
    error "Site metadata does not exist: $meta"
    return 1
  fi
  # Parse only the three metadata fields needed. Sourcing the whole metadata
  # file overwrote shell state and could select the wrong site's directory.
  while IFS='=' read -r key value || [[ -n "${key:-}" ]]; do
    case "$key" in
      SITE_DIR) site_dir="$value" ;;
      SITE_USER) expected_user="$value" ;;
      SITE_GROUP) expected_group="$value" ;;
    esac
  done < "$meta"
  if [[ -z "$site_dir" || -z "$expected_user" || -z "$expected_group" ]]; then
    error "Incomplete SITE_DIR/SITE_USER/SITE_GROUP in $meta; ownership unchanged."
    return 1
  fi
  if [[ ! -d "$site_dir" ]]; then
    error "Directory does not exist: $site_dir"
    return 1
  fi
  # Avoid recursive ownership changes outside the selected site's own tree.
  local trusted_root="/etc/one-click/$site_kind/$domain" resolved_root resolved_dir
  resolved_root="$(realpath -e -- "$trusted_root")" || return 1
  resolved_dir="$(realpath -e -- "$site_dir")" || return 1
  if [[ "$resolved_dir" != "$resolved_root" && "$resolved_dir" != "$resolved_root/"* ]]; then
    error "Site directory is outside the selected site: $site_dir; ownership unchanged."
    return 1
  fi
  printf "${orange}[Scanning:]${reset} %s\n" "$site_dir"
  echo "${lime} THIS MAY TAKE A WHILE! PLEASE WAIT...${reset}"
  while IFS= read -r -d '' item; do
    checked=$((checked + 1))
    read -r owner group < <(stat -c '%U %G' "$item")
    if [[ "$owner" != "$expected_user" || "$group" != "$expected_group" ]]; then
      warn "Ownership mismatch detected"
      info \
        "Path   : $item" \
        "Current: $owner:$group" \
        "Expect : $expected_user:$expected_group"
      if chown "$expected_user:$expected_group" "$item" 2>/dev/null; then
        success "Ownership repaired"
        fixed=$((fixed + 1))
      else
        error "Failed to repair ownership"
        bad=$((bad + 1))
      fi
    fi
  # Only repair website files. DB registry and password files must remain under
  # their own protected ownership, and symlinks must not lead outside the site.
  done < <(find "$site_dir" -type l -prune -o -print0)
  echo
  warn "Permissions scan complete"
  info \
    "Checked : $checked items" \
    "Fixed   : $fixed items" \
    "Failed  : $bad items"
  if [[ "$bad" -eq 0 ]]; then
    success "Permissions successsfully fixed." \
      "Permissions now look correct."
  fi
  sleep 10
}
############################## APPS (NODEjs) #############################################
app_exists() {
  local runtime="$1"
  local domain="$2"
  [[ -d "${app_dir}/${runtime}/${domain}" ]]
}
app_user_from_domain() {
  local domain="$1" tmp suffix
  tmp="$(mktemp)" || return 1
  suffix="${tmp##*.}"
  rm -f -- "$tmp"
  # Linux account names may be length-limited: keep unique prefix and domain hint.
  printf '%s-%s\n' "$suffix" "${domain//./-}" | tr -cd 'a-zA-Z0-9-\n' | cut -c 1-32
}
app_runtime_path() {
  local runtime="$1"
  local domain="$2"
  echo "${app_dir}/${runtime}/${domain}"
}
app_allocate_port() {
  local used port reserved="" meta allocated
  # Listening sockets alone are insufficient: stopped apps still own their port.
  used="$(ss -lnt | awk 'NR>1 {split($4,a,":"); print a[length(a)]}')" || return 1
  for meta in "${app_dir}/nodejs/"*/meta.conf; do
    [[ -f "$meta" ]] || continue
    allocated="$(sed -n 's/^PORT=//p' "$meta" | head -n 1)"
    [[ "$allocated" =~ ^[0-9]+$ ]] && reserved+="${allocated}"$'\n'
  done
  for ((port=app_port_start;port<=app_port_end;port++)); do
    if ! grep -qx "$port" <<< "$used" && ! grep -qx "$port" <<< "$reserved"; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  return 1
}
app_create_user() {
  local domain="$1"
  local user
  user="$(app_user_from_domain "$domain")"
  if ! id "$user" &>/dev/null; then
    useradd \
      --system \
      --shell /usr/sbin/nologin \
      --home "/nonexistent" \
      "$user" || return 1
  fi
  echo "$user"
}
app_create_directories() {
  local runtime="$1"
  local domain="$2"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  mkdir -p \
    "$root/app" \
    "$root/logs" \
    "$root/env" \
    "$root/run" \
    "$root/config" \
    "$root/backups" \
    "$root/releases"
}
app_write_runtime() {
  local runtime="$1"
  local domain="$2"
  local port="$3"
  local start_command="$4"
  local user="$5"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  local node_path="${root}/node_bin/bin/node"
  cat > "${root}/runtime.json" <<EOF
{
  "runtime": "${runtime}",
  "domain": "${domain}",
  "port": ${port},
  "start": "${start_command}",
  "user": "${user}",
  "node_path": "${node_path}"
}
EOF
}
nodejs_validate_app() {
  local path="$1"
  [[ -f "${path}/package.json" ]]
}
app_nodejs_write_launcher() {
  local root="$1" file="${1}/.oneclick-start.sh"
  [[ -d "$root" && ! -L "$root" && -f "$root/runtime.json" ]] || return 1
  cat > "$file" <<'NODE_LAUNCHER'
#!/usr/bin/env bash
set -e
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
command_line="$(jq -er '.start | select(type == "string" and length > 0)' "$root/runtime.json")"
exec /bin/bash -c "$command_line"
NODE_LAUNCHER
  chown root:root "$file" && chmod 0755 "$file"
}
app_generate_systemd() {
  local runtime="$1"
  local domain="$2"
  local root service runtime_file port user node_path npm_path log_dir meta
  root="$(app_runtime_path "$runtime" "$domain")"
  runtime_file="${root}/runtime.json"
  service="one-click-${runtime}-${domain}.service"
  meta="/etc/one-click/apps/nodejs/$domain/meta.conf"
  log_dir="/var/log/one-click/${domain}/apps/${runtime}"
  [[ -f "$runtime_file" ]] || {
    error "Runtime metadata missing: $runtime_file"
    return 1
  }
  jq empty "$runtime_file" >/dev/null 2>&1 || {
    error "Invalid Node.js runtime metadata: $runtime_file"
    return 1
  }
  port="$(jq -r '.port // empty' "$runtime_file")"
  user="$(jq -r '.user // empty' "$runtime_file")"
  node_path="$(jq -r '.node_path // empty' "$runtime_file")"
  npm_path="${root}/node_bin/bin/npm"
  [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]] || {
    error "Invalid Node.js runtime port for $domain."
    return 1
  }
  [[ -n "$user" ]] && id "$user" >/dev/null 2>&1 || {
    error "Node.js service user is invalid for $domain."
    return 1
  }
  [[ -x "$node_path" && -x "$npm_path" ]] || {
    error "Isolated Node.js runtime is incomplete for $domain."
    return 1
  }
  [[ -f "${root}/app/package.json" ]] || {
    error "package.json is missing for $domain."
    return 1
  }
  mkdir -p "$log_dir" "${root}/.npm" || return 1
  chown -R "$user":"${webserver_user:-$user}" "$log_dir" "${root}/.npm" || return 1
  app_nodejs_write_launcher "$root" || return 1
  cat > "/etc/systemd/system/${service}" <<EOF
[Unit]
Description=One-Click ${runtime} App (${domain})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
WorkingDirectory=${root}/app
Environment=PORT=${port}
Environment=NODE_ENV=production
Environment=HOME=${root}
Environment=PATH=${root}/node_bin/bin:/usr/bin:/bin
Environment=npm_config_cache=${root}/.npm
EnvironmentFile=-${root}/env/.env
ExecStart=/bin/bash ${root}/.oneclick-start.sh
Restart=on-failure
RestartSec=5
StandardOutput=append:${log_dir}/app.log
StandardError=append:${log_dir}/error.log

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload || return 1
  if ! systemctl enable --now "$service"; then
    error "Failed to start Node.js service $service."
    journalctl -u "$service" -n 30 --no-pager 2>/dev/null || true
    return 1
  fi
  if ! systemctl is-active --quiet "$service"; then
    error "Node.js service did not remain active: $service"
    journalctl -u "$service" -n 30 --no-pager 2>/dev/null || true
    return 1
  fi
  if [[ -f "$meta" ]]; then
    if grep -q '^SYSTEMD_ENABLED=' "$meta"; then
      sed -i 's/^SYSTEMD_ENABLED=.*/SYSTEMD_ENABLED=true/' "$meta"
    else
      echo "SYSTEMD_ENABLED=true" >> "$meta"
    fi
    if grep -q '^SYSTEMD_VHOST=' "$meta"; then
      sed -i "s|^SYSTEMD_VHOST=.*|SYSTEMD_VHOST=/etc/systemd/system/${service}|" "$meta"
    else
      echo "SYSTEMD_VHOST=/etc/systemd/system/${service}" >> "$meta"
    fi
    if grep -q '^SYSTEMD_SERVICE_NAME=' "$meta"; then
      sed -i "s|^SYSTEMD_SERVICE_NAME=.*|SYSTEMD_SERVICE_NAME=${service}|" "$meta"
    else
      echo "SYSTEMD_SERVICE_NAME=${service}" >> "$meta"
    fi
  fi
  success "Node.js service active: $service"
}
app_generate_nginx_proxy() {
  local domain="$1"
  local port="$2"
  local nginx_conf_file backup log_dir
  [[ "$port" =~ ^[0-9]+$ ]] || {
    error "Invalid Node.js backend port: $port"
    return 1
  }
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
  fi
  log_dir="/var/log/one-click/${domain}/nginx"
  mkdir -p "$log_dir" "$(dirname "$nginx_conf_file")"
  backup="${nginx_conf_file}.one-click-node-bak"
  [[ -f "$nginx_conf_file" ]] && cp -a "$nginx_conf_file" "$backup"
  cat > "$nginx_conf_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    access_log ${log_dir}/access.log oneclick;
    error_log ${log_dir}/error.log warn;

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 300;
        proxy_connect_timeout 30;
    }
}
EOF
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    ln -sfn "$nginx_conf_file" "/etc/nginx/sites-enabled/$domain.conf"
  fi
  if ! nginx -t >/dev/null 2>&1; then
    if [[ -f "$backup" ]]; then
      cp -a "$backup" "$nginx_conf_file"
    else
      rm -f -- "$nginx_conf_file"
      [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]] && rm -f -- "/etc/nginx/sites-enabled/$domain.conf"
    fi
    nginx -t >/dev/null 2>&1 || true
    error "Nginx proxy configuration validation failed for $domain. Original configuration restored."
    return 1
  fi
  if ! systemctl reload nginx; then
    if [[ -f "$backup" ]]; then cp -a "$backup" "$nginx_conf_file"; else rm -f -- "$nginx_conf_file"; fi
    [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]] && [[ ! -f "$backup" ]] && rm -f -- "/etc/nginx/sites-enabled/$domain.conf"
    systemctl reload nginx >/dev/null 2>&1 || true
    error "Nginx reload failed; proxy configuration reverted."
    return 1
  fi
}
app_generate_apache_proxy() {
  local domain="$1"
  local port="$2"
  local apache_conf_file service backup log_dir
  [[ "$port" =~ ^[0-9]+$ ]] || {
    error "Invalid Node.js backend port: $port"
    return 1
  }
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    apache_conf_file="/etc/apache2/sites-available/$domain.conf"
    service="apache2"
    a2enmod proxy proxy_http headers >/dev/null 2>&1 || {
      error "Failed to enable required Apache proxy modules."
      return 1
    }
  else
    apache_conf_file="/etc/httpd/conf.d/$domain.conf"
    service="httpd"
  fi
  log_dir="/var/log/one-click/${domain}/${service}"
  mkdir -p "$log_dir" "$(dirname "$apache_conf_file")"
  backup="${apache_conf_file}.one-click-node-bak"
  [[ -f "$apache_conf_file" ]] && cp -a "$apache_conf_file" "$backup"
  cat > "$apache_conf_file" <<EOF
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:${port}/
    ProxyPassReverse / http://127.0.0.1:${port}/

    RequestHeader set X-Forwarded-Proto "expr=%{REQUEST_SCHEME}"

    ErrorLog ${log_dir}/error.log
    CustomLog ${log_dir}/access.log combined
</VirtualHost>
EOF
  if [[ "$service" == "apache2" ]]; then
    a2ensite "${domain}.conf" >/dev/null 2>&1 || return 1
    if ! apache2ctl configtest >/dev/null 2>&1; then
      if [[ -f "$backup" ]]; then cp -a "$backup" "$apache_conf_file"; else a2dissite "${domain}.conf" >/dev/null 2>&1 || true; rm -f -- "$apache_conf_file"; fi
      error "Apache proxy configuration validation failed for $domain. Original configuration restored."
      return 1
    fi
  else
    if ! httpd -t >/dev/null 2>&1; then
      if [[ -f "$backup" ]]; then cp -a "$backup" "$apache_conf_file"; else rm -f -- "$apache_conf_file"; fi
      error "HTTPD proxy configuration validation failed for $domain. Original configuration restored."
      return 1
    fi
  fi
  if ! systemctl reload "$service"; then
    if [[ -f "$backup" ]]; then cp -a "$backup" "$apache_conf_file"; else
      [[ "$service" == "apache2" ]] && a2dissite "${domain}.conf" >/dev/null 2>&1 || true
      rm -f -- "$apache_conf_file"
    fi
    systemctl reload "$service" >/dev/null 2>&1 || true
    error "Apache reload failed; proxy configuration reverted."
    return 1
  fi
}
app_service_name() {
  local runtime="$1"
  local domain="$2"
  echo "one-click-${runtime}-${domain}.service"
}
app_start() {
  local runtime="$1"
  local domain="$2"
  systemctl start "$(app_service_name "$runtime" "$domain")"
}
app_stop() {
  local runtime="$1"
  local domain="$2"
  systemctl stop "$(app_service_name "$runtime" "$domain")"
}
app_restart() {
  local runtime="$1"
  local domain="$2"
  systemctl restart "$(app_service_name "$runtime" "$domain")"
}
app_status() {
  local runtime="$1"
  local domain="$2"
  systemctl status "$(app_service_name "$runtime" "$domain")"
}
app_logs() {
  local runtime="$1"
  local domain="$2"
  local app_log_dir="/var/log/one-click/${domain}/apps/${runtime}"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  tail -F \
    "${app_log_dir}/app.log" \
    "${app_log_dir}/error.log"
}
ensure_isolated_nodejs() {
  local root="$1"
  local domain="${2:-}"
  local meta="${root}/meta.conf"
  local node_dir="${root}/node_bin"
  local arch node_version tarball url sums_url stage expected
  [[ -n "$root" && -d "$root" ]] || {
    error "Invalid Node.js runtime root: $root"
    return 1
  }
  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64) arch="arm64" ;;
    *)
      error "Unsupported architecture: $(uname -m)"
      return 1
      ;;
  esac
  if [[ -x "${node_dir}/bin/node" && -x "${node_dir}/bin/npm" ]]; then
    node_version="$("${node_dir}/bin/node" --version 2>/dev/null || true)"
    if [[ -n "$node_version" && -f "$meta" ]]; then
      if grep -q '^NODE_VERSION=' "$meta"; then
        sed -i "s|^NODE_VERSION=.*|NODE_VERSION=$node_version|" "$meta"
      else
        echo "NODE_VERSION=$node_version" >> "$meta"
      fi
    fi
    return 0
  fi
  node_version="$(
    curl -fsSL https://nodejs.org/dist/index.json |
      jq -r '[.[] | select(.lts != false)][0].version // empty'
  )" || {
    error "Unable to determine the current Node.js LTS release."
    return 1
  }
  [[ "$node_version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    error "Invalid Node.js release value returned: ${node_version:-empty}"
    return 1
  }
  tarball="node-${node_version}-linux-${arch}.tar.xz"
  url="https://nodejs.org/dist/${node_version}/${tarball}"
  sums_url="https://nodejs.org/dist/${node_version}/SHASUMS256.txt"
  stage="${root}/.node-install.$$"
  rm -rf "$stage"
  mkdir -p "$stage/node"
  info "Installing Node.js ${node_version} for ${arch}."
  curl -fL --retry 3 --retry-delay 2 "$url" -o "$stage/$tarball" || {
    rm -rf "$stage"
    error "Failed to download Node.js archive."
    return 1
  }
  curl -fL --retry 3 --retry-delay 2 "$sums_url" -o "$stage/SHASUMS256.txt" || {
    rm -rf "$stage"
    error "Failed to download Node.js checksums."
    return 1
  }
  expected="$(awk -v f="$tarball" '$2==f {print $1; exit}' "$stage/SHASUMS256.txt")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
    rm -rf "$stage"
    error "Node.js checksum entry was not found."
    return 1
  }
  printf '%s  %s\n' "$expected" "$stage/$tarball" | sha256sum -c - >/dev/null 2>&1 || {
    rm -rf "$stage"
    error "Node.js archive checksum validation failed."
    return 1
  }
  tar -xJf "$stage/$tarball" -C "$stage/node" --strip-components=1 || {
    rm -rf "$stage"
    error "Failed to extract Node.js runtime."
    return 1
  }
  [[ -x "$stage/node/bin/node" && -x "$stage/node/bin/npm" ]] || {
    rm -rf "$stage"
    error "Extracted Node.js runtime is incomplete."
    return 1
  }
  rm -rf "$node_dir"
  mv "$stage/node" "$node_dir" || {
    rm -rf "$stage"
    error "Failed to activate isolated Node.js runtime."
    return 1
  }
  rm -rf "$stage"
  if [[ -f "$meta" ]]; then
    if grep -q '^NODE_VERSION=' "$meta"; then
      sed -i "s|^NODE_VERSION=.*|NODE_VERSION=$node_version|" "$meta"
    else
      echo "NODE_VERSION=$node_version" >> "$meta"
    fi
  fi
  success "Isolated Node.js engine placed at ${node_dir}/bin/node"
}
# Keep app data writable, but control metadata, binaries and backups admin-owned.
app_fix_permissions() {
  local domain="$1" root meta user group dir
  root="$(app_runtime_path nodejs "$domain")"
  meta="$root/meta.conf"
  [[ -f "$meta" && ! -L "$root" ]] || { error "Invalid Node.js metadata: $domain"; return 1; }
  user="$(sed -n 's/^SITE_USER=//p' "$meta" | head -n 1)"
  group="$(sed -n 's/^SITE_GROUP=//p' "$meta" | head -n 1)"
  [[ "$user" =~ ^[a-zA-Z0-9_-]+$ && "$group" =~ ^[a-zA-Z0-9_-]+$ ]] || { error "Invalid Node.js service identity"; return 1; }
  id "$user" >/dev/null 2>&1 && getent group "$group" >/dev/null 2>&1 || { error "Missing Node.js user/group"; return 1; }
  for dir in app logs env run config releases .npm; do
    mkdir -p "$root/$dir" || return 1
    # Do not traverse symlinks into another application's files.
    find "$root/$dir" -type l -prune -o -exec chown "$user:$group" {} + || return 1
  done
  mkdir -p "$root/backups" || return 1
  chown root:root "$root" "$meta" || return 1
  chmod 0755 "$root" && chmod 0644 "$meta" || return 1
  if [[ -f "$root/.oneclick-start.sh" ]]; then
    chown root:root "$root/.oneclick-start.sh" && chmod 0755 "$root/.oneclick-start.sh" || return 1
  fi
  if [[ -f "$root/runtime.json" ]]; then
    chown root:root "$root/runtime.json" && chmod 0644 "$root/runtime.json" || return 1
  fi
  if [[ -d "$root/node_bin" ]]; then
    find "$root/node_bin" -type l -prune -o -exec chown root:root {} + || return 1
  fi
  find "$root/backups" -type l -prune -o -exec chown root:root {} + || return 1
  chmod 0700 "$root/backups" || return 1
  if [[ -f "$root/env/.env" ]]; then chmod 0600 "$root/env/.env" || return 1; fi
}
app_nodejs_vhost_available() {
  local domain="$1" path
  for path in "/etc/nginx/sites-available/$domain.conf" "/etc/nginx/sites-enabled/$domain.conf" "/etc/nginx/conf.d/$domain.conf" "/etc/apache2/sites-available/$domain.conf" "/etc/apache2/sites-enabled/$domain.conf" "/etc/httpd/conf.d/$domain.conf"; do
    [[ ! -e "$path" && ! -L "$path" ]] || { error "Existing web configuration must not be overwritten: $path"; return 1; }
  done
}
app_nodejs_cleanup_partial() {
  local domain="$1" root="$2" user="$3" webserver="$4" user_created="${5:-0}" service
  [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ && "$root" == "${app_dir}/nodejs/${domain}" ]] || return 1
  service="$(app_service_name nodejs "$domain")"
  systemctl disable --now "$service" >/dev/null 2>&1 || true
  rm -f -- "/etc/systemd/system/$service" "/etc/systemd/system/${service}.d/one-click-start.conf"
  rmdir -- "/etc/systemd/system/${service}.d" 2>/dev/null || true
  rm -f -- "/etc/logrotate.d/one-click-nodejs-${domain}"
  if [[ "$webserver" == nginx ]]; then
    rm -f -- "/etc/nginx/sites-available/$domain.conf" "/etc/nginx/sites-enabled/$domain.conf" "/etc/nginx/conf.d/$domain.conf"
    systemctl reload nginx >/dev/null 2>&1 || true
  else
    rm -f -- "/etc/apache2/sites-available/$domain.conf" "/etc/apache2/sites-enabled/$domain.conf" "/etc/httpd/conf.d/$domain.conf"
    systemctl reload apache2 >/dev/null 2>&1 || systemctl reload httpd >/dev/null 2>&1 || true
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  [[ -d "$root" && ! -L "$root" ]] && rm -rf -- "$root"
  if [[ "$user_created" == 1 && -n "$user" ]] && id "$user" >/dev/null 2>&1; then
    userdel "$user" >/dev/null 2>&1 || warn "Remove orphaned app user manually: $user"
  fi
}
app_create_nodejs_steps() {
  local domain="$1" root="$2" user="$3" webserver="$4" webserver_user="$5" port="$6" git_repo="${7:-}" enable_hsts="${8:-no}" runtime=nodejs
  app_create_directories "$runtime" "$domain" || return 1
  ensure_isolated_nodejs "$root" "$domain" || return 1
  if [[ -n "$git_repo" ]]; then
    # An existing but empty target is valid for git clone.
    git clone -- "$git_repo" "$root/app" || { error "Git clone failed"; return 1; }
  fi
  if [[ ! -f "${root}/app/package.json" && -n "$git_repo" ]]; then
    error "Cloned repository has no package.json; refusing to replace its contents with a default app."
    return 1
  fi
  if [[ ! -f "${root}/app/package.json" ]]; then
    info "No package.json found. Creating a generic default configuration."
    mkdir -p "${root}/app/public"
    info "Generating default page"
  cat <<'EOF' > "${root}/app/public/index.html"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>SiteHUB Default WebPage</title><link rel="icon" type="image/png" href="https://sitehub.agency/wp-content/uploads/2025/06/cropped-Untitled-design-9-e1750161170804.png"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet"><style>*{margin:0;padding:0;box-sizing:border-box}body,html{height:100%;font-family:'Roboto',sans-serif}body{background:linear-gradient(135deg,#28a745,#003366);display:flex;flex-direction:column;justify-content:space-between;color:#fff}header{text-align:center;padding:50px 20px}header img.logo{height:80px;margin-bottom:20px}header h1{font-size:2.5em;margin-bottom:10px}header p{font-size:1.2em}.visuals{position:absolute;top:0;left:0;width:100%;height:100%;overflow:hidden;z-index:0}.visuals span{position:absolute;display:block;border-radius:50%;background:rgba(255,255,255,.05);animation:float 25s linear infinite}@keyframes float{0%{transform:translateY(0) rotate(0deg)}100%{transform:translateY(-1000px) rotate(720deg)}}main{position:relative;z-index:1;max-width:900px;margin:0 auto;padding:20px;text-align:center}section{margin:50px 0}.main-hero h2{font-size:2em;margin-bottom:15px}.main-hero p{font-size:1.1em;line-height:1.6;margin-bottom:25px}.cta-btn{display:inline-block;background:#fff;color:#003366;font-weight:700;text-decoration:none;padding:12px 25px;border-radius:50px;margin:10px;transition:all .3s ease}.cta-btn:hover{background:#e0e0e0}footer{text-align:center;padding:20px;font-size:.9em;color:rgba(255,255,255,.7)}@media(max-width:768px){header h1{font-size:2em}.main-hero h2{font-size:1.6em}}</style></head><body><div class="visuals" id="visuals"></div><header><img class="logo" src="https://us1.plesk.sitehub.agency/images/logos/6EwrLBBn5Xg.png" alt="SiteHUB"><h1>Default Web Page for <span id="domain-name">dynamic-domain.ng</span></h1><p>This page is generated by <a href="https://sitehub.agency" style="color:darkgreen;text-decoration:none;">Site <span style="color:blue;text-decoration:none;">HUB</span></a>, the leading hosting provider in Nigeria.<br>You see this page because there is no website at this address.</p></header><main id="placeholder-content"></main><footer>Copyright &copy; SiteHUB Agency <span id="year"></span>. All rights reserved - RC6935293</footer><script>document.getElementById("year").textContent=new Date().getFullYear();document.addEventListener("DOMContentLoaded",()=>{const e=location.hostname,t=location.protocol+"//"+e+":8443",n="support@sitehub.agency";document.getElementById("domain-name").textContent=e;const o=document.getElementById("placeholder-content");let a="";a+=`<section class="main-hero"><h2>Your domain <strong>${e}</strong> is now live!</h2><p><strong>${e}</strong> default page has been generated by the One-Click Toolbox Automation tool . No website content has been uploaded yet.<br>For more information about One-Click Toolbox:</p><a class="cta-btn" href="https://github.com/SiteHUB-NG/One-Click/" target="_blank">View On GitHub</a><br><br><br><hr><br><h2>Need Hosting?</h2><p>Start your own website in minutes with our web hosting & VPS plans!</p><a class="cta-btn" href="https://sitehub.agency/shared/" target="_blank">View Web Hosting Plans</a><a class="cta-btn" href="https://features.sitehub.agency/vps/" target="_blank">View VPS Plans</a></section>`,a+=`<section class="main-hero"><h2>Need Help?</h2><p>Contact our support team: <a style="color:#fff;text-decoration:underline;" href="mailto:${n}">${n}</a></p></section>`,o.innerHTML=a;const r=document.getElementById("visuals");for(let t=0;t<30;t++){let n=document.createElement("span"),o=60*Math.random()+20;n.style.width=o+"px",n.style.height=o+"px",n.style.left=100*Math.random()+"%",n.style.top=100*Math.random()+"%",n.style.animationDuration=20+20*Math.random()+"s",r.appendChild(n)}});</script></body></html>
EOF
    cat > "${root}/app/package.json" <<EOF
{
  "name": "${domain//./-}",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {}
}
EOF
  cat > "${root}/app/index.js" <<EOF
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = process.env.PORT || 3000;
const publicDir = path.join(__dirname, 'public');

const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon'
};

const server = http.createServer((req, res) => {
    const safeUrl = decodeURIComponent(req.url.split('?')[0]);
    let filePath = path.join(publicDir, safeUrl === '/' ? 'index.html' : safeUrl);

    const relative = path.relative(publicDir, filePath);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
        res.writeHead(403);
        return res.end('403 Forbidden');
    }

    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(404);
            return res.end('404 Not Found');
        }

        const ext = path.extname(filePath);
        res.writeHead(200, {
            'Content-Type': mimeTypes[ext] || 'application/octet-stream',
            'X-Content-Type-Options': 'nosniff'
        });

        res.end(content);
    });
});

server.listen(port, '127.0.0.1', () => {
    console.log(\`Server listening on \${port}\`);
});
EOF
  fi
  nodejs_validate_app "$root/app" || { error "Node.js package.json missing"; return 1; }
  install_webserver nodejs "$domain" "$root/app" "$enable_hsts" || return 1
  if [[ "$webserver" == nginx ]]; then
    app_generate_nginx_proxy "$domain" "$port" || return 1
  else
    app_generate_apache_proxy "$domain" "$port" || return 1
  fi
  app_fix_permissions "$domain" || return 1
  info "Running npm install via isolated binary engine."
  if ! ( cd "$root/app" && sudo -u "$user" env PATH="$root/node_bin/bin:/usr/bin:/bin" HOME="$root" npm_config_cache="$root/.npm" "$root/node_bin/bin/npm" install ); then
    error "npm install failed for $domain"
    return 1
  fi
  app_write_runtime "$runtime" "$domain" "$port" "npm start" "$user" || return 1
  app_generate_systemd "$runtime" "$domain" || return 1
  one-click engine "allow $webserver" -y || return 1
  # SSL is optional in this product: preserve its retry/skip behavior.
  install_letsencrypt nodejs
}
app_create_nodejs() {
  local git_repo="${1:-}" runtime=nodejs webserver_choice webserver webserver_user="" enable_hsts=no
  local root user="" user_created=0 port app_provision_active=0 br
  while true; do
    br=0
    read -rp "${cyan}[USER]${reset} Enter a domain name to use for your new app: " domain
    if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then warn "Invalid domain name"; br=1; fi
    if [[ -n "$domain" && "$br" -ne 1 ]]; then export domain; break; fi
    warn "Domain cannot be empty!"
  done
  info "Which webserver should host $domain?" "[1] Nginx" "[2] Apache"
  read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver_choice
  case "$webserver_choice" in
    1)
      webserver=nginx
      if id nginx >/dev/null 2>&1; then webserver_user=nginx; elif id www-data >/dev/null 2>&1; then webserver_user=www-data; fi
      if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
        error "Apache is already active"; return 1
      fi
      ;;
    2)
      webserver=apache
      if command -v apt >/dev/null 2>&1; then webserver_user=www-data; else webserver_user=apache; fi
      if systemctl is-active --quiet nginx; then error "Nginx is already active"; return 1; fi
      ;;
    *) error "Invalid selection"; return 1 ;;
  esac
  [[ -n "$webserver_user" ]] && id "$webserver_user" >/dev/null 2>&1 || { error "Webserver account missing"; return 1; }
  read -rp "${cyan}[USER]${blue} Enable HSTS: ${reset}" enable_hsts
  [[ "${enable_hsts,,}" =~ ^(y|yes)$ ]] && enable_hsts=yes || enable_hsts=no
  # A domain can belong to only one One-Click site type or existing vhost.
  local other
  for other in "${app_dir}/nodejs/$domain" "/etc/one-click/sites/$domain" "/etc/one-click/wordpress/$domain" "/etc/one-click/nextcloud/$domain"; do
    [[ ! -e "$other" && ! -L "$other" ]] || { error "Domain is already managed: $other"; return 1; }
  done
  app_nodejs_vhost_available "$domain" || return 1
  port="$(app_allocate_port)" || { error "No free Node.js backend port"; return 1; }
  root="$(app_runtime_path "$runtime" "$domain")"
  # No filesystem/user mutations occur before all the preflight checks above.
  mkdir -p -- "$root" || return 1
  user="$(app_user_from_domain "$domain")"
  if id "$user" >/dev/null 2>&1; then
    error "Generated Node.js user already exists: $user"; rmdir "$root" 2>/dev/null || true; return 1
  fi
  if ! useradd --system --shell /usr/sbin/nologin --home /nonexistent "$user"; then
    rmdir "$root" 2>/dev/null || true
    error "Failed to create isolated Node.js user"
    return 1
  fi
  user_created=1
  app_provision_active=1
  # EXIT safeguard applies only to this new Node.js application's resources.
  trap 'if [[ "${app_provision_active:-0}" == 1 ]]; then app_nodejs_cleanup_partial "$domain" "$root" "$user" "$webserver" "$user_created"; fi' EXIT
  cat > "$root/meta.conf" <<EOF
USER=$user
SITE_USER=$user
SITE_GROUP=$webserver_user
WEBSERVER_USER=$webserver_user
WEBSERVER=$webserver
WEBSERVER_SERVICE=$webserver
APP_DIR=$app_dir
SITE_DIR=$root
TYPE=nodejs
PORT=$port
SYSTEMD_VHOST=one-click-nodejs-${domain}.service
EOF
  if ! app_create_nodejs_steps "$domain" "$root" "$user" "$webserver" "$webserver_user" "$port" "$git_repo" "$enable_hsts"; then
    app_nodejs_cleanup_partial "$domain" "$root" "$user" "$webserver" "$user_created"
    app_provision_active=0; trap - EXIT
    error "Node.js installation failed; partial resources removed"
    return 1
  fi
  # Routing entry only after successful provisioning.
  if ! grep -Fq $'127.0.0.1\t'"$domain" /etc/hosts 2>/dev/null; then
    grep -q '^# One-Click Routing$' /etc/hosts 2>/dev/null || echo '# One-Click Routing' >> /etc/hosts
    sed -i.one-click_bak "/^# One-Click Routing$/a 127.0.0.1\t${domain}\t# One-Click Entry" /etc/hosts || warn "Local hosts entry could not be added"
  fi
  app_provision_active=0; trap - EXIT
  type="apps/nodejs"
  printf "${magenta}[NODEjs]${reset} %s\n" "=================================================" "NODEJS APPLICATION CREATED" "=================================================" " " "Domain:  $domain" "Runtime: nodejs" "Port:    $port" "Path:    $root" " "
  success "Node.js hosting successfully configured and proxied"
}
# Node-specific removal does not call the PHP/database/Redis teardown function.
app_delete() {
  local domain="$1" root user webserver service confirm
  root="$(app_runtime_path nodejs "$domain")"
  [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ && -f "$root/meta.conf" && ! -L "$root" ]] || {
    error "Node.js metadata missing or unsafe path: $domain"
    return 1
  }
  user="$(sed -n 's/^SITE_USER=//p' "$root/meta.conf" | head -n 1)"
  webserver="$(sed -n 's/^WEBSERVER=//p' "$root/meta.conf" | head -n 1)"
  [[ "$webserver" == nginx || "$webserver" == apache ]] || { error "Unknown Node.js webserver"; return 1; }
  service="$(app_service_name nodejs "$domain")"
  warn "Permanently delete Node.js app $domain, including its local backups and environment files?"
  read -rp "Type DELETE to confirm: " confirm
  [[ "$confirm" == DELETE ]] || { info "Deletion cancelled"; return 0; }
  systemctl disable --now "$service" >/dev/null 2>&1 || true
  rm -f -- "/etc/systemd/system/$service" "/etc/systemd/system/${service}.d/one-click-start.conf"
  rmdir -- "/etc/systemd/system/${service}.d" 2>/dev/null || true
  rm -f -- "/etc/logrotate.d/one-click-nodejs-${domain}"
  if [[ "$webserver" == nginx ]]; then
    rm -f -- "/etc/nginx/sites-enabled/$domain.conf" "/etc/nginx/sites-available/$domain.conf" "/etc/nginx/conf.d/$domain.conf"
    systemctl reload nginx >/dev/null 2>&1 || warn "Nginx reload failed after removal"
  else
    rm -f -- "/etc/apache2/sites-enabled/$domain.conf" "/etc/apache2/sites-available/$domain.conf" "/etc/httpd/conf.d/$domain.conf"
    systemctl reload apache2 >/dev/null 2>&1 || systemctl reload httpd >/dev/null 2>&1 || warn "Apache reload failed after removal"
  fi
  # Remove only the exact hosts entry created by One-Click.
  sed -i "/^127[.]0[.]0[.]1[[:space:]]\+${domain//./[.]}[[:space:]]*# One-Click Entry$/d" /etc/hosts 2>/dev/null || true
  rm -rf -- "$root"
  rm -rf -- "/var/log/one-click/$domain/apps/nodejs"
  if [[ -n "$user" && "$user" =~ ^[a-zA-Z0-9_-]+$ ]] && id "$user" >/dev/null 2>&1; then
    userdel "$user" >/dev/null 2>&1 || warn "Unable to remove isolated user: $user"
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  warn "Check for remaining SSL certificates and firewall rules before reusing $domain."
  success "Node.js application deleted: $domain"
}
# Node-specific backups never use static-site PHP/database restore handlers.
app_backup() {
  local domain="$1" root dest timestamp
  root="$(app_runtime_path nodejs "$domain")"
  [[ -f "$root/runtime.json" && -d "$root/app" ]] || { error "Node.js application metadata or files are missing"; return 1; }
  timestamp="$(date +%Y%m%d-%H%M%S)"
  dest="$root/backups/$timestamp"
  [[ ! -e "$dest" ]] || dest="${dest}-$$"
  ( umask 077; mkdir -p -- "$dest" && tar -czf "$dest/app.tar.gz" -C "$root" app && cp "$root/runtime.json" "$dest/runtime.json" ) || {
    rm -rf -- "$dest"
    error "Node.js app backup failed"
    return 1
  }
  success "Node.js application code backed up at $dest (external env/ excluded; check app/ for any embedded secrets)"
}
app_restore() {
  local domain="$1" root service choice archive stage snapshot candidate file rel owner group
  local -a backups=()
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  [[ -d "$root/app" && -f "$root/runtime.json" ]] || { error "Node.js application not found"; return 1; }
  # Latest first, including multiple backups taken in the same second.
  mapfile -d '' -t backups < <(find "$root/backups" -mindepth 2 -maxdepth 2 -type f -name app.tar.gz -printf '%T@ %p\0' 2>/dev/null | sort -z -nr | cut -z -d ' ' -f 2-)
  ((${#backups[@]})) || { warn "No Node.js app backups found"; return 0; }
  printf '%s\n' "Available Node.js application backups (source files only):"
  local i
  for i in "${!backups[@]}"; do printf '%s) %s\n' "$((i+1))" "$(dirname "${backups[i]}")"; done
  read -rp "Select backup [0 to cancel]: " choice
  [[ "$choice" == 0 ]] && return 0
  [[ "$choice" =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#backups[@]})) || { error "Invalid backup selection"; return 1; }
  archive="${backups[choice-1]}"
  # Never extract a backup with absolute, traversal or unexpected paths.
  while IFS= read -r rel; do
    [[ "$rel" == "app" || "$rel" == "app/" || "$rel" == app/* ]] || { error "Unexpected archive path: $rel"; return 1; }
    [[ "$rel" != *'/../'* && "$rel" != '../'* && "$rel" != *'/..' ]] || { error "Unsafe archive path: $rel"; return 1; }
  done < <(tar -tzf "$archive")
  stage="$(mktemp -d "$root/.node-restore.XXXXXXXX")" || return 1
  if ! tar -xzf "$archive" -C "$stage" --no-same-owner --no-same-permissions || [[ ! -d "$stage/app" ]]; then
    rm -rf -- "$stage"
    error "Failed to unpack Node.js backup; current app unchanged"
    return 1
  fi
  read -rp "Replace application files for $domain and restart the service? [y/N]: " choice
  if [[ "$choice" != y && "$choice" != yes ]]; then rm -rf -- "$stage"; return 0; fi
  owner="$(jq -r '.user // empty' "$root/runtime.json")"
  [[ -n "$owner" ]] && id "$owner" >/dev/null 2>&1 || { rm -rf -- "$stage"; error "Invalid service user"; return 1; }
  group="$(stat -c '%G' "$root/app")"
  chown -R "$owner:$group" "$stage/app" || { rm -rf -- "$stage"; return 1; }
  snapshot="$stage/previous"
  if ! mv "$root/app" "$snapshot"; then rm -rf -- "$stage"; return 1; fi
  if ! mv "$stage/app" "$root/app" || ! systemctl restart "$service" || ! systemctl is-active --quiet "$service"; then
    rm -rf -- "$root/app"
    mv "$snapshot" "$root/app" || error "CRITICAL: previous app remains at $snapshot"
    systemctl restart "$service" >/dev/null 2>&1 || true
    [[ -d "$snapshot" ]] || rm -rf -- "$stage"
    error "Node.js restore failed; original application restored if possible"
    return 1
  fi
  rm -rf -- "$stage"
  success "Node.js application files restored; environment and runtime settings left intact"
}
# Node.js management. These helpers do not mutate WordPress, Nextcloud or static sites.
# Migrate a previously installed Node.js service to the root-owned launcher.
# Backup and restore the unit if systemd rejects the replacement.
app_nodejs_ensure_service_launcher() {
  local domain="$1" root unit dropin
  root="$(app_runtime_path nodejs "$domain")"
  unit="/etc/systemd/system/$(app_service_name nodejs "$domain")"
  dropin="${unit}.d/one-click-start.conf"
  [[ -f "$unit" && ! -L "$unit" ]] || { error "Node.js systemd unit is missing"; return 1; }
  app_nodejs_write_launcher "$root" || return 1
  if grep -Fqx "ExecStart=/bin/bash $root/.oneclick-start.sh" "$unit"; then return 0; fi
  # Preserve the original unit: use a dedicated Node.js drop-in instead.
  mkdir -p -- "$(dirname "$dropin")" || return 1
  cat > "$dropin" <<EOF
[Service]
ExecStart=
ExecStart=/bin/bash $root/.oneclick-start.sh
EOF
  chown root:root "$dropin" && chmod 0644 "$dropin" || return 1
  if ! systemctl daemon-reload; then
    rm -f "$dropin"
    rmdir -- "$(dirname "$dropin")" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    error "Unable to migrate Node.js service launcher"; return 1
  fi
}
app_nodejs_context() {
  local selected="$1" root
  [[ "$selected" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}$ ]] || { error "Invalid Node.js domain"; return 1; }
  root="$(app_runtime_path nodejs "$selected")"
  [[ -d "$root" && ! -L "$root" && -f "$root/meta.conf" && -f "$root/runtime.json" && -d "$root/app" ]] || {
    error "Node.js metadata or application is missing for $selected"; return 1;
  }
  jq -e --arg domain "$selected" '.runtime == "nodejs" and .domain == $domain and (.port|type == "number") and (.user|type == "string")' "$root/runtime.json" >/dev/null 2>&1 || {
    error "Invalid runtime metadata for $selected"; return 1;
  }
  return 0
}
app_nodejs_owner() {
  local root
  root="$(app_runtime_path nodejs "$1")"
  jq -er '.user | select(type == "string" and test("^[a-zA-Z0-9_-]+$"))' "$root/runtime.json"
}
app_nodejs_as_owner() {
  local domain="$1"; shift
  local root user
  root="$(app_runtime_path nodejs "$domain")"
  user="$(app_nodejs_owner "$domain")" || return 1
  id "$user" >/dev/null 2>&1 || return 1
  sudo -u "$user" env "HOME=$root" "PATH=$root/node_bin/bin:/usr/bin:/bin" "npm_config_cache=$root/.npm" "$@"
}
app_nodejs_health() {
  local domain="$1" root service port path code
  app_nodejs_context "$domain" || return 1
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  port="$(jq -er '.port' "$root/runtime.json")" || return 1
  path="$(jq -r '.health_path // "/"' "$root/runtime.json")"
  [[ "$port" =~ ^[0-9]+$ && "$path" == /* && "$path" != *$'\n'* ]] || { error "Invalid health check configuration"; return 1; }
  if ! systemctl is-active --quiet "$service"; then error "Node.js service is not active: $service"; return 1; fi
  code="$(curl -sS -o /dev/null --max-time 8 --connect-timeout 3 -w '%{http_code}' -H "Host: $domain" "http://127.0.0.1:${port}${path}" 2>/dev/null)" || {
    error "Node.js process is active, but its HTTP backend is unreachable on port $port"; return 1;
  }
  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    success "Node.js backend healthy: HTTP $code (127.0.0.1:$port$path)"
    return 0
  fi
  warn "Node.js process active but endpoint returned HTTP $code at $path (configure its health path if needed)"
  return 1
}
app_nodejs_set_health_path() {
  local domain="$1" root choice path tmp
  root="$(app_runtime_path nodejs "$domain")"
  read -rp "Health endpoint path (must start with /, 0 to cancel): " path
  [[ "$path" == 0 || -z "$path" ]] && return 0
  [[ "$path" == /* && "$path" != *$'\n'* && "$path" != *$'\r'* && ${#path} -le 256 ]] || { error "Invalid health path"; return 1; }
  tmp="$(mktemp "$root/.health.XXXXXXXX")" || return 1
  if jq --arg path "$path" '.health_path = $path' "$root/runtime.json" > "$tmp"; then
    chown root:root "$tmp" && chmod 0644 "$tmp" && mv -f "$tmp" "$root/runtime.json" || { rm -f "$tmp"; return 1; }
    success "Health endpoint set to $path"
  else rm -f "$tmp"; return 1; fi
}
app_nodejs_dependencies() {
  local domain="$1" root npm
  root="$(app_runtime_path nodejs "$domain")"
  [[ -f "$root/app/package.json" && -x "$root/node_bin/bin/npm" ]] || { error "Node.js package/runtime missing"; return 1; }
  jq -e . "$root/app/package.json" >/dev/null 2>&1 || { error "Invalid package.json"; return 1; }
  if [[ -f "$root/app/package-lock.json" || -f "$root/app/npm-shrinkwrap.json" ]]; then
    info "Installing Node.js dependencies from lockfile (npm ci)"
    app_nodejs_as_owner "$domain" sh -c 'cd "$1" && exec "$2" ci' sh "$root/app" "$root/node_bin/bin/npm" || return 1
  else
    info "Installing Node.js dependencies (npm install; no lockfile present)"
    app_nodejs_as_owner "$domain" sh -c 'cd "$1" && exec "$2" install' sh "$root/app" "$root/node_bin/bin/npm" || return 1
  fi
  if jq -e '.scripts.build | type == "string" and length > 0' "$root/app/package.json" >/dev/null 2>&1; then
    info "Running application build script"
    app_nodejs_as_owner "$domain" sh -c 'cd "$1" && exec "$2" run build' sh "$root/app" "$root/node_bin/bin/npm" || return 1
  fi
}
app_nodejs_redeploy() {
  local domain="$1" mode="${2:-update}" root service stage user choice git_status
  app_nodejs_context "$domain" || return 1
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  user="$(app_nodejs_owner "$domain")" || return 1
  read -rp "Update $domain, reinstall dependencies and restart? [y/N]: " choice
  [[ "$choice" =~ ^([yY]|[yY][eE][sS])$ ]] || { info "Cancelled"; return 0; }
  # Admin-only rollback snapshot; no global cleanup and no other site's resources.
  stage="$(mktemp -d "$root/.node-redeploy.XXXXXXXX")" || return 1
  chmod 0700 "$stage" || { rm -rf "$stage"; return 1; }
  if ! cp -a "$root/app" "$stage/app"; then rm -rf "$stage"; error "Unable to create deployment rollback snapshot"; return 1; fi
  if [[ "$mode" == update ]] && app_nodejs_as_owner "$domain" git -C "$root/app" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_status="$(app_nodejs_as_owner "$domain" git -C "$root/app" status --porcelain 2>/dev/null)" || {
      rm -rf "$stage"; error "Unable to inspect Git working tree"; return 1;
    }
    if [[ -n "$git_status" ]]; then
      warn "Working tree contains local modifications; refusing to discard them."
      rm -rf "$stage"; return 0
    fi
    if ! app_nodejs_as_owner "$domain" git -C "$root/app" pull --ff-only; then
      error "Git pull failed; reverting application files"
      rm -rf "$root/app"; mv "$stage/app" "$root/app"; rm -rf "$stage"; return 1
    fi
  elif [[ "$mode" == update ]]; then
    info "No Git working tree; reinstalling dependencies without replacing the default HTML application."
  fi
  if ! app_nodejs_dependencies "$domain" || ! systemctl restart "$service" || ! systemctl is-active --quiet "$service"; then
    warn "Deployment failed; restoring previous application files"
    rm -rf -- "$root/app"
    if ! mv "$stage/app" "$root/app"; then error "CRITICAL: rollback snapshot retained in $stage/app"; return 1; fi
    systemctl restart "$service" >/dev/null 2>&1 || warn "Old app restored on disk but restart failed; inspect logs"
    rm -rf "$stage"
    return 1
  fi
  rm -rf "$stage"
  success "Node.js application redeployed: $domain"
  app_nodejs_health "$domain" || warn "App started, but HTTP health check needs investigation"
}
app_nodejs_runtime_upgrade() {
  local domain="$1" root current target arch index tarball url stage olddir service checksum choice tmp
  app_nodejs_context "$domain" || return 1
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  [[ -x "$root/node_bin/bin/node" ]] || { error "Node.js runtime not installed"; return 1; }
  current="$("$root/node_bin/bin/node" --version)"
  info "Current Node.js: $current"
  index="$(curl -fsSL --max-time 30 https://nodejs.org/dist/index.json)" || { error "Could not retrieve Node.js release list"; return 1; }
  local latest
  latest="$(jq -r '[.[] | select(.lts != false)][0].version // empty' <<< "$index")"
  info "Latest upstream LTS: $latest"
  read -rp "Enter LTS version (e.g. $latest), ENTER for latest, 0 to cancel: " target
  [[ "$target" == 0 ]] && return 0
  target="${target:-$latest}"
  [[ "$target" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { error "Invalid Node.js version"; return 1; }
  jq -e --arg v "$target" '.[] | select(.version == $v and .lts != false)' <<< "$index" >/dev/null || {
    error "Requested version is not listed as a Node.js LTS release"; return 1;
  }
  [[ "$target" != "$current" ]] || { info "Already running $target"; return 0; }
  read -rp "Change the isolated runtime from $current to $target and restart? [y/N]: " choice
  [[ "$choice" =~ ^([yY]|[yY][eE][sS])$ ]] || return 0
  case "$(uname -m)" in x86_64) arch=x64;; aarch64) arch=arm64;; *) error "Unsupported architecture"; return 1;; esac
  tarball="node-${target}-linux-${arch}.tar.xz"
  url="https://nodejs.org/dist/$target"
  stage="$(mktemp -d "$root/.node-upgrade.XXXXXXXX")" || return 1
  mkdir -p "$stage/new" || { rm -rf "$stage"; return 1; }
  if ! curl -fL --retry 2 "$url/$tarball" -o "$stage/$tarball" || ! curl -fL --retry 2 "$url/SHASUMS256.txt" -o "$stage/SHASUMS256.txt"; then
    rm -rf "$stage"; error "Node.js download failed"; return 1
  fi
  checksum="$(awk -v f="$tarball" '$2==f {print $1; exit}' "$stage/SHASUMS256.txt")"
  [[ "$checksum" =~ ^[0-9a-fA-F]{64}$ ]] && printf '%s  %s\n' "$checksum" "$stage/$tarball" | sha256sum -c - >/dev/null 2>&1 || {
    rm -rf "$stage"; error "Node.js SHA256 verification failed"; return 1;
  }
  if ! tar -xJf "$stage/$tarball" -C "$stage/new" --strip-components=1 || [[ ! -x "$stage/new/bin/node" || ! -x "$stage/new/bin/npm" ]]; then
    rm -rf "$stage"; error "Downloaded Node.js runtime is incomplete"; return 1
  fi
  # Keep previous engine until new engine is confirmed working.
  if ! mv "$root/node_bin" "$stage/previous"; then rm -rf "$stage"; return 1; fi
  if ! mv "$stage/new" "$root/node_bin" || ! systemctl restart "$service" || ! systemctl is-active --quiet "$service"; then
    rm -rf "$root/node_bin"
    if ! mv "$stage/previous" "$root/node_bin"; then error "CRITICAL: previous runtime retained at $stage/previous"; return 1; fi
    systemctl restart "$service" >/dev/null 2>&1 || warn "Previous runtime restored but app restart failed"
    rm -rf "$stage"
    error "Node.js runtime upgrade rolled back"
    return 1
  fi
  if grep -q '^NODE_VERSION=' "$root/meta.conf"; then
    sed -i "s|^NODE_VERSION=.*|NODE_VERSION=$target|" "$root/meta.conf"
  else printf 'NODE_VERSION=%s\n' "$target" >> "$root/meta.conf"; fi
  rm -rf "$stage"
  success "Node.js runtime upgraded to $target"
  app_nodejs_health "$domain" || warn "Check the application health endpoint after upgrading"
}
app_nodejs_set_start_command() {
  local domain="$1" root command_line tmp backup service choice
  app_nodejs_context "$domain" || return 1
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  info "Current command: $(jq -r '.start // "npm start"' "$root/runtime.json")"
  read -rp "Enter command for app user (0 to cancel): " command_line
  [[ "$command_line" == 0 || -z "$command_line" ]] && return 0
  [[ ${#command_line} -le 512 && "$command_line" != *$'\n'* && "$command_line" != *$'\r'* ]] || { error "Invalid startup command"; return 1; }
  read -rp "Change command and restart app? [y/N]: " choice
  [[ "$choice" =~ ^([yY]|[yY][eE][sS])$ ]] || return 0
  local dropin="/etc/systemd/system/${service}.d/one-click-start.conf" new_dropin=0
  [[ -f "$dropin" ]] || new_dropin=1
  app_nodejs_ensure_service_launcher "$domain" || return 1
  backup="$(mktemp "$root/.runtime-old.XXXXXXXX")" || return 1
  tmp="$(mktemp "$root/.runtime-new.XXXXXXXX")" || { rm -f "$backup"; return 1; }
  cp -p "$root/runtime.json" "$backup" || { rm -f "$tmp" "$backup"; return 1; }
  if ! jq --arg cmd "$command_line" '.start=$cmd' "$backup" > "$tmp" || ! chown root:root "$tmp" || ! chmod 0644 "$tmp" || ! mv "$tmp" "$root/runtime.json"; then
    rm -f "$tmp" "$backup"; return 1
  fi
  if ! systemctl restart "$service" || ! systemctl is-active --quiet "$service"; then
    mv "$backup" "$root/runtime.json" || error "Failed to restore startup command metadata"
    if [[ "$new_dropin" == 1 && -f "$dropin" ]]; then
      rm -f "$dropin"
      rmdir -- "$(dirname "$dropin")" 2>/dev/null || true
      systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    systemctl restart "$service" >/dev/null 2>&1 || true
    error "New start command failed; previous command restored"
    return 1
  fi
  rm -f "$backup"
  success "Startup command changed for $domain"
}
app_nodejs_environment() {
  local domain="$1" root file owner choice backup="" editor="${EDITOR:-nano}" service
  app_nodejs_context "$domain" || return 1
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  owner="$(app_nodejs_owner "$domain")" || return 1
  file="$root/env/.env"
  mkdir -p "$root/env" || return 1
  if [[ -f "$file" ]]; then
    backup="$(mktemp "$root/.env-previous.XXXXXXXX")" || return 1
    cp -p "$file" "$backup" || { rm -f "$backup"; return 1; }
  fi
  ( umask 077; "$editor" "$file" ) || { warn "Editor exited with an error"; [[ -z "$backup" ]] || rm -f "$backup"; return 1; }
  [[ -f "$file" && ! -L "$file" ]] || { error "Environment file is missing or unsafe"; return 1; }
  chown "$owner" "$file" && chmod 0600 "$file" || return 1
  read -rp "Restart app to apply new environment? [y/N]: " choice
  if [[ "$choice" =~ ^([yY]|[yY][eE][sS])$ ]]; then
    if ! systemctl restart "$service" || ! systemctl is-active --quiet "$service"; then
      if [[ -n "$backup" ]]; then cp -p "$backup" "$file"; else rm -f -- "$file"; fi
      systemctl restart "$service" >/dev/null 2>&1 || true
      error "Restart failed; previous environment restored"
      [[ -z "$backup" ]] || rm -f "$backup"
      return 1
    fi
  else info "Environment saved; changes take effect on the next restart"; fi
  [[ -z "$backup" ]] || rm -f "$backup"
  success "Environment configuration saved"
}
app_nodejs_ssl_menu() {
  local domain="$1" choice cert hsts
  while true; do
    printf '\nNode.js HTTPS - %s\n' "$domain"
    printf '%s\n' '0) Back' '1) Certificate status' '2) Install / retry Let’s Encrypt' '3) Check HTTPS and HSTS response'
    read -rp 'Select [0-3]: ' choice
    case "$choice" in
      0) return 0 ;;
      1)
        cert="/etc/letsencrypt/live/$domain/cert.pem"
        if [[ -f "$cert" ]]; then
          openssl x509 -in "$cert" -noout -dates -subject -issuer || warn "Unable to read certificate"
        else
          warn "No standard Certbot certificate found at $cert; checking Certbot records"
          command -v certbot >/dev/null 2>&1 && certbot certificates --cert-name "$domain" || true
        fi
        ;;
      2)
        # Reuse the global installer and its retry/skip behavior. Dynamic scoping
        # keeps the selected domain local to this wrapper.
        ( install_letsencrypt nodejs )
        ;;
      3)
        if command -v curl >/dev/null 2>&1; then
          info "Local HTTPS response (certificate is verified against the selected domain):"
          curl --silent --show-error --max-time 12 --resolve "$domain:443:127.0.0.1" -I "https://$domain/" || warn "HTTPS did not verify on the local server"
          info "Look for Strict-Transport-Security in the response headers when HSTS is enabled."
        fi
        ;;
      *) warn "Invalid selection" ;;
    esac
  done
}
app_nodejs_log_menu() {
  local domain="$1" root service choice owner group logdir conf
  root="$(app_runtime_path nodejs "$domain")"
  service="$(app_service_name nodejs "$domain")"
  logdir="/var/log/one-click/$domain/apps/nodejs"
  owner="$(app_nodejs_owner "$domain")" || return 1
  group="$(sed -n 's/^SITE_GROUP=//p' "$root/meta.conf" | head -n1)"
  [[ "$group" =~ ^[a-zA-Z0-9_-]+$ ]] && getent group "$group" >/dev/null 2>&1 || group="$owner"
  while true; do
    printf '\nNode.js logs - %s\n' "$domain"
    printf '%s\n' '0) Back' '1) Recent errors' '2) Recent systemd events' '3) Configure daily log rotation' '4) Rotate logs now'
    read -rp 'Select [0-4]: ' choice
    case "$choice" in
      0) return 0 ;;
      1) tail -n 100 "$logdir/error.log" 2>/dev/null || warn "No application error log yet" ;;
      2) journalctl -u "$service" -n 100 --no-pager || true ;;
      3)
        mkdir -p "$logdir" || return 1
        conf="/etc/logrotate.d/one-click-nodejs-${domain}"
        cat > "$conf" <<EOF
${logdir}/*.log {
    su ${owner} ${group}
    daily
    rotate 7
    missingok
    notifempty
    compress
    copytruncate
}
EOF
        chown root:root "$conf" && chmod 0644 "$conf" || return 1
        success "Installed Node.js daily log rotation for $domain"
        ;;
      4)
        conf="/etc/logrotate.d/one-click-nodejs-${domain}"
        [[ -f "$conf" ]] || { warn "Configure rotation first"; continue; }
        if command -v logrotate >/dev/null 2>&1; then logrotate -f "$conf" || error "Log rotation failed"; else warn "logrotate is not installed"; fi
        ;;
      *) warn "Invalid selection" ;;
    esac
  done
}
app_nodejs_backup_menu() {
  local domain="$1" choice
  while true; do
    printf '\nNode.js Backup / Restore - %s\n' "$domain"
    printf '%s\n' '0) Back' '1) Back up application' '2) Restore application backup'
    read -rp 'Select [0-2]: ' choice
    case "$choice" in
      0) return 0 ;;
      1) app_backup "$domain" || error "Backup failed" ;;
      2) app_restore "$domain" || error "Restore failed" ;;
      *) warn "Invalid selection" ;;
    esac
  done
}
app_nodejs_health_menu() {
  local domain="$1" choice
  while true; do
    printf '\nNode.js Health - %s\n' "$domain"
    printf '%s\n' '0) Back' '1) Check backend HTTP and service' '2) Change health check endpoint'
    read -rp 'Select [0-2]: ' choice
    case "$choice" in
      0) return 0 ;;
      1) app_nodejs_health "$domain" || true ;;
      2) app_nodejs_set_health_path "$domain" || error "Failed to save health path" ;;
      *) warn "Invalid selection" ;;
    esac
  done
}
nodejs_board() {
  local runtime=nodejs root service choice status app_domain
  if [[ -z "${domain:-}" ]]; then select_domain || return 0; fi
  app_domain="$domain"
  if ! app_nodejs_context "$app_domain"; then return 0; fi
  root="$(app_runtime_path nodejs "$app_domain")"
  service="$(app_service_name nodejs "$app_domain")"
  while true; do
    status=STOPPED
    systemctl is-active --quiet "$service" && status=RUNNING
    clear
    printf '%s\n' \
      "${cyan}=====================================================${reset}" \
      "${magenta}           ONE-CLICK Node.js MANAGEMENT${reset}" \
      "${cyan}=====================================================${reset}" \
      "${yellow}Domain:${reset} $app_domain   ${yellow}Status:${reset} $status" \
      "${yellow}Port:${reset}   $(jq -r '.port // "unknown"' "$root/runtime.json")"
    printf '%s\n' \
      ' 0) Back to Applications' \
      ' 1) Start Application' \
      ' 2) Stop Application' \
      ' 3) Restart Application' \
      ' 4) View Status' \
      ' 5) Follow Application Logs (Ctrl+C to return)' \
      ' 6) Toggle Service at Boot' \
      ' 7) Check / Fix Permissions' \
      ' 8) View Service File' \
      ' 9) Edit Environment and Optionally Restart' \
      '10) Open Application Directory' \
      '11) Delete Application' \
      '12) Backup / Restore' \
      '13) Update / Redeploy Application' \
      '14) Change Isolated Node.js Version' \
      '15) Application Health Checks' \
      '16) Configure Startup Command' \
      '17) SSL / HTTPS Management' \
      '18) Reinstall Dependencies / Rebuild' \
      '19) Logs, Rotation and Restart History'
    read -rp "${cyan}[USER]${blue} Select an option [0-19]: ${reset}" choice
    case "$choice" in
      0) info 'Returning to applications menu'; return 0 ;;
      1) if app_start "$runtime" "$app_domain"; then success 'Application started'; else error 'Application failed to start'; fi ;;
      2) if app_stop "$runtime" "$app_domain"; then success 'Application stopped'; else error 'Application failed to stop'; fi ;;
      3) if app_restart "$runtime" "$app_domain"; then success 'Application restarted'; else error 'Application failed to restart'; fi ;;
      4) systemctl status "$service" --no-pager || true ;;
      5) app_logs "$runtime" "$app_domain" ;;
      6)
        if systemctl is-enabled --quiet "$service"; then
          if systemctl disable "$service"; then warn 'Service disabled at boot'; else error 'Unable to disable service'; fi
        else
          if systemctl enable "$service"; then success 'Service enabled at boot'; else error 'Unable to enable service'; fi
        fi
        ;;
      7) app_fix_permissions "$app_domain" || error 'Permission repair failed' ;;
      8) if [[ -f "/etc/systemd/system/$service" ]]; then less "/etc/systemd/system/$service"; else error 'Service file missing'; fi ;;
      9) app_nodejs_environment "$app_domain" || error 'Environment edit failed' ;;
      10) ( cd "$root" && bash ) ;;
      11)
        app_delete "$app_domain" || error 'Node.js deletion failed'
        [[ -d "$root" ]] || return 0
        ;;
      12) app_nodejs_backup_menu "$app_domain" ;;
      13) app_nodejs_redeploy "$app_domain" update || error 'Redeployment failed' ;;
      14) app_nodejs_runtime_upgrade "$app_domain" || error 'Runtime change failed' ;;
      15) app_nodejs_health_menu "$app_domain" ;;
      16) app_nodejs_set_start_command "$app_domain" || error 'Startup command change failed' ;;
      17) app_nodejs_ssl_menu "$app_domain" ;;
      18) app_nodejs_redeploy "$app_domain" deps || error 'Dependency reinstallation failed' ;;
      19) app_nodejs_log_menu "$app_domain" ;;
      *) error 'Invalid option' ;;
    esac
    [[ -d "$root" ]] || return 0
    # Back from a submenu means immediate return to this menu.
    case "$choice" in 12|15|17|19) continue ;; esac
    read -rp 'Press ENTER to return to the Node.js menu...' _
  done
}
apps_menu() {
  used_app="${1:-}"
  if [[ "${used_app:-}" == "nodejs" ]]; then
    nodejs_board "$used_app"
  else
    config_dir="$base/sites/config"
    profiles_file="$config_dir/remotes.conf"
    map_file="$config_dir/domain_map.conf"
    current_profile_file="$config_dir/current_profile"
    mkdir -p "$config_dir" && touch "$map_file" "$profiles_file"
  fi
}
############################## STATIC SITES ##############################################
create_static_site() {
  local domain site_dir webserver_choice
  start_screen static
  local provision_success=0
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  while true; do
    local br=0
    read -rp "${cyan}[USER]${reset} Enter a domain name to use for your new site site: " domain
    if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      warn "Invalid domain name"
      br=1
    fi
    if [[ -n "$domain" && "$br" -ne 1 ]]; then
      export domain
      break
    fi
    warn "Domain cannot be empty!"
  done
  info "Which webserver should host $domain?" \
    "[1] Nginx" \
    "[2] Apache"
  read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver_choice
  case "$webserver_choice" in
    1)
      webserver="nginx"
      if id nginx &> /dev/null; then
        webserver_user="nginx"
      elif id www-data &> /dev/null; then
        webserver_user="www-data"
      fi
      if (systemctl is-active apache2 || systemctl is-active httpd) &> /dev/null; then
        error "Apache is already installed"
        warn "Either continue using Apache or disable/remove it"
        return 1
      fi
      ;;
    2)
      webserver="apache"
      if command -v apt &> /dev/null; then
        webserver_user=www-data
      else
        webserver_user="apache"
      fi
      if systemctl is-active nginx 2> /dev/null; then
        error "Nginx is already installed"
        warn "Either continue using Nginx or disable/remove it"
        return 1
      fi
      ;;
    *) error "Invalid selection"; return 1 ;;
  esac
  web_user="ocb_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  warn "Creating web owner $web_user"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
  site_dir="/etc/one-click/sites/$domain/www"
  trap "cleanup_failed_provision  $provision_success sites" EXIT INT TERM ERR
  mkdir -p "$site_dir"
  touch /etc/one-click/sites/$domain/meta.conf
  echo "SITE_USER=$web_user" >> /etc/one-click/sites/$domain/meta.conf
  echo "SITE_DIR=$site_dir" >> /etc/one-click/sites/$domain/meta.conf
  echo "SITE_GROUP=$webserver_user" >> /etc/one-click/sites/$domain/meta.conf
  echo "WEBSERVER=$webserver" >> /etc/one-click/sites/$domain/meta.conf
  echo "TYPE=static" >> /etc/one-click/sites/$domain/meta.conf
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Would you like to automate sitemap and robots generation? (y|n): " robots
    [[ -n "$robots" ]] && break
  done
  robots="${robots,,}"
  if [[ "$robots" == "y" || "$robots" == "yes" ]]; then
    sitemap_robots $domain $site_dir
    cat <<EOF >/etc/cron.d/one-click-sitemap_robots
# ==== Crawl site at 2am every week for changes to be submitted ====
0 2 * * 0 root bash /var/cache/one-click/wordpress.sh --crawler $domain $site_dir       # One-Click $domain Crawler
EOF
  else
    info "Automated crawler can be set up from web-admin at a later time if preferred"
    sleep 1
  fi
  read -rp "${cyan}[USER]${blue} Enable HSTS: ${reset}" enable_hsts
  if [[ "${enable_hsts,,}" =~ ^(y|yes)$ ]]; then
    enable_hsts="yes"
  fi
  info "Generating default page"
  cat <<'EOF' > "$site_dir/index.html"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>SiteHUB Default WebPage</title><link rel="icon" type="image/png" href="https://sitehub.agency/wp-content/uploads/2025/06/cropped-Untitled-design-9-e1750161170804.png"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet"><style>*{margin:0;padding:0;box-sizing:border-box}body,html{height:100%;font-family:'Roboto',sans-serif}body{background:linear-gradient(135deg,#28a745,#003366);display:flex;flex-direction:column;justify-content:space-between;color:#fff}header{text-align:center;padding:50px 20px}header img.logo{height:80px;margin-bottom:20px}header h1{font-size:2.5em;margin-bottom:10px}header p{font-size:1.2em}.visuals{position:absolute;top:0;left:0;width:100%;height:100%;overflow:hidden;z-index:0}.visuals span{position:absolute;display:block;border-radius:50%;background:rgba(255,255,255,.05);animation:float 25s linear infinite}@keyframes float{0%{transform:translateY(0) rotate(0deg)}100%{transform:translateY(-1000px) rotate(720deg)}}main{position:relative;z-index:1;max-width:900px;margin:0 auto;padding:20px;text-align:center}section{margin:50px 0}.main-hero h2{font-size:2em;margin-bottom:15px}.main-hero p{font-size:1.1em;line-height:1.6;margin-bottom:25px}.cta-btn{display:inline-block;background:#fff;color:#003366;font-weight:700;text-decoration:none;padding:12px 25px;border-radius:50px;margin:10px;transition:all .3s ease}.cta-btn:hover{background:#e0e0e0}footer{text-align:center;padding:20px;font-size:.9em;color:rgba(255,255,255,.7)}@media(max-width:768px){header h1{font-size:2em}.main-hero h2{font-size:1.6em}}</style></head><body><div class="visuals" id="visuals"></div><header><img class="logo" src="https://us1.plesk.sitehub.agency/images/logos/6EwrLBBn5Xg.png" alt="SiteHUB"><h1>Default Web Page for <span id="domain-name">dynamic-domain.ng</span></h1><p>This page is generated by <a href="https://sitehub.agency" style="color:darkgreen;text-decoration:none;">Site <span style="color:blue;text-decoration:none;">HUB</span></a>, the leading hosting provider in Nigeria.<br>You see this page because there is no website at this address.</p></header><main id="placeholder-content"></main><footer>Copyright &copy; SiteHUB Agency <span id="year"></span>. All rights reserved - RC6935293</footer><script>document.getElementById("year").textContent=new Date().getFullYear();document.addEventListener("DOMContentLoaded",()=>{const e=location.hostname,t=location.protocol+"//"+e+":8443",n="support@sitehub.agency";document.getElementById("domain-name").textContent=e;const o=document.getElementById("placeholder-content");let a="";a+=`<section class="main-hero"><h2>Your domain <strong>${e}</strong> is now live!</h2><p><strong>${e}</strong> default page has been generated by the One-Click Toolbox Automation tool . No website content has been uploaded yet.<br>For more information about One-Click Toolbox:</p><a class="cta-btn" href="https://github.com/SiteHUB-NG/One-Click/" target="_blank">View On GitHub</a><br><br><br><hr><br><h2>Need Hosting?</h2><p>Start your own website in minutes with our web hosting & VPS plans!</p><a class="cta-btn" href="https://sitehub.agency/shared/" target="_blank">View Web Hosting Plans</a><a class="cta-btn" href="https://features.sitehub.agency/vps/" target="_blank">View VPS Plans</a></section>`,a+=`<section class="main-hero"><h2>Need Help?</h2><p>Contact our support team: <a style="color:#fff;text-decoration:underline;" href="mailto:${n}">${n}</a></p></section>`,o.innerHTML=a;const r=document.getElementById("visuals");for(let t=0;t<30;t++){let n=document.createElement("span"),o=60*Math.random()+20;n.style.width=o+"px",n.style.height=o+"px",n.style.left=100*Math.random()+"%",n.style.top=100*Math.random()+"%",n.style.animationDuration=20+20*Math.random()+"s",r.appendChild(n)}});</script></body></html>
EOF
  success "New site prepared at $site_dir"
  install_webserver static "$domain" "$site_dir"
  create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "sites"
  chown "$web_user":"$webserver_user" "$site_dir"
  dns_check
  one-click engine "allow $webserver" -y
  install_letsencrypt static
  wp_backup_scheduler
  check_permissions "$domain" "sites"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_static-web-monitor_$domain
  provision_success=1
  trap - EXIT INT TERM ERR
  success "One-Click static site has now been installed for $domain"
  info "Access the site from ${magenta}https://${domain}${reset}"
}
clone_static_site() {
  old_domain="$1"
  read -rp "${cyan}[USER]${reset} New cloned domain name: " new_domain
  echo
  source /etc/one-click/sites/$old_domain/meta.conf
  old_site_dir="/etc/one-click/sites/${old_domain}/www"
  new_site_dir="/etc/one-click/sites/${new_domain}/www"
  [[ ! -d "$old_site_dir" ]] && {
    error "Source website does not exist:"
    error "$old_site_dir"
    return 1
  }
  if [[ -d "$new_site_dir" ]]; then
    error "Destination already exists:"
    error "$new_site_dir"
    return 1
  fi
  # ==== Begin cloning ====
  info "Creating cloned website directory."
  mkdir -p "$new_site_dir"
  info "Copying website files."
  rsync -aHAX --info=progress2 \
    "$old_site_dir/" \
    "$new_site_dir/"
  success "Website files copied successfully."
  info "Replacing domain references."
  find "$new_site_dir" \
    -type f \
    \( \
      -name "*.html" \
      -o -name "*.htm" \
      -o -name "*.php" \
      -o -name "*.js" \
      -o -name "*.css" \
      -o -name "*.json" \
      -o -name "*.xml" \
      -o -name "*.txt" \
    \) \
    -exec sed -i \
      "s/${old_domain//\//\\/}/${new_domain//\//\\/}/g" {} \;
  success "Domain references updated."
  info "Creating vhost."

  web_user="ocb_$(echo -n "$new_domain" | sha1sum | cut -c1-8)"
  warn "Creating web owner $web_user"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
  touch "/etc/one-click/sites/$new_domain/meta.conf"
  echo "SITE_USER=$web_user" >> /etc/one-click/sites/$new_domain/meta.conf
  echo "SITE_DIR=$new_site_dir" >> /etc/one-click/sites/$new_domain/meta.conf
  echo "SITE_GROUP=$SITE_GROUP" >> /etc/one-click/sites/$new_domain/meta.conf
  echo "WEBSERVER=$WEBSERVER" >> /etc/one-click/sites/$new_domain/meta.conf
  install_webserver static "$new_domain" "$new_site_dir"
  create_isolated_php_runtime "$new_domain" "$php_ver" "$web_user" "$WEBSERVER" "sites"
  chown "$web_user":"$SITE_GROUP" "$new_site_dir"
  dns_check
  one-click engine "allow $WEBSERVER" -y
  domain="$new_domain"
  install_letsencrypt static
  wp_backup_scheduler
  check_permissions "$new_domain" "sites"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_static-web-monitor_$domain
  success "One-Click static site has now been installed for $domain"
  info "Access the site from ${magenta}https://${domain}${reset}"
  success "Clone completed successfully."
  info \
    "Source      : $old_domain" \
    "Cloned Site : $new_domain" \
    "Location    : $new_site_dir" \
    "Conf File   : /etc/one-click/sites/$new_domain/meta.conf"
}
nginx_static_conf() {
  local domain="$1"
  local site_dir="$2"
  local enable_hsts="${3:-}"
  mkdir -p /var/log/one-click/${domain}/nginx
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/one-click/${domain}/nginx"
  fi
  echo "VHOST=$nginx_conf_file" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root $site_dir;
    index index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/one-click/${domain}/php.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires max;
        log_not_found off;
    }
}
EOF
  if [[ "$pkg_mgr" == "apt" && -d /etc/nginx/sites-available ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  for i in /etc/nginx/sites-enabled/ /etc/nginx/sites-available /etc/nginx/con.d/ ; do
    if [[ ! -d "$i" ]]; then
      continue
    fi
    find "$i" -type l -name '*default*' '!' -name 00-default.conf -delete
  done
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -Ei '
     N;/add_header.*\n$/ {
    p;s/add_header.*\n/add_header Strict-Transport-Security "max-age=15552000; includeSubDomains; preload" always;/;
    }' "$nginx_conf_file"
  fi
  nginx -t && systemctl enable --now nginx
}
apache_static_conf() {
  local domain="$1"
  local site_dir="$2"
  local enable_hsts="${3:-}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_conf_file="/etc/apache2/sites-available/$domain.conf"
    apache_log_dir="/var/log/one-click/${domain}/apache2"
    mkdir -p /var/log/one-click/${domain}/apache2
  else
    apache_conf_file="/etc/httpd/conf.d/$domain.conf"
    apache_log_dir="/var/log/one-click/${domain}/httpd"
    mkdir -p /var/log/one-click/${domain}/httpd
  fi
  echo "VHOST=$apache_conf_file" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  cat <<EOF >"$apache_conf_file"
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain

    DocumentRoot $site_dir

    <Directory $site_dir>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/error.log
    CustomLog ${apache_log_dir}/access.log combined
</VirtualHost>
EOF
  install_php_mods
  if [[ "$pkg_mgr" == "apt" ]]; then
    a2ensite "$domain"
    if systemctl is-active apache2 &> /dev/null; then
      systemctl reload apache2
    else
      systemctl enable apache2 --now
    fi
  else
    if ! systemctl is-active httpd &> /dev/null; then
      systemctl enable httpd --now
    else
      systemctl reload httpd
    fi
  fi
  if [[ "$enable_hsts" == "yes" ]]; then
    sed -i '/Header always set X-Download-Options/a \    Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"' "$apache_confi"
  fi
}
static_backup() {
  local domain base site backup timestamp webserver
  domain="${1:-}"
  snap="${2:-}"
  resolve_type "$domain"
  . /etc/one-click/${type}/${domain}/meta.conf
  base="/etc/one-click/${type}"
  if [[ -d "$base/$domain/www" ]]; then
    site="$base/$domain/www"
  elif [[ -d "$base/$domain/app" ]]; then
    site="$base/$domain/app"
  else
    error "No valid site directory found"
    return 1
  fi
  timestamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  [[ ! -f "$site/index.html" && ! -f "$site/index.php" && ! -f "$site/index.js" ]] && {
    error "No index file found (not a valid site: $domain)"
    return 1
  }
  if [[ -n "$snap" ]]; then
    backup="$base/rollback/$domain"
    info "Creating rollback snapshot"
    mkdir -p "$backup/$timestamp"
    backup_role=Rollback
  else
    backup="$base/backups/$domain"
    info "Creating site backup for $domain"
    mkdir -p "$backup/$timestamp"
    backup_role=Backup
  fi
  webserver="$WEBSERVER"
  info "Archiving files."
  tar -czf "$backup/$timestamp/files.tar.gz" -C "$site" .
  # ==== Save vhost config ====
  info "Saving webserver configuration."
  case "$webserver" in
    nginx)
      cp /etc/nginx/sites-available/$domain.conf "$backup/$timestamp/nginx.conf" 2>/dev/null || \
      cp /etc/nginx/conf.d/$domain.conf "$backup/$timestamp/nginx.conf"
      ;;
    apache)
      cp /etc/apache2/sites-available/$domain.conf "$backup/$timestamp/apache.conf" 2>/dev/null || \
      cp /etc/httpd/conf.d/$domain.conf "$backup/$timestamp/apache.conf"
      ;;
  esac
  # ==== Database Backup ===
  if resolve_site_database "$domain"; then
    info "Backing up database $db_name"
    db_pass=$(<"${db_password_file:-${db_pass}}")
    mysqldump \
      -h "$db_host" \
      -P "$db_port" \
      -u "$db_user" \
      -p"$db_pass" \
      "$db_name" \
      | gzip > "$backup/$timestamp/db.sql.gz"
    db_included=true
  else
    db_included=false
  fi
  # ==== Metadata ====
  cat > "$backup/$timestamp/meta.conf" <<EOF
DOMAIN=$domain
WEBSERVER=$webserver
SITE_DIR=$site
PHP_ENABLED=$(grep -q '\.php' <<< "$(ls $site 2>/dev/null)" && echo yes || echo no)
TIMESTAMP=$timestamp
POOL=enabled
SLICE=enabled
EOF
  # ==== Manifest ====
  cat > "$backup/$timestamp/manifest.txt" <<EOF
TYPE="$type"
DOMAIN=$domain
TIMESTAMP=$timestamp
HOSTNAME=$(hostname)
BACKUP_VERSION=1.0
DB_INCLUDED=$db_included
DB_ENGINE=${db_engine:-}
DB_HOST=${db_host:-}
DB_PORT=${db_port:-}
DB_NAME=${db_name:-}
DB_USER=${db_user:-}
EOF
  success "$backup_role stored at $backup/$timestamp"
  sleep 2
}
static_restore() {
  local domain base site_dir backup_dir webserver
  domain="${domain:-${1}}"
  resolve_type "$domain"
  read -rp "${yellow}[USER]${yellow} This will overwrite $domain. Continue? (y|n): " confirm
  [[ "$confirm" != "y" && "$confirm" != "yes" ]] && return 1
  create_rollback_snapshot "$domain" "static"
  backup_dir="$2"
  base="/etc/one-click/${type}"
  if [[ -d "$base/$domain/www" ]]; then
    site_dir="$base/$domain/www"
  elif [[ -d "$base/$domain/app" ]]; then
    site_dir="$base/$domain/app"
  else
    error "No valid site directory found"
    return 1
  fi
  [[ ! -d "$backup_dir" ]] && {
    die "Backup directory not found"
  }
  [[ -d "$site_dir" ]] || {
    die "Invalid site directory: $site_dir"
  }
  info "Loading metadata."
  . "$base/$domain/meta.conf"
  . "$backup_dir/meta.conf"
  . "$backup_dir/manifest.txt"
  # ==== Restore files ====
  info "Restoring files."
  find "$site_dir" -mindepth 1 -delete
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  # ==== Restore webserver ====
  info "Restoring webserver configuration."
  case "$WEBSERVER" in
    nginx)
      webserver_user="$SITE_GROUP"
      if [[ -f "$backup_dir/nginx.conf" ]]; then
        if systemctl is-active nginx.service &> /dev/null; then
          cp "$backup_dir/nginx.conf" /etc/nginx/sites-available/$domain.conf 2>/dev/null || \
          cp "$backup_dir/nginx.conf" /etc/nginx/conf.d/$domain.conf
          [[ -d /etc/nginx/sites-enabled ]] && \
          ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/
          systemctl reload nginx
        else
          error "$WEBSERVER is inactive"
          warn "Please check status and errors then try again"
          return
        fi
      fi
      ;;
    apache)
      if [[ -f "$backup_dir/apache.conf" ]]; then
        if [[ -d /etc/apache2 ]]; then
          webserver_user="$SITE_GROUP"
          if systemctl is-active apache2.service &> /dev/null; then
            cp "$backup_dir/apache.conf" /etc/apache2/sites-available/$domain.conf
            a2ensite "$domain"
            systemctl reload apache2
          else
            error "$WEBSERVER is inactive"
            warn "Please check status and errors then try again"
            return
          fi
        else
          webserver_user="$SITE_GROUP"
          if systemctl is-active httpd.service &> /dev/null; then
            cp "$backup_dir/apache.conf" /etc/httpd/conf.d/$domain.conf
            systemctl reload httpd
          else
            error "$WEBSERVER is inactive"
            warn "Please check status and errors then try again"
            return
          fi
        fi
      fi
      ;;
  esac
  # ==== Restore Database ====
  if [[ "$DB_INCLUDED" == "true" ]]; then
    if [[ -f "$backup_dir/db.sql.gz" ]]; then
      db_password_file=$(cat /etc/one-click/db-manager/secrets/db/${domain}.pass)
      DB_PASS=$(<"${db_password_file:-${DB_PASS}}")
      pv "$backup_dir/db.sql.gz" | gunzip | mysql \
        -u "$DB_USER" \
        -p"$DB_PASS" \
        "$DB_NAME"
    fi
  fi
  chown -R "$SITE_USER":"$SITE_GROUP" "$site_dir"
  success "Restore complete for $domain"
}
select_static_domain() {
  mode="${1}"
  if [[ "${2:-}" == "profile" ]]; then
    type=profile
  elif [[ "${2:-}" == "rollback" ]]; then
    type=restore
  else
    type=site
  fi
  local base="/etc/one-click/sites"
  local sites i choice
  mapfile -t sites < <(sed -n '/\./p' <(find "$base" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
  if [[ ${#sites[@]} -eq 0 ]]; then
    error "No static sites found in $base"
    return
  fi
  printf '%s\n' "${blue}Available Static sites:${reset}" " "
  printf "${magenta}%-3s${blue} | ${yellow}%s${reset}\n" "No" "Domain"
  echo "${blue}------------------------${reset}"
  for i in "${!sites[@]}"; do
    printf "${magenta}%-3s ${blue}| ${yellow}%s${reset}\n" "$((i+1))" "$(basename "${sites[$i]}")"
  done
  printf "${magenta}%-3s ${blue}| ${yellow}%s${reset}\n" "0" "${red}"
  read -rp "${cyan}[USER] ${blue}Select a $type to $mode by number: ${reset}" choice
  if [[ "$choice" -eq 0 ]]; then
    central_menu
  fi
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#sites[@]})); then
    error "Invalid selection"
    return 1
  fi
  domain=$(basename "${sites[$((choice-1))]}")
  export domain
}
static_backup_scheduler() {
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "[ERROR] No domain specified"; return 1; }
  cat <<EOF >/etc/cron.d/one-click-static-backups
0 3 * * * root bash /var/cache/one-click/sites.sh -staticback $domain       # One-Click Static Backup
30 3 * * * root bash /var/cache/one-click/sites.sh -staticrotate $domain    # One-Click Static Rotate
EOF
    success "Cron jobs created for static site $domain"
}
static_backup_interactive() {
  central_menu static
}
static_backup_int() {
  select_static_domain "backup" || return 1
  static_backup "$domain"
}
static_restore_int() {
  if [[ -z "${1}" ]]; then
    select_static_domain "restore" || return 1
  else
    domain="$1"
  fi
  resolve_type "$domain"
  resolve_profile "$domain"
  local backup_base="/etc/one-click/${type}/backups/$domain"
  local backups i choice
  mapfile -t backups < <(find "$backup_base" -mindepth 1 -maxdepth 1 -type d | sort)
  if [[ ${#backups[@]} -eq 0 ]]; then
    error "No backups found for $domain"
    return 1
  fi
  printf '%s\n' " " " " "${blue}Available backups for $domain:${reset}" " "
  printf "${magenta}%-3s ${blue}|${yellow} %s${reset}\n" "No" "Timestamp"
  echo "${blue}------------------------${reset}"
  for i in "${!backups[@]}"; do
    printf "${magenta}%-3s${blue} | ${yellow}%s${reset}\n" "$((i+1))" "$(basename "${backups[$i]}")"
  done
  read -rp "${cyan}[USER]${blue} Select a backup number to restore: ${reset}" choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#backups[@]})); then
    error "Invalid selection"
    return 1
  fi
  backup_dir="${backups[$((choice-1))]}"
  static_restore "$domain" "$backup_dir"
}
######################################## PHP MANAGER ##########################################
detect_env() {
  passed_arg="${1:-}"
  if [[ -f /etc/debian_version ]]; then
    os_family="debian"; pkg_manager="apt-get"
  elif [[ -f /etc/redhat-release ]]; then
    os_family="rhel"; pkg_manager="dnf"
    command -v dnf >/dev/null 2>&1 || pkg_manager="yum"
  else
    error "Unsupported OS."
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1
  fi
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites,apps/nodejs,nextcloud}/$domain 2> /dev/null) | head -1)
  if systemctl is-active --quiet nginx; then
    webserver="nginx"
    [[ "$os_family" == "debian" ]] && conf_path="/etc/nginx/sites-enabled" || conf_path="/etc/nginx/conf.d"
  elif systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    webserver="apache"
    if [[ "$os_family" == "debian" ]]; then
      conf_path="/etc/apache2/sites-enabled"
      webserver="apache2"
    else
      conf_path="/etc/httpd/conf.d"
      webserver="httpd"
    fi
  elif [[ "${passed_arg:-}" != "--monitor" ]]; then
    printf "$red[ERROR]:$reset  %s\n" "No supported webserver detected!"
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1
  fi
}
view_service_status() {
  systemctl status "$1" --no-pager -l || true
}
restart_service() {
  info "${yellow}Restarting $1.${reset}"
  systemctl restart "$1"
}
toggle_service() {
  local svc="$1"
  state=$(get_service_state "$svc")
  if [[ "$state" == "active" ]]; then
    info "${yellow}Stopping $svc...${reset}"
    systemctl stop "$svc"
  else
    success "Starting $svc..."
    systemctl start "$svc"
  fi
}
fmt_state() {
  case "$1" in
    active) printf "${green}%s${blue}\n" "ACTIVE"   ;;
    inactive) printf "${red}%s${blue}\n" "INACTV"   ;;
    failed) printf "${red}%s${blue}\n" "FAILED"     ;;
    *) printf "${yellow}%s${blue}\n" "$1"           ;;
  esac
}
get_service_state() {
  systemctl is-active "$1" 2>/dev/null || true
}
site_meta_file() {
  local domain="$1"
  local candidate
  for candidate in \
    "/etc/one-click/wordpress/${domain}/meta.conf" \
    "/etc/one-click/nextcloud/${domain}/meta.conf" \
    "/etc/one-click/sites/${domain}/meta.conf"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}
php_cli_version() {
  local binary="$1"
  [[ -x "$binary" ]] || return 1
  "$binary" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null
}
php_full_version() {
  local binary="$1"
  [[ -x "$binary" ]] || return 1
  "$binary" -r 'echo PHP_VERSION;' 2>/dev/null
}
php_fpm_version() {
  local binary="$1"
  [[ -x "$binary" ]] || return 1
  "$binary" -v 2>/dev/null | sed -En '1s/^PHP ([0-9]+\.[0-9]+).*/\1/p'
}
php_cli_for_fpm_binary() {
  local fpm_bin="$1"
  local expected="${2:-}"
  local detected="" ver_nodot="" base="" sibling="" candidate="" candidate_ver=""
  local -a candidates=()
  [[ -x "$fpm_bin" ]] || return 1
  detected="$(php_fpm_version "$fpm_bin" || true)"
  [[ -n "$expected" ]] || expected="$detected"
  [[ -n "$expected" ]] || return 1
  ver_nodot="${expected//./}"
  if [[ "$fpm_bin" =~ ^(/opt/remi/php[0-9]+/root)/usr/sbin/php-fpm$ ]]; then
    candidates+=("${BASH_REMATCH[1]}/usr/bin/php")
  fi
  base="$(basename "$fpm_bin")"
  sibling="$(dirname "$fpm_bin")/${base/php-fpm/php}"
  candidates+=(
    "$sibling"
    "/usr/bin/php${expected}"
    "/usr/bin/php${ver_nodot}"
    "/opt/remi/php${ver_nodot}/root/usr/bin/php"
  )
  candidate="$(command -v "php${ver_nodot}" 2>/dev/null || true)"
  [[ -n "$candidate" ]] && candidates+=("$candidate")
  candidate="$(command -v "php${expected}" 2>/dev/null || true)"
  [[ -n "$candidate" ]] && candidates+=("$candidate")
  candidate="$(command -v php 2>/dev/null || true)"
  [[ -n "$candidate" ]] && candidates+=("$candidate")
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    candidate_ver="$(php_cli_version "$candidate" || true)"
    if [[ "$candidate_ver" == "$expected" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}
site_php_fpm_bin() {
  local domain="$1"
  local meta="" saved="" unit="" exec_line="" candidate=""
  unit="/etc/systemd/system/php-fpm@${domain}.service"
  if [[ -f "$unit" ]]; then
    exec_line="$(sed -n 's/^ExecStart=//p' "$unit" | head -n1)"
  else
    exec_line="$(systemctl cat "php-fpm@${domain}.service" 2>/dev/null | sed -n 's/^ExecStart=//p' | head -n1)"
  fi
  candidate="${exec_line%% *}"
  candidate="${candidate#-}"
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  meta="$(site_meta_file "$domain" 2>/dev/null || true)"
  if [[ -n "$meta" ]]; then
    saved="$(sed -n 's/^PHP_FPM_BIN=//p' "$meta" | tail -n1)"
    if [[ -n "$saved" && -x "$saved" ]]; then
      printf '%s\n' "$saved"
      return 0
    fi
  fi
  return 1
}
site_php_cli_bin() {
  local domain="$1"
  local meta="" saved="" fpm_bin="" fpm_ver="" saved_ver="" candidate=""
  meta="$(site_meta_file "$domain" 2>/dev/null || true)"
  fpm_bin="$(site_php_fpm_bin "$domain" 2>/dev/null || true)"
  [[ -n "$fpm_bin" ]] && fpm_ver="$(php_fpm_version "$fpm_bin" || true)"
  if [[ -n "$meta" ]]; then
    saved="$(sed -n 's/^PHP_CLI_BIN=//p' "$meta" | tail -n1)"
    if [[ -n "$saved" && -x "$saved" ]]; then
      saved_ver="$(php_cli_version "$saved" || true)"
      if [[ -z "$fpm_ver" || "$saved_ver" == "$fpm_ver" ]]; then
        printf '%s\n' "$saved"
        return 0
      fi
    fi
  fi
  if [[ -n "$fpm_bin" ]]; then
    candidate="$(php_cli_for_fpm_binary "$fpm_bin" "$fpm_ver" || true)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    error "No PHP CLI matching the isolated PHP-FPM runtime for $domain could be resolved."
    return 1
  fi
  candidate="$(command -v php 2>/dev/null || true)"
  [[ -x "$candidate" ]] || return 1
  printf '%s\n' "$candidate"
}
site_php_version() {
  local domain="$1"
  local cli=""
  cli="$(site_php_cli_bin "$domain")" || return 1
  php_cli_version "$cli"
}
site_php_record_runtime() {
  local domain="$1"
  local fpm_bin="$2"
  local cli_bin="$3"
  local php_ver="$4"
  local meta="" pair="" key=""
  meta="$(site_meta_file "$domain" 2>/dev/null || true)"
  [[ -n "$meta" && -f "$meta" ]] || return 0
  for pair in \
    "PHP_VERSION=$php_ver" \
    "PHP_FPM_BIN=$fpm_bin" \
    "PHP_CLI_BIN=$cli_bin"; do
    key="${pair%%=*}"
    if grep -q "^${key}=" "$meta"; then
      sed -i "s|^${key}=.*|${pair}|" "$meta"
    else
      printf '%s\n' "$pair" >> "$meta"
    fi
  done
}
site_php_prepare_runtime() {
  local php_ver="$1"
  local mode="${2:-auto}"
  local system_cli="" system_fpm="" system_ver="" system_fpm_ver="" ver_nodot="" major_ver=""
  SITE_PHP_FPM_BIN=""
  SITE_PHP_CLI_BIN=""
  SITE_PHP_VERSION=""
  [[ "$php_ver" =~ ^[0-9]+\.[0-9]+$ ]] || {
    error "Invalid PHP version '$php_ver'."
    return 1
  }
  ver_nodot="${php_ver//./}"
  system_cli="$(command -v php 2>/dev/null || true)"
  system_fpm="$(command -v php-fpm 2>/dev/null || true)"
  [[ -n "$system_cli" ]] && system_ver="$(php_cli_version "$system_cli" || true)"
  [[ -n "$system_fpm" ]] && system_fpm_ver="$(php_fpm_version "$system_fpm" || true)"
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    if ! apt-cache show "php${php_ver}-fpm" >/dev/null 2>&1; then
      setup_repos || return 1
    fi
    "$pkg_mgr" install -y \
      "php${php_ver}-fpm" "php${php_ver}-cli" "php${php_ver}-xml" \
      "php${php_ver}-mysql" "php${php_ver}-mbstring" "php${php_ver}-gd" \
      "php${php_ver}-curl" "php${php_ver}-zip" >/dev/null 2>&1 || return 1
    SITE_PHP_FPM_BIN="/usr/sbin/php-fpm${php_ver}"
    [[ -x "$SITE_PHP_FPM_BIN" ]] || SITE_PHP_FPM_BIN="/usr/bin/php-fpm${php_ver}"
    SITE_PHP_CLI_BIN="/usr/bin/php${php_ver}"
  else
    if [[ "$mode" != "parallel" && "$system_ver" == "$php_ver" && "$system_fpm_ver" == "$php_ver" && -x "$system_fpm" ]]; then
      "$pkg_mgr" install -y \
        php-fpm php-cli php-xml php-mysqlnd php-mbstring php-gd php-process \
        >/dev/null 2>&1 || return 1
      SITE_PHP_FPM_BIN="$system_fpm"
      SITE_PHP_CLI_BIN="$system_cli"
    else
      . /etc/os-release
      major_ver="${VERSION_ID%%.*}"
      "$pkg_mgr" install -y epel-release >/dev/null 2>&1 || true
      "$pkg_mgr" install -y \
        "https://rpms.remirepo.net/enterprise/remi-release-${major_ver}.rpm" \
        >/dev/null 2>&1 || true
      "$pkg_mgr" install -y \
        "php${ver_nodot}" \
        "php${ver_nodot}-php-fpm" \
        "php${ver_nodot}-php-cli" \
        "php${ver_nodot}-php-mysqlnd" \
        "php${ver_nodot}-php-mbstring" \
        "php${ver_nodot}-php-xml" \
        "php${ver_nodot}-php-gd" \
        "php${ver_nodot}-php-process" \
        "php${ver_nodot}-php-sodium" \
        "php${ver_nodot}-php-pecl-zip" \
        >/dev/null 2>&1 || return 1
      SITE_PHP_FPM_BIN="/opt/remi/php${ver_nodot}/root/usr/sbin/php-fpm"
      SITE_PHP_CLI_BIN="/opt/remi/php${ver_nodot}/root/usr/bin/php"
    fi
  fi
  [[ -x "$SITE_PHP_FPM_BIN" ]] || {
    error "PHP-FPM $php_ver binary not found after installation."
    return 1
  }
  [[ -x "$SITE_PHP_CLI_BIN" ]] || SITE_PHP_CLI_BIN="$(php_cli_for_fpm_binary "$SITE_PHP_FPM_BIN" "$php_ver" || true)"
  [[ -x "$SITE_PHP_CLI_BIN" ]] || {
    error "PHP CLI $php_ver binary matching the site FPM runtime was not found."
    return 1
  }
  [[ "$(php_fpm_version "$SITE_PHP_FPM_BIN" || true)" == "$php_ver" ]] || {
    error "Installed PHP-FPM binary does not report PHP $php_ver."
    return 1
  }
  [[ "$(php_cli_version "$SITE_PHP_CLI_BIN" || true)" == "$php_ver" ]] || {
    error "Installed PHP CLI binary does not match PHP-FPM $php_ver."
    return 1
  }
  SITE_PHP_VERSION="$php_ver"
}
nextcloud_select_php_version() {
  local system_cli="" system_ver="" system_full="" candidate="" ver_nodot="" cli="" full=""
  system_cli="$(command -v php 2>/dev/null || true)"
  if [[ -n "$system_cli" ]]; then
    system_ver="$(php_cli_version "$system_cli" || true)"
    system_full="$(php_full_version "$system_cli" || true)"
    if [[ "$system_ver" =~ ^8\.[345]$ && ! "$system_full" =~ (alpha|beta|RC|dev) ]]; then
      printf '%s\n' "$system_ver"
      return 0
    fi
  fi
  for candidate in 8.5 8.4 8.3; do
    ver_nodot="${candidate//./}"
    for cli in \
      "/opt/remi/php${ver_nodot}/root/usr/bin/php" \
      "/usr/bin/php${candidate}" \
      "/usr/bin/php${ver_nodot}"; do
      [[ -x "$cli" ]] || continue
      full="$(php_full_version "$cli" || true)"
      if [[ "$(php_cli_version "$cli" || true)" == "$candidate" && ! "$full" =~ (alpha|beta|RC|dev) ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done
  done
  printf '%s\n' "8.5"
}
site_php_install_nextcloud_extensions() {
  local domain="$1"
  local cli="" fpm="" ver="" ver_nodot="" module=""
  local -a packages=()
  cli="$(site_php_cli_bin "$domain")" || return 1
  fpm="$(site_php_fpm_bin "$domain")" || return 1
  ver="$(php_cli_version "$cli")" || return 1
  ver_nodot="${ver//./}"
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    packages=("php${ver}-imagick" "php${ver}-apcu" "php${ver}-gmp" "php${ver}-intl")
    "$pkg_mgr" install -y "${packages[@]}" >/dev/null 2>&1 || return 1
    if ! "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m | grep -qi '^sodium$'; then
      "$pkg_mgr" install -y "php${ver}-common" >/dev/null 2>&1 || return 1
    fi
  elif [[ "$fpm" == /opt/remi/php*/root/usr/sbin/php-fpm ]]; then
    packages=(
      "php${ver_nodot}-php-pecl-imagick"
      "php${ver_nodot}-php-pecl-apcu"
      "php${ver_nodot}-php-gmp"
      "php${ver_nodot}-php-intl"
    )
    "$pkg_mgr" install -y "${packages[@]}" >/dev/null 2>&1 || return 1
    if ! "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m | grep -qi '^sodium$'; then
      "$pkg_mgr" install -y "php${ver_nodot}-php-sodium" >/dev/null 2>&1 || return 1
    fi
  else
    "$pkg_mgr" install -y php-pecl-imagick php-pecl-apcu php-gmp php-intl >/dev/null 2>&1 || return 1
    if ! "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m | grep -qi '^sodium$'; then
      "$pkg_mgr" install -y php-sodium >/dev/null 2>&1 || return 1
    fi
  fi
  for module in sodium apcu gmp intl; do
    "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m | grep -qi "^${module}$" || {
      error "Required Nextcloud PHP module '$module' is not loaded by the isolated PHP $ver runtime."
      return 1
    }
  done
}
site_php_install_redis_extension() {
  local domain="$1"
  local cli="" fpm="" ver="" ver_nodot="" package="" installed=0
  cli="$(site_php_cli_bin "$domain")" || return 1
  fpm="$(site_php_fpm_bin "$domain")" || return 1
  if "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m 2>/dev/null | grep -qi '^redis$'; then
    return 0
  fi
  ver="$(php_cli_version "$cli")" || return 1
  ver_nodot="${ver//./}"
  if [[ "$pkg_mgr" == "apt" || "$pkg_mgr" == "apt-get" ]]; then
    "$pkg_mgr" install -y "php${ver}-redis" >/dev/null 2>&1 || return 1
  elif [[ "$fpm" == /opt/remi/php*/root/usr/sbin/php-fpm ]]; then
    for package in \
      "php${ver_nodot}-php-pecl-redis6" \
      "php${ver_nodot}-php-pecl-redis" \
      "php${ver_nodot}-php-pecl-redis5"; do
      if "$pkg_mgr" install -y "$package" >/dev/null 2>&1; then
        installed=1
        break
      fi
    done
    [[ "$installed" -eq 1 ]] || {
      error "Unable to install a Redis PHP extension for isolated PHP $ver."
      return 1
    }
  else
    "$pkg_mgr" install -y php-pecl-redis >/dev/null 2>&1 || return 1
  fi
  "$cli" -c "/etc/one-click/php/${domain}/php.ini" -m 2>/dev/null | grep -qi '^redis$' || {
    error "Redis PHP extension is not loaded by the isolated PHP $ver runtime for $domain."
    return 1
  }
  if systemctl is-active --quiet "php-fpm@${domain}.service"; then
    systemctl restart "php-fpm@${domain}.service" || return 1
  fi
}
site_php_exec_as() {
  local domain="$1"
  local user="$2"
  shift 2
  local cli=""
  cli="$(site_php_cli_bin "$domain")" || return 1
  sudo -u "$user" "$cli" "$@"
}
site_wp_cli_command() {
  local domain="$1"
  local user="$2"
  local path="$3"
  local cli=""
  cli="$(site_php_cli_bin "$domain")" || return 1
  printf 'sudo -u %s %s -c /etc/one-click/php/%s/php.ini -d memory_limit=1024M /usr/local/bin/wp --path=%s\n' \
    "$user" "$cli" "$domain" "$path"
}
# Execute WP-CLI with the PHP version assigned to this site, without a
# word-split command string. Only staging-related paths use this helper.
wp_staging_cli() {
  local domain="$1" user="$2" path="$3" cli=""
  shift 3
  cli="$(site_php_cli_bin "$domain")" || return 1
  [[ -x "$cli" && -r "/usr/local/bin/wp" ]] || return 1
  sudo -u "$user" "$cli" -c "/etc/one-click/php/${domain}/php.ini" -d memory_limit=1024M \
    /usr/local/bin/wp --path="$path" "$@"
}
switch_cli_php() {
  info "Detecting installed PHP CLI versions."
  local php_bins=($(ls /usr/bin/php[0-9].* 2>/dev/null | sort -V))
  if [[ ${#php_bins[@]} -eq 0 ]]; then
    error "No versioned PHP binaries found in /usr/bin/"
    return 1
  fi
  echo "Available PHP CLI versions:"
  for i in "${!php_bins[@]}"; do
    printf ${magenta}[${yellow}%d${magenta}]${reset} %s\n "$((i+1))" "$(basename "${php_bins[$i]}")"
  done
  read -rp "${cyan}[USER]${reset} Select version to set as system default: " choice
  local selected_bin="${php_bins[$((choice-1))]}"
  local selected_ver=$(basename "$selected_bin")
  if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --set php "$selected_bin"
  elif command -v alternatives >/dev/null 2>&1; then
    alternatives --set php "$selected_bin"
  else
    info "No alternatives manager found. Using manual symlink."
    ln -sf "$selected_bin" /usr/bin/php
  fi
  success "CLI is now $(php -v | head -n1)"
}
switch_site_php() {
  local domain base_conf ini_file fpm_conf service_file current_ver new_ver
  local binary_path="" cli_path=""
  domain="$1"
  set_domain_context || return 1
  base_conf="/etc/one-click/php/$domain"
  ini_file="$base_conf/php.ini"
  fpm_conf="$base_conf/php-fpm.conf"
  current_ver="$(site_php_version "$domain" 2>/dev/null || true)"
  read -rp "${cyan}[USER]${reset} Enter PHP version (e.g., 8.2): " new_ver
  [[ "$new_ver" =~ ^[0-9]+\.[0-9]+$ ]] || {
    error "Invalid PHP version: $new_ver"
    return 1
  }
  site_php_prepare_runtime "$new_ver" "parallel" || return 1
  binary_path="$SITE_PHP_FPM_BIN"
  cli_path="$SITE_PHP_CLI_BIN"
  service_file="/etc/systemd/system/php-fpm@${domain}.service"
  [[ -f "$service_file" ]] || {
    error "Service file not found: $service_file"
    return 1
  }
  sed -Ei "s,(ExecStart=)[^ \t]*,\1$binary_path," "$service_file"
  systemctl daemon-reload
  systemctl restart "php-fpm@$domain"
  site_php_record_runtime "$domain" "$binary_path" "$cli_path" "$new_ver"
  if [[ -f "/etc/one-click/nextcloud/${domain}/meta.conf" ]]; then
    site_php_install_nextcloud_extensions "$domain" || return 1
  fi
  case "${webserver:-}" in
    nginx) systemctl reload nginx ;;
    apache|apache2)
      if systemctl cat apache2 >/dev/null 2>&1; then
        systemctl reload apache2
      else
        systemctl reload httpd
      fi
      ;;
    httpd) systemctl reload httpd ;;
  esac
  success "$domain is now using isolated PHP $new_ver for both FPM and site CLI operations."
  [[ -z "$current_ver" ]] || info "Previous site PHP version: $current_ver"
}
setup_repos() {
  if [[ "${os_family:-}" == "debian" ]]; then
    info "Ensuring Debian PHP repositories."
    $pkg_mgr update -y && $pkg_mgr install -y lsb-release ca-certificates curl gnupg2
    [[ ! -f /etc/apt/trusted.gpg.d/php.gpg ]] && curl -sSLo /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    $pkg_mgr update -y
  else
    info "Ensuring RHEL PHP repositories."
    $pkg_mgr install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
    $pkg_mgr install -y dnf-utils
  fi
}
install_php() {
  local ver="${1:-}"
  info "Installing PHP $ver and common extensions."
  setup_repos
  v=$(sed -En '/PHP/s/^[^0-9]*([0-9]+\.[0-9]+).*/\1/p' <(php -v))
  "$pkg_mgr" install -y php${v}-fpm
  $pkg_mgr install -y php-fpm "php$v-fpm" "php-posix" "php$v-cli" "php$v-mysql" "php$v-xml" "php$v-mbstring" "php$v-gd" "php$v-curl" "php$v-zip" "php$v-gd" || return 1
  fpm_service="php$v-fpm"
  if [[ "${webserver:-}" =~ apache || "$webserver" == "httpd" ]]; then
    a2enmod proxy_fcgi setenvif || true
    a2enconf php${v}-fpm || true
    $pkg_mgr module reset php -y
    $pkg_mgr module enable "php:remi-$ver" -y
    $pkg_mgr install -y php php-fpm php-mysql php-posix php-mysqlnd php-xml php-mbstring php-gd php-curl php-zip "php$ver-xml" php-gd || return 1
    fpm_service="php-fpm"
  fi
  $pkg_mgr stop "php$ver-fpm" 2>/dev/null || true
  $pkg_mgr disable "php$ver-fpm" 2>/dev/null || true
  success "PHP $v is installed and running."
}
site_tune_php() {
  php_version="$(site_php_version "$domain" 2>/dev/null || true)"
  set_domain_context
  [[ ! -f "$php_ini" ]] && {
    error "php.ini not found at $php_ini"
    return 1
  }
  info "Tuning PHP for ${domain} (PHP $php_version)"
  read -rp "${cyan}[USER]${reset} Memory Limit (e.g. 512M): " mem
  read -rp "${cyan}[USER]${reset} Upload Limit (e.g. 100M): " upload
  read -rp "${cyan}[USER]${reset} Execution Time: " exec_t
  update_ini() {
    sed -i "s|^;*$1 *=.*|$1 = $2|" "$php_ini"
  }
  [[ -n "$mem" ]] && update_ini memory_limit "$mem"
  [[ -n "$upload" ]] && {
    update_ini upload_max_filesize "$upload"
    update_ini post_max_size "$upload"
  }
  [[ -n "$exec_t" ]] && update_ini max_execution_time "$exec_t"
  systemctl restart "$php_service"
  success "Updated and restarted $php_service"
}
tune_php_settings() {
  local php_vers=($(ls /etc/php/ 2>/dev/null || ls /etc/opt/remi/ 2>/dev/null | grep -E '[0-9]\.[0-9]'))
  [[ ${#php_vers[@]} -eq 0 ]] && { error "No PHP configurations found."; return 1; }
  printf "$(tput setaf 98)[PHP]:${reset} %s\n" "Select PHP version to tune:"
  for i in "${!php_vers[@]}"; do
    printf "${magenta}[${yellow}%d${magenta}]${reset} PHP %s\n" "$((i+1))" "${php_vers[$i]}"
  done
  while true; do
    read -rp "${cyan}[USER]${blue} Choice: " v_idx
    [[ "$v_idx" =~ ^[0-9]+$ ]] && (( v_idx >= 1 && v_idx <= ${#php_vers[@]} )) && break || error "Invalid selection."
  done
  local sel_ver="${php_vers[$((v_idx-1))]}"
  if [[ "$os_family" == "debian" ]]; then
    ini_path="/etc/php/$sel_ver/fpm/php.ini"
    fpm_serv="php-fpm@${domain}"
  else
    ini_path="/etc/opt/remi/php${sel_ver//./}/php.ini"
    [[ ! -f "$ini_path" ]] && ini_path="/etc/php.ini"
    fpm_serv="php-fpm@${domain}"
  fi
  [[ ! -f "$ini_path" ]] && { error "php.ini not found at $ini_path"; return 1; }
  printf "$(tput setaf 98)[PHP]:${reset} %s\n" "Modifying settings for PHP $sel_ver ($ini_path)"
  read -rp "${cyan}[USER]${blue} New Memory Limit (e.g., 256M): " mem
  read -rp "${cyan}[USER]${blue} New Max Upload Size (e.g., 64M): " upload
  read -rp "${cyan}[USER]${blue} New Max Execution Time (seconds): " exec_t
  update_ini() {
    local key=$1; local val=$2
    if grep -q "^$key" "$ini_path"; then
      sed -i "s/^$key.*/$key = $val/" "$ini_path"
    else
      echo "$key = $val" >> "$ini_path"
    fi
  }
  [[ -n "$mem" ]] && update_ini "memory_limit" "$mem"
  [[ -n "$upload" ]] && { update_ini "upload_max_filesize" "$upload"; update_ini "post_max_size" "$upload"; }
  [[ -n "$exec_t" ]] && update_ini "max_execution_time" "$exec_t"
  systemctl restart "$fpm_serv"
  success "Settings updated and $fpm_serv restarted."
}
php_menu() {
  select_domain || return 1
  detect_env
  set_domain_context
  while true; do
    php_version="$(site_php_version "$domain" 2>/dev/null || true)"
    paste <(printf '%s\n' \
      "${yellow}--- PHP MANAGER ---${reset}" \
      "${magenta}OS:${green} $os_family ${blue}| ${magenta}Webserver: ${green}${webserver}" \
      "${blue}----------------------------${reset}" \
      "${magenta}[${yellow}1${magenta}]${reset} Install PHP Version" \
      "${magenta}[${yellow}2${magenta}]${reset} Switch Site PHP (Web)" \
      "${magenta}[${yellow}3${magenta}]${reset} Switch System PHP (CLI)" \
      "${magenta}[${yellow}4${magenta}]${reset} Global PHP.ini Tuning" \
      "${magenta}[${yellow}5${magenta}]${reset} Site-Specific Tuning" \
      "${magenta}[${yellow}6${magenta}]${reset} PHP Process Control" \
      "${magenta}[${yellow}7${magenta}]${reset} Change Domain" \
      "${magenta}[${yellow}0${magenta}]${reset} Exit") <(printf "${blue}[${green}${domain}${blue}] ${yellow}PHP VERSION:${blue} ${php_version} ${magenta}║ ${yellow}WEBSERVER:${blue} ${webserver}${reset}")
      read -rp "${cyan}[USER]${reset} Option: " opt
      case "$opt" in
        1)
          if [[ "$os_family" == "debian" ]]; then
            apt-cache pkgnames | grep -E '^php[0-9]+\.[0-9]+$' | sort -u
          else
            dnf module list php
          fi
          read -rp "${cyan}[USER]${reset} Version (e.g. 8.2): " v
          install_php "$v"           ;;
        2) switch_site_php "$domain" ;;
        3) switch_cli_php            ;;
        4) tune_php_settings         ;;
        5) site_tune_php             ;;
        6) php_process_control       ;;
        7) select_domain             ;;
        0) exit 0                    ;;
        *) error "Invalid option"    ;;
      esac
      echo
      read -rp "${cyan}[USER]${reset} Press Enter to continue..."
    done
}
set_domain_context() {
  php_service="php-fpm@${domain}.service"
  php_slice="one-click_${domain}.slice"
  if [[ -f "/etc/nginx/sites-enabled/${domain}.conf" ]]; then
    site_conf="/etc/nginx/sites-enabled/${domain}.conf"
  elif [[ -f "/etc/nginx/conf.d/${domain}.conf" ]]; then
    site_conf="/etc/nginx/conf.d/${domain}.conf"
  elif [[ -f "/etc/apache2/sites-enabled/${domain}.conf" ]]; then
    site_conf="/etc/apache2/sites-enabled/${domain}.conf"
  elif [[ -f "/etc/httpd/conf.d/${domain}.conf" ]]; then
    site_conf="/etc/httpd/conf.d/${domain}.conf"
  fi
  php_version="$(site_php_version "$domain" 2>/dev/null || true)"
  [[ -z "$php_version" ]] && php_version="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
  php_ini="/etc/one-click/php/${domain}/php.ini"
}
php_process_control() {
  local svc="$php_service"
  local slice="$php_slice"
  while true; do
    svc_state=$(get_service_state "$svc")
    slice_state=$(get_service_state "$slice")
    clear
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════╗" \
      "║                ${yellow}PHP PROCESS CONTROL${blue}                 ║" \
      "╠════╦═══════════════════════════════════════════════╣"
    printf "${blue}║ ${magenta}1${blue}  ║ View PHP-FPM Status        [%s]           ║${reset}\n" "$(fmt_state "$svc_state")"
    printf "${blue}║ ${magenta}2${blue}  ║ Toggle PHP-FPM             [%s]           ║${reset}\n" "$(fmt_state "$svc_state")"
    echo -e "${blue}║ ${magenta}3${blue}  ║ Restart PHP-FPM                               ║${reset}"
    printf "${blue}║ ${magenta}4${blue}  ║ View Slice Status          [%s]           ║${reset}\n" "$(fmt_state "$slice_state")"
    printf "${blue}║ ${magenta}5${blue}  ║ Toggle Slice               [%s]           ║${reset}\n" "$(fmt_state "$slice_state")"
    echo -e "${blue}║ ${magenta}0${blue}  ║ Back                                          ║${reset}"
    echo -e "${blue}╚════╩═══════════════════════════════════════════════╝${reset}"
    read -rsn1 -p "${cyan}[USER]${blue} Select option: " choice
    echo
    case "$choice" in
      1) view_service_status "$svc"   ;;
      2) toggle_service "$svc"        ;;
      3) restart_service "$svc"       ;;
      4) view_service_status "$slice" ;;
      5) toggle_service "$slice"      ;;
      0) return                       ;;
      *) echo "Invalid option"        ;;
    esac
    echo
    read -rp "${cyan}[USER]${reset} Press Enter to continue..."
  done
}
select_domain() {
  if [[ -n "${wpstatic:-}" ]]; then
    if [[ "$wpstatic" == "wordpress" ]]; then
      list_domains() {
        ls /etc/one-click/wordpress | sed -n '/\./p'
      }
    elif [[ "$wpstatic" == "static" ]]; then
      list_domains() {
        ls /etc/one-click/sites | sed -n '/\./p'
      }
    fi
  elif [[ -n "${used_app:-}" ]]; then
    if [[ "$used_app" == "nodejs" ]]; then
      list_domains() {
        ls /etc/one-click/apps/nodejs | sed -n '/\./p'
      }
    elif [[ "$used_app" == "nextcloud" ]]; then
      list_domains() {
        ls /etc/one-click/nextcloud | sed -n '/\./p'
      }
    fi
  else
    list_domains() {
      ls /etc/one-click/nextcloud /etc/one-click/wordpress /etc/one-click/sites /etc/one-click/apps/nodejs 2> /dev/null | sed -n '/\./p'
    }
  fi
  mapfile -t domains < <(list_domains)
  if [[ ${#domains[@]} -eq 0 ]]; then
    error "${red}No domains found${reset}"
    sleep 3
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
  fi
  if [[ ${#domains[@]} -eq 1 ]]; then
    domain="${domains[0]}"
    info "${green}Using domain: ${yellow}${domain}${reset}"
    return 0
  fi
  while true; do
    clear
    echo -e "${blue}╔════════════════════════════════════════════════════╗${reset}"
    echo -e "${blue}║              ${yellow}SELECT A DOMAIN TO MANAGE${blue}             ║${reset}"
    echo -e "${blue}╠═════╦══════════════════════════════════════════════╣${reset}"
    for i in "${!domains[@]}"; do
      local domain_name="${domains[$i]}"
      local icon=$(get_heartbeat "$domain_name")
      printf "${blue}║ ${magenta}%-3s${blue} ║ %b ${green}%-42s${blue} ║${reset}\n" "$((i+1))" "$icon" "${domains[$i]}"
    done
    echo -e "${blue}╠═════╩══════════════════════════════════════════════╣${reset}"
    echo -e "${blue}║ ${cyan}q${blue} = cancel                                         ║${reset}"
    echo -e "${blue}╚════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${blue} Select domain: " choice
    case "$choice" in
      q|Q) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
      '' ) continue ;;
      *[!0-9]*)
        echo -e "${red}Invalid input${reset}"
        sleep 1
        ;;
      *)
        idx=$((choice-1))
        if [[ -n "${domains[$idx]}" ]]; then
          domain="${domains[$idx]}"
          info "${green}Selected: ${yellow}${domain}${reset}"
          return 0
        else
          error "${red}Invalid selection${reset}"
          sleep 1
        fi
        ;;
    esac
  done
}
get_heartbeat() {
  local url="http://$1"
  local status
  status=$(curl -Is -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url" 2>/dev/null)
  case "$status" in
    20[0-9]|30[1278])
      echo -e "${green}●${reset}"
      ;;
    *)
      echo -e "${red}●${reset}"
      ;;
  esac
}
create_isolated_php_runtime() {
  local domain="$1"
  local php_ver="$2"
  local site_user="$3"
  local webserver="$4"
  local type="$5"
  local meta="/etc/one-click/${type}/${domain}/meta.conf"
  local php_bin=""
  local php_cli=""
  local listen_group=""
  local base_conf="/etc/one-click/php/$domain"
  local run_dir="/run/one-click/$domain"
  local log_dir="/var/log/one-click/$domain"
  local lib_dir="/var/lib/one-click/$domain"
  local ini_file="$base_conf/php.ini"
  local fpm_conf="$base_conf/php-fpm.conf"
  local pool_conf="$base_conf/pool.conf"
  local systemd_unit="/etc/systemd/system/php-fpm@$domain.service"
  local staging_allowed="" staging_rw=""
  local user_ini_line='php_admin_value[user_ini.filename] = ""'
  if [[ "$type" == 'wordpress' ]]; then
    staging_allowed="/etc/one-click/wordpress/staging/${domain}/:"
    # The staging path does not exist until after installation.  systemd's
    # leading '-' makes it an optional read-write path at first start.
    staging_rw=" -/etc/one-click/wordpress/staging/${domain}"
  fi
  [[ -n "$domain" && -n "$site_user" && -n "$type" ]] || {
    error "Incomplete PHP runtime parameters."
    return 1
  }
  id "$site_user" >/dev/null 2>&1 || {
    error "PHP site user does not exist: $site_user"
    return 1
  }
  if [[ "$type" == "nextcloud" ]]; then
    user_ini_line='php_admin_value[user_ini.filename] = ".user.ini"'
  fi
  site_php_prepare_runtime "$php_ver" "auto" || return 1
  php_bin="$SITE_PHP_FPM_BIN"
  php_cli="$SITE_PHP_CLI_BIN"
  case "${webserver_user:-}" in
    "")
      case "$webserver" in
        nginx) getent passwd nginx >/dev/null && listen_group="nginx" || listen_group="www-data" ;;
        apache|apache2|httpd) getent passwd apache >/dev/null && listen_group="apache" || listen_group="www-data" ;;
        *) listen_group="$site_user" ;;
      esac
      ;;
    *) listen_group="$webserver_user" ;;
  esac
  mkdir -p "$base_conf" "$run_dir" "$log_dir/php" "$lib_dir"/{tmp,sessions}
  chown -R "$site_user:$site_user" "$lib_dir"
  chmod 700 "$lib_dir" "$lib_dir/tmp" "$lib_dir/sessions"
  chown -R "$site_user:${listen_group}" "$log_dir/php"
  cat > "$ini_file" <<EOF
[PHP]
memory_limit = 1024M
upload_max_filesize = 64M
post_max_size = 64M
expose_php = Off
display_errors = Off
log_errors = On
session.save_path = $lib_dir/sessions
upload_tmp_dir = $lib_dir/tmp
EOF
  cat > "$pool_conf" <<EOF
[$domain]
user = $site_user
group = $site_user
listen = $run_dir/php.sock
listen.owner = $site_user
listen.group = $listen_group
listen.mode = 0660
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.process_idle_timeout = 10s
pm.max_requests = 500
php_admin_value[memory_limit] = 1024M
$user_ini_line
php_admin_value[open_basedir] = /etc/one-click/${type}/${domain}/:${staging_allowed}/tmp:/var/lib/one-click/${domain}/:/etc/one-click/db-manager/runtime/tokens:/etc/one-click/db-manager/sites/${domain}.json:/etc/one-click/db-manager/secrets/db/${domain}.pass
php_admin_value[upload_tmp_dir] = $lib_dir/tmp
php_admin_value[session.save_path] = $lib_dir/sessions
php_admin_value[display_errors] = Off
php_admin_value[error_log] = $log_dir/php/error.log
EOF
  cat > "$fpm_conf" <<EOF
[global]
pid = $run_dir/php-fpm.pid
error_log = $log_dir/php/php-fpm.log
include = $pool_conf
EOF
  cat > "$systemd_unit" <<EOF
[Unit]
Description=One-Click isolated PHP-FPM runtime for $domain
After=network.target
[Service]
Type=simple
ExecStart=$php_bin --nodaemonize --fpm-config $fpm_conf -c $ini_file
ExecReload=/bin/kill -USR2 \$MAINPID
User=root
Group=root
Slice=one-click_$domain.slice
RuntimeDirectory=one-click/$domain
RuntimeDirectoryMode=0755
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/one-click/${type}/${domain}${staging_rw} /var/lib/one-click/${domain} /var/log/one-click/${domain} /run/one-click/${domain}
NoNewPrivileges=true
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF
  if [[ -f "$meta" ]]; then
    for pair in \
      "PHP_DIR=$base_conf" \
      "PHP_RUNTIME=$run_dir" \
      "PHP_LIB_DIR=$lib_dir" \
      "PHP_INI_FILE=$ini_file" \
      "PHP_FPM_CONF=$fpm_conf" \
      "PHP_POOL_CONF=$pool_conf" \
      "PHP_SYSTEMD_ENABLED=true" \
      "PHP_SYSTEMD_SERVICE_NAME=php-fpm@$domain.service" \
      "PHP_SYSTEMD_VHOST=$systemd_unit" \
      "PHP_VERSION=$php_ver" \
      "PHP_FPM_BIN=$php_bin" \
      "PHP_CLI_BIN=$php_cli"; do
      key="${pair%%=*}"
      if grep -q "^${key}=" "$meta"; then
        sed -i "s|^${key}=.*|${pair}|" "$meta"
      else
        echo "$pair" >> "$meta"
      fi
    done
  fi
  systemctl daemon-reload
  systemctl enable "php-fpm@$domain" >/dev/null 2>&1
  if systemctl is-active --quiet "php-fpm@$domain"; then
    systemctl restart "php-fpm@$domain"
  else
    systemctl start "php-fpm@$domain"
  fi
  for _ in {1..20}; do
    [[ -S "$run_dir/php.sock" ]] && break
    sleep 0.25
  done
  if ! systemctl is-active --quiet "php-fpm@$domain" || [[ ! -S "$run_dir/php.sock" ]]; then
    error "PHP $php_ver runtime for $domain failed to become ready."
    journalctl -u "php-fpm@$domain" -n 30 --no-pager 2>/dev/null || true
    return 1
  fi
  success "PHP ${php_ver:-current} runtime for $domain is active."
  info "FPM: $php_bin" "CLI: $php_cli" "Socket: $run_dir/php.sock" "Logs: $log_dir/php/php-fpm.log"
}
create_rollback_snapshot() {
  local domain type ts base backup_source rollback_dir latest
  domain="$1"
  resolve_type "$domain"
  ts=$(date +%Y%m%d-%H%M%S)
  info "Creating rollback snapshot for $domain"
  if [[ "$type" == "wordpress" ]]; then
    base="/etc/one-click/wordpress"
    wp_backup "$domain" "ran" snap
  else
    base="/etc/one-click/${type}"
    static_backup "$domain" snap
  fi
  set +o pipefail
  backup_source="$base/backups/$domain"
  latest=$(ls -1 "$backup_source/" 2>/dev/null | tail -n1)
  set -o pipefail
  if [[ -z "$latest" ]]; then
    error "No recent backup found to snapshot"
    return 1
  fi
  rollback_dir="$base/rollback/$domain/$ts"
  mkdir -p "$rollback_dir"
  cp -a "$backup_source/$latest/." "$rollback_dir/"
  success "Rollback snapshot created: $ts"
}
rollback_list() {
  local domain="$1"
  skip_prompt="${2:-}"
  resolve_type "$domain"
  local base="/etc/one-click/$type/rollback"
  echo -e "\e[34m╔════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Snapshot             ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╣\e[0m"
  mapfile -t snaps < <(ls -1 "$base/$domain/" 2>/dev/null | sort -r)
  local i=1
  for s in "${snaps[@]}"; do
    printf "\e[34m║ %-2s ║ %-20s ║\e[0m\n" "$i" "$s"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╝\e[0m"
  if [[ "$skip_prompt" == "no" ]]; then
    read -rp "${cyan}[USER]${blue} Select snapshot ID: " choice
    echo "${snaps[$((choice-1))]}"
  fi
}
rollback_restore() {
  local domain type base
  domain="$1"
  type="$2"
  if [[ "$type" == "wordpress" ]]; then
    base="/etc/one-click/wordpress/rollback"
  else
    base="/etc/one-click/sites/rollback"
  fi
  local snapshot_root="${base}/${domain}"
  [[ ! -d "$snapshot_root" ]] && { error "No rollback snapshots found for $domain at $snapshot_root"; return 1; }
  mapfile -t snapshots < <(ls -1 "$snapshot_root" | sort -r)
  [[ ${#snapshots[@]} -eq 0 ]] && { error "No snapshots found"; return 1; }
  echo -e "\e[34m╔════╦═════════════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Snapshot                    ║\e[0m"
  echo -e "\e[34m╠════╬═════════════════════════════╣\e[0m"
  local i=1
  for ts in "${snapshots[@]}"; do
    printf "\e[34m║ %-2s ║ %-27s ║\e[0m\n" "$i" "$ts"
    ((i++))
  done
  echo -e "\e[34m╚════╩═════════════════════════════╝\e[0m"
  local choice tmp
  while true; do
    read -rp "${cyan}[USER]${blue} Select snapshot ID to restore (0 to cancel): ${reset}" choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice <= ${#snapshots[@]} )); then
      [[ "$choice" -eq 0 ]] && { error "Rollback cancelled"; return 1; }
      #tmp="${backup_dir}/${snapshots[$((choice-1))]}"
      break
    else
      error "Invalid selection, try again"
    fi
  done
  local selected_snapshot="${snapshot_root}/${snapshots[$((choice-1))]}"
  info "Restoring rollback snapshot: ${snapshots[$((choice-1))]}"
  if [[ "$type" == "wordpress" ]]; then
    wp_restore "$domain" "$selected_snapshot"
  else
    static_restore "$domain" "$selected_snapshot"
  fi
  success "Rollback completed for $domain"
}
web_log_view() {
  local domain="$1"
  local type="${2:-access}"
  local mode="${3:-view}"
  local status_filter="${4:-}"
  local log=""
  local base
  for base in /var/log/one-click/${domain}/nginx /var/log/one-click/${domain}/apache /var/log/one-click/${domain}/apache2 /var/log/one-click/${domain}/php /var/log/one-click/${domain}/httpd; do
    if [[ -f "$base/${type}.log" ]]; then
      log="$base/${type}.log"
      break
    fi
  done
  [[ -z "$log" ]] && {
    echo "Log not found for $domain ($type)"
    return 1
  }
  color_access() {
    awk -v status_filter="$status_filter" '
    {
      ip=$1
      match($0, /\[[^]]+\]/)
      timestamp=substr($0, RSTART, RLENGTH)
      method=$6
      gsub(/"/,"",method)
      path=$7
      status=$9
      if (status_filter != "" && status !~ "^"status_filter)
        next
      reset="\033[0m"
      ts_color="\033[90m"
      ip_color="\033[36m"
      method_color="\033[34m"
      if (status ~ /^2/)
        status_color="\033[32m"
      else if (status ~ /^3/)
        status_color="\033[36m"
      else if (status ~ /^4/)
        status_color="\033[33m"
      else if (status ~ /^5/)
        status_color="\033[31m"
      else
        status_color=reset
      printf "%s%s%s\n",
        ts_color, timestamp, reset
      printf "  %s%-15s%s  %s%-6s%s  %s%-4s%s\n",
        ip_color, ip, reset,
        method_color, method, reset,
        status_color, status, reset
      printf "  %s\n\n", path
    }'
  }
  color_error() {
    awk '
    {
      line=$0
      reset="\033[0m"
      match(line, /\[[^]]+\]/)
      timestamp=substr(line, RSTART, RLENGTH)
      ts_color="\033[90m"
      if (tolower(line) ~ /critical|fatal|emerg/)
        color="\033[31m"
      else if (tolower(line) ~ /warn|warning/)
        color="\033[33m"
      else if (tolower(line) ~ /notice|info/)
        color="\033[36m"
      else
        color="\033[0m"
      gsub(/\[[^]]+\]/, "", line)
      printf "%s%s%s\n",
        ts_color, timestamp, reset
      printf "  %s%s%s\n\n",
        color, line, reset
    }'
  }
  if [[ "$mode" == "tail" ]]; then
    if [[ "$type" == "access" ]]; then
      (tail -F "$log" | color_access) || true
    else
      (tail -F "$log" | color_error) || true
    fi
    return
  fi
  if [[ "$type" == "access" ]]; then
    (color_access < "$log" | less -R) || true
  else
    (color_error < "$log" | less -R) || true
  fi
}
##################################### SECURITY (GUARD) ##################################
declare -gA offense_count
# ==== Do Not Monitor IPs In Whitelist ====
WHITELIST=("127.0.0.1")
guard_dir="/etc/one-click/rule-engine/guard"
monitor_history_file="$guard_dir/history"
stats_file="$guard_dir/monitor_stats.db"
mkdir -p "$guard_dir"
apply_block() {
  local ip proto port action duration file
  if [[ "$ip" =~ .*:.* ]]; then
    fw_bin=ip6tables
  else
    fw_bin=iptables
  fi
  ip="$1"
  proto="$2"
  port="$3"
  action="$4"
  duration="$5"
  file="$6"
  $fw_bin -I INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action"
  local ts
  ts=$(date +%s)
  echo "{\"ts\":$ts,\"ip\":\"$ip\",\"proto\":\"$proto\",\"port\":\"$port\",\"action\":\"$action\",\"duration\":$duration,\"reason\":\"$reason\"}" >> "$monitor_history_file"
  (
    sleep "$duration"
    if $fw_bin -C INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action" &>/dev/null; then
        $fw_bin -D INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action"
        echo "{\"ts\":$(date +%s),\"ip\":\"$ip\",\"action\":\"UNBLOCKED\",\"reason\":\"Timeout\"}" >> "$monitor_history_file"
    fi
  ) &
}
monitor_web_logs() {
  local ip domain uri duration guard_id stats_file
  domain="$1"
  infos() {
    s=$1
    printf "$(tput setaf 4)[INFO]:$(tput sgr 0) %s${s}\n"
  }
  error() {
    s=$1
    printf "$(tput setaf 1)[ERROR]:$(tput sgr 0) %s${s}\n"
  }
  local log_files=()
  stats_file="/etc/one-click/rule-engine/guard/monitor_stats.db"
  mkdir -p /etc/one-click/rule-engine/guard
  paths=(
    "/var/log/one-click/${domain}/nginx/access.log" "/var/log/one-click/${domain}/nginx/error.log"
    "/var/log/one-click/${domain}/apache2/access.log" "/var/log/one-click/${domain}/apache2/error.log"
    "/var/log/one-click/${domain}/httpd/access.log" "/var/log/one-click/${domain}/httpd/error.log"
  )
  for f in "${paths[@]}"; do
    [[ -f "$f" ]] && log_files+=("$f")
  done
  [[ ${#log_files[@]} -eq 0 ]] && { error "No log files found."; return 1; }
  if [[ -f "$stats_file" ]]; then
    while read -r line; do
      hist_ip=$(echo "$line" | cut -d' ' -f2)
      hist_count=$(echo "$line" | cut -d' ' -f1)
      offense_count["$hist_ip"]=$hist_count
    done < "$stats_file"
  fi
  infos "Live Guard active on: ${log_files[*]}"
  tail -Fn0 "${log_files[@]}" | while read -r line; do
    if [[ "$line" =~ ([0-9]{1,3}(\.[0-9]{1,3}){3}) || "$line" =~ ^([a-fA-F0-9:]+)$ ]]; then
      ip="${BASH_REMATCH[1]}"
      for safe_ip in "${WHITELIST[@]}"; do
        [[ "$ip" == "$safe_ip" ]] && continue 2
      done
      if [[ "$line" =~ "$domain" ]]; then
      uri=$(awk -F'"' '{print $(NF-1)}' <<< "$line")
      if [[ "$line" =~ " 404 " ]]; then
        ((offense_count["$ip"]++))
        if (( offense_count["$ip"] >= 10 )); then
          reason="Web Scanner (404 Spamming)"
          duration=3600
          echo "Guard: Banning $ip for $duration seconds ($reason)"
          apply_block "$ip" "all" "0:65535" "DROP" "$duration"
          ts=$(date +%s)
          echo "{\"ts\":$ts,\"ip\":\"$ip\",\"domain\":\"$domain\",\"uri\":\"$uri\",\"reason\":\"$reason\"}" >> "$monitor_history_file"
          offense_count["$ip"]=0
        fi
      fi
      if [[ "$line" =~ "login failed" || "$line" =~ "wplogin" ]]; then
        ((offense_count["$ip"]++))
        if (( offense_count["$ip"] >= 5 )); then
          reason="Brute Force Attempt"
          duration=86400
          apply_block "$ip" "all" "0:65535" "DROP" "$duration"
          ts=$(date +%s)
          echo "{\"ts\":$ts,\"ip\":\"$ip\",\"domain\":\"$domain\",\"uri\":\"$uri\",\"reason\":\"$reason\"}" >> "$monitor_history_file"
          offense_count["$ip"]=0
        fi
      fi
      ts=$(date +%s)
      touch "$stats_file.tmp"
      if printf "%s %s\n" "${offense_count["$ip"]}" "$ip" >> "$stats_file.tmp"; then
        cat "$stats_file.tmp" "$stats_file" > "$stats_file.mv"
        rm -f "$stats_file.tmp" "$stats_file"
        mv "$stats_file.mv" "$stats_file"
      fi
    fi
  fi
  done
  return
}
submit_sitemap() {
  sitemap="$1"
  warn "${yellow}[*]${reset} Submitting sitemap: $sitemap"
  # ==== Submit to Bing ====
  curl -s "https://www.bing.com/ping?sitemap=$sitemap" &> /dev/null && info "${green}[+]${reset} Bing submitted"
  # ==== Submit to Yandex ====
  curl -s "https://webmaster.yandex.com/ping?sitemap=$sitemap" &> /dev/null && info "${green}[+]${reset} Yandex submitted"
  success "${green}[✓]${reset} Submission cycle complete"
}
sitemap_robots() {
  local base
  IFS=$'\n\t'
  domain="$1"
  site_dir="$2"
  sitemap="$site_dir/sitemap.xml"
  html="$site_dir/sitemap.html"
  robots="$site_dir/robots.txt"
  extensions="html htm php"
  tmpfile="$(mktemp)"
  trap 'echo "</urlset>" >> "$sitemap"' EXIT
  trap 'rm -f "$tmpfile"' EXIT
  info "Generating sitemap for $domain."
  cat > "$sitemap" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
EOF
  cat > "$html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>$domain Sitemap</title>

<style>
body {
    font-family: system-ui, sans-serif;
    background: #0f172a;
    color: #e2e8f0;
    max-width: 1000px;
    margin: auto;
    padding: 40px 20px;
    line-height: 1.6;
}

h1 {
    border-bottom: 2px solid #334155;
    padding-bottom: 10px;
    margin-bottom: 30px;
}

.sitemap-entry {
    background: #111827;
    border: 1px solid #1e293b;
    border-radius: 12px;
    padding: 18px;
    margin-bottom: 16px;
    transition: 0.2s ease;
}

.sitemap-entry:hover {
    border-color: #3b82f6;
    transform: translateY(-2px);
}

.sitemap-title a {
    color: #60a5fa;
    text-decoration: none;
    font-size: 18px;
    font-weight: 600;
}

.sitemap-title a:hover {
    text-decoration: underline;
}

.sitemap-meta {
    margin-top: 10px;
    font-size: 14px;
    color: #94a3b8;
    display: flex;
    gap: 20px;
    flex-wrap: wrap;
}
</style>
</head>

<body>

<h1>$domain Sitemap</h1>
EOF
  while IFS= read -r file; do
    base="$(basename "$file")"
    # ==== Ignore Hidden ====
    [[ "$base" =~ ^\. ]] && continue
    ext="${file##*.}"
    include=0
    case "$ext" in
      html|htm|php) include=1 ;;
      *) include=0            ;;
    esac
    [[ "$include" -eq 0 ]] && continue
    rel="${file#$site_dir}"
    # ==== Normalize index files ====
    rel="$(sed 's/index\.\(html\|htm\|php\)$//' <<< "$rel")"
    rel="$(sed 's,//*,/,g' <<< "$rel")"
    url="${domain}${rel}"
    title=$(sed -En 's/.*<title>|<\/title>.*//gp' "$file")
    lastmod="$(date -u -r "$file" '+%Y-%m-%dT%H:%M:%SZ')"
    priority="0.6"
    if [[ "$rel" == "/" ]]; then
      priority="1.0"
    elif [[ "$rel" =~ /guide|/docs|/api ]]; then
      priority="0.9"
    fi
    cat >> "$sitemap" <<EOF
    <url>
      <loc>https://${url}</loc>
      <lastmod>$lastmod</lastmod>
      <priority>$priority</priority>
    </url>
EOF

    cat >> "$html" <<EOF
<div class="sitemap-entry">
    <div class="sitemap-title">
        <a href="https://${url}">$title</a>
    </div>

    <div class="sitemap-meta">
        <span class="sitemap-lastmod">
            Last Updated: $lastmod
        </span>

        <span class="sitemap-priority">
            Priority: $priority
        </span>
    </div>
</div>
EOF
  done < <(find "$site_dir" -type f \
  \( \
    -iname "*.html" \
    -o -iname "*.htm" \
    -o -iname "*.php" \
  \) \
  -not -path "*/assets/*" \
  -not -path "*/static/*" \
  -not -path "*/plugins/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/cache/*" \
  -not -path "*/tmp/*" \
  -not -path "*/\.git/*")
  echo "</urlset>" >> "$sitemap"
  cat >> "$html" <<EOF
</body>
</html>
EOF
# ==== Robots ====
  info "Generating robots page."
  cat > "$robots" <<EOF
User-agent: *
Allow: /

Disallow: /.git/
Disallow: /tmp/
Disallow: /cache/
Disallow: /private/
Disallow: /backup/

Sitemap: $domain/sitemap.xml
EOF
  info "Generated:" \
    " - $sitemap" \
    " - $html" \
    " - $robots"
  submit_sitemap "$sitemap"
  # ==== Configure cron to crawl every week ====
  if [[ ! -f /etc/cron.d/one-click-sitemap_robots ]];then
    cat <<EOF >/etc/cron.d/one-click-sitemap_robots
# Crawl site at 2am every week for changes to be submitted to Google
0 2 * * 0 root bash /var/cache/one-click/wordpress.sh --crawler $domain $site_dir       # One-Click $domain Crawler
EOF
  fi
}
if [[ ! -f /etc/systemd/system/one-click-guard.service ]]; then
  cat << EOF > /etc/systemd/system/one-click-guard.service
[Unit]
Description=One-Click Abuse Monitor
After=network.target nls.target

[Service]
Type=simple
ExecStart=/var/cache/one-click/wordpress.sh --monitor
Restart=always
RestartSec=5
SyslogIdentifier=one-click--guard

[Install]
WantedBy=multi-user.target
EOF
fi
if [[ "$1" == "--monitor" ]]; then
  detect_env "$1"
  monitor_web_logs "$2"
  exit 0
fi
if command -v httpd &> /dev/null || command -v apache2 &> /dev/null || command -v nginx &> /dev/null; then
  if ! systemctl is-active one-click-guard.service &> /dev/null; then
    systemctl daemon-reload
    systemctl is-enabled --quiet "one-click-guard.service" || systemctl enable "one-click-guard.service"
    systemctl is-active --quiet "one-click-guard.service" || systemctl start "one-click-guard.service"
  fi
fi
view_security() {
  local filter_domain="$1"
  local history="${monitor_history_file}"
     draw_row() {
    local ts="$1" ip="$2" domain="$3" uri="$4" reason="$5"
    printf "${blue}│ %-13s │ %-20s │ %-13s │ %-13s │ %-13s │${reset}\n" "$ts" "$ip" "$domain" "$uri" "$reason"
  }
  [[ ! -f "$history" ]] && { echo "[INFO]: No history available."; return 0; }
  printf "${blue}┌───────────────┬──────────────────────┬───────────────┬───────────────┬───────────────┐${reset}\n"
  printf "${blue}│ %-13s │ %-17s    │ %-13s │ %-13s │ %-13s │${reset}\n" "Timestamp" "IP" "Domain" "URI" "Reason"
  printf "${blue}├───────────────┼──────────────────────┼───────────────┼───────────────┼───────────────┤${reset}\n"
  while IFS= read -r line; do
    local ip=$(jq -r '.ip // "0.0.0.0"' <<< "$line")
    local domain=$(jq -r '.domain // "System"' <<< "$line")
    local uri=$(jq -r '.uri // .action // "-"' <<< "$line")
    local reason=$(jq -r '.reason // "Firewall"' <<< "$line")
    local ts=$(jq -r '.ts' <<< "$line")
    [[ "$reason" =~ Timeout|UNBLOCKED ]] && continue
    if [[ -n "$filter_domain" ]]; then
      [[ "$domain" != "System" && "$domain" != "$filter_domain" ]] && continue
    fi
    local ts_fmt=$(date -d "@$ts" "+%m/%d %H:%M" 2>/dev/null || echo "$ts")
    local uri_short="${uri:0:13}"
    local reason_short="${reason:0:13}"
    draw_row "$ts_fmt" "$ip" "$domain" "$uri_short" "$reason_short"
  done < "$history"
  printf "${blue}└───────────────┴──────────────────────┴───────────────┴───────────────┴───────────────┘${reset}\n"
}
######################################## REMOTE BACKUP & RESTORE ##################################
remote_backup() {
  local domain="$1"
  local type="$2"
  local latest timestamp
  info "Creating a validated local backup before remote replication."
  resolve_profile "$domain" || return 1
  [[ "$remote_enabled" == "true" ]] || {
    error "The selected profile is not remote-enabled."
    return 1
  }
  case "$type" in
    wordpress)
      wp_backup "$domain" || return 1
      ;;
    static|sites)
      static_backup "$domain" || return 1
      ;;
    *)
      error "Remote profile backup currently supports WordPress and static sites only."
      return 1
      ;;
  esac
  latest="${last_backup_path:-}"
  [[ -n "$latest" && -d "$latest" ]] || {
    error "The local backup did not expose a valid backup path."
    return 1
  }
  timestamp="$(basename "$latest")"
  if [[ "$(awk -v p="[$profile]" '
      $0==p {f=1;next}
      /^\[/ {f=0}
      f && /^LAST_REMOTE_SYNC=/{sub(/^LAST_REMOTE_SYNC=/,"");print;exit}
    ' "$profiles_file")" != "$timestamp" ]]; then
    mirror_backup "$domain" "$latest" "$timestamp" || return 1
  fi
  success "Remote backup completed"
}
remote_backup_scheduler() {
  local domain="${1:-}"
  local backup_type="${2:-}"
  local cron_name safe_domain
  [[ -n "$domain" ]] || {
    error "No domain specified"
    return 1
  }
  if [[ -z "$backup_type" ]]; then
    resolve_type "$domain" || return 1
    case "$type" in
      wordpress) backup_type="wordpress" ;;
      sites) backup_type="static" ;;
      *)
        error "Scheduled remote backup currently supports WordPress and static sites only."
        return 1
        ;;
    esac
  fi
  safe_domain="${domain//[^A-Za-z0-9_.-]/_}"
  cron_name="/etc/cron.d/one-click-remote-backup-${safe_domain}"
  cat > "$cron_name" <<EOF
0 4 * * * root bash /var/cache/one-click/wordpress.sh -remoteback '$domain' '$backup_type'
EOF
  chmod 0644 "$cron_name"
  success "Daily remote backup scheduled for $domain"
}
remote_restore() {
  local domain="$1"
  local type="$2"
  local tmp
  resolve_profile "$domain" || return 1
  remote_list "$domain" "" restore || return 1
  [[ -n "${selected_remote_path:-}" ]] || {
    error "Remote backup path was not selected."
    return 1
  }
  tmp="$(mktemp -d "/tmp/oneclick-${domain}.XXXXXX")"
  if ! run_rsync \
    "${profile_user}@${profile_host}:${selected_remote_path}/" \
    "$tmp/"; then
    rm -rf "$tmp"
    return 1
  fi
  case "$type" in
    wordpress)
      wp_restore "$domain" "$tmp"
      ;;
    static|sites)
      static_restore "$domain" "$tmp"
      ;;
    *)
      rm -rf "$tmp"
      error "Remote restore currently supports WordPress and static sites only."
      return 1
      ;;
  esac
  local rc=$?
  rm -rf "$tmp"
  return "$rc"
}
remote_list() {
  local domain="$1"
  local mode="${3:-}"
  local -a timestamps servers paths
  local b ts server path i choice
  resolve_profile "$domain" || return 1
  [[ "$remote_enabled" == "true" ]] || {
    error "The selected profile is not remote-enabled."
    return 1
  }
  check_auth || return 1
  mapfile -t backups < <(
    run_ssh "
      for d in \"$profile_base\"/*/\"$domain\"/* \"$profile_base\"/\"$domain\"/*; do
        [ -d \"\$d\" ] || continue
        ts=\$(basename \"\$d\")
        parent=\$(dirname \"\$d\")
        if [ \"\$parent\" = \"$profile_base/$domain\" ]; then
          server=legacy
        else
          server=\$(basename \"\$(dirname \"\$parent\")\")
        fi
        printf '%s|%s|%s\n' \"\$ts\" \"\$server\" \"\$d\"
      done
    " | sort -r -t'|' -k1,1
  ) || return 1
  [[ ${#backups[@]} -gt 0 ]] || {
    error "No remote backups found for $domain."
    return 1
  }
  echo -e "\e[34m╔════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Timestamp            ║ Server               ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╬══════════════════════╣\e[0m"
  i=1
  for b in "${backups[@]}"; do
    IFS='|' read -r ts server path <<< "$b"
    timestamps+=("$ts")
    servers+=("$server")
    paths+=("$path")
    printf "\e[34m║ %-2s ║ %-20s ║ %-20s ║\e[0m\n" "$i" "$ts" "$server"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╩══════════════════════╝\e[0m"
  if [[ "$mode" == "restore" ]]; then
    while true; do
      read -rp "${cyan}[USER]${blue} Select backup ID to restore: ${reset}" choice
      if [[ "$choice" =~ ^[0-9]+$ ]] &&
         (( choice >= 1 && choice <= ${#timestamps[@]} )); then
        ts="${timestamps[$((choice-1))]}"
        selected_remote_server="${servers[$((choice-1))]}"
        selected_remote_path="${paths[$((choice-1))]}"
        export ts selected_remote_server selected_remote_path
        return 0
      fi
      error "Invalid choice, try again."
    done
  fi
}
local_list() {
  local domain type base ts mode choice
  domain="$1"
  mode="${2:-}"
  if [[ "$mode" == "wordpress" ]]; then
    base="/etc/one-click/wordpress/backups/$domain"
  else
    base="/etc/one-click/sites/backups/$domain"
  fi
  [[ ! -d "$base" ]] && { error "No local backups found for $domain"; return 1; }
  echo -e "\e[34m╔════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Timestamp            ║ Type                 ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╬══════════════════════╣\e[0m"
  mapfile -t backup_paths < <(ls -dt "$base"/*/ 2>/dev/null)
  [[ ${#backup_paths[@]} -eq 0 ]] && { error "No backups found"; return 1; }
  local i=1
  local ts_list=()
  for b in "${backup_paths[@]}"; do
    ts=$(basename "$b")
    ts_list+=("$ts")
    type=$( [[ -f "$b/db.sql.gz" ]] && echo "wordpress" || echo "static" )
    printf "\e[34m║ %-2s ║ %-20s ║ %-20s ║\e[0m\n" "$i" "$ts" "$type"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╩══════════════════════╝\e[0m"
  while true; do
    echo -e "${cyan}[INFO]${reset} Enter ID to ${red}Delete${reset}, or ${yellow}q${reset} to Exit"
    read -rp "${cyan}[USER]${blue} Choice: ${reset}" choice
    case "$choice" in
      q|Q|exit) return 0 ;;
      [0-9]*)
        local del_idx="${choice#d}"
        if (( del_idx >= 1 && del_idx <= ${#ts_list[@]} )); then
          local target_ts="${ts_list[$((del_idx-1))]}"
          read -rp "${cyan}[USER]${reset} ${red}Are you sure you want to delete backup $target_ts? (y/n): ${reset}" confirm
          if [[ "$confirm" == "y" ]]; then
            rm -rf "$base/$target_ts"
            success "Backup $target_ts deleted."
            return 0
          fi
        else
          error "Invalid ID for deletion."
        fi
        ;;
      [0-9]*)
        if (( choice >= 1 && choice <= ${#ts_list[@]} )); then
          ts="${ts_list[$((choice-1))]}"
          selected_backup_ts="$ts"
          return 0
        else
          error "Invalid ID for restore."
        fi
        ;;
      *) error "Invalid input." ;;
    esac
  done
}
profile_switch() {
  local profiles choice selected
  mapfile -t profiles < <(awk '/^\[.*\]/{gsub(/\[|\]/,""); print $0}' "$profiles_file")
  if [[ ${#profiles[@]} -eq 0 ]]; then
    error "No profiles available. Create one first."
    return
  fi
  echo -e "\e[34m╔════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Profile Name         ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╣\e[0m"
  local i=1
  for p in "${profiles[@]}"; do
    printf "\e[34m║ %-2s ║ %-20s ║\e[0m\n" "$i" "$p"
    ((i++))
  done
  printf "\e[34m║ %-2s ║ %-20s ║\e[0m\n" "0" "Go Back"
  echo -e "\e[34m╚════╩══════════════════════╝\e[0m"
  while true; do
    read -rp "${cyan}[USER]${blue} Select profile ID for $domain: " choice
    if [[ "$choice" -eq 0 ]]; then
      return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
      selected="${profiles[$((choice-1))]}"
      echo "$selected" > "$current_profile_file"
      break
    else
      error "Invalid selection, try again."
    fi
  done
  grep -v "^$domain=" "$map_file" > /tmp/map.tmp || true
  echo "$domain=$selected" >> /tmp/map.tmp
  mv /tmp/map.tmp "$map_file"
  success "$domain now uses profile '$selected'"
}
get_current_profile() {
  type="${wpstatic:-}"
  domain="$1"
  resolve_type "$domain"
  last_backup=$((ls -1 /etc/one-click/${type}/backups/${domain:-}/ 2> /dev/null | head -1) || true)
  lb_ts=$(echo "$last_backup" | sed -E 's/(.{4})(..)(..).(..)(..).*/\3-\2-\1 \4:\5/')
  disk_usage=$(awk '{print $1}' <(du -s -h /etc/one-click/${type}/${domain:-}/ 2> /dev/null))
  monitor_info=$(get_monitor_stats "$domain")
  if [[ -z "${domain:-}" ]]; then
    lb_ts="Not Loaded"
    disk_usage="Not Loaded"
  fi
  if [[ -f "$current_profile_file" ]]; then
    printf "${yellow}[${red}[${magenta}Current Profile: ${blue}$(cat ${current_profile_file:-Not Loaded})${red}]${yellow}]${reset}\n"
    echo -e "${blue}┌──────────────────┬───────────────────────────────────────┐"
    printf "${blue}│${yellow}  %-15s${blue} │${yellow} %-47s ${blue}│${reset}\n" "Uptime" "$monitor_info"
    printf "${blue}├──────────────────┼───────────────────────────────────────┤\n"
    printf "${blue}│${magenta}  %-15s ${blue}│${green} %-37s ${blue}│${reset}\n" \
      "Domain" "${domain:-N/A}" \
      "Last Backup" "${lb_ts:-Not Taken}" \
      "Disk Usage" "$disk_usage"
    echo -e "${blue}└──────────────────┴───────────────────────────────────────┘${reset}"
  fi
}
####################### PROFILES MANAGEMENT ################################
# ==== Delete Profile ====
profile_delete() {
  local profiles choice selected tmpfile current_profile
  mapfile -t profiles < <(
    awk '/^\[.*\]/{
      gsub(/\[|\]/,"")
      print
    }' "$profiles_file"
  )
  if [[ ${#profiles[@]} -eq 0 ]]; then
    error "No profiles available to delete"
    return 1
  fi
  echo -e "\e[34m╔════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Profile Name         ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╣\e[0m"
  local i=1
  for p in "${profiles[@]}"; do
    printf "\e[34m║ %-2s ║ %-20s ║\e[0m\n" "$i" "$p"
    ((i++))
  done
  printf "\e[34m║ %-2s ║ %-20s ║\e[0m\n" "0" "Exit"
  echo -e "\e[34m╚════╩══════════════════════╝\e[0m"
  while true; do
    read -rp "${cyan}[USER]${blue} Select profile ID to delete: ${reset}" choice
    [[ "$choice" == "0" ]] && return 0
    if [[ "$choice" =~ ^[0-9]+$ ]] &&
       (( choice >= 1 && choice <= ${#profiles[@]} )); then
      selected="${profiles[$((choice-1))]}"
      break
    fi
    error "Invalid selection"
  done
  validate_profile_integrity "$selected"
  # ==== Protect defaults ====
  if [[ "$selected" == "local-default" ]]; then
    error "Cannot delete protected profile"
    return 1
  fi
  # ==== Prevent deletion if assigned ====
  if grep -qE "^[^=]+=${selected}$" "$map_file" 2>/dev/null; then
    error "Profile '$selected' is still assigned to one or more domains"
    return 1
  fi
  read -rp "${cyan}[USER]${red} Delete profile '$selected'? (y|n): ${reset}" confirm
  [[ "$confirm" != "y" ]] && {
    info "Cancelled"
    return 0
  }
  tmpfile=$(mktemp)
  awk -v p="[$selected]" '
    $0==p {f=1; next}
    /^\[/ {f=0}
    !f
  ' "$profiles_file" > "$tmpfile"
  mv "$tmpfile" "$profiles_file"
  # ==== Clear stale active profile ====
  if [[ -f "$current_profile_file" ]]; then
    current_profile=$(<"$current_profile_file")
    if [[ "$current_profile" == "$selected" ]]; then
      echo "local-default" > "$current_profile_file"
    fi
  fi
  success "Profile '$selected' deleted"
}
# ==== Test Profile Connection ====
remote_profile_test() {
  local profile ret
  [[ -f "$current_profile_file" ]] || {
    error "No active profile"
    return 1
  }
  profile=$(<"$current_profile_file")
  load_profile "$profile" || return 1
  if [[ "$remote_enabled" != "true" ]]; then
    info "Local profile does not require connection testing"
    return 0
  fi
  if [[ -n "$profile_pass" ]]; then
    sshpass -p "$profile_pass" \
      ssh \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      "$profile_user@$profile_host" \
      "echo OK" >/dev/null 2>&1 || ret=$?
  else
    ssh \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      "$profile_user@$profile_host" \
      "echo OK" >/dev/null 2>&1 || ret=$?
  fi
  ret=${ret:-0}
  if [[ $ret -eq 0 ]]; then
    success "Connection OK"
  else
    error "Connection failed"
  fi
}
profile_add() {
  local profile type host user base_path sshpass e_pass remote_enabled
  read -rp "${cyan}[USER]${blue} Profile name: ${reset}" profile
  [[ -z "$profile" ]] && {
    error "Invalid profile name"
    return 1
  }
  if grep -q "^\[$profile\]" "$profiles_file" 2>/dev/null; then
    error "Profile already exists"
    return 1
  fi
  while true; do
    read -rp "${cyan}[USER]${blue} Profile type (local|remote): ${reset}" type
    if [[ "$type" != "local" && "$type" != "remote" ]]; then
      error "Invalid backup type!"
      info "Please enter a valid type."
    else
      break
    fi
  done
  case "$type" in
    remote)
      remote_enabled=true
      read -rp "${cyan}[USER]${blue} Remote host IP: ${reset}" host
      read -rp "${cyan}[USER]${blue} Remote username [root]: ${reset}" user
      user="${user:-root}"
      read -rp "${cyan}[USER]${blue} Remote base path [/backups]: ${reset}" base_path
      base_path="${base_path:-/backups}"
      read -rsp "${cyan}[USER]${blue} Password (leave empty for SSH key): ${reset}" sshpass
      echo
      [[ -n "$sshpass" ]] && \
        e_pass=$(encrypt_password "$sshpass") || \
        e_pass=""
      ;;
    local)
      remote_enabled=false
      read -rp "${cyan}[USER]${blue} Local backup path [/backups]: ${reset}" base_path
      base_path="${base_path:-/backups}"
      ;;
    *)
      error "Invalid profile type"
      return
      ;;
  esac
  cat >> "$profiles_file" <<EOF
[$profile]
TYPE=$type
REMOTE_ENABLED=$remote_enabled
HOST=${host:-}
USER=${user:-}
BASE_PATH=$base_path
E_PASSWD=${e_pass:-}
LAST_BACKUP=
LAST_REMOTE_SYNC=
LAST_SYNC_STATUS=

EOF
  success "Profile '$profile' successfully created"
}
profile_list() {
  echo -e "\e[34m╔══════════════════════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ Name                 ║ Host                 ║ Base Path            ║\e[0m"
  echo -e "\e[34m╠══════════════════════╬══════════════════════╬══════════════════════╣\e[0m"
  awk '
    /^\[/ {name=substr($0,2,length($0)-2)}
    /^HOST=/ {host=substr($0,6)}
    /^BASE_PATH=/ {
      base=substr($0,11)
      printf "%-22s %-22s %-22s\n", name, host, base
    }
  ' "$profiles_file" | while read -r profile_name profile_host2 profile_base_path; do
    printf "\e[34m║ %-20s ║ %-20s ║ %-20s ║\e[0m\n" "$profile_name" "$profile_host2" "$profile_base_path"
  done
  echo -e "\e[34m╚══════════════════════╩══════════════════════╩══════════════════════╝\e[0m"
  read -rp "${cyan}[USER]${reset} Press Enter to continue"
}
profile_assign() {
  local domain
  domain="${1:-}"
  if [[ -z "$domain" ]]; then
    read -rp "${cyan}[USER]${blue} Please enter domain: " domain
  fi
  read -rp "${cyan}[USER]${blue} Please create a profile name: " profile
  echo "$domain=$profile" > /tmp/map.tmp
  echo "$profile" > "$current_profile_file"
  grep -v "^$domain=" "$map_file" 2>/dev/null >> /tmp/map.tmp || true
  mv -f /tmp/map.tmp "$map_file"
  profile_add
  success "$profile has been created" "$domain → $profile"
  return 0
}
load_profile() {
  local profile="$1"
  local profile_pass_enc=""
  profile_type=""
  profile_host=""
  profile_user=""
  profile_base=""
  profile_pass=""
  remote_enabled=false
  validate_profile_integrity "$profile" || return 1
  while IFS='=' read -r key value; do
    case "$key" in
      TYPE) profile_type="$value" ;;
      REMOTE_ENABLED) remote_enabled="$value" ;;
      HOST) profile_host="$value" ;;
      USER) profile_user="$value" ;;
      BASE_PATH) profile_base="$value" ;;
      E_PASSWD) profile_pass_enc="$value" ;;
    esac
  done < <(
    awk -v p="[$profile]" '
      $0==p {f=1; next}
      /^\[/ {f=0}
      f
    ' "$profiles_file"
  )
  [[ -n "$profile_type" ]] || {
    error "Profile not found"
    return 0
  }
  if [[ "$profile_type" == "local" && -z "$profile_base" ]]; then
    profile_base="/backups"
  fi
  if [[ -n "$profile_pass_enc" ]]; then
    profile_pass="$(decrypt_password "$profile_pass_enc")" || {
      error "Failed to decrypt password for profile '$profile'."
      return 1
    }
  fi
  export profile_type remote_enabled profile_host profile_user profile_base profile_pass
}
mirror_backup() {
  local domain="$1"
  local backup_path="$2"
  local timestamp="$3"
  [[ "$remote_enabled" != "true" ]] && return 0
  info "Replicating backup to remote profile."
  run_ssh "mkdir -p '$profile_base/$domain/$timestamp'"
  run_rsync \
    "$backup_path/" \
    "${profile_user}@${profile_host}:${profile_base}/${domain}/${timestamp}/"

  update_profile_field "$profile" "LAST_REMOTE_SYNC" "$timestamp"
  update_profile_field "$profile" "LAST_SYNC_STATUS" "success"
}
update_profile_field() {
  local profile="$1"
  local field="$2"
  local value="$3"
  awk -v p="[$profile]" \
      -v f="$field" \
      -v v="$value" '
    $0==p {in_section=1}
    /^\[/ && $0!=p {in_section=0}
    in_section && $0 ~ "^"f"=" {
      print f"="v
      updated=1
      next
    }
    {print}
    END {
      if (in_section && !updated)
        print f"="v
    }
  ' "$profiles_file" > /tmp/profiles.tmp
  mv /tmp/profiles.tmp "$profiles_file"
}
resolve_profile() {
  local domain="$1"
  profile=$((grep "^$domain=" "$map_file" 2>/dev/null | cut -d'=' -f2) || true)
  if [[ -z "$profile" ]]; then
    warn "No profile assigned to $domain. Using default"
    info "Please assign a profile to $domain"
    profile="local-default"
  fi
  load_profile "$profile" || return 1
  export profile
}
assign_profile_to_domain() {
  local domain="$1"
  echo "Available profiles:"
  profile_list
  read -rp "${cyan}[USER]${blue} Select profile: " profile
  grep -v "^$domain=" "$map_file" 2>/dev/null > /tmp/map.tmp || true
  echo "$domain=$profile" >> /tmp/map.tmp
  mv -f /tmp/map.tmp "$map_file"
  success "$domain → $profile"
}
ensure_local_profile() {
  if ! grep -q "^\[local-default\]" "$profiles_file" 2>/dev/null; then
    cat >> "$profiles_file" <<EOF
[local-default]
TYPE=local
REMOTE_ENABLED=false
LAST_BACKUP=
LAST_REMOTE_SYNC=
LAST_SYNC_STATUS=
BACKUP_SIZE=

EOF
  fi
}
check_auth() {
  local known_hosts="/etc/one-click/known_hosts"
  local -a opts
  use_sshpass=0
  [[ "$remote_enabled" == "true" ]] || return 0
  [[ -n "$profile_host" && -n "$profile_user" ]] || {
    error "Profile transport metadata incomplete."
    return 1
  }
  touch "$known_hosts"
  chmod 600 "$known_hosts"
  opts=(
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$known_hosts"
    -o ConnectTimeout=5
  )
  if ssh -o BatchMode=yes "${opts[@]}" "${profile_user}@${profile_host}" "exit" >/dev/null 2>&1; then
    use_sshpass=0
    export use_sshpass
    return 0
  fi
  if [[ -n "$profile_pass" ]]; then
    command -v sshpass >/dev/null 2>&1 || {
      error "Password authentication is configured but sshpass is unavailable."
      return 1
    }
    if SSHPASS="$profile_pass" sshpass -e ssh \
      -o PubkeyAuthentication=no \
      "${opts[@]}" \
      "${profile_user}@${profile_host}" "exit" >/dev/null 2>&1; then
      use_sshpass=1
      export use_sshpass
      return 0
    fi
  fi
  error "Unable to authenticate to ${profile_user}@${profile_host}."
  return 1
}
run_ssh() {
  local command="$1"
  local known_hosts="/etc/one-click/known_hosts"
  local -a opts
  [[ "$remote_enabled" == "true" ]] || {
    error "Profile is not remote-enabled."
    return 1
  }
  check_auth || return 1
  opts=(
    -o StrictHostKeyChecking=accept-new
    -o UserKnownHostsFile="$known_hosts"
    -o ConnectTimeout=10
  )
  if [[ "$use_sshpass" == "1" ]]; then
    SSHPASS="$profile_pass" sshpass -e ssh "${opts[@]}" \
      "${profile_user}@${profile_host}" "$command"
  else
    ssh -o BatchMode=yes "${opts[@]}" \
      "${profile_user}@${profile_host}" "$command"
  fi
}
run_rsync() {
  local known_hosts="/etc/one-click/known_hosts"
  local ssh_cmd
  [[ "$remote_enabled" == "true" ]] || {
    error "Profile is not remote-enabled."
    return 1
  }
  check_auth || return 1
  ssh_cmd="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$known_hosts -o ConnectTimeout=10"
  if [[ "$use_sshpass" == "1" ]]; then
    SSHPASS="$profile_pass" sshpass -e rsync \
      -az --progress \
      -e "$ssh_cmd" \
      "$@"
  else
    rsync \
      -az --progress \
      -e "$ssh_cmd -o BatchMode=yes" \
      "$@"
  fi
}
###################################### DNS ###################################
dns_verify_dependencies() {
  local dependencies=(curl jq openssl dig)
  local missing=()
  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then missing+=("$cmd"); fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required system utilities: ${missing[*]}"
    return 1
  fi
  return 0
}
dns_generate_master_key() {
  [[ -f "$dns_master_key" ]] && return 0
  openssl rand -base64 64 > "$dns_master_key"
  chmod 600 "$dns_master_key"
}
dns_encrypt() { openssl enc -aes-256-cbc -pbkdf2 -a -salt -pass file:"$dns_master_key" <<< "$1"; }
dns_decrypt() { openssl enc -aes-256-cbc -pbkdf2 -a -d -salt -pass file:"$dns_master_key" <<< "$1"; }
dns_provider_path()   { echo "${dns_provider_root}/$1"; }
dns_provider_config() { echo "$(dns_provider_path "$1")/config.conf"; }
dns_domain_path()     { echo "${dns_domain_root}/$1"; }
dns_domain_meta()     { echo "$(dns_domain_path "$1")/meta.conf"; }
dns_provider_supported() {
  cat <<EOF
cloudflare
digitalocean
vultr
route53
linode
hetzner
gcore
bunny
namecheap
bind
powerdns
EOF
}
dns_provider_api_base() {
  case "$1" in
    cloudflare)   echo "https://api.cloudflare.com/client/v4"      ;;
    digitalocean) echo "https://api.digitalocean.com/v2"           ;;
    vultr)        echo "https://api.vultr.com/v2"                  ;;
    route53)      echo "https://route53.amazonaws.com/2013-04-01"  ;;
    linode)       echo "https://api.linode.com/v4"                 ;;
    hetzner)      echo "https://dns.hetzner.com/api/v1"            ;;
    gcore)        echo "https://api.gcore.com/dns/v2"              ;;
    bunny)        echo "https://api.bunny.net"                     ;;
    namecheap)    echo "https://api.namecheap.com/xml.response"    ;;
    bind|powerdns|pdns|local) echo "local"                         ;;
    *)            echo "https://api.${1}.com"                      ;;
  esac
}
dns_provider_verify_live() {
  local provider="$1"
  dns_provider_load "$provider" || return 1
  local api auth endpoint
  api="$(dns_provider_api_base "$provider")"
  auth="$(dns_provider_auth_header "$provider")"
  [[ "$api" == "local" ]] && return 0
  case "$provider" in
    cloudflare)   endpoint="/user/tokens/verify"       ;;
    digitalocean) endpoint="/account"                  ;;
    vultr)        endpoint="/account"                  ;;
    linode)       endpoint="/profile"                  ;;
    hetzner)      endpoint="/zones?page=1&per_page=1"  ;;
    *)
      warn "Dynamic or custom API endpoint provider format. Skipping active ping verification pass."
      return 0
      ;;
  esac
  local http_status
  http_status=$(curl -s -o /dev/null --connect-timeout 5 -w "%{http_code}" -X GET "${api}${endpoint}" -H "$auth")
  if [[ "$http_status" == "200" || "$http_status" == "201" ]]; then
    return 0
  else
    error "Authentication validation failed (HTTP Status: $http_status)."
    return 1
  fi
}
dns_provider_add() {
  local provider="${1:-}"
  if [[ -z "$provider" ]]; then
    info "Supported Providers:"
    dns_provider_supported | sed 's/^/  - /'
    echo
    read -rp "${cyan}[USER]${blue} Select DNS Provider: ${reset}" provider
  fi
  provider="${provider,,}"
  dns_generate_master_key
  mkdir -p "$(dns_provider_path "$provider")"
  while true; do
    case "$provider" in
      bind|powerdns|pdns)
          cat > "$(dns_provider_config "$provider")" <<EOF
PROVIDER=${provider}
TYPE=local
EOF
          break
          ;;
      route53)
          read -rp "${cyan}[USER]${blue} AWS Access Key: ${reset}" access
          read -rsp "${cyan}[USER]${reset} AWS Secret Key: " secret; echo
          local enc_access enc_secret
          enc_access="$(dns_encrypt "$access")"
          enc_secret="$(dns_encrypt "$secret")"
          cat > "$(dns_provider_config "$provider")" <<EOF
PROVIDER=route53
ACCESS_KEY=${enc_access}
SECRET_KEY=${enc_secret}
EOF
          ;;
      namecheap)
          read -rp "${cyan}[USER]${blue} API User: ${reset}" api_user
          read -rsp "${cyan}[USER]${reset} API Key: " api_key; echo
          local enc_user enc_key
          enc_user="$(dns_encrypt "$api_user")"
          enc_key="$(dns_encrypt "$api_key")"
          cat > "$(dns_provider_config "$provider")" <<EOF
PROVIDER=namecheap
API_USER=${enc_user}
API_KEY=${enc_key}
EOF
          ;;
      *)
          read -rsp "Enter Access/API Token for custom provider [${provider}]: " token; echo
          if [[ -z "${token}" ]]; then
            error "Token cannot be empty. Re-evaluating routing inputs."
            continue
          fi
          local encrypted
          encrypted="$(dns_encrypt "$token")"
          cat > "$(dns_provider_config "$provider")" <<EOF
PROVIDER=${provider}
TOKEN=${encrypted}
EOF
          ;;
    esac
    chmod 600 "$(dns_provider_config "$provider")"
    info "Validating configuration lane metadata permissions."
    if dns_provider_verify_live "$provider"; then
      success "Provider '$provider' successfully stored and locked down."
      break
    else
      rm -f "$(dns_provider_config "$provider")"
      error "Handshake verification faulted. State dropped. Try again."
    fi
  done
}
dns_provider_load() {
  local provider="$1" config
  config="$(dns_provider_config "$provider")"
  if [[ ! -f "$config" ]]; then return 1; fi
  source "$config"
  if [[ -n "${TOKEN:-}" ]]; then
    DNS_TOKEN="$(dns_decrypt "$TOKEN")"
  elif [[ -n "${ACCESS_KEY:-}" ]]; then
    DNS_ACCESS_KEY="$(dns_decrypt "$ACCESS_KEY")"
    DNS_SECRET_KEY="$(dns_decrypt "$SECRET_KEY")"
  elif [[ -n "${API_USER:-}" ]]; then
    DNS_API_USER="$(dns_decrypt "$API_USER")"
    DNS_API_KEY="$(dns_decrypt "$API_KEY")"
  fi
}
dns_provider_auth_header() {
  case "$1" in
    cloudflare|digitalocean|vultr|linode) echo "Authorization: Bearer ${DNS_TOKEN}" ;;
    hetzner)      echo "Auth-API-Token: ${DNS_TOKEN}"       ;;
    gcore)        echo "Authorization: APIKey ${DNS_TOKEN}" ;;
    bunny)        echo "AccessKey: ${DNS_TOKEN}"            ;;
    *)            echo "Authorization: Bearer ${DNS_TOKEN}" ;;
  esac
}
dns_api_request() {
  local provider="$1" method="$2" endpoint="$3" data="${4:-}"
  dns_provider_load "$provider" || return 1
  local api auth
  api="$(dns_provider_api_base "$provider")"
  auth="$(dns_provider_auth_header "$provider")"
  [[ "$api" == "local" ]] && return 0
  if [[ -n "$data" ]]; then
    curl -s -X "$method" "${api}${endpoint}" -H "$auth" -H "Content-Type: application/json" --data "$data"
  else
    curl -s -X "$method" "${api}${endpoint}" -H "$auth"
  fi
}
dns_init() {
  if [[ -f /etc/one-click/fleet/controller.env ]]; then
    . /etc/one-click/fleet/controller.env
    if [[ "$CONTROLLER_IP" != "$sys_ip" ]]; then
      error "$(hostname -s) is a fleet member" \
        "Only the controller can edit and add zones"
        return
    fi
  fi
  local t_interactive=0
  local t_int="${4:-}"
  if [[ "$t_int" != "-y" ]]; then
    while true; do
      read -rp "${cyan}[USER]${reset} Enter Domain: " domain
      if [[ "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
      else
        error "Invalid domain format. Please try again (e.g., example.com)."
      fi
    done
    while true; do
      read -rp "${cyan}[USER]${reset} Enter Target IP: " ip
      if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r r1 r2 r3 r4 <<< "$ip"
        if ((r1 <= 255 && r2 <= 255 && r3 <= 255 && r4 <= 255)); then
          break
        fi
      fi
      error "Invalid IPv4 address. Please try again (e.g., 192.168.1.100)."
    done
    printf "${cyan}${ul}Providers${ul_reset}${lime}\n"
    printf '%s\n' $((dns_provider_supported | tr '\n' ' ') || true)
    while true; do
      read -rp "${cyan}[USER]${reset} Enter Provider: " provider
      if dns_provider_supported | grep -qFx "$provider"; then
        break
      else
        error "Unsupported provider '$provider'."
        warn "Choose from: $(dns_provider_supported | tr '\n' ' ')"
        echo
      fi
    done
  else
    local domain="$1"
    local ip="$2"
    local provider="$3"
  fi
  dns_verify_dependencies || return 1
  if [[ "$provider" == "bind" ]]; then
    dns_ensure_bind_installed || return 1
  fi
  if [[ ! -f "$(dns_provider_config "$provider")" ]]; then
    warn "Provider '$provider' configuration file missing."
    dns_provider_add "$provider" || return 1
  fi
  mkdir -p "$(dns_domain_path "$domain")"
  cat > "$(dns_domain_meta "$domain")" <<EOF
DOMAIN=${domain}
PROVIDER=${provider}
CREATED=$(date +%s)
EOF
  dns_create_zone "$provider" "$domain" || return 1
  dns_add_record_backend "$domain" "A" "@" "$ip"
  dns_add_record_backend "$domain" "CNAME" "www" "$domain"
  success "Initialization complete for $domain via $provider"
}
dns_bind_create_zone() {
  local domain="$1"
  local zone_file
  zone_file="$(dns_bind_zone_file "$domain")"
  mkdir -p "$(dirname "$zone_file")"
  cat > "$zone_file" <<EOF
\$TTL 86400
@   IN  SOA ns1.${domain}. admin.${domain}. (
        $(date +%Y%m%d01) ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@   IN  NS  ns1.${domain}.
@   IN  NS  ns2.${domain}.
EOF
  local conf_file="/etc/bind/named.conf.local"
  if [[ -f "$conf_file" ]] && ! grep -q "zone \"$domain\"" "$conf_file"; then
    cat >> "$conf_file" <<EOF

zone "$domain" {
    type master;
    file "$zone_file";
};
EOF
  fi
  command -v systemctl &>/dev/null && (sudo systemctl reload bind9 || sudo systemctl reload named) &>/dev/null
}
dns_create_zone() {
  local provider="$1"
  local domain="$2"
  case "$provider" in
    bind)         dns_bind_create_zone "$domain"                                                           ;;
    cloudflare)   dns_api_request "$provider" POST "/zones" "{\"name\":\"${domain}\",\"jump_start\":true}" ;;
    digitalocean) dns_api_request "$provider" POST "/domains" "{\"name\":\"${domain}\"}"                   ;;
    vultr)        dns_api_request "$provider" POST "/domains" "{\"domain\":\"${domain}\"}"                 ;;
    *)            error "Zone generation not yet fully integrated for automated $provider setups."         ;;
  esac
}
dns_add_record() {
  local domain="$1"
  printf "${orange}[DNS]${magenta} %s\n${reset}" "Choose Record Type:" \
    "1) A      2) AAAA   3) CNAME" \
    "4) TXT    5) MX     6) SRV"
  read -rp "${cyan}[USER]${blue} Selection #: ${reset}" choice_idx
  local type
  case "$choice_idx" in
    1) type="A"     ;;
    2) type="AAAA"  ;;
    3) type="CNAME" ;;
    4) type="TXT"   ;;
    5) type="MX"    ;;
    6) type="SRV"   ;;
    *) error "Invalid entry choice option."; return 1 ;;
  esac
  local host value prio=0 weight=0 port=0
  if [[ "$type" == "SRV" ]]; then
    read -rp "${cyan}[USER]${blue} Service String (e.g., _sip._tcp): ${reset}" host
    read -rp "${cyan}[USER]${blue} Target Server Host (e.g., sip.foo.com): ${reset}" value
    read -rp "${cyan}[USER]${blue} Priority (e.g., 10): ${reset}" prio
    read -rp "${cyan}[USER]${blue} Weight (e.g., 60): ${reset}" weight
    read -rp "${cyan}[USER]${blue} Port Number (e.g., 5060): ${reset}" port
  elif [[ "$type" == "MX" ]]; then
    read -rp "${cyan}[USER]${blue} Subdomain Host (Use @ for root): ${reset}" host
    read -rp "${cyan}[USER]${blue} Mail Server Domain Target (e.g., mail.foo.com): ${reset}" value
    read -rp "${cyan}[USER]${blue} Priority (e.g., 10, 20): ${reset}" prio
  else
    read -rp "${cyan}[USER]${blue} Record Host Name (e.g., @ or www or v=spf1): ${reset}" host
    read -rp "${cyan}[USER]${blue} Record Destination Target Value: ${reset}" value
  fi
  dns_add_record_backend "$domain" "$type" "$host" "$value" "$prio" "$weight" "$port"
  success "Successfully created entry target for ${type} record."
}
dns_ensure_bind_installed() {
  if command -v named &>/dev/null; then
    return 0
  fi
  printf "${orange}[BIND]${reset} %s\n" "BIND is selected but not installed." \
    "Installing now..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y bind9 dnsutils
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y bind bind-utils
  elif command -v yum &>/dev/null; then
    sudo yum install -y bind bind-utils
  else
    error "No compatible package manager found (apt/dnf/yum). Please install BIND9 manually."
    return 1
  fi
  if ! command -v named &>/dev/null; then
    error "BIND9 installation failed or 'named' binary is not in PATH."
    return 1
  fi
  if command -v systemctl &>/dev/null; then
    info "Starting and enabling BIND service."
    sudo systemctl enable --now bind9 &>/dev/null || sudo systemctl enable --now named &>/dev/null
  fi
  success "BIND installed and initialized successfully."
}
dns_add_record_backend() {
  local domain="$1" type="$2" host="$3" value="$4"
  local prio="${5:-0}" weight="${6:-0}" port="${7:-0}"
  local ttl=3600
  source "$(dns_domain_meta "$domain")"
  case "$PROVIDER" in
    bind|powerdns|pdns|local)
      local zone_file
      zone_file="$(dns_bind_zone_file "$domain")"
      [[ ! -f "$zone_file" ]] && { error "Zone file missing"; return 1; }
      case "$type" in
        A|AAAA|CNAME)
          printf "%-20s IN %-6s %s\n" "$host" "$type" "$value" >> "$zone_file"
          ;;
        TXT)
          printf "%-20s IN %-6s \"%s\"\n" "$host" "$type" "$value" >> "$zone_file"
          ;;
        MX)
          printf "%-20s IN %-6s %d %s.\n" "$host" "$type" "$prio" "$value" >> "$zone_file"
          ;;
        SRV)
          printf "%-20s IN %-6s %d %d %d %s.\n" "$host" "$type" "$prio" "$weight" "$port" "$value" >> "$zone_file"
          ;;
      esac
      command -v systemctl &>/dev/null && sudo systemctl reload bind9 &>/dev/null
      ;;
    cloudflare)
      local zone_id payload
      zone_id="$(dns_cloudflare_get_zone_id "$domain")"
      case "$type" in
        A|AAAA|CNAME|TXT)
          payload="{\"type\":\"${type}\",\"name\":\"${host}\",\"content\":\"${value}\",\"ttl\":${ttl}}"
          ;;
        MX)
          payload="{\"type\":\"MX\",\"name\":\"${host}\",\"content\":\"${value}\",\"priority\":${prio},\"ttl\":${ttl}}"
          ;;
        SRV)
          payload="{
            \"type\": \"SRV\",
            \"name\": \"${host}\",
            \"ttl\": ${ttl},
            \"data\": {
              \"priority\": ${prio},
              \"weight\": ${weight},
              \"port\": ${port},
              \"target\": \"${value}\"
            }
          }"
          ;;
      esac
      dns_api_request "cloudflare" POST "/zones/${zone_id}/dns_records" "$payload"
      ;;
    digitalocean)
      local payload
      case "$type" in
        A|AAAA|CNAME|TXT)
          payload="{\"type\":\"${type}\",\"name\":\"${host}\",\"data\":\"${value}\",\"ttl\":${ttl}}"
          ;;
        MX)
          payload="{\"type\":\"MX\",\"name\":\"${host}\",\"data\":\"${value}\",\"priority\":${prio},\"ttl\":${ttl}}"
          ;;
        SRV)
          payload="{\"type\":\"SRV\",\"name\":\"${host}\",\"data\":\"${value}\",\"priority\":${prio},\"weight\":${weight},\"port\":${port},\"ttl\":${ttl}}"
          ;;
      esac
      dns_api_request "digitalocean" POST "/domains/${domain}/records" "$payload"
      ;;
  esac
}
dns_bind_add_record() {
  local domain="$1" host="$2" type="$3" value="$4"
  local zone_file
  zone_file="$(dns_bind_zone_file "$domain")"
  if [[ ! -f "$zone_file" ]]; then
    error "Local BIND zone file doesn't exist for $domain"
    return 1
  fi
  printf "%-12s IN %-6s %s\n" "$host" "$type" "$value" >> "$zone_file"
}
dns_cloudflare_get_zone_id() {
    dns_api_request cloudflare GET "/zones?name=$1" | jq -r '.result[0].id'
}
dns_list_records() {
  local domain="$1"
  source "$(dns_domain_meta "$domain")"
  case "$PROVIDER" in
    cloudflare)
      local zone_id
      zone_id="$(dns_cloudflare_get_zone_id "$domain")"
      dns_api_request "$PROVIDER" GET "/zones/${zone_id}/dns_records" | jq
      ;;
    digitalocean)
      dns_api_request "$PROVIDER" GET "/domains/${domain}/records" | jq
      ;;
    bind)
      cat "$(dns_bind_zone_file "$domain")"
      ;;
  esac
}
dns_check_authority() {
  local domain="$1"
  source "$(dns_domain_meta "$domain")"
  printf "${orange}[DNS]${orange} %s\n" \
    "================================================="
    "      ${yellow}DNS AUTHORITY STATUS${orange}"
    "=================================================${reset}"
  echo -e "${orange}[DNS]${magenta} Detected Public Nameservers:${reset}"
  dig +short NS "$domain"
  echo
  if [[ "$PROVIDER" == "cloudflare" ]]; then
    local zone_id
    zone_id="$(dns_cloudflare_get_zone_id "$domain")"
    dns_api_request "$PROVIDER" GET "/zones/${zone_id}" | jq '.result.name_servers'
  fi
}
select_fqdn() {
  if [[ -f /etc/one-click/fleet/controller.env ]]; then
    . /etc/one-click/fleet/controller.env
    if [[ "$CONTROLLER_IP" != "$sys_ip" ]]; then
      error "$(hostname -s) is a fleet member" \
        "Only the controller can edit and add zones"
        return
    fi
  fi
  local domain_dir="${DNS_DOMAIN_ROOT:-/etc/one-click/dns/domains}"
  if [[ ! -d "$domain_dir" ]]; then
    error "Domain tracking directory does not exist yet."
    return 1
  fi
  local domains=()
  local dir
  for dir in "$domain_dir"/*; do
    if [[ -d "$dir" ]]; then
      domains+=("$(basename "$dir")")
    fi
  done
  if [[ ${#domains[@]} -eq 0 ]]; then
    dns_init
    return 0
  fi
  while true; do
    echo -e "\n${blue}Available Managed Domains:${reset}"
    echo "-------------------------------------------------"
    local i
    for i in "${!domains[@]}"; do
      printf "  ${magenta}%2d)${reset} %s\n" "$((i + 1))" "${domains[$i]}"
    done
    echo "-------------------------------------------------"
    local choice
    read -rp "${cyan}[USER]${reset} Select a domain number [1-${#domains[@]}] or 0 to create a new zone: " choice
    if [[ "$choice" -eq 0 ]]; then
      dns_init
      return 0
    fi
    if [[ "$choice" =~ ^[1-9][0-9]?+$ ]] && (( choice >= 1 && choice <= ${#domains[@]} )); then
      fqdn="${domains[$((choice - 1))]}"
      success "Target domain context set to: ${fqdn}"
      echo
      break
    else
      error "Invalid numerical selection. Please try again."
    fi
  done
}
dns_delete_zone() {
  local domain="$1"
  local meta_file
  meta_file="$(dns_domain_meta "$domain")"
  if [[ ! -f "$meta_file" ]]; then
    error "No metadata found for domain: $domain"
    return 1
  fi
  source "$meta_file"
  info "Deleting zone '$domain' from provider '$PROVIDER'."
  case "$PROVIDER" in
    cloudflare)
      local zone_id
      zone_id="$(dns_cloudflare_get_zone_id "$domain")"
      if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
        dns_api_request "$PROVIDER" DELETE "/zones/${zone_id}"
      fi
      ;;
    digitalocean)
      dns_api_request "$PROVIDER" DELETE "/domains/${domain}"
      ;;
    vultr)
      dns_api_request "$PROVIDER" DELETE "/domains/${domain}"
      ;;
    bind)
      local zone_file
      zone_file="$(dns_bind_zone_file "$domain")"
      if [[ -f "$zone_file" ]]; then
        rm -f "$zone_file"
        command -v systemctl &>/dev/null && (sudo systemctl reload bind9 || sudo systemctl reload named) &>/dev/null
      fi
      ;;
    *)
      warn "Provider-side automated zone deletion not implemented for '$PROVIDER'."
      ;;
  esac
  rm -rf "$(dns_domain_path "$domain")"
  success "Zone '$domain' and local tracking data removed successfully."
}
dns_delete_record() {
  local domain="$1"
  source "$(dns_domain_meta "$domain")"
  if [[ "$PROVIDER" == "cloudflare" || "$PROVIDER" == "digitalocean" ]]; then
    info "Current DNS Records for $domain:"
    dns_list_records "$domain"
    echo
    read -rp "${cyan}[USER]${blue} Enter Record ID to delete: ${reset}" rec_id
    [[ -z "$rec_id" ]] && { error "Record ID cannot be empty."; return 1; }
    dns_delete_record_backend "$domain" "$rec_id"
  else
    read -rp "${cyan}[USER]${blue} Enter Host/Subdomain to delete (e.g., www or @): ${reset}" host
    read -rp "${cyan}[USER]${blue} Enter Record Type (optional, e.g. A, CNAME, TXT or leave blank): ${reset}" type
    [[ -z "$host" ]] && { error "Host cannot be empty."; return 1; }
    dns_delete_record_backend "$domain" "$host" "$type"
  fi
}
dns_delete_record_backend() {
  local domain="$1" record_id_or_host="$2" type="${3:-}"
  local meta_file
  meta_file="$(dns_domain_meta "$domain")"
  if [[ ! -f "$meta_file" ]]; then
    error "Domain metadata missing for $domain."
    return 1
  fi
  source "$meta_file"
  case "$PROVIDER" in
    cloudflare)
      local zone_id
      zone_id="$(dns_cloudflare_get_zone_id "$domain")"
      dns_api_request "cloudflare" DELETE "/zones/${zone_id}/dns_records/${record_id_or_host}"
      ;;
    digitalocean)
      dns_api_request "digitalocean" DELETE "/domains/${domain}/records/${record_id_or_host}"
      ;;
    bind|powerdns|pdns|local)
      local zone_file
      zone_file="$(dns_bind_zone_file "$domain")"
      [[ ! -f "$zone_file" ]] && { error "Zone storage file missing."; return 1; }
      if [[ -n "$type" ]]; then
        sed -i "/^${record_id_or_host}[[:space:]]\+IN[[:space:]]\+${type}/d" "$zone_file"
      else
        sed -i "/^${record_id_or_host}[[:space:]]/d" "$zone_file"
      fi
      command -v systemctl &>/dev/null && (sudo systemctl reload bind9 || sudo systemctl reload named || sudo systemctl reload pdns) &>/dev/null
      ;;
    *)
      error "Record deletion not supported for provider '$PROVIDER'."
      return 1
      ;;
  esac
  success "Record '${record_id_or_host}' removed from $domain."
}
dns_bind_zone_file() {
  echo "/etc/bind/zones/db.$1"  # Adjust path to match your BIND directory layout
}
dns_menu() {
  if ! command -v select_fqdn &>/dev/null; then
    dns_init
  else
    select_fqdn
  fi
  while true; do
    clear
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                      ${yellow}DNS Management${blue}                        ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Add/Configure DNS Provider${blue}                            ║" \
      "║ ${magenta}2${blue}  ║ ${green}Initialize New Domain Zone${blue}                            ║" \
      "║ ${magenta}3${blue}  ║ ${green}Add Record${blue}                                            ║" \
      "║ ${magenta}4${blue}  ║ ${green}Delete Record${blue}                                         ║" \
      "║ ${magenta}5${blue}  ║ ${green}List Records${blue}                                          ║" \
      "║ ${magenta}6${blue}  ║ ${green}Authority Status${blue}                                      ║" \
      "║ ${magenta}7${blue}  ║ ${green}Delete Zone${blue}                                           ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option [0-7]: " choice
    case "$choice" in
      1) dns_provider_add; read -rp "Press enter..."                                                 ;;
      2) dns_init "${fqdn:-${1:-}}" "${ip:-${2:-}}" "${provider:-${3:-}}"; read -rp "Press enter..." ;;
      3) dns_add_record "$fqdn"; read -rp "Press enter..."                                           ;;
      4) dns_delete_record "$fqdn"; read -rp "Press enter..."                                        ;;
      5) dns_list_records "$fqdn"; read -rp "Press enter..."                                         ;;
      6) select_fqdn; dns_check_authority "$fqdn"; read -rp "Press enter..."                         ;;
      7) dns_delete_zone "$fqdn"; read -rp "Press enter..."                                          ;;
      0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0                                  ;;
    esac
  done
}
################################### NEXTCLOUD ################################
install_nextcloud() {
  start_screen nextcloud
  local version="latest"
  local provision_success=0
  local php_ver="$(nextcloud_select_php_version)"
  local site_php_cli=""
  # ==== Meta Data ====
  while true; do
    local br=0
    read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to use for this installation: " domain
    if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      echo "Invalid domain name"
      br=1
    fi
    if [[ -n "$domain" && "$br" -ne 1 ]]; then
      export domain
      break
    fi
    echo "Domain cannot be empty!"
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide a NextCloud User: " nc_user
    [[ -n "$nc_user" ]] && break
  done
  while true; do
    read -rsp "${cyan}[USER]${reset} Please provide a password for $nc_user: " nc_pass
    echo
    if [[ ${#nc_pass} -lt 12 ]]; then
      echo "Password too short! Must be at least 12 characters."
      continue
    fi
    if ! [[ "$nc_pass" =~ [A-Z] ]]; then
      echo "Password must contain at least one uppercase letter."
      continue
    fi
    if ! [[ "$nc_pass" =~ [a-z] ]]; then
      echo "Password must contain at least one lowercase letter."
      continue
    fi
    if ! [[ "$nc_pass" =~ [0-9] ]]; then
      echo "Password must contain at least one number."
      continue
    fi
    read -rsp "${cyan}[USER]${blue} Confirm Password: " pass_confirm
    echo
    if [[ "$nc_pass" != "$pass_confirm" ]]; then
      echo "Passwords do not match. Try again."
      continue
    fi
    break
  done
  pass_confirm=
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Database User: " nc_db_user
    [[ -n "$nc_db_user" ]] && break
  done
  while true; do
    read -rsp "${cyan}[USER]${reset} Please provide the Database Password: " nc_db_pass
    echo
    if [[ ${#nc_db_pass} -lt 12 ]]; then
      echo "Password too short! Must be at least 12 characters."
      continue
    fi
    if ! [[ "$nc_db_pass" =~ [A-Z] ]]; then
      echo "Password must contain at least one uppercase letter."
      continue
    fi
    if ! [[ "$nc_db_pass" =~ [a-z] ]]; then
      echo "Password must contain at least one lowercase letter."
      continue
    fi
    if ! [[ "$nc_db_pass" =~ [0-9] ]]; then
      echo "Password must contain at least one number."
      continue
    fi
    read -rsp "${cyan}[USER]${blue} Confirm Password: " pass_confirm
    echo
    if [[ "$nc_db_pass" != "$pass_confirm" ]]; then
      echo "Passwords do not match. Try again."
      continue
    fi
    break
  done
  read -rp "${cyan}[USER]${blue} Enable HSTS: ${reset}" enable_hsts
  if [[ "${enable_hsts,,}" =~ ^(y|yes)$ ]]; then
    enable_hsts="yes"
  fi
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  nc_root="/etc/one-click/nextcloud/$domain"
  nc_webroot="$nc_root/www"
  nc_data="$nc_root/data"
  nc_logs="/var/log/one-click/${domain}/nextcloud/nextcloud.log"
  nc_logs_dir=$(dirname "$nc_logs")
  mkdir -p \
    "$nc_webroot" \
    "$nc_data" \
    "$nc_root/backups" \
    "$nc_root/config" \
    "$nc_logs_dir"
  chmod 750 "$nc_root"
  touch "$nc_logs"
  warn "Creating web owner"
  web_user="${nc_user:4}_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  id "$web_user" &>/dev/null || useradd -r -m -s /usr/sbin/nologin "$web_user"
  echo
  # ==== REDIS / VALKEY? ====
  while true; do
    read -rp "${cyan}[USER]${reset} Enable Redis/Valkey cache (y|n): " enable_redis
    if [[ "$enable_redis" =~ ^([Yy](es)?|[Nn](o)?)$ ]]; then
      break
    fi
    warn "Please enter y or n"
  done
  printf '%s\n' "Which webserver would you like to configure?" \
    "[1] Nginx" \
    "[2] Apache"
  while true; do
    read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver
    [[ -n "$webserver" ]] && break
  done
  case "$webserver" in
    1)
      webserver="nginx"
      if command -v apt &> /dev/null; then
        webserver_user="www-data"
      else
        webserver_user="nginx"
      fi
      ;;
    2)
      webserver="apache"
      if command -v apt &> /dev/null; then
        webserver_user="www-data"
      else
        webserver_user="apache"
      fi
      ;;
    *)
      echo "Invalid selection"
      ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1 ;;
  esac
  echo "SITE_USER=$web_user" >> "$nc_root/meta.conf"
  echo "SITE_DIR=$nc_webroot" >> "$nc_root/meta.conf"
  echo "SITE_GROUP=$webserver_user" >> "$nc_root/meta.conf"
  echo "WEBSERVER=$webserver" >> "$nc_root/meta.conf"
  echo "NC_USER=$nc_user" >> "$nc_root/meta.conf"
  echo "DB_ENABLED=true" >> "$nc_root/meta.conf"
  echo "DB_USER=$nc_db_user" >> "$nc_root/meta.conf"
  # ==== Selection Summary Confirmation ====
  [[ "$enable_redis" =~ ^[Nn] ]] && redis=No || redis=Yes
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────┐" \
    "│                        ${yellow}CONFIRMATION DETAILS${blue}          │" \
    "├──────────────────────────────────────────────────────┤"
  printf "${blue}│ %-19s : %-40s │\n" \
    "Domain Name" "${yellow}${domain}${blue}" \
    "Site User" "${yellow}${nc_user}${blue}" \
    "SSL Email" "${yellow}${email}${blue}" \
    "Database User" "${yellow}${nc_db_user}${blue}" \
    "Database Password" "${yellow}$(sed -E ':a;s/([[:alnum:]]([[:alnum:]*]+)?)[][:alnum:]!"%£+=_&^@$.-[]/\1*/;ta' <<< "$nc_db_pass")${blue}" \
    "Use Redis" "${yellow}${redis}${blue}" \
    "Webserver" "${yellow}${webserver}${blue}"
  printf '%s\n' "└──────────────────────────────────────────────────────┘${reset}"
  while true; do
    read -rp "${cyan}[USER]${reset} Are these details correct? (y|n): " proceed
    [[ -n "$proceed" ]] && break
  done
  proceed="${proceed,,}"
  echo
  if [[ "$proceed" == "n" || "$proceed" == "no" ]]; then
    warn "Deployment cancelled"
    exit 1
  fi
  trap "cleanup_failed_provision  $provision_success nextcloud" EXIT INT TERM ERR
  info "Installing $webserver"
  install_webserver nextcloud "$domain" "$nc_webroot" "$enable_hsts" || return 1
  info "Installing Nextcloud"
  curl -fL --retry 3 -O https://download.nextcloud.com/server/releases/latest.tar.bz2 || return 1
  curl -fL --retry 3 -O https://download.nextcloud.com/server/releases/latest.tar.bz2.sha256 || return 1
  grep 'latest.tar.bz2$' latest.tar.bz2.sha256 | sha256sum -c - || {
    error "Nextcloud checksum failed"
    return 1
  }
  if ! grep -q '^# One-Click Routing$' /etc/hosts 2>/dev/null; then
    echo "# One-Click Routing" >> /etc/hosts
  fi
  if ! grep -Fq $'127.0.0.1\t'"$domain" /etc/hosts 2>/dev/null; then
    sed -i.one-click_bak "/^# One-Click Routing$/a 127.0.0.1\t${domain}\t# One-Click Entry" /etc/hosts
  fi
  echo -e "HOSTS_ENTRY=\"127.0.0.1\t${domain}\"" >> "$nc_root/meta.conf"
  tar -xjf latest.tar.bz2 || return 1
  rsync -a nextcloud/ "$nc_webroot/" || return 1
  chmod o+x /etc/one-click
  chmod o+x /etc/one-click/nextcloud
  chmod o+x /etc/one-click/nextcloud/$domain
  chown -R "$web_user:$webserver_user" "$nc_root"
  rm -f latest*
  rm -rf nextcloud/
  info "Configuring PHP-FPM"
  create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "nextcloud" || return 1
  site_php_cli="$(site_php_cli_bin "$domain")" || return 1
  PHP_EXEC="sudo -u $web_user $site_php_cli -c /etc/one-click/php/${domain}/php.ini -d memory_limit=1024M"
  info "Installing missing Nextcloud PHP extensions into the isolated PHP $php_ver runtime"
  site_php_install_nextcloud_extensions "$domain" || return 1
  info "Tuning isolated OPcache parameters for $domain"
  local site_php_ini="/etc/one-click/php/${domain}/php.ini"
  if [[ -f "$site_php_ini" ]]; then
    if grep -q "opcache.interned_strings_buffer" "$site_php_ini"; then
      sed -i 's/;*opcache.interned_strings_buffer.*/opcache.interned_strings_buffer=16/' "$site_php_ini"
    else
      echo "opcache.interned_strings_buffer=16" >> "$site_php_ini"
    fi
    if grep -q "allow_url_fopen" "$site_php_ini"; then
      sed -i 's/;*allow_url_fopen.*/allow_url_fopen = On/' "$site_php_ini"
    else
      echo "allow_url_fopen = On" >> "$site_php_ini"
    fi
  fi
  info "Configuring MariaDB"
  configure_nc_db || return 1
  dns_check "$domain" || warn "DNS is not ready yet; SSL setup will require it before issuance."
  info "Configuring Nextcloud"
  . "$nc_root/meta.conf"
  nc_db="$DB_NAME"
  $PHP_EXEC "$nc_webroot/occ" maintenance:install \
    --database "mysql" \
    --database-name "$nc_db" \
    --database-user "$nc_db_user" \
    --database-pass "$nc_db_pass" \
    --admin-user "$nc_user" \
    --admin-pass "$nc_pass" \
    --database-host "127.0.0.1" \
    --data-dir "$nc_data" || return 1
  $PHP_EXEC "$nc_webroot/occ" config:system:set trusted_domains 1 --value="$domain" || warn "Could not set the additional trusted domain."
  $PHP_EXEC "$nc_webroot/occ" config:system:set overwriteprotocol --value="https" || warn "Could not set overwriteprotocol."
  if [[ "${enable_redis,,}" == "y" || "${enable_redis,,}" == "yes" ]]; then
    info "Installing and configuring isolated Redis/Valkey."
    setup_redis "$domain" || return 1
    redis_service "$domain" || return 1
    systemctl enable --now "$service" || {
      error "Failed to start isolated Redis service $service."
      journalctl -u "$service" -n 30 --no-pager 2>/dev/null || true
      return 1
    }
    for _ in {1..20}; do
      [[ -S "$sock" ]] && break
      sleep 0.25
    done
    [[ -S "$sock" ]] || {
      error "Redis socket was not created: $sock"
      return 1
    }
    redis_cli="$(command -v redis-cli || command -v valkey-cli)"
    if ! REDISCLI_AUTH="$redis_pw" "$redis_cli" -s "$sock" ping 2>/dev/null | grep -qx 'PONG'; then
      error "Isolated Redis/Valkey readiness check failed."
      return 1
    fi
    $PHP_EXEC "$nc_webroot/occ" config:system:set redis host --value="$sock" || warn "Could not write the Nextcloud Redis socket setting."
    $PHP_EXEC "$nc_webroot/occ" config:system:set redis port --value="0" --type=integer || warn "Could not write the Nextcloud Redis port setting."
    $PHP_EXEC "$nc_webroot/occ" config:system:set redis password --value="$redis_pw" || warn "Could not write the Nextcloud Redis password setting."
    $PHP_EXEC "$nc_webroot/occ" config:system:set memcache.local --value="\\OC\\Memcache\\APCu" || warn "Could not set Nextcloud local cache."
    $PHP_EXEC "$nc_webroot/occ" config:system:set memcache.locking --value="\\OC\\Memcache\\Redis" || warn "Could not set Nextcloud Redis locking cache."

    systemctl restart "php-fpm@${domain}.service" || warn "Could not restart the site PHP-FPM service after Redis configuration."
    success "Isolated Redis/Valkey configured."
  fi
  info "Enabling PHP"
  systemctl enable "php-fpm@${domain}.service" --now
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver" -y
  info "Configuring SSL"
  install_letsencrypt nextcloud
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site $domain > /dev/null 2>&1" > "/etc/cron.d/one-click_wp-web-monitor_nc_$domain"
  info "Applying Nextcloud runtime settings."
  if grep -q '^apc.enable_cli[[:space:]]*=' "/etc/one-click/php/${domain}/php.ini"; then
    sed -i 's/^apc.enable_cli[[:space:]]*=.*/apc.enable_cli = 1/' "/etc/one-click/php/${domain}/php.ini"
  else
    echo "apc.enable_cli = 1" >> "/etc/one-click/php/${domain}/php.ini"
  fi
  $PHP_EXEC "$nc_webroot/occ" config:system:set memcache.local --value="\\OC\\Memcache\\APCu" || warn "Could not set Nextcloud local cache."
  $PHP_EXEC "$nc_webroot/occ" config:system:set overwrite.cli.url --value="https://$domain" || warn "Could not set overwrite.cli.url."
  $PHP_EXEC "$nc_webroot/occ" config:system:set overwriteprotocol --value="https" || warn "Could not set overwriteprotocol."
  $PHP_EXEC "$nc_webroot/occ" config:system:set maintenance_window_start --value="1" --type=integer || warn "Could not set the maintenance window."
  $PHP_EXEC "$nc_webroot/occ" config:system:set user_status.enabled --value="true" --type=boolean || warn "Could not enable user status."
  $PHP_EXEC "$nc_webroot/occ" files:scan --all || warn "Initial Nextcloud file scan reported an error."
  if [[ -f "$nc_webroot/.user.ini" ]]; then
    sed -i 's/^memory_limit=.*/memory_limit=1024M/' "$nc_webroot/.user.ini"
    if ! grep -q "^memory_limit" "$nc_webroot/.user.ini"; then
     echo "memory_limit=1024M" >> "$nc_webroot/.user.ini"
   fi
 fi
  if [[ -f "$nc_webroot/.htaccess" ]]; then
    sed -i 's/php_value memory_limit .*/php_value memory_limit 1024M/' "$nc_webroot/.htaccess"
  fi
  systemctl daemon-reload
  systemctl restart "php-fpm@${domain}.service"
  harden_nextcloud
  check_permissions "$domain"
  case "$webserver" in
    nginx) systemctl reload nginx ;;
    apache|apache2)
      if systemctl cat apache2 >/dev/null 2>&1; then
        systemctl reload apache2
      else
        systemctl reload httpd
      fi
      ;;
  esac
  provision_success=1
  trap - EXIT INT TERM ERR
  success " Suit has now been installed!"
  info "Access the site from ${magenta}https://${domain}${reset}"
}
toggle_maintenance() {
  local output state
  output=$(site_php_exec_as "$domain" "$web_user" "$nc_webroot/occ" maintenance:mode 2>&1)
  state=$(grep -qi "enabled" <<< "$output" && echo "enabled" || echo "disabled")
  if [[ "$state" == "enabled" ]]; then
    ui_tog=Disable
    tog_status=disabling
    tog="--off"
    new_state=disabled
  else
    ui_tog=Enable
    tog_status=enabling
    tog="--on"
    new_state=enabled
  fi
  info "Mainenance mode is currently $state."
  read -rp "${cyan}[USER]${reset} ${ui_tog}? " tog_ui
  if [[ ! "${tog_ui,,}" =~ ^(y|yes)$ ]]; then
    warn "Maintenance mode will remain $state"
    return
  fi
  warn "Maintenance mode is currently ${state^^} ${lime}→${reset} ${tog_status^^}."
  site_php_exec_as "$domain" "$web_user" "$nc_webroot/occ" maintenance:mode "$tog" >/dev/null 2>&1 || {
    error "Failed to ${ui_tog,,} maintenance mode."
    return 1
  }
  success "Maintenance mode $new_state."
}
occ_console() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  info "Enter OCC command"
  read -rp "${cyan}[USER]${reset} occ> " occ_cmd
  site_php_exec_as "$domain" "$web_user" "$nc_webroot/occ" $occ_cmd
}
reset_nextcloud_password() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_user="$NC_USER"
  site_php_exec_as "$domain" "$web_user" "$nc_webroot/occ" \
    user:resetpassword "$nc_user"
}
backup_nextcloud_instance() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local timestamp partial backup_root
  local web_user nc_webroot nc_db data
  local maintenance_enabled=0
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  nc_db="$DB_NAME"
  data="/etc/one-click/nextcloud/${domain}/data"
  [[ -d "$nc_webroot" && -f "$nc_webroot/occ" && -d "$data" && -n "$nc_db" ]] || {
    error "Nextcloud runtime metadata is incomplete for $domain."
    return 1
  }
  timestamp="$(date +%F-%H%M%S)"
  backup_root="/etc/one-click/nextcloud/${domain}/backups/${timestamp}"
  partial="${backup_root}.partial"
  rm -rf "$partial"
  mkdir -p "$partial/files" "$partial/data" "$partial/db"
  info "Enabling maintenance mode."
  if ! site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" maintenance:mode --on >/dev/null; then
    rm -rf "$partial"
    error "Unable to enable Nextcloud maintenance mode."
    return 1
  fi
  maintenance_enabled=1
  if ! mysqldump --single-transaction --quick "$nc_db" > "$partial/db/database.sql"; then
    error "Nextcloud database backup failed."
    site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
      "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$partial"
    return 1
  fi
  [[ -s "$partial/db/database.sql" ]] || {
    error "Nextcloud database backup is empty."
    site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
      "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$partial"
    return 1
  }
  rsync -a "$nc_webroot/" "$partial/files/" || {
    error "Nextcloud application file backup failed."
    site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
      "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$partial"
    return 1
  }
  rsync -a "$data/" "$partial/data/" || {
    error "Nextcloud data backup failed."
    site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
      "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$partial"
    return 1
  }
  cp -a "$meta" "$partial/meta.conf"
  if ! site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" maintenance:mode --off >/dev/null; then
    error "Backup completed but maintenance mode could not be disabled."
    rm -rf "$partial"
    return 1
  fi
  maintenance_enabled=0
  mv "$partial" "$backup_root"
  last_nextcloud_backup_path="$backup_root"
  success "Nextcloud backup complete: $backup_root"
}
restore_nextcloud_backup() {
  local requested="${1:-}"
  local skip_safety="${2:-}"
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local web_user nc_webroot nc_db data backup safety_backup=""
  local restore_failed=0
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  nc_db="$DB_NAME"
  data="/etc/one-click/nextcloud/${domain}/data"
  if [[ -n "$requested" ]]; then
    backup="$requested"
  elif command -v fzf >/dev/null 2>&1; then
    backup="$(find "/etc/one-click/nextcloud/${domain}/backups" \
      -mindepth 1 -maxdepth 1 -type d ! -name '*.partial' | sort -r | fzf)"
  else
    mapfile -t nc_backups < <(
      find "/etc/one-click/nextcloud/${domain}/backups" \
        -mindepth 1 -maxdepth 1 -type d ! -name '*.partial' | sort -r
    )
    [[ ${#nc_backups[@]} -gt 0 ]] || {
      error "No Nextcloud backups found."
      return 1
    }
    printf '%s\n' "Available Nextcloud backups:"
    for i in "${!nc_backups[@]}"; do
      printf '  %d) %s\n' "$((i+1))" "$(basename "${nc_backups[$i]}")"
    done
    read -rp "Select backup: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#nc_backups[@]} )) || return 1
    backup="${nc_backups[$((choice-1))]}"
  fi
  [[ -n "$backup" ]] || return 1
  [[ -d "$backup/files" && -d "$backup/data" && -s "$backup/db/database.sql" ]] || {
    error "Selected Nextcloud backup is incomplete: $backup"
    return 1
  }
  if [[ "$skip_safety" != "no-safety" ]]; then
    backup_nextcloud_instance || {
      error "Could not create the required pre-restore safety backup."
      return 1
    }
    safety_backup="$last_nextcloud_backup_path"
  fi
  site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" maintenance:mode --on >/dev/null || return 1
  rsync -a --delete "$backup/files/" "$nc_webroot/" || restore_failed=1
  (( restore_failed == 0 )) && rsync -a --delete "$backup/data/" "$data/" || restore_failed=1
  (( restore_failed == 0 )) && mysql "$nc_db" < "$backup/db/database.sql" || restore_failed=1
  if (( restore_failed != 0 )); then
    error "Nextcloud restore failed."
    if [[ -n "$safety_backup" && -d "$safety_backup" ]]; then
      warn "Recovering the pre-restore Nextcloud state."
      rsync -a --delete "$safety_backup/files/" "$nc_webroot/" || true
      rsync -a --delete "$safety_backup/data/" "$data/" || true
      mysql "$nc_db" < "$safety_backup/db/database.sql" || true
    fi
    site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
      "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || true
    return 1
  fi
  if ! site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" maintenance:repair; then
    warn "Restore completed, but Nextcloud maintenance repair reported an error."
  fi
  site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" maintenance:mode --off >/dev/null || {
      error "Restore completed but maintenance mode could not be disabled."
      return 1
    }
  chown -R "$web_user:${SITE_GROUP}" "$nc_webroot" "$data"
  success "Nextcloud restore completed from $(basename "$backup")."
}
tail_nextcloud_logs() {
  . "/etc/one-click/nextcloud/${domain}/meta.conf" || {
    echo "Failed to load metadata"
    return 1
  }
  local log_file="/var/log/one-click/${domain}/nextcloud/nextcloud.log"
  [[ ! -f "$log_file" ]] && {
    echo "Nextcloud log not found: $log_file"
    return 1
  }
  clear
  printf "%s\n" \
    "╔══════════════════════════════════════════════════════════════╗" \
    "║                   Nextcloud Live Log View                    ║" \
    "╚══════════════════════════════════════════════════════════════╝" \
  printf " Domain : %s\n" "$domain"
  printf " Log    : %s\n\n" "$log_file"
  tail -Fn0 "$log_file" | while read -r line; do
    timestamp=$(jq -r '.time // "unknown"' <<< "$line" 2>/dev/null)
    level=$(jq -r '.level // "?"' <<< "$line" 2>/dev/null)
    app=$(jq -r '.app // "system"' <<< "$line" 2>/dev/null)
    message=$(jq -r '.message // .msg // "no message"' <<< "$line" 2>/dev/null)
    user=$(jq -r '.user // "-"' <<< "$line" 2>/dev/null)
    case "$level" in
      0) colour='\033[0;32m'; level_name="DEBUG" ;;
      1) colour='\033[0;36m'; level_name="INFO"  ;;
      2) colour='\033[1;33m'; level_name="WARN"  ;;
      3) colour='\033[1;31m'; level_name="ERROR" ;;
      4) colour='\033[1;35m'; level_name="FATAL" ;;
      *) colour='\033[0m'; level_name="$level"   ;;
    esac
    printf "%b[%s]\033[0m %-6s %-15s %-15s %s\n" \
      "$colour" \
      "$timestamp" \
      "$level_name" \
      "$app" \
      "$user" \
      "$message"
  done
}
restart_nextcloud_services() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local php_unit="php-fpm@${domain}.service"
  local redis_unit="redis-${domain}.service"
  local service=""
  local failed=0
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  info "Restarting Nextcloud services for $domain."
  if systemctl cat "$php_unit" >/dev/null 2>&1; then
    systemctl restart "$php_unit" || failed=1
  else
    error "PHP unit not found: $php_unit"
    failed=1
  fi
  if systemctl cat "$redis_unit" >/dev/null 2>&1; then
    systemctl restart "$redis_unit" || failed=1
  fi
  case "${WEBSERVER:-}" in
    nginx) service="nginx"; nginx -t >/dev/null 2>&1 || failed=1 ;;
    apache|apache2)
      if systemctl cat apache2 >/dev/null 2>&1; then
        service="apache2"
        apache2ctl configtest >/dev/null 2>&1 || failed=1
      else
        service="httpd"
        httpd -t >/dev/null 2>&1 || failed=1
      fi
      ;;
    httpd) service="httpd"; httpd -t >/dev/null 2>&1 || failed=1 ;;
    *)
      error "Unknown Nextcloud webserver: ${WEBSERVER:-unset}"
      failed=1
      ;;
  esac
  if [[ -n "$service" ]] && (( failed == 0 )); then
    systemctl reload "$service" || failed=1
  fi
  [[ -S "/run/one-click/${domain}/php.sock" ]] || {
    error "PHP socket is missing: /run/one-click/${domain}/php.sock"
    failed=1
  }
  if (( failed != 0 )); then
    error "One or more Nextcloud runtime services failed to restart."
    return 1
  fi
  success "Nextcloud services restarted."
}
repair_nextcloud_instance() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local web_user nc_webroot
  local php_cli=""
  local -a occ
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  php_cli="$(site_php_cli_bin "$domain")" || return 1
  occ=(sudo -u "$web_user" "$php_cli" -c "/etc/one-click/php/${domain}/php.ini" "$nc_webroot/occ")
  "${occ[@]}" status >/dev/null || {
    error "OCC validation failed."
    return 1
  }
  info "Running Nextcloud maintenance repair."
  "${occ[@]}" maintenance:repair || return 1
  "${occ[@]}" maintenance:mimetype:update-db || return 1
  "${occ[@]}" db:add-missing-indices || return 1
  "${occ[@]}" db:add-missing-columns || return 1
  "${occ[@]}" db:add-missing-primary-keys || return 1
  harden_nextcloud || return 1
  systemctl restart "php-fpm@${domain}.service" || return 1
  success "Nextcloud repair and hardening complete."
}
harden_nextcloud() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local nc_root nc_user nc_group
  local php_cli=""
  local -a occ
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  nc_root="$SITE_DIR"
  nc_user="$SITE_USER"
  nc_group="$SITE_GROUP"
  [[ -d "$nc_root" && -f "$nc_root/occ" ]] || {
    error "Nextcloud directory is incomplete: $nc_root"
    return 1
  }
  php_cli="$(site_php_cli_bin "$domain")" || return 1
  occ=(sudo -u "$nc_user" "$php_cli" -c "/etc/one-click/php/${domain}/php.ini" "$nc_root/occ")
  info "Hardening Nextcloud: $domain"
  chown -R "$nc_user:$nc_group" "$nc_root"
  find "$nc_root" -type d -exec chmod 750 {} \;
  find "$nc_root" -type f -exec chmod 640 {} \;
  [[ -f "$nc_root/config/config.php" ]] && chmod 600 "$nc_root/config/config.php"
  [[ -f "$nc_root/.htaccess" ]] && chmod 644 "$nc_root/.htaccess"
  if [[ -d "/etc/one-click/nextcloud/${domain}/data" ]]; then
    chown -R "$nc_user:$nc_group" "/etc/one-click/nextcloud/${domain}/data"
    find "/etc/one-click/nextcloud/${domain}/data" -type d -exec chmod 750 {} \;
    find "/etc/one-click/nextcloud/${domain}/data" -type f -exec chmod 640 {} \;
  fi
  rm -rf \
    "$nc_root/updater_backup" \
    "$nc_root/tests" \
    "$nc_root/build" \
    "$nc_root/dev" \
    "$nc_root/.github" \
    2>/dev/null || true

  cat > "$nc_root/.user.ini" <<'EOF'
expose_php=Off
display_errors=Off
log_errors=On
session.cookie_httponly=1
session.cookie_secure=1
session.use_strict_mode=1
EOF
  chown "$nc_user:$nc_group" "$nc_root/.user.ini"
  chmod 640 "$nc_root/.user.ini"
  "${occ[@]}" config:system:set auth.bruteforce.protection.enabled \
    --type=boolean --value=true >/dev/null 2>&1 || return 1
  "${occ[@]}" config:system:set filesystem_check_changes \
    --type=integer --value=0 >/dev/null 2>&1 || return 1
  "${occ[@]}" maintenance:update:htaccess >/dev/null 2>&1 || true
  find "$nc_root" -type f \( \
      -name "*.pem" -o -name "*.key" -o -name "*.crt" -o -name "*.p12" \
    \) -exec chmod 600 {} \;
  if [[ -d "$nc_root/apps" ]]; then
    find "$nc_root/apps" -type d -exec chmod 750 {} \;
    find "$nc_root/apps" -type f -exec chmod 640 {} \;
  fi
  "${occ[@]}" integrity:check-core >/dev/null 2>&1 || \
    warn "Nextcloud core integrity check reported differences."
  success "Nextcloud hardening complete."
}
update_nextcloud_instance() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local web_user nc_webroot work archive sums expected safety_backup=""
  local maintenance_on=0
  local php_cli=""
  local -a occ
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  php_cli="$(site_php_cli_bin "$domain")" || return 1
  occ=(sudo -u "$web_user" "$php_cli" -c "/etc/one-click/php/${domain}/php.ini" "$nc_webroot/occ")
  backup_nextcloud_instance || return 1
  safety_backup="$last_nextcloud_backup_path"
  work="$(mktemp -d /tmp/one-click-nextcloud-update.XXXXXX)"
  archive="$work/latest.tar.bz2"
  sums="$work/latest.tar.bz2.sha256"
  curl -fL --retry 3 \
    https://download.nextcloud.com/server/releases/latest.tar.bz2 \
    -o "$archive" || { rm -rf "$work"; return 1; }
  curl -fL --retry 3 \
    https://download.nextcloud.com/server/releases/latest.tar.bz2.sha256 \
    -o "$sums" || { rm -rf "$work"; return 1; }
  expected="$(awk '/latest\.tar\.bz2/{print $1; exit} NR==1{first=$1} END{if(!found && first){} }' "$sums")"
  [[ -n "$expected" ]] || expected="$(awk 'NR==1{print $1;exit}' "$sums")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || {
    rm -rf "$work"
    error "Unable to parse Nextcloud checksum."
    return 1
  }
  printf '%s  %s\n' "$expected" "$archive" | sha256sum -c - >/dev/null 2>&1 || {
    rm -rf "$work"
    error "Nextcloud update checksum validation failed."
    return 1
  }
  mkdir -p "$work/extract"
  tar -xjf "$archive" -C "$work/extract" || {
    rm -rf "$work"
    return 1
  }
  [[ -f "$work/extract/nextcloud/occ" ]] || {
    rm -rf "$work"
    error "Downloaded Nextcloud archive is incomplete."
    return 1
  }
  "${occ[@]}" maintenance:mode --on >/dev/null || {
    rm -rf "$work"
    return 1
  }
  maintenance_on=1
  if ! rsync -a \
    --exclude=config \
    --exclude=data \
    "$work/extract/nextcloud/" \
    "$nc_webroot/"; then
    error "Nextcloud application update copy failed."
    "${occ[@]}" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$work"
    restore_nextcloud_backup "$safety_backup" "no-safety" || true
    return 1
  fi
  if ! "${occ[@]}" upgrade; then
    error "Nextcloud database/application upgrade failed."
    "${occ[@]}" maintenance:mode --off >/dev/null 2>&1 || true
    rm -rf "$work"
    restore_nextcloud_backup "$safety_backup" "no-safety" || true
    return 1
  fi
  "${occ[@]}" maintenance:mode --off >/dev/null || {
    rm -rf "$work"
    error "Nextcloud update succeeded but maintenance mode could not be disabled."
    return 1
  }
  maintenance_on=0
  rm -rf "$work"
  repair_nextcloud_instance || return 1
  success "Nextcloud update completed."
}
nextcloud_status() {
  local meta="/etc/one-click/nextcloud/${domain}/meta.conf"
  local web_user nc_webroot data
  [[ -f "$meta" ]] || {
    error "Nextcloud metadata missing for $domain."
    return 1
  }
  . "$meta"
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  data="/etc/one-click/nextcloud/${domain}/data"
  site_php_exec_as "$domain" "$web_user" -c "/etc/one-click/php/${domain}/php.ini" \
    "$nc_webroot/occ" status || return 1
  echo
  systemctl status "php-fpm@${domain}.service" --no-pager || true
  if systemctl cat "redis-${domain}.service" >/dev/null 2>&1; then
    echo
    systemctl status "redis-${domain}.service" --no-pager || true
  fi
  echo
  df -h "$data"
}
remove_nextcloud_instance() {
  local target_domain="${domain:-${1:-}}"
  [[ -n "$target_domain" ]] || {
    error "No Nextcloud domain selected."
    return 1
  }
  delete_site "$target_domain"
}
nextcloud_menu() {
  used_app="nextcloud"
  select_domain
  domain="$(normalize_domain "$domain")"
  type="nextcloud"
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  while true; do
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK NEXTCLOUD${blue}                         ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Maintenance Mode${blue}                                      ║" \
      "║ ${magenta}2${blue}  ║ ${green}OCC Console${blue}                                           ║" \
      "║ ${magenta}3${blue}  ║ ${green}Reset Password${blue}                                        ║" \
      "║ ${magenta}4${blue}  ║ ${green}Harden Instance${blue}                                       ║" \
      "║ ${magenta}5${blue}  ║ ${green}View Logs${blue}                                             ║" \
      "║ ${magenta}6${blue}  ║ ${green}Restart Service${blue}                                       ║" \
      "║ ${magenta}7${blue}  ║ ${green}Restart PHP-FPM${blue}                                       ║" \
      "║ ${magenta}8${blue}  ║ ${green}Update Nextcloud${blue}                                      ║" \
      "║ ${magenta}9${blue}  ║ ${green}Backup Instance${blue}                                       ║" \
      "║ ${magenta}10${blue} ║ ${green}Check/Fix Permissions${blue}                                 ║" \
      "║ ${magenta}11${blue} ║ ${green}Delete Site${blue}                                           ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option [0-10]: " choice
    case "$choice" in
      1) toggle_maintenance                          ;;
      2) occ_console                                 ;;
      3) reset_nextcloud_password                    ;;
      4) repair_nextcloud_instance                   ;;
      5) tail_nextcloud_logs                         ;;
      6) restart_nextcloud_services                  ;;
      7) systemctl restart php-fpm@${domain}.service ;;
      8) update_nextcloud_instance                   ;;
      9) backup_nextcloud_instance                   ;;
      10) check_permissions "$domain" "nextcloud"    ;;
      11) delete_site "$domain"                      ;;
      0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
    esac
  done
}
################################# SITE REMOVAL ###############################
delete_site() {
  local domain="$1"
  [[ -z "$domain" ]] && { error "No domain provided"; return 1; }
  # All Node.js deletion entry points must use the isolated app teardown.
  if [[ -d "/etc/one-click/apps/nodejs/$domain" ]]; then
    resolve_type "$domain" || return 1
    [[ "$type" == "apps/nodejs" ]] || { error "Ambiguous Node.js domain: $domain"; return 1; }
    app_delete "$domain"
    return $?
  fi
  detect_env
  resolve_type "$domain"
  if [[ -z "${type:-}" ]]; then
    error "Could not resolve site type for domain '$domain'."
    return 1
  fi
  local meta_file="/etc/one-click/${type}/${domain}/meta.conf"
  # ==== Load Site Metadata ====
  if [[ -f "$meta_file" ]]; then
    info "Loading site metadata from $meta_file"
    . "$meta_file"
  else
    warn "meta.conf not found at $meta_file. Falling back to dynamic detection."
  fi
  local site_user="${SITE_USER:-$(get_site_user "$domain" 2>/dev/null || stat -c '%U' "/etc/one-click/${type}/$domain" 2>/dev/null || true)}"
  local service_name="${PHP_SYSTEMD_SERVICE_NAME:-php-fpm@${domain}.service}"
  local slice_name="one-click_${domain}.slice"
  local db_name="${DB_NAME:-}"
  local db_user="${DB_USER:-}"
  warn "This will delete ALL $domain configuration and data files."
  read -rp "${cyan}[USER]${red} WARNING: Delete $domain permanently? (y|n): ${reset}" confirm
  [[ "$confirm" != "y" ]] && { info "Teardown cancelled."; return 0; }
  info "Tearing down $domain (Type: $type)."
  systemctl disable --now "$service_name" 2>/dev/null || true
  systemctl disable --now "redis-${domain}" 2>/dev/null || true
  systemctl stop "$slice_name" 2>/dev/null || true
  find /etc/systemd/system /usr/lib/systemd/system -type f -name "*${domain}*.service" 2>/dev/null | while read -r unit; do
    systemctl disable --now "$(basename "$unit")" 2>/dev/null || true
    rm -f "$unit"
  done
  if [[ "$DB_ENABLED" == "true" || -n "$db_name" ]]; then
    read -rp "${cyan}[USER]${blue} Delete DB '$db_name'? (y|n): ${reset}" db_confirm
    if [[ "$db_confirm" == "y" ]]; then
      if [[ -n "$db_name" ]]; then
        info "Removing database: $db_name"
        mysql -e "DROP DATABASE IF EXISTS \`$db_name\`;" 2>/dev/null || true
      fi
      if [[ -n "$db_user" ]]; then
        info "Checking if other sites share DB user: $db_user"
        local user_occ
        user_occ=$(grep -r -l "DB_USER=$db_user" /etc/one-click/*/meta.conf 2>/dev/null | wc -l || echo 1)
        if [[ "$user_occ" -le 1 ]]; then
          info "Dropping unused DB user: $db_user"
          mysql -e "DROP USER IF EXISTS '$db_user'@'localhost';" 2>/dev/null || true
        else
          warn "DB User $db_user is still in use by other site(s). Skipping user deletion."
        fi
      fi
    fi
  fi
  if [[ "${WEBSERVER:-$webserver}" == "nginx" ]]; then
    rm -f "${VHOST:-/etc/nginx/sites-available/$domain.conf}" \
          "/etc/nginx/sites-enabled/$domain.conf" \
          "/etc/nginx/conf.d/$domain.conf" 2>/dev/null
    systemctl reload nginx 2>/dev/null || true
  else
    rm -f "${VHOST:-/etc/apache2/sites-available/$domain.conf}" \
          "/etc/apache2/sites-enabled/$domain.conf" \
          "/etc/httpd/conf.d/$domain*.conf" 2>/dev/null
    systemctl reload apache2 2>/dev/null || systemctl reload httpd 2>/dev/null || true
  fi
  if [[ -n "${HOSTS_ENTRY:-}" ]]; then
    sed -i "/${domain}/d" /etc/hosts 2>/dev/null || true
  fi
  info "Deleting site directories and PHP runtime for $domain..."
  rm -rf "${PHP_DIR:-/etc/one-click/php/$domain}" 2>/dev/null || true
  rm -rf "${PHP_RUNTIME:-/run/one-click/$domain}" 2>/dev/null || true
  rm -rf "${PHP_LIB_DIR:-/var/lib/one-click/$domain}" 2>/dev/null || true
  rm -f "/run/php-fpm-${domain}.sock" 2>/dev/null || true
  rm -rf "/etc/one-click/${type}/$domain" 2>/dev/null || true
  rm -rf "/etc/one-click/${type}/backups/$domain" 2>/dev/null || true
  rm -rf "/etc/one-click/${type}/rollback/$domain" 2>/dev/null || true
  rm -f "/etc/one-click/db-manager/sites/${domain}.json" 2>/dev/null || true
  rm -f "/etc/one-click/db-manager/secrets/db/${domain}.pass" 2>/dev/null || true
  rm -f "/var/log/one-click/${domain}/php/error.log" 2>/dev/null || true
  rm -f "/var/log/one-click/${domain}"*.log 2>/dev/null || true
  rm -f "${PHP_SYSTEMD_VHOST:-/etc/systemd/system/$service_name}" \
        "/etc/systemd/system/$slice_name" \
        "/etc/systemd/system/redis-${domain}.service" 2>/dev/null || true
  rm -rf "/etc/letsencrypt/live/$domain" \
         "/etc/letsencrypt/archive/$domain" \
         "/etc/letsencrypt/renewal/$domain.conf" 2>/dev/null || true
  if [[ -n "$site_user" ]] && id "$site_user" &>/dev/null; then
    info "Removing isolated system user: $site_user"
    printf "${orange}[DEL]:${reset} "
    gpasswd -d "${SITE_GROUP:-www-data}" "$site_user" 2>/dev/null || true
    userdel -r -f "$site_user" 2>/dev/null || true
  fi
  systemctl daemon-reload
  systemctl reset-failed 2>/dev/null || true
  success "The ($type) installation for $domain has now been deleted"
}
get_monitor_stats() {
  local domain="${1:-}"
  find /etc/one-click/{sites,wordpress,apps/nodejs,nextcloud}/ -maxdepth 1 \
    | while read -r site_mon; do
      if [[ "$site_mon" =~ \. ]]; then
        mon=$(basename $site_mon)
        #monitor "$mon"
        echo $mon
      fi
    done
  local profile_file="/etc/one-click/monitor/${domain}/${domain}.profile"
  local status_file="/etc/one-click/monitor/${domain}/monitor_status"
  local log_file="/var/log/one-click/${domain}/${webserver}/monitor.log"
  mkdir -p "/etc/one-click/monitor/${domain}"
  if [[ ! -f /etc/cron.d/one-click-uptime-monitor_$domain ]]; then
    echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site $domain > /dev/null 2>&1" > /etc/cron.d/one-click-uptime-monitor_$domain
  fi
  if [[ -f "$profile_file" ]]; then
    read -r saved_domain < "$profile_file"
    [[ -n "$saved_domain" ]] && domain="$saved_domain"
  fi
  if [[ ! -f "$status_file" ]]; then
    echo "INIT $(date +%s)" > "$status_file"
    echo "No data yet"
    return
  fi
  read -r state start_ts < "$status_file"
  now=$(date +%s)
  diff=$(( now - start_ts ))
  uptime_str="$(($diff / 86400))d $(($diff % 86400 / 3600))h $(($diff % 3600 / 60))m"
  if [[ -n "$domain" ]]; then
    echo "$domain" > "$profile_file"
  fi
  if [[ "$state" == "UP" ]]; then
    echo "${green}Online for $uptime_str${reset}               "
  else
    echo "${red}Offline for $uptime_str${reset}                "
  fi
}
monitor() {
  domain="${1:-}"
  check_url="https://$domain"
  status_file="/etc/one-click/monitor/${domain}/monitor_status"
  log_file="/var/log/one-click/${domain}/${webserver}/monitor.log"
  mkdir -p "/etc/one-click/monitor/${domain}" "/var/log/one-click/${domain}/${webserver}"
  now=$(date +%s)
  http_status=$(curl -o /dev/null -s -w "%{http_code}" \
    --max-time 5 --connect-timeout 3 "$check_url" || echo "000")
  if [[ -f "$status_file" ]]; then
    read -r last_state last_ts < "$status_file"
  else
    last_state="INIT"
    last_ts=$now
  fi
  if [[ "$http_status" =~ ^2|3 ]]; then
    current_state="UP"
  else
    current_state="DOWN"
  fi
  if [[ "$current_state" != "$last_state" ]]; then
    if [[ "$current_state" == "UP" ]]; then
      downtime=$((now - last_ts))
      echo "$(date): $domain is BACK UP (down for $downtime sec, status: $http_status)" >> "$log_file"
    else
      echo "$(date): $domain is DOWN (status: $http_status)" >> "$log_file"
    fi
    echo "$current_state $now" > "$status_file"
  else
    echo "$current_state $last_ts" > "$status_file"
  fi
}
############################### DATABASE MANAGEMENT ############################
resolve_site_database() {
  local domain="$1"
  local registry="/etc/one-click/db-manager/sites/${domain}.json"
  local meta="/etc/one-click/${type}/${domain}/meta.conf"
  db_enabled=false
  # ==== Registry (authoritative) ====
  if [[ -f "$registry" ]]; then
    db_enabled=$(jq -r '.database.enabled // false' "$registry")
    if [[ "$db_enabled" == "true" ]]; then
      db_engine=$(jq -r '.database.engine // empty' "$registry")
      db_host=$(jq -r '.database.host // localhost' "$registry")
      db_port=$(jq -r '.database.port // 3306' "$registry")
      db_name=$(jq -r '.database.name // empty' "$registry")
      db_user=$(jq -r '.database.user // empty' "$registry")
      db_password_file=$(jq -r '.database.password_file // empty' "$registry")
      [[ -n "$db_name" && -n "$db_user" ]] && return 0
    fi
  fi
  # ==== Fallback meta ====
  if [[ -f "$meta" ]]; then
    unset db_name db_user db_password_file
    source "$meta"
    [[ -n "${db_name:-}" ]] || return 1
    [[ -n "${db_user:-}" ]] || return 1
    [[ -n "${db_password_file:-}" ]] || return 1
    db_enabled=true
    db_engine="mysql"
    db_host="localhost"
    db_port="3306"
    return 0
  fi
  return 1
}
registry_exists() {
  local domain="$1"
  if [[ -z "$domain" ]]; then
    return 1
  fi
  [[ -f "$registry" ]]
}
registry_create() {
  local domain="$1"
  local registry type root meta php_ver passfile db_port db_enabled=false
  local nginx_enabled=false apache_enabled=false nginx_vhost="" apache_vhost=""
  local ssl_enabled=false http2_enabled=false pool_enabled=false basedir_enabled=false
  local db_name="" db_user="" legacy_pass="" site_dir="" created_at users_json="[]"
  local databases_json="[]" existing_ui=false adminer_version="6.1.1"
  local existing_aliases="[]" existing_dbs="[]" existing_users="[]" existing_backup='{"enabled":false,"last_backup":null}'
  local existing_db_name="" existing_db_user=""
  domain="$(normalize_domain "$domain")"
  [[ -n "$domain" ]] || {
    error "Missing domain"
    return 0
  }
  resolve_type "$domain" || {
    error "Unable to resolve site type for $domain."
    return 0
  }
  root="/etc/one-click/${type}/${domain}"
  meta="${root}/meta.conf"
  registry="${sitectl_dir}/${domain}.json"
  passfile="$(db_password_file "$domain")"
  [[ -f "$meta" ]] || {
    error "Meta file is missing: $meta"
    return 0
  }
  . "$meta"
  site_dir="${SITE_DIR:-${root}/www}"
  if [[ -f "$registry" ]] && jq empty "$registry" >/dev/null 2>&1; then
    existing_ui="$(jq -r '.database.ui_enabled // false' "$registry")"
    existing_db_name="$(jq -r '.database.primary.name // empty' "$registry")"
    existing_db_user="$(jq -r '.database.primary.user // empty' "$registry")"
    existing_aliases="$(jq -c '.site.aliases // []' "$registry")"
    existing_dbs="$(jq -c '.database.databases // []' "$registry")"
    existing_users="$(jq -c '
      (.database.primary.user // "") as $primary |
      [(.database.users // [])[] |
        if type == "string"
        then {"name": ., "role": (if . == $primary then "primary" else "secondary" end)}
        else .
        end
      ]' "$registry")"
    existing_backup="$(jq -c '.backup // {"enabled":false,"last_backup":null}' "$registry")"
  fi
  db_name="${DB_NAME:-$existing_db_name}"
  db_user="${DB_USER:-$existing_db_user}"
  legacy_pass="${DB_PASS:-}"
  mkdir -p "$sitectl_dir" "${db_manager_dir}/secrets/db" "${db_manager_dir}/secrets/db-users"
  chmod 0755 "$sitectl_dir"
  chmod 0711 "${db_manager_dir}/secrets" "${db_manager_dir}/secrets/db" "${db_manager_dir}/secrets/db-users"
  if [[ -n "$legacy_pass" && ! -f "$passfile" ]]; then
    db_write_password "$domain" "$legacy_pass" || return 0
  fi
  if [[ -n "$legacy_pass" && -n "$db_user" ]]; then
    local legacy_user_file
    legacy_user_file="$(db_user_password_file "$domain" "$db_user")"
    [[ -f "$legacy_user_file" ]] || db_write_user_password "$domain" "$db_user" "$legacy_pass" || return 0
  fi
  if [[ "$type" == "wordpress" && ! -f "$passfile" && -f "${root}/wp-config.php" ]]; then
    legacy_pass="$(sed -En "s/.*define\\([[:space:]]*[\"']DB_PASSWORD[\"'][[:space:]]*,[[:space:]]*[\"']([^\"']*)[\"'].*/\\1/p" "${root}/wp-config.php" | head -n1)"
    if [[ -n "$legacy_pass" ]]; then
      db_write_password "$domain" "$legacy_pass" || return 0
      [[ -n "$db_user" ]] && db_write_user_password "$domain" "$db_user" "$legacy_pass" || true
    fi
  fi
  sed -i '/^DB_PASS=/d;/^NC_PASS=/d' "$meta"
  if [[ -n "$db_name" ]] && db_exists "$db_name"; then
    db_enabled=true
  fi
  databases_json="$(jq -cn --argjson old "$existing_dbs" --arg db "$db_name" '
    ($old | unique_by(.name)) as $existing |
    if $db == "" then $existing
    else
      ($existing | map(select(.name != $db))) +
      [{"name":$db,"role":"primary"}]
      | map(if .name == $db then .role = "primary" else .role = "secondary" end)
    end
  ')"
  users_json="$(jq -cn --argjson old "$existing_users" --arg user "$db_user" '
    ($old | unique_by(.name)) as $existing |
    if $user == "" then $existing
    else
      ($existing | map(select(.name != $user))) +
      [{"name":$user,"role":"primary"}]
      | map(if .name == $user then .role = "primary" else .role = "secondary" end)
    end
  ')"
  if [[ -n "$db_user" ]]; then
    if [[ -f "$passfile" ]]; then
      local primary_user_secret
      primary_user_secret="$(db_user_password_file "$domain" "$db_user")"
      if [[ ! -f "$primary_user_secret" ]]; then
        db_write_user_password "$domain" "$db_user" "$(<"$passfile")" || return 0
      fi
    fi
  fi
  php_ver="$(site_php_version "$domain" 2>/dev/null || php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
  db_port="$(mysql -N -B -e "SHOW VARIABLES LIKE 'port';" 2>/dev/null | awk '{print $2}' | head -n1)"
  db_port="${db_port:-3306}"
  case "${WEBSERVER:-}" in
    nginx)
      nginx_enabled=true
      nginx_vhost="${VHOST:-}"
      ;;
    apache|apache2|httpd)
      apache_enabled=true
      apache_vhost="${VHOST:-}"
      ;;
  esac
  if [[ "$nginx_enabled" == "true" && -f "$nginx_vhost" ]]; then
    grep -qE 'listen .*443.*ssl|listen 443 ssl' "$nginx_vhost" && ssl_enabled=true
    grep -qE 'http2[[:space:]]+on|listen .*http2' "$nginx_vhost" && http2_enabled=true
  elif [[ "$apache_enabled" == "true" && -f "$apache_vhost" ]]; then
    grep -q 'SSLEngine on' "$apache_vhost" && ssl_enabled=true
    grep -qE 'Protocols.*h2' "$apache_vhost" && http2_enabled=true
  fi
  systemctl is-active --quiet "php-fpm@${domain}.service" && pool_enabled=true
  grep -q 'open_basedir' "/etc/one-click/php/${domain}/pool.conf" 2>/dev/null && basedir_enabled=true
  if [[ -f "$registry" ]]; then
    created_at="$(jq -r '.site.created_at // empty' "$registry" 2>/dev/null || true)"
  fi
  created_at="${created_at:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
  jq -n \
    --arg domain "$domain" \
    --arg type "$type" \
    --arg root "$site_dir" \
    --arg created "$created_at" \
    --arg php_ver "$php_ver" \
    --arg socket "/run/one-click/$domain/php.sock" \
    --arg engine "mariadb" \
    --arg host "localhost" \
    --argjson port "$db_port" \
    --arg db_name "$db_name" \
    --arg db_user "$db_user" \
    --arg passfile "$passfile" \
    --arg nginx_vhost "$nginx_vhost" \
    --arg apache_vhost "$apache_vhost" \
    --arg adminer_version "$adminer_version" \
    --argjson aliases "$existing_aliases" \
    --argjson backup "$existing_backup" \
    --argjson db_enabled "$db_enabled" \
    --argjson pool_enabled "$pool_enabled" \
    --argjson nginx_enabled "$nginx_enabled" \
    --argjson apache_enabled "$apache_enabled" \
    --argjson ssl_enabled "$ssl_enabled" \
    --argjson http2_enabled "$http2_enabled" \
    --argjson basedir_enabled "$basedir_enabled" \
    --argjson ui_enabled "$existing_ui" \
    --argjson dbs "$databases_json" \
    --argjson users "$users_json" '
    {
      version: 2,
      site: {
        domain: $domain,
        aliases: $aliases,
        type: $type,
        root: $root,
        created_at: $created,
        status: "active"
      },
      php: {
        enabled: $pool_enabled,
        version: $php_ver,
        pool: ($domain | gsub("\\."; "_")),
        socket: $socket
      },
      database: {
        enabled: $db_enabled,
        engine: $engine,
        host: $host,
        port: $port,
        primary: {
          name: (if $db_name == "" then null else $db_name end),
          user: (if $db_user == "" then null else $db_user end)
        },
        databases: $dbs,
        users: $users,
        password_file: $passfile,
        ui_enabled: $ui_enabled,
        adminer_version: $adminer_version
      },
      nginx: {
        enabled: $nginx_enabled,
        vhost: $nginx_vhost,
        ssl: $ssl_enabled,
        http2: $http2_enabled
      },
      apache: {
        enabled: $apache_enabled,
        vhost: $apache_vhost,
        ssl: $ssl_enabled,
        http2: $http2_enabled
      },
      wordpress: {
        detected: ($type == "wordpress"),
        table_prefix: null
      },
      security: {
        isolated_pool: $basedir_enabled,
        open_basedir: $basedir_enabled
      },
      backup: $backup
    }' > "${registry}.tmp" || {
      rm -f "${registry}.tmp"
      error "Failed to generate registry."
      return 0
    }
  jq empty "${registry}.tmp" >/dev/null 2>&1 || {
    rm -f "${registry}.tmp"
    error "Generated invalid registry JSON."
    return 0
  }
  chown root:root "${registry}.tmp"
  chmod 0644 "${registry}.tmp"
  mv "${registry}.tmp" "$registry"
  if ! grep -q '^# One-Click Routing$' /etc/hosts 2>/dev/null; then
    echo "# One-Click Routing" >> /etc/hosts
  fi
  if ! grep -Fq $'127.0.0.1\t'"$domain" /etc/hosts 2>/dev/null; then
    sed -i.one-click_bak "/^# One-Click Routing$/a 127.0.0.1\t${domain}\t# One-Click Entry" /etc/hosts
  fi
  if grep -q '^HOSTS_ENTRY=' "$meta"; then
    sed -i "s|^HOSTS_ENTRY=.*|HOSTS_ENTRY=\"127.0.0.1\\\\t${domain}\"|" "$meta"
  else
    echo -e "HOSTS_ENTRY=\"127.0.0.1\t${domain}\"" >> "$meta"
  fi
  # ==== Prepare the DB web surface ====
  case "$type" in
    wordpress|sites|nextcloud)
      local db_web_dir="${root}/www/db"
      mkdir -p "$db_web_dir" || {
        error "Failed to create DB web directory: $db_web_dir"
        return 0
      }
      chmod 0755 "${root}/www" "$db_web_dir" 2>/dev/null || true

      install_adminer || return 0
      db_write_adminer_wrapper "$domain" || return 0

      [[ -f "$db_web_dir/index.php" ]] || {
        error "DB UI wrapper was not generated for $domain."
        return 0
      }
      [[ -f "${ADMINER_FILE:-${root}/private/adminer.php}" ]] || {
        error "Private Adminer runtime was not installed for $domain."
        return 0
      }
      chmod 0644 "$db_web_dir/index.php"
      ;;
    apps/nodejs)
      info "DB registry created for Node.js. Embedded PHP DB UI is intentionally not exposed behind the Node.js proxy."
      ;;
    *)
      warn "Registry created, but no DB web surface was prepared for unsupported type '$type'."
      ;;
  esac
  registry_sync_databases "$domain" || true
  registry_detect_wordpress "$domain" || true
  check_permissions "$domain" || true
  success "Registry successfully generated"
  info "$registry"
}
registry_list() {
  find "$sitectl_dir" -maxdepth 1 -name "*.json" | sort
}
registry_show() {
  local domain="$1"
  if [[ ! -f "$registry" ]]; then
    error "Registry does not exist"
    return
  fi
  jq . "$registry"
}
normalize_domain() {
  local d="$1"
  d="${d//[$'\t\r\n ']}"
  d="${d,,}"
  d="${d%.}"
  echo "$d"
}
registry_validate() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  jq empty "$registry" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    error "Invalid JSON"
    return
  fi
  local required=(
    ".version"
    ".site.domain"
    ".site.type"
    ".site.root"
    ".site.created_at"
    ".site.status"
  )
  for field in "${required[@]}"; do
    local value
    value=$(jq -r "$field // empty" "$registry")
    if [[ -z "$value" ]]; then
      warn "Missing field $field"
      return 1
    fi
  done
  success "Registry valid"
}
registry_update() {
  local domain="$1"
  shift
  local registry="${sitectl_dir}/$(normalize_domain "$domain").json"
  local tmpfile
  [[ -f "$registry" ]] || {
    error "Registry missing: $registry"
    return 1
  }
  [[ "$#" -gt 0 ]] || {
    error "Registry update requires a jq filter."
    return 1
  }
  tmpfile="$(mktemp)"
  if ! jq "$@" "$registry" > "$tmpfile"; then
    rm -f "$tmpfile"
    error "jq update failed"
    return 1
  fi
  if ! jq empty "$tmpfile" >/dev/null 2>&1; then
    rm -f "$tmpfile"
    error "Update produced invalid JSON"
    return 1
  fi
  chown root:root "$tmpfile"
  chmod 0644 "$tmpfile"
  mv "$tmpfile" "$registry"
}
registry_delete() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  rm -f "$registry"
  warn "Registry deleted"
}
registry_get() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local field="$2"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  jq -r "$field" "$registry"
}
registry_set() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local field="$2"
  local value="$3"
  registry_update "$domain" "$field = \$value" --arg value "$value"
}
registry_get_field() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local field="$2"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  jq -r "$field // empty" "$registry"
}
registry_set_field() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local field="$2"
  local value="$3"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  local tmpfile
  tmpfile=$(mktemp)
  jq --arg value "$value" "$field = \$value" "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Update failed"
    return
  }
  jq empty "$tmpfile" || {
    rm -f "$tmpfile"
    error "Invalid JSON after update"
    return
  }
  mv "$tmpfile" "$registry"
}
registry_add_alias() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local alias="$2"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return
  fi
  if [[ -z "$alias" ]]; then
    error "No aliases provided"
    warn "Including www subdomain"
    alias="www.${domain}"
  fi
  local tmpfile
  tmpfile=$(mktemp)
  jq --arg alias "$alias" '.site.aliases += [$alias]' "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Failed to add alias"
    return
  }
  mv "$tmpfile" "$registry"
  success "Alias added: $alias"
}
registry_set_status() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local status="$2"
  registry_set_field "$domain" ".site.status" "$status"
}
registry_enable_db() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local engine="$2"
  local tmpfile
  tmpfile=$(mktemp)
  jq --arg engine "$engine" '
    .database.enabled = true |
    .database.engine = $engine
  ' "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Failed to enable DB"
    return
  }
  mv "$tmpfile" "$registry"
  success "Database enabled: $engine"
}
registry_each() {
  local callback="$1"
  local file
  for file in "${sitectl_dir}"/*.json; do
    [[ -f "$file" ]] || continue
    local domain
    domain=$(basename "$file" .json)
    "$callback" "$domain" "$file" "$@"
  done
}
registry_filter() {
  local jq_filter="$1"
  local file
  for file in "${sitectl_dir}"/*.json; do
    [[ -f "$file" ]] || continue
    if jq -e "$jq_filter" "$file" >/dev/null 2>&1; then
      basename "$file" .json
    fi
  done
}
registry_list_all() {
  registry_filter 'true'
}
registry_list_db_enabled() {
  registry_filter '.database.enabled == true'
}
registry_list_active() {
  registry_filter '.site.status == "active"'
}
registry_list_php_version() {
  local version="$1"
  registry_filter ".php.version == \"$version\""
}
registry_list_detailed() {
  local file
  for file in "${sitectl_dir}"/*.json; do
    [[ -f "$file" ]] || continue

    jq -r '"\(.site.domain) | \(.site.type) | \(.site.status)"' "$file"
  done
}
registry_list_wordpress() {
  registry_filter '.site.type == "wordpress"'
}
registry_list_static() {
  registry_filter '.site.type == "sites"'
}
db_list_all() {
  mysql -Nse "SHOW DATABASES;" 2>/dev/null
}
registry_add_database() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local db_name="$2"
  local role="${3:-secondary}"
  local tmpfile
  tmpfile=$(mktemp)
  jq \
    --arg db "$db_name" \
    --arg engine "$engine" \
    --arg role "$role" '
    .database.databases //= [] |
    if any(.database.databases[]?; .name == $db) then .
    else
      .database.databases += [{
        "name": $db,
        "role": $role
      }]
    end
  ' "$registry" > "$tmpfile" || {
      rm -f "$tmpfile"
      error "Failed to add database"
      return 1
    }
  mv "$tmpfile" "$registry"
  success "Database added to registry: $db_name"
}
db_list_user_databases() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
  printf "${blue}║${reset}  ${magenta}DATABASE LIST:${reset} %-52s ${blue}║${reset}\n" "$domain"
  printf "${blue}╠════╦══════════════════════════════╦══════════════════════════════════╣${reset}\n"
  local -a db_list=()
  local i=1
  while read -r db role; do
    db_list[$i]="$db"
    local role_color="$cyan"
    [[ "$role" == "primary" ]] && role_color="$green"
    printf "${blue}║${reset} ${cyan}%2d${reset} ║ %-28s ${blue}║${reset} ${role_color}%-34s${blue}║${reset}\n" \
      "$i" "$db" "${role^^}"
    ((i++))
  done < <(
    jq -r '
      (.database.databases // [])[] |
      "\(.name) \(.role)"
    ' "$registry"
  )
  printf "${blue}╚════╩══════════════════════════════╩══════════════════════════════════╝${reset}\n"
}
db_from_domain() {
  local domain="$1"
  sed "s/.*/:${domain}:/" <<< "$domain"
}
db_generate_user() {
  echo "u_$(openssl rand -hex 6)"
}
db_detect_engine() {
  if systemctl is-active --quiet mariadb || \
     systemctl is-active --quiet mysql; then
      echo "mariadb"
      return 0
  fi
  if systemctl is-active --quiet postgresql; then
      echo "postgresql"
      return 0
  fi
  return 1
}
db_exists() {
  local db_name="$1"
  mysql -N -e "SHOW DATABASES LIKE '${db_name}';" \
    2>/dev/null | grep -qx "$db_name"
}
registry_link_database() {
  local domain="$1"
  local db_name="$2"
  local registry="${sitectl_dir}/$(normalize_domain "$domain").json"
  local engine current_primary role
  [[ -f "$registry" ]] || {
    error "Registry missing"
    return 1
  }
  [[ -n "$db_name" ]] || {
    error "Database name required"
    return 1
  }
  db_exists "$db_name" || {
    error "Database does not exist: $db_name"
    return 1
  }
  engine="$(db_detect_engine)" || {
    error "Unable to detect database engine"
    return 1
  }
  current_primary="$(jq -r '.database.primary.name // empty' "$registry")"
  if [[ -z "$current_primary" || "$current_primary" == "$db_name" ]]; then
    role="primary"
  else
    role="secondary"
  fi
  registry_update "$domain" \
    --arg db "$db_name" \
    --arg engine "$engine" \
    --arg role "$role" '
      .database.enabled = true |
      .database.engine = $engine |
      .database.databases //= [] |
      .database.databases |=
        (map(select(.name != $db)) + [{"name": $db, "role": $role}]) |
      if $role == "primary" then
        .database.primary.name = $db |
        .database.databases |= map(
          if .name == $db then .role = "primary"
          else .role = "secondary"
          end
        )
      else .
      end
    ' || return 1
  success "Database linked: $db_name ($engine)"
}
db_detect_domain_databases() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  (mysql -N -B -e "SHOW DATABASES;" 2>/dev/null | \
    grep ":${domain}:") || error "No database found"
}
db_discover_site_db() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local expected
  expected=$(db_from_domain "$domain")
  db_discover_mysql_dbs | grep -Fx "$expected"
}
registry_sync_databases() {
  local domain="$1"
  local registry db_list dbs_json
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  if [[ ! -f "$registry" ]]; then
    warn "Registry not generated for $domain."
    info "Select Registry Management -> Create Site Registry to generate it."
    return 0
  fi
  db_list="$(db_detect_domain_databases "$domain")"
  if [[ -z "$db_list" ]]; then
    warn "No databases detected for $domain"
    return 0
  fi
  dbs_json="$(printf '%s\n' "$db_list" | sed '/^$/d' | jq -R . | jq -s .)" || return 1
  registry_update "$domain" --argjson dbs "$dbs_json" '
    .database.databases //= [] |
    reduce $dbs[] as $db (
      .;
      if any(.database.databases[]?; .name == $db) then .
      else
        if (.database.primary.name // "") == "" then
          .database.primary.name = $db |
          .database.databases += [{"name": $db, "role": "primary"}]
        else
          .database.databases += [{"name": $db, "role": "secondary"}]
        end
      end
    ) |
    (.database.primary.name // "") as $primary |
    .database.databases |=
      (unique_by(.name) |
       map(
         if .name == $primary
         then .role = "primary"
         else .role = "secondary"
         end
       ))
  ' || return 1
  chown root:root "$registry"
  chmod 0644 "$registry"
  success "Database sync complete for $domain"
}
db_auto_link_registry() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local expected
  expected=$(db_from_domain "$domain")
  if db_exists "$expected"; then
    registry_link_database "$domain" "$expected"
  else
    warn "Database not found in MySQL: $expected"
  fi
}
registry_get_db() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  jq -r '.database.databases[]? | select(.role == "primary") | .name' "${sitectl_dir}/${domain}.json"
}
registry_db_enabled() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  jq -r '.database.enabled' "${sitectl_dir}/${domain}.json"
}
registry_enable_db_ui() {
  local domain="$1"
  local registry type passfile
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  if [[ ! -f "$registry" ]]; then
    registry_create "$domain"
    [[ -f "$registry" ]] || return 0
  fi
  if [[ "$(jq -r '.database.enabled // false' "$registry")" != "true" ]]; then
    error "There is no enabled database for $domain."
    return 0
  fi
  resolve_type "$domain" || return 0
  if [[ "$type" == "apps/nodejs" ]]; then
    error "The embedded DB UI is not supported behind Node.js proxy vhosts."
    return 0
  fi
  passfile="$(jq -r '.database.password_file // empty' "$registry")"
  [[ -f "$passfile" ]] || {
    error "Primary DB password file is missing."
    return 0
  }
  install_adminer || return 0
  db_write_adminer_wrapper "$domain" || return 0
  registry_update "$domain" '.database.ui_enabled = true' || return 0
  success "$domain DB UI has been enabled"
}
registry_disable_db_ui() {
  local domain="$1"
  local registry token_file
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  [[ -f "$registry" ]] || {
    error "Registry missing."
    return 0
  }
  registry_update "$domain" '.database.ui_enabled = false' || return 0
  for token_file in "${db_manager_dir}/runtime/tokens/"*.json; do
    [[ -f "$token_file" ]] || continue
    if [[ "$(jq -r '.domain // empty' "$token_file" 2>/dev/null)" == "$domain" ]]; then
      rm -f "$token_file"
    fi
  done
  warn "$domain DB UI has been disabled"
}
install_adminer() {
  local adminer_version="6.1.1"
  local adminer_sha256="cd5d65d3e85c9e1233126625232150e2de405f3d56c76fdc171f4133a401e8d2"
  local adminer_url="https://github.com/vrana/adminer/releases/download/v${adminer_version}/adminer-${adminer_version}-mysql-en.php"
  local site_root="/etc/one-click/${type}/${domain}"
  local private_dir="${site_root}/private"
  local target="${private_dir}/adminer.php"
  local tmp meta
  meta="${site_root}/meta.conf"
  [[ -f "$meta" ]] || {
    error "Site metadata missing for $domain."
    return 1
  }
  mkdir -p "$private_dir"
  chmod 0755 "$private_dir"
  tmp="$(mktemp)"
  if ! curl -fL --retry 3 --retry-delay 2 "$adminer_url" -o "$tmp"; then
    rm -f "$tmp"
    error "Failed to download Adminer ${adminer_version}."
    return 1
  fi
  if ! printf '%s  %s\n' "$adminer_sha256" "$tmp" | sha256sum -c - >/dev/null 2>&1; then
    rm -f "$tmp"
    error "Adminer ${adminer_version} checksum validation failed."
    return 1
  fi
  local adminer_php
  adminer_php="$(site_php_cli_bin "$domain" 2>/dev/null || command -v php)"
  if ! "$adminer_php" -l "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    error "Downloaded Adminer ${adminer_version} failed PHP syntax validation."
    return 1
  fi
  install -o root -g root -m 0644 "$tmp" "$target"
  rm -f "$tmp"
  rm -f \
    "${site_root}/www/db/adminer.php" \
    "${site_root}/www/db/adminer-disabled.php" \
    "${site_root}/www/db"/adminer-[0-9]*.php \
    2>/dev/null || true
  if grep -q '^ADMINER_VERSION=' "$meta"; then
    sed -i "s|^ADMINER_VERSION=.*|ADMINER_VERSION=$adminer_version|" "$meta"
  else
    echo "ADMINER_VERSION=$adminer_version" >> "$meta"
  fi
  if grep -q '^ADMINER_FILE=' "$meta"; then
    sed -i "s|^ADMINER_FILE=.*|ADMINER_FILE=$target|" "$meta"
  else
    echo "ADMINER_FILE=$target" >> "$meta"
  fi
  adminer_file="$target"
  export adminer_file
  success "Adminer ${adminer_version} installed privately for $domain."
}
db_generate_password() {
  openssl rand -base64 32 | tr -d '\n'
}
db_password_file() {
  local domain="$1"
  echo "${db_manager_dir}/secrets/db/${domain}.pass"
}
db_user_password_file() {
  local domain="$1"
  local db_user="$2"
  echo "${db_manager_dir}/secrets/db-users/${domain}/${db_user}.pass"
}
db_write_password() {
  local domain="$1"
  local password="$2"
  local type meta site_user passfile
  domain="$(normalize_domain "$domain")"
  resolve_type "$domain" || return 1
  meta="/etc/one-click/${type}/${domain}/meta.conf"
  [[ -f "$meta" ]] || {
    error "Site metadata missing for $domain."
    return 1
  }
  . "$meta"
  site_user="${SITE_USER:-}"
  [[ -n "$site_user" ]] && id "$site_user" >/dev/null 2>&1 || {
    error "Unable to resolve the isolated site user for $domain."
    return 1
  }
  passfile="$(db_password_file "$domain")"
  mkdir -p "$(dirname "$passfile")"
  chown root:root "${db_manager_dir}/secrets" "$(dirname "$passfile")"
  chmod 0711 "${db_manager_dir}/secrets" "$(dirname "$passfile")"
  umask 077
  printf '%s' "$password" > "$passfile" || return 1
  chown "$site_user":root "$passfile"
  chmod 0400 "$passfile"
}
db_write_user_password() {
  local domain="$1"
  local db_user="$2"
  local password="$3"
  local type meta site_user passfile user_dir
  domain="$(normalize_domain "$domain")"
  resolve_type "$domain" || return 1
  meta="/etc/one-click/${type}/${domain}/meta.conf"
  [[ -f "$meta" ]] || {
    error "Site metadata missing for $domain."
    return 1
  }
  . "$meta"
  site_user="${SITE_USER:-}"
  [[ -n "$site_user" ]] && id "$site_user" >/dev/null 2>&1 || {
    error "Unable to resolve the isolated site user for $domain."
    return 1
  }
  user_dir="${db_manager_dir}/secrets/db-users/${domain}"
  passfile="$(db_user_password_file "$domain" "$db_user")"
  mkdir -p "$user_dir"
  chown root:root "${db_manager_dir}/secrets" "${db_manager_dir}/secrets/db-users" "$user_dir"
  chmod 0711 "${db_manager_dir}/secrets" "${db_manager_dir}/secrets/db-users" "$user_dir"
  umask 077
  printf '%s' "$password" > "$passfile" || return 1
  chown "$site_user":root "$passfile"
  chmod 0400 "$passfile"
}
db_create_user() {
  local domain="$1"
  local registry db_name db_user password user_secret current_primary role meta promote
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  [[ -f "$registry" ]] || {
    error "Registry missing"
    return 1
  }
  db_name="$(jq -r '.database.primary.name // empty' "$registry")"
  [[ -n "$db_name" ]] || db_name="$(db_from_domain "$domain")"
  db_exists "$db_name" || {
    error "Database does not exist: $db_name"
    return 1
  }
  db_user="$(db_generate_user)"
  password="$(db_generate_password)"
  current_primary="$(jq -r '.database.primary.user // empty' "$registry")"
  if [[ -z "$current_primary" ]]; then
    role="primary"
  else
    role="secondary"
  fi
  mysql <<EOF
CREATE USER IF NOT EXISTS '${db_user}'@'localhost'
IDENTIFIED BY '${password//\'/\'\'}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
EOF
  if [[ $? -ne 0 ]]; then
    error "Failed to create DB user"
    return 1
  fi
  db_write_user_password "$domain" "$db_user" "$password" || {
    mysql -e "DROP USER IF EXISTS '${db_user}'@'localhost';" >/dev/null 2>&1 || true
    return 1
  }
  registry_update "$domain" \
    --arg user "$db_user" \
    --arg role "$role" \
    --arg db "$db_name" \
    --arg current_primary "$current_primary" '
      .database.enabled = true |
      .database.users //= [] |
      .database.users |=
        (map(
          if type == "string"
          then {"name": ., "role": (if . == $current_primary then "primary" else "secondary" end)}
          else .
          end
        )) |
      .database.users |=
        (map(select(.name != $user)) + [{"name": $user, "role": $role}]) |
      .database.databases //= [] |
      if any(.database.databases[]?; .name == $db) then .
      else .database.databases += [{"name": $db, "role": "primary"}]
      end |
      if $role == "primary" then
        .database.primary.user = $user |
        .database.primary.name = $db |
        .database.users |= map(
          if .name == $user then .role = "primary"
          else .role = "secondary"
          end
        )
      else .
      end
    ' || return 1
  if [[ "$role" == "primary" ]]; then
    db_write_password "$domain" "$password" || return 1
    resolve_type "$domain" || return 1
    meta="/etc/one-click/${type}/${domain}/meta.conf"
    if grep -q '^DB_USER=' "$meta"; then
      sed -i "s|^DB_USER=.*|DB_USER=$db_user|" "$meta"
    else
      echo "DB_USER=$db_user" >> "$meta"
    fi
    success "Primary DB user created: $db_user"
    return 0
  fi
  success "Secondary DB user created: $db_user"
  read -rp "${cyan}[USER]${reset} Promote $db_user to primary DB user for $domain? (y|n): " promote
  promote="${promote,,}"
  if [[ "$promote" == "y" || "$promote" == "yes" ]]; then
    db_set_primary_user "$domain" "$db_user"
  fi
}
db_create_database() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local db_name
  db_name=$(db_from_domain "$domain")
  mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${db_name}\`;
EOF
  if [[ $? -ne 0 ]]; then
    error "Failed to create database"
    return 1
  fi
  jq --arg db "$db_name" '
    .database.enabled = true |
    .database.engine = "mariadb" |
    .database.primary.name = $db
  ' "$registry" > "$registry.tmp" \
    && mv "$registry.tmp" "$registry"
  registry_link_database "$domain" "$db_name" "mariadb"
  success "Database created: $db_name"
}
db_write_adminer_wrapper() {
  local domain="$1"
  local type meta root webroot wrapper adminer_path
  domain="$(normalize_domain "$domain")"
  resolve_type "$domain" || return 1
  root="/etc/one-click/${type}/${domain}"
  meta="${root}/meta.conf"
  webroot="${root}/www"
  wrapper="${webroot}/db/index.php"
  [[ -f "$meta" ]] || {
    error "Site metadata missing for $domain."
    return 1
  }
  . "$meta"
  adminer_path="${ADMINER_FILE:-${root}/private/adminer.php}"
  [[ -f "$adminer_path" ]] || {
    error "Private Adminer runtime missing for $domain."
    return 1
  }
  mkdir -p "${webroot}/db"
  cat > "$wrapper" <<EOF
<?php
ini_set('display_errors', '0');
error_reporting(E_ALL);

\$secureCookie = !empty(\$_SERVER['HTTPS']) && \$_SERVER['HTTPS'] !== 'off';
if (session_status() === PHP_SESSION_NONE) {
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'secure' => \$secureCookie,
        'httponly' => true,
        'samesite' => 'Strict'
    ]);
    session_start();
}

\$currentDomain = ${domain@Q};
\$registryFile = '/etc/one-click/db-manager/sites/' . \$currentDomain . '.json';
\$adminerFile = ${adminer_path@Q};

if (!is_file(\$registryFile)) {
    http_response_code(500);
    exit('Registry missing');
}

\$registry = json_decode(file_get_contents(\$registryFile), true);
if (!is_array(\$registry)) {
    http_response_code(500);
    exit('Registry decode failed');
}

if (!(bool)(\$registry['database']['ui_enabled'] ?? false)) {
    session_unset();
    session_destroy();
    http_response_code(403);
    exit('UI Disabled');
}

\$dbUser = (string)(\$registry['database']['primary']['user'] ?? '');
\$dbName = (string)(\$registry['database']['primary']['name'] ?? '');
\$passwordFile = (string)(\$registry['database']['password_file'] ?? '');

if (\$dbUser === '' || \$dbName === '' || \$passwordFile === '' || !is_file(\$passwordFile)) {
    http_response_code(500);
    exit('Database credentials incomplete');
}

if (isset(\$_GET['token'])) {
    \$token = (string)\$_GET['token'];

    if (!preg_match('/^[a-f0-9]{64}$/', \$token)) {
        http_response_code(403);
        exit('Invalid token format');
    }

    \$tokenFile = '/etc/one-click/db-manager/runtime/tokens/' . \$token . '.json';
    if (!is_file(\$tokenFile)) {
        http_response_code(403);
        exit('Invalid token');
    }

    \$data = json_decode(file_get_contents(\$tokenFile), true);
    if (!is_array(\$data) ||
        strcasecmp((string)(\$data['domain'] ?? ''), \$currentDomain) !== 0 ||
        (int)(\$data['expires'] ?? 0) < time()) {
        @unlink(\$tokenFile);
        http_response_code(403);
        exit('Token expired or invalid');
    }

    \$_SESSION['oneclick_db_auth'] = \$currentDomain;
    \$_SESSION['oneclick_db_ip'] = \$_SERVER['REMOTE_ADDR'] ?? '';
    \$_SESSION['oneclick_db_ua'] = \$_SERVER['HTTP_USER_AGENT'] ?? '';
    \$_SESSION['oneclick_db_last_activity'] = time();
    session_regenerate_id(true);
    @unlink(\$tokenFile);

    unset(\$_GET['token']);
}

\$timeout = 1800;
\$last = (int)(\$_SESSION['oneclick_db_last_activity'] ?? 0);
if (\$last > 0 && (time() - \$last) > \$timeout) {
    session_unset();
    session_destroy();
    http_response_code(403);
    exit('Session expired');
}

\$authorized =
    (\$_SESSION['oneclick_db_auth'] ?? '') === \$currentDomain &&
    (\$_SESSION['oneclick_db_ip'] ?? '') === (\$_SERVER['REMOTE_ADDR'] ?? '') &&
    (\$_SESSION['oneclick_db_ua'] ?? '') === (\$_SERVER['HTTP_USER_AGENT'] ?? '');

if (!\$authorized) {
    http_response_code(403);
    exit('Unauthorized');
}

\$_SESSION['oneclick_db_last_activity'] = time();

\$password = trim(file_get_contents(\$passwordFile));

function adminer_object() {
    class OneClickAdminer extends Adminer\Adminer {
        private \$registry;

        public function __construct() {
            global \$registry;
            \$this->registry = \$registry;
        }

        public function credentials() {
            global \$password;
            return [
                'localhost',
                (string)\$this->registry['database']['primary']['user'],
                \$password
            ];
        }

        public function database() {
            return (string)\$this->registry['database']['primary']['name'];
        }

        public function login(\$login, \$password) {
            return hash_equals(
                (string)\$this->registry['database']['primary']['user'],
                (string)\$login
            );
        }

        public function name() {
            global \$currentDomain;
            return 'One-Click DB Manager (' . \$currentDomain . ')';
        }
    }

    return new OneClickAdminer();
}

/*
 * Bootstrap through Adminer's own login path on the first authenticated request.
 * Later Adminer requests keep the session created by Adminer itself.
 */
if (!isset(\$_GET['username']) && \$_SERVER['REQUEST_METHOD'] === 'GET') {
    \$_GET['username'] = \$dbUser;
    \$_GET['db'] = \$dbName;
    \$_POST['auth'] = [
        'driver' => 'server',
        'server' => 'localhost',
        'username' => \$dbUser,
        'password' => \$password,
        'db' => \$dbName,
        'permanent' => 0
    ];
    if (!isset(\$_SESSION['token'])) {
        \$_SESSION['token'] = random_int(100000, 999999999);
    }
    \$_POST['token'] = \$_SESSION['token'];
}

if (!is_file(\$adminerFile)) {
    http_response_code(500);
    exit('Adminer runtime missing');
}

require \$adminerFile;
EOF
  chmod 0644 "$wrapper"
}
db_list_database_users() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  DB_USER_LIST=()
  local db_name
  db_name=$(jq -r '.database.databases[]? | select(.role == "primary") | .name // empty' "$registry")
  [[ -z "$db_name" ]] && { error "No DB linked"; return 1; }
  local users
  users=$(
    mysql -N -B -e "
      SELECT DISTINCT GRANTEE
      FROM information_schema.schema_privileges
      WHERE TABLE_SCHEMA='${db_name}';
    " 2>/dev/null | sed "s/'//g" | cut -d@ -f1
  )
  printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
  printf "${blue}║${reset}  ${magenta}DATABASE USERS:${orange} %-51s ${blue}║${reset}\n" "$domain"
  printf "${blue}╠══════════════════════════════════════════════════════════════════════╣${reset}\n"
  local i=1
  while read -r user; do
    [[ -z "$user" ]] && continue
    DB_USER_LIST[$i]="$user"
    printf "${blue}║${reset} ${magenta}%2d${blue} ║ %-63s ${blue}║${reset}\n" \
      "$i" "$user"
    ((i++))
  done <<< "$users"
  printf "${blue}╚════╩═════════════════════════════════════════════════════════════════╝${reset}\n"
}
db_get_user_by_index() {
  local index="$1"
  if [[ -z "$index" ]]; then
    return 1
  fi
  echo "${DB_USER_LIST[$index]}"
}
db_set_primary_user() {
  local domain="$1"
  local db_user="$2"
  local registry db_name user_exists user_secret password meta
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  [[ -f "$registry" ]] || {
    error "Registry missing"
    return 1
  }
  [[ -n "$db_user" ]] || {
    error "Database user required"
    return 1
  }
  user_exists="$(mysql -N -B -e "SELECT User FROM mysql.user WHERE User='${db_user}' AND Host='localhost' LIMIT 1;" 2>/dev/null)"
  [[ "$user_exists" == "$db_user" ]] || {
    error "Database user does not exist: $db_user"
    return 1
  }
  db_name="$(jq -r '.database.primary.name // empty' "$registry")"
  [[ -n "$db_name" ]] || {
    error "Primary database is not configured."
    return 1
  }
  user_secret="$(db_user_password_file "$domain" "$db_user")"
  [[ -f "$user_secret" ]] || {
    error "Stored password for $db_user is unavailable. Promotion refused."
    return 1
  }
  password="$(<"$user_secret")"
  registry_update "$domain" --arg user "$db_user" '
    .database.users //= [] |
    .database.users |= map(
      if type == "string" then
        {"name": ., "role": (if . == $user then "primary" else "secondary" end)}
      elif .name == $user then .role = "primary"
      else .role = "secondary"
      end
    ) |
    if any(.database.users[]?; .name == $user) then .
    else .database.users += [{"name": $user, "role": "primary"}]
    end |
    .database.primary.user = $user
  ' || return 1
  db_write_password "$domain" "$password" || return 1
  resolve_type "$domain" || return 1
  meta="/etc/one-click/${type}/${domain}/meta.conf"
  if grep -q '^DB_USER=' "$meta"; then
    sed -i "s|^DB_USER=.*|DB_USER=$db_user|" "$meta"
  else
    echo "DB_USER=$db_user" >> "$meta"
  fi
  success "Primary DB user updated: $db_user"
}
db_list_user_databases_raw() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  jq -r '
    (.database.databases // [])[] |
    .name
  ' "$registry"
}
db_bootstrap_site() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  db_create_database "$domain" || return 1
  db_create_user "$domain" || return 1
  local primary_user
  primary_user=$(jq -r '
    .database.users[0].name // empty
  ' "$registry")
  [[ -n "$primary_user" ]] && \
    db_set_primary_user "$domain" "$primary_user"
  success "DB bootstrap complete"
}
db_generate_token() {
  openssl rand -hex 32
}
db_token_file() {
  local token="$1"
  echo "/etc/one-click/db-manager/runtime/tokens/${token}.json"
}
db_create_login_token() {
  local domain="$1"
  local registry token expires token_file type meta site_user
  domain="$(normalize_domain "$domain")"
  registry="${sitectl_dir}/${domain}.json"
  [[ -f "$registry" ]] || {
    error "Registry missing"
    return 1
  }
  [[ "$(jq -r '.database.ui_enabled // false' "$registry")" == "true" ]] || {
    error "Database UI is disabled for $domain."
    return 1
  }
  resolve_type "$domain" || return 1
  meta="/etc/one-click/${type}/${domain}/meta.conf"
  . "$meta"
  site_user="${SITE_USER:-}"
  [[ -n "$site_user" ]] && id "$site_user" >/dev/null 2>&1 || {
    error "Unable to resolve the site runtime user."
    return 1
  }
  token="$(db_generate_token)"
  expires=$(( $(date +%s) + 1800 ))
  token_file="$(db_token_file "$token")"
  mkdir -p "$(dirname "$token_file")"
  chown root:root "$(dirname "$token_file")"
  chmod 0711 "$(dirname "$token_file")"
  cat > "$token_file" <<EOF
{
  "domain": "$domain",
  "expires": $expires
}
EOF
  chown "$site_user":root "$token_file"
  chmod 0400 "$token_file"
  printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
  printf "${blue}║${reset}  ${yellow}ACCESS TOKEN GENERATED${reset} %-44s ${blue}║${reset}\n" ""
  printf "${blue}╠══════════════════════════════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${cyan}DOMAIN:${reset}  %-59s ${blue}║${reset}\n" "$domain"
  printf "${blue}║${reset} ${cyan}EXPIRES:${reset} %-59s ${blue}║${reset}\n" "$(date -d "@$expires" 2>/dev/null || echo "$expires")"
  printf "${blue}╠══════════════════════════════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${cyan}LOGIN URL:${reset} %-57s ${blue}║${reset}\n" ""
  printf "${blue}║${reset} ${orange}\e[40m https://${domain}/db/?token=${token} \e[0m ${blue}║${reset}\n"
  printf "${blue}╚══════════════════════════════════════════════════════════════════════╝${reset}\n"
}
db_user_exists() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local db_user="$2"
  if [[ -z "$domain" || -z "$db_user" ]]; then
    return 1
  fi
  if [[ ! -f "$registry" ]]; then
    return 1
  fi
  local db_name
  db_name=$(jq -r '.database.databases[]? | select(.role == "primary") | .name // empty' "$registry")
  if [[ -z "$db_name" ]]; then
    return 1
  fi
  mysql -N -B -e "
    SELECT GRANTEE
    FROM information_schema.schema_privileges
    WHERE TABLE_SCHEMA='${db_name}';
  " 2>/dev/null | \
  sed "s/\'//g" | \
  cut -d@ -f1 | \
  grep -Fxq "$db_user"
}
db_discover_all() {
  mysql -Nse "SHOW DATABASES;" 2>/dev/null
}
db_resolve_user_index() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local index="$2"
  local user="${DB_USER_LIST[$index]}"
  if [[ -z "$user" ]]; then
    return 1
  fi
  echo "$user"
}
wp_detect() {
  local wp_base="$1"
  if [[ -f "$wp_base/wp-config.php" ]] && \
     [[ -d "$wp_base/www/wp-content" ]] && \
     [[ -d "$wp_base/www/wp-includes" ]]; then
      warn "WordPress site detected"
    return 0
  fi
  warn "${type^} site detected"
}
registry_detect_wordpress() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  . /etc/one-click/${type}/${domain}/meta.conf || . /etc/one-click/apps/${type}/${domain}/meta.conf
  local root
  wp_base="/etc/one-click/wordpress/$domain"
  if [[ -f "$wp_base" ]]; then
    success "Wordpress site detected for $domain"
    return
  fi
  if [[ -f skip_reg_check ]]; then
    rm -f skip_reg_check
    return
  fi
  if wp_detect "$wp_base"; then
    local tmpfile
    tmpfile=$(mktemp)
    jq '.wordpress.detected = true' \
      "${sitectl_dir}/${domain}.json" > "$tmpfile" || {
        rm -f "$tmpfile"
        error "WordPress detection failed"
        return 1
      }
    mv "$tmpfile" "${sitectl_dir}/${domain}.json"
    chown "$SITE_USER":"$SITE_GROUP" "$registry"
    success "${type:-$type_ver} detected for $domain"
    return 0
  fi
  jq '.wordpress.detected = false' \
    "${sitectl_dir}/${domain}.json" > /dev/null
  return 1
}
db_show_credentials() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  if [[ ! -f "$registry" ]]; then
    error "Registry not found for $domain"
    return 1
  fi
  read -rp "${cyan}[USER]${reset} Reveal DB password for $domain? (y|n): " confirm
  [[ "$confirm" != "y" ]] && return
  local db_user db_name passfile password host
  db_user=$(jq -r '.database.primary.user // empty' "$registry")
  db_name=$(jq -r '.database.primary.name // empty' "$registry")
  passfile=$(jq -r '.database.password_file // empty' "$registry")
  if [[ -z "$db_user" || -z "$db_name" || -z "$passfile" ]]; then
    error "Incomplete database configuration"
    return 1
  fi
  if [[ ! -f "$passfile" ]]; then
    error "Password file missing: $passfile"
    return 1
  fi
  password=$(<"$passfile")
  host="localhost"
  echo
  printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
  printf "${blue}║${reset}  ${magenta}DATABASE CREDENTIALS:${reset} %-45s ${blue}║${reset}\n" "$domain"
  printf "${blue}╠══════════════════════╦═══════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${cyan}DATABASE:${reset} %-10s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$db_name"
  printf "${blue}║${reset} ${cyan}USER:${reset} %-14s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$db_user"
  printf "${blue}║${reset} ${cyan}HOST:${reset} %-14s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$host"
  printf "${blue}╠══════════════════════╩═══════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${yellow}PASSWORD:${reset} %-58s ${blue}║${reset}\n" \
    "$password"
  printf "${blue}╚══════════════════════════════════════════════════════════════════════╝${reset}\n"
}
pause() {
  echo
  read -rp "${cyan}[USER]${reset} Press Enter to continue..."
}
db_manager_menu() {
  domain="$1"
  domain="$(normalize_domain "$domain")"
  type="$2"
  registry=${sitectl_dir}/${domain}.json
  if [[ -f "$registry" ]]; then
    registry_sync_databases "$domain" || true
    registry_detect_wordpress "$domain" || true
  else
    warn "Registry not generated for $domain."
    info "Open Registry Management and select [1] Create Site Registry."
  fi
  while true; do
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK DB XPRESS${blue}                         ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Database UI${blue}                                           ║" \
      "║ ${magenta}2${blue}  ║ ${green}Database Management${blue}                                   ║" \
      "║ ${magenta}3${blue}  ║ ${green}Registry Management${blue}                                   ║" \
      "║ ${magenta}4${blue}  ║ ${green}Registry Queries${blue}                                      ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option [0-4]: " choice
    case "$choice" in
      1) db_ui_menu    ;;
      2) database_menu ;;
      3) registry_menu ;;
      4) query_menu    ;;
      0) break         ;;
      *) error "Invalid option" ;;
    esac
  done
}
db_ui_menu() {
  if [[ ! -f /etc/one-click/db-manager/sites/${domain}.json ]]; then
    warn "Registry not generated"
    info "Generating registry now."
    registry_create "$domain"
  fi
  db_status=$(jq -r '.database.enabled' /etc/one-click/db-manager/sites/${domain}.json)
  if [[ "$db_status" != "true" ]]; then
    error "There is no database for $domain."
    return
  fi
  while true; do
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}DB UI Management${blue}                            ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Enable Database UI${blue}                                    ║" \
      "║ ${magenta}2${blue}  ║ ${green}Disable Database UI${blue}                                   ║" \
      "║ ${magenta}3${blue}  ║ ${green}Generate Login Token${blue}                                  ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option: " choice
    case "$choice" in
      1)
        registry_enable_db_ui "$domain"
        pause
        ;;
      2)
        registry_disable_db_ui "$domain"
        pause
        ;;
      3)
        db_create_login_token "$domain"
        pause
        ;;
      0)
        return
        ;;
      *)
        error "Invalid option"
        pause
        ;;
    esac
  done
}
query_menu() {
  while true; do
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}Registry Queries${blue}                           ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}List All Sites${blue}                                        ║" \
      "║ ${magenta}2${blue}  ║ ${green}List Wordpress Sites${blue}                                  ║" \
      "║ ${magenta}3${blue}  ║ ${green}List DB Enabled Sites${blue}                                 ║" \
      "║ ${magenta}4${blue}  ║ ${green}List Active Sites${blue}                                     ║" \
      "║ ${magenta}5${blue}  ║ ${green}List Sites By PHP Versions${blue}                            ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option: " choice
    case "$choice" in
      1)
        registry_list_all
        pause
        ;;
      2)
        registry_list_wordpress
        pause
        ;;
      3)
        registry_list_db_enabled
        pause
        ;;
      4)
        registry_list_active
        pause
        ;;
      5)
        read -rp "${cyan}[USER]${reset} Which PHP Version: " version
        registry_list_php_version "$version"
        pause
        ;;
      0)
        return
        ;;
      *)
        error "Invalid option"
        pause
        ;;
    esac
  done
}
database_menu() {
  while true; do
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}Database Management${blue}                         ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}List Databases${blue}                                        ║" \
      "║ ${magenta}2${blue}  ║ ${green}Create Database${blue}                                       ║" \
      "║ ${magenta}3${blue}  ║ ${green}Create Database User${blue}                                  ║" \
      "║ ${magenta}4${blue}  ║ ${green}Promote Database User${blue}                                 ║" \
      "║ ${magenta}5${blue}  ║ ${green}Bootsrap Site Database${blue}                                ║" \
      "║ ${magenta}6${blue}  ║ ${green}Link Database${blue}                                         ║" \
      "║ ${magenta}7${blue}  ║ ${green}Show Database Status${blue}                                  ║" \
      "║ ${magenta}8${blue}  ║ ${green}View Database Credentials${blue}                             ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option: " choice
      case "$choice" in
        1)
          db_list_user_databases "$domain"
          pause
          ;;
        2)
          db_create_database "$domain"
          pause
          ;;
        3)
          db_create_user "$domain"
          pause
          ;;
        4)
          db_list_database_users "$domain"
          while true; do
            read -rp "${cyan}[USER]${reset} Select user number to promote: " selection
            if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
              warn "Only numeric selection allowed"
              continue
            fi
            promote_name=$(db_resolve_user_index "$domain" "$selection")
            if [[ -z "$promote_name" ]]; then
              warn "Invalid selection index"
              continue
            fi
            break
          done
          db_set_primary_user "$domain" "$promote_name"
          pause
          ;;
        5)
          db_bootstrap_site "$domain"
          pause
          ;;
        6)
          db_list_user_databases "$domain"
          read -rp "${cyan}[USER]${reset} Database Name: " db_name
          registry_link_database "$domain" "$db_name"
          pause
          ;;
        7)
          printf '%s\n' " " \
            "DB Enabled : $(registry_db_enabled "$domain")" \
            "DB Name    : $(registry_get_db "$domain")" " "
          pause
          ;;
        8) db_show_credentials "$domain" ;;
        0)
          return
          ;;
        *)
          error "Invalid option"
          pause
          ;;
    esac
  done
}
registry_menu() {
  while true; do
    if [[ ! -f "${sitectl_dir}/${domain}.json" ]]; then
      warn "Registry not generated for $domain."
      info "Select [1] Create Site Registry to generate it."
    fi
    printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}Registry Management${blue}                         ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Create Site Registry${blue}                                  ║" \
      "║ ${magenta}2${blue}  ║ ${green}Show Site Registry${blue}                                    ║" \
      "║ ${magenta}3${blue}  ║ ${green}Validate Registry${blue}                                     ║" \
      "║ ${magenta}4${blue}  ║ ${green}Delete Registry${blue}                                       ║" \
      "║ ${magenta}5${blue}  ║ ${green}List Registries${blue}                                       ║" \
      "║ ${magenta}6${blue}  ║ ${green}Add Alias${blue}                                             ║" \
      "║ ${magenta}7${blue}  ║ ${green}Set Site Status${blue}                                       ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option: " choice
    case "$choice" in
    1)
      registry_create "$domain"
      pause
      ;;
    2)
      registry_show "$domain"
      pause
      ;;
    3)
      registry_validate "$domain"
      pause
      ;;
    4)
      registry_delete "$domain"
      pause
      ;;
    5)
      registry_list_detailed
      pause
      ;;
    6)
      while true; do
      read -rp "${cyan}[USER]${reset} Please provide a space separated list of additional domains for ${domain}: " aliases
      if [[ -z "$aliases" ]]; then
        warn "At least one alias is required"
        continue
      fi
      local invalid=0
      local alias
      for alias in $aliases; do
        if [[ ! "$alias" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
          warn "Invalid domain: $alias"
          invalid=1
        fi
      done
      [[ $invalid -eq 0 ]] && break
      done
      registry_add_alias "$domain" "$aliases"
      pause
      ;;
    7)
      local current_status
      current_status=$(registry_get_field "$domain" '.site.status')
      local new_status
      if [[ "$current_status" == "active" ]]; then
        new_status="disabled"
      else
        new_status="active"
      fi
      registry_set_status "$domain" "$new_status"
      success "$domain status changed to: $new_status"
      pause
      ;;
    8)
      read -rp "${cyan}[USER]${reset} Enter PHP Version to set: " version
      registry_set_php_version "$domain" "$version"
      pause
      ;;
    0)
      return
      ;;
    *)
      error "Invalid option"
      pause
      ;;
    esac
  done
}
db_entry() {
  select_domain
  if [[ -d /etc/one-click/sites/${domain}/ && -d /etc/one-click/wordpress/${domain}/ ]]; then
    info "$domain was found in both wordpress and static site directories."
    echo "${cyan}[USER]${reset} Select site type:"
    while true; do
      printf "${cyan}[USER]${reset}%s${cyan}]${reset} %s\n" \
        "1" "WordPress" \
        "2" "Static Site"
      read -rp "${cyan}[USER]${reset}Choice: " choice
      case "$choice" in
        1) type="wordpress"; break ;;
        2) type="sites"; break     ;;
        *) error "Invalid choice"  ;;
      esac
    done
  elif [[ -d /etc/one-click/wordpress/${domain}/ ]]; then
    type="wordpress"
  elif [[ -d /etc/one-click/apps/nodejs/${domain}/ ]]; then
    type="nodejs"
  elif [[ -d /etc/one-click/nextcloud/${domain}/ ]]; then
    type="nextcloud"
  else
    type="sites"
  fi
  db_manager_menu "$domain" "$type"
}
############################ CLEANUP ###############################
cleanup_failed_provision() {
  local exit_code=$?
  provision_success=$1
  type=$2
  if [[ "${ONECLICK_CLEANUP_DONE:-0}" -eq 1 ]]; then
    return "$exit_code"
  fi
  ONECLICK_CLEANUP_DONE=1
  trap - EXIT INT TERM ERR
  [[ "$exit_code" -eq 0 && "$provision_success" -eq 1 ]] && return 0
  warn "Provisioning failed or interrupted for '$domain' (Exit code: $exit_code). Purging partial footprint."
  if [[ -n "${PHP_SYSTEMD_SERVICE_NAME:-}" ]]; then
    systemctl disable --now "$PHP_SYSTEMD_SERVICE_NAME" 2>/dev/null || true
    rm -f "${PHP_SYSTEMD_VHOST:-/etc/systemd/system/${PHP_SYSTEMD_SERVICE_NAME}}" 2>/dev/null || true
  fi
  systemctl disable --now "redis-${domain}" 2>/dev/null || true
  rm -f     "${REDIS_CONF:-}"     "${REDIS_PASS_FILE:-}"     "/etc/one-click/redis/${domain}.conf"     "/etc/one-click/redis/${domain}.pass"     "/etc/redis/one-click/${domain}.conf"     "/etc/valkey/one-click/${domain}.conf"     "/run/redis/one-click-${domain}.sock"     "/run/valkey/one-click-${domain}.sock"     "/run/redis/redis-${domain}.sock"     "/run/valkey/redis-${domain}.sock"     "/run/one-click-redis-${domain}/redis.sock"     2>/dev/null || true
  rm -rf     "${REDIS_DATA_DIR:-}"     "/var/lib/one-click/redis/${domain}"     "/var/lib/redis/one-click/${domain}"     "/var/lib/valkey/one-click/${domain}"     "/run/one-click-redis-${domain}"     2>/dev/null || true
  systemctl stop "one-click_${domain}.slice" 2>/dev/null || true
  rm -f "/etc/systemd/system/one-click_${domain}.slice" \
    "/etc/systemd/system/redis-${domain}.service" 2>/dev/null || true
  if [[ "$type" == "wordpress" ]]; then
    # Only resources created in THIS provisioning attempt may be dropped.
    if [[ -n "${ONECLICK_WP_CREATED_DB:-}" ]]; then
      mysql -e "DROP DATABASE IF EXISTS \`$ONECLICK_WP_CREATED_DB\`;" 2>/dev/null || true
    fi
    if [[ -n "${ONECLICK_WP_CREATED_DB_USER:-}" ]]; then
      mysql -e "DROP USER IF EXISTS '$ONECLICK_WP_CREATED_DB_USER'@'localhost';" 2>/dev/null || true
    fi
  elif [[ "${DB_ENABLED:-false}" == "true" || -n "${DB_NAME:-}" ]]; then
    if [[ -n "${DB_NAME:-}" ]]; then
      info "Dropping partial database: $DB_NAME"
      mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null || true
    fi
    if [[ -n "${DB_USER:-}" ]]; then
      info "Dropping partial DB user: $DB_USER"
      mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null || true
    fi
  fi
  if [[ -n "${VHOST:-}" && -f "$VHOST" ]]; then
    rm -f "$VHOST" "/etc/nginx/sites-enabled/$domain.conf" \
      "/etc/apache2/sites-enabled/$domain.conf" 2>/dev/null || true
    systemctl reload "${WEBSERVER:-nginx}" 2>/dev/null || true
  fi
  if [[ -n "${HOSTS_ENTRY:-}" ]]; then
    sed -i "/${domain}/d" /etc/hosts 2>/dev/null || true
  fi
  rm -rf "${PHP_DIR:-/etc/one-click/php/$domain}" 2>/dev/null || true
  rm -rf "${PHP_RUNTIME:-/run/one-click/$domain}" 2>/dev/null || true
  rm -rf "${PHP_LIB_DIR:-/var/lib/one-click/$domain}" 2>/dev/null || true
  rm -rf "/etc/one-click/${type}/$domain" 2>/dev/null || true
  rm -f "/var/log/one-click/${domain}/php/error.log" 2>/dev/null || true
  if [[ -n "${SITE_USER:-}" ]] && id "$SITE_USER" &>/dev/null &&
     { [[ "$type" != "wordpress" ]] || [[ "${ONECLICK_WP_CREATED_USER:-0}" == "1" ]]; }; then
    info "Removing provisioned system user: $SITE_USER"
    gpasswd -d "${SITE_GROUP:-www-data}" "$SITE_USER" 2>/dev/null || true
    printf "$(tput setaf 192)[DEL]:${reset} "
    userdel -r -f "$SITE_USER" 2>/dev/null || true
  fi
  systemctl daemon-reload 2>/dev/null || true
  systemctl reset-failed 2>/dev/null || true
  error "${type^} cleanup complete for '$domain'."
  return "$exit_code"
}
################################# CRON NAVIGATION ##############################
if [[ "${1:-}" == "-remoteback" ]]; then
  cron_domain="${2:-}"
  cron_type="${3:-}"
  case "$cron_type" in
    wordpress)
      config_dir="/etc/one-click/wordpress/config"
      ;;
    static|sites)
      config_dir="/etc/one-click/sites/config"
      cron_type="static"
      ;;
    *)
      error "Unsupported scheduled remote backup type: ${cron_type:-unset}"
      exit 1
      ;;
  esac
  profiles_file="$config_dir/remotes.conf"
  map_file="$config_dir/domain_map.conf"
  current_profile_file="$config_dir/current_profile"
  mkdir -p "$config_dir"
  touch "$profiles_file" "$map_file"
  ensure_local_profile
  remote_backup "$cron_domain" "$cron_type"
  exit $?
fi
if [[ "${1:-}" == "-wpback" ]]; then
  info() {
    printf "$(tput setaf 4)[INFO]:$(tput sgr 0) %s\n"
  }
  success() {
    printf "$(tput setaf 2)[SUCCESS]$(tput sgr 0) %s\n"
  }
  warn() {
    printf "$(tput setaf 11)[WARN]:$(tput sgr 0) %s\n"
  }
  error() {
    printf "$(tput setaf 1)[ERROR]:$(tput sgr 0)  %s\n"
  }
  wp_backup "${2:-}"
fi
if [[ "${1:-}" == "-wprotate" ]]; then
  wp_backup_rotate "${2:-}"
fi
if [[ "${1:-}" == "-staticback" ]]; then
  info() {
    printf "$(tput setaf 4)[INFO]:$(tput sgr 0) %s\n"
  }
  success() {
    printf "$(tput setaf 2)[SUCCESS]$(tput sgr 0) %s\n"
  }
  warn() {
    printf "$(tput setaf 11)[WARN]:$(tput sgr 0) %s\n"
  }
  error() {
    printf "$(tput setaf 1)[ERROR]:$(tput sgr 0)  %s\n"
  }
  static_backup "${2:-}"
fi
if [[ "${1:-}" == "-staticrotate" ]]; then
  static_backup_rotate "${2:-}"
fi
if [[ "${1:-}" == "--monitor-site" ]]; then
  get_monitor_stats "${2:-}"
fi
if [[ "${1:-}" == "--crawler" ]]; then
  sitemap_robots "${2:-}" "${3:-}"
fi
