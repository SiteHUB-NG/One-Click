# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK RECOVERY MODE * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Oct 2026 == # === Version#: 1.0.0 === #
# ====== One-Click ====== #
# ===== Detect boot/root disks =====
non_interactive="${non_interactive:-0}"
_recovery_error() { error "$*"; return 1; }
_recovery_is_block() { [[ -b "$1" ]]; }
_recovery_efi_mode() { [[ -d /sys/firmware/efi ]]; }
_recovery_require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || { _recovery_error "Boot recovery requires root."; return 1; }
}
_recovery_require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || { _recovery_error "Required tool missing: $tool"; return 1; }
  done
}
_recovery_paths() {
  recovery_base="${recovery_base:-/etc/one-click/boot-recovery-tool}"
  recovery_config="${recovery_config:-$recovery_base/latest.conf}"
  [[ "$recovery_base" == /* && "$recovery_config" == /* ]] || { _recovery_error "Recovery paths must be absolute."; return 1; }
}
_recovery_prepare_base() {
  local ancestor="$recovery_base"
  while [[ ! -e "$ancestor" && ! -L "$ancestor" ]]; do ancestor=$(dirname -- "$ancestor") || return 1;done
  _recovery_data secure-dir "$ancestor" || return 1
  mkdir -p -- "$recovery_base" || return 1
  _recovery_data secure-dir "$recovery_base" || return 1
}
_recovery_data() {
  python3 - "$@" <<'PY'
import sys,os,json,stat,hashlib,shlex,re
from pathlib import Path
op=sys.argv[1];p=Path(sys.argv[2])
keys={'format_version','current_snapshot','recent_backup','boot_disk','disk_model','disk_serial','disk_wwn','disk_size','sector_size','partition_type','root_uuid','root_partuuid','root_fstype','root_subvol','root_device_type','boot_uuid','boot_partuuid','boot_separate','boot_type','esp_part','esp_uuid','esp_partuuid','esp_mount','grub_dir','architecture','secure_boot','boot_backup','grub_config_backup'}
def regular(f):
    s=f.lstat()
    if not stat.S_ISREG(s.st_mode):raise ValueError(f'Not a regular file: {f}')
    if s.st_uid!=0 or s.st_mode&0o022:raise ValueError(f'Untrusted ownership/permissions: {f}')
    return s

def directory(f):
    f=f.absolute()
    for item in [f,*f.parents]:
        s=item.lstat()
        if not stat.S_ISDIR(s.st_mode):raise ValueError(f'Not a real directory: {item}')
        if s.st_uid!=0:raise ValueError(f'Directory is not root-owned: {item}')
        if s.st_mode&0o022 and not (s.st_mode&stat.S_ISVTX and item!=f):
            raise ValueError(f'Directory is writable by other users: {item}')

def parse(f):
    regular(f)
    if f.suffix=='.json':a=json.loads(f.read_text())
    else:
        a={}
        for line in f.read_text().splitlines():
            if not line.strip() or line.lstrip().startswith('#'):continue
            m=re.fullmatch(r'([a-z_]+)=(.*)',line)
            if not m or m[1] not in keys:raise ValueError('Invalid legacy metadata assignment')
            if any(x in m[2] for x in ('$','`',';','\\','\x00')):raise ValueError('Shell syntax in legacy metadata')
            values=shlex.split(m[2],comments=False,posix=True)
            if len(values)>1:raise ValueError('Invalid legacy metadata value')
            a[m[1]]=values[0] if values else ''
    if not isinstance(a,dict):raise ValueError('Metadata must be an object')
    for k,v in a.items():
        if k not in keys or not isinstance(v,str) or any(c in v for c in ('\n','\r','\t','\x00')):
            raise ValueError('Invalid metadata key/value')
    return a

def entries(root):
    out={}
    for f in sorted(root.rglob('*')):
        rel=f.relative_to(root).as_posix()
        if rel in {'integrity.json','COMPLETE'}:continue
        st=f.lstat()
        if st.st_uid!=0 or (not f.is_symlink() and st.st_mode&0o022):raise ValueError(f'Untrusted snapshot entry: {rel}')
        if f.is_symlink():out[rel]={'type':'link','target':os.readlink(f)}
        elif f.is_dir():out[rel]={'type':'dir'}
        elif f.is_file():
            h=hashlib.sha256()
            with f.open('rb') as stream:
                for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
            out[rel]={'type':'file','sha256':h.hexdigest(),'size':st.st_size}
        else:raise ValueError(f'Special file in snapshot: {rel}')
    return out
try:
    if op=='secure-dir':directory(p)
    elif op=='safe-lock':
        directory(p.parent)
        if p.exists() or p.is_symlink():regular(p)
    elif op=='read':
        directory(p.parent)
        for k,v in parse(p).items():print(k+'\t'+v)
    elif op=='save-map':
        a=dict(x.split('=',1) for x in sys.argv[3:]);p.write_text(json.dumps(a,indent=2)+'\n');p.chmod(0o600)
        conf=p.with_suffix('.conf');conf.write_text(''.join(k+'='+shlex.quote(v)+'\n' for k,v in a.items()));conf.chmod(0o600)
    elif op=='seal':
        directory(p);a=entries(p);f=p/'integrity.json';f.write_text(json.dumps(a,sort_keys=True,indent=2)+'\n');f.chmod(0o600)
        (p/'COMPLETE').write_text('one-click-boot-recovery-v2\n');(p/'COMPLETE').chmod(0o600)
    elif op=='verify':
        directory(p);regular(p/'integrity.json');regular(p/'COMPLETE')
        if (p/'COMPLETE').read_text()!='one-click-boot-recovery-v2\n':raise ValueError('Invalid completion marker')
        a=json.loads((p/'integrity.json').read_text())
        if a!=entries(p):raise ValueError('Snapshot contents differ from integrity manifest')
    elif op=='legacy-tree':directory(p);entries(p)
    elif op=='latest':
        directory(p.parent);regular(p) if p.exists() or p.is_symlink() else None
        temp=p.parent/('.latest-'+str(os.getpid()))
        fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'w') as f:
            f.write('recent_backup='+shlex.quote(sys.argv[3])+'\n');f.flush();os.fsync(f.fileno())
        try:os.replace(temp,p)
        finally:temp.unlink(missing_ok=True)
    elif op=='fstab':
        regular(p)
        for line in p.read_text().splitlines():
            fields=line.split()
            if fields and not fields[0].startswith('#') and len(fields)>=4 and fields[1]=='/boot':
                print(fields[0]);break
    else:raise ValueError('Unknown metadata operation')
except (OSError,ValueError,KeyError,json.JSONDecodeError) as e:
    print('Recovery validation failed: '+str(e),file=sys.stderr);sys.exit(1)
PY
}
_recovery_mounted_source() {
  local source
  source=$(findmnt -nro SOURCE --target "$1") || return 1
  source="${source%%\[*}"
  [[ "$source" == /dev/* ]] && _recovery_is_block "$source" || { _recovery_error "Unsupported filesystem source for $1: $source"; return 1; }
  readlink -f -- "$source"
}
_recovery_parent_disk() {
  local dev="$1" listing name type
  local -a disks=()
  listing=$(lsblk -snrpo NAME,TYPE -- "$dev") || return 1
  while read -r name type; do
    [[ "$type" == disk ]] && disks+=("$name")
  done <<<"$listing"
  mapfile -t disks < <(printf '%s\n' "${disks[@]}" | sort -u)
  [[ ${#disks[@]} -eq 1 ]] && _recovery_is_block "${disks[0]}" || { _recovery_error "Cannot select one physical disk for $dev; multi-disk/RAID layouts require manual recovery."; return 1; }
  printf '%s\n' "${disks[0]}"
}
detect_boot_disk() {
  local dev
  if mountpoint -q /boot; then dev=$(_recovery_mounted_source /boot) || return 1
  else dev=$(_recovery_mounted_source /) || return 1; fi
  _recovery_parent_disk "$dev"
}
detect_esp() {
  local disk listing name type parttype mounted
  disk="${1:-}"
  [[ -n "$disk" ]] || disk=$(detect_boot_disk) || return 1
  listing=$(lsblk -nrpo NAME,TYPE,PARTTYPE -- "$disk") || return 1
  local -a candidates=()
  while read -r name type parttype; do
    [[ "$type" == part && "${parttype,,}" == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] && candidates+=("$name")
  done <<<"$listing"
  if mountpoint -q /boot/efi; then
    mounted=$(_recovery_mounted_source /boot/efi) || return 1
    for name in "${candidates[@]}"; do [[ "$name" == "$mounted" ]] && { printf '%s\n' "$name"; return 0; }; done
    _recovery_error "Mounted ESP is not on the selected boot disk."; return 1
  fi
  [[ ${#candidates[@]} -eq 1 ]] || { _recovery_error "ESP discovery is missing or ambiguous."; return 1; }
  printf '%s\n' "${candidates[0]}"
}
mount_esp() {
  local esp="${1:-}" mnt
  _recovery_is_block "$esp" || { _recovery_error "Invalid ESP device."; return 1; }
  mnt=$(mktemp -d /run/one-click-esp.XXXXXX) || return 1
  if ! mount -o ro -- "$esp" "$mnt"; then rmdir "$mnt"; _recovery_error "Failed to mount ESP $esp"; return 1; fi
  printf '%s\n' "$mnt"
}
_recovery_resolve() {
  local uuid="${1:-}" partuuid="${2:-}" matches
  if [[ -n "$uuid" ]]; then matches=$(blkid -t "UUID=$uuid" -o device) || return 1
  elif [[ -n "$partuuid" ]]; then matches=$(blkid -t "PARTUUID=$partuuid" -o device) || return 1
  else _recovery_error "No filesystem identifier recorded."; return 1; fi
  [[ -n "$matches" && "$matches" != *$'\n'* ]] && _recovery_is_block "$matches" || { _recovery_error "Filesystem identifier is missing or ambiguous."; return 1; }
  if [[ -n "$uuid" && -n "$partuuid" ]];then
    [[ "$(blkid -s PARTUUID -o value "$matches")" == "$partuuid" ]] || { _recovery_error "UUID/PARTUUID binding differs from the snapshot.";return 1; }
  fi
  readlink -f -- "$matches"
}
_recovery_disk_idle() {
  local disk="$1" listing swaps dev parent
  listing=$(lsblk -nrpo MOUNTPOINTS -- "$disk") || return 1
  [[ -z "${listing//[[:space:]]/}" ]] || { _recovery_error "Target disk has mounted filesystems. Boot from separate rescue media first."; return 1; }
  swaps=$(swapon --noheadings --raw --show --output NAME) || return 1
  while IFS= read -r dev; do
    [[ -n "$dev" ]] || continue
    if ! _recovery_is_block "$dev"; then dev=$(_recovery_mounted_source "$dev") || return 1; fi
    parent=$(_recovery_parent_disk "$dev") || return 1
    [[ "$parent" != "$disk" ]] || { _recovery_error "Target disk has active swap."; return 1; }
  done <<<"$swaps"
}
_recovery_load_map() {
  local path="$1" data key value
  boot_disk=""; disk_model=""; disk_serial=""; disk_wwn=""; disk_size=""; sector_size=""; partition_type=""
  root_uuid=""; root_partuuid=""; root_fstype=""; root_subvol=""; root_device_type=""; boot_uuid=""; boot_partuuid=""; boot_separate=""
  boot_type=""; esp_part=""; esp_uuid=""; esp_partuuid=""; esp_mount=""; grub_dir=""; architecture=""; secure_boot=""; format_version=""
  data=$(_recovery_data read "$path") || return 1
  while IFS=$'\t' read -r key value; do
    case "$key" in
      current_snapshot|recent_backup|boot_backup|grub_config_backup) ;;
      *) printf -v "$key" '%s' "$value" ;;
    esac
  done <<<"$data"
  [[ -n "$root_uuid" || -n "$root_partuuid" ]] || { _recovery_error "Snapshot root filesystem identifier is missing.";return 1; }
  if [[ "$format_version" == 2 ]];then
    [[ "$partition_type" =~ ^(gpt|dos)$ && "$boot_separate" =~ ^(yes|no)$ && -n "$architecture" ]] || return 1
    [[ "$boot_type" != UEFI || ( -n "$esp_uuid" && -n "$esp_partuuid" ) ]] || return 1
  fi
  [[ "$boot_disk" == /dev/* && "$boot_type" =~ ^(UEFI|BIOS)$ && "$grub_dir" =~ ^grub2?$ && "$disk_size" =~ ^[0-9]+$ && "$sector_size" =~ ^[0-9]+$ ]] || { _recovery_error "Snapshot boot metadata is incomplete or unsupported."; return 1; }
}
_recovery_mount() {
  local dev="$1" dest="$2" options="${3:-}"
  [[ ! -L "$dest" ]] || { _recovery_error "Refusing a symlinked mountpoint: $dest"; return 1; }
  mkdir -p -- "$dest" || return 1
  if [[ -n "$options" ]]; then mount -o "$options" -- "$dev" "$dest" || return 1
  else mount -- "$dev" "$dest" || return 1; fi
  _recovery_mounts+=("$dest")
}
_recovery_unmount_all() {
  local i
  for ((i=${#_recovery_mounts[@]}-1;i>=0;i--));do
    if ! umount --recursive -- "${_recovery_mounts[i]}";then
      error "Recovery mount could not be unmounted: ${_recovery_mounts[i]}. Remaining mounts were retained for inspection."
      return 1
    fi
    unset '_recovery_mounts[i]'
  done
  if [[ -n "${_recovery_workspace:-}" ]];then
    rmdir -- "$_recovery_workspace" || { _recovery_error "Recovery workspace is not empty; inspect $_recovery_workspace.";return 1; }
    _recovery_workspace=""
  fi
}
_recovery_cleanup() {
  local rc="$?"
  trap - EXIT
  if ! _recovery_unmount_all;then ((rc!=0)) || rc=1;fi
  exit "$rc"
}
_recovery_btrfs_single() {
  local listing
  _recovery_require btrfs || return 1
  listing=$(LC_ALL=C btrfs filesystem show --raw "$1") || return 1
  [[ "$listing" =~ Total[[:space:]]devices[[:space:]]([0-9]+) ]] && [[ "${BASH_REMATCH[1]}" == 1 ]] || { _recovery_error "Automatic recovery requires a single-device Btrfs filesystem.";return 1; }
}
mount_root() {
  local root_dev
  [[ -n "${_recovery_root:-}" ]] || { _recovery_error "mount_root must run inside a recovery operation."; return 1; }
  root_dev=$(_recovery_resolve "$root_uuid" "$root_partuuid") || return 1
  [[ "$(_recovery_parent_disk "$root_dev")" == "$boot_disk" ]] || { _recovery_error "Root filesystem does not belong to target disk."; return 1; }
  local options="" actual_fs
  actual_fs=$(blkid -s TYPE -o value "$root_dev") || return 1
  [[ -z "$root_fstype" || "$root_fstype" == "$actual_fs" ]] || { _recovery_error "Root filesystem type differs from the snapshot.";return 1; }
  case "$actual_fs" in
    ext2|ext3|ext4|xfs) ;;
    btrfs) _recovery_btrfs_single "$root_dev" || return 1;[[ -n "$root_subvol" ]] || { _recovery_error "Btrfs root subvolume missing from snapshot metadata.";return 1; };;
    *) _recovery_error "Unsupported root filesystem: $actual_fs";return 1;;
  esac
  if [[ -n "$root_subvol" ]]; then
    [[ "$root_subvol" != *[,[:space:]]* ]] || return 1
    options="subvol=$root_subvol"
  fi
  _recovery_mount "$root_dev" "$_recovery_root" "$options"
}
_recovery_target_path() {
  local relative="$1" resolved
  resolved=$(realpath -m -- "$_recovery_root/$relative") || return 1
  [[ "$resolved" == "$_recovery_root/"* && ! -L "$_recovery_root/$relative" ]] || { _recovery_error "Unsafe target path: $relative"; return 1; }
  printf '%s\n' "$resolved"
}
_recovery_grub_tools() {
  local candidate
  _recovery_grub_install=""; _recovery_grub_mkconfig=""
  for candidate in /usr/sbin/grub-install /sbin/grub-install /usr/sbin/grub2-install /sbin/grub2-install; do
    [[ -x "$_recovery_root$candidate" ]] && { _recovery_grub_install="$candidate"; break; }
  done
  for candidate in /usr/sbin/grub-mkconfig /sbin/grub-mkconfig /usr/sbin/grub2-mkconfig /sbin/grub2-mkconfig; do
    [[ -x "$_recovery_root$candidate" ]] && { _recovery_grub_mkconfig="$candidate"; break; }
  done
  [[ -n "$_recovery_grub_install" && -n "$_recovery_grub_mkconfig" ]] || { _recovery_error "GRUB tools missing in target root; use its distribution rescue procedure."; return 1; }
}
_recovery_grub_preflight() {
  local table types
  if [[ "$boot_type" == BIOS ]];then
    case "${architecture:-$(uname -m)}" in x86_64|i?86) ;;*) _recovery_error "Unsupported BIOS GRUB architecture.";return 1;;esac
    table=$(blkid -s PTTYPE -o value "$boot_disk") || return 1
    if [[ "$table" == gpt ]];then
      types=$(lsblk -nrpo PARTTYPE "$boot_disk") || return 1
      grep -Fiq '21686148-6449-6e6f-744e-656564454649' <<<"$types" || { _recovery_error "GPT BIOS recovery requires an existing BIOS Boot Partition; no partition will be created automatically.";return 1; }
    elif [[ "$table" != dos ]];then return 1;fi
  fi
}
_recovery_secure_boot() {
  if ! _recovery_efi_mode;then printf 'no\n';return 0;fi
  python3 - <<'PY_SECURE'
from pathlib import Path
try:
    files=list(Path('/sys/firmware/efi/efivars').glob('SecureBoot-*'))
    values=[f.read_bytes()[4:5] for f in files]
    print('yes' if b'\x01' in values else 'no' if values and all(v==b'\x00' for v in values) else 'unknown')
except OSError:
    print('unknown')
PY_SECURE
}
reinstall_grub() {
  [[ -n "${_recovery_root:-}" ]] || { _recovery_error "reinstall_grub must run inside a recovery operation."; return 1; }
  _recovery_grub_tools || return 1
  local item dest target
  for item in dev proc sys; do
    dest=$(_recovery_target_path "$item") || return 1
    mkdir -p -- "$dest" || return 1
    mount --rbind "/$item" "$dest" || return 1
    _recovery_mounts+=("$dest")
    mount --make-rslave "$dest" || return 1
  done
  info "Reinstalling GRUB using the target system's tools"
  if [[ "$boot_type" == UEFI ]]; then
    case "${architecture:-$(uname -m)}" in
      x86_64) target=x86_64-efi;; aarch64) target=arm64-efi;; i?86) target=i386-efi;;
      *) _recovery_error "Unsupported EFI architecture."; return 1;;
    esac
    chroot "$_recovery_root" "$_recovery_grub_install" --target="$target" --efi-directory=/boot/efi --bootloader-id=GRUB --no-nvram --recheck || return 1
  else
    # Never create partitions or bypass GRUB's embedding checks with --force.
    chroot "$_recovery_root" "$_recovery_grub_install" --target=i386-pc --recheck "$boot_disk" || return 1
  fi
  chroot "$_recovery_root" "$_recovery_grub_mkconfig" -o "/boot/$grub_dir/grub.cfg" || return 1
}
restore_esp() (
  _recovery_require_root || return 1
  local esp="${1:-}" src="${2:-}"
  _recovery_is_block "$esp" && [[ -d "$src" && ! -L "$src" ]] || return 1
  _recovery_require mount umount rsync mktemp python3 lsblk findmnt swapon || return 1
  local disk
  disk=$(_recovery_parent_disk "$esp") || return 1
  _recovery_disk_idle "$disk" || return 1
  _recovery_data legacy-tree "$src" || return 1
  [[ -z "$(findmnt -rn -S "$esp")" ]] || { _recovery_error "ESP is already mounted."; return 1; }
  local -a _recovery_mounts=()
  local _recovery_workspace
  _recovery_workspace=$(mktemp -d /run/one-click-esp-restore.XXXXXX) || return 1
  trap _recovery_cleanup EXIT
  _recovery_mount "$esp" "$_recovery_workspace" || return 1
  rsync -rlt --delete -- "$src/" "$_recovery_workspace/" || return 1
)
# ==== Backup: boot files and partition metadata (not a system image) ====
recovery_backup() (
  _recovery_require_root && _recovery_paths || return 1
  _recovery_require python3 findmnt lsblk blkid blockdev sfdisk mountpoint rsync mktemp flock mount umount swapon || return 1
  _recovery_prepare_base || return 1
  local lock_fd
  _recovery_data safe-lock "$recovery_base/.operation.lock" || return 1
  exec {lock_fd}>"$recovery_base/.operation.lock" || return 1
  chmod 0600 "$recovery_base/.operation.lock" || return 1
  flock -n "$lock_fd" || { _recovery_error "Another boot-recovery operation is running."; return 1; }
  local disk root_dev boot_dev timestamp out_path esp="" esp_mnt="" cont table_type root_options subvol="" secure="no"
  disk=$(detect_boot_disk) || return 1
  root_dev=$(_recovery_mounted_source /) || return 1
  [[ "$(_recovery_parent_disk "$root_dev")" == "$disk" ]] || { _recovery_error "Root and boot must use the same single physical disk."; return 1; }
  case "${non_interactive:-0}" in
    1|true|yes) ;;
    0|false|no|'')
      warn "Back up boot files and partition metadata (not the whole system)."
      read -rp "${cyan:-}[USER]${reset:-} Proceed [y|n]: " cont || return 1
      [[ "${cont,,}" == y || "${cont,,}" == yes ]] || return 1;;
    *) _recovery_error "non_interactive must be 0/1, false/true or no/yes."; return 1;;
  esac
  table_type=$(blkid -s PTTYPE -o value "$disk") || return 1
  [[ "$table_type" == gpt || "$table_type" == dos ]] || { _recovery_error "Unsupported partition table."; return 1; }
  [[ "$table_type" != gpt ]] || _recovery_require sgdisk || return 1
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  out_path=$(mktemp -d "$recovery_base/$timestamp.XXXXXX") || return 1
  chmod 0700 "$out_path" || return 1
  local -a _recovery_mounts=()
  local _recovery_workspace=""
  trap _recovery_cleanup EXIT
  local boot_separate=no boot_uuid="" boot_partuuid="" grub_layout
  if mountpoint -q /boot; then
    boot_separate=yes;boot_dev=$(_recovery_mounted_source /boot) || return 1
    boot_uuid=$(blkid -s UUID -o value "$boot_dev") || return 1
    boot_partuuid=$(blkid -s PARTUUID -o value "$boot_dev") || boot_partuuid=""
  fi
  if [[ -d /boot/grub2 ]]; then grub_layout=grub2
  elif [[ -d /boot/grub ]]; then grub_layout=grub
  else _recovery_error "No GRUB boot directory found."; return 1; fi
  root_options=$(findmnt -nro OPTIONS --target /) || return 1
  local source_fs
  source_fs=$(blkid -s TYPE -o value "$root_dev") || return 1
  case "$source_fs" in ext2|ext3|ext4|xfs) ;;btrfs) _recovery_btrfs_single "$root_dev" || return 1;;*) _recovery_error "Unsupported root filesystem: $source_fs";return 1;;esac
  if [[ "$source_fs" == btrfs ]]; then
    IFS=',' read -ra opts <<<"$root_options"
    for cont in "${opts[@]}"; do [[ "$cont" == subvol=* ]] && subvol="${cont#subvol=}"; done
    [[ -n "$subvol" ]] || { _recovery_error "Btrfs root subvolume could not be identified."; return 1; }
  fi
  local boot_mode=BIOS esp_uuid="" esp_partuuid="" arch
  arch=$(uname -m) || return 1
  if _recovery_efi_mode; then
    boot_mode=UEFI;esp=$(detect_esp "$disk") || return 1
    esp_uuid=$(blkid -s UUID -o value "$esp") || return 1
    esp_partuuid=$(blkid -s PARTUUID -o value "$esp") || return 1
    secure=$(_recovery_secure_boot) || return 1
  fi
  local saved_root_uuid saved_root_partuuid saved_root_type saved_storage_type saved_size saved_sector saved_model saved_serial saved_wwn
  saved_root_uuid=$(blkid -s UUID -o value "$root_dev") || return 1
  [[ -n "$saved_root_uuid" ]] || return 1
  saved_root_partuuid=$(blkid -s PARTUUID -o value "$root_dev") || saved_root_partuuid=""
  saved_root_type=$(blkid -s TYPE -o value "$root_dev") || return 1
  saved_storage_type=$(lsblk -dno TYPE "$root_dev") || return 1
  saved_size=$(blockdev --getsize64 "$disk") || return 1
  saved_sector=$(blockdev --getss "$disk") || return 1
  saved_model=$(lsblk -dno MODEL "$disk") || return 1
  saved_serial=$(lsblk -dno SERIAL "$disk") || return 1
  saved_wwn=$(lsblk -dno WWN "$disk") || return 1
  _recovery_data save-map "$out_path/recovery_map.json" \
    "format_version=2" "current_snapshot=$out_path" "boot_disk=$disk" \
    "disk_model=$saved_model" "disk_serial=$saved_serial" "disk_wwn=$saved_wwn" \
    "disk_size=$saved_size" "sector_size=$saved_sector" "partition_type=$table_type" \
    "root_uuid=$saved_root_uuid" "root_partuuid=$saved_root_partuuid" \
    "root_fstype=$saved_root_type" "root_subvol=$subvol" "root_device_type=$saved_storage_type" \
    "boot_separate=$boot_separate" "boot_uuid=$boot_uuid" "boot_partuuid=$boot_partuuid" \
    "boot_type=$boot_mode" "esp_part=$esp" "esp_uuid=$esp_uuid" "esp_partuuid=$esp_partuuid" "esp_mount=/boot/efi" \
    "grub_dir=$grub_layout" "architecture=$arch" "secure_boot=$secure" "boot_backup=yes" "grub_config_backup=yes" || return 1
  sfdisk --dump "$disk" >"$out_path/partition_table.txt" || return 1
  if [[ "$table_type" == gpt ]]; then sgdisk --backup="$out_path/layout.bin" "$disk" || return 1; fi
  if [[ "$boot_mode" == BIOS ]]; then
    dd if="$disk" of="$out_path/bootcode.bin" bs=446 count=1 status=none || return 1
    [[ "$(stat -c %s "$out_path/bootcode.bin")" == 446 ]] || return 1
  fi
  mkdir -p -- "$out_path/boot" "$out_path/grub/etc" || return 1
  rsync -aHAX --numeric-ids --exclude='/efi/***' -- /boot/ "$out_path/boot/" || return 1
  [[ ! -f /etc/default/grub ]] || cp -a -- /etc/default/grub "$out_path/grub/etc/grub" || return 1
  if [[ -d /etc/grub.d ]]; then rsync -aHAX --numeric-ids -- /etc/grub.d/ "$out_path/grub/etc/grub.d/" || return 1; fi
  if [[ "$boot_mode" == UEFI ]]; then
    esp_mnt=$(findmnt -rn -S "$esp" -o TARGET) || true
    if [[ "$esp_mnt" == *$'\n'* ]]; then _recovery_error "ESP has multiple mountpoints."; return 1; fi
    if [[ -z "$esp_mnt" ]]; then
      _recovery_workspace=$(mktemp -d /run/one-click-esp-backup.XXXXXX) || return 1
      _recovery_mount "$esp" "$_recovery_workspace" ro || return 1
      esp_mnt="$_recovery_workspace"
    fi
    mkdir -p "$out_path/esp" || return 1
    rsync -rlt -- "$esp_mnt/" "$out_path/esp/" || return 1
  fi
  chmod -R go-w -- "$out_path" || return 1
  _recovery_unmount_all || return 1
  _recovery_data seal "$out_path" && _recovery_data verify "$out_path" || return 1
  sync -f "$out_path" || return 1
  _recovery_data latest "$recovery_config" "$out_path" || return 1
  success "Boot recovery backup completed: $out_path"
)
recovery_verify() {
  _recovery_require_root && _recovery_require python3 || return 1
  [[ -n "${1:-}" ]] || { _recovery_error "Usage: recovery_verify <snapshot-directory>";return 1; }
  _recovery_data verify "$1" || return 1
  success "Boot recovery snapshot integrity verified: $1"
}
recovery_restore() (
  _recovery_require_root && _recovery_paths || return 1
  _recovery_require python3 findmnt lsblk blkid blockdev mount umount mountpoint rsync chroot mktemp realpath swapon flock || return 1
  local snap_path="" override_disk="" restore_layout=0 allow_legacy=0 arg
  while (($#)); do
    case "$1" in
      --disk) [[ $# -ge 2 ]] || return 1;override_disk="$2";shift 2;;
      --restore-layout) restore_layout=1;shift;;
      --allow-legacy) allow_legacy=1;shift;;
      --*) _recovery_error "Unknown restore option: $1";return 1;;
      *) [[ -z "$snap_path" ]] || return 1;snap_path="$1";shift;;
    esac
  done
  if [[ -z "$snap_path" && -f "$recovery_config" ]]; then
    local latest key value
    latest=$(_recovery_data read "$recovery_config") || return 1
    while IFS=$'\t' read -r key value; do
      [[ "$key" != recent_backup && "$key" != current_snapshot ]] || snap_path="$value"
    done <<<"$latest"
  fi
  if [[ -z "$snap_path" ]]; then
    local -a snapshots=();local sel dir
    [[ -d "$recovery_base" ]] || { _recovery_error "No recovery snapshots found.";return 1; }
    for dir in "$recovery_base"/*/; do
      [[ -f "$dir/recovery_map.json" || -f "$dir/recovery_map.conf" ]] && snapshots+=("${dir%/}")
    done
    ((${#snapshots[@]})) || { _recovery_error "No recovery snapshots found.";return 1; }
    for ((sel=0;sel<${#snapshots[@]};sel++));do printf '%d) %s\n' "$((sel+1))" "${snapshots[sel]}";done
    read -rp "${cyan:-}[USER]${reset:-} Select snapshot [1-${#snapshots[@]}]: " sel || return 1
    [[ "$sel" =~ ^[1-9][0-9]{0,5}$ ]] && ((10#$sel<=${#snapshots[@]})) || return 1
    snap_path="${snapshots[10#$sel-1]}"
  fi
  _recovery_data secure-dir "$snap_path" || return 1
  snap_path=$(realpath -e -- "$snap_path") || return 1
  local lock_fd
  _recovery_prepare_base || return 1
  _recovery_data safe-lock "$recovery_base/.operation.lock" || return 1
  exec {lock_fd}>"$recovery_base/.operation.lock" || return 1
  chmod 0600 "$recovery_base/.operation.lock" || return 1
  flock -n "$lock_fd" || { _recovery_error "Another boot-recovery operation is running.";return 1; }
  if [[ -f "$snap_path/recovery_map.json" ]]; then
    _recovery_data verify "$snap_path" || return 1
    _recovery_load_map "$snap_path/recovery_map.json" || return 1
  else
    ((allow_legacy)) || { _recovery_error "Legacy snapshot has no integrity manifest. Re-run with --allow-legacy only after reviewing it.";return 1; }
    _recovery_data legacy-tree "$snap_path" || return 1
    _recovery_load_map "$snap_path/recovery_map.conf" || return 1
    warn "Legacy snapshot: integrity cannot be verified against its original backup."
  fi
  local recorded_disk="$boot_disk" actual_size actual_sector identity confirm
  [[ -z "$override_disk" ]] || boot_disk="$override_disk"
  boot_disk=$(readlink -f -- "$boot_disk") || return 1
  _recovery_is_block "$boot_disk" && [[ "$(lsblk -dno TYPE "$boot_disk")" == disk ]] || { _recovery_error "Restore target must be a whole physical disk.";return 1; }
  actual_size=$(blockdev --getsize64 "$boot_disk") || return 1
  actual_sector=$(blockdev --getss "$boot_disk") || return 1
  [[ "$actual_size" == "$disk_size" && "$actual_sector" == "$sector_size" ]] || { _recovery_error "Target disk size/sector geometry differs from the snapshot.";return 1; }
  if [[ -z "$override_disk" && -n "$disk_wwn" ]]; then
    identity=$(lsblk -dno WWN "$boot_disk") || return 1
    [[ "$identity" == "$disk_wwn" ]] || { _recovery_error "Target disk WWN differs; choose --disk explicitly after checking the device.";return 1; }
  elif [[ -z "$override_disk" && -n "$disk_serial" ]]; then
    identity=$(lsblk -dno SERIAL "$boot_disk") || return 1
    [[ "$identity" == "$disk_serial" ]] || { _recovery_error "Target disk serial differs; choose --disk explicitly after checking the device.";return 1; }
  fi
  _recovery_disk_idle "$boot_disk" || return 1
  if ((restore_layout)) && [[ -z "$override_disk" && -z "$disk_wwn" && -z "$disk_serial" ]];then
    _recovery_error "No persistent disk identity recorded. Partition recovery requires an explicit --disk target.";return 1
  fi
  [[ -z "$architecture" || "$architecture" == "$(uname -m)" ]] || { _recovery_error "Rescue and target architectures differ.";return 1; }
  if [[ "$boot_type" == UEFI && "$(_recovery_secure_boot)" != no ]];then
    _recovery_error "Rescue firmware Secure Boot state is enabled or unknown; generic GRUB replacement is unavailable.";return 1
  fi
  [[ "$secure_boot" != yes ]] || { _recovery_error "Secure Boot snapshot: use the distribution's signed-loader recovery procedure; this module will not replace it with generic GRUB.";return 1; }
  { [[ "$boot_type" != UEFI ]] || _recovery_efi_mode; } || { _recovery_error "Boot the rescue environment in UEFI mode for EFI recovery.";return 1; }
  if ((restore_layout)); then
    [[ "$root_device_type" == part || "$root_device_type" == disk ]] || { _recovery_error "Combined partition/boot recovery requires a plain root device; LVM/crypt activation must be handled separately.";return 1; }
    _recovery_require sfdisk partprobe udevadm || return 1
    [[ -n "$partition_type" ]] || { _recovery_error "Legacy layout metadata is incomplete; automatic partition recovery is unavailable.";return 1; }
    [[ "$partition_type" != gpt ]] || _recovery_require sgdisk || return 1
    [[ -f "$snap_path/partition_table.txt" && ( "$partition_type" != gpt || -f "$snap_path/layout.bin" ) ]] || return 1
    local types
    types=$(lsblk -nrpo TYPE "$boot_disk") || return 1
    if grep -Eq '^(lvm|crypt|raid.*|md)$' <<<"$types";then _recovery_error "Deactivate LVM/crypt/RAID mappings before partition-table recovery.";return 1;fi
    warn "Partition-table recovery replaces the disk layout. It does not restore root filesystem data."
  else
    info "Boot-file recovery: partition layout and raw BIOS sectors will not be rewritten."
  fi
  [[ -d "$snap_path/boot" && ! -L "$snap_path/boot" ]] || return 1
  [[ "$boot_type" != UEFI || ( -d "$snap_path/esp" && ! -L "$snap_path/esp" ) ]] || return 1
  warn "Restore $snap_path to $boot_disk. Existing boot files will be replaced."
  read -rp "${cyan:-}[USER]${reset:-} Type CONFIRM $boot_disk to proceed: " confirm || return 1
  [[ "$confirm" == "CONFIRM $boot_disk" ]] || { _recovery_error "Restore aborted.";return 1; }
  _recovery_disk_idle "$boot_disk" || return 1
  if ((restore_layout)); then
    if [[ "$partition_type" == gpt ]];then sgdisk --load-backup="$snap_path/layout.bin" "$boot_disk" || return 1
    else sfdisk "$boot_disk" <"$snap_path/partition_table.txt" || return 1;fi
    partprobe "$boot_disk" && udevadm settle || return 1
  fi
  _recovery_grub_preflight || return 1
  local -a _recovery_mounts=()
  local _recovery_workspace _recovery_root boot_dest efi_dest etc_dest boot_dev spec esp_dev
  _recovery_workspace=$(mktemp -d /run/one-click-recovery.XXXXXX) || return 1
  _recovery_root="$_recovery_workspace"
  trap _recovery_cleanup EXIT
  mount_root || return 1
  boot_dest=$(_recovery_target_path boot) || return 1
  if [[ -z "$boot_separate" ]];then
    spec=$(_recovery_data fstab "$_recovery_root/etc/fstab") || return 1
    case "$spec" in
      UUID=*) boot_uuid="${spec#UUID=}";boot_separate=yes;;
      PARTUUID=*) boot_partuuid="${spec#PARTUUID=}";boot_separate=yes;;
      /dev/*) boot_dev=$(readlink -f -- "$spec") || return 1;boot_separate=yes;;
      '') boot_separate=no;;
      *) _recovery_error "Legacy /boot fstab source cannot be resolved safely.";return 1;;
    esac
  fi
  if [[ "$boot_separate" == yes ]];then
    [[ -n "${boot_dev:-}" ]] || boot_dev=$(_recovery_resolve "$boot_uuid" "$boot_partuuid") || return 1
    [[ "$(_recovery_parent_disk "$boot_dev")" == "$boot_disk" ]] || return 1
    _recovery_mount "$boot_dev" "$boot_dest" || return 1
  elif [[ "$boot_separate" != no ]];then return 1;fi
  if [[ "$boot_type" == UEFI ]];then
    if [[ -z "$esp_uuid" && -z "$esp_partuuid" ]];then
      _recovery_is_block "$esp_part" || return 1
      esp_dev=$(readlink -f -- "$esp_part") || return 1
    else esp_dev=$(_recovery_resolve "$esp_uuid" "$esp_partuuid") || return 1;fi
    [[ "$(_recovery_parent_disk "$esp_dev")" == "$boot_disk" ]] || return 1
    [[ "$(lsblk -dno PARTTYPE "$esp_dev")" == c12a7328-f81f-11d2-ba4b-00a0c93ec93b ]] || return 1
    efi_dest=$(_recovery_target_path boot/efi) || return 1
    _recovery_mount "$esp_dev" "$efi_dest" || return 1
  fi
  _recovery_grub_tools || return 1
  etc_dest=$(_recovery_target_path etc) || return 1
  [[ -d "$etc_dest/default" && ! -L "$etc_dest/default" && ! -L "$etc_dest/default/grub" && ! -L "$etc_dest/grub.d" ]] || return 1
  # Exclude the already-mounted ESP from the /boot --delete traversal.
  rsync -aHAX --numeric-ids --exclude='/efi/***' --delete -- "$snap_path/boot/" "$boot_dest/" || return 1
  if [[ "$boot_type" == UEFI ]];then rsync -rlt --delete -- "$snap_path/esp/" "$efi_dest/" || return 1;fi
  if [[ -f "$snap_path/grub/etc/grub" ]];then cp -a -- "$snap_path/grub/etc/grub" "$etc_dest/default/grub" || return 1;fi
  if [[ -d "$snap_path/grub/etc/grub.d" ]];then rsync -aHAX --numeric-ids --delete -- "$snap_path/grub/etc/grub.d/" "$etc_dest/grub.d/" || return 1;fi
  # GRUB installation recreates bootcode; never write the legacy 446-byte blob.
  reinstall_grub || return 1
  sync || return 1
  _recovery_unmount_all || return 1
  success "Boot-file restoration and GRUB commands completed: $snap_path"
  info "Recovery mounts were cleaned up. Check firmware boot entries if needed before rebooting."
)
recovery_menu() {
  _recovery_paths || return 1
  header_notice "${recovery_header:-}" "${recovery_banner:-}" "6" "11"
  local backup_run
  while true;do
    clear
    printf '\n%s\n' "${yellow:-}[${green:-}ONE-CLICK BOOT RECOVERY${yellow:-}]${reset:-}" 
    info "Capture and restore boot files and partition metadata. This is not a whole-system backup."
    printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
     '[1]. Backup' \
     '[2]. Restore' \
     '[3]. Display Snapshot Directory' \
     '[4]. Configure Cron' \
     '[0]. Exit'
    read -rp "${cyan:-}[USER]${reset:-} Select an option [0-4]: " backup_run || return 1
    case "$backup_run" in
      1) recovery_backup || error "Boot recovery backup did not complete."   ;;
      2) recovery_restore || error "Boot recovery restore did not complete." ;;
      3) 
        if [[ -d "$recovery_base" ]];then
          ls_table "$recovery_base"
        else 
          warn "No snapshots found"
        fi
        ;;
      4) install_cron "-y" "Boot Recovery Tool" "r"                 ;;
      0) ( sleep 0.5 && tmux kill-session -t "one-click" ) & exit 0 ;;
      *) error "Invalid selection"                                  ;;
    esac
    read -rp "${cyan:-}[USER]${reset:-} Press enter to continue: "
  done
}
# ==== End Boot Recovery ==== #
