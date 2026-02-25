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
  rule="$1"
  flag="${2:-}"
  dry_run=0
  if [[ "$flag" == "--dry-run" ]]; then
    dry_run=1
    shift
  fi
  if [[ -z "$rule" ]]; then
    die "Usage: one-click rule-engine [--dry-run] <rule in human words>"
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
  check_firewall_available
  rule_normalized=$(sed -E 's/[\t ]+and[\t ]+|,+/|/g' <<< "$rule_lower")
  IFS='|' read -ra subcommands <<< "$rule_normalized"
  for sub in "${subcommands[@]}"; do
    if grep -Eq "\b(drop|deny|block|stop|close)\b" <<< "$sub"; then
      last_action="DROP"
      break
    elif grep -Eq "\b(reject|decline|bounce)\b" <<< "$sub"; then
      last_action="REJECT"
      break
    elif grep -Eq "\b(open|allow|permit|accept|add)\b" <<< "$sub"; then
      last_action="ACCEPT"
      break
    elif grep -Eq "\b(delete|remove)\b" <<< "$sub"; then
      last_action="DELETE"
      break
    fi
  done
  for sub in "${subcommands[@]}"; do
    parse_firewall_command "$sub"
  done
  # ==== Exit if no command passed ====
  if [[ ${#generated_cmds[@]} -eq 0 ]]; then
    die "No valid commands generated."
  fi
  # ==== Non-Interactive Run ====
  if [[ "$dry_run" -eq 1 ]]; then
    info "[DRY RUN] The following commands would be executed:"
    for cmd in "${generated_cmds[@]}"; do
      echo "  $cmd"
    done
    exit 0
  fi
  # ==== Preview & Confirm ====
  info "The following commands will be executed:"
  for cmd in "${generated_cmds[@]}"; do
    printf "${green}[COMMAND]: %s${reset}\n" "$cmd"
  done
  echo
  read -rp "Apply ALL rules? (y|n): " confirm
  confirm="${confirm,,}"
  if [[ "$confirm" == "y" || "$confirm" == "yes" ]]; then
    for cmd in "${generated_cmds[@]}"; do
      if [[ "$dry_run" -eq 1 ]]; then
        printf '%s\r' "${yellow}[DRY RUN]${reset} The following commands would be executed:"
        printf '%s\n' "${yellow}[DRY RUN]${reset} $cmd"
      else
        eval "$cmd"
      fi
    done
    success "All rules successfully applied."
  else
    warn "No changes applied."
  fi
}    
