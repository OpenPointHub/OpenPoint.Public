#!/bin/bash

###############################################################################
# System Updates Module
# Purpose: Update packages, install essential tools, disable unnecessary services
###############################################################################

system_updates() {
    echo -e "${BLUE}[STEP 2] System Updates & Package Installation${NC}"
    echo ""
    
    # Update system
    echo -e "${GREEN}[1/3] Updating system packages...${NC}"
    apt-get update --fix-missing > /dev/null 2>&1 || apt-get update --fix-missing
    apt-get upgrade -y --fix-missing > /dev/null 2>&1
    echo "  ? System packages updated"
    
    # Install essential packages
    echo ""
    echo -e "${GREEN}[2/3] Installing essential packages...${NC}"
    apt-get install -y --fix-missing \
        curl wget git ca-certificates gnupg lsb-release \
        smartmontools iotop htop net-tools iftop > /dev/null 2>&1
    echo "  ? Essential packages installed"
    
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
    
    echo "  ? Disabled: Bluetooth, ModemManager, CUPS, cloud-init"
    echo ""
    echo -e "${GREEN}? System updates complete${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    system_updates
fi
