<#
.SYNOPSIS
    Enhanced disk health check and analysis with detailed reporting.

.DESCRIPTION
    This optimized module performs comprehensive disk health analysis including:
    - SMART data analysis
    - Disk performance metrics
    - Space utilization
    - File system health
    - Multiple drive support
    - Detailed HTML reporting

.PARAMETER RepairMode
    Enables repair mode to automatically fix found errors.

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER TargetDrives
    Array of specific drive letters to check. If omitted, checks all drives.

.PARAMETER GenerateReport
    Generates a detailed HTML report of findings.

.PARAMETER SkipSMART
    Skips SMART data analysis for faster execution.

.EXAMPLE
    Invoke-DiskCheck
    Performs a basic disk check on all drives.

.EXAMPLE
    Invoke-DiskCheck -RepairMode -VerboseOutput -TargetDrives "C:", "D:" -GenerateReport
    Performs detailed analysis on C: and D: drives with repair mode and generates HTML report.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables repair mode.")]
        [switch]$RepairMode,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose console output.")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Specific drives to check")]
        [string[]]$TargetDrives,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Generate HTML report")]
        [switch]$GenerateReport,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Skip SMART analysis")]
        [switch]$SkipSMART
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

        # Initialize log file in module directory
        $LogFile = Join-Path $ModuleDir "DiskCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $ReportFile = Join-Path $ModuleDir "DiskCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        function Get-SMARTData {
            param([string]$DriveLetter)
            try {
                $diskNumber = (Get-Partition -DriveLetter $DriveLetter[0]).DiskNumber
                $smartData = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction Stop |
                    Where-Object { $_.InstanceName -match "PHYSICALDRIVE$diskNumber$" }
                return $smartData
            }
            catch {
                Write-Log "Unable to retrieve SMART data for drive $DriveLetter`: $_"
                return $null
            }
        }

        function Get-DiskPerformanceMetrics {
            param([string]$DriveLetter)
            try {
                $counter = Get-Counter -Counter "\PhysicalDisk(*)\Disk Reads/sec", "\PhysicalDisk(*)\Disk Writes/sec" -ErrorAction Stop
                return $counter
            }
            catch {
                Write-Log "Unable to retrieve performance metrics for drive $DriveLetter`: $_"
                return $null
            }
        }

        function Get-DiskSpaceAnalysis {
            param([string]$DriveLetter)
            try {
                $drive = Get-PSDrive -Name $DriveLetter[0] -ErrorAction Stop
                return @{
                    TotalSize = $drive.Free + $drive.Used
                    FreeSpace = $drive.Free
                    UsedSpace = $drive.Used
                    PercentFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 2)
                }
            }
            catch {
                Write-Log "Unable to analyze disk space for drive $DriveLetter`: $_"
                return $null
            }
        }

        function Invoke-ChkDsk {
            param(
                [string]$DriveLetter,
                [switch]$Repair
            )
            try {
                $ChkdskPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\chkdsk.exe"
                if (-not (Test-Path $ChkdskPath)) {
                    throw "chkdsk.exe not found"
                }

                $arguments = "$DriveLetter /scan"
                if ($Repair) {
                    $arguments += " /f /r"
                }

                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processInfo.FileName = $ChkdskPath
                $processInfo.Arguments = $arguments
                $processInfo.Verb = "runas"
                $processInfo.UseShellExecute = $true
                $processInfo.RedirectStandardOutput = $false

                $process = [System.Diagnostics.Process]::Start($processInfo)
                $process.WaitForExit()

                return @{
                    ExitCode = $process.ExitCode
                    Success = $process.ExitCode -eq 0
                }
            }
            catch {
                Write-Log "Error running chkdsk on drive $DriveLetter`: $_"
                return @{
                    ExitCode = -1
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }

        function New-HTMLReport {
            param([hashtable]$Results)
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Disk Check Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .drive { margin: 20px 0; border: 1px solid #ddd; padding: 10px; }
        .warning { color: orange; }
        .error { color: red; }
        .success { color: green; }
        .metric { margin: 10px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f0f0f0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Disk Check Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
    </div>
"@
            foreach ($drive in $Results.GetEnumerator()) {
                $html += @"
    <div class="drive">
        <h2>Drive $($drive.Key)</h2>
        <div class="metric">
            <h3>Disk Space</h3>
            <table>
                <tr><th>Total Size</th><td>$([math]::Round($drive.Value.Space.TotalSize/1GB, 2)) GB</td></tr>
                <tr><th>Free Space</th><td>$([math]::Round($drive.Value.Space.FreeSpace/1GB, 2)) GB</td></tr>
                <tr><th>Used Space</th><td>$([math]::Round($drive.Value.Space.UsedSpace/1GB, 2)) GB</td></tr>
                <tr><th>Percent Free</th><td>$($drive.Value.Space.PercentFree)%</td></tr>
            </table>
        </div>
"@
                if ($drive.Value.SMART) {
                    $html += @"
        <div class="metric">
            <h3>SMART Status</h3>
            <p class="$($drive.Value.SMART.PredictFailure ? 'error' : 'success')">
                Prediction Status: $($drive.Value.SMART.PredictFailure ? 'Warning' : 'Healthy')
            </p>
        </div>
"@
                }

                if ($drive.Value.ChkDsk) {
                    $html += @"
        <div class="metric">
            <h3>CHKDSK Results</h3>
            <p class="$($drive.Value.ChkDsk.Success ? 'success' : 'error')">
                Status: $($drive.Value.ChkDsk.Success ? 'Passed' : 'Failed')
            </p>
        </div>
"@
                }
                $html += "</div>"
            }
            $html += "</body></html>"
            $html | Out-File -FilePath $ReportFile -Encoding UTF8
        }
    }

    process {
        try {
            Write-Log "Starting enhanced disk check..."
            
            # Get all drives if none specified
            if (-not $TargetDrives) {
                $TargetDrives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name | ForEach-Object { "$_`:" }
            }

            $results = @{}

            foreach ($drive in $TargetDrives) {
                Write-Log "Analyzing drive $drive..."
                $driveResults = @{}

                # Get disk space analysis
                Write-Log "Getting disk space analysis for $drive..."
                $driveResults.Space = Get-DiskSpaceAnalysis -DriveLetter $drive

                # Get SMART data if enabled
                if (-not $SkipSMART) {
                    Write-Log "Getting SMART data for $drive..."
                    $driveResults.SMART = Get-SMARTData -DriveLetter $drive
                }

                # Get performance metrics
                Write-Log "Getting performance metrics for $drive..."
                $driveResults.Performance = Get-DiskPerformanceMetrics -DriveLetter $drive

                # Run chkdsk if repair mode enabled
                if ($RepairMode) {
                    Write-Log "Running chkdsk on $drive..."
                    $driveResults.ChkDsk = Invoke-ChkDsk -DriveLetter $drive -Repair
                }

                $results[$drive] = $driveResults
            }

            # Generate HTML report if requested
            if ($GenerateReport) {
                Write-Log "Generating HTML report..."
                New-HTMLReport -Results $results
                Write-Host "HTML report generated at: $ReportFile"
            }

            # Output summary
            foreach ($drive in $results.GetEnumerator()) {
                $summary = @"
Drive $($drive.Key) Summary:
-------------------------
Space: $([math]::Round($drive.Value.Space.FreeSpace/1GB, 2))GB free of $([math]::Round($drive.Value.Space.TotalSize/1GB, 2))GB
Health: $(if($drive.Value.SMART){"SMART Status: $($drive.Value.SMART.PredictFailure ? 'Warning' : 'Healthy')"} else {"SMART data not available"})
"@
                Write-Host $summary
                Write-Log $summary
            }
        }
        catch {
            $errorMessage = "Critical error during disk check: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        $summary = "Disk check completed. Log file: $LogFile"
        if ($GenerateReport) {
            $summary += "`nReport file: $ReportFile"
        }
        Write-Log $summary
        Write-Host $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-DiskCheck
