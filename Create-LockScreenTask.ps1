# Create-LockScreenTask.ps1
# Creates a per-user scheduled task that locks the workstation 1 minute after logon.

$TaskName        = 'AutoLockScreen'
$TaskDescription = 'Automatically locks the screen 1 minute after user logon.'
$DelaySeconds    = 60

# Build current user in DOMAIN\User format (works for local accounts too)
$CurrentUser = "$env:USERDOMAIN\$env:USERNAME"

# If a previous task exists under this name, remove it to avoid XML/principal conflicts
try {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
} catch { }

# Action: wait 60s then lock workstation
$lockCmd = "Start-Sleep -Seconds $DelaySeconds; rundll32.exe user32.dll,LockWorkStation"
$Action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"$lockCmd`""

# Trigger: at logon of the current user (reliable principal context)
$Trigger   = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser

# Principal: run in the interactive context of the current user
$Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Limited

# Settings (keep things simple and reliable)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
             -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew

# Create and register the task
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description $TaskDescription
Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force | Out-Null

Write-Host "Scheduled task '$TaskName' created for user '$CurrentUser'. It will lock the workstation $DelaySeconds seconds after logon."
