<#
.SYNOPSIS
    Loads and executes PowerShell modules from a specified directory with a module selection prompt at startup.

.DESCRIPTION
    This script provides a framework for loading and executing PowerShell modules.
    Modules are loaded from the 'Modules' subdirectory relative to the script's location.
    At startup, a selection prompt is displayed, allowing the user to choose a module.
    After executing a module, the latest log in the module directory is displayed in the console.
    Log rotation is always performed after a module creates a new log.

.PARAMETER ModuleName
    The name of the module to load (without the .psm1 extension).
    If not specified, a module selection prompt will be displayed.

.PARAMETER ModuleParameters
    Additional parameters passed to the module's Invoke function.

.EXAMPLE
    .\Main.ps1

    Starts the script and displays the module selection prompt.

.EXAMPLE
    .\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-Verbose")

    Loads the 'DiskCheck' module and executes it with the parameter -Verbose.

.NOTES
    Parts of this script require administrator privileges. Displaying the log and performing log rotation after module processing do not require elevated rights.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ModuleName,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ModuleParameters
)

# Global variables
$ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"

function Show-LatestModuleLog {
    <#
    .SYNOPSIS
        Displays the latest log of a module in the console.

    .DESCRIPTION
        This function searches the module directory for the most recent log file and outputs its content to the console.

    .PARAMETER ModuleName
        The name of the module whose log should be displayed.

    .EXAMPLE
        Show-LatestModuleLog -ModuleName "DiskCleanup"

        Displays the latest log of the 'DiskCleanup' module.

    .NOTES
        The function assumes that log files have the '.log' extension and are stored in the module directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        $ModuleDirectory = Join-Path $ModulesPath $ModuleName

        if (-not (Test-Path $ModuleDirectory)) {
            Write-Warning "Module directory not found: $ModuleDirectory"
            return
        }

        $LatestLog = Get-ChildItem -Path $ModuleDirectory -Filter '*.log' |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($LatestLog) {
            Write-Host "Content of the latest log for module '$ModuleName':" -ForegroundColor Cyan
            Get-Content -Path $LatestLog.FullName
        }
        else {
            Write-Warning "No log files found in the module directory for module '$ModuleName'."
        }
    }
    catch {
        Write-Error "Error displaying the latest log: $_"
    }
}

function Invoke-ModuleExecution {
    <#
    .SYNOPSIS
        Executes module processing that requires administrator privileges.

    .DESCRIPTION
        This function loads the selected module and executes the corresponding Invoke function.

    .PARAMETER ModuleName
        The name of the module to load.

    .PARAMETER ModuleParameters
        Additional parameters for the module's Invoke function.

    .EXAMPLE
        Invoke-ModuleExecution -ModuleName "DiskCheck" -ModuleParameters @("-Verbose")

        Executes the 'DiskCheck' module with the parameter -Verbose.

    .NOTES
        This function requires administrator privileges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string[]]$ModuleParameters
    )

    try {
        # Update PSModulePath
        $env:PSModulePath = "$ModulesPath;$env:PSModulePath"

        # Import module
        Import-Module $ModuleName -ErrorAction Stop

        # Dynamically construct the command with parameters
        $Command = "Invoke-$ModuleName"
        $ParamList = @{}

        if ($ModuleParameters) {
            # Parse module parameters
            for ($i = 0; $i -lt $ModuleParameters.Count; $i++) {
                $param = $ModuleParameters[$i]
                if ($param -match '^-(.+)$') {
                    $ParamName = $matches[1]
                    $ParamValue = $true
                    # Check if a value for the parameter was provided
                    if ($i + 1 -lt $ModuleParameters.Count -and -not ($ModuleParameters[$i + 1] -match '^-')) {
                        $ParamValue = $ModuleParameters[$i + 1]
                        $i++
                    }
                    $ParamList[$ParamName] = $ParamValue
                }
            }
        }

        # Execute module function call with parameters
        & $Command @ParamList
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

function Rotate-ModuleLogs {
    <#
    .SYNOPSIS
        Performs log rotation for a module.

    .DESCRIPTION
        Retain only the latest three log files for the specified module.

    .PARAMETER ModuleName
        The name of the module whose logs should be rotated.

    .EXAMPLE
        Rotate-ModuleLogs -ModuleName "DiskCleanup"

        Performs log rotation for the 'DiskCleanup' module.

    .NOTES
        This function does not require administrator privileges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        $ModuleDirectory = Join-Path $ModulesPath $ModuleName

        if (-not (Test-Path $ModuleDirectory)) {
            Write-Warning "Module directory not found: $ModuleDirectory"
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
        Write-Error "Error during log rotation: $_"
    }
}

# Main logic

try {
    # If no module name is specified, start module selection prompt
    if (-not $ModuleName) {
        # List available modules
        $AvailableModules = Get-ChildItem -Path $ModulesPath -Directory | Select-Object -ExpandProperty Name

        if ($AvailableModules.Count -eq 0) {
            throw "No modules found in the Modules directory."
        }

        Write-Host "Available modules:"
        for ($i = 0; $i -lt $AvailableModules.Count; $i++) {
            Write-Host "[$($i + 1)] $($AvailableModules[$i])"
        }

        do {
            $selection = Read-Host "Please select a module by entering the corresponding number"
            $selection = [int]$selection - 1
        } until ($selection -ge 0 -and $selection -lt $AvailableModules.Count)

        $ModuleName = $AvailableModules[$selection]
    }

    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (-not $isAdmin) {
        Write-Warning "Executing the module requires administrator privileges. Restarting in elevated mode..."

        # Prepare arguments
        $argList = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -ModuleName `"$ModuleName`""
        if ($ModuleParameters) {
            $paramStr = $ModuleParameters | ForEach-Object { "`"$_`"" } -join ' '
            $argList += " -ModuleParameters $paramStr"
        }

        # Restart script in elevated session and pass parameters
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
    }
    else {
        # Execute module
        Invoke-ModuleExecution -ModuleName $ModuleName -ModuleParameters $ModuleParameters
    }

    # Perform log rotation after module execution
    Rotate-ModuleLogs -ModuleName $ModuleName

    # After log rotation, display the latest log
    Show-LatestModuleLog -ModuleName $ModuleName

}
catch {
    Write-Error "An error occurred: $_"
}
