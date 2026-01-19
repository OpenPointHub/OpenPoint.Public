#!/bin/bash

###############################################################################
# System Configuration Module
# Purpose: Configure keyboard, timezone, locale, and detect hardware
###############################################################################

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
    echo "  ? Keyboard layout set to US"
    
    # Set timezone to UTC
    echo ""
    echo -e "${GREEN}[2/4] Setting timezone to UTC...${NC}"
    timedatectl set-timezone UTC
    echo "  ? Timezone set to UTC"
    
    # Configure locale to en_US.UTF-8
    echo ""
    echo -e "${GREEN}[3/4] Configuring locale to en_US.UTF-8...${NC}"
    locale-gen en_US.UTF-8 > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 > /dev/null 2>&1
    echo "  ? Locale set to en_US.UTF-8"
    
    # Detect hardware
    echo ""
    echo -e "${GREEN}[4/4] Detecting hardware...${NC}"
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    DISK_SIZE=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')
    ARCH=$(uname -m)
    
    echo "  ?? RAM: ${TOTAL_RAM}MB"
    echo "  ?? Disk: ${DISK_SIZE}GB"
    echo "  ???  Architecture: ${ARCH}"
    
    if [[ $TOTAL_RAM -lt 3800 ]]; then
        echo -e "${YELLOW}  ? Warning: Less than 4GB RAM detected.${NC}"
    fi
    
    if [[ $ARCH != "aarch64" && $ARCH != "arm64" ]]; then
        echo -e "${YELLOW}  ? Warning: Not ARM64 architecture.${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}? System configuration complete${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    system_configuration
fi
