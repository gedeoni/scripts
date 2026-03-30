# 🖥️ PC System Health Monitor (`check_pc.ps1`)

A high-signal diagnostic script for Windows, designed to replicate the "real-time dashboard" feel of `check_mac.sh`. It surfaces critical performance metrics directly from PowerShell, bypassing the need for Task Manager.

## 🚀 Motivation
Windows performance management can be opaque. `check_pc.ps1` answers:
1. **Is my CPU truly throttled?** (Uses 1-second averaged counters to filter out momentary spikes).
2. **Where is my RAM going?** (Identifies the top 5 memory-heavy processes by Private Working Set).
3. **What's the status of my disk and battery?** (Quick glance at capacity and health).

---

## 🧠 Key Features

### 1. Accurate Resource Tracking
*   **Averaged CPU:** Unlike simple snapshots, it uses performance counters to get a meaningful average of total CPU load.
*   **Memory Breakdown:** Displays both free and total physical memory, listing the top consumers in Megabytes.
*   **Disk Health:** Monitors the primary `C:` drive usage percentage.

### 2. Battery & Power Intelligence
*   **Battery Status:** Detects if you are on AC power or discharging, providing estimated time remaining where available.
*   **Simulated Energy Impact:** On laptops, it uses CPU usage as a proxy for battery drain impact, mirroring the macOS "Energy Impact" score.

### 3. Visual Feedback
*   Uses **Text-based Status Indicators** (e.g., `[CRITICAL]`, `[HIGH]`, `[OK]`) combined with PowerShell foreground colors for maximum compatibility and clarity.

---

## 🛠️ How to Run
This script is written in PowerShell.

### 🏃 Quick Run
1. Open PowerShell.
2. Navigate to the directory:
   ```powershell
   cd C:\Projects\scripts\check_pc_status
   ```
3. Run the script:
   ```powershell
   .\check_pc.ps1
   ```

### 🌍 Global Access (Recommended)
To run this from anywhere by simply typing `checkpc`:

1. Open your PowerShell profile in Notepad:
   ```powershell
   notepad $PROFILE
   ```
2. Add the following function (replace with your actual path):
   ```powershell
   function checkpc {
       & "C:\Projects\scripts\check_pc_status\check_pc.ps1"
   }
   ```
3. Save, close, and restart PowerShell (or run `. $PROFILE`).
4. Type `checkpc` from any terminal.

---

## 📊 Example Output
```text
[OK] System Status | Status as of 2026-03-29 14:30:05

--- DISK STORAGE ---
Available: 450GB / 1000GB (55% used)

--- CPU USAGE ---
Overall CPU Used: 12%
Top 5 CPU Processes:
  - msedge               4.2%
  - Code                 2.1%
  - System               1.5%
  - explorer             0.8%
  - dwm                  0.5%

--- RAM USAGE ---
Available: 8.2GB / 32GB (74% used)
Top 5 RAM Consumers (Private Working Set):
  - msedge               1240MB
  - Code                 850MB
  - docker               600MB
  - slack                420MB
  - Teams                380MB

--- TOP 5 ENERGY IMPACT (Estimated) ---
msedge                    Impact Score: 4.2   LOW
Code                      Impact Score: 2.1   LOW
System                    Impact Score: 1.5   LOW
explorer                  Impact Score: 0.8   LOW
dwm                       Impact Score: 0.5   LOW

--- BATTERY STATUS ---
Battery Level: 95%
Status       : Discharging
Remaining    : 4h:12m
```
