#!/bin/bash
#
# Creates an exit node server on tailscale network

echo "Now converting $HOSTNAME into exit node"
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	[Yy][Ee][Ss]|[Yy] ) echo "OK, proceeding...";;
	[Nn][Oo]|[Nn] ) echo "Exiting...";
		exit 0;;
	* ) echo "Invalid response";
		exit 1;;
esac

# Enable IP forwarding
if [ -d "/etc/sysctl.d" ]; then
    echo "Configuring IP forwarding via /etc/sysctl.d..."
    echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
else
    echo "Configuring IP forwarding via /etc/sysctl.conf..."
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf
fi

# Check and configure firewall if available
if command -v firewall-cmd &> /dev/null; then
    echo "Updating firewall rules..."
    sudo firewall-cmd --permanent --add-masquerade
    sudo firewall-cmd --reload
else
    echo "firewall-cmd not found. Skipping firewall configuration."
fi

# Configure and start Tailscale as exit node
echo "Setting up Tailscale as exit node..."
sudo tailscale up --advertise-exit-node --ssh --accept-risk=lose-ssh

echo "✅ Setup complete!"
echo "You can now go to Tailscale Admin > Machines. Locate this machine, open the Edit route settings panel, and enable the Use as exit node option."

exit 0