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
# ========================== #================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== One-Click Backup ==== #
profiles_dir="/etc/one-click/backup-tool/profiles"
backup_dest="${backup_dest:-}"
profile_name="${profile_name:-default}"
config="${config:-$profiles_dir/${profile_name}.conf}"
mkdir -p "$profiles_dir"
show_profiles_table() {
  local profile_dir="/etc/one-click/backup-tool/profiles"
  [[ -d "$profile_dir" ]] || die "Profiles directory not found: $profile_dir"
  mapfile -t profiles < <(ls -1 "$profile_dir"/*.conf 2>/dev/null)
  [[ ${#profiles[@]} -gt 0 ]] || {
    warn "No profiles found. Please create one."
    configure_backup
  }
  echo
  echo -e "\e[1;34m┌────┬──────────────────────┬────────┬──────────────────┬────────┬──────────┐\e[0m"
  echo -e "\e[1;34m│ #  │ Profile              │ Size   │ Modified         │ Owner  │ Perms    │\e[0m"
  echo -e "\e[1;34m├────┼──────────────────────┼────────┼──────────────────┼────────┼──────────┤\e[0m"
  local i=1
  for p in "${profiles[@]}"; do
    stat --format="%s|%y|%U|%a" "$p" | {
      IFS="|" read -r size mtime owner perms
      printf "\e[1;34m│ %-2d │ %-20s │ %-6s │ %-16s │ %-6s │ %-8s │\e[0m\n" \
        "$i" \
        "$(basename "$p")" \
        "${size}B" \
        "${mtime:0:16}" \
        "$owner" \
        "$perms"
    }
    ((i++))
  done
  echo -e "\e[1;34m└────┴──────────────────────┴────────┴──────────────────┴────────┴──────────┘\e[0m"
  echo
}
# ==== List available profiles ====
select_snapshot_from_list() {
  local snapshots=("$@")
  [[ ${#snapshots[@]} -gt 0 ]] || error "No snapshots available"; run_menu
  echo
  info "Available backups:"
  local i=1
  for s in "${snapshots[@]}"; do
    printf "  [%d] %s\n" "$i" "$s"
    ((i++))
  done
  echo
  while true; do
    read -rp "${cyan}[USER]${reset} Select backup number (or q to cancel): " choice
    case "$choice" in
      q|Q) return 1 ;;
    esac
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#snapshots[@]} )); then
      SELECTED_SNAPSHOT="${snapshots[$((choice-1))]}"
      return 0
    fi
    warn "Invalid selection"
  done
}
list_profiles() {
  [[ -d "$profiles_dir" ]] || die "Profiles directory not found: $profiles_dir"
  profiles=()
  for f in "$profiles_dir"/*.conf; do
    [[ -f "$f" ]] || continue
    profiles+=( "$(basename "$f" .conf)" )
  done
}
select_profile() {
  list_profiles
  if [[ ${#profiles[@]} -eq 0 ]]; then
    warn "No profiles found" >&2
    backup_info
    configure_backup
  fi
  info "Available backup profiles:"
  local i=1
  for p in "${profiles[@]}"; do
    printf "  %d) %s\n" "$i" "$p"
    ((i++))
  done
  while true; do
    read -rp "${cyan}[USER]${reset} Select profile number: " sel
    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#profiles[@]} )); then
      selected_profile="${profiles[$((sel-1))]}"
      break
    else
      warn "Invalid selection"
    fi
  done
}
switch_profile() {
  local old
  old="$profile"
  select_profile || { warn "No profiles available"; continue; }
    profile="$selected_profile"
    load_profile "$profile" || { warn "Failed to load profile"; continue; }
    info "Profile switched to $profile."
    warn "$profile is now in use. $old is no longer the active profile" 
    run_menu
}
load_profile() {
  local profile_name="$1"
  [[ -n "$profile_name" ]] || profile_name=$(current_profile)
  local config_file="$profiles_dir/${profile_name}.conf"
  [[ -r "$config_file" ]] || { 
    warn "[WARN]: Profile $profile_name missing or unreadable. Using default."
    profile_name="default"
    config_file="$profiles_dir/default.conf"
    [[ -f "$config_file" ]] || touch "$config_file"
  }
  source "$config_file"
  printf '%s\n' "$profile_name" > "$profiles_dir/.current_profile"
  config="$config_file"
}
current_profile() {
  # ==== Ensure profiles_dir exists ====
  [[ -n "$profiles_dir" ]] || profiles_dir="/etc/one-click/backup-tool/profiles"
  mkdir -p "$profiles_dir"
  if [[ -r "$profiles_dir/.current_profile" ]]; then
    cat "$profiles_dir/.current_profile"
  else
    default_conf="$profiles_dir/default.conf"
    [[ -f "$default_conf" ]] || touch "$default_conf"
    echo "default" > "$profiles_dir/.current_profile"
    echo "default"
  fi
}
# ==== Does the user want to use ssh-keys? ====
ssh_key() {
  read -rp "${cyan}[USER]${reset} Would you like to configure a SSH key? " key_request
  key_request=${key_request,,}
  if [[ "$key_request" == "yes" || "$key_request" == "y" ]]; then
    req=y
    read -rp "${cyan}[USER]${reset} Please enter your ssh key path: " key
  else
    req=n
    warn "ssh key will not be used."
  fi
}
###############################################################################################
backup_info() {
  header_notice "$backup_title" "$r_backup" "11" "4"
  info "This is the One-Click Incremental RSYNC Snapshot Backup Tool with an optional RCLONE Sync" 
  if [[ ! -s "${config:-}" ]]; then
  config=/etc/one-click/backup-tools/profiles/default.conf
    info " " "Cronjobs will be created by this tool to automate the process" \
      "The initial backup will always be a full backup and thus, will take the  longest time" \
      "You will be placed behind a TMUX session outside of automation  to keep the session alive in case of local network jitters." \
      "After each backup, the snapshot directory is uploaded to a remote destination using RCLONE e.g S3, OneDrive etc." \
      " " "Restores can be chosen from specific dates"
    echo
    warn "${ul}This is the initial backup configuration that will be written to $config${ul_reset}"
  fi
}
launch_header() {
  header_notice "$backup_title" "$r_backup" "11" "4"
}
rclone_check() {
  [[ -n "$r_remote" ]] || die "rclone remote not configured"
  rclone lsd "$r_remote" >/dev/null 2>&1 \
    || die "rclone remote '$r_remote' is invalid or not authenticated"
}
rclone_list_snapshots() {
  rclone lsd "${r_remote}${s_file}" 2>/dev/null \
    | awk '{print $NF}' \
    | sort
}
rclone_upload_snapshot() {
  snapshot_dir="$1"
  snapshot_name=$(basename "$snapshot_dir")
  if [[ "$compress_rclone" == "y" ]]; then
    # Create compressed archive
    tmp_archive="/tmp/${snapshot_name}.tar.gz"
    info "Compressing snapshot for rclone: $snapshot_name"
    tar -czf "$tmp_archive" -C "$dst_dir" "$snapshot_name"
    info "Uploading compressed snapshot to rclone remote"
    rclone_check
    rclone copy "$tmp_archive" "${r_remote}/${s_file}/" \
      --stats 30s \
      --transfers 4 \
      --checkers 8 \
      --log-file="/var/log/one-click/rclone.log" \
      --log-level INFO \
      || die "RCLONE upload failed"
    rm -f "$tmp_archive"
    success "Rclone compressed upload completed: ${snapshot_name}.tar.gz"
  else
    # Original logic: raw folder
    info "Starting rclone upload for snapshot: $snapshot_name"
    rclone_check
    rclone sync "$snapshot_dir" "${r_remote}/${s_file}/${snapshot_name}" \
      --create-empty-src-dirs \
      --stats 30s \
      --transfers 4 \
      --checkers 8 \
      --log-file="/var/log/one-click/rclone.log" \
      --log-level INFO \
      || die "RCLONE upload failed"
    success "Rclone upload completed: $snapshot_name"
  fi
}
dump_databases() {
  dump_dir="$rsync_backup_dir/.db_dumps"
  mkdir -p "$dump_dir"
  if command -v mysqldump >/dev/null; then
    info "Dumping MySQL databases"
    mysqldump --single-transaction --routines --events \
      --all-databases > "$dump_dir/mysql.sql" \
      && success "MySQL dump successfully backed up to the remote server location: $dst_dir" \
      || die "MySQL dump failed"
  fi
  if command -v pg_dumpall >/dev/null; then
    info "Dumping PostgreSQL databases"
    sudo -u postgres pg_dumpall > "$dump_dir/postgres.sql" \
      && success "MySQL dump successfully backed up to the remote server location: $dst_dir" \
      || die "PostgreSQL dump failed"
  fi
}
restore_databases() {
  if [[ -f "$restore_path/.db_dumps/mysql.sql" ]]; then
    info "Restoring MySQL databases..."
    if [[ "$req" == "y" || "$req" == "yes" ]]; then
      ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
        "cat $dst_dir/.db_dumps/mysql.sql" | mysql \
        && success "Remote MySQL restore completed" \
        || die "Remote MySQL restore failed"
    else
      sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
        "cat $dst_dir/.db_dumps/mysql.sql" | mysql \
        && success "Remote MySQL restore completed" \
        || die "Remote MySQL restore failed"
    fi
  fi
  if [[ -f "$restore_path/.db_dumps/postgres.sql" ]]; then
    info "Restoring PostgreSQL databases..."
    if [[ "$req" == "y" || "$req" == "yes" ]]; then
      ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
        "cat $dst_dir/postgres.sql" | psql \
        && success "Remote PostgreSQL restore completed" \
        || die "Remote PostgreSQL restore failed"
    else
      sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
        "cat $dst_dir/postgres.sql" | psql \
        && success "Remote PostgreSQL restore completed" \
        || die "Remote PostgreSQL restore failed"
    fi
  fi
}
fetch_db_backup() {
  local mode="$1"
  db_dir="$dst_dir/.db_dumps"
  mkdir -p "$db_dir"
  dump_restor_path() {
    dump="${1:-}"
    case "$mode" in
    local)
      [[ -d "$dump" ]] || { warn "No DB dumps found in local snapshot"; return 0; }
      if ! rsync -a "$dst_dir/.db_dumps/mysql.sql" "$db_dir/"; then
        error "Failed to copy local DB dumps"
        sleep 2
        run_menu
      fi
      ;;
    ssh)
      info "Fetching database dumps from remote"
      if [[ "$req" == "y" || "$req" == "yes" ]]; then
        ssh_cmd=(ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip")
      else
        ssh_cmd=(sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip")
      fi
      remote_cmd="rsync -a \"${dump}\" \"${db_dir%/}/\""
      if ! "${ssh_cmd[@]}" "$remote_cmd"; then
        error "Failed to fetch remote DB dumps"
        sleep 2
        run_menu
      fi
      ;;
    rclone)
      info "Fetching database dumps from rclone"
      rclone_check
      if ! rclone copy "$dump" "$db_dir/" --progress; then
        error "Failed to fetch rclone DB dumps"
        sleep 2
        run_menu
      fi
      ;;
    *)
      die "fetch_db_backup: unknown mode '$mode'"
      ;;
  esac
  }
  if [[ -f "$restore_path/.db_dumps/postgres.sql" ]]; then
    case "$mode" in
      local)
        # Database dumps are part of the snapshot
        [[ -d "$dst_dir/.db_dumps" ]] || { warn "No DB dumps found in local snapshot"; set_menu; }
        if ! rsync -a "$dst_dir/postgres.sql" "$db_dir/"; then
          error "Failed to copy local DB dumps"
          sleep 2
          run_menu
        fi
        ;;
      ssh)
        info "Fetching database dumps from remote"
        if [[ "$req" == "y" || "$req" == "yes" ]]; then
          ssh_cmd=(ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip")
        else
          ssh_cmd=(sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip")
        fi
        remote_cmd="rsync -a \"${dst_dir%/}/postgres.sql\" \"${db_dir%/}/\""
        if ! "${ssh_cmd[@]}" "$remote_cmd"; then
            error "Failed to fetch remote DB dumps"
            sleep 2
            run_menu
        fi
        ;;
      rclone)
        info "Fetching database dumps from rclone"
        rclone_check
        if ! rclone copy "$dst_dir/postgres.sql" "$db_dir/" --progress; then
          error "Failed to fetch rclone DB dumps"
          sleep 2
          run_menu
        fi
        ;;
      *)
        error "fetch_db_backup: unknown mode '$mode'"
        run_menu
        ;;
    esac
  fi
}
add_profile() {
  echo
  info "Additional Profiles Wizard"
  read -rp "${cyan}[USER]${reset} Enter a name for the new profile: " new_profile
  [[ -n "$new_profile" ]] || { warn "Profile name cannot be empty"; return 1; }
  new_profile="${new_profile// /_}"
  local profile_file="$profiles_dir/${new_profile}.conf"
  if [[ -f "$profile_file" ]]; then
    warn "Profile '$new_profile' already exists."
    return 1
  fi
  local old_config="$config"
  local old_profile="$profile_name"
  profile_name="$new_profile"
  config="$profile_file"
  configure_backup
  config="$old_config"
  profile_name="$old_profile"
  success "Profile '$new_profile' created successfully"
}
backup() {
  backup_dest="${backup_dest:-}"
  non_interactive="${non_interactive:-0}"
  source "$config"
  snapshot_date=$(date +%F_%H-%M)
  tmp_archive="/tmp/${snapshot_date}.tar.gz"
  if [[ -n "$backup_label" ]]; then
    latest_snapshot="${dst_dir}/${snapshot_date}_${backup_label}"
  else
    latest_snapshot="${dst_dir}/${snapshot_date}"
  fi
  mkdir -p "$latest_snapshot" "$dst_dir" "${dst_dir}/local/latest"
  mkdir -p "$latest_snapshot/.db_dumps"
  if [[ -s "$config" ]]; then 
    source "$config"
  fi
  if [[ "${req:-}" != "y" ]]; then
    d_pass=$(decrypt_password "$pass")
  fi
  mkdir -p "$dst_dir" "$dst_dir/local/latest" "$dst_dir/rsync/latest" "$dst_dir/rclone/latest"
  if (( non_interactive )); then
    backup_dest="${backup_dest:-l}"
  else
    read -rp "${cyan}[USER]${reset} Backup destination: ${yellow}[${red}l${yellow}]${blue}ocal, ${yellow}[${red}r${yellow}]${blue}emote SSH, ${yellow}[${red}c${yellow}]${blue}loud${reset} (rclone) (e.g., lr)? " backup_dest
    backup_dest=${backup_dest,,}
  fi
  if [[ ! "$backup_dest" =~ "c" && "$req" == "y" || "$req" == "yes" ]]; then
    if ssh -i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no "${backup_user}@${backup_ip}" \
      "mkdir -p '$dst_dir' '$dst_dir/local/latest' '$dst_dir/rsync/latest' '$dst_dir/rclone/latest'"; then
        success "Directory created on remote server."
    else
      error "Failed to create remote backup directory: $dst_dir"
    fi
  else
    if sshpass -p "${d_pass:-}" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "${backup_user}@${backup_ip}" \
      "mkdir -p '$dst_dir' '$dst_dir/local/latest' '$dst_dir/rsync/latest' '$dst_dir/rclone/latest'"; then
        success "Directory created on remote server"
    else
      error "Failed to create remote backup directory: $dst_dir"
    fi
  fi
  for ((i=0;i<${#backup_dest};i++)); do
    case "${backup_dest:i:1}" in
      *l*)
        # ==== local backup ====
        info "Backing up to local storage now"
        warn "Detecting Database"
        dump_databases
        warn "Backup of data files to local storage now starting."
        rsync -a --link-dest="$dst_dir/local/latest" "$source/" "$latest_snapshot/"
        ln -sfn "$latest_snapshot" "$dst_dir/local/latest"
        success "Local snapshot completed: $latest_snapshot"
        ;;
      *r*)
        # ==== remote backup ====
        warn "Detecting Database"
        dump_databases
        warn "Backup of data files to remote storage now starting."
        tar -czf "$tmp_archive" -C "$dst_dir" "$(basename "$latest_snapshot")"
        if [[ "$req" == "y" || "$req" == "yes" ]]; then
          rsync -av --progress \
            -e "ssh -i $key -o StrictHostKeyChecking=no -p $ssh_port" \
            "$tmp_archive" \
            "${backup_user}@${backup_ip}:${dst_dir}/rsync/${snapshot_date}/"
        else
          rsync -av --progress \
            -e "sshpass -p '${d_pass}' ssh -o StrictHostKeyChecking=no -p $ssh_port" \
            "$tmp_archive" \
            "${backup_user}@${backup_ip}:${dst_dir}/rsync/${snapshot_date}/"
        fi
        ln -sfn "$latest_snapshot" "$dst_dir/rsync/latest"
        success "Remote snapshot completed: ${backup_ip}:${dst_dir}/${snapshot_date}"
        rm -rf "$tmp_archive"
        ;;
      *c*)
        # ==== rclone backup ====
        info "Backup to remote rclone storage now starting"
        mkdir -p "$latest_snapshot"
        warn "Detecting Database"
        dump_databases
        warn "Backup of data files to rclone storage now starting."
        rsync -a --link-dest="$dst_dir/rclone/latest" "$source/" "$latest_snapshot/"
        ln -sfn "$latest_snapshot" "$dst_dir/rclone/latest"
        rclone_check
        rclone_upload_snapshot "$latest_snapshot"
        success "rclone snapshot completed: $latest_snapshot - ${r_remote}/${s_file}/${snapshot_name}"
        ;;
      *) die "Invalid backup destination selected" ;;
    esac
  done
  if [[ "$use_rclone" == "y" || "$use_rclone" == "yes" ]]; then
    rclone_check
    rclone_upload_snapshot "$latest_snapshot"
  fi
  if (( ! non_interactive )); then
    read -rp "${cyan}[USER]${reset} Press Enter to continue"
    run_menu
  fi
}
# ==== CONFIGURE BACKUP ====
configure_backup() {
  info "Please select the directory from the following tree that you would like to backup from:"
  read -rp "${cyan}[USER]${reset} Press Enter to continue: " 
  source_dir() {
    tree -d -L 2 -I 'proc|sys|dev|run|tmp|snap|lost+found|lib|mail|spool|cache|lang|locale|zoneinfo|boot|bin|rc[0-9]*|.*' /
    read -rp "${cyan}[USER]${reset} Enter the directory where files should be backed up:                                         " source
    if [[ -d "$source" ]]; then
      tree -I 'proc|sys|dev|run|tmp|snap|lost+found|lib|mail|spool|cache|lang|locale|zoneinfo|boot|bin|rc[0-9]*|.*' "$source"
    else
      error "Invalid Directory"
      sleep 2
      source_dir
    fi
  }
  source_dir
  echo
  read -rp "${cyan}[USER]${reset} Use rclone backup? (y/n):                                                              " use_rclone
  use_rclone=${use_rclone,,}
  if [[ "$use_rclone" == "y" || "$use_rclone" == "yes" ]]; then
    read -rp "${cyan}[USER]${reset} rclone remote name (e.g. remote:):                                                     " r_remote
    read -rp "${cyan}[USER]${reset} Should backups be compressed [y/n]:                                                    " compress_rclone
  else
    read -rp "${cyan}[USER]${reset} Please enter the IP of the destination server:                                         " backup_ip
    until is_ipv4 "$backup_ip"; do
      error "The IP is ${red}INVALID${reset}! Please try again."
      read -rp "${cyan}[USER]${reset} Destination server IP:                                                                 " backup_ip
    done
    read -rp "${cyan}[USER]${reset} Please enter the remote server username:                                               " backup_user
    check_ssh() {
      read -s -rp "Enter the remote server password (leave blank to use key):                                              " pass
      echo
      if [[ "$pass" != "" ]]; then
        read -s -rp "Please enter the password again:                                                                        " pass2
      fi
      echo
    }
    check_ssh
    if [[ "${pass2:-}" != "" && "${pass:-}" != "{pass2:-}" ]]; then
      error "The passwords do not match!"
      info "Please try again."
      check_ssh
    fi
    echo
    if [[ -n "$pass" ]]; then
        e_pass=$(encrypt_password "$pass")
    else
      ssh_key
    fi
    read -rp "${cyan}[USER]${reset} SSH port [22]:                                                                           " ssh_port
    ssh_port=${ssh_port:-22}
  fi
  read -rp "${cyan}[USER]${reset} Directory on destination server to save backups to:                                      " dst_dir
  dst_dir="${dst_dir%/}"
  read -rp "${cyan}[USER]${reset} Enter a descriptive name for this backup (optional):                                     " backup_label
  backup_label="${backup_label// /_}"
  warn "Confirming SSH Credentials"
  if [[ "${req:-}" == "y" || "${req:-}" == "yes" ]]; then
    ssh -i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
      "exit" \
      && success "${green}SSH Credentials Validated${reset}"
  else
    sshpass -p "$pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no "$backup_user@$backup_ip" \
      "exit" \
      && success "${green}SSH Credentials Validated${reset}" 
  fi
  if [[ "${profile_name:-}" == "" ]]; then
    profile_name=default
    config="/etc/one-click/backup-tool/profiles/${profile_name}.conf"
    mkdir -p "/etc/one-click/backup-tool/profiles/"
    touch "$config"
  fi
  info "Configuring backup profile: $profile_name"
  r_remote="${r_remote:-}"
  r_remote="${r_remote%:}:"
  cat > "$config" <<EOF
source="$source"                          # Local_Directory
backup_ip="$backup_ip"                    # Remote_IP
backup_user="$backup_user"                # Backup_User
ssh_port="$ssh_port"                      # SSH_Port
dst_dir="$dst_dir"                        # Remote_Directory
use_rclone="$use_rclone"                  # Use_of_rclone?
r_remote="${r_remote:-no}"                # rclone_Remote
pass="${e_pass:-}"                        # encrypted_Password
key="${key:-}"                            # SSH_key_path
req="${req:-n}"                           # SSH_Key_request--(Yes/No)
key="${key:-}"                            # SSH_Key_Path
dump_dir="$source/.db_dumps"              # Database_dump_directory
compress_rclone="${compress_rclone:-yes}" # Compress_rclone_backups
backup_label="$backup_label"              # Backup_identifier
EOF
  profile_name=$(basename "$config" .conf)
  (column -t < "$config") > "${config}.tmp"
  rm -f "$config"
  mv "${config}.tmp" "${config}"
  chmod 600 "$config"
  success "Profile successfully created"
  if [[ -n "${dst_dir:-}" ]]; then
    info "To automate the firing of this script, we need to use cron for scheduled runs." \
      "Please configure a cron job: "
    install_cron "-z" "One-Click Backup Tool" "y" "$profile_name" "$backup_dest"
  else
    die "SSH Validation failed."
  fi
  success "Backup profile '$profile_name' saved."
  return 0
}
restore_remote_backs() {
  # ==== Restore from remote backup ====
  info "Available remote backups:"
  remote_base="$dst_dir/rsync"
  if [[ "$req" == "y" || "$req" == "yes" ]]; then
    ssh -i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no \
      "${backup_user}@${backup_ip}" \
      "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort" \
      || die "Failed to list remote backups"
  else
    sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no \
      "${backup_user}@${backup_ip}" \
      "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort" \
      || die "Failed to list remote backups"
  fi
  echo
  read -rp "${cyan}[USER]${reset} Backup date to restore (REQUIRED): " backup_date
  [[ -n "$backup_date" ]] || die "Restore aborted: no backup selected"
  [[ "$backup_date" =~ ^[0-9]{4}- ]] \
    || die "Invalid backup format"
  remote_snap="${remote_base}/${backup_date}"
  info "Restoring snapshot: $backup_date"
  if [[ "$req" == "y" || "$req" == "yes" ]]; then
    rsync -a --progress \
      -e "ssh -i $key -p $ssh_port -o StrictHostKeyChecking=no" \
      "${backup_user}@${backup_ip}:${remote_snap}/" \
      "$restore_path/" \
      || die "Restore failed"
  else
    sshpass -p "$d_pass" rsync -a --progress \
      -e "ssh -p $ssh_port -o StrictHostKeyChecking=no" \
      "${backup_user}@${backup_ip}:${remote_snap}/" \
      "$restore_path/" \
      || die "Restore failed"
  fi
  success "Remote restore completed: $backup_date"
  info "Restoring databases"
  fetch_db_backup ssh
  restore_databases
}
remote_table() {
  local -a items=("$@")
  local count=${#items[@]}
  local title
  if (( count == 1 )); then
    title=" SNAPSHOT "
  else
    title=" SNAPSHOTS "
  fi
  local BLUE="\033[34m"
  local WHITE="\033[97m"
  local DIM="\033[2m"
  local RESET="\033[0m"
  local max=0
  for i in "${items[@]}"; do
    (( ${#i} > max )) && max=${#i}
  done
  local width=$((max + 2))
  printf "${BLUE}┌"
  local pad=$(( (width - ${#title}) / 2 ))
  printf '─%.0s' $(seq 1 "$pad")
  printf "${WHITE}%s${BLUE}" "$title"
  printf '─%.0s' $(seq 1 "$((width - pad - ${#title}))")
  printf "┐${RESET}\n"
  for i in "${items[@]}"; do
    printf "${BLUE}│${RESET} %-*s ${BLUE}│${RESET}\n" "$max" "$i"
  done
  printf "${BLUE}└"
  printf '─%.0s' $(seq 1 "$width")
  printf "┘${RESET}\n"
}
# ==== RESTORE MENU ====
restore_menu() {
  select_snapshot_from_list() {
    snapshots=("$@")
    [[ ${#snapshots[@]} -gt 0 ]] || die "No backups available"

    echo
    info "Available backups:"
    local i=1
    for s in "${snapshots[@]}"; do
      printf "  [%d] %s\n" "$i" "$s"
      ((i++))
    done
    echo
    while true; do
      read -rp "${cyan}[USER]${reset} Select backup number (or q to cancel): " choice
      case "$choice" in
        q|Q) return 1 
        ;;
      esac
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#snapshots[@]} )); then
        selected_snapshot="${snapshots[$((choice-1))]}"
        return 0
      fi
      warn "Invalid selection"
    done
  }
  d_pass=$(decrypt_password "$pass")
  info "Restore Mode"
  read -rp "${cyan}[USER]${reset} Restore from ${yellow}[${red}l${yellow}]${blue}ocal, ${yellow}[${red}r${yellow}]${blue}emote${reset} SSH or ${yellow}[${red}c${yellow}]${blue}loud${reset} (rclone):                                                       " restore_from
  restore_from="${restore_from,,}"
  restore_from="${restore_from:0:1}"
  read -rp "${cyan}[USER]${reset} Restore to $source or alternative path: " restore_path
  restore_path="${restore_path:-$source}"
  mkdir -p "$restore_path" || die "Unable to create restore directory"
  case "$restore_from" in
    # ==== LOCAL ====
    l)
      mapfile -t local_snaps < <(
        ls -1 "$dst_dir" 2>/dev/null | grep -E '^[0-9]{4}-' | sort
      )
      select_snapshot_from_list "${local_snaps[@]}" \
        || die "Restore cancelled"

      src_snap="${dst_dir}/${selected_snapshot}"
      [[ -d "$src_snap" ]] || die "Snapshot not found"

      info "Restoring local snapshot: $selected_snapshot"
      rsync -a --progress "$src_snap/" "$restore_path/" \
        || die "Local restore failed"
      success "Local restore completed"
      restore_databases
      ;;
    # ==== REMOTE (SSH) ====
    r)
      remote_base="$dst_dir/rsync"
      remote_snaps=()
      if [[ "$req" == "y" || "$req" == "yes" ]]; then
        mapfile -t remote_snaps < <(
          ssh -i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no \
            "${backup_user}@${backup_ip}" \
            "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort"
        )
      else
        mapfile -t remote_snaps < <(
          sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no \
            "${backup_user}@${backup_ip}" \
            "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort"
        )
      fi
      select_snapshot_from_list "${remote_snaps[@]}" \
        || die "Restore cancelled"
      remote_snap="${remote_base}/${selected_snapshot}"
      info "Restoring remote snapshot: $selected_snapshot"
      if [[ "$req" == "y" || "$req" == "yes" ]]; then
        rsync -a --progress \
          -e "ssh -i $key -p $ssh_port -o StrictHostKeyChecking=no" \
          "${backup_user}@${backup_ip}:${remote_snap}/" \
          "$restore_path/" \
          || die "Remote restore failed"
      else
        sshpass -p "$d_pass" rsync -a --progress \
          -e "ssh -p $ssh_port -o StrictHostKeyChecking=no" \
          "${backup_user}@${backup_ip}:${remote_snap}/" \
          "$restore_path/" \
          || die "Remote restore failed"
      fi
      success "Remote restore completed"
      restore_databases
      ;;
    # ==== RCLONE ====
    c)
      rclone_check
      mapfile -t rclone_snaps < <(
        rclone lsd "${r_remote}/${s_file}" | awk '{print $NF}' | sort
      )
      select_snapshot_from_list "${rclone_snaps[@]}" \
        || die "Restore cancelled"
      remote_path="${r_remote}/${s_file}/${selected_snapshot}"
      info "Restoring rclone snapshot: $selected_snapshot"
      rclone copy "$remote_path" "$restore_path" --progress \
        || die "Rclone restore failed"
      success "Rclone restore completed"
      restore_databases
      ;;
    *)
      die "Invalid restore option selected"
      ;;
  esac
}
menu() {
  printf "%s\n" " " "${yellow}[${green}ONE-CLICK BACKUP TOOL${yellow}]${reset}                                  ${yellow}[${red}[$(tput setaf 4)PROFILE${reset}: $profile${red}]${yellow}]${reset}"
  info "Welcome to $(tput setaf 3)One-Click ${yellow}BACKUP${reset}!" \
    "Here. you can configure backup profiles, take and restore backups and choose your preferred backup location." \
    "One-Click offers an array of useful and disaster recovery tools."
  echo
  printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
  "[1]. Edit Configuration" \
  "[2]. View Configuration" \
  "[3]. View Profiles" \
  "[4]. Add Profile" \
  "[5]. Switch Profile" \
  "[6]. Take A Snapshot" \
  "[7]. Restore A Snapshot" \
  "[8]. View Local Snapshots" \
  "[9]. View Remote Snapshots" \
  "[10]. Configure cron job" \
  "[11]. Exit"
}

# ==== RUN MENU ====
run_menu() {
  remote_base="$dst_dir/rsync"
  d_pass=$(decrypt_password "$pass")
  while true; do
    clear
    menu
    read -rp "${cyan}[USER]${reset} Please select an option [1-11]: " backup_run
    case "$backup_run" in
      1)
        if [[ -s "$config" ]]; then
          info "Backup configuration exists at $config"
          read -rp "${cyan}[USER]${reset} Reconfigure it? [y/n]: " reconfig_backup
          [[ "${reconfig_backup,,}" =~ ^(y|yes)$ ]] && configure_backup
        else
          configure_backup
        fi
        ;;
      2) config_table "$config"       ;;
      3) show_profiles_table          ;;
      4) add_profile                  ;;
      5) switch_profile               ;;
      6) backup                       ;;
      7) restore_menu                 ;;
      8)
        if [[ -z "$(ls -A "$dst_dir" 2>/dev/null)" ]]; then
          warn "No local backups found"
        else
          ls_table "$dst_dir" | sed -E '1,3 ! {/[0-9_]/ ! d}'
        fi
        ;;
      9)
        if [[ -z "$(ls -A "$source" 2>/dev/null)" ]]; then
          warn "No backup files found"
        else
          if [[ "$req" == "y" || "$req" == "yes" ]]; then
            echo
            remote_table $(ssh -i "$key" -p "$ssh_port" -o StrictHostKeyChecking=no \
              "${backup_user}@${backup_ip}" \
              "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort")
          else
            echo
            remote_table $(sshpass -p "$d_pass" ssh -p "$ssh_port" -o StrictHostKeyChecking=no \
              "${backup_user}@${backup_ip}" \
              "ls -1 '$remote_base' | grep -E '^[0-9]{4}-' | sort")
          fi
        fi
        ;;
      10) 
        profile_name=$(basename "$config" .conf)
        install_cron "-z" "One-Click Backup Tool" "y" "$profile_name" "$backup_dest"
        ;;
      11) exit 0 ;;
      *) warn "Invalid selection"; sleep 1 ;;
    esac
    read -rp "${cyan}[USER]${reset} Press Enter to return to menu..."
  done
}
# ==== SEL ENTRY ====
rsync_rclone() {
  mkdir -p "$profiles_dir"
  local profile
  profile=$(current_profile)
  success "Using profile: ${cyan}${profile}${reset}"
  load_profile "$profile" || exit 1
  if [[ ! -f "${config:-}" ]]; then
    backup_info
  fi
  if [[ -s "$config" ]]; then
    launch_header
    run_menu
  else
    warn "Configuration file has not been initialized."
    info "Configuring now."
    configure_backup
  fi
}
