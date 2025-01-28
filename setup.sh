#!/bin/bash

echo "Welcome to the dynamic-eth-miner setup!"

# Function to check if NVIDIA GPU is available
is_nvidia_available() {
    nvidia-smi > /dev/null 2>&1
    return $?
}

# Function to check if Intel GPU is available
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

# Prompt for general inputs
read -p "Enter CPU Start Threshold (e.g., 20): " CPU_START_THRESHOLD
read -p "Enter CPU Stop Threshold (e.g., 70): " CPU_STOP_THRESHOLD
read -p "Enter Check Interval in seconds (e.g., 10): " CHECK_INTERVAL
read -p "Enter CPU Mining Pool Address (e.g., pool.supportxmr.com:3333): " CPU_POOL_ADDRESS
read -p "Enter CPU Wallet Address: " CPU_WALLET_ADDRESS

# Prompt for NVIDIA GPU settings if available
if [ "$HAS_NVIDIA" = true ]; then
    read -p "Enter NVIDIA GPU Start Threshold (e.g., 10): " NVIDIA_START_THRESHOLD
    read -p "Enter NVIDIA GPU Stop Threshold (e.g., 50): " NVIDIA_STOP_THRESHOLD
    read -p "Enter Ethereum Mining Pool Address (e.g., eu1.ethermine.org): " NVIDIA_POOL_ADDRESS
    read -p "Enter Ethereum Mining Pool Port (e.g., 4444): " NVIDIA_PORT
    read -p "Enter Ethereum Wallet Address: " NVIDIA_WALLET_ADDRESS
fi

# Prompt for Intel GPU settings if available
if [ "$HAS_INTEL" = true ]; then
    read -p "Enter Intel GPU Start Threshold (e.g., 10): " INTEL_START_THRESHOLD
    read -p "Enter Intel GPU Stop Threshold (e.g., 50): " INTEL_STOP_THRESHOLD
    read -p "Enter Ethereum Mining Pool Address (e.g., eu1.ethermine.org): " INTEL_POOL_ADDRESS
    read -p "Enter Ethereum Wallet Address: " INTEL_WALLET_ADDRESS
fi

# Create a .env file for Docker Compose
cat <<EOF > .env
# CPU Mining Pool
CPU_POOL_ADDRESS=${CPU_POOL_ADDRESS}
CPU_WALLET_ADDRESS=${CPU_WALLET_ADDRESS}

# NVIDIA GPU Mining Pool
$(if [ "$HAS_NVIDIA" = true ]; then
    echo "NVIDIA_POOL_ADDRESS=${NVIDIA_POOL_ADDRESS}"
    echo "NVIDIA_PORT=${NVIDIA_PORT}"
    echo "NVIDIA_WALLET_ADDRESS=${NVIDIA_WALLET_ADDRESS}"
fi)

# Intel GPU Mining Pool
$(if [ "$HAS_INTEL" = true ]; then
    echo "INTEL_POOL_ADDRESS=${INTEL_POOL_ADDRESS}"
    echo "INTEL_WALLET_ADDRESS=${INTEL_WALLET_ADDRESS}"
fi)
EOF

echo ".env file created with mining pool and wallet details."

# Start Docker Compose containers
echo "Starting Docker containers..."
docker-compose up -d

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
ExecStart=/bin/bash $MONITOR_SCRIPT_PATH \
    $(if [ "$HAS_NVIDIA" = true ]; then echo "$NVIDIA_START_THRESHOLD $NVIDIA_STOP_THRESHOLD"; else echo "0 0"; fi) \
    $CPU_START_THRESHOLD $CPU_STOP_THRESHOLD $CHECK_INTERVAL \
    $(if [ "$HAS_INTEL" = true ]; then echo "$INTEL_START_THRESHOLD $INTEL_STOP_THRESHOLD"; else echo "0 0"; fi)
Restart=always
EnvironmentFile=${PWD}/.env

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service file created: /etc/systemd/system/miner-monitor.service"

# Reload Systemd and enable the service
echo "Reloading Systemd daemon and enabling the service..."
sudo systemctl daemon-reload
sudo systemctl enable miner-monitor.service

# Start the service
echo "Starting the miner monitoring service..."
sudo systemctl start miner-monitor.service

# Check the status of the service
echo "Checking service status..."
sudo systemctl status miner-monitor.service

echo "Setup complete! The mining system is now running."
