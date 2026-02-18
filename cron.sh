#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK CRONS  MODULE * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ========================== #================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== Cron logic ====
validate_cron_field() {
  local val="$1"
  local max="$2"
  local field_name="$3"
  if [[ ! "$val" =~ ^[0-9\*\/\,\-]+$ ]]; then
    error "Invalid characters in $field_name."
    return 1
  fi
  [[ "$val" == "*" ]] && return 0
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    if (( val > max )); then
      error "$field_name ($val) exceeds maximum ($max)."
      return 1
    fi
  fi
  return 0
}
decrypt_cron() {
  local days months time_str dow_str day_str month_str schedule tz_val val unit
  schedule="$1"
  tz_val="$2"
  read -r min hour day month dow <<< "$schedule"
  days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  months=("" January February March April May June July August September October November December)
  translate_field() {
    val="$1"
    unit="$2"
    [[ "$val" == "*" ]] && echo "every $unit" || echo "$val"
  }
  if [[ "$hour" =~ ^[0-9]+$ && "$min" =~ ^[0-9]+$ ]]; then
    time_str=$(date -d "${hour}:${min}" +"%I:%M %p" 2>/dev/null || echo "${hour}:${min}")
  else
    time_str="$(translate_field "$min" "minute") past $(translate_field "$hour" "hour")"
  fi
  if [[ "$dow" =~ ^[0-6]$ ]]; then
    dow_str="${days[$dow]}"
  else
    dow_str="every day"
  fi
  if [[ "$day" =~ ^[0-9]+$ ]]; then
    case "$day" in
      1|21|31) suffix="st" ;;
      2|22)    suffix="nd" ;;
      3|23)    suffix="rd" ;;
      *)       suffix="th" ;;
    esac
    day_str="the ${day}${suffix}"
  else
    day_str="every day of the month"
  fi
  if [[ "$month" =~ ^[0-9]+$ ]]; then
    month_str="in ${months[$month]}"
  else
    month_str="every month"
  fi
  success "Cron job successfully installed" \
  "${grey}Your backup is scheduled to run on ${cyan}${dow_str}, ${day_str} ${month_str} ${grey}at ${cyan}${time_str} (${tz_val:-UTC}). ${green}[SUCCESS]${reset}"
}
select_timezone() {
  check=${1:-}
  clear
  printf '%s\n' " " "${red}[${yellow}CRON CONFIGURATOR${red}]${reset}" \
    "Cron configurations are timezone-oriented for predictable behavior." \
    "You can enter your exact schedule and use any notation that cron by default accepts:" 
  if [[ "$check" -eq 1 ]]; then
    echo
    read -rp "Please enter an alias to identify this cronjob by: " id
  fi
  printf '%s\n'  " " "${ul}Available countries:${ul_reset}"
  # ==== List countries ====
  countries=()
  for tz in /usr/share/zoneinfo/*; do
    [[ -d "$tz" ]] || continue
    country=$(basename "$tz")
    [[ "$country" == "Etc" || "$country" == "posix" || "$country" == "right" ]] && continue
    countries+=("$country")
  done
  for i in "${!countries[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${countries[$i]}"
  done
  read -rp "${cyan}[USER]${reset} Please select your country by number: " country_idx
  country_idx=$((country_idx-1))
  user_country="${countries[$country_idx]}"
  # ==== List timezones in country ====
  tz_list=()
  echo; echo "Available timezones in $user_country:"
  for tz in /usr/share/zoneinfo/"$user_country"/*; do
    [[ -f "$tz" ]] || continue
    tz_name="$user_country/$(basename "$tz")"
    tz_list+=("$tz_name")
  done
  for i in "${!tz_list[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${tz_list[$i]}"
  done
  read -rp "${cyan}[USER]${reset} Please select your timezone by number: " tz_idx
  tz_idx=$((tz_idx-1))
  echo
  user_tz="${tz_list[$tz_idx]}"
}
input_cron_schedule() {
  fields=(
    "minute|59|*"
    "hour|23|*"
    "day|31|*"
    "month|12|*"
    "weekday|6|*"
  )
  set -f
  cron_parts=()
  for field in "${fields[@]}"; do
    IFS='|' read -r name max default <<< "$field"
    while true; do
      read -rp "${cyan}[USER]${reset} Enter $name ($default for any, max $max) [*]: " user_input
      user_input=${user_input:-$default}
      if validate_cron_field "$user_input" "$max" "$name"; then
        cron_parts+=("$user_input")
        break
      fi
    done
  done
  final_cron_schedule="${cron_parts[*]}"
  success "Schedule set to: $final_cron_schedule"
  set +f
}
add_cron_job() {
  local schedule tz cmd comment logfile current_cron existing_cron cron_cmd
  schedule="$1"
  tz="$2"
  cmd="$3"
  comment="$4"
  logfile="$5"
  current_cron=$(crontab -l 2>/dev/null)
  existing_cron=$(sed -n "\,# ${comment}$,p" <<< "$current_cron")
  if [[ -n "$existing_cron" ]]; then
    echo
    warn "${yellow}CRON JOB EXISTS FOR: ${comment}${reset}"
    echo
    delete_cron_job
    exec < /dev/tty
    return
  fi
  cron_cmd="${schedule} TZ=\"${tz}\" ${cmd}"
  [[ -n "$logfile" ]] && cron_cmd+=" >> \"$logfile\" 2>&1"
  cron_cmd+=" # ${comment}"
  info "Adding cron job: ${cyan}${cron_cmd}${reset}"
  (echo "$current_cron"; echo "$cron_cmd") | crontab -
  decrypt_cron "$schedule" "$tz"
  sleep 2
}
install_cron() {
  local set_flag base_comment set_menu profile
  set_flag="$1"
  base_comment="$2"
  set_menu="$3"
  profile="${4:-}"
  backup_dest="${5:-l}"
  select_timezone 0
  input_cron_schedule
  if [[ "$set_menu" == "y" ]]; then
    local cmd="$0 $set_flag --profile=${profile} --backup-dest=${backup_dest} --non-interactive "
  else
    local cmd="$0 $set_flag --non-interactive"
  fi
  local comment="${profile}:${base_comment}"
  local logfile="/var/log/oneclick-cron.log"
  add_cron_job "$final_cron_schedule" "$user_tz" "$cmd" "$comment" "$logfile"
  exec < /dev/tty
  [[ "$set_menu" == "y" ]] && run_menu
  [[ "$set_menu" == "r" ]] && recovery_menu
  [[ "$set_menu" == "v" ]] && network_select_option
}
install_my_cron() {
  local id base_comment
  base_comment="$1"
  logfile="/var/log/oneclick-cron.log"
  select_timezone 1
  while true; do
    read -rp "${cyan}[USER]${reset} Enter full command or script path: " user_cmd
    [[ -n "$user_cmd" ]] && break
    warn "Command cannot be empty"
  done
  input_cron_schedule
  local comment="${id}:${base_comment}"
  add_cron_job "$final_cron_schedule" "$user_tz" "$user_cmd" "$comment" "$logfile"
}
list_cron_jobs() {
  local i=1
  local cron
  cron=$(crontab -l 2>/dev/null)
  if [[ -z "$cron" ]]; then
    warn "No cron jobs found."
    return
  fi
  echo
  printf "%s\n" "${ul}Current cron jobs:${ul_reset}"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    printf " %2d) %s\n" "$i" "$line"
    cron_map[$i]="$line"
    ((i++))
  done <<< "$cron"
}
delete_cron_job() {
  local cron new_cron choice
  cron=$(crontab -l 2>/dev/null)
  [[ -z "$cron" ]] && { warn "No cron jobs to delete."; return; }
  mapfile -t cron_map <<< "$(list_cron_jobs | awk '{print $0}')"
  list_cron_jobs
  echo
  read -rp "${cyan}[USER]${reset} Enter job number(s) to delete (e.g. 1 or 1 3 5), Enter to cancel: " choice
  [[ -z "$choice" ]] && return
  new_cron="$cron"
  for idx in $choice; do
    if [[ -n "${cron_map[$idx]}" ]]; then
      new_cron=$(sed "\|${cron_map[$idx]}|d" <<< "$new_cron")
      success "Removed cron job #$idx"
    else
      warn "Invalid selection: $idx"
    fi
  done
  echo "$new_cron" | crontab -
}
cron_menu() {
  header_notice "$cron_title" "$cron_banner" "18" "4"
  while true; do
    clear
    echo
    printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
      "${red}[${yellow}CRON MANAGEMENT${red}]${reset}" \
      "[1]. Add a cron job (custom command)" \
      "[2]. View cron jobs" \
      "[3]. Delete cron job(s)" \
      "[4]. Exit"
    read -rp "${cyan}[USER]${reset} Select an option: " choice
    case "$choice" in
      1)
        install_my_cron "One-Click Cron Configurator"
        read -rp "Press Enter to return to menu..."
        ;;
      2)
        list_cron_jobs
        read -rp "Press Enter to return to menu..."
        ;;
      3)
        delete_cron_job
        read -rp "Press Enter to return to menu..."
        ;;
      4)
        exit 0
        ;;
      "")
        continue
        ;;
      *)
        warn "Invalid option"
        sleep 1
        ;;
    esac
  done
}
# ==== End Cron Logic ==== #
