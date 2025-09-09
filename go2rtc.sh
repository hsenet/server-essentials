#!/bin/bash

# This script automates the installation and uninstallation of go2rtc
# on a DietPi system using a direct binary and a systemd service.

# --- Variables ---
SERVICE_NAME="go2rtc"
GO2RTC_DIR="/var/lib/go2rtc"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# --- Functions ---

# Function to check if go2rtc is installed (by checking for the service file)
check_go2rtc_installed() {
    if [ -f "${SERVICE_FILE}" ]; then
        return 0 # Service file exists, so assume installed
    else
        return 1 # Service file does not exist
    fi
}

# Function to get the correct go2rtc binary based on architecture
get_binary_name() {
    local arch=$(uname -m)
    case "${arch}" in
        aarch64)
            echo "go2rtc_linux_arm64"
            ;;
        armv7l)
            echo "go2rtc_linux_armv7"
            ;;
        *)
            echo "Unsupported architecture: ${arch}" >&2
            exit 1
            ;;
    esac
}

# Function to install go2rtc
install_go2rtc() {
    echo "--- Installing go2rtc ---"

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required but not installed. Please install curl first."
        exit 1
    fi

    # Create the go2rtc directory
    echo "Creating installation directory: ${GO2RTC_DIR}"
    if ! sudo mkdir -p "${GO2RTC_DIR}"; then
        echo "Error: Failed to create directory ${GO2RTC_DIR}"
        exit 1
    fi
    
    # Get the correct binary name and download it
    local binary_name=$(get_binary_name)
    echo "Downloading the latest go2rtc binary for your architecture (${binary_name})..."
    sudo curl -L "https://github.com/AlexxIT/go2rtc/releases/latest/download/${binary_name}" -o "${GO2RTC_DIR}/${SERVICE_NAME}"
    
    # Make the binary executable
    echo "Making the binary executable..."
    sudo chmod +x "${GO2RTC_DIR}/${SERVICE_NAME}"

    # Create the systemd service file
    echo "Creating the systemd service file: ${SERVICE_FILE}"
    sudo tee "${SERVICE_FILE}" > /dev/null <<EOF
[Unit]
Description=go2rtc
After=network.target

[Service]
Restart=always
WorkingDirectory=${GO2RTC_DIR}/
ExecStart=${GO2RTC_DIR}/${SERVICE_NAME}
User=$(logname 2>/dev/null || echo "pi") # Auto-detect current user, fallback to pi

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable/start the service
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    echo "Enabling and starting the go2rtc service..."
    sudo systemctl enable "${SERVICE_NAME}"
    sudo systemctl start "${SERVICE_NAME}"

    echo "go2rtc has been installed and the service is running."
    echo "To configure go2rtc, create or edit the file: ${GO2RTC_DIR}/go2rtc.yaml"
    echo "For example:"
    echo "sudo nano ${GO2RTC_DIR}/go2rtc.yaml"
    echo "And add your streams."
}

# Function to uninstall go2rtc
uninstall_go2rtc() {
    echo "--- Uninstalling go2rtc ---"

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        echo "Stopping the go2rtc service..."
        sudo systemctl stop "${SERVICE_NAME}"
    else
        echo "go2rtc service is not active."
    fi

    if systemctl is-enabled --quiet "${SERVICE_NAME}"; then
        echo "Disabling the go2rtc service..."
        sudo systemctl disable "${SERVICE_NAME}"
    else
        echo "go2rtc service is not enabled."
    fi

    echo "Removing the go2rtc systemd service file: ${SERVICE_FILE}"
    sudo rm -f "${SERVICE_FILE}"

    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    echo "Removing the go2rtc directory: ${GO2RTC_DIR}"
    sudo rm -rf "${GO2RTC_DIR}"

    echo "go2rtc has been uninstalled."
}

# --- Main Script Logic ---

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo or as root."
   exit 1
fi

echo "--- go2rtc Installation/Uninstallation Script for DietPi ---"

if check_go2rtc_installed; then
    echo "go2rtc is currently installed."
    echo "What would you like to do?"
    echo "1) Uninstall go2rtc"
    echo "2) Exit"
    read -p "Enter your choice (1-2): " choice
    case "$choice" in
        1) uninstall_go2rtc ;;
        2) echo "Exiting script.";;
        *) echo "Invalid choice. Exiting.";;
    esac
else
    echo "go2rtc is not installed."
    echo "What would you like to do?"
    echo "1) Install go2rtc"
    echo "2) Exit"
    read -p "Enter your choice (1-2): " choice
    case "$choice" in
        1) install_go2rtc ;;
        2) echo "Exiting script.";;
        *) echo "Invalid choice. Exiting.";;
    esac
fi
