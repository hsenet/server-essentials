
#!/bin/bash

echo "Installing speedtest..."

# Add Speedtest repository
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash

# Install Speedtest
sudo apt-get install speedtest

echo "Installing Tailscale..."

# Install Tailscale using dietpi-software
# The -i flag installs software items by their ID (162 is Tailscale)
/boot/dietpi/dietpi-software install 162

echo "Configuring Tailscale as exit node..."
# Give execute permissions to the script
chmod +x ./tailscale-exitnode.sh
# Run the tailscale-exitnode.sh script
./tailscale-exitnode.sh
