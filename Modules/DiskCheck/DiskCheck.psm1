<#
.SYNOPSIS
    Führt eine detaillierte Datenträgerprüfung durch und liefert informative Konsolen- und Logausgaben.

.DESCRIPTION
    Dieses Modul führt eine umfassende Überprüfung der Datenträger durch und repariert Fehler, wenn angegeben. Während des Prozesses werden detaillierte Informationen über die ausgeführten Schritte, Ergebnisse und etwaige Fehler ausgegeben und protokolliert.

.PARAMETER RepairMode
    Aktiviert den Reparaturmodus, um gefundene Fehler automatisch zu beheben.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Konsolenausgabe ein.

.EXAMPLE
    Invoke-DiskCheck
    Führt eine Datenträgerprüfung mit Standardeinstellungen durch und liefert informative Ausgaben.

.EXAMPLE
    Invoke-DiskCheck -RepairMode -VerboseOutput
    Führt die Datenträgerprüfung im Reparaturmodus durch und zeigt zusätzliche ausführliche Informationen an.

.NOTES
    Dieses Modul wurde erweitert, um die Konsolen- und Logausgaben deutlich informativer zu gestalten. Es folgt den PowerShell Best Practices und implementiert robuste Fehlerbehandlung sowie Logging.

#>

function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Aktiviert den Reparaturmodus.")]
        [switch]$RepairMode,

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
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "DiskCheckLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initialisiere Datenträgerprüfung..."
        Write-Verbose "Logdatei wird erstellt unter: $LogFile"
        "[$(Get-Date)] - Datenträgerprüfung gestartet." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Starte Datenträgerprüfung..."
            Write-Information "Die Datenträgerprüfung wird gestartet." -InformationAction Continue
            Write-Host "Starte die Datenträgerprüfung..."

            # Plattformüberprüfung
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                # Kommandozeilenargumente erstellen
                $arguments = "/scan"

                if ($RepairMode.IsPresent) {
                    $arguments += " /forceofflinefix /perf"
                    Write-Verbose "Reparaturmodus aktiviert."
                    Write-Host "Reparaturmodus ist aktiviert. Gefundene Fehler werden automatisch behoben."
                } else {
                    Write-Verbose "Reparaturmodus nicht aktiviert."
                    Write-Host "Reparaturmodus ist nicht aktiviert. Es werden keine Änderungen vorgenommen."
                }

                # Pfad zu chkdsk.exe ermitteln
                $ChkdskPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\chkdsk.exe"

                if (Test-Path $ChkdskPath) {
                    Write-Verbose "Ausführen von '$ChkdskPath' mit Argumenten '$arguments'"
                    Write-Host "Führe 'chkdsk.exe' aus mit den angegebenen Optionen..."

                    # Starten der Überprüfung und Messung der Dauer
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                    # Prozessinformationen erstellen
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = $ChkdskPath
                    $processInfo.Arguments = $arguments
                    $processInfo.Verb = "runas"
                    $processInfo.UseShellExecute = $true

                    # Prozess starten
                    $process = [System.Diagnostics.Process]::Start($processInfo)
                    $process.WaitForExit()
                    $Stopwatch.Stop()

                    Write-Verbose "Datenträgerprüfung abgeschlossen in $($Stopwatch.Elapsed.TotalSeconds) Sekunden."
                    Write-Host "Datenträgerprüfung erfolgreich abgeschlossen."
                    "[$(Get-Date)] - Datenträgerprüfung erfolgreich abgeschlossen in $($Stopwatch.Elapsed.TotalSeconds) Sekunden." | Add-Content -Path $LogFile

                    # Optional: Auswertung der Ergebnisse
                    # Hier könnte zusätzlicher Code eingefügt werden, um die Ergebnisse auszuwerten und detaillierter zu berichten
                } else {
                    $ErrorMessage = "Das Dienstprogramm 'chkdsk.exe' wurde nicht gefunden."
                    Write-Error $ErrorMessage
                    "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
                }
            } else {
                $WarningMessage = "Die Datenträgerprüfung ist unter diesem Betriebssystem nicht verfügbar."
                Write-Warning $WarningMessage
                "[$(Get-Date)] - WARNUNG: $WarningMessage" | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Fehler bei der Datenträgerprüfung: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Datenträgerprüfungsprozess abgeschlossen."
        Write-Host "Datenträgerprüfungsprozess abgeschlossen."
        "[$(Get-Date)] - Datenträgerprüfungsprozess abgeschlossen." | Add-Content -Path $LogFile
        Write-Verbose "Details finden Sie in der Logdatei: $LogFile"
    }
}
