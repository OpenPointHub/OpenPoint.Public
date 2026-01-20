#!/bin/bash

###############################################################################
# TPM Endorsement Key Extractor
# Purpose: Extract TPM endorsement key for Azure DPS registration
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
###############################################################################

echo "════════════════════════════════════════════"
echo "│      TPM Endorsement Key Extractor        │"
echo "════════════════════════════════════════════"
echo ""
echo "This key uniquely identifies your TPM chip."
echo "Send this to your Azure administrator to register this device."
echo ""
echo "Extracting endorsement key..."
echo ""

# Method 1: Direct read from TPM NVRAM
if sudo tpm2_nvread -C o 0x1c00002 2>/dev/null | xxd -p -c 256; then
    echo ""
    echo "✓ Endorsement key extracted successfully!"
else
    echo "⚠ Direct read failed, trying alternative method..."
    echo ""
    
    # Method 2: Using createek command
    sudo tpm2_createek -c /tmp/ek.ctx -G rsa -u /tmp/ek.pub 2>/dev/null
    sudo tpm2_readpublic -c /tmp/ek.ctx -f pem -o /tmp/ek.pem 2>/dev/null
    
    if [ -f /tmp/ek.pem ]; then
        echo "Endorsement Key (PEM format):"
        cat /tmp/ek.pem
        echo ""
        echo "✓ Endorsement key extracted successfully!"
        
        # Clean up temporary files
        rm -f /tmp/ek.ctx /tmp/ek.pub /tmp/ek.pem
    else
        echo "✗ Failed to extract endorsement key"
        echo "Your TPM may not be properly initialized."
        exit 1
    fi
fi

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "📧 Next step: Send this key to your Azure administrator"
echo "   They will use it to create a DPS enrollment for this device."
echo ""
