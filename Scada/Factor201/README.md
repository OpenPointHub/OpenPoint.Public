# OpenPoint SCADA - IoT Edge Device Setup Scripts

This directory contains scripts for setting up and managing Raspberry Pi Factor 201 devices running Azure IoT Edge for SCADA data collection.

## 📁 **File Structure**

```
OpenPoint.Public/Scada/Factor201/
├── README.md                           # This documentation
├── setup-iot-edge-device.sh           # Main orchestrator script
├── modules/                            # Setup modules
│   ├── system-config.sh               # System configuration
│   ├── system-updates.sh              # Package updates
│   ├── system-optimization.sh         # Performance tuning
│   ├── container-engine.sh            # Docker/Moby setup
│   ├── iotedge-runtime.sh             # IoT Edge installation
│   └── helper-scripts.sh              # Downloads helper scripts
└── helpers/                            # Utility scripts (installed to /usr/local/bin)
    ├── get-tpm-key.sh                 # TPM key extractor
    ├── iot-monitor.sh                 # System monitor
    └── scada-logs.sh                  # Log viewer

When deployed on device:
/usr/local/share/openpoint-setup/
└── modules/                            # Cached setup modules (FHS-compliant)
    ├── system-config.sh
    ├── system-updates.sh
    ├── system-optimization.sh
    ├── container-engine.sh
    ├── iotedge-runtime.sh
    └── helper-scripts.sh

/usr/local/bin/                         # Helper scripts (in $PATH)
├── get-tpm-key.sh                     # (if TPM present)
├── iot-monitor.sh
└── scada-logs.sh
```

### **Main Scripts**

| Script | Purpose | Public URL |
|--------|---------|------------|
| `setup-iot-edge-device.sh` | Main setup script - modular version (downloads modules) | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh) |

### **Setup Modules** (in `modules/` directory)

| Module | Purpose | Can Run Standalone |
|--------|---------|-------------------|
| `system-config.sh` | Keyboard, timezone, locale, hardware detection | ✅ Yes |
| `system-updates.sh` | Package updates and service management | ✅ Yes |
| `system-optimization.sh` | Swap, TRIM, watchdog, network optimizations | ✅ Yes |
| `container-engine.sh` | Docker/Moby installation and configuration | ✅ Yes |
| `iotedge-runtime.sh` | Azure IoT Edge and TPM tools installation | ✅ Yes |
| `helper-scripts.sh` | Download monitoring and utility scripts | ✅ Yes |

### **Helper Scripts** (in `helpers/` directory)

| Script | Purpose | Public URL |
|--------|---------|------------|
| `get-tpm-key.sh` | Extracts TPM endorsement key for DPS enrollment | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/helpers/get-tpm-key.sh) |
| `iot-monitor.sh` | System health monitoring utility | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/helpers/iot-monitor.sh) |
| `scada-logs.sh` | Interactive log viewer for SCADA module | [Download](https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/helpers/scada-logs.sh) |

## 🚀 **Quick Start**

### **Full Setup (Recommended)**

```bash
# Download and run the modular setup script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh
sudo bash ./setup-iot-edge-device.sh
```

**Features:**
- Interactive menu system
- Downloads setup modules on-demand
- Caches modules locally for offline use
- Always uses latest module versions when refreshed

**Module Caching:**
- On first run, modules are downloaded and cached to `/usr/local/share/openpoint-setup/modules/`
- Subsequent runs use cached modules (works offline)
- Use option 9 to refresh cached modules with latest versions from GitHub

### **Running Individual Modules**

```bash
# Example: Run just system optimization
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/modules/system-optimization.sh
chmod +x system-optimization.sh
sudo bash ./system-optimization.sh
```

### **Running Helper Scripts Directly**

```bash
# Download and run a helper script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/helpers/iot-monitor.sh
chmod +x iot-monitor.sh
./iot-monitor.sh
```

## 📋 **Interactive Menu**

The setup script provides an interactive menu with the following options:

1. **Full Setup** - Complete installation (recommended for first-time setup)
   - Runs all steps sequentially
   - Caches modules for offline use
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

9. **Refresh Module Cache** - Update all cached setup modules
   - Clears existing module cache
   - Re-downloads all modules from GitHub
   - Gets latest versions of all setup modules

0. **Exit** - Exit the setup script

## 🔧 **Usage Examples**

### **First-Time Setup**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 1 (Full Setup)
# Wait 15-20 minutes for completion
sudo reboot
```

### **Update Helper Scripts Only**
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

### **Refresh Module Cache**
```bash
sudo bash ./setup-iot-edge-device.sh
# Choose option 9 (Refresh Module Cache)
```

## 💾 **Offline Deployment**

The setup script supports offline deployment after the first run:

### **Prepare for Offline Use:**
```bash
# 1. Download main script (requires internet)
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh

# 2. Run once to cache modules AND download helper scripts (requires internet)
sudo bash ./setup-iot-edge-device.sh
# Choose option 1 (Full Setup) to download and cache all modules + helpers
# OR run these separately:
#   - Option 9 to cache setup modules
#   - Option 7 to download helper scripts

# 3. Everything is now cached - script works offline!
```

**What Gets Cached:**
- **Setup modules** → `/usr/local/share/openpoint-setup/modules/` (6 files)
- **Helper scripts** → `/usr/local/bin/` (3 files: get-tpm-key.sh, iot-monitor.sh, scada-logs.sh)
- **Main script** → Wherever you downloaded it (e.g., `~/setup-iot-edge-device.sh`)

### **Offline Usage:**
```bash
# Script runs using cached modules (no internet needed)
sudo bash ./setup-iot-edge-device.sh

# During module loading, you'll see:
# ✓ Using cached system-config
# ✓ Using cached system-updates
# (etc...)

# Helper scripts are already installed:
iot-monitor.sh      # Works offline
scada-logs.sh       # Works offline
get-tpm-key.sh      # Works offline (if TPM present)
```

### **Verify Offline Readiness:**
```bash
# Check cached modules
ls -la /usr/local/share/openpoint-setup/modules/
# Should show: system-config.sh, system-updates.sh, etc.

# Check helper scripts
ls -la /usr/local/bin/{get-tpm-key,iot-monitor,scada-logs}.sh
# Should show all three scripts

# Check main script
ls -la ~/setup-iot-edge-device.sh
# Should show the main script
```

### **Cached Module Location:**
```
/usr/local/share/openpoint-setup/modules/  # Setup modules (sourced by main script)
├── system-config.sh
├── system-updates.sh
├── system-optimization.sh
├── container-engine.sh
├── iotedge-runtime.sh
└── helper-scripts.sh

/usr/local/bin/                            # Helper utilities (user commands)
├── get-tpm-key.sh                         # (only if TPM was detected)
├── iot-monitor.sh
└── scada-logs.sh
```

**Note:** If you run the setup script for the first time in an offline environment, it will fail to download modules. Always run it once with internet connectivity before going offline.

### **Quick Reference - What Needs Internet:**

| Action | Requires Internet? | Downloads What? |
|--------|-------------------|-----------------|
| **First run (option 1)** | ✅ Yes | All modules + helper scripts |
| **Subsequent runs** | ❌ No | Uses cached modules |
| **Option 7 (Helper Scripts)** | ✅ Yes | Re-downloads helpers to `/usr/local/bin/` |
| **Option 9 (Refresh Cache)** | ✅ Yes | Re-downloads modules to cache |
| **Running individual steps (2-6,8)** | ❌ No | Uses cached modules |

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
   # Choose option 1
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

### **Module Download Fails**
```bash
# Check internet connectivity
ping -c 3 8.8.8.8

# Try downloading manually
wget -v https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/modules/system-config.sh
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

### **Update Cached Setup Modules**
```bash
sudo bash setup-iot-edge-device.sh
# Choose option 9 (Refresh Module Cache)
```

This will re-download all setup modules to get the latest versions from GitHub.

### **Update Helper Scripts**
```bash
sudo bash setup-iot-edge-device.sh
# Choose option 7 (Helper Scripts)
```

This will re-download the helper utilities (get-tpm-key.sh, iot-monitor.sh, scada-logs.sh).

### **Update Individual Module (Advanced)**
```bash
# Example: Update system optimization module manually
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/modules/system-optimization.sh -O /usr/local/share/openpoint-setup/modules/system-optimization.sh
chmod +x /usr/local/share/openpoint-setup/modules/system-optimization.sh
```

## 📝 **Development Notes**

### **Adding New Modules**

1. Create module in `modules/` directory
2. Export color variables for consistency
3. Make functions self-contained
4. Add standalone execution capability:
   ```bash
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
       your_function
   fi
   ```

### **Testing Modules**

```bash
# Test module standalone
bash -x modules/system-config.sh

# Test module sourcing
source modules/system-config.sh
system_configuration
```

## 📄 **License**

These scripts are part of the OpenPoint SCADA system.

---

**Repository:** https://github.com/OpenPointHub/OpenPoint.Public  
**Support:** Contact OpenPoint support team
