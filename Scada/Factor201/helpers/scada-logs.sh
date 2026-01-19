#!/bin/bash

###############################################################################
# SCADA Polling Module Log Viewer
# Purpose: Quick access to logs for troubleshooting OpenPoint SCADA module
# Repository: https://github.com/OpenPointHub/OpenPoint.Public
###############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MODULE_NAME="ScadaPollingModule"

# Show menu
show_menu() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}│  SCADA Polling Module - Log Viewer        │${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Select log view option:"
    echo ""
    echo "  ${GREEN}1${NC}) Live tail - Follow module logs in real-time"
    echo "  ${GREEN}2${NC}) Last 100 lines - Recent module activity"
    echo "  ${GREEN}3${NC}) Last 500 lines - Extended history"
    echo "  ${GREEN}4${NC}) Errors only - Filter for errors/exceptions"
    echo "  ${GREEN}5${NC}) Warnings & Errors - Show problems only"
    echo "  ${GREEN}6${NC}) IoT Edge system logs - Runtime issues"
    echo "  ${GREEN}7${NC}) All module logs since boot"
    echo "  ${GREEN}8${NC}) Docker container stats"
    echo "  ${GREEN}9${NC}) Export logs to file"
    echo "  ${YELLOW}0${NC}) Exit"
    echo ""
    echo -e "${CYAN}Current module status:${NC}"
    sudo iotedge list 2>/dev/null | grep -E "NAME|$MODULE_NAME" || echo "  Module not deployed yet"
    echo ""
}

# Check if module exists
check_module() {
    if ! sudo iotedge list 2>/dev/null | grep -q "$MODULE_NAME"; then
        echo -e "${RED}Error: $MODULE_NAME is not running${NC}"
        return 1
    fi
    return 0
}

# Live tail
live_tail() {
    echo -e "${GREEN}Live log stream (Ctrl+C to exit)${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME -f
}

# Last N lines
last_lines() {
    local lines=$1
    echo -e "${GREEN}Last $lines log entries${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail $lines
}

# Errors only
errors_only() {
    echo -e "${RED}Filtering for errors and exceptions${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "error|exception|fail|critical" || echo -e "${GREEN}✓ No errors found${NC}"
}

# Warnings and errors
warnings_errors() {
    echo -e "${YELLOW}Filtering for warnings and errors${NC}"
    echo ""
    sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "warn|error|exception|fail|critical" || echo -e "${GREEN}✓ No warnings or errors found${NC}"
}

# System logs
system_logs() {
    echo -e "${GREEN}IoT Edge system logs${NC}"
    echo ""
    sudo iotedge system logs --tail 200
}

# All logs since boot
all_logs() {
    echo -e "${GREEN}All module logs since boot${NC}"
    echo -e "${YELLOW}Warning: This may be a large amount of data${NC}"
    echo ""
    read -p "Continue? (y/N): " REPLY
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo iotedge logs $MODULE_NAME | less
    fi
}

# Docker stats
docker_stats() {
    echo -e "${GREEN}Container resource usage${NC}"
    echo ""
    echo "Real-time stats (Ctrl+C to exit):"
    docker stats $MODULE_NAME
}

# Export logs
export_logs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="scada_logs_${timestamp}.txt"
    
    echo -e "${GREEN}Exporting logs to: $filename${NC}"
    echo ""
    
    {
        echo "=================================================="
        echo "SCADA Polling Module Logs"
        echo "Exported: $(date)"
        echo "=================================================="
        echo ""
        echo "=== Module Status ==="
        sudo iotedge list 2>/dev/null | grep -E "NAME|$MODULE_NAME"
        echo ""
        echo "=== Last 500 Log Entries ==="
        sudo iotedge logs $MODULE_NAME --tail 500
        echo ""
        echo "=== Errors & Warnings ==="
        sudo iotedge logs $MODULE_NAME --tail 1000 | grep -i -E "warn|error|exception|fail|critical"
        echo ""
        echo "=== IoT Edge System Status ==="
        sudo iotedge system status 2>/dev/null
        echo ""
        echo "=== Container Stats (snapshot) ==="
        docker stats --no-stream $MODULE_NAME 2>/dev/null
    } > "$filename"
    
    echo -e "${GREEN}✓ Logs exported to: $filename${NC}"
    echo ""
    echo "File size: $(du -h "$filename" | cut -f1)"
    echo ""
    echo "You can copy this file off the device with:"
    echo "  scp $(whoami)@$(hostname -I | awk '{print $1}'):~/$filename ."
}

# Main loop
while true; do
    show_menu
    read -p "Select option: " choice
    echo ""
    
    case $choice in
        1) check_module && live_tail; read -p "Press ENTER..." ;;
        2) check_module && last_lines 100; read -p "Press ENTER..." ;;
        3) check_module && last_lines 500; read -p "Press ENTER..." ;;
        4) check_module && errors_only; read -p "Press ENTER..." ;;
        5) check_module && warnings_errors; read -p "Press ENTER..." ;;
        6) system_logs; read -p "Press ENTER..." ;;
        7) check_module && all_logs; read -p "Press ENTER..." ;;
        8) check_module && docker_stats; read -p "Press ENTER..." ;;
        9) check_module && export_logs; read -p "Press ENTER..." ;;
        0) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
done
