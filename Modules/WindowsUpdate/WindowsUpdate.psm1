<#
.SYNOPSIS
    Installiert Windows Updates mit optimierter Logik und Neustartverwaltung.

.DESCRIPTION
    Dieses Modul ermöglicht die Installation von Windows Updates mit einer optimierten Logik, die:
    - Überprüft, ob ein Neustart erforderlich ist, und den Benutzer um Genehmigung bittet.
    - Nach dem Neustart den Update-Prozess fortsetzt.
    - Updates in einer Schleife sucht und installiert, bis keine weiteren Updates verfügbar sind.
    - Nach jedem Installationsdurchlauf prüft, ob ein Neustart erforderlich ist, und den Benutzer um Genehmigung bittet.
    - Eine Abschlussprüfung durchführt, um sicherzustellen, dass alle Updates installiert sind.

.PARAMETER ModuleVerbose
    Aktiviert ausführliche Ausgaben für detaillierte Betriebsinformationen.

.EXAMPLE
    Invoke-WindowsUpdate -ModuleVerbose
    Installiert verfügbare Windows Updates mit optimierter Logik und aktiviertem ausführlichem Output.

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
        # Modulverzeichnis bestimmen
        $ModuleDirectory = Split-Path $PSCommandPath -Parent

        # Log-Dateipfad erstellen
        $LogFilePath = Join-Path $ModuleDirectory "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Aufzeichnung starten
        Start-Transcript -Path $LogFilePath -Append

        # Verbose-Ausgaben konfigurieren
        if ($ModuleVerbose) {
            $VerbosePreference = 'Continue'
            Write-Verbose "Ausführlicher Modus aktiviert."
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }
    }

    process {
        try {
            Write-Verbose "Starte Windows Update Prozess..."

            # Überprüfen, ob ein Neustart erforderlich ist
            Write-Verbose "Überprüfe, ob ein Neustart erforderlich ist..."
            $RebootPending = Test-PendingReboot

            if ($RebootPending) {
                Write-Verbose "Ein Neustart ist erforderlich."
                $UserConsent = Get-UserConsentForReboot

                if ($UserConsent) {
                    Write-Verbose "Benutzer hat dem Neustart zugestimmt. Neustart wird durchgeführt..."
                    Restart-Computer -Force
                    exit
                } else {
                    Write-Warning "Benutzer hat den Neustart abgelehnt. Der Update-Prozess wird beendet."
                    return
                }
            }

            # PSGallery registrieren, falls nicht vorhanden
            if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
                Write-Verbose "Registriere PSGallery..."
                Register-PSRepository -Name PSGallery -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -ErrorAction Stop
            }

            # PSWindowsUpdate Modul installieren, falls nicht vorhanden
            if (-not (Get-Module -Name PSWindowsUpdate -ListAvailable)) {
                Write-Verbose "Installiere PSWindowsUpdate Modul..."
                Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
            }

            Import-Module -Name PSWindowsUpdate -ErrorAction Stop

            $NoMoreUpdates = $false

            do {
                Write-Verbose "Suche nach verfügbaren Updates..."
                $Updates = Get-WindowsUpdate -AcceptAll -ErrorAction Stop

                if ($Updates) {
                    Write-Verbose "Updates gefunden. Installiere Updates..."
                    $Updates | Install-WindowsUpdate -AcceptAll -ForceInstall -ErrorAction Stop

                    Write-Output "Windows Updates erfolgreich installiert."

                    # Überprüfen, ob ein Neustart erforderlich ist
                    Write-Verbose "Überprüfe, ob ein Neustart erforderlich ist..."
                    $RebootPending = Test-PendingReboot

                    if ($RebootPending) {
                        Write-Verbose "Ein Neustart ist erforderlich."
                        $UserConsent = Get-UserConsentForReboot

                        if ($UserConsent) {
                            Write-Verbose "Benutzer hat dem Neustart zugestimmt. Neustart wird durchgeführt..."
                            Restart-Computer -Force
                            exit
                        } else {
                            Write-Warning "Benutzer hat den Neustart abgelehnt. Der Update-Prozess wird beendet."
                            return
                        }
                    }
                } else {
                    Write-Output "Keine weiteren Updates verfügbar."
                    $NoMoreUpdates = $true
                }
            } while (-not $NoMoreUpdates)

            # Abschlussprüfung
            Write-Verbose "Führe Abschlussprüfung durch..."
            $RebootPending = Test-PendingReboot

            if ($RebootPending) {
                Write-Verbose "Ein Neustart ist erforderlich."
                $UserConsent = Get-UserConsentForReboot

                if ($UserConsent) {
                    Write-Verbose "Benutzer hat dem Neustart zugestimmt. Neustart wird durchgeführt..."
                    Restart-Computer -Force
                    exit
                } else {
                    Write-Warning "Benutzer hat den Neustart abgelehnt. Der Update-Prozess wird beendet."
                    return
                }
            }

            Write-Output "Windows Update Prozess abgeschlossen."
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

function Test-PendingReboot {
    [CmdletBinding()]
    param()

    # Prüfen auf PendingFileRenameOperations
    $PendingFileRenameOperations = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue

    # Prüfen auf RebootPending von Windows Update
    $RebootRequired = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue

    # Prüfen auf CBS RebootPending
    $CBSRebootPending = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Updates" -Name "UpdateExeVolatile" -ErrorAction SilentlyContinue

    # Zusammenfassen der Ergebnisse
    if ($PendingFileRenameOperations -or $RebootRequired -or $CBSRebootPending) {
        return $true
    } else {
        return $false
    }
}

function Get-UserConsentForReboot {
    [CmdletBinding()]
    param()

    $Prompt = "Ein Neustart ist erforderlich, um den Update-Prozess fortzusetzen. Möchten Sie jetzt neu starten? [J]a / [N]ein:"
    do {
        $Input = Read-Host $Prompt
    } while ($Input -notin @('J', 'j', 'N', 'n'))

    if ($Input -in @('J', 'j')) {
        return $true
    } else {
        return $false
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

# Exportieren der Funktionen
Export-ModuleMember -Function Invoke-WindowsUpdate
