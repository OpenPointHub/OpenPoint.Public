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
