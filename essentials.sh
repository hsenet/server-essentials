#!/bin/bash

# Detect OS and distribution
detect_os() {
    if [[ -f /boot/dietpi/.version ]]; then
        echo "dietpi"
    elif [[ -f /etc/rpi-issue ]] || [[ $(cat /proc/cpuinfo | grep -i "raspberry") ]]; then
        echo "raspberrypi"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/ubuntu-release ]] || [[ $(lsb_release -si 2>/dev/null) == "Ubuntu" ]]; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
echo "Detected OS: $OS"

# Ask user if they want to install speedtest
read -p "Do you want to install speedtest? (y/n): " install_speedtest
if [[ $install_speedtest =~ ^[Yy]$ ]]; then
    echo "Installing speedtest..."
    
    case $OS in
        "dietpi")
            /boot/dietpi/dietpi-software install 168
            ;;
        "raspberrypi"|"debian"|"ubuntu")
            if command -v snap >/dev/null 2>&1; then
                sudo snap install speedtest
            else
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
                sudo apt update
                if sudo apt install -y speedtest; then
                    echo "Speedtest installed successfully"
                else
                    sudo apt install -y speedtest-cli
                fi
            fi
            ;;
        *)
            echo "Unsupported OS for speedtest installation"
            ;;
    esac
fi

# Ask user if they want to install Tailscale
read -p "Do you want to install Tailscale? (y/n): " install_tailscale
if [[ $install_tailscale =~ ^[Yy]$ ]]; then
    echo "Installing Tailscale..."
    
    case $OS in
        "dietpi")
            /boot/dietpi/dietpi-software install 162
            ;;
        "raspberrypi"|"debian"|"ubuntu")
            curl -fsSL https://tailscale.com/install.sh | sh
            ;;
        *)
            echo "Unsupported OS for Tailscale installation"
            ;;
    esac
    
    # Ask user if they want to configure Tailscale as exit node
    read -p "Do you want to configure Tailscale as exit node? (y/n): " configure_exitnode
    if [[ $configure_exitnode =~ ^[Yy]$ ]]; then
        echo "Configuring Tailscale as exit node..."
        if [[ -f ./tailscale-exitnode.sh ]]; then
            chmod +x ./tailscale-exitnode.sh
            ./tailscale-exitnode.sh
        else
            echo "Error: tailscale-exitnode.sh not found"
        fi
    fi
fi

# Ask user if they want to install ZeroTier
read -p "Do you want to install ZeroTier? (y/n): " install_zerotier
if [[ $install_zerotier =~ ^[Yy]$ ]]; then
    echo "Installing ZeroTier..."
    
    case $OS in
        "dietpi")
            /boot/dietpi/dietpi-software install 172
            ;;
        "raspberrypi"|"debian"|"ubuntu")
            curl -s https://install.zerotier.com | sudo bash
            ;;
        *)
            echo "Unsupported OS for ZeroTier installation"
            ;;
    esac
    
    read -p "Enter ZeroTier network ID to join (or press Enter to skip): " network_id
    if [[ -n $network_id ]]; then
        sudo zerotier-cli join $network_id
        echo "Joined ZeroTier network: $network_id"
    fi
fi

# Ask user if they want to install and configure zram
read -p "Do you want to install and configure zram for memory compression? (y/n): " install_zram
if [[ $install_zram =~ ^[Yy]$ ]]; then
    echo "Installing zram..."
    
    case $OS in
        "dietpi")
            /boot/dietpi/dietpi-software install 203
            ;;
        "raspberrypi"|"debian"|"ubuntu")
            sudo apt update
            sudo apt install -y zram-config
            
            sudo systemctl stop zram-config
            echo "PERCENT=50" | sudo tee /etc/default/zramswap > /dev/null
            echo "ALGO=lz4" | sudo tee -a /etc/default/zramswap > /dev/null
            sudo systemctl start zram-config
            sudo systemctl enable zram-config
            ;;
        *)
            echo "Unsupported OS for zram installation"
            ;;
    esac

    echo "zram configured successfully"
fi