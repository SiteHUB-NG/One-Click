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
st=$(date +%s)
virt=$(systemd-detect-virt)
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
    printf "${blue}│$(tput setaf 195) %-20s ${blue}│${reset} %-36s ${blue}│\n" "${1:-}" "$2"
  }
  # ==== Info Header ====
  print_section() {
    #printf "${blue}┌─────────────────────────────────────────────────────────────┐\n"
    printf "${blue}├──────────────────────┴──────────────────────────────────────┤\n"
    printf "│ %-63s \n" "${1:-}"
    printf "├──────────────────────┬──────────────────────────────────────┤${reset}\n"
  }
  legend() {
    local current_time=$(date +%s)
    local elapsed=$(( current_time - st ))
    key_col=$(tput setaf 217)
    desc_col=$(tput setaf 195)
    local timer=$(printf '%02d:%02d:%02d' $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60)))
    printf '%s\n' \
      " " " " \
      "${blue}┌───┬────────┐" \
      "│ ${key_col}p ${blue}│${desc_col} Pause${blue}  │" \
      "│ ${key_col}r ${blue}│${desc_col} Resume${blue} │" \
      "│ ${key_col}h ${blue}│${desc_col} Hide${blue}   │" \
      "│ ${key_col}u ${blue}│${desc_col} Unhide${blue} │" \
      "│ ${key_col}q ${blue}│${desc_col} Quit${blue}   │" \
      "├───┴────────┼──────────┐" \
      "│${key_col}System Time ${blue}│${desc_col} $(date +'%T')${blue} │" \
      "│${key_col}Time Elapsed${blue}│${desc_col} ${timer}${blue} │" \
      "└────────────┴──────────┘${reset}"
  }
  # ==== Info Table ====
  print_table() {
    clear
    # ==== Build System Info ====
    print_section "==================== ${yellow}NETWORK INFO${blue} ==========================│" \
      | sed '1{s/├/┌/;s/┤/┐/;s/┴/─/}'
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
    print_section "======================= ${yellow}OS INFO${blue} ============================│"
    print_row "OS" "$PRETTY_NAME"
    print_row "Kernel" "$kern"
    print_row "Shell" "$SHELL"
    print_row "Uptime" "$(uptime -p)"
    print_row "Up Since" "$(uptime -s)"
    print_row "Load" "$(cut -d' ' -f1-3 /proc/loadavg)"
    print_row "Virtualization" "${virt^^}"
    print_row "CPU" "$cpu_model"
    print_row "Cores" "$cpu"
    if command -v mpstat &> /dev/null; then
      steal=$(mpstat -P ALL | awk '{for (i=1;i<NF;i++) if ($i=="%steal") steal=i;}NR==4{print $steal}')
      print_row "Steal" "$steal"
    fi
    print_row "Entropy" "$entropy"
    print_section "======================= ${yellow}MEMORY${blue} =============================│"
    print_row "RAM Usage" "$(awk '/^MemTotal:/ { t=$2 } /^MemAvailable:/ { a=$2 } END { printf "%.2f / %.2f GB", (t-a)/1024/1024, t/1024/1024 }' /proc/meminfo)"
    print_row "Swap Usage" "$(awk '$1=="Swap:" {print $3" / "$2"B"}' <(free -h))"
    print_row "Dirty Wait" "$(awk '/^Dirty:/{print $2 $3}' <(cat /proc/meminfo))"
    print_section "===================== ${yellow}DISK HEALTH${blue} ==========================│"
    print_row "Disk Used" "$(awk '$NF == "/" {print $3" / "$2}' <(df -h))"
    print_row "Disk IO" "$(awk '{for (i=1;i<NF;i++) if ($i=="%iowait") steal=i;}NR==4{ print $steal}' <(iostat -x 1 1))"
    printf "${blue}└──────────────────────┴──────────────────────────────────────┘${reset}\n"
  }
  spinner_frames=('-' '\' '|' '/')
  pw='\'
  spinner_framess=('/' '|' '\' '-')
  i=0
  lc=1
  refresh=true
  # ==== Main loop ====
  while true; do
    entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    ent_val="$entropy"
    if [[ "$refresh" = true ]]; then
      clear
      paste <(print_table) <(legend) 
      [[ "$hide_mode" == true ]] && status_text="ON (HIDDEN)"
      i=$(( (i + 1) % 4 ))
      spinner="${spinner_frames[i]}"
      spinner2="${spinner_framess[i]}"
      printf "\rRefresh: ON %s" "$spinner"
      if [[ "$hide_mode" == true ]]; then
        printf "\nHidden: ON %s" "$spinner2"
        printf '\n%s' "Press $(tput setaf 217)u$(tput sgr 0) to unhide: "
      else
        printf "\nHidden: OFF %s" "$spinner2"
        printf '\n%s\n' "Press $(tput setaf 217)h$(tput sgr 0) to hide: "
      fi
    fi
    if read -s -t 0.5 -n 1 key; then
      case "$key" in
        e)
          install_dep "havged" "grep haveged <(systemctl list-unit-files)" "haveged" "$pkg_mgr"
          systemctl enable haveged --now
          ;;
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
          if [[ "$hide_mode" == true ]]; then
            printf '\n%s' "Press $(tput setaf 217)u$(tput sgr 0) to unhide: "
          else
            printf '\n%s' "Press $(tput setaf 217)h$(tput sgr 0) to hide: "
          fi
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
    ((lc++))
  done
}
# ==== End Of System Info ==== #
