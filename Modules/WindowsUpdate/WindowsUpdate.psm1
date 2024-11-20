<#
.SYNOPSIS
    Installiert verfügbare Windows Updates mit detaillierten Konsolen- und Logausgaben.

.DESCRIPTION
    Dieses Modul überprüft auf verfügbare Windows Updates und installiert sie.
    Während des Prozesses werden detaillierte Informationen über die ausgeführten Schritte, gefundene Updates, Installationsfortschritt und etwaige Fehler ausgegeben und protokolliert.
    Alle Aktionen werden in einer Logdatei im temporären Verzeichnis gespeichert.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Konsolenausgabe ein, um zusätzliche Debugging-Informationen anzuzeigen.

.EXAMPLE
    Invoke-WindowsUpdate
    Installiert verfügbare Windows Updates mit standardmäßigen Konsolen- und Logausgaben.

.EXAMPLE
    Invoke-WindowsUpdate -VerboseOutput
    Installiert verfügbare Windows Updates mit ausführlichen Konsolen- und Logausgaben.

.NOTES
    Version:        1.2.0
    Author:         Ihr Name
    Creation Date:  20.11.2023
    Last Modified:  20.11.2023
#>

function Invoke-WindowsUpdate {
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
            Write-Verbose "Ausführliche Ausgabe aktiviert."
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        # Initialisierung der Logdatei
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "WindowsUpdateLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initialisiere Windows Update Prozess..."
        Write-Verbose "Logdatei wird erstellt unter: $LogFile"
        "[$(Get-Date)] - Windows Update Prozess gestartet." | Out-File -FilePath $LogFile -Encoding UTF8

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Initialisiere Windows Update Prozess..."
    }

    process {
        try {
            # Überprüfung auf verfügbare Updates
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Überprüfe auf verfügbare Updates..."
            Write-Information "Überprüfe auf verfügbare Updates..." -InformationAction Continue
            Write-Verbose "Rufe verfügbare Updates ab..."

            # Erfordert das Modul PSWindowsUpdate
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Write-Verbose "PSWindowsUpdate-Modul nicht gefunden. Installiere Modul..."
                Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
                Write-Verbose "PSWindowsUpdate-Modul erfolgreich installiert."
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
            } else {
                Write-Verbose "PSWindowsUpdate-Modul ist vorhanden."
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
            }

            $updates = Get-WindowsUpdate -ErrorAction Stop
            $updateCount = $updates.Count

            if ($updateCount -gt 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Es wurden $updateCount Updates gefunden."
                Write-Verbose "Gefundene Updates:"
                foreach ($update in $updates) {
                    Write-Verbose " - $($update.Title)"
                    "[$(Get-Date)] - Gefundenes Update: $($update.Title)" | Add-Content -Path $LogFile
                }

                # Installation der Updates
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Installiere verfügbare Updates..."
                Write-Information "Installation der Updates wird gestartet..." -InformationAction Continue
                Write-Verbose "Starte Installation der Updates..."

                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction Stop
                $Stopwatch.Stop()

                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Updates erfolgreich installiert."
                Write-Verbose "Installation abgeschlossen in $($Stopwatch.Elapsed.TotalMinutes.ToString("N2")) Minuten."
                "[$(Get-Date)] - Updates erfolgreich installiert in $($Stopwatch.Elapsed.TotalMinutes.ToString("N2")) Minuten." | Add-Content -Path $LogFile
            } else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Keine Updates verfügbar."
                Write-Verbose "Es wurden keine Updates gefunden."
                "[$(Get-Date)] - Keine Updates verfügbar." | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Fehler bei der Installation der Windows Updates: $($_.Exception.Message)"
            Write-Error "[$(Get-Date -Format 'HH:mm:ss')] $ErrorMessage"
            "[$(Get-Date)] - FEHLER: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Windows Update Prozess abgeschlossen."
        Write-Verbose "Windows Update Prozess abgeschlossen."
        "[$(Get-Date)] - Windows Update Prozess abgeschlossen." | Add-Content -Path $LogFile
        Write-Verbose "Details finden Sie in der Logdatei: $LogFile"
    }
}
