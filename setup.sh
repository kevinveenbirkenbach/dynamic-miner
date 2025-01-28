#!/bin/bash

echo "Welcome to the dynamic-eth-miner setup!"

# Prompt for user inputs
read -p "Enter GPU Start Threshold (e.g., 10): " GPU_START_THRESHOLD
read -p "Enter GPU Stop Threshold (e.g., 50): " GPU_STOP_THRESHOLD
read -p "Enter CPU Start Threshold (e.g., 20): " CPU_START_THRESHOLD
read -p "Enter CPU Stop Threshold (e.g., 70): " CPU_STOP_THRESHOLD
read -p "Enter Check Interval in seconds (e.g., 10): " CHECK_INTERVAL
read -p "Enter Ethereum Mining Pool Address (e.g., eu1.ethermine.org): " GPU_POOL_ADDRESS
read -p "Enter Ethereum Mining Pool Port (e.g., 4444): " GPU_PORT
read -p "Enter Ethereum Wallet Address: " GPU_WALLET_ADDRESS
read -p "Enter CPU Mining Pool Address (e.g., pool.supportxmr.com:3333): " CPU_POOL_ADDRESS
read -p "Enter CPU Wallet Address: " CPU_WALLET_ADDRESS

# Create a .env file for Docker Compose
cat <<EOF > .env
# GPU Mining Pool
POOL_ADDRESS=${GPU_POOL_ADDRESS}
PORT=${GPU_PORT}
WALLET_ADDRESS=${GPU_WALLET_ADDRESS}

# CPU Mining Pool
CPU_POOL_ADDRESS=${CPU_POOL_ADDRESS}
CPU_WALLET_ADDRESS=${CPU_WALLET_ADDRESS}
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
ExecStart=/bin/bash $MONITOR_SCRIPT_PATH ${GPU_START_THRESHOLD} ${GPU_STOP_THRESHOLD} ${CPU_START_THRESHOLD} ${CPU_STOP_THRESHOLD} ${CHECK_INTERVAL}
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
