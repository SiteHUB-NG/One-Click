#!/usr/bin/env bash
# ============================================================================ #
# **************************  Migrator / OS Reinstallation multipurpose Tool.  #
# *Written By Chike Egbuna * DD + Rsync Migrations/Backup modes are available. #
# ************************** Incremental, full + dry backup options available  #
# Server System status available for basic server performance insight + stats. #
# Please note this tool will install numerous required dependencies automatic. #
# Network repair script *************************** OS install feature use tool#
# available fo DD where * ONE-CLICK REINSTALL MOD * reinstall by ~bin456789 to #
# grub + initramfs need *************************** reinstall OS' over network #
# reinitalization after a migration.| *https://github.com/bin456789/reinstall* #
# ========================== #================================================ #
# === Build: Jan 2026 === # === Updated: Feb 2026 == # === Version#: 1.2.5 === #
# ====== One-Click ====== #
# ==== reinstall OS selection ====
trap 'on_error $?' ERR
on_error() {
  local code=$1
  if [[ "$code" -ne 99 ]]; then
    echo "[ERROR] Something went wrong (code $code), cleaning up..."
    cleanup
    exit "$code"
  fi
}
get_os() {
  header_notice "$os_title" "$os_reinstall" "3" "1"
  # ==== Download reinstall script that will be used. ====
  if ! curl -O -s "$reinstall"; then
    warn "Primary reinstall script location unavailable. Trying fallback"
    if ! curl -O -s "$reinstall_secondary"; then
      die "Failed to download critical dependancy"
    else
      reinstall="$reinstall_secondary"
    fi
  fi
  chmod +x $(basename "$reinstall")
}
os_menu() {
  # ==== List all images presented by reinstall ====
  mapfile -t avail_images < <(
    bash $(basename "$reinstall") |
    sed -E '
      /^$/d
      s/^[^a-zA-Z]* ([[:alpha:]]+(\.xyz)?)($|[ \t]+.*)/\1/
      s/Usage:  .\/reinstall.sh |\||[0-9]//g
      /Options:/,$d
    ' |
    awk '{ printf "%d_%s\n", NR, $0 }'
  )
  printf '%s\n' "${avail_images[@]}" | sed 's/_/ /g' \
    | sed -E "
        s/^[0-9]+/${yellow}[${green}ONE-CLICK${yellow}]${reset}[&]./;
        \$ {
          p;
          s/([^]]*\].{6})([^]]*[0-9]+).*/echo \1\$((\2+1))]. Exit/e;
        }
      " \
    | column -t
  # ==== Compare arrays ====
  mapfile -t images < <(
    bash $(basename "$reinstall") |
    sed -E '
      /^$/d
      s/^[^a-zA-Z]* ([[:alpha:]]+(\.xyz)?)($|[ \t]+.*)/\1/
      s/Usage:  .\/reinstall.sh |\||[0-9]//g
      /Options:/,$d
    '
  )
  # ==== Build OS Selection Logic ====
  os_select() {
    local os_choice
    while true; do
      read -rp "${cyan}[USER]${reset} Please select a number for the flavour you would like to install: " os_choice
      # ==== Must be a number ====
      if [[ ! "$os_choice" =~ ^[0-9]+$ ]]; then
        error "Invalid input. Please enter a number."
        sleep 2
        clear
        continue
      fi
      # ==== Must only accept as many options as reinstall has available ====
      if (( os_choice < 1 || os_choice > $((${#images[@]} + 1)) )); then
        info "Selection out of range. Please choose between 1 and ${#images[@]}."
        sleep 2
        clear
        continue
      fi
      # ==== Initial OS Mapping ====
      if [[ "$os_choice" -eq "$((${#images[@]} + 1))" ]]; then
        info "Exiting into TMUX session"
        exit 0
      fi
      os_full="${avail_images[os_choice-1]}"
      os="${os_full#*_}"
      [[ -n "$os" ]] || continue
      break
    done
  return 0
  }
  os_select
}
# ==== End OS Selection ==== #
# ==== One-Click OS Reinstall ====
map_image() {
  # ==== Define OS versions For Image Mapping ====
  declare -A os_versions=(
    [anolis]="7 8 23"
    [opencloudos]="8 9 23"
    [rocky]="8 9 10"
    [oracle]="8 9 10"
    [almalinux]="8 9 10"
    [centos]="9 10"
    [fnos]="1"
    [nixos]="25.11"
    [fedora]="42 43"
    [debian]="9 10 11 12 13"
    [alpine]="3.20 3.21 3.22 3.23"
    [openSUSE]="15.6 16.0 tumbleweed"
    [openeuler]="20.03 22.03 24.03 25.09"
    [ubuntu]="16.04 18.04 20.04 22.04 24.04 25.10"
    [windows]="2012 2016 2019 2022 2025"
    [redhat]="7 8 9"
    [netboot.xyz]=
    [kali]=
    [arch]=
    [gentoo]=
    [aosc]=
  )
  os="${os,,}"
  [[ -n "${os_versions[$os]+_}" ]] || {
    error "Unknown OS: $os"
    return 1
  }
  # ==== Version check ====
  if [[ "$os" == "redhat" ]]; then
    read -rp "${cyan}[USER]${reset} What version of Red Hat would you like (select ${blue}b${reset} to go back)? [7|8|9|b]: " ver
    [[ "$ver" == "b" ]] && {
      clear
      back_button=1
      return 0
    }
    case "$ver" in
      7)
        img="http://access.cdn.redhat.com/.../rhel-server-7.9-x86_64-kvm.qcow2"
        os_name="Red Hat Enterprise Linux 7.9"
        ;;
      8)
        img="http://access.cdn.redhat.com/.../rhel-8.10-x86_64-kvm.qcow2"
        os_name="Red Hat Enterprise Linux 8.10"
        ;;
      9)
        img="http://access.cdn.redhat.com/.../rhel-9.4-x86_64-kvm.qcow2"
        os_name="Red Hat Enterprise Linux 9.4"
        ;;
      *)
        error "Invalid Red Hat version selected"
        sleep 2
        return 1
        ;;
    esac
  elif [[ "$os" == "windows" ]]; then
    read -rp "${cyan}[USER]${reset} What version of $os would you like (select ${blue}b${reset} to go back)? [${os_versions[$os]}|b]: " ver
    [[ "$ver" == "b" ]] && {
      clear
      back_button=1
      return 0
    }
    grep -qw "$ver" <<< "${os_versions[$os]}" || {
      echo "Invalid version"
      return 1
    }
    case "$ver" in
      2012) iso_name="Windows Server 2012 SERVERSTANDARD"; iso="...ISO URL..." ;;
      2016) iso_name="Windows Server 2016 SERVERSTANDARD"; iso="...ISO URL..." ;;
      2019) iso_name="Windows Server 2019 SERVERSTANDARD"; iso="...ISO URL..." ;;
      2022) iso_name="Windows Server 2022 SERVERSTANDARD"; iso="...ISO URL..." ;;
      2025) iso_name="Windows Server 2025 SERVERSTANDARD"; iso="...ISO URL..." ;;
      *)
        error "Invalid selection. Please try again."
        back_button=1
        return 0
        ;;
    esac
  else
    read -rp "${cyan}[USER]${reset} What version of $os would you like (select ${blue}b${reset} to go back)? [${os_versions[$os]}|b]: " ver
    [[ "$ver" == "b" ]] && {
      clear
      back_button=1
      return 0
    }
    if ! grep -qw "$ver" <<< "${os_versions[$os]}"; then
      error "Invalid version. Please try again."
      back_button=1
      return 0
    fi
  fi
  return 0
}
# ==== Does the user want to use ssh-keys? ====
ssh_key() {
  read -rp "${cyan}[USER]${reset} Would you like to configure a SSH key? " key_request
  key_request=${key_request,,}
  if [[ "$key_request" == "yes" || "$key_request" == "y" ]]; then
    req=y
    read -rp "${cyan}[USER]${reset} Please enter your ssh key path: " key
  else
    req=n
    warn "ssh key will not be used."
  fi
}
# ==== Set Password ====
set_pass() {
  info "Please enter [password|pass] or [key|ssh|ssh_key]: "
  read -rp "${cyan}[USER]${reset} Would you like to use a password or SSH key: " req
  req="${req,,}"
  case "$req" in
    password|pass)
      req=n
      read -s -rp "Enter your SSH password for ${user}@${destination_server}: " pass
      echo
      read -s -rp "Please re-enter your password: " pass2
      echo
      # ==== Ensure password was entered accurately ====
      while [[ ! "$pass" == "$pass2" ]]; do
      warn "${red}Passwords do not match${reset}" "${green}Please try again${reset}"
      set_pass
      done
      ;;
    key|ssh|ssh_key)
      req=y
      ssh_key
      ;;
  esac  
}
set_password() {
  info "Please enter [password|pass] or [key|ssh|ssh_key]: " 
  read -rp "${cyan}[USER]${reset} Would you like to use a password or SSH key: " req
  req="${req,,}"
  case "$req" in
    password|pass)
      req=n
      read -s -rp "Please enter your password: " password
      echo
      password_strength "$password"
      read -s -rp "Please re-enter your password: " password2
      echo
      password_strength "$password2"
      # ==== Ensure password was entered accurately ====
      while [[ ! "$password" == "$password2" ]]; do
        warn "${red}Passwords do not match${reset}" "${green}Please try again${reset}"
        set_password
      done
      ;;
    key|ssh|ssh_key)
      req=y
      ssh_key
      ;;
  esac
  if [[ "$os" == "windows" ]]; then
    read -rp "${cyan}[USER]${reset} Please enter the RDP port \# (will default to 3389 if empty): " rdp
    if [ -z "${RDP_PORT:-}" ]; then
        rdp=3389
    fi
    echo
    printf "${yellow}[${green}ONE-CLICK${yellow}]${reset} %s\n" \
    "Select Windows installation language:" \
    "1) English (United States)" \
    "2) English (United Kingdom)" \
    "3) Chinese (Simplified)" \
    "4) Chinese (Traditional)" \
    "5) French" \
    "6) German" \
    "7) Spanish" \
    "8) Japanese" \
    "9) Korean"
    read -rp "${cyan}[USER]${reset} Please select your preferred language[1-9]: " language
    case "$language" in
      1) WIN_LANG="en-US" ;;
      2) WIN_LANG="en-GB" ;;
      3) WIN_LANG="zh-CN" ;;
      4) WIN_LANG="zh-TW" ;;
      5) WIN_LANG="fr-FR" ;;
      6) WIN_LANG="de-DE" ;;
      7) WIN_LANG="es-ES" ;;
      8) WIN_LANG="ja-JP" ;;
      9) WIN_LANG="ko-KR" ;;
      *) echo "Invalid choice" ; exit 1 ;;
    esac 
  fi
}
confirm_install() {
  warn "${grey}This will totally wipe all data from this device!" \
  "This is irreversable. Please make sure you have a back up if the data on this device is important" \
  " ${reset}"
  read -rp "${cyan}[USER]${reset} Please confirm you are happy to proceed? " install_reinstall
  install_reinstall="${install_reinstall:-}"
  install_reinstall="${install_reinstall,,}"
  if [[ ! "${install_reinstall}" =~ ^(y|yes)$ ]]; then
    die "You have chosen not to proceed."
  fi
  warn "This may take a while to complete"
}
# ==== Run reinstall to change OS pn server ====
install_image() {
  confirm_install
  # ==== Linux with SSH key ====
  if [[ "$os" != "windows" && "$req" == "y" ]]; then
    bash $(basename "$reinstall") "$os $ver" --password "$password" --ssh-key "$key" \
      | sed -E '/(Password: .)....(.).*/s//\1xxxx\2x/' \
      | sed -E "N;s,\nUsername:,\n                         _ _      _    \n  ___  _ __   ___    ___\| \(_\) ___\| \| __\\n / _ \\\| '_ \\\ / _ \\\  / __\| \| \|/ __\| \|/ /\n\| \(_\) \| \| \| \|  __/ \| \(__\| \| \| \(__\|   < \n \\\___/\|_\| \|_\|\\\___\|  \\\___\|_\|_\|\\\___\|_\|\\\_\\\&,"
  # ==== Linux without SSH key ====
  elif [[ "$os" != "windows" ]]; then
    bash $(basename "$reinstall") "$os $ver" --password "$password" \
      | sed -E '/(Password: .)....(.).*/s//\1xxxx\2x/' \
      | sed -E "N;s,\nUsername:,\n                         _ _      _    \n  ___  _ __   ___    ___\| \(_\) ___\| \| __\\n / _ \\\| '_ \\\ / _ \\\  / __\| \| \|/ __\| \|/ /\n\| \(_\) \| \| \| \|  __/ \| \(__\| \| \| \(__\|   < \n \\\___/\|_\| \|_\|\\\___\|  \\\___\|_\|_\|\\\___\|_\|\\\_\\\&,"
  # ==== Bindows ====
  else
    bash $(basename "$reinstall") "$os" --image-name "$iso_name" --iso "$iso" --password "$password" --lang "$language" --rdp-port "$rdp" \
      | sed -E '/(Password: .)....(.).*/s//\1xxxx\2x/' \
      | sed -E "N;s,\nUsername:,\n                         _ _      _    \n  ___  _ __   ___    ___\| \(_\) ___\| \| __\\n / _ \\\| '_ \\\ / _ \\\  / __\| \| \|/ __\| \|/ /\n\| \(_\) \| \| \| \|  __/ \| \(__\| \| \| \(__\|   < \n \\\___/\|_\| \|_\|\\\___\|  \\\___\|_\|_\|\\\___\|_\|\\\_\\\&,"
    echo
    cat << 'EOF'
Since Microsoft only publicly provides ISO images of the Evaluation (trial) version, this version is limited to 180 days by default.
After expiration, automatic restarts every hour may occur, affecting the user experience.

To convert to production using the open source Microsoft Activation Scripts (MAS), follow these steps:

1. Open PowerShell as administrator and run:
   $(tput setaf 5)irm https://get.activated.win | iex${reset}

2. In the menu, select:
   $(tput setaf 7)[7] Change Windows Edition(Change version)${reset}
   Then choose ServerStandard to convert to Production Standard Edition.
   Wait for the conversion to complete. The system will automatically restart.

3. After restarting, open PowerShell again (as administrator) and run:
   $(tput setaf 5)irm https://get.activated.win | iex${reset}

4. Select:
   $(tput setaf 7)[3] Activation - Windows${reset}
   Wait for activation to complete.

After activation, the trial limitations are removed, but you should still obtain a valid license for extended use.
EOF
  fi
}
# ==== Complete the OS reinstallation ====
finish(){
  read -rp "${cyan}[USER]${reset} The installation of $os has now completed and the system needs to be rebooted. Should the system be rebooted now? [y/n]: " finalize
  finalize="${finalize,,}"
  if [[ "$finalize" == "y" || "$finalize" == "yes" ]]; then
    warn "The system will go down in 10 seconds..."
    sleep 10
    reboot
  else
    exit 0
  fi
}
os_reinstall_run() {
  get_os
  while true; do
    os_menu
    trap - ERR
    back_button=0
    map_image
    trap 'on_error $?' ERR
    if [[ "$back_button" -eq 1 ]]; then
      info "Going back to OS menu..."
      sleep 2
      clear
      continue
    fi
    break
  done
  set_password
  install_image
  finish
  exit 0
}
# ==== End One-Click OS Reinstall ==== #
