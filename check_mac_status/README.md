# 🖥️ macOS System Health Monitor (`check_mac.sh`)

A specialized diagnostic script designed to provide a high-signal, real-time overview of a Mac's internal state. Unlike the standard Activity Monitor, this script surfaces "hidden" metrics like memory pressure breakdown and energy impact in a single, concise view.

## 🚀 Motivation
Modern macOS (especially on Apple Silicon) manages resources aggressively. Standard tools often show "High RAM usage" without explaining *why*. This script was born from the need to answer three critical questions:
1. **Where is my RAM actually going?** (Distinguishing between active apps, system overhead, and background compression).
2. **Is my CPU truly "busy"?** (Seeing the top 5 consumers by actual impact).
3. **What is killing my battery?** (Identifying the "Energy Impact" of specific apps).

---

## 🧠 Key Features & Logic

### 1. Intelligent RAM Breakdown
The script calculates memory usage in three distinct tiers to provide a complete picture of your 36GB+ capacity:
*   **Resident Memory (Top 5):** The actual "heavy hitters" currently active in your workspace (e.g., Chrome, Docker, VMs).
*   **Breakdown (Remainder):**
    *   **Wired RAM:** The "System Tax." This is memory bolted down by the macOS Kernel and hardware drivers. It cannot be compressed or moved to disk.
    *   **Compressed RAM:** The "Application Overflow." macOS "zips" data from background apps to fit more into your physical RAM, avoiding the performance hit of using the SSD (Swap).
*   **Available:** The true "empty" space left before the system must start swapping.

### 2. Disk & CPU Health
*   **Disk Storage:** Real-time percentage of used vs. available space on your primary partition.
*   **CPU Impact:** A 5-second averaged snapshot of the top processes, preventing "ghost" spikes from skewing the data.

### 3. Battery Intelligence
*   **Energy Impact:** Lists processes by their battery drain score.
*   **Time Estimates:** Provides real-time "Time until drained" or "Time until fully charged" estimates directly from the system power management.

---

## 🛠️ Potential Use Cases
*   **Developer Diagnostics:** Monitor the "Wired" memory footprint of Docker or Virtual Machines to ensure they aren't starving the host OS.
*   **Performance Troubleshooting:** Quickly identify if a "System Slowdown" is caused by high CPU usage or if the system has reached a "RAM Critical" state (100% usage).
*   **Battery Preservation:** Identify background processes (like "Code Helper" or "WindowServer") that are consuming excessive energy while unplugged.
*   **CLI Dashboard:** Perfect for running in a small terminal window or a tmux pane to keep an eye on system health without opening a heavy GUI.

---

## 🏃 How to Run
Ensure the script has execution permissions:
```bash
chmod +x check_mac.sh
./check_mac.sh
```

### 🌍 Global Access (Recommended)
To run this script from anywhere without navigating to the folder, add an alias to your `~/.zshrc` file:

1. Open your zsh configuration:
   ```bash
   nano ~/.zshrc
   ```
2. Add the following line at the bottom (replace with your actual path):
   ```bash
   alias checkmac='/Users/gedeon/Projects/Scripts/check_mac_status/check_mac.sh'
   ```
3. Save and reload the configuration:
   ```bash
   source ~/.zshrc
   ```
4. Now, simply type `checkmac` from any terminal window.

## 📊 Example Output
```text
🔴 RAM Critical | Status as of 2026-03-27 10:15:04

--- 💾 DISK STORAGE ---
Available: 515Gi / 926Gi (44% used)

--- ⚡ CPU USAGE ---
Overall CPU Used: 53.2%
Top 5 CPU Processes:
  - cloudcode_cli        166.8%
  - cloudcode_cli        152.4%
  - Google Chrome He     34.0%
  - Google Chrome He     18.8%
  - Python               14.1%

--- 🧠 RAM USAGE ---
Available: 189M / 35Gi (99% used)
Top 5 RAM Consumers (Resident Memory):
  - com.apple.Virtua     8108M
  - Google Chrome He     2238M
  - Code Helper (Plu     2018M
  - WindowServer         1798M
  - com.apple.WebKit     1790M
Breakdown (Remainder): 3690M Wired, 15G Compressed

--- 🔋 TOP 5 BATTERY CONSUMERS ---
cloudcode_cli             Energy Impact: 168.6 🔴 High
cloudcode_cli             Energy Impact: 149.9 🔴 High
Google Chrome He          Energy Impact: 34.0 🟡 Moderate
Google Chrome He          Energy Impact: 18.8 🟢 Low
Google Chrome He          Energy Impact: 13.2 🟢 Low

--- ⚡ BATTERY STATUS ---
Battery Level: 100%
Remaining: 2h:45m (until drained)
```
