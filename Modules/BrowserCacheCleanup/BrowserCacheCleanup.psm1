<#
.SYNOPSIS
    Bereinigt die Browser-Caches mit detaillierten Konsolen- und Logausgaben.

.DESCRIPTION
    Dieses Modul bereinigt die Caches von installierten Browsern, um Speicherplatz freizugeben und die Privatsphäre zu verbessern. Während des Prozesses werden detaillierte Informationen über die ausgeführten Schritte, Ergebnisse und etwaige Fehler ausgegeben und protokolliert.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Konsolenausgabe ein.

.EXAMPLE
    Invoke-BrowserCacheCleanup
    Bereinigt die Browser-Caches mit Standardeinstellungen und liefert informative Ausgaben.

.EXAMPLE
    Invoke-BrowserCacheCleanup -VerboseOutput
    Bereinigt die Browser-Caches und zeigt zusätzliche ausführliche Informationen an.

.NOTES
    Dieses Modul wurde erweitert, um die Konsolen- und Logausgaben deutlich informativer zu gestalten. Es folgt den PowerShell Best Practices und implementiert robuste Fehlerbehandlung sowie Logging.

#>

function Invoke-BrowserCacheCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Schaltet die ausführliche Konsolenausgabe ein.")]
        [switch]$VerboseOutput
    )

    begin {
        # Konfiguration der ausführlichen Ausgabe
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        # Initialisierung der Logdatei
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "BrowserCacheCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initialisiere Browser-Cache-Bereinigung..."
        Write-Verbose "Logdatei wird erstellt unter: $LogFile"
        "[$(Get-Date)] - Browser-Cache-Bereinigung gestartet." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Ermittle installierte Browser..."
            Write-Information "Die Browser-Cache-Bereinigung wird gestartet." -InformationAction Continue
            Write-Host "Starte die Browser-Cache-Bereinigung..."

            $browsers = @('Chrome', 'Firefox', 'Edge')
            foreach ($browser in $browsers) {
                Write-Verbose "Überprüfe Installation von $browser..."
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
                            Write-Verbose "Bereinige Cache für $browser unter $path..."
                            Write-Host "Bereinige Cache für $browser..."
                            Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                            Write-Verbose "Cache für $browser bereinigt."
                            "[$(Get-Date)] - Cache für $browser im Profil $_.Name bereinigt." | Add-Content -Path $LogFile
                        } else {
                            $WarningMessage = "Cache-Pfad für $browser ($path) wurde nicht gefunden."
                            Write-Warning $WarningMessage
                            "[$(Get-Date)] - WARNUNG: $WarningMessage" | Add-Content -Path $LogFile
                        }
                    }
                } elseif ($cachePath -and (Test-Path $cachePath)) {
                    Write-Verbose "Bereinige Cache für $browser unter $cachePath..."
                    Write-Host "Bereinige Cache für $browser..."
                    Get-ChildItem -Path $cachePath -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Verbose "Cache für $browser bereinigt."
                    "[$(Get-Date)] - Cache für $browser bereinigt." | Add-Content -Path $LogFile
                } else {
                    $WarningMessage = "Cache-Pfad für $browser wurde nicht gefunden oder $browser ist nicht installiert."
                    Write-Warning $WarningMessage
                    "[$(Get-Date)] - WARNUNG: $WarningMessage" | Add-Content -Path $LogFile
                }
            }

            Write-Verbose "Browser-Caches erfolgreich bereinigt."
            Write-Host "Browser-Caches wurden erfolgreich bereinigt."
            "[$(Get-Date)] - Browser-Caches erfolgreich bereinigt." | Add-Content -Path $LogFile
        }
        catch {
            $ErrorMessage = "Fehler bei der Bereinigung der Browser-Caches: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Browser-Cache-Bereinigungsprozess abgeschlossen."
        Write-Host "Browser-Cache-Bereinigungsprozess abgeschlossen."
        "[$(Get-Date)] - Browser-Cache-Bereinigungsprozess abgeschlossen." | Add-Content -Path $LogFile
        Write-Verbose "Details finden Sie in der Logdatei: $LogFile"
    }
}
