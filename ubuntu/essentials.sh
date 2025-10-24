#!/bin/bash

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

echo "Installing Tailscale..."

curl -fsSL https://tailscale.com/install.sh | sh

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