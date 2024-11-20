<#
.SYNOPSIS
    Lädt und führt PowerShell-Module aus einem angegebenen Verzeichnis mit einem Modul-Auswahlassistenten beim Start aus.

.DESCRIPTION
    Dieses Skript bietet ein Framework zum Laden und Ausführen von PowerShell-Modulen.
    Module werden aus dem 'Modules'-Unterverzeichnis relativ zum Speicherort des Skripts geladen.
    Beim Start wird ein Auswahlassistent angezeigt, mit dem der Benutzer ein Modul auswählen kann.
    Nach der Ausführung eines Moduls wird das aktuellste Log im Modulverzeichnis in der Konsole angezeigt.

.PARAMETER ModuleName
    Der Name des Moduls, das geladen werden soll (ohne die .psm1-Erweiterung).
    Wenn nicht angegeben, wird ein Modul-Auswahlassistent angezeigt.

.PARAMETER ModuleParameters
    Zusätzliche Parameter, die an die Invoke-Funktion des Moduls übergeben werden.

.EXAMPLE
    .\Main.ps1

    Startet das Skript und zeigt den Modul-Auswahlassistenten an.

.EXAMPLE
    .\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-Verbose")

    Lädt das 'DiskCheck'-Modul und führt es mit dem Parameter -Verbose aus.

.NOTES
    Stellen Sie sicher, dass das Skript mit Administratorrechten ausgeführt wird.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ModuleName,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ModuleParameters
)

# Funktion zur Anzeige des aktuellsten Logs eines Moduls
function Show-LatestModuleLog {
    <#
    .SYNOPSIS
        Zeigt das aktuellste Log eines Moduls in der Konsole an.

    .DESCRIPTION
        Diese Funktion sucht im Modulverzeichnis nach der aktuellsten Log-Datei und gibt deren Inhalt in der Konsole aus.

    .PARAMETER ModuleName
        Der Name des Moduls, dessen Log angezeigt werden soll.

    .EXAMPLE
        Show-LatestModuleLog -ModuleName "DiskCleanup"

        Zeigt das aktuellste Log des Moduls 'DiskCleanup' an.

    .NOTES
        Die Funktion geht davon aus, dass die Log-Dateien die Erweiterung '.log' haben und im Modulverzeichnis gespeichert sind.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        # Konstruktion des Modulverzeichnis-Pfads
        $ModuleDirectory = Join-Path $ModulesPath $ModuleName

        # Validierung des Modulverzeichnisses
        if (-not (Test-Path $ModuleDirectory)) {
            Write-Warning "Modulverzeichnis nicht gefunden: $ModuleDirectory"
            return
        }

        # Ermitteln der aktuellsten Log-Datei im Modulverzeichnis
        $LatestLog = Get-ChildItem -Path $ModuleDirectory -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($LatestLog) {
            Write-Host "Inhalt des neuesten Logs für Modul '$ModuleName':" -ForegroundColor Cyan
            Get-Content -Path $LatestLog.FullName
        }
        else {
            Write-Warning "Keine Log-Dateien im Modulverzeichnis gefunden für Modul '$ModuleName'."
        }
    }
    catch {
        Write-Error "Fehler beim Anzeigen des neuesten Logs: $_"
    }
}

# Beginn des Skripts

# Überprüfen, ob als Administrator ausgeführt
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Dieses Skript erfordert Administratorrechte. Neustart im erhöhten Modus..."
    # Skript in erhöhter Sitzung neu starten
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs -Wait
    exit # Beenden der aktuellen Sitzung
}

$ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"

# Log-Dateiverwaltung: Behalte nur die neuesten drei Log-Dateien für jedes Modul
Get-ChildItem -Path $ModulesPath -Recurse -Filter *.log | 
    Group-Object { $_.DirectoryName } | 
    ForEach-Object {
        $logs = $_.Group | Sort-Object LastWriteTime -Descending
        $logs | Select-Object -Skip 3 | Remove-Item -Force -ErrorAction SilentlyContinue
    }

try {
    # Überprüfen, ob das Modules-Verzeichnis existiert
    if (-not (Test-Path $ModulesPath)) {
        throw "Modules-Verzeichnis nicht gefunden: $ModulesPath"
    }

    # PSModulePath aktualisieren
    $env:PSModulePath = "$ModulesPath;$env:PSModulePath"

    # Wenn kein Modulname angegeben ist, Modul-Auswahlassistent starten
    if (-not $ModuleName) {
        # Verfügbare Module auflisten
        $AvailableModules = Get-ChildItem -Path $ModulesPath -Directory | Select-Object -ExpandProperty Name

        if ($AvailableModules.Count -eq 0) {
            throw "Keine Module im Modules-Verzeichnis gefunden."
        }

        Write-Host "Verfügbare Module:"
        for ($i = 0; $i -lt $AvailableModules.Count; $i++) {
            Write-Host "[$($i + 1)] $($AvailableModules[$i])"
        }

        do {
            $selection = Read-Host "Bitte wählen Sie ein Modul durch Eingabe der entsprechenden Zahl"
            [int]$selection = [int]$selection - 1
        } until ($selection -ge 0 -and $selection -lt $AvailableModules.Count)

        $ModuleName = $AvailableModules[$selection]
    }

    # Modul importieren
    Import-Module $ModuleName -ErrorAction Stop

    # Dynamisch den Befehl mit Parametern zusammenstellen
    $Command = "Invoke-$ModuleName"
    $ParamList = @{}

    # Modulparameter parsen
    for ($i = 0; $i -lt $ModuleParameters.Count; $i++) {
        $param = $ModuleParameters[$i]
        if ($param -match '^-(.+)$') {
            $ParamName = $matches[1]
            $ParamValue = $true
            # Überprüfen, ob ein Wert für den Parameter angegeben wurde
            if ($i + 1 -lt $ModuleParameters.Count -and -not ($ModuleParameters[$i + 1] -match '^-')) {
                $ParamValue = $ModuleParameters[$i + 1]
                $i++
            }
            $ParamList[$ParamName] = $ParamValue
        }
    }

    # Modul-Funktionsaufruf mit Parametern ausführen
    & $Command @ParamList

    # Nach Ausführung des Moduls das aktuellste Log anzeigen
    Show-LatestModuleLog -ModuleName $ModuleName
}
catch {
    Write-Error "Ein Fehler ist aufgetreten: $_"
}
