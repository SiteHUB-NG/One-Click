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
install_dep "sysbench" "type sysbench" "sysbench" "$pkg_mgr" true
# ==== Check System Resources ====
clear
start=$(date +%s)
disk=($(ls -1 /sys/block/))
cpu_model=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
size="$ram"
read_ram=$(sysbench memory --memory-block-size=1M --memory-total-size="$size" --memory-oper=read run)
write_ram=$(sysbench memory --memory-block-size=1M --memory-total-size="$size" --memory-oper=write run)
throughput=($(awk -F'[)(]' '/MiB/{print $2}' <<< "$read_ram"))
total=$(awk '/transferred/{print $1}' <<< "$read_ram")
ops=$(awk '/operations:/{print $3}' <<< "$read_ram")
write_throughput=($(awk -F'[)(]' '/MiB/{print $2}' <<< "$write_ram"))
write_total=$(awk '/transferred/{print $1}' <<< "$write_ram")
write_ops=$(awk '/operations:/{print $3}' <<< "$write_ram")
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
  i=0
  n=0
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
  lsblk -dno NAME,TYPE | awk '$2=="disk"{print $1}' | while read -r d; do
    print_row "$key_width" "$val_width" "Disk$((++i))" "${yellow}${d}${blue} - $size"
    if [[ -r /sys/block/$d/device/modalias ]]; then
      name=$(< /sys/block/$d/device/modalias)
    elif [[ -r /sys/block/$d/device/model ]]; then
      name=$(< /sys/block/$d/device/model)
    elif [[ -r /sys/block/$d/device/vendor ]]; then
      vendor=$(< /sys/block/$d/device/vendor)
      name="$vendor VirtIO Disk"
    else
        name="Unknown Disk"
    fi
    print_row "$key_width" "$val_width" "Disk Name$((++n))" "$(tput setaf 214)$name${blue}"
  done 
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
run_ocb_no_gb() {
  local version gb_path gb_url
  header_notice "$ocb_header" "$ocb_banner" "3" "62"
  init
  expand_country "${country:-}"
  print_table
  fio_cpu_benchmark
  fio_disk_benchmark
  # ==== RAM BENCH ====
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "Test" "Total MiB" "MiB/sec" "Ops/sec"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ RAM Bandwidth Benchmark                                                                          │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"

  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "Read" "$total" "${throughput[0]}" "$ops" \
    "Write" "$write_total" "${write_throughput[0]}" "$write_ops"
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
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
  
  threads=$(nproc)
  time_sec=65
  cpu_max_prime=30000
  cpu_output=$(sysbench cpu --threads=$threads --time=$time_sec --cpu-max-prime=$cpu_max_prime run)
  # ==== PARSE RESULTS ====
  total_time=$(echo "$cpu_output" | awk -F: '/total time:/ {gsub(/ /,"",$2); print $2}')
  events_sec=$(echo "$cpu_output" | awk -F: '/events per second:/ {gsub(/ /,"",$2); print $2}')
  min_time=$(echo "$cpu_output" | awk -F: '/min:/ {gsub(/ /,"",$2); print $2}')
  avg_time=$(echo "$cpu_output" | awk -F: '/avg:/ {gsub(/ /,"",$2); print $2}')
  max_time=$(echo "$cpu_output" | awk -F: '/max:/ {gsub(/ /,"",$2); print $2}')
  # ==== PRINT TABLE ====
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "Test" "Total Sec" "Events/sec" "Min/Avg/Max Sec"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ CPU Benchmark (sysbench)                                                                         │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤ "
  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "CPU Multi-Core" "$total_time" "$events_sec" "$min_time / $avg_time / $max_time"
  printf "${blue}%s${reset}\n" \
  "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
  end=$(date +%s)
  total_time "start" "end"
}
run_ocb() {
  avail_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  avail_disk=$(awk 'NR != 1 {print $4}' <(sed 's/G//g' <(df -BG /)))
  if (( avail_mem < 1500 )); then
    warn "Less than 1.5GB RAM." "Geekbench will not be run. Will use sysbench instead."
    run_ocb_no_gb
  fi
  if (( avail_disk < 7 )); then
    warn "Less than 7GB Storage." "Geekbench will not be run. Will use sysbench instead."
    run_ocb_no_gb
  fi
  local version gb_path gb_url
  version="${1:-6}"
  gb_path="/etc/one-click/ocb/geekbench_${version:-6}"
  mkdir -p "$gb_path"
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
  # ==== RAM BENCH ====
  printf "${blue}%s${reset}\n" \
    "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐"
  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "Test" "Total MiB" "MiB/sec" "Ops/sec"
  printf "${yellow}%s${reset}\n" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤" \
    "│ RAM Bandwidth Benchmark                                                                          │" \
    "├──────────────────────────────────────────────────────────────────────────────────────────────────┤"

  printf "${blue}│%-20s %-15s %-15s %-45s│${reset}\n" \
    "Read" "$total" "${throughput[0]}" "$ops" \
    "Write" "$write_total" "${write_throughput[0]}" "$write_ops"
  printf "${blue}%s${reset}\n" \
    "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
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
