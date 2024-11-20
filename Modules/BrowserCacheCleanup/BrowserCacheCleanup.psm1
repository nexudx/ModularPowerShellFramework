<#
.SYNOPSIS
    Bereinigt die Browser-Caches gängiger Webbrowser.

.DESCRIPTION
    Dieses Modul bietet Funktionen zur Bereinigung der Caches von weit verbreiteten Webbrowsern,
    einschließlich Google Chrome, Mozilla Firefox, Microsoft Edge und Brave Browser.

.PARAMETER ModuleVerbose
    Aktiviert ausführliche Ausgaben für detaillierte Operationsinformationen.

.EXAMPLE
    Invoke-BrowserCacheCleanup -ModuleVerbose
    Bereinigt die Browser-Caches mit aktiviertem ausführlichem Output.

.NOTES
    Stellen Sie sicher, dass das Skript mit angemessenen Berechtigungen ausgeführt wird, um auf die Browser-Cache-Verzeichnisse zugreifen zu können.
#>
function BrowserCacheCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    begin {
        # Initialisierungscode
        # Bestimmen des Modulverzeichnisses
        $ModuleDirectory = Split-Path $PSCommandPath -Parent

        # Erstellen eines Log-Dateipfads
        $LogFilePath = Join-Path $ModuleDirectory "BrowserCacheCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        try {
            # Starten des Loggings
            Start-Transcript -Path $LogFilePath -Append
        }
        catch {
            Write-Warning "Konnte das Logging nicht starten: $_"
        }

        # Initialisieren der Liste der bereinigten Browser
        $CleanedBrowsers = @()
    }

    process {
        try {
            if ($ModuleVerbose) { Write-Verbose "Starte Browser-Cache-Bereinigung..." }

            # Bereinigen des Google Chrome Caches
            if ($ModuleVerbose) { Write-Verbose "Bereinige Google Chrome Cache..." }
            $chromeCachePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\"
            if (Test-Path $chromeCachePath) {
                Remove-Item -Path "${chromeCachePath}*" -Recurse -Force -ErrorAction SilentlyContinue
                $CleanedBrowsers += "Google Chrome"
            }

            # Bereinigen des Mozilla Firefox Caches
            if ($ModuleVerbose) { Write-Verbose "Bereinige Mozilla Firefox Cache..." }
            $firefoxProfilesPath = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles\'
            if (Test-Path $firefoxProfilesPath) {
                Get-ChildItem -Path $firefoxProfilesPath -Directory | ForEach-Object {
                    $cacheDir = Join-Path $_.FullName 'cache2'
                    if (Test-Path $cacheDir) {
                        Remove-Item -Path "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                        if ($CleanedBrowsers -notcontains "Mozilla Firefox") {
                            $CleanedBrowsers += "Mozilla Firefox"
                        }
                    }
                }
            }

            # Bereinigen des Microsoft Edge Caches
            if ($ModuleVerbose) { Write-Verbose "Bereinige Microsoft Edge Cache..." }
            $edgeCachePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\"
            if (Test-Path $edgeCachePath) {
                Remove-Item -Path "${edgeCachePath}*" -Recurse -Force -ErrorAction SilentlyContinue
                $CleanedBrowsers += "Microsoft Edge"
            }

            # Bereinigen des Brave Browser Caches
            if ($ModuleVerbose) { Write-Verbose "Bereinige Brave Browser Cache..." }
            $braveCachePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\"
            if (Test-Path $braveCachePath) {
                Remove-Item -Path "${braveCachePath}*" -Recurse -Force -ErrorAction SilentlyContinue
                $CleanedBrowsers += "Brave Browser"
            }

            if ($CleanedBrowsers.Count -gt 0) {
                Write-Output "Browser-Cache-Bereinigung erfolgreich abgeschlossen. Bereinigte Browser: $($CleanedBrowsers -join ', ')."
            }
            else {
                Write-Output "Keine Browser-Caches wurden bereinigt."
            }
        }
        catch {
            Write-Error "Browser-Cache-Bereinigung fehlgeschlagen: $_"
        }
    }

    end {
        # Cleanup-Code
        try {
            # Stoppen des Loggings
            Stop-Transcript
        }
        catch {
            Write-Warning "Konnte das Logging nicht beenden: $_"
        }
    }
}

# Proxy-Funktion zur Handhabung des -ModuleVerbose Parameters
function Invoke-BrowserCacheCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Übergabe der Parameter an die BrowserCacheCleanup-Funktion mittels Splatting
    BrowserCacheCleanup @PSBoundParameters
}

# Exportieren der Proxy-Funktion
Export-ModuleMember -Function Invoke-BrowserCacheCleanup
