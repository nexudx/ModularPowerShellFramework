<#
.SYNOPSIS
    Führt eine detaillierte Datenträgerbereinigung durch und liefert informative Konsolen- und Logausgaben.

.DESCRIPTION
    Dieses Modul führt eine umfassende Datenträgerbereinigung durch, um unnötige Dateien zu entfernen und Speicherplatz freizugeben. Während des Prozesses werden detaillierte Informationen über die ausgeführten Schritte, Ergebnisse und etwaige Fehler ausgegeben und protokolliert.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Konsolenausgabe ein.

.EXAMPLE
    Invoke-DiskCleanup
    Führt die Datenträgerbereinigung mit Standardeinstellungen durch und liefert informative Ausgaben.

.EXAMPLE
    Invoke-DiskCleanup -VerboseOutput
    Führt die Bereinigung durch und zeigt zusätzliche ausführliche Informationen an.

.NOTES
    Dieses Modul wurde erweitert, um die Konsolen- und Logausgaben deutlich informativer zu gestalten. Es folgt den PowerShell Best Practices und implementiert robuste Fehlerbehandlung sowie Logging.

#>

function Invoke-DiskCleanup {
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
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "DiskCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initialisiere Datenträgerbereinigung..."
        Write-Verbose "Logdatei wird erstellt unter: $LogFile"
        "[$(Get-Date)] - Datenträgerbereinigung gestartet." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Starte Datenträgerbereinigung..."
            Write-Information "Die Datenträgerbereinigung wird gestartet." -InformationAction Continue
            Write-Host "Starte die Datenträgerbereinigung..."

            # Plattformüberprüfung
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                # Überprüfen, ob 'cleanmgr.exe' vorhanden ist
                $CleanMgrPath = Join-Path -Path $env:Windir -ChildPath "System32\cleanmgr.exe"

                if (Test-Path $CleanMgrPath) {
                    $CleanupArgs = "/sagerun:1"
                    Write-Verbose "Ausführen von '$CleanMgrPath' mit Argumenten '$CleanupArgs'"
                    Write-Host "Führe 'cleanmgr.exe' aus mit vordefinierten Einstellungen..."

                    # Starten der Bereinigung und Messung der Dauer
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    Start-Process -FilePath $CleanMgrPath -ArgumentList $CleanupArgs -Wait -ErrorAction Stop
                    $Stopwatch.Stop()

                    Write-Verbose "Datenträgerbereinigung abgeschlossen in $($Stopwatch.Elapsed.TotalSeconds) Sekunden."
                    Write-Host "Datenträgerbereinigung erfolgreich abgeschlossen."
                    "[$(Get-Date)] - Datenträgerbereinigung erfolgreich abgeschlossen in $($Stopwatch.Elapsed.TotalSeconds) Sekunden." | Add-Content -Path $LogFile

                    # Optional: Hinzufügen von Informationen zum freigegebenen Speicherplatz
                    # Hier könnte zusätzlicher Code eingefügt werden, um den freigegebenen Speicherplatz zu ermitteln und auszugeben
                }
                else {
                    $ErrorMessage = "Das Dienstprogramm 'cleanmgr.exe' wurde nicht gefunden."
                    Write-Error $ErrorMessage
                    "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
                }
            }
            else {
                $WarningMessage = "Die Datenträgerbereinigung ist unter diesem Betriebssystem nicht verfügbar."
                Write-Warning $WarningMessage
                "[$(Get-Date)] - WARNUNG: $WarningMessage" | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Fehler bei der Datenträgerbereinigung: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Bereinigungsprozess abgeschlossen."
        Write-Host "Bereinigungsprozess abgeschlossen."
        "[$(Get-Date)] - Bereinigungsprozess abgeschlossen." | Add-Content -Path $LogFile
        Write-Verbose "Details finden Sie in der Logdatei: $LogFile"
    }
}
