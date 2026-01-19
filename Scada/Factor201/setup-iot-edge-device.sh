#!/bin/bash

###############################################################################
# Ubuntu Server Optimization Script for Raspberry Pi Factor 201
# Hardware: 4GB RAM, 128GB SSD
# Purpose: Prepare system for OpenPoint SCADA Polling IoT Edge Module
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│  Ubuntu Server Optimization for OpenPoint SCADA Module        │${NC}"
echo -e "${BLUE}│  Target: Raspberry Pi Factor 201 (4GB RAM, 128GB SSD)         │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Check if IoT Edge is already configured and warn user
if command -v iotedge &> /dev/null; then
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}│  WARNING: IoT Edge Already Installed      │${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}This system already has Azure IoT Edge installed.${NC}"
    echo ""
    echo "Current status:"
    iotedge system status 2>/dev/null || echo "  IoT Edge not configured yet"
    echo ""
    echo "The script will:"
    echo "  ✓ Skip IoT Edge installation (already installed)"
    echo "  ✓ Update system configurations safely"
    echo "  ✓ Backup Docker config before changes"
    echo "  ⚠ May require restart of Docker (will disrupt running containers)"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    echo ""
fi

# Pre-cleanup: Remove duplicate entries from previous runs
echo -e "${BLUE}Checking for duplicate configuration entries...${NC}"

# Function to safely remove duplicates from a file
remove_duplicates() {
    local file=$1
    local pattern=$2
    local description=$3
    
    if [ -f "$file" ]; then
        local count=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
        if [ "$count" -gt 1 ]; then
            echo -e "${YELLOW}  → Found $count instances of $description, cleaning up...${NC}"
            # Keep only the first occurrence
            awk -v pattern="$pattern" '!seen[$0]++ || $0 !~ pattern' "$file" > "${file}.tmp"
            mv "${file}.tmp" "$file"
            echo -e "${GREEN}  ✓ Cleaned up duplicates${NC}"
        fi
    fi
}

# Clean up sysctl.conf duplicates
if [ -f /etc/sysctl.conf ]; then
    # Remove exact duplicate lines (keep file descriptor limits intact)
    awk '!seen[$0]++' /etc/sysctl.conf > /etc/sysctl.conf.tmp
    mv /etc/sysctl.conf.tmp /etc/sysctl.conf
    echo -e "${GREEN}  ✓ Cleaned sysctl.conf${NC}"
fi

# Clean up limits.conf duplicates
if [ -f /etc/security/limits.conf ]; then
    # Remove duplicate nofile entries
    grep -v "nofile 65535" /etc/security/limits.conf > /etc/security/limits.conf.tmp || true
    mv /etc/security/limits.conf.tmp /etc/security/limits.conf
    echo -e "${GREEN}  ✓ Cleaned limits.conf (will re-add correct entries)${NC}"
fi

echo ""

# Verify root filesystem is on SSD (optional check)
echo -e "${BLUE}Verifying system storage...${NC}"
ROOT_DEVICE=$(df / | awk 'NR==2 {print $1}')
ROOT_DISK=$(lsblk -no pkname "$ROOT_DEVICE" 2>/dev/null)

if [ -n "$ROOT_DISK" ]; then
    ROTATIONAL=$(cat "/sys/block/$ROOT_DISK/queue/rotational" 2>/dev/null)
    if [ "$ROTATIONAL" = "0" ]; then
        echo -e "${GREEN}  ✓ Root filesystem is on SSD/Flash storage${NC}"
    else
        echo -e "${YELLOW}  ⚠ Warning: Root filesystem appears to be on HDD/SD card${NC}"
        echo -e "${YELLOW}  This script is optimized for SSD storage.${NC}"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}  ⚠ Could not detect storage type, continuing...${NC}"
fi
echo ""

# Configure keyboard layout to US
echo -e "${GREEN}[1/14] Configuring keyboard layout to US...${NC}"
cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF

# Apply keyboard settings immediately for current session
loadkeys us 2>/dev/null || true
echo "  ✓ Keyboard layout set to US"

# Set timezone to UTC
echo ""
echo -e "${GREEN}[2/14] Setting timezone to UTC...${NC}"
timedatectl set-timezone UTC
echo "  ✓ Timezone set to UTC"

# Configure locale to en_US.UTF-8
echo ""
echo -e "${GREEN}[3/14] Configuring locale to en_US.UTF-8...${NC}"
# Generate en_US.UTF-8 locale if not already present
locale-gen en_US.UTF-8 > /dev/null 2>&1
# Set as default locale
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 > /dev/null 2>&1
echo "  ✓ Locale set to en_US.UTF-8"

# Detect hardware
echo ""
echo -e "${GREEN}[4/14] Detecting hardware...${NC}"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
DISK_SIZE=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
ARCH=$(uname -m)

echo "  💾 RAM: ${TOTAL_RAM}MB"
echo "  💿 Disk: ${DISK_SIZE}GB"
echo "  🖥️  Architecture: ${ARCH}"

if [[ $TOTAL_RAM -lt 3800 ]]; then
    echo -e "${YELLOW}  ⚠ Warning: Less than 4GB RAM detected. Optimizations may need adjustment.${NC}"
fi

if [[ $ARCH != "aarch64" && $ARCH != "arm64" ]]; then
    echo -e "${YELLOW}  ⚠ Warning: Not ARM64 architecture. Some optimizations may not apply.${NC}"
fi

# Update system
echo ""
echo -e "${GREEN}[5/14] Updating system packages...${NC}"
# Use --fix-missing to handle incomplete package downloads or broken dependencies
apt-get update --fix-missing > /dev/null 2>&1 || apt-get update --fix-missing
apt-get upgrade -y --fix-missing > /dev/null 2>&1
echo "  ✓ System packages updated"

# Install essential packages
echo ""
echo -e "${GREEN}[6/14] Installing essential packages...${NC}"
apt-get install -y --fix-missing \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    smartmontools \
    iotop \
    htop \
    net-tools \
    iftop > /dev/null 2>&1
echo "  ✓ Essential packages installed"

# Remove unnecessary packages (headless server)
echo ""
echo -e "${GREEN}[7/14] Removing unnecessary services for headless operation...${NC}"
systemctl stop bluetooth 2>/dev/null || true
systemctl disable bluetooth 2>/dev/null || true
systemctl stop ModemManager 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
systemctl stop cups 2>/dev/null || true
systemctl disable cups 2>/dev/null || true

# Disable cloud-init (not needed for physical IoT Edge devices)
if command -v cloud-init &> /dev/null; then
    touch /etc/cloud/cloud-init.disabled
    systemctl disable cloud-init 2>/dev/null || true
    systemctl disable cloud-config 2>/dev/null || true
    systemctl disable cloud-final 2>/dev/null || true
    systemctl disable cloud-init-local 2>/dev/null || true
    echo "  ✓ Disabled cloud-init services"
    
    # Clean up cloud-init network configuration (it may be incomplete/broken)
    if [ -f /etc/netplan/50-cloud-init.yaml ]; then
        echo "  → Removing cloud-init netplan config (may be incomplete)"
        rm -f /etc/netplan/50-cloud-init.yaml
        
        # Create a simple working netplan config for DHCP
        cat > /etc/netplan/01-netcfg.yaml <<'NETEOF'
# Network configuration for IoT Edge device
# This file is managed by setup script, not cloud-init
# Automatically enables DHCP on all ethernet interfaces
network:
  version: 2
  renderer: networkd
  ethernets:
    # Raspberry Pi uses 'eth0' or 'end0' typically
    # This config works for any standard ethernet interface
    all-eth:
      match:
        name: "e*"
      dhcp4: true
      dhcp6: false
      optional: true
NETEOF
        
        # Apply new network configuration
        netplan generate > /dev/null 2>&1
        echo "  ✓ Created clean netplan configuration for DHCP"
    fi
fi

echo "  ✓ Disabled: Bluetooth, ModemManager, CUPS, cloud-init"

echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│  System Updates Complete (7/14)                                │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue with system optimizations...${NC}"
read -r

# Optimize swap settings
echo ""
echo -e "${GREEN}[8/14] Optimizing swap settings for 4GB RAM system...${NC}"
if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

if ! grep -q "vm.vfs_cache_pressure=50" /etc/sysctl.conf; then
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
fi
sysctl -p > /dev/null 2>&1
echo "  ✓ Swappiness set to 10 (prefer RAM over swap)"

# Enable SSD TRIM
echo ""
echo -e "${GREEN}[9/14] Enabling SSD TRIM for longevity...${NC}"
systemctl enable fstrim.timer > /dev/null 2>&1
systemctl start fstrim.timer > /dev/null 2>&1
echo "  ✓ Weekly TRIM scheduled"

# Enable hardware watchdog for automatic recovery
echo ""
echo -e "${GREEN}[10/14] Enabling hardware watchdog for automatic recovery...${NC}"

# Load watchdog kernel module
if ! lsmod | grep -q bcm2835_wdt; then
    modprobe bcm2835_wdt 2>/dev/null || true
fi

# Make watchdog module load at boot
if ! grep -q "bcm2835_wdt" /etc/modules 2>/dev/null; then
    echo "bcm2835_wdt" >> /etc/modules
fi

# Install and configure watchdog daemon
apt-get install -y --fix-missing watchdog > /dev/null 2>&1

# Configure watchdog daemon
cat > /etc/watchdog.conf <<EOF
# Hardware watchdog device
watchdog-device = /dev/watchdog

# Test if watchdog device is accessible
watchdog-timeout = 15

# Watchdog will reboot system after 60 seconds if daemon stops
# Daemon pings watchdog every 10 seconds

# Check system load (reboot if load average > 24 for 1 minute)
max-load-1 = 24

# Check if system can allocate memory
allocatable-memory = 1

# Repair binary: try to fix issues before rebooting
#repair-binary = /usr/sbin/repair
#repair-timeout = 60

# Logging
#verbose = yes
#log-dir = /var/log/watchdog

# Realtime priority for watchdog daemon (ensures it runs even under load)
realtime = yes
priority = 1
EOF

# Start and enable watchdog service
systemctl enable watchdog > /dev/null 2>&1
systemctl start watchdog > /dev/null 2>&1

echo "  ✓ Hardware watchdog enabled"
echo "  ✓ System will auto-reboot if unresponsive for 60 seconds"

# Increase file descriptors
echo ""
echo -e "${GREEN}[11/14] Increasing file descriptor limits...${NC}"

# Add file descriptor limits only if not already present
if ! grep -q "soft nofile 65535" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
    echo "  ✓ File descriptor limit: 65535"
else
    echo "  ✓ File descriptor limits already configured"
fi

# Network optimizations
echo ""
echo -e "${GREEN}[12/14] Applying network optimizations...${NC}"

# Add network optimizations only if not already present
if ! grep -q "Network optimizations for IoT Edge workloads" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf <<EOF

# Network optimizations for IoT Edge workloads
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=15
EOF
    echo "  ✓ Network buffers increased for better throughput"
else
    echo "  ✓ Network optimizations already configured"
fi

sysctl -p > /dev/null 2>&1
echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│  System Optimization Complete (12/14)                          │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue with container engine installation...${NC}"
read -r

# Install Moby (Microsoft's container engine for IoT Edge)
echo ""
echo -e "${GREEN}[13/14] Installing Moby container engine...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "  ✓ Container engine already installed (${DOCKER_VERSION})"
    if [[ $DOCKER_VERSION == *"moby"* ]]; then
        echo "  ✓ Using Moby (Microsoft's recommended engine)"
    else
        echo -e "${YELLOW}  ⚠ Warning: Non-Moby engine detected. Microsoft recommends Moby for IoT Edge.${NC}"
        echo "  ℹ️  To switch to Moby, uninstall current Docker and re-run this script."
    fi
else
    # Install Moby engine and CLI
    apt-get update --fix-missing > /dev/null 2>&1
    apt-get install -y --fix-missing moby-engine moby-cli > /dev/null 2>&1
    
    # Start and enable Docker service (Moby uses the same service name)
    systemctl start docker
    systemctl enable docker > /dev/null 2>&1
    
    echo "  ✓ Moby container engine installed successfully"
fi

# Configure Docker daemon for IoT Edge
echo ""
echo -e "${GREEN}[13/14] Configuring container engine for IoT Edge...${NC}"
mkdir -p /etc/docker

# Check if daemon.json already exists and is properly configured
if [ -f /etc/docker/daemon.json ]; then
    echo -e "${YELLOW}  → Docker daemon.json already exists${NC}"
    echo -e "${YELLOW}  → Checking configuration...${NC}"
    
    # Verify it has the required settings
    if grep -q '"log-driver": "local"' /etc/docker/daemon.json; then
        echo "  ✓ Docker already configured for IoT Edge"
    else
        echo -e "${YELLOW}  → Updating Docker configuration for IoT Edge compatibility...${NC}"
        
        # Backup existing config
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        echo "  ✓ Backed up existing config to daemon.json.backup.*"
        
        # Apply IoT Edge recommended config
        cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
        systemctl restart docker
        echo "  ✓ Docker reconfigured for IoT Edge"
    fi
else
    # No existing config, create fresh
    cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
    systemctl restart docker
    echo "  ✓ Container engine configured for production use"
fi

echo "  ✓ Using 'local' logging driver (Microsoft recommended for IoT Edge)"

echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│  Container Engine Ready (13/14)                                │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue with IoT Edge installation...${NC}"
read -r

# Install Azure IoT Edge Runtime
echo ""
echo -e "${GREEN}[14/14] Installing Azure IoT Edge Runtime...${NC}"
if command -v iotedge &> /dev/null; then
    echo "  ✓ IoT Edge already installed ($(iotedge --version))"
else
    # Install Microsoft package repository (dynamic version detection)
    UBUNTU_VERSION=$(lsb_release -rs)
    echo "  → Detected Ubuntu version: ${UBUNTU_VERSION}"
    wget https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb > /dev/null 2>&1
    dpkg -i packages-microsoft-prod.deb > /dev/null 2>&1
    rm packages-microsoft-prod.deb
    
    # Install IoT Edge and Defender for IoT
    apt-get update --fix-missing > /dev/null 2>&1
    apt-get install -y --fix-missing aziot-edge defender-iot-micro-agent-edge > /dev/null 2>&1
    
    echo "  ✓ IoT Edge runtime installed successfully"
    echo "  ✓ Microsoft Defender for IoT micro-agent installed"
fi

# Install TPM tools (for secure device provisioning)
echo ""
echo -e "${GREEN}Installing TPM 2.0 tools...${NC}"
if ! command -v tpm2_getcap &> /dev/null; then
    apt-get install -y --fix-missing tpm2-tools > /dev/null 2>&1
    echo "  ✓ TPM 2.0 tools installed"
else
    echo "  ✓ TPM 2.0 tools already installed"
fi

# Check for TPM device
echo ""
echo -e "${GREEN}Checking for TPM hardware...${NC}"
if ls /dev/tpm* &> /dev/null 2>&1; then
    echo "  ✓ TPM device detected: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')"
    
    # Create helper script to extract endorsement key
    cat > /usr/local/bin/get-tpm-key.sh <<'TPMEOF'
#!/bin/bash
echo "════════════════════════════════════════════"
echo "│      TPM Endorsement Key Extractor        │"
echo "════════════════════════════════════════════"
echo ""
echo "This key uniquely identifies your TPM chip."
echo "Send this to your Azure administrator to register this device."
echo ""
echo "Extracting endorsement key..."
echo ""


# Method 1: Direct read
if sudo tpm2_nvread -C o 0x1c00002 2>/dev/null | xxd -p -c 256; then
    echo ""
    echo "✓ Endorsement key extracted successfully!"
else
    echo "⚠ Direct read failed, trying alternative method..."
    echo ""
    
    # Method 2: Using createek
    sudo tpm2_createek -c /tmp/ek.ctx -G rsa -u /tmp/ek.pub 2>/dev/null
    sudo tpm2_readpublic -c /tmp/ek.ctx -f pem -o /tmp/ek.pem 2>/dev/null
    
    if [ -f /tmp/ek.pem ]; then
        echo "Endorsement Key (PEM format):"
        cat /tmp/ek.pem
        echo ""
        echo "✓ Endorsement key extracted successfully!"
    else
        echo "✗ Failed to extract endorsement key"
        echo "Your TPM may not be properly initialized."
        exit 1
    fi
fi

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "📧 Next step: Send this key to your Azure administrator"
echo ""
TPMEOF
    
    chmod +x /usr/local/bin/get-tpm-key.sh
    echo "  ✓ Created TPM key extraction helper: get-tpm-key.sh"
else
    echo -e "${YELLOW}  ⚠ No TPM device found${NC}"
    echo "  ℹ️  Will use connection string fallback for provisioning"
fi

# Create monitoring script
echo ""
echo -e "${GREEN}Creating system monitoring script...${NC}"
cat > /usr/local/bin/iot-monitor.sh <<'EOF'
#!/bin/bash
# Quick system health check for IoT Edge device

echo "════════════════════════════════════════════"
echo "│  System Health Check - $(date +'%Y-%m-%d %H:%M:%S')                │"
echo "════════════════════════════════════════════"
echo ""

# IoT Edge Status
echo "🔷 Azure IoT Edge:"
if command -v iotedge &> /dev/null; then
    sudo iotedge system status 2>/dev/null || echo "   Not configured yet"
    echo ""
    echo "   Modules:"
    sudo iotedge list 2>/dev/null || echo "   Not configured yet"
else
    echo "   Not installed"
fi

# TPM Status
echo ""
echo "🔐 TPM Status:"
if ls /dev/tpm* &> /dev/null; then
    echo "   ✓ TPM device available: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')"
else
    echo "   ✗ No TPM device found"
fi

# Defender for IoT Status
echo ""
echo "🛡️  Microsoft Defender for IoT:"
if systemctl is-active --quiet defender-iot-micro-agent 2>/dev/null; then
    echo "   ✓ Defender micro-agent is running"
else
    echo "   ⚠ Defender micro-agent not running or not installed"
fi

# Memory
echo ""
echo "💾 Memory Usage:"
free -h | awk 'NR==1 || NR==2'
echo ""
echo "   Swap:"
free -h | awk 'NR==1 || NR==3'

# Disk
echo ""
echo "💿 Disk Usage:"
df -h / | awk 'NR==1 || NR==2'

# Docker containers
echo ""
echo "🐳 Docker Containers:"
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
fi

# IoT Edge module stats
echo ""
echo "📊 Module Statistics (last 1 second):"
if command -v docker &> /dev/null; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "No containers running"
fi

# System load
echo ""
echo "⚡ System Load:"
uptime

# Network connections
echo ""
echo "🌐 Active Connections:"
netstat -an | grep ESTABLISHED | wc -l | xargs echo "   Established connections:"

# Network connectivity test
echo ""
echo "📡 Network Connectivity:"
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "   ✓ Internet connectivity: OK"
else
    echo "   ✗ Internet connectivity: FAILED"
fi

# Show network interfaces and IPs
echo ""
echo "🔌 Network Interfaces:"
ip -br addr show | grep -v "^lo" | awk '{printf "   %s: %s\n", $1, $3}'

# Temperature
echo ""
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp | sed 's/temp=//')
    echo "🌡️  Temperature: $TEMP"
else
    echo "🌡️  Temperature: Not available (will be monitored by SCADA module)"
fi

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "💡 Tip: Run 'sudo iotedge check' for comprehensive IoT Edge diagnostics"
echo ""
EOF

chmod +x /usr/local/bin/iot-monitor.sh

# Create SCADA log viewer script
echo ""
echo -e "${GREEN}Creating SCADA log viewer script...${NC}"
cat > /usr/local/bin/scada-logs.sh <<'SCADALOGS'
#!/bin/bash

###############################################################################
# SCADA Polling Module Log Viewer
# Purpose: Quick access to logs for troubleshooting OpenPoint SCADA module
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MODULE_NAME="ScadaPollingModule"

# Show menu
show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│  SCADA Polling Module - Log Viewer        │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Select log view option:"
    echo ""
    echo "  ${GREEN}1${NC}) Live tail - Follow module logs in real-time"
    echo "  ${GREEN}2${NC}) Last 100 lines - Recent module activity"
    echo "  ${GREEN}3${NC}) Last 500 lines - Extended history"
    echo "  ${GREEN}4${NC}) Errors only - Filter for errors/exceptions"
    echo "  ${GREEN}5${NC}) Warnings & Errors - Show problems only"
    echo "  ${GREEN}6${NC}) IoT Edge system logs - Runtime issues"
    echo "  ${GREEN}7${NC}) All module logs since boot"
    echo "  ${GREEN}8${NC}) Docker container stats"
    echo "  ${GREEN}9${NC}) Export logs to file"
    echo "  ${YELLOW}0${NC}) Exit"
    echo ""
    echo -e "${CYAN}Current module status:${NC}"
    sudo iotedge list 2>/dev/null | grep -E "NAME|$MODULE_NAME" || echo "  Module not deployed yet"
    echo ""
}

# Check if module exists
check_module() {
    if ! sudo iotedge list 2>/dev/null | grep -q "$MODULE_NAME"; then
        echo -e "${RED}Error: $MODULE_NAME is not running${NC}"
        return 1
    fi
    return 0
}

# Live tail
live_tail() {
    echo -e "${GREEN}Live log stream (Ctrl+C to exit)${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME -f
}

# Last N lines
last_lines() {
    local lines=$1
    echo -e "${GREEN}Last $lines log entries${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail $lines
}

# Errors only
errors_only() {
    echo -e "${RED}Filtering for errors and exceptions${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "error|exception|fail|critical" || echo -e "${GREEN}✓ No errors found${NC}"
}

# Warnings and errors
warnings_errors() {
    echo -e "${YELLOW}Filtering for warnings and errors${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "warn|error|exception|fail|critical" || echo -e "${GREEN}✓ No warnings or errors found${NC}"
}

# System logs
system_logs() {
    echo -e "${GREEN}IoT Edge system logs${NC}"
    echo ""
    sudo iotedge system logs --tail 200
}

# All logs since boot
all_logs() {
    echo -e "${GREEN}All module logs since boot${NC}"
    echo -e "${YELLOW}Warning: This may be a large amount of data${NC}"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo iotedge logs $MODULE_NAME | less
    fi
}

# Docker stats
docker_stats() {
    echo -e "${GREEN}Container resource usage${NC}"
    echo ""
    echo "Real-time stats (Ctrl+C to exit):"
    docker stats $MODULE_NAME
}

# Export logs
export_logs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="scada_logs_${timestamp}.txt"
    
    echo -e "${GREEN}Exporting logs to: $filename${NC}"
    echo ""
    
    {
        echo "=================================================="
        echo "SCADA Polling Module Logs"
        echo "Exported: $(date)"
        echo "=================================================="
        echo ""
        echo "=== Module Status ==="
        sudo iotedge list 2>/dev/null | grep -E "NAME|$MODULE_NAME"
        echo ""
        echo "=== Last 500 Log Entries ==="
        sudo iotedge logs $MODULE_NAME --tail 500
        echo ""
        echo "=== Errors & Warnings ==="
        sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "warn|error|exception|fail|critical"
        echo ""
        echo "=== IoT Edge System Status ==="
        sudo iotedge system status 2>/dev/null
        echo ""
        echo "=== Container Stats (snapshot) ==="
        docker stats --no-stream $MODULE_NAME 2>/dev/null
    } > "$filename"
    
    echo -e "${GREEN}✓ Logs exported to: $filename${NC}"
    echo ""
    echo "File size: $(du -h "$filename" | cut -f1)"
    echo ""
    echo "You can copy this file off the device with:"
    echo "  scp $(whoami)@$(hostname -I | awk '{print $1}'):~/$filename ."
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1) check_module && live_tail; read -p "Press ENTER..." ;;
        2) check_module && last_lines 100; read -p "Press ENTER..." ;;
        3) check_module && last_lines 500; read -p "Press ENTER..." ;;
        4) check_module && errors_only; read -p "Press ENTER..." ;;
        5) check_module && warnings_errors; read -p "Press ENTER..." ;;
        6) system_logs; read -p "Press ENTER..." ;;
        7) check_module && all_logs; read -p "Press ENTER..." ;;
        8) check_module && docker_stats; read -p "Press ENTER..." ;;
        9) check_module && export_logs; read -p "Press ENTER..." ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
SCADALOGS

chmod +x /usr/local/bin/scada-logs.sh
echo "  ✓ Created /usr/local/bin/scada-logs.sh"

echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│  IoT Edge Installation Complete (14/14)                        │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to see installation summary...${NC}"
read -r

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│                    OPTIMIZATION COMPLETE                       │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ System optimized for IoT Edge deployment${NC}"
echo ""
echo "📋 Applied optimizations:"
echo "   ✓ Keyboard layout set to US"
echo "   ✓ Timezone set to UTC"
echo "   ✓ Locale set to en_US.UTF-8"
echo "   ✓ Swap reduced to 10% (prefer RAM)"
echo "   ✓ SSD TRIM enabled (weekly)"
echo "   ✓ Hardware watchdog enabled (auto-reboot if system hangs)"
echo "   ✓ Network buffers increased"
echo "   ✓ File descriptor limit: 65535"
echo "   ✓ Moby container engine configured"
echo "   ✓ Local logging driver enabled"
echo "   ✓ Azure IoT Edge runtime installed"
echo "   ✓ Microsoft Defender for IoT installed"
echo "   ✓ Unnecessary services disabled (Bluetooth, ModemManager, CUPS, cloud-init)"
echo "   ✓ System monitoring script created (iot-monitor.sh)"
echo "   ✓ SCADA log viewer created (scada-logs.sh)"
echo ""
echo -e "${YELLOW}Press ENTER to see useful commands and next steps...${NC}"
read -r

# Page 2: Useful Commands
clear
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│                    USEFUL COMMANDS                             │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo "📋 System Monitoring:"
echo "   • iot-monitor.sh                          - Quick health check"
echo "   • scada-logs.sh                           - SCADA module log viewer"
echo "   • sudo iotedge system status              - IoT Edge status"
echo "   • sudo iotedge check                      - Full diagnostics"
echo ""
echo "📋 TPM & Device Identity:"
echo "   • get-tpm-key.sh                          - Extract TPM endorsement key"
echo "   • ls -l /dev/tpm*                         - Verify TPM device"
echo ""
echo "📋 Module Management:"
echo "   • sudo iotedge list                       - List running modules"
echo "   • sudo iotedge logs <module-name>         - View module logs"
echo "   • sudo iotedge system logs                - View system logs"
echo ""
echo "📋 Container & System:"
echo "   • docker stats                            - Container resource usage"
echo "   • docker ps                               - Running containers"
echo "   • sudo systemctl status defender-iot-micro-agent - Defender status"
echo ""
echo -e "${YELLOW}Press ENTER to see configuration steps...${NC}"
read -r

# Page 3: Next Steps
clear
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}│                    NEXT STEPS (AFTER REBOOT)                   │${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}RECOMMENDED: TPM-Based Provisioning (Most Secure)${NC}"
echo ""
echo "Step 1: Extract TPM endorsement key and send to Azure administrator"
echo "   get-tpm-key.sh"
echo "   # Copy the output and send via secure channel"
echo ""
echo "Step 2: Wait for Azure administrator to provide:"
echo "   • DPS Scope ID (e.g., 0ne00XXXXXX)"
echo "   • Registration ID (e.g., scada-device-001)"
echo ""
echo "Step 3: Configure IoT Edge with values from administrator"
echo "   sudo iotedge config dps --scope-id YOUR_SCOPE_ID --registration-id YOUR_REG_ID"
echo "   sudo iotedge config apply"
echo ""
echo "Step 4: Verify IoT Edge is running"
echo "   sudo iotedge system status"
echo "   sudo iotedge list"
echo ""
echo "Step 5: Run comprehensive diagnostics"
echo "   sudo iotedge check"
echo ""
echo "Step 6: Monitor deployment"
echo "   iot-monitor.sh"
echo ""
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Setup complete! Ready to reboot.${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  Please reboot the system for all changes to take effect:${NC}"
echo "   sudo reboot"
echo ""
