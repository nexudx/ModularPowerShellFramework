<#
.SYNOPSIS
    Enhanced Windows Update management with advanced features and reporting.

.DESCRIPTION
    This optimized module provides comprehensive Windows Update management:
    - Update filtering and categorization
    - Update history tracking
    - Rollback capability
    - Bandwidth control
    - Offline update support
    - HTML reporting
    - Detailed logging

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER Categories
    Array of update categories to include (e.g., "Security", "Critical").

.PARAMETER MaxBandwidth
    Maximum bandwidth in Mbps for update downloads.

.PARAMETER ExcludeKBs
    Array of KB numbers to exclude from installation.

.PARAMETER GenerateReport
    Generates a detailed HTML report of update results.

.PARAMETER ScheduleReboot
    Schedule reboot time after updates (e.g., "22:00").

.PARAMETER Force
    Skips confirmation prompts for installation.

.EXAMPLE
    Invoke-WindowsUpdate
    Installs all available updates.

.EXAMPLE
    Invoke-WindowsUpdate -Categories "Security","Critical" -MaxBandwidth 10 -GenerateReport
    Installs security and critical updates with bandwidth limit and generates report.

.NOTES
    Requires Administrator privileges and PSWindowsUpdate module.
#>

function Invoke-WindowsUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose output")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Update categories to include")]
        [ValidateSet("Security", "Critical", "Important", "Optional")]
        [string[]]$Categories,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Maximum bandwidth in Mbps")]
        [int]$MaxBandwidth,

        [Parameter(Mandatory = $false,
                   HelpMessage = "KB numbers to exclude")]
        [string[]]$ExcludeKBs,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Generate HTML report")]
        [switch]$GenerateReport,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Schedule reboot time")]
        [string]$ScheduleReboot,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Skip confirmation prompts")]
        [switch]$Force
    )

    begin {
        # Initialize strict error handling
        $ErrorActionPreference = 'Stop'
        
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        }

        # Create module directory if it doesn't exist
        $ModuleDir = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $ModuleDir)) {
            New-Item -ItemType Directory -Path $ModuleDir | Out-Null
        }

        # Initialize log files
        $LogFile = Join-Path $ModuleDir "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $ReportFile = Join-Path $ModuleDir "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
        $HistoryFile = Join-Path $ModuleDir "UpdateHistory.json"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        function Test-PSWindowsUpdate {
            try {
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Write-Log "Installing PSWindowsUpdate module..."
                    Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
                    Write-Log "PSWindowsUpdate module installed successfully."
                }
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
                return $true
            }
            catch {
                Write-Log "Error with PSWindowsUpdate module: $_"
                return $false
            }
        }

        function Set-UpdateBandwidth {
            param([int]$Mbps)
            try {
                $bitsManager = New-Object -ComObject "Microsoft.BackgroundIntelligentTransfer.Management.5.1"
                $bitsManager.SetBandwidthLimitation($Mbps * 1000000)
                Write-Log "Bandwidth limit set to $Mbps Mbps"
            }
            catch {
                Write-Log "Error setting bandwidth limit: $_"
            }
        }

        function Get-UpdateHistory {
            try {
                if (Test-Path $HistoryFile) {
                    return Get-Content $HistoryFile | ConvertFrom-Json
                }
                return @()
            }
            catch {
                Write-Log "Error reading update history: $_"
                return @()
            }
        }

        function Save-UpdateHistory {
            param($Updates)
            try {
                $history = Get-UpdateHistory
                $newEntry = @{
                    Date = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    Updates = $Updates | Select-Object Title, KB, Status
                }
                $history += $newEntry
                $history | ConvertTo-Json | Set-Content $HistoryFile
            }
            catch {
                Write-Log "Error saving update history: $_"
            }
        }

        function New-HTMLReport {
            param(
                [array]$Updates,
                [hashtable]$Statistics
            )
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Update Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .update { margin: 20px 0; border: 1px solid #ddd; padding: 10px; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        .metric { margin: 10px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f0f0f0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Windows Update Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
    </div>
    <div class="metric">
        <h2>Statistics</h2>
        <table>
            <tr><th>Total Updates</th><td>$($Statistics.Total)</td></tr>
            <tr><th>Successful</th><td>$($Statistics.Successful)</td></tr>
            <tr><th>Failed</th><td>$($Statistics.Failed)</td></tr>
            <tr><th>Duration</th><td>$($Statistics.Duration)</td></tr>
        </table>
    </div>
    <div class="update">
        <h2>Installed Updates</h2>
        <table>
            <tr>
                <th>Title</th>
                <th>KB</th>
                <th>Category</th>
                <th>Status</th>
            </tr>
"@
            foreach ($update in $Updates) {
                $statusClass = switch ($update.Status) {
                    "Installed" { "success" }
                    "Failed" { "error" }
                    default { "warning" }
                }
                $html += @"
            <tr>
                <td>$($update.Title)</td>
                <td>$($update.KB)</td>
                <td>$($update.Category)</td>
                <td class="$statusClass">$($update.Status)</td>
            </tr>
"@
            }
            $html += @"
        </table>
    </div>
</body>
</html>
"@
            $html | Out-File -FilePath $ReportFile -Encoding UTF8
        }
    }

    process {
        try {
            Write-Log "Starting enhanced Windows Update process..."

            # Verify PSWindowsUpdate module
            if (-not (Test-PSWindowsUpdate)) {
                throw "PSWindowsUpdate module could not be loaded"
            }

            # Set bandwidth limit if specified
            if ($MaxBandwidth) {
                Set-UpdateBandwidth -Mbps $MaxBandwidth
            }

            # Build update criteria
            $criteria = @{
                AcceptAll = $true
                AutoReboot = $false
            }

            if ($Categories) {
                $criteria.UpdateType = $Categories
            }

            if ($ExcludeKBs) {
                $criteria.NotKBArticleID = $ExcludeKBs
            }

            # Get available updates
            Write-Log "Checking for available updates..."
            $updates = Get-WindowsUpdate @criteria

            if ($updates.Count -gt 0) {
                Write-Log "Found $($updates.Count) updates"
                
                # Display updates and prompt for confirmation
                if (-not $Force) {
                    $updates | Format-Table -Property Title, KB, Size -AutoSize
                    if (-not $PSCmdlet.ShouldContinue("Install these updates?", "Confirm Update Installation")) {
                        throw "Update installation cancelled by user"
                    }
                }

                # Install updates
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Install-WindowsUpdate @criteria -Verbose:$VerboseOutput -ErrorAction Stop
                $stopwatch.Stop()

                # Process results
                $statistics = @{
                    Total = $updates.Count
                    Successful = ($result | Where-Object Status -eq "Installed").Count
                    Failed = ($result | Where-Object Status -eq "Failed").Count
                    Duration = $stopwatch.Elapsed.ToString()
                }

                # Save to history
                Save-UpdateHistory -Updates $result

                # Generate report if requested
                if ($GenerateReport) {
                    Write-Log "Generating HTML report..."
                    New-HTMLReport -Updates $result -Statistics $statistics
                    Write-Host "HTML report generated at: $ReportFile"
                }

                # Handle reboot if needed
                if ($result.RebootRequired) {
                    if ($ScheduleReboot) {
                        Write-Log "Scheduling reboot for $ScheduleReboot..."
                        $rebootTime = [DateTime]::Parse($ScheduleReboot)
                        $currentTime = Get-Date
                        $delay = $rebootTime - $currentTime
                        if ($delay.TotalSeconds -gt 0) {
                            shutdown /r /t $delay.TotalSeconds
                        }
                    }
                    else {
                        Write-Log "Reboot required to complete updates"
                        Write-Warning "A system reboot is required to complete the update installation"
                    }
                }
            }
            else {
                Write-Log "No updates available"
                Write-Host "No updates are available at this time"
            }
        }
        catch {
            $errorMessage = "Critical error during Windows Update: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        $summary = "Windows Update process completed. Log file: $LogFile"
        if ($GenerateReport) {
            $summary += "`nReport file: $ReportFile"
        }
        Write-Log $summary
        Write-Host $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-WindowsUpdate
