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
# === Build: Jan 2026 === # === Updated: June 2026 == # == Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== WordPress ====
if [[ "$pkg_mgr" == "apt" ]]; then
  dig_pkg=dnsutils
  php_pkg="php"
else
  dig_pkg=bind-utils
  php_pkg="$(awk '$0 !~ /=/ {print $1}' <($pkg_mgr search php 2> /dev/null) | head -1)"
fi
if command -v install_dep &> /dev/null; then
  install_dep "php" "command -v php" "${php_pkg:-php-fpm}" "$pkg_mgr" true
  install_dep "git" "command -v git" "git" "$pkg_mgr" true
  install_dep "dig" "command -v dig" "$dig_pkg" "$pkg_mgr" true
  install_dep "bzip2" "command -v bzip2" "bzip2" "$pkg_mgr" true
fi
. /etc/os-release
base_dir="/etc/one-click"
config_dir="$base_dir/configuration"
db_manager_dir=/etc/one-click/db-manager
sitectl_dir="${db_manager_dir}/sites"
mkdir -p ${db_manager_dir}/{sites,runtime,logs,backups,cache,templates}
mkdir -p ${db_manager_dir}/runtime/{db,sessions,locks,temp}
mkdir -p ${db_manager_dir}/runtime/tokens
chmod 700 ${db_manager_dir}/runtime/tokens
chmod -R 755 ${db_manager_dir}
secret_key="/etc/one-click.backup_secret.key"
current_profile_file="$config_dir/current_profile"
webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
centos_ver=$(grep -Eo [0-9]+ /etc/centos-release 2> /dev/null || true)
app_dir="/etc/one-click/apps"
app_port_start=5000
app_port_end=5999
dns_api_root="/etc/one-click/dns"
dns_provider_root="${dns_api_root}/providers"
dns_domain_root="${dns_api_root}/domains"
dns_master_key="/etc/one-click/.dns.key"
mkdir -p "$dns_provider_root" "$dns_domain_root" "/etc/one-click"
if [[ -f /etc/cron.d/db-manager ]]; then
  */10 * * * * find /etc/one-click/db-manager/runtime/tokens -type f -mmin +30 -delete
fi
if [[ "$ID" == "debian" ]]; then
  php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
fi
dns_check() {
  dns=$(dig "$domain" +short @8.8.8.8 | tail -n1)
  dns_www=$(dig +short "www.$domain" | tail -n1)
  if [[ "$dns" != "$sys_ip" || "$dns" != "$sys_ipv6" ]]; then
    warn "Domain does not resolve to this server (${sys_ip:-${sys_ipv6}})"
  fi
}
resolve_type() {
  local domain="$1"
  local matches=()
  [[ -e "/etc/one-click/wordpress/$domain" ]] && matches+=("wordpress")
  [[ -e "/etc/one-click/sites/$domain" ]] && matches+=("sites")
  [[ -e "/etc/one-click/apps/nodejs/$domain" ]] && matches+=("apps/nodejs")
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
  #web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) 2> /dev/null | head -1)
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
  info "Archiving files..."
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
    info "Fetching remote backup from $profile_host..."
    run_rsync \
      "${profile_user}@${profile_host}:${profile_base}/${domain}/" \
      "$backup_dir/"
  fi
  info "Loading metadata..."
  . "$backup_dir/meta.conf" 2>/dev/null
  . "$base/$domain/meta.conf" 2>/dev/null

  info "Clearing current site directory..."
  find "$site_dir" -mindepth 1 -delete
  rm -f "$config_path"
  info "Restoring from $loc ($dest) -> $backup_dir"
  # ==== Restore files ====
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  # ==== Relocate wp-config ====
  if [[ -f "$site_dir/wp-config.php" ]]; then
    info "Relocating wp-config.php to secure parent directory..."
    mv "$site_dir/wp-config.php" "$config_path"
  fi
  # ==== Restore database ====
  info "Restoring database..."
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
  local domain
  domain="${domain:-}"
  cat <<EOF >/etc/cron.d/one-click-wp-backups
0 2 * * * root bash /var/cache/one-click/wordpress.sh -wpback $domain    #One-Click WP Backup
30 2 * * * root bash /var/cache/one-click/wordpress.sh -wprotate $domain #One-Click WP Rotate
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
                warn "${yellow}[*]${yellow} Removing automation..."
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
      9) check_permissions $domain ;;
      10)
        read -rp "${cyan}[USER]${reset} This action will delete the domain $domain."
        read -rp "${cyan}[USER]${reset} Are you sure you want to continue (y|n): " del_domain
        del_domain="${del_domain,,}"
        if [[ "$del_domain" != "y" && "$del_domain" != "yes" ]]; then
          error "Not progressing with domain deleteion of $domain"
        else
          if [[ -d /etc/one-click/wordpress/$domain ]]; then
            rm -rf /etc/one-click/wordpress/$domain
          else
            rm -rf /etc/one-click/sites/$domain
          fi
          rm -f /etc/nginx/conf.d/${domain}.conf
          rm -f /etc/nginx/sites-enabled/${domain}.conf
          rm -f /etc/nginx/sites-available/${domain}.conf
          rm -f /etc/httpd/conf.d/${domain}.conf
        fi
        ;;
      11) web_logs ;;
      0)
        error "Exiting..."
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
  if ! command -v wp >/dev/null 2>&1; then
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
  fi
}
# ==== Configure DB ====
install_db() {
  info "Updating System"
  "$pkg_mgr" -y update
  info "Installing dependencies"
  "$pkg_mgr" install -y \
   mariadb-server \
  php-fpm \
  php-posix \
  unzip \
  curl > /dev/null
}
configure_nc_db() {
  local nc_db="one_click:${domain//./-}:$(openssl rand -hex 4):$nc_db_user"
  echo "DB_NAME=$nc_db" >> /etc/one-click/nextcloud/$domain/meta.conf
  install_db
  systemctl enable mariadb --now
  mysql -e "CREATE DATABASE IF NOT EXISTS \`$nc_db\`;"
  user_exists=$(mysql -sN -e "SELECT 1 FROM mysql.user WHERE user='$nc_db_user' AND host='localhost'")
  if [[ "$user_exists" == "1" ]]; then
    warn "Database user '$nc_db_user' already exists. Reusing existing user."
  else
    info "Creating database user '$nc_db_user'"
    mysql -e "CREATE USER '$nc_db_user'@'localhost' IDENTIFIED BY '$nc_db_pass';"
  fi
  mysql -e "GRANT ALL PRIVILEGES ON \`$nc_db\`.* TO '$nc_db_user'@'localhost'; FLUSH PRIVILEGES;"
}
configure_db() {
  local db="one_click:${domain}:$(openssl rand -hex 4):$dbuser"
  echo "DB_NAME=$db" >> /etc/one-click/wordpress/$domain/meta.conf
  systemctl enable mariadb --now
  mysql -e "CREATE DATABASE IF NOT EXISTS \`$db\`;"
  user_exists=$(mysql -sN -e "SELECT 1 FROM mysql.user WHERE user='$dbuser' AND host='localhost'")
  if [[ "$user_exists" == "1" ]]; then
    warn "Database user '$dbuser' already exists. Reusing existing user."
  else
    info "Creating database user '$dbuser'"
    mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
  fi
  mysql -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$dbuser'@'localhost'; FLUSH PRIVILEGES;"
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
  sed -Ei 's/(memory_limit = ).*/\11024M/' /etc/php.ini
  chown "$web_user":"${webserver_user:-${webserver}}" "$site"
  cd "$site" || return
  if [[ ! -f "${site}/wp-config.php" ]]; then
    $wp_cmd core download  || {
      warn "WP available in this location."
    }
  fi
  # ==== Ensure mysqli ====
  vers=$(sed -En '1s/[^.]*([0-9]+\.[0-9]+).*/\1/p' <(php -v))
  if [[ "$pkg_mgr" == "apt" ]]; then
    "$pkg_mgr" -y install php${vers}-mysql php-mysql php-posix || true
  else
    "$pkg_mgr" -y install php-mysqlnd php-posix || true
  fi
  # ==== Configure WP ====
  $wp_cmd config create \
    --dbname=$DB_NAME \
    --dbuser=$dbuser \
    --dbpass=$dbpass
}
# ==== Install ====
install_wp() {
  if $wp_cmd core is-installed >/dev/null 2>&1; then
    warn "WordPress already installed, skipping install"
  else
    $wp_cmd core install \
      --url="http://$domain" \
      --title="$title" \
      --admin_user="$admin" \
      --admin_password="$pass" \
      --admin_email="$email"
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
  $wp_cmd plugin install \
    wordfence \
    wp-super-cache \
    --activate
  # ==== Installing Selected Services ====
  if [[ "$enable_redis" == "y" ]]; then
    info "Installing and configuring Redis"
    # ==== Install Redis ====
    if [[ "$pkg_mgr" == "apt" ]]; then
      $pkg_mgr install -y redis-server php-redis
      $pkg_mgr -y install redis || $pkg_mgr install -y valkey 
      systemctl enable redis-server --now > /dev/null || systemctl enable --now valkey > /dev/null
      local service="redis-${domain}"
      redis_conf="/etc/redis/redis.conf"
      php_user="$webserver"
    else
      if ! $pkg_mgr -y install redis > /dev/null; then
        $pkg_mgr install -y valkey > /dev/null
        systemctl enable --now valkey > /dev/null
        redis_execstart=/usr/bin/valkey-server
        conf="/etc/valkey/one-click/${domain}.conf"
        redis_conf="/etc/valkey/valkey.conf"
        redis_ver=$(sort -rV <(awk '$1=="valkey"{print $2}' <(dnf module list valkey 2>/dev/null)) | head -1)
      else
        systemctl enable redis-server --now > /dev/null
        systemctl enable redis --now > /dev/null
        redis_execstart=/usr/bin/redis-server
        conf="/etc/redis/one-click/${domain}.conf"
        redis_conf="/etc/redis/redis.conf"
        redis_ver=$(sort -rV <(awk '$1=="redis"{print $2}' <(dnf module list redis 2>/dev/null)) | head -1)
      fi
      $pkg_mgr install -y php-pecl-redis
      local service="redis-${domain}"
      php_user="$webserver"
    fi
    redis_pw=$(openssl rand -base64 32)
    if [[ -d /run/redis ]]; then
      sock="/run/redis/redis-${domain}.sock"
    else
      sock="/run/valkey/redis-${domain}.sock"
    fi
    # ==== Verify Redis ====
    if ! redis-cli ping &>/dev/null; then
      if ! valkey-cli ping > /dev/null; then
        error "Redis failed to install"
        return 1
      else
        for red in /usr/bin/valkey-*; do
          cp -f $red /usr/bin/redis-${red##*-}
        done
        #cp -f /usr/bin/valkey-cli /usr/bin/redis-cli
      fi
    fi
    # ==== Configure Redis ====
    if ! getent passwd redis > /dev/null; then
      redis_user=valkey
      redis_dir=valkey
    else
      redis_user=redis
      red_dir=redis
    fi
    setup_redis "$domain"
    redis_service "$domain"
    $wp_cmd plugin install redis-cache --activate
    wp_config="/etc/one-click/wordpress/${domain}/wp-config.php"
    if ! grep -q "WP_REDIS_HOST" "$wp_config"; then
      cat <<EOF >> "$wp_config"

/** Redis Added By One-Click */
define('WP_REDIS_SCHEME', 'unix');
define('WP_REDIS_PATH', "$sock");
define('WP_REDIS_HOST', null);
define('WP_REDIS_PORT', null);
define('WP_REDIS_PASSWORD', "$redis_pw");
EOF
    fi
    usermod -aG "$redis_user" "$webserver_user"
    usermod -aG "$redis_user" "$web_user"
    systemctl daemon-reexec
    systemctl enable "${service}" --now
    for i in {1..10}; do
      if [[ -S "$sock" ]]; then
        break
      fi
      sleep 1
    done
    chown $redis_user:$web_user "$sock"
    mkdir -p /etc/systemd/system/php-fpm@${domain}.service.d/
    cat > /etc/systemd/system/php-fpm@${domain}.service.d/${domain}-redis.conf <<EOF
[Service]
ReadWritePaths=/run/redis/
EOF
    systemctl daemon-reload
    systemctl restart php-fpm@${domain}.service
    $wp_cmd redis enable
    success "Redis installed and configured."
  fi
}
# ==== REDIS ====
setup_redis() {
  local domain="$1"
  #local conf="/etc/redis/one-click/${domain}.conf"
  #local sock="/run/redis/redis-${domain}.sock"
  local data_dir="/var/lib/redis/${domain}"
  mkdir -p "$data_dir" $(dirname "$conf")
  chown $redis_user:$redis_user "$data_dir"
  cat > "$conf" <<EOF
bind 127.0.0.1
port 0

requirepass $redis_pw
unixsocket $sock
unixsocketperm 770

dir $data_dir

maxmemory 512mb
maxmemory-policy allkeys-lru

daemonize no
supervised systemd
EOF
}
redis_service() {
  local domain="$1"
  #local conf="/etc/redis/one-click/${domain}.conf"
  local service="redis-${domain}"
  if ! grep -Eq 'vm.overcommit_memory = 1' /etc/sysctl.conf; then
    echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
    sysctl -p
  fi
  cat > "/etc/systemd/system/${service}.service" <<EOF
[Unit]
Description=One-Click Redis Instance for ${domain}
After=network.target

[Service]
Type=notify
ExecStart=$redis_execstart $conf
ExecStop=/usr/bin/redis-cli shutdown
User=$redis_user
Group=$web_user
RuntimeDirectory=$redis_dir
RuntimeDirectoryMode=0775
UMask=0002
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}
redis_menu() {
  local instance_service="redis-${domain}"
  if [[ -d /run/valkey ]]; then
    local instance_sock="/run/valkey/redis-${domain}.sock"
    local instance_conf="/etc/valkey/one-click/${domain}.conf"
  else
    local instance_sock="/run/redis/redis-${domain}.sock"
    local instance_conf="/etc/redis/one-click/${domain}.conf"
  fi
  while true; do
    local status_raw=$(systemctl is-active "$instance_service" 2>/dev/null)
    if [[ "$status_raw" == "active" ]]; then
      local status_tbl="${green}ACTIVE${reset}"
      local usage=$(redis-cli -s "$instance_sock" info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
      local max_mem=$(grep "maxmemory " "$instance_conf" | awk '{print $2}')
    else
      local status_tbl="${red}INACTIVE${reset}"
      local usage="N/A"
      local max_mem=$(grep "maxmemory " "$instance_conf" 2>/dev/null | awk '{print $2}' || echo "N/A")
    fi
    clear
    printf "${blue}╔══════════════════════════════════════════════════════════════════════╗${reset}\n"
    printf "${blue}║${reset}  ${magenta}REDIS MANAGEMENT:${reset} %-49s ${blue}║${reset}\n" "$domain"
    printf "${blue}╠══════════════════════╦══════════════════════╦════════════════════════╣${reset}\n"
    printf "${blue}║${reset} ${cyan}STATUS:${reset} %-22b ${blue}║${reset} ${cyan}USED:${reset} %-14s ${blue}║${reset} ${cyan}LIMIT:${reset} %-15s ${blue}║${reset}\n" \
      "$status_tbl" "$usage" "${max_mem^^}"
    printf "${blue}╚══════════════════════╩══════════════════════╩════════════════════════╝${reset}\n"
    printf "${magenta}ACTIONS:${reset}\n"
    printf '%s\n' \
      "  ${yellow}1)${reset} Start Instance        ${yellow}5)${reset} Edit Config (Manual)" \
      "  ${yellow}2)${reset} Stop Instance         ${yellow}6)${reset} Set Max Memory" \
      "  ${yellow}3)${reset} Restart Instance      ${yellow}7)${reset} Flush All Cache" \
      "  ${yellow}4)${reset} View Live Logs        ${yellow}0)${reset} Back" \
      "${blue}────────────────────────────────────────────────────────────────────────${reset}"
    read -p "Select an option: " rchoice
    case $rchoice in
      1) systemctl start "$instance_service"   ;;
      2) systemctl stop "$instance_service"    ;;
      3) systemctl restart "$instance_service" ;;
      4)
        echo -e "${cyan}--- Last 20 lines of logs for $domain ---${reset}"
        journalctl -u "$instance_service" -n 20 --no-pager
        read -p "Press Enter to continue..."
        ;;
      5) nano "$instance_conf" && systemctl restart "$instance_service" ;;
      6)
        read -p "Enter new memory limit (e.g. 256mb): " new_limit
        sed -i "s/^maxmemory .*/maxmemory $new_limit/" "$instance_conf"
        systemctl restart "$instance_service"
        success "Memory updated to $new_limit"
        sleep 1
        ;;
      7)
        if [[ "$status_raw" == "active" ]]; then
          redis-cli -s "$instance_sock" flushall
          success "Redis cache for $domain cleared."
        else
          error "Cannot flush: Service is not running."
        fi
        sleep 1
        ;;
      0) return 0    ;;
      *) invalid_opt ;;
    esac
  done
}
# ==== WP Staging ====
wp_staging() {
  prod="/etc/one-click/wordpress/$domain/"
  stage="/etc/one-click/wordpress/staging/$domain"
  db_user=$(sed -En "/DB_USER/s/^[^)]*'([^']*)'.*/\1/p" "$prod/wp-config.php")
  db_pass=$(sed -En "/DB_PASSWORD/s/^[^)]*'([^']*)'.*/\1/p" "$prod/wp-config.php")
  local wp_cmd="sudo -u $web_user /usr/local/bin/wp --path=$stage/www"
  info "Creating staging environment"
  mkdir -p "$stage"
  rsync -a "$prod/" "$stage/"
  chown -R "$web_user":"$webserver_user" "$stage"
  chmod 644 "$stage/wp-config.php"
  cd "$stage"
  $wp_cmd db export stage.sql
  stage_db="stage_$(openssl rand -hex 4)"
  if mysql -e "USE $stage_db;" 2>/dev/null; then
    echo -e "\e[33m[WARN] Database $stage_db already exists\e[0m"
    echo "Choose an action:"
    echo "  1) Delete existing DB and recreate"
    echo "  2) Use existing DB"
    echo "  3) Cancel staging"
    while true; do
      read -rp "${cyan}[USER]${reset} Enter choice [1-3]: " choice
      case "$choice" in
        1)
          echo "Dropping existing database..."
          mysql -e "DROP DATABASE $stage_db;"
          echo "Creating new database..."
          mysql -e "CREATE DATABASE $stage_db;"
          break
          ;;
        2)
          echo "Using existing database $stage_db"
          break
          ;;
        3)
          echo "Cancelling staging"
          return 1
          ;;
        *)
          echo "Invalid choice, try again"
          ;;
      esac
    done
  else
    mysql -e "CREATE DATABASE $stage_db"
    mysql -e "GRANT ALL PRIVILEGES ON $stage_db.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass'"
    $wp_cmd config set DB_NAME "$stage_db"
    #$wp_cmd db export "$stage/stage.sql"
    $wp_cmd db import "$stage/stage.sql"
    $wp_cmd option update siteurl "https://staging.$domain"
    $wp_cmd search-replace "https://$domain" "https://staging.$domain" --skip-columns=guid
    info "Staging created at staging.$domain"
  fi
}
wp_staging_push() {
  create_rollback_snapshot "$domain" "wordpress"
  prod="/etc/one-click/wordpress/$domain"
  stage="/etc/one-click/wordpress/staging/$domain"
  local wp_cmd="sudo -u $web_user /usr/local/bin/wp --path=$prod/www"
  printf '%s\n' "$(tput setaf 165)[PUSH}${reset} Deploying staging to production"
  rsync -a --delete "$stage/" "$prod/"
  cd "$prod"
  $wp_cmd db export deploy.sql
  $wp_cmd db import deploy.sql
  printf '%s\n' "$(tput setaf 165)[PUSH}${green} Deployment completed: Push from staging successful${reset}"
}
staging_vhost_nginx() {
  local domain stage_root
  domain="$1"
  stage_root="/etc/one-click/wordpress/staging/$domain"
  mkdir -p /var/log/nginx/${domain}_staging
  cat > "/etc/nginx/conf.d/staging.$domain.conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name staging.$domain;

    access_log /var/log/nginx/${domain}_staging/access.log oneclick;
    error_log /var/log/nginx/${domain}_staging/error.log warn;

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

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}
EOF
  systemctl reload nginx
}
default_nginx() {
  if [[ -d /etc/nginx/sites-enabled ]]; then
    conf=/etc/nginx/sites-enabled/00-default.conf
  else
    /etc/nginx/conf.d/00-default.conf
  fi
  openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout /etc/ssl/private/ssl-cert-default_site.key \
    -out /etc/ssl/certs/ssl-cert-default_site.pem \
    -subj "/CN=localhost"
  cat> "$conf" << EOF
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
  if [[ "$pkg_mgr" == "apt" && -d /etc/nginx/sites-available ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  for i in /etc/nginx/sites-enabled/ /etc/nginx/sites-available /etc/nginx/con.d/ ; do
    if [[ ! -d "$i" ]]; then
      continue
    fi
    find "$i" -type l -name '*default*' '!' -name 00-default.conf -delete
  done
  if nginx -t &> /dev/null; then
    systemctl reload nginx
  fi
}
staging_vhost_apache() {
  local domain stage_root
  domain="$1"
  stage_root="/etc/one-click/wordpress/staging/$domain"
  if [[ "$webserver_user" == "www-data" ]]; then
    local conf="/etc/apache2/sites-enabled/staging.${domain}.conf"
  else
    local conf="/etc/httpd/conf.d/staging.${domain}.conf"
  fi
  cat > "$conf" <<EOF
<VirtualHost *:80>
    ServerName staging.$domain
    ServerAlias www.staging.$domain
    DocumentRoot $stage_root

    <Directory $stage_root>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/$domain-error.log
    CustomLog ${apache_log_dir}/$domain-access.log combined

</VirtualHost>
EOF
  systemctl reload httpd 2> /dev/null || systemctl reload apache2 2> /dev/null
}
wp_staging_enable() {
  local domain="$1"
  if [[ ! -d /etc/one-click/wordpress/staging/$domain ]]; then
    wp_staging "$domain"
  fi
  if [[ "$webserver" == "nginx" ]]; then
    staging_vhost_nginx "$domain"
  else
    staging_vhost_apache "$domain"
  fi
  enable_staging_ssl "$domain" 2>/dev/null || true
  success "Staging enabled at ${cyan}https://staging.$domain${reset}"
}
wp_staging_disable() {
  local domain="$1"
  rm -f /etc/nginx/conf.d/staging.$domain.conf 2>/dev/null
  rm -f /etc/httpd/conf.d/staging.$domain.conf 2>/dev/null
  systemctl reload nginx 2>/dev/null || systemctl reload httpd
  success "Staging disabled for $domain"
}
staging_status() {
    local domain="$1"
    [[ -d "/etc/one-click/wordpress/staging/$domain" ]] && echo "ON" || echo "OFF"
}
# ===== WordPress main menu =====
wp_menu() {
  select_wp_domain manage "WordPress site"
  config_dir="$base/wordpress/config"
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) | head -1)
  profiles_file="$config_dir/remotes.conf"
  map_file="$config_dir/domain_map.conf"
  current_profile_file="$config_dir/current_profile"
  site="/etc/one-click/wordpress/$domain/www"
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
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
        wp_restore_int "$domain"    ;;
      5) wp_staging_menu "$domain"  ;;
      6) wp_rollback_menu "$domain" ;;
      7) wp_staging_push "$domain"  ;;
      8) delete_site "$domain"      ;;
      9) wp_magic_login "$domain"   ;;
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
  local mode
  mode="$1"
  domain="${2:-}"
  if [[ "$mode" == "wordpress" ]]; then
    mode_ver="$mode"
  elif [[ "$mode" == "nodejs" ]]; then
    mode_ver="apps/nodejs"
  elif [[ "$mode" == "nextcloud" ]]; then
    mode_ver="nextcloud"
  else
    mode_ver="sites"
  fi
  site_dir="${3:-}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      if (systemctl is-active apache2 || systemctl is-active httpd) > /dev/null; then
        systemctl disable apache2 --now || systemctl disable httpd --now
      fi
      sed -i.one-click-bak '/^#deb-src/{s/^#//}' /etc/apt/sources.list
      "$pkg_mgr" clean
      "$pkg_mgr" update -y
      if ! "$pkg_mgr" -y install nginx &>/dev/null; then
        "$pkg_mgr" install -y debian-archive-keyring
        "$pkg_mgr" install -y nginx || "$pkg_mgr" install -y nginx-full
      fi
      if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q 'oneclick' /etc/nginx/nginx.conf; then
          mkdir -p /etc/nginx/one-click
          cat > /etc/nginx/one-click/logging.conf <<'EOF'
# ==== One-Click Logging ====

log_format oneclick '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" "$host"';

EOF
        fi
        if ! grep -q 'include /etc/nginx/one-click/\*.conf;' /etc/nginx/nginx.conf; then
          cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.one-click-bak
          sed -Ei '
            s,(access_log ).*,include /etc/nginx/one-click/*.conf;\n\t\1/var/log/nginx/example.com.access.log oneclick;,;
          ' /etc/nginx/nginx.conf
        fi
      fi
      if [[ ! -f /etc/nginx/sites-enabled/00-default.conf ]]; then
        default_nginx
      fi
      nginx_conf
    else
      if systemctl is-active nginx > /dev/null; then
        systemctl disable nginx --now
      fi
      "$pkg_mgr" install -y apache2 libapache2-mod-php
      if [[ "$mode" == "wordpress" ]]; then
        apache_conf
        apache_ssl_conf
      else 
        apache_static_conf "$domain" "$site_dir"
      fi
      a2ensite "${domain}.conf"
      #a2ensite "$domain-le-ssl.conf"
    fi
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      if systemctl is-active httpd > /dev/null; then
        systemctl disable nginx --now
      fi
      "$pkg_mgr" install -y nginx
      if [[ "$mode" == "wordpress" ]]; then
        nginx_conf
      else
        nginx_static_conf "$domain" "$site_dir"
      fi
    else
      if systemctl is-active nginx > /dev/null; then
        systemctl disable nginx --now
      fi
      "$pkg_mgr" install -y httpd php php-fpm
      if [[ "$mode" == "wordpress" ]]; then
        apache_conf
        apache_ssl_conf
      else 
        apache_static_conf "$domain" "$site_dir"
      fi
      httpd -t
    fi
  fi
  return 0
}
# ==== Webservers Configs ====
install_php_mods() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    apt install -y \
      apache2 \
      libapache2-mod-php \
      php \
      php-fpm \
      php-mysqlnd \
      php-curl \
      php-gd \
      php-mbstring \
      php-xml \
      php-zip \
      php-mysql \
      php-posix \
      bzip2
    a2enmod rewrite
    a2enmod ssl
    a2enmod headers
    a2enmod proxy
    a2enmod proxy_fcgi
    a2ensite "$domain"
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    "$pkg_mgr" install -y \
        httpd \
        mod_ssl \
        mod_proxy_fcgi \
        php \
        php-fpm \
        php-mysqlnd \
        php-gd \
        php-mbstring \
        php-xml \
        php-json \
        php-mysql \
        php-posix \
        bzip2
  fi
}
# ==== Nginx ====
nginx_conf() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  fi
  echo "VHOST=$nginx_conf_file" >> /etc/one-click/${mode_ver}/${domain}/meta.conf
  mkdir -p /var/log/nginx/${domain}
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root /etc/one-click/$mode_ver/$domain/www;
    index index.php index.html;

    access_log /var/log/nginx/${domain}/access.log oneclick;
    error_log /var/log/nginx/${domain}/error.log warn;

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
  nginx -t
  systemctl enable nginx --now
  systemctl reload nginx
}
# ==== Apache ====
apache_conf() {
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
    apache_log_dir="/var/log/apache2"
  else
    apache_log_dir="/var/log/httpd"
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

    ErrorLog ${apache_log_dir}/$domain-error.log
    CustomLog ${apache_log_dir}/$domain-access.log combined
</VirtualHost>
EOF
  install_php_mods
}
apache_ssl_conf() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    ssl_apache_conf=/etc/apache2/sites-available/$domain-le-ssl.conf
    apache_confi=/etc/apache2/sites-available/$domain.conf
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    ssl_apache_conf=/etc/httpd/conf.d/$domain-le-ssl.conf
    apache_confi=/etc/httpd/conf.d/$domain.conf
  fi
  cat << EOF > "$ssl_apache_conf"
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName $domain
    ServerAlias www.$domain

    DocumentRoot /etc/one-click/$mode_ver/$domain/www

    <Directory /etc/one-click/${mode_ver}/$domain/www>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/one-click/${domain}/php.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/$domain-ssl-error.log
    CustomLog ${apache_log_dir}/$domain-ssl-access.log combined
</VirtualHost>
</IfModule>
EOF
  sed -Ei 's/#(Redirect permanent)/\1/' "$apache_confi"
  if [[ "$pkg_mgr" == "apt" ]]; then
    a2ensite "$(basename $ssl_apache_conf)"
  fi
}
webroot_nginx_template() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/nginx"
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
  mode="${1:-}"
  if [[ -z "${domain:-}" ]]; then
    select_domain
    if [[ -z "${domain:-}" ]]; then
      while true; do
        read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to issue SSL for: " domain
        [[ -n "$domain" ]] && break
        if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
          echo "Invalid domain name"
        fi
      done
      if [[ -d "/etc/one-click/wordpress/${domain}" ]]; then
        site="/etc/one-click/wordpress/${domain}/www"
      elif [[ -d "/etc/one-click/sites/${domain}" ]]; then
        site="/etc/one-click/sites/$domain/www"
      fi
      if [[ "$mode" == "wordpress" ]]; then
        site="/etc/one-click/wordpress/$domain/www"
      else
        site="/etc/one-click/sites/$domain/www"
      fi
      wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
      webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
      email=$($wp_cmd option get admin_email || true)
    fi
  fi
  if [[ -z "${email:-}" ]]; then
    while true; do
      read -rp "${cyan}[USER]${blue} Please provide an email address for LetsEncrypt:${reset} " email
      [[ -n "$email" ]] && break
    done
  fi
  while true; do
    info "Starting Let's Encrypt SSL setup..."
    if ! dns_check; then
      warn "DNS does not point to this server."
      echo "  $domain -> $dns"
      echo "  www.$domain -> $dns_www"
      read -rp "${cyan}[USER]${reset} Fix DNS and press ENTER to retry (or type 'skip'): " action
      [[ "$action" == "skip" ]] && return
      continue
    fi
    webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
    "$pkg_mgr" install -y certbot
    if [[ "$webserver" == "nginx" ]]; then
      if ! "$pkg_mgr" install -y python3-certbot-nginx; then
        manual_install=1
      fi
    else
      if ! "$pkg_mgr" install -y python3-certbot-apache; then
        manual_install=1
      fi
    fi
    if [[ "$webserver" == "nginx" ]]; then
      if certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email"; then
        bot_installed=1
      fi
    else
      if certbot --apache -d "$domain" --non-interactive --agree-tos -m "$email"; then
        bot_installed=1
      fi
    fi
    if [[ "${bot_installed:-}" -eq 1 ]]; then
      if [[ "$mode" == "wordpress" ]]; then
        $wp_cmd option update home "https://$domain"
        $wp_cmd option update siteurl "https://$domain"
      fi
      info "SSL successfully installed!"
      break
    else
      warn "Certbot failed."
      printf '%s\n' "Options:" \
        "  [1] Try webroot installation" \
        "  [2] Change email" \
        "  [3] Skip SSL setup" \
        "  [4] Install Self-Signed Certificate" \
        "  [5] View logs"
      read -rp "${cyan}[USER]${reset} Choose an option: " choice
      case "$choice" in
        1)
          if [[ -d "/etc/one-click/wordpress/${domain}" ]]; then
            site="/etc/one-click/wordpress/${domain}/www"
          elif [[ -d "/etc/one-click/sites/${domain}" ]]; then
            site="/etc/one-click/sites/$domain/www"
          fi
          if certbot certonly --webroot -w "${site:-${site_dir:-}}" -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"; then
            bot_installed=0
            manual_install=1
            success "SSL installed"
            return
          fi
          ;;
        2)
          while true; do
            read -rp "${cyan}[USER]${blue} Enter new email: " email
            [[ -n "$email" ]] && break
          done                                       ;;
        3) warn "Skipping SSL setup."; return        ;;
        4)
          info "Installing self signed certificate"
          if [[ -d "/etc/one-click/wordpress/${domain}" ]]; then
            dir="/etc/one-click/wordpress/$domain"
            site="/etc/one-click/wordpress/${domain}/www"
            cert_dir="/etc/one-click/wordpress/${domain}/cert"
          elif [[ -d "/etc/one-click/sites/${domain}" ]]; then
            site="/etc/one-click/sites/$domain/www"
            dir="/etc/one-click/sites/$domain"
            cert_dir="/etc/one-click/sites/${domain}/cert"
          elif [[ -d "/etc/one-click/nextcloud/${domain}" ]]; then
            site="/etc/one-click/nextcloud/$domain/www"
            dir="/etc/one-click/nextcloud/$domain"
            cert_dir="/etc/one-click/nextcloud/${domain}/cert"
          elif [[ -d "/etc/one-click/apps/nodejs/${domain}" ]]; then
            site="/etc/one-click/apps/nodejs/$domain/www"
            dir="/etc/one-click/apps/nodejs/$domain"
            cert_dir="/etc/one-click/apps/nodejs/${domain}/cert"
          fi
          . "${dir}/meta.conf"
          mkdir -p "$cert_dir"
          chmod 755 "$cert_dir"
          web_user="$SITE_USER"
          webserver_user="$SITE_GROUP"
          openssl req -x509 -nodes -days 365 \
            -newkey rsa:4096 \
            -keyout ${cert_dir}/${domain}-oneclick_selfsigned-privkey.key \
            -out ${cert_dir}/${domain}-oneclick_selfsigned-fullchain.pem \
            -subj "/C=NG/ST=Lagos/L=Lagos/O=Site/CN=$domain"
          chown "$web_user":"$webserver_user" "${cert_dir}/${domain}-oneclick_selfsigned-fullchain.pem" "${cert_dir}/${domain}-oneclick_selfsigned-privkey.key"
          chmod 640 ${cert_dir}/${domain}-oneclick_selfsigned-privkey.key
          chmod 644 ${cert_dir}/${domain}-oneclick_selfsigned-fullchain.pem
          if [[ "$webserver" == "nginx" ]]; then
            if [[ "$pkg_mgr" == "apt" ]]; then
              nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
            else
              nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
            fi
            apachehttpd=nginx
            sed -Ei.oneclick-bak "
              /server_name/ {
                h;
                n;
                G;
                s,se.*,return 301 https://\$host\$request_uri;\n}\n\nserver {\n    listen 443 ssl; #Managed By One-Click\n    server_name $domain www.${domain};\n\n    ssl_certificate ${cert_dir}/${domain}-oneclick_selfsigned-fullchain.pem;\n    ssl_certificate_key ${cert_dir}/${domain}-oneclick_selfsigned-privkey.key;\n,
              };
            "  "$nginx_conf_file"
          else
            if [[ "$pkg_mgr" == "apt" ]]; then
              ssl_apache_conf=/etc/apache2/sites-available/$domain-le-ssl.conf
              apachehttpd=apache2
            elif [[ "$pkg_mgr" == "dnf" ]]; then
              ssl_apache_conf=/etc/httpd/conf.d/$domain-le-ssl.conf
              apachehttpd=httpd
            fi
            sed -Ei.oneclick-bak "
              /DocumentRoot/ {
                h;
                n;
                G;
                s,D.*,SSLEngine on\n    SSLCertificateFile ${cert_dir}/${domain}-oneclick_selfsigned-fullchain.pem\n    SSLCertificateKeyFile ${cert_dir}/${domain}-oneclick_selfsigned-privkey.key\n,
              }
            " "$ssl_apache_conf"
          fi
          if systemctl reload "$apachehttpd" 2> /dev/null; then
            success "Self signed certificate installed"
          fi
          read -p "Click Enter to exit: "
          return
          ;;
        5) less /var/log/letsencrypt/letsencrypt.log ;;
        *) warn "Invalid option"                     ;;
      esac
    fi
  done
  letsencrypt_autorenew
}
letsencrypt_autorenew() {
  info "Configuring Let's Encrypt auto-renewal"
  cat <<EOF >/etc/cron.d/one-click-letsencrypt
0 3 * * * root certbot renew --quiet --post-hook "systemctl reload nginx 2>/dev/null || systemctl reload apache2" # One-Click Wordpress
EOF
  chmod 644 /etc/cron.d/one-click-letsencrypt
  success "Auto-renew enabled"
}
# === Run Script ====
run_script() {
  start_screen wordpress
  echo
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
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
  web_user="${admin:4}_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  echo "$web_user" > /tmp/web-user
  export admin
  export web_user
  site="/etc/one-click/wordpress/$domain/www"
  mkdir -p "$site"
  touch "${site}/meta.conf"
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
  warn "Creating web owner"
  id "$web_user" &>/dev/null || useradd -r -m -s /usr/sbin/nologin "$web_user"
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
  echo "SITE_USER=$web_user" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "SITE_DIR=$site" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "SITE_GROUP=$webserver_user" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "WEBSERVER=$webserver" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "DB_PASS=$dbpass" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "DB_USER=$dbuser" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "TYPE=wordpress" >> /etc/one-click/wordpress/$domain/meta.conf
  echo "WEBSERVER_SERVICE=$webserver" >> /etc/one-click/wordpress/$domain/meta.conf
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
  install_wp_cli
  info "Installing $webserver"
  install_webserver wordpress "$domain" "site_dir"
  info "Creating resource slice for $domain"
  info "Configuring PHP-FPM"
  create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "wordpress"
  info "Enabling PHP"
  systemctl enable php-fpm@${domain}.service --now
  info "Confguring MariaDB"
  configure_db
  dns_check
  info "Downloading Wordpress"
  download_wp
  info "Installing Wordpress"
  install_wp
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
      chmod 644 "$dest_config"
      success "wp-config.php moved to $dest_config and permissions set to 644."
    else
      error "Failed to move file. Check permissions and global server settings then try again."
      exit 1
    fi
  fi
  mkdir -p /etc/one-click/wordpress/backups
  chmod -R 700 /etc/one-click/wordpress/backups
  chown "$web_user":"$webserver_user" /etc/one-click/wordpress/backups
  chown "$web_user":"$webserver_user" /etc/one-click/wordpress/$domain/meta.conf
  # ==== Inject direct perms ====
  file="/etc/one-click/wordpress/${domain}/wp-config.php"
  grep -q "ONECLICK_PLATFORM_BOOTSTRAP" "$file" || cat >> "$file" <<'EOF'
if ( ! defined('ONECLICK_PLATFORM_BOOTSTRAP') ) {
    define('ONECLICK_PLATFORM_BOOTSTRAP', true);
    define('FS_METHOD', 'direct');
    define('WP_CONTENT_DIR', ABSPATH . 'wp-content');
    define('WP_CONTENT_URL', 'https://DOMAIN_REPLACE/wp-content');
    define('WP_TEMP_DIR', '/var/lib/one-click/ONECLICK-DOMAIN_REPLACE/tmp');
}
EOF
  sed -i "s|ONECLICK-DOMAIN_REPLACE|$domain|g" "$file"
  # ==== Open Firewall ====
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver" -y
  info "Installing Plugins"
  wp_plugins
  $wp_cmd option get home
  info "Configuring SSL"
  install_letsencrypt wordpress
  set +o pipefail
  if [[ "${manual_install:-}" -eq 1 ]]; then
    webroot_nginx_template
  fi
  set -o pipefail
  wp_backup_scheduler
  systemctl restart "$webserver"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_wp-web-monitor_$domain
  info "Fixing permissions"
  sleep 1
  check_permissions "$domain"
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
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
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
            info "Deactivating $slug..."
            $wp_cmd plugin deactivate "$slug"
          else
            info "Activating $slug..."
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
        info "Searching WordPress.org..."
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
          info "Installing $selected_slug..."
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
        info "Fetching installed plugins..."
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
  warn "No valid link found, generating new one..."
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
  local domain="$1"
  . "/etc/one-click/${mode_ver:-${type:-}}/${domain}/meta.conf" &> /dev/null || . "/etc/one-click/apps/nodejs/${domain}/meta.conf" &> /dev/null
  local site_dir="$SITE_DIR"
  local secrets_dir="/etc/one-click/db-manager/secrets/db/${domain}.pass"
  local registry_dir="/etc/one-click/db-manager/sites/${domain}.json"
  local expected_user="${SITE_USER:-$USER}"
  local expected_group="${SITE_GROUP:-$WEBSERVER_USER}"
  [[ ! -d "$site_dir" ]] && {
    error "Directory does not exist: $site_dir"
    return 1
  }
  printf "${orange}[Scanning:]${reset} %s\n" "$site_dir"
  echo
  local bad=0
  local fixed=0
  local checked=0
  while IFS= read -r -d '' item || [[ -n "$item" ]]; do
    checked=$((checked + 1))
    read -r owner group < <(
      stat -c '%U %G' "$item"
    )
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
  done < <(find "$site_dir" "$registry_dir" "$secrets_dir" -print0 || true)
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
  local domain="$1"
  echo "$(sed 's/.*\.//' <<< $(basename $(mktemp)))-$domain" \
    | tr '.' '-' \
    | tr -cd 'a-zA-Z0-9-'
}
app_runtime_path() {
  local runtime="$1"
  local domain="$2"
  echo "${app_dir}/${runtime}/${domain}"
}
app_allocate_port() {
  local used
  used="$(ss -lnt | awk 'NR>1 {split($4,a,":"); print a[length(a)]}')"
  for ((port=$app_port_start;port<=$app_port_end;port++)); do
    if ! grep -qx "$port" <<< "$used"; then
      echo "$port"
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
      "$user"
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
app_generate_systemd() {
  local runtime="$1"
  local domain="$2"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  local port; port="$(jq -r '.port' "${root}/runtime.json")"
  local user; user="$(jq -r '.user' "${root}/runtime.json")"
  local node_path; node_path="$(jq -r '.node_path' "${root}/runtime.json")"  
  local entry_point
  if [[ -f "${root}/app/package.json" ]]; then
    entry_point="$(jq -r '.main // "index.js"' "${root}/app/package.json")"
    [[ "$entry_point" == "null" ]] && entry_point="index.js"
  else
    entry_point="index.js"
  fi
  local service="one-click-${runtime}-${domain}.service"  
  echo "SYSTEMD_ENABLED=true" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  echo "SYSTEMD_VHOST=/etc/systemd/system/${service}" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  echo "SYSTEMD_SERVICE_NAME=${service//.*}" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  cat > "/etc/systemd/system/${service}" <<EOF
[Unit]
Description=One-Click ${runtime} App (${domain})
After=network.target

[Service]
Type=simple
User=${user}
WorkingDirectory=${root}/app

Environment=PORT=${port}
Environment=NODE_ENV=production
Environment=PATH=${root}/node_bin/bin:/usr/bin:/bin
EnvironmentFile=-${root}/env/.env

ExecStart=${node_path} ${entry_point}

Restart=always
RestartSec=5
StandardOutput=append:${root}/logs/app.log
StandardError=append:${root}/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "${service}"
}
app_generate_nginx_proxy() {
  local domain="$1"
  local port="$2"
  . "${app_dir}/${runtime}/${domain}/meta.conf"
  cat> ${app_dir}/nodejs/${domain}/config/nginx.conf <<EOF

location / {

    proxy_pass http://127.0.0.1:${port};

    proxy_http_version 1.1;

    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_read_timeout 300;
    proxy_connect_timeout 300;

}

EOF
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-enabled/$domain.conf"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
  fi
  sed -Ei "
    /^[ \t]+index.*/ {
      p;
      s,,include ${app_dir}/nodejs/${domain}/config/nginx.conf;,
    };
    \,location / \{,,/}/d
  " "$nginx_conf_file"
  systemctl reload nginx
}
app_generate_apache_proxy() {
  local domain="$1"
  local port="$2"
  .  "${app_dir}/${runtime}/${domain}/meta.conf"
  cat> ${app_dir}/nodejs/${domain}/config/apache.conf <<EOF

ProxyPreserveHost On

ProxyPass / http://127.0.0.1:${port}/
ProxyPassReverse / http://127.0.0.1:${port}/

RequestHeader set X-Forwarded-Proto "https"

EOF
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_conf_file="/etc/apache2/sites-available/$domain.conf"
  else
    apache_conf_file="/etc/httpd/conf.d/$domain.conf"
  fi
  sed -Ei "
    /DocumentRoot.*/ {
      p;
      s,,IncludeOptional ${app_dir}/nodejs/${domain}/config/apache.conf,
    };
  " "$apache_conf_file"
  systemctl reload apache2 || systemctl reload httpd
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
  local app_log_dir="/var/log/one-click/apps/${runtime}/${domain}"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  tail -F \
    "${app_log_dir}/app.log" \
    "${app_log_dir}/error.log"
}
ensure_isolated_nodejs() {
  local root="$1"
  local node_version="v20.11.1"
  echo "NODE_VERSION=$node_version" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64) arch="x64"    ;;
    aarch64) arch="arm64" ;;
    *) error "Unsupported architecture: $arch"; return 1 ;;
  esac
  local node_dir="${root}/node_bin"
  if [[ -x "${node_dir}/bin/node" && -x "${node_dir}/bin/npm" ]]; then
    return 0
  fi
  info "Installing Node.js (${node_version})..."
  mkdir -p "$node_dir"
  local tarball="node-${node_version}-linux-${arch}.tar.xz"
  local url="https://nodejs.org/dist/${node_version}/${tarball}"
  curl -fsSL "$url" -o "/tmp/${tarball}"
  tar -xJf "/tmp/${tarball}" -C "$node_dir" --strip-components=1
  rm "/tmp/${tarball}"
  success "Isolated Node.js engine placed at ${node_dir}/bin/node"
}
app_create_nodejs() {
  local git_repo="${1:-}"
  local runtime="nodejs"
  local php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  while true; do
    br=0
    read -rp "${cyan}[USER]${reset} Enter a domain name to use for your new app: " domain
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
  if app_exists "$runtime" "$domain"; then
    warn "Application already exists."
    return 1
  fi
  mkdir -p "${app_dir}/${runtime}/${domain}"
  local root
  root="$(app_runtime_path "$runtime" "$domain")"
  local user
  user="$(app_create_user "$domain")"
  if [[ ! $(sed -En '/# One-Click Routing/p' /etc/hosts) == "# One-Click Routing" ]]; then
    echo "# One-Click Routing" >> /etc/hosts
  elif [[ ! $(cat /etc/hosts) =~ 127.0.0.1.*"$domain" ]]; then
    sed -Ei.one-click_bak -e "/# One-Click/{a\127.0.0.1\t${domain}" -e '}' /etc/hosts
  fi
  echo -e "HOSTS_ENTRY=\"127.0.0.1\t${domain}\"" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  warn "Creating app owner $user"
  id "$user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$user"
  echo "USER=$user" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "SITE_USER=$user" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  echo "SITE_GROUP=$webserver_user" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  echo "WEBSERVER_USER=$webserver_user" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "WEBSERVER=$webserver" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "WEBSERVER_SERVICE=$webserver" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "APP_DIR=$app_dir" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "SITE_DIR=$root" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "TYPE=$runtime" >> /etc/one-click/apps/nodejs/$domain/meta.conf
  info "Creating Node.js application..."
  local port
  port="$(app_allocate_port)"
  if [[ -z "$port" ]]; then
    error "Failed to allocate port."
    return 1
  fi
  echo "PORT=$port" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  echo "SYSTEMD_VHOST=one-click-${runtime}-${domain}.service" >> "${app_dir}/${runtime}/${domain}/meta.conf"
  app_create_directories "$runtime" "$domain"
  ensure_isolated_nodejs "$root"
  cd "${root}/app" || return 1
  if [[ -n "$git_repo" ]]; then
    git clone "$git_repo" "${root}/app"
  else
    mkdir -p "${root}/app"
  fi
  if [[ ! -f "${root}/app/package.json" ]]; then
    info "No package.json found. Creating a generic default configuration..."
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
  if ! nodejs_validate_app "${root}/app"; then
    warn "package.json not found."
    error "Invalid Node.js application."
    return 1
  fi
  install_webserver nodejs "$domain" "$app_dir"
  create_isolated_php_runtime "$domain" "$php_ver" "$user" "$webserver_user" "apps/nodejs"
  if [[ "$webserver" == "nginx" ]];then
    app_generate_nginx_proxy "$domain" "$port"
  else
    app_generate_apache_proxy "$domain" "$port"
  fi
  chown -R "${user}:${webserver_user}" "$root"
  one-click engine "allow $port" -y
  info "Running npm install via isolated binary engine..."
  sudo -u "$user" \
    env PATH="${root}/node_bin/bin:/usr/bin:/bin" \
    HOME="${root}" \
    "${root}/node_bin/bin/npm" install
  app_write_runtime \
    "$runtime" \
    "$domain" \
    "$port" \
    "npm start" \
    "$user"
  type="apps/nodejs"
  check_permissions "$domain"
  printf "${magenta}[NODEjs]${reset} %s\n" \
    "=================================================" \
    "NODEJS APPLICATION CREATED" \
    "=================================================" " " \
    "Domain:  $domain" \
    "Runtime: nodejs" \
    "Port:    $port" \
    "Path:    $root" " " 
  app_generate_systemd "$runtime" "$domain"
  success "Node.js hosting successfully configured and proxied"
}
nodejs_board() {
  if [[ -z "${domain:-}" ]]; then
    select_domain || return 1
  fi
  if [[ ! -d "/etc/one-click/apps/nodejs/$domain" ]]; then
    error "No app found for $domain"
    return 1
  fi
  runtime="$1"
  root="$(app_runtime_path "$runtime" "$domain")"
  service="$(app_service_name "$runtime" "$domain")"
  while true; do
    local status="STOPPED"
    if systemctl is-active --quiet "$service"; then
      status="RUNNING"
    fi
    clear
    printf "%s\n" \
      "${cyan}=================================================${reset}" \
      "${magenta}        ONE-CLICK APP MANAGEMENT${reset}" \
      "${cyan}=================================================${reset}" " " \
      "${yellow}Domain:${reset} $domain" \
      "${yellow}Runtime:${reset} $runtime" \
      "${yellow}Status:${reset} $status"
    if [[ -f "${root}/runtime.json" ]]; then
      printf "${yellow}Port:${reset}     %s\n" \
        $(jq -r '.port' "${root}/runtime.json")
    fi
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK NodeJS ADMIN         ${blue}             ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Start Application  ${blue}                                   ║" \
      "║ ${magenta}2${blue}  ║ ${green}Stop Application ${blue}                                     ║" \
      "║ ${magenta}3${blue}  ║ ${green}Restart Application${blue}                                   ║" \
      "║ ${magenta}4${blue}  ║ ${green}View Status${blue}                                           ║" \
      "║ ${magenta}5${blue}  ║ ${green}View Logs   ${blue}                                          ║" \
      "║ ${magenta}6${blue}  ║ ${green}Toggle Service   ${blue}                                     ║" \
      "║ ${magenta}7${blue}  ║ ${green}Check/Fix Permissions${blue}                                 ║" \
      "║ ${magenta}8${blue}  ║ ${green}View Service File${blue}                                     ║" \
      "║ ${magenta}9${blue}  ║ ${green}Edit Environment File${blue}                                 ║" \
      "║ ${magenta}10${blue} ║ ${green}Open App Directory${blue}                                    ║" \
      "║ ${magenta}11${blue} ║ ${green}Backup App  ${blue}                                          ║" \
      "║ ${magenta}12${blue} ║ ${green}Restore App ${blue}                                          ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit  ${blue}                                                ║" \
      "╚════╩═══════════════════════════════════════════════════════╝")
  read -rp "${cyan}[USER]${blue} Select an option [0-12]: " choice
    case "$choice" in
      1)
        app_start "$runtime" "$domain"
        success "Application started"
        sleep 1
        ;;
      2)
        app_stop "$runtime" "$domain"
        success "Application stopped"
        sleep 1
        ;;
      3)
        app_restart "$runtime" "$domain"
        success "Application restarted"
        sleep 1
        ;;
      4)
        clear
        systemctl status "$service"
        read -rp "${cyan}[USER]${blue} Press enter to continue..."
        ;;
      5)
        clear
        app_logs "$runtime" "$domain"
        ;;
      6)
        if systemctl is-enabled --quiet "$service"; then
          systemctl disable "$service"
          warn "Service disabled"
        else
          systemctl enable "$service"
          success "Service enabled"
        fi
        sleep 1
        ;;
      7) check_permissions "$domain" ;;
      8)
        clear
        less "/etc/systemd/system/${service}"
        ;;
      9)
        mkdir -p "${root}/env"
        ${EDITOR:-nano} "${root}/env/.env"
        ;;
      10)
        clear
        cd "${root}" || return 1
        bash
        ;;
      11)
        resolve_profile "$domain"
        static_backup "$domain"
        ;;
      12)
        static_restore_int "$domain"
        ;;
      0)
        error "Exiting..."
        ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
        ;;
      *) error "Invalid option" ;;
    esac
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
  check_permissions "$domain"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_static-web-monitor_$domain
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
  info "Creating cloned website directory..."
  mkdir -p "$new_site_dir"
  info "Copying website files..."
  rsync -aHAX --info=progress2 \
    "$old_site_dir/" \
    "$new_site_dir/"
  success "Website files copied successfully."
  info "Replacing domain references..."
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
  info "Creating vhost..."

  web_user="ocb_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  warn "Creating web owner $web_user"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
  touch /etc/one-click/sites/$domain/meta.conf
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
  check_permissions "$new_domain"
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
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/nginx"
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
  nginx -t && systemctl enable --now nginx
}
apache_static_conf() {
  local domain="$1"
  local site_dir="$2"
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_conf_file="/etc/apache2/sites-available/$domain.conf"
    apache_log_dir="/var/log/apache2"
  else
    apache_conf_file="/etc/httpd/conf.d/$domain.conf"
    apache_log_dir="/var/log/httpd"
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

    ErrorLog ${apache_log_dir}/$domain-error.log
    CustomLog ${apache_log_dir}/$domain-access.log combined
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
  info "Archiving files..."
  tar -czf "$backup/$timestamp/files.tar.gz" -C "$site" .
  # ==== Save vhost config ====
  info "Saving webserver configuration..."
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
  info "Loading metadata..."
  . "$base/$domain/meta.conf"
  . "$backup_dir/meta.conf"
  . "$backup_dir/manifest.txt"
  # ==== Restore files ====
  info "Restoring files..."
  find "$site_dir" -mindepth 1 -delete
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  # ==== Restore webserver ====
  info "Restoring webserver configuration..."
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
  else
    printf "$red[ERROR]:$reset  %s\n" "No supported webserver detected!"
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1
  fi
}
view_service_status() {
  systemctl status "$1" --no-pager -l || true
}
restart_service() {
  info "${yellow}Restarting $1...${reset}"
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
switch_cli_php() {
  info "Detecting installed PHP CLI versions..."
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
    info "No alternatives manager found. Using manual symlink..."
    ln -sf "$selected_bin" /usr/bin/php
  fi
  success "CLI is now $(php -v | head -n1)"
}
switch_site_php() {
  local domain base_conf ini_file fpm_conf ver_nodot binary_path service_file current_ver
  domain="$1"
  set_domain_context || return 1
  base_conf="/etc/one-click/php/$domain"
  ini_file="$base_conf/php.ini"
  fpm_conf="$base_conf/php-fpm.conf"
  current_ver=$(awk -F"[ /]" '/ExecStart/{print $4}' <(systemctl cat php-fpm@$domain.service))
  read -rp "${cyan}[USER]${reset} Enter PHP version (e.g., 8.2): " new_ver
  ver_nodot="${new_ver//.}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    if ! dpkg -l | grep -q "php${new_ver}-fpm"; then
      info "Installing PHP $new_ver from the current version $current_ver"
      apt update -y
      apt install -y php${new_ver}-fpm php${new_ver}-cli php${new_ver}-mysql php${new_ver}-mbstring php${new_ver}-xml
      a2enconf php${new_ver}-fpm
    fi
    binary_path="/usr/sbin/php-fpm${new_ver}"
  else
    if [[ ! -f "/opt/remi/php${ver_nodot}/root/usr/sbin/php-fpm" ]]; then
      info "Installing PHP $new_ver from the current version $current_ver"
      dnf install -y "php${ver_nodot}-php-fpm" "php${ver_nodot}-php-cli" "php${ver_nodot}-php-mbstring"
    fi
    binary_path="/opt/remi/php${ver_nodot}/root/usr/sbin/php-fpm"
  fi
  if [[ ! -x "$binary_path" ]]; then
    error "PHP-FPM binary not found: $binary_path"
    return 1
  fi
  service_file="/etc/systemd/system/php-fpm@${domain}.service"
  if [[ ! -f "$service_file" ]]; then
    error "Service file not found: $service_file"
    return 1
  fi
  sed -Ei "s,(ExecStart=)[^ \t]*,\1$binary_path," /etc/systemd/system/php-fpm@${domain}.service
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl restart "php-fpm@$domain"
  systemctl  reload "$webserver"
  success " $domain is now using PHP $new_ver"
}
setup_repos() {
  if [[ "${os_family:-}" == "debian" ]]; then
    info "Ensuring Debian PHP repositories (sury.org)..."
    $pkg_mgr update -y && $pkg_mgr install -y lsb-release ca-certificates curl gnupg2
    [[ ! -f /etc/apt/trusted.gpg.d/php.gpg ]] && curl -sSLo /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    $pkg_mgr update -y
  else
    info "Ensuring RHEL PHP repositories (Remi)..."
    $pkg_mgr install -y https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
    $pkg_mgr install -y dnf-utils
  fi
}
install_php() {
  local ver="${1:-}"
  info "Installing PHP $ver and common extensions..."
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
  php_version=$(awk -F"[ /]" '/ExecStart/{print $4}' <(systemctl cat php-fpm@$domain.service) | sed 's/[^0-9]*//')
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
    php_version=$(awk -F"[ /]" '/ExecStart/{print $4}' <(systemctl cat php-fpm@$domain.service) | sed 's/[^0-9]*//')
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
          install_php "$v"        ;;
        2) switch_site_php "$domain"  ;;
        3) switch_cli_php         ;;
        4) tune_php_settings      ;;
        5) site_tune_php          ;;
        6) php_process_control    ;;
        7) select_domain          ;;
        0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
        *) error "Invalid option" ;;
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
  php_version=$(sed -En '/^ExecStart=[^0-9]*([0-9]+).*/{s//\1/;s/./&./p}' /etc/systemd/system/php-fpm@${domain}.service)
  [[ -z "$php_version" ]] && php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
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
  local domain php_ver site_user webserver
  domain="$1"
  local php_ver="$2"
  local site_user="$3"
  local webserver="$4"
  local type="$5"
  {
    v=$(sed -En '/PHP/s/^[^0-9]*([0-9]+\.[0-9]+).*/\1/p' <(php -v))
  #"$pkg_mgr" install -y php${v}-fpm
    $pkg_mgr install -y php-fpm || $pkg_mgr install -y "php$v-fpm"
    $pkg_mgr install -y  php-cli || $pkg_mgr install -y "php$v-cli" 
    $pkg_mgr install -y  php-xml || $pkg_mgr install -y "php$v-xml"
    $pkg_mgr -y install php-mysqlnd || $pkg_mgr -y install "php$v-mysql" 
    $pkg_mgr install -y  php-mbstring || $pkg_mgr install -y "php$v-mbstring" 
    $pkg_mgr install -y  php-gd || $pkg_mgr install -y "php$v-gd" 
    $pkg_mgr install -y  php-curl || $pkg_mgr install -y "php$v-curl" 
    $pkg_mgr install -y  php-zip || $pkg_mgr install -y "php$v-zip" 
  } 2> /dev/null
  php_bin="/usr/sbin/php-fpm${v}"
  local base_conf="/etc/one-click/php/$domain"
  local run_dir="/run/one-click/$domain"
  local log_dir="/var/log/one-click/$domain"
  local lib_dir="/var/lib/one-click/$domain"
  local ini_file="$base_conf/php.ini"
  local fpm_conf="$base_conf/php-fpm.conf"
  local pool_conf="$base_conf/pool.conf"
  local systemd_unit="/etc/systemd/system/php-fpm@$domain.service"
  echo "PHP_DIR=$base_conf" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_RUNTIME=$run_dir" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_LIB_DIR=$lib_dir" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_INI_FILE=$ini_file" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_FPM_CONF=$fpm_conf" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_POOL_CONF=$pool_conf" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_SYSTEMD_ENABLED=true" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_SYSTEMD_SERVICE_NAME=php-fpm@$domain.service" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  echo "PHP_SYSTEMD_VHOST=$systemd_unit" >> /etc/one-click/${mode_ver}/$domain/meta.conf
  mkdir -p "$base_conf" "$run_dir" "$log_dir" "$lib_dir"/{tmp,sessions}
  chown -R "$site_user:$site_user" "$lib_dir"
  chmod 700 "$lib_dir"
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
#extension=mysqli
#extension=pdo_mysql
#extension=mysqlnd
EOF
    if [[ "$pkg_mgr" != "apt" ]]; then
      sed -E 's/^#//' "$ini_file"
    fi
    cat > "$pool_conf" <<EOF
[$domain]
user = $site_user
group = $site_user
listen = $run_dir/php.sock
listen.owner = $site_user
listen.group = ${webserver_user:-${webserver}}
listen.mode = 0660
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.process_idle_timeout = 10s
pm.max_requests = 500
php_admin_value[open_basedir] = /etc/one-click/${type}/${domain}/:/etc/one-click/${type}/${domain}/www/:/tmp:/var/lib/one-click/${domain}/:/etc/one-click/db-manager/runtime/tokens:/etc/one-click/db-manager/sites/${domain}.json:/etc/one-click/db-manager/secrets/db/${domain}.pass:/etc/one-click/db-manager/runtime/tokens/
php_admin_value[upload_tmp_dir] = $lib_dir/tmp
php_admin_value[session.save_path] = $lib_dir/sessions
php_admin_value[disable_functions] =
php_admin_value[display_errors] = Off
php_admin_value[error_log] = /var/log/one-click/php/${domain}-error.log
EOF
    cat > "$fpm_conf" <<EOF
[global]
pid = $run_dir/php-fpm.pid
error_log = $log_dir/php-fpm.log
include = $pool_conf
EOF
    cat > "$systemd_unit" <<EOF
[Unit]
Description=One-Click isolated PHP-FPM runtime for $domain
After=network.target

[Service]
ExecStart=$php_bin --nodaemonize --fpm-config $fpm_conf -c $ini_file
ExecReload=/bin/kill -USR2 \$MAINPID
User=root
Group=root
Slice=one-click_$domain.slice
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/one-click/
NoNewPrivileges=true
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "php-fpm@$domain"
  if ! systemctl start "php-fpm@$domain" > /dev/null; then
    sed -Ei 's/(php-fpm)[0-9.]+/\1/' $fpm_conf
    systemctl start "php-fpm@$domain"
  fi
  if systemctl is-active --quiet "php-fpm@$domain"; then
    success "PHP $php_ver runtime for $domain is active."
    info "Socket: $run_dir/php.sock" "Logs:  $log_dir/php-fpm.log"
  else
    error "PHP $php_ver runtime for $domain failed to start!"
    journalctl -u "php-fpm@$domain" --no-pager | tail -20
    return 1
  fi
}
########################### ROLLBACK ########################
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
  for base in /var/log/nginx /var/log/apache /var/log/httpd; do
    if [[ -f "$base/$domain/${type}.log" ]]; then
      log="$base/$domain/${type}.log"
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
    "/var/log/nginx/$domain/access.log" "/var/log/nginx/$domain/error.log"
    "/var/log/apache2/$domain/access.log" "/var/log/apache2/$domain/error.log"
    "/var/log/httpd/$domain/access.log" "/var/log/httpd/$domain/error.log"
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
  info "Generating sitemap for $domain..."
  cat > "$sitemap" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset
    xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
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
      <loc>$url</loc>
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
  info "Generating robots page..."
  cat > "$robots" <<EOF
User-agent: *
Allow: /

# Block sensitive/system areas
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
  detect_env
  monitor_web_logs "$2"
fi
if ! systemctl is-active one-click-guard.service &> /dev/null; then
  systemctl daemon-reload
  systemctl enable one-click-guard.service --now
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
  local domain type
  domain="$1"
  type="$2"
  info "A remote backup will be processed by creating a local backup first" \
    "Once complete, it will be sent to your remote storage based on profile"
  resolve_profile "$domain"
  pass_profile=$(awk -v p="[$profile]" '
    $0==p {f=1; next}
    /^\[/ {f=0}
    f && /^E-PASSWD=/ {
      print substr($0,10)
      exit
    }
  ' "$profiles_file")
  if [[ -n "$pass_profile" ]]; then
    d_pass=$(decrypt_password "$pass_profile")
  fi
  if [[ "$type" == "wordpress" ]]; then
    wp_backup "$domain"
    base="/etc/one-click/wordpress"
  else
    static_backup "$domain"
    base="/etc/one-click/sites"
  fi
  shopt -s nullglob
  backups=( "$base/backups/$domain/"* )
  if (( ${#backups[@]} == 0 )); then
    error "No backups found for $domain"
    return 1
  fi
  sleep 3
  latest=$((printf '%s\n' "${backups[@]}" | sort -r | head -n1) || true)
  timestamp=$(basename "$latest")
  remote_path="$remote_base/$(hostname)/$domain/$timestamp"
  check_auth
  run_ssh "mkdir -p $remote_path"
  run_rsync "$latest/" "$remote_user@$remote_host:$remote_path/"
  success "Remote backup completed"
  return
}
remote_backup_scheduler() {
  local domain="${1:-}"
  [[ -z "$domain" ]] && { echo "[ERROR] No domain specified"; return 1; }
  cat <<EOF >/etc/cron.d/one-click-remote-backups
0 4 * * * root bash /var/cache/one-click/remote.sh -remoteback $domain    # One-Click Remote Backup
30 4 * * * root bash /var/cache/one-click/remote.sh -remoterotate $domain # One-Click Remote Rotate
EOF
  success "Cron jobs created for remote backups of $domain"
}
remote_restore() {
  local domain="$1"
  type="$2"
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
  remote_list "$domain" "" restore
  tmp="/tmp/oneclick-$domain-$ts"
  mkdir -p "$tmp"
  shopt -s nullglob
  run_rsync "$remote_user@$remote_host:$remote_base/*/$domain/$ts/" "$tmp/"
  if [[ "$type" == "wordpress" ]]; then
    wp_restore "$domain" "$tmp"
  else
    static_restore "$domain" "$tmp"
  fi
  rm -rf "$tmp"
}
remote_list() {
  local domain type
  domain="$1"
  d_pass="${2:-$d_pass}"
  local -a timestamps servers
  resolve_profile "$domain"
  check_auth
  echo -e "\e[34m╔════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Timestamp            ║ Server               ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╬══════════════════════╣\e[0m"
  mapfile -t backups < <(
    run_ssh "
      for d in $remote_base/*/$domain/*; do
        server=\$(echo \$d | cut -d'/' -f3)
        ts=\$(basename \$d)
        echo \"\$ts \$server\"
      done
    "
  )
  local i=1
  for b in "${backups[@]}"; do
    ts=$(awk '{print $1}' <<< "$b")
    server=$(awk '{print $2}' <<< "$b")
    timestamps+=("$ts")
    servers+=("$server")
    printf "\e[34m║ %-2s ║ %-20s ║ %-20s ║\e[0m\n" "$i" "$ts" "$server"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╩══════════════════════╝\e[0m"
  if [[ "${3:-}" == "restore" ]]; then
    local choice
    while true; do
      read -rp "${cyan}[USER]${blue} Select backup ID to restore: ${reset}" choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#timestamps[@]} )); then
        ts="${timestamps[$((choice-1))]}"
        return 0
      else
        error "Invalid choice, try again."
      fi
    done
  fi
  read -rp "${cyan}[USER]${blue} Press Enter to continue"
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
  profile_type=""
  profile_host=""
  profile_user=""
  profile_base=""
  profile_pass=""
  remote_enabled=false
  while IFS='=' read -r key value; do
    case "$key" in
      TYPE)
        profile_type="$value"
        ;;
      REMOTE_ENABLED)
        remote_enabled="$value"
        ;;
      HOST)
        profile_host="$value"
        ;;
      USER)
        profile_user="$value"
        ;;
      BASE_PATH)
        profile_base="$value"
        ;;
      E_PASSWD)
        profile_pass_enc="$value"
        ;;
    esac
  done < <(
    awk -v p="[$profile]" '
      $0==p {f=1; next}
      /^\[/ {f=0}
      f
    ' "$profiles_file"
  )
  [[ -z "$profile_type" ]] && {
    error "Profile not found"
    return
  }
  if [[ -n "$profile_pass_enc" ]]; then
    profile_pass=$(decrypt_password "$profile_pass_enc")
  fi
  export profile_type
  export remote_enabled
  export profile_host
  export profile_user
  export profile_base
  export profile_pass
  return 0
}
mirror_backup() {
  local domain="$1"
  local backup_path="$2"
  local timestamp="$3"
  [[ "$remote_enabled" != "true" ]] && return 0
  info "Replicating backup to remote profile..."
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
  use_sshpass=0
  # ==== Local profiles do not require SSH ====
  [[ "$remote_enabled" != "true" ]] && return 0
  # ==== Missing transport metadata ====
  [[ -z "$profile_host" || -z "$profile_user" ]] && {
    error "Profile transport metadata incomplete"
    return 1
  }
  if ssh \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o ConnectTimeout=5 \
      "${profile_user}@${profile_host}" \
      "exit" >/dev/null 2>&1; then
    use_sshpass=0
  else
    use_sshpass=1
  fi
  export use_sshpass
  return 0
}
run_ssh() {
  detect_auth_method || return 1
  if [[ "$remote_enabled" != "true" ]]; then
    error "Profile is not remote-enabled"
    return 1
  fi
  if [[ "$use_sshpass" == "1" ]]; then
    sshpass -p "$profile_pass" \
      ssh \
      -o StrictHostKeyChecking=no \
      "${profile_user}@${profile_host}" \
      "$1"
  else
    ssh \
      -o StrictHostKeyChecking=no \
      "${profile_user}@${profile_host}" \
      "$1"
  fi
}
run_rsync() {
  detect_auth_method || return 1
  if [[ "$remote_enabled" != "true" ]]; then
    error "Profile is not remote-enabled"
    return 1
  fi
  if [[ "$use_sshpass" == "1" ]]; then
    sshpass -p "$profile_pass" \
      rsync \
      -az \
      --progress \
      -e "ssh -o StrictHostKeyChecking=no" \
      "$@"
  else
    rsync \
      -az \
      --progress \
      -e "ssh -o StrictHostKeyChecking=no" \
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
            error "Token cannot be empty. Re-evaluating routing inputs..."
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
    info "Validating configuration lane metadata permissions..."
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
dns_add_record_backend() {
  local domain="$1" type="$2" host="$3" value="$4"
  local prio="${5:-0}" weight="${6:-0}" port="${7:-0}"
  local ttl=3600
  source "$(dns_domain_meta "$domain")"
  case "$PROVIDER" in
    bind|powerdns|pdns|local)
        local zone_file
        zone_file="$(dns_bind_zone_file "$domain")"
        [[ ! -f "$zone_file" ]] && { error "Zone storage file missing on local disk."; return 1; }
        case "$type" in
          A|AAAA|CNAME) printf "%-20s IN %-6s %s\n" "$host" "$type" "$value" >> "$zone_file" ;;
          TXT)          printf "%-20s IN %-6s \"%s\"\n" "$host" "$type" "$value" >> "$zone_file" ;;
          MX)           printf "%-20s IN %-6s %d %s.\n" "$host" "$type" "$prio" "$value" >> "$zone_file" ;;
          SRV)          printf "%-20s IN %-6s %d %d %d %s.\n" "$host" "$type" "$prio" "$weight" "$port" "$value" >> "$zone_file" ;;
        esac
        command -v systemctl &>/dev/null && (sudo systemctl reload bind9 || sudo systemctl reload named || sudo systemctl reload pdns) &>/dev/null
        ;;
    cloudflare)
        local zone_id payload
        zone_id="$(dns_cloudflare_get_zone_id "$domain")"
        case "$type" in
          A|AAAA|CNAME|TXT) payload="{\"type\":\"${type}\",\"name\":\"${host}\",\"content\":\"${value}\",\"ttl\":${ttl}}" ;;
          MX)               payload="{\"type\":\"MX\",\"name\":\"${host}\",\"content\":\"${value}\",\"priority\":${prio},\"ttl\":${ttl}}" ;;
          SRV)              payload="{\"type\":\"SRV\",\"name\":\"${host}\",\"ttl\":${ttl},\"data\":{\"priority\":${prio},\"weight\":${weight},\"port\":${port},\"target\":\"${value}\"}}" ;;
        esac
        dns_api_request "cloudflare" POST "/zones/${zone_id}/dns_records" "$payload"
        ;;
    digitalocean)
        local payload
        case "$type" in
          A|AAAA|CNAME|TXT) payload="{\"type\":\"${type}\",\"name\":\"${host}\",\"data\":\"${value}\",\"ttl\":${ttl}}" ;;
          MX)               payload="{\"type\":\"MX\",\"name\":\"${host}\",\"data\":\"${value}\",\"priority\":${prio},\"ttl\":${ttl}}" ;;
          SRV)              payload="{\"type\":\"SRV\",\"name\":\"${host}\",\"data\":\"${value}\",\"priority\":${prio},\"weight\":${weight},\"port\":${port},\"ttl\":${ttl}}" ;;
        esac
        dns_api_request "digitalocean" POST "/domains/${domain}/records" "$payload"
        ;;
    *)
        info "Routing generic structured payload envelope to provider custom endpoint: [$PROVIDER]..."
        local generic_payload="{\"type\":\"${type}\",\"name\":\"${host}\",\"value\":\"${value}\",\"ttl\":${ttl}}"
        dns_api_request "$PROVIDER" POST "/domains/${domain}/records" "$generic_payload"
        ;;
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
    info "Starting and enabling BIND service..."
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
    bind|local)
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
  printf "${orange}[DNS]${blue} =================================================\n"
  echo -e "                 ${yellow}DNS AUTHORITY STATUS${reset}"
  printf "${orange}=================================================${reset}\n"
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
      "║                 ${yellow}Registry Management${blue}                        ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Add/Configure DNS Provider${blue}                            ║" \
      "║ ${magenta}2${blue}  ║ ${green}Initialize New Domain Zone${blue}                            ║" \
      "║ ${magenta}3${blue}  ║ ${green}Add Record${blue}                                            ║" \
      "║ ${magenta}4${blue}  ║ ${green}List Records${blue}                                          ║" \
      "║ ${magenta}5${blue}  ║ ${green}Authority Status${blue}                                      ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option [0-5]: " choice
    case "$choice" in
      1) dns_provider_add; read -rp "Press enter..."                                                 ;;
      2) dns_init "${fqdn:-${1:-}}" "${ip:-${2:-}}" "${provider:-${3:-}}"; read -rp "Press enter..." ;;
      3) dns_add_record "$fqdn"; read -rp "Press enter..."                                           ;;
      4) dns_list_records "$fqdn"; read -rp "Press enter..."                                         ;;
      5) select_fqdn; dns_check_authority "$fqdn"; read -rp "Press enter..."                         ;;
      0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0                                  ;;
    esac
  done
}
################################### NEXTCLOUD ################################
install_nextcloud() {
  start_screen nextcloud
  local version="latest"
  local php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
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
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  nc_root="/etc/one-click/nextcloud/$domain"
  nc_webroot="$nc_root/www"
  nc_data="$nc_root/data"
  nc_logs="$nc_data/nextcloud.log"
  mkdir -p \
    "$nc_webroot" \
    "$nc_data" \
    "$nc_logs" \
    "$nc_root/backups" \
    "$nc_root/config"
  chmod 750 "$nc_root"
  warn "Creating web owner"
  web_user="${nc_user:4}_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  id "$web_user" &>/dev/null || useradd -r -m -s /usr/sbin/nologin "$web_user"
  echo
  # ==== REDIS? ====
  if [[ "$centos_ver" -lt 10 ]]; then
    while true; do
      read -rp "${cyan}[USER]${reset} Enable Redis (y|n): " enable_redis
      if [[ "$enable_redis" =~ ^[Yy](es)?|[Nn]o?$ ]]; then
        break
      fi
      warn "Please enter y or n"
    done
  else
    warn "CentOS $centos_ver does not support redis"
    enable_redis=n
  fi
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
  echo "NC_PASS=$nc_pass" >> "$nc_root/meta.conf"
  echo "DB_ENABLED=true" >> "$nc_root/meta.conf"
  echo "DB_PASS=$nc_db_pass" >> "$nc_root/meta.conf"
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
  info "Installing Nextcloud"
  curl -LO https://download.nextcloud.com/server/releases/latest.tar.bz2
  curl -LO https://download.nextcloud.com/server/releases/latest.tar.bz2.sha256
  grep 'latest.tar.bz2$' latest.tar.bz2.sha256 | sha256sum -c - || {
    error "Nextcloud checksum failed"
    return 1
  }
  if [[ ! $(sed -En '/# One-Click Routing/p' /etc/hosts) == "# One-Click Routing" ]]; then
    echo "# One-Click Routing" >> /etc/hosts
  elif [[ ! $(cat /etc/hosts) =~ 127.0.0.1.*"$domain" ]]; then
    sed -Ei.one-click_bak -e "/# One-Click/{a\127.0.0.1\t${domain}" -e '}' /etc/hosts
  fi
  echo -e "HOSTS_ENTRY=\"127.0.0.1\t${domain}\"" >> "$nc_root/meta.conf"
  tar -xjf latest.tar.bz2
  rsync -a nextcloud/ "$nc_webroot/"
  chmod o+x /etc/one-click
  chmod o+x /etc/one-click/nextcloud
  chmod o+x /etc/one-click/nextcloud/$domain
  chown -R "$web_user:$webserver_user" "$nc_root"
  rm -f latest*
  rm -rf nextcloud/
  info "Installing $webserver"
  install_webserver nextcloud "$domain" "$nc_webroot"
  info "Creating resource slice for $domain"
  info "Configuring PHP-FPM"
  create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "nextcloud"
  info "Enabling PHP"
  systemctl enable php-fpm@${domain}.service --now
  info "Configuring MariaDB"
  configure_nc_db
  dns_check
  info "Configuring Nextcloud"
  . "$nc_root/meta.conf"
  nc_db="$DB_NAME"
  sudo -u "$web_user" php \
    "$nc_webroot/occ" maintenance:install \
    --database "mysql" \
    --database-name "$nc_db" \
    --database-user "$nc_db_user" \
    --database-pass "$nc_db_pass" \
    --admin-user "$nc_user" \
    --admin-pass "$nc_pass" \
    --database-host "127.0.0.1" \
    --data-dir "$nc_data"
  sudo -u "$web_user" php "$nc_webroot/occ" \
    config:system:set trusted_domains 1 \
    --value="$domain"
  sudo -u "$web_user" php "$nc_webroot/occ" \
    config:system:set overwriteprotocol \
    --value="https"
  if [[ "$enable_redis" == "y" ]]; then
    info "Installing and configuring Redis"
    if [[ "$pkg_mgr" == "apt" ]]; then
      redis_ver=$(sort -rV <(awk '{print $3}' <(apt-cache madison redis-server 2>/dev/null)) | head -1)
      $pkg_mgr install -y redis-server php-redis
      systemctl enable redis-server --now
      local service="redis-${domain}"
      redis_conf="/etc/redis/redis.conf"
      php_user="$webserver"
    else
      if [[ -d /run/redis ]]; then
        redis_ver=$(sort -rV <(awk '$1=="redis"{print $2}' <(dnf module list redis 2>/dev/null)) | head -1)
        dnf -y module enable redis:$redis_ver
        $pkg_mgr install -y redis php-pecl-redis
        systemctl enable redis --now
        local service="redis-${domain}"
        redis_conf="/etc/redis/redis.conf"
        redis_execstart=/usr/bin/redis-server
      else
        redis_ver=$(sort -rV <(awk '$1=="valkey"{print $2}' <(dnf module list valkey 2>/dev/null)) | head -1)
        $pkg_mgr install -y php-pecl-redis
        local service="redis-${domain}"
        $pkg_mgr install -y valkey > /dev/null
        systemctl enable --now valkey > /dev/null
        conf="/etc/valkey/one-click/${domain}.conf"
        redis_conf="/etc/valkey/valkey.conf"
        redis_execstart=/usr/bin/valkey-server
      fi
      php_user="$webserver"
    fi
    redis_pw=$(openssl rand -base64 32)
    if [[ -d /run/valkey ]]; then
      sock="/run/valkey/redis-${domain}.sock"
      readpath=/run/valkey/
      redis_user=valkey
      redis_dir=valkey
      for red in /usr/bin/valkey-*; do
        cp -f $red /usr/bin/redis-${red##*-}
      done
    else
      sock="/run/redis/redis-${domain}.sock"
      readpath=/run/redis/
      redis_user=redis
      redis_dir=redis
    fi
    if ! redis-cli ping &>/dev/null; then
      error "Redis failed to install"
      return 1
    fi
    echo "REDIS_ENABLED=true" >> "$nc_root/meta.conf"
    echo "REDIS_VERSION=${redis_ver:-}" >> "$nc_root/meta.conf"
    echo "REDIS_SERVICE=$service" >> "$nc_root/meta.conf"
    echo "REDIS_SERVICE_CONF=/etc/systemd/system/php-fpm@${domain}.service.d/${domain}-redis.conf" >> "$nc_root/meta.conf"
    echo "REDIS_CONF=$redis_conf" >> "$nc_root/meta.conf"
    echo "REDIS_SOCK=$sock" >> "$nc_root/meta.conf"
    echo "REDIS_PASS=$redis_pw" >> "$nc_root/meta.conf"
    setup_redis "$domain"
    redis_service "$domain"
    usermod -aG $redis_user "$webserver_user"
    usermod -aG $redis_user "$web_user"
    systemctl daemon-reexec
    systemctl enable "${service}" --now
    for i in {1..10}; do
      if [[ -S "$sock" ]]; then
        break
      fi
      sleep 1
    done
    if [[ ! -S "$sock" ]]; then
      error "Socket $sock was never created. Check: journalctl -u redis-${domain}"
      return 1
    else
      success "Isolated redis socket created"
    fi
    chown $redis_user:$web_user "$sock"
    mkdir -p /etc/systemd/system/php-fpm@${domain}.service.d/
    cat > /etc/systemd/system/php-fpm@${domain}.service.d/${domain}-redis.conf <<EOF
[Service]
ReadWritePaths="$readpath"
EOF
    systemctl daemon-reload
    systemctl restart php-fpm@${domain}.service
    sudo -u "$web_user" php "$nc_webroot/occ" \
      config:system:set redis host --value="$sock"
    success "Redis installed and configured."
  fi
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver" -y
  info "Configuring SSL"
  install_letsencrypt wordpress
  set +o pipefail
  if [[ "${manual_install:-}" -eq 1 ]]; then
    webroot_nginx_template
  fi
  systemctl restart "$webserver"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site $domain > /dev/null 2>&1" > "/etc/cron.d/one-click_wp-web-monitor_nc_$domain"
  info "Fixing permissions"
  sleep 1
  check_permissions "$domain"
  systemctl reload "$webserver"
  success " Suit has now been installed!"
  info "Access the site from ${magenta}https://${domain}${reset}"
}
toggle_maintenance() {
  local output state
  output=$(sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode 2>&1)
  state=$(grep -qi "enabled" <<< "$output" && echo "enabled" || echo "disabled")
  if [[ "$state" == "enabled" ]]; then
    warn "Maintenance mode is currently ENABLED → disabling..."
    sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --off >/dev/null 2>&1 || {
      error "Failed to disable maintenance mode"
      return 1
    }
    success "Maintenance mode disabled"
  else
    warn "Maintenance mode is currently DISABLED → enabling..."
    sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --on >/dev/null 2>&1 || {
      error "Failed to enable maintenance mode"
      return 1
    }
    success "Maintenance mode enabled"
  fi
}
occ_console() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  info "Enter OCC command"
  read -rp "${cyan}[USER]${reset} occ> " occ_cmd
  sudo -u "$web_user" php "$nc_webroot/occ" $occ_cmd
}
reset_nextcloud_password() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  sudo -u "$web_user" php "$nc_webroot/occ" \
    user:resetpassword "$nc_user"
}
backup_nextcloud_instance() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  nc_db="$DB_NAME"
  data="/etc/one-click/nextcloud/${domain}/data"
  timestamp=$(date +%F-%H%M%S)
  backup_root="/etc/one-click/nextcloud/${domain}/backups/${timestamp}"
  mkdir -p \
    "$backup_root/files" \
    "$backup_root/data" \
    "$backup_root/db"
  info "Enabling maintenance mode"
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --on
  info "Dumping database"
  mysqldump "$nc_db" > \
    "$backup_root/db/database.sql"
  info "Syncing application files"
  rsync -a \
    "$nc_webroot/" \
    "$backup_root/files/"
  info "Syncing data directory"
  rsync -a \
    "$data/" \
    "$backup_root/data/"
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --off
  success "Backup complete"
}
restore_nextcloud_backup() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  backup=$(find \
    "/etc/one-click/nextcloud/${domain}/backups" \
    -mindepth 1 -maxdepth 1 \
    | fzf)
  [[ -z "$backup" ]] && return 1
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --on
  rsync -a --delete \
    "$backup/files/" \
    "$nc_webroot/"
  rsync -a --delete \
    "$backup/data/" \
    "$data/"
  mysql "$nc_db" < \
    "$backup/db/database.sql"
  sudo -u "$wen_user" php "$nc_webroot/occ" maintenance:repair
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --off
}
tail_nextcloud_logs() {
  . "/etc/one-click/nextcloud/${domain}/meta.conf" || {
    echo "Failed to load metadata"
    return 1
  }
  local log_file="/etc/one-click/nextcloud/nginx2.test/logs/"
  [[ ! -f "$log_file" ]] && {
    echo "Nextcloud log not found: $log_file"
    return 1
  }
  clear
  printf "\n"
  printf "╔══════════════════════════════════════════════════════════════╗\n"
  printf "║                   Nextcloud Live Log View                  ║\n"
  printf "╚══════════════════════════════════════════════════════════════╝\n"
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
      1) colour='\033[0;36m'; level_name="INFO" ;;
      2) colour='\033[1;33m'; level_name="WARN" ;;
      3) colour='\033[1;31m'; level_name="ERROR" ;;
      4) colour='\033[1;35m'; level_name="FATAL" ;;
      *) colour='\033[0m'; level_name="$level" ;;
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
  info "Restarting Nextcloud services for ${domain}"
  local php_unit="php-fpm@${domain}.service"
  local redis_unit="redis-${domain}.service"
  if systemctl cat "$php_unit" >/dev/null 2>&1; then
    info "Restarting ${php_unit}"
    if systemctl restart "$php_unit"; then
      success "PHP-FPM restarted"
    else
      error "Failed to restart ${php_unit}"
    fi
  else
    warn "PHP unit not found: ${php_unit}"
  fi
  if systemctl cat "$redis_unit" >/dev/null 2>&1; then
    info "Restarting ${redis_unit}"
    if systemctl restart "$redis_unit"; then
      success "Redis restarted"
    else
      error "Failed to restart ${redis_unit}"
    fi
  else
    warn "Redis unit not found: ${redis_unit}"
  fi
  info "Reloading nginx"
  if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx \
      && success "Nginx reloaded" \
      || error "Failed to reload nginx"
  else
    error "Nginx configuration test failed"
    return 1
  fi
  local sock="/run/one-click/${domain}/php.sock"
  if [[ -S "$sock" ]]; then
    success "PHP socket active: $sock"
  else
    warn "PHP socket missing: $sock"
  fi
  success "Nextcloud services restarted"
}
repair_nextcloud_instance() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  info "Running Nextcloud repair"
  harden_nextcloud
  info "Validating OCC"
  php "$nc_webroot/occ" status || {
    error "OCC validation failed"
    return 1
  }
  info "Running maintenance repair"
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:repair
  info "Repairing mimetypes"
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mimetype:update-db
  info "Repairing indexes"
  sudo -u "$web_user" php "$nc_webroot/occ" db:add-missing-indices
  info "Repairing columns"
  sudo -u "$web_user" php "$nc_webroot/occ" db:add-missing-columns
  info "Repairing primary keys"
  sudo -u "$web_user" php "$nc_webroot/occ" db:add-missing-primary-keys
  info "Restarting PHP-FPM"
  systemctl restart php-fpm@$domain
  success "Repair & Hardening complete"
}
harden_nextcloud() {
  . "/etc/one-click/nextcloud/${domain}/meta.conf" || {
    error "Failed to load metadata"
    return 1
  }
  local nc_root="${SITE_DIR}"
  local nc_user="${SITE_USER}"
  local nc_group="${SITE_GROUP}"
  [[ ! -d "$nc_root" ]] && {
    error "Nextcloud directory not found: $nc_root"
    return 1
  }
  info "Hardening Nextcloud: ${domain}"
  chown -R "${nc_user}:${nc_group}" "$nc_root"
  find "$nc_root" -type d -exec chmod 750 {} \;
  find "$nc_root" -type f -exec chmod 640 {} \;
  [[ -f "$nc_root/config/config.php" ]] &&
    chmod 600 "$nc_root/config/config.php"
  [[ -f "$nc_root/.htaccess" ]] &&
    chmod 644 "$nc_root/.htaccess"
  if [[ -d "$nc_root/data" ]]; then
    chmod 750 "$nc_root/data"
    chown -R "${nc_user}:${nc_group}" "$nc_root/data"
  fi
  rm -rf \
    "$nc_root/updater_backup" \
    "$nc_root/core/skeleton" \
    "$nc_root/tests" \
    "$nc_root/build" \
    "$nc_root/dev" \
    "$nc_root/.github" \
  2>/dev/null
  cat > "$nc_root/.user.ini" <<'EOF'
expose_php=Off
display_errors=Off
log_errors=On
session.cookie_httponly=1
session.cookie_secure=1
session.use_strict_mode=1
EOF
  if command -v sudo >/dev/null; then
    sudo -u "$nc_user" php "$nc_root/occ" config:system:set \
      auth.bruteforce.protection.enabled \
      --type=boolean --value=true >/dev/null 2>&1
    sudo -u "$nc_user" php "$nc_root/occ" config:system:set \
      filesystem_check_changes \
      --type=integer --value=0 >/dev/null 2>&1
    sudo -u "$nc_user" php "$nc_root/occ" config:system:set \
      check_for_working_htaccess \
      --type=boolean --value=true >/dev/null 2>&1
    sudo -u "$nc_user" php "$nc_root/occ" config:system:set \
      default_phone_region \
      --value="GB" >/dev/null 2>&1
    sudo -u "$nc_user" php "$nc_root/occ" maintenance:update:htaccess \
      >/dev/null 2>&1
  fi
  find "$nc_root" \
    -name "*.pem" \
    -o -name "*.key" \
    -o -name "*.crt" \
    -o -name "*.p12" \
      | while read -r cert; do
        chmod 600 "$cert"
    done
  find "$nc_root/apps" -type d -exec chmod 750 {} \;
  find "$nc_root/apps" -type f -exec chmod 640 {} \;
  if [[ -f "$nc_root/occ" ]]; then
    sudo -u "$nc_user" php "$nc_root/occ" integrity:check-core \
      >/dev/null 2>&1 || true
  fi
  success "Nextcloud hardening complete"
}
update_nextcloud_instance() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  backup_nextcloud_instance
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --on
  curl -LO \
    https://download.nextcloud.com/server/releases/latest.tar.bz2
  tar -xjf latest.tar.bz2
  rsync -a \
    --exclude=config \
    --exclude=data \
    nextcloud/ \
    "$nc_webroot/"
  sudo -u "$web_user" php "$nc_webroot/occ" upgrade
  sudo -u "$web_user" php "$nc_webroot/occ" maintenance:mode --off
  repair_nextcloud_instance
}
nextcloud_status() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  sudo -u "$web_user" php "$nc_webroot/occ" status
  echo
  systemctl status php-fpm@$domain --no-pager
  echo
  df -h "$data"
}
remove_nextcloud_instance() {
  . /etc/one-click/nextcloud/${domain}/meta.conf
  web_user="$SITE_USER"
  nc_webroot="$SITE_DIR"
  nc_db="$DB_NAME"
  nc_db_user="$DB_USER"
  nc_root="/etc/one-click/nextcloud/${domain}"
  read -rp \
    "${cyan}[USER]${reset} Destroy ${domain}? This is irreversible (y|n): " confirm
  [[ "$confirm" != "yes" ]] && return 1
  systemctl stop php-fpm@${domain}
  rm -rf "$nc_root"
  mysql <<EOF
DROP DATABASE ${nc_db};
DROP USER '${nc_db_user}'@'localhost';
EOF
  userdel "$web_user"
  rm -f \
    "/etc/nginx/conf.d/${domain}.conf"
  rm -f \
    "/etc/one-click/db-manager/sites/${domain}.conf"
  if [[ "$webserver" == "nginx" ]]; then
    systemctl reload nginx
  elif [[ "$webserver" == "httpd" ]]; then
    systemctl reload httpd
  else
    systemctl reload apache2
  fi
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
      "║ ${magenta}0${blue}  ║ ${green}Exit${blue}                                                  ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}"
    read -rp "${cyan}[USER]${reset} Select option [0-9]: " choice
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
      0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
    esac
  done
}
################################# SITE REMOVAL ###############################
delete_site() {
  local domain="$1"
  detect_env
  resolve_type "$domain"
  web_user=$(stat -c '%U' "/etc/one-click/${type}/$domain" 2>/dev/null)
  local slice_name="one-click_${domain}.slice"
  local service_name="php-fpm@${domain}.service"
  local site_user
  [[ -z "$domain" ]] && { error "No domain provided"; return; }
  warn "This will delete ALL $domain domains. Be careful if you have the same domain under different hosting types!"
  read -rp "${cyan}[USER]${red} WARNING: Delete $domain permanently? (y|n): ${reset}" confirm
  [[ "$confirm" != "y" ]] && { info "Cancelled"; return; }
  info "Tearing down $domain..."
  site_user=$(get_site_user "$domain")
  # ==== Extract DB ====
  if [[ "$type" == "wordpress" ]]; then
    wp_config="/etc/one-click/wordpress/$domain/wp-config.php"
    if [[ -f "$wp_config" ]]; then
      db_name=$(sed -En "/DB_NAME/s/.*'([^']+)'.*/\1/p" "$wp_config")
      db_user=$(sed -En "/DB_USER/s/.*'([^']+)'.*/\1/p" "$wp_config")
    fi
  fi
  # ==== Stop services ====
  systemctl disable --now "$service_name" 2>/dev/null
  systemctl stop "$slice_name" 2>/dev/null
  # ==== Remove systemd ====
  (rm -f "/etc/systemd/system/$service_name"
  rm -f "/etc/systemd/system/$slice_name"
  # ==== PHP-FPM ====
  rm -f "/etc/php-fpm.d/${domain}.conf"
  rm -f "/etc/php/${domain}.conf"
  rm -f "/run/php${php_ver:-}-fpm-${domain}.sock") 2> /dev/null
  systemctl reload php-fpm 2>/dev/null || systemctl reload php*-fpm
  # ==== DB cleanup ====
  if [[ "$type" == "wordpress" && -n "$db_name" ]]; then
    read -rp "${cyan}[USER]${blue} Delete DB $db_name? (y|n): ${reset}" db_confirm
    if [[ "$db_confirm" == "y" ]]; then
      info "Removing database: $db_name"
      mysql -e "DROP DATABASE IF EXISTS \`$db_name\`;"
      info "Checking if other sites share DB user: $db_user"
      user_occurrence=$((grep -r "DB_USER.*'$db_user'" /etc/one-click/wordpress/*/wp-config.php 2>/dev/null | wc -l) || true)
      if [[ "$user_occurrence" -le 1 ]]; then
        info "dry_run$db_user. Dropping user..."
        mysql -e "DROP USER IF EXISTS '$db_user'@'localhost';" || true
      else
        warn "DB User $db_user is still in use by $((user_occurrence - 1)) other site(s). Skipping user deletion."
      fi
    fi
  fi
  # ==== Webserver ====
  if [[ "$webserver" == "nginx" ]]; then
    (rm -f "/etc/nginx/sites-available/$domain.conf"
    rm -f "/etc/nginx/sites-enabled/$domain.conf"
    rm -f "/etc/nginx/conf.d/$domain.conf") 2> /dev/null
    systemctl reload nginx
  else
    (rm -f "/etc/apache2/sites-available/$domain.conf"
    rm -f "/etc/httpd/conf.d/$domain.conf") 2> /dev/null
    systemctl reload apache2 2>/dev/null || systemctl reload httpd
  fi
  # ==== Files ====
  (rm -rf "/etc/one-click/${type}/$domain"
  # ==== Backups ====
  rm -rf "/etc/one-click/${type}/backups/$domain"
  rm -rf "/etc/one-click/${type}/rollback/$domain"
  # ==== Logs ====
  rm -f /var/log/php-fpm-$domain.log
  rm -f /var/log/nginx/$domain*.log 2>/dev/null
  rm -f /var/log/httpd/$domain*.log 2>/dev/null
  # ==== Redis ====
  systemctl disable --now "redis-${domain}" 2>/dev/null
  rm -f "/etc/systemd/system/redis-${domain}.service"
  # ==== SSL ====
  rm -rf "/etc/letsencrypt/live/$domain"
  rm -rf "/etc/letsencrypt/archive/$domain"
  rm -f "/etc/letsencrypt/renewal/$domain.conf") 2> /dev/null
  # ==== MISC LOST+FOUND ====
  warn "Stopping services owned by $domain"
  find /etc/systemd /usr/lib/systemd /lib/systemd \
    -type f -name "*${domain}*.service" 2>/dev/null |
    while read -r line; do
     systemctl disable --now "$(basename "$line")"
    done
  warn "Deleting all other associated files and directories for $domain"
  find / \
  \( \
    -path "/sys" -o \
    -path "/proc" -o \
    -path "/dev" -o \
    -path "/run" -o \
    -path "/boot" -o \
    -path "/usr" -o \
    -path "/lib" -o \
    -path "/lib64" -o \
    -path "/var/log" -o \
    -path "/etc/one-click/wordpress/backups" -o \
    -path "/etc/one-click/sites/backups" -o \
    -path "/etc/one-click/apps/nodejs/backups" -o \
    -path "/etc/one-click/wordpress/rollback" -o \
    -path "/etc/one-click/sites/rollback" -o \
    -path "/etc/one-click/apps/nodejs/rollback" -o \
    -path "/etc/one-click/db-manager/secrets/db/" -o \
    -path "/etc/one-click/db-manager/sites/" \
  \) -prune \
  -o -path "*$domain*" -exec rm -rf {} + 2>/dev/null
  # ==== Remove system user ====
  set +o pipefail
  info "Removing system user $site_user"
  if id "$site_user" &>/dev/null; then
    gpasswd -d "$webserver" "$site_user" 2>/dev/null
    userdel -r "$site_user"
  fi
  set -o pipefail
  # ==== Systemd cleanup ====
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl reset-failed
  success "Fully removed $domain"
}
get_monitor_stats() {
  local domain="${1:-}"
  find /etc/one-click/{sites,wordpress,apps/nodejs}/ -maxdepth 1 \
    | while read -r site_mon; do
      if [[ "$site_mon" =~ \. ]]; then 
        mon=$(basename $site_mon)
        #monitor "$mon"
        echo $mon
      fi
    done
  local profile_file="/etc/one-click/monitor/${domain}/${domain}.profile"
  local status_file="/etc/one-click/monitor/${domain}/monitor_status"
  local log_file="/var/log/${webserver}/${domain}/monitor.log"
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
  log_file="/var/log/${webserver}/${domain}/monitor.log"
  mkdir -p "/etc/one-click/monitor/${domain}" "/var/log/${webserver}/${domain}"
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
  domain="$(normalize_domain "$domain")"
  if [[ -d /etc/one-click/nextcloud/${domain} ]]; then
    type=nextcloud
  elif [[ -d /etc/one-click/sites/${domain} ]]; then
    type=static
  elif [[ -d /etc/one-click/apps/nodejs/${domain} ]]; then
    type=nodejs
  elif [[ -d /etc/one-click/wordpress/${domain} ]]; then
    type=wordpress
  fi
  db_port=$(awk -F= '/port =/{print $2}' /etc/mysql/my.cnf)
  local meta_file="/etc/one-click/${type}/${domain}/meta.conf"
  local php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
  passfile="/etc/one-click/db-manager/secrets/db/${domain}.pass"
  mkdir -p ${db_manager_dir}/secrets/db
  chmod 700 ${db_manager_dir}/secrets
  chmod 700 ${db_manager_dir}/secrets/db
  if [[ -z "$domain" ]]; then
    error "Missing domain"
    return
  fi
  if [[ -z "$type" ]]; then
    error "Missing type"
    return
  fi
  if [[ ! -d "$sitectl_dir" ]]; then
    error "Registry directory missing: $sitectl_dir"
    return
  fi
  if [[ -f "$meta_file" ]]; then
    . "$meta_file" || true
    if [[ -d "/etc/one-click/${type}/$domain" ]]; then
      info "Creating $passfile"
      echo "$DB_PASS" > "$passfile"
      db_status=true
    fi
  else
    error "Meta file is missing!"
    return
  fi
  if registry_exists "$domain"; then
    error "Site registry already exists"
    return
  fi
  if [[ ! $(sed -En '/# One-Click Routing/p' /etc/hosts) == "# One-Click Routing" ]]; then
    echo "# One-Click Routing" >> /etc/hosts
    sed -Ei.one-click_bak -e "/# One-Click/{a\127.0.0.1\t${domain}" -e '}' /etc/hosts
  elif [[ ! $(cat /etc/hosts) =~ 127.0.0.1.*"$domain" ]]; then
    sed -Ei.one-click_bak -e "/# One-Click/{a\127.0.0.1\t${domain}\t# One-Click Entry" -e '}' /etc/hosts
  fi
  echo -e "HOSTS_ENTRY=\"127.0.0.1\t${domain}\"" >> "$meta_file"
  local nginx_vhost=""
  local apache_vhost=""
  if [[ "${WEBSERVER:-}" == "nginx" ]]; then
    nginx_enabled="true"
    nginx_vhost="$VHOST"
    apache_enabled="false"
  elif [[ "${WEBSERVER:-}" == "apache" || "${WEBSERVER:-}" == "apache2" ]]; then
    apache_enabled="true"
    apache_vhost="$VHOST"
    nginx_enabled="false"
  else
    nginx_enabled="false"
    apache_enabled="false"
    warn "Unknown webserver type [${WEBSERVER:-}] in meta.conf"
  fi
  local wp_detected="false"
  local wp_prefix="null"
  if [[ "$type" == "wordpress" ]]; then
    wp_detected="true"
    wp_prefix="\"${DB_PREFIX:-oc_}\""
  fi
  pool_enabled=false
  if systemctl status php-fpm@${domain}.service > /dev/null; then
    pool_enabled=true
  fi
  local databases_json_array="[]"
  local users_json_array="[]"
  if [[ -n "${DB_NAME:-}" ]]; then
    databases_json_array="[{\"name\": \"$DB_NAME\", \"role\": \"primary\"}]"
  fi
  if [[ -n "${DB_USER:-}" ]]; then
    users_json_array="[\"$DB_USER\"]"
  fi
  local ssl_enabled="false"
  local http2_enabled="false"
  if [[ "$nginx_enabled" == "true" && -f "$nginx_vhost" ]]; then
    if grep -qE 'listen .*:443.*ssl' "$nginx_vhost"; then
      ssl_enabled="true"
    fi
    if grep -qE 'listen .*:443.*http2|http2\s+on' "$nginx_vhost"; then
      http2_enabled="true"
    fi
  elif [[ "$apache_enabled" == "true" && -f "$apache_vhost" ]]; then
    if grep -qE '<VirtualHost .*:443>' "$apache_vhost" && grep -q 'SSLEngine on' "$apache_vhost"; then
      ssl_enabled="true"
    fi
    if grep -qE 'Protocols.*h2' "$apache_vhost"; then
      http2_enabled="true"
    fi
  fi
  basedir_enabled=false
  if grep -E 'open_basedir' /etc/one-click/php/${domain}/pool.conf > /dev/null; then
    basedir_enabled=true
  fi
  ui_enabled=false
  if [[ ! -f "/etc/one-click/${type}/${domain}/www/db/adminer-disabled.php" ]]; then
    ui_enabled=true
  fi
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local pool
  pool=$(echo "$domain" | tr '.' '_')
  local json
  json=$(cat <<EOF
{
  "version": 1,
  "site": {
    "domain": "$domain",
    "aliases": [],
    "type": "$type",
    "root": "$SITE_DIR",
    "created_at": "$created_at",
    "status": "active"
  },
  "php": {
    "enabled": $pool_enabled,
    "version": "$php_ver",
    "pool": "$pool",
    "socket": "/run/one-click/$domain/php.sock"
  },
  "database": {
    "enabled": "${db_status:-null}",
    "engine": "MariaDB",
    "host": "$(hostname -s)",
    "port": ${db_port:-3306},
    "primary": {
      "name": "${DB_NAME:-null}",
      "user": "${DB_USER:-null}"
    },
    "databases": $databases_json_array,
    "users": $users_json_array,
    "password_file": "${db_manager_dir}/secrets/db/${domain}.pass",
    "ui_enabled": $ui_enabled
  },
  "nginx": {
    "enabled": $nginx_enabled,
    "vhost": "$nginx_vhost",
    "ssl": $ssl_enabled,
    "http2": $http2_enabled
  },
  "apache": {
    "enabled": $apache_enabled,
    "vhost": "$apache_vhost",
    "ssl": "$ssl_enabled",
    "http2": "$http2_enabled"
  },
  "wordpress": {
    "detected": "$wp_detected",
    "table_prefix": $wp_prefix
  },
  "security": {
    "isolated_pool": $basedir_enabled,
    "open_basedir": $basedir_enabled
  },
  "backup": {
    "enabled": false,
    "last_backup": null
  }
}
EOF
)
  if ! echo "$json" | jq empty >/dev/null 2>&1; then
    error "Generated invalid JSON"
    return
  fi
  if ! echo "$json" > "$registry"; then
    error "Failed to write registry"
    return
  fi
  if [[ ! -f "$registry" ]]; then
    error "Registry was not created"
    return
  fi
  success "Registry created"
  info "$registry"
  mkdir -p "/etc/one-click/${type}/${domain}/www/db"
  install_adminer 2> /dev/null \
    | sed -E '/^(Submodule|Cloning|remote|From|Unpacking|Missing| ?\*|adminer|PHP|Receiving|Resolving|Note:|^$|)/d'
  cat > "/etc/one-click/${type}/${domain}/www/db/index.php" <<EOF
<?php

ini_set('display_errors', 0);
error_reporting(E_ALL);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

\$pathParts = explode('/', str_replace('\\\\', '/', __FILE__));
\$currentDomain = \$pathParts[count(\$pathParts) - 4] ?? '';

\$registryFile =
    "/etc/one-click/db-manager/sites/" .
    \$currentDomain .
    ".json";

if (!file_exists(\$registryFile)) {
    http_response_code(500);
    exit("Registry missing");
}

\$registry = json_decode(
    file_get_contents(\$registryFile),
    true
);

if (!\$registry) {
    http_response_code(500);
    exit("Registry decode failed");
}

if (!(\$registry['database']['ui_enabled'] ?? false)) {
    session_unset();
    session_destroy();

    http_response_code(403);
    exit("UI Disabled");
}

\$passwordFile =
    \$registry['database']['password_file'] ?? '';

if (!\$passwordFile || !file_exists(\$passwordFile)) {
    http_response_code(500);
    exit("Password file missing");
}

if (array_key_exists('token', \$_GET)) {

    \$token = \$_GET['token'];

    if (!preg_match('/^[a-zA-Z0-9\-]+$/', \$token)) {
        http_response_code(403);
        exit("Invalid token format");
    }

    \$tokenFile =
        "/etc/one-click/db-manager/runtime/tokens/" .
        \$token .
        ".json";

    if (!file_exists(\$tokenFile)) {
        http_response_code(403);
        exit("Invalid token");
    }

    \$data = json_decode(
        file_get_contents(\$tokenFile),
        true
    );

    if (!\$data) {
        http_response_code(403);
        exit("Invalid token data");
    }

    \$tokenDomain =
        trim(\$data['domain'] ?? '');

    \$expectedDomain =
        trim(\$currentDomain);

    if (
        strcasecmp(
            \$tokenDomain,
            \$expectedDomain
        ) !== 0
    ) {
        http_response_code(403);
        exit("Invalid token verification data");
    }

    if ((\$data['expires'] ?? 0) < time()) {

        @unlink(\$tokenFile);

        http_response_code(403);
        exit("Token expired");
    }

    \$_SESSION['oneclick_db_auth'] =
        \$expectedDomain;

    \$_SESSION['oneclick_db_ip'] =
        \$_SERVER['REMOTE_ADDR'] ?? '';

    \$_SESSION['oneclick_db_ua'] =
        \$_SERVER['HTTP_USER_AGENT'] ?? '';

    \$_SESSION['oneclick_db_last_activity'] =
        time();

    session_regenerate_id(true);

    @unlink(\$tokenFile);
}

\$timeout = 1800;

if (
    isset(\$_SESSION['oneclick_db_last_activity']) &&
    (
        time() -
        \$_SESSION['oneclick_db_last_activity']
    ) > \$timeout
) {

    session_unset();
    session_destroy();

    http_response_code(403);
    exit("Session expired");
}

\$_SESSION['oneclick_db_last_activity'] =
    time();

\$sessionAuth =
    \$_SESSION['oneclick_db_auth'] ?? '';

\$sessionIP =
    \$_SESSION['oneclick_db_ip'] ?? '';

\$sessionUA =
    \$_SESSION['oneclick_db_ua'] ?? '';

\$currentIP =
    \$_SERVER['REMOTE_ADDR'] ?? '';

\$currentUA =
    \$_SERVER['HTTP_USER_AGENT'] ?? '';

if (
    \$sessionAuth !== \$currentDomain ||
    \$sessionIP !== \$currentIP ||
    \$sessionUA !== \$currentUA
) {

    session_unset();
    session_destroy();

    http_response_code(403);
    exit("Unauthorized");
}

if (!array_key_exists('username', \$_GET)) {
    \$_GET['username'] = '';
}

function adminer_object() {

    class OneClickAdminer extends Adminer {

        private \$registry;

        public function __construct() {

            global \$currentDomain;

            \$registryFile =
                "/etc/one-click/db-manager/sites/" .
                \$currentDomain .
                ".json";

            \$this->registry = json_decode(
                file_get_contents(\$registryFile),
                true
            );
        }

        function credentials() {

            \$passwordFile =
                \$this->registry['database']['password_file'];

            return [
                'localhost',
                \$this->registry['database']['primary']['user'],
                trim(file_get_contents(\$passwordFile))
            ];
        }

        function database() {

            return
                \$this->registry['database']['primary']['name'];
        }

        function name() {

            global \$currentDomain;

            return
                'One-Click DB Manager (' .
                \$currentDomain .
                ')';
        }
    }

    return new OneClickAdminer;
}

if (file_exists(__DIR__ . "/adminer.php")) {

    \$_GET['server'] = 'localhost';

    \$_GET['username'] =
        \$registry['database']['primary']['user'] ?? '';

    \$_GET['db'] =
        \$registry['database']['primary']['name'] ?? '';

    \$_SESSION['pwds']['server']['localhost']
        [\$_GET['username']] =
        trim(file_get_contents(\$passwordFile));

    include __DIR__ . "/adminer.php";

} else {

    http_response_code(500);
    exit("UI Disabled. Please enable first.");
}
EOF
  registry_sync_databases "$domain"
  registry_detect_wordpress "$domain"
  check_permissions "$domain"
  success "Registry successfully generated"
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
  #local jq_filter=".site.enabled = true"
  local jq_filter="$2"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return 1
  fi
  local tmpfile
  tmpfile=$(mktemp)
  if ! jq "$jq_filter" "$registry" > "$tmpfile"; then
    rm -f "$tmpfile"
    error "jq update failed"
    return 1
  fi
  if ! jq empty "$tmpfile" 2>/dev/null; then
    rm -f "$tmpfile"
    error "Update produced invalid JSON"
    return 1
  fi
  mv "$tmpfile" "$registry"
  success "Registry updated"
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
  domain="$(normalize_domain "$domain")"
  local db_name="$2"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return 1
  fi
  if [[ -z "$db_name" ]]; then
    error "Database name required"
    return 1
  fi
  if ! db_exists "$db_name"; then
    error "Database does not exist: $db_name"
    return 1
  fi
  local engine
  engine=$(db_detect_engine)
  if [[ -z "$engine" ]]; then
    error "Unable to detect database engine"
    return 1
  fi
  local tmpfile
  tmpfile=$(mktemp)
  jq \
  --arg db "$db_name" \
  --arg engine "$engine" '
    .database.enabled = true |
    .database.databases //= [] |
    .database.databases += [{
      "name": $db,
      "role": "primary"
    }] |
    .database.databases //= [] |
    .database.databases += [{
      "name": $db,
      "role": "primary"
    }] |
    .database.engine = $engine
  ' "$registry" > "$tmpfile" || {

      rm -f "$tmpfile"
      error "Failed to link database"
      return 1
    }
  mv "$tmpfile" "$registry"
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
  domain="$(normalize_domain "$domain")"
  . /etc/one-click/${type}/${domain}/meta.conf || . /etc/one-click/apps/${type}/${domain}/meta.conf
  local registry="${sitectl_dir}/${domain}.json"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    warn "Please create site registry for full access to this module"
    touch skip_reg_check
    return
  fi
  local db_list
  db_list=$(db_detect_domain_databases "$domain")
  [[ -z "$db_list" ]] && {
    warn "No databases detected for $domain"
    info "Please create a database for full functionality of this tool"
  }
  local tmpfile
  tmpfile=$(mktemp)
  jq --argjson dbs "$(printf '%s\n' "$db_list" | jq -R . | jq -s .)" '
    .database.databases //= [] |
    reduce $dbs[] as $db (
      .;
      if any(.database.databases[]?; .name == $db) then
        .
      else
        .database.databases += [{
          "name": $db,
          "role": "secondary"
        }]
      end
    )
  ' "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Failed to sync databases"
    return 1
  }
  mv "$tmpfile" "$registry"
  chown "$SITE_USER":"$SITE_GROUP" "$registry"
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
  domain="$(normalize_domain "$domain")"
  . /etc/one-click/${type}/${domain}/meta.conf
  registry_update "$domain" '
    .database.ui_enabled = true
  '
  if [[ -f "/etc/one-click/${type}/${domain}/www/db/adminer.php" ]]; then
    error "UI is already enabled"
    return
  fi
  mv -f /etc/one-click/${type}/${domain}/www/db/adminer-disabled.php /etc/one-click/${type}/${domain}/www/db/adminer.php
  success "$domain DB UI has been enabled"
}
registry_disable_db_ui() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  . /etc/one-click/${type}/${domain}/meta.conf
  if [[ -f "/etc/one-click/${type}/${domain}/www/db/adminer-disabled.php" ]]; then
    error "UI is already disabled"
    return
  fi
  registry_update "$domain" '
    .database.ui_enabled = false
  '
  mv -f /etc/one-click/${type}/${domain}/www/db/adminer.php /etc/one-click/${type}/${domain}/www/db/adminer-disabled.php
  warn "$domain DB UI has been disabled"
}
install_adminer() {
  local a_base="/etc/one-click/${type}"
  local target="$a_base/${domain}/www/db"
  local build="/tmp/adminer-build"
  echo "ADMINER_DIR=$target" >> "$a_base/${domain}/meta.conf"
  rm -rf "$build"
  mkdir -p "$target" "$build"
  cd "$build"
  set +o pipefail
  git clone https://github.com/vrana/adminer.git "$build" || {
    error "Failed to clone Adminer"
    return 1
  }
  git checkout v4.8.1 || {
    error "Failed to checkout Adminer version"
    return 1
  }
  git config --global url."https://".insteadOf git://
  git submodule update --init --recursive || {
    error "Failed to fetch Adminer submodules"
    return 1
  }
  php compile.php || {
    error "Adminer compile failed"
    return 1
  }
  [[ ! -f adminer-4.8.1.php ]] && {
    error "Compiled Adminer missing"
    return 1
  }
  cp adminer-4.8.1.php $target/adminer-disabled.php || {
    error "Failed to deploy Adminer"
    return 1
  }
  set -o pipefail
  chmod 644 "$target/adminer-disabled.php"
  success "Compiled Adminer installed for $domain"
  info "Be sure to enable the UI to use"
  return
}
db_generate_password() {
  openssl rand -base64 32 | tr -d '\n'
}
db_password_file() {
  local domain="$1"
  echo "${db_manager_dir}/secrets/db/${domain}.pass"
}
db_write_password() {
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local password="$2"
  local passfile
  passfile=$(db_password_file "$domain")
  echo "$password" > "$passfile"
  chmod 600 "$passfile"
}
db_create_user() {
  local a_base="/etc/one-click/${type}"
  local domain="$1"
  domain="$(normalize_domain "$domain")"
  local db_name
  db_name=$(db_from_domain "$domain")
  local db_user
  db_user=$(db_generate_user)
  local password
  password=$(db_generate_password)
  local password_file=$(db_password_file "$domain")
  local tmpfile=$(mktemp)
  echo "DB_NAME=$db_name" >> "$a_base/${domain}/meta.conf"
  echo "DB_USER=$db_user" >> "$a_base/${domain}/meta.conf"
  echo "DB_PASS=$db_n" >> "$a_base/${domain}/meta.conf"
  mysql <<EOF
CREATE USER IF NOT EXISTS '${db_user}'@'localhost'
IDENTIFIED BY '${password}';

GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';

FLUSH PRIVILEGES;
EOF
  if [[ $? -ne 0 ]]; then
    error "Failed to create DB user"
    return 1
  fi
  jq \
  --arg user "$db_user" \
  --arg db "$db_name" \
  --arg passfile "$password_file" '
  .database.enabled = true |
  .database.engine = "mariadb" |

  .database.primary.user = $user |
  .database.primary.name = $db |

  .database.password_file = $passfile |

  .database.users = [
    {
      "name": $user,
      "role": "primary"
    }
  ] |

  .database.databases |= (
    if any(.[]; .name == $db)
    then .
    else . + [{
      "name": $db,
      "role": "primary"
    }]
    end
  )
  ' "$registry" > "$tmpfile" 
  mv "$tmpfile" "$registry" 
  rm -f "$tmpfile"
  db_write_password "$domain" "$password"
  local role="secondary"
  if jq -e '.database.primary.user == null' "$registry" >/dev/null 2>&1; then
    role="primary"
  fi
  local tmpfile
  tmpfile=$(mktemp)
  jq \
    --arg user "$db_user" \
    --arg role "$role" \
  '
  .database.users //= [] |
  if any(.database.users[]; .name == $user)
  then .
  else
    .database.users += [{
      "name": $user,
      "role": $role
    }]
  end |
  if $role == "primary" then
    .database.primary.user = $user
  else
    .
  end
  ' "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Failed to update registry users"
    return 1
  }
  mv "$tmpfile" "$registry"
  registry_update "$domain" \
    --arg user "$db_user" \
    --arg passfile "$(db_password_file "$domain")" \
    '
    .database.primary.user = $user |
    .database.password_file = $passfile
    '
  success "DB user created: $db_user"
  read -rp "${cyan}[USER]${reset} Would you like to promote $db_user to primary DB user for $domain (y|n)? " promote
  promote="${promote,,}"
  if [[ "$promote" != "y" && "$promote" != "yes" ]]; then
    info "Now exiting..."
    return
  fi
  info "Promoting $db_user"
  db_set_primary_user "$domain" "$db_user"
  echo "DB_USER=$db_user" >> /etc/one-click/${type}/${domain}/meta.conf
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
  domain="$(normalize_domain "$domain")"
  local db_user="$2"
  local registry="${sitectl_dir}/${domain}.json"
  [[ ! -f "$registry" ]] && {
    error "Registry missing"
    return 1
  }
  [[ -z "$db_user" ]] && {
    error "Database user required"
    return 1
  }
  local user_exists
  user_exists=$(mysql -N -e "
    SELECT User
    FROM mysql.user
    WHERE User='${db_user}'
    LIMIT 1;
  ")
  [[ "$user_exists" != "$db_user" ]] && {
    error "Database user does not exist"
    return 1
  }
  local tmpfile
  tmpfile=$(mktemp)
  jq --arg user "$db_user" '
    .database.users //= [] |

    .database.users |= map(
      if .name == $user then
        .role = "primary"
      else
        .role = "secondary"
      end
    ) |
    .database.primary.user = $user
  ' "$registry" > "$tmpfile" || {
    rm -f "$tmpfile"
    error "Failed to update registry"
    return 1
  }
  mv "$tmpfile" "$registry"
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
  domain="$(normalize_domain "$domain")"
  if [[ ! -f "$registry" ]]; then
    error "Registry missing"
    return 1
  fi
  local token expires token_file
  token=$(db_generate_token)
  expires=$(( $(date +%s) + 1800 ))
  token_file=$(db_token_file "$token")
  mkdir -p "$(dirname "$token_file")"
  cat > "$token_file" <<EOF
{
  "domain": "$domain",
  "expires": $expires
}
EOF
  chmod 600 "$token_file"
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
  printf "${blue}║${reset}  ${magenta}DATABASE CREDENTIALS:${reset} %-43s ${blue}║${reset}\n" "$domain"
  printf "${blue}╠══════════════════════╦═══════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${cyan}DATABASE:${reset} %-12s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$db_name"
  printf "${blue}║${reset} ${cyan}USER:${reset} %-16s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$db_user"
  printf "${blue}║${reset} ${cyan}HOST:${reset} %-16s ${blue}║${reset} %-45s ${blue}║${reset}\n" \
    "" "$host"
  printf "${blue}╠══════════════════════╩═══════════════════════════════════════════════╣${reset}\n"
  printf "${blue}║${reset} ${yellow}PASSWORD:${reset} %-54s ${blue}║${reset}\n" \
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
  registry_sync_databases "$domain"
  registry_detect_wordpress "$domain"
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
      "║                ${yellow}Registry Queries${blue}                ║" \
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
################################# CRON NAVIGATION ##############################
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
