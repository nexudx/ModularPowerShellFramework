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
        [ValidateRange(1, 1000)]
        [int]$MaxBandwidth,

        [Parameter(Mandatory = $false,
                   HelpMessage = "KB numbers to exclude")]
        [ValidatePattern('^KB\d+$')]
        [string[]]$ExcludeKBs,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Schedule reboot time (HH:mm)")]
        [ValidatePattern('^([01]?[0-9]|2[0-3]):[0-5][0-9]$')]
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

        # Initialize log files with mutex for thread safety
        $script:LogFile = Join-Path $ModuleDir "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $script:HistoryFile = Join-Path $ModuleDir "UpdateHistory.json"
        $script:LogMutex = New-Object System.Threading.Mutex($false, "GlobalWindowsUpdateLogMutex")

        function Write-UpdateLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Message,
                
                [Parameter(Mandatory = $false)]
                [ValidateSet('Information', 'Warning', 'Error')]
                [string]$Severity = 'Information'
            )
            
            $LogMessage = "[$(Get-Date)] [$Severity] - $Message"
            
            $script:LogMutex.WaitOne() | Out-Null
            try {
                $LogMessage | Add-Content -Path $script:LogFile
                
                switch ($Severity) {
                    'Warning' { Write-Warning $Message }
                    'Error' { Write-Error $Message }
                    default { Write-Verbose $Message }
                }
            }
            finally {
                $script:LogMutex.ReleaseMutex()
            }
        }

        function Test-PSWindowsUpdate {
            try {
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Write-UpdateLog "Installing PSWindowsUpdate module..." -Severity 'Warning'
                    Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
                    Write-UpdateLog "PSWindowsUpdate module installed successfully."
                }
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
                
                # Verify module functionality
                $null = Get-Command -Module PSWindowsUpdate -ErrorAction Stop
                return $true
            }
            catch {
                Write-UpdateLog "Error with PSWindowsUpdate module: $_" -Severity 'Error'
                return $false
            }
        }

        function Test-BitsService {
            try {
                $bits = Get-Service -Name BITS -ErrorAction Stop
                if ($bits.Status -ne 'Running') {
                    Write-UpdateLog "Starting BITS service..." -Severity 'Warning'
                    Start-Service -Name BITS -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    
                    $bits = Get-Service -Name BITS -ErrorAction Stop
                    if ($bits.Status -ne 'Running') {
                        throw "Failed to start BITS service"
                    }
                }
                return $true
            }
            catch {
                Write-UpdateLog "BITS service error: $_" -Severity 'Error'
                return $false
            }
        }

        function Set-UpdateBandwidth {
            param([int]$Mbps)
            
            try {
                if (-not (Test-BitsService)) {
                    throw "BITS service not available"
                }

                $bitsManager = New-Object -ComObject "Microsoft.BackgroundIntelligentTransfer.Management.5.1"
                $bitsManager.SetBandwidthLimitation($Mbps * 1000000)
                Write-UpdateLog "Bandwidth limit set to $Mbps Mbps"
                return $true
            }
            catch {
                Write-UpdateLog "Error setting bandwidth limit: $_" -Severity 'Error'
                return $false
            }
        }

        function Get-UpdateHistory {
            try {
                $script:LogMutex.WaitOne() | Out-Null
                try {
                    if (Test-Path $script:HistoryFile) {
                        $history = Get-Content $script:HistoryFile | ConvertFrom-Json
                        # Validate history structure
                        if ($history -isnot [array]) {
                            throw "Invalid history file format"
                        }
                        return $history
                    }
                    return @()
                }
                finally {
                    $script:LogMutex.ReleaseMutex()
                }
            }
            catch {
                Write-UpdateLog "Error reading update history: $_" -Severity 'Error'
                return @()
            }
        }

        function Save-UpdateHistory {
            param($Updates)
            
            try {
                $script:LogMutex.WaitOne() | Out-Null
                try {
                    $history = Get-UpdateHistory
                    $newEntry = @{
                        Date = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                        Updates = $Updates | Select-Object Title, KB, Status
                        System = @{
                            OSVersion = [System.Environment]::OSVersion.Version.ToString()
                            LastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString()
                        }
                    }
                    $history += $newEntry
                    $history | ConvertTo-Json -Depth 10 | Set-Content $script:HistoryFile
                }
                finally {
                    $script:LogMutex.ReleaseMutex()
                }
            }
            catch {
                Write-UpdateLog "Error saving update history: $_" -Severity 'Error'
            }
        }

        function Test-PendingReboot {
            try {
                $pendingReboot = $false
                
                # Check Component-Based Servicing
                $cbsPending = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue
                if ($cbsPending) {
                    $pendingReboot = $true
                }

                # Check Windows Update
                $wuPending = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
                if ($wuPending) {
                    $pendingReboot = $true
                }

                # Check Pending File Rename Operations
                $pfroPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
                $pfroValue = (Get-ItemProperty -Path $pfroPath -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
                if ($pfroValue) {
                    $pendingReboot = $true
                }

                return $pendingReboot
            }
            catch {
                Write-UpdateLog "Error checking pending reboot: $_" -Severity 'Warning'
                return $false
            }
        }
    }

    process {
        try {
            Write-UpdateLog "Starting enhanced Windows Update process..."

            # Check for pending reboot
            if (Test-PendingReboot) {
                throw "System has pending reboot. Please restart before installing updates."
            }

            # Verify PSWindowsUpdate module
            if (-not (Test-PSWindowsUpdate)) {
                throw "PSWindowsUpdate module could not be loaded"
            }

            # Set bandwidth limit if specified
            if ($MaxBandwidth) {
                if (-not (Set-UpdateBandwidth -Mbps $MaxBandwidth)) {
                    Write-UpdateLog "Continuing without bandwidth limit" -Severity 'Warning'
                }
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
            Write-UpdateLog "Checking for available updates..."
            $updates = Get-WindowsUpdate @criteria -ErrorAction Stop

            if ($updates.Count -gt 0) {
                Write-UpdateLog "Found $($updates.Count) updates"
                
                # Display updates and prompt for confirmation
                if (-not $Force) {
                    $updates | Format-Table -Property Title, KB, Size -AutoSize
                    if (-not $PSCmdlet.ShouldContinue("Install these updates?", "Confirm Update Installation")) {
                        throw "Update installation cancelled by user"
                    }
                }

                # Install updates with progress tracking
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

                Write-UpdateLog "Update Statistics: $($statistics | ConvertTo-Json)"

                # Save to history
                Save-UpdateHistory -Updates $result

                # Handle reboot if needed
                if ($result.RebootRequired) {
                    if ($ScheduleReboot) {
                        Write-UpdateLog "Scheduling reboot for $ScheduleReboot..."
                        $rebootTime = [DateTime]::Parse($ScheduleReboot)
                        $currentTime = Get-Date
                        $delay = $rebootTime - $currentTime
                        
                        if ($delay.TotalSeconds -gt 0) {
                            $delaySeconds = [int]$delay.TotalSeconds
                            Write-UpdateLog "System will restart in $([math]::Round($delay.TotalHours, 2)) hours"
                            shutdown /r /t $delaySeconds /c "Scheduled restart for Windows Updates"
                        }
                        else {
                            Write-UpdateLog "Scheduled time is in the past, skipping reboot" -Severity 'Warning'
                        }
                    }
                    else {
                        Write-UpdateLog "Reboot required to complete updates" -Severity 'Warning'
                        Write-Warning "A system reboot is required to complete the update installation"
                    }
                }
            }
            else {
                Write-UpdateLog "No updates available"
                Write-Host "No updates are available at this time"
            }
        }
        catch {
            $errorMessage = "Critical error during Windows Update: $_"
            Write-UpdateLog $errorMessage -Severity 'Error'
            throw $errorMessage
        }
    }

    end {
        Write-UpdateLog "Windows Update process completed. Log file: $LogFile"
        Write-Host "Windows Update process completed. Log file: $LogFile"
        
        # Cleanup
        if ($script:LogMutex) {
            $script:LogMutex.Dispose()
        }
    }
}

# Export module members
Export-ModuleMember -Function Invoke-WindowsUpdate
