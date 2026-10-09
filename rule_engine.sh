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
# === Build: Jan 2026 === # === Updated: Oct 2026 == # === Version#: 1.0.0 === #
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
_one_click_fw_direct_kind() {
  local text="${1:-}" kind=""
  case "$text" in
    audit|audit\ *|ssh\ *|alias-*|sensitive:*|sensitive-remove:*|sensitive-list*|list|list\ *|show|show\ *|view|view\ *|display|display\ *|delete\ alias*|remove\ alias*|purge\ alias*|forget\ alias*)
      kind=parser ;;
    backup|backup\ *|save|save\ *|retain|retain\ *|copy\ firewall*|export\ firewall*|dump\ firewall*|snapshot\ firewall*)
      kind=backup ;;
    restore|restore\ *|revive\ firewall*|recreate\ firewall*|regenerate\ firewall*|repair\ firewall*|import\ firewall*|reinstate\ firewall*)
      kind=restore ;;
    delete\ firewall\ backup*|remove\ firewall\ backup*|purge\ firewall\ backup*|delete\ backup*|remove\ backup*|purge\ backup*)
      kind=delete_backups ;;
    delete\ firewall\ rule*|remove\ firewall\ rule*|purge\ firewall\ rule*|delete\ firewall\ policy*|remove\ firewall\ policy*)
      kind=reject ;;
  esac
  printf '%s' "$kind"
}
_one_click_fw_split_clauses() {
  local input="${1:-}" segment item candidate previous=""
  local action="" protocol="" keyword="" prefix="" suffix=""
  local list re_ports re_bare re_single port
  local -a sections=() entries=() numbers=()
  rule_clauses=()
  input=$(sed -E 's/[[:space:]]+and[[:space:]]+/|/g' <<< "$input") || return 1
  IFS='|' read -r -a sections <<< "$input"
  (( ${#sections[@]} > 0 )) || { error "Empty firewall request."; return 1; }
  re_ports='^(.+[[:space:]])(ports?)[[:space:]]+(([0-9]+([-:][0-9]+)?)([[:space:]]*,[[:space:]]*[0-9]+([-:][0-9]+)?)+)([[:space:]].*)?$'
  re_bare='^(.+[[:space:]])(([0-9]+([-:][0-9]+)?)([[:space:]]*,[[:space:]]*[0-9]+([-:][0-9]+)?)+)([[:space:]].*)?$'
  re_single='^(.+[[:space:]]ports?[[:space:]]+)([0-9]+([-:][0-9]+)?)([[:space:]].*)?$'
  for segment in "${sections[@]}"; do
    segment="${segment#"${segment%%[![:space:]]*}"}"
    segment="${segment%"${segment##*[![:space:]]}"}"
    [[ -n "$segment" ]] || { error "Empty firewall rule clause."; return 1; }
    if [[ "$segment" == ,* || "$segment" == *, || "$segment" == *,,* ]]; then
      error "Malformed firewall comma list: $segment"
      return 1
    fi
    prefix="" suffix="" list=""
    if [[ "$segment" =~ $re_ports ]]; then
      prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]} "
      list="${BASH_REMATCH[3]}"
      suffix="${BASH_REMATCH[8]}"
    elif [[ "$segment" =~ $re_bare ]]; then
      prefix="${BASH_REMATCH[1]}"
      list="${BASH_REMATCH[2]}"
      suffix="${BASH_REMATCH[7]}"
    fi
    if [[ -n "$list" ]]; then
      IFS=',' read -r -a numbers <<< "$list"
      for port in "${numbers[@]}"; do
        port="${port//[[:space:]]/}"
        candidate="${prefix}${port}${suffix}"
        rule_clauses+=("$candidate")
        previous="$candidate"
      done
    else
      IFS=',' read -r -a entries <<< "$segment"
      for item in "${entries[@]}"; do
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        [[ -n "$item" ]] || { error "Empty firewall comma clause."; return 1; }
        candidate="$item"
        if [[ "$item" =~ ^(allow|open|permit|accept|add|block|drop|deny|reject|remove|delete|flush|clear|reset|log)([[:space:]]|$) ]]; then
          : 
        elif [[ -z "$previous" ]]; then
          candidate="$item"
        elif [[ "$item" =~ ^(tcp|udp|icmp|icmpv6)([[:space:]]|$) ]]; then
          candidate="$action $item"
        elif [[ "$item" =~ ^(ports?|range)([[:space:]]|$) ]]; then
          candidate="$action ${protocol:+$protocol }$item"
        elif [[ "$item" =~ ^[0-9]+([-:][0-9]+)?([[:space:]]|$) ]]; then
          if [[ "$previous" =~ $re_single ]]; then
            candidate="${BASH_REMATCH[1]}${item}${BASH_REMATCH[4]}"
          elif [[ "$previous" =~ ^(.+[[:space:]])([0-9]+([-:][0-9]+)?)([[:space:]].*)?$ ]]; then
            candidate="${BASH_REMATCH[1]}${item}${BASH_REMATCH[4]}"
          else
            error "Cannot safely inherit the previous port context for '$item'."
            return 1
          fi
        else
          candidate="$action ${protocol:+$protocol }$item"
        fi
        rule_clauses+=("$candidate")
        previous="$candidate"
        if [[ "$candidate" =~ ^(allow|open|permit|accept|add|block|drop|deny|reject|remove|delete|flush|clear|reset|log)([[:space:]]|$) ]]; then
          action="${BASH_REMATCH[1]}"
        fi
        if [[ "$candidate" =~ (^|[[:space:]])(tcp|udp|icmp|icmpv6)([[:space:]]|$) ]]; then
          protocol="${BASH_REMATCH[2]}"
        else
          protocol=""
        fi
      done
    fi
    if [[ -n "$list" ]]; then
      if [[ "$previous" =~ ^(allow|open|permit|accept|add|block|drop|deny|reject|remove|delete|flush|clear|reset|log)([[:space:]]|$) ]]; then
        action="${BASH_REMATCH[1]}"
      fi
      if [[ "$previous" =~ (^|[[:space:]])(tcp|udp|icmp|icmpv6)([[:space:]]|$) ]]; then
        protocol="${BASH_REMATCH[2]}"
      else
        protocol=""
      fi
    fi
  done
  (( ${#rule_clauses[@]} > 0 && ${#rule_clauses[@]} <= 40 )) || {
    error "Rule request contains no commands or too many commands (maximum 40)."
    return 1
  }
}
# ==== Rule Engine Helpers ====
rule_engine() {
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
  fi
  if [[ "$y_int" == "-y" || "$flag" == "-y" ]]; then
    y_interactive=1
  fi
  if [[ -z "$rule" ]]; then
    die "Usage: one-click rule-engine [--dry-run] '<rule in human words wrapped in quotes>'"
  fi
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
  if [[ "$rule" =~ ^[[:space:]]*[Rr][Aa][Ww]: ]]; then
    if (( dry_run == 1 )); then
      error "[DRY-RUN] Raw shell commands cannot be previewed safely."
      return 1
    fi
    _one_click_fw_raw_dispatch "$rule"
    return $?
  fi
  rule_lower=${rule,,}
  rule_lower=$(sed -E 's/^[[:space:]]*(please|can you|could you|help me|how to)[[:space:]]+//; s/^[[:space:]]+//; s/[[:space:]]+$//' <<< "$rule_lower")
  [[ -n "$rule_lower" ]] || { error "No firewall command provided."; return 1; }
  local direct_kind=""
  direct_kind=$(_one_click_fw_direct_kind "$rule_lower") || return 1
  if [[ -n "$direct_kind" ]]; then
    if (( dry_run == 1 )); then
      error "[DRY-RUN] Direct management actions are not previewable; no changes made."
      return 1
    fi
    _one_click_fw_direct_dispatch "$direct_kind" "$rule"
    return $?
  fi
  detect_firewall_backend
  if (( dry_run == 0 )); then
    _one_click_fw_require_prerequisites "${firewall_backend:-none}" || return 1
  fi
  if (( dry_run == 0 )); then
    mkdir -p "$engine_dir" "${engine_dir}guard/" || return 1
    touch "$alias_file" || return 1
  fi
  last_action=""
  last_proto=""
  generated_cmds=()
  # ==== Stable Backend Environment ==== 
  if command -v iptables &>/dev/null && iptables -V 2>/dev/null | grep -qi nf_tables; then
    if (( dry_run == 1 )); then
      printf "${magenta}[DRY-RUN]${reset} %s\n" "iptables is running in nf_tables compatibility mode."
    else
      info "iptables is running in nf_tables compatibility mode."
    fi
  fi
  load_host_aliases
  _one_click_fw_split_clauses "$rule_lower" || return 1
  local sub
  for sub in "${rule_clauses[@]}"; do
    if [[ -n "$(_one_click_fw_direct_kind "$sub")" ]]; then
      error "Management commands must be issued separately, not in a rule batch."
      return 1
    fi
    last_action=""
    last_proto=""
    parse_firewall_command "$sub" "" || {
      error "Rule parsing failed; no firewall commands applied."
      return 1
    }
  done
  # ==== Validate and safely deduplicate generated operations ====
  unique_cmds=()
  local -a check_argv=()
  local i can_check=0
  for cmd in "${generated_cmds[@]}"; do
    if ! _one_click_fw_command_argv "$cmd"; then
      error "Unsupported or unsafe generated command; refusing batch: $cmd"
      return 1
    fi
    local is_dup=0
    if [[ "${fw_argv[0]}" == iptables || "${fw_argv[0]}" == ip6tables ]]; then
      check_argv=("${fw_argv[@]}")
      can_check=0
      for i in "${!check_argv[@]}"; do
        if [[ "${check_argv[$i]}" == -I || "${check_argv[$i]}" == -A ]]; then
          check_argv[$i]=-C
          can_check=1
          break
        fi
      done
      if (( can_check == 1 )) && "${check_argv[@]}" &>/dev/null; then
        is_dup=1
      fi
    fi
    if (( is_dup == 1 )); then
      info "Skipping duplicate rule already active in kernel: $cmd"
      duplicate_skipped=1
      continue
    fi
    unique_cmds+=("$cmd")
  done
  if [[ ${#unique_cmds[@]} -eq 0 ]]; then
    if [[ "$duplicate_skipped" == "1" ]]; then
      info "All rules already exist. Nothing to change."
      return 0
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
  local sandbox_approved=0
  if (( dry_run == 1 )); then
    if ! declare -F dry_run >/dev/null 2>&1; then
      error "[DRY-RUN] Isolated namespace dry_run() function is unavailable; refusing to apply rules."
      return 1
    fi
    if ! dry_run "${unique_cmds[@]}"; then
      warn "[DRY-RUN] Sandbox failed or application was declined; no live firewall changes attempted."
      return 1
    fi
    sandbox_approved=1
    _one_click_fw_require_prerequisites "${firewall_backend:-none}" || return 1
    mkdir -p "$engine_dir" "${engine_dir}guard/" || return 1
    touch "$alias_file" || return 1
    dry_run=0
  fi
  # ==== Transactional Firewall Apply (Fix 02) ====
  confirm=n
  if (( sandbox_approved == 1 || y_interactive == 1 )); then
    confirm=y
  else
    read -rp "${cyan}[USER]:${reset} Apply ALL rules? (y|n): " confirm || confirm=n
    confirm="${confirm,,}"
  fi
  if [[ "$confirm" != y && "$confirm" != yes ]]; then
    warn "No changes applied."
    return 0
  fi
  local exec_cmd tx_dir tx_base tx_unit tx_result=0 confirmed=0
  local -a apply_cmds=() fail=()
  local -a runnable_cmds=()
  for cmd in "${unique_cmds[@]}"; do
    runnable_cmds=("$cmd")
    apply_cmds+=("${runnable_cmds[@]}")
  done
  if ! _one_click_fw_backend_preflight "${firewall_backend:-none}" "${apply_cmds[@]}"; then
    error "Firewall backend preflight failed; no changes applied."
    return 1
  fi
  if (( ${#apply_cmds[@]} == 0 || ${#apply_cmds[@]} > 40 )); then
    error "Firewall transaction requires 1–40 executable rules; split larger batches."
    return 1
  fi
  tx_base="/run/one-click/rule-engine/transactions"
  if [[ "${ONE_CLICK_FW_TEST_MODE:-}" == 1 ]]; then
    tx_base="${ONE_CLICK_FW_TEST_BASE:?Missing test transaction base}"
  fi
  if (( EUID != 0 )); then
    error "Run One-Click as root to change firewall rules."
    return 1
  fi
  ( umask 077; mkdir -p "$tx_base" ) || return 1
  chmod 700 "$tx_base" || return 1
  tx_dir=$(umask 077; mktemp -d "$tx_base/tx.XXXXXXXX") || {
    error "Cannot allocate protected firewall snapshot storage."
    return 1
  }
  tx_unit="oneclick-fw-$(basename "$tx_dir" | tr -cd 'a-zA-Z0-9')"
  if [[ "$firewall_backend" == ufw || "$firewall_backend" == firewalld ]]; then
    local manager_line
    : > "$tx_dir/manager.plans" || return 1
    : > "$tx_dir/manager.attempts" || return 1
    for exec_cmd in "${apply_cmds[@]}"; do
      manager_line=$(_one_click_fw_manager_plan "$exec_cmd") || {
        error "Unrecognised manager rule: $exec_cmd"; return 1;
      }
      printf '%s\n' "$manager_line" >> "$tx_dir/manager.plans" || return 1
    done
  fi
  if ! _one_click_fw_tx_prepare "$tx_dir" "${firewall_backend:-iptables}" "$tx_unit"; then
    error "Verified firewall snapshot/watchdog unavailable; refusing to apply rules."
    return 1
  fi
  if ! /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" applying; then
    error "Firewall rollback watchdog transaction could not be armed."
    return 1
  fi
  # ==== Execute Rules (bounded; watchdog runs independently of SSH) ====
  local manager_index=0 manager_fd manager_status=0 tx_state
  for exec_cmd in "${apply_cmds[@]}"; do
    if ! _one_click_fw_command_argv "$exec_cmd"; then
      error "Firewall command validation failed during application."
      tx_result=1
      fail+=("$exec_cmd")
      break
    fi
    if ! exec {manager_fd}> "$tx_dir/lock"; then
      tx_result=1; fail+=("$exec_cmd"); break
    fi
    if ! flock -x "$manager_fd"; then
      exec {manager_fd}>&-
      tx_result=1; fail+=("$exec_cmd"); break
    fi
    tx_state=$(<"$tx_dir/state")
    if [[ "$tx_state" != APPLYING ]]; then
      error "Transaction entered state '$tx_state' before command; refusing additional firewall mutations."
      flock -u "$manager_fd"
      exec {manager_fd}>&-
      tx_result=1; fail+=("$exec_cmd"); break
    fi
    if [[ "$firewall_backend" == ufw || "$firewall_backend" == firewalld ]]; then
      if ! printf '%s\n' "$manager_index" >> "$tx_dir/manager.attempts"; then
        flock -u "$manager_fd"; exec {manager_fd}>&-
        tx_result=1; fail+=("$exec_cmd"); break
      fi
    fi
    if timeout --signal=TERM --kill-after=2s 10s "${fw_argv[@]}" &>/dev/null; then
      manager_status=0
    else
      manager_status=$?
    fi
    flock -u "$manager_fd"
    exec {manager_fd}>&-
    (( manager_index += 1 ))
    if (( manager_status == 0 )); then
      info "Rule applied: $exec_cmd"
    else
      warn "Failed to apply rule: $exec_cmd"
      fail+=("$exec_cmd")
      tx_result=1
      break
    fi
  done
  if (( tx_result != 0 )); then
    warn "Rule application failures detected:"
    printf '%s\n' '========================================='
    for exec_cmd in "${fail[@]}"; do
      error "${yellow}[][]${blue} $exec_cmd ${yellow}[][]${reset}"
    done
    printf '%s\n' '========================================='
    warn "Rolling back firewall state."
    if /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" rollback; then
      warn "No changes applied."
    else
      error "Rollback failed. Firewall was NOT flushed. Recovery snapshot: $tx_dir"
    fi
    return 1
  fi
  success "All rules successfully applied."
  if ! /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" pending; then
    error "Firewall confirmation state unavailable; requesting safe rollback."
    /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" rollback || \
      error "CRITICAL: Rollback failed. Recovery snapshot: $tx_dir"
    return 1
  fi
  # ==== Independent Safety Confirmation ====
  if (( y_interactive == 1 )); then
    info "Automation Mode: Changes automatically committed."
    confirmed=1
  else
    printf "${yellow}[SAFETY]:${reset} Firewall will auto-rollback in 10 seconds unless confirmed.\n"
    local safety_confirm=""
    read -t 8 -rp "$(printf "${cyan}[USER]:${reset} Confirm firewall is functional? (y|yes): ")" safety_confirm || safety_confirm=""
    safety_confirm="${safety_confirm,,}"
    [[ "$safety_confirm" == y || "$safety_confirm" == yes ]] && confirmed=1
  fi

  if (( confirmed == 1 )); then
    if /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" commit; then
      success "Firewall changes confirmed and committed."
      info "Please save your rules with ${cyan}one-click engine backup${reset}"
      return 0
    fi
    error "Commit deadline expired or rollback already started."
  else
    warn "Confirmation not received. Triggering rollback."
  fi
  if /usr/bin/bash "$tx_dir/worker.sh" "$tx_dir" rollback; then
    warn "No changes applied."
  else
    error "CRITICAL: Firewall rollback failed; preserved snapshot at: $tx_dir"
  fi
  return 1
}
