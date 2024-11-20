<#
.SYNOPSIS
    Enhanced disk cleanup with customizable targets and detailed reporting.

.DESCRIPTION
    This optimized module performs comprehensive disk cleanup including:
    - Windows built-in cleanup (cleanmgr)
    - Custom cleanup targets
    - Multiple drive support
    - Space usage reporting
    - Configurable cleanup rules
    - Detailed HTML reporting

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER TargetDrives
    Array of specific drive letters to clean. If omitted, cleans system drive.

.PARAMETER Categories
    Specific cleanup categories to target. Available options:
    - Windows (Windows built-in cleanup)
    - Downloads (Downloads folder)
    - Temp (Temporary files)
    - Recycle (Recycle bin)
    - Updates (Windows update cleanup)
    If omitted, all categories are processed.

.PARAMETER GenerateReport
    Generates a detailed HTML report of cleanup results.

.PARAMETER Force
    Skips all confirmation prompts for deletions.

.EXAMPLE
    Invoke-DiskCleanup
    Performs basic cleanup on system drive.

.EXAMPLE
    Invoke-DiskCleanup -TargetDrives "C:", "D:" -Categories "Downloads", "Temp" -GenerateReport -Force
    Cleans downloads and temp files on C: and D: drives with HTML report, no confirmations.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-DiskCleanup {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false)]
        [string[]]$TargetDrives,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Windows", "Downloads", "Temp", "Recycle", "Updates")]
        [string[]]$Categories,

        [Parameter(Mandatory = $false)]
        [switch]$GenerateReport,

        [Parameter(Mandatory = $false)]
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
        $LogFile = Join-Path $ModuleDir "DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $ReportFile = Join-Path $ModuleDir "DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        function Get-DriveSpace {
            param([string]$DriveLetter)
            try {
                $drive = Get-PSDrive -Name $DriveLetter[0] -ErrorAction Stop
                return @{
                    TotalSize = $drive.Free + $drive.Used
                    FreeSpace = $drive.Free
                    UsedSpace = $drive.Used
                }
            }
            catch {
                Write-Log "Unable to get drive space for $DriveLetter`: $_"
                return $null
            }
        }

        function Invoke-WindowsCleanup {
            param([string]$DriveLetter)
            try {
                $CleanMgrPath = Join-Path -Path $env:Windir -ChildPath "System32\cleanmgr.exe"
                if (Test-Path $CleanMgrPath) {
                    Write-Log "Running Windows Cleanup on $DriveLetter..."
                    Start-Process -FilePath $CleanMgrPath -ArgumentList "/sagerun:1 /d $DriveLetter" -Wait -NoNewWindow
                    return $true
                }
                return $false
            }
            catch {
                Write-Log "Error running Windows Cleanup: $_"
                return $false
            }
        }

        function Clear-DownloadsFolder {
            param([string]$DriveLetter)
            try {
                $downloadsPath = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
                if (Test-Path $downloadsPath) {
                    Write-Log "Cleaning Downloads folder..."
                    $items = Get-ChildItem -Path $downloadsPath -Recurse
                    $totalSize = ($items | Measure-Object -Property Length -Sum).Sum
                    # Use Force parameter to skip confirmation
                    Remove-Item -Path "$downloadsPath\*" -Recurse -Force -ErrorAction Stop
                    return $totalSize
                }
                return 0
            }
            catch {
                Write-Log "Error cleaning Downloads folder: $_"
                return 0
            }
        }

        function Clear-TempFolders {
            param([string]$DriveLetter)
            try {
                $paths = @(
                    $env:TEMP,
                    "$env:SystemRoot\Temp",
                    "$env:SystemRoot\Prefetch"
                )
                $totalSize = 0
                foreach ($path in $paths) {
                    if (Test-Path $path) {
                        Write-Log "Cleaning temp folder: $path"
                        $items = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue
                        $totalSize += ($items | Measure-Object -Property Length -Sum).Sum
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                return $totalSize
            }
            catch {
                Write-Log "Error cleaning temp folders: $_"
                return 0
            }
        }

        function Clear-RecycleBin {
            try {
                Write-Log "Clearing Recycle Bin..."
                # Use Force parameter to skip confirmation
                Clear-RecycleBin -Force -ErrorAction Stop
                return $true
            }
            catch {
                Write-Log "Error clearing Recycle Bin: $_"
                return $false
            }
        }

        function Clear-WindowsUpdates {
            try {
                Write-Log "Cleaning Windows Update files..."
                $result = Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -NoNewWindow -PassThru
                return $result.ExitCode -eq 0
            }
            catch {
                Write-Log "Error cleaning Windows Update files: $_"
                return $false
            }
        }

        function New-HTMLReport {
            param([hashtable]$Results)
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Disk Cleanup Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm')</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .drive { margin: 20px 0; border: 1px solid #ddd; padding: 10px; }
        .success { color: green; }
        .error { color: red; }
        .metric { margin: 10px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f0f0f0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Disk Cleanup Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')</p>
    </div>
"@
            foreach ($drive in $Results.GetEnumerator()) {
                $html += @"
    <div class="drive">
        <h2>Drive $($drive.Key)</h2>
        <div class="metric">
            <h3>Space Changes</h3>
            <table>
                <tr><th>Initial Free Space</th><td>$([math]::Round($drive.Value.InitialSpace.FreeSpace/1GB, 2)) GB</td></tr>
                <tr><th>Final Free Space</th><td>$([math]::Round($drive.Value.FinalSpace.FreeSpace/1GB, 2)) GB</td></tr>
                <tr><th>Space Freed</th><td>$([math]::Round(($drive.Value.FinalSpace.FreeSpace - $drive.Value.InitialSpace.FreeSpace)/1GB, 2)) GB</td></tr>
            </table>
        </div>
        <div class="metric">
            <h3>Cleanup Actions</h3>
            <table>
                <tr><th>Category</th><th>Status</th><th>Size Cleaned</th></tr>
"@
                foreach ($action in $drive.Value.Actions.GetEnumerator()) {
                    $html += @"
                <tr>
                    <td>$($action.Key)</td>
                    <td class="$($action.Value.Success ? 'success' : 'error')">$($action.Value.Success ? 'Success' : 'Failed')</td>
                    <td>$([math]::Round($action.Value.SizeCleared/1MB, 2)) MB</td>
                </tr>
"@
                }
                $html += "</table></div></div>"
            }
            $html += "</body></html>"
            $html | Out-File -FilePath $ReportFile -Encoding UTF8
        }
    }

    process {
        try {
            Write-Log "Starting enhanced disk cleanup..."
            
            # Get all drives if none specified
            if (-not $TargetDrives) {
                $TargetDrives = @($env:SystemDrive)
            }

            # Use all categories if none specified
            if (-not $Categories) {
                $Categories = @("Windows", "Downloads", "Temp", "Recycle", "Updates")
            }

            $results = @{}

            foreach ($drive in $TargetDrives) {
                Write-Log "Processing drive $drive..."
                $driveResults = @{
                    InitialSpace = Get-DriveSpace -DriveLetter $drive
                    Actions = @{}
                }

                foreach ($category in $Categories) {
                    Write-Log "Processing category $category..."
                    switch ($category) {
                        "Windows" {
                            $success = Invoke-WindowsCleanup -DriveLetter $drive
                            $driveResults.Actions[$category] = @{
                                Success = $success
                                SizeCleared = 0  # Size unknown for Windows cleanup
                            }
                        }
                        "Downloads" {
                            $sizeCleared = Clear-DownloadsFolder -DriveLetter $drive
                            $driveResults.Actions[$category] = @{
                                Success = $true
                                SizeCleared = $sizeCleared
                            }
                        }
                        "Temp" {
                            $sizeCleared = Clear-TempFolders -DriveLetter $drive
                            $driveResults.Actions[$category] = @{
                                Success = $true
                                SizeCleared = $sizeCleared
                            }
                        }
                        "Recycle" {
                            $success = Clear-RecycleBin
                            $driveResults.Actions[$category] = @{
                                Success = $success
                                SizeCleared = 0  # Size unknown for recycle bin
                            }
                        }
                        "Updates" {
                            $success = Clear-WindowsUpdates
                            $driveResults.Actions[$category] = @{
                                Success = $success
                                SizeCleared = 0  # Size unknown for Windows updates
                            }
                        }
                    }
                }

                $driveResults.FinalSpace = Get-DriveSpace -DriveLetter $drive
                $results[$drive] = $driveResults

                # Output drive summary
                $spaceFreed = $driveResults.FinalSpace.FreeSpace - $driveResults.InitialSpace.FreeSpace
                $summary = @"
Drive $drive Cleanup Summary:
---------------------------
Initial Free Space: $([math]::Round($driveResults.InitialSpace.FreeSpace/1GB, 2))GB
Final Free Space: $([math]::Round($driveResults.FinalSpace.FreeSpace/1GB, 2))GB
Space Freed: $([math]::Round($spaceFreed/1GB, 2))GB
"@
                Write-Host $summary
                Write-Log $summary
            }

            # Generate HTML report if requested
            if ($GenerateReport) {
                Write-Log "Generating HTML report..."
                New-HTMLReport -Results $results
                Write-Host "HTML report generated at: $ReportFile"
            }
        }
        catch {
            $errorMessage = "Critical error during disk cleanup: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        $summary = "Disk cleanup completed. Log file: $LogFile"
        if ($GenerateReport) {
            $summary += "`nReport file: $ReportFile"
        }
        Write-Log $summary
        Write-Host $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-DiskCleanup
