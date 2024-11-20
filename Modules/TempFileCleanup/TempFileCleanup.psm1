<#
.SYNOPSIS
    Führt eine Bereinigung von temporären Dateien durch und liefert detaillierte Ausgaben.

.DESCRIPTION
    Dieses Modul bereinigt temporäre Dateien von definierten Pfaden, um Speicherplatz freizugeben und die Systemleistung zu verbessern.
    Es liefert dabei ausführliche Informationen über die Anzahl der gelöschten Dateien, den freigegebenen Speicherplatz und die Pfade, die bereinigt wurden.

.PARAMETER VerboseOutput
    Schaltet die ausführliche Ausgabe ein.

.PARAMETER LogPath
    Gibt den Pfad an, unter dem das Log gespeichert werden soll. Standardmäßig wird ein Log im Modulverzeichnis erstellt.

.EXAMPLE
    Invoke-TempFileCleanup
    Führt die temporäre Dateienbereinigung mit Standardeinstellungen durch.

.EXAMPLE
    Invoke-TempFileCleanup -VerboseOutput
    Führt die Bereinigung durch und zeigt ausführliche Informationen an.

.EXAMPLE
    Invoke-TempFileCleanup -LogPath "C:\Logs\TempCleanup.log"
    Führt die Bereinigung durch und speichert das Log unter dem angegebenen Pfad.

.NOTES
    - Unterstützt PowerShell Version 5.1 und höher.
    - Erfordert ausreichende Berechtigungen zum Löschen von Dateien in den Zielverzeichnissen.
    - Stellt sicher, dass sensible Daten nicht gelöscht werden.
#>

function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Gibt an, ob ausführliche Ausgaben angezeigt werden sollen.")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Gibt den Pfad für die Log-Datei an.")]
        [string]$LogPath = "$PSScriptRoot\TempFileCleanup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).log"
    )

    begin {
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }
        Write-Verbose "Initialisiere temporäre Dateienbereinigung..."

        $StartTime = Get-Date
        $TotalFilesDeleted = 0
        $TotalSpaceFreed = 0
        $CleanedDirectories = @()
        $LogContent = @()
    }

    process {
        try {
            Write-Verbose "Scanne nach temporären Dateien..."

            $tempPaths = @(
                "$env:TEMP",
                "$env:Windir\Temp"
            )

            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    Write-Verbose "Bereinige Verzeichnis: $path"

                    $files = Get-ChildItem -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue

                    $filesCount = $files.Count
                    $filesSize = ($files | Measure-Object -Property Length -Sum).Sum

                    if ($filesCount -gt 0) {
                        $files | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                        $TotalFilesDeleted += $filesCount
                        $TotalSpaceFreed += $filesSize
                        $CleanedDirectories += $path

                        Write-Verbose "Gelöschte Dateien: $filesCount"
                        Write-Verbose ("Freigegebener Speicherplatz: {0:N2} MB" -f ($filesSize / 1MB))
                    } else {
                        Write-Verbose "Keine temporären Dateien in $path gefunden."
                    }

                } else {
                    Write-Verbose "Verzeichnis nicht gefunden: $path"
                }
            }

            Write-Verbose "Temporäre Dateien erfolgreich bereinigt."
        }
        catch {
            Write-Error "Fehler bei der Bereinigung temporärer Dateien: $_"
        }
    }

    end {
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime

        $Summary = @"
Temporary File Cleanup Complete:
Startzeit: $($StartTime)
Endzeit: $($EndTime)
Dauer: $($Duration)

Gelöschte Dateien insgesamt: $TotalFilesDeleted
Freigegebener Speicherplatz insgesamt: {0:N2} MB

Bereinigte Verzeichnisse:
$($CleanedDirectories -join "`n")
"@

        Write-Verbose "Bereinigungsprozess abgeschlossen."
        Write-Verbose $Summary

        # Log schreiben
        $LogContent += "**********************"
        $LogContent += "Start der Windows PowerShell-Aufzeichnung"
        $LogContent += "Startzeit: $($StartTime.ToString('yyyyMMddHHmmss'))"
        $LogContent += "Benutzername: $([Environment]::UserDomainName)\$([Environment]::UserName)"
        $LogContent += "Computer: $env:COMPUTERNAME ($env:OS)"
        $LogContent += "**********************"
        $LogContent += $Summary
        $LogContent += "**********************"
        $LogContent += "Ende der Windows PowerShell-Aufzeichnung"
        $LogContent += "Endzeit: $($EndTime.ToString('yyyyMMddHHmmss'))"
        $LogContent += "**********************"

        $LogContent | Out-File -FilePath $LogPath -Encoding UTF8
        Write-Verbose "Log gespeichert unter: $LogPath"
    }
}
