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

### **Script Download Fails**
```bash
# Check internet connectivity
ping -c 3 8.8.8.8

# Try downloading with verbose output
wget -v https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
```

### **IoT Edge Not Starting**
```bash
sudo iotedge system status
sudo iotedge system logs
sudo iotedge check
```

### **Module Not Deploying**
```bash
scada-logs.sh  # Choose option 4 or 5 for errors
sudo iotedge list
```

## 📊 **System Requirements**

- **Device:** Raspberry Pi Factor 201 or compatible
- **RAM:** 4GB (minimum)
- **Storage:** 128GB SSD (recommended)
- **OS:** Ubuntu Server 24.04 LTS (ARM64)
- **Network:** Ethernet connection with internet access
- **Optional:** TPM 2.0 module (for secure provisioning)

## 🔄 **Updating Scripts**

### **Update Main Setup Script**
```bash
# Re-download the main script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh -O setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh
```

### **Update Helper Scripts**
```bash
sudo bash setup-iot-edge-device.sh
# Choose option 7 (Helper Scripts)
```

### **Update Individual Helper Script**
```bash
# Example: Update iot-monitor.sh
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/iot-monitor.sh -O /usr/local/bin/iot-monitor.sh
chmod +x /usr/local/bin/iot-monitor.sh
```

## 📄 **License**

These scripts are part of the OpenPoint SCADA system.

---

**Repository:** https://github.com/OpenPointHub/OpenPoint.Public  
**Support:** Contact OpenPoint support team
