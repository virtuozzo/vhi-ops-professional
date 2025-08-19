#!/bin/bash

# Function to run a command and check its success
run_apt() {
    local command="$1"
    local description="$2"
	export DEBIAN_FRONTEND=noninteractive

    echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Starting $command"
    echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Starting $description." >> /etc/issue
    eval "$command"
    if [ $? -eq 0 ]; then
        echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Successfully finished $command" 
        echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Successfully finished $description." >> /etc/issue
    else
        echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') Could not perform $command" >&2
        echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') Could not perform $description." >> /etc/issue
    fi

    systemctl restart getty@tty1.service
}

exec >/var/log/customization.log 2>&1

cp /etc/issue{,.bak}

# Set the message to display during the customization
echo -e "\e[31m Customization is in progress!                      \e[0m" > /tmp/customization.info
echo -e "\e[31m Please do not perform any actions until            \e[0m" >> /tmp/customization.info
echo -e "\e[31m customization is complete and Bastion is restarted.\e[0m" >> /tmp/customization.info
echo -e "" >> /tmp/customization.info

# Set the message to display in case the customization fails
echo -e "" > /tmp/customization.warning
echo -e "\e[41m\e[30m WARNING! Customization failed!     \e[0m" > /tmp/customization.warning
echo -e "\e[41m\e[30m Consult /var/log/customization.log,\e[0m" >> /tmp/customization.warning
echo -e "\e[41m\e[30m resolve the issues, and redeploy.  \e[0m" >> /tmp/customization.warning
echo -e "" >> /tmp/customization.warning

# Set the message of the day and login prompt to custom messages
cat /tmp/customization.info >> /etc/motd
cat /tmp/customization.info >> /etc/issue

# Restart tty1 to refresh motd
systemctl restart getty@tty1.service

echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Setting up 'student' user"
# Set the hashed password for the "student" user.
PASSWORD_HASH='$6$ldNxDfgP/1A66Uol$9im0QsZoncBot9CLf2iEgnC74EsKwmJylZDlJyq/FRnWP0dk4szF7EqTbh1UCoyoCyL.wvOe11QRFuvlj4blV.'
# Create the "student" user and add it to the sudo group
useradd -m -s /bin/bash -G sudo student
# Set the password for the "student" user
usermod --password "${PASSWORD_HASH}" student

# Changing SSH port to 2228
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Reconfiguring the SSH port to 2228"
sed -i 's/#Port 22/Port 2228/g' /etc/ssh/sshd_config
systemctl restart ssh

# Update hosts file
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Updating hosts file"
echo "10.0.102.10 cloud.student.lab" >> /etc/hosts

# Upgrade the system
run_apt "apt-get update -eany -q" "system update"
run_apt "apt-get upgrade -y -q" "system upgrade"

# Check if the string exists in the file
echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Checking customization success"
if grep -q "ERROR" /var/log/customization.log; then
	echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') Customization issue found"
	cat /tmp/customization.warning >> /etc/motd
	cat /tmp/customization.warning >> /etc/issue
	systemctl restart getty@tty1.service
else
	echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') No customization issues found"
	echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') Customization finished successfully"
    rm /etc/motd
    mv /etc/issue{.bak,}
    reboot
fi