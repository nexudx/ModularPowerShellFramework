<#
.SYNOPSIS
    Lädt und führt PowerShell-Module aus einem angegebenen Verzeichnis mit einem Modul-Auswahlassistenten beim Start aus.

.DESCRIPTION
    Dieses Skript bietet ein Framework zum Laden und Ausführen von PowerShell-Modulen.
    Module werden aus dem 'Modules'-Unterverzeichnis relativ zum Speicherort des Skripts geladen.
    Beim Start wird ein Auswahlassistent angezeigt, mit dem der Benutzer ein Modul auswählen kann.
    Nach der Ausführung eines Moduls wird das aktuellste Log im Modulverzeichnis in der Konsole angezeigt.
    Die Logrotation wird immer ausgeführt, nachdem ein Modul ein neues Log erstellt hat.

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
    Teile dieses Skripts erfordern Administratorrechte. Die Anzeige des Logs und die Logrotation nach der Modulverarbeitung erfordern keine erhöhten Rechte.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ModuleName,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ModuleParameters
)

# Globale Variablen
$ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"

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
        $ModuleDirectory = Join-Path $ModulesPath $ModuleName

        if (-not (Test-Path $ModuleDirectory)) {
            Write-Warning "Modulverzeichnis nicht gefunden: $ModuleDirectory"
            return
        }

        $LatestLog = Get-ChildItem -Path $ModuleDirectory -Filter '*.log' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

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

function Invoke-ModuleExecution {
    <#
    .SYNOPSIS
        Führt die Hauptlogik des Skripts aus, die Administratorrechte erfordert.

    .DESCRIPTION
        Diese Funktion lädt das ausgewählte Modul und führt die entsprechende Invoke-Funktion aus.

    .PARAMETER ModuleName
        Der Name des zu ladenden Moduls.

    .PARAMETER ModuleParameters
        Zusätzliche Parameter für die Modul-Invoke-Funktion.

    .EXAMPLE
        Invoke-ModuleExecution -ModuleName "DiskCheck" -ModuleParameters @("-Verbose")

        Führt das Modul 'DiskCheck' mit dem Parameter -Verbose aus.

    .NOTES
        Diese Funktion erfordert Administratorrechte.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string[]]$ModuleParameters
    )

    try {
        # PSModulePath aktualisieren
        $env:PSModulePath = "$ModulesPath;$env:PSModulePath"

        # Modul importieren
        Import-Module $ModuleName -ErrorAction Stop

        # Dynamisch den Befehl mit Parametern zusammenstellen
        $Command = "Invoke-$ModuleName"
        $ParamList = @{}

        if ($ModuleParameters) {
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
        }

        # Modul-Funktionsaufruf mit Parametern ausführen
        & $Command @ParamList
    }
    catch {
        Write-Error "Ein Fehler ist aufgetreten: $_"
    }
}

function Rotate-ModuleLogs {
    <#
    .SYNOPSIS
        Führt die Logrotation für ein Modul aus.

    .DESCRIPTION
        Behalte nur die neuesten drei Log-Dateien für jedes Modul.

    .PARAMETER ModuleName
        Der Name des Moduls, dessen Logs rotiert werden sollen.

    .EXAMPLE
        Rotate-ModuleLogs -ModuleName "DiskCleanup"

        Führt die Logrotation für das Modul 'DiskCleanup' aus.

    .NOTES
        Diese Funktion erfordert keine Administratorrechte.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        $ModuleDirectory = Join-Path $ModulesPath $ModuleName

        if (-not (Test-Path $ModuleDirectory)) {
            Write-Warning "Modulverzeichnis nicht gefunden: $ModuleDirectory"
            return
        }

        $Logs = Get-ChildItem -Path $ModuleDirectory -Filter '*.log' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -Skip 3

        if ($Logs) {
            $Logs | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Fehler bei der Logrotation: $_"
    }
}

# Hauptlogik

try {
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
            $selection = [int]$selection - 1
        } until ($selection -ge 0 -and $selection -lt $AvailableModules.Count)

        $ModuleName = $AvailableModules[$selection]
    }

    # Überprüfen, ob als Administrator ausgeführt
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (-not $isAdmin) {
        Write-Warning "Die Ausführung des Moduls erfordert Administratorrechte. Neustart im erhöhten Modus..."

        # Argumente vorbereiten
        $argList = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -ModuleName `"$ModuleName`""
        if ($ModuleParameters) {
            $paramStr = $ModuleParameters | ForEach-Object { "`"$_`"" } -join ' '
            $argList += " -ModuleParameters $paramStr"
        }

        # Skript in erhöhter Sitzung neu starten und Parameter übergeben
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
    }
    else {
        # Modul ausführen
        Invoke-ModuleExecution -ModuleName $ModuleName -ModuleParameters $ModuleParameters
    }

    # Logrotation nach Modulausführung durchführen
    Rotate-ModuleLogs -ModuleName $ModuleName

    # Nach der Logrotation das aktuellste Log anzeigen
    Show-LatestModuleLog -ModuleName $ModuleName

}
catch {
    Write-Error "Ein Fehler ist aufgetreten: $_"
}
