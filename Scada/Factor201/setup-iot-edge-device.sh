#!/bin/bash

###############################################################################
# Ubuntu Server Optimization Script for Raspberry Pi Factor 201
# Hardware: 4GB RAM, 128GB SSD
# Purpose: Prepare system for OpenPoint SCADA Polling IoT Edge Module
###############################################################################

# Exit on error in main script, but allow functions to handle their own errors
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Debug mode (set to 1 to show all command output, 0 to hide)
DEBUG_MODE=${DEBUG_MODE:-1}

# Logging function
log_command() {
    if [ "$DEBUG_MODE" = "1" ]; then
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

# Error handler
trap 'handle_error $? $LINENO' ERR

handle_error() {
    local exit_code=$1
    local line_number=$2
    echo ""
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo -e "${RED}│  ERROR OCCURRED                          │${NC}"
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo -e "${RED}Exit Code: $exit_code${NC}"
    echo -e "${RED}Line Number: $line_number${NC}"
    echo ""
    echo "The script encountered an error. Check the output above for details."
    echo ""
    echo "TIP: To hide verbose output, run with:"
    echo "     DEBUG_MODE=0 sudo bash ./setup-iot-edge-device.sh"
    echo ""
    read -p "Press ENTER to return to menu..."
}

# Function to show menu
show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│  Ubuntu Server Optimization for OpenPoint SCADA Module        │${NC}"
    echo -e "${BLUE}│  Target: Raspberry Pi Factor 201 (4GB RAM, 128GB SSD)         │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Select installation option:"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${CYAN}Full Setup${NC} - Complete installation (recommended for first-time setup)"
    echo ""
    echo -e "  ${GREEN}2${NC}) System Configuration - Keyboard, timezone, locale, hardware detection"
    echo -e "  ${GREEN}3${NC}) System Updates - Update packages and install essential tools"
    echo -e "  ${GREEN}4${NC}) System Optimization - Swap, TRIM, watchdog, file descriptors, network"
    echo -e "  ${GREEN}5${NC}) Container Engine - Install and configure Moby/Docker"
    echo -e "  ${GREEN}6${NC}) IoT Edge Runtime - Install Azure IoT Edge and TPM tools"
    echo -e "  ${GREEN}7${NC}) Helper Scripts - Download monitoring and log viewer scripts"
    echo ""
    echo -e "  ${GREEN}8${NC}) Clean Duplicate Config - Remove duplicate entries from previous runs"
    echo ""
    echo -e "  ${YELLOW}0${NC}) Exit"
    echo ""
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root (use sudo)${NC}" 
        exit 1
    fi
}

# Check if package manager is busy
check_package_manager() {
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || 
       fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || 
       fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        echo -e "${YELLOW}│  WARNING: Package Manager Busy          │${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
        echo ""
        echo "Another package manager (apt/dpkg) is currently running."
        echo "This is often Ubuntu's automatic update process."
        echo ""
        echo "Options:"
        echo "  1. Wait 5-10 minutes for it to finish, then run this script"
        echo "  2. Check what's running: ps aux | grep apt"
        echo "  3. Stop automatic updates temporarily:"
        echo "     sudo systemctl stop apt-daily.timer"
        echo "     sudo systemctl stop apt-daily-upgrade.timer"
        echo "  4. Disable automatic updates permanently (recommended for IoT Edge):"
        echo "     sudo systemctl disable apt-daily.timer"
        echo "     sudo systemctl disable apt-daily-upgrade.timer"
        echo "     sudo systemctl stop unattended-upgrades"
        echo ""
        read -p "Would you like to disable automatic updates now? (y/N): " REPLY
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Disabling automatic updates..."
            systemctl stop apt-daily.timer 2>/dev/null || true
            systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
            systemctl disable apt-daily.timer 2>/dev/null || true
            systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
            systemctl stop unattended-upgrades 2>/dev/null || true
            systemctl disable unattended-upgrades 2>/dev/null || true
            echo -e "${GREEN}✓ Automatic updates disabled${NC}"
            echo ""
            echo "Waiting 10 seconds for processes to release locks..."
            sleep 10
            
            # Kill any remaining apt processes
            killall apt apt-get 2>/dev/null || true
            sleep 2
            
            echo -e "${GREEN}✓ Ready to continue${NC}"
            return 0
        else
            read -p "Continue anyway (not recommended)? (y/N): " REPLY2
            echo
            if [[ ! $REPLY2 =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Wait for package manager to be available
wait_for_package_manager() {
    local max_wait=300  # 5 minutes max
    local waited=0
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || 
          fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || 
          fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
        
        if [ $waited -eq 0 ]; then
            echo ""
            echo -e "${YELLOW}⏳ Package manager is busy (likely unattended-upgrades)${NC}"
            echo "   Waiting for it to finish (up to 5 minutes)..."
        fi
        
        sleep 5
        waited=$((waited + 5))
        
        if [ $((waited % 30)) -eq 0 ]; then
            echo "   Still waiting... (${waited}s elapsed)"
        fi
        
        if [ $waited -ge $max_wait ]; then
            echo ""
            echo -e "${RED}Timeout waiting for package manager${NC}"
            echo "You can:"
            echo "  1. Wait longer and run the script again"
            echo "  2. Stop unattended upgrades:"
            echo "     sudo systemctl stop unattended-upgrades"
            echo "     sudo killall apt apt-get dpkg"
            return 1
        fi
    done
    
    if [ $waited -gt 0 ]; then
        echo -e "${GREEN}   ✓ Package manager is now available${NC}"
        echo ""
    fi
    
    return 0
}

# System requirements notice
show_requirements() {
    echo ""
    echo -e "${BLUE}System Requirements Check${NC}"
    echo "This script is optimized for:"
    echo "  • Raspberry Pi Factor 201"
    echo "  • 4GB RAM"
    echo "  • 128GB SSD storage"
    echo "  • Ubuntu Server 24.04 LTS (ARM64)"
    echo ""
    echo -e "${YELLOW}⚠️  Be sure to run the script from SSD, NOT SD card or HDD storage.${NC}"
    echo ""
}

# Pre-cleanup: Remove duplicate entries from previous runs
cleanup_duplicates() {
    echo -e "${BLUE}Checking for duplicate configuration entries...${NC}"
    
    # Clean up sysctl.conf duplicates
    if [ -f /etc/sysctl.conf ]; then
        awk '!seen[$0]++' /etc/sysctl.conf > /etc/sysctl.conf.tmp
        mv /etc/sysctl.conf.tmp /etc/sysctl.conf
        echo -e "${GREEN}  ✓ Cleaned sysctl.conf${NC}"
    fi
    
    # Clean up limits.conf duplicates
    if [ -f /etc/security/limits.conf ]; then
        grep -v "nofile 65535" /etc/security/limits.conf > /etc/security/limits.conf.tmp || true
        mv /etc/security/limits.conf.tmp /etc/security/limits.conf
        echo -e "${GREEN}  ✓ Cleaned limits.conf (will re-add correct entries)${NC}"
    fi
    
    echo ""
}

# Check if IoT Edge is already installed
check_iotedge_installed() {
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
        read -p "Continue? (y/N): " REPLY
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            return 1
        fi
        echo ""
    fi
    return 0
}

# System configuration (keyboard, timezone, locale, hardware detection)
system_configuration() {
    echo -e "${BLUE}[STEP 1] System Configuration${NC}"
    echo ""
    
    # Configure keyboard layout to US
    echo -e "${GREEN}[1/4] Configuring keyboard layout to US...${NC}"
    cat > /etc/default/keyboard <<EOF
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
EOF
    loadkeys us 2>/dev/null || true
    echo "  ✓ Keyboard layout set to US"
    
    # Set timezone to UTC
    echo ""
    echo -e "${GREEN}[2/4] Setting timezone to UTC...${NC}"
    timedatectl set-timezone UTC
    echo "  ✓ Timezone set to UTC"
    
    # Configure locale to en_US.UTF-8
    echo ""
    echo -e "${GREEN}[3/4] Configuring locale to en_US.UTF-8...${NC}"
    locale-gen en_US.UTF-8 > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 > /dev/null 2>&1
    echo "  ✓ Locale set to en_US.UTF-8"
    
    # Detect hardware
    echo ""
    echo -e "${GREEN}[4/4] Detecting hardware...${NC}"
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    DISK_SIZE=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    ARCH=$(uname -m)
    
    # Calculate RAM in GB for display (simple division by 1024)
    RAM_GB=$(echo "scale=1; $TOTAL_RAM / 1024" | bc)
    
    echo "  💾 RAM: ${TOTAL_RAM}MB (${RAM_GB}GB)"
    echo "  💿 Disk: ${DISK_SIZE}GB"
    echo "  🖥️  Architecture: ${ARCH}"
    
    # 4GB RAM (4096MB) shows as ~3700-3900MB due to system/GPU reserved memory
    # Warn only if significantly below expected range
    if [[ $TOTAL_RAM -lt 3500 ]]; then
        WARN_RAM_GB=$(echo "scale=1; $TOTAL_RAM / 1024" | bc)
        echo -e "${YELLOW}  ⚠ Warning: Detected ${TOTAL_RAM}MB RAM (${WARN_RAM_GB}GB), expected ~3.7GB for 4GB hardware.${NC}"
        echo -e "${YELLOW}     System optimizations are tuned for 4GB. Performance may vary.${NC}"
    fi
    
    if [[ $ARCH != "aarch64" && $ARCH != "arm64" ]]; then
        echo -e "${YELLOW}  ⚠ Warning: Not ARM64 architecture. Some optimizations may not apply.${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ System configuration complete${NC}"
}

# System updates and package installation
system_updates() {
    echo -e "${BLUE}[STEP 2] System Updates & Package Installation${NC}"
    echo ""
    
    # Wait for package manager before starting
    wait_for_package_manager || return 1
    
    # Update system
    echo -e "${GREEN}[1/3] Updating system packages...${NC}"
    echo "  (This may take several minutes...)"
    
    if ! apt-get update --fix-missing 2>&1 | grep -v "^Get:" | grep -v "^Hit:" | grep -v "^Ign:" | grep -E "Err:|W:|E:"; then
        apt-get update --fix-missing
    fi
    
    if ! apt-get upgrade -y --fix-missing 2>&1 | tail -20; then
        echo -e "${RED}  ✗ Failed to upgrade packages${NC}"
        echo "  Continuing anyway..."
    else
        echo "  ✓ System packages updated"
    fi
    
    # Install essential packages
    echo ""
    echo -e "${GREEN}[2/3] Installing essential packages...${NC}"
    
    # Wait again in case unattended-upgrades started during upgrade
    wait_for_package_manager || return 1
    
    if apt-get install -y --fix-missing \
        curl wget git ca-certificates gnupg lsb-release \
        smartmontools iotop htop net-tools iftop 2>&1 | tail -10; then
        echo "  ✓ Essential packages installed"
    else
        echo -e "${YELLOW}  ⚠ Some packages may have failed to install${NC}"
        echo "  Continuing anyway..."
    fi
    
    # Remove unnecessary services
    echo ""
    echo -e "${GREEN}[3/3] Disabling unnecessary services...${NC}"
    systemctl stop bluetooth 2>/dev/null || true
    systemctl disable bluetooth 2>/dev/null || true
    systemctl stop ModemManager 2>/dev/null || true
    systemctl disable ModemManager 2>/dev/null || true
    systemctl stop cups 2>/dev/null || true
    systemctl disable cups 2>/dev/null || true
    
    # Disable cloud-init
    if command -v cloud-init &> /dev/null; then
        touch /etc/cloud/cloud-init.disabled
        systemctl disable cloud-init 2>/dev/null || true
        systemctl disable cloud-config 2>/dev/null || true
        systemctl disable cloud-final 2>/dev/null || true
        systemctl disable cloud-init-local 2>/dev/null || true
        
        # Clean up cloud-init network configuration
        if [ -f /etc/netplan/50-cloud-init.yaml ]; then
            rm -f /etc/netplan/50-cloud-init.yaml
            cat > /etc/netplan/01-netcfg.yaml <<'NETEOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    all-eth:
      match:
        name: "e*"
      dhcp4: true
      dhcp6: false
      optional: true
NETEOF
            netplan generate > /dev/null 2>&1
        fi
    fi
    
    echo "  ✓ Disabled: Bluetooth, ModemManager, CUPS, cloud-init"
    echo ""
    echo -e "${GREEN}✓ System updates complete${NC}"
}

# System optimizations
system_optimization() {
    echo -e "${BLUE}[STEP 3] System Optimization${NC}"
    echo ""
    
    # Optimize swap settings
    echo -e "${GREEN}[1/5] Optimizing swap settings...${NC}"
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
    echo -e "${GREEN}[2/5] Enabling SSD TRIM...${NC}"
    systemctl enable fstrim.timer > /dev/null 2>&1
    systemctl start fstrim.timer > /dev/null 2>&1
    echo "  ✓ Weekly TRIM scheduled"
    
    # Enable hardware watchdog
    echo ""
    echo -e "${GREEN}[3/5] Enabling hardware watchdog...${NC}"
    if ! lsmod | grep -q bcm2835_wdt; then
        modprobe bcm2835_wdt 2>/dev/null || true
    fi
    if ! grep -q "bcm2835_wdt" /etc/modules 2>/dev/null; then
        echo "bcm2835_wdt" >> /etc/modules
    fi
    
    # Wait for package manager before installing watchdog
    wait_for_package_manager || return 1
    
    apt-get install -y --fix-missing watchdog > /dev/null 2>&1
    cat > /etc/watchdog.conf <<EOF
watchdog-device = /dev/watchdog
watchdog-timeout = 15
max-load-1 = 24
allocatable-memory = 1
realtime = yes
priority = 1
EOF
    systemctl enable watchdog > /dev/null 2>&1
    systemctl start watchdog > /dev/null 2>&1
    echo "  ✓ Hardware watchdog enabled"
    
    # Increase file descriptors
    echo ""
    echo -e "${GREEN}[4/5] Increasing file descriptor limits...${NC}"
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
    echo -e "${GREEN}[5/5] Applying network optimizations...${NC}"
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
        echo "  ✓ Network buffers increased"
    else
        echo "  ✓ Network optimizations already configured"
    fi
    sysctl -p > /dev/null 2>&1
    
    echo ""
    echo -e "${GREEN}✓ System optimization complete${NC}"
}

# Container engine installation
container_engine() {
    echo -e "${BLUE}[STEP 4] Container Engine Installation${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    # Install Moby
    echo -e "${GREEN}[1/2] Installing Moby container engine...${NC}"
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        echo "  ✓ Container engine already installed (${DOCKER_VERSION})"
    else
        # Wait for package manager
        wait_for_package_manager
        if [ $? -ne 0 ]; then
            set -e
            return 1
        fi
        
        echo "  Updating package lists..."
        apt-get update --fix-missing 2>&1 | tail -5
        
        echo "  Installing container engine (this may take a few minutes)..."
        
        # Add Microsoft repository for moby-engine
        echo "  Adding Microsoft package repository..."
        UBUNTU_VERSION=$(lsb_release -rs)
        wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb > /dev/null 2>&1
        rm packages-microsoft-prod.deb
        
        echo "  Updating package lists with Microsoft repository..."
        apt-get update --fix-missing 2>&1 | tail -5
        
        echo "  Installing moby-engine from Microsoft repository..."
        apt-get install -y moby-engine 2>&1 | tee /tmp/docker-install.log | tail -15
        local install_result=$?
        
        if [ $install_result -eq 0 ]; then
            echo ""
            echo "  ✓ Moby engine package installed"
        else
            echo ""
            echo -e "${RED}  ✗ Failed to install moby-engine (exit code: $install_result)${NC}"
            echo ""
            echo "Last 30 lines of installation log:"
            tail -30 /tmp/docker-install.log
            echo ""
            echo "Diagnostic commands to run:"
            echo "  apt-cache policy moby-engine"
            echo "  cat /tmp/docker-install.log"
            echo ""
            echo "Microsoft repository should provide moby-engine for Ubuntu ${UBUNTU_VERSION}"
            set -e
            return 1
        fi
        
        echo ""
        echo "  Starting Docker service..."
        systemctl restart docker 2>&1
        local docker_start_result=$?
        
        if [ $docker_start_result -eq 0 ]; then
            echo "  ✓ Docker service started"
        else
            echo -e "${RED}  ✗ Failed to start Docker service (exit code: $docker_start_result)${NC}"
            echo ""
            echo "Service status:"
            systemctl status docker.service --no-pager -l
            set -e
            return 1
        fi
    fi
    
    # Verify Docker is running
    echo ""
    echo "  Verifying Docker installation..."
    
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}  ⚠ Docker service not active, attempting to start...${NC}"
        systemctl start docker
        sleep 2
    fi
    
    if systemctl is-active --quiet docker; then
        echo "  ✓ Docker service is active"
    else
        echo -e "${RED}  ✗ Docker service failed to start${NC}"
        echo ""
        systemctl status docker --no-pager
        set -e
        return 1
    fi
    
    if docker --version > /dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version)
        echo "  ✓ Docker command works: ${DOCKER_VERSION}"
    else
        echo -e "${RED}  ✗ Docker command failed${NC}"
        echo "  Try running: docker --version"
        set -e
        return 1
    fi
    
    # Configure Docker
    echo ""
    echo -e "${GREEN}[2/2] Configuring container engine...${NC}"
    mkdir -p /etc/docker
    
    if [ -f /etc/docker/daemon.json ]; then
        if ! grep -q '"log-driver": "local"' /etc/docker/daemon.json; then
            echo "  Backing up existing daemon.json..."
            cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
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
            echo "  Restarting Docker to apply configuration..."
            systemctl restart docker
            echo "  ✓ Docker reconfigured for IoT Edge"
        else
            echo "  ✓ Docker already configured for IoT Edge"
        fi
    else
        echo "  Creating daemon.json configuration..."
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
        echo "  Restarting Docker to apply configuration..."
        systemctl restart docker
        echo "  ✓ Docker configured"
    fi
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ Container engine ready${NC}"
}

# IoT Edge runtime installation
iotedge_runtime() {
    echo -e "${BLUE}[STEP 5] IoT Edge Runtime Installation${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    # Install IoT Edge
    echo -e "${GREEN}[1/2] Installing Azure IoT Edge Runtime...${NC}"
    if command -v iotedge &> /dev/null; then
        echo "  ✓ IoT Edge already installed ($(iotedge --version))"
    else
        # Wait for package manager
        wait_for_package_manager
        if [ $? -ne 0 ]; then
            set -e
            return 1
        fi
        
        echo "  Adding Microsoft package repository (if not already added)..."
        UBUNTU_VERSION=$(lsb_release -rs)
        
        # Check if Microsoft repo is already configured
        if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
            wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
            dpkg -i packages-microsoft-prod.deb 2>&1 | tail -5
            local dpkg_result=$?
            rm packages-microsoft-prod.deb
            
            if [ $dpkg_result -eq 0 ]; then
                echo "  ✓ Microsoft repository added"
            else
                echo -e "${YELLOW}  ⚠ Repository may already be configured${NC}"
            fi
        else
            echo "  ✓ Microsoft repository already configured"
        fi
        
        echo ""
        echo "  Updating package lists..."
        apt-get update --fix-missing 2>&1 | tail -5
        
        echo ""
        echo "  Installing Azure IoT Edge Runtime (this may take a few minutes)..."
        apt-get install -y --fix-missing aziot-edge defender-iot-micro-agent-edge 2>&1 | tee /tmp/iotedge-install.log | tail -15
        local install_result=$?
        
        if [ $install_result -eq 0 ]; then
            echo ""
            echo "  ✓ IoT Edge runtime installed"
            echo "  ✓ Microsoft Defender for IoT installed"
        else
            echo ""
            echo -e "${RED}  ✗ Failed to install IoT Edge runtime (exit code: $install_result)${NC}"
            echo ""
            echo "Last 30 lines of installation log:"
            tail -30 /tmp/iotedge-install.log
            echo ""
            echo "Diagnostic commands to run:"
            echo "  apt-cache policy aziot-edge"
            echo "  apt-cache policy defender-iot-micro-agent-edge"
            echo "  cat /tmp/iotedge-install.log"
            echo ""
            echo "Microsoft repository should provide IoT Edge for Ubuntu ${UBUNTU_VERSION}"
            set -e
            return 1
        fi
        
        # Verify IoT Edge installation
        echo ""
        echo "  Verifying IoT Edge installation..."
        if command -v iotedge &> /dev/null; then
            IOTEDGE_VERSION=$(iotedge --version 2>/dev/null || echo "unknown")
            echo "  ✓ IoT Edge command available: ${IOTEDGE_VERSION}"
        else
            echo -e "${RED}  ✗ IoT Edge command not found after installation${NC}"
            set -e
            return 1
        fi
    fi
    
    # Install TPM tools
    echo ""
    echo -e "${GREEN}[2/2] Installing TPM 2.0 tools...${NC}"
    if ! command -v tpm2_getcap &> /dev/null; then
        # Wait for package manager again
        wait_for_package_manager
        if [ $? -ne 0 ]; then
            set -e
            return 1
        fi
        
        echo "  Installing tpm2-tools..."
        apt-get install -y --fix-missing tpm2-tools 2>&1 | tee /tmp/tpm-install.log | tail -10
        local tpm_install_result=$?
        
        if [ $tpm_install_result -eq 0 ]; then
            echo "  ✓ TPM 2.0 tools installed"
        else
            echo -e "${YELLOW}  ⚠ Failed to install TPM tools (exit code: $tpm_install_result)${NC}"
            echo "  This is optional - IoT Edge can work without TPM"
            echo "  Log saved to: /tmp/tpm-install.log"
        fi
    else
        echo "  ✓ TPM 2.0 tools already installed"
    fi
    
    # Check for TPM device
    echo ""
    echo "  Checking for TPM device..."
    if ls /dev/tpm* &> /dev/null 2>&1; then
        echo "  ✓ TPM device detected: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')"
    else
        echo -e "${YELLOW}  ⚠ No TPM device found${NC}"
        echo "  ℹ️  Will use connection string fallback for provisioning"
    fi
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ IoT Edge runtime ready${NC}"
    return 0
}

# Download helper scripts
helper_scripts() {
    echo -e "${BLUE}[STEP 6] Downloading Helper Scripts${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    BASE_URL="https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201"
    
    # TPM key extractor (if TPM present)
    if ls /dev/tpm* &> /dev/null 2>&1; then
        echo -e "${GREEN}[1/3] Downloading TPM key extraction helper...${NC}"
        wget -q ${BASE_URL}/get-tpm-key.sh -O /usr/local/bin/get-tpm-key.sh
        local wget_result=$?
        
        if [ $wget_result -eq 0 ]; then
            chmod +x /usr/local/bin/get-tpm-key.sh
            echo "  ✓ Created: get-tpm-key.sh"
        else
            echo -e "${RED}  ✗ Failed to download get-tpm-key.sh (exit code: $wget_result)${NC}"
            echo "  Check internet connection or URL: ${BASE_URL}/get-tpm-key.sh"
        fi
    else
        echo -e "${YELLOW}[1/3] Skipping TPM helper (no TPM device)${NC}"
    fi
    
    # System monitor
    echo ""
    echo -e "${GREEN}[2/3] Downloading system monitoring script...${NC}"
    wget -q ${BASE_URL}/iot-monitor.sh -O /usr/local/bin/iot-monitor.sh
    local wget_result=$?
    
    if [ $wget_result -eq 0 ]; then
        chmod +x /usr/local/bin/iot-monitor.sh
        echo "  ✓ Created: iot-monitor.sh"
    else
        echo -e "${RED}  ✗ Failed to download iot-monitor.sh (exit code: $wget_result)${NC}"
        echo "  Check internet connection or URL: ${BASE_URL}/iot-monitor.sh"
        set -e
        return 1
    fi
    
    # Log viewer
    echo ""
    echo -e "${GREEN}[3/3] Downloading SCADA log viewer...${NC}"
    wget -q ${BASE_URL}/scada-logs.sh -O /usr/local/bin/scada-logs.sh
    local wget_result=$?
    
    if [ $wget_result -eq 0 ]; then
        chmod +x /usr/local/bin/scada-logs.sh
        echo "  ✓ Created: scada-logs.sh"
    else
        echo -e "${RED}  ✗ Failed to download scada-logs.sh (exit code: $wget_result)${NC}"
        echo "  Check internet connection or URL: ${BASE_URL}/scada-logs.sh"
        set -e
        return 1
    fi
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ Helper scripts ready${NC}"
    return 0
}

# Full setup
full_setup() {
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Starting Full Setup - This may take 15-20 minutes${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo ""
    
    show_requirements
    check_iotedge_installed || return 1
    cleanup_duplicates
    
    # Disable exit on error for the setup steps
    set +e
    
    system_configuration
    local step1_result=$?
    if [ $step1_result -ne 0 ]; then
        echo -e "${RED}✗ Step 1 failed with exit code $step1_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    system_updates
    local step2_result=$?
    if [ $step2_result -ne 0 ]; then
        echo -e "${RED}✗ Step 2 failed with exit code $step2_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    system_optimization
    local step3_result=$?
    if [ $step3_result -ne 0 ]; then
        echo -e "${RED}✗ Step 3 failed with exit code $step3_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    container_engine
    local step4_result=$?
    if [ $step4_result -ne 0 ]; then
        echo -e "${RED}✗ Step 4 failed with exit code $step4_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    iotedge_runtime
    local step5_result=$?
    if [ $step5_result -ne 0 ]; then
        echo -e "${RED}✗ Step 5 failed with exit code $step5_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    helper_scripts
    local step6_result=$?
    if [ $step6_result -ne 0 ]; then
        echo -e "${RED}✗ Step 6 failed with exit code $step6_result${NC}"
        echo "Continue anyway? (y/N): "
        read -p "" REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 1
        fi
    fi
    
    # Re-enable exit on error
    set -e
    
    # Show completion summary
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│         INSTALLATION COMPLETE              │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}✅ System optimized for IoT Edge deployment${NC}"
    echo ""
    echo "Applied optimizations:"
    echo "   ✓ Keyboard layout set to US"
    echo "   ✓ Timezone set to UTC"
    echo "   ✓ Locale set to en_US.UTF-8"
    echo "   ✓ Swap optimized for 4GB RAM"
    echo "   ✓ SSD TRIM enabled"
    echo "   ✓ Hardware watchdog enabled"
    echo "   ✓ Network buffers increased"
    echo "   ✓ File descriptor limits increased"
    echo "   ✓ Moby container engine configured"
    echo "   ✓ Azure IoT Edge runtime installed"
    echo "   ✓ Helper scripts installed"
    echo ""
    echo -e "${YELLOW}⚠️  Please reboot the system:${NC}"
    echo "   sudo reboot"
    echo ""
    echo "After reboot, run:"
    echo "   get-tpm-key.sh      - Extract TPM key"
    echo "   iot-monitor.sh      - Monitor system health"
    echo "   scada-logs.sh       - View SCADA logs"
    echo ""
}

# Main script execution
main() {
    check_root
    check_package_manager
    
    while true; do
        show_menu
        read -p "Select option: " choice
        echo ""
        
        case $choice in
            1)
                full_setup
                read -p "Press ENTER to return to menu..." dummy
                ;;
            2)
                show_requirements
                system_configuration
                read -p "Press ENTER to return to menu..." dummy
                ;;
            3)
                system_updates
                read -p "Press ENTER to return to menu..." dummy
                ;;
            4)
                system_optimization
                read -p "Press ENTER to return to menu..." dummy
                ;;
            5)
                container_engine
                read -p "Press ENTER to return to menu..." dummy
                ;;
            6)
                check_iotedge_installed || continue
                iotedge_runtime
                read -p "Press ENTER to return to menu..." dummy
                ;;
            7)
                helper_scripts
                read -p "Press ENTER to return to menu..." dummy
                ;;
            8)
                cleanup_duplicates
                echo -e "${GREEN}✓ Cleanup complete${NC}"
                read -p "Press ENTER to return to menu..." dummy
                ;;
            0)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main
