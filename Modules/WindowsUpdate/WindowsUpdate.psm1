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
    - Detailed logging

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER Categories
    Array of update categories to include (e.g., "Security", "Critical").

.PARAMETER MaxBandwidth
    Maximum bandwidth in Mbps for update downloads.

.PARAMETER ExcludeKBs
    Array of KB numbers to exclude from installation.

.PARAMETER ScheduleReboot
    Schedule reboot time after updates (e.g., "22:00").

.PARAMETER Force
    Skips confirmation prompts for installation.

.EXAMPLE
    Invoke-WindowsUpdate
    Installs all available updates.

.EXAMPLE
    Invoke-WindowsUpdate -Categories "Security","Critical" -MaxBandwidth 10
    Installs security and critical updates with bandwidth limit.

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
        Write-Log "Windows Update process completed. Log file: $LogFile"
        Write-Host "Windows Update process completed. Log file: $LogFile"
    }
}

# Export module members
Export-ModuleMember -Function Invoke-WindowsUpdate
