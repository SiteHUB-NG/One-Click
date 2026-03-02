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
install_dep "cron" "command -v cron" "cron" "$pkg_mgr" true
trap 'cron_menu' SIGUSR1
draw_table_row() {
  local index="$1"
  local schedule="$2"
  local command="$3"
  n_run="$4"
  local display_cmd="${command:0:67}"
  [[ ${#command} -gt 67 ]] && display_cmd+="..."
  printf "${blue}│ ${reset}%-3s ${blue}│ ${reset}%-18s ${blue}│ ${reset}%-70s ${blue}│${reset}%-20s ${blue}│${reset}\n" "$index" "$schedule" "$display_cmd" "$n_run"
}
get_next_run() {
  local sched="$1"
  read -r m h dom mon dow <<< "$sched"
  if [[ "$m" =~ / || "$h" =~ / ]]; then
    local now_ts=$(date +%s)
    for (( i=1; i<=1440; i++ )); do
      local t_ts=$(( now_ts + (i * 60) ))
      local t_m=$(date -d "@$t_ts" +%-M); local t_h=$(date -d "@$t_ts" +%-H)
      [[ "$m" =~ / ]] && (( t_m % ${m#*/} != 0 )) && continue
      [[ "$h" =~ / ]] && (( t_h % ${h#*/} != 0 )) && continue
      [[ "$m" != "*" && "$m" != "$t_m" && ! "$m" =~ / ]] && continue
      [[ "$h" != "*" && "$h" != "$t_h" && ! "$h" =~ / ]] && continue
      date -d "@$t_ts" +"%b %d, %H:%M" && return
    done
  fi
  local target_m="${m#0}"; [[ "$target_m" == "*" ]] && target_m=$(date +%-M)
  local target_h="${h#0}"; [[ "$target_h" == "*" ]] && target_h=$(date +%-H)
  local current_year=$(date +%Y)
  if [[ "$mon" =~ ^[0-9]+$ && "$dom" =~ ^[0-9]+$ ]]; then
    # Construct the date for THIS year
    local target_date="$current_year-$mon-$dom $target_h:$target_m"
    local target_ts=$(date -d "$target_date" +%s 2>/dev/null)
    local now_ts=$(date +%s)
    if [[ -z "$target_ts" || $target_ts -lt $now_ts ]]; then
      # If it passed or date is invalid (Feb 29), move to NEXT year
      date -d "$((current_year + 1))-$mon-$dom $target_h:$target_m" +"%b %d, %H:%M"
    else
      date -d "$target_date" +"%b %d, %H:%M"
    fi
    return
  fi
  if [[ "$dow" =~ ^[0-9]+$ ]]; then
    local day_diff=$(( (dow - $(date +%w) + 7) % 7 ))
    # If today is Monday but the time has passed, move to next week
    local today_target_ts=$(date -d "$target_h:$target_m" +%s 2>/dev/null)
    [[ $day_diff -eq 0 && $today_target_ts -lt $(date +%s) ]] && day_diff=7
    date -d "$day_diff days $target_h:$target_m" +"%b %d, %H:%M"
    return
  fi
  local today_ts=$(date -d "$target_h:$target_m" +%s 2>/dev/null)
  if [[ $today_ts -lt $(date +%s) ]]; then
    date -d "tomorrow $target_h:$target_m" +"%b %d, %H:%M"
  else
    date -d "today $target_h:$target_m" +"%b %d, %H:%M"
  fi
}
list_cron_jobs() {
  local i=1
  local cron=$(crontab -l 2>/dev/null)
  if [[ -z "$cron" ]]; then
    warn "No cron jobs found."
    return 1
  fi
  printf "${blue}%s\n${reset}" \
    "┌─────┬────────────────────┬────────────────────────────────────────────────────────────────────────┬─────────────────────┐" \
    "│ ID  │ SCHEDULE           │ COMMAND / PATH                                                         │ NEXT ESTIMATED RUN  │" \
    "├─────┼────────────────────┼────────────────────────────────────────────────────────────────────────┼─────────────────────┤"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    local sched=$(echo "$line" | awk '{print $1,$2,$3,$4,$5}')
    local cmd=$(sed -E 's/^[0-9/ *]+[ \t]+(TZ="[^"]*"[ \t]+)?(.*)/\2/' <<< "$line")
    local comment=$(echo "$line" | grep -oP '(?<=# ).*' | cut -d':' -f1)
    local min=$(echo "$sched" | awk '{print $1}')
    local hr=$(echo "$sched" | awk '{print $2}')
    local next_est="Projecting..."
    if [[ "$sched" == "@reboot" ]]; then
      next_est="On Next Boot"
    else
      next_est=$(get_next_run "$sched")
    fi
    draw_table_row "$i" "$sched" "$cmd" "$next_est"
    cron_map[$i]="$line"
    ((i++))
  done <<< "$cron"
  echo -e "${blue}└─────┴────────────────────┴────────────────────────────────────────────────────────────────────────┴─────────────────────┘${reset}"
}
validate_cron_field() {
  local val max field_name
  val="$1"
  max="$2"
  field_name="$3"
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
  local days months time_str dow_str day_str month_str schedule tz_val val unit next run
  schedule="$1"
  tz_val="$2"
  read -r min hour day month dow <<< "$schedule"
  days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  months=("" January February March April May June July August September October November December)
  translate_field() {
    local val="$1"
    local unit="$2"
    if [[ "$val" == "*" ]]; then
      echo "every $unit"
    elif [[ "$val" =~ ^\*/([0-9]+)$ ]]; then
      echo "every ${BASH_REMATCH[1]} ${unit}s"
    elif [[ "$val" =~ , ]]; then
      echo "at ${unit}s ${val}"
    else
      echo "$val"
    fi
  }
  if [[ "$hour" =~ ^[0-9]+$ && "$min" =~ ^[0-9]+$ ]]; then
    time_str=$(date -d "${hour}:${min}" +"%I:%M %p" 2>/dev/null || echo "${hour}:${min}")
    local now_sec=$(date +%s)
    local target_sec=$(date -d "$hour:$min" +%s 2>/dev/null)
    if (( target_sec < now_sec )); then
      next_run=$(date -d "tomorrow $hour:$min" +"%A, %B %d at %I:%M %p")
    else
      next_run=$(date -d "$hour:$min" +"%A, %B %d at %I:%M %p")
    fi
    echo -e "${grey}Next scheduled run: ${yellow}${next_run}${reset}"
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
  return
}
select_timezone() {
  local check=${1:-0}
  local search_dir="/usr/share/zoneinfo"
  if [[ "$check" -eq 1 ]]; then
    read -rp "${cyan}[USER]${reset} Enter an alias for this job (e.g., backup-db): " id
  fi
  while true; do
    read -rp "${cyan}[USER]${reset} Enter Timezone (e.g., 'WAT', 'Lagos', 'London', 'Warsaw' or 'list'): " tz_input
    if [[ "$tz_input" == "list" ]]; then
      find "$search_dir" -type f | sed "s|$search_dir/||g" | grep -vE 'Etc/|posix/|right/' | column
      continue
    fi
    local matches=($(find "$search_dir" -type f | grep -i "$tz_input" | sed "s|$search_dir/||g"))
    if [[ ${#matches[@]} -eq 1 ]]; then
      user_tz="${matches[0]}"
      break
    elif [[ ${#matches[@]} -gt 1 ]]; then
      echo -e "${yellow}Multiple matches found. Please be more specific:${reset}"
      printf "%s\n" "${matches[@]}" | head -n 10
    else
      warn "No timezone found for '$tz_input'. Try 'UTC' or 'list'."
    fi
  done
  success "Timezone set to: $user_tz"
}
convert_human_to_cron() {
  local input=${1,,}
  case "$input" in
    sun*) echo 0 ;; mon*) echo 1  ;; tue*) echo 2  ;; wed*) echo 3  ;; 
    thu*) echo 4 ;; fri*) echo 5  ;; sat*) echo 6  ;;
    jan*) echo 1 ;; feb*) echo 2  ;; mar*) echo 3  ;; apr*) echo 4  ;; 
    may*) echo 5 ;; jun*) echo 6  ;; jul*) echo 7  ;; aug*) echo 8  ;; 
    sep*) echo 9 ;; oct*) echo 10 ;; nov*) echo 11 ;; dec*) echo 12 ;;
    *) echo "$1" ;;
  esac
}
input_cron_schedule() {
  printf '%s\n' "${yellow}Cron Syntax Guide:${reset}" \
    "  ${cyan}*${reset}      : Every unit (every minute/hour)" \
    "  ${cyan}*/10${reset}   : Every 10th unit (e.g., every 10 mins)" \
    "  ${cyan}1-5${reset}    : Range (e.g., Monday through Friday)" \
    "  ${cyan}0,30${reset}   : Specific units (e.g., on the hour and half-hour)"
  fields=(
    "minute|59|0"
    "hour|23|*"
    "day|31|*"
    "month|12|*"
    "weekday|6|*"
  )
  cron_parts=()
  for field in "${fields[@]}"; do
    IFS='|' read -r name max default <<< "$field"
    while true; do
      read -rp "${cyan}[USER]${reset} $name ($default): " user_input
      user_input=${user_input:-$default}
      user_input=$(convert_human_to_cron "$user_input")
      if validate_cron_field "$user_input" "$max" "$name"; then
        cron_parts+=("$user_input")
        break
      fi
    done
  done
  final_cron_schedule="${cron_parts[*]}"
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
  base_comment="$1"
  logfile="/var/log/oneclick-cron.log"
  select_timezone 1
  while true; do
    read -rp "${cyan}[USER]${reset} Enter full command or script path: " user_cmd
    [[ -n "$user_cmd" ]] && break
    warn "Command cannot be empty"
  done
  if [[ -f "$user_cmd" && ! -x "$user_cmd" ]]; then
    warn "Warning: This file exists but is not executable. Remember to chmod +x it."
    read -rp "${cyan}[USER]:${reset}Would you like to make it executable now (y|n): " ex_cmd
    ex_cmd="${ex_cmd,,}"
    [[ "$ex_cmd" == "y" || "$ex_cmd" == "yes" ]] && chmod +x "$user_cmd"
  fi
  input_cron_schedule
  local comment="${id}:${base_comment}"
  add_cron_job "$final_cron_schedule" "$user_tz" "$user_cmd" "$comment" "$logfile"
}
delete_cron_job() {
  local cron new_cron choice
  cron=$(crontab -l 2>/dev/null)
  [[ -z "$cron" ]] && { warn "No cron jobs to delete."; return; }
  list_cron_jobs
  echo
  read -rp "${cyan}[USER]${reset} Enter job number(s) to delete (e.g. 1 or 1 3 5), Enter to cancel: " choice
  [[ -z "$choice" ]] && return
  new_cron="$cron"
  for idx in $choice; do
    if [[ -n "${cron_map[$idx]}" ]]; then
      new_cron=$(echo "$new_cron" | grep -vF "${cron_map[$idx]}")
      success "Removed cron job #$idx"
    else
      warn "Invalid selection: $idx"
    fi
  done
  echo "$new_cron" | crontab -
}
cron_menu() {
  header_notice "$cron_title" #"$cron_banner" "18" "4"
  install_dep "cron" "command -v cron" "cron" "$pkg_mgr" true
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
