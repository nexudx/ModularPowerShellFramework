<#
.SYNOPSIS
    Loads and executes PowerShell modules from a specified directory.
.DESCRIPTION
    This script provides a basic framework for loading and executing PowerShell modules.
    Modules are loaded from the 'Modules' subdirectory relative to the script's location.
    Each module should have its own configuration within its directory.
.PARAMETER ModuleName
    The name of the module to load (without the .psm1 extension).
.PARAMETER ModuleParameters
    Additional parameters to pass to the module's invoke function.
.EXAMPLE
    .\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-Param1", "Value1")
.NOTES
    Ensure that the script is run with administrator privileges.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ModuleParameters
)

begin {
    # Check if running as administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "This script requires administrator privileges. Restarting in elevated mode..."
        # Restart the script in an elevated session
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $ModuleName $($ModuleParameters -join ' ')" -Verb RunAs -Wait
        exit # Exit the current non-elevated session
    }

    $ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"

    # Log file management: Retain only the latest three log files for each module
    Get-ChildItem -Path $ModulesPath -Recurse -Filter *.log | 
    Group-Object { $_.DirectoryName } | 
    ForEach-Object {
        $logs = $_.Group | Sort-Object LastWriteTime -Descending
        $logs | Select-Object -Skip 3 | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

process {
    try {
        # Check if the Modules directory exists
        if (-not (Test-Path $ModulesPath)) {
            throw "Modules directory not found: $ModulesPath"
        }

        # Prepend module path to PSModulePath
        $env:PSModulePath = "$ModulesPath;$env:PSModulePath"

        # Import the module by name
        Import-Module $ModuleName -ErrorAction Stop

        # Dynamically construct the command with parameters
        $command = "Invoke-$ModuleName"
        $paramList = @{}
        
        # Parse module parameters
        foreach ($param in $ModuleParameters) {
            if ($param -match '^-(.+)$') {
                $paramName = $matches[1]
                $paramList[$paramName] = $true
            }
        }

        # Execute the module's invoke function with parameters
        & $command @paramList
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

end {
    # Cleanup code if necessary
}
