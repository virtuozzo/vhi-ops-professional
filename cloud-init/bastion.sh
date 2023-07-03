#!/bin/bash

# Set the message of the day in red and bold
echo -e "\e[1m\e[31m Customization is in progress!                      \e[0m" >> /etc/motd
echo -e "\e[1m\e[31m Please do not perform any actions until            \e[0m" >> /etc/motd
echo -e "\e[1m\e[31m customization is complete and Bastion is restarted.\e[0m" >> /etc/motd
echo -e "" >> /etc/motd

# Set the login prompt message red and bold
echo -e "\e[1m\e[31m Customization is in progress!                      \e[0m" >> /etc/issue
echo -e "\e[1m\e[31m Please do not perform any actions until            \e[0m" >> /etc/issue
echo -e "\e[1m\e[31m customization is complete and Bastion is restarted.\e[0m" >> /etc/issue
echo -e "" >> /etc/issue
systemctl restart getty@tty1.service

# Set the hashed password for the "student" user.
PASSWORD_HASH='$6$ldNxDfgP/1A66Uol$9im0QsZoncBot9CLf2iEgnC74EsKwmJylZDlJyq/FRnWP0dk4szF7EqTbh1UCoyoCyL.wvOe11QRFuvlj4blV.'

# Create the "student" user and add it to the sudo group
useradd -m -s /bin/bash -G sudo student

# Set the password for the "student" user
usermod --password "${PASSWORD_HASH}" student

# Create a URL shortcut for VHI Admin Panel
mkdir -p /home/student/Desktop
echo "[Desktop Entry]
Encoding=UTF-8
Name=VHI Admin Panel
Type=Link
URL=https://cloud.student.lab:8888
Icon=text-html" > "/home/student/Desktop/VHI Admin Panel.desktop"
chown -R student:student /home/student/Desktop

# Install the Cinnamon desktop environment and XRDP
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y cinnamon-desktop-environment cinnamon-core xrdp

# Configure XRDP
echo "cinnamon-session" > /home/student/.xsession
sed -i 's/3389/3390/g' /etc/xrdp/xrdp.ini
systemctl restart xrdp.service

# Configure Cinnamon for RDP
mkdir -p /home/student/.config/gtk-3.0/
echo "[Settings]" > /home/student/.config/gtk-3.0/settings.ini
echo "gtk-modules=\"appmenu-gtk-module,cinnamon-applet-proxy\"" >> /home/student/.config/gtk-3.0/settings.ini
chown -R student:student /home/student

# Change the SSH port to 2228
sed -i 's/#Port 22/Port 2228/g' /etc/ssh/sshd_config
systemctl restart ssh

# Upgrade the system
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Update hosts file
echo "10.0.102.10 cloud.student.lab" >> /etc/hosts

# Reset the message of the day to the default
echo "" > /etc/motd
echo "" > /etc/issue

# Reboot the system
reboot
