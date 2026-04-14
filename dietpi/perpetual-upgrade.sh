#!/bin/bash

################################################################################
# DietPI Perpetual Auto-Upgrade Script
# 
# This script continuously monitors and automatically upgrades DietPI
# at specified intervals. It runs in the background and logs all activity.
#
# Usage:
#   ./perpetual-upgrade.sh [options]
#
# Options:
#   -i, --interval HOURS    Check interval in hours (default: 6)
#   -d, --dry-run          Show what would be updated without applying
#   -l, --log-file PATH    Custom log file path (default: /var/log/dietpi-upgrade.log)
#   -f, --foreground       Run in foreground (don't daemonize)
#   -s, --stop             Stop the running upgrade daemon
#   --uninstall            Uninstall daemon and remove all files
#   -h, --help             Display this help message
#
# Examples:
#   sudo ./perpetual-upgrade.sh                    # Start with default settings
#   sudo ./perpetual-upgrade.sh -i 12             # Check every 12 hours
#   sudo ./perpetual-upgrade.sh -d                # Dry run to see what would update
#   sudo ./perpetual-upgrade.sh -f                # Run in foreground
#   sudo ./perpetual-upgrade.sh --uninstall       # Remove daemon and files
#
################################################################################

set -euo pipefail

# Configuration
INTERVAL_HOURS=${INTERVAL_HOURS:-6}
DRY_RUN=false
LOG_FILE="/var/log/dietpi-upgrade.log"
FOREGROUND=false
PIDFILE="/var/run/dietpi-perpetual-upgrade.pid"
DAEMON_NAME="dietpi-perpetual-upgrade"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
    log "WARN" "$@"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    log "ERROR" "$@"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS" "$@"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dietpi() {
    if [[ ! -f /boot/dietpi/.version ]]; then
        log_error "DietPI not detected. This script requires DietPI to run."
        exit 1
    fi
    
    local dietpi_version=$(cat /boot/dietpi/.version)
    log_info "DietPI version: ${dietpi_version}"
}

check_dpkg_lock() {
    # Check if dpkg is currently locked
    if [[ -f /var/lib/apt/lists/lock ]] || [[ -f /var/cache/apt/archives/lock ]] || [[ -f /var/lib/dpkg/lock* ]]; then
        return 0  # Lock exists
    fi
    return 1  # No lock
}

wait_for_dpkg_lock() {
    local max_wait=$((INTERVAL_HOURS * 3600))
    local elapsed=0
    local check_interval=30
    
    while [[ $elapsed -lt $max_wait ]]; do
        if ! check_dpkg_lock; then
            log_info "dpkg lock released after $elapsed seconds"
            return 0
        fi
        
        log_warn "dpkg is locked. Waiting... ($elapsed/$max_wait seconds)"
        sleep $check_interval
        ((elapsed += check_interval))
    done
    
    log_error "dpkg lock still held after $max_wait seconds. Skipping upgrade attempt."
    return 1
}

check_tailscale_status() {
    # Check if Tailscale is installed and running
    if ! command -v tailscale &>/dev/null; then
        return 1  # Tailscale not installed
    fi
    
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        return 0  # Tailscale is running
    fi
    return 1  # Tailscale not running
}

check_network_connectivity() {
    # Try to reach a reliable DNS server or public gateway
    if timeout 5 ping -c 1 8.8.8.8 &>/dev/null 2>&1; then
        return 0
    fi
    
    # Fall back to checking if we have any network interface up
    if ip link show | grep -q "state UP"; then
        return 0
    fi
    
    return 1
}

check_tailscale_connectivity() {
    # Check if device is connected to Tailscale network
    if ! command -v tailscale &>/dev/null; then
        return 0  # Tailscale not installed, skip check
    fi
    
    if ! systemctl is-active --quiet tailscaled 2>/dev/null; then
        return 1  # Tailscale daemon not running
    fi
    
    # Check if tailscale status shows connected
    if tailscale status 2>/dev/null | grep -q "idle"; then
        return 0  # Connected and idle
    fi
    
    if tailscale status 2>/dev/null | grep -q "is (Ethernet|DERP|Wireguard)"; then
        return 0  # Connected via some interface
    fi
    
    return 1  # Not connected
}

check_dietpi_update() {
    # Run dietpi-update with -c flag to check for updates without installing
    if /boot/dietpi/dietpi-update -c 2>&1 | tee -a "${LOG_FILE}" | grep -q "Updates available"; then
        return 0
    else
        return 1
    fi
}

perform_upgrade() {
    log_info "Starting DietPI upgrade..."
    
    # Pre-upgrade checks
    log_info "Performing pre-upgrade checks..."
    
    # Check for dpkg locks and wait for them to be released
    if check_dpkg_lock; then
        log_warn "dpkg is currently locked. Another process is using the package manager."
        if ! wait_for_dpkg_lock; then
            log_error "Unable to acquire dpkg lock. Aborting upgrade."
            return 1
        fi
    fi
    
    # Check network connectivity
    if ! check_network_connectivity; then
        log_error "No network connectivity detected. Aborting upgrade."
        return 1
    fi
    
    # Verify Tailscale is connected if it's installed
    local tailscale_was_running=false
    if check_tailscale_status; then
        tailscale_was_running=true
        if ! check_tailscale_connectivity; then
            log_warn "Tailscale is not connected. This upgrade may cause further disconnection."
            log_warn "Proceeding anyway, but exit node connectivity may be impacted."
        else
            log_info "Tailscale is properly connected. Proceeding with upgrade."
        fi
    fi
    
    if [[ $DRY_RUN == true ]]; then
        log_info "[DRY-RUN] Would execute: /boot/dietpi/dietpi-update"
        log_info "[DRY-RUN] Would perform post-upgrade checks"
        return 0
    fi
    
    # Perform the upgrade
    log_info "===== STARTING UPGRADE PROCESS ====="
    local upgrade_start=$(date +%s)
    
    if /boot/dietpi/dietpi-update 2>&1 | tee -a "${LOG_FILE}"; then
        log_success "DietPI upgrade completed successfully"
        
        # Post-upgrade checks
        log_info "Performing post-upgrade checks..."
        
        # Re-check network connectivity
        if ! check_network_connectivity; then
            log_error "Network connectivity lost after upgrade. This may recover automatically."
        else
            log_info "Network connectivity verified"
        fi
        
        # Wait for Tailscale to reconnect if it was running before
        if [[ $tailscale_was_running == true ]]; then
            log_info "Waiting for Tailscale to reconnect..."
            local reconnect_timeout=120
            local elapsed=0
            
            while [[ $elapsed -lt $reconnect_timeout ]]; do
                if check_tailscale_connectivity; then
                    log_success "Tailscale reconnected successfully"
                    break
                fi
                sleep 5
                ((elapsed += 5))
            done
            
            if [[ $elapsed -ge $reconnect_timeout ]]; then
                log_error "Tailscale did not reconnect within ${reconnect_timeout} seconds"
                log_warn "Manual intervention may be required. Run: sudo systemctl restart tailscaled"
                return 1
            fi
        fi
        
        local upgrade_duration=$(($(date +%s) - upgrade_start))
        log_info "Upgrade completed in $((upgrade_duration / 60)) minutes $((upgrade_duration % 60)) seconds"
        return 0
    else
        log_error "DietPI upgrade failed with exit code $?"
        return 1
    fi
}

daemonize() {
    log_info "Starting DietPI perpetual upgrade daemon..."
    
    # Create a systemd service file for better control
    create_systemd_service
    
    # Start the service if systemd is available
    if command -v systemctl &>/dev/null; then
        if systemctl daemon-reload && systemctl enable "${DAEMON_NAME}.service" && systemctl start "${DAEMON_NAME}.service"; then
            log_success "Daemon started successfully via systemd"
            systemctl status "${DAEMON_NAME}.service"
        else
            log_warn "Failed to start via systemd, falling back to background process"
            nohup "$0" --foreground --interval "$INTERVAL_HOURS" --log-file "$LOG_FILE" >/dev/null 2>&1 &
            echo $! > "${PIDFILE}"
            log_success "Daemon started with PID: $(cat ${PIDFILE})"
        fi
    fi
}

create_systemd_service() {
    local service_file="/etc/systemd/system/${DAEMON_NAME}.service"
    
    if [[ -f $service_file ]]; then
        log_info "Systemd service already exists"
        return
    fi
    
    log_info "Creating systemd service file..."
    
    cat > "${service_file}" << 'EOF'
[Unit]
Description=DietPI Perpetual Auto-Upgrade Daemon for Exit Nodes
Documentation=https://github.com/DietPi/DietPi
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/root/dietpi-perpetual-upgrade.sh --foreground
Restart=always
RestartSec=30
StartLimitInterval=600
StartLimitBurst=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dietpi-upgrade

# Resource management for exit nodes
CPUAccounting=yes
MemoryAccounting=yes
Nice=10

# Security hardening
PrivateTmp=no
NoNewPrivileges=yes

# Exit node considerations - ensure system health
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "Systemd service created at ${service_file}"
}

stop_daemon() {
    log_info "Stopping DietPI perpetual upgrade daemon..."
    
    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet "${DAEMON_NAME}.service"; then
            if systemctl stop "${DAEMON_NAME}.service"; then
                log_success "Daemon stopped successfully"
                return 0
            fi
        fi
    fi
    
    if [[ -f $PIDFILE ]]; then
        local pid=$(cat "${PIDFILE}")
        if kill "$pid" 2>/dev/null; then
            rm -f "${PIDFILE}"
            log_success "Daemon stopped (PID: $pid)"
            return 0
        fi
    fi
    
    log_warn "No running daemon found"
    return 1
}

show_status() {
    echo -e "${BLUE}=== DietPI Perpetual Upgrade Status ===${NC}"
    
    if command -v systemctl &>/dev/null; then
        systemctl status "${DAEMON_NAME}.service" 2>/dev/null || echo "Service not found"
    elif [[ -f $PIDFILE ]]; then
        local pid=$(cat "${PIDFILE}")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Daemon running with PID: $pid"
        else
            echo "PID file exists but process not found"
        fi
    else
        echo "Daemon is not running"
    fi
    
    echo -e "\n${BLUE}=== Recent Log Entries ===${NC}"
    if [[ -f $LOG_FILE ]]; then
        tail -20 "${LOG_FILE}"
    else
        echo "No log file found yet"
    fi
}

print_help() {
    grep "^#" "$0" | grep -E "^\s*#\s" | head -n 30
}

upgrade_loop() {
    log_info "Starting upgrade loop with ${INTERVAL_HOURS} hour interval"
    log_info "Press Ctrl+C to stop"
    
    # Ensure log file exists and is writable
    touch "${LOG_FILE}" 2>/dev/null || {
        log_error "Cannot create log file at ${LOG_FILE}"
        exit 1
    }
    
    # Trap for graceful shutdown
    trap 'log_info "Received interrupt signal, shutting down gracefully..."; exit 0' SIGINT SIGTERM
    
    local iteration=0
    local consecutive_failures=0
    local max_consecutive_failures=5
    
    while true; do
        ((iteration++))
        log_info "=== Upgrade check iteration $iteration ==="
        
        # Pre-check: Ensure we have network connectivity
        if ! check_network_connectivity; then
            log_warn "No network connectivity. Skipping update check for now."
            consecutive_failures=$((consecutive_failures + 1))
            
            if [[ $consecutive_failures -ge $max_consecutive_failures ]]; then
                log_error "Network connectivity lost for $max_consecutive_failures consecutive checks."
                log_error "Device may have lost internet connectivity or Tailscale exit node connectivity."
            fi
        else
            consecutive_failures=0
        fi
        
        # Check for updates
        if check_dietpi_update; then
            log_warn "Updates available for DietPI"
            
            # Attempt upgrade
            if perform_upgrade; then
                log_success "Upgrade cycle completed successfully"
            else
                log_error "Upgrade cycle failed. Will retry at next interval."
            fi
        else
            log_info "No updates available at this time"
        fi
        
        # Calculate next check time
        local sleep_seconds=$((INTERVAL_HOURS * 3600))
        local next_check=$(date -d "+${INTERVAL_HOURS} hours" '+%Y-%m-%d %H:%M:%S')
        log_info "Next update check scheduled for: ${next_check}"
        log_info "Sleeping for ${INTERVAL_HOURS} hours..."
        
        sleep "${sleep_seconds}"
    done
}

################################################################################
# Uninstall Functions
################################################################################

confirm_uninstall() {
    local response
    read -p "$(echo -e ${YELLOW})Are you sure you want to uninstall the daemon?$(echo -e ${NC}) (y/N): " -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

disable_and_remove_service() {
    log_info "Disabling systemd service..."
    
    if ! command -v systemctl &>/dev/null; then
        log_warn "systemd not available, skipping service disabling"
        return 0
    fi
    
    if systemctl is-active --quiet "${DAEMON_NAME}.service" 2>/dev/null; then
        if systemctl stop "${DAEMON_NAME}.service"; then
            log_success "Service stopped"
        fi
    fi
    
    local service_file="/etc/systemd/system/${DAEMON_NAME}.service"
    if [[ -f $service_file ]]; then
        if systemctl disable "${DAEMON_NAME}.service" 2>/dev/null; then
            log_success "Service disabled"
        fi
        
        if rm -f "${service_file}"; then
            log_success "Service file removed"
        fi
        
        if systemctl daemon-reload; then
            log_success "systemd daemon reloaded"
        fi
    fi
    
    return 0
}

uninstall_daemon() {
    log_info "Uninstalling DietPI perpetual upgrade daemon..."
    echo ""
    
    # Confirm action
    if ! confirm_uninstall; then
        log_warn "Uninstallation cancelled"
        return 0
    fi
    
    echo ""
    log_info "Starting uninstallation..."
    echo ""
    
    # Stop daemon
    if [[ -f $PIDFILE ]]; then
        local pid=$(cat "${PIDFILE}")
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" 2>/dev/null && log_success "Daemon stopped"
        fi
        rm -f "${PIDFILE}"
    fi
    
    # Disable and remove service
    disable_and_remove_service
    
    # Remove script file
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/perpetual-upgrade.sh"
    if [[ -f $script_path ]]; then
        if rm -f "$script_path"; then
            log_success "Script file removed: ${script_path}"
        fi
    fi
    
    # Remove log file
    if [[ -f $LOG_FILE ]]; then
        if rm -f "${LOG_FILE}"; then
            log_success "Log file removed: ${LOG_FILE}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}=== Uninstallation completed successfully ===${NC}"
    echo ""
    return 0
}

################################################################################
# Main
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interval)
                INTERVAL_HOURS="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -f|--foreground)
                FOREGROUND=true
                shift
                ;;
            -s|--stop)
                check_root
                stop_daemon
                exit $?
                ;;
            --uninstall)
                check_root
                uninstall_daemon
                exit $?
                ;;
            --status)
                show_status
                exit 0
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
    
    # Validation
    check_root
    check_dietpi
    
    # Validate interval is a positive number
    if ! [[ $INTERVAL_HOURS =~ ^[0-9]+$ ]] || [[ $INTERVAL_HOURS -lt 1 ]]; then
        log_error "Interval must be a positive integer (hours)"
        exit 1
    fi
    
    # Create log directory if needed
    local log_dir=$(dirname "${LOG_FILE}")
    mkdir -p "${log_dir}" 2>/dev/null || {
        log_error "Cannot create log directory: ${log_dir}"
        exit 1
    }
    
    log_info "================================"
    log_info "DietPI Perpetual Upgrade Script"
    log_info "================================"
    log_info "Check interval: ${INTERVAL_HOURS} hours"
    log_info "Log file: ${LOG_FILE}"
    log_info "Dry run: ${DRY_RUN}"
    log_info "Foreground: ${FOREGROUND}"
    
    # Start the upgrade loop
    if [[ $FOREGROUND == true ]]; then
        upgrade_loop
    else
        daemonize
    fi
}

main "$@"
