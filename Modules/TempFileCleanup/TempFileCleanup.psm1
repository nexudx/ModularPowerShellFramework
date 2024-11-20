<#
.SYNOPSIS
    Führt eine Bereinigung von temporären Dateien durch.

.DESCRIPTION
    Dieses Modul bereinigt temporäre Dateien, um Speicherplatz freizugeben und die Systemleistung zu verbessern.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Ausgabe ein.

.EXAMPLE
    Invoke-TempFileCleanup
    Führt die temporäre Dateienbereinigung mit Standardeinstellungen durch.

.EXAMPLE
    Invoke-TempFileCleanup -VerboseOutput
    Führt die Bereinigung durch und zeigt ausführliche Informationen an.

.NOTES
    Dieses Modul wurde aktualisiert, um den -ModuleVerbose Schalter zu entfernen und folgt den PowerShell Best Practices.

#>

function Invoke-TempFileCleanup {
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
        Write-Verbose "Initialisiere temporäre Dateienbereinigung..."
    }

    process {
        try {
            # Hauptlogik zur Bereinigung temporärer Dateien
            Write-Verbose "Scanne nach temporären Dateien..."

            $tempPaths = @(
                "$env:TEMP\*",
                "$env:Windir\Temp\*"
            )

            foreach ($path in $tempPaths) {
                Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }

            Write-Verbose "Temporäre Dateien erfolgreich bereinigt."
        }
        catch {
            Write-Error "Fehler bei der Bereinigung temporärer Dateien: $_"
        }
    }

    end {
        Write-Verbose "Bereinigungsprozess abgeschlossen."
    }
}
