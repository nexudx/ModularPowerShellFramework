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
    - Handles permission-related issues gracefully

.PARAMETER TargetServices
    Optional array of specific service names to monitor. If omitted, monitors all accessible services.

.PARAMETER LogRetentionDays
    Number of days to retain log files. Default is 30 days.

.PARAMETER StateFile
    Custom path for the JSON state file. If omitted, uses default path in module directory.

.PARAMETER VerboseOutput
    Enables detailed console output.

.EXAMPLE
    Invoke-ServiceStatusMonitor
    Monitors all accessible services and reports any changes.

.EXAMPLE
    Invoke-ServiceStatusMonitor -TargetServices "wuauserv", "spooler" -VerboseOutput
    Monitors specific services with detailed output.

.NOTES
    Requires Administrator privileges for full service access.
    Some services may not be accessible due to security restrictions.
    Use 'Run as Administrator' for complete service monitoring capabilities.
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
        $ErrorActionPreference = 'Continue'
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

        # Initialize logging function with enhanced error context
        function Write-ServiceLog {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Message,
                
                [Parameter(Mandatory = $false)]
                [ValidateSet('Info', 'Warning', 'Error')]
                [string]$Level = 'Info',

                [Parameter(Mandatory = $false)]
                [System.Management.Automation.ErrorRecord]$ErrorRecord
            )
            
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $LogEntry = "[$Timestamp] [$Level] - $Message"
            
            # Add detailed error context if available
            if ($ErrorRecord) {
                $errorContext = @"
Error Details:
- Exception Type: $($ErrorRecord.Exception.GetType().FullName)
- Message: $($ErrorRecord.Exception.Message)
- Category: $($ErrorRecord.CategoryInfo.Category)
- Target Object: $($ErrorRecord.TargetObject)
- Fully Qualified Error ID: $($ErrorRecord.FullyQualifiedErrorId)
"@
                $LogEntry += "`n$errorContext"
            }
            
            try {
                $LogEntry | Add-Content -Path $CurrentLogFile -ErrorAction Stop
                if ($VerboseOutput -or $Level -ne 'Info') {
                    switch ($Level) {
                        'Warning' { Write-Warning $Message }
                        'Error' { Write-Warning $Message }
                        default { Write-Host $LogEntry }
                    }
                }
            }
            catch {
                Write-Warning "Failed to write to log file: $_"
                Write-Host $LogEntry
            }
        }

        # Function to check for elevated privileges
        function Test-ElevatedPrivileges {
            try {
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object Security.Principal.WindowsPrincipal($identity)
                $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
                return $principal.IsInRole($adminRole)
            }
            catch {
                Write-ServiceLog "Error checking privileges: $_" -Level 'Warning' -ErrorRecord $_
                return $false
            }
        }

        # Function to get detailed service information with enhanced error handling
        function Get-DetailedServiceInfo {
            param([System.ServiceProcess.ServiceController]$Service)
            
            try {
                $basicInfo = @{
                    Name = $Service.Name
                    DisplayName = $Service.DisplayName
                    Status = $Service.Status.ToString()
                    ProcessId = $null
                    StartType = "Unknown"
                    Account = "Unknown"
                    Path = "Unknown"
                    Dependencies = @()
                    Description = ""
                    LastStartTime = $null
                    LastErrorCode = 0
                    DelayedAutoStart = $false
                    Timestamp = (Get-Date).ToString("o")
                    AccessLevel = "Limited"  # New field to track access level
                }

                # Try to get WMI information with specific error handling
                try {
                    $wmiService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($Service.Name)'" -ErrorAction Stop
                    if ($wmiService) {
                        $basicInfo.StartType = $wmiService.StartMode
                        $basicInfo.Account = $wmiService.StartName
                        $basicInfo.Path = $wmiService.PathName
                        $basicInfo.Description = $wmiService.Description
                        $basicInfo.LastErrorCode = $wmiService.ErrorControl
                        $basicInfo.DelayedAutoStart = $wmiService.DelayedAutoStart
                        $basicInfo.AccessLevel = "Full"
                    }
                }
                catch [System.UnauthorizedAccessException] {
                    Write-ServiceLog "Access denied for service '$($Service.Name)' - requires elevated privileges" -Level 'Warning' -ErrorRecord $_
                }
                catch [Microsoft.Management.Infrastructure.CimException] {
                    Write-ServiceLog "Service '$($Service.Name)' cannot be queried due to the following error: $($_.Exception.Message)" -Level 'Warning' -ErrorRecord $_
                }
                catch {
                    Write-ServiceLog "Unexpected error accessing service '$($Service.Name)': $_" -Level 'Warning' -ErrorRecord $_
                }

                # Try to get dependencies with specific error handling
                try {
                    $basicInfo.Dependencies = @($Service.ServicesDependedOn | Select-Object -ExpandProperty Name)
                }
                catch [System.Security.SecurityException] {
                    Write-ServiceLog "Access denied when retrieving dependencies for service '$($Service.Name)'" -Level 'Warning' -ErrorRecord $_
                }
                catch {
                    Write-ServiceLog "Error retrieving dependencies for service '$($Service.Name)': $_" -Level 'Warning' -ErrorRecord $_
                }

                # Try to get process ID with specific error handling
                try {
                    if ($Service.Status -eq 'Running') {
                        $basicInfo.ProcessId = $Service.Id
                    }
                }
                catch [System.ComponentModel.Win32Exception] {
                    Write-ServiceLog "Access denied when retrieving process ID for service '$($Service.Name)'" -Level 'Warning' -ErrorRecord $_
                }
                catch {
                    Write-ServiceLog "Error retrieving process ID for service '$($Service.Name)': $_" -Level 'Warning' -ErrorRecord $_
                }

                return $basicInfo
            }
            catch {
                Write-ServiceLog "Critical error processing service '$($Service.Name)': $_" -Level 'Warning' -ErrorRecord $_
                return $null
            }
        }

        # Function to load previous state with enhanced error handling
        function Get-PreviousState {
            if (Test-Path $StateFilePath) {
                try {
                    $state = Get-Content $StateFilePath -Raw | ConvertFrom-Json
                    $servicesHash = @{}
                    foreach ($property in $state.Services.PSObject.Properties) {
                        $servicesHash[$property.Name] = $property.Value
                    }
                    return $servicesHash
                }
                catch [System.IO.IOException] {
                    Write-ServiceLog "File access error reading state file: $_" -Level 'Warning' -ErrorRecord $_
                    return $null
                }
                catch [System.Management.Automation.RuntimeException] {
                    Write-ServiceLog "JSON parsing error in state file: $_" -Level 'Warning' -ErrorRecord $_
                    return $null
                }
                catch {
                    Write-ServiceLog "Unexpected error reading state file: $_" -Level 'Warning' -ErrorRecord $_
                    return $null
                }
            }
            return $null
        }

        # Function to save current state with enhanced error handling
        function Save-CurrentState {
            param($ServiceState)
            
            try {
                $state = @{
                    Timestamp = (Get-Date).ToString("o")
                    Services = $ServiceState
                }
                $stateJson = $state | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($StateFilePath, $stateJson)
            }
            catch [System.UnauthorizedAccessException] {
                Write-ServiceLog "Access denied when saving state file: $_" -Level 'Warning' -ErrorRecord $_
            }
            catch [System.IO.IOException] {
                Write-ServiceLog "File system error when saving state file: $_" -Level 'Warning' -ErrorRecord $_
            }
            catch {
                Write-ServiceLog "Unexpected error saving state file: $_" -Level 'Warning' -ErrorRecord $_
            }
        }

        # Enhanced service state comparison
        function Compare-ServiceStates {
            param($Previous, $Current)
            
            $changes = @{
                Modified = @()
                New = @()
                Removed = @()
                AccessDenied = @()  # New category for tracking permission issues
            }

            # Check for new and modified services
            foreach ($svc in $Current.GetEnumerator()) {
                if ($svc.Value.AccessLevel -eq "Limited") {
                    $changes.AccessDenied += $svc.Value
                }
                
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

        # Enhanced log cleanup with error handling
        function Remove-OldLogs {
            try {
                $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
                Get-ChildItem -Path $ModuleDir -Filter "ServiceStatus_*.log" |
                    Where-Object { $_.LastWriteTime -lt $cutoffDate } |
                    ForEach-Object {
                        try {
                            Remove-Item $_.FullName -Force -ErrorAction Stop
                            Write-ServiceLog "Removed old log file: $($_.Name)" -Level 'Info'
                        }
                        catch [System.UnauthorizedAccessException] {
                            Write-ServiceLog "Access denied when removing old log file $($_.Name)" -Level 'Warning' -ErrorRecord $_
                        }
                        catch {
                            Write-ServiceLog "Error removing old log file $($_.Name): $_" -Level 'Warning' -ErrorRecord $_
                        }
                    }
            }
            catch {
                Write-ServiceLog "Error during log cleanup: $_" -Level 'Warning' -ErrorRecord $_
            }
        }
    }

    process {
        try {
            Write-ServiceLog "Starting service status monitor..."
            
            # Enhanced privilege check with specific recommendations
            $isAdmin = Test-ElevatedPrivileges
            if (-not $isAdmin) {
                $elevationMessage = @"
Limited access mode - Not running with administrator privileges.
To get full access to all services:
1. Close PowerShell/Terminal
2. Right-click on PowerShell/Terminal
3. Select 'Run as Administrator'
4. Re-run this command
"@
                Write-ServiceLog $elevationMessage -Level 'Warning'
            }

            # Load previous state
            $previousState = Get-PreviousState
            
            # Get current services with enhanced error handling
            $services = if ($TargetServices) {
                Write-ServiceLog "Filtering for specific services: $($TargetServices -join ', ')"
                $TargetServices | ForEach-Object { 
                    try {
                        Get-Service -Name $_ -ErrorAction Stop
                    }
                    catch [System.InvalidOperationException] {
                        Write-ServiceLog "Service '$_' not found" -Level 'Warning' -ErrorRecord $_
                        $null
                    }
                    catch [System.Security.SecurityException] {
                        Write-ServiceLog "Access denied for service '$_'" -Level 'Warning' -ErrorRecord $_
                        $null
                    }
                    catch {
                        Write-ServiceLog "Error accessing service '$_': $_" -Level 'Warning' -ErrorRecord $_
                        $null
                    }
                } | Where-Object { $_ -ne $null }
            }
            else {
                try {
                    Get-Service -ErrorAction Stop
                }
                catch [System.Security.SecurityException] {
                    Write-ServiceLog "Access denied when retrieving services - requires elevated privileges" -Level 'Warning' -ErrorRecord $_
                    @()
                }
                catch {
                    Write-ServiceLog "Error retrieving services: $_" -Level 'Warning' -ErrorRecord $_
                    @()
                }
            }

            # Process current services with enhanced tracking
            $currentState = @{}
            $accessStats = @{
                Total = 0
                FullAccess = 0
                LimitedAccess = 0
                Failed = 0
            }

            foreach ($service in $services) {
                $accessStats.Total++
                try {
                    $serviceInfo = Get-DetailedServiceInfo -Service $service
                    if ($serviceInfo) {
                        $currentState[$service.Name] = $serviceInfo
                        if ($serviceInfo.AccessLevel -eq "Full") {
                            $accessStats.FullAccess++
                        }
                        else {
                            $accessStats.LimitedAccess++
                        }
                    }
                    else {
                        $accessStats.Failed++
                    }
                }
                catch {
                    Write-ServiceLog "Error processing service $($service.Name): $_" -Level 'Warning' -ErrorRecord $_
                    $accessStats.Failed++
                }
            }

            # Enhanced access statistics reporting
            if ($accessStats.LimitedAccess -gt 0 -or $accessStats.Failed -gt 0) {
                $accessSummary = @"
Service Access Summary:
- Total Services: $($accessStats.Total)
- Full Access: $($accessStats.FullAccess)
- Limited Access: $($accessStats.LimitedAccess)
- Failed Access: $($accessStats.Failed)
"@
                Write-ServiceLog $accessSummary -Level 'Warning'
            }

            # Compare states and detect changes
            $changes = Compare-ServiceStates -Previous $previousState -Current $currentState

            # Enhanced change logging
            if ($changes.Modified.Count -gt 0 -or $changes.New.Count -gt 0 -or 
                $changes.Removed.Count -gt 0 -or $changes.AccessDenied.Count -gt 0) {
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
  - Access Level: $($change.Current.AccessLevel)
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
  - Access Level: $($new.AccessLevel)
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

                if ($changes.AccessDenied.Count -gt 0) {
                    $accessDeniedDetails = @"

Services with Limited Access:
$($changes.AccessDenied | ForEach-Object { "- $($_.DisplayName) ($($_.Name))" } | Out-String)
"@
                    Write-ServiceLog $accessDeniedDetails -Level 'Warning'
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
            Write-ServiceLog "Critical error during service monitoring: $_" -Level 'Warning' -ErrorRecord $_
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
Services with Limited Access: $($changes.AccessDenied.Count)
Running with Administrator Privileges: $($isAdmin)
Log File: $CurrentLogFile
State File: $StateFilePath
"@
        Write-ServiceLog $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-ServiceStatusMonitor
