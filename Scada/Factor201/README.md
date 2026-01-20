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

## 📋 **Interactive Menu**

The setup script provides an interactive menu with the following options:

1. **Full Setup** - Complete installation (recommended for first-time setup)
   - Runs all steps sequentially
   - Downloads helper scripts
   - Takes 15-20 minutes

2. **System Configuration** - Keyboard/timezone/locale/hardware detection
   - Sets keyboard layout to US
   - Sets timezone to UTC
   - Configures locale to en_US.UTF-8
   - Detects RAM, disk, and architecture

3. **System Updates** - Package updates and service management
   - Updates all system packages
   - Installs essential tools (curl, wget, git, etc.)
   - Disables unnecessary services (Bluetooth, ModemManager, CUPS, cloud-init)

4. **System Optimization** - Performance tuning
   - Optimizes swap settings for 4GB RAM
   - Enables SSD TRIM
   - Enables hardware watchdog
   - Increases file descriptor limits
   - Applies network optimizations

5. **Container Engine** - Docker/Moby installation and configuration
   - Installs Moby container engine
   - Configures logging driver for IoT Edge
   - Sets storage driver to overlay2

6. **IoT Edge Runtime** - Azure IoT Edge and TPM tools
   - Installs Azure IoT Edge runtime
   - Installs Microsoft Defender for IoT
   - Installs TPM 2.0 tools
   - Detects TPM hardware

7. **Helper Scripts** - Download monitoring and log viewer utilities
   - Downloads get-tpm-key.sh (if TPM present)
   - Downloads iot-monitor.sh
   - Downloads scada-logs.sh

8. **Clean Duplicate Config** - Maintenance utility
   - Removes duplicate entries from /etc/sysctl.conf
   - Removes duplicate entries from /etc/security/limits.conf
   - Safe to run multiple times

0. **Exit** - Exit the setup script

## 🔧 **Usage Examples**

### **First-Time Setup**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 1 (Full Setup)
# Wait 15-20 minutes for completion
sudo reboot
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

## 💾 **Offline Usage**

The main setup script works offline for all options **except option 7** (Helper Scripts download):

**What Works Offline:**
- ✅ Main setup script (already downloaded)
- ✅ All menu options 1-6, 8 (embedded in main script)
- ✅ Helper scripts (once downloaded via option 7)

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

# 3. Main script and helper scripts are now available offline
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

## 🎯 **Deployment Workflow**

1. **Physical Setup**
   - Install Ubuntu Server on SSD
   - Connect network, keyboard (optional)
   - Boot device

2. **Run Setup Script**
   ```bash
   wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
   chmod +x setup-iot-edge-device.sh
   sudo bash ./setup-iot-edge-device.sh
   # Choose option 1 (Full Setup)
   ```

3. **Reboot**
   ```bash
   sudo reboot
   ```

4. **Extract TPM Key**
   ```bash
   get-tpm-key.sh
   # Send output to Azure administrator
   ```

5. **Azure Provisioning** (Azure Administrator)
   - Create DPS Individual Enrollment with TPM key
   - Assign to IoT Hub
   - Deploy SCADA module

6. **Configure IoT Edge**
   ```bash
   sudo iotedge config dps --scope-id YOUR_SCOPE_ID --registration-id YOUR_REG_ID
   sudo iotedge config apply
   ```

7. **Verify Deployment**
   ```bash
   sudo iotedge check
   iot-monitor.sh
   ```

## 🐛 **Troubleshooting**

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
```

### Common Errors

**"dpkg lock" or "Unable to acquire lock"**

Another package manager is running. Wait for it to finish or kill it:
```bash
# Check what's using apt
ps aux | grep apt

# Wait for automatic updates to finish
sudo systemctl stop apt-daily.timer
sudo systemctl stop apt-daily-upgrade.timer

# Run script again
sudo bash ./setup-iot-edge-device.sh
```

**"Network unreachable" during package install**

Check internet connectivity:
```bash
ping -c 3 8.8.8.8
ping -c 3 packages.microsoft.com

# Check DNS
cat /etc/resolv.conf
```

**Script fails at Step 2 (System Updates)**

The package repository might be updating. Try again in 5 minutes, or run in debug mode to see the specific error.

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

# 3. Send both files to support
```
