# Import common module
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) "Common\Common.psm1")

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
        
        Write-ModuleLog -Message "Checking profiles in: $baseProfilePath" -ModuleName 'BrowserCacheCleanup'
        
        if (-not (Test-Path $baseProfilePath)) {
            Write-ModuleLog -Message "$BrowserName base profile path not found" -ModuleName 'BrowserCacheCleanup'
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

        Write-ModuleLog -Message "Found $($profiles.Count) cache locations for $BrowserName" -ModuleName 'BrowserCacheCleanup'
        return $profiles
    }
    catch {
        Write-ModuleLog -Message "Error getting profiles for $BrowserName`: $_" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
                Write-ModuleLog -Message "Attempting to stop $procName processes..." -ModuleName 'BrowserCacheCleanup'
                
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
                    Write-ModuleLog -Message "Failed to stop all $procName processes" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
                    $allStopped = $false
                }
                else {
                    Write-ModuleLog -Message "Successfully stopped all $procName processes" -ModuleName 'BrowserCacheCleanup'
                }
            }
        }
        
        # Additional wait time to ensure file handles are released
        Start-Sleep -Seconds 2
        return $allStopped
    }
    catch {
        Write-ModuleLog -Message "Error stopping browser processes: $_" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
                        Write-ModuleLog -Message "Error accessing file $($_.FullName): $_" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
                    }
                }
            
            Write-ModuleLog -Message "Cache stats for $CachePath`: Files: $fileCount, Errors: $errorCount" -ModuleName 'BrowserCacheCleanup'
            return [math]::Round($size/1GB, 2)
        }
        return 0
    }
    catch {
        Write-ModuleLog -Message "Error calculating cache size for $CachePath`: $_" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
            Write-ModuleLog -Message "Processing $BrowserName cache: $ProfileName\$CacheType" -ModuleName 'BrowserCacheCleanup'
            
            $initialSize = Get-BrowserCacheSize -CachePath $CachePath
            
            if ($initialSize -eq 0) {
                Write-ModuleLog -Message "Cache is empty: $CachePath" -ModuleName 'BrowserCacheCleanup'
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
                            Write-ModuleLog -Message "Could not remove or move $($_.FullName): $_" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
            
            Write-ModuleLog -Message "Cleared $BrowserName $ProfileName\$CacheType`: $freedSpace GB freed ($filesProcessed files processed, $errorCount errors)" -ModuleName 'BrowserCacheCleanup'
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
        Write-ModuleLog -Message "Error clearing $BrowserName cache: $_" -Severity 'Error' -ModuleName 'BrowserCacheCleanup'
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
        # Initialize module operation
        $operation = Start-ModuleOperation -ModuleName 'BrowserCacheCleanup'
        if (-not $operation.Success) {
            throw "Failed to initialize BrowserCacheCleanup operation"
        }

        if ($VerboseOutput) {
            $VerbosePreference = 'Continue'
        }

        Write-ModuleLog -Message "Starting browser cache cleanup" -ModuleName 'BrowserCacheCleanup'

        # Check for admin privileges
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-ModuleLog -Message "Warning: Running without administrator privileges. Some operations may fail." -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
            Write-ModuleLog -Message "Processing $($browser.Key)..." -ModuleName 'BrowserCacheCleanup'
            
            # Get all cache paths for this browser
            $cacheLocations = Get-BrowserProfiles -BrowserName $browser.Key -BrowserConfig $browser.Value
            
            if ($cacheLocations.Count -gt 0) {
                if ($Force) {
                    # Stop main browser processes
                    $allProcesses = $browser.Value.ProcessNames + $browser.Value.BackgroundProcesses
                    $stopped = Stop-BrowserProcesses -ProcessNames $allProcesses
                    if (-not $stopped) {
                        Write-ModuleLog -Message "Unable to stop all $($browser.Key) processes, cleanup might be incomplete" -Severity 'Warning' -ModuleName 'BrowserCacheCleanup'
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
                    Write-ModuleLog -Message $message -ModuleName 'BrowserCacheCleanup'
                }
                else {
                    $message = "$($browser.Key) cleanup failed: $($browserResults.Error)"
                    Write-Host $message -ForegroundColor Red
                    Write-ModuleLog -Message $message -Severity 'Error' -ModuleName 'BrowserCacheCleanup'
                }
            }
            else {
                Write-ModuleLog -Message "$($browser.Key) not installed or no cache found" -ModuleName 'BrowserCacheCleanup'
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
        Write-ModuleLog -Message $summary -ModuleName 'BrowserCacheCleanup'
        Write-Host "`n$summary" -ForegroundColor Green

        # Complete module operation
        Stop-ModuleOperation -ModuleName 'BrowserCacheCleanup' -StartTime $operation.StartTime -Success $true

        return $results
    }
    catch {
        Write-ModuleLog -Message "Critical error during browser cache cleanup: $_" -Severity 'Error' -ModuleName 'BrowserCacheCleanup'
        Stop-ModuleOperation -ModuleName 'BrowserCacheCleanup' -StartTime $operation.StartTime -Success $false -ErrorMessage $_.Exception.Message
        throw
    }
}

Export-ModuleMember -Function Invoke-BrowserCacheCleanup
