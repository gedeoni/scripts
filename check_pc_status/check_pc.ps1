# PowerShell System Health Monitor (check_pc.ps1)
# High-signal diagnostic script for Windows.

# --- DATA GATHERING ---
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 1. Disk Storage (C: Drive)
$DriveC = Get-PSDrive C -ErrorAction SilentlyContinue
if ($DriveC) {
    $TotalDiskGB = [Math]::Round(($DriveC.Used + $DriveC.Free) / 1GB, 1)
    $UsedDiskGB = [Math]::Round($DriveC.Used / 1GB, 1)
    $FreeDiskGB = [Math]::Round($DriveC.Free / 1GB, 1)
    $DiskPct = [Math]::Round(($DriveC.Used / ($DriveC.Used + $DriveC.Free)) * 100)
}

# 2. CPU Usage (Average over 1 second to avoid spikes)
$CpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
$TotalCpuVal = if ($CpuCounter) { [Math]::Round($CpuCounter.CounterSamples[0].CookedValue) } else { 0 }
$TopCpuProcs = Get-Process | Where-Object {$_.CPU -ne $null} | Sort-Object CPU -Descending | Select-Object -First 5 | Select-Object Name, @{Name='CPU';Expression={[Math]::Round($_.CPU, 1)}}

# 3. RAM Usage
$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($OS) {
    $TotalRamGB = [Math]::Round($OS.TotalVisibleMemorySize / 1MB, 1)
    $FreeRamGB = [Math]::Round($OS.FreePhysicalMemory / 1MB, 1)
    $UsedRamGB = [Math]::Round($TotalRamGB - $FreeRamGB, 1)
    $RamPct = [Math]::Round(($UsedRamGB / $TotalRamGB) * 100)
}
$TopRamProcs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | Select-Object Name, @{Name='RAM';Expression={[Math]::Round($_.WorkingSet64 / 1MB, 1)}}

# 4. Battery Status
$Battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$HasBattery = $null -ne $Battery

# --- SUMMARY LOGIC ---
$Summary = "[OK] System Status"
$StatusColor = "Green"

if ($TotalCpuVal -gt 85) { $Summary = "[CRITICAL] CPU Load"; $StatusColor = "Red" }
elseif ($TotalCpuVal -gt 60) { $Summary = "[HIGH] CPU Load"; $StatusColor = "Yellow" }
elseif ($RamPct -gt 95) { $Summary = "[CRITICAL] RAM Usage"; $StatusColor = "Red" }
elseif ($RamPct -gt 85) { $Summary = "[HIGH] RAM Usage"; $StatusColor = "Yellow" }
elseif ($DiskPct -gt 90) { $Summary = "[CRITICAL] Disk Space Low"; $StatusColor = "Red" }

# --- OUTPUT ---
Write-Host "`n$Summary | Status as of $Timestamp" -ForegroundColor $StatusColor

Write-Host "`n--- DISK STORAGE ---" -ForegroundColor Cyan
if ($DriveC) {
    Write-Host "Available: $($FreeDiskGB)GB / $($TotalDiskGB)GB ($DiskPct% used)"
} else {
    Write-Host "Error: Could not retrieve Disk information."
}

Write-Host "`n--- CPU USAGE ---" -ForegroundColor Cyan
Write-Host "Overall CPU Used: $TotalCpuVal%"
Write-Host "Top 5 CPU Processes:"
foreach ($p in $TopCpuProcs) {
    Write-Host "  - $($p.Name.PadRight(20)) $($p.CPU)%"
}

Write-Host "`n--- RAM USAGE ---" -ForegroundColor Cyan
if ($OS) {
    Write-Host "Available: $($FreeRamGB)GB / $($TotalRamGB)GB ($RamPct% used)"
}
Write-Host "Top 5 RAM Consumers (Private Working Set):"
foreach ($p in $TopRamProcs) {
    Write-Host "  - $($p.Name.PadRight(20)) $($p.RAM)MB"
}

if ($HasBattery) {
    Write-Host "`n--- TOP 5 ENERGY IMPACT (Estimated) ---" -ForegroundColor Cyan
    foreach ($p in $TopCpuProcs) {
        $Impact = "LOW"
        $ImpactColor = "Green"
        if ($p.CPU -gt 50) { $Impact = "HIGH"; $ImpactColor = "Red" }
        elseif ($p.CPU -gt 20) { $Impact = "MODERATE"; $ImpactColor = "Yellow" }
        
        Write-Host "$($p.Name.PadRight(25)) Impact Score: $($p.CPU.ToString().PadRight(5)) " -NoNewline
        Write-Host "$Impact" -ForegroundColor $ImpactColor
    }

    Write-Host "`n--- BATTERY STATUS ---" -ForegroundColor Cyan
    $Status = switch ($Battery.BatteryStatus) {
        1 { "Discharging" }
        2 { "On AC Power" }
        3 { "Fully Charged" }
        4 { "Low" }
        5 { "Critical" }
        6 { "Charging" }
        7 { "Charging and High" }
        8 { "Charging and Low" }
        9 { "Charging and Critical" }
        default { "Unknown" }
    }
    Write-Host "Battery Level: $($Battery.EstimatedChargeRemaining)%"
    Write-Host "Status       : $Status"
    if ($Battery.EstimatedRunTime -and $Battery.EstimatedRunTime -ne 71582788) {
        $Hours = [Math]::Floor($Battery.EstimatedRunTime / 60)
        $Mins = $Battery.EstimatedRunTime % 60
        Write-Host "Remaining    : $($Hours)h:$($Mins)m"
    }
} else {
    Write-Host "`n--- POWER STATUS ---" -ForegroundColor Cyan
    Write-Host "Desktop PC / AC Power detected (No battery found)."
}
Write-Host ""
