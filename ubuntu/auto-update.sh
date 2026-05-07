#!/bin/bash

# Auto-Update Script for Ubuntu
# ----------------------------
# This script updates package lists, upgrades packages, removes unused packages,
# and reboots the server if required.
#
# Usage:
#   1. Upload this script to your server (e.g., to /usr/local/bin/auto-update.sh)
#   2. Make it executable: sudo chmod +x /usr/local/bin/auto-update.sh
#   3. To run manually: sudo /usr/local/bin/auto-update.sh
#
# Scheduling (Run daily at midnight):
#   1. Open crontab: sudo crontab -e
#   2. Add the following line:
#      0 0 * * * /usr/local/bin/auto-update.sh
#

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

LOG_FILE="/var/log/auto-update.log"

# Create log file if it doesn't exist and set permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

{
    echo "-------------------------------------------"
    echo "Auto-update started at: $(date)"
    
    export DEBIAN_FRONTEND=noninteractive

    echo "Updating package lists..."
    apt-get update
    
    echo "Upgrading packages..."
    apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
    
    echo "Removing unused packages..."
    apt-get autoremove -y
    apt-get autoclean -y

    if [ -f /var/run/reboot-required ]; then
        echo "Reboot required. System is rebooting..."
        echo "Auto-update finished at: $(date)"
        reboot
    else
        echo "No reboot required."
        echo "Auto-update finished at: $(date)"
    fi
} >> "$LOG_FILE" 2>&1
