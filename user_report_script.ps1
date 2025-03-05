## ===========================================================================
## NAME:        LogLoggedInUsers.ps1 
## CREATED:     05-MAR-2025
## BY:          DAVID RADOICIC
## VERSION:     1.0
## DESCRIPTION: Checks the Windows system for logged in users and sends an email.
##
##
## NOTE:
## The script first determines the current Central Time timestamp and configures the timezone.
## Script calls query user to list all logged-in users; this command returns all active user sessions on the system​. 
## It then parses the output to extract usernames and joins them into a single comma-separated string.
## It composes an email using the Outlook COM interface and then sends the email.


# Timezone configuration: Convert current time to Central Time (CT)
try {
    $CTzone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time")
} catch {
    Write-Error "Central Timezone not found on system."
    $CTzone = $null
}
if ($CTzone) {
    $timestamp = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $CTzone)
    $timestampStr = $timestamp.ToString("yyyy-MM-dd HH:mm:ss")
    $tzLabel = "(Central Time)"
} else {
    # Fallback to local time if CT zone not available
    $timestampStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $tzLabel = "(Local Time)"
}

# Get all logged-in users using 'query user' (fallback to query session if needed)
$rawOutput = try { (query user) } catch { (query session) }  # query session is similar alias
$usersList = "None"
if ($rawOutput) {
    $lines = $rawOutput | Select-Object -Skip 1    # skip header line
    $loggedOnUsers = @()
    foreach ($line in $lines) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            # Remove any leading '>' indicator and trim whitespace
            $clean = $line.TrimStart('>').Trim()
            # 'query user' output columns are separated by whitespace; first token is username
            $username = $clean -split '\s+' | Select-Object -First 1
            $loggedOnUsers += $username
        }
    }
    if ($loggedOnUsers.Count -gt 0) {
        $usersList = ($loggedOnUsers | Sort-Object -Unique) -join ', '
    }
}

# Prepare the log message line
$logLine = "$($timestampStr) $tzLabel - Logged-in users: $usersList"

# Try to send email via Outlook (if available)
$sent = $false
try {
    $Outlook = New-Object -ComObject Outlook.Application
    $Mail = $Outlook.CreateItem(0)
    $Mail.To = "Your Email Here"               # recipient email
    $Mail.Subject = "Logged-in Users Report ($($timestampStr) CT)"
    $Mail.Body = $logLine
    $Mail.Send()                                    # send email
    $sent = $true
} catch {
    # Could not send email (Outlook not installed or other issue)
    $sent = $false
}

# If email not sent, write to a log file
if (-not $sent) {
    $logFile = "C:\Logs\LoggedInUsers.log"          # path to log file
    # Ensure directory exists
    $dir = Split-Path $logFile -Parent
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null }
    Add-Content -Path $logFile -Value $logLine
}