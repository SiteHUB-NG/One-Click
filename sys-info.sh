#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK BACK-UP TOOL  * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ============================================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== System information widget ====
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
    print_row "IP Country" "$ip_country"
    print_row "Provider" "$ip_upstream"
    print_row "ASN Number" "$ip_asn"
    for n in "${ns[@]}"; do
      print_row "Nameserver" "$n"
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
    printf "└─────────────────────────────────────────────────────────────┘\n"
    print_section "======================= MEMORY =============================│"
    print_row "RAM Usage" "$(awk '/^MemTotal:/ { t=$2 } /^MemAvailable:/ { a=$2 } END { printf "%.2f / %.2f GB", (t-a)/1024/1024, t/1024/1024 }' /proc/meminfo)"
    printf "└─────────────────────────────────────────────────────────────┘\n"
    print_section "===================== DISK HEALTH ==========================│"
    print_row "Disk Used" "$(awk '$NF == "/" {print $3" / "$2}' <(df -h))"
    print_row "Disk Capacity" "$drive_cap"
    print_row "Disk IO" "$(iostat -xz | awk '$1 ~ /^[svn][vd][ma]/{print $3}')"
    printf "└─────────────────────────────────────────────────────────────┘\n"
  }
  i=0
  while true; do
    print_table
    spinner="${spinner_frames[i % 4]}"
    printf "\r%s %s %s %s" \
      "${red}${r1[i]}" \
      "${blue}${r2[i]}" \
      "$(tput setaf 5)${r3[i]}" \
      "$spinner" \
      "${reset}"
    i=$(( (i + 1) % 4 ))
    sleep 2
  done
}
# ==== End Of System Info ==== #
