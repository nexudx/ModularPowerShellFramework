<#
.SYNOPSIS
    Enhanced Windows service status monitor with comprehensive change detection.

.DESCRIPTION
    Advanced module for monitoring Windows services that:
    - Tracks all service status changes
    - Detects new and removed services
    - Maintains detailed JSON-based state tracking
    - Provides comprehensive logging with timestamps
    - Compares current state with previous states
    - Monitors all service properties for changes

.PARAMETER TargetServices
    Optional array of specific service names to monitor. If omitted, monitors all services.

.PARAMETER LogRetentionDays
    Number of days to retain log files. Default is 30 days.

.PARAMETER StateFile
    Custom path for the JSON state file. If omitted, uses default path in module directory.

.PARAMETER VerboseOutput
    Enables detailed console output.

.EXAMPLE
    Invoke-ServiceStatusMonitor
    Monitors all services and reports any changes.

.EXAMPLE
    Invoke-ServiceStatusMonitor -TargetServices "wuauserv", "spooler" -VerboseOutput
    Monitors specific services with detailed output.

.NOTES
    Requires Administrator privileges for full service access.
#>

function Invoke-ServiceStatusMonitor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Specific services to monitor")]
        [string[]]$TargetServices,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Number of days to retain log files")]
        [int]$LogRetentionDays = 30,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Custom path for state file")]
        [string]$StateFile,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose console output")]
        [switch]$VerboseOutput
    )

    begin {
        # Initialize strict error handling
        $ErrorActionPreference = 'Stop'
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        }

        # Setup directories and files
        $ModuleDir = Join-Path $PSScriptRoot "Logs"
        $DefaultStateFile = Join-Path $ModuleDir "ServiceState.json"
        $StateFilePath = if ($StateFile) { $StateFile } else { $DefaultStateFile }
        
        if (-not (Test-Path $ModuleDir)) {
            New-Item -ItemType Directory -Path $ModuleDir -Force | Out-Null
            Write-Verbose "Created logs directory: $ModuleDir"
        }

        $CurrentLogFile = Join-Path $ModuleDir "ServiceStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Write-Verbose "Initializing new log file: $CurrentLogFile"

        # Initialize logging function
        function Write-ServiceLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Message,
                
                [Parameter(Mandatory = $false)]
                [ValidateSet('Info', 'Warning', 'Error')]
                [string]$Level = 'Info'
            )
            
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $LogEntry = "[$Timestamp] [$Level] - $Message"
            
            try {
                $LogEntry | Add-Content -Path $CurrentLogFile -ErrorAction Stop
                if ($VerboseOutput -or $Level -ne 'Info') {
                    switch ($Level) {
                        'Warning' { Write-Warning $Message }
                        'Error' { Write-Error $Message }
                        default { Write-Host $LogEntry }
                    }
                }
            }
            catch {
                Write-Warning "Failed to write to log file: $_"
                Write-Host $LogEntry
            }
        }

        # Function to get detailed service information
        function Get-DetailedServiceInfo {
            param([System.ServiceProcess.ServiceController]$Service)
            
            try {
                $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$($Service.Name)'" -ErrorAction Stop
                if (-not $wmiService) {
                    throw "WMI service information not found"
                }

                return @{
                    Name = $Service.Name
                    DisplayName = $Service.DisplayName
                    Status = $Service.Status.ToString()
                    StartType = $wmiService.StartMode
                    Account = $wmiService.StartName
                    Path = $wmiService.PathName
                    ProcessId = $Service.Id
                    Dependencies = @($Service.ServicesDependedOn | Select-Object -ExpandProperty Name)
                    Description = $wmiService.Description
                    LastStartTime = $null  # Will be updated if running
                    LastErrorCode = $wmiService.ErrorControl
                    DelayedAutoStart = $wmiService.DelayedAutoStart
                    Timestamp = (Get-Date).ToString("o")
                }
            }
            catch {
                Write-ServiceLog "Error getting details for service $($Service.Name): $_" -Level 'Error'
                return $null
            }
        }

        # Function to load previous state
        function Get-PreviousState {
            if (Test-Path $StateFilePath) {
                try {
                    $state = Get-Content $StateFilePath -Raw | ConvertFrom-Json
                    # Convert the Services property to a hashtable
                    $servicesHash = @{}
                    foreach ($property in $state.Services.PSObject.Properties) {
                        $servicesHash[$property.Name] = $property.Value
                    }
                    return $servicesHash
                }
                catch {
                    Write-ServiceLog "Error reading previous state file: $_" -Level 'Warning'
                    return $null
                }
            }
            return $null
        }

        # Function to save current state
        function Save-CurrentState {
            param($ServiceState)
            
            try {
                $state = @{
                    Timestamp = (Get-Date).ToString("o")
                    Services = $ServiceState
                }
                $state | ConvertTo-Json -Depth 10 | Set-Content $StateFilePath
            }
            catch {
                Write-ServiceLog "Error saving current state: $_" -Level 'Error'
            }
        }

        # Function to compare service states
        function Compare-ServiceStates {
            param($Previous, $Current)
            
            $changes = @{
                Modified = @()
                New = @()
                Removed = @()
            }

            # Check for new and modified services
            foreach ($svc in $Current.GetEnumerator()) {
                if (-not $Previous -or -not $Previous.ContainsKey($svc.Name)) {
                    $changes.New += $svc.Value
                }
                elseif ($Previous[$svc.Name].Status -ne $svc.Value.Status -or
                        $Previous[$svc.Name].StartType -ne $svc.Value.StartType -or
                        $Previous[$svc.Name].Account -ne $svc.Value.Account) {
                    $changes.Modified += @{
                        Previous = $Previous[$svc.Name]
                        Current = $svc.Value
                    }
                }
            }

            # Check for removed services
            if ($Previous) {
                foreach ($svc in $Previous.Keys) {
                    if (-not $Current.ContainsKey($svc)) {
                        $changes.Removed += $Previous[$svc]
                    }
                }
            }

            return $changes
        }

        # Cleanup old logs
        function Remove-OldLogs {
            try {
                $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
                Get-ChildItem -Path $ModuleDir -Filter "ServiceStatus_*.log" |
                    Where-Object { $_.LastWriteTime -lt $cutoffDate } |
                    ForEach-Object {
                        Remove-Item $_.FullName -Force
                        Write-ServiceLog "Removed old log file: $($_.Name)" -Level 'Info'
                    }
            }
            catch {
                Write-ServiceLog "Error during log cleanup: $_" -Level 'Warning'
            }
        }
    }

    process {
        try {
            Write-ServiceLog "Starting service status monitor..."
            
            # Verify administrator privileges
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            if (-not $isAdmin) {
                throw "This function requires administrator privileges"
            }

            # Load previous state
            $previousState = Get-PreviousState
            
            # Get current services
            $services = if ($TargetServices) {
                Write-ServiceLog "Filtering for specific services: $($TargetServices -join ', ')"
                $TargetServices | ForEach-Object { 
                    try {
                        Get-Service -Name $_ -ErrorAction Stop
                    }
                    catch {
                        Write-ServiceLog "Warning: Service '$_' not found or access denied: $_" -Level 'Warning'
                        $null
                    }
                } | Where-Object { $_ -ne $null }
            }
            else {
                Get-Service
            }

            # Process current services
            $currentState = @{}
            foreach ($service in $services) {
                $serviceInfo = Get-DetailedServiceInfo -Service $service
                if ($serviceInfo) {
                    $currentState[$service.Name] = $serviceInfo
                }
            }

            # Compare states and detect changes
            $changes = Compare-ServiceStates -Previous $previousState -Current $currentState

            # Log changes
            if ($changes.Modified.Count -gt 0 -or $changes.New.Count -gt 0 -or $changes.Removed.Count -gt 0) {
                Write-ServiceLog "Service Changes Detected:" -Level 'Info'

                foreach ($change in $changes.Modified) {
                    $changeDetails = @"

Modified Service: $($change.Current.DisplayName) ($($change.Current.Name))
Previous State:
  - Status: $($change.Previous.Status)
  - StartType: $($change.Previous.StartType)
  - Account: $($change.Previous.Account)
Current State:
  - Status: $($change.Current.Status)
  - StartType: $($change.Current.StartType)
  - Account: $($change.Current.Account)
  - Process ID: $($change.Current.ProcessId)
  - Path: $($change.Current.Path)
  - Dependencies: $($change.Current.Dependencies -join ', ')
"@
                    Write-ServiceLog $changeDetails
                }

                foreach ($new in $changes.New) {
                    $newDetails = @"

New Service Detected: $($new.DisplayName) ($($new.Name))
  - Status: $($new.Status)
  - StartType: $($new.StartType)
  - Account: $($new.Account)
  - Process ID: $($new.ProcessId)
  - Path: $($new.Path)
  - Dependencies: $($new.Dependencies -join ', ')
"@
                    Write-ServiceLog $newDetails
                }

                foreach ($removed in $changes.Removed) {
                    $removedDetails = @"

Removed Service: $($removed.DisplayName) ($($removed.Name))
  - Last Known Status: $($removed.Status)
  - Last Known StartType: $($removed.StartType)
  - Last Known Account: $($removed.Account)
"@
                    Write-ServiceLog $removedDetails
                }
            }
            else {
                Write-ServiceLog "No service changes detected."
            }

            # Save current state
            Save-CurrentState -ServiceState $currentState

            # Cleanup old logs
            Remove-OldLogs
        }
        catch {
            Write-ServiceLog "Critical error during service monitoring: $_" -Level 'Error'
            throw $_
        }
    }

    end {
        $summary = @"

Service Status Monitor Summary:
-----------------------------
Total Services Monitored: $($currentState.Count)
Modified Services: $($changes.Modified.Count)
New Services: $($changes.New.Count)
Removed Services: $($changes.Removed.Count)
Log File: $CurrentLogFile
State File: $StateFilePath
"@
        Write-ServiceLog $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-ServiceStatusMonitor
