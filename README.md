# 🚀 LIMO - (Advanced System Monitoring & Auto-Healing) 🔥

## 📝 Overview
**LIMO (Linux Monitor)** is a powerful and interactive Bash-based **system monitoring tool** designed to keep your Linux system running smoothly. It provides real-time monitoring, **auto-healing** for high CPU usage, process management, network bandwidth monitoring, and comprehensive log tracking—all with an intuitive interface and **Telegram alerts**. 📊💡

## ✨ Features (Enhanced in v2.0)
✅ **Real-time System Monitoring** – Stay informed about CPU, memory, disk, and network usage with improved metrics

✅ **Enhanced Auto-Healing** – Now runs for 24-hour cycles with configurable check intervals (default: 60s)

✅ **Advanced Process Management** – Search/filter processes by name and view detailed CPU/MEM usage before killing

✅ **Network Bandwidth Monitoring** – View real-time **internet speed usage** with human-readable format (KB/s, MB/s, GB/s) 🌐

✅ **Comprehensive Logging System** – New toggleable monitoring with:
   - 30-minute monitoring sessions
   - 5-second interval data collection
   - PID file tracking to prevent duplicates

✅ **Expanded Log Viewer** – Now includes:
   - System monitor logs
   - Cloud-init logs
   - Package manager history
   - User login history
   - Failed login attempts
   - Critical system errors

✅ **Improved Dependency Management** – Automatic installation of missing packages with support for:
   - apt (Debian/Ubuntu)
   - dnf/yum (RHEL/CentOS)

✅ **Interactive Menu** – User-friendly dashboard using `whiptail` with better organization

✅ **Telegram Integration** – Enhanced alerts for all major actions

---

## 🔧 Installation & Setup
### 📌 Prerequisites
The script will now automatically check and install missing dependencies including:
- `bc curl whiptail sysstat iproute2 procps coreutils gawk util-linux systemd`

### 📥 Installation Steps
1️⃣ Clone this repository:
   ```bash
   git clone https://github.com/mechpiyush/limo.git
   cd limo
   ```
2️⃣ Make the script executable:
   ```bash
   chmod +x limo.sh
   ```
3️⃣ Configure environment variables in the script:
   ```bash
   THRESHOLD_CPU=80         # CPU usage threshold (in %)
   HEAL_INTERVAL=60         # Interval in seconds between checks
   REFRESH_RATE=1           # Dashboard refresh rate in seconds
   BOT_TOKEN="your_bot_token" # Telegram bot token
   CHAT_ID="your_chat_id"   # Telegram chat ID
   ```

---

## 🎛️ New Configuration Options
```bash
LOG_FILE="$HOME/limo/logs/sys_monitor.log"  # Centralized log location
MONITOR_PID_FILE="/tmp/system_monitor.pid"  # PID tracking for monitoring
MONITOR_SCRIPT="/tmp/system_monitor.sh"     # Temporary monitoring script
```

---

## 🚀 Enhanced Usage
### ▶️ Start LIMO
```bash
./limo.sh
```

### 🆕 New Dashboard Options:
1️⃣ **Refresh** – Update system stats (configurable interval)

2️⃣ **Kill a Process** – Enhanced process search and selection

3️⃣ **Network Bandwidth Monitor** – Real-time speed tracking

4️⃣ **Toggle Auto-Healing** – 24-hour healing cycles (default 60s checks)

5️⃣ **Toggle System Monitoring** – New! Start/stop 30-minute monitoring sessions

6️⃣ **View System Logs** – Expanded log categories:
   - System Monitor Logs
   - Cloud-init logs
   - Package history
   - Login history
   - Failed logins
   - Systemd errors

7️⃣ **Exit** – Clean shutdown

---

## 📜 Enhanced Logging System
- **Monitoring Sessions**: Runs for 30 minutes by default, collecting data every 5 seconds
- **Centralized Logs**: All data stored in `$HOME/limo/logs/sys_monitor.log`
- **PID Tracking**: Prevents duplicate monitoring sessions
- **Permission Management**: Automatic log file permission setting (644)

---

## ⚙️ Technical Improvements
1️⃣ **Better Dependency Handling**:
   - Automatic detection of package manager (apt/dnf/yum)
   - Interactive installation prompts
   - Comprehensive dependency mapping

2️⃣ **Improved Human-Readable Formatting**:
   - Enhanced byte conversion for network speeds
   - Better numeric formatting throughout

3️⃣ **More Robust Process Management**:
   - Process search functionality
   - Detailed process information before killing
   - Confirmation prompts

4️⃣ **Enhanced Auto-Healing**:
   - 24-hour runtime limit
   - PID file tracking
   - Better Telegram notifications

---

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing
Pull requests are welcome! Feel free to open an issue for discussions. 🛠️

## 📧 Contact
For any issues, reach out via **GitHub Issues** or **Email**.

---

**Made with ❤️ by [Piyush Sharma](https://github.com/mechpiyush) ✨**

**Version 2.0** - Now with enhanced monitoring, better logging, and improved user experience!

Key changes from v1 to v2:
- Added toggleable system monitoring
- Expanded log viewing capabilities
- Improved dependency management
- Enhanced process management
- Better network monitoring
- More robust auto-healing
- Improved user interface
- Added confirmation prompts for major actions
- Better Telegram integration
