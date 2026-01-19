#!/bin/bash

###############################################################################
# IoT Edge Runtime Module
# Purpose: Install Azure IoT Edge runtime and TPM tools
###############################################################################

iotedge_runtime() {
    echo -e "${BLUE}[STEP 5] IoT Edge Runtime Installation${NC}"
    echo ""
    
    # Install IoT Edge
    echo -e "${GREEN}[1/2] Installing Azure IoT Edge Runtime...${NC}"
    if command -v iotedge &> /dev/null; then
        echo "  ? IoT Edge already installed ($(iotedge --version))"
    else
        UBUNTU_VERSION=$(lsb_release -rs)
        wget -q https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb > /dev/null 2>&1
        rm packages-microsoft-prod.deb
        apt-get update --fix-missing > /dev/null 2>&1
        apt-get install -y --fix-missing aziot-edge defender-iot-micro-agent-edge > /dev/null 2>&1
        echo "  ? IoT Edge runtime installed"
        echo "  ? Microsoft Defender for IoT installed"
    fi
    
    # Install TPM tools
    echo ""
    echo -e "${GREEN}[2/2] Installing TPM 2.0 tools...${NC}"
    if ! command -v tpm2_getcap &> /dev/null; then
        apt-get install -y --fix-missing tpm2-tools > /dev/null 2>&1
        echo "  ? TPM 2.0 tools installed"
    else
        echo "  ? TPM 2.0 tools already installed"
    fi
    
    # Check for TPM device
    echo ""
    if ls /dev/tpm* &> /dev/null 2>&1; then
        echo "  ? TPM device detected: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')"
    else
        echo -e "${YELLOW}  ? No TPM device found${NC}"
        echo "  ??  Will use connection string fallback for provisioning"
    fi
    
    echo ""
    echo -e "${GREEN}? IoT Edge runtime ready${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    iotedge_runtime
fi
