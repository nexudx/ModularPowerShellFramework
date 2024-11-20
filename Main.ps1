# Main PowerShell Framework Script
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$ModuleNames,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ModuleParameters
)

$script:ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"
$script:FrameworkLogDir = Join-Path $PSScriptRoot "Logs"

# Create framework log directory if it doesn't exist
if (-not (Test-Path $FrameworkLogDir)) {
    New-Item -ItemType Directory -Path $FrameworkLogDir | Out-Null
}

$script:FrameworkLogFile = Join-Path $FrameworkLogDir "Framework.log"

function Write-FrameworkLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information'
    )
    
    $LogMessage = "[$(Get-Date)] [$Severity] - $Message"
    Add-Content -Path $FrameworkLogFile -Value $LogMessage
    
    switch ($Severity) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        default { Write-Verbose $Message }
    }
}

function Test-ModuleHealth {
    param([string]$ModuleName)
    
    try {
        $modulePath = Join-Path $ModulesPath $ModuleName
        if (-not (Test-Path $modulePath)) { return $false }
        
        $psd1Path = Join-Path $modulePath "$ModuleName.psd1"
        $psm1Path = Join-Path $modulePath "$ModuleName.psm1"
        
        if (-not (Test-Path $psd1Path) -or -not (Test-Path $psm1Path)) {
            return $false
        }
        
        Import-Module $psm1Path -Force -ErrorAction Stop
        Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        Write-FrameworkLog "Module health check failed: $_" -Severity 'Error'
        return $false
    }
}

function Show-ModuleOutput {
    param([string]$ModuleName)
    
    $moduleLogDir = Join-Path $ModulesPath "$ModuleName\Logs"
    if (Test-Path $moduleLogDir) {
        $latestLog = Get-ChildItem -Path $moduleLogDir -Filter "*.log" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
            
        if ($latestLog) {
            Write-Host "`nModule Log Output ($ModuleName):" -ForegroundColor Cyan
            Get-Content -Path $latestLog.FullName | Write-Host
        }
    }
}

function Invoke-ModuleWithElevation {
    param(
        [string]$ModuleName
    )

    $elevateScript = @"
Set-Location '$PSScriptRoot'
`$env:PSModulePath = '$ModulesPath;' + `$env:PSModulePath
Import-Module '$ModuleName'
Invoke-$ModuleName
"@
    
    $elevateScriptPath = Join-Path $env:TEMP "ElevateModule_$ModuleName.ps1"
    $elevateScript | Set-Content -Path $elevateScriptPath -Force
    
    try {
        $process = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$elevateScriptPath`"" -Verb RunAs -Wait -PassThru
        
        if ($process.ExitCode -ne 0) {
            Write-FrameworkLog "Elevated process for $ModuleName failed with exit code: $($process.ExitCode)" -Severity 'Error'
        }
    }
    finally {
        if (Test-Path $elevateScriptPath) {
            Remove-Item -Path $elevateScriptPath -Force
        }
    }
    
    Show-ModuleOutput -ModuleName $ModuleName
}

function Get-AvailableModules {
    Get-ChildItem -Path $ModulesPath -Directory |
        Where-Object { $_.Name -ne "Common" -and (Test-ModuleHealth $_.Name) } |
        Select-Object -ExpandProperty Name
}

# Main execution
try {
    Write-FrameworkLog "Framework execution started"

    # Get available modules
    $availableModules = Get-AvailableModules
    if ($availableModules.Count -eq 0) {
        throw "No healthy modules found"
    }

    # Module selection handling
    if (-not $ModuleNames -or $ModuleNames.Count -eq 0) {
        Write-Host "`nAvailable Modules:"
        for ($i = 0; $i -lt $availableModules.Count; $i++) {
            Write-Host "[$($i + 1)] $($availableModules[$i])"
        }

        $selectedModules = @()
        do {
            Write-Host "`nSelect modules to run (comma-separated numbers, e.g. '1,3,4' or 'all' for all modules):"
            $userSelection = Read-Host
            
            if ($userSelection.ToLower() -eq 'all') {
                $selectedModules = $availableModules
                break
            }
            
            $selections = $userSelection -split ',' | ForEach-Object { $_.Trim() }
            $selectedModules = foreach ($sel in $selections) {
                $index = [int]$sel - 1
                if ($index -ge 0 -and $index -lt $availableModules.Count) {
                    $availableModules[$index]
                }
            }
        } until ($selectedModules.Count -gt 0)

        $ModuleNames = $selectedModules
    }
    # Handle 'all' parameter
    elseif ($ModuleNames.Count -eq 1 -and $ModuleNames[0].ToLower() -eq 'all') {
        Write-FrameworkLog "All modules selected via parameter"
        $ModuleNames = $availableModules
    }

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    foreach ($ModuleName in $ModuleNames) {
        Write-Host "`nExecuting module: $ModuleName" -ForegroundColor Green
        
        if (-not $isAdmin) {
            Write-Warning "Elevating privileges for module execution: $ModuleName"
            Invoke-ModuleWithElevation -ModuleName $ModuleName
        }
        else {
            # Already running as admin, execute directly
            $env:PSModulePath = "$ModulesPath;$env:PSModulePath"
            Import-Module $ModuleName
            & "Invoke-$ModuleName"
            Show-ModuleOutput -ModuleName $ModuleName
        }
    }
}
catch {
    Write-FrameworkLog "Critical error: $_" -Severity 'Error'
    throw
}
finally {
    Write-FrameworkLog "Framework execution completed"
}
