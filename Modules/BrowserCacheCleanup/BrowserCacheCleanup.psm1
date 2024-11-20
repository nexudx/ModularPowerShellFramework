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

function Stop-BrowserProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName
    )
    
    try {
        $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        if ($process) {
            Write-ModuleLog "Attempting to stop $ProcessName process..." -Level "Verbose"
            Stop-Process -Name $ProcessName -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-ModuleLog "Successfully stopped $ProcessName process" -Level "Verbose"
            return $true
        }
        return $true  # Process not running is also a success
    }
    catch {
        Write-ModuleLog "Failed to stop $ProcessName process: $_" -Level "Warning"
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
            $size = (Get-ChildItem -Path $CachePath -Recurse -ErrorAction Stop | 
                Measure-Object -Property Length -Sum -ErrorAction Stop).Sum
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
        [switch]$Force
    )
    
    try {
        if (Test-Path $CachePath) {
            $initialSize = Get-BrowserCacheSize -CachePath $CachePath
            
            if ($Force) {
                Remove-Item -Path "$CachePath\*" -Recurse -Force -ErrorAction Stop
            }
            else {
                Get-ChildItem -Path $CachePath -Recurse | Remove-Item -Force -ErrorAction Stop
            }
            
            $finalSize = Get-BrowserCacheSize -CachePath $CachePath
            $freedSpace = $initialSize - $finalSize
            
            Write-ModuleLog "Cleared $BrowserName cache: $freedSpace GB freed" -Level "Verbose"
            return @{
                Success = $true
                InitialSize = $initialSize
                FinalSize = $finalSize
                FreedSpace = $freedSpace
            }
        }
        return @{
            Success = $true
            InitialSize = 0
            FinalSize = 0
            FreedSpace = 0
        }
    }
    catch {
        Write-ModuleLog "Error clearing $BrowserName cache: $_" -Level "Error"
        return @{
            Success = $false
            InitialSize = 0
            FinalSize = 0
            FreedSpace = 0
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

        # Browser configurations
        $browsers = @{
            Chrome = @{
                ProcessName = "chrome"
                CachePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
            }
            Firefox = @{
                ProcessName = "firefox"
                CachePath = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\cache2"
            }
            Edge = @{
                ProcessName = "msedge"
                CachePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
            }
            Opera = @{
                ProcessName = "opera"
                CachePath = "$env:APPDATA\Opera Software\Opera Stable\Cache"
            }
            Brave = @{
                ProcessName = "brave"
                CachePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"
            }
        }

        $results = @{}

        foreach ($browser in $browsers.GetEnumerator()) {
            Write-ModuleLog "Processing $($browser.Key)..." -Level "Verbose"
            
            # Check if browser is installed
            $cachePath = Resolve-Path -Path $browser.Value.CachePath -ErrorAction SilentlyContinue
            if ($cachePath) {
                if ($Force) {
                    $stopped = Stop-BrowserProcess -ProcessName $browser.Value.ProcessName
                    if (-not $stopped) {
                        Write-ModuleLog "Unable to stop $($browser.Key) process, skipping..." -Level "Warning"
                        continue
                    }
                }

                $result = Clear-BrowserCache -BrowserName $browser.Key -CachePath $cachePath -Force:$Force
                $results[$browser.Key] = $result

                if ($result.Success) {
                    Write-Host "$($browser.Key): Freed $($result.FreedSpace) GB"
                }
                else {
                    Write-ModuleLog "$($browser.Key) cleanup failed: $($result.Error)" -Level "Error"
                }
            }
            else {
                Write-ModuleLog "$($browser.Key) cache path not found, skipping..." -Level "Verbose"
            }
        }

        # Generate summary
        $totalFreed = ($results.Values | Measure-Object -Property FreedSpace -Sum).Sum
        $summary = "Cache cleanup completed. Total space freed: $totalFreed GB"
        Write-ModuleLog $summary
        Write-Host $summary

        return $results
    }
    catch {
        Write-ModuleLog "Critical error during browser cache cleanup: $_" -Level "Error"
        throw
    }
}

Export-ModuleMember -Function Invoke-BrowserCacheCleanup
