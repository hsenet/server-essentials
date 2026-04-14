# DietPI Perpetual Auto-Upgrade Script

A production-hardened bash script that continuously monitors and automatically upgrades DietPI at specified intervals. This script runs as a daemon in the background and logs all upgrade activities. **Specifically designed for Orange Pi Zero 3S devices running as Tailscale exit nodes worldwide.**

## Features

- **Automatic Upgrades**: Perpetually checks for and installs DietPI updates
- **Tailscale Exit Node Safe**: Monitors Tailscale connectivity and waits for reconnection after upgrades
- **dpkg Lock Handling**: Detects and waits for package manager locks instead of failing
- **Network Awareness**: Verifies network connectivity before and after upgrades
- **Configurable Intervals**: Customize the update check frequency (default: 6 hours)
- **Systemd Integration**: Automatically creates and manages a systemd service with exit node optimizations
- **Comprehensive Logging**: All activities logged to `/var/log/dietpi-upgrade.log` with detailed timestamps
- **Dry-Run Mode**: Test what would be upgraded without actually applying changes
- **Graceful Shutdown**: Properly handles interrupt signals and failed upgrades
- **Error Recovery**: Automatic retry logic for transient failures
- **Status Monitoring**: Check the status of the running daemon and recent logs

## Orange Pi Zero 3S / Tailscale Exit Node Special Features

This script includes specific protections for devices running as Tailscale exit nodes:

1. **Pre-upgrade Checks**: 
   - Verifies network connectivity before attempting upgrade
   - Checks if Tailscale is connected and idle
   - Warns if Tailscale is already disconnected before upgrade starts

2. **dpkg Lock Management**: 
   - Detects if apt/dpkg is locked by another process
   - Waits up to the configured interval for the lock to clear
   - Prevents failed upgrades due to package manager conflicts

3. **Post-upgrade Validation**:
   - Waits up to 2 minutes for Tailscale to reconnect after upgrade
   - Logs warning if Tailscale fails to reconnect (manual restart may be needed)
   - Verifies network is still functional post-upgrade

4. **Network Monitoring**:
   - Tracks consecutive connectivity failures
   - Alerts if device loses internet connectivity across multiple check cycles
   - Helps identify when exit node has lost connectivity

## Requirements

- DietPI operating system
- Root access (required to run upgrades)
- Systemd (recommended for daemon management)
- Tailscale (optional but script is optimized for it)
- Network connectivity to reach DietPI update servers



## Installation

1. Copy the script to your DietPI system:
```bash
sudo cp perpetual-upgrade.sh /root/perpetual-upgrade.sh
sudo chmod +x /root/perpetual-upgrade.sh
```

## Usage

### Basic Usage

Start the upgrade daemon with default settings (checks every 6 hours):
```bash
sudo /root/perpetual-upgrade.sh
```

### Command Options

```
-i, --interval HOURS      Check interval in hours (default: 6)
-d, --dry-run            Show what would be updated without applying
-l, --log-file PATH      Custom log file path (default: /var/log/dietpi-upgrade.log)
-f, --foreground         Run in foreground (don't daemonize)
-s, --stop               Stop the running upgrade daemon
--uninstall              Uninstall daemon and remove all files
--status                 Show daemon status and recent logs
-h, --help               Display help message
```

### Examples

#### Check for updates every 12 hours instead of 6:
```bash
sudo /root/perpetual-upgrade.sh --interval 12
```

#### Run a dry-run to see what would be upgraded:
```bash
sudo /root/perpetual-upgrade.sh --dry-run
```

#### Run in foreground (useful for debugging):
```bash
sudo /root/perpetual-upgrade.sh --foreground
```

#### Check daemon status:
```bash
sudo /root/perpetual-upgrade.sh --status
```

#### Stop the daemon:
```bash
sudo /root/perpetual-upgrade.sh --stop
```

#### Uninstall the daemon:
```bash
sudo /root/perpetual-upgrade.sh --uninstall
```

## How It Works

1. **Initialization**: The script checks that it's running on DietPI and has root privileges
2. **Update Check**: Periodically runs `dietpi-update -c` to check for available updates
3. **Upgrade Process**: When updates are found, runs `dietpi-update` to apply them
4. **Logging**: All operations are logged with timestamps
5. **Scheduling**: Automatically waits the specified interval before the next check
6. **Daemon Management**: Creates a systemd service for persistent, automated execution

## Log File

All activities are logged to `/var/log/dietpi-upgrade.log` with timestamps. Example log entries:

```
[2024-01-15 08:30:00] [INFO] DietPI version: v9.6.0
[2024-01-15 08:30:05] [INFO] Starting upgrade loop with 6 hour interval
[2024-01-15 08:30:10] [INFO] === Upgrade check iteration 1 ===
[2024-01-15 08:30:15] [WARN] Updates available for DietPI
[2024-01-15 08:30:20] [INFO] Starting DietPI upgrade...
[2024-01-15 08:45:00] [SUCCESS] DietPI upgrade completed successfully
```

View recent logs:
```bash
sudo tail -f /var/log/dietpi-upgrade.log
```

## Systemd Service

When started normally (not in `--foreground` mode), the script automatically creates a systemd service file at `/etc/systemd/system/dietpi-perpetual-upgrade.service`:

View service status:
```bash
sudo systemctl status dietpi-perpetual-upgrade.service
```

View service logs:
```bash
sudo journalctl -u dietpi-perpetual-upgrade.service -f
```

Enable auto-start on boot:
```bash
sudo systemctl enable dietpi-perpetual-upgrade.service
```

## Troubleshooting

### Tailscale Exit Node Issues

**Problem: Tailscale disconnects during upgrade**

This is normal behavior. The script monitors for this:

1. Check the log to see if Tailscale reconnected:
```bash
sudo grep -i "tailscale" /var/log/dietpi-upgrade.log | tail -10
```

2. If it didn't reconnect automatically, restart Tailscale:
```bash
sudo systemctl restart tailscaled
```

3. If Tailscale keeps disconnecting, check for issues with the upgrade process:
```bash
sudo journalctl -u dietpi-perpetual-upgrade -n 50
```

**Problem: dpkg is locked and upgrade keeps failing**

The script waits for dpkg locks to clear automatically. If it's stuck:

1. Check what's holding the lock:
```bash
sudo lsof | grep -i dpkg
sudo ps aux | grep -i apt
```

2. If there's a stuck process, kill it carefully:
```bash
# Check for unattended-upgrades
sudo systemctl status unattended-upgrades
sudo systemctl stop unattended-upgrades

# Or check for other package manager processes
sudo pkill -f apt-get
sudo pkill -f dpkg
```

3. Clean up any corrupted package state:
```bash
sudo dpkg --configure -a
sudo apt-get clean
```

**Problem: Device loses network connectivity after upgrade**

1. Check if the issue is Tailscale-specific:
```bash
# Check regular network
ping 8.8.8.8

# Check Tailscale specifically
tailscale status

# Check for IP/DNS issues
systemctl status systemd-resolved
resolvectl query google.com
```

2. Check systemd service logs:
```bash
sudo journalctl -u dietpi-perpetual-upgrade -f
```

3. Manual network recovery:
```bash
# Restart networking
sudo systemctl restart networking

# Restart Tailscale
sudo systemctl restart tailscaled

# Check interface status
ip addr show
ip route show
```

### General Troubleshooting
- Ensure you're running as root: `sudo /root/perpetual-upgrade.sh`
- Verify DietPI is installed: `cat /boot/dietpi/.version`

### Can't write to log file
- Check permissions: `ls -la /var/log/dietpi-upgrade.log`
- Try a custom log location: `sudo /root/perpetual-upgrade.sh --log-file /tmp/upgrade.log`

### Want to watch upgrades in real-time
- Run in foreground mode: `sudo /root/perpetual-upgrade.sh --foreground`
- Then view logs in another terminal: `sudo tail -f /var/log/dietpi-upgrade.log`

### Daemon not starting
- Check if systemd is available: `command -v systemctl`
- Manually start in foreground for debugging: `sudo /root/perpetual-upgrade.sh --foreground`
- Check systemd service logs: `sudo journalctl -u dietpi-perpetual-upgrade.service -n 50`

## Exit Node Monitoring & Best Practices

### Recommended Settings for Exit Nodes

For optimal behavior on globally distributed exit nodes, use longer intervals:

```bash
# 12-hour check interval (less disruptive for 24/7 exit nodes)
sudo /root/perpetual-upgrade.sh --interval 12

# 24-hour check interval (most conservative, best for stable production)
sudo /root/perpetual-upgrade.sh --interval 24
```

### Monitoring Tail Node Health

**Watch logs in real-time:**
```bash
sudo journalctl -u dietpi-perpetual-upgrade -f
```

**Check upgrade history:**
```bash
sudo grep "SUCCESS\|ERROR\|Tailscale" /var/log/dietpi-upgrade.log
```

**Monitor Tailscale connectivity:**
```bash
# Check current status
tailscale status

# Monitor routing table
ip route | grep -i tailscale

# Check for network issues
sudo journalctl -u tailscaled -n 20
```

### Best Practices

1. **Stagger upgrades across exit nodes**: Don't run this with the same schedule on all exit nodes to avoid network disruption
2. **Monitor logs remotely**: Consider logging to a central server using rsyslog or similar
3. **Plan for brief disconnects**: Users should expect 5-30 minute disconnects during upgrade windows
4. **Test upgrades**: Run with `--dry-run` first to understand timing on your hardware
5. **Run in off-peak hours**: Consider scheduling upgrades during low-usage periods
6. **Keep exit node capacity**: Ensure sufficient resources for both exit node functionality and upgrades

### Monitoring Checklist

- [ ] Verify Tailscale connectivity every 6-12 hours
- [ ] Review upgrade logs weekly for errors or failures
- [ ] Test manual upgrade process monthly
- [ ] Monitor system resource usage during upgrades
- [ ] Document any issues in exit node management system
- [ ] Keep backup exit nodes ready in case one becomes unstable
- [ ] Monitor network throughput to ensure exit node stays healthy



### Custom Log Location
```bash
sudo /root/perpetual-upgrade.sh \
    --interval 12 \
    --log-file /var/log/custom/dietpi-upgrade.log
```

### Run Checks Every 24 Hours
```bash
sudo /root/perpetual-upgrade.sh --interval 24
```

### Frequent Checks (Every 3 Hours)
```bash
sudo /root/perpetual-upgrade.sh --interval 3
```

## Uninstallation

Use the main script with the `--uninstall` option for safe, clean removal:

### Automated Uninstall (Recommended)

```bash
# Interactive uninstall with confirmation
sudo /root/perpetual-upgrade.sh --uninstall
```

### What Gets Removed

The uninstall process cleanly removes:
- DietPI perpetual upgrade daemon process
- Main script (`/root/perpetual-upgrade.sh`)
- Systemd service file and configuration
- PID file
- Log files

### Manual Uninstall (Alternative)

If you prefer manual removal:

```bash
# Stop the daemon
sudo /root/perpetual-upgrade.sh --stop

# Disable systemd service
sudo systemctl disable dietpi-perpetual-upgrade.service
sudo rm /etc/systemd/system/dietpi-perpetual-upgrade.service

# Reload systemd
sudo systemctl daemon-reload

# Remove the script
sudo rm /root/perpetual-upgrade.sh

# Optional: Remove log file
sudo rm /var/log/dietpi-upgrade.log
```

## Technical Implementation Details

### Issue Resolution for Exit Nodes

This script was specifically designed to handle issues that occur on Orange Pi Zero 3S devices running as Tailscale exit nodes:

#### 1. dpkg Lock Handling
**Problem**: Other processes (unattended-upgrades, apt auto-fixes) could hold the dpkg lock, causing upgrades to fail silently.

**Solution**: 
- Pre-upgrade check detects if dpkg/apt is locked
- Script waits up to the full interval period for the lock to clear
- Clear error logging if lock cannot be acquired
- Prevents cascade failures from repeated retry attempts

#### 2. Tailscale Disconnection Management  
**Problem**: During system upgrades, network services restart, causing Tailscale to disconnect temporarily. Exit nodes would appear offline during this time.

**Solution**:
- Checks Tailscale connectivity status before upgrade
- Automatically verifies Tailscale reconnection after upgrade (up to 120 seconds)
- Logs detailed information about disconnection/reconnection
- Alerts if manual restart is needed

#### 3. Network Connectivity Verification
**Problem**: Exit node upgrades could fail silently if network was unavailable, and downed nodes might not be noticed immediately.

**Solution**:
- Verifies network connectivity using multi-method checks (ping, interface status)
- Tracks consecutive connectivity failures across check cycles
- Alerts when connectivity is lost for multiple iterations
- Prevents upgrade attempts when network is unavailable

#### 4. dpkg Corruption Recovery
**Problem**: Interrupted upgrades could leave dpkg in an inconsistent state.

**Solution**:
- Each upgrade includes pre-checks and post-validation
- Uses proper exit codes for failure detection
- Logs detailed information for recovery procedures

### Upgrade Timing Analysis

**Time breakdown for typical Orange Pi Zero 3S upgrade:**
- Pre-checks: ~5-10 seconds
- dpkg lock wait (if needed): variable
- Actual upgrade: 10-20 minutes
- Post-upgrade checks: 5-10 seconds
- Tailscale reconnection: 5-120 seconds

**Total potential disconnection**: 20-30 minutes under normal conditions

This means exit node users may experience temporary routing through backup nodes during this window.

### Logging Information

The script logs three types of connectivity events:

1. **Pre-upgrade**: Network/Tailscale status before upgrade starts
2. **During upgrade**: DietPI's own upgrade logging
3. **Post-upgrade**: Network recovery, Tailscale reconnection status

Check logs for:
```bash
grep "Pre-upgrade\|Post-upgrade\|connectivity\|Tailscale" /var/log/dietpi-upgrade.log
```



- Update checks are lightweight operations
- Full upgrades may take 5-30 minutes depending on the number of packages
- Updates are applied in the background without blocking other services
- Recommended check interval: 6-12 hours to balance freshness and system load

## Security Notes

- The script requires root privileges to perform upgrades
- All operations are logged for audit purposes
- Review the log file periodically to monitor upgrade success
- Keep the script file protected: `sudo chmod 600 /root/perpetual-upgrade.sh`

## License

Use freely and modify as needed for your DietPI system.
