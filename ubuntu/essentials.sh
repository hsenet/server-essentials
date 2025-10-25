#!/bin/bash

# Ask user if they want to install speedtest
read -p "Do you want to install speedtest? (y/n): " install_speedtest
if [[ $install_speedtest =~ ^[Yy]$ ]]; then
    echo "Installing speedtest..."
    
    # Check if snap is available
    if command -v snap >/dev/null 2>&1; then
        sudo snap install speedtest
    else
        echo "Snap not available. Installing speedtest via apt..."
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
        sudo apt update
        if sudo apt install -y speedtest; then
            echo "Speedtest installed successfully"
        else
            echo "Speedtest package not available. Installing speedtest-cli..."
            sudo apt install -y speedtest-cli
        fi
    fi
fi

# Ask user if they want to install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
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
fi

# Ask user if they want to install ZeroTier
read -p "Do you want to install ZeroTier? (y/n): " install_zerotier
if [[ $install_zerotier =~ ^[Yy]$ ]]; then
    echo "Installing ZeroTier..."
    curl -s https://install.zerotier.com | sudo bash
    read -p "Enter ZeroTier network ID to join (or press Enter to skip): " network_id
    if [[ -n $network_id ]]; then
        sudo zerotier-cli join $network_id
        echo "Joined ZeroTier network: $network_id"
    fi
fi

# Ask user if they want to install and configure zram
read -p "Do you want to install and configure zram for memory compression (Extends life of SSDs)? (y/n): " install_zram
if [[ $install_zram =~ ^[Yy]$ ]]; then
    echo "Installing zram..."
    sudo apt update
    sudo apt install -y zram-config
    
    # Configure optimal zram settings
    echo "Configuring zram..."
    sudo systemctl stop zram-config
    
    # Set zram size to 50% of RAM
    total_ram=$(free -b | awk '/^Mem:/{print $2}')
    zram_size=$((total_ram / 2))
    
    echo "PERCENT=50" | sudo tee /etc/default/zramswap > /dev/null
    echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap > /dev/null
    
    sudo systemctl start zram-config
    sudo systemctl enable zram-config
    
    echo "zram configured successfully with 50% of RAM and lz4 compression"
fi