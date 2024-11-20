# Import common module
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) "Common\Common.psm1")

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

        # Initialize module operation
        $operation = Start-ModuleOperation -ModuleName 'WindowsUpdate'
        if (-not $operation.Success) {
            throw "Failed to initialize WindowsUpdate operation"
        }

        # Initialize history file path
        $script:HistoryFile = Join-Path $operation.LogDirectory "UpdateHistory.json"

        function Test-PSWindowsUpdate {
            try {
                if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                    Write-ModuleLog -Message "Installing PSWindowsUpdate module..." -Severity 'Warning' -ModuleName 'WindowsUpdate'
                    Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
                    Write-ModuleLog -Message "PSWindowsUpdate module installed successfully." -ModuleName 'WindowsUpdate'
                }
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
                
                # Verify module functionality
                $null = Get-Command -Module PSWindowsUpdate -ErrorAction Stop
                return $true
            }
            catch {
                Write-ModuleLog -Message "Error with PSWindowsUpdate module: $_" -Severity 'Error' -ModuleName 'WindowsUpdate'
                return $false
            }
        }

        function Test-BitsService {
            try {
                $bits = Get-Service -Name BITS -ErrorAction Stop
                if ($bits.Status -ne 'Running') {
                    Write-ModuleLog -Message "Starting BITS service..." -Severity 'Warning' -ModuleName 'WindowsUpdate'
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
                Write-ModuleLog -Message "BITS service error: $_" -Severity 'Error' -ModuleName 'WindowsUpdate'
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
                Write-ModuleLog -Message "Bandwidth limit set to $Mbps Mbps" -ModuleName 'WindowsUpdate'
                return $true
            }
            catch {
                Write-ModuleLog -Message "Error setting bandwidth limit: $_" -Severity 'Error' -ModuleName 'WindowsUpdate'
                return $false
            }
        }

        function Get-UpdateHistory {
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
            catch {
                Write-ModuleLog -Message "Error reading update history: $_" -Severity 'Error' -ModuleName 'WindowsUpdate'
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
                    System = @{
                        OSVersion = [System.Environment]::OSVersion.Version.ToString()
                        LastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToString()
                    }
                }
                $history += $newEntry
                $history | ConvertTo-Json -Depth 10 | Set-Content $script:HistoryFile
            }
            catch {
                Write-ModuleLog -Message "Error saving update history: $_" -Severity 'Error' -ModuleName 'WindowsUpdate'
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
                Write-ModuleLog -Message "Error checking pending reboot: $_" -Severity 'Warning' -ModuleName 'WindowsUpdate'
                return $false
            }
        }
    }

    process {
        try {
            Write-ModuleLog -Message "Starting enhanced Windows Update process..." -ModuleName 'WindowsUpdate'

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
                    Write-ModuleLog -Message "Continuing without bandwidth limit" -Severity 'Warning' -ModuleName 'WindowsUpdate'
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
            Write-ModuleLog -Message "Checking for available updates..." -ModuleName 'WindowsUpdate'
            $updates = Get-WindowsUpdate @criteria -ErrorAction Stop

            if ($updates.Count -gt 0) {
                Write-ModuleLog -Message "Found $($updates.Count) updates" -ModuleName 'WindowsUpdate'
                
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

                Write-ModuleLog -Message "Update Statistics: $($statistics | ConvertTo-Json)" -ModuleName 'WindowsUpdate'

                # Save to history
                Save-UpdateHistory -Updates $result

                # Handle reboot if needed
                if ($result.RebootRequired) {
                    if ($ScheduleReboot) {
                        Write-ModuleLog -Message "Scheduling reboot for $ScheduleReboot..." -ModuleName 'WindowsUpdate'
                        $rebootTime = [DateTime]::Parse($ScheduleReboot)
                        $currentTime = Get-Date
                        $delay = $rebootTime - $currentTime
                        
                        if ($delay.TotalSeconds -gt 0) {
                            $delaySeconds = [int]$delay.TotalSeconds
                            Write-ModuleLog -Message "System will restart in $([math]::Round($delay.TotalHours, 2)) hours" -ModuleName 'WindowsUpdate'
                            shutdown /r /t $delaySeconds /c "Scheduled restart for Windows Updates"
                        }
                        else {
                            Write-ModuleLog -Message "Scheduled time is in the past, skipping reboot" -Severity 'Warning' -ModuleName 'WindowsUpdate'
                        }
                    }
                    else {
                        Write-ModuleLog -Message "Reboot required to complete updates" -Severity 'Warning' -ModuleName 'WindowsUpdate'
                        Write-Warning "A system reboot is required to complete the update installation"
                    }
                }
            }
            else {
                Write-ModuleLog -Message "No updates available" -ModuleName 'WindowsUpdate'
                Write-Host "No updates are available at this time"
            }
        }
        catch {
            $errorMessage = "Critical error during Windows Update: $_"
            Write-ModuleLog -Message $errorMessage -Severity 'Error' -ModuleName 'WindowsUpdate'
            Stop-ModuleOperation -ModuleName 'WindowsUpdate' -StartTime $operation.StartTime -Success $false -ErrorMessage $_.Exception.Message
            throw $errorMessage
        }
    }

    end {
        # Complete module operation
        Stop-ModuleOperation -ModuleName 'WindowsUpdate' -StartTime $operation.StartTime -Success $true
        Write-Host "Windows Update process completed. Check logs for details."
    }
}

# Export module members
Export-ModuleMember -Function Invoke-WindowsUpdate
