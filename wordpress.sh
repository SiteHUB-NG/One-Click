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
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== WordPress ====
if command -v install_dep 2> /dev/null; then
  install_dep "php" "command -v php" "php-fpm" "$pkg_mgr" true
  install_dep "git" "command -v git" "git" "$pkg_mgr" true
fi
. /etc/os-release
secret_key="/etc/one-click.backup_secret.key"
current_profile_file="$config_dir/current_profile"
webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
if [[ "$ID" == "debian" ]]; then
  php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
fi
if ! grep -q 'oneclick' /etc/nginx/nginx.conf; then
  mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.init_one-click-bak
  ((sed -En '0,/^http \{/ {p}' /etc/nginx/nginx.conf.one-click-bak; echo "    log_format oneclick '\$remote_addr - \$remote_user [\$time_local] '
                        '\"\$request\" \$status \$body_bytes_sent '
                        '\"\$http_referer\" \"\$http_user_agent\" \"\$host\"';"); sed -En '/^http \{/ {:a;n;p;ba}' /etc/nginx/nginx.conf.one-click-bak) > /etc/nginx/nginx.conf
fi
dns_check() {
  dns=$(dig +short "$domain" | tail -n1)
  dns_www=$(dig +short "www.$domain" | tail -n1)
  if [[ "$dns" != "$sys_ip" ]]; then
    warn "Domain does not resolve to this server ($sys_ip)"
  fi
}
# ==== Wordpress Backup ====
wp_backup() {
  if [[ ${1:-} =~ ^- ]]; then
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
  fi
  local domain base site backup timestamp config_path
  domain="${1:-}"
  base="/etc/one-click/wordpress"
  site="$base/$domain/www"
  config_path="$base/$domain/wp-config.php"
  backup="$base/backups/$domain"
  timestamp=$(date +%Y%m%d-%H%M%S)
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) 2> /dev/null | head -1)
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
  chown "$web_user":"$web_user" "$backup/$timestamp/meta.conf"
  info "Building manifest"
  # ==== Manifest ====
  cat > "$backup/$timestamp/manifest.txt" <<EOF
TYPE=$( [[ -f "$backup/$timestamp/db.sql.gz" ]] && echo wordpress || echo static )
DOMAIN=$domain
TIMESTAMP=$timestamp
HOSTNAME=$(hostname)
BACKUP_VERSION=1.0
EOF
  success "Backup stored at $backup/$timestamp"
  sleep 2
}
wp_restore() {
  warn "Beginning restore"
  create_rollback_snapshot "$domain" "wordpress"
  local domain base site_dir backup_dir db_name db_user db_pass
  domain="${domain:-${1}}"
  backup_dir="${2:-}"
  base="/etc/one-click/wordpress"
  site_dir="$base/$domain/www"
  config_path="$base/$domain/wp-config.php"
  read -rp "${cyan}[USER]${yellow} This will overwrite the current $domain. Continue? (y|n): " confirm
  if [[ "$confirm" != "y" ]]; then 
    return 1
  fi
  [[ ! -d "$backup_dir" ]] && {
    die "Backup directory not found"
  }
  [[ -d "$site_dir" ]] || {
    die "Invalid site_dir"
  }
  info "Loading metadata..."
  source "$backup_dir/meta.conf"
  info "Clearing current site directory..."
  find "$site_dir" -mindepth 1 -delete
  rm -f "$config_path"
  info "Restoring files..."
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  if [[ -f "$site_dir/wp-config.php" ]]; then
    info "Relocating wp-config.php to secure parent directory..."
    mv "$site_dir/wp-config.php" "$config_path"
  fi
  info "Restoring database..."
  db_name=$(grep DB_NAME "$config_path" | cut -d"'" -f4)
  db_user=$(grep DB_USER "$config_path" | cut -d"'" -f4)
  db_pass=$(grep DB_PASSWORD "$config_path" | cut -d"'" -f4)
  pv "$backup_dir/db.sql.gz" | gunzip | mysql -u"$db_user" -p"$db_pass" "$db_name"
  chown -R "$web_user":"$webserver" "$site_dir"
  chown "$web_user":"$webserver" "$config_path"
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
  mapfile -t sites < <(sed -n '/\./p' <(find "$base" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
  if [[ ${#sites[@]} -eq 0 ]]; then
    error "No WordPress sites found in $base"
    return 1
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
profiles_board() {
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK WEB BACKUP MANAGER${blue}                ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Switch Profiles${blue}                                       ║" \
      "║ ${magenta}2${blue}  ║ ${green}List Profiles ${blue}                                        ║" \
      "║ ${magenta}3${blue}  ║ ${green}Add Profile ${blue}                                          ║" \
      "║ ${magenta}4${blue}  ║ ${green}Delete Profile ${blue}                                       ║" \
      "║ ${magenta}5${blue}  ║ ${green}Test Profile Connection ${blue}                              ║" \
      "║ ${magenta}0${blue}  ║ ${green}Back ${blue}                                                 ║" \
      "╚════╩═══════════════════════════════════════════════════════╝${reset}") <(get_current_profile)
    read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) profile_switch
        read -rp "${cyan}[USER]${blue} Press Enter to continue" ;;
      2) profile_list                      ;;
      3) remote_profile_add                ;;
      4) remote_profile_delete             ;;
      5) remote_profile_test               ;;
      0) clear; return 0                   ;;
      *) echo "Invalid option"             ;;
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
      "╚════╩═══════════════════════════════════════════════════════╝") <(get_current_profile)

  read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1)
        if [[ "$wpstatic" == "wordpress" ]]; then
          if [[ -z "${domain:-}" ]]; then
            warn "Please create a vhost before proceeding"
            read -rp "Press Enter to continue"
            run_script
          fi
          resolve_profile "$domain"
          wp_backup "$domain"
        else
          if [[ -z "${domain:-}" ]]; then
            warn "Please create a vhost before proceeding"
            read -rp "Press Enter to continue"
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
          static_restore_int
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
      *) echo "Invalid option"   ;;
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
      "║                ${yellow}ONE-CLICK WEB BACKUP MANAGER${blue}                ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Backup Restores & Rollback  ${blue}                          ║" \
      "║ ${magenta}2${blue}  ║ ${green}Manage Profiles  ${blue}                                     ║" \
      "║ ${magenta}3${blue}  ║ ${green}Cron   ${blue}                                               ║" \
      "║ ${magenta}4${blue}  ║ ${green}Change Domain   ${blue}                                      ║" \
      "║ ${magenta}5${blue}  ║ ${green}Guard   ${blue}                                              ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit  ${blue}                                                ║" \
      "╚════╩═══════════════════════════════════════════════════════╝") <(get_current_profile)
  read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) backup_board   ;;
      2) profiles_board ;;
      3)
        if [[ "$wpstatic" == "wordpress" ]]; then
          install_wp_cron "-wpback" "One-Click WordPress Backup" "$domain"
        else
          install_wp_cron "-staticback" "One-Click Static Backup" "$domain"
        fi
        ;;
      4) select_domain  ;;
      5) view_security "$domain" ;;
      0)
        echo "Exiting..."
        ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0
        ;;
      *) echo "Invalid option" ;;
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
configure_db() {
  db="one_click_$(openssl rand -hex 4)_$dbuser"
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
  if [[ -f "${site}/wp-config.php" ]]; then
    warn "WordPress already exists at $site"
    read -rp "${cyan}[USER]${reset} Skip WP installation and continue (y|n)? " choice
    choice="${choice,,}"
    [[ "$choice" =~ ^[Yy]$ || "$choice" == "yes" ]] && return
    info "Backing up existing wp-config.php"
    cp "$site/wp-config.php" "$site/wp-config.php.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$site"
  chown "$web_user":"$webserver" "$site"
  cd "$site" || return
  if [[ ! -f "${site}/wp-config.php" ]]; then
    $wp_cmd core download  || {
      warn "WP available in this location..."
    }
  fi
  # ==== Configure WP ====
  $wp_cmd config create \
    --dbname=$db \
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
  chown -R "$web_user":"$webserver" /etc/one-click/wordpress/$domain/www
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
    redis-cache \
    wordfence \
    wp-super-cache \
    --activate 
  # ==== Installing Selected Services ====
  if [[ "$enable_redis" == "y" ]]; then
    if [[ "$pkg_mgr" =~ (debian|ubuntu) ]]; then
      "$pkg_mgr" install redis-server -y
      systemctl enable redis-server --now
    else
      redis_ver=$(sort -rV <(awk '$1=="redis"{print $2}' <(dnf module list redis 2>/dev/null)) | head -1)
      if dnf -y module enable redis:$redis_ver; then
        "$pkg_mgr" install redis -y
        systemctl enable redis --now
      fi
    fi
    if ! redis-cli ping 2> /dev/null; then
      error "Redis failed to install"
      return 1
    fi
    $wp_cmd plugin activate redis-cache 
    $wp_cmd redis enable 
  fi
}
# ==== WP Staging ====
wp_staging() {
  prod="/etc/one-click/wordpress/$domain/www"
  stage="/etc/one-click/wordpress/staging/$domain"
  db_user=$(sed -En "/DB_USER/s/^[^)]*'([^']*)'.*/\1/p" "$prod/wp-config.php")
  db_pass=$(sed -En "/DB_PASSWORD/s/^[^)]*'([^']*)'.*/\1/p" "$prod/wp-config.php")
  info "Creating staging environment"
  mkdir -p "$stage"
  rsync -a "$prod/" "$stage/"
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
      read -rp "Enter choice [1-3]: " choice
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
    $wp_cmd --path="$stage" db export stage.sql
    $wp_cmd --path="$stage" db import stage.sql
    $wp_cmd --path="$stage" option update siteurl "https://staging.$domain"
    info "Staging created at staging.$domain"
  fi
}
wp_staging_push() {
  create_rollback_snapshot "$domain" "wordpress"
  prod="/etc/one-click/wordpress/$domain/www"
  stage="/etc/one-click/wordpress/staging/$domain"
  info "Deploying staging to production"
  rsync -a --delete "$stage/" "$prod/"
  cd "$prod"
  $wp_cmd db export deploy.sql 
  $wp_cmd db import deploy.sql 
  info "Deployment completed"
}
staging_vhost_nginx() {
  local domain stage_root
  domain="$1"
  stage_root="/etc/one-click/wordpress/staging/$domain"
  mkdir -p /var/log/nginx/${domain}_staging
  cat > "/etc/nginx/conf.d/staging.$domain.conf" <<EOF
server {
    listen 80;
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
staging_vhost_apache() {
  local domain stage_root
  domain="$1"
  stage_root="/etc/one-click/wordpress/staging/$domain"
  cat > "/etc/httpd/conf.d/staging.$domain.conf" <<EOF
<VirtualHost *:80>
    ServerName staging.$domain
    ServerAlias www.staging.$domain
    DocumentRoot $stage_root

    <Directory $stage_root>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${apache_log_dir}/$domain-error.log
    CustomLog ${apache_log_dir}/$domain-access.log combined
    
</VirtualHost>
EOF
  systemctl reload httpd
}
wp_staging_enable() {
  local domain="$1"
  if command -v nginx >/dev/null; then
    staging_vhost_nginx "$domain"
  else
    staging_vhost_apache "$domain"
  fi
  enable_staging_ssl "$domain" 2>/dev/null || true
  success "Staging enabled at https://staging.$domain"
}
wp_staging_disable() {
  local domain="$1"
  rm -f /etc/nginx/conf.d/staging.$domain.conf 2>/dev/null
  rm -f /etc/httpd/conf.d/staging.$domain.conf 2>/dev/null
  systemctl reload nginx 2>/dev/null || systemctl reload httpd
  success "Staging disabled for $domain"
}
# ===== Helper functions =====
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
    "${magenta}2${green}  Backup Site${blue}"
    "${magenta}3${green}  Restore Backup${blue}"
    "${magenta}4${green}  Staging Menu${blue}"
    "${magenta}5${green}  Rollback Snapshots${blue}"
    "${magenta}6${green}  Push Staging${blue}"
    "${magenta}7${green}  Delete Site${blue}"
    "${magenta}8${green}  Reset Password${blue}"
    "${magenta}0${green}  Exit${blue}"
  )
  local choice
  while true; do
    draw_box "${magenta}Managing WordPress:${yellow} $domain${blue}" "${options[@]}"
    read -rp "Select an option: " choice
    case "$choice" in
      1) wp_plugin_manager "$domain" ;;
      2) wp_backup "$domain"         ;;
      3) 
        resolve_profile "$domain"
        wp_restore_int "$domain"    ;;
      4) wp_staging_menu "$domain"  ;;
      5) wp_rollback_menu "$domain" ;;
      6) wp_staging_push "$domain"  ;;
      7) delete_site "$domain"      ;;
      8) wp_magic_login "$domain"   ;;
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
    read -rp "Select an option: " choice
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
    read -rp "Select an option: " choice
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
  site_dir="${3:-}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      sed -i.one-click-bak '/^#deb-src/{s/^#//};/^deb /{s/^/#/}' /etc/apt/sources.list
      "$pkg_mgr" clean
      "$pkg_mgr" update -y
      if ! "$pkg_mgr" -y install nginx &>/dev/null; then
        "$pkg_mgr" install -y debian-archive-keyring
        "$pkg_mgr" install -y nginx || "$pkg_mgr" install -y nginx-full
      fi
      nginx_conf
    else
      "$pkg_mgr" install -y apache2 libapache2-mod-php
      if [[ "$mode" == "wordpress" ]]; then
        apache_conf
        apache_ssl_conf
      elif [[ "$mode" == "static" ]]; then
        apache_static_conf "$domain" "$site_dir"
      fi
      a2ensite "${domain}.conf"
      #a2ensite "$domain-le-ssl.conf"
    fi
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      "$pkg_mgr" install -y nginx
      if [[ "$mode" == "wordpress" ]]; then
        nginx_conf
      else
        nginx_static_conf "$domain" "$site_dir"
      fi
    else
      "$pkg_mgr" install -y httpd php php-fpm
      if [[ "$mode" == "wordpress" ]]; then
        apache_conf
        apache_ssl_conf
      elif [[ "$mode" == "static" ]]; then
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
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-zip
    a2enmod rewrite
    a2enmod ssl
    a2enmod headers
    a2ensite "$domain"
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    "$pkg_mgr" install -y \
      httpd \
      mod_ssl \
      php \
      php-fpm \
      php-mysqlnd \
      php-gd \
      php-mbstring \
      php-xml \
      php-json
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
  mkdir -p /var/log/nginx/${domain}
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    server_name $domain www.$domain;

    root /etc/one-click/wordpress/$domain/www;
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
  if [[ "$pkg_mgr" == "apt" ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  nginx -t
  systemctl enable nginx --now
  systemctl reload nginx
}
# ==== Apache ====
apache_conf() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_confi=/etc/apache2/sites-available/$domain.conf
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    apache_confi=/etc/httpd/conf.d/$domain.conf
  fi
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

    DocumentRoot /etc/one-click/wordpress/$domain/www

    <Directory /etc/one-click/wordpress/$domain/www>
        AllowOverride All
        Require all granted
    </Directory>

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

    DocumentRoot /etc/one-click/wordpress/$domain/www

    <Directory /etc/one-click/wordpress/$domain/www>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${apache_log_dir}/$domain-ssl-error.log
    CustomLog ${apache_log_dir}/$domain-ssl-access.log combined
</VirtualHost>
</IfModule>
EOF
  sed -Ei 's/#(Redirect permanent)/\1/' "$apache_confi"
}
webroot_nginx_template() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    nginx_conf_file="/etc/nginx/sites-available/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  else
    nginx_conf_file="/etc/nginx/conf.d/$domain.conf"
    nginx_log_dir="/var/log/nginx"
  fi
  sed -Ei '/listen 80;|^\}/d;' "$nginx_conf_file"
  cat << EOF >> "$nginx_conf_file"
    listen 443 ssl; # Managed By One-Click
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
        site="/etc/one-click/static/www/$domain"
      fi
      if [[ "$mode" == "wordpress" ]]; then
        site="/etc/one-click/wordpress/$domain/www"
      else
        site="/etc/one-click/static/www/$domain"
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
      if certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"; then
        bot_installed=1
      fi
    else
      if certbot --apache -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"; then
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
      echo "Options:"
      echo "  [1] Try webroot installation"
      echo "  [2] Change email"
      echo "  [3] Skip SSL setup"
      echo "  [4] View logs"
      read -rp "${cyan}[USER]${reset} Choose an option: " choice
      case "$choice" in
        1)
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
        4) less /var/log/letsencrypt/letsencrypt.log ;;
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
  echo "SITE_USER=$web_user" >> /etc/one-click/wordpress/$domain/meta.conf
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
  warn "Creating web owner"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
  chown "$web_user":"$webserver" /etc/one-click/wordpress/$domain/meta.conf
  echo
  while true; do
    read -rp "${cyan}[USER]${reset} Enable Redis (y|n): " enable_redis
    [[ -n "$enable_redis" ]] && break
  done
  #read -rp "${cyan}[USER]${reset} Enable Cloudflare (y|n): " enable_cloudflare
  #read -rp "${cyan}[USER]${reset} Enable Staging? (y|n) " enable_staging
  printf '%s\n' "Which webserver would you like to configure?" \
    "[1] Nginx" \
    "[2] Apache"
  while true; do
    read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver
    [[ -n "$webserver" ]] && break
  done
  case "$webserver" in
    1) webserver="nginx"                ;;
    2) webserver="apache"               ;;
    *) 
      echo "Invalid selection" 
      ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1 ;;
  esac
  # ==== Selection Summary Confirmation ====
  [[ "$enable_redis" == "n" ]] && redis=No || redis=Yes
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
    "Webserver" "${yellow}${webserver}${blue}"
  printf '%s\n' "└──────────────────────────────────────────────────────┘${reset}"
  while true; do
    read -rp "${cyan}[USER]${reset} Are these details correct? (y|n): " proceed
    [[ -n "$proceed" ]] && break
  done
  proceed="${proceed,,}"
  echo 
  # ==== Install Dependancies ====
  if [[ "$proceed" == "y" || "$proceed" == "yes" ]]; then
    info "Updating System"
    "$pkg_mgr" -y update
    info "Installing dependencies"
    "$pkg_mgr" install -y \
    mariadb-server \
    php-fpm \
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
      success "wp-config.php moved to $dest_config and permissions set to 600."
    else
      error "Failed to move file. Check permissions and global server settings then try again."
      exit 1
    fi
  fi
  mkdir -p /etc/one-click/wordpress/backups
  chmod -R 700 /etc/one-click/wordpress/backups
  chown "$web_user":"$webserver" /etc/one-click/wordpress/backups
  # ==== Open Firewall ====
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver"
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
  success "One-Click Wordpress has now been installed!"
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
        $wp_cmd plugin list
        read -rp "Plugin to Toggle: " plugin
        [[ -z "$plugin" ]] && continue
        # Get current status to determine whether to activate or deactivate
        status=$($wp_cmd plugin get "$plugin" --field=status 2>/dev/null)
        if [[ "$status" == "active" ]]; then
          $wp_cmd plugin deactivate "$plugin"
        else
          $wp_cmd plugin activate "$plugin"
        fi
        ;;
      2)
        read -rp "Search for plugin: " search_term
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
          read -rp "Confirm deletion of $del_slug? (y|n): " confirm
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
  meta_file="/etc/one-click/wordpress/config/remotes.conf"
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
  meta_file="/etc/one-click/wordpress/config/remotes.conf"
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
############################## STATIC SITES ##############################################
create_static_site() {
  local domain site_dir webserver_choice
  start_screen static
  php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
  while true; do
    local br=0
    read -rp "${cyan}[USER]${reset} Enter a domain name to use for your new site site: " domain
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
  warn "Creating web owner"
  web_user="ocb_$(echo -n "$domain" | sha1sum | cut -c1-8)"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
  site_dir="/etc/one-click/sites/$domain/www"
  mkdir -p "$site_dir"
  chown "$web_user":"$webserver" "$site_dir"
  touch /etc/one-click/sites/$domain/meta.conf
  echo "SITE_USER=$web_user" >> /etc/one-click/sites/$domain/meta.conf
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  cat <<'EOF' > "$site_dir/index.html"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>SiteHUB Default WebPage</title><link rel="icon" type="image/png" href="https://sitehub.agency/wp-content/uploads/2025/06/cropped-Untitled-design-9-e1750161170804.png"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet"><style>*{margin:0;padding:0;box-sizing:border-box}body,html{height:100%;font-family:'Roboto',sans-serif}body{background:linear-gradient(135deg,#28a745,#003366);display:flex;flex-direction:column;justify-content:space-between;color:#fff}header{text-align:center;padding:50px 20px}header img.logo{height:80px;margin-bottom:20px}header h1{font-size:2.5em;margin-bottom:10px}header p{font-size:1.2em}.visuals{position:absolute;top:0;left:0;width:100%;height:100%;overflow:hidden;z-index:0}.visuals span{position:absolute;display:block;border-radius:50%;background:rgba(255,255,255,.05);animation:float 25s linear infinite}@keyframes float{0%{transform:translateY(0) rotate(0deg)}100%{transform:translateY(-1000px) rotate(720deg)}}main{position:relative;z-index:1;max-width:900px;margin:0 auto;padding:20px;text-align:center}section{margin:50px 0}.main-hero h2{font-size:2em;margin-bottom:15px}.main-hero p{font-size:1.1em;line-height:1.6;margin-bottom:25px}.cta-btn{display:inline-block;background:#fff;color:#003366;font-weight:700;text-decoration:none;padding:12px 25px;border-radius:50px;margin:10px;transition:all .3s ease}.cta-btn:hover{background:#e0e0e0}footer{text-align:center;padding:20px;font-size:.9em;color:rgba(255,255,255,.7)}@media(max-width:768px){header h1{font-size:2em}.main-hero h2{font-size:1.6em}}</style></head><body><div class="visuals" id="visuals"></div><header><img class="logo" src="https://us1.plesk.sitehub.agency/images/logos/6EwrLBBn5Xg.png" alt="SiteHUB"><h1>Default Web Page for <span id="domain-name">dynamic-domain.ng</span></h1><p>This page is generated by <a href="https://sitehub.agency" style="color:darkgreen;text-decoration:none;">Site <span style="color:blue;text-decoration:none;">HUB</span></a>, the leading hosting provider in Nigeria.<br>You see this page because there is no website at this address.</p></header><main id="placeholder-content"></main><footer>Copyright &copy; SiteHUB Agency <span id="year"></span>. All rights reserved - RC6935293</footer><script>document.getElementById("year").textContent=new Date().getFullYear();document.addEventListener("DOMContentLoaded",()=>{const e=location.hostname,t=location.protocol+"//"+e+":8443",n="support@sitehub.agency";document.getElementById("domain-name").textContent=e;const o=document.getElementById("placeholder-content");let a="";a+=`<section class="main-hero"><h2>Your domain <strong>${e}</strong> is now live!</h2><p><strong>${e}</strong> default page has been generated by the One-Click Toolbox Automation tool . No website content has been uploaded yet.<br>For more information about One-Click Toolbox:</p><a class="cta-btn" href="https://github.com/SiteHUB-NG/One-Click/" target="_blank">View On GitHub</a><br><br><br><hr><br><h2>Need Hosting?</h2><p>Start your own website in minutes with our web hosting & VPS plans!</p><a class="cta-btn" href="https://sitehub.agency/shared/" target="_blank">View Web Hosting Plans</a><a class="cta-btn" href="https://features.sitehub.agency/vps/" target="_blank">View VPS Plans</a></section>`,a+=`<section class="main-hero"><h2>Need Help?</h2><p>Contact our support team: <a style="color:#fff;text-decoration:underline;" href="mailto:${n}">${n}</a></p></section>`,o.innerHTML=a;const r=document.getElementById("visuals");for(let t=0;t<30;t++){let n=document.createElement("span"),o=60*Math.random()+20;n.style.width=o+"px",n.style.height=o+"px",n.style.left=100*Math.random()+"%",n.style.top=100*Math.random()+"%",n.style.animationDuration=20+20*Math.random()+"s",r.appendChild(n)}});</script></body></html>
EOF
  success "New site prepared at $site_dir"
  info "Which webserver should host $domain?" \
    "[1] Nginx" \
    "[2] Apache"
  read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver_choice
    case "$webserver_choice" in
      1) webserver="nginx"                  ;;
      2) webserver="apache"                 ;;
      *) echo "Invalid selection"; return 1 ;;
  esac
  install_webserver static "$domain" "$site_dir"
  create_isolated_php_runtime "$domain" "$php_ver" "$web_user" "$webserver" "sites"
  dns_check
  one-click engine "allow $webserver"
  install_letsencrypt static
  wp_backup_scheduler
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor-site "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_static-web-monitor_$domain
  success "One-Click static site has now been installed for $domain"
  info "Access the site from ${magenta}https://${domain}${reset}"
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
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
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
  if [[ "$pkg_mgr" == "apt" ]]; then
    ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  fi
  systemctl enable nginx --now
  nginx -t && systemctl reload nginx
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
        SetHandler "proxy:unix:/run/php${php_ver:-}-fpm-${domain}.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${apache_log_dir}/$domain-error.log
    CustomLog ${apache_log_dir}/$domain-access.log combined
</VirtualHost>
EOF
  install_php_mods
  if [[ "$pkg_mgr" == "apt" ]]; then
    a2ensite "$domain"
    systemctl reload apache2
  else
    systemctl enable httpd --now
    systemctl reload httpd
  fi
}
static_backup() {
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
  local domain base site backup timestamp webserver
  domain="${1:-}"
  base="/etc/one-click/sites"
  site="$base/$domain/www"
  backup="$base/backups/$domain"
  timestamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  [[ ! -f "$site/index.html" && ! -f "$site/index.php" ]] && {
    error "No index file found (not a valid static site)"
    return 1
  }
  info "Creating static site backup for $domain"
  mkdir -p "$backup/$timestamp"
  if ss -taulpn | grep ':80\|:443' &> /dev/null; then
    webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
  else
    if [[ -f "/etc/nginx/sites-available/$domain.conf" || -f "/etc/nginx/conf.d/$domain.conf" ]]; then
      webserver="nginx"
    elif [[ -f "/etc/apache2/sites-available/$domain.conf" || -f "/etc/httpd/conf.d/$domain.conf" ]]; then
      webserver="apache"
    else
      webserver="unknown"
    fi
  fi
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
TYPE=$( [[ -f "$backup/$timestamp/db.sql.gz" ]] && echo wordpress || echo static )
DOMAIN=$domain
TIMESTAMP=$timestamp
HOSTNAME=$(hostname)
BACKUP_VERSION=1.0
EOF
  success "Backup stored at $backup/$timestamp"
  sleep 2
}
static_restore() {
  read -rp "${yellow}[USER]${yellow} This will overwrite $domain. Continue? (y|n): " confirm
  [[ "$confirm" != "y" && "$confirm" != "yes" ]] && return 1
  create_rollback_snapshot "$domain" "static"
  local domain base site_dir backup_dir webserver
  domain="${domain:-${1}}"
  backup_dir="$2"
  base="/etc/one-click/sites"
  site_dir="$base/www/$domain"
  [[ ! -d "$backup_dir" ]] && {
    die "Backup directory not found"
  }
  [[ -d "$site_dir" && "$site_dir" == *"/www/"* ]] || {
    die "Invalid site_dir"
  }
  info "Loading metadata..."
  source "$backup_dir/meta.conf"
  # ==== Restore files ====
  info "Restoring files..."
  find "$site_dir" -mindepth 1 -delete
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  # ==== Restore webserver ====
  info "Restoring webserver configuration..."
  case "$WEBSERVER" in
    nginx)
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
  chown -R "$web_user":"$webserver" "$site_dir"
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
  select_static_domain "restore" || return 1
  resolve_profile "$domain"
  local backup_base="/etc/one-click/sites/backups/$domain"
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
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) | head -1)
  if systemctl is-active --quiet nginx; then
    webserver="nginx"
    [[ "$os_family" == "debian" ]] && conf_path="/etc/nginx/sites-enabled" || conf_path="/etc/nginx/conf.d"
  elif systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    webserver="apache"
    [[ "$os_family" == "debian" ]] && conf_path="/etc/apache2/sites-enabled" || conf_path="/etc/httpd/conf.d"
    [[ "$os_family" == "rhel" ]] && webserver="httpd"
  else
    error "No supported webserver detected!" 
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
  local domain="$1"
  set_domain_context || return 1
  local base_conf="/etc/one-click/php/$domain"
  local ini_file="$base_conf/php.ini"
  local fpm_conf="$base_conf/php-fpm.conf"
  read -rp "Enter PHP version (e.g., 8.2): " new_ver
  local ver_nodot="${new_ver//.}"
  local binary_path="/opt/remi/php${ver_nodot}/root/usr/sbin/php-fpm"
  if [[ ! -f "$binary_path" ]]; then
    echo "Installing PHP $new_ver..."
    dnf install -y "php${ver_nodot}-php-fpm" "php${ver_nodot}-php-cli" "php${ver_nodot}-php-mbstring"
  fi
  sed -Ei "s,(ExecStart=)[^ \t]*,\1$binary_path," /etc/systemd/system/php-fpm@${domain}.service
  systemctl daemon-reload
  systemctl restart "php-fpm@$domain"
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
  setup_repos
  info "Installing PHP $ver and common extensions..."
  if [[ "${os_family:-}" == "debian" ]]; then
    $pkg_mgr install -y "php$ver-fpm" "php$ver-cli" "php$ver-mysql" "php$ver-xml" "php$ver-mbstring" "php$ver-gd" "php$ver-curl" || return 1
    fpm_service="php$ver-fpm"
  else
    $pkg_mgr module reset php -y
    $pkg_mgr module enable "php:remi-$ver" -y
    $pkg_mgr install -y php php-fpm php-mysqlnd php-xml php-mbstring php-gd php-curl || return 1
    fpm_service="php-fpm"
  fi
  $pkg_mgr stop "php$ver-fpm" 2>/dev/null || true
  $pkg_mgr disable "php$ver-fpm" 2>/dev/null || true
  success "PHP $ver is installed and running."
}
site_tune_php() {
  set_domain_context
  [[ ! -f "$php_ini" ]] && {
    error "php.ini not found at $php_ini"
    return 1
  }
  info "Tuning PHP for ${domain} (PHP ${php_version})"
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
    fpm_serv="php-fpm-${domain}"
  else
    ini_path="/etc/opt/remi/php${sel_ver//./}/php.ini"
    [[ ! -f "$ini_path" ]] && ini_path="/etc/php.ini"
    fpm_serv="php-fpm-${domain}"
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
  php_version=$(sed -En '/^ExecStart=[^0-9]*([0-9]+).*/{s//\1/;s/./&./p}' /etc/systemd/system/php-fpm@${domain}.service)
  while true; do
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
      "${magenta}[${yellow}0${magenta}]${reset} Exit") <(printf "${blue}[${green}${domain}${blue}] PHP ${php_version} | ${webserver}${reset}")
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
      read -rp "Press Enter to continue..."
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
    read -rp "Press Enter to continue..."
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
  else
    list_domains() {
      ls /etc/one-click/wordpress /etc/one-click/sites | sed -n '/\./p'
    }
  fi
  mapfile -t domains < <(list_domains)
  if [[ ${#domains[@]} -eq 0 ]]; then
    error "${red}No domains found${reset}"
    return 1
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
  if [[ -f "/usr/sbin/php-fpm$php_ver" ]]; then
    php_bin="/usr/sbin/php-fpm$php_ver"
  else
    php_bin="/usr/sbin/php-fpm"
  fi
  local base_conf="/etc/one-click/php/$domain"
  local run_dir="/run/one-click/$domain"
  local log_dir="/var/log/one-click/$domain"
  local lib_dir="/var/lib/one-click/$domain"
  local ini_file="$base_conf/php.ini"
  local fpm_conf="$base_conf/php-fpm.conf"
  local pool_conf="$base_conf/pool.conf"
  local systemd_unit="/etc/systemd/system/php-fpm@$domain.service"
  mkdir -p "$base_conf" "$run_dir" "$log_dir" "$lib_dir"/{tmp,sessions}
  chown -R "$site_user:$site_user" "$lib_dir"
  chmod 700 "$lib_dir"
  cat > "$ini_file" <<EOF
[PHP]
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
expose_php = Off
display_errors = Off
log_errors = On
session.save_path = $lib_dir/sessions
upload_tmp_dir = $lib_dir/tmp
extension=mysqli
extension=pdo_mysql
extension=mysqlnd
EOF
    cat > "$pool_conf" <<EOF
[$domain]
user = $site_user
group = $site_user
listen = $run_dir/php.sock
listen.owner = $site_user
listen.group = $webserver
listen.mode = 0660
pm = ondemand
pm.max_children = 5
php_admin_value[open_basedir] = /etc/one-click/${type}/${domain}/:/etc/one-click/${type}/${domain}/www/:/tmp:/var/lib/one-click/${domain}/
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
NoNewPrivileges=true
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "php-fpm@$domain"
  systemctl start "php-fpm@$domain"
  if systemctl is-active --quiet "php-fpm@$domain"; then
    success "PHP $php_ver runtime for $domain is active."
    info "Socket: $run_dir/php.sock" "Logs:  $log_dir/php-fpm.log"
  else
    error "PHP $php_ver runtime for $domain failed to start!"
    journalctl -u "php-fpm@$domain" --no-pager | tail -20
  fi
}
########################### ROLLBACK ########################
create_rollback_snapshot() {
  local domain type ts base backup_source rollback_dir latest
  domain="$1"
  type="$2"
  ts=$(date +%Y%m%d-%H%M%S)
  info "Creating rollback snapshot for $domain"
  if [[ "$type" == "wordpress" ]]; then
    base="/etc/one-click/wordpress"
    wp_backup "$domain" "ran"
  else
    base="/etc/one-click/sites"
    static_backup "$domain"
  fi
  set +o pipefail
  backup_source="$base/backups/$domain"
  latest=$(ls -dt "$backup_source/"* 2>/dev/null | head -n1)
  set -o pipefail
  [[ -z "$latest" ]] && { error "No recent backup found to snapshot"; return 1; }
  rollback_dir="$base/rollback/$domain/$ts"
  mkdir -p "$rollback_dir"
  cp -a "$latest/." "$rollback_dir/"
  success "Rollback snapshot created: $ts"
}
rollback_list() {
  local domain="$1"
  skip_prompt="${2:-}"
  local base="/etc/one-click/wordpress/rollback"
  echo -e "\e[34m╔════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Snapshot             ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╣\e[0m"
  mapfile -t snaps < <(ls -1 "$base/$domain" 2>/dev/null | sort -r)
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
##################################### SECURITY ##################################
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
#config_dir="$base/sites/config"
#profiles_file="$config_dir/remotes.conf"
#map_file="$config_dir/domain_map.conf"
#current_profile_file="$config_dir/current_profile"
#mkdir -p "$config_dir" && touch "$map_file" "$profiles_file"
profile_add() {
  export d_pass
  read -rp "${cyan}[USER]${blue} Please provide the remote hosts IP address:${reset} " host
  read -rp "${cyan}[USER]${blue} Please provide the remote username:${reset} " user
  user="${user:-root}"
  read -rp "${cyan}[USER]${blue} Remote base path [/backups]: ${reset}" base_path
  base_path="${base_path:-/backups}"
  check_auth
  cat >> "$profiles_file" <<EOF
[$profile]
HOST=${host}
USER=${user:-root}
BASE_PATH=$base_path
E-PASSWD=$e_pass
EOF
  if [[ -z "$profiles_file" ]]; then
    error "profiles file was not populated"
    return 1
  fi
  if grep -q "^\[$profile" "$profiles_file"; then
    success "Profile '$profile' created"
    return 0
  else
    error "Profile "$profile" not added"
    return 1
  fi
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
  read -rp "Press Enter to continue" 
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
  local profile
  profile="$1"
  profile_pass_enc=$(awk -v p="[$profile]" '
    $0==p {f=1; next}
    /^\[/ {f=0}
    f && /^E-PASSWD=/ {
      print substr($0,10)
      exit
    }
  ' "$profiles_file")
  profile_type=$(awk -v p="[$profile]" '
    $0==p {f=1; next}
    /^\[/ {f=0}
    f && /^TYPE=/ {print substr($0,6); exit}
' "$profiles_file")
  if [[ "$profile_type" == "local" ]]; then
    remote_host=""
    remote_user=""
    remote_base=""
    profile_pass=""
    return 0
  fi
  if [[ -n "$profile_pass_enc" ]]; then
    profile_pass=$(decrypt_password "$profile_pass_enc")
  else
    profile_pass=""
  fi
  profile_host=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0}f&&/^HOST=/{print substr($0,6)}' "$profiles_file")
  profile_user=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0}f&&/^USER=/{print substr($0,6)}' "$profiles_file")
  profile_base=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0}f&&/^BASE_PATH=/{print substr($0,11)}' "$profiles_file")
  if [[ -z "$profile_host" ]]; then
    error "Profile not found"
    return 1
  fi
  export profile_pass
  return
}
resolve_profile() {
  local domain
  domain="$1"
  profile=$(grep "^$domain=" "$map_file" 2>/dev/null | cut -d'=' -f2)
  if [[ -z "$profile" ]]; then
    info "No profile assigned to $domain"
    profile="local-default"
  fi
  load_profile "$profile"
  remote_host="$profile_host"
  remote_user="$profile_user"
  remote_base="$profile_base"
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
  if ! grep -q "^\[Not Assigned\]" "$profiles_file" 2>/dev/null; then
    cat >> "$profiles_file" <<EOF
[local-default]
TYPE=local
EOF
  fi
}
check_auth() {
  if [[ "$profile_type" == "local" ]]; then
    use_sshpass=0
    return 0
  fi
  if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "${user:-remote_user}@${host:-remote_host}" "exit" >/dev/null 2>&1; then
    #read -rsp "${cyan}[USER]${blue} ${host:-remote_host}'s password: " sshpass
    #if [[ -n "$sshpass" ]]; then
    #  e_pass=$(encrypt_password "$sshpass")
    #fi
    #echo
    use_sshpass=1
  else
    use_sshpass=0
  fi
  #export e_pass
  #export d_pass
}
run_ssh() {
  if [[ "$use_sshpass" == 1 ]]; then
    sshpass -p "$d_pass" ssh -o StrictHostKeyChecking=no "$remote_user@$remote_host" "$1"
  else
    ssh "$remote_user@$remote_host" "$1"
  fi
}
run_rsync() {
  if [[ "$use_sshpass" == 1 ]]; then
    sshpass -p "$d_pass" rsync -az --progress -e "ssh -o StrictHostKeyChecking=no" "$@"
  else
    rsync -az --progress "$@"
  fi
}
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
          read -rp "${red}Are you sure you want to delete backup $target_ts? (y/n): ${reset}" confirm
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
  type="${wpstatic}"
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
      "Last Backup" "$lb_ts" \
      "Disk Usage" "$disk_usage"
    echo -e "${blue}└──────────────────┴───────────────────────────────────────┘${reset}"
  fi
}
####################### REMOTE PROFILES MANAGEMENT ################################
# ==== Add New Profile ====
remote_profile_add() {
  local profile host user base_path sshpass e_pass
  read -rp "${cyan}[USER]${blue} Enter new profile name: " profile
  [[ -z "$profile" ]] && { error "Invalid name"; return 1; }
  if grep -q "^\[$profile\]" "$profiles_file"; then
    echo "Profile already exists"
    return 1
  fi
  read -rp "${cyan}[USER]${blue} Enter the remote host IP: " host
  read -rp "${cyan}[USER]${blue} Enter ${host}'s username [root]: " user
  user="${user:-root}"
  read -rp "${cyan}[USER]${blue} Enter remote base path [/backups]: " base_path
  base_path="${base_path:-/backups}"
  read -rsp "${cyan}[USER]${blue} Password (leave empty for SSH key): " sshpass
  echo
  [[ -n "$sshpass" ]] && e_pass=$(encrypt_password "$sshpass") || e_pass=""
  cat >> "$profiles_file" <<EOF
[$profile]
HOST=$host
USER=$user
BASE_PATH=$base_path
E-PASSWD=$e_pass
EOF
    success "Profile '$profile' added"
}
# ==== List Remote Profiles ====
remote_profile_list() {
  local -a names hosts bases
  while IFS= read -r line; do
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      name="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^HOST=(.*)$ ]]; then
      host="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^BASE_PATH=(.*)$ ]]; then
      base="${BASH_REMATCH[1]}"
      names+=("$name")
      hosts+=("$host")
      bases+=("$base")
    fi
  done < "$profiles_file"
  if [[ ${#names[@]} -eq 0 ]]; then
    error "No profiles found."
    return 1
  fi
  echo -e "\e[34m╔════╦══════════════════════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Profile Name         ║ Host                 ║ Base Path            ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╬══════════════════════╬══════════════════════╣\e[0m"
  local i=1
  for idx in "${!names[@]}"; do
    printf "\e[34m║ %-2s ║ %-20s ║ %-20s ║ %-20s ║\e[0m\n" \
      "$i" "${names[$idx]}" "${hosts[$idx]}" "${bases[$idx]}"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╩══════════════════════╩══════════════════════╝\e[0m"
  read -rp "${cyan}[USER]${blue} Press Enter to continue"
}
# ==== Switch Active Profile ====
remote_profile_switch() {
  local profiles choice selected
  mapfile -t profiles < <(awk '/^\[/{gsub(/\[|\]/,""); print}' "$profiles_file")
  [[ ${#profiles[@]} -eq 0 ]] && { error "No profiles found"; return 1; }
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
    read -rp "${cyan}[USER]${blue} Select profile ID to activate: ${reset}" choice
    if [[ "$choice" -eq 0 ]]; then
      return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
      selected="${profiles[$((choice-1))]}"
      echo "$selected" > "$current_profile_file"
      success "Active profile: $selected"
      break
    else
      error "Invalid selection"
    fi
  done
}
# ==== Delete Remote Profile ====
remote_profile_delete() {
  local profiles choice selected
  mapfile -t profiles < <(awk '/^\[.*\]/{gsub(/\[|\]/,""); print $0}' "$profiles_file")
  if [[ ${#profiles[@]} -eq 0 ]]; then
    error "No profiles available to delete"
    return 1
  fi
  echo -e "\e[34m╔════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ${yellow}ID ${blue}║ ${yellow}Profile Name${blue}         ║\e[0m"
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
    if [[ "$choice" -eq 0 ]]; then
      return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
      selected="${profiles[$((choice-1))]}"
      break
    else
      error "Invalid selection, try again."
    fi
  done
  if grep -q "=${selected}$" "$map_file"; then
    error "Profile '$selected' is assigned to a domain"
    return 1
  fi
  awk -v p="[$selected]" '
    $0==p {f=1; next}
    /^\[/ {f=0}
    !f
  ' "$profiles_file" > /tmp/remotes.tmp
  mv /tmp/remotes.tmp "$profiles_file"
  success "Profile '$selected' deleted"
}
# ==== Test Profile Connection ====
remote_profile_test() {
  local profile profile_host profile_user profile_pass_enc d_pass ret
  [[ -f "$current_profile_file" ]] || { error "No active profile"; return; }
  profile=$(<"$current_profile_file")
  profile_pass_enc=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0} f&&/^E-PASSWD=/{print substr($0,10)}' "$profiles_file")
  [[ -z "$profile" ]] && { error "Active profile is empty"; return 1; }
  profile_host=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0} f&&/^HOST=/{print substr($0,6)}' "$profiles_file")
  profile_user=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0} f&&/^USER=/{print substr($0,6)}' "$profiles_file")
  profile_pass_enc=$(awk -v p="[$profile]" '$0==p{f=1;next}/^\[/{f=0} f&&/^E-PASSWD=/{print substr($0,10)}' "$profiles_file")
  [[ -n "$profile_pass_enc" ]] && d_pass=$(decrypt_password "$profile_pass_enc") || d_pass=""
  if [[ -n "$d_pass" ]]; then
    sshpass -p "$d_pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      "$profile_user@$profile_host" "echo OK" >/dev/null 2>&1 || ret=$?
  else
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      "$profile_user@$profile_host" "echo OK" >/dev/null 2>&1 || ret=$?
  fi
  ret=${ret:-0}
  if [[ $ret -eq 0 ]]; then
  success "${green}Connection OK to $profile_host as $profile_user${reset}"
    else
        error "${red}Connection failed to $profile_host as $profile_user${reset}"
    fi
}
################################# SITE REMOVAL ###############################
delete_site() {
  local domain="$1"
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) | head -1)
  detect_env 
  local type="${2:-wordpress}"
  local slice_name="one-click_${domain}.slice"
  local service_name="php-fpm@${domain}.service"
  local site_user
  [[ -z "$domain" ]] && { error "No domain provided"; return 1; }
  read -rp "${cyan}[USER]${red} WARNING: Delete $domain permanently? (y|n): ${reset}" confirm
  [[ "$confirm" != "y" ]] && { info "Cancelled"; return 1; }
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
  (rm -rf "/etc/one-click/wordpress/$domain"
  rm -rf "/etc/one-click/sites/$domain"
  # ==== Backups ====
  rm -rf "/etc/one-click/wordpress/backups/$domain"
  rm -rf "/etc/one-click/sites/backups/$domain"
  rm -rf "/etc/one-click/wordpress/rollback/$domain"
  rm -rf "/etc/one-click/sites/rollback/$domain"
  # ==== Logs ====
  rm -f /var/log/php-fpm-$domain.log
  rm -f /var/log/nginx/$domain*.log 2>/dev/null
  rm -f /var/log/httpd/$domain*.log 2>/dev/null
  # ==== SSL ====
  rm -rf "/etc/letsencrypt/live/$domain"
  rm -rf "/etc/letsencrypt/archive/$domain"
  rm -f "/etc/letsencrypt/renewal/$domain.conf") 2> /dev/null
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
  # ==== MISC LOST+FOUND ====
  warn "Deleting all other associated files and directories for $domain"
  (locate "$domain" | while read line; do 
    rm -rf "$line"
  done) 2> /dev/null
  # ==== Remove system user ====
  set +o pipefail
  info "Removing system user $site_user"
  if id "$site_user" &>/dev/null; then
    gpasswd -d nginx "$site_user" 2>/dev/null
    userdel "$site_user"
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
  monitor "$domain"
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
  mkdir -p "/etc/one-click/monitor/${domain}"
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
################################# CRON NAVIGATION ##############################
if [[ "${1:-}" == "-wpback" ]]; then
  wp_backup "${2:-}"
fi
if [[ "${1:-}" == "-wprotate" ]]; then
  wp_backup_rotate "${2:-}"
fi
if [[ "${1:-}" == "-staticback" ]]; then
  static_backup "${2:-}"
fi
if [[ "${1:-}" == "-staticrotate" ]]; then
  static_backup_rotate "${2:-}"
fi
if [[ "${1:-}" == "--monitor-site" ]]; then
  get_monitor_stats "${2:-}"
fi
