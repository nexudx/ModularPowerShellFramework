<#
.SYNOPSIS
    Installiert Windows Updates.

.DESCRIPTION
    Dieses Modul stellt eine Funktion zur Installation verfügbarer Windows Updates bereit.
    Wenn keine Updates gefunden werden, wird ein zweiter Suchlauf durchgeführt.
    Falls die Updates nicht installiert werden können, weil ein Neustart erforderlich ist, wird das System neu gestartet.

.PARAMETER ModuleVerbose
    Aktiviert ausführliche Ausgaben für detaillierte Betriebsinformationen.

.EXAMPLE
    Invoke-WindowsUpdate -ModuleVerbose
    Installiert verfügbare Windows Updates mit aktiviertem ausführlichem Output.

.NOTES
    Stellen Sie sicher, dass das Skript mit Administratorrechten ausgeführt wird, um die volle Funktionalität zu gewährleisten.
#>
function WindowsUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Aktiviert ausführliche Ausgaben.")]
        [switch]$ModuleVerbose
    )

    begin {
        # Bestimmen des Modulverzeichnisses
        $ModuleDirectory = Split-Path $PSCommandPath -Parent

        # Erstellen des Log-Dateipfads
        $LogFilePath = Join-Path $ModuleDirectory "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Starten der Aufzeichnung
        Start-Transcript -Path $LogFilePath -Append
    }

    process {
        try {
            if ($ModuleVerbose) { Write-Verbose "Starte Windows Update Prozess..." }

            # PSGallery registrieren, falls noch nicht registriert
            if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                if ($ModuleVerbose) { Write-Verbose "Registriere PSGallery..." }
                Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2 -InstallationPolicy Trusted -ErrorAction Stop
            }

            # Prüfen, ob das PSWindowsUpdate Modul installiert ist
            if (-not (Get-Module PSWindowsUpdate -ListAvailable)) {
                if ($ModuleVerbose) { Write-Verbose "Installiere PSWindowsUpdate Modul..." }
                Install-Module PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            }

            Import-Module PSWindowsUpdate -ErrorAction Stop

            $UpdateAttempt = 0
            $UpdatesFound = $false

            while ($UpdateAttempt -lt 2 -and -not $UpdatesFound) {
                if ($ModuleVerbose) { Write-Verbose "Suche nach verfügbaren Updates... (Versuch $($UpdateAttempt + 1))" }

                # Automatisches Akzeptieren der Updates
                $updates = Get-WindowsUpdate -AcceptAll -ErrorAction Stop

                if ($updates) {
                    $UpdatesFound = $true
                    if ($ModuleVerbose) { Write-Verbose "Installiere Updates..." }

                    # Updates installieren
                    $updates | Install-WindowsUpdate -AcceptAll -ForceInstall -ErrorAction Stop

                    Write-Output "Windows Updates erfolgreich installiert."

                    # Prüfen, ob ein Neustart erforderlich ist
                    if (Get-WURebootStatus) {
                        if ($ModuleVerbose) { Write-Verbose "Neustart erforderlich. Starte das System neu..." }
                        Restart-Computer -Force
                        exit
                    }
                }
                else {
                    if ($ModuleVerbose) { Write-Verbose "Keine Updates gefunden beim Versuch $($UpdateAttempt + 1)." }
                    $UpdateAttempt++
                }
            }

            if (-not $UpdatesFound) {
                Write-Output "Keine Windows Updates nach zwei Versuchen gefunden."
            }
        }
        catch {
            Write-Error "Fehler beim Installieren der Windows Updates: $_"
        }
    }

    end {
        # Beenden der Aufzeichnung
        Stop-Transcript
    }
}

# Proxy-Funktion zur Handhabung des Parameters -ModuleVerbose
function Invoke-WindowsUpdate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Aktiviert ausführliche Ausgaben.")]
        [switch]$ModuleVerbose
    )

    # Übergabe der Parameter an die WindowsUpdate Funktion
    WindowsUpdate @PSBoundParameters
}

# Exportieren der Proxy-Funktion
Export-ModuleMember -Function Invoke-WindowsUpdate
