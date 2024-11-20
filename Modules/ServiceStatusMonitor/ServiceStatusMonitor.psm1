# Import common module
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) "Common\Common.psm1")

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

        # Initialize module operation
        $operation = Start-ModuleOperation -ModuleName 'ServiceStatusMonitor'
        if (-not $operation.Success) {
            throw "Failed to initialize ServiceStatusMonitor operation"
        }

        # Setup state file path
        $DefaultStateFile = Join-Path $operation.LogDirectory "ServiceState.json"
        $StateFilePath = if ($StateFile) { $StateFile } else { $DefaultStateFile }

        # Function to check for elevated privileges
        function Test-ElevatedPrivileges {
            try {
                $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object Security.Principal.WindowsPrincipal($identity)
                $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
                return $principal.IsInRole($adminRole)
            }
            catch {
                Write-ModuleLog -Message "Error checking privileges: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
                    Write-ModuleLog -Message "Access denied for service '$($Service.Name)' - requires elevated privileges" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }
                catch [Microsoft.Management.Infrastructure.CimException] {
                    Write-ModuleLog -Message "Service '$($Service.Name)' cannot be queried due to the following error: $($_.Exception.Message)" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }
                catch {
                    Write-ModuleLog -Message "Unexpected error accessing service '$($Service.Name)': $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }

                # Try to get dependencies with specific error handling
                try {
                    $basicInfo.Dependencies = @($Service.ServicesDependedOn | Select-Object -ExpandProperty Name)
                }
                catch [System.Security.SecurityException] {
                    Write-ModuleLog -Message "Access denied when retrieving dependencies for service '$($Service.Name)'" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }
                catch {
                    Write-ModuleLog -Message "Error retrieving dependencies for service '$($Service.Name)': $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }

                # Try to get process ID with specific error handling
                try {
                    if ($Service.Status -eq 'Running') {
                        $basicInfo.ProcessId = $Service.Id
                    }
                }
                catch [System.ComponentModel.Win32Exception] {
                    Write-ModuleLog -Message "Access denied when retrieving process ID for service '$($Service.Name)'" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }
                catch {
                    Write-ModuleLog -Message "Error retrieving process ID for service '$($Service.Name)': $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }

                return $basicInfo
            }
            catch {
                Write-ModuleLog -Message "Critical error processing service '$($Service.Name)': $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
                    Write-ModuleLog -Message "File access error reading state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                    return $null
                }
                catch [System.Management.Automation.RuntimeException] {
                    Write-ModuleLog -Message "JSON parsing error in state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                    return $null
                }
                catch {
                    Write-ModuleLog -Message "Unexpected error reading state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
                Write-ModuleLog -Message "Access denied when saving state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
            }
            catch [System.IO.IOException] {
                Write-ModuleLog -Message "File system error when saving state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
            }
            catch {
                Write-ModuleLog -Message "Unexpected error saving state file: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
    }

    process {
        try {
            Write-ModuleLog -Message "Starting service status monitor..." -ModuleName 'ServiceStatusMonitor'
            
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
                Write-ModuleLog -Message $elevationMessage -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
            }

            # Load previous state
            $previousState = Get-PreviousState
            
            # Get current services with enhanced error handling
            $services = if ($TargetServices) {
                Write-ModuleLog -Message "Filtering for specific services: $($TargetServices -join ', ')" -ModuleName 'ServiceStatusMonitor'
                $TargetServices | ForEach-Object { 
                    try {
                        Get-Service -Name $_ -ErrorAction Stop
                    }
                    catch [System.InvalidOperationException] {
                        Write-ModuleLog -Message "Service '$_' not found" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                        $null
                    }
                    catch [System.Security.SecurityException] {
                        Write-ModuleLog -Message "Access denied for service '$_'" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                        $null
                    }
                    catch {
                        Write-ModuleLog -Message "Error accessing service '$_': $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                        $null
                    }
                } | Where-Object { $_ -ne $null }
            }
            else {
                try {
                    Get-Service -ErrorAction Stop
                }
                catch [System.Security.SecurityException] {
                    Write-ModuleLog -Message "Access denied when retrieving services - requires elevated privileges" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                    @()
                }
                catch {
                    Write-ModuleLog -Message "Error retrieving services: $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
                    Write-ModuleLog -Message "Error processing service $($service.Name): $_" -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
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
                Write-ModuleLog -Message $accessSummary -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
            }

            # Compare states and detect changes
            $changes = Compare-ServiceStates -Previous $previousState -Current $currentState

            # Enhanced change logging
            if ($changes.Modified.Count -gt 0 -or $changes.New.Count -gt 0 -or 
                $changes.Removed.Count -gt 0 -or $changes.AccessDenied.Count -gt 0) {
                Write-ModuleLog -Message "Service Changes Detected:" -ModuleName 'ServiceStatusMonitor'

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
                    Write-ModuleLog -Message $changeDetails -ModuleName 'ServiceStatusMonitor'
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
                    Write-ModuleLog -Message $newDetails -ModuleName 'ServiceStatusMonitor'
                }

                foreach ($removed in $changes.Removed) {
                    $removedDetails = @"

Removed Service: $($removed.DisplayName) ($($removed.Name))
  - Last Known Status: $($removed.Status)
  - Last Known StartType: $($removed.StartType)
  - Last Known Account: $($removed.Account)
"@
                    Write-ModuleLog -Message $removedDetails -ModuleName 'ServiceStatusMonitor'
                }

                if ($changes.AccessDenied.Count -gt 0) {
                    $accessDeniedDetails = @"

Services with Limited Access:
$($changes.AccessDenied | ForEach-Object { "- $($_.DisplayName) ($($_.Name))" } | Out-String)
"@
                    Write-ModuleLog -Message $accessDeniedDetails -Severity 'Warning' -ModuleName 'ServiceStatusMonitor'
                }
            }
            else {
                Write-ModuleLog -Message "No service changes detected." -ModuleName 'ServiceStatusMonitor'
            }

            # Save current state
            Save-CurrentState -ServiceState $currentState

            # Complete module operation successfully
            Stop-ModuleOperation -ModuleName 'ServiceStatusMonitor' -StartTime $operation.StartTime -Success $true
        }
        catch {
            Write-ModuleLog -Message "Critical error during service monitoring: $_" -Severity 'Error' -ModuleName 'ServiceStatusMonitor'
            Stop-ModuleOperation -ModuleName 'ServiceStatusMonitor' -StartTime $operation.StartTime -Success $false -ErrorMessage $_.Exception.Message
            throw
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
State File: $StateFilePath
"@
        Write-ModuleLog -Message $summary -ModuleName 'ServiceStatusMonitor'
        Write-Host $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-ServiceStatusMonitor
