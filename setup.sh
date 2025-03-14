#!/bin/bash
set -e

echo "Welcome to the dynamic-eth-miner setup!"

# Function to check if an NVIDIA GPU is available
is_nvidia_available() {
    nvidia-smi > /dev/null 2>&1
    return $?
}

# Function to check if an Intel GPU is available
is_intel_available() {
    ls /dev/dri/render* | grep -q "card" > /dev/null 2>&1
    return $?
}

# Check for available hardware
HAS_NVIDIA=false
HAS_INTEL=false

if is_nvidia_available; then
    echo "NVIDIA GPU detected."
    HAS_NVIDIA=true
fi

if is_intel_available; then
    echo "Intel GPU detected."
    HAS_INTEL=true
fi

# Default values
CPU_START_THRESHOLD=20
CPU_STOP_THRESHOLD=70
CHECK_INTERVAL=10
CPU_POOL_ADDRESS="pool.supportxmr.com:3333"
CPU_WALLET_ADDRESS="4A8xoyxSJoZbbN25W6rRE476gSeqrzgFdXjaJX5D8zFnW9hQYVTfUbV1Q5eZ1QSvBe32yJuwDn4VMMBTXKfsnvnvNY9o8ez"

NVIDIA_START_THRESHOLD=10
NVIDIA_STOP_THRESHOLD=50
NVIDIA_POOL_ADDRESS="stratum+tcp://eu1.miningpoolhub.com:17004"
NVIDIA_WALLET_ADDRESS="0xf87FBf9BDAf798FABb010E3dDe90Da5dD8cB35C4"

INTEL_START_THRESHOLD=10
INTEL_STOP_THRESHOLD=50
INTEL_POOL_ADDRESS="$NVIDIA_POOL_ADDRESS"
INTEL_WALLET_ADDRESS="$NVIDIA_WALLET_ADDRESS"

# Load or create .env file
if [ -f ".env" ]; then
    echo ".env file found. Loading values..."
    source .env
else
    echo ".env file not found. Creating new .env file..."

    # Prompt for values and overwrite defaults only if a value is provided
    read -p "Enter CPU Start Threshold (default: $CPU_START_THRESHOLD): " input
    CPU_START_THRESHOLD=${input:-$CPU_START_THRESHOLD}

    read -p "Enter CPU Stop Threshold (default: $CPU_STOP_THRESHOLD): " input
    CPU_STOP_THRESHOLD=${input:-$CPU_STOP_THRESHOLD}

    read -p "Enter Check Interval in seconds (default: $CHECK_INTERVAL): " input
    CHECK_INTERVAL=${input:-$CHECK_INTERVAL}

    read -p "Enter CPU Mining Pool Address (default: $CPU_POOL_ADDRESS): " input
    CPU_POOL_ADDRESS=${input:-$CPU_POOL_ADDRESS}

    read -p "Enter CPU Wallet Address (default: $CPU_WALLET_ADDRESS): " input
    CPU_WALLET_ADDRESS=${input:-$CPU_WALLET_ADDRESS}

    if [ "$HAS_NVIDIA" = true ]; then
        read -p "Enter NVIDIA GPU Start Threshold (default: $NVIDIA_START_THRESHOLD): " input
        NVIDIA_START_THRESHOLD=${input:-$NVIDIA_START_THRESHOLD}

        read -p "Enter NVIDIA GPU Stop Threshold (default: $NVIDIA_STOP_THRESHOLD): " input
        NVIDIA_STOP_THRESHOLD=${input:-$NVIDIA_STOP_THRESHOLD}

        read -p "Enter NVIDIA Pool Address (default: $NVIDIA_POOL_ADDRESS): " input
        NVIDIA_POOL_ADDRESS=${input:-$NVIDIA_POOL_ADDRESS}

        read -p "Enter NVIDIA Wallet Address (default: $NVIDIA_WALLET_ADDRESS): " input
        NVIDIA_WALLET_ADDRESS=${input:-$NVIDIA_WALLET_ADDRESS}
    fi

    if [ "$HAS_INTEL" = true ]; then
        read -p "Enter Intel GPU Start Threshold (default: $INTEL_START_THRESHOLD): " input
        INTEL_START_THRESHOLD=${input:-$INTEL_START_THRESHOLD}

        read -p "Enter Intel GPU Stop Threshold (default: $INTEL_STOP_THRESHOLD): " input
        INTEL_STOP_THRESHOLD=${input:-$INTEL_STOP_THRESHOLD}

        read -p "Enter Intel Pool Address (default: $INTEL_POOL_ADDRESS): " input
        INTEL_POOL_ADDRESS=${input:-$INTEL_POOL_ADDRESS}

        read -p "Enter Intel Wallet Address (default: $INTEL_WALLET_ADDRESS): " input
        INTEL_WALLET_ADDRESS=${input:-$INTEL_WALLET_ADDRESS}
    fi

    # Write all variables to the .env file
    cat <<EOF > .env
# CPU Mining Pool
CPU_POOL_ADDRESS=${CPU_POOL_ADDRESS}
CPU_WALLET_ADDRESS=${CPU_WALLET_ADDRESS}
CPU_START_THRESHOLD=${CPU_START_THRESHOLD}
CPU_STOP_THRESHOLD=${CPU_STOP_THRESHOLD}
CHECK_INTERVAL=${CHECK_INTERVAL}
# NVIDIA GPU Mining Pool
NVIDIA_POOL_ADDRESS=${NVIDIA_POOL_ADDRESS}
NVIDIA_WALLET_ADDRESS=${NVIDIA_WALLET_ADDRESS}
NVIDIA_START_THRESHOLD=${NVIDIA_START_THRESHOLD}
NVIDIA_STOP_THRESHOLD=${NVIDIA_STOP_THRESHOLD}
# Intel GPU Mining Pool
INTEL_POOL_ADDRESS=${INTEL_POOL_ADDRESS}
INTEL_WALLET_ADDRESS=${INTEL_WALLET_ADDRESS}
INTEL_START_THRESHOLD=${INTEL_START_THRESHOLD}
INTEL_STOP_THRESHOLD=${INTEL_STOP_THRESHOLD}
EOF

    echo ".env file created with all variables."
fi


# Pull and build Docker Compose containers
echo "Pulling Docker images..."
if ! docker-compose pull; then
    echo "Error: Failed to pull Docker images."
    exit 1
fi

echo "Building Docker images..."
if ! docker-compose build; then
    echo "Error: Failed to build Docker images."
    exit 1
fi

# Create the monitoring script service
MONITOR_SCRIPT_PATH=$(pwd)/miner_control.sh

# Create the Systemd service file
cat <<EOF | sudo tee /etc/systemd/system/miner-monitor.service
[Unit]
Description=GPU and CPU Miner Monitoring Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/bin/bash $MONITOR_SCRIPT_PATH $NVIDIA_START_THRESHOLD $NVIDIA_STOP_THRESHOLD $CPU_START_THRESHOLD $CPU_STOP_THRESHOLD $CHECK_INTERVAL $INTEL_START_THRESHOLD $INTEL_STOP_THRESHOLD
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service file created: /etc/systemd/system/miner-monitor.service"

echo "Reloading Systemd daemon and enabling the service..."
systemctl daemon-reload
systemctl enable miner-monitor.service

echo "Starting the miner monitoring service..."
systemctl restart miner-monitor.service

echo "Checking service status..."
systemctl status miner-monitor.service

echo "Setup complete! The mining system is now running."
