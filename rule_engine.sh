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
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== Firewall RuleEngine ==== 
rule_engine() {
  if [[ "$pkg_mgr" == "apt" ]]; then
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    install_dep "iptables" "command -v iptables" "iptables iptables-services" "$pkg_mgr" true
  fi
  declare -gA alerted_ports=()
  engine_dir="/etc/one-click/rule-engine/"
  alias_file=/etc/one-click/rule-engine/.alias.conf
  real_ssh=$(sed -En '/sshd/{/0.0:/{s/^[^:]*:([0-9]+).*/\1/p}}' <(ss -ltnp))
  rule="$1"
  flag="${2:-}"
  dry_run=0
  duplicate_skipped=0
  if [[ "$flag" == "--dry-run" ]]; then
    dry_run=1
    shift
  fi
  if [[ -z "$rule" ]]; then
    die "Usage: one-click rule-engine [--dry-run] '<rule in human words wrapped in quotes>'"
  fi
  mkdir -p "$engine_dir"
  touch "$alias_file"
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
    info "iptables is running in nf_tables compatibility mode."
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
    die "No valid commands generated."
  fi
  # ==== Dry-run preview ====
  if [[ "$dry_run" -eq 1 ]]; then
    info "[DRY RUN] The following commands would be executed:"
    for cmd in "${unique_cmds[@]}"; do
        echo "  $cmd"
    done
    exit 0
  fi
  # ==== Preview & Confirm ==== 
  info "The following commands will be executed:"
  for cmd in "${unique_cmds[@]}"; do
    # ==== Capitalize RAW Display Entries ====
    cmd=$(
        sed -E '
        s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
        s/input|output|forward|prerouting/\U&/g
    ' <<< "$cmd")
    printf "${cyan}[COMMAND]: %s${reset}\n" "$cmd"
  done
  echo
  read -rp "${cyan}[USER]:${reset} Apply ALL rules? (y|n): " confirm
  confirm="${confirm,,}"
  if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
    i=""
    # ==== Take snapshot BEFORE applying rule ====
    tmp_snapshot=$(mktemp /tmp/iptables_backup.XXXXXX)
    "${fw_bin:-iptables}-save" > "$tmp_snapshot"
    # ==== Launch background rollback timer (10s) ====
    (
      sleep 13
      if [[ ! -f /tmp/fw_confirmed ]]; then
        warn "No confirmation received. Reverting firewall to previous state..."
        if iptables-restore < "$tmp_snapshot"; then
          success "Firewall successfully reverted to previous state."
        else
          error "Failed to revert firewall from snapshot!"
        fi
      fi
    ) &
    rollback_pid=$!
    fail=()
    fatal=0
    for cmd in "${unique_cmds[@]}"; do
      cmd="${cmd#raw: }"
      # ==== Handle RAW Entries ====
      cmd=$(
        sed -E '
          s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
          s/input|output|forward|prerouting/\U&/g;
      ' <<< "$cmd")
      read -r -a arr <<< "$cmd"
       # ==== Execute Commands ====
      if "${arr[@]}"; then
        info "Rule applied: $cmd"
      else
        warn "Failed to apply rule: $cmd"
        fail+=("$cmd")
        fatal=1
      fi
    done
    if [[ "${fatal:-}" -eq 1 ]]; then
      warn "The following commands failed to install:"
      echo "========================================="
      for f in "${fail[@]}"; do
        error "${yellow}[][]${blue} $f ${yellow}[][]${reset}"
      done
      echo "========================================="
    else
      success "All rules successfully applied."
    fi
  else
    warn "No changes applied."
    exit 0
  fi
  echo
  echo "${yellow}[SAFETY]:${reset} Firewall configuration will rollback in 10 seconds if not confirmed functional!"
  if ! read -t 10 -rp "${cyan}[USER]:${reset} Confirm rule is safe? (y|yes to keep): " safety_confirm ; then
    safety_confirm=""
  fi
  safety_confirm="${safety_confirm,,}"
  echo
  if [[ "$safety_confirm" == "y" || "$safety_confirm" == "yes" ]]; then
    touch /tmp/fw_confirmed
    kill "$rollback_pid" 2>/dev/null
    success "Rule confirmed and persisted in memory."
    info "Please save your rules with ${cyan}one-click engine backup${reset}"
    sleep 1
    success "Firewall rules persisted."
    rm -f "$tmp_snapshot" /tmp/fw_confirmed
  else
    wait "$rollback_pid"
    warn "No changes applied"
  fi
}
