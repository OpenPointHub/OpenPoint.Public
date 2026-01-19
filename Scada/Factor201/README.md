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

Both setup scripts provide an interactive menu:

1. **Full Setup** - Complete installation (runs all steps)
2. **System Configuration** - Keyboard/timezone/locale
3. **System Updates** - Package updates
4. **System Optimization** - Performance tuning
5. **Container Engine** - Docker/Moby
6. **IoT Edge Runtime** - Azure IoT Edge
7. **Helper Scripts** - Monitoring tools
8. **Clean Duplicates** - Maintenance utility

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

### **Update All Helper Scripts**
```bash
sudo bash setup-iot-edge-device.sh
# Choose option 7
```

### **Update Individual Module**
```bash
# Example: Update system optimization module
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/modules/system-optimization.sh -O /tmp/system-optimization.sh
chmod +x /tmp/system-optimization.sh
sudo bash /tmp/system-optimization.sh
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
