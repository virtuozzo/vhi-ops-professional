# Unified bastion customization; lab_log from prepended _lab_log.sh.
# Template vars: student_password, lab_track
# Target: Debian 13 (trixie) + XFCE + xrdp (xorgxrdp).

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
  lab_log INFO "Creating desktop shortcuts (Application launchers — avoids untrusted Type=Link prompts)"
  mkdir -p /home/student/Desktop
  cat >"/home/student/Desktop/VHI Admin Panel.desktop" <<'DESK1'
[Desktop Entry]
Version=1.0
Type=Application
Name=VHI Admin Panel
Comment=Open VHI Admin Panel in Firefox
Exec=/usr/bin/firefox-esr https://cloud.student.lab:8888
Icon=firefox-esr
Terminal=false
StartupNotify=true
DESK1
  cat >"/home/student/Desktop/VHI Self-Service Panel.desktop" <<'DESK2'
[Desktop Entry]
Version=1.0
Type=Application
Name=VHI Self-Service Panel
Comment=Open VHI Self-Service in Firefox
Exec=/usr/bin/firefox-esr https://cloud.student.lab:8800
Icon=firefox-esr
Terminal=false
StartupNotify=true
DESK2
  chmod 755 /home/student/Desktop/*.desktop
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
  lab_log INFO "Selecting lightdm as display manager (local / VGA console graphical login)"
  echo 'lightdm shared/default-x-display-manager select lightdm' | debconf-set-selections

  run_apt "apt-get install -y -q --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    dbus-x11 \
    lightdm lightdm-gtk-greeter \
    xserver-xorg-core xserver-xorg-input-all \
    spice-vdagent \
    qemu-guest-agent \
    xrdp xorgxrdp \
    firefox-esr \
    python3 python3-pip python3-venv pipx \
    locales-all \
    firmware-linux" "XFCE, LightDM, Xorg input drivers, SPICE/QEMU agents, RDP, Firefox, Python, locales, firmware"
}

bastion_locales_and_ssh_client_quirks() {
  lab_log INFO "System default locale (locales-all installed); normalize invalid SSH-forwarded LC_* (e.g. macOS LC_CTYPE=UTF-8)"
  cat >/etc/default/locale <<'LOC'
LANG=C.UTF-8
LOC
  cat >/etc/profile.d/00-fix-ssh-locale.sh <<'FIX'
# Run before cloud-init locale-check: macOS often forwards LC_CTYPE=UTF-8.
case "$LC_ALL" in (UTF-8|utf-8) export LC_ALL=C.UTF-8 ;; esac
case "$LC_CTYPE" in (UTF-8|utf-8) export LC_CTYPE=C.UTF-8 ;; esac
FIX
  chmod 644 /etc/profile.d/00-fix-ssh-locale.sh
}

bastion_xfce_performance_defaults() {
  lab_log INFO "Disabling XFCE compositing; default terminal = xfce4-terminal"
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
  cat > /home/student/.config/xfce4/xfconf/xfce-perchannel-xml/helpers.xml <<'HLP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="helpers" version="1.0">
  <property name="TerminalEmulator" type="string" value="/usr/bin/xfce4-terminal"/>
</channel>
HLP
  chown -R student:student /home/student/.config

  if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal 2>/dev/null || true
  fi
}

bastion_console_graphical_target() {
  lab_log INFO "Enabling graphical target and LightDM for local console (VGA / web console)"
  install -d /etc/lightdm/lightdm.conf.d
  cat >/etc/lightdm/lightdm.conf.d/01-console-vt.conf <<'LDC'
[LightDM]
# Prefer the first virtual terminal so typical cloud HTML5 consoles show the greeter.
minimum-vt=1
LDC
  systemctl daemon-reload

  lab_log INFO "Guest agents for cloud web console keyboard/mouse (SPICE / QEMU)"
  systemctl enable qemu-guest-agent.service 2>/dev/null || true
  systemctl start qemu-guest-agent.service 2>/dev/null || true
  systemctl enable spice-vdagentd.service 2>/dev/null || true
  systemctl start spice-vdagentd.service 2>/dev/null || true

  systemctl set-default graphical.target
  systemctl enable lightdm.service
  systemctl start lightdm.service || lab_log ERROR "lightdm failed to start (see journalctl -u lightdm)"
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
track_is_s3 && bastion_s3_extras
bastion_update_hosts
bastion_install_desktop_packages
bastion_locales_and_ssh_client_quirks
bastion_xfce_performance_defaults
bastion_desktop_shortcuts
bastion_console_graphical_target
bastion_xrdp_configure
bastion_upgrade
bastion_finalize_or_fail
