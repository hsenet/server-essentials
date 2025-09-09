#!/bin/bash
#
# Converts device to Tailscale subnet router

# Get local subnet
SUBNET=$(ip route | grep -E '^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.' | grep -v tailscale | head -1 | awk '{print $1}')

echo "Converting $HOSTNAME to subnet router for $SUBNET"
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	[Yy][Ee][Ss]|[Yy] ) echo "OK, proceeding...";;
	[Nn][Oo]|[Nn] ) echo "Exiting..."; exit 0;;
	* ) echo "Invalid response"; exit 1;;
esac

# Check if Tailscale is installed
if ! command -v tailscale &> /dev/null; then
    echo "Tailscale is not installed. Please install Tailscale first."
    exit 1
fi

# Enable IP forwarding
if [ -d "/etc/sysctl.d" ]; then
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
else
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf
fi

# Optimize UDP GRO forwarding
if ! command -v ethtool &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y ethtool
fi
if command -v ethtool &> /dev/null; then
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    sudo ethtool -K $INTERFACE rx-udp-gro-forwarding on
fi

# Configure Tailscale as subnet router
sudo tailscale up --advertise-routes=$SUBNET --ssh

echo "✅ Subnet router configured for $SUBNET"
echo "Enable subnet routes in Tailscale Admin Console"