#!/bin/bash
# Collect system info and send to server via SSH

SERVER="client-reports@192.168.18.1"
REMOTE_PATH="/home/client-reports/clients-info/$(hostname)-$(date -Iseconds).json"

# Gather data
HOSTNAME=$(hostname)
IP=$(ip -4 route get 1 | awk '{print $NF;exit}')
MAC=$(ip link show $(ip route | awk '/default/ {print $5}') | awk '/ether/ {print $2}')
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
DISK_TOTAL=$(lsblk -b -d -o SIZE -n | head -1 | awk '{print $1/1024/1024/1024 " GB"}')  # assumes first disk
PRODUCT_NAME=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
SERIAL=$(dmidecode -s system-serial-number 2>/dev/null || echo "Unknown")

# Build JSON
JSON=$(cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$HOSTNAME",
  "ip": "$IP",
  "mac": "$MAC",
  "cpu_model": "$CPU_MODEL",
  "cpu_cores": "$CPU_CORES",
  "memory_mb": "$MEM_TOTAL",
  "disk_total": "$DISK_TOTAL",
  "product_name": "$PRODUCT_NAME",
  "serial": "$SERIAL"
}
EOF
)

# Send via SSH (non-interactive, using key)
echo "$JSON" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SERVER" "cat > $REMOTE_PATH"
