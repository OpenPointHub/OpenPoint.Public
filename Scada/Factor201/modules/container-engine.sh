#!/bin/bash

###############################################################################
# Container Engine Module
# Purpose: Install and configure Moby/Docker for IoT Edge
###############################################################################

container_engine() {
    echo -e "${BLUE}[STEP 4] Container Engine Installation${NC}"
    echo ""
    
    # Install Moby
    echo -e "${GREEN}[1/2] Installing Moby container engine...${NC}"
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        echo "  ? Container engine already installed (${DOCKER_VERSION})"
    else
        apt-get update --fix-missing > /dev/null 2>&1
        apt-get install -y --fix-missing moby-engine moby-cli > /dev/null 2>&1
        systemctl start docker
        systemctl enable docker > /dev/null 2>&1
        echo "  ? Moby container engine installed"
    fi
    
    # Configure Docker
    echo ""
    echo -e "${GREEN}[2/2] Configuring container engine...${NC}"
    mkdir -p /etc/docker
    
    if [ -f /etc/docker/daemon.json ]; then
        if ! grep -q '"log-driver": "local"' /etc/docker/daemon.json; then
            cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
            cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
            systemctl restart docker
            echo "  ? Docker reconfigured for IoT Edge"
        else
            echo "  ? Docker already configured for IoT Edge"
        fi
    else
        cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
        systemctl restart docker
        echo "  ? Container engine configured"
    fi
    
    echo ""
    echo -e "${GREEN}? Container engine ready${NC}"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    container_engine
fi
