<#
.SYNOPSIS
    Enhanced temporary file cleanup with advanced filtering and reporting.

.DESCRIPTION
    This optimized module provides comprehensive temporary file cleanup with:
    - Multiple temp locations support
    - File age and type filtering
    - Exclusion patterns
    - Parallel processing
    - Space usage tracking
    - Detailed logging
    - File locking detection
    - Safe deletion practices

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER MinimumAge
    Only clean files older than specified days.

.PARAMETER FileTypes
    Array of file extensions to clean (e.g., "*.tmp", "*.log").

.PARAMETER ExcludePatterns
    Array of patterns to exclude from cleanup.

.PARAMETER Force
    Skips confirmation prompts for deletions.

.PARAMETER MaxParallelJobs
    Maximum number of parallel cleanup jobs (default: 2).

.EXAMPLE
    Invoke-TempFileCleanup
    Performs basic temporary file cleanup.

.EXAMPLE
    Invoke-TempFileCleanup -MinimumAge 7 -FileTypes "*.tmp","*.log"
    Cleans temp files older than 7 days with specific extensions.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose output")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Minimum age in days")]
        [ValidateRange(0, 365)]
        [int]$MinimumAge = 0,

        [Parameter(Mandatory = $false,
                   HelpMessage = "File types to clean")]
        [ValidatePattern('^\*\.[a-zA-Z0-9]+$')]
        [string[]]$FileTypes,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Patterns to exclude")]
        [string[]]$ExcludePatterns,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Skip confirmation prompts")]
        [switch]$Force,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Maximum parallel jobs")]
        [ValidateRange(1, 4)]
        [int]$MaxParallelJobs = 2
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
        $script:LogFile = Join-Path $ModuleDir "TempFileCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $script:LogMutex = New-Object System.Threading.Mutex($false, "GlobalTempFileCleanupLogMutex")

        function Write-CleanupLog {
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

        # Define temp locations to clean with safety checks
        $script:TempLocations = @{
            "Windows Temp" = @{
                Path = "$env:windir\Temp"
                Description = "Windows temporary files"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\Temp" -and (Test-Path $env:windir)
                }
            }
            "User Temp" = @{
                Path = $env:TEMP
                Description = "User temporary files"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\Temp" -and $Path -notlike "$env:windir*"
                }
            }
            "Prefetch" = @{
                Path = "$env:windir\Prefetch"
                Description = "Windows prefetch files"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\Prefetch" -and (Test-Path $env:windir)
                }
            }
            "Recent" = @{
                Path = [Environment]::GetFolderPath('Recent')
                Description = "Recently accessed files"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\Recent"
                }
            }
            "Thumbnails" = @{
                Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                Description = "Windows thumbnail cache"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\Explorer" -and (Test-Path $env:LOCALAPPDATA)
                }
            }
            "IIS Logs" = @{
                Path = "$env:SystemDrive\inetpub\logs\LogFiles"
                Description = "IIS log files"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\LogFiles" -and (Test-Path "$env:SystemDrive\inetpub")
                }
            }
            "Windows CBS Logs" = @{
                Path = "$env:windir\Logs\CBS"
                Description = "Windows component store logs"
                SafetyCheck = {
                    param($Path)
                    return $Path -like "*\CBS" -and (Test-Path "$env:windir\Logs")
                }
            }
        }

        function Test-FileLock {
            param([string]$Path)
            
            try {
                $file = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
                $file.Close()
                $file.Dispose()
                return $false
            }
            catch {
                return $true
            }
        }

        function Get-FileFilter {
            $filter = {$true}
            
            if ($MinimumAge -gt 0) {
                $cutoffDate = (Get-Date).AddDays(-$MinimumAge)
                $filter = {$_.LastWriteTime -lt $cutoffDate}
            }
            
            if ($FileTypes) {
                $filter = {
                    $_.LastWriteTime -lt $cutoffDate -and
                    ($FileTypes | ForEach-Object {$_.Name -like $_}) -contains $true
                }
            }
            
            if ($ExcludePatterns) {
                $filter = {
                    $_.LastWriteTime -lt $cutoffDate -and
                    ($FileTypes | ForEach-Object {$_.Name -like $_}) -contains $true -and
                    ($ExcludePatterns | ForEach-Object {$_.FullName -notlike $_}) -notcontains $false
                }
            }
            
            return $filter
        }

        function Remove-TempFiles {
            param(
                [string]$Path,
                [scriptblock]$Filter,
                [string]$LocationName
            )
            
            try {
                # Verify location safety
                $safetyCheck = $script:TempLocations[$LocationName].SafetyCheck
                if (-not (& $safetyCheck $Path)) {
                    throw "Safety check failed for location: $Path"
                }

                # Get files matching filter
                $files = Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object $Filter

                $result = @{
                    LocationName = $LocationName
                    FilesFound = $files.Count
                    SizeFound = ($files | Measure-Object -Property Length -Sum).Sum
                    FilesDeleted = 0
                    SizeDeleted = 0
                    LockedFiles = 0
                    Errors = @()
                }

                foreach ($file in $files) {
                    try {
                        # Check if file is locked
                        if (Test-FileLock -Path $file.FullName) {
                            $result.LockedFiles++
                            $result.Errors += "File locked: $($file.FullName)"
                            continue
                        }

                        # Safe delete with retry
                        $retryCount = 3
                        $deleted = $false
                        
                        while (-not $deleted -and $retryCount -gt 0) {
                            try {
                                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                $deleted = $true
                                $result.FilesDeleted++
                                $result.SizeDeleted += $file.Length
                            }
                            catch {
                                $retryCount--
                                if ($retryCount -eq 0) {
                                    throw
                                }
                                Start-Sleep -Milliseconds 100
                            }
                        }
                    }
                    catch {
                        $result.Errors += "Failed to delete $($file.FullName): $_"
                    }
                }

                return $result
            }
            catch {
                Write-CleanupLog "Error processing $LocationName`: $_" -Severity 'Error'
                return @{
                    LocationName = $LocationName
                    FilesFound = 0
                    SizeFound = 0
                    FilesDeleted = 0
                    SizeDeleted = 0
                    LockedFiles = 0
                    Errors = @("Failed to process directory: $_")
                }
            }
        }
    }

    process {
        try {
            Write-CleanupLog "Starting enhanced temporary file cleanup..."
            
            # Get file filter based on parameters
            $filter = Get-FileFilter
            
            # Process locations in parallel with job throttling
            $jobs = @()
            $results = @{}
            
            foreach ($location in $script:TempLocations.GetEnumerator()) {
                Write-CleanupLog "Queuing cleanup for $($location.Key)..."
                
                if (Test-Path $location.Value.Path) {
                    # Wait if max jobs reached
                    while ($jobs.Count -ge $MaxParallelJobs) {
                        $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
                        foreach ($job in $completed) {
                            $results[$job.Location] = Receive-Job -Job $job.Job
                            Remove-Job -Job $job.Job
                            $jobs = $jobs | Where-Object { $_ -ne $job }
                        }
                        if ($jobs.Count -ge $MaxParallelJobs) {
                            Start-Sleep -Milliseconds 100
                        }
                    }

                    # Start new job
                    $job = Start-Job -ScriptBlock ${function:Remove-TempFiles} -ArgumentList @(
                        $location.Value.Path,
                        $filter,
                        $location.Key
                    )
                    
                    $jobs += @{
                        Job = $job
                        Location = $location.Key
                    }
                }
                else {
                    Write-CleanupLog "Location not found: $($location.Value.Path)" -Severity 'Warning'
                }
            }

            # Wait for remaining jobs
            while ($jobs.Count -gt 0) {
                $completed = $jobs | Where-Object { $_.State -eq 'Completed' }
                foreach ($job in $completed) {
                    $results[$job.Location] = Receive-Job -Job $job.Job
                    Remove-Job -Job $job.Job
                    $jobs = $jobs | Where-Object { $_ -ne $job }
                }
                if ($jobs.Count -gt 0) {
                    Start-Sleep -Milliseconds 100
                }
            }

            # Process and display results
            $totalSaved = 0
            $totalFiles = 0
            $totalLocked = 0
            $totalErrors = 0

            foreach ($result in $results.Values) {
                $summary = @"
$($result.LocationName) Results:
Files Found: $($result.FilesFound)
Size Found: $([math]::Round($result.SizeFound/1MB, 2)) MB
Files Deleted: $($result.FilesDeleted)
Size Deleted: $([math]::Round($result.SizeDeleted/1MB, 2)) MB
Locked Files: $($result.LockedFiles)
"@
                Write-CleanupLog $summary
                Write-Host $summary

                if ($result.Errors.Count -gt 0) {
                    foreach ($error in $result.Errors) {
                        Write-CleanupLog "ERROR: $error" -Severity 'Warning'
                    }
                }

                $totalSaved += $result.SizeDeleted
                $totalFiles += $result.FilesDeleted
                $totalLocked += $result.LockedFiles
                $totalErrors += $result.Errors.Count
            }

            # Display final summary
            $finalSummary = @"

Cleanup Complete:
Total Files Deleted: $totalFiles
Total Space Saved: $([math]::Round($totalSaved/1MB, 2)) MB
Total Locked Files: $totalLocked
Total Errors: $totalErrors
"@
            Write-CleanupLog $finalSummary
            Write-Host $finalSummary
        }
        catch {
            $errorMessage = "Critical error during temporary file cleanup: $_"
            Write-CleanupLog $errorMessage -Severity 'Error'
            throw $errorMessage
        }
    }

    end {
        Write-CleanupLog "Temporary file cleanup completed. Log file: $LogFile"
        Write-Host "Temporary file cleanup completed. Log file: $LogFile"
        
        # Cleanup
        if ($script:LogMutex) {
            $script:LogMutex.Dispose()
        }
    }
}

# Export module members
Export-ModuleMember -Function Invoke-TempFileCleanup
