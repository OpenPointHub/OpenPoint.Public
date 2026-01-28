#!/bin/bash

###############################################################################
# Firewall Configuration Script for OpenPoint SCADA IoT Edge Devices
# Purpose: Configure UFW firewall for secure IoT Edge and SCADA operations
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
###############################################################################

# Exit on error
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration file
FIREWALL_CONFIG="/etc/openpoint/firewall-config.conf"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root (use sudo)${NC}" 
        exit 1
    fi
}

# Show menu
show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│  IoT Edge Firewall Configuration          │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Select firewall configuration option:"
    echo ""
    echo -e "  ${GREEN}1${NC}) Configure Basic Firewall (IoT Edge + System Updates)"
    echo -e "  ${GREEN}2${NC}) Configure Full Firewall (IoT Edge + SCADA + Updates)"
    echo -e "  ${GREEN}3${NC}) Add RTAC Device Access"
    echo -e "  ${GREEN}4${NC}) Configure SSH Access (Management Network)"
    echo -e "  ${GREEN}5${NC}) Show Current Firewall Rules"
    echo -e "  ${GREEN}6${NC}) Test Connectivity"
    echo -e "  ${GREEN}7${NC}) Disable Firewall"
    echo -e "  ${GREEN}8${NC}) Enable Firewall"
    echo ""
    echo -e "  ${YELLOW}0${NC}) Exit"
    echo ""
    
    # Show current status
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$(ufw status | head -1)
        if [[ $UFW_STATUS == *"active"* ]]; then
            echo -e "${CYAN}Current Status: ${GREEN}Firewall Active${NC}"
        else
            echo -e "${CYAN}Current Status: ${YELLOW}Firewall Inactive${NC}"
        fi
    else
        echo -e "${CYAN}Current Status: ${RED}UFW not installed${NC}"
    fi
    echo ""
}

# Install UFW if needed
install_ufw() {
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}UFW not installed. Installing...${NC}"
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y ufw > /dev/null 2>&1
        echo -e "${GREEN}✓ UFW installed${NC}"
    fi
}

# Save configuration
save_config() {
    local rtac_ip=$1
    local mgmt_network=$2
    
    mkdir -p /etc/openpoint
    cat > "$FIREWALL_CONFIG" <<EOF
# OpenPoint SCADA Firewall Configuration
# Generated: $(date)

RTAC_IP=$rtac_ip
MGMT_NETWORK=$mgmt_network
EOF
    echo -e "${GREEN}✓ Configuration saved to $FIREWALL_CONFIG${NC}"
}

# Load configuration
load_config() {
    if [ -f "$FIREWALL_CONFIG" ]; then
        source "$FIREWALL_CONFIG"
    fi
}

# Configure basic firewall (IoT Edge + Updates)
configure_basic_firewall() {
    echo -e "${BLUE}[BASIC FIREWALL CONFIGURATION]${NC}"
    echo ""
    echo "This will configure firewall rules for:"
    echo "  • Azure IoT Hub connectivity (AMQPS, HTTPS)"
    echo "  • Container registry access (HTTPS)"
    echo "  • DNS resolution"
    echo "  • System updates (Ubuntu, Microsoft)"
    echo "  • NTP time synchronization"
    echo ""
    read -p "Continue? (y/N): " REPLY
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    install_ufw
    
    echo "Configuring firewall rules..."
    
    # Disable UFW temporarily
    ufw --force disable > /dev/null 2>&1
    
    # Reset to defaults
    ufw --force reset > /dev/null 2>&1
    
    # Default policies
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    echo -e "${GREEN}[1/6] Basic rules configured${NC}"
    
    # DNS (Critical)
    ufw allow out 53/tcp comment 'DNS TCP' > /dev/null 2>&1
    ufw allow out 53/udp comment 'DNS UDP' > /dev/null 2>&1
    echo -e "${GREEN}[2/6] DNS rules configured${NC}"
    
    # NTP (Recommended)
    ufw allow out 123/udp comment 'NTP time sync' > /dev/null 2>&1
    echo -e "${GREEN}[3/6] NTP rules configured${NC}"
    
    # Azure IoT Hub - AMQPS (Primary)
    ufw allow out 5671/tcp comment 'Azure IoT Hub AMQPS' > /dev/null 2>&1
    echo -e "${GREEN}[4/6] Azure IoT Hub AMQPS configured${NC}"
    
    # HTTPS (IoT Hub fallback, Container Registry, Updates)
    ufw allow out 443/tcp comment 'HTTPS - IoT Hub, ACR, Updates' > /dev/null 2>&1
    echo -e "${GREEN}[5/6] HTTPS rules configured${NC}"
    
    # HTTP (System updates)
    ufw allow out 80/tcp comment 'HTTP - System updates' > /dev/null 2>&1
    echo -e "${GREEN}[6/6] HTTP rules configured${NC}"
    
    # Enable UFW
    ufw --force enable > /dev/null 2>&1
    
    echo ""
    echo -e "${GREEN}✓ Basic firewall configured and enabled${NC}"
    echo ""
    echo "Configured rules:"
    echo "  • Outbound DNS (port 53)"
    echo "  • Outbound NTP (port 123)"
    echo "  • Outbound AMQPS to Azure (port 5671)"
    echo "  • Outbound HTTPS (port 443)"
    echo "  • Outbound HTTP (port 80)"
    echo ""
    echo -e "${YELLOW}⚠️  SSH access not configured. Use Option 4 to enable SSH.${NC}"
    echo ""
}

# Configure full firewall (IoT Edge + SCADA + Updates)
configure_full_firewall() {
    echo -e "${BLUE}[FULL FIREWALL CONFIGURATION]${NC}"
    echo ""
    
    # Load existing config
    load_config
    
    # Get RTAC IP
    if [ -z "$RTAC_IP" ]; then
        read -p "Enter RTAC IP address (e.g., 192.168.1.100): " RTAC_IP
    else
        read -p "Enter RTAC IP address [$RTAC_IP]: " NEW_RTAC_IP
        RTAC_IP=${NEW_RTAC_IP:-$RTAC_IP}
    fi
    
    # Validate IP
    if ! [[ $RTAC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}Invalid IP address format${NC}"
        return
    fi
    
    echo ""
    echo "This will configure firewall rules for:"
    echo "  • Azure IoT Hub connectivity"
    echo "  • Container registry access"
    echo "  • RTAC polling (HTTP/HTTPS to $RTAC_IP)"
    echo "  • DNS, NTP, System updates"
    echo ""
    read -p "Continue? (y/N): " REPLY
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    install_ufw
    
    echo "Configuring firewall rules..."
    
    # Disable UFW temporarily
    ufw --force disable > /dev/null 2>&1
    
    # Reset to defaults
    ufw --force reset > /dev/null 2>&1
    
    # Default policies
    ufw default deny incoming > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    
    echo -e "${GREEN}[1/8] Basic rules configured${NC}"
    
    # DNS
    ufw allow out 53/tcp comment 'DNS TCP' > /dev/null 2>&1
    ufw allow out 53/udp comment 'DNS UDP' > /dev/null 2>&1
    echo -e "${GREEN}[2/8] DNS rules configured${NC}"
    
    # NTP
    ufw allow out 123/udp comment 'NTP time sync' > /dev/null 2>&1
    echo -e "${GREEN}[3/8] NTP rules configured${NC}"
    
    # Azure IoT Hub - AMQPS
    ufw allow out 5671/tcp comment 'Azure IoT Hub AMQPS' > /dev/null 2>&1
    echo -e "${GREEN}[4/8] Azure IoT Hub AMQPS configured${NC}"
    
    # HTTPS (IoT Hub, ACR, Updates)
    ufw allow out 443/tcp comment 'HTTPS - IoT Hub, ACR, Updates' > /dev/null 2>&1
    echo -e "${GREEN}[5/8] HTTPS rules configured${NC}"
    
    # HTTP (Updates)
    ufw allow out 80/tcp comment 'HTTP - System updates' > /dev/null 2>&1
    echo -e "${GREEN}[6/8] HTTP rules configured${NC}"
    
    # RTAC HTTP
    ufw allow out to $RTAC_IP port 80 proto tcp comment "RTAC HTTP - $RTAC_IP" > /dev/null 2>&1
    echo -e "${GREEN}[7/8] RTAC HTTP access configured${NC}"
    
    # RTAC HTTPS
    ufw allow out to $RTAC_IP port 443 proto tcp comment "RTAC HTTPS - $RTAC_IP" > /dev/null 2>&1
    echo -e "${GREEN}[8/8] RTAC HTTPS access configured${NC}"
    
    # Enable UFW
    ufw --force enable > /dev/null 2>&1
    
    # Save config
    save_config "$RTAC_IP" "$MGMT_NETWORK"
    
    echo ""
    echo -e "${GREEN}✓ Full firewall configured and enabled${NC}"
    echo ""
    echo "Configured rules:"
    echo "  • Outbound DNS (port 53)"
    echo "  • Outbound NTP (port 123)"
    echo "  • Outbound AMQPS to Azure (port 5671)"
    echo "  • Outbound HTTPS (port 443)"
    echo "  • Outbound HTTP (port 80)"
    echo "  • Outbound HTTP to RTAC ($RTAC_IP:80)"
    echo "  • Outbound HTTPS to RTAC ($RTAC_IP:443)"
    echo ""
    echo -e "${YELLOW}⚠️  SSH access not configured. Use Option 4 to enable SSH.${NC}"
    echo ""
}

# Add RTAC device access
add_rtac_access() {
    echo -e "${BLUE}[ADD RTAC DEVICE ACCESS]${NC}"
    echo ""
    
    # Load existing config
    load_config
    
    # Get RTAC IP
    read -p "Enter RTAC IP address (e.g., 192.168.1.100): " RTAC_IP
    
    # Validate IP
    if ! [[ $RTAC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}Invalid IP address format${NC}"
        return
    fi
    
    echo ""
    echo "This will add firewall rules for:"
    echo "  • HTTP access to $RTAC_IP (port 80)"
    echo "  • HTTPS access to $RTAC_IP (port 443)"
    echo ""
    read -p "Continue? (y/N): " REPLY
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    install_ufw
    
    # Add rules
    ufw allow out to $RTAC_IP port 80 proto tcp comment "RTAC HTTP - $RTAC_IP" > /dev/null 2>&1
    ufw allow out to $RTAC_IP port 443 proto tcp comment "RTAC HTTPS - $RTAC_IP" > /dev/null 2>&1
    
    # Save config
    save_config "$RTAC_IP" "$MGMT_NETWORK"
    
    echo -e "${GREEN}✓ RTAC access configured${NC}"
    echo ""
    echo "Added rules:"
    echo "  • Outbound HTTP to $RTAC_IP (port 80)"
    echo "  • Outbound HTTPS to $RTAC_IP (port 443)"
    echo ""
}

# Configure SSH access
configure_ssh_access() {
    echo -e "${BLUE}[CONFIGURE SSH ACCESS]${NC}"
    echo ""
    
    # Load existing config
    load_config
    
    echo "SSH access can be configured in two ways:"
    echo ""
    echo "  1) Allow from specific management network (RECOMMENDED)"
    echo "     Example: 192.168.1.0/24"
    echo ""
    echo "  2) Allow from anywhere (NOT RECOMMENDED)"
    echo "     Use only for testing or if VPN is configured"
    echo ""
    read -p "Select option (1/2): " SSH_OPTION
    echo
    
    case $SSH_OPTION in
        1)
            if [ -z "$MGMT_NETWORK" ]; then
                read -p "Enter management network (e.g., 192.168.1.0/24): " MGMT_NETWORK
            else
                read -p "Enter management network [$MGMT_NETWORK]: " NEW_MGMT_NETWORK
                MGMT_NETWORK=${NEW_MGMT_NETWORK:-$MGMT_NETWORK}
            fi
            
            # Validate network
            if ! [[ $MGMT_NETWORK =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                echo -e "${RED}Invalid network format. Use CIDR notation (e.g., 192.168.1.0/24)${NC}"
                return
            fi
            
            install_ufw
            
            # Add SSH rule
            ufw allow from $MGMT_NETWORK to any port 22 proto tcp comment "SSH from management network" > /dev/null 2>&1
            
            # Save config
            save_config "$RTAC_IP" "$MGMT_NETWORK"
            
            echo -e "${GREEN}✓ SSH access configured${NC}"
            echo ""
            echo "SSH access allowed from: $MGMT_NETWORK"
            echo ""
            ;;
            
        2)
            echo -e "${YELLOW}⚠️  WARNING: This will allow SSH from ANY IP address${NC}"
            echo "This is NOT recommended for production systems."
            echo ""
            read -p "Are you sure? (y/N): " REPLY
            echo
            
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
            
            install_ufw
            
            # Add SSH rule (allow from anywhere)
            ufw allow 22/tcp comment 'SSH from anywhere' > /dev/null 2>&1
            
            echo -e "${YELLOW}✓ SSH access allowed from anywhere${NC}"
            echo ""
            echo -e "${RED}WARNING: SSH is now accessible from the entire internet.${NC}"
            echo "Consider using a VPN or restricting to a specific network."
            echo ""
            ;;
            
        *)
            echo -e "${RED}Invalid option${NC}"
            return
            ;;
    esac
}

# Show current firewall rules
show_firewall_rules() {
    echo -e "${BLUE}[CURRENT FIREWALL RULES]${NC}"
    echo ""
    
    if ! command -v ufw &> /dev/null; then
        echo -e "${RED}UFW not installed${NC}"
        return
    fi
    
    # Show status
    echo -e "${CYAN}Firewall Status:${NC}"
    ufw status verbose
    echo ""
    
    # Show numbered rules
    echo -e "${CYAN}Detailed Rules:${NC}"
    ufw status numbered
    echo ""
    
    # Show saved configuration
    if [ -f "$FIREWALL_CONFIG" ]; then
        echo -e "${CYAN}Saved Configuration:${NC}"
        cat "$FIREWALL_CONFIG"
        echo ""
    fi
}

# Test connectivity
test_connectivity() {
    echo -e "${BLUE}[CONNECTIVITY TEST]${NC}"
    echo ""
    
    load_config
    
    # Test DNS
    echo -e "${CYAN}[1/6] Testing DNS resolution...${NC}"
    if nslookup google.com > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ DNS working${NC}"
    else
        echo -e "${RED}  ✗ DNS failed${NC}"
        echo -e "${YELLOW}  Check: Allow UDP/TCP port 53${NC}"
    fi
    echo ""
    
    # Test NTP
    echo -e "${CYAN}[2/6] Testing NTP sync...${NC}"
    if timedatectl status | grep -q "System clock synchronized: yes"; then
        echo -e "${GREEN}  ✓ NTP synchronized${NC}"
    else
        echo -e "${YELLOW}  ⚠ NTP not synchronized (may take time)${NC}"
        echo -e "${YELLOW}  Check: Allow UDP port 123${NC}"
    fi
    echo ""
    
    # Test HTTPS
    echo -e "${CYAN}[3/6] Testing HTTPS connectivity...${NC}"
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ HTTPS working${NC}"
    else
        echo -e "${RED}  ✗ HTTPS failed${NC}"
        echo -e "${YELLOW}  Check: Allow TCP port 443${NC}"
    fi
    echo ""
    
    # Test Azure IoT Hub (if iotedge is installed)
    echo -e "${CYAN}[4/6] Testing Azure IoT Hub connectivity...${NC}"
    if command -v iotedge &> /dev/null; then
        # Try to get IoT Hub hostname from iotedge config first
        IOT_HUB_HOSTNAME=""
        
        if [ -f /etc/aziot/config.toml ]; then
            CONFIG_HOSTNAME=$(grep -E "^hostname\s*=" /etc/aziot/config.toml 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo "")
            if [ -n "$CONFIG_HOSTNAME" ]; then
                IOT_HUB_HOSTNAME="$CONFIG_HOSTNAME"
                echo "  Detected IoT Hub hostname from config: $IOT_HUB_HOSTNAME"
            fi
        fi
        
        # If not found, prompt user
        if [ -z "$IOT_HUB_HOSTNAME" ]; then
            echo "  IoT Hub hostname not found in configuration."
            read -p "  Enter IoT Hub hostname (e.g., YourIoTHub.azure-devices.net): " IOT_HUB_HOSTNAME
            
            # Validate input
            if [ -z "$IOT_HUB_HOSTNAME" ]; then
                echo -e "${YELLOW}  ⚠ No hostname provided, skipping IoT Hub test${NC}"
                echo ""
                return
            fi
        fi
        
        echo ""
        
        # Test HTTPS connectivity to IoT Hub
        if curl -s --connect-timeout 5 https://$IOT_HUB_HOSTNAME > /dev/null 2>&1; then
            echo -e "${GREEN}  ✓ IoT Hub HTTPS reachable ($IOT_HUB_HOSTNAME)${NC}"
        else
            echo -e "${RED}  ✗ IoT Hub HTTPS unreachable ($IOT_HUB_HOSTNAME)${NC}"
            echo -e "${YELLOW}  Check: Allow TCP port 443 to *.azure-devices.net${NC}"
        fi
        
        # Test AMQPS port connectivity (primary protocol for IoT Edge)
        if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$IOT_HUB_HOSTNAME/5671" 2>/dev/null; then
            echo -e "${GREEN}  ✓ IoT Hub AMQPS port reachable (port 5671)${NC}"
        else
            echo -e "${YELLOW}  ⚠ IoT Hub AMQPS port unreachable${NC}"
            echo -e "${YELLOW}  Check: Allow TCP port 5671 to *.azure-devices.net${NC}"
        fi
        
        # Check if IoT Edge is actually connected and running
        # Check for both old (iotedge) and new (aziot-edged) service names
        IOT_EDGE_RUNNING=false
        if systemctl is-active --quiet aziot-edged 2>/dev/null; then
            IOT_EDGE_RUNNING=true
        elif systemctl is-active --quiet iotedge 2>/dev/null; then
            IOT_EDGE_RUNNING=true
        fi
        
        if [ "$IOT_EDGE_RUNNING" = true ]; then
            if sudo iotedge list 2>/dev/null | grep -q "edgeAgent"; then
                echo -e "${GREEN}  ✓ IoT Edge runtime connected and running${NC}"
            else
                echo -e "${YELLOW}  ⚠ IoT Edge not yet provisioned or modules not deployed${NC}"
                echo -e "${YELLOW}  Note: This is normal before DPS provisioning is complete${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠ IoT Edge service not running${NC}"
            echo -e "${YELLOW}  Start with: sudo systemctl start aziot-edged${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ IoT Edge not installed, skipping${NC}"
    fi
    echo ""
    
    # Test Container Registry
    echo -e "${CYAN}[5/6] Testing Container Registry access...${NC}"
    if curl -s --connect-timeout 5 https://mcr.microsoft.com > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ MCR accessible${NC}"
    else
        echo -e "${RED}  ✗ MCR failed${NC}"
        echo -e "${YELLOW}  Check: Allow TCP port 443 to mcr.microsoft.com${NC}"
    fi
    echo ""
    
    # Test RTAC (if configured)
    echo -e "${CYAN}[6/6] Testing RTAC connectivity...${NC}"
    if [ -n "$RTAC_IP" ]; then
        if curl -s --connect-timeout 5 http://$RTAC_IP > /dev/null 2>&1; then
            echo -e "${GREEN}  ✓ RTAC accessible at $RTAC_IP${NC}"
        else
            echo -e "${RED}  ✗ RTAC not accessible at $RTAC_IP${NC}"
            echo -e "${YELLOW}  Check: RTAC device is powered on and reachable${NC}"
            echo -e "${YELLOW}  Check: Allow TCP port 80/443 to $RTAC_IP${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ RTAC IP not configured, skipping${NC}"
    fi
    echo ""
    
    echo -e "${CYAN}Test complete.${NC}"
    echo ""
}

# Disable firewall
disable_firewall() {
    echo -e "${YELLOW}[DISABLE FIREWALL]${NC}"
    echo ""
    echo -e "${RED}WARNING: This will disable the firewall completely.${NC}"
    echo "The system will be open to all incoming connections."
    echo ""
    read -p "Are you sure? (y/N): " REPLY
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    if command -v ufw &> /dev/null; then
        ufw --force disable > /dev/null 2>&1
        echo -e "${YELLOW}✓ Firewall disabled${NC}"
    else
        echo -e "${RED}UFW not installed${NC}"
    fi
    echo ""
}

# Enable firewall
enable_firewall() {
    echo -e "${GREEN}[ENABLE FIREWALL]${NC}"
    echo ""
    
    if ! command -v ufw &> /dev/null; then
        echo -e "${RED}UFW not installed. Use Option 1 or 2 to configure firewall first.${NC}"
        echo ""
        return
    fi
    
    # Check if any rules exist
    RULE_COUNT=$(ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
    
    if [ "$RULE_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No firewall rules configured.${NC}"
        echo "Use Option 1 or 2 to configure firewall rules first."
        echo ""
        return
    fi
    
    ufw --force enable > /dev/null 2>&1
    echo -e "${GREEN}✓ Firewall enabled${NC}"
    echo ""
    echo "Active rules: $RULE_COUNT"
    echo ""
}

# Main loop
main() {
    check_root
    
    while true; do
        show_menu
        read -p "Select option: " choice
        echo ""
        
        case $choice in
            1)
                configure_basic_firewall
                read -p "Press ENTER to continue..." dummy
                ;;
            2)
                configure_full_firewall
                read -p "Press ENTER to continue..." dummy
                ;;
            3)
                add_rtac_access
                read -p "Press ENTER to continue..." dummy
                ;;
            4)
                configure_ssh_access
                read -p "Press ENTER to continue..." dummy
                ;;
            5)
                show_firewall_rules
                read -p "Press ENTER to continue..." dummy
                ;;
            6)
                test_connectivity
                read -p "Press ENTER to continue..." dummy
                ;;
            7)
                disable_firewall
                read -p "Press ENTER to continue..." dummy
                ;;
            8)
                enable_firewall
                read -p "Press ENTER to continue..." dummy
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
