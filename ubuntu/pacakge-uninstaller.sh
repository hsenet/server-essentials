#!/bin/bash
# Ubuntu Server DietPi-style Uninstaller
# Author: Copilot + Jenkin

sudo apt update
sudo apt install -y whiptail

OPTIONS=(
    "nginx" "Nginx Web Server" OFF
    "apache2" "Apache Web Server" OFF
    "docker.io" "Docker Engine" OFF
    "compose" "Docker Compose Plugin" OFF
    "portainer" "Portainer Docker UI" OFF
    "mariadb-server" "MariaDB SQL Server" OFF
    "postgresql" "PostgreSQL SQL Server" OFF
    "tailscale" "Tailscale Mesh VPN" OFF
    "zerotier" "ZeroTier Virtual Network" OFF
    "mosquitto" "MQTT Broker" OFF
    "homeassistant" "Home Assistant (Docker)" OFF
    "nodejs" "Node.js Runtime" OFF
    "python3" "Python 3 Runtime" OFF
    "frigate" "Frigate NVR (Docker)" OFF
    "fail2ban" "Brute-force Protection" OFF
    "ufw" "Uncomplicated Firewall" OFF
)

CHOICES=$(whiptail --title "Uninstall Software" --checklist "Select software to remove" 25 78 15 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
[ $? -ne 0 ] && exit 0
CHOICES=($CHOICES)

for choice in "${CHOICES[@]}"; do
    case $choice in
        "\"nginx\"") sudo apt remove --purge -y nginx ;;
        "\"apache2\"") sudo apt remove --purge -y apache2 ;;
        "\"docker.io\"") sudo apt remove --purge -y docker.io ;;
        "\"compose\"") sudo apt remove --purge -y docker-compose-plugin ;;
        "\"portainer\"") sudo docker rm -f portainer && sudo docker volume rm portainer_data ;;
        "\"mariadb-server\"") sudo apt remove --purge -y mariadb-server ;;
        "\"postgresql\"") sudo apt remove --purge -y postgresql postgresql-contrib ;;
        "\"tailscale\"") sudo tailscale down && sudo apt remove --purge -y tailscale ;;
        "\"zerotier\"") sudo zerotier-cli leave && sudo apt remove --purge -y zerotier-one ;;
        "\"mosquitto\"") sudo apt remove --purge -y mosquitto mosquitto-clients ;;
        "\"homeassistant\"") sudo docker rm -f homeassistant ;;
        "\"nodejs\"") sudo apt remove --purge -y nodejs ;;
        "\"python3\"") sudo apt remove --purge -y python3 python3-pip ;;
        "\"frigate\"") sudo docker rm -f frigate && sudo docker volume rm frigate-config ;;
        "\"fail2ban\"") sudo apt remove --purge -y fail2ban ;;
        "\"ufw\"") sudo apt remove --purge -y ufw ;;
    esac
done

sudo apt autoremove -y
echo "✅ Uninstallation complete!"