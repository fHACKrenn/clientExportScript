#!/bin/sh
cat > /usr/local/bin/client-boot-report.sh << 'EOF'
#!/bin/bash
# Wait for network (max 30 sec)
for i in {1..30}; do
    if ip route get 1 >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

PUSHGATEWAY="http://192.168.18.1:9091"
# Use MAC address as unique instance identifier
MAC=$(ip link show $(ip route | awk '/default/ {print $5}') | awk '/ether/ {print $2}' | tr -d ':')
INSTANCE="client-$MAC"
JOB="client_boot"

# Gather data
IP=$(ip -4 route get 1 | awk '{print $NF;exit}')
CPU_CORES=$(nproc)
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
DISK_GB=$(lsblk -b -d -o SIZE -n | head -1 | awk '{print $1/1024/1024/1024}')
PRODUCT=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
SERIAL=$(dmidecode -s system-serial-number 2>/dev/null || echo "Unknown")

# Build Prometheus metrics
METRICS=$(cat <<EOM
# HELP client_boot_time Unix timestamp of boot
# TYPE client_boot_time gauge
client_boot_time $(date +%s)
# HELP client_ip IP address
# TYPE client_ip gauge
client_ip{ip="$IP"} 1
# HELP client_cpu_cores Number of CPU cores
# TYPE client_cpu_cores gauge
client_cpu_cores $CPU_CORES
# HELP client_memory_mb Total memory in MB
# TYPE client_memory_mb gauge
client_memory_mb $MEM_MB
# HELP client_disk_total_gb Total disk in GB
# TYPE client_disk_total_gb gauge
client_disk_total_gb $DISK_GB
# HELP client_product_name Product name
# TYPE client_product_name gauge
client_product_name{product="$PRODUCT"} 1
# HELP client_serial Serial number
# TYPE client_serial gauge
client_serial{serial="$SERIAL"} 1
EOM
)

# Push to Pushgateway with retry
for i in {1..3}; do
    curl -s -X POST --data-binary "$METRICS" "$PUSHGATEWAY/metrics/job/$JOB/instance/$INSTANCE" && break
    sleep 2
done
EOF
chmod +x /usr/local/bin/client-boot-report.sh
