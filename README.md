# linux-bash-scripts

---

# 🐧 Linux System Administration Scripts

Two powerful Bash scripts for log analysis and system monitoring.

## 📦 Scripts Overview

### 🔍 `log_analyzer.sh` 

**Purpose**: Analyze log files for errors, warnings, and patterns  

**Features**:

✔ Counts ERROR/WARNING/INFO messages  
✔ Identifies top 5 frequent errors  
✔ Generates timeline of first/last errors  
✔ Creates hourly error distribution charts  
✔ Outputs formatted report (text/file)  

**Usage**:

Bash Script for Log File Analysis

  1. Save it as log_analyzer.sh

  2. Make it executable: chmod +x log_analyzer.sh

  3. Run it with your log file: ./log_analyzer.sh /var/log/application.log

### 📊 `system_health_monitor.sh`  

**Purpose**: Real-time system performance monitoring

**Features**:

✔ Live CPU/Memory/Disk usage tracking  
✔ Process monitoring (top resource hogs)  
✔ Network connectivity checks  
✔ Customizable refresh interval  
✔ Threshold-based alerts (visual/audio)  

**Usage**:

Bash Script for Real-Time System Health Monitoring

  1.  Save the script as system_monitor.sh

  2.  Make it executable: chmod +x system_monitor.sh

  3.  Run it: ./system_monitor.sh

---

## 🛠️ Requirements

Bash 4.0+

Linux/Unix environment

---

## 📄 License

This project is released under the MIT License.

---

## 👤 Author

*Wasiq Mahmood*  
📬 wasiqmahmood93@gmail.com
