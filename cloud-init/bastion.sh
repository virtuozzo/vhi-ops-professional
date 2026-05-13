# Unified bastion customization; lab_log from prepended _lab_log.sh.
# Template vars: student_password, lab_track
# Target: Debian stable + XFCE + xrdp (xorgxrdp) + optional TigerVNC.

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

bastion_apt_enable_firmware_components() {
  lab_log INFO "Ensuring apt sources include contrib, non-free, and non-free-firmware where needed"
  if grep -Rqs 'non-free-firmware' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
    lab_log INFO "non-free-firmware already referenced in apt sources"
    return 0
  fi
  if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sed -i \
      -e 's/^Components: main$/Components: main contrib non-free non-free-firmware/' \
      -e 's/^Components: main contrib$/Components: main contrib non-free non-free-firmware/' \
      -e 's/^Components: main contrib non-free$/Components: main contrib non-free non-free-firmware/' \
      /etc/apt/sources.list.d/debian.sources 2>/dev/null || true
  fi
  if grep -q '^deb ' /etc/apt/sources.list 2>/dev/null; then
    sed -i 's/ main$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
  fi
}

bastion_bootstrap_base_packages() {
  run_apt "apt-get update -eany -q" "apt metadata refresh (bootstrap)"
  run_apt "apt-get install -y -q sudo ca-certificates" "sudo and CA certs before creating student user"
}

bastion_student_and_ssh() {
  lab_log INFO "Setting up 'student' user"
  useradd -m -s /bin/bash -G sudo student
  echo "student:${student_password}" | chpasswd

  for u in debian ubuntu; do
    if [ -f "/home/$u/.ssh/authorized_keys" ]; then
      lab_log INFO "Copying SSH authorized_keys from $u to student"
      install -d -m 700 -o student -g student /home/student/.ssh
      cp "/home/$u/.ssh/authorized_keys" /home/student/.ssh/authorized_keys
      chmod 600 /home/student/.ssh/authorized_keys
      chown -R student:student /home/student/.ssh
      break
    fi
  done

  lab_log INFO "Allowing password authentication for user student (OpenStack client over SSH)"
  cat >/etc/ssh/sshd_config.d/90-student-auth.conf <<'SSHEOF'
Match User student
    PasswordAuthentication yes
SSHEOF

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
  run_apt "apt-get update -eany -q" "apt metadata refresh (desktop stack)"
  run_apt "apt-get install -y -q --no-install-recommends \
    xfce4 \
    dbus-x11 \
    xrdp xorgxrdp \
    tigervnc-standalone-server tigervnc-common \
    firefox-esr \
    python3 python3-pip python3-venv \
    firmware-linux" "XFCE, RDP, TigerVNC, Firefox, Python, firmware"
}

bastion_xfce_performance_defaults() {
  lab_log INFO "Disabling XFCE compositing for lighter remote sessions"
  install -d -m 755 -o student -g student /home/student/.config/xfce4/xfconf/xfce-perchannel-xml
  cat > /home/student/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'XFM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="false"/>
    <property name="show_frame_shadow" type="bool" value="false"/>
  </property>
</channel>
XFM
  chown -R student:student /home/student/.config
}

bastion_xrdp_configure() {
  lab_log INFO "Configuring XRDP for XFCE (xorgxrdp)"
  cat > /home/student/.xsession <<'XS'
#!/bin/sh
exec startxfce4
XS
  chmod 755 /home/student/.xsession
  chown student:student /home/student/.xsession

  sed -i 's/^port=3389/port=3390/' /etc/xrdp/xrdp.ini
  sed -i 's/^#*port=3389/port=3390/' /etc/xrdp/xrdp.ini

  if grep -q '^tcp_nodelay=' /etc/xrdp/xrdp.ini; then
    sed -i 's/^tcp_nodelay=.*/tcp_nodelay=true/' /etc/xrdp/xrdp.ini
  elif grep -q '^\[Globals\]' /etc/xrdp/xrdp.ini; then
    sed -i '/^\[Globals\]/a tcp_nodelay=true' /etc/xrdp/xrdp.ini
  fi
  if grep -q '^max_bpp=' /etc/xrdp/xrdp.ini; then
    sed -i 's/^max_bpp=.*/max_bpp=24/' /etc/xrdp/xrdp.ini
  fi

  systemctl enable xrdp
  systemctl restart xrdp.service
}

bastion_tigervnc_setup() {
  lab_log INFO "Configuring TigerVNC (display :1, TCP 5901) for student"
  install -d -m 700 -o student -g student /home/student/.vnc
  cat > /home/student/.vnc/xstartup <<'XVNC'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/startxfce4
XVNC
  chmod 755 /home/student/.vnc/xstartup
  chown -R student:student /home/student/.vnc

  printf '%s\n' "${student_password}" | sudo -u student env HOME=/home/student vncpasswd -f >/home/student/.vnc/passwd
  chmod 600 /home/student/.vnc/passwd
  chown student:student /home/student/.vnc/passwd

  cat > /etc/systemd/system/tigervnc-student.service <<'UNIT'
[Unit]
Description=TigerVNC XFCE session for student (display :1, port 5901)
After=network.target

[Service]
Type=simple
User=student
Group=student
Environment=HOME=/home/student
WorkingDirectory=/home/student
ExecStart=/usr/bin/tigervncserver :1 -fg -geometry 1920x1080 -depth 24 -localhost no -SecurityTypes VncAuth
ExecStop=/usr/bin/tigervncserver -kill :1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable tigervnc-student.service
  systemctl start tigervnc-student.service || lab_log ERROR "TigerVNC service start failed (check /var/log/tigervnc or journalctl)"
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
bastion_apt_enable_firmware_components
bastion_bootstrap_base_packages
bastion_student_and_ssh
bastion_desktop_shortcuts
track_is_s3 && bastion_s3_extras
bastion_update_hosts
bastion_install_desktop_packages
bastion_xfce_performance_defaults
bastion_xrdp_configure
bastion_tigervnc_setup
bastion_upgrade
bastion_finalize_or_fail
