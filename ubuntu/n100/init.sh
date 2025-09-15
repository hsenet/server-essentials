sudo apt update
sudo apt install lm-sensors intel-gpu-tools curl jq
sudo sensors-detect
sensors
cp motd_custom ~/.motd_custom
chmod +x ~/.motd_custom
echo "~/.motd_custom" >> ~/.bashrc