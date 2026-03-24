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
# ========================== #================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== WordPress ====
#!/usr/bin/env bash
. /etc/os-release
secret_key="/etc/one-click.backup_secret.key"
current_profile_file="$config_dir/current_profile"
webserver=$(awk -F'"' '/:80|:443/ {print $2}' <(ss -taulpn) | uniq)
if [[ "$ID" == "debian" ]]; then
  php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
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
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  [[ ! -f "$config_path" ]] && {
    error "wp-config.php missing"
    return 1
  }
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
}
wp_restore() {
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
  chown -R "$web_user":"$web_user" "$site_dir"
  chown "$web_user":"$web_user" "$config_path"
  chmod 644 "$config_path"
  success "Restore complete for $domain"
}
wp_backup_scheduler() {
  local domain
  domain="${domain:-${1}}"
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
  #if [[ "$mode" == "backup" ]]; then
  #  read -rp "${cyan}[USER]${blue} Would you like to configure a cronjob to backup daily at 2am (y|n): ${reset}" confirm_backup
  #  confirm_backup="${confirm_backup,,}"
  #  if [[ "$confirm_backup" == "y" || "$confirm_backup" == "yes" ]]; then
  #    wp_backup_scheduler "$domain"
  #  fi
  #fi
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
      1)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "switch" "profile" || return 1
        else
          select_static_domain "switch to" "profile" || return 1
        fi
        profile_switch
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
          select_wp_domain "backup" || return 1
          if [[ -z "${domain:-}" ]]; then
            warn "Please create a vhost before proceeding"
            read -rp "Press Enter to continue"
            run_script
          fi
          resolve_profile "$domain"
          wp_backup "$domain"
        else
          select_static_domain "backup" || return 1
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
          select_wp_domain "restore" || return 1
          resolve_profile "$domain"
          wp_restore_int
        else
          static_restore_int
        fi
        ;;
      3)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "backup" || return 1
        else
          select_static_domain "backup" || return 1
        fi
        remote_backup "$domain" "$wpstatic"
        ;;
      4)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "backup" || return 1
        else
          select_static_domain "backup" || return 1
        fi
        remote_restore "$domain" "$wpstatic"
        ;;
      5)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "rollback" || return 1
        else
          select_static_domain "rollback" || return 1
        fi
        rollback_restore "$domain" "$wpstatic"
        ;;
      6)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "backup" || return 1
        else
          select_static_domain "backup" || return 1
        fi
        local_list "$domain" "$wpstatic"
        read -rp "${cyan}[USER]${blue} Press Enter to continue"
        ;;
      7)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "backup" || return 1
        else
          select_static_domain "backup" || return 1
        fi
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
      8)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "rollback" || return 1
        else
          select_static_domain "rollback" || return 1
        fi
        rollback_list "$domain" ;;
      0) clear; return 0        ;;
      *) echo "Invalid option"  ;;
    esac
  done
}
main_board() {
  while true; do
    paste <(printf "${blue}%s${reset}\n" \
      "╔════════════════════════════════════════════════════════════╗" \
      "║                ${yellow}ONE-CLICK WEB BACKUP MANAGER${blue}                ║" \
      "╠════╦═══════════════════════════════════════════════════════╣" \
      "║ ${magenta}1${blue}  ║ ${green}Backup Restores & Rollback  ${blue}                          ║" \
      "║ ${magenta}2${blue}  ║ ${green}Manage Profiles  ${blue}                                     ║" \
      "║ ${magenta}3${blue}  ║ ${green}Cron   ${blue}                                               ║" \
      "║ ${magenta}0${blue}  ║ ${green}Exit  ${blue}                                                ║" \
      "╚════╩═══════════════════════════════════════════════════════╝") <(get_current_profile)
  read -rp "${cyan}[USER]${blue} Select an option: " choice
    case "$choice" in
      1) backup_board   ;;
      2) profiles_board ;;
      3)
        if [[ "$wpstatic" == "wordpress" ]]; then
          select_wp_domain "backup" || return 1
          install_wp_cron "-wpback" "One-Click WordPress Backup" "$domain"
        else
          select_static_domain "backup" || return 1
          install_wp_cron "-staticback" "One-Click Static Backup" "$domain"
        fi
        ;;
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
  #select_wp_domain "restore" || return 1
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
  #if [[ -d /etc/one-click/wordpress/$domain/www ]]; then
  #  warn "Directory exists"
  #  read -rp "${cyan}[USER]${reset} Reuse existing installation? (y|n): " reuse
  #  [[ "$reuse" != "y" && "$reuse" != "yes" ]] && return 1
  #fi
  if [[ -f "${site}/wp-config.php" ]]; then
    warn "WordPress already exists at $site"
    read -rp "${cyan}[USER]${reset} Skip WP installation and continue (y|n)? " choice
    choice="${choice,,}"
    [[ "$choice" =~ ^[Yy]$ || "$choice" == "yes" ]] && return
    info "Backing up existing wp-config.php"
    cp "$site/wp-config.php" "$site/wp-config.php.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$site"
  chown "$web_user":"$web_user" "$site"
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
  chown -R "$web_user":"$web_user" /etc/one-click/wordpress/$domain/www
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
  #read -rsp "Enter MySQL root password: " root_pass
  #echo
  #mysql -u root -p"$db_pass" -e "CREATE DATABASE $stage_db"
  #mysql -u root -p"$db_pass" -e "GRANT ALL PRIVILEGES ON $stage_db.* TO '$db_user'@'localhost'"
  #mysql -u root -p"$root_pass" -e "FLUSH PRIVILEGES"
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
  cat > "/etc/nginx/conf.d/staging.$domain.conf" <<EOF
server {
    listen 80;
    server_name staging.$domain;

    root $stage_root;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php${php_ver:-}-fpm-${domain}.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
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
  cat << EOF > "$nginx_conf_file"
server {
    listen 80;
    server_name $domain www.$domain;

    root /etc/one-click/wordpress/$domain/www;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php${php_ver:-}-fpm-${domain}.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
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
          if certbot certonly --webroot -w "${site:-${site_dir}}" -d "$domain" -d "www.$domain" --non-interactive --agree-tos -m "$email"; then
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
    /etc/one-click/wordpress/$domain/meta.conf
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
  touch /etc/one-click/sites/$domain/meta.conf
  echo "SITE_USER=$web_user" >> /etc/one-click/wordpress/$domain/meta.conf
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
  warn "Creating web owner"
  id "$web_user" &>/dev/null || useradd -r -s /usr/sbin/nologin "$web_user"
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
  create_site_slice "$domain"
  create_php_pool "$domain"
  create_service_file "$domain"
  info "Enabling PHP"
  systemctl enable php-fpm-${domain} --now 
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
  chown -R root:root /etc/one-click/wordpress/backups
  # ==== Open Firewall ====
  info "Opening firewall ports 80 and 443"
  one-click engine "allow $webserver"
  info "Installing Plugins"
  wp_plugins
  $wp_cmd option get home 
  info "Configuring SSL"
  install_letsencrypt wordpress
  if [[ "$manual_install" -eq 1 ]]; then
    webroot_nginx_template
  fi
  wp_backup_scheduler
  "$pkg_mgr" restart "$webserver"
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_wp-web-monitor_$domain
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
        # Get currently installed plugins
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
_get_site_user() {
  local domain path
  domain="$1"
  for path in \
    "/etc/one-click/wordpress/$domain" \
    "/etc/one-click/sites/$domain"
  do
    [[ -d "$path" ]] && stat -c '%U' "$path" && return
  done
}
############################## STATIC SITES ##############################################
create_static_site() {
  local domain site_dir webserver_choice
  start_screen static
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
  chown "$web_user":"$web_user" "$site_dir"
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
  create_site_slice "$domain"
  create_php_pool "$domain"
  create_service_file "$domain"
  dns_check
  one-click engine "allow $webserver"
  install_letsencrypt static
  wp_backup_scheduler
  echo "* * * * * /var/cache/one-click/wordpress.sh --monitor "$domain" > /dev/null 2>&1" > /etc/cron.d/one-click_static-web-monitor_$domain
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
        fastcgi_pass unix:/run/php${php_ver:-}-fpm-${domain}.sock;
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
  chown -R "$web_user":"$web_user" "$site_dir"
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
select_domain() {
  mode="${1:-}"
  if [[ "${2:-}" == "profile" ]]; then
    type=profile
  elif [[ "${2:-}" == "rollback" ]]; then
    type=restore
  else
    type=site
  fi
  local base_static="/etc/one-click/sites"
  local base_wordpress="/etc/one-click/wordpress"
  local sites i choice
  mapfile -t sites < <(sed -n '/\./p' <(find "$base_static" "$base_wordpress" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
  if [[ ${#sites[@]} -eq 0 ]]; then
    error "No static sites found in $base"
    return
  fi
  printf '%s\n' "${blue}Available Sites:${reset}" " "
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
static_restore_interactive() {
  central_menu static
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
  local new_ver="$2"
  info "Switching $domain to PHP $new_ver..."
  sed -i "s|php[0-9.]*-fpm-${domain}.sock|php${new_ver}-fpm-${domain}.sock|g" /etc/nginx/sites-available/"$domain"
  local service_file="/etc/systemd/system/php-fpm-${domain}.service"
  sed -i "s|/usr/sbin/php-fpm[0-9.]*|/usr/sbin/php-fpm${new_ver}|g" "$service_file"
  sed -i "s|/etc/php/[0-9.]*/fpm/pool.d/|/etc/php/${new_ver}/fpm/pool.d/|g" "$service_file"
  mv /etc/php/${old_ver}/fpm/pool.d/${domain}.conf /etc/php/${new_ver}/fpm/pool.d/${domain}.conf
  systemctl daemon-reload
  systemctl restart "php-fpm-${domain}.service"
  systemctl reload "$webserver"
  success "$domain is now running on PHP $new_ver"
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
  systemctl stop "$fpm_service" && systemctl disable "$fpm_service"
  success "PHP $ver is installed and running."
}
site_tune_php() {
  local configs=($(ls "$conf_path" 2>/dev/null | grep -E ".conf$|^[0-9a-zA-Z_-]+$"))
  [[ ${#configs[@]} -eq 0 ]] && { error "No site configs found."; return 1; }
  echo "Select a site to manage its PHP settings:"
  for i in "${!configs[@]}"; do 
    printf "${magenta}[${yellow}%d${magenta}]${reset} %s\n" "$((i+1))" "${configs[$i]}"
  done 
  while true; do
    read -rp "${cyan}[USER]${blue} Choice: " cfg_idx
    [[ "$cfg_idx" =~ ^[0-9]+$ ]] && (( cfg_idx >= 1 && cfg_idx <= ${#configs[@]} )) && break || error "Invalid selection."
  done
  local target_cfg="$conf_path/${configs[$((cfg_idx-1))]}"
  info "Analyzing $target_cfg..."    
  local detected_ver=$(grep -oP 'php[0-9]+\.[0-9]+' "$target_cfg" | head -n1 | sed 's/php//')
  [[ -z "$detected_ver" ]] && detected_ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
  success "Detected PHP $detected_ver"
  if [[ "${os_family:-}" == "debian" ]]; then
    ini_path="/etc/php/$detected_ver/fpm/php.ini"
    fpm_serv="php-fpm-${domain}"
  else
    ini_path="/etc/opt/remi/php${detected_ver//./}/php.ini"
    [[ ! -f "$ini_path" ]] && ini_path="/etc/php.ini"
    fpm_serv="php-fpm-${domain}"
  fi
  [[ ! -f "$ini_path" ]] && { error "php.ini not found at $ini_path"; return 1; }
  echo -e "\n--- Tuning PHP $detected_ver Settings ---"
  info "File: $ini_path"
  read -rp "${cyan}[USER]${reset} New Memory Limit (e.g. 512M) [Enter to skip]: " mem
  read -rp "${cyan}[USER]${reset} New Max Upload (e.g. 100M) [Enter to skip]: " upload
  read -rp "${cyan}[USER]${blue} Max Execution Time [Enter to skip]: " exec_t
  read -rp "${cyan}[USER]${blue} Display Errors (on|off) [Enter to skip]: " display_error
  update_ini() {
    local key=$1; local val=$2
    sed -i "s|^;*$key *=.*|$key = $val|" "$ini_path"
  }
  [[ -n "$mem" ]] && update_ini "memory_limit" "$mem"
  [[ -n "$upload" ]] && { update_ini "upload_max_filesize" "$upload"; update_ini "post_max_size" "$upload"; }
  [[ -n "$exec_t" ]] && update_ini "max_execution_time" "$exec_t"
  [[ -n "$display_error" ]] && update_ini "display_errors" "$display_error"
  systemctl restart "$fpm_serv"
  success "Settings applied and $fpm_serv restarted."
}
switch_webserver_php() {
  local configs=($(ls "$conf_path" 2>/dev/null | grep -E ".conf$|^[0-9a-zA-Z_-]+$"))
  [[ ${#configs[@]} -eq 0 ]] && { error "No configs found in $conf_path"; return 1; }
  echo "${green}${ul}Available Site Configs:${ul_reset}${reset}"
  for i in "${!configs[@]}"; do 
    printf "${magenta}[${yellow}%d${magenta}]${reset} %s\n" "$((i+1))" "${configs[$i]}"
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Select config (1-${#configs[@]}): " cfg_idx
    if [[ "$cfg_idx" =~ ^[0-9]+$ ]] && (( cfg_idx >= 1 && cfg_idx <= ${#configs[@]} )); then
      break 
    else
      error "Invalid selection. Please enter a number between 1 and ${#configs[@]}."
    fi
  done
  local target_cfg="$conf_path/${configs[$((cfg_idx-1))]}"
  info "Selected: $(basename "$target_cfg")"
  local target_cfg="$conf_path/${configs[$((cfg_idx-1))]}"
  read -rp "${cyan}[USER]${reset} Enter the PHP version to apply (e.g. 8.1): " target_ver
  if ! command -v "php$target_ver" >/dev/null 2>&1 && [[ ! -f "/usr/bin/php$target_ver" ]]; then
    read -rp "${cyan}[USER]${reset} PHP $target_ver not found. Install it? (y|n): " confirm
    [[ "$confirm" == "y" ]] && install_php "$target_ver" || return 1
  fi
  if [[ "$os_family" == "debian" ]]; then
    new_sock="unix:/var/run/php${php_ver:-}-fpm.sock"
  else
    new_sock="unix:/var/run/php-fpm/www.sock" 
  fi
  if [[ ! -S "${new_sock#unix:}" ]]; then
    error "Target PHP socket does not exist: ${new_sock#unix:}"
    return 1
  fi
  info "Updating $target_cfg..."
  sed -Ei "
    s,unix:/var/run/php[0-9.]+-fpm.sock,$new_sock,g
    s,unix:/run/php[0-9.]+-fpm.sock,$new_sock,g
  " "$target_cfg"
  if [[ "$webserver" == "nginx" ]]; then
    nginx -t && systemctl reload nginx && success "Nginx reloaded."
  else
    if [[ "$os_family" == "debian" ]]; then
      apache2ctl configtest
      systemctl reload apache2
    else
      httpd -t
      systemctl reload httpd
    fi
    success "Apache reloaded."
  fi
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
  detect_env
  while true; do
    printf '%s\n' \
      "${yellow}--- PHP MANAGER ---${reset}" \
      "${magenta}OS:${green} $os_family ${blue}| ${magenta}Webserver: ${green}${webserver}" \
      "${blue}----------------------------${reset}" \
      "${magenta}[${yellow}1${magenta}]${reset} Install PHP Version" \
      "${magenta}[${yellow}2${magenta}]${reset} Switch Site PHP (Web)" \
      "${magenta}[${yellow}3${magenta}]${reset} Switch System PHP (CLI)" \
      "${magenta}[${yellow}4${magenta}]${reset} Global PHP.ini Tuning" \
      "${magenta}[${yellow}5${magenta}]${reset} Site-Specific Tuning" \
      "${magenta}[${yellow}6${magenta}]${reset} Exit"
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
        2) switch_webserver_php   ;;
        3) switch_cli_php         ;;
        4) tune_php_settings      ;;
        5) site_tune_php          ;;
        6) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
        *) error "Invalid option" ;;
      esac
    done
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
    wp_backup "$domain" >/dev/null 2>&1
  else
    base="/etc/one-click/sites"
    static_backup "$domain" >/dev/null 2>&1
  fi
  backup_source="$base/backups/$domain"
  latest=$(ls -dt "$backup_source/"* 2>/dev/null | head -n1)
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
monitor_history_file="/etc/one-click/rule-engine/guard/history"
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
  echo "{\"ts\":$ts,\"ip\":\"$ip\",\"proto\":\"$proto\",\"port\":\"$port\",\"action\":\"$action\",\"duration\":$duration}" >> "$monitor_history_file"
  (
    sleep "$duration"
    if $fw_bin -C INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action" &>/dev/null; then
        $fw_bin -D INPUT -p "$proto" --dport "$port" -s "$ip" -j "$action"
        echo "{\"ts\":$(date +%s),\"ip\":\"$ip\",\"action\":\"UNBLOCKED\",\"reason\":\"Timeout\"}" >> "$monitor_history_file"
    fi
  ) &
}
monitor_web_logs() {
  info() { 
    s=$1
    printf "$(tput setaf 4)[INFO]:$(tput sgr 0) %s${s}\n" 
  }
  local log_files=()
  local ip reason duration guard_id stats_file
  stats_file="/etc/one-click/rule-engine/guard//monitor_stats.db"
  paths=(
    "/var/log/nginx/access.log" "/var/log/nginx/error.log"
    "/var/log/apache2/access.log" "/var/log/apache2/error.log"
    "/var/log/httpd/access.log" "/var/log/httpd/error_log"
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
  info "Live Guard active on: ${log_files[*]}"
  tail -Fn0 "${log_files[@]}" | while read -r line; do
    if [[ "$line" =~ ([0-9]{1,3}(\.[0-9]{1,3}){3}) || "$line" =~ ^([a-fA-F0-9:]+)$ ]]; then
      ip="${BASH_REMATCH[1]}"  
      for safe_ip in "${WHITELIST[@]}"; do 
        [[ "$ip" == "$safe_ip" ]] && continue 2
      done
      if [[ "$line" =~ " 404 " ]]; then
        ((offense_count["$ip"]++))
        if (( offense_count["$ip"] >= 10 )); then
          reason="Web Scanner (404 Spamming)"
          duration=3600
          info "Guard: Banning $ip for $duration seconds ($reason)"
          apply_block "$ip" "all" "0:65535" "DROP" "$duration"
          offense_count["$ip"]=0 
        fi
      fi
      if [[ "$line" =~ "login failed" || "$line" =~ "wplogin" ]]; then
        ((offense_count["$ip"]++))
        if (( offense_count["$ip"] >= 5 )); then
          reason="Brute Force Attempt"
          duration=86400
          apply_block "$ip" "all" "0:65535" "DROP" "$duration"
          offense_count["$ip"]=0
        fi
      fi      
      printf "%s %s\n" "${offense_count["$ip"]}" "$ip" >> "$stats_file.tmp"
      mv "$stats_file.tmp" "$stats_file"
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
  monitor_web_logs
fi
if ! systemctl is-active one-click-guard.service &> /dev/null; then
  systemctl daemon-reload
  systemctl enable one-click-guard.service --now
fi
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
  if grep "^$domain=" "$map_file" 2>/dev/null; then
    profile=$(grep "^$domain=" "$map_file" 2>/dev/null | cut -d'=' -f2)
  else
    profile=
  fi
  if [[ -z "$profile" ]]; then
    info "No profile assigned to $domain"
    profile_assign "$domain"
    profile=$(grep "^$domain=" "$map_file" 2>/dev/null | cut -d'=' -f2)
  fi
  load_profile "$profile"
  remote_host="$profile_host"
  remote_user="$profile_user"
  remote_base="$profile_base"
}
check_auth() {
  if [[ -n "${profile_pass:-}" ]]; then
    sshpass="$profile_pass"
    use_sshpass=1
    return 0
  fi
  if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$user@$host" "exit" >/dev/null 2>&1; then
    read -rsp "${cyan}[USER]${blue} ${host}'s password: " sshpass
    if [[ -n "$sshpass" ]]; then
      e_pass=$(encrypt_password "$sshpass")
    fi
    echo
    use_sshpass=1
  else
    use_sshpass=0
  fi
  export e_pass
  export d_pass
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
  resolve_profile "$domain"
  if [[ "$type" == "wordpress" ]]; then
    wp_backup "$domain"
    base="/etc/one-click/wordpress"
  else
    static_backup "$domain"
    base="/etc/one-click/sites"
  fi
  latest=$(ls -dt "$base/backups/$domain/"* | head -n1)
  timestamp=$(basename "$latest")
  d_pass="$profile_pass"
  info "A remote backup will be processed by creating a local backup first" \
    "Once complete, it will be sent to your remote storage based on profile"
  remote_path="$remote_base/$(hostname)/$domain/$timestamp"
  check_auth
  run_ssh "mkdir -p $remote_path"
  run_rsync "$latest/" "$remote_user@$remote_host:$remote_path/"
  success "Remote backup completed"
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
  local domain type base timestamp
  domain="$1"
  mode="${2:-}"
  if [[ "${mode:-}" == "wordpress" ]]; then
    base="/etc/one-click/wordpress/backups/$domain"
  else
    base="/etc/one-click/sites/backups/$domain"
  fi  
  [[ ! -d "$base" ]] && { 
    error "No local backups found for $domain"; 
    return 1; 
  }
  echo -e "\e[34m╔════╦══════════════════════╦══════════════════════╗\e[0m"
  echo -e "\e[34m║ ID ║ Timestamp            ║ Type                 ║\e[0m"
  echo -e "\e[34m╠════╬══════════════════════╬══════════════════════╣\e[0m"
  mapfile -t backups < <(ls -dt "$base"/*/ 2>/dev/null)
  timestamps=()
  local i=1
  for b in "${backups[@]}"; do
    ts=$(basename "$b")
    timestamps+=("$ts")
    if [[ -f "$b/db.sql.gz" ]]; then
      type="wordpress"
    else
      type="static"
    fi
    printf "\e[34m║ %-2s ║ %-20s ║ %-20s ║\e[0m\n" "$i" "$ts" "$type"
    ((i++))
  done
  echo -e "\e[34m╚════╩══════════════════════╩══════════════════════╝\e[0m"
  if [[ "${2:-}" == "restore" ]]; then
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
  monitor_info=$(get_monitor_stats)
  if [[ -z "${domain:-}" ]]; then
    lb_ts="Not Loaded"
    disk_usage="Not Loaded"
  fi
  if [[ -f "$current_profile_file" ]]; then
    printf "${yellow}[${red}[${magenta}Current Profile: ${blue}$(cat ${current_profile_file:-Not Loaded})${red}]${yellow}]${reset}\n"
    echo -e "${blue}┌──────────────────────────────────────────────────────────┐"
    printf "${blue}│${yellow}  %-15s${blue} │${yellow} %-37s ${blue}│${reset}\n" "Uptime" "$monitor_info"
    printf "${blue}├──────────────────────────────────────────────────────────┤\n" 
    printf "${blue}│${magenta}  %-15s ${blue}│${green} %-37s ${blue}│${reset}\n" \
      "Domain" "${domain:-N/A}" \
      "Last Backup" "$lb_ts" \
      "Disk Usage" "$disk_usage"
    echo -e "${blue}└──────────────────────────────────────────────────────────┘${reset}"
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
  read -rp "${cyan}[USER]${blue} Enter ${hosts}'s username [root]: " user
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
################################## RESOURCE CONTROL ######################################
create_site_slice() {
  local domain="$1"
  local mem_limit="${2:-512M}"
  local cpu_limit="${3:-50%}" 
  local slice_name="one-click_${domain}.slice"
  if [[ -z "$domain" ]]; then
    error "No domain provided"
    return 1
  fi
  local slice_file="/etc/systemd/system/${slice_name}"
  cat > "$slice_file" <<EOF
[Unit]
Description=One-Click Resource Slice for $domain

[Slice]
MemoryMax=$mem_limit
CPUQuota=$cpu_limit
EOF
  systemctl daemon-reload
  systemctl start "$slice_name"
  systemctl enable "$slice_name" >/dev/null 2>&1
  success "Slice $slice_name created with Memory=$mem_limit CPU=$cpu_limit"
  if [[ -d "/etc/php-fpm.d/" ]]; then
    local pool_file="/etc/php-fpm.d/${domain}.conf"
  else
    local pool_file="/etc/php/${domain}.conf"
  fi
  if [[ -f "$pool_file" ]]; then
    systemctl reload php-fpm-${domain}.service --now
    info "PHP-FPM pool $domain assigned to slice $slice_name"
  fi
  info "Any future cron or CLI tasks for $domain can be run in this slice using:"
  printf "${magenta}%s${reset}\n" "systemd-run --slice=$slice_name --unit=oneclick-$domain <command>"
  success "Per-site resource isolation ready for $domain"
}
create_service_file() {
  local domain service_file
  domain="${1:-}"
  service_file="/etc/systemd/system/php-fpm-${domain}.service"
  if [[ -f /usr/sbin/php-fpm ]]; then
    local php_path="/usr/sbin/php-fpm"
  else
    local php_path="/usr/sbin/php-fpm${php_ver:-}"
  fi
  if [[ -d "/etc/php-fpm.d/" ]]; then
    local pool_file="/etc/php-fpm.d/${domain}.conf"
  else
    local pool_file="/etc/php/${domain}.conf"
  fi
  cat > "$service_file" <<EOF
[Unit]
Description=PHP-FPM for $domain
After=network.target

[Service]
Type=notify
Slice=one-click_${domain}.slice
ExecStart=$php_path --nodaemonize --fpm-config "$pool_file"
ExecReload=/bin/kill -USR2 \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}
create_php_pool() {
  local domain="$1"
  local slice_name="one-click_${domain}.slice"
  if [[ -d "/etc/php-fpm.d/" ]]; then
    local pool_file="/etc/php-fpm.d/${domain}.conf"
  else
    local pool_file="/etc/php/${domain}.conf"
  fi
  if grep -q "nginx" /etc/group; then
    local webserver="nginx"
  elif grep -q "www-data" /etc/group; then
    local webserver="www-data"
  elif grep -q "apache" /etc/group; then
    local webserver="apache"
  else
    local webserver="nobody"
  fi
  local socket="/run/php${php_ver:-}-fpm-${domain}.sock"
  cat > "$pool_file" <<EOF
[$domain]
user = $web_user
group = $web_user

listen = $socket
listen.owner = $web_user
listen.group = $webserver
listen.mode = 0660

pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 10s
pm.max_requests = 500

; Logging
php_admin_value[error_log] = /var/log/php-fpm${php_ver:-}-$domain.log
php_admin_flag[log_errors] = on
EOF
  systemctl disable php-fpm --now || systemctl disable php${php_ver:-}-fpm --now
  #systemctl enable php-fpm-${domain}.service --now
  success "PHP-FPM pool created for $domain on socket $socket and slice $slice_name"
  info "To control the php service, use the following" "${magenta}php-fpm-${domain}.service${reset}"
}
################################# SITE REMOVAL ###############################
delete_site() {
  local domain="$1"
  web_user=$(awk 'NR != 1 && NR != 2 {print $3}' <(ls -l /etc/one-click/{wordpress,sites}/$domain 2> /dev/null) | head -1)
  detect_env 
  local type="${2:-wordpress}"
  local slice_name="one-click_${domain}.slice"
  local service_name="php-fpm-${domain}.service"
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
        mysql -e "DROP USER IF EXISTS '$db_user'@'localhost';"
      else
        warn "DB User $db_user is still in use by $((user_occurrence - 1)) other site(s). Skipping user deletion."
      fi
    fi
  fi
  # ==== MISC LOST+FOUND ====
  find /etc /var /run -type f -name '*one-click*' | while read line; do
    rm -f "$line"
  done
  # ==== Remove system user ====
  if id "$site_user" &>/dev/null; then
    gpasswd -d nginx "$site_user" 2>/dev/null
    userdel "$site_user"
  fi
  # ==== Systemd cleanup ====
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl reset-failed
  success "Fully removed $domain"
}
get_monitor_stats() {
  if [[ ! -f /etc/one-click/.domain.profile ]]; then
    domain="${1:-}"
  else
    domain=$(cat /etc/one-click/.domain.profile)
  fi
  check_url="https://${domain:-}"
  status_file="/tmp/.monitor_${domain:-}_status"
  log_file="/var/log/monitor_${domain:-}.log"
  if [[ -f "$status_file" ]]; then
    read -r state start_ts < "$status_file"
    diff=$(( $(date +%s) - start_ts ))
    uptime_str="$(($diff / 86400))d $(($diff % 86400 / 3600))h $(($diff % 3600 / 60))m"
      if [[ -n "$domain" ]]; then
        echo "$domain" > /etc/one-click/.domain.profile
      fi
      if [[ "$state" == "UP" ]]; then
        echo "Online for $uptime_str"
      else
        echo "Offline for $uptime_str"
      fi
    else
    echo "No data yet"
  fi
}
monitor() {
  domain="${1:-}"
  check_url="https://$domain"
  status_file="/tmp/.uptime-monitor_${domain}_status"
  log_file="/var/log/uptime-monitor_${domain}.log"
  now=$(date +%s)
  http_status=$(curl -o /dev/null -s -w "%{http_code}" --max-time 2 "$check_url")
  if [[ -f "$status_file" ]]; then
    read -r last_state last_ts < "$status_file"
  else
  last_state="INIT"
  last_ts=$now
  fi
  if [[ "$http_status" -eq 200 ]]; then
    if [[ "$last_state" == "DOWN" ]]; then
      downtime=$((now - last_ts))
      echo "$(date): $domain is BACK UP. It was down for $downtime seconds." >> "$log_file"
    fi
    if [[ "$last_state" != "UP" ]]; then
      echo "UP $now" > "$status_file"
    else
      echo "UP $last_ts" > "$status_file"
    fi
  else
    if [[ "$last_state" == "UP" || "$last_state" == "INIT" ]]; then
      echo "$(date): $domain is DOWN (Status: $http_status)" >> "$log_file"
      echo "DOWN $now" > "$status_file"
    fi
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
if [[ "${1:-}" == "--monitor" ]]; then
  get_monitor_stats "${2:-}"
fi
