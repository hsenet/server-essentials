#!/bin/bash

# Ask user if they want to install speedtest
read -p "Do you want to install speedtest? (y/n): " install_speedtest
if [[ $install_speedtest =~ ^[Yy]$ ]]; then
    echo "Installing speedtest..."
    
    # Check if snap is available
    if command -v snap >/dev/null 2>&1; then
        if ! sudo snap install speedtest; then
            echo "Error: Failed to install speedtest via snap"
            exit 1
        fi
    else
        echo "Snap not available. Installing speedtest via apt..."
        if ! curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash; then
            echo "Error: Failed to setup speedtest repository"
            exit 1
        fi
        if ! sudo apt update; then
            echo "Error: Failed to update apt package list"
            exit 1
        fi
        if sudo apt install -y speedtest; then
            echo "Speedtest installed successfully"
        else
            echo "Speedtest package not available. Installing speedtest-cli..."
            if ! sudo apt install -y speedtest-cli; then
                echo "Error: Failed to install speedtest-cli"
                exit 1
            fi
        fi
    fi
fi

# Ask user if they want to install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
    echo "Installing Tailscale..."
    if ! curl -fsSL https://tailscale.com/install.sh | sh; then
        echo "Error: Failed to install Tailscale"
        exit 1
    fi
fi

# Ask user if they want to configure Tailscale as exit node
read -p "Do you want to configure Tailscale as exit node? (y/n): " configure_exitnode
if [[ $configure_exitnode =~ ^[Yy]$ ]]; then
    echo "Configuring Tailscale as exit node..."
    if [[ -f ../tailscale-exitnode.sh ]]; then
        chmod +x ../tailscale-exitnode.sh
        ../tailscale-exitnode.sh
    else
        echo "Error: tailscale-exitnode.sh not found in parent directory"
    fi
else
    # Only run this command if user doesn't want to configure as exit node
    sudo tailscale up --ssh --accept-risk=lose-ssh
fi

# Ask user if they want to install ZeroTier
read -p "Do you want to install ZeroTier? (y/n): " install_zerotier
if [[ $install_zerotier =~ ^[Yy]$ ]]; then
    echo "Installing ZeroTier..."
    if ! curl -s https://install.zerotier.com | sudo bash; then
        echo "Error: Failed to install ZeroTier"
        exit 1
    fi
    read -p "Enter ZeroTier network ID to join (or press Enter to skip): " network_id
    if [[ -n $network_id ]]; then
        if ! sudo zerotier-cli join $network_id; then
            echo "Error: Failed to join ZeroTier network"
            exit 1
        fi
        echo "Joined ZeroTier network: $network_id"
    fi
fi

# Ask user if they want to install and configure zram
read -p "Do you want to install and configure zram for memory compression (Extends life of SSDs)? (y/n): " install_zram
if [[ $install_zram =~ ^[Yy]$ ]]; then
    echo "Installing zram..."
    if ! sudo apt update; then
        echo "Error: Failed to update apt package list"
        exit 1
    fi
    if ! sudo apt install -y zram-config; then
        echo "Error: Failed to install zram-config"
        exit 1
    fi
    
    # Configure optimal zram settings
    echo "Configuring zram..."
    if ! sudo systemctl stop zram-config; then
        echo "Warning: Failed to stop zram-config service"
    fi
    
    # Set zram size to 50% of RAM
    total_ram=$(free -b | awk '/^Mem:/{print $2}')
    zram_size=$((total_ram / 2))
    
    echo "PERCENT=50" | sudo tee /etc/default/zramswap > /dev/null
    echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap > /dev/null
    
    if ! sudo systemctl start zram-config; then
        echo "Error: Failed to start zram-config service"
        exit 1
    fi
    if ! sudo systemctl enable zram-config; then
        echo "Error: Failed to enable zram-config service"
        exit 1
    fi
    
    echo "zram configured successfully with 50% of RAM and lz4 compression"
    zramctl
fi

# Ask user if they want to install unattended-upgrades
read -p "Do you want to install unattended-upgrades for automatic security updates? (y/n): " install_unattended
if [[ $install_unattended =~ ^[Yy]$ ]]; then
    echo "Installing unattended-upgrades..."
    sudo apt update && sudo apt -y install unattended-upgrades update-notifier-common
    sudo dpkg-reconfigure -plow unattended-upgrades
fi

# Ask user if they want to setup custom auto-update script
read -p "Do you want to setup a custom auto-update and reboot script? (y/n): " setup_autoupdate
if [[ $setup_autoupdate =~ ^[Yy]$ ]]; then
    read -p "Enter the hour to run updates (0-23, default 0): " update_hour
    update_hour=${update_hour:-0}
    # Validate hour input
    if ! [[ "$update_hour" =~ ^[0-9]+$ ]] || [ "$update_hour" -lt 0 ] || [ "$update_hour" -gt 23 ]; then
        echo "Error: Invalid hour. Please enter a number between 0 and 23."
        exit 1
    fi
    
    read -p "Enter the minute to run updates (0-59, default 0): " update_minute
    update_minute=${update_minute:-0}
    # Validate minute input
    if ! [[ "$update_minute" =~ ^[0-9]+$ ]] || [ "$update_minute" -lt 0 ] || [ "$update_minute" -gt 59 ]; then
        echo "Error: Invalid minute. Please enter a number between 0 and 59."
        exit 1
    fi

    echo "Setting up auto-update script..."
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if [[ -f "$SCRIPT_DIR/auto-update.sh" ]]; then
        sudo cp "$SCRIPT_DIR/auto-update.sh" /usr/local/bin/auto-update.sh
        sudo chmod +x /usr/local/bin/auto-update.sh

        # Add to crontab, replacing any existing entry for this script
        CRON_JOB="$update_minute $update_hour * * * /usr/local/bin/auto-update.sh"
        (sudo crontab -l 2>/dev/null | grep -v "/usr/local/bin/auto-update.sh" ; echo "$CRON_JOB") | sudo crontab -
        echo "Auto-update scheduled for $update_hour:$update_minute daily."
    else
        echo "Error: auto-update.sh not found in $SCRIPT_DIR"
    fi
fi
