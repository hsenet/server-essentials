#!/bin/bash
#
# Creates an exit node server on tailscale network

echo "Now converting $HOSTNAME into exit node"
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	yes ) echo ok, we will proceed;;
	no ) echo exiting...;
		exit;;
	* ) echo invalid response;
		exit 1;;
esac

if [ -d "/etc/sysctl.d" ]; then
    echo
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
    sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
else
    echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p /etc/sysctl.conf
fi

if ! command -v firewall-cmd &> /dev/null
    echo "Update firewall"
    firewall-cmd --permanent --add-masquerade
then
    echo "Firewall not found. Skipping.."
fi

echo "You can now go to Tailscale Admin > Machines. Locate this machine,  open the Edit route settings panel, and enable the Use as exit node option"

exit;