#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK MULTI TOOLBOX * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Aug 2026 == # === Version#: 1.0.0 === #
# ====== One-Click ====== #
# ==== Firewall RuleEngine ==== 
# ==== Helper: Ensure nftables IP Filter Base Chains Exist ====
ensure_nftables_base_chains() {
  if command -v nft &>/dev/null; then
    nft add table ip filter &>/dev/null || true
    nft add chain ip filter INPUT '{ type filter hook input priority 0 ; policy accept ; }' &>/dev/null || true
    nft add chain ip filter FORWARD '{ type filter hook forward priority 0 ; policy accept ; }' &>/dev/null || true
    nft add chain ip filter OUTPUT '{ type filter hook output priority 0 ; policy accept ; }' &>/dev/null || true
  fi
}
expand_multiport_command() {
  local cmd="$1"
  if [[ "$cmd" =~ -m[[:space:]]+multiport[[:space:]]+--(dports|sports)[[:space:]]+([^[:space:]]+) ]]; then
    local flag="${BASH_REMATCH[1]}"
    local ports_str="${BASH_REMATCH[2]}"
    local single_flag="${flag%s}"
    IFS=',' read -ra ports <<< "$ports_str"
    for port in "${ports[@]}"; do
      local unrolled_cmd
      unrolled_cmd=$(echo "$cmd" | sed -E "s/-m[[:space:]]+multiport[[:space:]]+--${flag}[[:space:]]+[^[:space:]]+/--${single_flag} ${port}/")
      echo "$unrolled_cmd"
    done
  else
    echo "$cmd"
  fi
}
# ==== Firewall RuleEngine ====
rule_engine() {
  if ! systemctl is-active --quiet firewalld; then
    fail2ban_failed=true
  else
    fail2ban_failed=false
  fi
  if [[ -f "/var/log/auth.log" || -f "/var/log/secure" ]]; then
    logs_exist=true
  else
    logs_exist=false
  fi
  if [[ "$pkg_mgr" == "apt" ]]; then
    if [[ "$fail2ban_failed" == true && "$logs_exist" == false ]]; then
      apt-get -y install rsyslog &> /dev/null
      systemctl enable --now rsyslog &> /dev/null
    fi
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
    install_dep "fail2ban" "command -v fail2ban-client" "fail2ban" "$pkg_mgr" true
    systemctl enable fail2ban --now &> /dev/null
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    if [[ "$fail2ban_failed" == true && "$logs_exist" == false ]]; then
      dnf -y install rsyslog &> /dev/null
      systemctl enable --now rsyslog &> /dev/null
    fi
    install_dep "iptables" "command -v iptables" "iptables iptables-services" "$pkg_mgr" true
    install_dep "fail2ban" "command -v fail2ban-client" "fail2ban" "$pkg_mgr" true
    systemctl enable fail2ban --now &> /dev/null
  fi
  declare -gA alerted_ports=()
  engine_dir="/etc/one-click/rule-engine/"
  alias_file=/etc/one-click/rule-engine/.alias.conf
  real_ssh=$(sed -En '/sshd/{/0.0:/{s/^[^:]*:([0-9]+).*/\1/p}}' <(ss -ltnp))
  rule="$1"
  flag="${2:-}"
  y_int="${3:-}"
  dry_run=0
  duplicate_skipped=0
  y_interactive=0
  if [[ "$rule" == "--dry-run" ]]; then
    if [[ "$flag" == "-y" || "$y_int" == "-y" ]]; then
      y_interactive=1
    fi
    dry_run=1
    rule="$flag"
    if [[ -f /tmp/fw_confirmed ]]; then
      rm -f /tmp/fw_confirmed
    fi
  fi
  if [[ "$y_int" == "-y" || "$flag" == "-y" ]]; then
    y_interactive=1
  fi
  if [[ -z "$rule" ]]; then
    die "Usage: one-click rule-engine [--dry-run] '<rule in human words wrapped in quotes>'"
  fi
  mkdir -p "$engine_dir"
  mkdir -p "${engine_dir}guard/"
  touch "$alias_file"
  # ==== Default Sensitive Ports ====
  declare -A default_sensitive_ports=(
    ["${real_ssh:-22}"]="SSH (Remote Access)"
    [21]="FTP (Unencrypted File Transfer)"
    [25]="SMTP (Mail Routing)"
    [443]="HTTPS (Web Traffic)"
    [3306]="MySQL (Database)"
    [9090]="Cockpit"
    [51820]="WireGuard VPN"
  )
  # ==== Persistent Alias System ====
  declare -A host_aliases
  load_host_aliases() {
    [[ -f "$alias_file" ]] || return
    while IFS='=' read -r name ip; do
      [[ -z "$name" || "$name" =~ ^# ]] && continue
      host_aliases[$name]=$ip
    done < "$alias_file"
  }
  rule_lower=${rule,,}
  rule_lower=$(sed -E 's/ ?(how to|please|can you|help|fix|this) ?//g' <<< "$rule_lower")
  last_action=""
  last_proto=""
  generated_cmds=()
  # ==== Detect Backend Environment ====
  detect_firewall_backend
  if command -v iptables &>/dev/null && iptables -V 2>/dev/null | grep -qi nf_tables; then
    if [[ "$dry_run" -eq 1 ]]; then
      printf "${magenta}[DRY-RUN]${reset} %s\n" "iptables is running in nf_tables compatibility mode."
    else
      info "iptables is running in nf_tables compatibility mode."
    fi
  fi
  load_host_aliases
  clean_duplicate_rules
  check_firewall_available
  rule_normalized=$(sed -E 's/[\t ]+and[\t ]+|,+/|/g' <<< "$rule_lower")
  IFS='|' read -ra subcommands <<< "$rule_normalized"
  # ==== Determine last_action from subcommands ====
  for sub in "${subcommands[@]}"; do
    if grep -Eq "\b(drop|deny|block|stop|close)\b" <<< "$sub"; then
      last_action="DROP"; break
    elif grep -Eq "\b(reject|decline|bounce)\b" <<< "$sub"; then
      last_action="REJECT"; break
    elif grep -Eq "\b(open|allow|permit|accept|add)\b" <<< "$sub"; then
      last_action="ACCEPT"; break
    elif grep -Eq "\b(delete|remove)\b" <<< "$sub"; then
      last_action="DELETE"; break
    fi
  done
  # ==== Parse Subcommands ====
  for sub in "${subcommands[@]}"; do
    parse_firewall_command "$sub" "$last_proto"
  done
  # ==== Backend-Aware Deduplication Against Live System ====
  unique_cmds=()
  for cmd in "${generated_cmds[@]}"; do
    local is_dup=0
    case "${firewall_backend:-iptables}" in
      iptables|ip6tables)
        read -r -a arr <<< "$cmd"
        if "${fw_bin:-iptables}" -C "${arr[@]:1}" &>/dev/null; then
          is_dup=1
        fi
        ;;
      nft)
        if nft list ruleset 2>/dev/null | grep -F -q "$cmd"; then
          is_dup=1
        fi
        ;;
      ufw)
        if ufw status 2>/dev/null | grep -F -q "$cmd"; then
          is_dup=1
        fi
        ;;
      firewalld)
        if firewall-cmd --zone=public --query-port="${cmd#*--add-port=}" &>/dev/null 2>&1; then
          is_dup=1
        fi
        ;;
    esac
    if [[ "$is_dup" -eq 1 ]]; then
      info "Skipping duplicate rule already active in kernel: $cmd"
      duplicate_skipped=1
      continue
    fi
    unique_cmds+=("$cmd")
  done
  if [[ ${#unique_cmds[@]} -eq 0 ]]; then
    if [[ "$duplicate_skipped" == "1" ]]; then
      info "All rules already exist. Nothing to change."
      exit 0
    fi
    if [[ "$dry_run" -eq 1 ]]; then
      printf "${red}[DRY-RUN]${reset} %s\n" "No valid commands generated." "DRY-RUN Failed!"
      exit 1
    else
      die "No valid commands generated."
    fi
  fi
  # ==== Preview Commands ====
  if [[ "$dry_run" -eq 1 ]]; then
    printf "${magenta}[DRY-RUN]${reset} %s\n" "The following commands will be executed:"
  else
    info "The following commands will be executed:"
  fi
  for cmd in "${unique_cmds[@]}"; do
    if [[ "$dry_run" -eq 1 ]]; then
      printf "${magenta}[DRY-RUN]${cyan} %s${reset}\n" "$cmd"
    else
      printf "${cyan}[COMMAND]: %s${reset}\n" "$cmd"
    fi
  done
  confirm=n
  if [[ "$y_interactive" -eq 1 ]]; then
    confirm="y"
  else
    if [[ "$dry_run" -eq 1 ]]; then
      read -rp "${magenta}[DRY-RUN]:${reset} Apply ALL rules? (y|n): " confirm
    else
      read -rp "${cyan}[USER]:${reset} Apply ALL rules? (y|n): " confirm
    fi
    confirm="${confirm,,}"
  fi
  if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
    tmp_snapshot=$(mktemp /tmp/fw_backup.XXXXXX)
    confirm_file=$(mktemp /tmp/fw_confirmed.XXXXXX)
    state_file=$(mktemp /tmp/fw_state.XXXXXX)
    echo "APPLYING" > "$state_file"
    trap 'rm -f "${tmp_snapshot:-}" "${confirm_file:-}" "${state_file:-}" 2>/dev/null' EXIT INT TERM
    # ==== Backend-Aware Snapshot Creation ====
    case "${firewall_backend:-iptables}" in
      nft)
        nft list ruleset > "$tmp_snapshot" 2>/dev/null || true
        ;;
      ufw)
        ufw status verbose > "$tmp_snapshot" 2>/dev/null || true
        ;;
      firewalld)
        firewall-cmd --runtime-to-permanent &>/dev/null || true
        firewall-cmd --zone=public --list-all > "$tmp_snapshot" 2>/dev/null || true
        ;;
      *)
        ${fw_bin:-iptables}-save -c > "$tmp_snapshot" 2>/dev/null || true
        ;;
    esac
    fail=()
    fatal=0
    # ==== Dry Run Verification ====
    if [[ "$dry_run" -eq 1 ]]; then
      if ! dry_run "${unique_cmds[@]}"; then
        printf "${magenta}[DRY-RUN]${red} %s${reset}\n" "Dry run failed. Exiting without applying rules."
        return 1 2>/dev/null || exit 1
      fi
    fi
    # ==== Ensure base nftables chains exist ====
    ensure_nftables_base_chains
    # ==== Execute Rules ====
    for cmd in "${unique_cmds[@]}"; do
      mapfile -t runnable_cmds < <(expand_multiport_command "$cmd")
      for exec_cmd in "${runnable_cmds[@]}"; do
        if eval "$exec_cmd" &>/dev/null; then
          info "Rule applied: $exec_cmd"
        else
          warn "Failed to apply rule: $exec_cmd"
          fail+=("$exec_cmd")
          fatal=1
        fi
      done
    done
    # ==== Universal Rollback Function ====
    rollback() {
      warn "Rolling back firewall state."
      case "${firewall_backend:-iptables}" in
        nft)
          nft flush ruleset
          if nft -f "$tmp_snapshot" &>/dev/null; then
            success "nftables restored successfully."
            echo "ROLLED_BACK" > "$state_file"
            return 0
          fi
          ;;
        ufw)
          ufw disable &>/dev/null
          ufw reload &>/dev/null
          success "UFW state reset."
          echo "ROLLED_BACK" > "$state_file"
          return 0
          ;;
        firewalld)
          firewall-cmd --reload &>/dev/null
          success "Firewalld reloaded from permanent store."
          echo "ROLLED_BACK" > "$state_file"
          return 0
          ;;
        *)
          if sanitize_and_restore_iptables "$tmp_snapshot"; then
            echo "ROLLED_BACK" > "$state_file"
            return 0
          fi
          ;;
      esac
      # ==== Emergency Flush Fail-Safe ====
      error "CRITICAL: Native restore failed! Emergency recovery engaged."
      if command -v iptables &>/dev/null; then
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F
        iptables -X
        [[ -n "${real_ssh:-}" ]] && iptables -A INPUT -p tcp --dport "$real_ssh" -j ACCEPT
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
      fi
      echo "ROLLED_BACK" > "$state_file"
    }
    if [[ "$fatal" -eq 1 ]]; then
      warn "Rule application failures detected:"
      echo "========================================="
      for f in "${fail[@]}"; do
        error "${yellow}[][]${blue} $f ${yellow}[][]${reset}"
      done
      echo "========================================="
      rollback
      exit 1
    fi
    success "All rules successfully applied."
    echo "PENDING_CONFIRM" > "$state_file"

    # ==== Safety Confirmation Loop ====
    echo
    confirmed=0
    if [[ "$y_interactive" -eq 1 ]]; then
      confirmed=1
      info "Automation Mode: Changes automatically committed."
    else
      printf "${yellow}[SAFETY]:${reset} Firewall will auto-rollback in 10 seconds unless confirmed.\n"
      if ! read -t 10 -rp "$(printf "${cyan}[USER]:${reset} Confirm firewall is functional? (y|yes): ")" safety_confirm; then
        safety_confirm=""
      fi
      safety_confirm="${safety_confirm,,}"
      if [[ "$safety_confirm" == "y" || "$safety_confirm" == "yes" ]]; then
        confirmed=1
      fi
    fi

    if [[ "$confirmed" -eq 1 ]]; then
      echo "COMMITTED" > "$state_file"
      success "Firewall changes confirmed and committed."
      info "Please save your rules with ${cyan}one-click engine backup${reset}"
      sleep 1
      rm -f "$tmp_snapshot" "$confirm_file"
    else
      warn "Confirmation not received. Triggering rollback."
      rollback
      warn "No changes applied."
    fi
  else
    warn "No changes applied."
    exit 0
  fi
}
