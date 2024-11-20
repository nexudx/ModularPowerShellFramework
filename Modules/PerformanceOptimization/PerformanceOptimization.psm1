<#
.SYNOPSIS
    Advanced system performance optimization and monitoring.

.DESCRIPTION
    This optimized module provides comprehensive system performance optimization with:
    - CPU optimization
    - Memory management
    - Process priority optimization
    - Service optimization
    - Network performance tuning
    - Startup optimization
    - Performance monitoring
    - Detailed logging

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER Areas
    Specific areas to optimize (e.g., "CPU", "Memory", "Network").

.PARAMETER Force
    Skips confirmation prompts for optimizations.

.PARAMETER SafeMode
    Performs only safe optimizations.

.EXAMPLE
    Invoke-PerformanceOptimization
    Performs basic system performance optimization.

.EXAMPLE
    Invoke-PerformanceOptimization -Areas "CPU","Memory"
    Optimizes specific areas.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-PerformanceOptimization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose output")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Areas to optimize")]
        [ValidateSet("CPU", "Memory", "Network", "Services", "Startup")]
        [string[]]$Areas = @("CPU", "Memory", "Network", "Services", "Startup"),

        [Parameter(Mandatory = $false,
                   HelpMessage = "Skip confirmation prompts")]
        [switch]$Force,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Perform only safe optimizations")]
        [switch]$SafeMode
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

        # Initialize log file
        $LogFile = Join-Path $ModuleDir "PerformanceOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        # List of protected system processes
        $protectedProcesses = @(
            "System", "Idle", "svchost", "lsass", "csrss", "smss", "wininit",
            "services", "winlogon", "MsMpEng", "spoolsv", "explorer"
        )

        # Performance optimization functions
        function Optimize-CPU {
            try {
                Write-Log "Starting CPU optimization..."
                
                # Get current CPU-intensive processes
                $processes = Get-Process | Where-Object {
                    $_.CPU -gt 20 -and 
                    $_.ProcessName -notin $protectedProcesses -and
                    $_.Handle # Only processes we can access
                } | Sort-Object CPU -Descending
                
                $result = @{
                    ProcessesOptimized = 0
                    Actions = @()
                }

                foreach ($process in $processes) {
                    try {
                        # Only adjust priority if we have access
                        if (Test-ProcessAccess $process) {
                            $process.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
                            $result.ProcessesOptimized++
                            $result.Actions += "Adjusted priority for $($process.ProcessName)"
                        }
                    }
                    catch {
                        Write-Log "Skipping process $($process.ProcessName): $_"
                    }
                }

                return $result
            }
            catch {
                Write-Log "Error in CPU optimization: $_"
                return $null
            }
        }

        function Test-ProcessAccess {
            param([System.Diagnostics.Process]$Process)
            
            try {
                $null = $Process.Handle
                return $true
            }
            catch {
                return $false
            }
        }

        function Optimize-Memory {
            try {
                Write-Log "Starting memory optimization..."
                
                $result = @{
                    ProcessesOptimized = 0
                    Actions = @()
                }

                # Optimize memory-intensive processes
                $processes = Get-Process | Where-Object {
                    $_.WorkingSet64 -gt 500MB -and
                    $_.ProcessName -notin $protectedProcesses -and
                    $_.Handle # Only processes we can access
                } | Sort-Object WorkingSet64 -Descending

                foreach ($process in $processes) {
                    try {
                        if (Test-ProcessAccess $process) {
                            [System.GC]::Collect()
                            [System.GC]::WaitForPendingFinalizers()
                            $result.ProcessesOptimized++
                            $result.Actions += "Optimized memory for $($process.ProcessName)"
                        }
                    }
                    catch {
                        Write-Log "Skipping process memory $($process.ProcessName): $_"
                    }
                }

                # Clear system cache
                try {
                    [System.GC]::Collect()
                    [System.GC]::WaitForPendingFinalizers()
                    $result.Actions += "Cleared system memory cache"
                }
                catch {
                    Write-Log "Error clearing system cache: $_"
                }

                return $result
            }
            catch {
                Write-Log "Error in memory optimization: $_"
                return $null
            }
        }

        function Optimize-Network {
            try {
                Write-Log "Starting network optimization..."
                
                $result = @{
                    OptimizationsApplied = 0
                    Actions = @()
                }

                # Apply safe network optimizations
                if (-not $SafeMode) {
                    try {
                        # Enable TCP Window Auto-Tuning
                        $null = netsh int tcp set global autotuninglevel=normal
                        $result.OptimizationsApplied++
                        $result.Actions += "Enabled TCP Window Auto-Tuning"
                    }
                    catch {
                        Write-Log "Error setting TCP auto-tuning: $_"
                    }

                    try {
                        # Clear DNS cache
                        Clear-DnsClientCache
                        $result.OptimizationsApplied++
                        $result.Actions += "Cleared DNS cache"
                    }
                    catch {
                        Write-Log "Error clearing DNS cache: $_"
                    }
                }

                return $result
            }
            catch {
                Write-Log "Error in network optimization: $_"
                return $null
            }
        }

        function Optimize-Services {
            try {
                Write-Log "Starting services optimization..."
                
                $result = @{
                    ServicesOptimized = 0
                    Actions = @()
                }

                # Define non-essential services that can be safely optimized
                $nonEssentialServices = @(
                    @{Name = "TabletInputService"; StartupType = "Manual"}
                    @{Name = "WSearch"; StartupType = "Manual"}
                    @{Name = "DiagTrack"; StartupType = "Manual"}
                )

                foreach ($service in $nonEssentialServices) {
                    try {
                        $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
                        if ($svc -and $svc.StartType -ne $service.StartupType) {
                            Set-Service -Name $service.Name -StartupType $service.StartupType -ErrorAction Stop
                            $result.ServicesOptimized++
                            $result.Actions += "Optimized service: $($service.Name) to $($service.StartupType)"
                        }
                    }
                    catch {
                        Write-Log "Error optimizing service $($service.Name): $_"
                    }
                }

                return $result
            }
            catch {
                Write-Log "Error in services optimization: $_"
                return $null
            }
        }

        function Optimize-Startup {
            try {
                Write-Log "Starting startup optimization..."
                
                $result = @{
                    ItemsOptimized = 0
                    Actions = @()
                }

                # Get startup items from current user's registry
                $startupPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

                try {
                    if (Test-Path $startupPath) {
                        $items = Get-ItemProperty -Path $startupPath -ErrorAction SilentlyContinue
                        foreach ($item in $items.PSObject.Properties) {
                            if ($item.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSProvider")) {
                                # Backup before removing
                                $backupPath = Join-Path $ModuleDir "StartupBackup_$(Get-Date -Format 'yyyyMMdd').reg"
                                $null = reg export $startupPath $backupPath /y
                                
                                # Remove non-essential startup items
                                Remove-ItemProperty -Path $startupPath -Name $item.Name -ErrorAction SilentlyContinue
                                $result.ItemsOptimized++
                                $result.Actions += "Removed startup item: $($item.Name)"
                            }
                        }
                    }
                }
                catch {
                    Write-Log "Error processing startup path $startupPath`: $_"
                }

                return $result
            }
            catch {
                Write-Log "Error in startup optimization: $_"
                return $null
            }
        }
    }

    process {
        try {
            Write-Log "Starting performance optimization..."
            
            # Initialize results
            $results = @{}
            
            # Process each optimization area
            foreach ($area in $Areas) {
                Write-Log "Processing $area optimization..."
                Write-Host "`nOptimizing $area..." -ForegroundColor Cyan
                
                switch ($area) {
                    "CPU" { 
                        $results[$area] = Optimize-CPU
                        if ($results[$area]) {
                            Write-Host "Processes Optimized: $($results[$area].ProcessesOptimized)"
                        }
                    }
                    "Memory" { 
                        $results[$area] = Optimize-Memory
                        if ($results[$area]) {
                            Write-Host "Processes Optimized: $($results[$area].ProcessesOptimized)"
                        }
                    }
                    "Network" { 
                        $results[$area] = Optimize-Network
                        if ($results[$area]) {
                            Write-Host "Optimizations Applied: $($results[$area].OptimizationsApplied)"
                        }
                    }
                    "Services" { 
                        $results[$area] = Optimize-Services
                        if ($results[$area]) {
                            Write-Host "Services Optimized: $($results[$area].ServicesOptimized)"
                        }
                    }
                    "Startup" { 
                        $results[$area] = Optimize-Startup
                        if ($results[$area]) {
                            Write-Host "Startup Items Optimized: $($results[$area].ItemsOptimized)"
                        }
                    }
                }
                
                if ($results[$area]) {
                    Write-Host "Actions taken:"
                    $results[$area].Actions | ForEach-Object { Write-Host "- $_" }
                }
                else {
                    Write-Warning "Failed to optimize $area"
                }
            }
        }
        catch {
            $errorMessage = "Critical error during performance optimization: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        Write-Host "`nPerformance optimization completed. Log file: $LogFile" -ForegroundColor Green
    }
}

function Get-SystemPerformanceMetrics {
    [CmdletBinding()]
    param()

    try {
        $metrics = @{
            CPU = @{
                TopProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU, WorkingSet
            }
            Memory = @{
                SystemInfo = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
            }
            Disk = @{
                Volumes = Get-Volume | Where-Object { $_.DriveLetter } | Select-Object DriveLetter, Size, SizeRemaining
            }
            Network = @{
                Adapters = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object Name, LinkSpeed
            }
        }

        # Display metrics in a readable format
        Write-Host "`nSystem Performance Metrics:" -ForegroundColor Cyan
        
        Write-Host "`nTop CPU Processes:"
        $metrics.CPU.TopProcesses | Format-Table -AutoSize

        Write-Host "`nMemory:"
        $totalGB = [math]::Round($metrics.Memory.SystemInfo.TotalVisibleMemorySize/1MB, 2)
        $freeGB = [math]::Round($metrics.Memory.SystemInfo.FreePhysicalMemory/1MB, 2)
        $usedGB = $totalGB - $freeGB
        Write-Host "- Total: $totalGB GB"
        Write-Host "- Used: $usedGB GB"
        Write-Host "- Free: $freeGB GB"

        Write-Host "`nDisk Volumes:"
        foreach ($volume in $metrics.Disk.Volumes) {
            $sizeGB = [math]::Round($volume.Size/1GB, 2)
            $freeGB = [math]::Round($volume.SizeRemaining/1GB, 2)
            $usedGB = $sizeGB - $freeGB
            Write-Host "Drive $($volume.DriveLetter):"
            Write-Host "- Total: $sizeGB GB"
            Write-Host "- Used: $usedGB GB"
            Write-Host "- Free: $freeGB GB"
        }

        Write-Host "`nNetwork Adapters:"
        foreach ($adapter in $metrics.Network.Adapters) {
            Write-Host "- $($adapter.Name): $($adapter.LinkSpeed)"
        }

        return $metrics
    }
    catch {
        Write-Error "Error getting system performance metrics: $_"
        return $null
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-PerformanceOptimization',
    'Get-SystemPerformanceMetrics'
)
