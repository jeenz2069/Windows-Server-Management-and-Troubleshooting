# DiskUsageAlertReport.ps1

# Set the usage threshold percentage
$Threshold = 85

# Email (Gmail) SMTP Settings
$SMTPServer = "smtp.gmail.com"
$SMTPPort = 587
$Username = "<USERNAME>"
$Password = "<GOOGLEAPPPASSWORD>"  # Use your Google App Password
$To = "<EMAIL>"
$From = "<EMAIL>"

# Define flag file paths (using TEMP directory)
$alertFlagFile = "$env:TEMP\DiskAlertFlag.txt"
$tuesdayFlagFile = "$env:TEMP\TuesdayReportFlag.txt"

$currentDate = Get-Date
$isTuesdayReport = ($currentDate.DayOfWeek -eq "Tuesday" -and $currentDate.Hour -eq 8)

# Get current machine hostname for report title
$hostname = hostname

# Get all fixed drives (DriveType 3) using WMI
$Disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"

# Prepare report rows and check if any drive exceeds threshold
$alertTriggered = $false
$rows = ""

foreach ($Disk in $Disks) {
    $DriveLetter = $Disk.DeviceID
    $FreeSpace = [double]$Disk.FreeSpace
    $TotalSpace = [double]$Disk.Size
    if ($TotalSpace -gt 0) {
        $UsedSpace = $TotalSpace - $FreeSpace
        $UsedPercentage = [math]::Round(($UsedSpace / $TotalSpace * 100), 2)
    } else {
        $UsedPercentage = 0
    }
    # Convert sizes to GB
    $TotalGB = [math]::Round($TotalSpace / 1GB, 2)
    $FreeGB = [math]::Round($FreeSpace / 1GB, 2)

    # Determine row class based on usage threshold
    if ($UsedPercentage -ge $Threshold) {
        $rowClass = "alert"
        $alertTriggered = $true
    } else {
        $rowClass = "normal"
    }
    
    $rows += "<tr class='$rowClass'><td>$DriveLetter</td><td>$TotalGB</td><td>$FreeGB</td><td>$UsedPercentage%</td></tr>`n"
}

# Generate HTML email body with inline CSS styles
$htmlBody = @"
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; }
    h2 { color: #333; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }
    th { background-color: #f2f2f2; }
    .alert { background-color: #f8d7da; color: #721c24; }
    .normal { background-color: #d4edda; color: #155724; }
  </style>
</head>
<body>
  <h2>Disk Usage Report for $hostname</h2>
  <p>This is an automated disk usage report generated on $($currentDate).</p>
  <table>
    <tr>
      <th>Drive</th>
      <th>Total Space (GB)</th>
      <th>Free Space (GB)</th>
      <th>Used (%)</th>
    </tr>
    $rows
  </table>
"@

# Add alert message if any drive exceeds the threshold
if ($alertTriggered) {
    $htmlBody += "<p style='color:#721c24; font-weight:bold;'>Warning: One or more drives have exceeded $Threshold% usage.</p>"
} else {
    $htmlBody += "<p style='color:#155724;'>All drives are below $Threshold% usage.</p>"
}

$htmlBody += "</body></html>"

# Function to send email
function Send-Email {
    param (
        [string]$Subject,
        [string]$Body
    )
    $SMTPClient = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
    
    $MailMessage = New-Object System.Net.Mail.MailMessage
    $MailMessage.From = $From
    $MailMessage.To.Add($To)
    $MailMessage.Subject = $Subject
    $MailMessage.Body = $Body
    $MailMessage.IsBodyHtml = $true
    
    $SMTPClient.Send($MailMessage)
}

# Determine whether to send the email
$sendEmail = $false
$subject = ""

if ($isTuesdayReport) {
    # Tuesday report: send email once on Tuesday at 8am regardless of usage.
    $todayStr = $currentDate.ToString("yyyy-MM-dd")
    $tuesdaySent = $false
    if (Test-Path $tuesdayFlagFile) {
        $lastTuesday = Get-Content $tuesdayFlagFile
        if ($lastTuesday -eq $todayStr) {
            $tuesdaySent = $true
        }
    }
    if (-not $tuesdaySent) {
        $sendEmail = $true
        $subject = "Weekly Disk Usage Report - $todayStr"
        # Update Tuesday flag file with today's date
        $todayStr | Out-File $tuesdayFlagFile -Encoding ascii
    }
} elseif ($alertTriggered) {
    # For alert condition (non-Tuesday), send email only if the flag file doesn't exist
    if (-not (Test-Path $alertFlagFile)) {
        $sendEmail = $true
        $subject = "Disk Space Alert - One or More Drives Exceed $Threshold% Usage"
        # Create flag file to prevent repeated alerts
        "AlertSent" | Out-File $alertFlagFile -Encoding ascii
    }
} else {
    # If no alert condition exists, remove the alert flag file to allow future alerts
    if (Test-Path $alertFlagFile) {
        Remove-Item $alertFlagFile
    }
}

# Send email if determined
if ($sendEmail) {
    Send-Email -Subject $subject -Body $htmlBody
}
