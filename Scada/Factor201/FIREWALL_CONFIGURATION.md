# Firewall Configuration for OpenPoint SCADA IoT Edge Devices

## Overview

The `configure-firewall.sh` script provides an interactive menu to configure UFW (Uncomplicated Firewall) for IoT Edge devices running the SCADA Polling Module.

## Quick Start

```bash
# Download the script
wget https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/configure-firewall.sh
chmod +x configure-firewall.sh

# Run the script
sudo bash ./configure-firewall.sh
```

## Menu Options

### 1. Configure Basic Firewall (IoT Edge + System Updates)

Sets up essential rules for IoT Edge operation:
- Azure IoT Hub connectivity (AMQPS port 5671, HTTPS port 443)
- Container registry access (HTTPS port 443)
- DNS resolution (UDP/TCP port 53)
- System updates (HTTP port 80, HTTPS port 443)
- NTP time synchronization (UDP port 123)

**Use this when**: You want minimal firewall rules for IoT Edge without SCADA-specific rules.

### 2. Configure Full Firewall (IoT Edge + SCADA + Updates)

Includes everything from Basic Firewall plus:
- RTAC polling access (HTTP port 80, HTTPS port 443 to specific RTAC IP)

**Use this when**: Setting up a production SCADA device with a specific RTAC target.

### 3. Add RTAC Device Access

Add firewall rules for an additional RTAC device.

**Use this when**: You have multiple RTACs to poll from the same IoT Edge device.

### 4. Configure SSH Access (Management Network)

Configure SSH access for device management:
- **Option 1**: Allow from specific management network (e.g., 192.168.1.0/24) - **RECOMMENDED**
- **Option 2**: Allow from anywhere - **NOT RECOMMENDED** for production

**Use this when**: You need remote SSH access for device management.

### 5. Show Current Firewall Rules

Display all active firewall rules and configuration.

### 6. Test Connectivity

Test critical connectivity:
- DNS resolution
- NTP synchronization
- HTTPS connectivity
- Azure IoT Hub connection
- Container registry access
- RTAC connectivity

**Use this when**: Troubleshooting connectivity issues or verifying firewall configuration.

### 7. Disable Firewall

Temporarily disable the firewall.

**Use this when**: Troubleshooting connectivity issues (NOT recommended for production).

### 8. Enable Firewall

Re-enable the firewall with existing rules.

---

## Usage Examples

### First-Time Setup (Production SCADA Device)

```bash
sudo bash ./configure-firewall.sh

# Select: 2 (Configure Full Firewall)
# Enter RTAC IP: 192.168.1.100

# Select: 4 (Configure SSH Access)
# Select: 1 (Specific management network)
# Enter network: 192.168.1.0/24

# Select: 6 (Test Connectivity)
# Verify all tests pass

# Select: 0 (Exit)
```

### Add Additional RTAC Device

```bash
sudo bash ./configure-firewall.sh

# Select: 3 (Add RTAC Device Access)
# Enter RTAC IP: 192.168.1.101

# Select: 0 (Exit)
```

### Troubleshooting Connectivity

```bash
sudo bash ./configure-firewall.sh

# Select: 6 (Test Connectivity)
# Check which tests fail

# If needed, temporarily disable firewall:
# Select: 7 (Disable Firewall)
# Test connectivity manually
# Select: 8 (Enable Firewall)

# Select: 5 (Show Current Firewall Rules)
# Verify rules are correct
```

---

## Firewall Rules Reference

### Outbound Rules (Device ? Network)

| Service | Protocol | Port | Destination | Purpose |
|---------|----------|------|-------------|---------|
| DNS | UDP/TCP | 53 | DNS servers | Name resolution |
| NTP | UDP | 123 | NTP servers | Time synchronization |
| AMQPS | TCP | 5671 | *.azure-devices.net | IoT Hub (primary) |
| HTTPS | TCP | 443 | Multiple | IoT Hub (fallback), ACR, updates |
| HTTP | TCP | 80 | Multiple | System updates, RTAC |
| RTAC | TCP | 80/443 | RTAC IP | SCADA data polling |

### Inbound Rules (Network ? Device)

| Service | Protocol | Port | Source | Purpose |
|---------|----------|------|--------|---------|
| SSH | TCP | 22 | Management network | Device management |

---

## Configuration File

The script saves configuration to `/etc/openpoint/firewall-config.conf`:

```sh
# Example configuration
RTAC_IP=192.168.1.100
MGMT_NETWORK=192.168.1.0/24
```

This allows the script to remember your settings between runs.

---

## Troubleshooting

### Issue: IoT Edge can't connect to IoT Hub

```bash
# Test connectivity
sudo bash ./configure-firewall.sh
# Select: 6 (Test Connectivity)

# If Azure IoT Hub test fails:
# Check rules:
sudo bash ./configure-firewall.sh
# Select: 5 (Show Current Firewall Rules)

# Verify ports 5671 and 443 are allowed outbound
```

**Solution**: Reconfigure firewall with Option 1 or 2.

### Issue: Can't SSH to device

```bash
# Check if SSH rule exists:
sudo ufw status | grep 22

# If not found, add SSH access:
sudo bash ./configure-firewall.sh
# Select: 4 (Configure SSH Access)
```

### Issue: SCADA module can't reach RTAC

```bash
# Test RTAC connectivity
sudo bash ./configure-firewall.sh
# Select: 6 (Test Connectivity)

# If RTAC test fails:
# 1. Verify RTAC IP is correct in /etc/openpoint/firewall-config.conf
# 2. Verify RTAC device is powered on and reachable
# 3. Add/update RTAC access:
sudo bash ./configure-firewall.sh
# Select: 3 (Add RTAC Device Access)
```

### Issue: System updates failing

```bash
# Test connectivity
sudo bash ./configure-firewall.sh
# Select: 6 (Test Connectivity)

# If DNS or HTTPS tests fail:
# Reconfigure basic firewall:
sudo bash ./configure-firewall.sh
# Select: 1 (Configure Basic Firewall)
```

---

## Security Best Practices

### ? DO

- Use Option 2 (Full Firewall) for production deployments
- Restrict SSH to specific management network (Option 4 ? Option 1)
- Test connectivity after configuration (Option 6)
- Keep firewall enabled at all times
- Review rules periodically (Option 5)

### ? DON'T

- Allow SSH from anywhere (0.0.0.0/0) in production
- Disable firewall permanently
- Add overly broad rules (prefer specific IPs)
- Forget to test connectivity after changes

---

## Integration with Setup Script

The firewall script is **standalone** and does not modify `setup-iot-edge-device.sh`. It can be run:

- **Before** initial setup (recommended)
- **After** setup is complete
- **Anytime** to modify firewall rules

**Recommended workflow:**

1. Run `setup-iot-edge-device.sh` (Option 1: Full Setup)
2. Reboot device
3. Run `configure-firewall.sh` (Option 2: Full Firewall)
4. Test connectivity (Option 6)
5. Extract TPM key and complete Azure provisioning

---

## Manual UFW Commands

If you prefer manual configuration:

```bash
# Enable UFW
sudo ufw enable

# Allow DNS
sudo ufw allow out 53

# Allow AMQPS (IoT Hub)
sudo ufw allow out 5671/tcp

# Allow HTTPS
sudo ufw allow out 443/tcp

# Allow HTTP to specific RTAC
sudo ufw allow out to 192.168.1.100 port 80 proto tcp

# Allow SSH from management network
sudo ufw allow from 192.168.1.0/24 to any port 22

# Check status
sudo ufw status verbose
```

---

## Uninstalling/Resetting

```bash
# Disable firewall
sudo ufw disable

# Reset all rules
sudo ufw --force reset

# Remove configuration
sudo rm /etc/openpoint/firewall-config.conf

# Uninstall UFW (optional)
sudo apt remove ufw
```

---

## Related Documentation

- [Setup Script](README.md) - Initial device setup
- [IoT Monitor](iot-monitor.sh) - System health monitoring
- [SCADA Logs](scada-logs.sh) - Log viewer

---

**Repository:** https://github.com/OpenPointHub/OpenPoint.Public  
**Script:** `configure-firewall.sh`  
**Version:** 1.0  
**Last Updated:** January 2026
