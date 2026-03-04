#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK SYSINFO MODULE* reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== System information widget ====
hide_mode=true
cpu_model=$(sed -E 's/^([^@]*).*/\1/' <<< $cpu_model)
ip_asn=$(sed -E 's/^([^ \t]*).*/\1/' <<< "$ip_asn")
ip_upstream=$(sed -E 's/^[^ ]* (.*)/\1/' <<< "$ip_upstream")
x_site_ip="$(sed -En '/wg0/,$ {/inet/s,^[^/]* ([0-9.]+)/.*,\1,p}' <(ip a s))"
x_site_gw="$(awk -F"[=: ]" '/Endpoint/{print $4}' <(wg showconf wg0))"
who_ip="$whois_ip"
sys_gwd="$sys_gw"
x_site_gwd="$x_site_gw"
x_site_ipd="$x_site_ip"
sys_info() {
  strip_ansi() {
    sed -E 's/\x1B\[[0-9;]*[mK]//g'
  }
  center_block() {
    strip_ansi | awk -v w="$term_width" '
    {
      len = length($0)
      pad = int((w - len) / 2)
      if (pad < 0) pad = 0
      printf "%*s%s\n", pad, "", $0
    }'
  }
  hidden() {
    if [[ "$hide_mode" == true ]]; then
      whois_ip=$(sed -E ':a;s/^([^.]*\.([.*]+)?)[0-9]/\1*/;ta' <<< "$whois_ip")
      sys_gw=$(sed -E ':a;s/^([^.]*\.([.*]+)?)[0-9]/\1*/;ta' <<< "$sys_gw")
      x_site_ip=$(sed -E ':a;s/^([^.]*\.([.*]+)?)[0-9]/\1*/;ta' <<< "$x_site_ip")
      x_site_gw=$(sed -E ':a;s/^([^.]*\.([.*]+)?)[0-9]/\1*/;ta' <<< "$x_site_gw")
    else
      whois_ip="$who_ip"
      sys_gw="$sys_gwd"
      x_site_ip="$x_site_ipd"
      x_site_gw="$x_site_gwd"
    fi
  }
  hidden
  print_row() {
    printf "│ %-20s │ %-36s │\n" "${1:-}" "$2"
  }
  # ==== Info Header ====
  print_section() {
    printf "┌─────────────────────────────────────────────────────────────┐\n"
    printf "│ %-63s \n" "${1:-}"
    printf "├─────────────────────────────────────────────────────────────┤\n"
  }
  # ==== Info Table ====
  print_table() {
    clear
    # ==== Build System Info ====
    print_section "==================== NETWORK INFO ==========================│"
    print_row "IP Address" "$whois_ip"
    print_row "Gateway" "$sys_gw"
    if command -v wg showconf wg0 &> /dev/null; then
      print_row "Cross-Site IP" "$x_site_ip"
      print_row "Cross-Site Endpoint" "$x_site_gw"
    fi
    expand_country $ip_country
    print_row "IP Country" "$country"
    print_row "Provider" "$ip_upstream"
    print_row "ASN Number" "$ip_asn"
    for n in "${ns[@]}"; do
      print_row "Nameserver$((++i))" "$n"
    done
    print_row "Hostname" "$HOSTNAME"
    printf "└─────────────────────────────────────────────────────────────┘\n"
    print_section "======================= OS INFO ============================│"
    print_row "OS" "$PRETTY_NAME"
    print_row "Kernel" "$kern"
    print_row "Shell" "$SHELL"
    print_row "Uptime" "$(uptime -p)"
    print_row "Up Since" "$(uptime -s)"
    print_row "Load" "$(cut -d' ' -f1-3 /proc/loadavg)"
    print_row "CPU" "$cpu_model"
    print_row "Cores" "$cpu"
    if command -v mpstat &> /dev/null; then
      steal=$(mpstat -P ALL | awk '{for (i=1;i<NF;i++) if ($i=="%steal") steal=i;}NR==4{print $steal}')
      print_row "Steal" "$steal"
    fi
    printf "└─────────────────────────────────────────────────────────────┘\n"
    print_section "======================= MEMORY =============================│"
    print_row "RAM Usage" "$(awk '/^MemTotal:/ { t=$2 } /^MemAvailable:/ { a=$2 } END { printf "%.2f / %.2f GB", (t-a)/1024/1024, t/1024/1024 }' /proc/meminfo)"
    print_row "Swap Usage" "$(awk '$1=="Swap:" {print $3" / "$2"B"}' <(free -h))"
    printf "└─────────────────────────────────────────────────────────────┘\n"
    print_section "===================== DISK HEALTH ==========================│"
    print_row "Disk Used" "$(awk '$NF == "/" {print $3" / "$2}' <(df -h))"
    print_row "Disk Capacity" "$drive_cap"
    print_row "Disk IO" "$(awk '{for (i=1;i<NF;i++) if ($i=="%iowait") steal=i;}NR==4{ print $steal}' <(iostat -x 1 1))"
    #print_row "Disk IO" "$(iostat -xz | awk '$1 ~ /^[svn][vd][ma]/{print $3}')"
    printf "└─────────────────────────────────────────────────────────────┘\n"
  }
  spinner_frames=('-' '\' '|' '/')
  i=0
  refresh=true
  # ==== Main loop ====
  while true; do
    if [[ "$refresh" = true ]]; then
      clear
      print_table
      [[ "$hide_mode" == true ]] && status_text="ON (HIDDEN)"
      i=$(( (i + 1) % 4 ))
      spinner="${spinner_frames[i]}"
      printf "\rRefresh: ON %s" "$spinner"
      if [[ "$hide_mode" == true ]]; then
        printf '\n%s' "Press $(tput setaf 217)u$(tput sgr 0) to unhide"
      else
        printf '\n%s' "Press $(tput setaf 217)h$(tput sgr 0) to hide"
      fi
    fi
    if read -t 0.5 -n 1 key; then
      case "$key" in
        h) 
          hide_mode=true
          hidden
          if [[ "$refresh" == false ]]; then
            print_table
          fi
          ;;
        p)
          refresh=false
          printf "\r%-80s\r" ""
          echo "Refresh PAUSED. Press $(tput setaf 217)r$(tput sgr 0) to resume."
          ;;
        r)
          refresh=true
          ;;
        q)
          clear
          break
          ;;
        u)
          hide_mode=false
          hidden
          if [[ "$refresh" == false ]]; then
            print_table
          fi
          ;;
      esac
    fi
    if [[ "$refresh" = true ]]; then
      sleep 1
    else
      sleep 0.2
    fi
  done
}
# ==== End Of System Info ==== #
