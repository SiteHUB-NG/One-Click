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
# === Build: Jan 2026 === # === Updated: May 2026 == # === Version#: 1.0.0 === #
# ====== One-Click ====== #
# ==== OCB Module ==== 
collect_sysinfo
install_dep "fio" "type fio" "fio" "$pkg_mgr" true
install_dep "iperf3" "type iperf3" "iperf3" "$pkg_mgr" true
install_dep "sysbench" "type sysbench" "sysbench" "$pkg_mgr" true
mkdir -p /etc/one-click/ocb/benchmarks
# ==== Check System Resources ====
clear
if curl -s -X POST http://api.oneclick.i.ng:4000/v1/request-token -H "Content-Type: application/json" &> /dev/null; then
  #key=$(curl -s -X POST http://api.oneclick.i.ng:4000/v1/request-token -H "Content-Type: application/json" | jq -r .token)
  challenge=$(curl -s -X POST http://api.oneclick.i.ng:4000/v1/request-challenge \
    | jq -r .challenge)
  echo -n "$challenge" > /tmp/ocb.txt
  challenged=$(openssl pkeyutl -sign \
    -inkey /etc/one-click/ocb/ocb.pem -rawin \
    -in /tmp/ocb.txt | base64 -w0)
  key=$(curl -s -X POST http://api.oneclick.i.ng:4000/v1/request-token \
    -H "Content-Type: application/json" \
    -d "{
      \"challenge\": \"$challenge\",
      \"signature\": \"$challenged\"
    }" | jq -r .token)
else
  warn "Token unavailable. Will not be able to publish results"
fi
no_gb=0
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
if grep -E -q '(vmx|svm)' /proc/cpuinfo; then
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
 #   "AES-NI"|"VM-x/AMD-V"|"Connectivity"|"Disk") pad=$((pad + 2)) ;;
 #   "Connectivity")                              pad=$((pad + 6)) ;;
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
  lsblk -dno NAME,SIZE,TYPE | awk '$3=="disk"{print $1,$2}' | while read -r d s; do
    print_row "$key_width" "$val_width" "Disk$((++i))" "${yellow}${d}${blue} - $s"
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
ram_bench() {
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
}
gb_check() {
  if (( avail_mem < 1500 )); then
    printf "$(tput setaf 100)%s${reset}\n" \
      "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐" \
      "│ RAM is not enough to run Geekbench.                                                              │" \
      "│ Geekbench will not be run. Will use sysbench instead.                                            │" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    no_gb=1
  fi
  if (( avail_disk < 7 )); then
    printf "$(tput setaf 100)%s${reset}\n" \
      "┌──────────────────────────────────────────────────────────────────────────────────────────────────┐" \
      "│ Storage is too small for Geekbench.                                                              │" \
      "│ Geekbench will not be run. Will use sysbench instead.                                            │" \
      "└──────────────────────────────────────────────────────────────────────────────────────────────────┘"
    no_gb=1
  fi
}
iperf_run() {
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
}
run_sysbench() {
  threads=$(nproc)
  time_sec=65
  cpu_max_prime=30000
  cpu_output=$(sysbench cpu --threads=$threads --time=$time_sec --cpu-max-prime=$cpu_max_prime run)
  # ==== PARSE RESULTS ====
  total_time=$(awk -F: '/total time:/ {gsub(/ /,"",$2); print $2}' <<< "$cpu_output")
  events_sec=$(awk -F: '/events per second:/ {gsub(/ /,"",$2); print $2}' <<< "$cpu_output")
  min_time=$(awk -F: '/min:/ {gsub(/ /,"",$2); print $2}' <<< "$cpu_output")
  avg_time=$(awk -F: '/avg:/ {gsub(/ /,"",$2); print $2}' <<< "$cpu_output")
  max_time=$(awk -F: '/max:/ {gsub(/ /,"",$2); print $2}' <<< "$cpu_output")
  # ==== Config ====
  printf '%s=%s\n' \
    "avg_time" "$avg_time" \
    "max_time" "$max_time" > /etc/one-click/ocb/temp.conf
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
}
# ==== Run Script ====
run_ocb() {
  avail_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  avail_disk=$(awk 'NR != 1 {print $4}' <(sed 's/G//g' <(df -BG /)))
  local version gb_path gb_url
  version="${1:-6}"
  gb_path="/etc/one-click/ocb/geekbench_${version:-6}"
  mkdir -p "$gb_path"
  # ==== Detect package ====
  if [[ $version == "6" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench6"
    gb_run="True"
  elif [[ $version == "5" ]]; then
    gb_url=$(get_latest_gb "$version") || return
    gb_cmd="geekbench5"
    gb_run="True"
  else
    return
  fi
  header_notice "$ocb_header" "$ocb_banner" "3" "62"
  init
  expand_country "${country:-}"
  print_table
  fio_cpu_benchmark
  fio_disk_benchmark
  ram_bench
  iperf_run
  if (( no_gb == 1 )); then
    run_sysbench 
  else
    geekbench_table "${version:-6}" "$gb_path" 
  fi
}
run_ocb_pipe() {
  avail_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  avail_disk=$(awk 'NR != 1 {print $4}' <(sed 's/G//g' <(df -BG /)))
  gb_check
  if (( no_gb == 1 )); then
    bench_result="/etc/one-click/ocb/benchmarks/bench_$(date +'%F-%T').sysbench"
    run_ocb | tee -a "$bench_result"
    sed -Ei '
      s/^[^├└T┌│]*//g;
      s/(.*[^├└T┌│]).*$/\1/
      /Preparing Geekbench/d
    ' "$bench_result"
    end=$(date +%s)
    source /etc/one-click/ocb/temp.conf
    if [[ -n "$key" ]]; then
      raw=$(base64 -w 0 "$bench_result")
      response=$(
        jq -n \
          --arg id "$bench_ext" \
          --arg version "1" \
          --arg tool "One-Click Bench" \
          --arg provider "One-Click Bench" \
          --arg raw "$raw" \
          --argjson single "$avg_time" \
          --argjson multi "$max_time" \
          '{
            id: $id,
            version: $version,
            tool: $tool,
            provider: $provider,
            benchmark: {
              single: $single,
              multi: $multi
            },
            raw_output: $raw
          }' | curl -s -X POST "http://api.oneclick.i.ng:4000/v1/publish" \
            -H "Content-Type: application/json" \
            -H "x-ocb-token: '"$key"'" \
            --data-binary @-
      )
      url=$(echo "$response" | jq -r '.url')
    fi
  else
    bench_result="/etc/one-click/ocb/benchmarks/bench_$(date +'%F-%T').gb${version:-6}"
    run_ocb | tee -a "$bench_result"
    source /etc/one-click/ocb/temp.conf
    sed -Ei '
      s/\x1B\[[0-9;]*[mK]//g;
      s/\x0F|\r//g;
      s/ Running iperf3 test to[^│]*│//;
      /Preparing Geekbench|Initializing Fio|Running (read|write) test/d
    '  "$bench_result"
    end=$(date +%s)
    if [[ -n "$key" && "$no_gb" -eq 0 ]]; then
      raw=$(base64 -w 0 "$bench_result")
      response=$(
        jq -n \
          --arg id "$gb_id" \
          --arg version "$version" \
          --arg tool "One-Click Bench" \
          --arg provider "One-Click Bench" \
          --arg raw "$raw" \
          --argjson single "$single" \
          --argjson multi "$multi" \
          '{
            id: $id,
            version: $version,
            tool: $tool,
            provider: $provider,
            benchmark: {
              single: $single,
              multi: $multi
            },
            raw_output: $raw
          }' | curl -s -X POST "http://api.oneclick.i.ng:4000/v1/publish" \
            -H "Content-Type: application/json" \
            -H "x-ocb-token: '"$key"'" \
            --data-binary @-
      )
      url=$(echo "$response" | jq -r '.url')
      total_time "$start" "$end" "$url" "$key"
      exit 0
    fi
  fi
  total_time "$start" "$end" "$url" "$key"
  rm -f /etc/one-click/ocb/temp.conf
  exit 0
}
geek() {
  header_notice "$ocb_header" "$ocb_banner" "3" "62"
  if (( no_gb == 1 )); then
    run_sysbench
  else
    geekbench_table "${version:-6}" "$gb_path"
  fi
}
cpu_sys() {
  avail_mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  avail_disk=$(awk 'NR != 1 {print $4}' <(sed 's/G//g' <(df -BG /)))
  mkdir -p /etc/one-click/ocb
  gb_check
  if (( no_gb == 1 )); then
    bench_ext="bench_$(date +'%F-%T').sysbench"
    bench_result="/etc/one-click/ocb/benchmarks/$bench_ext"
    geek | tee -a "$bench_result"
    sed -Ei '
      s/^[^├└T┌│]*//g;
      s/(.*[^├└T┌│]).*$/\1/
      /Preparing Geekbench/d
    ' "$bench_result"
    end=$(date +%s)
    source /etc/one-click/ocb/temp.conf
    if [[ -n "$key" ]]; then
      raw=$(base64 -w 0 "$bench_result")
      response=$(
        jq -n \
          --arg id "$bench_ext" \
          --arg version "1" \
          --arg tool "One-Click Bench" \
          --arg provider "One-Click Bench" \
          --arg raw "$raw" \
          --argjson single "$avg_time" \
          --argjson multi "$max_time" \
          '{
            id: $id,
            version: $version,
            tool: $tool,
            provider: $provider,
            benchmark: {
              single: $single,
              multi: $multi
            },
            raw_output: $raw
          }' | curl -s -X POST "http://api.oneclick.i.ng:4000/v1/publish" \
            -H "Content-Type: application/json" \
            -H "x-ocb-token: '"$key"'" \
            --data-binary @-
      )
      url=$(echo "$response" | jq -r '.url')
    fi
  else
    version="${1:-6}"
    gb_path="/etc/one-click/ocb/geekbench_${version:-6}"
    bench_result="/etc/one-click/ocb/benchmarks/bench-only_$(date +'%F-%T').gb${1:-6}"
    mkdir -p "$gb_path"
    # ==== Detect package ====
    if [[ $version == "6" ]]; then
      gb_url=$(get_latest_gb "$version") || return
      gb_cmd="geekbench6"
      gb_run="True"
    elif [[ $version == "5" ]]; then
      gb_url=$(get_latest_gb "$version") || return
      gb_cmd="geekbench5"
      gb_run="True"
    else
      return
    fi
    geek | tee -a "$bench_result"
    sed -Ei '
      s/\x1B\[[0-9;]*[mK]//g;
      s/\x0F|\r//g;
      s/ Running iperf3 test to[^│]*│//;
      /Preparing Geekbench|Initializing Fio|Running (read|write) test/d
    '  "$bench_result"
    source /etc/one-click/ocb/temp.conf
    end=$(date +%s)
    if [[ -n "$key" ]]; then
      raw=$(base64 -w 0 "$bench_result")
      response=$(
        jq -n \
          --arg id "$gb_id" \
          --arg version "$version" \
          --arg tool "One-Click Bench" \
          --arg provider "One-Click Bench" \
          --arg raw "$raw" \
          --argjson single "$single" \
          --argjson multi "$multi" \
          '{
            id: $id,
            version: $version,
            tool: $tool,
            provider: $provider,
            benchmark: {
              single: $single,
              multi: $multi
            },
            raw_output: $raw
          }' | curl -s -X POST "http://api.oneclick.i.ng:4000/v1/publish" \
            -H "Content-Type: application/json" \
            -H "x-ocb-token: '"$key"'" \
            --data-binary @-
      )
      url=$(echo "$response" | jq -r '.url')
    fi
  fi
  total_time "$start" "$end" "$url" "$key"
  rm -f /etc/one-click/ocb/temp.conf
  exit 0
}
