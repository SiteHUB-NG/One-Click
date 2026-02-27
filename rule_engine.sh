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
  if [[ "pkg_mgr" == "apt" ]]; then
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
  elif [[ "$pkg_mgr" == "dnf" ]]; then
    install_dep "iptables" "type iptables" "iptables" "$pkg_mgr" true
    install_dep "iptables-services" "type iptables-services" "iptables-services" "$pkg_mgr" true
  fi
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
  sensitive_ports=(22 3389 80 443)
  rule_lower=${rule,,}
  rule_lower=$(sed -E 's/ ?(how to|please|can you|help|fix|this) ?//g' <<< "$rule_lower")
  last_action=""
  generated_cmds=()
  detect_firewall_backend
  if iptables -V 2>/dev/null | grep -qi nf_tables; then
    info "iptables is running in nf_tables compatibility mode."
  fi
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
    parse_firewall_command "$sub"
  done
  # ==== Deduplicate against kernel ====
  unique_cmds=()
  for cmd in "${generated_cmds[@]}"; do
    read -r -a arr <<< "$cmd"
    # Skip if rule already exists in kernel
    if [[ "${fw_bin:-}" == "iptables" || "${fw_bin:-}" == "ip6tables" ]]; then
      if iptables -C "${arr[@]}" &>/dev/null; then
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
    for cmd in "${unique_cmds[@]}"; do
      cmd="${cmd#raw: }"
      # ==== Handle RAW Entries ====
      cmd=$(
        sed -E '
          s/^([^-]*)(-[a-ik-lnoq-su-z])(.*[ \t])(.*)/\1\U\2\L\3\U\4/;
          s/input|output|forward|prerouting/\U&/g
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
      die "Installation Failed!"
    else
      success "All rules successfully applied."
      exit 0
    fi
  else
    warn "No changes applied."
    exit 0
  fi
}
