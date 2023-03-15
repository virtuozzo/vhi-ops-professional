#!/bin/bash

# Set the hashed password for the "student" user.
PASSWORD_HASH="$6$rounds=4096$S9I1xAEfqVLrDI1W$3yRIB/iQ.MxxOR0EU8YbaJsHF79LhihTiq3ByhcKzu9uPp/EaIvRLLggTzdECsB9XDNy43hgcuc/VtoCcYetZ1"

# Install the GNOME desktop environment
apt-get update
apt-get install -y ubuntu-desktop gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal

# Create the "student" user and add it to the sudo group
useradd -m -s /bin/bash -G sudo student

# Set the password for the "student" user
usermod --password "${PASSWORD_HASH}" student

# Configure XRDP
sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini
systemctl restart xrdp

# Change the SSH port to 2228
sed -i 's/#Port 22/Port 2228/g' /etc/ssh/sshd_config
systemctl restart ssh

# Upgrade the system
apt-get upgrade -y

# Configure GNOME desktop environment system-wide
echo "exec gnome-session" >> /etc/X11/Xsession

# Reboot
reboot