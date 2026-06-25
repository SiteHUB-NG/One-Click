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
# === Build: Jan 2026 === # === Updated: June 2026 == # === Version#: 1.2.0 === #
# ====== One-Click ====== #
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
    systemctl enable fail2ban --now
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
    if  [[ "$flag" == "-y" || "$y_int" == "-y" ]]; then
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
  #touch "${engine_dir}guard/"{ssh,ddos}
  # ==== Default Sensitive Ports (Remove from here) ====
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
  detect_firewall_backend
  if iptables -V 2>/dev/null | grep -qi nf_tables; then
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
  # ==== Parse all subcommands first ====
  for sub in "${subcommands[@]}"; do
    parse_firewall_command "$sub" "$last_proto"
  done
  # ==== Deduplicate against kernel ====
  unique_cmds=()
  for cmd in "${generated_cmds[@]}"; do
    read -r -a arr <<< "$cmd"
    if [[ "${fw_bin:-}" == "iptables" || "${fw_bin:-}" == "ip6tables" ]]; then
        if "${fw_bin:-}" -C "${arr[@]}" &>/dev/null; then
            info "Skipping duplicate rule already in kernel: $cmd"
            duplicate_skipped=1
            continue
        fi
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
  # ==== Preview & Confirm ==== 
  if [[ "$dry_run" -eq 1 ]]; then
    printf "${magenta}[DRY-RUN]${reset} %s\n" "The following commands will be executed:"
  else
    info "The following commands will be executed:"
  fi
  for cmd in "${unique_cmds[@]}"; do
    # ==== Capitalize RAW Display Entries ====
    cmd=$(
        sed -E '
        s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
        s/input|output|forward|prerouting/\U&/g
    ' <<< "$cmd")
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
    i=""
    fw_bin="${fw_bin:-iptables}"
    save_cmd="${fw_bin}-save"
    case "$fw_bin" in
      ip6tables)
        restore_cmd="ip6tables-restore"
        ;;
      *)
        restore_cmd="iptables-restore"
        ;;
    esac
    tmp_snapshot=$(mktemp /tmp/${fw_bin}_backup.XXXXXX)
    confirm_file=$(mktemp /tmp/fw_confirmed.XXXXXX)
    state_file=$(mktemp /tmp/fw_state.XXXXXX)
    echo "APPLYING" > "$state_file"
    trap '
      rm -f "${tmp_snapshot:-}" "${confirm_file:-}" "${state_file:-}" 2>/dev/null
    ' EXIT INT TERM
    if ! "$save_cmd" > "$tmp_snapshot"; then
      error "Failed to create firewall snapshot!"
      exit 1
    fi
    fail=()
    fatal=0
    # ==== Dry Run ====
    if [[ "$dry_run" -eq 1 ]]; then
      dry_run "${unique_cmds[@]}" || {
        printf "${magenta}[DRY-RUN]${red} %s${reset}\n" \
          "Dry run failed. Exiting without applying rules."
        exit 1
      }
    fi
    # ==== Apply Rules ====
    for cmd in "${unique_cmds[@]}"; do
      cmd="${cmd#raw: }"
      cmd=$(
        sed -E '
          s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
          s/input|output|forward|prerouting/\U&/g;
        ' <<< "$cmd"
      )
      read -r -a arr <<< "$cmd"
      if "${arr[@]}"; then
        info "Rule applied: $cmd"
      else
        warn "Failed to apply rule: $cmd"
        fail+=("$cmd")
        fatal=1
      fi
    done
    # ==== Rollback ====
    rollback() {
      warn "Rolling back firewall state..."
      if "$restore_cmd" < "$tmp_snapshot"; then
        success "Firewall restored successfully."
        echo "ROLLED_BACK" > "$state_file"
      else
        error "CRITICAL: Restore failed!"
        warn "Emergency recovery engaged..."
        "${fw_bin}" -P INPUT ACCEPT
        "${fw_bin}" -P OUTPUT ACCEPT
        "${fw_bin}" -P FORWARD ACCEPT
        "${fw_bin}" -F
        "${fw_bin}" -X
        if [[ -n "${real_ssh:-}" ]]; then
          "${fw_bin}" -A INPUT -p tcp --dport "$real_ssh" -j ACCEPT
        fi
        "${fw_bin}" -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        echo "ROLLED_BACK" > "$state_file"
      fi
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
    # ==== Confirmation ====
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
      success "Firewall rules persisted."
      rm -f "$tmp_snapshot" "$confirm_file"
    else
      warn "Confirmation not received. Triggering rollback..."
      rollback
      warn "No changes applied"
    fi
  else
    warn "No changes applied."
    exit 0
  fi
}
