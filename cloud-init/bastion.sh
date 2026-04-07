# Unified bastion customization; lab_log from prepended _lab_log.sh.
# Template vars: student_password, lab_track

LAB_TRACK="${lab_track}"

track_is_s3() { [[ "$LAB_TRACK" == "s3" ]]; }

apt_progress_issue() {
  local level="$1"
  local text="$2"
  local ts
  ts=$(date +'%Y-%m-%d %H:%M:%S')
  echo "[$level] $ts $text" >> /etc/issue
}

run_apt() {
  local command="$1"
  local description="$2"
  export DEBIAN_FRONTEND=noninteractive

  lab_log INFO "Starting $command"
  apt_progress_issue INFO "Starting $description."
  eval "$command"
  if [ $? -eq 0 ]; then
    lab_log INFO "Successfully finished $command"
    apt_progress_issue INFO "Successfully finished $description."
  else
    lab_log ERROR "Could not perform $command"
    apt_progress_issue ERROR "Could not perform $description."
  fi

  systemctl restart getty@tty1.service
}

exec >/var/log/customization.log 2>&1

bastion_banner_and_motd() {
  cp /etc/issue{,.bak}

  echo -e "\e[31m Customization is in progress!                      \e[0m" > /tmp/customization.info
  echo -e "\e[31m Please do not perform any actions until            \e[0m" >> /tmp/customization.info
  echo -e "\e[31m customization is complete and Bastion is restarted.\e[0m" >> /tmp/customization.info
  echo -e "" >> /tmp/customization.info

  echo -e "" > /tmp/customization.warning
  echo -e "\e[41m\e[30m WARNING! Customization failed!     \e[0m" > /tmp/customization.warning
  echo -e "\e[41m\e[30m Consult /var/log/customization.log,\e[0m" >> /tmp/customization.warning
  echo -e "\e[41m\e[30m resolve the issues, and redeploy.  \e[0m" >> /tmp/customization.warning
  echo -e "" >> /tmp/customization.warning

  cat /tmp/customization.info >> /etc/motd
  cat /tmp/customization.info >> /etc/issue
  systemctl restart getty@tty1.service
}

bastion_student_and_ssh() {
  lab_log INFO "Setting up 'student' user"
  useradd -m -s /bin/bash -G sudo student
  echo "student:${student_password}" | chpasswd

  lab_log INFO "Reconfiguring the SSH port to 2228"
  sed -i 's/#Port 22/Port 2228/g' /etc/ssh/sshd_config
  systemctl restart ssh
}

bastion_desktop_shortcuts() {
  lab_log INFO "Creating desktop shortcuts"
  mkdir -p /home/student/Desktop
  echo "[Desktop Entry]
Encoding=UTF-8
Name=VHI Admin Panel
Type=Link
URL=https://cloud.student.lab:8888
Icon=text-html" > "/home/student/Desktop/VHI Admin Panel.desktop"
  echo "[Desktop Entry]
Encoding=UTF-8
Name=VHI Self-Service Panel
Type=Link
URL=https://cloud.student.lab:8800
Icon=text-html" > "/home/student/Desktop/VHI Self-Service Panel.desktop"
  chown -R student:student /home/student/Desktop
}

bastion_s3_extras() {
  lab_log INFO "Creating simple text file"
  mkdir -p /home/student/Documents
  echo "simple text file" >> /home/student/Documents/text
  chown -R student:student /home/student/Documents
}

bastion_update_hosts() {
  lab_log INFO "Updating hosts file"
  echo "10.0.102.10 cloud.student.lab" >> /etc/hosts
  track_is_s3 && echo "10.0.102.10 s3.cloud.student.lab" >> /etc/hosts
}

bastion_install_desktop_packages() {
  run_apt "apt-get update -eany -q" "system update"
  run_apt "apt-get install -y -q cinnamon-desktop-environment cinnamon-core xrdp python3-pip" "desktop environment installation"
}

bastion_xrdp_cinnamon() {
  lab_log INFO "Configuring XRDP"
  echo "cinnamon-session" > /home/student/.xsession
  sed -i 's/3389/3390/g' /etc/xrdp/xrdp.ini
  systemctl restart xrdp.service

  lab_log INFO "Configuring Cinnamon for RDP"
  mkdir -p /home/student/.config/gtk-3.0/
  echo "[Settings]" > /home/student/.config/gtk-3.0/settings.ini
  echo "gtk-modules=\"appmenu-gtk-module,cinnamon-applet-proxy\"" >> /home/student/.config/gtk-3.0/settings.ini
  chown -R student:student /home/student
}

bastion_upgrade() {
  run_apt "apt-get upgrade -y -q" "system upgrade"
}

bastion_finalize_or_fail() {
  lab_log INFO "Checking customization success"
  if grep -q "ERROR" /var/log/customization.log; then
    lab_log ERROR "Customization issue found"
    cat /tmp/customization.warning >> /etc/motd
    cat /tmp/customization.warning >> /etc/issue
    systemctl restart getty@tty1.service
  else
    lab_log INFO "No customization issues found"
    lab_log INFO "Customization finished successfully"
    rm /etc/motd
    mv /etc/issue{.bak,}
    reboot
  fi
}

# -----------------------------------------------------------------------------
# End of function definitions.
# Main: order of operations — customization steps run top to bottom.
# -----------------------------------------------------------------------------
bastion_banner_and_motd
bastion_student_and_ssh
bastion_desktop_shortcuts
track_is_s3 && bastion_s3_extras
bastion_update_hosts
bastion_install_desktop_packages
bastion_xrdp_cinnamon
bastion_upgrade
bastion_finalize_or_fail
