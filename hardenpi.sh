#!/bin/bash
#
# Removes logging to SDcard and instead to RAM

echo "Install Log2ram?"
read -p "Do you want to proceed? (yes/no) " yn
case $yn in 
	yes ) echo ok, we will proceed;;
	no ) echo exiting...;
		exit;;
	* ) echo invalid response;
		exit 1;;
esac

echo "deb [signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian/ bookworm main" | sudo tee /etc/apt/sources.list.d/azlux.list
sudo wget -O /usr/share/keyrings/azlux-archive-keyring.gpg  https://azlux.fr/repo.gpg
sudo apt update
sudo apt install log2ram

sudo du -sh /var/log

echo "Edit /etc/log2ram.conf to increase SIZE to much above the value maintained above."

exit;