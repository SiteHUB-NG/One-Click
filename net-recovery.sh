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
# ==== Network Repair ====
network_select_option() {
  info "Network repair is a tool that will attempt to fix and resolve network connectivity issues" \
    "If it has had the opportunity to assess your environment before disaster, it will create snapshots and backups of your current configuration." \
    " " "Outside of snapshots, it can only make intelligent guesses to fix a connectivity issue." \
    " " "This tool ${red}DOES NOT${reset} guarantee that it will be able to fix your issue." " "
  printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
    "[1]. Display Snapshot Contents" \
    "[2]. Display Backup Contents" \
    "[3]. Health Check|Repair Network" \
    "[4]. Backup Network Configs" \
    "[5]. Capture state snapshot" \
    "[6]. Restore Network Configs" \
    "[7]. Configure cron for snapshots" \
    "[8]. Exit"
  read -rp "${cyan}[USER]${reset} Please select an option to proceed with: " repair_select
}
timestamp() { date +%Y%m%d-%H%M%S; }
primary_iface() {
  ip -o link show up | awk -F': ' '$2 != "lo" {print $2; exit}'
}
have_net() {
  ping -c1 -W2 1.1.1.1 &>/dev/null
}
have_dns() {
  getent hosts google.com &>/dev/null
}
backup_file() {
  local file
  file="${1:-}"
  [[ -e "$file" ]] || return 0
  mkdir -p ${backup_dir}/$(dirname "${file}")
  if [[ -d "$file" ]]; then
    rsync -aH --delete "$file/" "${backup_dir}/${file}/"
  else
    rsync -aH "$file" "${backup_dir}/${file}.bak.$(timestamp)"
  fi    
}
backup_all_configs() {
  local error
  error=()
  non_interactive=${non_interactive:-0}
  if ! have_net; then
    die "Backup cannot be taken of a network that is not functional"
  fi
  if [[ -d "${backup_dir}.old/" ]]; then
    rm -rf "${backup_dir}.old"/*
  fi
  if [[ -d "$backup_dir" ]]; then
    info "Cleaning old backups in $backup_dir"
    mkdir -p "${backup_dir}.old"
    rsync -aH "$backup_dir/" "${backup_dir}.old/"
    rm -rf "$backup_dir"/*
  fi
  if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
  fi
  ip a s > "$config_dir/ip_add_show.txt"
  ip r s > "$config_dir/ip_route_show.txt"
  ip rule show > "$config_dir/ip_rule_show.txt"
  if command -v resolvconf >/dev/null 2>&1; then
    if resolvconf -l > "$config_dir/resolvconf_status.txt" &> /dev/null ; then
      success "resolvconf status state successfully saved"
    else
      error "resolvconf status state could not be saved"
      error+=(resolvconf)
    fi
  fi
  if command -v resolvectl &> /dev/null; then
    if type systemd-resolve; then
      if resolvectl status > "$config_dir/resolvectl_status.txt" &> /dev/null; then
        success "resolvectl status state successfully saved"

      else
        error "resolvectl status state could not be saved"
        error+=(resolvctl)
      fi
    else
      warn "systemd-resolve not available for resolvectl" "No config to back up"
      error+=(systemd-resolve)
    fi
  else
    warn "No resolvconf or resolvectl found."
  fi
  info "Backing up key configs..."
  dirs=(
    /etc/hosts
    /etc/resolv.conf
    /etc/hostname
    /etc/sysctl.conf
    /etc/sysctl.d/*.conf
    "$config_dir/ip_add_show.txt"
    "$config_dir/ip_route_show.txt"
    "$config_dir/ip_rule_show.txt"
    "$config_dir/resolvectl_status.txt"
    /etc/NetworkManager/system-connections/
    /etc/network/interfaces
    /etc/netplan/*.yaml
    /etc/sysconfig/network-scripts/ifcfg-\* 
    /etc/NetworkManager/NetworkManager.conf
    /etc/iptables/rules.v4 
    /etc/systemd/resolved.conf 
  )
  for dir in "${dirs[@]}"; do
    backup_file "$dir" 2>/dev/null || true
    if [[ -s "$dir" ]]; then
      success "$dir has been backed up"
    else 
      error+=("$dir")
    fi
  done
  echo
  success "${yellow}[${reset}Backup has been successful${yellow}]${reset}"
  if [[ "${#error[@]}" -gt 0 ]]; then
    error "The following failed to backup or are not available: "
    warn "${error[@]}"
  fi
  if (( ! non_interactive )); then
    sleep 2
    echo; echo
  fi
}
snapshot_state() {
  info "Creating snapshots"
  > "$service_restore"
  if systemctl is-active firewalld &>/dev/null; then
    snap_firewalld="$snaps_dir/firewalld-state-$(timestamp).tar.gz"
    firewall-cmd --runtime-to-permanent
    state_snap=(
      /etc/firewalld/firewalld.conf
      /etc/firewalld
      /etc/firewalld/firewalld.conf
      /etc/firewalld/zones/*.xml
      /etc/firewalld/services/*.xml
      /etc/firewalld/direct.xml
    )
    success "iptables restore state added to $service_restore"
    echo "firewalld $snap_firewalld" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_firewalld" "${existing[@]}" &>/dev/null
  fi
  if command -v nft &>/dev/null; then
    nft list ruleset > "$snaps_dir"/nftables.state
    snap_nft="$snaps_dir/nftables-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/nftables.conf
      /etc/nftables.d/*.conf
      /etc/sysconfig/nftables.conf
      /etc/one-click/network-repair/snapshots/nftables.state
    )
    success "iptables restore state added to $service_restore"
    echo "nft $snap_nft" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_nft" "${existing[@]}" &>/dev/null
  fi
  if command -v iptables &>/dev/null; then
    iptables-save > "$snaps_dir"/iptables.state
    snap_iptables="$snaps_dir/iptables-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/iptables/rules.v4
      /etc/iptables/rules.v6
      /etc/sysconfig/iptables
      /etc/sysconfig/ip6tables
      /etc/sysconfig/SuSEfirewall2
      /etc/one-click/network-repair/snapshots/iptables.state
    )
    success "iptables restore state added to $service_restore"
    echo "iptables $snap_iptables" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_iptables" "${existing[@]}" &>/dev/null
  fi
  if command -v ufw &>/dev/null && ufw status &>/dev/null; then
    snap_ufw="$snaps_dir/ufw-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/ufw/ufw.conf
      /etc/ufw/sysctl.conf
      /etc/ufw/user.rules
      /etc/ufw/user6.rules
    )
    success "iptables restore state added to $service_restore"
    echo "ufw $snap_ufw" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_ufw" "${existing[@]}" &>/dev/null
  fi
  if command -v NetworkManager &>/dev/null; then
    snap_NetworkManager="$snaps_dir/nm-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/NetworkManager/NetworkManager.conf
      /etc/sysconfig/network
      /etc/sysconfig/network-scripts/ifcfg-*
      /etc/sysconfig/network-scripts/route-*
      /etc/sysconfig/network-scripts/rule-*
      /etc/NetworkManager/system-connections/*.nmconnection
    )
    success "iptables restore state added to $service_restore"
    echo "nm $snap_NetworkManager" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_NetworkManager" "${existing[@]}" &>/dev/null
  fi
  if command -v netplan &>/dev/null; then
    snap_netplan="$snaps_dir/netplan-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/netplan/*.yaml
    )
    success "iptables restore state added to $service_restore"
    echo "netplan $snap_netplan" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_netplan" "${existing[@]}" &>/dev/null
  fi
  if command -v ifup &>/dev/null; then
    snap_ifup="$snaps_dir/ifupdown-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/network/interfaces
      /etc/network/interfaces.d/*.cfg
    )
    success "iptables restore state added to $service_restore"
    echo "ifup $snap_ifup" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_ifup" "${existing[@]}" &>/dev/null
  fi
  if [[ -e "/etc/systemd/network/*.netdev" ]]; then
    snap_networkd="$snaps_dir/ifupdown-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/systemd/network/*.network
      /etc/systemd/network/*.netdev
      /etc/systemd/network/*.link
    )
    success "iptables restore state added to $service_restore"
    echo "netdev $snap_networkd" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_networkd" "${existing[@]}" &>/dev/null
  fi
  if [[ -e "/etc/sysconfig/network/" ]]; then
    snap_wicked="$snaps_dir/ifupdown-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/sysconfig/network/
      /etc/sysconfig/network/ifcfg-*
    )
    success "iptables restore state added to $service_restore"
    echo "suse $snap_wicked" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_wicked" "${existing[@]}" &>/dev/null
  fi
}
restore_backup() {
  warn "This will automatically restore known working network configurations"
  read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed [y|n]: " confirm_restore
  confirm_restore=${confirm_restore,,}
  [[ "$confirm_restore" != "y" && "$confirm_restore" != "yes" ]] && {
    info "You have chosen not to proceed with the restore"
    return 0
  }
  info "Restoring backup configs and snapshots..."
  for f in "$backup_dir"/**/*.bak.*; do
    rel="${f#$backup_dir/}"
    rel="${rel%.bak.*}"
    orig="/$rel"
    mkdir -p "$(dirname "$orig")"
    cp -a "$f" "$orig"
    success "Restored $orig from backup"
  done
  while read -r map service; do
    [[ -f "$service" ]] || continue

    case "$map" in
      ufw)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        ufw reload
        success "$service has been reloaded"
        ;;
      iptables)
        iptables-restore < "$snaps_dir/iptables.state"
        success "$service configs has been restored."
        tar -xzf "$service" -C /
        ;;
      nft)
        nft -f "$snaps_dir/nftables.state"
        success "$service configs has been restored."
        tar -xzf "$service" -C /
        ;;
      firewalld)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        systemctl restart firewalld
        success "$service has been reloaded"
        ;;
      suse)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        systemctl restart wicked
        success "$service has been reloaded"
        ;;
      netdev)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        systemctl restart systemd-networkd
        success "$service has been reloaded"
        ;;
      ifup)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        systemctl restart networking || ifdown -a && ifup -a
        success "$service has been reloaded"
        ;;
      netplan)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        netplan generate && netplan apply
        success "$service has been reloaded"
        ;;
      nm)
        tar -xzf "$service" -C /
        success "$service configs has been restored."
        systemctl restart NetworkManager
        success "$service has been reloaded"
        ;;
    esac

    success "$map service restarted"
  done < "$service_restore"
}
repair() {
  # ==== Check & repair network ====
  if have_net && have_dns; then
    success "${green}The network is healthy${reset}"
    info "Preparing snapshots of the current configuration"
    backup_all_configs
    success "${green}[HEALTHY NETWORK]${reset} - snapshot available via menu option 5"
    return 0
  fi
  error "Network problem detected - attempting network repair"
  info "Attempting to diagnose the issue"
  iface="$(primary_iface || true)"
  if [[ -z "$iface" ]]; then
    error "No interface detected"
    info "[1/5]: Rescanning PCI Bus"
    echo 1 > /sys/bus/pci/rescan
    sleep 1
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
    warn "rescanning did not fix connectivity"
    sleep 0.3
    info "[2/5]: Reloading NIC drivers"
    for mod in virtio_net e1000 e1000e igb ixgbe vmxnet3 r8169; do
      modprobe -r "$mod" 2>/dev/null || true
      modprobe "$mod" 2>/dev/null || true
    done
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
    warn "Reloading of NIC drivers also did not restore connectivity"
    sleep 0.3
    info "[3/5]: Reloading Udev"
    udevadm control --reload
    udevadm trigger
    sleep 2
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
    warn "Network still down after udev reload"
    sleep 0.3
    info "[4/5]: Checking for hidden interfaces"
    if ip link show | grep -q "state DOWN"; then
      ip link set up $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo) || true
    fi
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
    warn "No hidden interfaces found"
    sleep 0.3
    info "[5/5]: Forcefully trying to bring up the interface"
    if systemctl is-enabled NetworkManager &>/dev/null; then
      systemctl restart NetworkManager
    elif systemctl is-enabled systemd-networkd &>/dev/null; then
      systemctl restart systemd-networkd
    fi
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
    error "All attempts to bring the network up have failed!"
    die
  fi
  # ==== Bring interface up ====
  info "Attempting to bring up interface $iface"
  ip link set "$iface" up || true
  sleep 2
  if have_net; then
    success "Connectivity has been restored"
    exit 0
  fi
  # ==== Ensure IP ====
  if ! ip -4 addr show "$iface" | grep -q inet; then
    warn "No IPv4 on $iface" "Attempting fix"
    for id in "${ids[@]}"; do
      case "$id" in
        debian|ubuntu)
          iface_file="/etc/network/interfaces"
          [[ -f "${iface_file:-}" ]] && cp "${iface_file:-}" "${iface_file:-}.bak"
          sed -Ei.one-click-bak "
            s/$sys_gw/$destination_gw/
            s/$ipv6_gw/${remote_v6_gw:-}
            s/$sys_ip/$destination_server/g; 
            s/${sys_ipv6/:1}/${destination_v6/:1}/g; 
            s/$ipv6_gw/${remote_v6_gw:-}/g;
            s/eth0/$nic/g
          " "${iface_file:-}"
          if [[ -f /etc/wireguard/wg0.conf ]]; then
            sed -Ei.one-click-bak "
              s/$sys_ip/$destination_server/g; 
              s/$sys_gw/$destination_gw/g; 
              s/${sys_ipv6/:1}/${destination_v6/:1}/g; 
              s/$ipv6_gw/${remote_v6_gw:-}/g;
              s/^.*200 default via $destination_gw/#&/
              " /etc/wireguard/wg0.conf
            wg-quick up wg0
          fi
          ip addr flush dev "$nic" || true
          ifup "$nic" &> /dev/null || true
          ;;
        rhel|centos|rocky|almalinux|fedora)
          local nmcli_status
          # ==== Try NetworkManager ====
          if command -v nmcli &> /dev/null; then
            iface_file="/etc/NetworkManager/system-connections/$nic.nmconnection"
            [[ -f "${iface_file:-}" ]] && cp "${iface_file:-}" "${iface_file:-}.bak"
            sed -Ei.one-click-bak "
              s/$sys_ip/$destination_server/g;
              s/$sys_gw/$destination_gw/g;
              s/${sys_ipv6/:1}/${destination_v6/:1}/g;
              s/$ipv6_gw/${remote_v6_gw:-}/g;
              s/eth0/$nic/g
            " "${iface_file:-}"
            if [[ -f /etc/wireguard/wg0.conf ]]; then
              sed -Ei.one-click-bak "
                s/$sys_ip/$destination_server/g;
                s/$sys_gw/$destination_gw/g;
                s/${sys_ipv6/:1}/${destination_v6/:1}/g;
                s/$ipv6_gw/${remote_v6_gw:-}/g;
                s/200 default via $destination_gw/#&/
              " /etc/wireguard/wg0.conf
              wg-quick up wg0
            fi
            nmcli device set "$nic" managed yes
            nmcli connection reload
            nmcli device disconnect "$nic"
            nmcli device connect "$nic"
            systemctl restart network || systemctl restart NetworkManager
          else
            #  ==== Check which network files exist ====
            local iface_file
            iface_file="/etc/sysconfig/network-scripts/ifcfg-$nic"
            [[ -f "${iface_file:-}" ]] && cp "${iface_file:-}" "${iface_file:-}.bak"
            sed -Ei.one-click-bak "
              s/$sys_ip/$destination_server/g
              s/$sys_gw/$destination_gw/g;
              s/${sys_ipv6/:1}/${destination_v6/:1}/g;
              s/$ipv6_gw/${remote_v6_gw:-}/g
              s/eth0/$nic/g
            " /etc/sysconfig/network-scripts/ifcfg-"$nic"
            if [[ -f /etc/wireguard/wg0.conf ]]; then
              sed -Ei.one-click-bak "
                s/$sys_ip/$destination_server/g;
                s/$sys_gw/$destination_gw/g;
                s/${sys_ipv6/:1}/${destination_v6/:1}/g;
                s/$ipv6_gw/${remote_v6_gw:-}/g;
                s/200 default via $destination_gw/#&/
              " /etc/wireguard/wg0.conf
              wg-quick up wg0
            fi
            systemctl restart network || systemctl restart NetworkManager
          fi
          ;;
      esac
    done
    if have_net; then
      success "Connectivity has been restored"
      exit 0
    fi
  fi
  # ==== Ensure default route ====
  if ! ip route | grep -q default; then
    info "No default route available" "Configuring now."
    ip route add default via "$sys_gw" dev "$nic" || true
  fi
  # ==== Restart if still no ping ====
  if ! have_net; then
    warn "Restarting interfaces"
    if systemctl is-active NetworkManager &>/dev/null; then
      systemctl restart NetworkManager
    elif systemctl is-active systemd-networkd &>/dev/null; then
      systemctl restart systemd-networkd
    elif command -v service &>/dev/null; then
      service networking restart || true
    fi
    sleep 5
  fi
  # ==== Reset DNS ====
  if have_net && ! have_dns; then
    warn "DNS is broken - restoring resolv.conf"
    cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
  fi
  # ==== Network? Grab snapshots ====
  if have_net && have_dns; then
    success "Network is active"
    snapshot_state
  else
    error "Network issue detected."
    warn "Would you like for this script to try and restore connectivity [y/n]: " restore_network
    restore_network=${restore_network,,}
    if [[ "$restore_network" == "y" || "$restore_network" == "yes" ]]; then
      warn "Attempting to fix network issues"
      restore_backup
    fi
  fi
  echo "=== Network Repair finished ==="
  return 0  
}
fix_network() {
  header_notice "$net_repair_title" "$net_repair_banner" "18" "4"
  # ==== User Selection: DD or Rsync? ====
  mkdir -p "$base_dir" "$backup_dir" "$snaps_dir" "$config_dir"
  #exec >>"$log_file" 2>&1
  info "=== Network Repair started: $(date +'%F') ==="
  # =========== BEGIN NETWORK REPAIR ===============
  while true; do
    network_select_option
    repair_select="${repair_select,,}"
    case "$repair_select" in
      1)
        if [[ -z "$(ls -A "$snaps_dir" 2>/dev/null)" ]]; then
          warn "No snapshots found"
          #return
        else
          ls_table "$snaps_dir"
          #return
        fi
        ;;
      2)
        if [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
          warn "No backups found"
        else
          ls_table "$backup_dir/*/" 
        fi
        ;;
      3)repair                                                ;;
      4)backup_all_configs                                    ;;
      5)snapshot_state                                        ;;
      6)restore_backup                                        ;;
      7)install_cron "-x" "One-Click Network Repair Tool" "v" ;;
      8)info "Exiting Network Repair" ; break                 ;;
      *)warn "Invalid selection"                              ;;
    esac
    echo
    read -rp "${cyan}[USER]${reset} Press Enter to return to menu..."
    clear
  done
}
# ==== End Of Network Repair ==== #
