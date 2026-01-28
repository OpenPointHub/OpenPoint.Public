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
    echo -e "  ${GREEN}7${NC}) Persistent Storage - Configure edgeAgent/edgeHub persistent storage"
    echo -e "  ${GREEN}8${NC}) Configure DNS - Set custom DNS servers or use automatic resolution"
    echo ""
    echo -e "  ${GREEN}9${NC}) Clean Duplicate Config - Remove duplicate entries from previous runs"
    echo -e "  ${GREEN}10${NC}) Configure Update Policy - Security-only, manual, or disable updates"
    echo -e "  ${GREEN}11${NC}) Extract TPM Key - Get TPM endorsement key for DPS enrollment"
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
    
    # Clean up sysctl.conf duplicates (removes duplicate lines, keeps first occurrence)
    if [ -f /etc/sysctl.conf ]; then
        awk '!seen[$0]++' /etc/sysctl.conf > /etc/sysctl.conf.tmp
        mv /etc/sysctl.conf.tmp /etc/sysctl.conf
        echo -e "${GREEN}  ✓ Cleaned sysctl.conf${NC}"
    fi
    
    # Clean up limits.conf duplicates (removes duplicate lines, keeps first occurrence)
    if [ -f /etc/security/limits.conf ]; then
        awk '!seen[$0]++' /etc/security/limits.conf > /etc/security/limits.conf.tmp
        mv /etc/security/limits.conf.tmp /etc/security/limits.conf
        echo -e "${GREEN}  ✓ Cleaned limits.conf${NC}"
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
    
    # Detect DNS servers from current configuration
    echo "  Detecting DNS configuration..."
    DNS_SERVERS=()
    
    # Try to get DNS from systemd-resolved
    if systemctl is-active systemd-resolved &>/dev/null; then
        DETECTED_DNS=$(resolvectl status 2>/dev/null | grep "DNS Servers:" -A 3 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -3)
        if [ -n "$DETECTED_DNS" ]; then
            while IFS= read -r dns_ip; do
                # Skip loopback addresses
                if [[ "$dns_ip" != "127."* ]]; then
                    DNS_SERVERS+=("\"$dns_ip\"")
                fi
            done <<< "$DETECTED_DNS"
        fi
    fi
    
    # Fallback to resolv.conf if no DNS found yet
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        DETECTED_DNS=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3)
        if [ -n "$DETECTED_DNS" ]; then
            while IFS= read -r dns_ip; do
                # Skip loopback addresses
                if [[ "$dns_ip" != "127."* ]]; then
                    DNS_SERVERS+=("\"$dns_ip\"")
                fi
            done <<< "$DETECTED_DNS"
        fi
    fi
    
    # Final fallback to Google DNS
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        DNS_SERVERS=("\"8.8.8.8\"" "\"8.8.4.4\"")
        echo -e "  ${YELLOW}⚠ No DNS servers detected, using Google DNS (8.8.8.8, 8.8.4.4)${NC}"
    else
        echo "  ✓ Detected DNS servers: ${DNS_SERVERS[@]//\"/}"
    fi
    
    # Build DNS JSON array
    DNS_JSON=$(IFS=,; echo "${DNS_SERVERS[*]}")
    
    if [ -f /etc/docker/daemon.json ]; then
        if ! grep -q '"log-driver": "local"' /etc/docker/daemon.json; then
            echo "  Backing up existing daemon.json..."
            cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
            cat > /etc/docker/daemon.json <<EOF
{
  "dns": [$DNS_JSON],
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
            echo "  ✓ Docker reconfigured for IoT Edge with DNS"
        else
            echo "  ✓ Docker already configured for IoT Edge"
        fi
    else
        echo "  Creating daemon.json configuration..."
        cat > /etc/docker/daemon.json <<EOF
{
  "dns": [$DNS_JSON],
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
        echo "  ✓ Docker configured with DNS"
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
        
        # Install aziot-edge (core IoT Edge runtime)
        # Note: defender-iot-micro-agent-edge was retired in August 2025
        apt-get install -y aziot-edge 2>&1 | tee /tmp/iotedge-install.log | tail -15
        local install_result=$?
        
        if [ $install_result -eq 0 ]; then
            echo ""
            echo "  ✓ IoT Edge runtime installed"
        else
            echo ""
            echo -e "${RED}  ✗ Failed to install IoT Edge runtime (exit code: $install_result)${NC}"
            echo ""
            echo "Last 30 lines of installation log:"
            tail -30 /tmp/iotedge-install.log
            echo ""
            echo "Diagnostic commands to run:"
            echo "  apt-cache policy aziot-edge"
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

# Extract TPM endorsement key
extract_tpm_key() {
    echo -e "${BLUE}[TPM KEY EXTRACTION]${NC}"
    echo ""
    
    # Check if TPM is available
    if [ ! -e /dev/tpm0 ] && [ ! -e /dev/tpmrm0 ]; then
        echo -e "${RED}✗ No TPM device found!${NC}"
        echo "  Please ensure TPM is enabled in BIOS/UEFI"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}Checking TPM status...${NC}"
    echo ""
    
    # Try to read existing endorsement key
    tpm2_readpublic -Q -c 0x81010001 -o ek.pub 2> /dev/null
    
    if [ $? -gt 0 ]; then
        # EK doesn't exist, need to create it
        echo "Initializing TPM (first-time setup)..."
        echo ""
        
        # Create the endorsement key (EK)
        echo "  → Creating endorsement key..."
        tpm2_createek -c 0x81010001 -G rsa -u ek.pub
        
        if [ $? -gt 0 ]; then
            echo -e "${RED}✗ Failed to create endorsement key${NC}"
            rm -f ek.pub 2> /dev/null
            return 1
        fi
        
        # Create the storage root key (SRK)
        echo "  → Creating storage root key..."
        tpm2_createprimary -Q -C o -c srk.ctx > /dev/null
        
        # Make the SRK persistent
        echo "  → Making SRK persistent..."
        tpm2_evictcontrol -c srk.ctx 0x81000001 > /dev/null
        
        # Open transient handle space for the TPM
        tpm2_flushcontext -t > /dev/null
        
        echo -e "  ${GREEN}✓ TPM initialized successfully!${NC}"
        echo ""
    else
        echo -e "  ${GREEN}✓ TPM already initialized${NC}"
        echo ""
    fi
    
    # Extract registration information
    echo "Gathering registration information..."
    echo ""
    
    # Calculate Registration ID (SHA256 of endorsement key)
    REGISTRATION_ID=$(sha256sum -b ek.pub | cut -d' ' -f1 | sed -e 's/[^[:alnum:]]//g')
    
    # Get Endorsement Key (base64 encoded)
    ENDORSEMENT_KEY=$(base64 -w0 ek.pub)
    
    # Display results
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│         DEVICE REGISTRATION INFO           │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Registration ID:${NC}"
    echo "$REGISTRATION_ID"
    echo ""
    echo -e "${CYAN}Endorsement Key:${NC}"
    echo "$ENDORSEMENT_KEY"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📧 Next Steps:${NC}"
    echo "   1. Copy both values above"
    echo "   2. Send to your Azure administrator"
    echo "   3. They will create a DPS enrollment using:"
    echo "      - Registration ID (shown above)"
    echo "      - Endorsement Key (shown above)"
    echo ""
    
    # Clean up temporary files
    rm -f ek.pub srk.ctx 2> /dev/null
    
    echo -e "${GREEN}✓ Complete!${NC}"
    echo ""
    
    return 0
}

# Persist IoT Edge storage to host filesystem
persist_iot_edge_storage() {
    echo -e "${BLUE}[STEP 7] Configuring Persistent IoT Edge Storage${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    echo -e "${GREEN}[1/3] Creating persistent storage directories...${NC}"
    
    # Create directories on host for persistent storage
    mkdir -p /var/lib/iotedge/edgeAgent
    mkdir -p /var/lib/iotedge/edgeHub
    
    # Set proper permissions
    chown -R iotedge:iotedge /var/lib/iotedge 2>/dev/null || true
    chmod -R 755 /var/lib/iotedge
    
    echo "  ✓ Created: /var/lib/iotedge/edgeAgent"
    echo "  ✓ Created: /var/lib/iotedge/edgeHub"
    
    # Create environment file for IoT Edge modules
    echo ""
    echo -e "${GREEN}[2/3] Configuring IoT Edge environment variables...${NC}"
    
    # This will be used by the deployment manifest to configure volume mounts
    cat > /etc/systemd/system/iotedge.service.d/persistent-storage.conf <<'EOF'
[Service]
Environment="EDGEAGENT_STORAGE_PATH=/var/lib/iotedge/edgeAgent"
Environment="EDGEHUB_STORAGE_PATH=/var/lib/iotedge/edgeHub"
EOF
    
    echo "  ✓ Created systemd drop-in configuration"
    
    # Reload systemd to pick up changes
    echo ""
    echo -e "${GREEN}[3/3] Reloading systemd configuration...${NC}"
    systemctl daemon-reload
    echo "  ✓ Systemd configuration reloaded"
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ Persistent storage configured${NC}"
    echo ""
    echo -e "${CYAN}ℹ️  To use persistent storage in your deployment manifest:${NC}"
    echo ""
    echo "For edgeAgent, add to createOptions:"
    echo '  "HostConfig": {'
    echo '    "Binds": ["/var/lib/iotedge/edgeAgent:/tmp/edgeAgent"]'
    echo '  }'
    echo ""
    echo "For edgeHub, add to createOptions:"
    echo '  "HostConfig": {'
    echo '    "Binds": ["/var/lib/iotedge/edgeHub:/tmp/edgeHub"]'
    echo '  }'
    echo ""
    return 0
}

# Helper function to update Docker DNS configuration
update_docker_dns() {
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        echo -e "  ${YELLOW}⚠ Docker not installed, skipping Docker DNS update${NC}"
        return 0
    fi
    
    # Detect DNS servers from current configuration
    DNS_SERVERS=()
    
    # Try to get DNS from systemd-resolved
    if systemctl is-active systemd-resolved &>/dev/null; then
        DETECTED_DNS=$(resolvectl status 2>/dev/null | grep "DNS Servers:" -A 3 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -3)
        if [ -n "$DETECTED_DNS" ]; then
            while IFS= read -r dns_ip; do
                # Skip loopback addresses
                if [[ "$dns_ip" != "127."* ]]; then
                    DNS_SERVERS+=("\"$dns_ip\"")
                fi
            done <<< "$DETECTED_DNS"
        fi
    fi
    
    # Fallback to resolv.conf if no DNS found yet
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        DETECTED_DNS=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3)
        if [ -n "$DETECTED_DNS" ]; then
            while IFS= read -r dns_ip; do
                # Skip loopback addresses
                if [[ "$dns_ip" != "127."* ]]; then
                    DNS_SERVERS+=("\"$dns_ip\"")
                fi
            done <<< "$DETECTED_DNS"
        fi
    fi
    
    # Final fallback to Google DNS
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        DNS_SERVERS=("\"8.8.8.8\"" "\"8.8.4.4\"")
        echo "  ⚠ No DNS servers detected, using Google DNS (8.8.8.8, 8.8.4.4)"
    else
        echo "  ✓ Detected DNS servers: ${DNS_SERVERS[@]//\"/}"
    fi
    
    # Build DNS JSON array
    DNS_JSON=$(IFS=,; echo "${DNS_SERVERS[*]}")
    
    # Backup existing daemon.json
    if [ -f /etc/docker/daemon.json ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup-$(date +%s)
        echo "  ✓ Backed up existing Docker configuration"
        
        # Read existing config and update DNS
        if command -v jq &>/dev/null; then
            # Use jq if available for safer JSON manipulation
            jq ".dns = [$DNS_JSON]" /etc/docker/daemon.json > /etc/docker/daemon.json.tmp
            mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
        else
            # Fallback: simple sed replacement (less safe but works)
            # Remove existing "dns" line if present
            sed -i '/"dns":/d' /etc/docker/daemon.json
            # Add new "dns" line after the opening brace
            sed -i "1 a\  \"dns\": [$DNS_JSON]," /etc/docker/daemon.json
        fi
    else
        # Create new daemon.json with DNS
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json <<EOF
{
  "dns": [$DNS_JSON],
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
    fi
    
    echo "  ✓ Updated Docker DNS configuration"
    
    # Restart Docker to apply changes
    echo "  Restarting Docker..."
    systemctl restart docker 2>&1 | tail -3
    
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ Docker restarted with new DNS settings${NC}"
    else
        echo -e "  ${YELLOW}⚠ Docker restart may have issues - check 'systemctl status docker'${NC}"
    fi
}

# Configure DNS resolution
configure_dns() {
    echo -e "${BLUE}[DNS CONFIGURATION]${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    # Show current DNS configuration
    echo -e "${GREEN}[1/5] Checking current DNS configuration...${NC}"
    echo ""
    
    # Check if systemd-resolved is active
    if systemctl is-active systemd-resolved &>/dev/null; then
        echo "  Current DNS (from systemd-resolved):"
        resolvectl status 2>/dev/null | grep "DNS Servers:" | head -5 | sed 's/^/    /'
    else
        echo "  Current DNS (from /etc/resolv.conf):"
        grep "^nameserver" /etc/resolv.conf 2>/dev/null | sed 's/^/    /' || echo "    (none configured)"
    fi
    
    # Test current DNS
    echo ""
    echo "  Testing current DNS resolution..."
    if timeout 3 nslookup google.com &>/dev/null; then
        echo -e "  ${GREEN}✓ DNS is working${NC}"
    else
        echo -e "  ${YELLOW}⚠ DNS resolution failed${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}[2/5] Choose DNS configuration:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${CYAN}Use DHCP/Automatic DNS${NC} (default)"
    echo "     • Let DHCP server provide DNS settings"
    echo "     • Recommended for most environments"
    echo "     • No manual configuration needed"
    echo ""
    echo -e "  ${GREEN}2${NC}) ${CYAN}Configure Custom DNS Servers${NC}"
    echo "     • Manually specify DNS server IP addresses"
    echo "     • Use for corporate/private DNS"
    echo "     • Examples: 8.8.8.8, 1.1.1.1, or your local DNS"
    echo ""
    echo -e "  ${GREEN}3${NC}) Show current configuration and exit"
    echo ""
    read -p "Select option (1-3): " dns_choice
    echo ""
    
    case $dns_choice in
        1)
            echo -e "${GREEN}[3/5] Configuring automatic DNS (DHCP)...${NC}"
            echo ""
            
            # Find the primary network interface
            PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
            
            if [ -z "$PRIMARY_INTERFACE" ]; then
                echo -e "${RED}✗ Could not detect primary network interface${NC}"
                set -e
                return 1
            fi
            
            echo "  Detected interface: $PRIMARY_INTERFACE"
            
            # Backup existing netplan configuration
            if [ -f /etc/netplan/01-netcfg.yaml ]; then
                cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup-$(date +%s)
                echo "  ✓ Backed up existing netplan configuration"
            fi
            
            # Create netplan configuration with DHCP
            cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $PRIMARY_INTERFACE:
      dhcp4: true
      dhcp6: false
      optional: true
EOF
            
            echo "  ✓ Created netplan configuration for automatic DNS"
            echo ""
            echo -e "${GREEN}[4/5] Applying system DNS configuration...${NC}"
            
            # Apply netplan configuration
            netplan apply 2>&1 | tail -5
            
            if [ $? -eq 0 ]; then
                echo "  ✓ Configuration applied successfully"
                
                # Wait for DNS to update
                echo ""
                echo "  Waiting for DNS to update (5 seconds)..."
                sleep 5
                
                # Test DNS
                echo ""
                echo "  Testing DNS resolution..."
                if timeout 3 nslookup google.com &>/dev/null; then
                    echo -e "  ${GREEN}✓ DNS is working!${NC}"
                else
                    echo -e "  ${YELLOW}⚠ DNS test failed${NC}"
                    echo "  This may be temporary - try 'sudo resolvectl flush-caches'"
                fi
                
                # Update Docker DNS
                echo ""
                echo -e "${GREEN}[5/5] Updating Docker DNS configuration...${NC}"
                update_docker_dns
                
                echo ""
                echo -e "${GREEN}✓ Automatic DNS configured${NC}"
            else
                echo -e "${RED}✗ Failed to apply netplan configuration${NC}"
                echo "  Restoring backup..."
                if [ -f /etc/netplan/01-netcfg.yaml.backup-* ]; then
                    mv /etc/netplan/01-netcfg.yaml.backup-* /etc/netplan/01-netcfg.yaml
                fi
                set -e
                return 1
            fi
            ;;
            
        2)
            echo -e "${GREEN}[3/5] Configuring custom DNS servers...${NC}"
            echo ""
            
            # Prompt for DNS servers
            echo "Enter DNS server IP addresses (one per line, blank line to finish):"
            echo "Examples: 8.8.8.8, 1.1.1.1, 192.168.1.1"
            echo ""
            
            DNS_SERVERS=()
            while true; do
                read -p "DNS Server ${#DNS_SERVERS[@]}: " dns_ip
                
                # Break on empty input
                if [ -z "$dns_ip" ]; then
                    break
                fi
                
                # Validate IP address format
                if echo "$dns_ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
                    DNS_SERVERS+=("$dns_ip")
                    echo "  ✓ Added: $dns_ip"
                else
                    echo -e "  ${YELLOW}⚠ Invalid IP format, skipping${NC}"
                fi
                
                # Stop after 3 servers
                if [ ${#DNS_SERVERS[@]} -ge 3 ]; then
                    echo "  Maximum 3 DNS servers, continuing..."
                    break
                fi
            done
            
            # Check if any DNS servers were added
            if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
                echo -e "${RED}✗ No valid DNS servers provided${NC}"
                set -e
                return 1
            fi
            
            echo ""
            echo "Configured DNS servers:"
            for dns in "${DNS_SERVERS[@]}"; do
                echo "  • $dns"
            done
            echo ""
            
            # Find the primary network interface
            PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
            
            if [ -z "$PRIMARY_INTERFACE" ]; then
                echo -e "${RED}✗ Could not detect primary network interface${NC}"
                set -e
                return 1
            fi
            
            echo "  Detected interface: $PRIMARY_INTERFACE"
            
            # Backup existing netplan configuration
            if [ -f /etc/netplan/01-netcfg.yaml ]; then
                cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup-$(date +%s)
                echo "  ✓ Backed up existing netplan configuration"
            fi
            
            # Build nameservers YAML array
            NAMESERVERS_YAML=""
            for dns in "${DNS_SERVERS[@]}"; do
                NAMESERVERS_YAML+="        - $dns"$'\n'
            done
            
            # Create netplan configuration with custom DNS
            cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $PRIMARY_INTERFACE:
      dhcp4: true
      dhcp6: false
      dhcp4-overrides:
        use-dns: false
      nameservers:
        addresses:
$NAMESERVERS_YAML
      optional: true
EOF
            
            echo "  ✓ Created netplan configuration with custom DNS"
            echo ""
            echo -e "${GREEN}[4/5] Applying system DNS configuration...${NC}"
            
            # Apply netplan configuration
            netplan apply 2>&1 | tail -5
            
            if [ $? -eq 0 ]; then
                echo "  ✓ Configuration applied successfully"
                
                # Wait for DNS to update
                echo ""
                echo "  Waiting for DNS to update (5 seconds)..."
                sleep 5
                
                # Flush DNS cache
                resolvectl flush-caches 2>/dev/null || true
                
                # Test DNS
                echo ""
                echo "  Testing DNS resolution..."
                if timeout 3 nslookup google.com &>/dev/null; then
                    echo -e "  ${GREEN}✓ DNS is working!${NC}"
                    
                    # Show which DNS server answered
                    DNS_SERVER_USED=$(nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}')
                    if [ -n "$DNS_SERVER_USED" ]; then
                        echo "  Using DNS server: $DNS_SERVER_USED"
                    fi
                else
                    echo -e "  ${YELLOW}⚠ DNS test failed${NC}"
                    echo "  Possible issues:"
                    echo "    • DNS server IP incorrect"
                    echo "    • DNS server not reachable"
                    echo "    • Firewall blocking DNS (port 53)"
                fi
                
                # Update Docker DNS
                echo ""
                echo -e "${GREEN}[5/5] Updating Docker DNS configuration...${NC}"
                update_docker_dns
                
                echo ""
                echo -e "${GREEN}✓ Custom DNS configured${NC}"
            else
                echo -e "${RED}✗ Failed to apply netplan configuration${NC}"
                echo "  Restoring backup..."
                if [ -f /etc/netplan/01-netcfg.yaml.backup-* ]; then
                    mv /etc/netplan/01-netcfg.yaml.backup-* /etc/netplan/01-netcfg.yaml
                fi
                set -e
                return 1
            fi
            ;;
            
        3)
            echo -e "${CYAN}Current DNS Configuration:${NC}"
            echo ""
            
            # Show netplan config
            if [ -f /etc/netplan/01-netcfg.yaml ]; then
                echo "Netplan configuration (/etc/netplan/01-netcfg.yaml):"
                cat /etc/netplan/01-netcfg.yaml | sed 's/^/  /'
                echo ""
            fi
            
            # Show systemd-resolved status
            if systemctl is-active systemd-resolved &>/dev/null; then
                echo "Active DNS servers (systemd-resolved):"
                resolvectl status 2>/dev/null | grep -A 10 "DNS Servers:" | sed 's/^/  /'
            else
                echo "DNS from /etc/resolv.conf:"
                cat /etc/resolv.conf | sed 's/^/  /'
            fi
            
            echo ""
            ;;
            
        *)
            echo -e "${RED}Invalid option${NC}"
            set -e
            return 1
            ;;
    esac
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    return 0
}

# Configure update policy
configure_update_policy() {
    echo -e "${BLUE}[UPDATE POLICY CONFIGURATION]${NC}"
    echo ""
    echo -e "${CYAN}Choose how system updates are handled:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${CYAN}Security auto-update with auto-reboot${NC} (recommended for production)"
    echo "     • Security patches installed automatically at 3 AM CST (9 AM UTC)"
    echo "     • System reboots automatically if needed (3:30 AM CST / 9:30 AM UTC)"
    echo "     • Most secure - updates are immediately active"
    echo "     • Minimal downtime (~12-17 minutes during update window)"
    echo ""
    echo -e "  ${GREEN}2${NC}) ${CYAN}Manual updates only${NC}"
    echo "     • All updates require manual trigger"
    echo "     • Update via 'sudo apt update && sudo apt upgrade'"
    echo "     • Operator must reboot manually when needed"
    echo "     • Best for test environments or strict change control"
    echo ""
    echo -e "  ${GREEN}3${NC}) ${YELLOW}All auto-updates with reboot${NC} (not recommended for production)"
    echo "     • All updates (security + feature) installed automatically at 3 AM CST"
    echo "     • System reboots automatically if needed (3:30 AM CST)"
    echo "     • ⚠️  May introduce unexpected changes"
    echo "     • Only use in development environments"
    echo ""
    echo -e "  ${GREEN}4${NC}) Show current policy"
    echo ""
    read -p "Select option (1-4): " choice
    echo ""
    
    case $choice in
        1)
            echo -e "${GREEN}Configuring security auto-update with auto-reboot...${NC}"
            echo ""
            
            # Wait for package manager
            wait_for_package_manager || return 1
            
            # Install unattended-upgrades
            echo "Installing unattended-upgrades package..."
            apt-get install -y unattended-upgrades apt-listchanges 2>&1 | tail -5
            
            # Configure for security updates only with auto-reboot
            echo "Configuring for security updates with automatic reboot..."
            cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
// Automatic security updates for IoT Edge devices
// Configuration for OpenPoint SCADA Polling Module

Unattended-Upgrade::Allowed-Origins {
    // Security updates only - no feature updates
    "${distro_id}:${distro_codename}-security";
    
    // Commented out: feature/bug fix updates
    // "${distro_id}:${distro_codename}-updates";
};

// Automatically get security updates
Unattended-Upgrade::DevRelease "false";

// Split upgrade into minimal steps (more reliable)
Unattended-Upgrade::MinimalSteps "true";

// Install updates on shutdown (safer than during operation)
Unattended-Upgrade::InstallOnShutdown "false";

// Automatically reboot if required (during maintenance window)
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "09:30";

// Email notification (configure your email)
// Unattended-Upgrade::Mail "ops@openpoint.com";
// Unattended-Upgrade::MailReport "on-change";

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically fix interrupted dpkg
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Log to syslog
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
            
            # Configure update schedule (3 AM CST = 9 AM UTC)
            cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
// Update schedule for security patches
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
            
            # Set specific time (9 AM UTC = 3 AM CST)
            systemctl edit --full --force apt-daily.timer > /dev/null 2>&1 <<'EOF'
[Unit]
Description=Daily apt download activities

[Timer]
OnCalendar=09:00
RandomizedDelaySec=0
Persistent=true

[Install]
WantedBy=timers.target
EOF
            
            # Enable the service
            systemctl enable unattended-upgrades > /dev/null 2>&1
            systemctl start unattended-upgrades > /dev/null 2>&1
            
            echo ""
            echo -e "${GREEN}✓ Security auto-update with auto-reboot enabled${NC}"
            echo ""
            echo "Configuration:"
            echo "  • Security updates: Automatic (daily at 9 AM UTC / 3 AM CST)"
            echo "  • Feature updates: Manual"
            echo "  • Auto-reboot: Enabled (at 9:30 AM UTC / 3:30 AM CST if needed)"
            echo "  • Email notifications: Disabled (uncomment in config to enable)"
            echo ""
            echo "Update window: 9:00 AM - 11:00 AM UTC (3:00 AM - 5:00 AM CST)"
            echo "  - Updates install: 9:00-9:30 AM UTC (3:00-3:30 AM CST)"
            echo "  - Reboot if needed: 9:30 AM UTC (3:30 AM CST)"
            echo "  - System ready: ~9:35 AM UTC (~3:35 AM CST)"
            echo ""
            echo "To view update logs:"
            echo "  tail -100 /var/log/unattended-upgrades/unattended-upgrades.log"
            ;;
            
        2)
            echo -e "${GREEN}Configuring manual updates only...${NC}"
            echo ""
            
            # Stop and disable automatic updates
            systemctl stop unattended-upgrades 2>/dev/null || true
            systemctl disable unattended-upgrades 2>/dev/null || true
            systemctl mask unattended-upgrades 2>/dev/null || true
            systemctl stop apt-daily.timer 2>/dev/null || true
            systemctl disable apt-daily.timer 2>/dev/null || true
            systemctl mask apt-daily.timer 2>/dev/null || true
            systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
            systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
            systemctl mask apt-daily-upgrade.timer 2>/dev/null || true
            
            echo -e "${GREEN}✓ Automatic updates disabled${NC}"
            echo ""
            echo "All updates now require manual action:"
            echo ""
            echo "Option 1: Local manual update"
            echo "  sudo apt update && sudo apt upgrade -y"
            echo "  sudo reboot  # If /var/run/reboot-required exists"
            echo ""
            echo "Option 2: Use setup script"
            echo "  sudo bash ./setup-iot-edge-device.sh"
            echo "  (then select option 3: System Updates)"
            echo ""
            ;;
            
        3)
            echo -e "${YELLOW}Configuring all auto-updates with reboot...${NC}"
            echo ""
            
            # Wait for package manager
            wait_for_package_manager || return 1
            
            # Install unattended-upgrades
            echo "Installing unattended-upgrades package..."
            apt-get install -y unattended-upgrades apt-listchanges 2>&1 | tail -5
            
            # Configure for ALL updates with auto-reboot
            echo "Configuring for all updates with automatic reboot..."
            cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
// Automatic updates (ALL) for IoT Edge devices
// Configuration for OpenPoint SCADA Polling Module
// WARNING: Not recommended for production

Unattended-Upgrade::Allowed-Origins {
    // Security updates
    "${distro_id}:${distro_codename}-security";
    
    // Feature/bug fix updates (ENABLED - may cause unexpected changes)
    "${distro_id}:${distro_codename}-updates";
};

// Automatically get all updates
Unattended-Upgrade::DevRelease "false";

// Split upgrade into minimal steps (more reliable)
Unattended-Upgrade::MinimalSteps "true";

// Install updates on shutdown (safer than during operation)
Unattended-Upgrade::InstallOnShutdown "false";

// Automatically reboot if required
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "09:30";

// Email notification (configure your email)
// Unattended-Upgrade::Mail "ops@openpoint.com";
// Unattended-Upgrade::MailReport "on-change";

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically fix interrupted dpkg
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Log to syslog
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
            
            # Configure update schedule (3 AM CST = 9 AM UTC)
            cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
// Update schedule for all updates
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
            
            # Set specific time (9 AM UTC = 3 AM CST)
            systemctl edit --full --force apt-daily.timer > /dev/null 2>&1 <<'EOF'
[Unit]
Description=Daily apt download activities

[Timer]
OnCalendar=09:00
RandomizedDelaySec=0
Persistent=true

[Install]
WantedBy=timers.target
EOF
            
            # Enable the service
            systemctl enable unattended-upgrades > /dev/null 2>&1
            systemctl start unattended-upgrades > /dev/null 2>&1
            
            echo ""
            echo -e "${YELLOW}✓ All auto-updates with auto-reboot enabled${NC}"
            echo ""
            echo "Configuration:"
            echo "  • Security updates: Automatic (daily at 9 AM UTC / 3 AM CST)"
            echo "  • Feature updates: Automatic (daily at 9 AM UTC / 3 AM CST)"
            echo "  • Auto-reboot: Enabled (at 9:30 AM UTC / 3:30 AM CST if needed)"
            echo ""
            echo -e "${YELLOW}⚠️  WARNING: This may introduce unexpected changes${NC}"
            echo -e "${YELLOW}   Not recommended for production systems${NC}"
            echo ""
            echo "To view update logs:"
            echo "  tail -100 /var/log/unattended-upgrades/unattended-upgrades.log"
            ;;
            
        4)
            echo -e "${CYAN}Current Update Policy:${NC}"
            echo ""
            
            # Check unattended-upgrades status
            if systemctl is-enabled unattended-upgrades &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} unattended-upgrades: enabled"
                
                if systemctl is-active unattended-upgrades &>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} Service status: active"
                else
                    echo -e "  ${YELLOW}⚠${NC} Service status: inactive"
                fi
                
                # Show configured sources
                if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
                    echo ""
                    echo "  Allowed update sources:"
                    grep "Allowed-Origins" -A 10 /etc/apt/apt.conf.d/50unattended-upgrades | \
                        grep "${distro_id}" | sed 's/^/    /'
                fi
                
                # Show auto-reboot setting
                if grep -q "Automatic-Reboot.*true" /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
                    echo -e "  ${YELLOW}⚠${NC} Auto-reboot: enabled"
                else
                    echo -e "  ${GREEN}✓${NC} Auto-reboot: disabled"
                fi
            else
                echo -e "  ${YELLOW}⚠${NC} unattended-upgrades: disabled"
                echo "    All updates require manual action"
            fi
            
            # Check scheduled update timers
            echo ""
            echo "  Scheduled update timers:"
            if systemctl is-active apt-daily.timer &>/dev/null; then
                NEXT_RUN=$(systemctl status apt-daily.timer 2>/dev/null | grep "Trigger:" | awk '{print $2, $3, $4}')
                echo -e "  ${GREEN}✓${NC} apt-daily.timer: active (next: ${NEXT_RUN})"
            else
                echo -e "  ${YELLOW}⚠${NC} apt-daily.timer: inactive"
            fi
            
            # Check for pending updates
            echo ""
            echo "  Checking for available updates..."
            apt-get update -qq 2>&1 > /dev/null
            UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing" | wc -l)
            
            if [ "$UPDATES" -gt 0 ]; then
                echo -e "  ${YELLOW}⚠${NC} Updates available: ${UPDATES}"
                echo "    Run 'apt list --upgradable' to see details"
            else
                echo -e "  ${GREEN}✓${NC} System is up to date"
            fi
            
            # Check reboot status
            if [ -f /var/run/reboot-required ]; then
                echo ""
                echo -e "  ${YELLOW}⚠${NC} Reboot required after previous updates"
                echo "    Packages requiring reboot:"
                cat /var/run/reboot-required.pkgs | sed 's/^/      /'
            fi
            
            echo ""
            ;;
            
        *)
            echo -e "${RED}Invalid option${NC}"
            return 1
            ;;
    esac
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
    
    # Clean config files after optimization to remove any duplicates
    # This ensures clean config before Docker and IoT Edge installation
    cleanup_duplicates
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
    
    persist_iot_edge_storage
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
    echo "   ✓ Persistent storage configured"
    echo ""
    echo -e "${YELLOW}⚠️  Please reboot the system:${NC}"
    echo "   sudo reboot"
    echo ""
    echo "After reboot, run this script again and select:"
    echo "   11. Extract TPM Key - Get registration ID and endorsement key"
    echo ""
    echo "To view container logs:"
    echo "   docker logs -f <container_name>"
    echo "   docker logs -f ScadaPollingModule"
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
                persist_iot_edge_storage
                read -p "Press ENTER to return to menu..." dummy
                ;;
            8)
                configure_dns
                read -p "Press ENTER to return to menu..." dummy
                ;;
            9)
                cleanup_duplicates
                echo -e "${GREEN}✓ Cleanup complete${NC}"
                read -p "Press ENTER to return to menu..." dummy
                ;;
            10)
                configure_update_policy
                read -p "Press ENTER to return to menu..." dummy
                ;;
            11)
                extract_tpm_key
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
