#!/bin/bash
# Ubuntu Server DietPi-style Installer
# Author: Jenkin

sudo apt update
sudo apt install -y whiptail curl

# --- CATEGORY MENUS ---
main_menu() {
    CHOICE=$(whiptail --title "Ubuntu Server Software Installer" \
        --menu "Select a category" 20 60 10 \
        1 "Web Servers" \
        2 "Databases" \
        3 "Networking & Remote Access" \
        4 "Home Automation & IoT" \
        5 "AI / Surveillance" \
        6 "Security Tools" \
        7 "Exit" \
        3>&1 1>&2 2>&3)

    case $CHOICE in
        1) web_servers ;;
        2) databases ;;
        3) networking ;;
        4) home_automation ;;
        5) ai_surveillance ;;
        6) security_tools ;;
        7) exit 0 ;;
    esac
}

web_servers() {
    OPTIONS=(
        "nginx" "Nginx Web Server" OFF
        "apache2" "Apache Web Server" OFF
        "docker.io" "Docker Engine" OFF
        "compose" "Docker Compose Plugin" OFF
        "portainer" "Portainer Docker UI" OFF
    )
    run_installer "Web Servers" "${OPTIONS[@]}"
}

databases() {
    OPTIONS=(
        "mariadb-server" "MariaDB SQL Server" OFF
        "postgresql" "PostgreSQL SQL Server" OFF
    )
    run_installer "Databases" "${OPTIONS[@]}"
}

networking() {
    OPTIONS=(
        "tailscale" "Tailscale Mesh VPN" OFF
        "zerotier" "ZeroTier Virtual Network" OFF
    )
    run_installer "Networking & Remote Access" "${OPTIONS[@]}"
}

home_automation() {
    OPTIONS=(
        "mosquitto" "MQTT Broker" OFF
        "homeassistant" "Home Assistant (Docker)" OFF
        "nodejs" "Node.js Runtime" OFF
        "python3" "Python 3 Runtime" OFF
    )
    run_installer "Home Automation & IoT" "${OPTIONS[@]}"
}

ai_surveillance() {
    OPTIONS=(
        "frigate" "Frigate NVR (Docker)" OFF
        "motioneye" "MotionEye Surveillance (Docker)" OFF
        "zoneminder" "ZoneMinder NVR" OFF
    )
    run_installer "AI / Surveillance" "${OPTIONS[@]}"
}

security_tools() {
    OPTIONS=(
        "fail2ban" "Brute-force Protection" OFF
        "ufw" "Uncomplicated Firewall" OFF
    )
    run_installer "Security Tools" "${OPTIONS[@]}"
}

# --- INSTALLER LOGIC ---
run_installer() {
    TITLE=$1
    shift
    OPTIONS=("$@")
    CHOICES=$(whiptail --title "$TITLE" --checklist "Select software to install" 25 78 15 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return
    CHOICES=($CHOICES)

    for choice in "${CHOICES[@]}"; do
        case $choice in
            "\"nginx\"") sudo apt install -y nginx ;;
            "\"apache2\"") sudo apt install -y apache2 ;;
            "\"docker.io\"") sudo apt install -y docker.io ;;
            "\"compose\"") sudo apt install -y docker-compose-plugin ;;
            "\"portainer\"")
                sudo docker volume create portainer_data
                sudo docker run -d \
                    -p 8000:8000 -p 9443:9443 \
                    --name portainer \
                    --restart=unless-stopped \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v portainer_data:/data \
                    portainer/portainer-ce:latest
                ;;
            "\"mariadb-server\"") sudo apt install -y mariadb-server ;;
            "\"postgresql\"") sudo apt install -y postgresql postgresql-contrib ;;
            "\"tailscale\"")
                curl -fsSL https://tailscale.com/install.sh | sh
                sudo tailscale up
                ;;
            "\"zerotier\"")
                curl -s https://install.zerotier.com | sudo bash
                ;;
            "\"mosquitto\"") sudo apt install -y mosquitto mosquitto-clients ;;
            "\"homeassistant\"")
                sudo docker run -d \
                    --name homeassistant \
                    --restart=unless-stopped \
                    -v /PATH/TO/CONFIG:/config \
                    --network=host \
                    ghcr.io/home-assistant/home-assistant:stable
                ;;
            "\"nodejs\"") curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs ;;
            "\"python3\"") sudo apt install -y python3 python3-pip ;;
            "\"frigate\"")
                sudo docker volume create frigate-config
                sudo docker run -d \
                    --name frigate \
                    --restart=unless-stopped \
                    --mount type=tmpfs,target=/tmp/cache,tmpfs-size=100000000 \
                    --mount source=frigate-config,target=/config \
                    --device /dev/bus/usb:/dev/bus/usb \
                    -p 5000:5000 \
                    -p 1935:1935 \
                    blakeblackshear/frigate:stable
                ;;
            "\"motioneye\"")
                sudo docker run -d \
                    --name motioneye \
                    --restart=unless-stopped \
                    -p 8765:8765 \
                    -v /etc/localtime:/etc/localtime:ro \
                    -v /PATH/TO/CONFIG:/etc/motioneye \
                    -v /PATH/TO/MEDIA:/var/lib/motioneye \
                    ccrisan/motioneye:master-amd64
                ;;
            "\"zoneminder\"")
                sudo apt install -y zoneminder
                sudo systemctl enable zoneminder
                sudo systemctl start zoneminder
                ;;
            "\"fail2ban\"") sudo apt install -y fail2ban ;;
            "\"ufw\"") sudo apt install -y ufw && sudo ufw enable ;;
        esac
    done
}

# --- MAIN LOOP ---
while true; do
    main_menu
done
