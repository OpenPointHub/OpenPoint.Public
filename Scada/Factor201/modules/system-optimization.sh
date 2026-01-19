#!/bin/bash

###############################################################################
# System Optimization Module
# Purpose: Optimize swap, TRIM, watchdog, file descriptors, network settings
###############################################################################

system_optimization() {
    echo -e "${BLUE}[STEP 3] System Optimization${NC}"
    echo ""
    
    # Optimize swap settings
    echo -e "${GREEN}[1/5] Optimizing swap settings...${NC}"
    if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
        echo "vm.swappiness=10" >> /etc/sysctl.conf
    fi
    if ! grep -q "vm.vfs_cache_pressure=50" /etc/sysctl.conf; then
        echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    fi
    sysctl -p > /dev/null 2>&1
    echo "  ? Swappiness set to 10 (prefer RAM over swap)"
    
    # Enable SSD TRIM
    echo ""
    echo -e "${GREEN}[2/5] Enabling SSD TRIM...${NC}"
    systemctl enable fstrim.timer > /dev/null 2>&1
    systemctl start fstrim.timer > /dev/null 2>&1
    echo "  ? Weekly TRIM scheduled"
    
    # Enable hardware watchdog
    echo ""
    echo -e "${GREEN}[3/5] Enabling hardware watchdog...${NC}"
    if ! lsmod | grep -q bcm2835_wdt; then
        modprobe bcm2835_wdt 2>/dev/null || true
    fi
    if ! grep -q "bcm2835_wdt" /etc/modules 2>/dev/null; then
        echo "bcm2835_wdt" >> /etc/modules
    fi
    apt-get install -y --fix-missing watchdog > /dev/null 2>&1
    cat > /etc/watchdog.conf <<EOF
watchdog-device = /dev/watchdog
watchdog-timeout = 15
max-load-1 = 24
allocatable-memory = 1
realtime = yes
priority = 1
EOF
    systemctl enable watchdog > /dev/null 2>&1
    systemctl start watchdog > /dev/null 2>&1
    echo "  ? Hardware watchdog enabled"
    
    # Increase file descriptors
    echo ""
    echo -e "${GREEN}[4/5] Increasing file descriptor limits...${NC}"
    if ! grep -q "soft nofile 65535" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf <<EOF
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
        echo "  ? File descriptor limit: 65535"
    else
        echo "  ? File descriptor limits already configured"
    fi
    
    # Network optimizations
    echo ""
    echo -e "${GREEN}[5/5] Applying network optimizations...${NC}"
    if ! grep -q "Network optimizations for IoT Edge workloads" /etc/sysctl.conf; then
        cat >> /etc/sysctl.conf <<EOF

# Network optimizations for IoT Edge workloads
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=15
EOF
        echo "  ? Network buffers increased"
    else
        echo "  ? Network optimizations already configured"
    fi
    sysctl -p > /dev/null 2>&1
    
    echo ""
    echo -e "${GREEN}? System optimization complete${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    system_optimization
fi
