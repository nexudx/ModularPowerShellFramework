<#
.SYNOPSIS
    Führt eine Datenträgerprüfung durch.

.DESCRIPTION
    Dieses Modul führt eine Überprüfung der Datenträger durch und repariert Fehler, wenn angegeben.

.PARAMETER RepairMode
    Aktiviert den Reparaturmodus, um gefundene Fehler automatisch zu beheben.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Ausgabe ein.

.EXAMPLE
    Invoke-DiskCheck
    Führt eine Datenträgerprüfung mit Standardeinstellungen durch.

.EXAMPLE
    Invoke-DiskCheck -RepairMode -VerboseOutput
    Führt die Datenträgerprüfung im Reparaturmodus durch und zeigt ausführliche Informationen an.

.NOTES
    Dieses Modul wurde aktualisiert, um den -ModuleVerbose Schalter zu entfernen und folgt den PowerShell Best Practices.

#>

function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Aktiviert den Reparaturmodus.")]
        [switch]$RepairMode,

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
        Write-Verbose "Initialisiere Datenträgerprüfung..."
    }

    process {
        try {
            Write-Verbose "Starte Datenträgerprüfung..."

            $arguments = "/scan"

            if ($RepairMode.IsPresent) {
                $arguments += " /forceofflinefix"
            }

            # Beispiel für Windows: Ausführen von chkdsk
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                Start-Process -FilePath "chkdsk.exe" -ArgumentList $arguments -Wait -Verb RunAs
                Write-Verbose "Datenträgerprüfung abgeschlossen."
            }
            else {
                Write-Warning "Die Datenträgerprüfung ist unter diesem Betriebssystem nicht verfügbar."
            }
        }
        catch {
            Write-Error "Fehler bei der Datenträgerprüfung: $_"
        }
    }

    end {
        Write-Verbose "Datenträgerprüfungsprozess abgeschlossen."
    }
}
