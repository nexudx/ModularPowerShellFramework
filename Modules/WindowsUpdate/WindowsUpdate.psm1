<#
.SYNOPSIS
    Installiert verfügbare Windows Updates und bietet ausführliche Konsolen- und Logausgaben.

.DESCRIPTION
    Dieses Modul überprüft auf verfügbare Windows Updates und installiert sie.
    Es implementiert detaillierte Konsolenausgaben mit Zeitstempeln und erstellt umfangreiche Logdateien zur Nachverfolgung des Update-Prozesses.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Ausgabe ein, um zusätzliche Debugging-Informationen anzuzeigen.

.EXAMPLE
    Invoke-WindowsUpdate -VerboseOutput
    Installiert verfügbare Windows Updates mit ausführlichen Konsolen- und Logausgaben.

.NOTES
    Version:        1.1.0
    Author:         Ihr Name
    Creation Date:  20.11.2023
    Last Modified:  20.11.2023
#>

function Invoke-WindowsUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Gibt an, ob ausführliche Ausgaben angezeigt werden sollen.")]
        [switch]$VerboseOutput
    )

    begin {
        # Initialisierung des Loggings
        $scriptDir = Split-Path -Parent $PSCommandPath
        $logFileName = "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $logFilePath = Join-Path -Path $scriptDir -ChildPath $logFileName
        Start-Transcript -Path $logFilePath -Append | Out-Null

        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
            Write-Verbose "Verbose Ausgabe aktiviert."
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Initialisiere Windows Update Prozess..."
    }

    process {
        try {
            # Überprüfung auf verfügbare Updates
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Überprüfe auf verfügbare Updates..."
            $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop

            if ($updates -ne $null -and $updates.Count -gt 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Es wurden $($updates.Count) Updates gefunden."
                Write-Verbose "Gefundene Updates: $($updates | Select-Object -ExpandProperty Title -Join ', ')"

                # Installation der Updates
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Installiere verfügbare Updates..."
                Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop

                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Updates erfolgreich installiert."
            } else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Keine Updates verfügbar."
            }
        }
        catch {
            Write-Error "[$(Get-Date -Format 'HH:mm:ss')] Fehler bei der Installation der Windows Updates: $_"
        }
    }

    end {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Windows Update Prozess abgeschlossen."
        Stop-Transcript | Out-Null
    }
}
