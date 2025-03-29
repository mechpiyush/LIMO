#!/bin/bash

# Configuration
LOG_FILE="$HOME/limo/logs/sys_monitor.log"
MONITOR_PID_FILE="/tmp/system_monitor.pid"
MONITOR_SCRIPT="/tmp/system_monitor.sh"
THRESHOLD_CPU=80
BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"
TELEGRAM_API="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
REFRESH_RATE=1
HEAL_INTERVAL=60

# Required dependencies with their installation commands
declare -A DEPENDENCIES=(
    ["bc"]="bc"
    ["curl"]="curl"
    ["whiptail"]="whiptail"
    ["iostat"]="sysstat"
    ["ss"]="iproute2"
    ["top"]="procps"
    ["df"]="coreutils"
    ["free"]="procps"
    ["ps"]="procps"
    ["awk"]="gawk"
    ["tail"]="coreutils"
    ["last"]="util-linux"
    ["lastb"]="util-linux"
    ["journalctl"]="systemd"
)

# Function to install missing dependencies
install_dependencies() {
    local missing=()
    for cmd in "${!DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("${DEPENDENCIES[$cmd]}")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies detected: ${missing[*]}"
        if whiptail --yesno "Some required packages are missing. Install them now?" 8 60; then
            if ! sudo -v; then
                whiptail --msgbox "Error: Sudo access is required to install dependencies" 8 60
                exit 1
            fi

            # Different package managers
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y "${missing[@]}"
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y "${missing[@]}"
            elif command -v yum &>/dev/null; then
                sudo yum install -y "${missing[@]}"
            else
                whiptail --msgbox "Error: Could not detect package manager" 8 60
                exit 1
            fi

            # Verify installation
            for cmd in "${!DEPENDENCIES[@]}"; do
                if ! command -v "$cmd" &>/dev/null; then
                    whiptail --msgbox "Error: Failed to install $cmd" 8 60
                    exit 1
                fi
            done
        else
            whiptail --msgbox "Error: Required dependencies are missing" 8 60
            exit 1
        fi
    fi
}

# Initialize log directory and files
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Function to convert bytes to human-readable format
human_format() {
    local bytes=$1
    if (( bytes > 10**9 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024 / 1024 / 1024") GB"
    elif (( bytes > 10**6 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024 / 1024") MB"
    elif (( bytes > 10**3 )); then
        echo "$(bc <<< "scale=2; $bytes / 1024") KB"
    else
        echo "$bytes B"
    fi
}

# Enhanced log_system_data function with toggle feature
log_system_data() {
    # Check if monitoring is already running
    if [ -f "$MONITOR_PID_FILE" ] && ps -p $(cat "$MONITOR_PID_FILE") > /dev/null; then
        whiptail --msgbox "⚠️ System monitoring is already running!\n\nData is being collected to: $LOG_FILE" 10 60
        return
    fi

    # Create the monitoring script
    cat > "$MONITOR_SCRIPT" << 'EOF'
#!/bin/bash

LOG_FILE="$1"
DURATION_MINUTES=30
INTERVAL_SECONDS=5

# Create log directory if not exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Calculate end time
END_TIME=$(date -d "+$DURATION_MINUTES minutes" +%s)

# Monitoring loop
while [ $(date +%s) -lt $END_TIME ]; do
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4"%"}')"
        echo "Memory: $(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)", $3, $2, $3*100/$2}')"
        echo "Disk: $(df -h / | awk 'NR==2 {print $5}')"
        echo "Connections: $(ss -tulnp | wc -l)"
        echo "Load Avg: $(uptime | awk -F'load average: ' '{print $2}')"
        echo ""
    } >> "$LOG_FILE"

    sleep $INTERVAL_SECONDS
done

# Cleanup after completion
rm -f "$MONITOR_PID_FILE"
EOF

    # Make the script executable
    chmod +x "$MONITOR_SCRIPT"

    # Start monitoring in background
    "$MONITOR_SCRIPT" "$LOG_FILE" &
    MONITOR_PID=$!
    echo $MONITOR_PID > "$MONITOR_PID_FILE"

    whiptail --msgbox "✅ System monitoring started!\n\n• Interval: Every 5 seconds\n• Duration: 30 minutes\n• Log file: $LOG_FILE" 12 60
}

# Function to stop monitoring
stop_system_monitoring() {
    if [ ! -f "$MONITOR_PID_FILE" ]; then
        whiptail --msgbox "⚠️ No active system monitoring found" 10 60
        return
    fi

    MONITOR_PID=$(cat "$MONITOR_PID_FILE")
    if ps -p $MONITOR_PID > /dev/null; then
        kill $MONITOR_PID
        rm -f "$MONITOR_PID_FILE"
        whiptail --msgbox "🛑 System monitoring stopped\n\nExisting data preserved in: $LOG_FILE" 10 60
    else
        rm -f "$MONITOR_PID_FILE"
        whiptail --msgbox "⚠️ Monitoring was not running (cleaned up PID file)" 10 60
    fi
}

# Toggle function for the menu with confirmation prompts
toggle_system_monitoring() {
    # Check if monitoring is already running
    if [ -f "$MONITOR_PID_FILE" ] && ps -p $(cat "$MONITOR_PID_FILE") >/dev/null 2>&1; then
        # Monitoring is running - prompt to disable
        if whiptail --yesno "System monitoring is currently active.\n\nDo you want to disable it?" 10 60; then
            stop_system_monitoring  # Use the existing stop function
            send_telegram_alert "🛑 System monitoring has been manually disabled."
        else
            whiptail --msgbox "System monitoring remains active." 8 40
        fi
    else
        # Monitoring not running - prompt to enable
        if whiptail --yesno "Enable system monitoring?\n\nWhen enabled, it will:\n- Run for 30 minutes\n- Collect data every 5 seconds\n- Log to: $LOG_FILE" 12 60; then
            log_system_data  # Use the existing start function
            send_telegram_alert "✅ System monitoring has been enabled. Duration: 30 minutes, Interval: 5 seconds."
        else
            whiptail --msgbox "System monitoring remains inactive." 8 40
        fi
    fi
}

# Function to send Telegram alert
send_telegram_alert() {
    local message="⚠ System Alert%0A$(date)%0A%0A$1"
    curl -s -X POST "$TELEGRAM_API" -d chat_id="$CHAT_ID" -d text="$message" -d parse_mode="Markdown" >/dev/null
}

# Function to check CPU and send alert if needed
check_cpu_alert() {
    local CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
        send_telegram_alert "🚨 High CPU Usage Detected: $CPU_LOAD% (Threshold: $THRESHOLD_CPU%)"
    fi
}

# Function to display system stats in whiptail
display_stats() {
    while true; do
        # Get system stats
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
        MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
        MEM_USED=$(free -m | awk 'NR==2{print $3}')
        MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
        DISK=$(df -h / | awk 'NR==2 {print $5}')
        NET=$(ss -s | grep "estab" | awk '{print $4}')
        DISK_IO=$(iostat -d | awk 'NR==4 {print $2}' 2>/dev/null || echo "N/A")

        # Get top processes
        TOP_MEM=$(ps -eo pid,user,%mem,comm --sort=-%mem | head -6 | awk '{printf "%-8s %-10s %-5s %s\n", $1, $2, $3, $4}' | tr '\n' '|')

        # Create whiptail menu
        choice=$(whiptail --title " 🖥  SYSTEM MONITOR DASHBOARD " --menu "\
CPU Usage: $CPU% | Memory: $MEM_USED/$MEM_TOTAL MB ($MEM_PERCENT%) | Disk: $DISK
Network: $NET conn | Disk I/O: $DISK_IO MB/s

Top Memory Processes:
$(echo "$TOP_MEM" | tr '|' '\n')" 30 90 6 \
"1" "Refresh (Every $REFRESH_RATE sec)" \
"2" "Kill a Process" \
"3" "Monitor Network Bandwidth" \
"4" "Toggle Auto-Healing (CPU)" \
"5" "Toggle System Monitoring" \
"6" "View System Logs" \
"7" "Exit" 3>&1 1>&2 2>&3)

        # Check CPU threshold in background
        check_cpu_alert &

        case $choice in
            1) sleep "$REFRESH_RATE" ;;
            2) kill_process ;;
            3) monitor_network ;;
            4) toggle_auto_heal ;;
            5) toggle_system_monitoring ;;
            6) show_system_logs ;;
            7) break ;;
            *) break ;;
        esac
    done
}

kill_process() {
    # Get a list of processes sorted by CPU usage
    PROCESS_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 15)

    # Ask user for a search term
    SEARCH_TERM=$(whiptail --inputbox "Enter process name to search (leave empty for all):" 8 60 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && return  # User canceled input

    if [ -n "$SEARCH_TERM" ]; then
        FILTERED_LIST=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | grep -i "$SEARCH_TERM" | awk '{printf "%s \"%s (CPU: %s%%, MEM: %s%%)\"\n", $1, $5, $3, $4}' | head -n 10)

        # Check if search found no results
        if [ -z "$FILTERED_LIST" ]; then
            whiptail --msgbox "Invalid search... Process not found" 8 40
            return 1
        fi
    else
        FILTERED_LIST="$PROCESS_LIST"
    fi

    # Show process list in whiptail menu
    PID=$(whiptail --title "Select Process to Kill" --menu "Select a process to kill:" 20 80 10 $FILTERED_LIST 3>&1 1>&2 2>&3)
    [ -z "$PID" ] && return  # User canceled selection

    # Kill the selected process
    if kill -9 "$PID" 2>/dev/null; then
        send_telegram_alert "Process $PID was killed."
        whiptail --msgbox "✅ Process $PID killed!" 8 40
    else
        whiptail --msgbox "❌ Failed to kill process $PID!" 8 40
    fi
}

# Function to monitor network bandwidth
monitor_network() {
    # Detect active network interface
    INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
    [ -z "$INTERFACE" ] && INTERFACE="eth0"

    # Get initial values
    prev_rx=$(awk "/$INTERFACE/ {print \$2}" /proc/net/dev)
    prev_tx=$(awk "/$INTERFACE/ {print \$10}" /proc/net/dev)

    while true; do
        # Get current values
        curr_rx=$(awk "/$INTERFACE/ {print \$2}" /proc/net/dev)
        curr_tx=$(awk "/$INTERFACE/ {print \$10}" /proc/net/dev)

        # Calculate differences
        rx_diff=$((curr_rx - prev_rx))
        tx_diff=$((curr_tx - prev_tx))

        # Convert to bits and calculate speed (1 byte = 8 bits)
        rx_speed=$((rx_diff * 8))
        tx_speed=$((tx_diff * 8))

        # Update previous values
        prev_rx=$curr_rx
        prev_tx=$curr_tx

        # Format speeds
        rx_human=$(human_format $rx_speed)
        tx_human=$(human_format $tx_speed)

        # Create display message
        message="\
Network Interface: $INTERFACE

Download Speed: $rx_human/s
Upload Speed:   $tx_human/s

Press ESC to return to main menu"

        # Display in whiptail with option to refresh or exit
        choice=$(whiptail --title "🌐 Network Bandwidth Monitor" --menu "$message" 25 90 2 \
        "1" "Refresh" \
        "2" "Exit" 3>&1 1>&2 2>&3)

        [ "$choice" != "1" ] && break

        # Sending telegram alert
        send_telegram_alert "$message"
    done
}

# Function to toggle auto-healing for CPU
toggle_auto_heal() {
    # Check if auto-heal is already running
    if [ -f "/tmp/auto_heal.pid" ]; then
        PID=$(cat /tmp/auto_heal.pid)
        if kill -0 "$PID" 2>/dev/null; then
            # Auto-heal is running, prompt to disable
            if whiptail --yesno "Auto-healing is currently active. Do you want to disable it?" 8 78; then
                kill "$PID"
                rm "/tmp/auto_heal.pid"
                whiptail --msgbox "Auto-healing has been disabled." 8 40
                send_telegram_alert "🛑 Auto-healing has been manually disabled."
            fi
            return
        else
            # Stale PID file
            rm "/tmp/auto_heal.pid"
        fi
    fi

    # Auto-heal not running, prompt to enable
    if whiptail --yesno "Enable auto-healing? When enabled, it will run for 24 hours, checking every $HEAL_INTERVAL seconds and killing the top CPU process if usage exceeds ${THRESHOLD_CPU}%." 12 78; then
        (
            end_time=$(($(date +%s) + 86400)) # 24 hours
            while [ "$(date +%s)" -lt "$end_time" ]; do
                CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
                if (( $(echo "$CPU_LOAD > $THRESHOLD_CPU" | bc -l) )); then
                    PID_TO_KILL=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $1}')
                    PROCESS_NAME=$(ps -eo pid,%cpu,comm --sort=-%cpu | awk 'NR==2{print $3}')
                    if [ -n "$PID_TO_KILL" ]; then
                        kill -9 "$PID_TO_KILL"
                        send_telegram_alert "🔧 Auto-heal: High CPU ($CPU_LOAD% > $THRESHOLD_CPU%). Killed process $PROCESS_NAME (PID: $PID_TO_KILL)."
                    fi
                fi
                sleep "$HEAL_INTERVAL"
            done
            rm "/tmp/auto_heal.pid" 2>/dev/null
            send_telegram_alert "🕒 Auto-healing cycle completed after 24 hours and is now inactive."
        ) &
        echo $! > "/tmp/auto_heal.pid"
        whiptail --msgbox "✅ Auto-healing has been enabled for 24 hours. A Telegram alert will notify you when it completes." 10 70
        send_telegram_alert "✅ Auto-healing has been enabled. It will run for 24 hours, checking every $HEAL_INTERVAL seconds."
    else
        whiptail --msgbox "Auto-healing remains inactive." 8 40
    fi
}

# Function to show system logs
show_system_logs() {
    while true; do
        local choice=$(whiptail --title "📜 SYSTEM LOG VIEWER" --menu "Select log type to view:" 20 70 7 \
            "1" "System Monitor Logs - LIMO" \
            "2" "System initialization & cloud setup" \
            "3" "Software install/update History" \
            "4" "User Login History (last 10)" \
            "5" "Failed Login Attempts (last 5)" \
            "6" "Critical Errors (Kernel/systemd)" \
            "7" "Return to Main Menu" \
            3>&1 1>&2 2>&3)

        case $choice in
            1) show_log_file "$LOG_FILE" "SYSTEM MONITOR LOGS" ;;
            2) show_log_file "/var/log/cloud-init.log" "CLOUD INIT LOGS" "" ;;  # Third argument is optional for filter
            3) show_log_file "/var/log/dnf.log" "PACKAGE MANAGER HISTORY" "debug" ;;
            4) show_last_logins ;;
            5) show_failed_logins ;;
            6) show_systemd_errors ;;
            7|"") break ;;
            *) break ;;
        esac
    done
}

# Helper function for displaying log files with sudo
show_log_file() {
    local file=$1
    local title=${2:-"Log File"}
    local filter=${3:-""}

    if ! sudo test -f "$file"; then
        whiptail --msgbox "Error: Log file not found: $file" 10 60
        return
    fi

    if [ -n "$filter" ]; then
        sudo grep -a -E -i "$filter" "$file" | tail -n 30 > /tmp/log_display.txt || \
            echo "No matching entries found" > /tmp/log_display.txt
    else
        sudo tail -n 30 "$file" > /tmp/log_display.txt
    fi

    whiptail --title "$title" --textbox /tmp/log_display.txt 25 90 --scrolltext
    rm -f /tmp/log_display.txt
}

show_last_logins() {
    sudo last -n 10 > /tmp/log_display.txt
    whiptail --title "Recent Logins (last 10)" --textbox /tmp/log_display.txt 15 90
    rm -f /tmp/log_display.txt
}

show_failed_logins() {
    sudo lastb -a -n 5 2>/dev/null > /tmp/log_display.txt || \
        echo "No failed login attempts" > /tmp/log_display.txt
    whiptail --title "Failed Login Attempts" --textbox /tmp/log_display.txt 10 90
    rm -f /tmp/log_display.txt
}

show_systemd_errors() {
    sudo journalctl -p 3 -xb --no-pager -n 15 > /tmp/log_display.txt
    whiptail --title "Critical System Errors (last 15)" --textbox /tmp/log_display.txt 25 90
    rm -f /tmp/log_display.txt
}

# Main execution
install_dependencies
while true; do
    display_stats
    if whiptail --title "Exit" --yesno "Are you sure you want to exit the system monitor?" 8 78; then
        whiptail --msgbox "Thank you for using the System Monitor!" 8 50
        break
    fi
done
