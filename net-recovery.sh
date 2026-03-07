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
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== Network Repair ====
network_select_option() {
  mkdir -p "$backup_dir"
  info "Network repair is a tool that will attempt to fix and resolve network connectivity issues" \
    "If it has had the opportunity to assess your environment before disaster, it will create snapshots and backups of your current configuration." \
    " " "Outside of snapshots, it can only make intelligent guesses to fix a connectivity issue." \
    " " "This tool ${red}DOES NOT${reset} guarantee that it will be able to fix your issue." " "
  printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
    "[1]. Health Check|Repair Network" \
    "[2]. Backup Network Configs" \
    "[3]. Capture state snapshot" \
    "[4]. Display Backup Contents" \
    "[5]. Display Snapshot Contents" \
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
    success "Firewalld restore state added to $service_restore"
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
    success "nf_tables restore state added to $service_restore"
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
    success "ufw restore state added to $service_restore"
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
    success "NetworkManager restore state added to $service_restore"
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
    success "Netplan restore state added to $service_restore"
    echo "netplan $snap_netplan" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_netplan" "${existing[@]}" &>/dev/null
  fi
  if command -v ifup &>/dev/null; then
    snap_ifup="$snaps_dir/ifup-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/network/interfaces
      /etc/network/interfaces.d/*.cfg
    )
    success "ifup restore state added to $service_restore"
    echo "ifup $snap_ifup" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_ifup" "${existing[@]}" &>/dev/null
  fi
  if [[ -e "/etc/systemd/network/*.netdev" ]]; then
    snap_networkd="$snaps_dir/networkd-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/systemd/network/*.network
      /etc/systemd/network/*.netdev
      /etc/systemd/network/*.link
    )
    success "netdev restore state added to $service_restore"
    echo "netdev $snap_networkd" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_networkd" "${existing[@]}" &>/dev/null
  fi
  if [[ -e "/etc/sysconfig/network/" ]]; then
    snap_wicked="$snaps_dir/rhel_network-state-$(timestamp).tar.gz"
    state_snap=(
      /etc/sysconfig/network/
      /etc/sysconfig/network/ifcfg-*
    )
    success "rhel_network restore state added to $service_restore"
    echo "suse $snap_wicked" >> "$service_restore"
    existing=()
    for snap in "${state_snap[@]}"; do
      [[ -e "$snap" ]] && existing+=("$snap")
    done
    [[ ${#existing[@]} -gt 0 ]] && tar czf "$snap_wicked" "${existing[@]}" &>/dev/null
  fi
}
restore_backup() {
  if [[ "$recovery_restore" -ne 0 ]]; then
    warn "This will automatically restore known working network configurations"
    read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed [y|n]: " confirm_restore
    confirm_restore=${confirm_restore,,}
    [[ "$confirm_restore" != "y" && "$confirm_restore" != "yes" ]] && {
      info "You have chosen not to proceed with the restore"
      return 0
    }
  fi
  info "Restoring backup configs and snapshots..."
  local found_backups=0
  while IFS= read -r f; do
    [[ -e "$f" ]] || continue
    found_backups=1
    rel="${f#$backup_dir/}"
    orig="/${rel%.bak.*}"
    mkdir -p "$(dirname "$orig")"
    cp -a "$f" "$orig"
    success "Restored $orig from backup"
  done < <(find "$backup_dir" -type f -name "*.bak.*" 2>/dev/null)
  if [[ -f "$service_restore" ]]; then
    info "Service mapping file found. Restoring service snapshots..."
    while read -r map service_tar; do
      [[ -z "$map" || -z "$service_tar" ]] && continue
      if [[ ! -f "$service_tar" ]]; then
        warn "Snapshot tarball missing: $service_tar"
        continue
      fi
      case "$map" in
        ufw)
          tar -xzf "$service_tar" -C / && ufw reload
          ;;
        iptables)
          # Restore the state file first if it exists
          [[ -f "$snaps_dir/iptables.state" ]] && iptables-restore < "$snaps_dir/iptables.state"
          tar -xzf "$service_tar" -C /
          ;;
        nft)
          [[ -f "$snaps_dir/nftables.state" ]] && nft -f "$snaps_dir/nftables.state"
          tar -xzf "$service_tar" -C /
          ;;
        firewalld)
          tar -xzf "$service_tar" -C / && systemctl restart firewalld
          ;;
        nm) 
          tar -xzf "$service_tar" -C / && systemctl restart NetworkManager
          ;;
        netplan)
          tar -xzf "$service_tar" -C / && netplan generate && netplan apply
          ;;
        ifup)
          tar -xzf "$service_tar" -C / && (systemctl restart networking || { ifdown -a; ifup -a; })
          ;;
        suse)
          tar -xzf "$service_tar" -C / && systemctl restart wicked
          ;;
        netdev)
          tar -xzf "$service_tar" -C / && systemctl restart systemd-networkd
          ;;
      esac
      success "Service [$map] restored and reloaded"
    done < "$service_restore"
  else
    warn "No service snapshot mapping file found at $service_restore"
  fi

  if [[ $found_backups -eq 0 && ! -f "$service_restore" ]]; then
    error "No backups or snapshots available to restore."
  else
    success "${yellow}[${reset}Restore process complete${yellow}]${reset}"
  fi
}
repair() {
  local int out dns_time retrans rx_error rx_dropped tx_error tx_dropped next_hop gw dev config_net
  out=$(ip -s link show "$nic")
  isp=$(curl -s http://ip-api.com/line?fields=isp,org,as,query)
  dns_time=$(awk '/Query time/{print $4}' <(dig google.com))
  if command -v netstat &> /dev/null; then
    retrans=$(awk '/segments retransmitted/{print $1}' <(netstat -s))
  elif command -v nstat &> /dev/null; then
    retrans=$(awk 'NR==2 {print $2}' <(nstat -az TcpRetransSegs))
  fi
  gw=$(awk '/default/{print $3}' <(ip r))
  dev=$(awk '/default/{print $5}' <(ip r))
  gw6=$(awk '/default/{print $3}' <(ip -6 r))
  dev6=$(awk '/default/{print $5}' <(ip -6 r))
  next_6_hop=$(awk -v gw="$gw6" '$0 ~ gw {print $1 " [" $3 "]"}' <(ip neighbor show dev "$dev6") | head -n 1)
  next_hop=$(awk -v gw="$gw" '$0 ~ gw {print $1 " [" $3 "]"}' <(ip neighbor show dev "$dev"))
  rx_error=$(awk '/RX:/{getline; print $3}' <<< "$out")
  rx_dropped=$(awk '/RX/{getline; print $4}' <<< "$out")
  tx_dropped=$(awk '/TX/{getline; print $4}' <<< "$out")
  tx_error=$(awk '/TX:/{getline; print $3}' <<< "$out")
  int=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
  # ==== Check & repair network ====
  warn \
    "${yellow}╔════════════════════════════════════════════════════════════╗" \
    "${yellow}║                    NETWORK HEALTH CHECK                    ║" \
    "${yellow}╚════════════════════════════════════════════════════════════╝${reset}"
  if have_net && have_dns; then
    echo -e "\n● ${cyan}[INTERFACE: $int]${reset}"
    echo -e "  ├─ Error Check: "
    if [ "$rx_error" -gt 0 ]; then
      echo -e "\e[31mFAIL\e[0m (RX: $rx_error errors)"
    else
      echo -e "\e[32mPASS\e[0m (RX: No errors)"
    fi
    if [ "$tx_error" -gt 0 ]; then
      echo -e "\e[31mFAIL\e[0m (TX: $tx_error errors)"
    else
      echo -e "\e[32mPASS\e[0m (TX: No errors)"
    fi
    if [ "$rx_dropped" -gt 0 ]; then
      echo -e "\e[31mFAIL\e[0m (RX: $rx_dropped drops)"
    else
      echo -e "\e[32mPASS\e[0m (RX No drops)"
    fi
    if [ "$tx_dropped" -gt 0 ]; then
      echo -e "\e[31mFAIL\e[0m (TX: $tx_dropped drops)"
    else
      echo -e "\e[32mPASS\e[0m (TX: No drops)"
    fi
      echo -ne "  ├─ Path MTU (1500b): "
    if ping -c 1 -M do -s 1472 8.8.8.8 &>/dev/null; then
      echo -e "\e[32mOK\e[0m"
    else
      echo -e "\e[33mFRAGMENTED\e[0m (Standard MTU failing; check for 1450 or lower)"
    fi
    echo -ne "  ├─ DNS Response: "
    if [ -z "$dns_time" ]; then 
      echo -e "\e[31mTIMEOUT\e[0m"; 
    elif [ "$dns_time" -gt 100 ]; then 
      echo -e "\e[33mSLOW\e[0m (${dns_time}ms)"; 
    else 
      echo -e "\e[32mFAST\e[0m (${dns_time}ms)"; 
    fi
    echo -ne "  └─ TCP Retransmit Rate: "
    if [ "$retrans" -gt 5000 ]; then 
      echo -e "\e[33mHIGH\e[0m"
    else 
      echo -e "\e[32mSTABLE\e[0m" 
    fi
    echo -e "\n● ${cyan}[ACTIVE PORTS]${reset}"
    awk '/LISTEN/{printf "  ├─ %-15s %s\n", $5, $7}' <(ss -tulpn) | sed '$s/├/└/'
    echo -e "\n● ${cyan}[ACTIVE INTERFACES]${reset}"
    awk '{printf "  ├─ %-10s %-10s %s\n", $1, $2, $3}' <(ip -br link show) | sed '$s/├/└/'
    echo -e "\n● ${cyan}[GATEWAY & ROUTING]${reset}"
    if [ -n "$gw" ]; then
      echo "  ├─ Gateway:      $gw (via $dev)"
      echo "  ├─ Next Hop/MAC: ${next_hop:-Local Gateway Reachable}"
    fi
    if [ -n "$gw6" ]; then
      echo "  ├─ IPv6 Gateway: $gw6 (via $dev6)"
    
      echo "  ├─ IPv6 NextHop: ${next_6_hop}:-Local Gateway Reachable}"
    else
      echo "  ├─ IPv6 Gateway: Not Configured"
    fi
    echo "  └─ Routing Table: ${green}Active"
    echo -e "\n● ${cyan}[ISP & PUBLIC IDENTITY]${reset}"
    if [ $? -eq 0 ]; then
      awk '
        NR==1 {printf "  ├─ ISP:      %s\n", $0}
        NR==2 {printf "  ├─ Org:      %s\n", $0}
        NR==3 {printf "  ├─ AS Path:  %s\n", $0}
        NR==4 {printf "  └─ PublicIP: %s\n", $0}
      ' <<< "$isp"
    else
      echo "  └─ Error: Could not reach IP-API"
    fi
      echo -e "\n● ${cyan}[IPv6 CONNECTIVITY]${reset}"
    if ping6 -c 1 google.com &>/dev/null; then
      echo -e "  └─ Status: \e[32mONLINE\e[0m"
    else
      echo -e "  └─ Status: \e[31mOFFLINE/DISABLED\e[0m"
    fi
    echo
    echo -e "\n● ${cyan}[NETWORK ASSESSMENT]${reset}"
    success "${green}THE NETWORK IS HEALTHY${reset}"
    echo
    sleep 3
    read -p "Would you like to backup the current network configurations? [y|n]: " config_net
    if [[ "$config_net" == "y" || "$config_net" == "yes"  ]]; then
      info "Preparing snapshots of the current configuration"
      backup_all_configs
      success "Backup of healthy network complete"
    else
      error "Network Config Backup Rejected" 
    fi
    return 0
  fi
  error "Network problem detected - attempting network repair"
  warn "Attempting to diagnose the issue"
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
  # ==== Restore Snapshot ====
  if ! ip -4 addr show "$iface" | grep -q inet; then
    recovery_restore=1
    restore_backup
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
  # ==== Network? ====
  if have_net && have_dns; then
    success "Network is active"
  else
    warn "Unable to bring the network up."
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
      1) repair ;;
      2)backup_all_configs                                    ;;
      3)snapshot_state                                        ;;
      4)
        if [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
          warn "No backups found"
        else
          ls_table_all
        fi
        ;;
      5)
        if [[ -z "$(ls -A "$snaps_dir" 2>/dev/null)" ]]; then
          warn "No snapshots found"
          #return
        else
          ls_table "$snaps_dir"
          #return
        fi
        ;;
     
      6)restore_backup                                         ;;
      7)install_cron "-x" "One-Click Network Repair Tool" "v"  ;;
      8)tmux kill-session -t "one-click"                       ;;
      *)warn "Invalid selection"                               ;;
    esac
    echo
    read -rp "${cyan}[USER]${reset} Press Enter to return to menu..."
    clear
  done
}
# ==== End Of Network Repair ==== #
