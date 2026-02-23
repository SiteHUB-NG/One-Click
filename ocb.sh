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
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.0.0 === #
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
  ram="$(awk '/Mem/{print $2}' <(free -h))B"
elif [[ "${#ram}" -eq 5 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B"
elif [[ "${#ram}" -eq 6 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B"
elif [[ "${#ram}" -eq 7 ]]; then
  ram="$(awk '/Mem/{print $2}' <(free -h))B"
fi
if [[ "${#swap}" -eq 4 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B"
elif [[ "${#swap}" -eq 5 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B"
elif [[ "${#swap}" -eq 6 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B"
elif [[ "${#swap}" -eq 7 ]]; then
  swap="$(awk '/Swap/{print $2}' <(free -h))B"
fi
if [[ "${#uptime}" -eq 19 ]]; then
  uptime="${uptime}"
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
  ipv4="${green}✔ IPv4: Online${blue}"
else
  ipv4="${red}✖ IPv4: Offline${blue}"
fi
if is_v6_online; then
  ipv6="${green}✔ IPv6: Online${blue}"
else
  ipv6="${red}✖ IPv6: Offline${blue}"
fi
if [[ "$ipv4" == "✔ IPv4: Online" ]]; then
  primary=IPv4
else
  primary=IPv6
fi
if grep -q aes /proc/cpuinfo; then
    aes="${green}✔ Yes${blue}"
else
    aes="${red}✖ No${blue}"
fi
if egrep -q '(vmx|svm)' /proc/cpuinfo; then
    x_v="${green}✔ Yes${blue}"
else
    x_v="${red}✖ No${blue}"
fi
}
print_row() {
  local key_width val_width key val cleaned visible pad
  key_width="$1"
  val_width="$2"
  key="$3"
  val="$4"
  cleaned=$(sed -r 's/\x1B\[[0-9;]*[mK]//g' <<< "$val")
  visible=$(printf "%s" "$cleaned" | wc -m)
  pad=$((val_width - visible))
  case "$key" in
    "AES-NI"|"VM-x/AMD-V"|"Connectivity"|"Disk") pad=$((pad + 2)) ;;
    "Connectivity")                              pad=$((pad + 6)) ;;
 #   "Disk")                                      pad=$((pad + 1)) ;;                                     
  esac
  (( pad < 0 )) && pad=0
  printf "${blue}│ %-*s │ %s%*s │${reset}\n" \
    "$key_width" "$key" \
    "$val" "$pad" ""
}
print_table() {
  local key_width val_width total_width inner_width border core_plural
  key_width=15
  val_width=78
  if [[ "${cpu_cores:-}" -gt 1 ]]; then
    core_plural="cores"
  else
    core_plural="core"
  fi
  total_width=$((key_width + val_width + 7))
  inner_width=$((total_width - 2))
  border=$(printf '─%.0s' $(seq 1 "$inner_width"))
  printf "${blue}┌%s┐${reset}\n" "$border"
  printf "${blue}│ %-*s │${reset}\n" "$((total_width-4))" "Basic System Information"
  printf "${blue}├%s┤${reset}\n" "$border"
  print_row "$key_width" "$val_width" "Uptime" "$uptime"
  print_row "$key_width" "$val_width" "Processor" "$cpu_model @ $freq"
  print_row "$key_width" "$val_width" "Cores" "$cpu_cores $core_plural"
  print_row "$key_width" "$val_width" "AES-NI" "$aes"
  print_row "$key_width" "$val_width" "VM-x/AMD-V" "$x_v"
  print_row "$key_width" "$val_width" "RAM" "$ram"
  print_row "$key_width" "$val_width" "Swap" "$swap"
  print_row "$key_width" "$val_width" "Disk" "${disk[*]}"
  print_row "$key_width" "$val_width" "Distro" "$distro"
  print_row "$key_width" "$val_width" "Kernel" "$kernel"
  print_row "$key_width" "$val_width" "VM Type" "$virt"
  print_row "$key_width" "$val_width" "Connectivity" "$ipv4 / $ipv6"
  print_row "$key_width" "$val_width" "ISP" "$ip_upstream"
  print_row "$key_width" "$val_width" "ASN" "${ip_asn:-Unknown}"
  print_row "$key_width" "$val_width" "Hostname" "$HOSTNAME"
  print_row "$key_width" "$val_width" "Location" "$location"
  print_row "$key_width" "$val_width" "Country" "$country"
  printf "${blue}└%s┘${reset}\n" "$border"
}
run_ocb() {
  local version gb_path gb_url
  version="${1:-6}"
  gb_path="/etc/one-click/ocb/geekbench_${version:-6}"
  if [[ $version == "6" ]]; then
    if [[ "${arch:-}" == *aarch64* || "${ARCH:-}" == *arm* ]]; then
      gb_url="https://cdn.geekbench.com/Geekbench-6.5.0-LinuxARMPreview.tar.gz"
    else
      gb_url="https://cdn.geekbench.com/Geekbench-6.5.0-Linux.tar.gz"
    fi
    gb_cmd="geekbench6"
    gb_run="True"
  elif [[ $version == "5" ]]; then
    if [[ "${arch:-}" == *aarch64* || "${arch:-}" == *arm* ]]; then
      gb_url="https://cdn.geekbench.com/Geekbench-5.5.1-LinuxARMPreview.tar.gz"
    else
      gb_url="https://cdn.geekbench.com/Geekbench-5.5.1-Linux.tar.gz"
    fi
    gb_cmd="geekbench5"
    gb_run="True"
  fi
  install_geekbench "$gb_url" "$gb_path" "$version"
  header_notice "$ocb_header" "$ocb_banner" "3" "62"
  init
  expand_country "${country:-}"
  print_table
  fio_cpu_benchmark
  fio_disk_benchmark
  if ping -4 -c1 google.com &> /dev/null; then
    iperf_table "IPv4"
  else
     printf "${red}%s${reset}\n" \
      "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐" \
      "│ No IPv4 connectivity detected. Skipping IPv4 iperf tests.                                        │" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
  fi
  if ping -6 -c1 google.com &>/dev/null; then
    iperf_table "IPv6"
  else
    printf "${red}%s${reset}\n" \
      "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐" \
      "│ No IPv6 connectivity detected. Skipping IPv6 iperf tests.                                        │" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
  fi
  geekbench_table "${version:-6}" "$gb_path"
  end=$(date +%s)
  total_time "start" "end"
}
