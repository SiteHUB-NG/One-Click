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
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== One-Click Migrator ====
kernel_version="$(uname -r)"
int=$(basename $(ls -1 /etc/wireguard/*.conf))
int="${int/.*}"
wg_file=($(ls -1 /etc/wireguard/*.conf))
install_dependencies() {
  local needed=(cpio gzip busybox dropbear)
  local missing=()
  for cmd in "${needed[@]}"; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if (( ${#missing[@]} == 0 )); then
    warn "${yellow}[+]${reset} All dependencies already installed"
    return 0
  fi
  echo "[!] Missing: ${missing[*]}"
  # ==== Detect package manager ====`
  local pm=""
  if command -v apt-get &>/dev/null; then
    pm="apt"
  elif command -v dnf &>/dev/null; then
    pm="dnf"
  elif command -v yum &>/dev/null; then
    pm="yum"
  elif command -v apk &>/dev/null; then
    pm="apk"
  elif command -v pacman &>/dev/null; then
    pm="pacman"
  else
    error "No supported package manager found" >&2
    return 1
  fi
  info "${blue}[+]${reset} Using package manager: $pm"
  # ==== Install missing packages ====
  case "$pm" in
    apt)
      info "${blue}[+]${reset} Installing ${missing[*]} with apt-get"
      apt-get update -qq || { echo "[ERROR] apt-get update failed"; return 1; }
      DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" \
        || { echo "[ERROR] apt-get install failed"; return 1; }
      ;;
    dnf)
      dnf -y install "${missing[@]}" || { echo "[ERROR] dnf install failed"; return 1; }
      ;;
    yum)
      yum -y install "${missing[@]}" || { echo "[ERROR] yum install failed"; return 1; }
      ;;
    apk)
      apk add --no-cache "${missing[@]}" || { echo "[ERROR] apk add failed"; return 1; }
      ;;
    pacman)
      pacman -Sy --noconfirm "${missing[@]}" || { echo "[ERROR] pacman install failed"; return 1; }
      ;;
  esac
  # ==== Confirm installation ====
  local failed=()
  for cmd in "${needed[@]}"; do
    command -v "$cmd" &>/dev/null || failed+=("$cmd")
  done
  if (( ${#failed[@]} > 0 )); then
    error "Could not install: ${failed[*]}" >&2
    return 1
  fi
  success "${green}[✓]${reset} Dependencies installed successfully"
}
before_migration() {
  recovery_dir="/boot/recovery"
  rm -rf "$recovery_dir"
  mkdir -p "$recovery_dir/"{bin,sbin,etc,proc,sys,dev,run,root,lib,lib64}
  vmlinuz="$recovery_dir/vmlinuz-$(uname -r)"
  initrd="$recovery_dir/initrd-$(uname -r).img"
  # ==== Copy kernel ====
  success "${green}[+]${reset} Copying kernel"
  cp -f /boot/vmlinuz-$(uname -r) "$vmlinuz"
  install_dependencies
  # ==== Build Initramfs tree ====
  warn "${yellow}[+]${reset} Building recovery initramfs tree"
  box="$(which busybox)"
  cp -f "$box" "$recovery_dir/bin/"
  copy_libs() {
    local bin="$1"
    ldd "$bin" | awk '{print $3}' | grep -E '^/' | while read -r lib; do
      mkdir -p "$recovery_dir$(dirname "$lib")"
      cp -f "$lib" "${recovery_dir}${lib}"
    done
  }
  copy_libs "$box"
  for cmd in sh ip mount umount ls mkdir cp echo cat dd blkid udhcpc; do
    ln -s busybox "$recovery_dir/bin/$cmd"
  done
  cp -a /lib/modules/$(uname -r) "$recovery_dir/lib/modules/"
  mkdir -p "$recovery_dir/dev"
  mknod -m 622 "$recovery_dir/dev/console" c 5 1
  mknod -m 666 "$recovery_dir/dev/null" c 1 3
  mknod -m 666 "$recovery_dir/dev/tty0" c 4 0
  cat > "$recovery_dir/etc/net.conf" <<'EOF'
nic="$nic"
destination_server="${destination_server:-}"
mask="$mask"
destination_gw="${destination_gw:-}"
EOF
  # ==== Init script ====
  mkdir -p "$recovery_dir/lib/modules/$kernel_version"
  cp -f /sbin/modprobe "$recovery_dir/sbin/"
  copy_libs /sbin/modprobe
  cp -f /lib/modules/$(uname -r)/modules.* "$recovery_dir/lib/modules/$(uname -r)/"
  cat > "$recovery_dir/init" <<'EOF'
#!/bin/sh
# Mount pseudo-filesystems
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmpfs /run
# Load modules
for mod in $(ls /lib/modules/$(uname -r)/kernel/drivers/net/ | sed 's/.ko$//'); do
    modprobe $mod 2>/dev/null || true
done
# Configure network
. /etc/net.conf
ip link set lo up
if [ -n "${destination_server:-}" ]; then
    ip addr add "${destination_server:-}/${mask}" dev "$nic"
    ip link set "$nic" up
    ip route add default via "${destination_gw:-}"
else
    for i in $(ls /sys/class/net | grep -v lo); do
        ip link set "$i" up
        udhcpc -i "$i" &
    done
fi
sleep 1
if [ -x /sbin/dropbear ]; then
    dropbear -R -E &
fi
# ==== Mount target root if available ====
if [ -b /dev/sda1 ]; then
    mkdir -p /mnt
    mount /dev/sda1 /mnt
fi
# ==== Auto-repair ====
if [ -x /sbin/auto-repair.sh ]; then
    /sbin/auto-repair.sh
fi
# Fallback shell
exec /bin/sh
EOF
  chmod +x "$recovery_dir/init"
  # ==== Build initrd image ====
  warn "${yellow}[+]${reset} Creating initramfs image"
  (
    cd "$recovery_dir"
    find . | cpio -H newc -o
  ) | gzip > "$initrd"
  # ==== GRUB Entry ====
  warn "${yellow}[+]${reset} Installing GRUB recovery entry"
  cat >> /boot/grub/custom.cfg <<EOF
menuentry "Recovery Environment (SSH)" {
    search --file --no-floppy --set=root /boot/recovery/vmlinuz-${kernel_version}
    set prefix=(\$root)/boot/grub
    insmod linux
    insmod ext4
    insmod search_fs_file
    insmod search_fs_uuid
    linux /boot/recovery/vmlinuz-${kernel_version} root=/dev/ram0 rw rdinit=/init
    initrd /boot/recovery/initrd-${kernel_version}.img
}
EOF

  sed -Ei.one-click-backup '
    s/(GRUB_DEFAULT=)"?[^"]*"?/\1"Recovery Environment (SSH)"/
    s/(GRUB_TIMEOUT=)"?[^"]*"?/\15/
  ' /etc/default/grub
  update-grub
  success "${green}[✓]${reset} Recovery environment prepared successfully"
  warn "Now ready to perform DD migration. The system can auto-boot into recovery after migration."
}
after_migration() {
  rm -f /etc/default/grub
  rm -f /etc/default/custom.cfg
  mv /etc/default/grub.one-click-backup /etc/default/grub
  update-grub
  rm -rf /boot/recovery
}
migration() {
  header_notice "$raw_title" "$wizard" "5" "6"
  # ==== User Selection: DD or Rsync? ====
  choose_migration_type() {
    printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
      "[1]. Migrate with dd (raw block level)" \
      "[2]. Migrate with rsync (recommended)"
    read -rp "${cyan}[USER]${reset} Please select the type of migration you would like to proceed with: " migration_type
  }
  if [[ ! "${migration_type:-}" == [0-9] ]]; then
    warn "Please input only an integer"
    choose_migration_type
  fi
  if [[ "${migration_type:-}" -eq 1 ]]; then
    dd_migrate
  elif [[ "${migration_type:-}" -eq 2 ]]; then
    rsync_migrate
  fi
}
# ==== Use Rsync as the migration tool ====
rsync_migrate() {
  local exclude_dirs running_services exclude_services dirs_to_migrate
  exclude_dirs=(
    "/dev/"
    "/proc/"
    "/sys/"
    "/tmp/"
    "/run/"
    "/mnt/"
    "/media/"
    "/boot/"
    "/lost\+found"
  )
  running_services=(
    $(awk '$1~/.*\.service/{print $1}' <(systemctl list-units --type=service --state=running) > /root/rsync-services-running.txt)
  )
  exclude_services=(
    "avahi-daemon"
    "accounts-daemon"
    "bluetooth"
    "cron"
    "polkit"
    "power-profiles-daemon"
    "rtkit-daemon"
    "ssh"
    "sshd"
    "systemd"
    "systemd-logind"
    "systemd-udevd"
    "systemd-journald"
    "systemd-timesyncd"
    "systemd-udevd"
    "network"
    "NetworkManager"
    "user*"
  )
  dirs_to_migrate=(
    $(ls -1 / > all_dirs.txt; for i in "${exclude_dirs[@]}"; do sed -Ei "\,${i//\/},d" all_dirs.txt; done; cat all_dirs.txt)
  )
  # ==== Exclude Services ====
  cat << 'EOF' > /root/rsync-services-exclude.txt
avahi-daemon
accounts-daemon
bluetooth
ssh
sshd
systemd
systemd-logind
systemd-udevd
systemd-journald
systemd-timesyncd
systemd-udevd
network
NetworkManager
user
EOF
  # ==== Exclude Files ====
  cat << 'EOF' > /root/rsync-etc-exclude.txt
# DO NOT MIGRATE FILES IN /etc
/etc/network/*
/etc/NetworkManager/*
/etc/netplan/*
/etc/sysconfig/network*
/etc/sysconfig/network-scripts/*
/etc/resolv.conf
/etc/ssh/*
/etc/hosts
/etc/machine-id
/etc/localtime
/etc/mtab
/etc/adjtime
/etc/modprobe.d/
/etc/modules-load.d/
/etc/dracut.conf.d/
/etc/chrony.conf
/etc/ntp.conf
/etc/systemd/
/etc/udev/*
#/etc/passwd
#/etc/shadow
#/etc/group
#/etc/gshadow
#/etc/pam.d/
/var/lib/dbus/machine-id
/proc/*
/tmp/*
/sys/*
/dev/*
/mnt/*
/boot/*
/boot/grub/*
/etc/default/*
/run/*
/var/run/*
/var/lock/*
/media/*
/lost+found
/var/lib/rpm/*
/var/lib/yum/*
/var/lib/dbus
/lib/modules/*
/lib/firmware/*
/lib64/modules/*
/lib64/firmware/*
/sys/class/dmi/id/product_uuid
/swapfile
EOF
  # ==== Create backups of files that will be excluded but may be needed later ====
  cp /etc/fstab /etc/fstab.migrator-backup
  cp /etc/resolv.conf /etc/resolve.migrator-backup
  cp /etc/hosts /etc/hosts.migrator-backup
  # ==== Notice Main ====
  info "This tool will securely migrate your data from the current system to the new environment. It will clone as much of it as possible including PAM." \
    "The process is designed to be safe, verifiable, and minimally disruptive (to the local device)." \
    " " \
    "Data will be transferred securely over encrypted channels" 
  warn "This is none destructive for the local server. However, it is 100% ${red}DESTRUCTIVE${reset} on the ${ul}remote server${ul_reset}!" 
  info "This is a migration tool. Plan adequately."
  echo
  # ==== Gather Pre-req info ====
  read -rp "${cyan}[USER]${reset} Please enter the username of the destination server: " user
  if [[ "$user" == "root" ]]; then
    user_dir="/root"
  else
    user_dir="/home/${user}"
  fi
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
  # ==== Require Valid IPv4 ====
  v4() {
    read -rp "${cyan}[USER]${reset} Please enter the IP of the destination server: " destination_server
    if ! is_ipv4 "$destination_server"; then
      echo "The IP is ${red}INVALID${reset}! Please try again."
      v4
    fi
  }
  # ==== Check if rsync is available on remote server and install if not ====
  info "Checking SSH credentials are valid"
  check_rsync() {
    for id in "${ids[@]}"; do
      if [[ "$id" == "debian" || "$ID" == "debian" ]]; then
        if ! sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "if ! type rsync &> /dev/null; then apt -y install rsync; fi" &> /dev/null; then
          error "Rsync failed — possible SSH timeout or connection error" 
          return 1
        else
          echo
          success "${green}SSH credentials are valid${reset}" 
        fi
      elif [[ "$id" == "rhel" ]]; then
        if [[ ! -s "$key" ]]; then
          if ! sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "if ! type rsync &> /dev/null; then dnf -y install rsync; fi" &> /dev/null; then
            error " " "Rsync failed — possible SSH timeout or connection error"
            return 1
          else
            success "${green}SSH credentials are valid${reset}"
          fi
        else
          if ! ssh -i "$key" -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "if ! type rsync &> /dev/null; then dnf -y install rsync; fi" &> /dev/null; then
            error " " "Rsync failed — possible SSH timeout or connection error"
            return 1
          else
            success "${green}SSH credentials are valid${reset}"
          fi
        fi
      fi
    done
  }
  run_migrate_rsync
}
# ==== Does the user want to use ssh-keys? ====
ssh_key() {
  read -rp "${cyan}[USER]${reset} Would you like to configure a SSH key? " key_request
  key_request=${key_request,,}
  if [[ "$key_request" == "yes" || "$key_request" == "y" ]]; then
    read -rp "${cyan}[USER]${reset} Please enter your ssh key path: " key
    [[ -s "$key" ]] || {
      warn "SSH Key not found" && ssh_key
    }
    req=y
  else
    req=n
    warn "ssh key will not be used."
  fi
}
# ==== Set Password ====
set_pass() {
  info "Please enter [password|pass] or [key|ssh|ssh_key]: "
  read -rp "${cyan}[USER]${reset} Would you like to use a password or SSH key: " req
  req="${req,,}"
  case "$req" in
    password|pass)
      req=n
      read -s -rp "${cyan}[USER]${reset} Enter your SSH password for ${user}@${destination_server}: " pass
      echo
      read -s -rp "${cyan}[USER]${reset} Please re-enter your password: " pass2
      echo
      # ==== Ensure password was entered accurately ====
      while [[ ! "$pass" == "$pass2" ]]; do
        warn "${red}Passwords do not match${reset}" "${green}Please try again${reset}"
        set_pass
      done
      ;;
    key|ssh|ssh_key)
      req=y
      ssh_key
      ;;
    *) die "Invalid selection!" ;;
  esac
  return 0
}
# ==== Rsync Migration Script ====
run_migrate_rsync() {
  v4
  ssh-keygen -f '/root/.ssh/known_hosts' -R "$destination_server"
  set_pass
  check_rsync
  info "The following directories and all content will be included in the migration: "
  for dir in "${dirs_to_migrate[@]}"; do
    sleep 0.5
     printf '%s\n' "$dir"
  done
  echo
  for ((i=seq;i<((seq+22));i++));do
    printf '%s' "$(tput setaf $i)$(tput setab $i).${reset}"; sleep 0.3;
  done
  echo
  add_exclude=()
  read -rp "${cyan}[USER]${reset} If you would like to exclude any of these directories, please enter them seperated by a space: " add_exclude
  add_exclude=($(echo "$add_exclude"))
  for exclude in "${add_exclude[@]}"; do
    dirs_to_migrate=($(printf '%s\n' "${dirs_to_migrate[@]}" | sed "/$exclude/d"))
  done
  # ==== Known DBs to check for ====
  db_migration() {
    dbs=(
      "mysql"
      "mariadb"
      "postgresql"
      "redis"
      "mongod"
      "redis-server"
      "elasticsearch"
    )
    # ==== Check if DB services are active ====
    active_dbs=()
    for db in "${dbs[@]}"; do
      if systemctl list-units --type=service --state=running | grep -q "${db}.*\.service"; then
        active_dbs+=("$db")
      fi
    done
    if pgrep -f "sqlite3" &> /dev/null; then
      active_dbs+=("sqlite (process-based)")
    fi
    if [[ "${#active_dbs[@]}" -eq 0 ]]; then
      warn "No active databases were found running!" "Backing up for DBS will be skipped on this run..."
    else
      warn "The following database services were found running on this system: "
      i=1
      echo
      for db in "${active_dbs[@]}"; do
        echo "${i}: $db"
        ((i++))
      done
      echo
      i=0
      letters=( B C D E F G H I J K L M N O P Q R S T U V W X Y Z )
      printf '%s\n' "${ul}${yellow}Migration Options:${reset}${ul_reset}" \
      "          ${red}[A]${reset}. Migrate All Databases"
      if [[ "${#active_dbs}" -eq 1 ]]; then
        echo "          ${red}[B]${reset}. Migrate $db"
      else
        for db in "${active_dbs[@]}"; do
          echo "          ${red}[${letters[$i]]}]${reset}. Migrate $db"
          ((i++))
        done
      fi
      printf '%s\n' " " "Please select the database option to use for migration." \
      "You can select multiple options by seperating them with a comma"
      mig() {
        read -rp "${cyan}[USER]${reset} Please note opting not to stop the database may cause unexpected behaviour: " migrate_db
        migrate_db="${migrate_db,,}"
        echo
      }
      mig
      backup_database() {
        local db="${1:-}"
        local date_str
        date_str=$(date +'%F')

        case "$db" in
          mariadb|mysql)
            mkdir -p "${backup_dir}/mysql"
            mysqldump --all-databases --single-transaction --flush-logs | gzip > "${backup_dir}/mysql/mysql-migrator-${date_str}.sql.gz"
            ;;
          postgresql)
            mkdir -p "${backup_dir}/postgres"
            sudo -u postgres pg_dumpall | gzip > "${backup_dir}/postgres/postgres-migrator-${date_str}.sql.gz"
            ;;
          mongodb)
            mkdir -p "${backup_dir}/mongo"
            mongodump --archive="${backup_dir}/mongo/mongo-migrator-${date_str}.archive" --gzip
            ;;
          sqlite)
            mkdir -p "${backup_dir}/sqlite"
            find / -name "*.db" 2>/dev/null | while read -r sq; do
              sqlite3 "$sq" ".backup '${backup_dir}/sqlite/$(basename "$sq")-migrator-${date_str}.db'"
            done
            ;;
          redis)
            mkdir -p "${backup_dir}/redis"
            echo "Redis will now be stopped to backup consistently"
            stop_service redis-server
            cp /var/lib/redis/dump.rdb "${backup_dir}/redis/redis-migrator-${date_str}.rdb"
            start_service redis-server
            ;;
          *)
            error "There has been an issue backing up the database." \
            "Please try again or carry out manually"
            return 1
            ;;
        esac
      }
      if [[ "$migrate_db" == "a" ]]; then
        printf '%s\n' "Preparing your DB backup." \
        "All databases will be live migrated (except Redis)." \
        "There will be no downtime for this!"
        read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed? " db_proceed
        db_proceed=$(echo "$db_proceed" | tr '[:upper:]' '[:lower:]')
        if [[ "$db_proceed" == "y" || "$db_proceed" == "yes" ]]; then
          for db in "${active_dbs[@]}"; do
            db_name="${db%% *}"
            backup_database "$db_name"
          done
        fi
      elif [[ "$migrate_db" =~ ^[0-9]+$ ]]; then
        db_name="${db[$migrate_db]}"
        backup_database "$db_name"
      else
        warn "Your response must be an integer or a lettered option" \
                     "Please try again."
        sleep 0.3
        mig
      fi
      return 0
    fi
  }
  #dmc="$?"
  # ==== Now the heavy lifting! ====
  dir_migration() {
    echo
    # ==== Prompt user for dry run or actual migration ====
    while true; do
      info '%s\n' "The rsync migration is just about ready to begin." \
        "To protect the migration process from unexpected disconnections, this session is run inside of it's own ${cyan}tmux${reset} window." \
        "You can detach from the session at any time with ${cyan}Ctrl+b${reset} then ${cyan}d${reset} and the process will continue in the background" \
        "Should you need to reattach, please ensure you are the root user (or use sudo) and use the following command ${cyan}tmux reattach${reset} if the single session is running or ${cyan}tmux reattach -t 'one-click'${reset}" \
        " " 
        warn "Before proceeding, please confirm you are happy to proceed or try a dry run first." 
      info  " " 
      printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
        "${ul}Options:${ul_reset}" \
        "[1]. Dry-Run Migration" \
        "[2]. Proceed with migration" \
        "[3]. Go Back"
      read -rp "${cyan}[USER]${reset} Please select option 1,2 or 3: " dry_run
      [[ "$dry_run" =~ ^[123]$ ]] && break
      warn "Invalid option. Please select 1,2 or 3 ONLY!"
    done
    # ==== Build rsync flags ====
    rsync_opts=(
      -aHAXxP
      --numeric-ids
      --partial
      --inplace
      --stats
      --human-readable
      --info=progress2
      --exclude-from=/root/rsync-etc-exclude.txt
      -e "ssh -o StrictHostKeyChecking=no"
    )
    # ==== Go Back ====
    [[ "$dry_run" -eq 3 ]] && migration
    # ==== Add --dry-run flag if user opted for dry run ====
    [[ "$dry_run" -eq 1 ]] && rsync_opts+=(--dry-run)
    # ==== Migrate directories ====
    for migrate in "${dirs_to_migrate[@]}"; do
      if [[ -d "/$migrate" ]]; then
        directory=Directory
      elif [[ -f "/$migrate" ]]; then
        directory=File
      fi
      info '%s\n' "${grey}${directory:-} ${cyan}${migrate}${grey} is now being migrated${reset}"
      rsync_cmd_run=(
        sshpass -p "$pass" rsync --relative "${rsync_opts[@]}" "/${migrate}" "${user}@${destination_server}:/"
      )
      rsycn_cmd_run1=(
        rsync --relative "${rsync_opts[@]} -e ssh -i "$key"" "/${migrate}" "${user}@${destination_server}:/"
      )
      if [[ ! -s "$key" ]]; then
        wait_for_network
        create_service "${rsync_cmd_run[*]}" "Remote Backup Restore"
        if "${rsync_cmd_run[@]}"; then
          remove_service
        else
          die "restore failed"
        fi
        ec="$?"
      else
        wait_for_network
        create_service "${rsync_cmd_run1[*]}" "Remote Backup Restore"
        if "${rsync_cmd_run1[@]}"; then
          remove_service
        else
          die "restore failed"
        fi
      fi
      if [[ $ec -ne 0 ]]; then
          echo
          printf '%s\n' "${red}Migration of ${cyan}${migrate}${red} failed during this run.${reset}"
          [[ "$dry_run" -eq 1 ]] && exit 1
      fi
    done
    if [[ "$dry_run" -eq 1 ]]; then
      echo
      success "${green}Dry run successful${grey}. You can now confidently proceed with the real migration.${reset}" \
        " "
      dir_migration
    else
      success " " \
        "${green}Entering the final phase${grey}. Please be patient. This may take a while...${reset}" \
        " "
    fi
  }
  # ==== Carry out remote actions to complete rsync migration ====
  complete_migration() {
    complete_migration_banner
    sensitive_files=(/etc/group /etc/gshadow /etc/shadow /etc/passwd)
    if [[ ! -s "$key" ]]; then
      sshpass -p "$pass" scp /root/rsync-services-running.txt "${user}@${destination_server}":/root/rsync-services-running.txt
      sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
        "while read -r line; do systemctl restart \"\$line\"; done < /root/rsync-services-running.txt"
    else
      scp -i "$key" /root/rsync-services-running.txt "${user}@${destination_server}":/root/rsync-services-running.txt
      ssh -i "$key" -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
        "while read -r line; do systemctl restart \"\$line\"; done < /root/rsync-services-running.txt"
    fi
    info "${grey}Now carrying out the final phase of the migration." \
      "${red}Writing fragile and sensitive files. SSH may disconnect." \
      "${warning}Manual migration may be required for incomplete files." \
      "${grey}Your remote server password will become the password here." \
      "Ensure it matches before proceeding.${reset}"
    final_phase() {
      local sensitive_dir
      sensitive_dir="${1:-}"
      info "${grey}Final phase migration!! ${red}${sensitive_dir}${grey} is now being written to the remote server.${reset}"
      return 0
    }
    for sensitive in "${sensitive_files[@]}"; do
      info "${grey}Final phase migration!! ${red}${sensitive}${grey} is now being written to the remote server.${reset}"
      final_phase "$sensitive"
      rsync_cmd_run=(
        sshpass -p "$pass" rsync "${rsync_opts[@]}" "/$sensitive" "${user}@${destination_server}:/etc-temp/"
      )
      rsync_cmd_run1=(
        rsync "${rsync_opts[@]} -e ssh -i $key" "/$sensitive" "${user}@${destination_server}:/etc-temp/"
      )
      if [[ ! -s "$key" ]]; then
        wait_for_network
        create_service "${rsync_cmd_run[*]}" "Sensitive Files"
        if "${rsync_cmd_run[@]}"; then
          remove_service
        else
          die "restore failed"
        fi
      else
        wait_for_network
        create_service "${rsync_cmd_run1[*]}" "Sensitive Files"
        if "${rsync_cmd_run1[@]}"; then
          remove_service
        else
          die "restore failed"
        fi
      fi
    done
    echo
    sleep 0.5
    fp_rsync_cmd_run_pam=(
      sshpass -p "$pass" rsync -av --delete /etc/pam.d/ "${user}@${destination_server}":/etc/pam.d/
    )
    fp_rsync_cmd_run_ssh=(
      sshpass -p "$pass" rsync -av --delete /etc/ssh/ "${user}@${destination_server}":/etc/ssh/
    )
    if [[ ! -s "$key" ]]; then
      final_phase "/etc/pam.d/*"
      wait_for_network
      create_service "${fp_rsync_cmd_run_pam[*]}" "Final Phase PAM"
      if "${fp_rsync_cmd_run_pam[@]}"; then
        remove_service
      else
        die "restore failed"
      fi
      final_phase "/etc/ssh/*"
      wait_for_network
      create_service "${fp_rsync_cmd_run_ssh[*]}" "Final Phase SSH"
      if "${fp_rsync_cmd_run_ssh[@]}"; then
        remove_service
      else
        die "restore failed"
      fi
      info '%s\n' " " \
        "${yellow}Finalizing!" \
        "${grey}Remote server will be rebooted shortly...${reset}" " "
      sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
      "nohup sh -c '
        mv -f /etc-temp/group /etc/ &&
        mv -f /etc-temp/gshadow /etc/ &&
        mv -f /etc-temp/shadow /etc/ &&
        mv -f /etc-temp/passwd /etc/ &&
        rmdir /etc-temp &&
        reboot -f
      ' >/dev/null 2>&1 &"
    else
      wait_for_network
      create_service "${fp_rsync_cmd_run_pam[*]}" "Final Phase PAM"
      if "${fp_rsync_cmd_run_pam[@]}"; then
        remove_service
      else
        die "restore failed"
      fi
      final_phase "/etc/ssh/*"
      wait_for_network
      create_service "${fp_rsync_cmd_run_ssh[*]}" "Final Phase SSH"
      if "${fp_rsync_cmd_run_ssh[@]}"; then
        remove_service
      else
        die "restore failed"
      fi
      info '%s\n' " " \
        "${yellow}Finalizing!" \
        "${grey}Remote server will be rebooted shortly...${reset}" " "
      ssh -i "$key" -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
      "nohup sh -c '
        mv -f /etc-temp/group /etc/ &&
        mv -f /etc-temp/gshadow /etc/ &&
        mv -f /etc-temp/shadow /etc/ &&
        mv -f /etc-temp/passwd /etc/ &&
        rmdir /etc-temp &&
        reboot -f
      ' >/dev/null 2>&1 &"
    fi
    printf '%s\n' \
      " $(tput setaf 10)\"=================================================\"${reset}" \
      "$banner" \
      " $(tput setaf 10)\"=================================================\"${reset}" " " \
      "${green}This server has now been migrated to $destination_server" \
      " ${reset}" \
      "${red}PLEASE NOTE${grey}: The remote server ${cyan}${destination_server}${grey} is now a mirror of this server" \
      "Certain files and directories will remain on the destination server to preserve functionality, however, for the most part, your new server will behave exactly the same.${reset}"
  }
  # ==== Keep track of running services ====
  track_restart_services() {
    warn "Remote services will now be restarted and systemd reloaded"
    #  ==== Prepare the services file ====
    while read -r line; do
      sed -Ei "/$line/d" /root/rsync-services-running.txt
    done < <(printf '%s\n' "${exclude_services[@]}")
    # ==== Reload systemd daemon
    info "Reloading systemd on the remote server"
    if ! sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "systemctl daemon-reload"; then
      error "${red}Systemd failed to reload${reset}"
    else
      success "Systemd ${green}successfully${reset} reloaded"
    fi
    # ==== Restart services on remote server
    while read -r line; do
      echo "Restarting $line on the remote server"
      if [[ ! -s "$key" ]]; then
        if ! sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "systemctl restart $line"; then
          error "${red}$line failed to restart${reset}"
        else
          success "$line ${green}successfully${reset} restarted"
        fi
      else
        if ! ssh -i "$key" -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "systemctl restart $line"; then
          error "${red}$line failed to restart${reset}"
        else
          success "$line ${green}successfully${reset} restarted"
        fi
      fi
    done < /root/rsync-services-running.txt
    echo "All services have no been restarted on the remote server"
  }
  before_migration
  db_migration
  dir_migration
  track_restart_services
  complete_migration
  after_migration
}
# ==== Use DD as the backup/migration tool ====
dd_migrate() {
  # ==== Notice Main ====
  info "This is a raw block-level migration (entire disk, bootloader, partitions, filesystem)." \
    "${red}ALL DATA ON THE DESTINATION WILL BE DESTROYED.${reset}" \
    " " "Please prepare the destination server with a similar (or the same) OS as this: $PRETTY_NAME although cross OS migration should generally work." \
    " " "This script must be run on the source first and then the destination after" \
    " " "It is advised to stop services before running this tool." \
    "While it can be used on a live server, there may be data inconsistency, or corruption in the data sent over." \
    "There is no external storage requirement nor will this tool affect your live working environment"
  echo
  printf '%s' "${cyan}[USER]${reset} [Scanning Drives]: "; for ((i=seq;i<((seq+22));i++));do printf '%s' "$(tput setaf $i)$(tput setab $i).${reset}"; sleep 0.3; done; echo -e '\n'
  # ==== Gather Pre-req info ====
  read -rp "${cyan}[USER]${reset} Please enter the username of the destination server:                                   " user
  if [[ "$user" == "root" ]]; then
    user_dir="/root"
  else
    user_dir="/home/${user}"
  fi
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
  # ==== IPv6 Validator ====
  is_ipv6() {
    local ip=$1
    if ip -6 addr add "$ip/128" dev lo 2>/dev/null; then
      ip -6 addr del "$ip/128" dev lo 2>/dev/null
      return 0
    else
      return 1
    fi
  }
  # ==== Require Valid IPv4 ====
  v4() {
    read -rp "${cyan}[USER]${reset} Please enter the IP of the destination server:                                         " destination_server
    if ! is_ipv4 "$destination_server"; then
      error "The IP is ${red}INVALID$${reset}! Please try again."
      v4
    fi
  }
  # ==== Require Valid IPv6 ====
  v6(){
    read -rp "${cyan}[USER]${reset} Please enter the IPv6 address of the destination server $destination_server (Optional):       " destination_v6
    if is_ipv6 "$destination_v6"; then
      error "The IP is ${red}INVALID${reset}! Please try again."
      v6
    fi
    if [[ ! "$destination_v6" == "" ]]; then
      read -rp "${cyan}[USER]${reset} Please enter the IPv6 gateway address for ${destination_v6}:                           " remote_v6_gw
      if [[ "${remote_v6_gw:-}" == "" ]]; then
        warn "The gateway IPv6 is required. Please try again."
        v6
      fi
    fi
  }
  # ==== Ensure GW is present ====
  v4_gw() {
    read -rp "${cyan}[USER]${reset} Please enter the IPv4 gateway address for ${destination_server}:                                " destination_gw
    if [[ "$destination_gw" == "" ]]; then
      warn "The gateway IP is required. Please try again."
      v4_gw
    fi
  }
  v_run() {
    v4
    v4_gw
  }
  v_check() {
    if [[ "$destination_server" == "$destination_gw" ]]; then
      warn '%s\n' "The remote IP and gateway are this same!" "Please double check the values and try again"
      sleep 2
      v_run
    fi
  }
  run_migrate
}
# ==== DD Migration Script ====
run_migrate() {
  v_run
  destination_server=${destination_server:-}
  banner_len="${#destination_server}"
  ssh-keygen -f '/root/.ssh/known_hosts' -R "${destination_server:-}" &> /dev/null
  v_check
  v6
  set_pass
  # ==== After Migration Network Repair ====
  cat << EOF > "$net_repair"
[Unit]
Description=After Migration Network Repair
After=network-pre.target
Wants=network-pre.target
ConditionPathExists="$net_config"

[Service]
Type=oneshot
ExecStart="$net_config"
RemainAfterExit=yes
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF
  if [[ -f "$net_config" ]]; then
    rm -f "$net_config"
  fi
  cat << EOF > "$net_config"
ids=(${ids[@]})
for id in ${ids[@]} ; do
  case \${id:-} in
    debian|ubuntu)
      [[ -f /etc/network/interfaces ]] && cp /etc/network/interfaces /etc/network/interfaces.bak
      sed -Ei.one-click-backup "
        s/$sys_gw/$destination_gw/;
        s/$ipv6_gw/${remote_v6_gw:-}/g;
        s/$sys_ip/$destination_server/g; 
        s,${sys_ipv6/:1},${destination_v6/:1},g; 
        s/$ipv6_gw/${remote_v6_gw:-}/g;
        /${nic:-}/,/inet6/ {
          /gateway/! {
            /netmask/ {
              p;
              s/^([\t ]+).*/\1gateway ${destination_gw:-}/;
            }
          }
        }
        /inet6/,$ {
          /gateway/! {
            /netmask/ {
              p;
              s/^([\t ]+).*/\1gateway ${destination_v6_gw:-}/;
            }
          }
        }
      " /etc/network/interfaces
      if [[ -d /etc/wireguard/ ]]; then
        wg-quick down "$int"
        sed -Ei.one-click-backup "
          /ip -6/ ! {
            s/$sys_ip/$destination_server/g; 
            s/$sys_gw/$destination_gw/g; 
            s,${sys_ipv6/:1},${destination_v6/:1},g; 
            s/$ipv6_gw/${remote_v6_gw:-}/g;
            s/^.*200 default via $destination_gw/#&/;
            /ip -6/ {
              /${sys_ip}|${destination_server}/d
            }
          }
        " $wg_file
        wg-quick up "$int"
      fi
      sed -i.one-click-backup "s/eth0/$nic/g" /etc/network/interfaces
      ip addr flush dev "$nic" || true
      ifdown "$nic" &> /dev/null || true
      ifup "$nic" &> /dev/null || true
      ;;
    rhel|centos|rocky|almalinux|fedora)
      local nmcli_status
      # ==== Try NetworkManager ====
      if command -v nmcli &> /dev/null; then
        iface_file="/etc/NetworkManager/system-connections/$nic.nmconnection"
        [[ -f /etc/NetworkManager/system-connections/$nic.nmconnection ]] && cp /etc/NetworkManager/system-connections/$nic.nmconnection /etc/NetworkManager/system-connections/$nic.nmconnection.bak
        sed -Ei.one-click-backup "
          s/$sys_ip/$destination_server/g;
          s/$sys_gw/$destination_gw/g;
          s,${sys_ipv6/:1},${destination_v6/:1},g;
          s/$ipv6_gw/${remote_v6_gw:-}/g
        " /etc/NetworkManager/system-connections/$nic.nmconnection
        if [[ -f /etc/wireguard/wg0.conf ]]; then
          wg-quick down "$int"
          sed -Ei.one-click-backup "
            /ip -6/ ! {
              s/$sys_ip/$destination_server/g;
              s/$sys_gw/$destination_gw/g;
              s/${sys_ipv6/:1}/${destination_v6/:1}/g;
              s/$ipv6_gw/${remote_v6_gw:-}/g;
              s/200 default via $destination_gw/#&/;
              /ip -6/ {
                /${sys_ip}|${destination_server}/d
              }
            }
          " $wg_file
          wg-quick up "$int"
        fi
        sed -i.one-click-backup "s/eth0/$nic/g" /etc/NetworkManager/system-connections/$nic.nmconnection
        nmcli device set "$nic" managed yes
        nmcli connection reload
        nmcli device disconnect $nic
        nmcli device connect $nic
        systemctl restart network || systemctl restart NetworkManager
      else
        #  ==== Check which network file exists ====
        local iface_file
        iface_file="/etc/sysconfig/network-scripts/ifcfg-$nic"
        [[ -f /etc/sysconfig/network-scripts/ifcfg-$nic ]] && cp /etc/sysconfig/network-scripts/ifcfg-$nic /etc/sysconfig/network-scripts/ifcfg-$nic.bak
        sed -Ei.one-click-backup "
          s/$sys_ip/$destination_server/g;
          s/$sys_gw/$destination_gw/g;
          s,${sys_ipv6/:1},${destination_v6/:1},g;
          s/$ipv6_gw/${remote_v6_gw:-}/g
        " /etc/sysconfig/network-scripts/ifcfg-$nic
        if [[ -d /etc/wireguard/ ]]; then
          wg-quick down "$int"
          sed -Ei.one-click-backup "
            /ip -6/ ! {
              s/$sys_ip/$destination_server/g;
              s/$sys_gw/$destination_gw/g;
              s,${sys_ipv6/:1},${destination_v6/:1},g;
              s/$ipv6_gw/${remote_v6_gw:-}/g;
              s/200 default via $destination_gw/#&/;
              /ip -6/ {
                /${sys_ip}|${destination_server}/d
              }
            }  
          " $wg_file
          wg-quick up "$int"
        fi
        sed -i.one-click-backup "s/eth0/$nic/g" /etc/sysconfig/network-scripts/ifcfg-$nic
        systemctl restart network || systemctl restart NetworkManager
      fi
      ;;
  esac
  rm -f $net_config
  reboot
done
EOF
  chmod +x "$net_config"
  sync
  sleep 1
  info "Network reconfigurations files prepared."
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable net-reconfigure.service
  # ==== End After Migration Network Repair ====
  # ==== Singular & Plural Definitions ====
  (( "${#drives[@]}" > 1 )) && {
    z="drive's"
    y="their"
    x="disks"
  } || {
    z="drive"
    y="it's"
    x="disk"
  }
  # ==== Quick SSH pass to check credential validity ====
  echo
  info "Checking SSH Validity..."
  sleep 0.3
  if ! sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" "exit"; then
    error '%s\n' " " "${red}SSH connection failed!${reset}" \
    "Please double-check credentials and host keys." \
    " " >&2
    printf '%s' "Now exiting"
    for dot in {1..10}; do printf '%s' '.';sleep 0.3;done 
    echo
    return 1
  fi
  success " " "${green}[✓] SSH Credentials Valid!${reset}"
  before_migration
  # ==== Comparism disk table + display of disks being migrated ====
  mapfile -t remote_drives < <(
    sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
    "lsblk -dn -o NAME,SIZE,TYPE | awk '\$3==\"disk\"{print \$1,\$2}'")
  echo
  echo "${cyan}=========================================================${reset}"
  printf "${grey}#${reset} %s\n" "${green}The following "$z" will be migrated in "$y" entirety:${reset}" \
  "${green}=======${reset}" \
  "${z^}" "${green}=======${reset}" 
  printf "${grey}#${reset} ${cyan}%s\n" "${drives[@]}${reset}" 
  echo "${cyan}=========================================================${reset}"
  echo
  # ==== Completion Resizable Banner ====
  complete_migration_banner
  # ==== Disk Destroyer Confirmation ====
  confirm_destroy() {
    printf '%s\n' \
      "This is a ${red}DESTRUCTIVE${reset} action and will totally wipe ALL data on the remote server." \
      " " \
      "                           ${ul}Overview:${ul_reset}" \
      "                 Remote User:            ${cyan}${user}${reset}" \
      "                 Remote Server IPv4:     ${cyan}${destination_server}${reset}" \
      "                 Remote Server Gateway:  ${cyan}${destination_gw}${reset}"
    if [[ "$destination_v6" != "" ]]; then
      printf '%s\n' "                 Remote Server IPv6:     ${cyan}${destination_v6}${reset}" \
        "                 Remote IPv6 Gateway:    ${cyan}${remote_v6_gw}${reset}"
    fi
    printf '%s\n' "                 SSK Key:                ${cyan}Not Configured${reset}" \
      "                 Mode:                   ${yellow}DD Migrator Clone${reset}" " "
    warn "${red}$(tput setab 3)SSH WILL NO LONGER BE ACCESSIBLE ONCE YOU START BUT THIS CONNECTIION WILL REMAIN ACTIVE SO LONG AS YOU DO NOT DISCONNECT${reset}" 
    read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed? " destroy_remote
    destroy_remote="${destroy_remote:-}"
    destroy_remote="${destroy_remote,,}"
    if [[ ! "${destroy_remote}" =~ ^(y|yes)$ ]]; then
      exit 1
    fi
    info "This may take a while to complete" " "\
      "To protect the migration process from unexpected disconnections, this session is run inside of it's own ${cyan}tmux${reset} window." \
      "You can disconnect from the session at any time with ${cyan}Ctrl+b${reset} then ${cyan}d${reset} and the process will continue in the background." \
      "Should you need to reattch, please ensure you are the root user and use the following commands:"
    printf "${cyan}[TCMD]:%s\n" "$(tput setaf 3)tmux reattach${reset} if there is the single session." \
      "$(tput setaf 3)tmux reattach -t 'one-click'${reset} if there is more than one session." 
    info  " " 
    sleep 1
  }
  # ==== After Migration Steps ====
  post_migration() {
    printf '%s\n' " $(tput setaf 10)\"=================================================\"${reset}" \
      "$banner" \
      " $(tput setaf 10)\"=================================================\"${reset}" " " \
      "This server ($sys_ip) has now been cloned to the new server ($destination_server)" " " \
      "$(tput setaf 10)==== GENERAL STEPS AFTER MIGRATION/CLONING ====${reset}" " " \
      "(1). You will need to log into the management portal for $destination_server." " "\
      "${ul}${cyan}Quick Fix${reset}$(tput rmul)" \
      "(2). Enable rescue mode." \
      "(3). Log into the rescue shell." \
      "(4). Fix the filesystem - ${grey}e2fsck -b 32768 -y /dev/${remote_disk_name[@]}${reset}" \
      "                 or     ${grey}fsck -y /dev/${remote_disk_name[@]}${reset}" \
      "(5). Disable rescue mode (Will reboot automatically. If not, reboot)" \
      "Log in with your old server credentials. Migration complete!" " "\
      "${ul}${cyan}Extended Fix 1${reset}$(tput rmul)" \
      "(2). Reboot the server." \
      "(3). Check if you have been dropped into ${cyan}GRUB Rescue${reset}." \
      "(4). If not, jump to step ??FILL IN??. If so, check the following:" \
      "(5). List Partitions             $(tput setab 3)$(tput setaf 7)grub rescue\> ls${reset}" \
      "You\'ll see something like:    $(tput setab 3)$(tput setaf 7)(hd0) (hd0,gpt1) (hd0,gpt2)${reset}" \
      "(6). Find the boot partition     $(tput setab 3)$(tput setaf 7)grub rescue> ls (hd0,gpt1)/${reset}" \
      "                               $(tput setab 3)$(tput setaf 7)grub rescue> ls (hd0,gpt2)/${reset}" \
      "You should find one that contains ${cyan}/boot /vmlinuz /run /sys${reset} etc. Lets assume \(hd0,gpt2\)" \
      "(7). Set the boot variables      $(tput setab 3)$(tput setaf 7)grub rescue> set root=(hd0,gpt2) \(hd0,gpt2\)${reset}" \
      "                               $(tput setab 3)$(tput setaf 7)grub rescue> set prefix=(hd0,gpt2)/boot/grub/${reset}" \
      "                               $(tput setab 3)$(tput setaf 7)grub rescue> insmod normal${reset}" \
      "                               $(tput setab 3)$(tput setaf 7)grub rescue> normal${reset}" \
      "The system will now reboot. You may see another GRUB error in which case continue to the next step." \
      "(8). Enable rescue mode." \
      "(9). Log into the rescue shell." \
      "(10). Fix the filesystem - ${grey}e2fsck -b 32768 -y /dev/${remote_disk_name[@]}${reset}" \
      "                 or     ${grey}fsck -y /dev/${remote_disk_name[@]}${reset}" \
      "(11). Disable rescue mode \(Will reboot automatically. If not, reboot\)" \
      "(12). At this point, you may be dropped back into GRUB Rescue. If so, follow steps 5-7 again." \
      " " "Log in with your old server credentials. Migration complete!" \
      "${ul}${cyan}Extended Fix 2${reset}${ul_reset}" \
      "(2). Enable rescue mode." \
      "(3). Fix the filesystem - ${grey}e2fsck -b 32768 -y /dev/${remote_disk_name[@]}${reset}" \
      "                 or     ${grey}fsck -y /dev/${remote_disk_name[@]}${reset}" \
      "                        If prompted to Fix, select Yes/Fix/Accept" \
      "(4). Mount the filesystem:To achieve this, mount the filesystems to access ${cyan}parted${reset} or ${cyan}fdisk${reset}" \
      "                        ${grey}mount /dev/${remote_disk_name[@]} /mnt${reset}" \
      "                        ${grey}mount --bind /dev  /mnt/dev" \
      "                        mount --bind /proc /mnt/proc" \
      "                        mount --bind /sys /mnt/sys" \
      "                        chroot /mnt${reset}" \
      "(5). Find / UUID          We need the UUID to add to FSTAB." \
      "                        ${grey}blkid${reset}" \
      "                        Use the UUID (vdb1?) in fstab and set it as the root partition" \
      "(6). Update GRUB          ${grey}grub-install ${remote_disk_name[@]}${reset}" \
      "                        ${grey}update-grub${reset}" \
      "(7). Disable rescue mode \(Will reboot automatically. If not, reboot\)" " " \
      "${ul}${cyan}Additional Troubleshooting${reset}${ul_reset}" \
      "(1). Add BIOS           - ${grey}parted /dev/${remote_disk_name[@]:0:-1}" \
      "                        type p \(print\). Take note of the start value" \
      "                        mkpart bios_grub 1MiB 3MiB" \
      "                        set 1 bios_grub on" \
      "                        quit${reset}" \
      "             You may be asked if you want to fix the FS if the disk is larger. Accept this prompt." \
      "(2). Reboot. " \
      "If dropped into ${red}Emergency Mode${reset}, you will need to run:" \
      "                        ${grey}fsck -y /dev/${remote_disk_name[@]}${reset}" \
      "on your drives and allow initramfs to repair itself" " " \
      "If you are dropped into ${red}GRUB${reset} or ${red}Dracut Emergency Shell${reset}, then you will need to launch rescue mode on your server or boot from a live CD" " " \
      " " \
      "${ul}${cyan}Dracut Shell${reset}${ul_reset}" \
      "Once in rescue mode, you will need to reinstall ${red}GRUB${reset} and fix the filesystem." \
      "This can be achieved by following the following steps:" " "\
      "(3). Load Rescue Mode" \
      "(4). Fix the filesystem - ${grey}fsck -y /dev/${remote_disk_name[@]}${reset}" \
      "(5). Mount the filesystem ${grey}mount /dev/${remote_disk_name[@]} /mnt${reset}" \
      "                        ${grey}mount --bind /dev  /mnt/dev" \
      "                        mount --bind /proc /mnt/proc" \
      "                        mount --bind /sys /mnt/sys" \
      "                        chroot /mnt${reset}" \
      "(6). Load the parted tool ${grey}parted /dev/${remote_disk_name[@]}${reset}" \
      "Press ${grey}p${reset} to print all of the partitions. You should be shown a warning about capacity discrepency. Select fix." \
      "If the option is not displayed or you miss it, you can run the following command:" \
      "                        ${grey}resizepart 1 100%" \
      "                        quit${reset}" \
      "(7). Reinstall GRUB     - ${grey}dracut -f --regenerate-all" \
      "                        grub2-install /dev/${remote_disk_name[@]}" \
      "                        grub2-mkconfig -o /boot/grub2/grub.cfg${reset} " " " \
      "(8). Exit rescue mode " " " \
      "Ensure you have access to a reliable serial console or VNC Client and have your VNC password available" " " \
      "You can hold the ${blue}y${reset} button during the fsck check if dropped into ${red}Emergency Mode${reset}" " " " "
  }
  actual_dd_run() {
    local local_drives_sorted remote_drives_sorted num_local num_remote min_disks
    local_drives_sorted=($(for d in "${local_drives[@]}"; do echo "$d"; done | sort -k2 -nr | awk '{print $1}'))
    remote_drives_sorted=($(for d in "${remote_drives[@]}"; do echo "$d"; done | sort -k2 -nr | awk '{print $1}'))
    num_local=${#local_drives_sorted[@]}
    num_remote=${#remote_drives_sorted[@]}
    min_disks=$(( num_local < num_remote ? num_local : num_remote ))
    info "Mapping $min_disks $x..."

    for ((i=0;i<min_disks;i++)); do
      local_disk_name=$(echo "${local_drives_sorted[i]}" | awk '{print $1}')
      remote_disk_name=$(echo "${remote_drives_sorted[i]}" | awk '{print $1}')

      info "${ul}Physical Drive Mapping:${ul_reset} /dev/$local_disk_name ${cyan} →${reset} /dev/$remote_disk_name"

      # ==== Find local partitions ====
      mapfile -t local_parts < <(lsblk -ln -o NAME,SIZE,TYPE /dev/"$local_disk_name" | awk '$3=="part"{print $1,$2}' | sort -k2 -hr | awk '{print $1}')
      # ==== Find remote partitions ====
      mapfile -t remote_parts < <(
        sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no "${user}@${destination_server}" \
        "lsblk -ln -o NAME,SIZE,TYPE /dev/$remote_disk_name | awk '\$3==\"part\"{print \$1,\$2}' | sort -k2 -hr | awk '{print \$1}'"
      )
      # ==== Clone each partition ====
      for ((j=0;j<${#local_parts[@]} && j<${#remote_parts[@]}; j++)); do
        local_disk_name="${local_parts[j]}"
        remote_disk_name="${remote_parts[j]}"
        info "${ul}Partition Mapping:${ul_reset}      /dev/$local_disk_name ${cyan}→${reset} /dev/$remote_disk_name"
        dd if="/dev/$local_disk_name" bs=64M status=progress conv=sync,noerror \
          | gzip -1 \
          | sshpass -p "$pass" ssh -T -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o StrictHostKeyChecking=no \
          "${user}@${destination_server}" \
          "gunzip | dd of=/dev/$remote_disk_name bs=64M status=progress"
        rc=$?
        if (( rc != 0 )); then
          die "Error cloning /dev/$local_disk_name → /dev/$remote_disk_name"
        fi
      done
    done
    if (( num_local > num_remote )); then
        warn "$((num_local - num_remote)) local disks were not cloned because the remote server has fewer disks."
    fi
    echo
    after_migration
    post_migration
  }
  confirm_destroy
  actual_dd_run
  unset pass   
}
# ==== End Of One-Click Migrator ==== #
