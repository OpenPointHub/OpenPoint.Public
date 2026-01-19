#!/bin/bash

###############################################################################
# Helper Scripts Module
# Purpose: Download monitoring and utility scripts
###############################################################################

helper_scripts() {
    echo -e "${BLUE}[STEP 6] Downloading Helper Scripts${NC}"
    echo ""
    
    BASE_URL="https://raw.githubusercontent.com/OpenPointHub/OpenPoint.Public/master/Scada/Factor201/helpers"
    
    # TPM key extractor (if TPM present)
    if ls /dev/tpm* &> /dev/null 2>&1; then
        echo -e "${GREEN}[1/3] Downloading TPM key extraction helper...${NC}"
        wget -q ${BASE_URL}/get-tpm-key.sh -O /usr/local/bin/get-tpm-key.sh
        chmod +x /usr/local/bin/get-tpm-key.sh
        echo "  ✓ Created: get-tpm-key.sh"
    else
        echo -e "${YELLOW}[1/3] Skipping TPM helper (no TPM device)${NC}"
    fi
    
    # System monitor
    echo ""
    echo -e "${GREEN}[2/3] Downloading system monitoring script...${NC}"
    wget -q ${BASE_URL}/iot-monitor.sh -O /usr/local/bin/iot-monitor.sh
    chmod +x /usr/local/bin/iot-monitor.sh
    echo "  ✓ Created: iot-monitor.sh"
    
    # Log viewer
    echo ""
    echo -e "${GREEN}[3/3] Downloading SCADA log viewer...${NC}"
    wget -q ${BASE_URL}/scada-logs.sh -O /usr/local/bin/scada-logs.sh
    chmod +x /usr/local/bin/scada-logs.sh
    echo "  ✓ Created: scada-logs.sh"
    
    echo ""
    echo -e "${GREEN}✓ Helper scripts ready${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    helper_scripts
fi
