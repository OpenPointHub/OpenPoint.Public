#!/bin/bash

###############################################################################
# IoT Edge System Health Monitor
# Purpose: Quick system health check for IoT Edge devices
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
###############################################################################

echo "════════════════════════════════════════════"
echo "│  System Health Check - $(date +'%Y-%m-%d %H:%M:%S')                │"
echo "════════════════════════════════════════════"
echo ""

# IoT Edge Status
echo "🔷 Azure IoT Edge:"
if command -v iotedge &> /dev/null; then
    sudo iotedge system status 2>/dev/null || echo "   Not configured yet"
    echo ""
    echo "   Modules:"
    sudo iotedge list 2>/dev/null || echo "   Not configured yet"
else
    echo "   Not installed"
fi

# TPM Status
echo ""
echo "🔐 TPM Status:"
if ls /dev/tpm* &> /dev/null 2>&1; then
    echo "   ✓ TPM device available: $(ls /dev/tpm* 2>/dev/null | tr '\n' ' ')"
else
    echo "   ✗ No TPM device found"
fi

# Defender for IoT Status
echo ""
echo "🛡️  Microsoft Defender for IoT:"
if systemctl is-active --quiet defender-iot-micro-agent 2>/dev/null; then
    echo "   ✓ Defender micro-agent is running"
else
    echo "   ⚠ Defender micro-agent not running or not installed"
fi

# Memory Usage
echo ""
echo "💾 Memory Usage:"
free -h | awk 'NR==1 || NR==2'
echo ""
echo "   Swap:"
free -h | awk 'NR==1 || NR==3'

# Disk Usage
echo ""
echo "💿 Disk Usage:"
df -h / | awk 'NR==1 || NR==2'

# Docker Containers
echo ""
echo "🐳 Docker Containers:"
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" 2>/dev/null || echo "   No containers running"
fi

# IoT Edge Module Statistics
echo ""
echo "📊 Module Statistics (last 1 second):"
if command -v docker &> /dev/null; then
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null || echo "   No containers running"
fi

# System Load
echo ""
echo "⚡ System Load:"
uptime

# Network Connections
echo ""
echo "🌐 Active Connections:"
netstat -an 2>/dev/null | grep ESTABLISHED | wc -l | xargs echo "   Established connections:"

# Network Connectivity Test
echo ""
echo "📡 Network Connectivity:"
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "   ✓ Internet connectivity: OK"
else
    echo "   ✗ Internet connectivity: FAILED"
fi

# Network Interfaces
echo ""
echo "🔌 Network Interfaces:"
ip -br addr show 2>/dev/null | grep -v "^lo" | awk '{printf "   %s: %s\n", $1, $3}'

# System Temperature
echo ""
if command -v vcgencmd &> /dev/null; then
    TEMP=$(vcgencmd measure_temp 2>/dev/null | sed 's/temp=//')
    echo "🌡️  Temperature: $TEMP"
else
    echo "🌡️  Temperature: Not available (will be monitored by SCADA module)"
fi

echo ""
echo "════════════════════════════════════════════"
echo ""
echo "💡 Tip: Run 'sudo iotedge check' for comprehensive IoT Edge diagnostics"
echo ""
