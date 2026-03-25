#!/bin/bash
# Wait for network (max 30 sec)
for i in {1..30}; do
    if ip route get 1 >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

GATEWAY=$(ip route | grep default | awk '{print $3}')
PUSHGATEWAY="http://$GATEWAY:9091"

# Get MAC address from default interface
DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}')
if [ -z "$DEFAULT_IFACE" ]; then
    # fallback: first interface with link up (excluding loopback)
    DEFAULT_IFACE=$(ip link show up | grep -E '^[0-9]+:' | grep -v lo | head -1 | cut -d: -f2 | xargs)
fi
MAC=$(ip link show "$DEFAULT_IFACE" | awk '/ether/ {print $2}' | tr -d ':')
INSTANCE="client-$MAC"
JOB="client_boot"

# Gather data
IP=$(ip -4 route get 1 | awk '{print $NF;exit}')
CPU_CORES=$(nproc)
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
DISK_GB=$(lsblk -b -d -o SIZE -n | head -1 | awk '{printf "%.1f", $1/1024/1024/1024}')
PRODUCT=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
SERIAL=$(dmidecode -s system-serial-number 2>/dev/null || echo "Unknown")

# Build metrics (ensuring no extra blank lines and proper newline)
METRICS=$(printf "%s\n" \
"# HELP client_boot_time Unix timestamp of boot" \
"# TYPE client_boot_time gauge" \
"client_boot_time $(date +%s)" \
"# HELP client_ip IP address" \
"# TYPE client_ip gauge" \
"client_ip{ip=\"$IP\"} 1" \
"# HELP client_cpu_cores Number of CPU cores" \
"# TYPE client_cpu_cores gauge" \
"client_cpu_cores $CPU_CORES" \
"# HELP client_memory_mb Total memory in MB" \
"# TYPE client_memory_mb gauge" \
"client_memory_mb $MEM_MB" \
"# HELP client_disk_total_gb Total disk in GB" \
"# TYPE client_disk_total_gb gauge" \
"client_disk_total_gb $DISK_GB" \
"# HELP client_product_name Product name" \
"# TYPE client_product_name gauge" \
"client_product_name{product=\"$PRODUCT\"} 1" \
"# HELP client_serial Serial number" \
"# TYPE client_serial gauge" \
"client_serial{serial=\"$SERIAL\"} 1" \
)

# Send with explicit newline at the end
printf "%s\n" "$METRICS" | curl -X POST --data-binary @- "$PUSHGATEWAY/metrics/job/$JOB/instance/$INSTANCE"
