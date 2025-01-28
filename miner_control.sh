#!/bin/bash

# Thresholds for usage
GPU_THRESHOLD=10    # GPU usage percentage
CPU_THRESHOLD=20    # CPU usage percentage
CHECK_INTERVAL=10   # Time in seconds between checks

# Docker container name
CONTAINER_NAME="ethereum-miner"

# Function to get GPU utilization using nvidia-smi
get_gpu_usage() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{print $1}'
}

# Function to get CPU utilization
get_cpu_usage() {
    awk -v cores=$(nproc) '{u=$2+$4; t=$2+$4+$5} NR==1{uo=u;to=t} NR==2{print (u-uo)*100/(t-to)/cores}' <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat)
}

# Main loop
while true; do
    # Get GPU and CPU usage
    GPU_USAGE=$(get_gpu_usage)
    CPU_USAGE=$(get_cpu_usage)

    # Start or stop container based on thresholds
    if (( $(echo "$GPU_USAGE < $GPU_THRESHOLD" | bc -l) && $(echo "$CPU_USAGE < $CPU_THRESHOLD" | bc -l) )); then
        if ! docker ps | grep -q "$CONTAINER_NAME"; then
            echo "$(date): Starting Ethereum miner..."
            docker-compose up -d
        fi
    else
        if docker ps | grep -q "$CONTAINER_NAME"; then
            echo "$(date): Stopping Ethereum miner due to high usage..."
            docker-compose down
        fi
    fi

    # Wait before the next check
    sleep $CHECK_INTERVAL
done
