<#
.SYNOPSIS
    Führt eine Datenträgerbereinigung durch.

.DESCRIPTION
    Dieses Modul führt eine Datenträgerbereinigung durch, um unnötige Dateien zu entfernen und Speicherplatz freizugeben.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Ausgabe ein.

.EXAMPLE
    Invoke-DiskCleanup
    Führt die Datenträgerbereinigung mit Standardeinstellungen durch.

.EXAMPLE
    Invoke-DiskCleanup -VerboseOutput
    Führt die Bereinigung durch und zeigt ausführliche Informationen an.

.NOTES
    Dieses Modul wurde aktualisiert, um den -ModuleVerbose Schalter zu entfernen und folgt den PowerShell Best Practices.

#>

function Invoke-DiskCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Gibt an, ob ausführliche Ausgaben angezeigt werden sollen.")]
        [switch]$VerboseOutput
    )

    begin {
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }
        Write-Verbose "Initialisiere Datenträgerbereinigung..."
    }

    process {
        try {
            # Hauptlogik zur Durchführung der Datenträgerbereinigung
            Write-Verbose "Starte Datenträgerbereinigung..."

            # Beispiel für Windows: Ausführen von Cleanmgr.exe mit vordefinierten Einstellungen
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait
                Write-Verbose "Datenträgerbereinigung abgeschlossen."
            }
            else {
                Write-Warning "Die Datenträgerbereinigung ist unter diesem Betriebssystem nicht verfügbar."
            }
        }
        catch {
            Write-Error "Fehler bei der Datenträgerbereinigung: $_"
        }
    }

    end {
        Write-Verbose "Bereinigungsprozess abgeschlossen."
    }
}
