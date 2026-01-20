# OpenPoint SCADA - IoT Edge Device Setup Scripts

This directory contains scripts for setting up and managing Raspberry Pi Factor 201 devices running Azure IoT Edge for SCADA data collection.

## 📁 **File Structure**

```
OpenPoint.Public/Scada/Factor201/
├── README.md                    # This documentation
├── setup-iot-edge-device.sh    # Main setup script (all-in-one)
├── get-tpm-key.sh              # TPM key extractor
├── iot-monitor.sh              # System monitor
└── scada-logs.sh               # Log viewer

When deployed on device:
/usr/local/bin/                  # Helper scripts (in $PATH)
├── get-tpm-key.sh              # (only if TPM detected)
├── iot-monitor.sh
└── scada-logs.sh
```

## 📄 **Scripts**

| Script | Purpose | Public URL |
|--------|---------|------------|
| `setup-iot-edge-device.sh` | Main setup script (all-in-one, downloads helper scripts) | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh) |
| `get-tpm-key.sh` | Extracts TPM endorsement key for DPS enrollment | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/get-tpm-key.sh) |
| `iot-monitor.sh` | System health monitoring utility | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/iot-monitor.sh) |
| `scada-logs.sh` | Interactive log viewer for SCADA module | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/scada-logs.sh) |

## 🚀 **Quick Start**

```bash
# Download and run the setup script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh
sudo bash ./setup-iot-edge-device.sh
```

**Features:**
- Interactive menu system
- All setup functions embedded in one script
- Downloads helper utilities to `/usr/local/bin/`
- Works offline after helper scripts are downloaded
- **Automatically handles Ubuntu's automatic updates**
- **Configurable update policy** for production deployments
- **Debug mode enabled by default** - see all command output for transparency
- **Intelligent error handling** - waits for package manager, offers solutions

**⚠️ Common Issue:** If script returns to menu during "Updating system packages...", it's likely Ubuntu's automatic updates running in background. The script will automatically detect this, wait up to 5 minutes, and offer to disable automatic updates. See [Quick Troubleshooting Guide](QUICK_TROUBLESHOOTING.md) for details.

**💡 Tip:** To reduce verbosity, run with `DEBUG_MODE=0 sudo bash ./setup-iot-edge-device.sh`

## 📋 **Interactive Menu**

The setup script provides an interactive menu with the following options:

1. **Full Setup** - Complete installation (recommended for first-time setup)
   - Runs all steps sequentially
   - Downloads helper scripts
   - Takes 15-20 minutes
   - Prompts to continue on errors (optional skip)

2. **System Configuration** - Keyboard/timezone/locale/hardware detection
   - Sets keyboard layout to US
   - Sets timezone to UTC
   - Configures locale to en_US.UTF-8
   - Detects RAM, disk, and architecture
   - Warns if hardware doesn't match expected specs

3. **System Updates** - Package updates and service management
   - Updates all system packages
   - Installs essential tools (curl, wget, git, smartmontools, htop, iotop, iftop, etc.)
   - Disables unnecessary services (Bluetooth, ModemManager, CUPS, cloud-init)
   - **Automatically waits** if package manager is busy
   - **Handles unattended-upgrades** gracefully

4. **System Optimization** - Performance tuning
   - Optimizes swap settings for 4GB RAM (swappiness=10, vfs_cache_pressure=50)
   - Enables SSD TRIM (weekly schedule)
   - Enables hardware watchdog (bcm2835_wdt, 15s timeout)
   - Increases file descriptor limits (65535)
   - Applies network optimizations (TCP buffers, keepalive settings)

5. **Container Engine** - Docker/Moby installation and configuration
   - Installs Moby container engine from Microsoft repository
   - Configures logging driver (`local`, 10MB max, 3 files)
   - Sets storage driver to `overlay2`
   - Configures file descriptor ulimits
   - **Verifies installation** before proceeding

6. **IoT Edge Runtime** - Azure IoT Edge and TPM tools
   - Installs Azure IoT Edge runtime (`aziot-edge`)
   - Installs TPM 2.0 tools (`tpm2-tools`)
   - Detects TPM hardware automatically
   - **Verifies installation** and shows version
   - **Note:** Microsoft Defender for IoT micro agent (retired August 2025) is no longer installed

7. **Helper Scripts** - Download monitoring and log viewer utilities
   - Downloads `get-tpm-key.sh` (if TPM present)
   - Downloads `iot-monitor.sh` (system monitoring)
   - Downloads `scada-logs.sh` (log viewer)
   - Installs to `/usr/local/bin/` (in PATH)
   - **Verifies downloads** before marking complete

8. **Clean Duplicate Config** - Maintenance utility
   - Removes duplicate entries from `/etc/sysctl.conf`
   - Removes duplicate entries from `/etc/security/limits.conf`
   - Safe to run multiple times
   - Useful after running setup script multiple times

9. **Configure Update Policy** ⭐ NEW
   - **Security-only automatic** (recommended for production)
     - Auto-installs critical security patches at 3 AM daily
     - Feature updates require manual approval
     - Never auto-reboots (operator must reboot manually)
     - Optional email notifications
   - **Manual updates only** (maximum control)
     - All updates require manual trigger
     - Update via `sudo apt update && sudo apt upgrade`
     - Or trigger remotely via IoT Hub (requires implementation)
   - **Disable all automatic updates** (for testing only)
     - Completely disables automatic updates
     - NOT recommended for production
   - **Show current policy**
     - Check update configuration
     - Show pending updates
     - Check reboot requirements

0. **Exit** - Exit the setup script

## 🔧 **Usage Examples**

### **First-Time Setup**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 1 (Full Setup)
# Wait 15-20 minutes for completion
sudo reboot
```

### **Configure Update Policy (Production)**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 (Configure Update Policy)
# Choose option 1 (Security-only automatic)
# Recommended for remote substations
```

### **Update Helper Scripts**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 7 (Helper Scripts)
```

### **Re-run System Optimization**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 4 (System Optimization)
```

### **Fix Duplicate Config Entries**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 8 (Clean Duplicates)
```

### **Check for System Updates**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 (Configure Update Policy)
# Choose option 4 (Show current policy)
```

## 💾 **Offline Usage**

The main setup script works offline for all options **except option 7** (Helper Scripts download):

**What Works Offline:**
- ✅ Main setup script (already downloaded)
- ✅ All menu options 1-6, 8-9 (embedded in main script)
- ✅ Helper scripts (once downloaded via option 7)
- ✅ Configure update policy (option 9)

**What Needs Internet:**
- ❌ Downloading the main script initially
- ❌ Option 7 - Downloading/updating helper scripts
- ❌ Package updates (option 3)
- ❌ Installing Docker, IoT Edge (options 5, 6)

**Prepare for Field Deployment:**
```bash
# 1. Download main script (requires internet)
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh

# 2. Run full setup to download helper scripts (requires internet)
sudo bash ./setup-iot-edge-device.sh
# Choose option 1 (Full Setup)

# 3. Configure update policy (works offline)
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 → option 1 (Security-only automatic)

# 4. Main script and helper scripts are now available offline
```

**Verify Downloaded Scripts:**
```bash
# Check main script
ls -la ~/setup-iot-edge-device.sh

# Check helper scripts
ls -la /usr/local/bin/{get-tpm-key,iot-monitor,scada-logs}.sh
```

## 📖 **After Setup**

Once setup is complete, use these commands:

```bash
# Reboot to apply all changes
sudo reboot

# Extract TPM key (send to Azure administrator)
get-tpm-key.sh

# Monitor system health
iot-monitor.sh

# View SCADA module logs
scada-logs.sh
```

## 🔄 **Update Management**

### **Recommended Update Policy for Production**

For devices deployed at remote substations:

```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 (Configure Update Policy)
# Choose option 1 (Security-only automatic)
```

**This configures:**
- ✅ Critical security patches installed automatically at 3 AM daily
- ✅ Feature updates require manual approval
- ✅ Never auto-reboots (prevents data loss)
- ✅ Logs all updates to `/var/log/unattended-upgrades/`

**Check for updates requiring reboot:**
```bash
cat /var/run/reboot-required.pkgs
```

**Manually apply feature updates:**
```bash
sudo apt update && sudo apt upgrade -y
```

**Or use setup script:**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 3 (System Updates)
```

### **Update Schedule Best Practices**

**For production substations:**
```
Daily (automatic):    Security patches only (3 AM)
Monthly (manual):     Feature updates during maintenance window
Quarterly (manual):   Full system upgrade + reboot (scheduled downtime)
```

**Check update status:**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 → option 4 (Show current policy)
```

## 🎯 **Deployment Workflow**

1. **Physical Setup**
   - Install Ubuntu Server 24.04 LTS on SSD
   - Connect network, keyboard (optional)
   - Boot device

2. **Run Setup Script**
   ```bash
   wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
   chmod +x setup-iot-edge-device.sh
   sudo bash ./setup-iot-edge-device.sh
   # Choose option 1 (Full Setup)
   ```

3. **Configure Update Policy**
   ```bash
   sudo bash ./setup-iot-edge-device.sh
   # Choose option 9 → option 1 (Security-only automatic)
   ```

4. **Reboot**
   ```bash
   sudo reboot
   ```

5. **Extract TPM Key**
   ```bash
   get-tpm-key.sh
   # Send output to Azure administrator
   ```

6. **Azure Provisioning** (Azure Administrator)
   - Create DPS Individual Enrollment with TPM key
   - Assign to IoT Hub
   - Deploy SCADA module

7. **Configure IoT Edge**
   ```bash
   sudo iotedge config dps --scope-id YOUR_SCOPE_ID --registration-id YOUR_REG_ID
   sudo iotedge config apply
   ```

8. **Verify Deployment**
   ```bash
   sudo iotedge check
   iot-monitor.sh
   ```

## 🐛 **Troubleshooting**

### Script Returns to Menu Unexpectedly (Most Common Issue)

**Symptoms:**
- Script was running "Updating system packages..." then suddenly returned to menu
- No error message shown
- Happens during Step 2 or Step 3

**Cause:** Ubuntu's automatic updates (unattended-upgrades) started running in the background and locked the package manager.

**Solution 1: Let Script Handle It (Recommended) ⭐**

The script now:
1. ✅ **Detects** when package manager is locked
2. ✅ **Waits up to 5 minutes** for it to finish
3. ✅ **Shows progress** every 30 seconds
4. ✅ **Offers to disable** automatic updates permanently

Just run the script again:
```bash
sudo bash ./setup-iot-edge-device.sh
```

When prompted "Would you like to disable automatic updates now?", answer **Y**es.

**Solution 2: Configure Update Policy After Setup**

Once setup completes, configure a proper update policy:
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 (Configure Update Policy)
# Choose option 1 (Security-only automatic)
```

This gives you automatic security patches without the disruption of Ubuntu's default automatic updates.

**Solution 3: Manually Disable Automatic Updates First**

For immediate control:
```bash
# Stop current automatic updates
sudo systemctl stop unattended-upgrades
sudo systemctl stop apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer

# Disable permanently
sudo systemctl disable unattended-upgrades
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer

# Kill any remaining apt processes
sudo killall apt apt-get 2>/dev/null || true

# Wait 10 seconds, then run setup
sleep 10
sudo bash ./setup-iot-edge-device.sh
```

**Why Configure Update Policy for IoT Edge?**
- ✅ Prevents package conflicts during module updates
- ✅ Avoids unexpected reboots that disrupt data collection
- ✅ You control when updates happen (security vs feature)
- ✅ Automatic security patches keep device secure

### Script Stops Unexpectedly

**Symptoms:**
- Script returns to menu without completing a step
- No error message shown
- Silent failure during package updates

**Solution 1: Run in Debug Mode**
```bash
# Enable verbose output to see what's failing
DEBUG_MODE=1 sudo bash ./setup-iot-edge-device.sh
```

This will show all command output including errors that are normally hidden.

**Solution 2: Run Steps Individually**
```bash
# Instead of "Full Setup", run each step separately
sudo bash ./setup-iot-edge-device.sh
# Choose option 2 (System Configuration)
# If it works, continue to option 3, etc.
```

**Solution 3: Check System Logs**
```bash
# Check for system errors
sudo journalctl -xe

# Check for package manager locks
sudo lsof /var/lib/dpkg/lock-frontend
sudo lsof /var/lib/apt/lists/lock

# Check automatic update status
systemctl status unattended-upgrades
```

### Common Errors

**"dpkg lock" or "Unable to acquire lock"**

The script now handles this automatically by waiting up to 5 minutes. If it still fails:
```bash
# Check what's using apt
ps aux | grep apt

# Force stop (use with caution)
sudo systemctl stop unattended-upgrades
sudo killall apt apt-get dpkg
```

**"Network unreachable" during package install**

Check internet connectivity:
```bash
ping -c 3 8.8.8.8
ping -c 3 packages.microsoft.com

# Check DNS
cat /etc/resolv.conf

# Check network interface
ip addr show
```

**Script fails at Step 2 (System Updates)**

Most likely unattended-upgrades. The script now handles this automatically with a 5-minute wait period.

**"Failed to install moby-engine"**

Check Microsoft repository:
```bash
apt-cache policy moby-engine
cat /tmp/docker-install.log
```

**"IoT Edge command not found after installation"**

Verify installation:
```bash
apt-cache policy aziot-edge
cat /tmp/iotedge-install.log
```

### Getting Help

If the script fails, collect this information:

```bash
# 1. Run in debug mode and save output
DEBUG_MODE=1 sudo bash ./setup-iot-edge-device.sh 2>&1 | tee setup-debug.log

# 2. System information
uname -a > system-info.txt
lsb_release -a >> system-info.txt
free -h >> system-info.txt
df -h >> system-info.txt

# 3. Check for automatic updates
systemctl status unattended-upgrades >> system-info.txt
systemctl status apt-daily.timer >> system-info.txt

# 4. Check update policy
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 → option 4 (Show current policy)
# Take screenshot

# 5. Send files to support
```

## 🆕 **What's New**

### **Version 2.0 (Current)**

**Major Features:**
- ✅ **Option 9: Configure Update Policy** - Control automatic updates
  - Security-only automatic updates (recommended)
  - Manual updates only
  - Disable all automatic updates (for testing)
  - Show current policy and pending updates
- ✅ **Intelligent package manager handling** - Waits up to 5 minutes for locks
- ✅ **Improved error handling** - Shows exit codes and helpful messages
- ✅ **Better logging** - All installation logs saved to `/tmp/`
- ✅ **Verification steps** - Confirms Docker and IoT Edge work after install

**Improvements:**
- 🔧 Removed Defender for IoT micro agent (retired August 2025)
- 🔧 Enhanced error messages with actionable solutions
- 🔧 Progress indicators during long waits
- 🔧 Option to continue on non-critical failures
- 🔧 Better detection of hardware (RAM warnings if <3.5GB)

### **Version 1.0**

**Initial Release:**
- Interactive menu system
- Full setup automation
- Helper script downloads
- Debug mode support

## 📄 **License**

These scripts are part of the OpenPoint SCADA system.

---

## 📚 **Additional Documentation**

- [Quick Troubleshooting Guide](QUICK_TROUBLESHOOTING.md) - Fast solutions for common issues
- [Error Handling Improvements](ERROR_HANDLING_IMPROVEMENTS.md) - Comprehensive error handling details
- [Defender for IoT Deprecation](DEFENDER_DEPRECATION.md) - Why Defender micro agent was removed (Aug 2025)
- [Cache-Busting Guide](CACHE_BUSTING.md) - Ensuring fresh script downloads
- [Network Configuration](NETWORK_CONFIGURATION.md) - Container networking for RTAC connectivity

---

**Repository:** https://github.com/OpenPointHub/OpenPoint.Public  
**Support:** Contact OpenPoint support team  
**Version:** 2.0  
**Last Updated:** January 2026
