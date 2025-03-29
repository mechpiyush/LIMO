#!/bin/bash

# Configuration
LOG_FILE="$HOME/limo/logs/sys_monitor.log"
THRESHOLD_CPU=80
BOT_TOKEN="your_bot_token"    # Check readme file to know how to get it.
CHAT_ID="your_chat_id"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
REFRESH_RATE=1  # seconds for dashboard refresh
HEAL_INTERVAL=60  # seconds between auto-heal checks

# Ensure dependencies are installed
dependencies=(bc curl whiptail iostat ss top df free ps awk tail)
for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Please install it first." >&2
        exit 1
    fi
done

# Initialize log file if not exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Function to convert bytes to human-readable format
human_format() {
    awk 'BEGIN { suffix[1]="B"; suffix[2]="KB"; suffix[3]="MB"; suffix[4]="GB"; 
        val='$1'; i=1;
        while (val>=1024 && i<4) { val/=1024; i++ }
        printf "%.2f %s", val, suffix[i] }'
}

# Function to log system data
log_system_data() {
    echo "$(date) | " >> "$LOG_FILE"
    echo "CPU Usage: $(top -bn1 | awk '/Cpu\(s\)/ {print $2 + $4"%"}')" >> "$LOG_FILE"
    echo "Memory Usage: $(free -m | awk 'NR==2{printf "Memory: %s/%sMB (%.2f%%)\n", $3, $2, $3*100/$2 }')" >> "$LOG_FILE"
    echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')" >> "$LOG_FILE"
    echo "Active Connections: $(ss -tulnp | wc -l)" >> "$LOG_FILE"
}

# Function to send Telegram alert
send_telegram_alert() {
    local message="⚠ System Alert%0A$(date)%0A%0A$1"
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$message" -d parse_mode="Markdown" >/dev/null
}

# Function to check CPU and send alert if needed
check_cpu_alert() {
    local CPU_LOAD=$(top -bn1 | awk '/Cpu\(s\)/ {print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        send_telegram_alert "🚨 High CPU Usage Detected: $CPU_LOAD% (Threshold: $THRESHOLD_CPU%)"
    fi
}

# Function to handle script cleanup
cleanup() {
    rm -f /tmp/auto_heal.pid
    exit 0
}
trap cleanup SIGINT SIGTERM

# Function to display system stats
display_stats() {
    while true; do
        CPU=$(top -bn1 | awk '/Cpu\(s\)/ {print int($2 + $4)}')
        MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
        MEM_USED=$(free -m | awk 'NR==2{print $3}')
        MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
        DISK=$(df -h / | awk 'NR==2 {print $5}')
        NET=$(ss -s | awk '/estab/ {print $4}')
        DISK_IO=$(iostat -d 2>/dev/null | awk 'NR==4 {print $2}' || echo "N/A")

        TOP_MEM=$(ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | awk '{printf "%s %s %s %s\n", $1, $2, $3, $4}')

        choice=$(whiptail --title "🖥  SYSTEM MONITOR DASHBOARD" --menu "\
CPU: $CPU% | Memory: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%) | Disk: $DISK\
Network: $NET conn | Disk I/O: $DISK_IO MB/s\n\nTop Memory Processes:\n$TOP_MEM" 30 90 6 \
"1" "Refresh" \
"2" "Kill a Process" \
"3" "Monitor Network Bandwidth" \
"4" "Toggle Auto-Healing (CPU)" \
"5" "View Logs" \
"6" "Exit" 3>&1 1>&2 2>&3)

        check_cpu_alert &

        case $choice in
            1) sleep "$REFRESH_RATE" ;;
            2) kill_process ;;
            3) monitor_network ;;
            4) auto_heal ;;
            5) show_logs ;;
            6) break ;;
            *) break ;;
        esac
    done
}

# Function to show logs with error handling
show_logs() {
    if [ ! -s "$LOG_FILE" ]; then
        whiptail --msgbox "Log file is empty or unavailable." 8 40
        return
    fi
    tail -50 "$LOG_FILE" > /tmp/log_temp.txt
    whiptail --title "📜 System Monitor Logs" --scrolltext --textbox /tmp/log_temp.txt 25 90
    rm /tmp/log_temp.txt
    log_content_tele=$(tail -n 10 "$LOG_FILE")
    send_telegram_alert "$log_content_tele"
}

# Main execution
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Are you sure you want to exit the system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        cleanup
    fi
done
