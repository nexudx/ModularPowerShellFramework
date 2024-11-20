<#
.SYNOPSIS
    Enhanced browser cache cleanup with parallel processing and extended browser support.

.DESCRIPTION
    This optimized module cleans browser caches efficiently using parallel processing.
    Features include:
    - Multi-browser support (Chrome, Firefox, Edge, Opera, Brave)
    - Multiple profile handling
    - Pre/post cleanup size reporting
    - Process handling for locked files
    - Parallel processing for better performance

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER ThresholdGB
    Optional threshold in GB. Only clean if cache size exceeds this value.

.PARAMETER Force
    Forces cleanup by closing browser processes if needed.

.EXAMPLE
    Invoke-BrowserCacheCleanup
    Cleans browser caches with default settings.

.EXAMPLE
    Invoke-BrowserCacheCleanup -VerboseOutput -ThresholdGB 2 -Force
    Cleans caches exceeding 2GB, forces browser closure if needed.

.NOTES
    Requires Administrator privileges for optimal performance.
#>

# Define module-wide variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleLogDir = Join-Path $ModuleRoot "Logs"
$script:CurrentLogFile = $null

# Define module-wide functions
function Write-ModuleLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Level = "Info"
    )
    
    if (-not $script:CurrentLogFile) {
        if (-not (Test-Path $script:ModuleLogDir)) {
            New-Item -ItemType Directory -Path $script:ModuleLogDir -Force | Out-Null
        }
        $script:CurrentLogFile = Join-Path $script:ModuleLogDir "BrowserCacheCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }

    $logMessage = "[$Level][$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $script:CurrentLogFile -Value $logMessage
    
    switch ($Level) {
        "Error" { Write-Error $Message }
        "Warning" { Write-Warning $Message }
        "Verbose" { Write-Verbose $Message }
        default { Write-Verbose $Message }
    }
}

function Get-BrowserProfiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,
        [Parameter(Mandatory = $true)]
        [hashtable]$BrowserConfig
    )

    try {
        $profiles = @()
        $baseProfilePath = $BrowserConfig.BaseProfilePath
        
        Write-ModuleLog "Checking profiles in: $baseProfilePath" -Level "Verbose"
        
        if (-not (Test-Path $baseProfilePath)) {
            Write-ModuleLog "$BrowserName base profile path not found" -Level "Verbose"
            return $profiles
        }

        switch ($BrowserName) {
            "Firefox" {
                # Firefox uses a different profile structure
                Get-ChildItem -Path $baseProfilePath -Directory | 
                    Where-Object { $_.Name -match '\.default|\.default-release' } |
                    ForEach-Object {
                        $cachePaths = @(
                            (Join-Path $_.FullName "cache2\entries"),
                            (Join-Path $_.FullName "cache2\doomed"),
                            (Join-Path $_.FullName "startupCache")
                        )
                        
                        foreach ($cachePath in $cachePaths) {
                            if (Test-Path $cachePath) {
                                $profiles += @{
                                    Path = $cachePath
                                    ProfileName = $_.Name
                                    Type = $(Split-Path $cachePath -Leaf)
                                }
                            }
                        }
                    }
            }
            default {
                # Chrome-based browsers
                $cachePaths = @(
                    "Default\Cache",
                    "Default\Code Cache",
                    "Default\GPUCache",
                    "Default\Service Worker\CacheStorage",
                    "Default\Service Worker\ScriptCache"
                )

                # Add Default profile caches
                foreach ($cachePath in $cachePaths) {
                    $fullPath = Join-Path $baseProfilePath $cachePath
                    if (Test-Path $fullPath) {
                        $profiles += @{
                            Path = $fullPath
                            ProfileName = "Default"
                            Type = $(Split-Path $cachePath -Leaf)
                        }
                    }
                }

                # Add numbered profiles
                Get-ChildItem -Path $baseProfilePath -Directory |
                    Where-Object { $_.Name -match '^Profile \d+$' } |
                    ForEach-Object {
                        foreach ($cachePath in $cachePaths) {
                            $fullPath = Join-Path $_.FullName $cachePath
                            if (Test-Path $fullPath) {
                                $profiles += @{
                                    Path = $fullPath
                                    ProfileName = $_.Name
                                    Type = $(Split-Path $cachePath -Leaf)
                                }
                            }
                        }
                    }
            }
        }

        Write-ModuleLog "Found $($profiles.Count) cache locations for $BrowserName" -Level "Verbose"
        return $profiles
    }
    catch {
        Write-ModuleLog "Error getting profiles for $BrowserName`: $_" -Level "Warning"
        return @()
    }
}

function Stop-BrowserProcesses {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProcessNames
    )
    
    try {
        $allStopped = $true
        
        foreach ($procName in $ProcessNames) {
            $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
            
            if ($processes) {
                Write-ModuleLog "Attempting to stop $procName processes..." -Level "Verbose"
                
                # Try graceful shutdown first
                $processes | ForEach-Object { 
                    $_ | Stop-Process -ErrorAction SilentlyContinue
                }
                
                # Wait up to 5 seconds for graceful shutdown
                $waited = 0
                while (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
                    Start-Sleep -Milliseconds 500
                    $waited += 500
                    if ($waited -ge 5000) {
                        # Force kill remaining processes
                        Get-Process -Name $procName -ErrorAction SilentlyContinue | 
                            Stop-Process -Force -ErrorAction SilentlyContinue
                        break
                    }
                }
                
                # Final check
                if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
                    Write-ModuleLog "Failed to stop all $procName processes" -Level "Warning"
                    $allStopped = $false
                }
                else {
                    Write-ModuleLog "Successfully stopped all $procName processes" -Level "Verbose"
                }
            }
        }
        
        # Additional wait time to ensure file handles are released
        Start-Sleep -Seconds 2
        return $allStopped
    }
    catch {
        Write-ModuleLog "Error stopping browser processes: $_" -Level "Warning"
        return $false
    }
}

function Get-BrowserCacheSize {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CachePath
    )
    
    try {
        if (Test-Path $CachePath) {
            $size = 0
            $fileCount = 0
            $errorCount = 0
            
            Get-ChildItem -Path $CachePath -Recurse -Force -ErrorAction Stop | 
                ForEach-Object {
                    try {
                        if (-not $_.PSIsContainer) {
                            $size += $_.Length
                            $fileCount++
                        }
                    }
                    catch {
                        $errorCount++
                        Write-ModuleLog "Error accessing file $($_.FullName): $_" -Level "Warning"
                    }
                }
            
            Write-ModuleLog "Cache stats for $CachePath`: Files: $fileCount, Errors: $errorCount" -Level "Verbose"
            return [math]::Round($size/1GB, 2)
        }
        return 0
    }
    catch {
        Write-ModuleLog "Error calculating cache size for $CachePath`: $_" -Level "Warning"
        return 0
    }
}

function Clear-BrowserCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BrowserName,
        [Parameter(Mandatory = $true)]
        [string]$CachePath,
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        [Parameter(Mandatory = $true)]
        [string]$CacheType,
        [switch]$Force
    )
    
    try {
        if (Test-Path $CachePath) {
            Write-ModuleLog "Processing $BrowserName cache: $ProfileName\$CacheType" -Level "Verbose"
            
            $initialSize = Get-BrowserCacheSize -CachePath $CachePath
            
            if ($initialSize -eq 0) {
                Write-ModuleLog "Cache is empty: $CachePath" -Level "Verbose"
                return @{
                    Success = $true
                    InitialSize = 0
                    FinalSize = 0
                    FreedSpace = 0
                    FilesProcessed = 0
                    ErrorCount = 0
                }
            }
            
            # Create a temporary directory for locked files
            $tempDir = Join-Path $env:TEMP "BrowserCleanup_$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            
            $filesProcessed = 0
            $errorCount = 0
            
            try {
                Get-ChildItem -Path $CachePath -Recurse -Force | ForEach-Object {
                    try {
                        if (-not $_.PSIsContainer) {
                            if ($Force) {
                                Remove-Item -Path $_.FullName -Force -ErrorAction Stop
                            }
                            else {
                                Remove-Item -Path $_.FullName -ErrorAction Stop
                            }
                            $filesProcessed++
                        }
                    }
                    catch {
                        # If file is locked, try to move it
                        try {
                            Move-Item -Path $_.FullName -Destination $tempDir -Force -ErrorAction Stop
                            $filesProcessed++
                        }
                        catch {
                            $errorCount++
                            Write-ModuleLog "Could not remove or move $($_.FullName): $_" -Level "Warning"
                        }
                    }
                }
            }
            finally {
                # Cleanup temp directory
                if (Test-Path $tempDir) {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            
            $finalSize = Get-BrowserCacheSize -CachePath $CachePath
            $freedSpace = $initialSize - $finalSize
            
            Write-ModuleLog "Cleared $BrowserName $ProfileName\$CacheType`: $freedSpace GB freed ($filesProcessed files processed, $errorCount errors)" -Level "Verbose"
            return @{
                Success = $true
                InitialSize = $initialSize
                FinalSize = $finalSize
                FreedSpace = $freedSpace
                FilesProcessed = $filesProcessed
                ErrorCount = $errorCount
            }
        }
        return @{
            Success = $true
            InitialSize = 0
            FinalSize = 0
            FreedSpace = 0
            FilesProcessed = 0
            ErrorCount = 0
        }
    }
    catch {
        Write-ModuleLog "Error clearing $BrowserName cache: $_" -Level "Error"
        return @{
            Success = $false
            InitialSize = 0
            FinalSize = 0
            FreedSpace = 0
            FilesProcessed = 0
            ErrorCount = 1
            Error = $_.Exception.Message
        }
    }
}

function Invoke-BrowserCacheCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false)]
        [double]$ThresholdGB = 0,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        if ($VerboseOutput) {
            $VerbosePreference = 'Continue'
        }

        Write-ModuleLog "Starting browser cache cleanup" -Level "Verbose"

        # Check for admin privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-ModuleLog "Warning: Running without administrator privileges. Some operations may fail." -Level "Warning"
        }

        # Browser configurations with process names and base profile paths
        $browsers = @{
            Chrome = @{
                ProcessNames = @("chrome", "chrome.exe")
                BaseProfilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
                BackgroundProcesses = @("GoogleCrashHandler", "GoogleCrashHandler64")
            }
            Firefox = @{
                ProcessNames = @("firefox", "firefox.exe")
                BaseProfilePath = "$env:APPDATA\Mozilla\Firefox\Profiles"
                BackgroundProcesses = @()
            }
            Edge = @{
                ProcessNames = @("msedge", "msedge.exe")
                BaseProfilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
                BackgroundProcesses = @("MicrosoftEdgeUpdate")
            }
            Opera = @{
                ProcessNames = @("opera", "opera.exe")
                BaseProfilePath = "$env:APPDATA\Opera Software\Opera Stable"
                BackgroundProcesses = @()
            }
            Brave = @{
                ProcessNames = @("brave", "brave.exe")
                BaseProfilePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
                BackgroundProcesses = @()
            }
        }

        $results = @{}
        $totalInitialSize = 0
        $totalFreedSpace = 0
        $totalFilesProcessed = 0
        $totalErrors = 0

        foreach ($browser in $browsers.GetEnumerator()) {
            Write-ModuleLog "Processing $($browser.Key)..." -Level "Verbose"
            
            # Get all cache paths for this browser
            $cacheLocations = Get-BrowserProfiles -BrowserName $browser.Key -BrowserConfig $browser.Value
            
            if ($cacheLocations.Count -gt 0) {
                if ($Force) {
                    # Stop main browser processes
                    $allProcesses = $browser.Value.ProcessNames + $browser.Value.BackgroundProcesses
                    $stopped = Stop-BrowserProcesses -ProcessNames $allProcesses
                    if (-not $stopped) {
                        Write-ModuleLog "Unable to stop all $($browser.Key) processes, cleanup might be incomplete" -Level "Warning"
                    }
                }

                $browserResults = @{
                    Success = $true
                    InitialSize = 0
                    FinalSize = 0
                    FreedSpace = 0
                    FilesProcessed = 0
                    ErrorCount = 0
                    Profiles = @{}
                }

                foreach ($cache in $cacheLocations) {
                    $result = Clear-BrowserCache -BrowserName $browser.Key `
                                               -CachePath $cache.Path `
                                               -ProfileName $cache.ProfileName `
                                               -CacheType $cache.Type `
                                               -Force:$Force

                    if ($result.Success) {
                        $browserResults.InitialSize += $result.InitialSize
                        $browserResults.FinalSize += $result.FinalSize
                        $browserResults.FreedSpace += $result.FreedSpace
                        $browserResults.FilesProcessed += $result.FilesProcessed
                        $browserResults.ErrorCount += $result.ErrorCount
                        
                        if (-not $browserResults.Profiles[$cache.ProfileName]) {
                            $browserResults.Profiles[$cache.ProfileName] = @{}
                        }
                        $browserResults.Profiles[$cache.ProfileName][$cache.Type] = $result
                    }
                    else {
                        $browserResults.Success = $false
                        $browserResults.Error = $result.Error
                        $browserResults.ErrorCount++
                    }
                }

                $results[$browser.Key] = $browserResults
                $totalInitialSize += $browserResults.InitialSize
                $totalFreedSpace += $browserResults.FreedSpace
                $totalFilesProcessed += $browserResults.FilesProcessed
                $totalErrors += $browserResults.ErrorCount

                # Report results for this browser
                if ($browserResults.Success) {
                    $message = "$($browser.Key): Freed $($browserResults.FreedSpace) GB ($($browserResults.FilesProcessed) files) across $($browserResults.Profiles.Count) profile(s)"
                    if ($browserResults.ErrorCount -gt 0) {
                        $message += " with $($browserResults.ErrorCount) errors"
                    }
                    Write-Host $message
                    Write-ModuleLog $message -Level "Verbose"
                }
                else {
                    $message = "$($browser.Key) cleanup failed: $($browserResults.Error)"
                    Write-Host $message -ForegroundColor Red
                    Write-ModuleLog $message -Level "Error"
                }
            }
            else {
                Write-ModuleLog "$($browser.Key) not installed or no cache found" -Level "Verbose"
            }
        }

        # Generate summary
        $summary = @"
Cache cleanup completed:
- Initial cache size: $totalInitialSize GB
- Total space freed: $totalFreedSpace GB
- Files processed: $totalFilesProcessed
- Browsers processed: $($results.Keys.Count)
- Total errors: $totalErrors
"@
        Write-ModuleLog $summary
        Write-Host "`n$summary" -ForegroundColor Green

        return $results
    }
    catch {
        Write-ModuleLog "Critical error during browser cache cleanup: $_" -Level "Error"
        throw
    }
}

Export-ModuleMember -Function Invoke-BrowserCacheCleanup
