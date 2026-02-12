# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK MULIPLE TOOLS * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ===== Detect boot/root disks =====
non_interactive="${non_interactive:-}"
detect_boot_disk() {
  lsblk -no pkname "$(findmnt -nvo SOURCE /)" | head -n1 | sed 's|^|/dev/|'
}
detect_esp() {
  local disk
  disk=$(detect_boot_disk)
  lsblk -lpno NAME,PARTTYPE "$disk" \
    | awk '$2=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"{print $1; exit}'
}
mount_esp() {
  local esp mnt
  esp="$1"
  mnt="/tmp/esp_mount"
  mkdir -p "$mnt"
  mount "$esp" "$mnt" || die "Failed to mount ESP $esp"
  echo "$mnt"
}
mount_root() {
  local root_dev
  root_dev=$(blkid -t UUID="$root_uuid" -o device) \
    || die "Root partition not found by UUID"

  mkdir -p /mnt
  mount "$root_dev" /mnt || die "Failed to mount root filesystem"
}
reinstall_grub() {
  info "Reinstalling GRUB bootloader"
  if command -v grub-mkconfig >/dev/null; then
    grub=grub
  else
    grub=grub2
  fi
  mount --bind /dev  /mnt/dev
  mount --bind /proc /mnt/proc
  mount --bind /sys  /mnt/sys
  if [[ "$boot_type" == "UEFI" ]]; then
    mount "$esp_part" /mnt/boot/efi || die "Failed to mount ESP in chroot"
    chroot /mnt "${grub}"-install \
      --target=x86_64-efi \
      --efi-directory=/boot/efi \
      --bootloader-id=GRUB \
      --recheck \
      || die "UEFI grub-install failed"
  else
    chroot /mnt "${grub}"-install \
      --target=i386-pc \
      "$boot_disk" \
      || die "BIOS grub-install failed"
  fi
  chroot /mnt "${grub}"-mkconfig -o "/boot/${grub_dir}/grub.cfg"
  umount -R /mnt/dev /mnt/proc /mnt/sys || true
}
restore_esp() {
  local esp src mnt
  esp="$1"
  src="$2"
  mnt="/tmp/esp_mount"
  mkdir -p "$mnt"
  info "Restoring EFI System Partition: $esp"
  mount "$esp" "$mnt" || die "Failed to mount ESP for restore"
  rsync -aHAX --delete "$src/" "$mnt/" || die "ESP restore failed"
  umount "$mnt"
}
# ===== Backup =====
recovery_backup() {
  local disk timestamp out_path esp esp_mnt cont
  disk=$(detect_boot_disk)
  timestamp=$(date +%F_%H-%M)
  out_path="$recovery_base/$timestamp"
  current_snapshot="$out_path"
  mkdir -p "$out_path"
  warn "This will carry out a backup of critical boot recovery components"
  if (( ! non_interactive )); then
    read -rp "${cyan}[USER]${reset} Proceed [y/n]: " cont
    cont="${cont,,}"
    if [[ ! "$cont" == "y" && ! "$cont" == "yes" ]]; then
      error "Backup Aborted!"
      return
    fi
  else
    info "Running in non-interactive mode: proceeding automatically"
  fi
  info "Backing up boot disk: $disk"
  cat > "$out_path/recovery_map.conf" <<EOF
current_snapshot="$current_snapshot"

# ==== Disk information ====
boot_disk="$disk"
disk_model="$(lsblk -ndo MODEL "$disk")"
disk_size="$(blockdev --getsize64 "$disk")"
sector_size="$(blockdev --getss "$disk")"

# ==== Root filesystem ====
root_uuid="$(blkid -s UUID -o value "$(findmnt -nvo SOURCE /)")"
root_partuuid="$(blkid -s PARTUUID -o value "$(findmnt -nvo SOURCE /)")"

# ==== Boot type ====
boot_type="$( [ -d /sys/firmware/efi ] && echo UEFI || echo BIOS )"

# ==== EFI System Partition (UEFI only) ====
esp_part="$(detect_esp 2>/dev/null || true)"
esp_mount="/boot/efi"

# ==== GRUB layout ====
grub_dir="$(
  if [[ -d /boot/grub2 ]]; then
    echo grub2
  elif [[ -d /boot/grub ]]; then
    echo grub
  else
    echo unknown
  fi
)"
EOF
  # Backup partition table
  sgdisk --backup="$out_path/layout.bin" "$disk"
  sfdisk -d "$disk" > "$out_path/partition_table.txt"
  # Detect boot type
  if [ -d /sys/firmware/efi ]; then
    echo "boot_type=UEFI" >> "$out_path/recovery_map.conf"
    esp=$(detect_esp) || die "No EFI System Partition found"
    echo "esp_part=$esp" >> "$out_path/recovery_map.conf"
    info "Backing up EFI System Partition $esp"
    mkdir -p "$out_path/esp"
    esp_mnt=$(mount_esp "$esp")
    rsync -aHAX --numeric-ids "$esp_mnt/" "$out_path/esp/" || die "ESP backup failed"
    umount "$esp_mnt"
  else
    echo "boot_type=BIOS" >> "$out_path/recovery_map.conf"
    info "Backing up BIOS bootcode"
    dd if="$disk" of="$out_path/bootcode.bin" bs=446 count=1
  fi
  # ==== Backup /boot and GRUB ====
  info "Backing up /boot and GRUB configuration"
  mkdir -p "$out_path/boot"
  mkdir -p "$out_path/grub"
  # --- /boot ---
  if mountpoint -q /boot; then
    rsync -aHAX --numeric-ids /boot/ "$out_path/boot/" \
      || die "/boot backup failed"
    echo "boot_backup=yes" >> "$out_path/recovery_map.conf"
  else
    warn "/boot is not a separate mount; backing up directory anyway"
    rsync -aHAX --numeric-ids /boot/ "$out_path/boot/" || true
    echo "boot_backup=partial" >> "$out_path/recovery_map.conf"
  fi
  # --- GRUB directories (grub or grub2) ---
  for grubdir in /boot/grub /boot/grub2; do
    if [[ -d "$grubdir" ]]; then
      rsync -aHAX --numeric-ids "$grubdir/" "$out_path/grub/$(basename "$grubdir")/" \
        || die "Failed to backup $grubdir"
      echo "grub_dir=$(basename "$grubdir")" >> "$out_path/recovery_map.conf"
    fi
  done
  # --- GRUB configuration files ---
  mkdir -p "$out_path/grub/etc"
  [[ -f /etc/default/grub ]] && \
    cp -a /etc/default/grub "$out_path/grub/etc/"
  [[ -d /etc/grub.d ]] && \
    rsync -aHAX --numeric-ids /etc/grub.d/ "$out_path/grub/etc/grub.d/"
  echo "grub_config_backup=yes" >> "$out_path/recovery_map.conf"
  echo "recent_backup=$out_path" > "$recovery_config"
  mkdir -p "$out_path/boot"
  rsync -aHAX --numeric-ids /boot/ "$out_path/boot/"
  success "Backup completed: $out_path"
  return
}
# ===== Restore =====
recovery_restore() {
  local snap_path disk root_dev sel
  local snapshots=()
  recovery_base="/etc/one-click/boot-recovery-tool"
  recovery_config="$recovery_base/latest.conf"
  mkdir -p "$recovery_base"
  current_snapshot=""
  [[ -f "$recovery_config" ]] && source "$recovery_config"
  # --- Explicit snapshot passed as argument ---
  if [[ -n "${1:-}" ]]; then
    snap_path="$1"
  # --- Auto-load last snapshot ---
  elif [[ -n "${current_snapshot:-}" && -d "$current_snapshot" ]]; then
    snap_path="$current_snapshot"
  else
    # --- Enumerate snapshots ---
    mapfile -t snapshots < <(ls -1d "$recovery_base"/*/ 2>/dev/null | sort)
    [[ ${#snapshots[@]} -eq 0 ]] && die "No recovery snapshots found"
    echo "Available snapshots:"
    print_blue_table "$recovery_base"
    read -rp "${cyan}[USER]${reset} Select snapshot [1-${#snapshots[@]}]: " sel

    if [[ -z "$sel" ]]; then
      warn "No selection made."
      return 
    elif [[ "$sel" =~ ^[0-9]+$ && "$sel" -ge 1 && "$sel" -le ${#snapshots[@]} ]]; then
      snap_path="${snapshots[sel-1]}"
    else
      die "Invalid snapshot selection"
      return 
    fi
  fi
  [[ -d "$snap_path" ]] || die "Invalid snapshot directory: $snap_path"
  [[ -f "$snap_path/recovery_map.conf" ]] || die "Invalid snapshot (missing recovery_map.conf)"
  source "$snap_path/recovery_map.conf"
  disk="$boot_disk"
  info "Restoring snapshot: $snap_path -> $disk"
  warn "This is destructive! Entire disk will be overwritten!"
  read -rp "${cyan}[USER]${reset} Type CONFIRM to proceed: " confirm
  [[ "$confirm" != "CONFIRM" ]] && { error "Restore aborted"; return; }
  # ==== Restore partition layout ====
  info "Restoring partition table"
  sgdisk --load-backup="$snap_path/layout.bin" "$disk"
  partprobe "$disk"
  sleep 2
  # ==== Mount root ====
  mount_root
  # ==== Restore EFI System Partition (UEFI) ====
  if [[ "$boot_type" == "UEFI" && -d "$snap_path/esp" ]]; then
    info "Restoring EFI System Partition"
    mkdir -p /mnt/boot/efi
    mount "$esp_part" /mnt/boot/efi || die "ESP mount failed"
    rsync -aHAX --delete "$snap_path/esp/" /mnt/boot/efi/
  fi
  # ==== Restore BIOS bootcode ====
  if [[ "$boot_type" == "BIOS" && -f "$snap_path/bootcode.bin" ]]; then
    info "Restoring BIOS bootcode"
    dd if="$snap_path/bootcode.bin" of="$disk" bs=446 count=1
  fi
  # ==== Restore /boot ====
  if [[ -d "$snap_path/boot" ]]; then
    info "Restoring /boot"
    mkdir -p /mnt/boot
    rsync -aHAX --delete "$snap_path/boot/" /mnt/boot/
  fi
  # ==== Restore GRUB configuration ====
  if [[ -d "$snap_path/grub" ]]; then
    info "Restoring GRUB configuration"
    [[ -d "$snap_path/grub/$grub_dir" ]] && \
      rsync -aHAX "$snap_path/grub/$grub_dir/" "/mnt/boot/$grub_dir/"
    [[ -d "$snap_path/grub/etc" ]] && \
      rsync -aHAX "$snap_path/grub/etc/" /mnt/etc/
  fi
  # ==== Reinstall + regenerate GRUB ====
  reinstall_grub
  umount -R /mnt || true
  success "Restoration complete. Snapshot: $(basename "$snap_path")"
  info "Remove rescue media (if mounted) and reboot."
  read -rp "${cyan}[USER]${reset} Press ENTER to continue.."
}

# ==== Recovery Navigation ====
recovery_menu() {
  header_notice "$recovery_header" "$recovery_banner" "6" "11"
  while true; do
    clear
    printf "\n%s\n" "${yellow}[${green}ONE-CLICK BOOT RECOVERY${yellow}]${reset}"
    info "The One-Click Boot Recovery tool safely captures and restores a system’s boot state." \
      "Rescue mode may be needed in some situations to recover a corrupted boot partition."
    printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
      "[1]. Backup" \
      "[2]. Restore" \
      "[3]. Snapshot Directory" \
      "[4]. Backup Directory" \
      "[5]. Configure Cron" \
      "[6]. Exit"
    read -rp "${cyan}[USER]${reset} Select an option [1-6]: " backup_run
    case "$backup_run" in
      1) recovery_backup  ;;
      2) recovery_restore ;;
      3)
        if [[ -z "$(ls -A "${recovery_base:-}" 2>/dev/null)" ]]; then
          warn "No snapshots found"
        else
          ls_table "${recovery_base:-}" 
        fi
        ;;
      4)
        if [[ -z "$(ls -A "${out_path:-}" 2>/dev/null)" ]]; then
          warn "No snapshots found"
        else
          ls_table "${out_path:-}"
        fi
        ;;
      5) install_cron "-y" "Boot Recovery Tool" "r"      ;;
      6) exit 0                                          ;;
      *) echo "[ERROR] Invalid selection"                ;;
    esac
    read -rp "${cyan}[USER]${reset} Press enter to continue"
  done
}
# ==== End Boot Recovery ==== #
