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
    echo -e "  ${GREEN}12${NC}) Enable TPM Hardware - Enable Nuvoton NPCT750 TPM SPI overlay (requires reboot)"
    echo -e "  ${GREEN}13${NC}) ${YELLOW}Repair IoT Edge${NC} - Purge and clean reinstall (fixes broken installs)"
    echo -e "  ${GREEN}14${NC}) ${CYAN}Pre-Provision Health Check${NC} - Verify install is clean before connecting to Azure"
    echo -e "  ${GREEN}15${NC}) ${RED}Quarantine Device${NC} - Immediately stop & disable all Azure IoT services"
    echo -e "  ${GREEN}16${NC}) ${GREEN}Apply Config${NC} - Safely apply config.toml (generates certs, patches config, then applies)"
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
    
    # Hold aziot packages so apt-get upgrade doesn't break them.
    # A blanket upgrade can remove aziot binaries mid-flight, leaving
    # service units intact but no executables — the exact failure mode
    # that causes "aziot-edged binary not found" after reboot.
    local HELD_PACKAGES=()
    for pkg in aziot-edge aziot-identity-service; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            apt-mark hold "$pkg" > /dev/null 2>&1 && HELD_PACKAGES+=("$pkg")
        fi
    done
    if [ ${#HELD_PACKAGES[@]} -gt 0 ]; then
        echo "  ℹ️  Held packages during upgrade: ${HELD_PACKAGES[*]}"
    fi
    
    if ! apt-get upgrade -y --fix-missing 2>&1 | tail -20; then
        echo -e "${RED}  ✗ Failed to upgrade packages${NC}"
        echo "  Continuing anyway..."
    else
        echo "  ✓ System packages updated"
    fi
    
    # Unhold aziot packages
    for pkg in "${HELD_PACKAGES[@]}"; do
        apt-mark unhold "$pkg" > /dev/null 2>&1
    done
    
    # Safety net: fix any broken packages left by a partial upgrade
    apt-get --fix-broken install -y > /dev/null 2>&1
    
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

# Generate Edge CA and trust bundle certificates.
#
# IoT Edge's internal "quickstart" cert auto-generation can fail silently
# on some platforms (ARM64 + Ubuntu 24.04), producing:
#   "could not load cert with id aziot-edged-trust-bundle
#    -- parameter id has an invalid value"
#
# By providing explicit cert files and referencing them in config.toml,
# we tell certd to import known-good certificates instead of relying on
# the internal generation. This completely bypasses the quickstart path.
#
# Generated files:
#   /etc/aziot/certificates/edge-ca.pem      — Edge CA certificate
#   /etc/aziot/certificates/edge-ca-key.pem  — Edge CA private key
#   /etc/aziot/certificates/trust-bundle.pem — Trust bundle (= CA cert)
generate_edge_certificates() {
    local CERT_DIR="/etc/aziot/certificates"
    
    # Check if certs already exist and are valid (not expired within 24h)
    if [ -f "$CERT_DIR/edge-ca.pem" ] && \
       [ -f "$CERT_DIR/edge-ca-key.pem" ] && \
       [ -f "$CERT_DIR/trust-bundle.pem" ]; then
        if openssl x509 -checkend 86400 -noout -in "$CERT_DIR/edge-ca.pem" 2>/dev/null; then
            echo "  ✓ Edge certificates exist and are valid"
            return 0
        else
            echo -e "${YELLOW}  ⚠ Edge CA cert expired or invalid, regenerating...${NC}"
        fi
    fi
    
    echo "  Generating Edge CA certificate and trust bundle..."
    mkdir -p "$CERT_DIR"
    
    # Generate a self-signed CA cert (used as both Edge CA and trust bundle).
    # RSA 4096 is strong enough for production and fast on ARM64.
    # 730 days (~2 years) is typical for IoT Edge deployments.
    if ! openssl req -x509 -newkey rsa:4096 \
        -keyout "$CERT_DIR/edge-ca-key.pem" \
        -out "$CERT_DIR/edge-ca.pem" \
        -sha256 -days 730 -nodes \
        -subj "/CN=IoT Edge Device CA" 2>/dev/null; then
        echo -e "${RED}  ✗ Failed to generate Edge CA certificate${NC}"
        echo "    Verify openssl is installed: openssl version"
        return 1
    fi
    
    # Trust bundle = the CA cert itself.
    # edgeHub's server cert will be signed by this CA, and modules need
    # the trust bundle to verify edgeHub's TLS identity.
    cp "$CERT_DIR/edge-ca.pem" "$CERT_DIR/trust-bundle.pem"
    
    # Set ownership so aziot services can read the files:
    #   certd (aziotcs) reads: trust-bundle.pem, edge-ca.pem
    #   keyd  (aziotks) reads: edge-ca-key.pem
    if id -u aziotcs &>/dev/null; then
        chown aziotcs:aziotcs "$CERT_DIR/edge-ca.pem" "$CERT_DIR/trust-bundle.pem"
    fi
    if id -u aziotks &>/dev/null; then
        chown aziotks:aziotks "$CERT_DIR/edge-ca-key.pem"
    fi
    chmod 0444 "$CERT_DIR/edge-ca.pem" "$CERT_DIR/trust-bundle.pem"
    chmod 0400 "$CERT_DIR/edge-ca-key.pem"
    
    echo "  ✓ Generated Edge CA cert and trust bundle (valid 730 days)"
    echo "    $CERT_DIR/edge-ca.pem"
    echo "    $CERT_DIR/edge-ca-key.pem"
    echo "    $CERT_DIR/trust-bundle.pem"
    return 0
}

# Ensure config.toml references explicit Edge CA and trust bundle certificates.
#
# When trust_bundle_cert and [edge_ca] are set in config.toml, "iotedge config
# apply" imports our cert files as preloaded certs instead of triggering the
# internal quickstart cert generation. This resolves the trust bundle error:
#   "could not load cert with id aziot-edged-trust-bundle
#    -- parameter id has an invalid value"
#
# This function is safe to call multiple times — it only modifies config.toml
# if the settings are missing.
patch_config_trust_bundle() {
    local CONFIG="/etc/aziot/config.toml"
    local CERT_DIR="/etc/aziot/certificates"
    
    # Only patch if config.toml exists (user has started provisioning)
    if [ ! -f "$CONFIG" ]; then
        return 0
    fi
    
    # Only patch if our cert files exist
    if [ ! -f "$CERT_DIR/trust-bundle.pem" ] || \
       [ ! -f "$CERT_DIR/edge-ca.pem" ] || \
       [ ! -f "$CERT_DIR/edge-ca-key.pem" ]; then
        return 0
    fi
    
    local CHANGED=0
    
    # ── trust_bundle_cert (top-level setting) ──
    if grep -q '^trust_bundle_cert\s*=' "$CONFIG" 2>/dev/null; then
        # Already set (uncommented) — update the value
        sed -i 's|^trust_bundle_cert\s*=.*|trust_bundle_cert = "file:///etc/aziot/certificates/trust-bundle.pem"|' "$CONFIG"
        CHANGED=1
    elif grep -q '#.*trust_bundle_cert' "$CONFIG" 2>/dev/null; then
        # Commented out in template — add active line after the comment
        sed -i '/#.*trust_bundle_cert/a trust_bundle_cert = "file:///etc/aziot/certificates/trust-bundle.pem"' "$CONFIG"
        CHANGED=1
    else
        # Not present at all — insert before the first [section] header
        local FIRST_SECTION_LINE
        FIRST_SECTION_LINE=$(grep -n '^\[' "$CONFIG" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_SECTION_LINE" ]; then
            sed -i "${FIRST_SECTION_LINE}i trust_bundle_cert = \"file:///etc/aziot/certificates/trust-bundle.pem\"" "$CONFIG"
        else
            echo '' >> "$CONFIG"
            echo 'trust_bundle_cert = "file:///etc/aziot/certificates/trust-bundle.pem"' >> "$CONFIG"
        fi
        CHANGED=1
    fi
    
    # ── [edge_ca] section ──
    if ! grep -q '^\[edge_ca\]' "$CONFIG" 2>/dev/null; then
        cat >> "$CONFIG" <<'EDGECA'

[edge_ca]
cert = "file:///etc/aziot/certificates/edge-ca.pem"
pk = "file:///etc/aziot/certificates/edge-ca-key.pem"
EDGECA
        CHANGED=1
    fi
    
    if [ $CHANGED -eq 1 ]; then
        echo "  ✓ Patched config.toml with explicit Edge CA and trust bundle"
    fi
    return 0
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
        
        # Repair any broken dpkg state before installing.
        # If a previous apt-get upgrade partially removed aziot packages,
        # dpkg will be in a half-configured state and the install below
        # will fail. --fix-broken resolves this first.
        echo ""
        echo "  Checking for broken packages..."
        apt-get --fix-broken install -y 2>&1 | tail -5
        
        # Clean up stale Docker state from a previous broken install.
        # When aziot-edge breaks mid-upgrade, the binaries are gone but
        # Docker still has orphaned edgeAgent/edgeHub containers and the
        # azure-iot-edge network. If we reinstall without cleaning these,
        # IoT Edge may fail to start because Docker refuses to recreate
        # resources that already exist.
        if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
            echo ""
            echo "  Cleaning stale Docker state from previous install..."
            for container in edgeAgent edgeHub; do
                if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -qx "$container"; then
                    docker rm -f "$container" 2>/dev/null
                    echo "  ✓ Removed orphaned container: $container"
                fi
            done
            if docker network ls --format "{{.Name}}" 2>/dev/null | grep -qx "azure-iot-edge"; then
                docker network rm azure-iot-edge 2>/dev/null
                echo "  ✓ Removed stale network: azure-iot-edge"
            fi
        fi
        
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
    
    # Verify critical directories exist (catches broken/partial installs)
    # iotedge config apply writes to /etc/aziot/edged/config.d/00-super.toml
    # If these directories are missing, config apply will fail silently and
    # iotedge list will stall indefinitely because services can't start
    echo ""
    echo "  Verifying IoT Edge config directories..."
    local DIRS_OK=1
    for dir in /etc/aziot /etc/aziot/edged/config.d /etc/aziot/keyd/config.d /etc/aziot/certd/config.d /etc/aziot/identityd/config.d; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}  ✗ Missing directory: $dir${NC}"
            mkdir -p "$dir"
            echo -e "${GREEN}  ✓ Created: $dir${NC}"
            DIRS_OK=0
        fi
    done
    
    # Verify runtime directories exist with correct ownership.
    # These hold certificates (trust bundle), private keys, and service state.
    # Without them, aziot-certd cannot store the trust bundle certificate and
    # "iotedge config apply" fails with:
    #   "could not load cert with id aziot-edged-trust-bundle -- not found"
    #
    # Each aziot service runs as a dedicated user and needs its own dirs:
    #   aziot-keyd   → aziotks
    #   aziot-certd  → aziotcs
    #   aziot-identityd → aziotid
    #   aziot-edged  → iotedge
    echo ""
    echo "  Verifying IoT Edge runtime directories..."
    
    # Format: "directory:owner:group"
    local RUNTIME_DIRS=(
        "/var/lib/aziot/keyd:aziotks:aziotks"
        "/var/lib/aziot/certd:aziotcs:aziotcs"
        "/var/lib/aziot/identityd:aziotid:aziotid"
        "/var/lib/aziot/edged:iotedge:iotedge"
        "/var/secrets/aziot/keyd:aziotks:aziotks"
        "/var/secrets/aziot/certd:aziotcs:aziotcs"
        "/var/secrets/aziot/identityd:aziotid:aziotid"
    )
    
    for entry in "${RUNTIME_DIRS[@]}"; do
        IFS=':' read -r dir owner group <<< "$entry"
        if [ ! -d "$dir" ]; then
            echo -e "${RED}  ✗ Missing runtime directory: $dir${NC}"
            mkdir -p "$dir"
            # Only chown if the user exists (created by aziot packages)
            if id -u "$owner" &>/dev/null; then
                chown "$owner:$group" "$dir"
                chmod 0770 "$dir"
                echo -e "${GREEN}  ✓ Created: $dir (owner: $owner)${NC}"
            else
                echo -e "${YELLOW}  ✓ Created: $dir (owner '$owner' not found — will be fixed on config apply)${NC}"
            fi
            DIRS_OK=0
        else
            # Fix ownership on existing directories — a manual mkdir or
            # partial install may have left them owned by root
            if id -u "$owner" &>/dev/null; then
                actual_owner=$(stat -c '%U' "$dir" 2>/dev/null)
                if [ "$actual_owner" != "$owner" ]; then
                    chown "$owner:$group" "$dir"
                    chmod 0770 "$dir"
                    echo -e "${YELLOW}  ✓ Fixed ownership: $dir ($actual_owner → $owner)${NC}"
                    DIRS_OK=0
                fi
            fi
        fi
    done
    
    if [ $DIRS_OK -eq 1 ]; then
        echo "  ✓ All IoT Edge directories present with correct ownership"
    else
        echo -e "${YELLOW}  ⚠ Missing directories were created — package may have installed incompletely${NC}"
        echo "  If problems persist, run a clean reinstall:"
        echo "    sudo apt-get purge -y aziot-edge aziot-identity-service"
        echo "    sudo rm -rf /etc/aziot /var/lib/aziot /var/secrets/aziot"
        echo "    sudo apt-get install -y aziot-edge"
    fi
    
    # Clear stale certificate, key, and identity data from runtime directories.
    # If a previous "iotedge config apply" partially succeeded (e.g., DPS
    # registration worked but the trust bundle cert write was interrupted),
    # the runtime directories contain corrupt database entries. When certd
    # restarts, it finds a ghost entry for "aziot-edged-trust-bundle" but
    # the stored cert data is invalid, producing:
    #   "could not load cert with id aziot-edged-trust-bundle
    #    -- parameter id has an invalid value"
    # This cascading failure prevents aziot-edged from starting (management
    # socket timeout) and makes "iotedge list" hang for 30 seconds.
    #
    # Clearing is safe: "iotedge config apply" regenerates ALL certs, keys,
    # and identity state from config.toml. Persistent module data lives in
    # /var/lib/iotedge/ (unaffected).
    echo ""
    echo "  Clearing stale runtime data (ensures clean cert/key generation)..."
    local STALE_FILES_FOUND=0
    for state_dir in /var/lib/aziot/certd /var/lib/aziot/keyd /var/lib/aziot/identityd /var/lib/aziot/edged; do
        if [ -d "$state_dir" ]; then
            file_count=$(find "$state_dir" -type f 2>/dev/null | wc -l)
            if [ "$file_count" -gt 0 ]; then
                find "$state_dir" -type f -delete 2>/dev/null
                echo "  ✓ Cleared $file_count stale file(s) from $state_dir"
                STALE_FILES_FOUND=1
            fi
        fi
    done
    if [ $STALE_FILES_FOUND -eq 0 ]; then
        echo "  ✓ Runtime directories are clean (no stale data)"
    else
        echo -e "${YELLOW}  ⚠ Stale runtime data cleared — certs/keys will be regenerated on config apply${NC}"
        if [ -f /etc/aziot/config.toml ]; then
            echo "    Re-apply configuration to regenerate certs: sudo iotedge config apply"
        fi
    fi
    
    # Generate explicit Edge CA and trust bundle certificates.
    # This bypasses the quickstart cert auto-generation which fails on some
    # platforms with: "parameter id has an invalid value"
    echo ""
    echo -e "${GREEN}  Generating Edge CA certificates...${NC}"
    generate_edge_certificates
    
    # If config.toml already exists (re-running option 6 on provisioned device),
    # patch it to reference our explicit certs
    patch_config_trust_bundle
    
    # Verify aziot-identity-service is installed (required dependency)
    if ! systemctl list-unit-files aziot-identityd.service &>/dev/null; then
        echo -e "${RED}  ✗ aziot-identityd service not found — aziot-identity-service package missing${NC}"
        echo "  Attempting to install..."
        apt-get install -y aziot-identity-service 2>&1 | tail -5
        if systemctl list-unit-files aziot-identityd.service &>/dev/null; then
            echo -e "${GREEN}  ✓ aziot-identity-service installed${NC}"
        else
            echo -e "${RED}  ✗ Failed — run a clean reinstall:${NC}"
            echo "    sudo apt-get purge -y aziot-edge aziot-identity-service"
            echo "    sudo rm -rf /etc/aziot /var/lib/aziot /var/secrets/aziot"
            echo "    sudo apt-get install -y aziot-edge"
        fi
    else
        echo "  ✓ aziot-identityd service available"
    fi
    
    # Ensure config template exists for provisioning
    if [ -f /etc/aziot/config.toml.edge.template ] && [ ! -f /etc/aziot/config.toml ]; then
        echo ""
        echo -e "${CYAN}  ℹ️  Config template available. To provision this device:${NC}"
        echo "    sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml"
        echo "    sudo nano /etc/aziot/config.toml  # Add your DPS/connection string"
        echo ""
        echo -e "${CYAN}  ℹ️  Edge CA certificates have been pre-generated.${NC}"
        echo -e "${GREEN}    Use option 16 (Apply Config) to safely apply the configuration.${NC}"
        echo "    It will auto-patch config.toml with cert references before applying."
        echo ""
        echo "    DO NOT run 'sudo iotedge config apply' directly — use option 16 instead."
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
        echo "  ℹ️  If this board has a Nuvoton NPCT750 TPM module, run option 12 to enable it."
        echo "  ℹ️  Otherwise, will use connection string fallback for provisioning."
    fi
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ IoT Edge runtime ready${NC}"
    return 0
}

# Configure udev rules to give IoT Edge (aziottpm group) access to TPM devices
configure_tpm_udev_rules() {
    local RULES_FILE="/etc/udev/rules.d/tpmaccess.rules"
    local RULES_NEEDED=0
    
    if [ -f "$RULES_FILE" ] && grep -q "aziottpm" "$RULES_FILE"; then
        echo "  ✓ IoT Edge TPM udev rules already configured"
    else
        RULES_NEEDED=1
    fi
    
    # Check if aziottpm group exists (created by aziot-edge package)
    if ! getent group aziottpm &>/dev/null; then
        echo -e "  ${YELLOW}⚠ Group 'aziottpm' does not exist yet${NC}"
        echo "    It will be created when Azure IoT Edge is installed (option 6)."
        echo "    Re-run option 12 after installing IoT Edge to apply udev rules."
        return 0
    fi
    
    if [ $RULES_NEEDED -eq 1 ]; then
        echo "  Creating udev rules for IoT Edge TPM access..."
        cat > "$RULES_FILE" <<'EOF'
# allow aziottpm access to tpm0 and tpmrm0
KERNEL=="tpm0", SUBSYSTEM=="tpm", OWNER="root", GROUP="aziottpm", MODE="0660"
KERNEL=="tpmrm0", SUBSYSTEM=="tpmrm", OWNER="root", GROUP="aziottpm", MODE="0660"
EOF
        echo "  ✓ Created $RULES_FILE"
    fi
    
    # Trigger udev to apply the new rules
    /bin/udevadm trigger --subsystem-match=tpm --subsystem-match=tpmrm 2>/dev/null || true
    echo "  ✓ Triggered udev to apply rules"
    
    # Verify permissions if TPM devices exist
    if [ -e /dev/tpm0 ] || [ -e /dev/tpmrm0 ]; then
        echo ""
        echo "  Verifying TPM device permissions:"
        ls -l /dev/tpm* 2>/dev/null | while read -r line; do
            echo "    $line"
        done
        
        # Check if permissions are correct
        if ls -l /dev/tpm0 2>/dev/null | grep -q "aziottpm"; then
            echo -e "  ${GREEN}✓ IoT Edge has access to TPM devices${NC}"
        else
            echo -e "  ${YELLOW}⚠ Permissions not yet applied - may require a reboot${NC}"
        fi
    else
        echo "  ℹ️  TPM devices not present yet - rules will apply after reboot"
    fi
}

# Enable Nuvoton NPCT750 TPM hardware on Factor 201
enable_tpm_hardware() {
    echo -e "${BLUE}[TPM HARDWARE ENABLEMENT]${NC}"
    echo -e "${BLUE}  Nuvoton NPCT750 TPM 2.0 Module (SPI)${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    # Locate the boot config file
    local CONFIG_FILE=""
    if [ -f /boot/firmware/config.txt ]; then
        CONFIG_FILE="/boot/firmware/config.txt"
    elif [ -f /boot/config.txt ]; then
        CONFIG_FILE="/boot/config.txt"
    else
        echo -e "${RED}✗ Boot config file not found!${NC}"
        echo "  Checked: /boot/firmware/config.txt and /boot/config.txt"
        set -e
        return 1
    fi
    
    echo -e "${GREEN}[1/5] Checking boot configuration...${NC}"
    echo "  Config file: $CONFIG_FILE"
    echo ""
    
    local CHANGES_MADE=0
    
    # Check if TPM is already detected
    if [ -e /dev/tpm0 ] || [ -e /dev/tpmrm0 ]; then
        echo -e "  ${GREEN}✓ TPM device already detected: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')${NC}"
        echo ""
        
        # Still ensure udev rules are in place for IoT Edge access
        configure_tpm_udev_rules
        
        echo "  You can run option 11 to extract the TPM key."
        echo ""
        set -e
        return 0
    fi
    
    # Backup config file
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-$(date +%s)"
    echo "  ✓ Backed up config file"
    
    # Step 1: Enable SPI
    echo ""
    echo -e "${GREEN}[2/5] Enabling SPI interface...${NC}"
    if grep -q "^dtparam=spi=on" "$CONFIG_FILE"; then
        echo "  ✓ SPI already enabled"
    elif grep -q "^#.*dtparam=spi=on" "$CONFIG_FILE"; then
        sed -i 's/^#.*dtparam=spi=on/dtparam=spi=on/' "$CONFIG_FILE"
        echo "  ✓ SPI enabled (uncommented)"
        CHANGES_MADE=1
    else
        # dtparam must appear BEFORE any dtoverlay lines in the boot config
        local FIRST_OVERLAY_LINE=$(grep -n "^dtoverlay=" "$CONFIG_FILE" | head -1 | cut -d: -f1)
        if [ -n "$FIRST_OVERLAY_LINE" ]; then
            sed -i "${FIRST_OVERLAY_LINE}i dtparam=spi=on" "$CONFIG_FILE"
            echo "  ✓ SPI enabled (inserted before overlays)"
        else
            echo "dtparam=spi=on" >> "$CONFIG_FILE"
            echo "  ✓ SPI enabled (added)"
        fi
        CHANGES_MADE=1
    fi
    
    # Step 2: Enable TPM overlay
    echo ""
    echo -e "${GREEN}[3/5] Enabling Nuvoton TPM device tree overlay...${NC}"
    
    # Disable conflicting TPM overlays (only one TPM overlay can be active on the SPI bus)
    # The Factor 201 uses Nuvoton NPCT750 - other TPM overlays will conflict and prevent detection
    local CONFLICTING_OVERLAYS=("tpm-slb9670" "tpm-slb9670-spi")
    for overlay in "${CONFLICTING_OVERLAYS[@]}"; do
        if grep -q "^dtoverlay=$overlay" "$CONFIG_FILE"; then
            sed -i "s/^dtoverlay=$overlay/#dtoverlay=$overlay  # disabled - conflicts with tpm-nuvoton/" "$CONFIG_FILE"
            echo -e "  ${YELLOW}⚠ Disabled conflicting overlay: dtoverlay=$overlay${NC}"
            echo "    Only one TPM overlay can be active on the SPI bus"
            CHANGES_MADE=1
        fi
        # Also catch manufacturer typo: "dtoverly" instead of "dtoverlay"
        if grep -q "^dtoverly=$overlay" "$CONFIG_FILE"; then
            sed -i "s/^dtoverly=$overlay/#dtoverly=$overlay  # disabled - typo and conflicts with tpm-nuvoton/" "$CONFIG_FILE"
            echo -e "  ${YELLOW}⚠ Disabled conflicting overlay with typo: dtoverly=$overlay${NC}"
            echo "    (manufacturer typo: 'dtoverly' should be 'dtoverlay')"
            CHANGES_MADE=1
        fi
    done
    
    if grep -q "^dtoverlay=tpm-nuvoton" "$CONFIG_FILE"; then
        echo "  ✓ TPM overlay already enabled"
    elif grep -q "^#.*dtoverlay=tpm-nuvoton" "$CONFIG_FILE"; then
        sed -i 's/^#.*dtoverlay=tpm-nuvoton/dtoverlay=tpm-nuvoton/' "$CONFIG_FILE"
        echo "  ✓ TPM overlay enabled (uncommented)"
        CHANGES_MADE=1
    else
        echo "dtoverlay=tpm-nuvoton" >> "$CONFIG_FILE"
        echo "  ✓ TPM overlay added"
        CHANGES_MADE=1
    fi
    
    # Step 3: Ensure tpm_tis_spi kernel module loads at boot
    echo ""
    echo -e "${GREEN}[4/5] Configuring TPM kernel module...${NC}"
    if grep -q "^tpm_tis_spi" /etc/modules 2>/dev/null; then
        echo "  ✓ tpm_tis_spi module already in /etc/modules"
    else
        echo "tpm_tis_spi" >> /etc/modules
        echo "  ✓ tpm_tis_spi module added to /etc/modules"
        CHANGES_MADE=1
    fi
    
    # Try loading the module now (may fail if overlay not yet active)
    modprobe tpm_tis_spi 2>/dev/null && echo "  ✓ tpm_tis_spi module loaded" || echo "  ℹ️  Module will load after reboot"
    
    # Step 5: Configure udev rules for IoT Edge TPM access
    echo ""
    echo -e "${GREEN}[5/5] Configuring IoT Edge TPM access (udev rules)...${NC}"
    configure_tpm_udev_rules
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    if [ $CHANGES_MADE -eq 1 ]; then
        echo -e "${GREEN}✓ TPM hardware configuration complete${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  A reboot is REQUIRED for changes to take effect:${NC}"
        echo "   sudo reboot"
        echo ""
        echo "After reboot:"
        echo "  1. Verify TPM is detected:  ls -la /dev/tpm*"
        echo "  2. Check kernel log:        sudo dmesg | grep -i tpm"
        echo "  3. Apply IoT Edge config:   sudo iotedge config apply"
        echo "  4. Extract TPM key:         Run this script → option 11"
    else
        echo -e "${GREEN}✓ TPM hardware already configured${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  TPM overlay is configured but /dev/tpm0 not found.${NC}"
        echo "  If you haven't rebooted since enabling, reboot now:"
        echo "   sudo reboot"
        echo ""
        echo "  If you have rebooted, check:"
        echo "   sudo dmesg | grep -i tpm    # Look for errors"
        echo "   sudo dmesg | grep -i spi    # Check SPI bus"
        echo "   cat $CONFIG_FILE | grep -i tpm"
        echo ""
        echo "  Common issue: Multiple TPM overlays active (e.g., tpm-slb9670 + tpm-nuvoton)."
        echo "  Only one can be active. Run option 12 again to auto-fix conflicts."
    fi
    echo ""
    
    return 0
}

# Extract TPM endorsement key
extract_tpm_key() {
    echo -e "${BLUE}[TPM KEY EXTRACTION]${NC}"
    echo ""
    
    # Check if TPM is available
    if [ ! -e /dev/tpm0 ] && [ ! -e /dev/tpmrm0 ]; then
        echo -e "${RED}✗ No TPM device found!${NC}"
        echo ""
        echo "  The TPM device (/dev/tpm0) is not present. For Factor 201 boards"
        echo "  with a Nuvoton NPCT750 TPM module, run option 12 first to enable"
        echo "  the SPI TPM overlay, then reboot before running this option."
        echo ""
        echo "  Quick fix:"
        echo "    1. Run this script → option 12 (Enable TPM Hardware)"
        echo "    2. sudo reboot"
        echo "    3. Run this script → option 11 (Extract TPM Key)"
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
    
    # ── Layer 1: Create directories and set ownership NOW ─────────────────
    echo -e "${GREEN}[1/4] Creating persistent storage directories...${NC}"
    
    # Create directories on host for persistent storage
    mkdir -p /var/lib/iotedge/edgeAgent
    mkdir -p /var/lib/iotedge/edgeHub
    
    # The edgeAgent container runs as 'edgeagentuser' (UID 13622) and
    # edgeHub runs as 'edgehubuser' (UID 13623) INSIDE the container.
    # The host directories MUST be owned by these UIDs so the container
    # processes can write to the bind-mounted paths.
    #
    # WARNING: Do NOT use the host's 'iotedge' user here. That only worked
    # when edgeAgent ran as root (pre-2025). Microsoft changed edgeAgent to
    # run as a non-root user for security hardening. Using the wrong UID
    # causes "access to path /home/edgeagentuser is denied" after any
    # container image update or reboot.
    chown -R 13622:13622 /var/lib/iotedge/edgeAgent
    chown -R 13623:13623 /var/lib/iotedge/edgeHub
    chmod -R 755 /var/lib/iotedge
    
    echo "  ✓ Created: /var/lib/iotedge/edgeAgent (owner: UID 13622 / edgeagentuser)"
    echo "  ✓ Created: /var/lib/iotedge/edgeHub (owner: UID 13623 / edgehubuser)"
    
    # ── Layer 2: tmpfiles.d — auto-fix on every boot ─────────────────────
    echo ""
    echo -e "${GREEN}[2/4] Installing boot-time ownership guarantee (tmpfiles.d)...${NC}"
    
    # systemd-tmpfiles runs early in every boot and ensures these directories
    # exist with the correct ownership. This catches:
    #   - Package updates that reset ownership
    #   - Manual mistakes (someone runs chown on /var/lib)
    #   - Filesystem corruption after power loss
    cat > /etc/tmpfiles.d/iotedge-storage.conf <<'EOF'
# Persistent storage for Azure IoT Edge bind mounts.
# edgeAgent runs as UID 13622, edgeHub as UID 13623 inside their containers.
# These directories are bind-mounted via the deployment manifest:
#   /var/lib/iotedge/edgeAgent:/tmp/edgeAgent
#   /var/lib/iotedge/edgeHub:/tmp/edgeHub
#
# Type  Path                            Mode  UID    GID    Age  Argument
d       /var/lib/iotedge                0755  root   root   -    -
d       /var/lib/iotedge/edgeAgent      0755  13622  13622  -    -
d       /var/lib/iotedge/edgeHub        0755  13623  13623  -    -
EOF
    
    # Run it now so the rules take effect immediately (not just on next boot)
    systemd-tmpfiles --create /etc/tmpfiles.d/iotedge-storage.conf 2>/dev/null
    
    echo "  ✓ Created /etc/tmpfiles.d/iotedge-storage.conf"
    echo "    Directories will be verified/recreated on every boot automatically"
    
    # ── Layer 3: ExecStartPre — auto-fix before every service start ──────
    echo ""
    echo -e "${GREEN}[3/4] Installing service-start ownership guarantee (systemd drop-in)...${NC}"
    
    # Modern aziot-edge uses aziot-edged.service (not iotedge.service)
    local SERVICE_NAME=""
    if systemctl list-unit-files aziot-edged.service &>/dev/null; then
        SERVICE_NAME="aziot-edged"
    elif systemctl list-unit-files iotedge.service &>/dev/null; then
        SERVICE_NAME="iotedge"
    else
        echo -e "  ${YELLOW}⚠ IoT Edge service not found — install IoT Edge first (option 6)${NC}"
        echo "    Persistent storage directories are ready. Re-run this after installing IoT Edge."
        set -e
        return 0
    fi
    
    # This drop-in runs ownership fixup commands BEFORE aziot-edged starts.
    # Even if something changed the ownership since last boot, this guarantees
    # the directories are correct before any container tries to use them.
    #
    # This catches the scenario that broke devices in production:
    #   1. Microsoft pushes updated edgeAgent image (now runs as UID 13622)
    #   2. IoT Edge pulls the new image and recreates the container
    #   3. Container tries to write to bind-mounted /tmp/edgeAgent
    #   4. Host directory is owned by wrong UID → "permission denied" → Failed
    #
    # With ExecStartPre, step 3 always succeeds because ownership is fixed
    # moments before the container starts.
    mkdir -p /etc/systemd/system/${SERVICE_NAME}.service.d
    cat > /etc/systemd/system/${SERVICE_NAME}.service.d/persistent-storage.conf <<'EOF'
[Service]
# Ensure persistent storage directories exist and have correct ownership
# before IoT Edge starts any containers. This runs on every service start,
# restart, and crash recovery.
#
# The "+" prefix is CRITICAL: it tells systemd to run the command as root
# even though aziot-edged.service runs as a non-root user (iotedge/aziotedge).
# Without "+", chown runs as the service user and fails with
# "operation not permitted" — which causes the entire service to fail.
#
# edgeAgent = UID 13622 (edgeagentuser inside container)
# edgeHub   = UID 13623 (edgehubuser inside container)
ExecStartPre=+/bin/mkdir -p /var/lib/iotedge/edgeAgent /var/lib/iotedge/edgeHub
ExecStartPre=+/bin/chown -R 13622:13622 /var/lib/iotedge/edgeAgent
ExecStartPre=+/bin/chown -R 13623:13623 /var/lib/iotedge/edgeHub
EOF
    
    echo "  ✓ Created systemd drop-in for ${SERVICE_NAME}.service"
    echo "    Ownership will be verified/fixed before every service start"
    
    # Reload systemd to pick up changes
    echo ""
    echo -e "${GREEN}[4/4] Reloading systemd configuration...${NC}"
    systemctl daemon-reload
    echo "  ✓ Systemd configuration reloaded"
    
    # ── Auto-restart IoT Edge if device is already provisioned ───────────
    # When this function runs on a device that was already provisioned
    # (e.g., fixing a broken edgeAgent after a Microsoft image update),
    # just fixing ownership isn't enough — the failed container is still
    # sitting in Docker with "Failed" status. We need to:
    #   1. Remove the failed edgeAgent/edgeHub containers so Docker
    #      recreates them with the now-correct bind mount ownership
    #   2. Restart IoT Edge services so they pull fresh containers
    #
    # We only do this if config.toml exists (device was provisioned).
    # If config.toml doesn't exist, this is a fresh install and the user
    # hasn't run "iotedge config apply" yet — nothing to restart.
    if [ -f /etc/aziot/config.toml ]; then
        echo ""
        echo -e "${RED}═══════════════════════════════════════════${NC}"
        echo -e "${RED}│  PROVISIONED DEVICE DETECTED               │${NC}"
        echo -e "${RED}═══════════════════════════════════════════${NC}"
        echo ""
        
        # SAFETY FIRST: Immediately stop all aziot services.
        # If this device was broken (e.g., bad permissions, missing config.d),
        # the services may have auto-started on boot and could be making
        # partial/broken calls to Azure DPS right now — corrupting enrollments
        # and device identities in IoT Hub. Stop them before anything else.
        echo -e "${YELLOW}  Stopping all Azure IoT services immediately (damage control)...${NC}"
        for svc in aziot-edged aziot-identityd aziot-keyd aziot-certd aziot-tpmd; do
            systemctl stop "${svc}.service" 2>/dev/null && echo "  ✓ Stopped ${svc}" || true
        done
        echo ""
        
        # Remove failed/stale edgeAgent and edgeHub containers
        # They will be recreated by IoT Edge with the corrected ownership
        if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
            for container in edgeAgent edgeHub; do
                if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -qx "$container"; then
                    local STATUS=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)
                    docker rm -f "$container" 2>/dev/null
                    echo "  ✓ Removed $container container (was: ${STATUS:-unknown})"
                fi
            done
        fi
        
        echo -e "${YELLOW}  ⚠️  This device has an existing config.toml (previously provisioned).${NC}"
        echo ""
        echo "  Running 'iotedge config apply' will:"
        echo "    • Regenerate derived config files (00-super.toml)"
        echo "    • Restart all Azure IoT services"
        echo -e "    • ${RED}CONTACT AZURE DPS immediately${NC}"
        echo ""
        echo "  If this device was corrupting Azure state (broken DPS enrollment,"
        echo "  phantom device identity, portal errors), you must FIRST:"
        echo "    1. Disable or delete the DPS enrollment in Azure Portal"
        echo "    2. Delete the corrupted device identity in IoT Hub"
        echo "    3. Then come back and apply config"
        echo ""
        read -p "  Apply config and reconnect to Azure now? (y/N): " APPLY_CONFIRM
        echo ""
        
        if [[ $APPLY_CONFIRM =~ ^[Yy]$ ]]; then
            # User confirmed — proceed with config apply
            # Use "iotedge config apply" instead of "iotedge system restart".
            # config apply does everything system restart does PLUS regenerates the
            # derived config files (e.g., /etc/aziot/edged/config.d/00-super.toml)
            # from config.toml. This is critical when the config.d directories were
            # missing/recreated — without the generated 00-super.toml, the services
            # start but immediately fail because they have no runtime config.
            #
            # "iotedge config apply" reads config.toml → writes 00-super.toml into
            # each service's config.d/ → restarts all aziot services.
            # The ExecStartPre drop-in fires during that restart, fixing ownership.
            if command -v iotedge &>/dev/null; then
                # Generate explicit Edge CA and trust bundle certificates,
                # then patch config.toml to reference them. This bypasses
                # the quickstart cert auto-generation which fails on some
                # platforms with "parameter id has an invalid value".
                echo "  Ensuring Edge CA certificates exist..."
                generate_edge_certificates
                echo ""
                echo "  Patching config.toml with cert references..."
                patch_config_trust_bundle
                echo ""
                
                # Clear stale cert/key/identity data before config apply.
                # A previous failed "iotedge config apply" may have left
                # corrupt trust bundle entries in the certd database,
                # causing "parameter id has an invalid value" on restart.
                # This cascading failure prevents aziot-edged from starting
                # and makes the management socket timeout on iotedge list.
                # Clearing is safe: config apply regenerates everything.
                echo "  Clearing stale runtime data for clean cert generation..."
                for state_dir in /var/lib/aziot/certd /var/lib/aziot/keyd /var/lib/aziot/identityd /var/lib/aziot/edged; do
                    if [ -d "$state_dir" ]; then
                        find "$state_dir" -type f -delete 2>/dev/null
                    fi
                done
                echo "  ✓ Runtime data cleared"
                
                echo "  Applying configuration and restarting IoT Edge services..."
                iotedge config apply 2>&1 | sed 's/^/    /'
                local apply_result=$?
                
                if [ $apply_result -eq 0 ]; then
                    echo -e "  ${GREEN}✓ IoT Edge config applied and services restarted${NC}"
                    echo ""
                    echo "  Waiting 15 seconds for edgeAgent to start..."
                    sleep 15
                    
                    # Quick status check
                    echo ""
                    echo "  Current service status:"
                    iotedge system status 2>/dev/null | sed 's/^/    /' || echo "    (could not get status)"
                    
                    echo ""
                    echo "  Container status:"
                    docker ps --format "    {{.Names}}  {{.Status}}  {{.Image}}" 2>/dev/null || echo "    (could not list containers)"
                else
                    echo -e "  ${YELLOW}⚠ iotedge config apply returned exit code $apply_result${NC}"
                    echo "  You may need to apply manually:"
                    echo "    sudo iotedge config apply"
                fi
            else
                echo -e "  ${YELLOW}⚠ iotedge command not found — restart manually after installing IoT Edge${NC}"
            fi
        else
            # User declined — keep services stopped and disable auto-start.
            # This ensures the device does NOT contact Azure on next reboot.
            echo -e "${CYAN}  Keeping Azure IoT services DISABLED (safe mode).${NC}"
            echo ""
            for svc in aziot-edged aziot-identityd aziot-keyd aziot-certd aziot-tpmd; do
                systemctl disable "${svc}.service" 2>/dev/null || true
            done
            echo "  ✓ All aziot services stopped and disabled (won't start on reboot)"
            echo ""
            echo -e "${CYAN}  The device is now SAFE — it will not contact Azure.${NC}"
            echo ""
            echo "  When you're ready to reconnect:"
            echo "    1. Clean Azure state first:"
            echo "       • DPS → Manage enrollments → delete/disable the enrollment"
            echo "       • IoT Hub → Devices → delete the corrupted device identity"
            echo "    2. Re-enable and apply config (choose one):"
            echo "       Option A (no reboot):"
            echo "         sudo systemctl enable aziot-edged aziot-identityd aziot-keyd aziot-certd"
            echo "         sudo iotedge config apply"
            echo "       Option B (simpler — reboot re-enables everything):"
            echo "         sudo systemctl enable aziot-edged aziot-identityd aziot-keyd aziot-certd"
            echo "         sudo reboot"
            echo "    3. Verify:"
            echo "       sudo iotedge system status"
            echo "       sudo iotedge list"
        fi
    fi
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}✓ Persistent storage configured${NC}"
    echo ""
    echo "Protection layers installed:"
    echo "  ✓ Layer 1: Directories created with correct ownership (just now)"
    echo "  ✓ Layer 2: tmpfiles.d — ownership auto-fixed on every boot"
    echo "  ✓ Layer 3: ExecStartPre — ownership auto-fixed before every service start"
    echo "  ✓ Layer 4: Health check (option 14) — validates ownership on demand"
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

# Repair IoT Edge - purge and clean reinstall
repair_iotedge() {
    echo -e "${BLUE}[REPAIR IoT EDGE]${NC}"
    echo -e "${BLUE}  Purge and Clean Reinstall${NC}"
    echo ""
    
    # Temporarily disable exit-on-error for this function
    set +e
    
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo -e "${RED}│  WARNING: DESTRUCTIVE OPERATION           │${NC}"
    echo -e "${RED}═══════════════════════════════════════════${NC}"
    echo ""
    echo "This will:"
    echo "  • Stop all Azure IoT Edge services"
    echo "  • Purge aziot-edge and aziot-identity-service packages"
    echo "  • Remove orphaned Docker containers (edgeAgent, edgeHub, modules)"
    echo "  • Delete ALL IoT Edge configuration (/etc/aziot)"
    echo "  • Delete ALL IoT Edge state (/var/lib/aziot, /var/secrets/aziot)"
    echo "  • Remove systemd drop-in overrides"
    echo "  • Reinstall aziot-edge from scratch"
    echo ""
    echo -e "${YELLOW}⚠️  You will need to re-provision the device after reinstall.${NC}"
    echo -e "${YELLOW}   Have your DPS scope ID, registration ID, and symmetric key ready.${NC}"
    echo ""
    read -p "Type 'REPAIR' to confirm, or anything else to cancel: " CONFIRM
    echo ""
    
    if [ "$CONFIRM" != "REPAIR" ]; then
        echo "Cancelled."
        set -e
        return 0
    fi
    
    # Step 1: Stop all aziot services
    echo -e "${GREEN}[1/7] Stopping IoT Edge services...${NC}"
    local SERVICES=("aziot-edged" "aziot-identityd" "aziot-keyd" "aziot-certd" "aziot-tpmd")
    for svc in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            systemctl stop "${svc}.service" 2>/dev/null
            echo "  ✓ Stopped ${svc}"
        else
            echo "  · ${svc} not running"
        fi
    done
    # Also stop legacy service name if present
    systemctl stop iotedge.service 2>/dev/null || true
    echo ""
    
    # Step 2: Purge packages
    echo -e "${GREEN}[2/7] Purging IoT Edge packages...${NC}"
    
    wait_for_package_manager
    if [ $? -ne 0 ]; then
        set -e
        return 1
    fi
    
    apt-get purge -y aziot-edge 2>&1 | tail -5
    apt-get purge -y aziot-identity-service 2>&1 | tail -5
    echo "  ✓ Packages purged"
    echo ""
    
    # Step 3: Remove all Docker containers and IoT Edge network
    # On dedicated IoT Edge devices, all containers are managed by IoT Edge
    # (edgeAgent, edgeHub, ScadaPollingModule, etc.) — safe to remove everything
    echo -e "${GREEN}[3/7] Removing all Docker containers...${NC}"
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        local ALL_CONTAINERS=$(docker ps -a --format "{{.Names}}" 2>/dev/null)
        if [ -n "$ALL_CONTAINERS" ]; then
            echo "$ALL_CONTAINERS" | while read -r cname; do
                docker rm -f "$cname" 2>/dev/null && echo "  ✓ Removed container: $cname" || echo "  · Could not remove: $cname"
            done
        else
            echo "  · No containers found"
        fi
        
        # Remove the IoT Edge Docker network
        if docker network ls --format "{{.Name}}" 2>/dev/null | grep -qx "azure-iot-edge"; then
            docker network rm azure-iot-edge 2>/dev/null && echo "  ✓ Removed network: azure-iot-edge" || echo "  · Could not remove network azure-iot-edge"
        fi
        
        echo "  ✓ Docker cleanup complete"
    else
        echo "  · Docker not running, skipping container cleanup"
    fi
    echo ""
    
    # Step 4: Remove all config and state directories
    echo -e "${GREEN}[4/7] Removing configuration and state...${NC}"
    rm -rf /etc/aziot
    echo "  ✓ Removed /etc/aziot"
    rm -rf /var/lib/aziot
    echo "  ✓ Removed /var/lib/aziot"
    rm -rf /var/secrets/aziot
    echo "  ✓ Removed /var/secrets/aziot"
    echo ""
    
    # Step 5: Clean up systemd drop-ins
    echo -e "${GREEN}[5/7] Cleaning systemd overrides...${NC}"
    if [ -d /etc/systemd/system/aziot-edged.service.d ]; then
        rm -rf /etc/systemd/system/aziot-edged.service.d
        echo "  ✓ Removed aziot-edged.service.d drop-in"
    fi
    if [ -d /etc/systemd/system/iotedge.service.d ]; then
        rm -rf /etc/systemd/system/iotedge.service.d
        echo "  ✓ Removed iotedge.service.d drop-in (legacy)"
    fi
    systemctl daemon-reload
    
    apt-get autoremove -y 2>&1 | tail -3
    echo "  ✓ Cleaned up dependencies"
    echo ""
    
    # Step 6: Reinstall
    echo -e "${GREEN}[6/7] Reinstalling Azure IoT Edge...${NC}"
    
    wait_for_package_manager
    if [ $? -ne 0 ]; then
        set -e
        return 1
    fi
    
    # Re-add Microsoft package repository.
    # The purge + autoremove in steps 2/5 can remove packages-microsoft-prod,
    # which deletes /etc/apt/sources.list.d/microsoft-prod.list.
    # Without the repo, apt can't find aziot-edge and the install fails with
    # "E: Unable to locate package aziot-edge".
    echo "  Ensuring Microsoft package repository is configured..."
    if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
        UBUNTU_VERSION=$(lsb_release -rs)
        wget -q "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
        dpkg -i /tmp/packages-microsoft-prod.deb > /dev/null 2>&1
        rm -f /tmp/packages-microsoft-prod.deb
        echo "  ✓ Microsoft repository re-added"
    else
        echo "  ✓ Microsoft repository already configured"
    fi
    
    echo "  Updating package lists..."
    apt-get update --fix-missing 2>&1 | tail -5
    
    echo "  Installing aziot-edge (this may take a few minutes)..."
    apt-get install -y aziot-edge 2>&1 | tee /tmp/iotedge-repair.log | tail -15
    local install_result=$?
    
    if [ $install_result -ne 0 ]; then
        echo ""
        echo -e "${RED}✗ Failed to reinstall aziot-edge (exit code: $install_result)${NC}"
        echo ""
        echo "  Check log: /tmp/iotedge-repair.log"
        echo ""
        echo "  Manual recovery:"
        echo "    UBUNTU_VERSION=\$(lsb_release -rs)"
        echo "    wget https://packages.microsoft.com/config/ubuntu/\${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb"
        echo "    sudo dpkg -i packages-microsoft-prod.deb"
        echo "    sudo apt-get update"
        echo "    sudo apt-get install -y aziot-edge"
        set -e
        return 1
    fi
    echo "  ✓ aziot-edge installed"
    echo ""
    
    # Step 7: Verify installation
    echo -e "${GREEN}[7/7] Verifying installation...${NC}"
    
    # Check command
    if command -v iotedge &>/dev/null; then
        echo "  ✓ iotedge command available: $(iotedge --version 2>/dev/null || echo 'unknown')"
    else
        echo -e "  ${RED}✗ iotedge command not found${NC}"
        set -e
        return 1
    fi
    
    # Check critical config directories
    local ALL_DIRS_OK=1
    for dir in /etc/aziot /etc/aziot/edged/config.d /etc/aziot/keyd/config.d /etc/aziot/certd/config.d /etc/aziot/identityd/config.d; do
        if [ -d "$dir" ]; then
            echo "  ✓ $dir"
        else
            echo -e "  ${RED}✗ Missing: $dir${NC}"
            mkdir -p "$dir"
            echo -e "  ${GREEN}  → Created${NC}"
            ALL_DIRS_OK=0
        fi
    done
    
    # Check runtime directories (certificates, keys, state)
    # Without these, aziot-certd cannot store the trust bundle and
    # config apply fails with "aziot-edged-trust-bundle -- not found"
    local RUNTIME_DIRS=(
        "/var/lib/aziot/keyd:aziotks:aziotks"
        "/var/lib/aziot/certd:aziotcs:aziotcs"
        "/var/lib/aziot/identityd:aziotid:aziotid"
        "/var/lib/aziot/edged:iotedge:iotedge"
        "/var/secrets/aziot/keyd:aziotks:aziotks"
        "/var/secrets/aziot/certd:aziotcs:aziotcs"
        "/var/secrets/aziot/identityd:aziotid:aziotid"
    )
    
    for entry in "${RUNTIME_DIRS[@]}"; do
        IFS=':' read -r dir owner group <<< "$entry"
        if [ -d "$dir" ]; then
            echo "  ✓ $dir"
        else
            echo -e "  ${RED}✗ Missing: $dir${NC}"
            mkdir -p "$dir"
            if id -u "$owner" &>/dev/null; then
                chown "$owner:$group" "$dir"
                chmod 0770 "$dir"
            fi
            echo -e "  ${GREEN}  → Created (owner: $owner)${NC}"
            ALL_DIRS_OK=0
        fi
    done
    
    # Check aziot-identityd service
    if systemctl list-unit-files aziot-identityd.service &>/dev/null; then
        echo "  ✓ aziot-identityd service available"
    else
        echo -e "  ${RED}✗ aziot-identityd service missing${NC}"
        echo "  Attempting to install aziot-identity-service..."
        apt-get install -y aziot-identity-service 2>&1 | tail -5
    fi
    
    # Generate explicit Edge CA and trust bundle certificates.
    # This ensures the certs exist before the user provisions the device,
    # avoiding the quickstart cert generation bug.
    echo ""
    echo "  Generating Edge CA certificates..."
    generate_edge_certificates
    
    # Re-enable exit-on-error
    set -e
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}│  IoT Edge REPAIR COMPLETE                  │${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Next steps to provision the device:${NC}"
    echo ""
    echo -e "  ${YELLOW}0. If re-provisioning with a DIFFERENT enrollment:${NC}"
    echo "     Delete the old DPS registration in Azure Portal:"
    echo "       DPS → Manage enrollments → Individual → select old enrollment → Delete registration"
    echo "     Or delete the old device identity in IoT Hub:"
    echo "       IoT Hub → Devices → select old device → Delete"
    echo ""
    echo "  1. Copy the config template:"
    echo "     sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml"
    echo ""
    echo "  2. Edit the config with your provisioning details:"
    echo "     sudo nano /etc/aziot/config.toml"
    echo ""
    echo "     For DPS symmetric key provisioning, set:"
    echo '       [provisioning]'
    echo '       source = "dps"'
    echo '       [provisioning.attestation]'
    echo '       method = "symmetric_key"'
    echo '       registration_id = "<your-registration-id>"'
    echo '       symmetric_key = { value = "<your-symmetric-key>" }'
    echo '       [provisioning.attestation.dps]'
    echo '       global_endpoint = "https://global.azure-devices-provisioning.net"'
    echo '       id_scope = "<your-id-scope>"'
    echo ""
    echo ""
    echo "  3. Run the health check (option 14) to confirm the install is clean"
    echo ""
    echo -e "  4. ${GREEN}Use option 16 (Apply Config) to safely apply the configuration.${NC}"
    echo "     It will auto-patch config.toml with Edge CA cert references,"
    echo "     clear stale data, and run 'iotedge config apply' for you."
    echo ""
    echo -e "     ${RED}DO NOT run 'sudo iotedge config apply' directly — use option 16.${NC}"
    echo ""
    echo "  5. Verify it's working:"
    echo "     sudo iotedge system status"
    echo "     sudo iotedge list"
    echo ""
    
    # Fix persistent storage ownership if directories survive the repair.
    # edgeAgent runs as UID 13622, edgeHub as UID 13623 inside the container.
    if [ -d /var/lib/iotedge ]; then
        echo -e "${CYAN}ℹ️  Persistent storage directories (/var/lib/iotedge) still exist.${NC}"
        echo "  Fixing ownership to match container UIDs..."
        [ -d /var/lib/iotedge/edgeAgent ] && chown -R 13622:13622 /var/lib/iotedge/edgeAgent
        [ -d /var/lib/iotedge/edgeHub ]   && chown -R 13623:13623 /var/lib/iotedge/edgeHub
        chmod -R 755 /var/lib/iotedge
        echo -e "  ${GREEN}✓ Ownership corrected (edgeAgent=13622, edgeHub=13623)${NC}"
        echo "  Run option 7 after provisioning to re-apply the systemd drop-in."
        echo ""
    fi
    
    # Auto-run health check after repair
    echo ""
    read -p "Run pre-provision health check now? (Y/n): " RUN_CHECK
    echo ""
    if [[ ! $RUN_CHECK =~ ^[Nn]$ ]]; then
        verify_iotedge_health
    fi
    
    return 0
}

# Pre-provisioning health check
# Validates the IoT Edge installation is clean and ready BEFORE connecting to Azure.
# This prevents a broken install from contacting DPS and corrupting Azure state.
verify_iotedge_health() {
    echo -e "${BLUE}[PRE-PROVISION HEALTH CHECK]${NC}"
    echo -e "${BLUE}  Verify IoT Edge is ready before connecting to Azure${NC}"
    echo ""
    echo -e "${CYAN}This check runs entirely LOCAL — no Azure contact is made.${NC}"
    echo -e "${CYAN}All checks must pass before you provision the device.${NC}"
    echo ""
    
    local PASS=0
    local FAIL=0
    local WARN=0
    
    pass() { echo -e "  ${GREEN}✓ PASS${NC} — $1"; PASS=$((PASS + 1)); }
    fail() { echo -e "  ${RED}✗ FAIL${NC} — $1"; FAIL=$((FAIL + 1)); }
    warn() { echo -e "  ${YELLOW}⚠ WARN${NC} — $1"; WARN=$((WARN + 1)); }
    
    # ── 1. Package integrity ──────────────────────────────────────────────
    echo -e "${GREEN}[1/10] Package integrity...${NC}"
    
    # Check aziot-edge package is fully installed (not half-configured)
    local EDGE_STATUS=$(dpkg -l aziot-edge 2>/dev/null | grep "^ii" | awk '{print $3}')
    if [ -n "$EDGE_STATUS" ]; then
        pass "aziot-edge package installed (${EDGE_STATUS})"
    else
        # Check for broken/half-configured state
        local EDGE_BROKEN=$(dpkg -l aziot-edge 2>/dev/null | grep -E "^(iF|iU|iH|rc)")
        if [ -n "$EDGE_BROKEN" ]; then
            fail "aziot-edge package is BROKEN ($(echo $EDGE_BROKEN | awk '{print $1}') state)"
            echo "         Run option 13 (Repair) to fix"
        else
            fail "aziot-edge package not installed"
        fi
    fi
    
    local IDS_STATUS=$(dpkg -l aziot-identity-service 2>/dev/null | grep "^ii" | awk '{print $3}')
    if [ -n "$IDS_STATUS" ]; then
        pass "aziot-identity-service package installed (${IDS_STATUS})"
    else
        local IDS_BROKEN=$(dpkg -l aziot-identity-service 2>/dev/null | grep -E "^(iF|iU|iH|rc)")
        if [ -n "$IDS_BROKEN" ]; then
            fail "aziot-identity-service package is BROKEN"
        else
            fail "aziot-identity-service package not installed"
        fi
    fi
    echo ""
    
    # ── 2. Critical binaries ──────────────────────────────────────────────
    echo -e "${GREEN}[2/10] Critical binaries...${NC}"
    
    for bin in iotedge aziot-edged aziot-identityd aziot-keyd aziot-certd; do
        if command -v "$bin" &>/dev/null; then
            pass "$bin found at $(which $bin)"
        else
            fail "$bin binary not found"
        fi
    done
    echo ""
    
    # ── 3. Critical directories ───────────────────────────────────────────
    echo -e "${GREEN}[3/10] Critical directories...${NC}"
    
    echo "  Config directories:"
    for dir in /etc/aziot /etc/aziot/edged/config.d /etc/aziot/keyd/config.d /etc/aziot/certd/config.d /etc/aziot/identityd/config.d; do
        if [ -d "$dir" ]; then
            pass "$dir exists"
        else
            fail "$dir missing"
        fi
    done
    
    # Runtime directories hold certificates (trust bundle), private keys,
    # and service state. Without them, aziot-certd cannot create the trust
    # bundle and config apply fails with:
    #   "could not load cert with id aziot-edged-trust-bundle -- not found"
    echo "  Runtime directories:"
    local RUNTIME_DIR_CHECKS=(
        "/var/lib/aziot/keyd:aziotks"
        "/var/lib/aziot/certd:aziotcs"
        "/var/lib/aziot/identityd:aziotid"
        "/var/lib/aziot/edged:iotedge"
        "/var/secrets/aziot/keyd:aziotks"
        "/var/secrets/aziot/certd:aziotcs"
        "/var/secrets/aziot/identityd:aziotid"
    )
    
    for entry in "${RUNTIME_DIR_CHECKS[@]}"; do
        IFS=':' read -r dir expected_owner <<< "$entry"
        if [ -d "$dir" ]; then
            local actual_owner=$(stat -c '%U' "$dir" 2>/dev/null)
            if [ "$actual_owner" = "$expected_owner" ]; then
                pass "$dir (owner: $expected_owner)"
            else
                fail "$dir exists but owned by '$actual_owner' — expected '$expected_owner'"
                echo "         Fix: sudo chown $expected_owner:$expected_owner $dir"
            fi
        else
            fail "$dir missing — aziot services cannot store certs/keys/state"
            echo "         Fix: re-run option 6 (IoT Edge Runtime) or option 13 (Repair)"
        fi
    done
    
    # Check for stale runtime data that causes trust bundle errors.
    # A partially-failed "iotedge config apply" can leave corrupt cert
    # entries in certd's database, producing:
    #   "could not load cert with id aziot-edged-trust-bundle
    #    -- parameter id has an invalid value"
    echo "  Stale runtime data:"
    local STALE_DATA_FOUND=0
    for state_dir in /var/lib/aziot/certd /var/lib/aziot/keyd /var/lib/aziot/identityd /var/lib/aziot/edged; do
        if [ -d "$state_dir" ]; then
            local fc=$(find "$state_dir" -type f 2>/dev/null | wc -l)
            if [ "$fc" -gt 0 ]; then
                warn "$state_dir has $fc leftover file(s) from previous provisioning"
                echo "         This may cause 'parameter id has an invalid value' errors"
                echo "         Fix: re-run option 6 (IoT Edge Runtime) to clear stale data"
                STALE_DATA_FOUND=1
            fi
        fi
    done
    if [ $STALE_DATA_FOUND -eq 0 ]; then
        pass "No stale runtime data in cert/key/identity directories"
    fi
    echo ""
    
    # ── 4. Config template ────────────────────────────────────────────────
    echo -e "${GREEN}[4/10] Configuration state...${NC}"
    
    if [ -f /etc/aziot/config.toml.edge.template ]; then
        pass "Config template exists (/etc/aziot/config.toml.edge.template)"
    else
        fail "Config template missing — package may be corrupt"
    fi
    
    # config.toml should NOT exist yet (repair deletes it, user creates it during provisioning)
    if [ -f /etc/aziot/config.toml ]; then
        warn "config.toml already exists — leftover from previous provisioning?"
        echo "         If re-provisioning, delete it first: sudo rm /etc/aziot/config.toml"
    else
        pass "No leftover config.toml (clean state)"
    fi
    
    # Check Edge CA certificates (explicit certs bypass broken quickstart)
    echo "  Edge CA certificates:"
    local CERT_DIR="/etc/aziot/certificates"
    if [ -f "$CERT_DIR/edge-ca.pem" ] && [ -f "$CERT_DIR/edge-ca-key.pem" ] && [ -f "$CERT_DIR/trust-bundle.pem" ]; then
        if openssl x509 -checkend 86400 -noout -in "$CERT_DIR/edge-ca.pem" 2>/dev/null; then
            local CERT_EXPIRY
            CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_DIR/edge-ca.pem" 2>/dev/null | sed 's/notAfter=//')
            pass "Edge CA cert valid (expires: $CERT_EXPIRY)"
            pass "Trust bundle cert exists"
        else
            fail "Edge CA cert expired — re-run option 6 (IoT Edge Runtime) to regenerate"
        fi
        
        # Check ownership
        local CA_OWNER=$(stat -c '%U' "$CERT_DIR/edge-ca.pem" 2>/dev/null)
        local KEY_OWNER=$(stat -c '%U' "$CERT_DIR/edge-ca-key.pem" 2>/dev/null)
        if [ "$CA_OWNER" = "aziotcs" ] && [ "$KEY_OWNER" = "aziotks" ]; then
            pass "Cert file ownership correct (aziotcs/aziotks)"
        else
            fail "Cert file ownership wrong (ca=$CA_OWNER, key=$KEY_OWNER) — expected aziotcs/aziotks"
            echo "         Fix: re-run option 6 (IoT Edge Runtime)"
        fi
    else
        fail "Edge CA certificates missing — quickstart certs will be used (may fail)"
        echo "         Fix: re-run option 6 (IoT Edge Runtime) to generate explicit certs"
        echo "         This resolves 'parameter id has an invalid value' trust bundle errors"
    fi
    
    # Check config.toml references explicit certs (if config.toml exists)
    if [ -f /etc/aziot/config.toml ]; then
        if grep -q '^trust_bundle_cert\s*=' /etc/aziot/config.toml 2>/dev/null; then
            pass "config.toml has trust_bundle_cert set"
        else
            warn "config.toml missing trust_bundle_cert — run option 7 to auto-patch"
        fi
        if grep -q '^\[edge_ca\]' /etc/aziot/config.toml 2>/dev/null; then
            pass "config.toml has [edge_ca] section"
        else
            warn "config.toml missing [edge_ca] section — run option 7 to auto-patch"
        fi
    fi
    echo ""
    
    # ── 5. Systemd unit files ─────────────────────────────────────────────
    echo -e "${GREEN}[5/10] Systemd services...${NC}"
    
    for svc in aziot-edged aziot-identityd aziot-keyd aziot-certd; do
        if systemctl list-unit-files "${svc}.service" &>/dev/null 2>&1; then
            pass "${svc}.service unit file registered"
        else
            fail "${svc}.service unit file missing"
        fi
    done
    
    # Services should NOT be running before provisioning
    # If aziot-identityd is running without a valid config, it will attempt DPS contact
    local RUNNING_SERVICES=""
    for svc in aziot-edged aziot-identityd aziot-keyd aziot-certd aziot-tpmd; do
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            RUNNING_SERVICES+="$svc "
        fi
    done
    if [ -n "$RUNNING_SERVICES" ]; then
        fail "Azure IoT services are RUNNING before provisioning: ${RUNNING_SERVICES}"
        echo "         This means the device may be contacting Azure RIGHT NOW"
        echo "         Stop them: sudo systemctl stop aziot-edged aziot-identityd aziot-keyd aziot-certd"
    else
        pass "No Azure IoT services running (safe — not contacting Azure)"
    fi
    echo ""
    
    # ── 6. Docker engine ──────────────────────────────────────────────────
    echo -e "${GREEN}[6/10] Docker engine...${NC}"
    
    if command -v docker &>/dev/null; then
        pass "Docker binary found"
    else
        fail "Docker binary not found — run option 5 (Container Engine)"
    fi
    
    if systemctl is-active --quiet docker 2>/dev/null; then
        pass "Docker service is running"
    else
        fail "Docker service not running"
    fi
    
    # Verify Docker can actually run containers
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        if docker info &>/dev/null; then
            pass "Docker daemon responding"
        else
            fail "Docker daemon not responding (docker info failed)"
        fi
    fi
    echo ""
    
    # ── 7. Clean Docker state ─────────────────────────────────────────────
    echo -e "${GREEN}[7/10] Clean Docker state (no leftover containers)...${NC}"
    
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        local CONTAINER_COUNT=$(docker ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
        if [ "$CONTAINER_COUNT" -eq 0 ]; then
            pass "No Docker containers present (clean state)"
        else
            fail "${CONTAINER_COUNT} leftover container(s) found:"
            docker ps -a --format "  {{.Names}}  ({{.Status}})  {{.Image}}" 2>/dev/null | while read -r line; do
                echo -e "         ${RED}$line${NC}"
            done
            echo "         Run option 13 (Repair) to remove them"
        fi
        
        # Check for leftover IoT Edge network
        if docker network ls --format "{{.Name}}" 2>/dev/null | grep -qx "azure-iot-edge"; then
            fail "Leftover Docker network 'azure-iot-edge' found"
            echo "         Run: docker network rm azure-iot-edge"
        else
            pass "No leftover azure-iot-edge Docker network"
        fi
    else
        warn "Cannot check Docker state (Docker not running)"
    fi
    echo ""
    
    # ── 8. Persistent storage ownership ───────────────────────────────────
    echo -e "${GREEN}[8/10] Persistent storage ownership...${NC}"
    
    if [ -d /var/lib/iotedge/edgeAgent ]; then
        local EA_OWNER=$(stat -c '%u' /var/lib/iotedge/edgeAgent 2>/dev/null)
        if [ "$EA_OWNER" = "13622" ]; then
            pass "/var/lib/iotedge/edgeAgent owned by UID 13622 (edgeagentuser)"
        else
            fail "/var/lib/iotedge/edgeAgent owned by UID ${EA_OWNER} — must be 13622"
            echo "         Fix: sudo chown -R 13622:13622 /var/lib/iotedge/edgeAgent"
            echo "         Or re-run option 7 (Persistent Storage)"
        fi
    else
        warn "/var/lib/iotedge/edgeAgent not created yet — run option 7"
    fi
    
    if [ -d /var/lib/iotedge/edgeHub ]; then
        local EH_OWNER=$(stat -c '%u' /var/lib/iotedge/edgeHub 2>/dev/null)
        if [ "$EH_OWNER" = "13623" ]; then
            pass "/var/lib/iotedge/edgeHub owned by UID 13623 (edgehubuser)"
        else
            fail "/var/lib/iotedge/edgeHub owned by UID ${EH_OWNER} — must be 13623"
            echo "         Fix: sudo chown -R 13623:13623 /var/lib/iotedge/edgeHub"
            echo "         Or re-run option 7 (Persistent Storage)"
        fi
    else
        warn "/var/lib/iotedge/edgeHub not created yet — run option 7"
    fi
    echo ""
    
    # ── 9. Storage protection layers ───────────────────────────────────────
    echo -e "${GREEN}[9/10] Storage protection layers (auto-recovery)...${NC}"
    
    # Check tmpfiles.d config exists (boot-time protection)
    if [ -f /etc/tmpfiles.d/iotedge-storage.conf ]; then
        if grep -q "13622" /etc/tmpfiles.d/iotedge-storage.conf 2>/dev/null && \
           grep -q "13623" /etc/tmpfiles.d/iotedge-storage.conf 2>/dev/null; then
            pass "tmpfiles.d config installed (ownership auto-fixed on every boot)"
        else
            fail "tmpfiles.d config exists but has wrong UIDs — re-run option 7"
        fi
    else
        fail "tmpfiles.d config missing — ownership won't survive reboots"
        echo "         Fix: re-run option 7 (Persistent Storage)"
    fi
    
    # Check systemd drop-in has ExecStartPre (service-start protection)
    local DROPIN_DIR=""
    if [ -d /etc/systemd/system/aziot-edged.service.d ]; then
        DROPIN_DIR="/etc/systemd/system/aziot-edged.service.d"
    elif [ -d /etc/systemd/system/iotedge.service.d ]; then
        DROPIN_DIR="/etc/systemd/system/iotedge.service.d"
    fi
    
    if [ -n "$DROPIN_DIR" ] && [ -f "${DROPIN_DIR}/persistent-storage.conf" ]; then
        if grep -q "ExecStartPre=+" "${DROPIN_DIR}/persistent-storage.conf" 2>/dev/null; then
            pass "Systemd drop-in has ExecStartPre=+ (runs chown as root before every start)"
        elif grep -q "ExecStartPre=" "${DROPIN_DIR}/persistent-storage.conf" 2>/dev/null; then
            fail "Systemd drop-in has ExecStartPre WITHOUT '+' prefix — chown runs as non-root and fails"
            echo "         Fix: re-run option 7 (Persistent Storage) to update the drop-in"
            echo "         The '+' prefix tells systemd to run the command as root"
        else
            warn "Systemd drop-in exists but missing ExecStartPre — re-run option 7 to upgrade"
            echo "         Old drop-in only had environment variables (no protection)"
        fi
    else
        warn "No systemd drop-in for persistent storage — re-run option 7"
    fi
    echo ""
    
    # ── 10. Network / DNS readiness ───────────────────────────────────────
    echo -e "${GREEN}[10/10] Network readiness (local checks only)...${NC}"
    
    # Check DNS resolution works (using a non-Azure domain to avoid triggering anything)
    if timeout 5 nslookup google.com &>/dev/null; then
        pass "DNS resolution working"
    else
        fail "DNS resolution failed — containers won't be able to pull images"
    fi
    
    # Check we can resolve the DPS endpoint (DNS only, no HTTP connection)
    if timeout 5 nslookup global.azure-devices-provisioning.net &>/dev/null; then
        pass "Can resolve global.azure-devices-provisioning.net (DNS only)"
    else
        warn "Cannot resolve DPS endpoint — check DNS/firewall"
    fi
    
    # Check we can resolve the ACR endpoint (DNS only, no HTTP connection)
    if timeout 5 nslookup openpointiotmodules-aubsa0egcxaycybt.azurecr.io &>/dev/null; then
        pass "Can resolve ACR (openpointiotmodules-*.azurecr.io) (DNS only)"
    else
        warn "Cannot resolve ACR endpoint — module images won't pull"
    fi
    echo ""
    
    # ── Summary ───────────────────────────────────────────────────────────
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│         HEALTH CHECK RESULTS               │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}PASS: ${PASS}${NC}   ${YELLOW}WARN: ${WARN}${NC}   ${RED}FAIL: ${FAIL}${NC}"
    echo ""
    
    if [ $FAIL -eq 0 ]; then
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}│  ✅ ALL CHECKS PASSED — SAFE TO PROVISION               │${NC}"
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "The installation is clean. You can now safely:"
        echo ""
        echo "  1. sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml"
        echo "  2. sudo nano /etc/aziot/config.toml   # Add DPS provisioning details"
        echo -e "  3. ${GREEN}Run option 16 (Apply Config)${NC} — auto-patches certs and applies safely"
        echo ""
        echo -e "  ${RED}DO NOT run 'sudo iotedge config apply' directly — use option 16.${NC}"
        echo ""
        if [ $WARN -gt 0 ]; then
            echo -e "${YELLOW}Review the warnings above but they won't prevent provisioning.${NC}"
            echo ""
        fi
        echo -e "${CYAN}Safe commands to run NOW (before config apply):${NC}"
        echo "  iotedge --version          # Print version (no network)"
        echo "  iotedge system status      # Check service states (should all be inactive)"
        echo ""
        echo -e "${YELLOW}Commands to AVOID until after config apply:${NC}"
        echo "  iotedge list               # Hangs — needs running services"
        echo "  iotedge check              # Probes Azure endpoints"
        echo ""
        echo -e "${CYAN}After config apply, verify with:${NC}"
        echo "  sudo iotedge system status # All services should be 'active (running)'"
        echo "  sudo iotedge list          # Should show edgeAgent within ~2 minutes"
        echo ""
        return 0
    else
        echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}│  ❌ ${FAIL} CHECK(S) FAILED — DO NOT PROVISION YET         │${NC}"
        echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${RED}Fix the failures above before running 'iotedge config apply'.${NC}"
        echo -e "${RED}Provisioning with a broken install may corrupt Azure state${NC}"
        echo -e "${RED}(corrupted device identity, broken DPS enrollment, portal crash).${NC}"
        echo ""
        echo -e "${YELLOW}Safe commands you CAN run to investigate:${NC}"
        echo "  iotedge --version          # Verify binary exists"
        echo "  iotedge system status      # Check if anything is unexpectedly running"
        echo "  dpkg -l aziot-edge         # Check package state (should show 'ii')"
        echo "  sudo systemctl stop aziot-identityd  # Stop if it's running!"
        echo ""
        return 1
    fi
}

# Apply IoT Edge configuration safely.
#
# This is the ONLY recommended way to run "iotedge config apply".
# It ensures Edge CA certificates exist and config.toml references them
# BEFORE applying, which prevents the quickstart cert generation bug:
#   "could not load cert with id aziot-edged-trust-bundle"
#
# The flow:
#   1. Verify config.toml exists (user must create it from template first)
#   2. Generate Edge CA certs if they don't exist
#   3. Patch config.toml to reference the certs (trust_bundle_cert + [edge_ca])
#   4. Stop all aziot services (clean slate)
#   5. Clear stale runtime data (corrupt cert/key database entries)
#   6. Run "iotedge config apply" (generates 00-super.toml + restarts services)
#   7. Wait and show status
apply_iotedge_config() {
    echo -e "${BLUE}[APPLY IoT EDGE CONFIGURATION]${NC}"
    echo ""
    
    # Temporarily disable exit-on-error
    set +e
    
    # ── Step 1: Verify config.toml exists ─────────────────────────────────
    local CONFIG="/etc/aziot/config.toml"
    
    if [ ! -f "$CONFIG" ]; then
        echo -e "${RED}✗ config.toml not found at $CONFIG${NC}"
        echo ""
        echo "You must create config.toml before applying:"
        echo ""
        echo "  sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml"
        echo "  sudo nano /etc/aziot/config.toml   # Add DPS provisioning details"
        echo ""
        echo "Then run this option again."
        set -e
        return 1
    fi
    
    echo -e "${GREEN}[1/7] config.toml found${NC}"
    
    # Verify it has provisioning settings (basic sanity check)
    if ! grep -q '^\[provisioning\]' "$CONFIG" 2>/dev/null; then
        echo -e "${YELLOW}  ⚠ config.toml may not have [provisioning] section configured${NC}"
        echo "    Make sure you've added your DPS or connection string settings."
        echo ""
        read -p "  Continue anyway? (y/N): " REPLY
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            set -e
            return 0
        fi
    else
        echo "  ✓ [provisioning] section found"
    fi
    echo ""
    
    # ── Step 2: Generate Edge CA certificates ─────────────────────────────
    echo -e "${GREEN}[2/7] Ensuring Edge CA certificates exist...${NC}"
    generate_edge_certificates
    echo ""
    
    # ── Step 3: Patch config.toml with cert references ────────────────────
    echo -e "${GREEN}[3/7] Patching config.toml with cert references...${NC}"
    patch_config_trust_bundle
    
    # Show what's in config.toml for verification
    if grep -q '^trust_bundle_cert' "$CONFIG" 2>/dev/null; then
        echo "  ✓ trust_bundle_cert is set"
    else
        echo -e "${RED}  ✗ trust_bundle_cert not found in config.toml after patching${NC}"
    fi
    if grep -q '^\[edge_ca\]' "$CONFIG" 2>/dev/null; then
        echo "  ✓ [edge_ca] section is set"
    else
        echo -e "${RED}  ✗ [edge_ca] section not found in config.toml after patching${NC}"
    fi
    echo ""
    
    # ── Step 4: Stop all aziot services ───────────────────────────────────
    echo -e "${GREEN}[4/7] Stopping all Azure IoT services...${NC}"
    for svc in aziot-edged aziot-identityd aziot-keyd aziot-certd aziot-tpmd; do
        systemctl stop "${svc}.service" 2>/dev/null && echo "  ✓ Stopped ${svc}" || true
    done
    echo ""
    
    # ── Step 5: Clear stale runtime data ──────────────────────────────────
    echo -e "${GREEN}[5/7] Clearing stale runtime data...${NC}"
    for state_dir in /var/lib/aziot/certd /var/lib/aziot/keyd /var/lib/aziot/identityd /var/lib/aziot/edged; do
        if [ -d "$state_dir" ]; then
            local fc=$(find "$state_dir" -type f 2>/dev/null | wc -l)
            if [ "$fc" -gt 0 ]; then
                find "$state_dir" -type f -delete 2>/dev/null
                echo "  ✓ Cleared $fc file(s) from $state_dir"
            fi
        fi
    done
    echo "  ✓ Runtime data cleared (certs/keys will be regenerated)"
    echo ""
    
    # ── Step 6: Remove stale Docker containers ────────────────────────────
    echo -e "${GREEN}[6/7] Cleaning stale Docker containers...${NC}"
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        for container in edgeAgent edgeHub; do
            if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -qx "$container"; then
                local STATUS=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)
                docker rm -f "$container" 2>/dev/null
                echo "  ✓ Removed $container (was: ${STATUS:-unknown})"
            fi
        done
        if docker network ls --format "{{.Name}}" 2>/dev/null | grep -qx "azure-iot-edge"; then
            docker network rm azure-iot-edge 2>/dev/null
            echo "  ✓ Removed stale network: azure-iot-edge"
        fi
    fi
    echo ""
    
    # ── Step 7: Apply configuration ───────────────────────────────────────
    echo -e "${GREEN}[7/7] Applying IoT Edge configuration...${NC}"
    echo ""
    echo -e "${YELLOW}  This will contact Azure DPS and register the device.${NC}"
    read -p "  Continue? (y/N): " REPLY
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "  Cancelled. Config.toml has been patched with cert references."
        echo "  You can run 'sudo iotedge config apply' manually when ready."
        set -e
        return 0
    fi
    
    iotedge config apply 2>&1 | sed 's/^/    /'
    local apply_result=$?
    
    if [ $apply_result -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ IoT Edge config applied and services started${NC}"
        echo ""
        echo "  Waiting 20 seconds for edgeAgent to start..."
        sleep 20
        
        echo ""
        echo "  Service status:"
        iotedge system status 2>/dev/null | sed 's/^/    /' || echo "    (could not get status)"
        
        echo ""
        echo "  Container status:"
        docker ps --format "    {{.Names}}  {{.Status}}  {{.Image}}" 2>/dev/null || echo "    (no containers yet)"
        
        echo ""
        echo -e "${CYAN}Verify with:${NC}"
        echo "  sudo iotedge system status"
        echo "  sudo iotedge list"
        echo "  sudo iotedge check"
    else
        echo ""
        echo -e "${RED}✗ iotedge config apply failed (exit code: $apply_result)${NC}"
        echo ""
        echo "  Check the logs:"
        echo "    sudo journalctl -u aziot-certd -n 30 --no-pager"
        echo "    sudo journalctl -u aziot-keyd -n 30 --no-pager"
        echo "    sudo journalctl -u aziot-edged -n 30 --no-pager"
    fi
    echo ""
    
    set -e
    return $apply_result
}

# Quarantine device — immediately stop and disable all Azure IoT services
# Use this when a broken device is actively corrupting Azure DPS/IoT Hub state.
# After quarantine, the device will NOT contact Azure even after reboot.
quarantine_device() {
    echo -e "${RED}════════════════════════════════════════════${NC}"
    echo -e "${RED}│  QUARANTINE DEVICE                         │${NC}"
    echo -e "${RED}════════════════════════════════════════════${NC}"
    echo ""
    echo "This will immediately:"
    echo "  • Stop all Azure IoT Edge services"
    echo "  • Disable them from starting on reboot"
    echo "  • Stop all IoT Edge containers (edgeAgent, edgeHub, modules)"
    echo ""
    echo -e "${CYAN}The device will NOT contact Azure until you manually re-enable.${NC}"
    echo ""
    
    # Step 1: Stop all aziot services immediately
    echo -e "${GREEN}[1/3] Stopping all Azure IoT services...${NC}"
    local SERVICES=("aziot-edged" "aziot-identityd" "aziot-keyd" "aziot-certd" "aziot-tpmd")
    for svc in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            systemctl stop "${svc}.service" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} Stopped ${svc}"
        else
            echo "  · ${svc} already stopped"
        fi
    done
    echo ""
    
    # Step 2: Disable auto-start on boot
    echo -e "${GREEN}[2/3] Disabling auto-start on boot...${NC}"
    for svc in "${SERVICES[@]}"; do
        systemctl disable "${svc}.service" 2>/dev/null || true
    done
    echo "  ✓ All aziot services disabled (won't start on reboot)"
    echo ""
    
    # Step 3: Stop containers
    echo -e "${GREEN}[3/3] Stopping IoT Edge containers...${NC}"
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        for container in edgeAgent edgeHub; do
            if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -qx "$container"; then
                local STATUS=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null)
                docker rm -f "$container" 2>/dev/null
                echo "  ✓ Removed $container (was: ${STATUS:-unknown})"
            fi
        done
        
        # Also stop any module containers (ScadaPollingModule, etc.)
        local MODULE_CONTAINERS=$(docker ps -a --format "{{.Names}}" 2>/dev/null | grep -v -E "^$")
        if [ -n "$MODULE_CONTAINERS" ]; then
            echo "$MODULE_CONTAINERS" | while read -r cname; do
                docker stop "$cname" 2>/dev/null && echo "  ✓ Stopped $cname" || true
            done
        else
            echo "  · No containers running"
        fi
    else
        echo "  · Docker not running"
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}│  DEVICE QUARANTINED                       │${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}This device is now SAFE — it will not contact Azure, even after reboot.${NC}"
    echo ""
    echo "Next steps to fix and reconnect:"
    echo ""
    echo "  1. Clean Azure state from the portal:"
    echo "     • DPS → Manage enrollments → Individual enrollments"
    echo "       → Find the device → Delete registration (or disable)"
    echo "     • IoT Hub → Devices → Find the device → Delete"
    echo ""
    echo "  2. Fix the device (choose one):"
    echo "     • Option 13 (Repair) — purge and clean reinstall"
    echo "     • Option 7 (Persistent Storage) — fix ownership only"
    echo "     • Option 1 (Full Setup) — complete reinstall"
    echo ""
    echo "  3. Run option 14 (Health Check) to verify the install is clean"
    echo ""
    echo "  4. Re-enable and provision:"
    echo "       sudo systemctl enable aziot-edged aziot-identityd aziot-keyd aziot-certd"
    echo "       sudo cp /etc/aziot/config.toml.edge.template /etc/aziot/config.toml"
    echo "       sudo nano /etc/aziot/config.toml   # Add DPS details"
    echo -e "       ${GREEN}Run option 16 (Apply Config)${NC} — auto-patches certs and applies safely"
    echo ""
    echo -e "  ${RED}DO NOT run 'sudo iotedge config apply' directly — use option 16.${NC}"
    echo ""
    
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
    echo "   12. Enable TPM Hardware - Enable the Nuvoton NPCT750 TPM overlay"
    echo "       (then reboot again, and run option 11 to extract the key)"
    echo "   11. Extract TPM Key - Get registration ID and endorsement key"
    echo ""
    echo "To provision the device after setting up config.toml:"
    echo -e "   ${GREEN}16. Apply Config${NC} - Safely apply config (generates certs, patches config, applies)"
    echo -e "   ${RED}DO NOT run 'sudo iotedge config apply' directly — use option 16.${NC}"
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
            12)
                enable_tpm_hardware
                read -p "Press ENTER to return to menu..." dummy
                ;;
            13)
                repair_iotedge
                read -p "Press ENTER to return to menu..." dummy
                ;;
            14)
                verify_iotedge_health
                read -p "Press ENTER to return to menu..." dummy
                ;;
            15)
                quarantine_device
                read -p "Press ENTER to return to menu..." dummy
                ;;
            16)
                apply_iotedge_config
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
