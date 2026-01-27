# Quick Troubleshooting Guide

## 🚨 Script Returned to Menu During "Updating system packages..."

**Most Common Issue - Caused by Ubuntu's automatic updates**

### Quick Fix (One Command):
```bash
sudo systemctl stop unattended-upgrades && sudo systemctl disable unattended-upgrades && sudo bash ./setup-iot-edge-device.sh
```

### Or Let Script Handle It:
1. Run script again: `sudo bash ./setup-iot-edge-device.sh`
2. When asked "Would you like to disable automatic updates?", answer `y`
3. Script will handle everything automatically

---

## 🐛 Other Issues

| Symptom | Quick Fix |
|---------|-----------|
| **Too much output** | Run with quiet mode: `DEBUG_MODE=0 sudo bash ./setup-iot-edge-device.sh` |
| **Silent failure, no error** | Debug mode is on by default now! Check output above the error |
| **"dpkg lock" error** | Script now waits automatically (up to 5 min) |
| **Package install fails** | Check internet: `ping -c 3 8.8.8.8` |
| **Step X failed, continue?** | Say `y` to continue to next step |

---

## 📋 Pre-Flight Checklist

Before running setup, verify:

```bash
# 1. Internet connectivity
ping -c 3 packages.microsoft.com

# 2. No package manager running
ps aux | grep apt

# 3. Enough disk space (need ~5GB)
df -h /

# 4. Running as root
sudo whoami  # Should say "root"
```

---

## 🎯 Recommended Setup Process

### First Time Setup:
```bash
# 1. Disable automatic updates (prevents issues)
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer

# 2. Download script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/setup-iot-edge-device.sh
chmod +x setup-iot-edge-device.sh

# 3. Run full setup
sudo bash ./setup-iot-edge-device.sh
# Choose option 1

# 4. Reboot after completion
sudo reboot
```

### If Something Goes Wrong:
```bash
# Run individual steps instead of full setup
sudo bash ./setup-iot-edge-device.sh
# Choose option 2, then 3, then 4, etc.
```

---

## 📞 Need Help?

Collect diagnostic info:
```bash
DEBUG_MODE=1 sudo bash ./setup-iot-edge-device.sh 2>&1 | tee setup-log.txt
```

Send `setup-log.txt` to support with description of issue.
