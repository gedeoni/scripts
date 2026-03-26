#!/bin/bash

# --- HELPER FUNCTIONS ---
to_mib() { # Converts a storage value (e.g., "10G", "512M") to Mebibytes (MiB).
    local val=$1
    local num=$(echo "$val" | sed 's/[^0-9.]//g') # Extracts the numerical part (e.g., "10.5" from "10.5GB")
    local unit=$(echo "$val" | sed 's/[0-9.]//g') # Extracts the unit part (e.g., "GB" from "10.5GB")
    case "$unit" in
        T|Ti|TB) echo "$num * 1024 * 1024" | bc ;; # Convert Terabytes/Tebibytes to Mebibytes
        G|Gi|GB) echo "$num * 1024" | bc ;;       # Convert Gigabytes/Gibibytes to Mebibytes
        M|Mi|MB) echo "$num" ;;                   # Already in Mebibytes
        K|Ki|KB) echo "$num / 1024" | bc ;;       # Convert Kilobytes/Kibibytes to Mebibytes
        *) echo "$num" ;;                         # Default: assume Mebibytes or unknown unit
    esac
}

# --- DATA GATHERING ---
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Disk storage
# Get total and available disk space in human-readable format
read -r TOTAL_DISK_STR AVAIL_DISK_STR <<< "$(df -h / | awk 'NR==2 {print $2, $4}')"
TOTAL_DISK_MIB=$(to_mib "$TOTAL_DISK_STR")
AVAIL_DISK_MIB=$(to_mib "$AVAIL_DISK_STR")
USED_DISK_MIB=$(echo "$TOTAL_DISK_MIB - $AVAIL_DISK_MIB" | bc)
DISK_PCT=$(echo "scale=2; ($USED_DISK_MIB / $TOTAL_DISK_MIB) * 100" | bc | awk '{printf "%.0f", $1}')

# Stats Summary
STATS_SUMMARY=$(top -l 1 -n 0)
CPU_LINE=$(echo "$STATS_SUMMARY" | grep "CPU usage")
USER_CPU=$(echo "$CPU_LINE" | awk '{print $3}' | sed 's/%//')
SYS_CPU=$(echo "$CPU_LINE" | awk '{print $5}' | sed 's/%//')
TOTAL_CPU=$(echo "$USER_CPU + $SYS_CPU" | bc)
TOTAL_CPU_VAL=$(echo "$TOTAL_CPU" | awk '{printf "%.0f", $1}')

RAM_LINE=$(echo "$STATS_SUMMARY" | grep "PhysMem")
USED_RAM_STR=$(echo "$RAM_LINE" | awk '{print $2}')
FREE_RAM_STR=$(echo "$RAM_LINE" | awk '{print $(NF-1)}')
USED_RAM_MIB=$(to_mib "$USED_RAM_STR")
FREE_RAM_MIB=$(to_mib "$FREE_RAM_STR")
TOTAL_RAM_MIB=$(echo "$USED_RAM_MIB + $FREE_RAM_MIB" | bc)
RAM_PCT=$(echo "scale=2; ($USED_RAM_MIB / $TOTAL_RAM_MIB) * 100" | bc | awk '{printf "%.0f", $1}')

# --- SUMMARY LINE ---
if [ "$TOTAL_CPU_VAL" -gt 85 ]; then
    SUMMARY="🔴 CPU Critical"
elif [ "$TOTAL_CPU_VAL" -gt 60 ]; then
    SUMMARY="🟡 High CPU"
elif [ "$RAM_PCT" -gt 95 ]; then
    SUMMARY="🔴 RAM Critical"
elif [ "$RAM_PCT" -gt 85 ]; then
    SUMMARY="🟡 High RAM"
elif [ "$DISK_PCT" -gt 90 ]; then
    SUMMARY="🔴 Disk Low"
else
    SUMMARY="🟢 System OK"
fi

# --- OUTPUT ---
echo "$SUMMARY | Status as of $TIMESTAMP"

echo -e "\n--- 💾 DISK STORAGE ---"
printf "Available: %s / %s (%s%% used)\n" "$AVAIL_DISK_STR" "$TOTAL_DISK_STR" "$DISK_PCT"

echo -e "\n--- ⚡ CPU USAGE ---"
printf "Overall CPU Used: %.1f%%\n" "$TOTAL_CPU"
echo "Top 5 CPU Processes:"
# top -stats command,cpu with -l 2. The second COMMAND header marks the start of the data we want.
top -l 2 -stats command,cpu -o cpu -n 5 | awk '
/COMMAND/ { c++; if(c==2) p=1; next }
p {
    # top output: COMMAND is 16 chars, followed by %CPU
    # Use substr to avoid duplication and get full name if possible
    name = substr($0, 1, 16);
    val = substr($0, 17);
    sub(/[ ]+$/, "", name);
    sub(/^[ ]+/, "", val);
    sub(/[ ]+$/, "", val);
    if (name != "") {
        printf "  - %-20s %s%%\n", name, val;
        count++; if(count==5) exit;
    }
}'

echo -e "\n--- 🧠 RAM USAGE ---"
printf "Available: %s / %.0fGi (%s%% used)\n" "$FREE_RAM_STR" "$(echo "$TOTAL_RAM_MIB / 1024" | bc)" "$RAM_PCT"
echo "Top 5 RAM Consumers:"
top -l 1 -stats command,mem -o mem -n 5 | awk '
/COMMAND/ { p=1; next }
p {
    name = substr($0, 1, 16);
    val = substr($0, 17);
    sub(/[ ]+$/, "", name);
    sub(/^[ ]+/, "", val);
    sub(/[ ]+$/, "", val);
    if (name != "") {
        printf "  - %-20s %s\n", name, val;
        count++; if(count==5) exit;
    }
}'

echo -e "\n--- 🔋 TOP 5 BATTERY CONSUMERS ---"
top -l 2 -stats command,power -o power -n 5 | awk '
/COMMAND/ { c++; if(c==2) p=1; next }
p {
    name = substr($0, 1, 16);
    val = substr($0, 17);
    sub(/[ ]+$/, "", name);
    sub(/^[ ]+/, "", val);
    sub(/[ ]+$/, "", val);
    
    if (name != "") {
        color = "🟢 Low";
        # Convert val to number for comparison
        num = val + 0;
        if (num > 50) color = "🔴 High";
        else if (num > 20) color = "🟡 Moderate";
        
        printf "%-25s Energy Impact: %s %s\n", name, val, color;
        count++; if(count==5) exit;
    }
}'

echo -e "\n--- ⚡ BATTERY STATUS ---"
pmset -g batt | grep -v "Now drawing" | awk -F'; ' '{ 
    match($1, /[0-9]+%/);
    pct = substr($1, RSTART, RLENGTH);
    status = $2;

    if (match($3, /[0-9]+:[0-9]+/)) {
        time_str = substr($3, RSTART, RLENGTH);
        split(time_str, t, ":");
        h = t[1]; m = t[2];
    } else {
        h = ""; m = "";
    }

    if (status ~ /discharging/) {
        if (h != "" && m != "") {
            printf "Battery Level: %s\nRemaining: %sh:%sm (until drained)\n", pct, h, m
        } else {
            printf "Battery Level: %s\nRemaining: Calculating...\n", pct
        }
    } else {
        if (h != "" && m != "") {
            printf "Battery Level: %s\nRemaining: %sh:%sm (until fully charged)\n", pct, h, m
        } else if (status ~ /finishing charge/) {
            printf "Battery Level: %s\nRemaining: Finishing charge...\n", pct
        } else if (pct == "100%") {
            printf "Battery Level: %s\nRemaining: Fully Charged\n", pct
        } else {
            printf "Battery Level: %s\nRemaining: Charging (no estimate yet)\n", pct
        }
    }
}'
