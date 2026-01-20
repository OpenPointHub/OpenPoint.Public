#!/bin/bash

###############################################################################
# TPM Endorsement Key Extractor
# Purpose: Extract TPM endorsement key for Azure DPS registration
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
# Based on: Microsoft Azure IoT Edge TPM provisioning guidelines
###############################################################################

# Check for sudo if not running as root
if [ "$USER" != "root" ]; then
  SUDO="sudo "
else
  SUDO=""
fi

echo "════════════════════════════════════════════"
echo "│      TPM Endorsement Key Extractor        │"
echo "════════════════════════════════════════════"
echo ""
echo "This key uniquely identifies your TPM chip."
echo "Send this to your Azure administrator to register this device."
echo ""

# Check if TPM is available
if [ ! -e /dev/tpm0 ] && [ ! -e /dev/tpmrm0 ]; then
    echo "✗ No TPM device found!"
    echo "  Please ensure TPM is enabled in BIOS/UEFI"
    exit 1
fi

echo "Checking TPM status..."
echo ""

# Try to read existing endorsement key
$SUDO tpm2_readpublic -Q -c 0x81010001 -o ek.pub 2> /dev/null

if [ $? -gt 0 ]; then
    # EK doesn't exist, need to create it
    echo "Initializing TPM (first-time setup)..."
    echo ""
    
    # Create the endorsement key (EK)
    echo "  → Creating endorsement key..."
    $SUDO tpm2_createek -c 0x81010001 -G rsa -u ek.pub
    
    if [ $? -gt 0 ]; then
        echo "✗ Failed to create endorsement key"
        exit 1
    fi
    
    # Create the storage root key (SRK)
    echo "  → Creating storage root key..."
    $SUDO tpm2_createprimary -Q -C o -c srk.ctx > /dev/null
    
    # Make the SRK persistent
    echo "  → Making SRK persistent..."
    $SUDO tpm2_evictcontrol -c srk.ctx 0x81000001 > /dev/null
    
    # Open transient handle space for the TPM
    $SUDO tpm2_flushcontext -t > /dev/null
    
    echo "  ✓ TPM initialized successfully!"
    echo ""
else
    echo "  ✓ TPM already initialized"
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
echo "════════════════════════════════════════════"
echo "│         DEVICE REGISTRATION INFO           │"
echo "════════════════════════════════════════════"
echo ""
echo "Registration ID:"
echo "$REGISTRATION_ID"
echo ""
echo "Endorsement Key:"
echo "$ENDORSEMENT_KEY"
echo ""
echo "════════════════════════════════════════════"
echo ""
echo "📧 Next Steps:"
echo "   1. Copy both values above"
echo "   2. Send to your Azure administrator"
echo "   3. They will create a DPS enrollment using:"
echo "      - Registration ID (shown above)"
echo "      - Endorsement Key (shown above)"
echo ""

# Clean up temporary files
$SUDO rm -f ek.pub srk.ctx 2> /dev/null

echo "✓ Complete!"
echo ""
