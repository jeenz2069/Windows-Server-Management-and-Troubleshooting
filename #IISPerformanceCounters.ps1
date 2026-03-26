#IISPerformanceCounters.ps1
<#
.SYNOPSIS
Creates a targeted PerfMon Data Collector Set for a selected IIS Application Pool.

.DESCRIPTION
This script:
1. Enumerates all IIS Application Pools
2. Prompts the user to select one via a numbered list
3. Resolves the associated w3wp process instance(s)
4. Creates and starts a Data Collector Set with relevant IIS, ASP.NET, HTTP.sys, and system counters

PERMISSIONS REQUIRED
- Must be run as Administrator
- User must be a member of:
  - Local Administrators group
  - OR Performance Log Users group (for logman), but Admin is strongly recommended
- IIS Management components must be installed (WebAdministration module)

NOTES
- If the selected App Pool is not currently running, w3wp counters will not be added
- Script handles multiple worker processes (web garden scenarios)
#>

# CONFIGURATION
$setName = "IIS_Targeted_Capture"
$logPath = "C:\PerfLogs\IIS_Targeted"
$sampleInterval = "00:00:05"
$maxSizeMB = 500
# endregion

# Ensure log directory exists
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory | Out-Null
}

# Import IIS module
Import-Module WebAdministration

# region ENUMERATE APPLICATION POOLS
$appPools = Get-ChildItem IIS:\AppPools | Select-Object -ExpandProperty Name

if (-not $appPools) {
    Write-Host "No Application Pools found."
    exit
}

Write-Host "`nAvailable Application Pools:`n"

for ($i = 0; $i -lt $appPools.Count; $i++) {
    Write-Host "[$($i+1)] $($appPools[$i])"
}

# endregion

# region USER SELECTION
$selection = Read-Host "`nEnter the number of the Application Pool to monitor"

if (-not ($selection -as [int]) -or $selection -lt 1 -or $selection -gt $appPools.Count) {
    Write-Host "Invalid selection."
    exit
}

$appPool = $appPools[$selection - 1]
Write-Host "`nSelected Application Pool: $appPool"
# endregion

# region RESOLVE W3WP INSTANCES
$w3wpProcesses = Get-WmiObject Win32_Process | Where-Object {
    $_.Name -eq "w3wp.exe" -and $_.CommandLine -match $appPool
}

$procInstances = @()

if ($w3wpProcesses) {
    $pidMap = (Get-Counter '\Process(*)\ID Process').CounterSamples

    foreach ($proc in $w3wpProcesses) {
        $instance = $pidMap | Where-Object { $_.CookedValue -eq $proc.ProcessId } |
            Select-Object -ExpandProperty InstanceName

        if ($instance) {
            $procInstances += $instance
        }
    }
}

# endregion

# region BUILD COUNTER LIST

$counters = @()

# --- IIS Web Service Counters ---
$counters += "\Web Service(_Total)\Current Connections"
$counters += "\Web Service(_Total)\Total Method Requests/sec"
$counters += "\Web Service(_Total)\Get Requests/sec"
$counters += "\Web Service(_Total)\Post Requests/sec"
$counters += "\Web Service(_Total)\Bytes Sent/sec"
$counters += "\Web Service(_Total)\Bytes Received/sec"

# --- ASP.NET Application Counters ---
$counters += "\ASP.NET Applications($appPool)\Requests/Sec"
$counters += "\ASP.NET Applications($appPool)\Requests Executing"
$counters += "\ASP.NET Applications($appPool)\Requests Queued"
$counters += "\ASP.NET Applications($appPool)\Request Wait Time"
$counters += "\ASP.NET Applications($appPool)\Request Execution Time"

# --- HTTP.sys Request Queue ---
$counters += "\HTTP Service Request Queues($appPool)\CurrentQueueSize"
$counters += "\HTTP Service Request Queues($appPool)\RequestsQueued"
$counters += "\HTTP Service Request Queues($appPool)\RejectedRequests"

# --- Application Pool State ---
$counters += "\APP_POOL_WAS($appPool)\Current Application Pool State"
$counters += "\APP_POOL_WAS($appPool)\Current Worker Processes"

# --- Worker Process Counters (per w3wp instance) ---
foreach ($instance in $procInstances) {
    $counters += "\Process($instance)\% Processor Time"
    $counters += "\Process($instance)\Private Bytes"
    $counters += "\Process($instance)\Working Set"
    $counters += "\W3SVC_W3WP($instance)\Active Requests"
    $counters += "\W3SVC_W3WP($instance)\Requests/Sec"
}

# --- System Counters ---
$counters += "\Processor(_Total)\% Processor Time"
$counters += "\Processor(_Total)\% Privileged Time"

$counters += "\Memory\Available MBytes"
$counters += "\Memory\Committed Bytes"
$counters += "\Memory\% Committed Bytes In Use"
$counters += "\Memory\Pages/sec"

# endregion

# region CREATE DATA COLLECTOR SET

# Remove existing set if present
logman delete $setName -ets 2>$null

# Write counters to temp file (logman requirement for large sets)
$tempFile = "$env:TEMP\counters.txt"
$counters | Out-File -FilePath $tempFile -Encoding ascii

# Create the Data Collation Set
logman create counter $setName `
    -cf $tempFile `
    -si $sampleInterval `
    -o "$logPath\$setName" `
    -f bincirc `
    -max $maxSizeMB

# Start it
logman start $setName

# endregion

Write-Host "`nData Collector Set '$setName' started successfully."
Write-Host "Log location: $logPath"
