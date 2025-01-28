#!/bin/bash
set -e

# Thresholds for GPU usage (separate start and stop thresholds)
NVIDIA_GPU_START_THRESHOLD=$1  # GPU usage percentage to start the NVIDIA GPU miner
NVIDIA_GPU_STOP_THRESHOLD=$2   # GPU usage percentage to stop the NVIDIA GPU miner

# Thresholds for Intel GPU usage (separate start and stop thresholds)
INTEL_GPU_START_THRESHOLD=$6   # Intel GPU usage percentage to start the Intel GPU miner
INTEL_GPU_STOP_THRESHOLD=$7    # Intel GPU usage percentage to stop the Intel GPU miner

# Thresholds for CPU usage (separate start and stop thresholds)
CPU_START_THRESHOLD=$3         # CPU usage percentage to start the CPU miner
CPU_STOP_THRESHOLD=$4          # CPU usage percentage to stop the CPU miner

CHECK_INTERVAL=$5              # Time in seconds between checks

# Docker container names
NVIDIA_CONTAINER_NAME="nvidia-gpu-miner"
INTEL_CONTAINER_NAME="intel-gpu-miner"
CPU_CONTAINER_NAME="cpu-miner"

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

# Function to get NVIDIA GPU usage
get_nvidia_gpu_usage() {
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{print $1}'
}

# Function to get Intel GPU usage
get_intel_gpu_usage() {
    intel_gpu_top -J 2>/dev/null | jq '.engines | .[] | select(.class=="Render") | .busy' | awk '{print $1 * 100}'
}

# Function to get CPU usage
get_cpu_usage() {
    awk -v cores=$(nproc) '{u=$2+$4; t=$2+$4+$5} NR==1{uo=u;to=t} NR==2{print (u-uo)*100/(t-to)/cores}' <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat)
}

# Main loop
while true; do
    # Get CPU usage
    CPU_USAGE=$(get_cpu_usage)

    # Check if NVIDIA GPU is available
    if is_nvidia_available; then
        NVIDIA_GPU_USAGE=$(get_nvidia_gpu_usage)

        # NVIDIA GPU Miner Logic
        if (( $(echo "$NVIDIA_GPU_USAGE < $NVIDIA_GPU_START_THRESHOLD" | bc -l) )); then
            if ! docker ps | grep -q "$NVIDIA_CONTAINER_NAME"; then
                echo "$(date): NVIDIA GPU usage is low ($NVIDIA_GPU_USAGE%). Starting NVIDIA GPU miner..."
                docker-compose up -d "$NVIDIA_CONTAINER_NAME"
            fi
        elif (( $(echo "$NVIDIA_GPU_USAGE > $NVIDIA_GPU_STOP_THRESHOLD" | bc -l) )); then
            if docker ps | grep -q "$NVIDIA_CONTAINER_NAME"; then
                echo "$(date): NVIDIA GPU usage is high ($NVIDIA_GPU_USAGE%). Stopping NVIDIA GPU miner..."
                docker-compose stop "$NVIDIA_CONTAINER_NAME"
            fi
        fi
    else
        echo "$(date): NVIDIA GPU not detected. Skipping NVIDIA GPU miner..."
    fi

    # Check if Intel GPU is available
    if is_intel_available; then
        INTEL_GPU_USAGE=$(get_intel_gpu_usage)

        # Intel GPU Miner Logic
        if (( $(echo "$INTEL_GPU_USAGE < $INTEL_GPU_START_THRESHOLD" | bc -l) )); then
            if ! docker ps | grep -q "$INTEL_CONTAINER_NAME"; then
                echo "$(date): Intel GPU usage is low ($INTEL_GPU_USAGE%). Starting Intel GPU miner..."
                docker-compose up -d "$INTEL_CONTAINER_NAME"
            fi
        elif (( $(echo "$INTEL_GPU_USAGE > $INTEL_GPU_STOP_THRESHOLD" | bc -l) )); then
            if docker ps | grep -q "$INTEL_CONTAINER_NAME"; then
                echo "$(date): Intel GPU usage is high ($INTEL_GPU_USAGE%). Stopping Intel GPU miner..."
                docker-compose stop "$INTEL_CONTAINER_NAME"
            fi
        fi
    else
        echo "$(date): Intel GPU not detected. Skipping Intel GPU miner..."
    fi

    # CPU Miner Logic
    if (( $(echo "$CPU_USAGE < $CPU_START_THRESHOLD" | bc -l) )); then
        if ! docker ps | grep -q "$CPU_CONTAINER_NAME"; then
            echo "$(date): CPU usage is low ($CPU_USAGE%). Starting CPU miner..."
            docker-compose up -d "$CPU_CONTAINER_NAME"
        fi
    elif (( $(echo "$CPU_USAGE > $CPU_STOP_THRESHOLD" | bc -l) )); then
        if docker ps | grep -q "$CPU_CONTAINER_NAME"; then
            echo "$(date): CPU usage is high ($CPU_USAGE%). Stopping CPU miner..."
            docker-compose stop "$CPU_CONTAINER_NAME"
        fi
    fi

    # Wait before the next check
    sleep $CHECK_INTERVAL
done
