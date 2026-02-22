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
# ==== OCB Module ==== 
collect_sysinfo
install_dep "fio" "type fio" "fio" "$pkg_mgr" true
install_dep "iperf3" "type iperf3" "iperf3" "$pkg_mgr" true
clear
start=$(date +%s)
cpu_model=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
ram="${ram:-}"
swap="${swap:-}"
uptime="${uptime:-}"
cpu_cores="${cpu_cores:-}"
freq="${freq:-}"
init() {
if [[ "${#ram}" -eq 4 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B                                                                           │"
elif [[ "${#ram}" -eq 5 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B                                                                          │"
elif [[ "${#ram}" -eq 6 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B                                                                         │"
elif [[ "${#ram}" -eq 7 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B                                                                        │"
fi
if [[ "${#swap}" -eq 4 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B                                                                           │"
elif [[ "${#swap}" -eq 5 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B                                                                          │"
elif [[ "${#swap}" -eq 6 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B                                                                         │"
elif [[ "${#swap}" -eq 7 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B                                                                        │"
fi
if [[ "${#uptime}" -eq 19 ]]; then
  uptime="${uptime}                                                            │"
fi
if command -v systemd-detect-virt &>/dev/null; then
  virt=$(systemd-detect-virt)
  [[ "$virt" == "none" ]] && virt="Baremetal"
elif command -v virt-what &>/dev/null; then
  virt=$(virt-what)
  [[ -z "$virt" ]] && virt="Baremetal"
else
    virt="Unknown"
fi
if is_online; then
  ipv4="${green}✔ IPv4: Online${reset}"
else
  ipv4="${red}✖ IPv4: Offline${reset}"
fi
if is_v6_online; then
  ipv6="${green}✔ IPv6: Online                                                ${blue}│${reset}"
else
  ipv6="${red}✖ IPv6: Offline                                               ${blue}│${reset}"
fi
if [[ "$ipv4" == "✔ IPv4: Online" ]]; then
  primary=IPv4
else
  primary=IPv6
fi
if grep -q aes /proc/cpuinfo; then
    aes="${green}✔ Yes${reset}${blue}                                                                          │"
else
    aes="${red}✖ No${reset}${blue}                                                                         │"
fi
if egrep -q '(vmx|svm)' /proc/cpuinfo; then
    x_v="${green}✔ Yes${reset}${blue}                                                                          │"
else
    x_v="${red}✖ No${reset}${blue}                                                                         │"
fi
}
print_table() {
  # Hardcoded widths
  local key_width=15
  local val_width=95
  if [[ "${cpu_cores:-}" -gt 1 ]]; then
    core_plural="cores                                                                        │"
  else
    core_plural="core                                                                         │"
  fi
  # Top border and header
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐" \
    "│ Basic System Information                                                                         │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"
  # Table rows (key │ value │)
  printf "${blue}│ %-*s │ %-*s${reset}\n" \
    "$key_width" "Uptime" "$val_width" "$uptime                                           │" \
    "$key_width" "Processor" "$val_width" "$cpu_model @ $freq                       │" \
    "$key_width" "Cores" "$val_width" "$cpu_cores $core_plural" \
    "$key_width" "AES-NI" "$val_width" "$aes" \
    "$key_width" "VM-x/AMD-V" "$val_width" "$x_v" \
    "$key_width" "RAM" "$val_width" "$ram" \
    "$key_width" "Swap" "$val_width" "$swap" \
    "$key_width" "Disk" "$val_width" "${disk[*]}                                                                  ${blue}│${reset}" \
    "$key_width" "Distro" "$val_width" "$distro                                                 │" \
    "$key_width" "Kernel" "$val_width" "$kernel                                                            │" \
    "$key_width" "VM Type" "$val_width" "$virt                                                                            │" \
    "$key_width" "Connectivity" "$val_width" "$ipv4 / $ipv6" \
    "$key_width" "ISP" "$val_width" "$ip_upstream                                                                        │" \
    "$key_width" "ASN" "$val_width" "${ip_asn:-Unknown}                                                                        │" \
    "$key_width" "Hostname" "$val_width" "$HOSTNAME                                                                        │" \
    "$key_width" "Location" "$val_width" "$location                                                                          │"  \
    "$key_width" "Country" "$val_width" "$country                                                                        │"
  # Bottom border
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
}
run_ocb() {
  header_notice "$ocb_header" "$ocb_banner" "62" "197"
  init
  print_table
  expand_country "${country:-}"
  fio_cpu_benchmark
  fio_disk_benchmark
  iperf_table "IPv4"
  if ping -6 -c1 google.com &>/dev/null; then
    iperf_table "IPv6"
  else
    printf '%s\n' "No IPv6 connectivity detected. Skipping IPv6 iperf tests."
  fi
  geekbench_table 6
  end=$(date +%s)
  total_time "start" "end"
}
