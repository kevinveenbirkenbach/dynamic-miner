#!/bin/bash

# Thresholds for GPU usage (separate start and stop thresholds)
GPU_START_THRESHOLD=$1  # GPU usage percentage to start the GPU miner
GPU_STOP_THRESHOLD=$2   # GPU usage percentage to stop the GPU miner

# Thresholds for CPU usage (separate start and stop thresholds)
CPU_START_THRESHOLD=$3  # CPU usage percentage to start the CPU miner
CPU_STOP_THRESHOLD=$4   # CPU usage percentage to stop the CPU miner

CHECK_INTERVAL=$5       # Time in seconds between checks

# Docker container names
GPU_CONTAINER_NAME="gpu-miner"
CPU_CONTAINER_NAME="cpu-miner"

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

    # GPU Miner Logic
    if (( $(echo "$GPU_USAGE < $GPU_START_THRESHOLD" | bc -l) )); then
        if ! docker ps | grep -q "$GPU_CONTAINER_NAME"; then
            echo "$(date): GPU usage is low ($GPU_USAGE%). Starting GPU miner..."
            docker-compose up -d "$GPU_CONTAINER_NAME"
        fi
    elif (( $(echo "$GPU_USAGE > $GPU_STOP_THRESHOLD" | bc -l) )); then
        if docker ps | grep -q "$GPU_CONTAINER_NAME"; then
            echo "$(date): GPU usage is high ($GPU_USAGE%). Stopping GPU miner..."
            docker-compose stop "$GPU_CONTAINER_NAME"
        fi
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
