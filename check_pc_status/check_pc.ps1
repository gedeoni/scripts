# PowerShell System Health Monitor (check_pc.ps1)
# High-signal diagnostic script for Windows.

# --- DATA GATHERING ---
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# 1. Disk Storage (All Fixed Disks)
$Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
$DiskData = foreach ($Disk in $Disks) {
    $TotalGB = [Math]::Round($Disk.Size / 1GB, 1)
    $FreeGB = [Math]::Round($Disk.FreeSpace / 1GB, 1)
    $UsedGB = [Math]::Round($TotalGB - $FreeGB, 1)
    $PctUsed = if ($TotalGB -gt 0) { [Math]::Round(($UsedGB / $TotalGB) * 100) } else { 0 }
    [PSCustomObject]@{
        Drive = $Disk.DeviceID
        Free  = $FreeGB
        Total = $TotalGB
        Pct   = $PctUsed
    }
}

# 2. CPU Usage
$CpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
$TotalCpuVal = if ($CpuCounter) { [Math]::Round($CpuCounter.CounterSamples[0].CookedValue) } else { 0 }

# Get Top 5 CPU Processes using CIM for formatted percentage
$TopCpuProcs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -notmatch '^_Total$|^Idle$' } | 
    Sort-Object PercentProcessorTime -Descending | 
    Select-Object -First 5 | 
    Select-Object @{Name='Name';Expression={$_.Name}}, @{Name='CPU';Expression={$_.PercentProcessorTime}}

# 3. RAM Usage
$OS = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
if ($OS) {
    $TotalRamGB = [Math]::Round($OS.TotalVisibleMemorySize / 1MB, 1)
    $FreeRamGB = [Math]::Round($OS.FreePhysicalMemory / 1MB, 1)
    $UsedRamGB = [Math]::Round($TotalRamGB - $FreeRamGB, 1)
    $RamPct = [Math]::Round(($UsedRamGB / $TotalRamGB) * 100)
}
# Using PrivateMemorySize64 for Private Memory usage
$TopRamProcs = Get-Process | Sort-Object PrivateMemorySize64 -Descending | Select-Object -First 5 | 
    Select-Object Name, @{Name='RAM';Expression={[Math]::Round($_.PrivateMemorySize64 / 1MB, 1)}}

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
elseif (($DiskData | Where-Object { $_.Pct -gt 90 }).Count -gt 0) { $Summary = "[CRITICAL] Disk Space Low"; $StatusColor = "Red" }

# --- OUTPUT ---
Write-Host "`n$Summary | Status as of $Timestamp" -ForegroundColor $StatusColor

Write-Host "`n--- DISK STORAGE ---" -ForegroundColor Cyan
if ($DiskData) {
    foreach ($d in $DiskData) {
        Write-Host "Drive $($d.Drive): Available: $($d.Free)GB / $($d.Total)GB ($($d.Pct)% used)"
    }
} else {
    Write-Host "Error: Could not retrieve Disk information."
}

Write-Host "`n--- CPU USAGE ---" -ForegroundColor Cyan
Write-Host "Overall CPU Used: $TotalCpuVal%"
Write-Host "Top 5 CPU Processes:"
foreach ($p in $TopCpuProcs) {
    Write-Host "  - $($p.Name.PadRight(25)) $($p.CPU)%"
}

Write-Host "`n--- RAM USAGE ---" -ForegroundColor Cyan
if ($OS) {
    Write-Host "Available: $($FreeRamGB)GB / $($TotalRamGB)GB ($RamPct% used)"
}
Write-Host "Top 5 RAM Consumers (Private Memory):"
foreach ($p in $TopRamProcs) {
    Write-Host "  - $($p.Name.PadRight(25)) $($p.RAM)MB"
}

if ($HasBattery) {
    Write-Host "`n--- TOP 5 ENERGY IMPACT (Estimated) ---" -ForegroundColor Cyan
    foreach ($p in $TopCpuProcs) {
        $Impact = "LOW"
        $ImpactColor = "Green"
        if ($p.CPU -gt 50) { $Impact = "HIGH"; $ImpactColor = "Red" }
        elseif ($p.CPU -gt 20) { $Impact = "MODERATE"; $ImpactColor = "Yellow" }
        
        Write-Host "  - $($p.Name.PadRight(25)) Impact Score: $($p.CPU.ToString().PadRight(5)) " -NoNewline
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
