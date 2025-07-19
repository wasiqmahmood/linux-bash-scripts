#!/bin/bash

# Configuration
REFRESH_RATE=3
LOG_FILE="system_health.log"
MAX_ALERTS=5
FILTER="all"

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Alert thresholds
CPU_WARNING=70
CPU_CRITICAL=90
MEM_WARNING=70
MEM_CRITICAL=90
DISK_WARNING=70
DISK_CRITICAL=90
NET_WARNING=80
NET_CRITICAL=95

# Recent alerts array
declare -a RECENT_ALERTS

# Function to display help
show_help() {
    clear
    echo -e "${BLUE}SYSTEM HEALTH MONITOR HELP${NC}"
    echo "----------------------"
    echo "Keyboard shortcuts:"
    echo "  h - Show this help screen"
    echo "  q - Quit the application"
    echo "  r - Change refresh rate"
    echo "  f - Filter displayed metrics (all/cpu/mem/disk/net)"
    echo "  c - Clear alerts log"
    echo "  ↑  - Increase refresh rate by 1s"
    echo "  ↓  - Decrease refresh rate by 1s"
    echo ""
    echo "Press any key to return..."
    read -n 1 -s
}

# Function to log alerts
log_alert() {
    local timestamp=$(date +'%H:%M:%S')
    local message="[$timestamp] $1"
    RECENT_ALERTS=("$message" "${RECENT_ALERTS[@]}")
    if [ ${#RECENT_ALERTS[@]} -gt $MAX_ALERTS ]; then
        RECENT_ALERTS=("${RECENT_ALERTS[@]:0:$MAX_ALERTS}")
    fi
    echo "$message" >> "$LOG_FILE"
}

# Function to get color based on value
get_color() {
    local value=$1
    local warning=$2
    local critical=$3

    if (( $(echo "$value >= $critical" | bc -l) )); then
        echo -e "${RED}"
    elif (( $(echo "$value >= $warning" | bc -l) )); then
        echo -e "${YELLOW}"
    else
        echo -e "${GREEN}"
    fi
}

# Function to generate bar
generate_bar() {
    local percent=$1
    local width=30
    local filled=$(echo "scale=0; $width * $percent / 100" | bc)
    filled=${filled%.*}
    local empty=$((width - filled))

    # Make sure we don't exceed the width
    if [ $filled -gt $width ]; then
        filled=$width
        empty=0
    fi

    for ((i=0; i<filled; i++)); do
        echo -n "█"
    done
    for ((i=0; i<empty; i++)); do
        echo -n "░"
    done
}

# Function to get CPU usage
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    local top_processes=$(ps -eo pcpu,comm --sort=-pcpu | head -n 4 | tail -n 3 | awk '{print $2 " (" $1 "%), "}' | tr -d '\n' | sed 's/, $//')
    
    local status="OK"
    local color=$(get_color "$cpu_usage" "$CPU_WARNING" "$CPU_CRITICAL")
    
    if (( $(echo "$cpu_usage >= $CPU_CRITICAL" | bc -l) )); then
        status="CRITICAL"
        log_alert "CPU usage exceeded $CPU_CRITICAL% ($cpu_usage%)"
    elif (( $(echo "$cpu_usage >= $CPU_WARNING" | bc -l) )); then
        status="WARNING"
        log_alert "CPU usage exceeded $CPU_WARNING% ($cpu_usage%)"
    fi
    
    if [[ "$FILTER" == "all" || "$FILTER" == "cpu" ]]; then
        echo -e "CPU USAGE: ${color}$cpu_usage% $(generate_bar $cpu_usage) [$status]${NC}"
        echo -e "  Process: $top_processes"
    fi
}

# Function to get memory usage
get_memory_usage() {
    local total_mem=$(free -m | awk '/Mem:/ {print $2}')
    local used_mem=$(free -m | awk '/Mem:/ {print $3}')
    local free_mem=$(free -m | awk '/Mem:/ {print $4}')
    local cache_mem=$(free -m | awk '/Mem:/ {print $6}')
    local buffers_mem=$(free -m | awk '/Mem:/ {print $5}')
    local mem_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    local status="OK"
    local color=$(get_color "$mem_percent" "$MEM_WARNING" "$MEM_CRITICAL")
    
    if (( $(echo "$mem_percent >= $MEM_CRITICAL" | bc -l) )); then
        status="CRITICAL"
        log_alert "Memory usage exceeded $MEM_CRITICAL% ($mem_percent%)"
    elif (( $(echo "$mem_percent >= $MEM_WARNING" | bc -l) )); then
        status="WARNING"
        log_alert "Memory usage exceeded $MEM_WARNING% ($mem_percent%)"
    fi
    
    if [[ "$FILTER" == "all" || "$FILTER" == "mem" ]]; then
        echo -e "MEMORY: ${color}$used_mem""MB/$total_mem""MB ($mem_percent%) $(generate_bar $mem_percent) [$status]${NC}"
        echo -e "  Free: ${free_mem}MB | Cache: ${cache_mem}MB | Buffers: ${buffers_mem}MB"
    fi
}

# Function to get disk usage
get_disk_usage() {
    if [[ "$FILTER" == "all" || "$FILTER" == "disk" ]]; then
        echo "DISK USAGE:"
        df -h | grep -E '^/dev' | awk '{print $6 " " $5}' | while read mount usage; do
            local percent=${usage%\%}
            local status="OK"
            local color=$(get_color "$percent" "$DISK_WARNING" "$DISK_CRITICAL")
            
            if (( $(echo "$percent >= $DISK_CRITICAL" | bc -l) )); then
                status="CRITICAL"
                log_alert "Disk usage on $mount exceeded $DISK_CRITICAL% ($percent%)"
            elif (( $(echo "$percent >= $DISK_WARNING" | bc -l) )); then
                status="WARNING"
                log_alert "Disk usage on $mount exceeded $DISK_WARNING% ($percent%)"
            fi
            
            printf "  %-9s: ${color}%3s%% %s [%s]${NC}\n" "$mount" "$percent" "$(generate_bar $percent)" "$status"
        done
    fi
}

# Function to get network usage
get_network_usage() {
    if [[ "$FILTER" == "all" || "$FILTER" == "net" ]]; then
        echo "NETWORK:"
        local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
        for intf in $interfaces; do
            local rx1=$(cat /sys/class/net/$intf/statistics/rx_bytes)
            local tx1=$(cat /sys/class/net/$intf/statistics/tx_bytes)
            sleep 1
            local rx2=$(cat /sys/class/net/$intf/statistics/rx_bytes)
            local tx2=$(cat /sys/class/net/$intf/statistics/tx_bytes)
            
            local rx_speed=$(echo "scale=2; ($rx2 - $rx1) / 1024 / 1024" | bc)
            local tx_speed=$(echo "scale=2; ($tx2 - $tx1) / 1024 / 1024" | bc)
            
            local rx_color=$(get_color "$rx_speed" "$NET_WARNING" "$NET_CRITICAL")
            local tx_color=$(get_color "$tx_speed" "$NET_WARNING" "$NET_CRITICAL")
            
            printf "  %-5s (in) : ${rx_color}%5.2f MB/s %s [OK]${NC}\n" "$intf" "$rx_speed" "$(generate_bar $(echo "scale=0; $rx_speed * 100 / 10" | bc))"
            printf "  %-5s (out): ${tx_color}%5.2f MB/s %s [OK]${NC}\n" "$intf" "$tx_speed" "$(generate_bar $(echo "scale=0; $tx_speed * 100 / 10" | bc))"
        done
    fi
}

# Function to get load average
get_load_avg() {
    if [[ "$FILTER" == "all" ]]; then
        local load=$(uptime | awk -F'average: ' '{print $2}')
        echo "LOAD AVERAGE: $load"
    fi
}

# Function to display recent alerts
show_recent_alerts() {
    if [[ "$FILTER" == "all" ]]; then
        echo "RECENT ALERTS:"
        if [ ${#RECENT_ALERTS[@]} -eq 0 ]; then
            echo "  No recent alerts"
        else
            for alert in "${RECENT_ALERTS[@]}"; do
                echo "  $alert"
            done
        fi
    fi
}

# Main display function
display_dashboard() {
    clear
    
    # Header
    local hostname=$(hostname)
    local date=$(date +'%Y-%m-%d')
    local uptime=$(uptime | awk -F'( |,|:)+' '{print $6" days, "$8" hours, "$10" minutes"}')
    
    echo -e "${BLUE}╔════════════ SYSTEM HEALTH MONITOR v1.0 ════════════╗  [R]efresh rate: ${REFRESH_RATE}s${NC}"
    echo -e "${BLUE}║ Hostname: $hostname          Date: $date ║  [F]ilter: ${FILTER^}${NC}"
    echo -e "${BLUE}║ Uptime: $uptime               ║  [Q]uit${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # System metrics
    get_cpu_usage
    echo ""
    get_memory_usage
    echo ""
    get_disk_usage
    echo ""
    get_network_usage
    echo ""
    get_load_avg
    echo ""
    show_recent_alerts
    echo ""
    echo -e "Press 'h' for help, 'q' to quit"
}

# Main loop
while true; do
    display_dashboard
    
    # Check for user input without blocking
    read -t $REFRESH_RATE -n 1 -s input || continue
    
    case $input in
        q) 
            echo "Exiting system health monitor..."
            exit 0
            ;;
        h)
            show_help
            ;;
        r)
            echo -n "Enter new refresh rate (seconds): "
            read new_rate
            if [[ $new_rate =~ ^[0-9]+$ ]] && [ $new_rate -gt 0 ]; then
                REFRESH_RATE=$new_rate
            else
                echo "Invalid refresh rate. Using current value."
                sleep 1
            fi
            ;;
        f)
            echo -n "Enter filter (all/cpu/mem/disk/net): "
            read new_filter
            case $new_filter in
                all|cpu|mem|disk|net)
                    FILTER=$new_filter
                    ;;
                *)
                    echo "Invalid filter. Using 'all'."
                    sleep 1
                    ;;
            esac
            ;;
        c)
            > "$LOG_FILE"
            RECENT_ALERTS=()
            echo "Alerts cleared."
            sleep 1
            ;;
        $'\x1b') # Handle arrow keys
            read -sn2 -t 0.1 arrow
            case $arrow in
                [A) # Up arrow - increase refresh rate
                    REFRESH_RATE=$((REFRESH_RATE + 1))
                    ;;
                [B) # Down arrow - decrease refresh rate
                    if [ $REFRESH_RATE -gt 1 ]; then
                        REFRESH_RATE=$((REFRESH_RATE - 1))
                    fi
                    ;;
            esac
            ;;
    esac
done