<#
.SYNOPSIS
    Enhanced PowerShell module management framework with advanced features.

.DESCRIPTION
    This optimized framework provides comprehensive module management:
    - Module selection and execution
    - Parameter validation and parsing
    - Log and report management
    - Module health verification
    - Execution summary
    - Error handling

.PARAMETER ModuleName
    The name of the module to load (without the .psm1 extension).
    If not specified, a module selection prompt will be displayed.

.PARAMETER ModuleParameters
    Additional parameters passed to the module's Invoke function.

.EXAMPLE
    .\Main.ps1
    Starts the framework and displays the module selection prompt.

.EXAMPLE
    .\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-Verbose", "-GenerateReport")
    Loads the DiskCheck module with verbose output and report generation.

.NOTES
    Requires Administrator privileges for full functionality.
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
$FrameworkLogDir = Join-Path $PSScriptRoot "Logs"

# Create framework log directory if it doesn't exist
if (-not (Test-Path $FrameworkLogDir)) {
    New-Item -ItemType Directory -Path $FrameworkLogDir | Out-Null
}

# Use a single rolling log file instead of timestamp-based files
$FrameworkLogFile = Join-Path $FrameworkLogDir "Framework.log"

function Write-FrameworkLog {
    param([string]$Message)
    
    $LogMessage = "[$(Get-Date)] - $Message"
    
    # Create the log file if it doesn't exist
    if (-not (Test-Path $FrameworkLogFile)) {
        $LogMessage | Set-Content -Path $FrameworkLogFile
        Write-Verbose $Message
        return
    }
    
    # Get current log content
    $logContent = @(Get-Content -Path $FrameworkLogFile)
    
    # Add new message to the beginning of the array
    $logContent = @($LogMessage) + $logContent
    
    # Keep only the last 42 lines
    if ($logContent.Count -gt 42) {
        $logContent = $logContent[0..41]
    }
    
    # Write updated content back to file
    $logContent | Set-Content -Path $FrameworkLogFile
    Write-Verbose $Message
}

function Test-ModuleHealth {
    <#
    .SYNOPSIS
        Verifies module health and dependencies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        Write-FrameworkLog "Verifying module health: $ModuleName"
        
        $modulePath = Join-Path $ModulesPath $ModuleName
        $psd1Path = Join-Path $modulePath "$ModuleName.psd1"
        $psm1Path = Join-Path $modulePath "$ModuleName.psm1"

        # Check module files
        if (-not (Test-Path $psd1Path) -or -not (Test-Path $psm1Path)) {
            throw "Module files missing or incomplete"
        }

        # Check module manifest
        $manifest = Import-PowerShellDataFile -Path $psd1Path
        
        # Verify required directories
        $logDir = Join-Path $modulePath "Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir | Out-Null
        }

        return $true
    }
    catch {
        Write-FrameworkLog "Module health check failed: $_"
        return $false
    }
}

function Show-ModuleOutput {
    <#
    .SYNOPSIS
        Displays module execution output including logs and reports.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    try {
        $moduleLogDir = Join-Path $ModulesPath "$ModuleName\Logs"
        
        # Get latest log file
        $latestLog = Get-ChildItem -Path $moduleLogDir -Filter "*.log" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestLog) {
            Write-Host "`nModule Log Output:" -ForegroundColor Cyan
            Get-Content -Path $latestLog.FullName | Write-Host
        }

        # Check for HTML report
        $latestReport = Get-ChildItem -Path $moduleLogDir -Filter "*.html" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestReport) {
            Write-Host "`nHTML report generated: $($latestReport.FullName)" -ForegroundColor Green
            # Optionally open the report
            if ($PSCmdlet.ShouldProcess("Open HTML report?")) {
                Start-Process $latestReport.FullName
            }
        }
    }
    catch {
        Write-Error "Error displaying module output: $_"
    }
}

function Invoke-ModuleExecution {
    <#
    .SYNOPSIS
        Executes module with enhanced parameter handling and monitoring.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string[]]$ModuleParameters
    )

    try {
        Write-FrameworkLog "Starting module execution: $ModuleName"

        # Update PSModulePath
        $env:PSModulePath = "$ModulesPath;$env:PSModulePath"

        # Import module
        Import-Module $ModuleName -Force -ErrorAction Stop

        # Parse parameters into hashtable
        $paramList = @{}
        if ($ModuleParameters) {
            for ($i = 0; $i -lt $ModuleParameters.Count; $i++) {
                $param = $ModuleParameters[$i]
                if ($param -match '^-(.+)$') {
                    $paramName = $matches[1]
                    $paramValue = $true
                    if ($i + 1 -lt $ModuleParameters.Count -and -not ($ModuleParameters[$i + 1] -match '^-')) {
                        $paramValue = $ModuleParameters[$i + 1]
                        $i++
                    }
                    $paramList[$paramName] = $paramValue
                }
            }
        }

        # Start execution timer
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        # Execute module
        $Command = "Invoke-$ModuleName"
        & $Command @paramList

        $stopwatch.Stop()
        Write-FrameworkLog "Module execution completed in $($stopwatch.Elapsed.TotalSeconds) seconds"

        return $true
    }
    catch {
        Write-FrameworkLog "Module execution failed: $_"
        Write-Error "Module execution failed: $_"
        return $false
    }
}

function Rotate-ModuleLogs {
    <#
    .SYNOPSIS
        Enhanced log rotation with support for multiple file types.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [int]$RetainCount = 3
    )

    try {
        $moduleLogDir = Join-Path $ModulesPath "$ModuleName\Logs"
        
        if (-not (Test-Path $moduleLogDir)) {
            return
        }

        # Rotate logs
        foreach ($extension in @("*.log", "*.html")) {
            $files = Get-ChildItem -Path $moduleLogDir -Filter $extension |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip $RetainCount

            if ($files) {
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-FrameworkLog "Rotated $($files.Count) $extension files for $ModuleName"
            }
        }
    }
    catch {
        Write-FrameworkLog "Error during log rotation: $_"
    }
}

# Main logic
try {
    Write-FrameworkLog "Framework execution started"

    # Module selection if not specified
    if (-not $ModuleName) {
        $availableModules = Get-ChildItem -Path $ModulesPath -Directory |
            Where-Object { Test-ModuleHealth $_.Name } |
            Select-Object -ExpandProperty Name

        if ($availableModules.Count -eq 0) {
            throw "No healthy modules found in the Modules directory"
        }

        Write-Host "`nAvailable Modules:"
        for ($i = 0; $i -lt $availableModules.Count; $i++) {
            Write-Host "[$($i + 1)] $($availableModules[$i])"
        }

        do {
            $selection = Read-Host "`nSelect module (1-$($availableModules.Count))"
            $selection = [int]$selection - 1
        } until ($selection -ge 0 -and $selection -lt $availableModules.Count)

        $ModuleName = $availableModules[$selection]
    }

    # Verify module health
    if (-not (Test-ModuleHealth $ModuleName)) {
        throw "Module health check failed for $ModuleName"
    }

    # Check administrator privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (-not $isAdmin) {
        Write-Warning "Elevating privileges for module execution..."

        # Prepare elevation arguments
        $argList = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -ModuleName `"$ModuleName`""
        if ($ModuleParameters) {
            $paramStr = $ModuleParameters | ForEach-Object { "`"$_`"" } -join ' '
            $argList += " -ModuleParameters $paramStr"
        }

        # Restart with elevation
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait

        # Show output after elevated process completes
        Show-ModuleOutput -ModuleName $ModuleName
    }
    else {
        # Execute module
        $success = Invoke-ModuleExecution -ModuleName $ModuleName -ModuleParameters $ModuleParameters

        if ($success) {
            # Rotate logs
            Rotate-ModuleLogs -ModuleName $ModuleName

            # Show output
            Show-ModuleOutput -ModuleName $ModuleName
        }
    }
}
catch {
    Write-FrameworkLog "Critical error: $_"
    Write-Error "Critical error: $_"
}
finally {
    Write-FrameworkLog "Framework execution completed"
}
