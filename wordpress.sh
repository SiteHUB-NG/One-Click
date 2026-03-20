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
. /etc/os-release
if [[ "$ID" == "debian" ]]; then
  php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
fi
if id www-data &>/dev/null; then
  web_user="www-data"
elif id apache &>/dev/null; then
  web_user="apache"
elif id nginx &>/dev/null; then
  web_user="nginx"
fi
dns_check() {
  dns=$(dig +short "$domain" | tail -n1)
  dns_www=$(dig +short "www.$domain" | tail -n1)
  if [[ "$dns" != "$sys_ip" ]]; then
    warn "Domain does not resolve to this server ($sys_ip)"
    return 1
  fi
}
# ==== Wordpress Backup ====
wp_backup() {
  info() {
    printf "$(tput setaf 4)[INFO]:$(tput sgr 0) %s\n"
  }
  success() {
    printf "$(tput setaf 2)[SUCCESS]$(tput sgr 0) %s\n"
  }
  local domain base site backup timestamp
  domain="${1:-}"
  base="/etc/one-click/wordpress"
  site="$base/www/$domain"
  backup="$base/backups/$domain"
  timestamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  [[ ! -f "$site/wp-config.php" ]] && {
    error "wp-config.php missing"
    return 1
  }
  info "Creating WordPress backup for $domain"
  mkdir -p "$backup/$timestamp"
  local db_name db_user db_pass
  db_name=$(grep DB_NAME "$site/wp-config.php" | cut -d"'" -f4)
  db_user=$(grep DB_USER "$site/wp-config.php" | cut -d"'" -f4)
  db_pass=$(grep DB_PASSWORD "$site/wp-config.php" | cut -d"'" -f4)
  info "Backing up database..."
  mysqldump -u"$db_user" -p"$db_pass" "$db_name" | gzip | pv > "$backup/$timestamp/db.sql.gz"
  info "Archiving files..."
  tar -czf "$backup/$timestamp/files.tar.gz" -C "$site" .
  cat > "$backup/$timestamp/meta.conf" <<EOF
DOMAIN=$domain
DB_NAME=$db_name
DB_USER=$db_user
TIMESTAMP=$timestamp
EOF
  success "Backup stored at $backup/$timestamp"
}
wp_restore() {
  read -rp "${cyan}[USER]${blue} This will overwrite $domain. Continue? (y|n): " confirm
  if [[ "$confirm" != "y" ]]; then 
    return 1
  fi
  local domain base site_dir backup_dir
  domain="${domain:-${1}}"
  backup_dir="$2"
  base="/etc/one-click/wordpress"
  site_dir="$base/www/$domain"
  [[ ! -d "$backup_dir" ]] && {
    die "Backup directory not found"
  }
  [[ -d "$site_dir" && "$site_dir" == *"/www/"* ]] || {
    die "Invalid site_dir"
  }
  info "Loading metadata..."
  source "$backup_dir/meta.conf"
  local db_name db_user db_pass
  db_name=$(grep DB_NAME "$site_dir/wp-config.php" | cut -d"'" -f4)
  db_user=$(grep DB_USER "$site_dir/wp-config.php" | cut -d"'" -f4)
  db_pass=$(grep DB_PASSWORD "$site_dir/wp-config.php" | cut -d"'" -f4)
  info "Restoring files..."
  find "$site_dir" -mindepth 1 -delete
  tar -xzf "$backup_dir/files.tar.gz" -C "$site_dir"
  info "Restoring database..."
  gunzip < "$backup_dir/db.sql.gz" | pv | mysql -u"$db_user" -p"$db_pass" "$db_name"
  chown -R "$web_user":"$web_user" "$site_dir"
  success "Restore complete for $domain"
}
wp_backup_scheduler() {
  local domain="${domain:-${1}}"
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
  base="/etc/one-click/wordpress/www"
  mapfile -t sites < <(find "$base" -mindepth 1 -maxdepth 1 -type d)
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
  read -rp "${cyan}[USER] ${blue}Select a site to $mode by number: ${reset}" choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#sites[@]})); then
    error "Invalid selection"
    return 1
  fi
  domain=$(basename "${sites[$((choice-1))]}")
  export domain
  if [[ "$mode" == "backup" ]]; then
    read -rp "${cyan}[USER]${blue} Would you like to configure a cronjob to backup daily at 2am (y|n): ${reset}" confirm_backup
    confirm_backup="${confirm_backup,,}"
    if [[ "$confirm_backup" == "y" || "$confirm_backup" == "yes" ]]; then
      wp_backup_scheduler "$domain"
    fi
  fi
}
wp_backup_interactive() {
  select_wp_domain "backup" || return 1
  wp_backup "$domain"
}
wp_restore_interactive() {
  local backup_base backups i choice
  select_wp_domain "restore" || return 1
  backup_base="/etc/one-click/wordpress/backups/$domain"
  backups i choice
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
  if [[ -d "$site" ]]; then
    warn "Directory exists"
    read -rp "${cyan}[USER]${reset} Reuse existing installation? (y|n): " reuse
    [[ "$reuse" != "y" && "$reuse" != "yes" ]] && return 1
  fi
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
  chown -R "$web_user":"$web_user" /etc/one-click/wordpress/www/$domain
  find /etc/one-click/wordpress/www/$domain -type d -exec chmod 755 {} \;
  find /etc/one-click/wordpress/www/$domain -type f -exec chmod 644 {} \;
}
# ==== Plugins ====
wp_plugins() {
  $wp_cmd plugin install \
    redis-cache \
    wordfence \
    wp-super-cache \
    --activate 
  # ==== Installing Selected Services ====
  if [[ "$enable_redis" == "y" ]]; then
    $wp_cmd plugin activate redis-cache 
    $wp_cmd redis enable 
  fi
}
# ==== WP Staging ====
wp_staging() {
  prod="/etc/one-click/wordpress/www/$domain"
  stage="/etc/one-click/wordpress/staging/$domain"
  info "Creating staging environment"
  mkdir -p "$stage"
  rsync -a "$prod/" "$stage/"
  cd "$stage"
  $wp_cmd db export stage.sql 
  stage_db="stage_$(openssl rand -hex 4)"
  mysql -e "CREATE DATABASE $stage_db"
  mysql -e "GRANT ALL PRIVILEGES ON $stage_db.* TO '$dbuser'@'localhost'"
  mysql -e "FLUSH PRIVILEGES"
  $wp_cmd config set DB_NAME "$stage_db" 
  $wp_cmd db import stage.sql 
  $wp_cmd option update siteurl "https://staging.$domain" 
  $wp_cmd option update home "https://staging.$domain" 
  info "Staging created at staging.$domain"
}
wp_staging_push() {
  prod="/etc/one-click/wordpress/www/$domain"
  stage="/etc/one-click/wordpress/staging/$domain"
  info "Deploying staging to production"
  rsync -a --delete "$stage/" "$prod/"
  cd "$prod"
  $wp_cmd db export deploy.sql 
  $wp_cmd db import deploy.sql 
  info "Deployment completed"
}
# ==== Install Webserver ====
install_webserver() {
  local mode
  mode="$1"
  domain="${2:-}"
  site_dir="${3:-}"
  if [[ "$pkg_mgr" == "apt" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      "$pkg_mgr" install -y nginx
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
      a2ensite "$domain-le-ssl.conf"
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

    root /etc/one-click/wordpress/www/$domain;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php${php_ver}-fpm.sock;
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

    DocumentRoot /etc/one-click/wordpress/www/$domain

    <Directory /etc/one-click/wordpress/www/$domain>
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

    DocumentRoot /etc/one-click/wordpress/www/$domain

    <Directory /etc/one-click/wordpress/www/$domain>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$domain-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain-ssl-access.log combined
</VirtualHost>
</IfModule>
EOF
  sed -Ei 's/#(Redirect permanent)/\1/' "$apache_confi"
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
    "│${yellow}              $default_site                                        ${blue}│" \
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
    start_screen wordpress
    while true; do
      read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to issue SSL for: " domain
      [[ -n "$domain" ]] && break
      if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Invalid domain name"
      fi
    done
    if [[ "$mode" == "wordpress" ]]; then
      site="/etc/one-click/wordpress/www/$domain"
    else
      site="/etc/one-click/static/www/$domain"
    fi
    wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
    if command -v nginx &> /dev/null; then
      webserver="nginx"
    fi
    if command -v httpd &> /dev/null; then
      webserver="httpd"
    fi
    if command -v apache2 &> /dev/null; then
      webserver=apache2
    fi
    email=$($wp_cmd option get admin_email || true)
  fi
  if [[ -z "$email" ]]; then
    while true; do
      read -rp "${cyan}[USER]${reset} Please provide an email address for LetsEncrypt: " email
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
    "$pkg_mgr" install -y certbot
    if [[ "$webserver" == "nginx" ]]; then
      "$pkg_mgr" install -y python3-certbot-nginx
    else
      "$pkg_mgr" install -y python3-certbot-apache
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
      echo "  [1] Retry"
      echo "  [2] Change email"
      echo "  [3] Skip SSL setup"
      echo "  [4] View logs"
      read -rp "${cyan}[USER]${reset} Choose an option: " choice
      case "$choice" in
        1) continue ;;
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
  site="/etc/one-click/wordpress/www/$domain"
  wp_cmd="sudo -u "$web_user" /usr/local/bin/wp --path=$site"
  mkdir -p "$site"
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
  install_wp_cli
  install_webserver wordpress
  systemctl enable php${php_ver:-}-fpm --now
  configure_db
  dns_check
  download_wp
  install_wp
  harden_wp
  # ==== Open Firewall ====
  one-click engine "allow $webserver"
  wp_plugins
  $wp_cmd option get home 
  install_letsencrypt wordpress
  wp_backup_scheduler
  success "One-Click Wordpress has now been installed!"
  info "Access the site from ${magenta}https://${domain}${reset}"
  info "Access WP Admin page via ${magenta}https://${domain}/wp-admin${reset}"
}
if [[ "${1:-}" == "-wpback" ]]; then
  wp_backup "${2:-}"
fi
if [[ "${1:-}" == "-wprotate" ]]; then
  wp_backup_rotate "${2:-}"
fi
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
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the Admin Email: " email
    [[ -n "$email" ]] && break
  done
  site_dir="/etc/one-click/sites/www/$domain"
  mkdir -p "$site_dir"
  chown "$web_user":"$web_user" "$site_dir"
  cat <<'EOF' > "$site_dir/index.html"
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>SiteHUB Default WebPage</title><link rel="icon" type="image/png" href="https://sitehub.agency/wp-content/uploads/2025/06/cropped-Untitled-design-9-e1750161170804.png"><link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet"><style>*{margin:0;padding:0;box-sizing:border-box}body,html{height:100%;font-family:'Roboto',sans-serif}body{background:linear-gradient(135deg,#28a745,#003366);display:flex;flex-direction:column;justify-content:space-between;color:#fff}header{text-align:center;padding:50px 20px}header img.logo{height:80px;margin-bottom:20px}header h1{font-size:2.5em;margin-bottom:10px}header p{font-size:1.2em}.visuals{position:absolute;top:0;left:0;width:100%;height:100%;overflow:hidden;z-index:0}.visuals span{position:absolute;display:block;border-radius:50%;background:rgba(255,255,255,.05);animation:float 25s linear infinite}@keyframes float{0%{transform:translateY(0) rotate(0deg)}100%{transform:translateY(-1000px) rotate(720deg)}}main{position:relative;z-index:1;max-width:900px;margin:0 auto;padding:20px;text-align:center}section{margin:50px 0}.main-hero h2{font-size:2em;margin-bottom:15px}.main-hero p{font-size:1.1em;line-height:1.6;margin-bottom:25px}.cta-btn{display:inline-block;background:#fff;color:#003366;font-weight:700;text-decoration:none;padding:12px 25px;border-radius:50px;margin:10px;transition:all .3s ease}.cta-btn:hover{background:#e0e0e0}footer{text-align:center;padding:20px;font-size:.9em;color:rgba(255,255,255,.7)}@media(max-width:768px){header h1{font-size:2em}.main-hero h2{font-size:1.6em}}</style></head><body><div class="visuals" id="visuals"></div><header><img class="logo" src="https://us1.plesk.sitehub.agency/images/logos/6EwrLBBn5Xg.png" alt="SiteHUB"><h1>Default Web Page for <span id="domain-name">dynamic-domain.ng</span></h1><p>This page is generated by <a href="https://sitehub.agency" style="color:darkgreen;text-decoration:none;">Site <span style="color:blue;text-decoration:none;">HUB</span></a>, the leading hosting provider in Nigeria.<br>You see this page because there is no website at this address.</p></header><main id="placeholder-content"></main><footer>Copyright &copy; SiteHUB Agency <span id="year"></span>. All rights reserved - RC6935293</footer><script>document.getElementById("year").textContent=new Date().getFullYear();document.addEventListener("DOMContentLoaded",()=>{const e=location.hostname,t=location.protocol+"//"+e+":8443",n="support@sitehub.agency";document.getElementById("domain-name").textContent=e;const o=document.getElementById("placeholder-content");let a="";a+=`<section class="main-hero"><h2>Your domain <strong>${e}</strong> is now live!</h2><p><strong>${e}</strong> default page has been generated by the One-Click Toolbox Automation tool . No website content has been uploaded yet.<br>For more information about One-Click Toolbox:</p><a class="cta-btn" href="https://github.com/SiteHUB-NG/One-Click/" target="_blank">View On GitHub</a><br><br><br><hr><br><h2>Need Hosting?</h2><p>Start your own website in minutes with our web hosting & VPS plans!</p><a class="cta-btn" href="https://sitehub.agency/shared/" target="_blank">View Web Hosting Plans</a><a class="cta-btn" href="https://features.sitehub.agency/vps/" target="_blank">View VPS Plans</a></section>`,a+=`<section class="main-hero"><h2>Need Help?</h2><p>Contact our support team: <a style="color:#fff;text-decoration:underline;" href="mailto:${n}">${n}</a></p></section>`,o.innerHTML=a;const r=document.getElementById("visuals");for(let t=0;t<30;t++){let n=document.createElement("span"),o=60*Math.random()+20;n.style.width=o+"px",n.style.height=o+"px",n.style.left=100*Math.random()+"%",n.style.top=100*Math.random()+"%",n.style.animationDuration=20+20*Math.random()+"s",r.appendChild(n)}});</script></body></html>
EOF
  success "New site prepared at %s\n" "$site_dir"
  printf '%s\n' "Which webserver should host $domain?" \
    "[1] Nginx" \
    "[2] Apache"
  read -rp "${cyan}[USER]${reset} Select Web Server (1|2): " webserver_choice
    case "$webserver_choice" in
      1) webserver="nginx" ;;
      2) webserver="apache" ;;
      *) echo "Invalid selection"; return 1 ;;
  esac
  install_webserver static "$domain" "$site_dir"
  dns_check
  one-click engine "allow $webserver"
  install_letsencrypt static
  wp_backup_scheduler
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
        fastcgi_pass unix:/run/php/php${php_ver:-}-fpm.sock;
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
  local domain base site backup timestamp webserver
  domain="${1:-}"
  base="/etc/one-click/sites"
  site="$base/www/$domain"
  backup="$base/backups/$domain"
  timestamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -d "$site" ]] && {
    error "Site directory not found"
    return 1
  }
  # 🔒 Strong validation (like wp-config.php)
  [[ ! -f "$site/index.html" && ! -f "$site/index.php" ]] && {
    error "No index file found (not a valid static site)"
    return 1
  }
  info "Creating static site backup for $domain"
  mkdir -p "$backup/$timestamp"
  if [[ -f "/etc/nginx/sites-available/$domain.conf" || -f "/etc/nginx/conf.d/$domain.conf" ]]; then
    webserver="nginx"
  elif [[ -f "/etc/apache2/sites-available/$domain.conf" || -f "/etc/httpd/conf.d/$domain.conf" ]]; then
    webserver="apache"
  else
    webserver="unknown"
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
EOF
  success "Backup stored at $backup/$timestamp"
}
static_restore() {
  read -rp "${cyan}[USER]${blue} This will overwrite $domain. Continue? (y|n): " confirm
  [[ "$confirm" != "y" && "$confirm" != "yes" ]] && return 1
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
        cp "$backup_dir/nginx.conf" /etc/nginx/sites-available/$domain.conf 2>/dev/null || \
        cp "$backup_dir/nginx.conf" /etc/nginx/conf.d/$domain.conf
        [[ -d /etc/nginx/sites-enabled ]] && \
        ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/
        systemctl reload nginx
      fi
      ;;
    apache)
      if [[ -f "$backup_dir/apache.conf" ]]; then
        if [[ -d /etc/apache2 ]]; then
          cp "$backup_dir/apache.conf" /etc/apache2/sites-available/$domain.conf
          a2ensite "$domain"
          systemctl reload apache2
        else
          cp "$backup_dir/apache.conf" /etc/httpd/conf.d/$domain.conf
          systemctl reload httpd
        fi
      fi
      ;;
  esac
  chown -R "$web_user":"$web_user" "$site_dir"
  success "Restore complete for $domain"
}
select_static_domain() {
  mode="${1}"
  local base="/etc/one-click/sites/www"
  local sites i choice
  mapfile -t sites < <(find "$base" -mindepth 1 -maxdepth 1 -type d)
  if [[ ${#sites[@]} -eq 0 ]]; then
    error "No static sites found in $base"
    return 1
  fi
  printf '%s\n' "${blue}Available Static sites:${reset}" " "
  printf "${magenta}%-3s${blue} | ${yellow}%s${reset}\n" "No" "Domain"
  echo "${blue}------------------------${reset}"
  for i in "${!sites[@]}"; do
    printf "${magenta}%-3s ${blue}| ${yellow}%s${reset}\n" "$((i+1))" "$(basename "${sites[$i]}")"
  done
  read -rp "${cyan}[USER] ${blue}Select a site to $mode by number: ${reset}" choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#sites[@]})); then
    error "Invalid selection"
    return 1
  fi
  domain=$(basename "${sites[$((choice-1))]}")
  export domain
}
static_backup_interactive() {
  select_static_domain "backup" || return 1
  static_backup "$domain"
}
static_restore_interactive() {
  select_static_domain "restore" || return 1
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
    os_family="debian"; pkg_manager="apt-get"; web_user="www-data"
  elif [[ -f /etc/redhat-release ]]; then
    os_family="rhel"; pkg_manager="dnf"; web_user="apache"
    command -v dnf >/dev/null 2>&1 || pkg_manager="yum"
  else
    error "Unsupported OS."
    ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 1
  fi
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
  systemctl restart "$fpm_service" && systemctl enable "$fpm_service"
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
    fpm_serv="php$detected_ver-fpm"
  else
    ini_path="/etc/opt/remi/php${detected_ver//./}/php.ini"
    [[ ! -f "$ini_path" ]] && ini_path="/etc/php.ini"
    fpm_serv="php-fpm"
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
    read -rp "${cyan}[USER]${reset} PHP $target_ver not found. Install it? (y/n): " confirm
    [[ "$confirm" == "y" ]] && install_php "$target_ver" || return 1
  fi
  if [[ "$os_family" == "debian" ]]; then
    new_sock="unix:/var/run/php/php$target_ver-fpm.sock"
  else
    new_sock="unix:/var/run/php-fpm/www.sock" 
  fi
  if [[ ! -S "${new_sock#unix:}" ]]; then
    error "Target PHP socket does not exist: ${new_sock#unix:}"
    return 1
  fi
  info "Updating $target_cfg..."
  sed -Ei "
    s|unix:/var/run/php/php[0-9.]+-fpm.sock|$new_sock|g
    s|unix:/run/php/php[0-9.]+-fpm.sock|$new_sock|g
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
  echo "Select PHP version to tune:"
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
    fpm_serv="php$sel_ver-fpm"
  else
    ini_path="/etc/opt/remi/php${sel_ver//./}/php.ini"
    [[ ! -f "$ini_path" ]] && ini_path="/etc/php.ini"
    fpm_serv="php-fpm"
  fi
  [[ ! -f "$ini_path" ]] && { error "php.ini not found at $ini_path"; return 1; }
  echo -e "\nModifying settings for PHP $sel_ver ($ini_path)"
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
##################################### SECURITY ##################################
declare -gA offense_count
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
if ! systemctl is-active one-click-guard.service 2> /dev/null; then
  systemctl daemon-reload
  systemctl enable one-click-guard.service --now
fi
