#!/bin/bash
# Frigate UI: http://<server-ip>:5000
# Home Assistant: http://<server-ip>:8123
# MQTT Broker: mqtt://<server-ip>:1883
set -e

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing prerequisites ==="
sudo apt install -y ca-certificates curl gnupg lsb-release software-properties-common

echo "=== Adding Docker official GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "=== Adding Docker repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing Docker Engine + Compose plugin ==="
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "=== Installing Coral USB TPU runtime ==="
echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | \
  sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt update
sudo apt install -y libedgetpu1-std

echo "=== Creating project directories ==="
mkdir -p ~/surveillance/{frigate/config,mosquitto/{config,data,log},homeassistant/config,media/frigate}

echo "=== Creating Mosquitto config ==="
cat > ~/surveillance/mosquitto/config/mosquitto.conf <<EOF
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
listener 1883
allow_anonymous false
password_file /mosquitto/config/password.txt
EOF

echo "=== Creating Frigate config ==="
cat > ~/surveillance/frigate/config/config.yml <<EOF
mqtt:
  host: mosquitto
  user: mqtt_user
  password: mqtt_pass

detectors:
  coral:
    type: edgetpu
    device: usb

cameras:
  front_door:
    ffmpeg:
      inputs:
        - path: rtsp://user:pass@camera-ip:554/stream
          roles:
            - detect
            - record
    detect:
      width: 1920
      height: 1080
      fps: 5
EOF

echo "=== Creating docker-compose.yml ==="
cat > ~/surveillance/docker-compose.yml <<'EOF'
version: "3.9"

services:
  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log

  frigate:
    container_name: frigate
    image: ghcr.io/blakeblackshear/frigate:stable
    privileged: true
    restart: unless-stopped
    shm_size: "64mb"
    devices:
      - /dev/bus/usb:/dev/bus/usb
      - /dev/dri:/dev/dri
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./frigate/config:/config
      - ./media/frigate:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "5000:5000"
      - "1935:1935"
      - "8554:8554"
      - "8555:8555/tcp"
      - "8555:8555/udp"
    environment:
      - FRIGATE_RTSP_PASSWORD=your_rtsp_password
      - LIBVA_DRIVER_NAME=iHD

  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - ./homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
EOF

echo "=== Creating MQTT user ==="
docker run --rm -it \
  -v ~/surveillance/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto:2 mosquitto_passwd -c /mosquitto/config/password.txt mqtt_user

echo "=== Starting stack ==="
cd ~/surveillance
docker compose up -d

echo "=== Done! ==="
echo "Frigate UI: http://<server-ip>:5000"
echo "Home Assistant: http://<server-ip>:8123"
echo "MQTT Broker: mqtt://<server-ip>:1883"
