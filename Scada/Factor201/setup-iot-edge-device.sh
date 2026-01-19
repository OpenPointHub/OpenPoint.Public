#!/bin/bash

###############################################################################
# Ubuntu Server Optimization Script for Raspberry Pi Factor 201
# Hardware: 4GB RAM, 128GB SSD
# Purpose: Prepare system for OpenPoint SCADA Polling IoT Edge Module
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
###############################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Base URL for modules
BASE_URL="https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/modules"

# Module cache directory (persistent location)
MODULE_CACHE_DIR="/usr/local/share/openpoint-setup/modules"

# Download and source a module
source_module() {
    local module_name=$1
    local module_file="${MODULE_CACHE_DIR}/${module_name}.sh"
    
    # Create cache directory if it doesn't exist
    mkdir -p "${MODULE_CACHE_DIR}"
    
    # Download module if not cached or force refresh
    if [ ! -f "${module_file}" ] || [ "${FORCE_REFRESH:-false}" = "true" ]; then
        echo -e "${CYAN}  → Downloading ${module_name}...${NC}"
        wget -q ${BASE_URL}/${module_name}.sh -O ${module_file} 2>/dev/null || {
            echo -e "${RED}✗ Failed to download ${module_name}${NC}"
            return 1
        }
        chmod +x ${module_file}
    else
        echo -e "${GREEN}  ✓ Using cached ${module_name}${NC}"
    fi
    
    # Source the module with colors available
    export RED GREEN YELLOW BLUE CYAN NC
    source ${module_file}
    return 0
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
    echo -e "  ${GREEN}9${NC}) Refresh Module Cache - Re-download all setup modules"
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

# Refresh module cache
refresh_module_cache() {
    echo -e "${BLUE}Refreshing Module Cache${NC}"
    echo ""
    echo "This will re-download all setup modules to get the latest versions."
    echo ""
    read -p "Continue? (y/N): " REPLY
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Refresh cancelled."
        return 0
    fi
    
    echo -e "${CYAN}Removing cached modules...${NC}"
    if [ -d "${MODULE_CACHE_DIR}" ]; then
        rm -rf "${MODULE_CACHE_DIR}"
        echo -e "${GREEN}  ✓ Cache cleared${NC}"
    else
        echo -e "${YELLOW}  ℹ️  No cache to clear${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Downloading fresh modules...${NC}"
    export FORCE_REFRESH=true
    
    local modules=("system-config" "system-updates" "system-optimization" "container-engine" "iotedge-runtime" "helper-scripts")
    local success=0
    local failed=0
    
    for module in "${modules[@]}"; do
        if source_module "$module" > /dev/null 2>&1; then
            ((success++))
        else
            ((failed++))
            echo -e "${RED}  ✗ Failed to download ${module}${NC}"
        fi
    done
    
    unset FORCE_REFRESH
    
    echo ""
    echo -e "${GREEN}✓ Module cache refreshed${NC}"
    echo "  Downloaded: ${success} modules"
    if [ $failed -gt 0 ]; then
        echo -e "${YELLOW}  Failed: ${failed} modules${NC}"
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

# Full setup
full_setup() {
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Starting Full Setup - This may take 15-20 minutes${NC}"
    echo -e "${CYAN}════════════════════════════════════════════${NC}"
    echo ""
    
    show_requirements
    check_iotedge_installed || return 1
    cleanup_duplicates
    
    # Download and execute each module
    echo -e "${CYAN}Downloading setup modules...${NC}"
    
    source_module "system-config" && system_configuration
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    source_module "system-updates" && system_updates
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    source_module "system-optimization" && system_optimization
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    source_module "container-engine" && container_engine
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    source_module "iotedge-runtime" && iotedge_runtime
    echo ""
    read -p "Press ENTER to continue..." dummy
    
    source_module "helper-scripts" && helper_scripts
    
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
                source_module "system-config" && system_configuration
                read -p "Press ENTER to return to menu..." dummy
                ;;
            3)
                source_module "system-updates" && system_updates
                read -p "Press ENTER to return to menu..." dummy
                ;;
            4)
                source_module "system-optimization" && system_optimization
                read -p "Press ENTER to return to menu..." dummy
                ;;
            5)
                source_module "container-engine" && container_engine
                read -p "Press ENTER to return to menu..." dummy
                ;;
            6)
                check_iotedge_installed || continue
                source_module "iotedge-runtime" && iotedge_runtime
                read -p "Press ENTER to return to menu..." dummy
                ;;
            7)
                source_module "helper-scripts" && helper_scripts
                read -p "Press ENTER to return to menu..." dummy
                ;;
            8)
                cleanup_duplicates
                echo -e "${GREEN}✓ Cleanup complete${NC}"
                read -p "Press ENTER to return to menu..." dummy
                ;;
            9)
                refresh_module_cache
                read -p "Press ENTER to return to menu..." dummy
                ;;
            0)
                echo "Exiting..."
                # Cleanup any remaining temp files
                rm -f /tmp/{system-config,system-updates,system-optimization,container-engine,iotedge-runtime,helper-scripts}.sh
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
