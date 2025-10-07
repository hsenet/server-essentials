#!/usr/bin/env bash
set -euo pipefail

# 1. Update
sudo apt update && sudo apt upgrade -y

# 2. Docker
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

# 3. Install Docker Compose standalone
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Copy portainer folder to home directory
cp -r portainer $HOME/
chown -R $USER:$USER $HOME/portainer

# 5. Start Portainer from home directory
cd $HOME/portainer
docker-compose up -d

echo "Docker and Portainer installed successfully!"
echo "Portainer folder copied to: $HOME/portainer"
echo "Access Portainer at: http://$(hostname -I | awk '{print $1}'):9000"

