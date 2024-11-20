<#
.SYNOPSIS
    Cleans browser caches with detailed console and log outputs.

.DESCRIPTION
    This module cleans the caches of installed browsers to free up space and improve privacy. During the process, detailed information about the steps performed, results, and any errors are displayed and logged.

.PARAMETER VerboseOutput
    Enables verbose console output.

.EXAMPLE
    Invoke-BrowserCacheCleanup
    Cleans browser caches with default settings and provides informative outputs.

.EXAMPLE
    Invoke-BrowserCacheCleanup -VerboseOutput
    Cleans browser caches and displays additional verbose information.

.NOTES
    This module has been enhanced to make console and log outputs significantly more informative. It follows PowerShell Best Practices and implements robust error handling and logging.

#>

function Invoke-BrowserCacheCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose console output.")]
        [switch]$VerboseOutput
    )

    begin {
        # Configuration of verbose output
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        # Initialization of the log file
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "BrowserCacheCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initializing browser cache cleanup..."
        Write-Verbose "Log file will be created at: $LogFile"
        "[$(Get-Date)] - Browser cache cleanup started." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Determining installed browsers..."
            Write-Information "Browser cache cleanup is starting." -InformationAction Continue
            Write-Host "Starting browser cache cleanup..."

            $browsers = @('Chrome', 'Firefox', 'Edge')
            foreach ($browser in $browsers) {
                Write-Verbose "Checking installation of $browser..."
                switch ($browser) {
                    'Chrome' {
                        $cachePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
                    }
                    'Firefox' {
                        $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
                        $profileDirs = Get-ChildItem -Path $profilesPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*.default*' }
                        $cachePaths = $profileDirs | ForEach-Object { Join-Path -Path $_.FullName -ChildPath 'cache2' }
                    }
                    'Edge' {
                        $cachePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
                    }
                    default {
                        $cachePath = $null
                    }
                }

                if ($browser -eq 'Firefox' -and $cachePaths) {
                    foreach ($path in $cachePaths) {
                        if (Test-Path $path) {
                            Write-Verbose "Cleaning cache for $browser at $path..."
                            Write-Host "Cleaning cache for $browser..."
                            Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            Write-Verbose "Cache for $browser cleaned."
                            "[$(Get-Date)] - Cache for $browser in profile $_.Name cleaned." | Add-Content -Path $LogFile
                        } else {
                            $WarningMessage = "Cache path for $browser ($path) was not found."
                            Write-Warning $WarningMessage
                            "[$(Get-Date)] - WARNING: $WarningMessage" | Add-Content -Path $LogFile
                        }
                    }
                } elseif ($cachePath -and (Test-Path $cachePath)) {
                    Write-Verbose "Cleaning cache for $browser at $cachePath..."
                    Write-Host "Cleaning cache for $browser..."
                    Get-ChildItem -Path $cachePath -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Verbose "Cache for $browser cleaned."
                    "[$(Get-Date)] - Cache for $browser cleaned." | Add-Content -Path $LogFile
                } else {
                    $WarningMessage = "Cache path for $browser was not found or $browser is not installed."
                    Write-Warning $WarningMessage
                    "[$(Get-Date)] - WARNING: $WarningMessage" | Add-Content -Path $LogFile
                }
            }

            Write-Verbose "Browser caches cleaned successfully."
            Write-Host "Browser caches have been cleaned successfully."
            "[$(Get-Date)] - Browser caches cleaned successfully." | Add-Content -Path $LogFile
        }
        catch {
            $ErrorMessage = "Error during browser cache cleanup: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Browser cache cleanup process completed."
        Write-Host "Browser cache cleanup process completed."
        "[$(Get-Date)] - Browser cache cleanup process completed." | Add-Content -Path $LogFile
        Write-Verbose "Details can be found in the log file: $LogFile"
    }
}
