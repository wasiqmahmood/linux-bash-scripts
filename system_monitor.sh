#!/bin/bash

# Refresh interval
REFRESH=3

# Colors
RESET="\e[0m"
RED="\e[91m"
YELLOW="\e[93m"
GREEN="\e[92m"

# Function to draw bar (based on percent)
draw_bar() {
    local percent=$1
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    local bar=$(printf "█%.0s" $(seq 1 $filled))
    bar+=$(printf "░%.0s" $(seq 1 $empty))
    echo "$bar"
}

# Function to categorize health
health_status() {
    local val=$1
    local warn=$2
    local crit=$3
    if (( val >= crit )); then echo -e "${RED}[CRITICAL]${RESET}"
    elif (( val >= warn )); then echo -e "${YELLOW}[WARNING]${RESET}"
    else echo -e "${GREEN}[OK]${RESET}"
    fi
}

# Function to format size in MB/s
format_speed() {
    awk '{printf "%.1f MB/s", $1 / 1024 / 1024}'
}

# Fake alerts (for demo)
alerts=(
"[14:25:12] CPU usage exceeded 80% (83%)"
"[14:02:37] Memory usage exceeded 75% (78%)"
"[13:46:15] Disk usage on / exceeded 75% (76%)"
)

while true; do
    clear
    now=$(date +"%Y-%m-%d")
    hostname=$(hostname)
    uptime_str=$(uptime -p | cut -d " " -f2-)
    loadavg=$(cat /proc/loadavg | awk '{print $1", "$2", "$3}')
    
    # CPU
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
    cpu_usage=$(awk "BEGIN {print 100 - $cpu_idle}")
    cpu_status=$(health_status "${cpu_usage%.*}" 60 80)
    cpu_bar=$(draw_bar "${cpu_usage%.*}")
    top_procs=$(ps -eo comm,%cpu --sort=-%cpu | awk 'NR>1 && $2>5 { printf "%s (%s%%), ", $1, $2 }' | sed 's/, $//')

    # Memory
    read mem_total mem_used mem_free <<< $(free -m | awk '/Mem:/ {print $2, $3, $4}')
    mem_percent=$(awk "BEGIN {printf \"%d\", ($mem_used/$mem_total)*100}")
    mem_status=$(health_status "$mem_percent" 70 85)
    mem_bar=$(draw_bar "$mem_percent")
    mem_cache=$(free -m | awk '/Mem:/ {print $6}')
    mem_buffers=$(free -m | awk '/Mem:/ {print $7}')

    # Disk
    disk_lines=$(df -h --output=target,pcent | grep -v "Use%" | while read mount usage; do
        p=${usage%\%}
        bar=$(draw_bar $p)
        status=$(health_status $p 70 85)
        printf "  %-8s: %3s%% %s %s\n" "$mount" "$p" "$bar" "$status"
    done)

    # Network - use /proc/net/dev or simulate for demo
    rx_bytes=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    sleep 1
    rx_bytes2=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    tx_bytes2=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    rx_rate=$(format_speed $((rx_bytes2 - rx_bytes)))
    tx_rate=$(format_speed $((tx_bytes2 - tx_bytes)))
    rx_bar=$(draw_bar $(awk "BEGIN {print int((${rx_bytes2}-${rx_bytes})/1024/1024*5)}"))
    tx_bar=$(draw_bar $(awk "BEGIN {print int((${tx_bytes2}-${tx_bytes})/1024/1024*5)}"))

    # Output header
    echo "╔════════════ SYSTEM HEALTH MONITOR v1.0 ════════════╗  [R]efresh rate: ${REFRESH}s"
    printf "║ Hostname: %-25s Date: %s ║  [F]ilter: All\n" "$hostname" "$now"
    printf "║ Uptime: %-44s ║  [Q]uit\n" "$uptime_str"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"

    # CPU
    printf "\nCPU USAGE: %s%% %s %s\n" "${cpu_usage%.*}" "$cpu_bar" "$cpu_status"
    echo "  Process: ${top_procs:-N/A}"

    # Memory
    printf "\nMEMORY: %.1fGB/%.0fGB (%s%%) %s %s\n" "$(awk "BEGIN {print $mem_used/1024}")" "$(awk "BEGIN {print $mem_total/1024}")" "$mem_percent" "$mem_bar" "$mem_status"
    echo "  Free: ${mem_free}MB | Cache: ${mem_cache}MB | Buffers: ${mem_buffers}MB"

    # Disk
    echo -e "\nDISK USAGE:"
    echo "$disk_lines"

    # Network
    echo -e "\nNETWORK:"
    printf "  eth0 (in) : %-10s %s [OK]\n" "$rx_rate" "$rx_bar"
    printf "  eth0 (out): %-10s %s [OK]\n" "$tx_rate" "$tx_bar"

    # Load
    echo -e "\nLOAD AVERAGE: $loadavg"

    # Alerts
    echo -e "\nRECENT ALERTS:"
    for alert in "${alerts[@]}"; do
        echo "$alert"
    done

    echo -e "\nPress 'h' for help, 'q' to quit"

    sleep "$REFRESH"
done
