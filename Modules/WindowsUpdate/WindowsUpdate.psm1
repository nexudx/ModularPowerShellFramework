<#
.SYNOPSIS
    Installiert verfügbare Windows Updates.

.DESCRIPTION
    Dieses Modul überprüft auf verfügbare Windows Updates und installiert sie.

.EXAMPLE
    Invoke-WindowsUpdate
    Installiert verfügbare Windows Updates mit standardmäßigen Einstellungen.

.NOTES
    Dieses Modul wurde aktualisiert, um den -ModuleVerbose Schalter zu entfernen und folgt den PowerShell Best Practices.

#>

function Invoke-WindowsUpdate {
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
        Write-Verbose "Initialisiere Windows Update Prozess..."
    }

    process {
        try {
            # Hauptlogik zur Überprüfung und Installation von Updates
            Write-Verbose "Überprüfe auf verfügbare Updates..."
            $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot

            if ($updates -ne $null) {
                Write-Verbose "Installiere verfügbare Updates..."
                Install-WindowsUpdate -AcceptAll -IgnoreReboot
                Write-Verbose "Updates erfolgreich installiert."
            } else {
                Write-Verbose "Keine Updates verfügbar."
            }
        }
        catch {
            Write-Error "Fehler bei der Installation der Windows Updates: $_"
        }
    }

    end {
        Write-Verbose "Windows Update Prozess abgeschlossen."
    }
}
