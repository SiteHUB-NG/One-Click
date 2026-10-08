#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK NET-REPAIR MOD* reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ========================== #================================================ #
# === Build: Jan 2026 === # === Updated: Oct 2026 == # === Version#: 1.0.0 === #
# ====== One-Click ====== #
# ==== Network Repair ====
# One-Click Network Repair. This module is sourced by the existing parent script.
# Intentional contract: menu cancellation/back => 0; a failed real operation => 1.
# A failed health assessment communicates via skip_check / skip_reason and returns 0.
net_repair_init() {
  # The parent One-Click script also defines base_dir, config_dir, backup_dir.
  # Never reuse them here: they belong to other hosting/migration modules.
  net_repair_root="${net_repair_root:-/etc/one-click/network-repair}"
  backup_dir="$net_repair_root/backups"
  snaps_dir="$net_repair_root/snapshots"
  config_dir="$net_repair_root/config"
  service_restore="$snaps_dir/service-restore.txt"
  local p
  for p in "$net_repair_root" "$backup_dir" "$snaps_dir" "$config_dir"; do
    if [[ "$p" != /* || "$p" == / || "/$p/" == *'/../'* || "$p" == /etc || "$p" == /var || "$p" == /usr ]]; then
      printf '[ERROR] Unsafe network-repair storage path: %s\n' "$p" >&2
      return 1
    fi
  done
  mkdir -p -- "$net_repair_root" "$backup_dir/sets" "$snaps_dir/sets" "$config_dir" || return 1
  chmod 700 "$backup_dir" "$backup_dir/sets" "$snaps_dir" "$snaps_dir/sets" "$config_dir" 2>/dev/null || return 1
}

net_note() { printf '[INFO] %s\n' "$*"; }
net_warn() { printf '[WARN] %s\n' "$*" >&2; }
net_fail() { printf '[ERROR] %s\n' "$*" >&2; }
net_yes() {
  local answer
  read -r -p "${1} [y/N]: " answer || return 1
  case "${answer,,}" in y|yes) return 0;; *) return 1;; esac
}
# Extra opt-in, independent from the restore confirmation.
net_console_authorized() {
  local answer
  net_warn 'This can interrupt SSH or change active network/firewall state.'
  net_warn 'Use ONLY with verified out-of-band/console access and a recovery plan.'
  read -r -p 'Type CONSOLE to confirm independent recovery access: ' answer || return 1
  [[ "$answer" == CONSOLE ]]
}
net_id() { date -u +%Y%m%dT%H%M%S-%N; }

timestamp() { date +%Y%m%d-%H%M%S; }
network_select_option() {
  printf '%s\n' \
    'NETWORK REPAIR | Please verify backup and console access before restoring' \
    '[1]. Health Check / Repair Network' \
    '[2]. Backup Network Configs' \
    '[3]. Capture State Snapshot' \
    '[4]. Display Backup Contents' \
    '[5]. Display Snapshot Contents' \
    '[6]. Restore Network Configs' \
    '[7]. Configure cron for snapshots' \
    '[0]. Back'
  read -r -p '[USER] Select an option: ' repair_select
}
primary_iface() {
  local route
  route="$(ip -4 route show default 2>/dev/null | head -n 1)"
  if [[ " $route " =~ [[:space:]]dev[[:space:]]([^[:space:]]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  ip -o link show up 2>/dev/null | awk -F': ' '$2 != "lo" {sub(/@.*/, "", $2);print $2;exit}'
}
have_dns() {
  getent ahostsv4 cloudflare.com >/dev/null 2>&1 || getent hosts example.com >/dev/null 2>&1
}
net_ipv4_probe() {
  ping -4 -c1 -W2 1.1.1.1 >/dev/null 2>&1 ||
    { command -v curl >/dev/null 2>&1 && curl -4 -fsSI --connect-timeout 3 --max-time 5 https://1.1.1.1/ -o /dev/null >/dev/null 2>&1; }
}
net_ipv6_probe() {
  ping -6 -c1 -W2 2606:4700:4700::1111 >/dev/null 2>&1
}
have_net() {
  net_ipv4_probe || { ip -6 route show default 2>/dev/null | grep -q . && net_ipv6_probe; }
}

# Backup format: sets/<id>/{data,etc paths,manifest.tsv,SHA256SUMS,COMPLETE}.
# Original directories (including NetworkManager connection profiles) remain directories.
backup_file() {
  local original="${1:-}" root="${net_backup_dest:-}" rel parent verify
  [[ -n "$root" && "$original" == /etc/* ]] || return 1
  [[ -e "$original" || -L "$original" ]] || return 0
  rel="${original#/}"; parent="$(dirname -- "$rel")"
  mkdir -p -- "$root/data/$parent" || return 1
  rsync -aH -- "$original" "$root/data/$parent/" || return 1
  verify="$(rsync -aHnci -- "$original" "$root/data/$parent/" 2>/dev/null)" || return 1
  [[ -z "$verify" ]] || { net_fail "Verification differed: $original"; return 1; }
  printf 'etc\t%s\n' "$rel" >> "$root/manifest.tsv"
}
net_hash_set() {
  local set="$1"
  ( cd "$set/data" || exit 1
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum
  ) > "$set/SHA256SUMS" || return 1
  (cd "$set/data" || exit 1
   find . -type l -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' link; do
     printf '%q	%q
' "$link" "$(readlink -- "$link")"
   done
  ) > "$set/SYMLINKS" || return 1
  [[ -s "$set/manifest.tsv" && ( -s "$set/SHA256SUMS" || -s "$set/SYMLINKS" ) ]] || return 1
}
net_validate_set() {
  local set="${1:-}" rel category count=0
  [[ -d "$set/data/etc" && -f "$set/SHA256SUMS" && -f "$set/SYMLINKS" && -s "$set/manifest.tsv" && -f "$set/COMPLETE" ]] || return 1
  [[ -s "$set/SHA256SUMS" || -s "$set/SYMLINKS" ]] || return 1
  while IFS=$'\t' read -r category rel; do
    [[ "$category" == etc && "$rel" == etc/* && "$rel" != *'..'* && "$rel" != /* ]] || return 1
    [[ -e "$set/data/$rel" || -L "$set/data/$rel" ]] || return 1
    count=$((count+1))
  done < "$set/manifest.tsv"
  (( count > 0 )) || return 1
  if [[ -s "$set/SHA256SUMS" ]]; then
    (cd "$set/data" && sha256sum -c --status ../SHA256SUMS) || return 1
  fi
  cmp -s -- "$set/SYMLINKS" <(
    cd "$set/data" || exit 1
    find . -type l -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' link; do
      printf '%q	%q
' "$link" "$(readlink -- "$link")"
    done
  ) || return 1
}
net_latest_set() {
  local root="$1" target
  [[ -L "$root/latest" ]] || return 1
  target="$(readlink -f -- "$root/latest")" || return 1
  [[ "$target" == "$root/sets/"* && -d "$target" ]] || return 1
  printf '%s\n' "$target"
}
net_publish_set() {
  local root="$1" set="$2" link="$root/.latest.$$"
  ln -s -- "sets/$(basename -- "$set")" "$link" || return 1
  mv -Tf -- "$link" "$root/latest" || { rm -f -- "$link"; return 1; }
}
backup_all_configs() (
  umask 077
  local new root id item copied=0 failed=0
  local -a sources=(
    /etc/hosts /etc/resolv.conf /etc/hostname
    /etc/sysctl.conf /etc/sysctl.d
    /etc/NetworkManager
    /etc/network /etc/netplan /etc/sysconfig/network /etc/sysconfig/network-scripts
    /etc/iptables /etc/nftables.conf /etc/nftables.d /etc/sysconfig/nftables.conf
    /etc/systemd/resolved.conf /etc/systemd/network /etc/ufw /etc/firewalld
  )
  net_repair_init || return 1
  root="$backup_dir"
  id="$(net_id)-$$"
  new="$root/sets/$id"
  mkdir -m 700 -p -- "$new/data" || return 1
  : > "$new/manifest.tsv" || return 1
  net_backup_dest="$new"
  for item in "${sources[@]}"; do
    [[ -e "$item" || -L "$item" ]] || continue
    if backup_file "$item"; then copied=$((copied+1)); else failed=$((failed+1)); net_fail "Backup failed: $item"; fi
  done
  unset net_backup_dest
  if (( failed > 0 || copied == 0 )) || ! net_hash_set "$new"; then
    net_fail "Incomplete backup kept for examination: $new (previous latest unchanged)"
    return 1
  fi
  # Diagnostic commands do not alter network state and must not invalidate a good config set.
  mkdir -p -- "$new/diagnostics"
  ip -4 address show > "$new/diagnostics/ip4-address.txt" 2>/dev/null || true
  ip -6 address show > "$new/diagnostics/ip6-address.txt" 2>/dev/null || true
  ip -4 route show > "$new/diagnostics/ip4-route.txt" 2>/dev/null || true
  ip -6 route show > "$new/diagnostics/ip6-route.txt" 2>/dev/null || true
  ip rule show > "$new/diagnostics/ip-rule.txt" 2>/dev/null || true
  command -v resolvconf >/dev/null 2>&1 && resolvconf -l > "$new/diagnostics/resolvconf.txt" 2>/dev/null || true
  command -v resolvectl >/dev/null 2>&1 && resolvectl status > "$new/diagnostics/resolvectl.txt" 2>/dev/null || true
  : > "$new/COMPLETE"
  if ! net_validate_set "$new" || ! net_publish_set "$root" "$new"; then
    net_fail "Backup verification/publish failed; previous latest is untouched: $new"
    return 1
  fi
  net_note "Verified network backup: $new"
  return 0
)

# Source-driven snapshot archives: never apply firewall rules while capturing.
net_snap_component() {
  local set="$1" component="$2"; shift 2
  local src existing=() rel=() candidate archive
  for candidate in "$@"; do
    [[ -e "$candidate" || -L "$candidate" ]] && existing+=("$candidate")
  done
  (( ${#existing[@]} )) || return 0
  for src in "${existing[@]}"; do
    [[ "$src" == /etc/* ]] || return 1
    rel+=("${src#/}")
  done
  archive="$set/archives/$component.tar.gz"
  tar -C / -czf "$archive" -- "${rel[@]}" 2>/dev/null || return 1
  tar -tzf "$archive" >/dev/null 2>&1 || return 1
  sha256sum "$archive" | awk '{print $1}' > "$archive.sha256" || return 1
  printf '%s\t%s\n' "$component" "archives/$component.tar.gz" >> "$set/manifest.tsv"
}
net_validate_archive() {
  local archive="$1" entry hash
  [[ -f "$archive" && -f "$archive.sha256" ]] || return 1
  hash="$(sha256sum "$archive" | awk '{print $1}')" || return 1
  [[ "$hash" == "$(cat "$archive.sha256")" ]] || return 1
  while IFS= read -r entry; do
    [[ "$entry" == etc/* && "$entry" != *'..'* && "$entry" != /* ]] || return 1
  done < <(tar -tzf "$archive")
  tar -tzf "$archive" >/dev/null 2>&1
}
net_validate_snapshot() {
  local set="$1" component rel found=0
  [[ -f "$set/COMPLETE" && -s "$set/manifest.tsv" ]] || return 1
  while IFS=$'\t' read -r component rel; do
    case "$component" in firewalld|nft|iptables|ufw|nm|netplan|ifup|networkd|suse) ;; *) return 1;; esac
    [[ "$rel" == "archives/$component.tar.gz" ]] || return 1
    net_validate_archive "$set/$rel" || return 1
    found=$((found+1))
  done < "$set/manifest.tsv"
  (( found > 0 ))
}
snapshot_state() (
  umask 077
  local id set root failed=0
  net_repair_init || return 1
  root="$snaps_dir"; id="$(net_id)-$$"; set="$root/sets/$id"
  mkdir -m 700 -p -- "$set/archives" "$set/state" || return 1
  : > "$set/manifest.tsv"
  if systemctl is-active --quiet firewalld 2>/dev/null; then
    net_snap_component "$set" firewalld /etc/firewalld || failed=1
    command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --list-all-zones > "$set/state/firewalld-runtime.txt" 2>/dev/null || true
  fi
  if command -v nft >/dev/null 2>&1; then
    net_snap_component "$set" nft /etc/nftables.conf /etc/nftables.d /etc/sysconfig/nftables.conf || failed=1
    nft list ruleset > "$set/state/nftables.rules" 2>/dev/null || true
  fi
  if command -v iptables-save >/dev/null 2>&1; then
    net_snap_component "$set" iptables /etc/iptables /etc/sysconfig/iptables /etc/sysconfig/ip6tables || failed=1
    iptables-save > "$set/state/iptables.v4" 2>/dev/null || true
    command -v ip6tables-save >/dev/null 2>&1 && ip6tables-save > "$set/state/iptables.v6" 2>/dev/null || true
  fi
  if command -v ufw >/dev/null 2>&1; then
    net_snap_component "$set" ufw /etc/ufw || failed=1
  fi
  if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    net_snap_component "$set" nm /etc/NetworkManager /etc/sysconfig/network-scripts || failed=1
  fi
  if command -v netplan >/dev/null 2>&1; then
    net_snap_component "$set" netplan /etc/netplan || failed=1
  fi
  if command -v ifup >/dev/null 2>&1; then
    net_snap_component "$set" ifup /etc/network || failed=1
  fi
  if systemctl is-active --quiet systemd-networkd 2>/dev/null; then
    net_snap_component "$set" networkd /etc/systemd/network || failed=1
  fi
  if systemctl is-active --quiet wicked 2>/dev/null; then
    net_snap_component "$set" suse /etc/sysconfig/network || failed=1
  fi
  if (( failed > 0 )) || [[ ! -s "$set/manifest.tsv" ]]; then
    net_fail "Snapshot incomplete (previous snapshot preserved): $set"
    return 1
  fi
  : > "$set/COMPLETE"
  net_validate_snapshot "$set" && net_publish_set "$root" "$set" || {
    net_fail "Snapshot validation failed; previous latest is unchanged: $set"
    return 1
  }
  net_note "Read-only network/firewall snapshot verified: $set"
  return 0
)

# Restore only a validated set made by this module. Avoid --delete on destination.
net_restore_copy_set() {
  local set="$1" category rel saved failed=0
  while IFS=$'\t' read -r category rel; do
    [[ "$category" == etc && "$rel" == etc/* && "$rel" != *'..'* ]] || return 1
    saved="$set/data/$rel"
    mkdir -p -- "/$(dirname "$rel")" || { failed=1; continue; }
    if [[ -d "$saved" && ! -L "$saved" ]]; then
      mkdir -p -- "/$rel" || { failed=1; continue; }
      rsync -aH -- "$saved/" "/$rel/" || failed=1
    else
      cp -a --remove-destination -- "$saved" "/$rel" || failed=1
    fi
  done < "$set/manifest.tsv"
  (( failed == 0 ))
}
net_restore_snapfiles() {
  local set="$1" component rel
  while IFS=$'\t' read -r component rel; do
    net_validate_archive "$set/$rel" || return 1
    tar -xzf "$set/$rel" -C / || return 1
  done < "$set/manifest.tsv"
}
net_apply_services() {
  local manager choice
  net_warn 'Configuration files restored. Active services have NOT been reloaded.'
  printf '%s\n' 'Choose ONE manager only; leave the rest untouched:' \
    '[0] Do not apply (recommended over SSH)' \
    '[1] NetworkManager' '[2] systemd-networkd' '[3] netplan' \
    '[4] ifupdown networking' '[5] wicked' '[6] firewalld'
  read -r -p 'Manager to apply [0]: ' choice || return 0
  [[ "$choice" == [1-6] ]] || return 0
  net_console_authorized || { net_warn 'Active configuration left unchanged.'; return 0; }
  net_yes "Apply selected manager $choice now?" || return 0
  case "$choice" in
    1) systemctl restart NetworkManager ;;
    2) systemctl restart systemd-networkd ;;
    3) netplan generate && netplan apply ;;
    4) systemctl restart networking ;;
    5) systemctl restart wicked ;;
    6) systemctl restart firewalld ;;
  esac
}
restore_backup() (
  umask 077
  local rollback_set="" source_kind source_set reply root idx i
  local -a sets=()
  net_repair_init || return 1
  printf '%s\n' '[1] Restore a versioned configuration backup' '[2] Restore a versioned snapshot' '[0] Cancel'
  read -r -p 'Choose recovery source: ' reply || return 0
  case "$reply" in
    0|'') return 0 ;;
    1) source_kind=config; root="$backup_dir" ;;
    2) source_kind=snapshot; root="$snaps_dir" ;;
    *) net_warn 'Invalid restore selection'; return 0 ;;
  esac
  mapfile -t sets < <(find "$root/sets" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort -r)
  (( ${#sets[@]} )) || { net_fail 'No versioned recovery sets exist'; return 1; }
  printf '%s\n' 'Available recovery sets (newest first):'
  for (( i=0; i<${#sets[@]}; i++ )); do printf '[%d] %s\n' "$((i+1))" "${sets[i]}"; done
  printf '[0] Cancel\n'
  read -r -p 'Choose recovery set: ' reply || return 0
  [[ "$reply" =~ ^[0-9]+$ ]] || { net_warn 'Invalid set number'; return 0; }
  idx=$((10#$reply))
  (( idx > 0 )) || return 0
  (( idx <= ${#sets[@]} )) || { net_warn 'Set number out of range'; return 0; }
  source_set="$root/sets/${sets[idx-1]}"
  if [[ "$source_kind" == config ]]; then net_validate_set "$source_set" || { net_fail 'Backup integrity check failed'; return 1; }
  else net_validate_snapshot "$source_set" || { net_fail 'Snapshot integrity check failed'; return 1; }; fi
  net_warn "Restoring $source_kind from $source_set writes to /etc. No services will restart automatically."
  net_yes 'Restore these configuration files?' || return 0
  # Independent safety copy, even when offline, before touching /etc.
  backup_all_configs || { net_fail 'Safety backup failed; restore not started'; return 1; }
  rollback_set="$(net_latest_set "$backup_dir")" || return 1
  if [[ "$source_kind" == config ]]; then
    if ! net_restore_copy_set "$source_set"; then
      net_fail "Restore failed. Attempting local configuration rollback using $rollback_set"
      net_restore_copy_set "$rollback_set" || net_fail 'Rollback incomplete. Console recovery may be required.'
      return 1
    fi
  else
    if ! net_restore_snapfiles "$source_set"; then
      net_fail "Snapshot restore failed. Attempting local configuration rollback using $rollback_set"
      net_restore_copy_set "$rollback_set" || net_fail 'Rollback incomplete. Console recovery may be required.'
      return 1
    fi
  fi
  net_note "Restored configuration files. Safety backup: $rollback_set"
  # Runtime firewall state deliberately NOT replayed. A snapshot is not a firewall activation plan.
  net_warn 'Runtime firewall snapshots are diagnostic only; no live firewall changes were applied.'
  if ! net_apply_services; then
    net_fail 'Selected manager failed to apply. Restoring pre-operation config files.'
    net_restore_copy_set "$rollback_set" || net_fail 'Rollback failed. Local console recovery required.'
    net_warn 'Active daemon state might still differ from files on disk; no further restart attempted.'
    return 1
  fi
  return 0
)

net_numeric_metric() {
  local name="$1" value="$2"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%-16s %s\n' "$name:" "$value"
  else
    printf '%-16s %s\n' "$name:" 'Unavailable'
  fi
}
health_check() {
  local iface route4 route6 address4 dns4=0 net4=0 net6=0 iface_ok=0
  local counters rxerr txerr rxdrop txdrop gw4 gw6
  local -a reasons=()
  skip_reason=()
  skip_check=0
  iface="$(primary_iface 2>/dev/null)"
  if [[ -z "$iface" && -n "${nic:-}" ]] && ip link show "$nic" >/dev/null 2>&1; then iface="$nic"; fi
  route4="$(ip -4 route show default 2>/dev/null | head -n 1)"
  route6="$(ip -6 route show default 2>/dev/null | head -n 1)"
  if [[ -n "$iface" ]] && ip -o link show "$iface" 2>/dev/null | grep -qw UP; then
    iface_ok=1
  else
    reasons+=('INTERFACE_DOWN_OR_MISSING')
  fi
  [[ -n "$route4" || -n "$route6" ]] || reasons+=('ROUTE')
  if have_dns; then dns4=1; else reasons+=('DNS'); fi
  if net_ipv4_probe; then net4=1; fi
  if [[ -n "$route6" ]] && net_ipv6_probe; then net6=1; fi
  if (( net4 == 0 && net6 == 0 )); then
    # External failure can also be an ICMP/HTTPS policy. Never use it alone to justify disruption.
    reasons+=('EXTERNAL_CONNECTIVITY_UNCONFIRMED')
  fi
  skip_reason=("${reasons[@]}")
  if (( ${#reasons[@]} > 0 )); then skip_check=1; fi
  printf '\n=== NETWORK HEALTH ASSESSMENT ===\n'
  printf 'Interface: %s\n' "${iface:-not detected}"
  printf 'Default IPv4 route: %s\nDefault IPv6 route: %s\n' "${route4:-none}" "${route6:-none}"
  printf 'DNS resolution: %s\nExternal IPv4: %s\nExternal IPv6: %s\n' \
    "$( (( dns4 )) && echo PASS || echo FAIL)" \
    "$( (( net4 )) && echo REACHABLE || echo UNCONFIRMED)" \
    "$( (( net6 )) && echo REACHABLE || echo 'UNAVAILABLE / NOT ROUTED')"
  if (( iface_ok )); then
    counters="$(ip -s link show "$iface" 2>/dev/null)"
    rxerr="$(awk '$1=="RX:" {getline;print $3;exit}' <<< "$counters")"
    rxdrop="$(awk '$1=="RX:" {getline;print $4;exit}' <<< "$counters")"
    txerr="$(awk '$1=="TX:" {getline;print $3;exit}' <<< "$counters")"
    txdrop="$(awk '$1=="TX:" {getline;print $4;exit}' <<< "$counters")"
    net_numeric_metric RX-errors "$rxerr"
    net_numeric_metric TX-errors "$txerr"
    net_numeric_metric RX-dropped "$rxdrop"
    net_numeric_metric TX-dropped "$txdrop"
  fi
  command -v ss >/dev/null 2>&1 && { printf '\nActive listening ports:\n'; ss -tulpn 2>/dev/null | head -n 16; }
  printf '\nActive interfaces:\n'; ip -br link show 2>/dev/null || true
  command -v wg >/dev/null 2>&1 && { printf '\nWireGuard interfaces:\n'; ip -br link show type wireguard 2>/dev/null || true; }
  if (( skip_check )); then
    net_warn "Assessment incomplete / problems detected: ${skip_reason[*]}"
  else
    net_note 'External connectivity, route, interface and DNS checks passed.'
  fi
  [[ "${1:-}" == menu ]] && { read -r -p 'Press Enter to continue: ' || true; }
  return 0
}

# No driver unload, unscoped udev triggers, DNS overwrite, or automatic daemon restarts.
# Active changes require a fresh backup and an explicit confirmation.
repair() {
  local iface route4
  health_check
  (( skip_check )) || return 0
  net_warn "Detected: ${skip_reason[*]}"
  if net_yes 'Create an offline-capable safety backup before diagnostics/repair?'; then
    backup_all_configs || { net_fail 'Backup failed: no network changes will be attempted'; return 1; }
  else
    net_warn 'No backup: diagnostic-only mode. No configuration will be changed.'
    return 0
  fi
  iface="$(primary_iface 2>/dev/null)"
  if [[ -z "$iface" && -n "${nic:-}" ]] && ip link show "$nic" >/dev/null 2>&1; then iface="$nic"; fi
  if [[ -z "$iface" ]]; then
    net_fail 'No suitable NIC detected. PCI/driver operations require a local console and manual diagnosis.'
    return 1
  fi
  if ! ip -o link show "$iface" 2>/dev/null | grep -q 'UP'; then
    if net_yes "Bring only $iface up?"; then
      ip link set dev "$iface" up || { net_fail 'Interface activation failed'; return 1; }
    fi
  fi
  route4="$(ip -4 route show default 2>/dev/null | head -n 1)"
  if [[ -z "$route4" && -n "${sys_gw:-}" ]]; then
    net_warn "Missing IPv4 default route; proposed gateway $sys_gw on $iface."
    if net_console_authorized && net_yes 'Add this default route?'; then
      ip -4 route add default via "$sys_gw" dev "$iface" || net_fail 'Default route update failed'
    fi
  fi
  if ! have_dns; then
    net_warn 'DNS unresolved. Existing resolv.conf is preserved (may contain private resolvers).'
    if command -v resolvectl >/dev/null 2>&1 && net_yes 'Flush systemd-resolved caches without changing configured DNS servers?'; then
      resolvectl flush-caches || net_warn 'DNS cache flush failed'
    fi
  fi
  health_check
  if (( skip_check )); then
    net_warn 'Connectivity is not fully verified; disruptive restarts and driver reloads were not attempted.'
    return 1
  fi
  net_note 'Network health checks now pass.'
  return 0
}
fix_network() (
  net_repair_init || return 1
  if declare -F header_notice >/dev/null 2>&1; then
    header_notice "${net_repair_title:-Network Repair}" "${net_repair_banner:-}" "18" "4"
  fi
  while true; do
    network_select_option || return 0
    repair_select="${repair_select,,}"
    case "$repair_select" in
      1) repair || net_warn 'Network recovery not confirmed' ;;
      2) backup_all_configs || net_warn 'Backup failed' ;;
      3) snapshot_state || net_warn 'Snapshot failed' ;;
      4) if [[ -d "$backup_dir/sets" ]]; then ls -lah "$backup_dir/sets"; else net_warn 'No backups'; fi ;;
      5) if [[ -d "$snaps_dir/sets" ]]; then ls -lah "$snaps_dir/sets"; else net_warn 'No snapshots'; fi ;;
      6) restore_backup || net_warn 'Restore did not complete successfully' ;;
      7) if declare -F install_cron >/dev/null 2>&1; then
           install_cron '-x' 'One-Click Network Repair Tool' 'v' || net_warn 'Cron setup failed'
         else net_warn 'Parent install_cron function is unavailable'; fi ;;
      0) return 0 ;;
      *) net_warn 'Invalid selection' ;;
    esac
    printf '\n'
    read -r -p '[USER] Press Enter to return to menu...' || return 0
    command -v clear >/dev/null 2>&1 && clear || true
  done
)
# ==== End Of Network Repair ==== #
