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
php_ver=$(awk '/^PHP/{split($2,arr,".");print arr[1]"."arr[2]}' <(php -v))
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
backup="/etc/one-click/wordpress/backups/$domain"
timestamp=$(date +%Y%m%d-%H%M%S)
info "Creating WordPress backup"
mkdir -p "$backup/$timestamp"
wp db export "$backup/$timestamp/db.sql" 
tar -czf "$backup/$timestamp/files.tar.gz" -C "$site" .
info "Backup stored at $backup/$timestamp"
}
wp_backup_scheduler() {
  cat <<EOF >/etc/cron.d/one-click-wp-backups
0 2 * * * root /usr/local/bin/one-click wp backup $domain # One-Click WP Backup
30 2 * * * root /usr/local/bin/one-click wp rotate $domain # One-Click WP Rotate
EOF
}
wp_backup_rotate() {
  backup="/etc/one-click/wordpress/backups/$domain"
  find "$backup" -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
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
  cd "$site" || return
  if [[ ! -f "${site}/wp-config.php" ]]; then
    $wp_cmd core download  || {
      warn "WP available in this location..."
      #sleep 2
      #$wp_cmd core download 
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
  chown -R www-data:www-data /etc/one-click/wordpress/www/$domain
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
# ==== WP Rollback ====
wp_restore() {
  backup="$1"
  info "Restoring WordPress backup: $backup"
  tar -xzf "$backup/files.tar.gz" -C "$site"
  $wp_cmd db import "$backup/db.sql" 
  info "Rollback completed"
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
  if [[ "$pkg_mgr" == "apt" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      "$pkg_mgr" install -y nginx
      nginx_conf
    else
      "$pkg_mgr" install -y apache2 libapache2-mod-php
      apache_conf
      a2ensite "${domain}.conf"
      a2ensite "$domain-le-ssl.conf"
      systemctl reload apache2
    fi
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    if [[ "$webserver" == "nginx" ]]; then
      "$pkg_mgr" install -y nginx
      nginx_conf
    else
      "$pkg_mgr" install -y httpd php php-fpm
      apache_conf
      httpd -t
    fi
  fi
}
# ==== Webservers Configs ====
# ==== Nginx ====
nginx_conf() {
cat << EOF > /etc/nginx/sites-available/$domain.conf
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

  ln -sf /etc/nginx/sites-available/$domain.conf /etc/nginx/sites-enabled/$domain.conf
  nginx -t
  systemctl reload nginx
  systemctl enable nginx --now
}
# ==== Apache ====
apache_conf() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    apache_confi=/etc/apache2/sites-available/$domain.conf
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    apache_confi=/etc/httpd/conf.d/$domain.conf
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

    ErrorLog \${APACHE_LOG_DIR}/$domain-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain-access.log combined
</VirtualHost>
EOF
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
    systemctl reload apache2
    systemctl enable apache2 --now
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
      systemctl enable httpd --now
  fi
}
# ==== Intro Message ====
start_screen() {
  clear
  header_notice "$wp_title" "${wp_banner:-}" "188" "40"
  printf "${blue}%s${reset}\n" " " \
    "┌───────────────────────────────────────────────────────────────────────────────────┐" \
    "│${yellow}              ONE-CLICK WORDPRESS INSTALLER                                        ${blue}│" \
    "├───────────────────────────────────────────────────────────────────────────────────┤" \
    "│                                                                                   │" \
    "│${yellow}${ul}Overview:${ul_reset}${blue}                                                                          │" \
    "│  This tool will install a fully functional WordPress site with:                   │" \
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
    "│                                                                                   │" \
    "│${yellow}Press ENTER to continue when ready...${blue}                                              │" \
    "└───────────────────────────────────────────────────────────────────────────────────┘${reset}"
  return 0
}
# ==== LetsEncrypt ====
install_letsencrypt() {
  if [[ -z "${domain:-}" ]]; then
    start_screen
    while true; do
      read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to issue SSL for: " domain
      [[ -n "$domain" ]] && break
      if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Invalid domain name"
      fi
    done
    site="/etc/one-click/wordpress/www/$domain"
    wp_cmd="sudo -u www-data /usr/local/bin/wp --path=$site"
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
      read -rp "${cyan}[USER]${reset} Please provide an email address for LetsWncrypt: " email
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
      $wp_cmd option update home "https://$domain" 
      $wp_cmd option update siteurl "https://$domain" 
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
            read -rp "Enter new email: " email
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
  start_screen
  while true; do
    read -rp "${cyan}[USER]${reset} Please provide the domain name you would like to use for this installation: " domain
    if ! [[ "$domain" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
      echo "Invalid domain name"
    fi
    [[ -n "$domain" ]] && break
    echo "Domain cannot be empty!"
  done
  site="/etc/one-click/wordpress/www/$domain"
  wp_cmd="sudo -u www-data wp --path=$site"
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
    read -rsp "Confirm Password: " pass_confirm
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
    read -rsp "Confirm Password: " pass_confirm
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
    1) webserver="nginx" ;;
    2) webserver="apache" ;;
    *) echo "Invalid selection"; exit 1 ;;
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
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-zip \
    unzip \
    curl
  fi
  install_wp_cli
  install_webserver
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
  install_letsencrypt
  wp_backup_scheduler
  success "One-Click WOrdpress has now been installed!"
  info "Access the site from $domain"
  info "Access WP Admin page via $domain/wp-admin"
}
