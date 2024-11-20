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
    .\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-Verbose")
    Loads the DiskCheck module with verbose output.

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
$script:ModulesPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "Modules"
$script:FrameworkLogDir = Join-Path $PSScriptRoot "Logs"
$script:OriginalPSModulePath = $env:PSModulePath

# Create framework log directory if it doesn't exist
if (-not (Test-Path $FrameworkLogDir)) {
    New-Item -ItemType Directory -Path $FrameworkLogDir | Out-Null
}

# Use a single rolling log file instead of timestamp-based files
$script:FrameworkLogFile = Join-Path $FrameworkLogDir "Framework.log"

function Write-FrameworkLog {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information'
    )
    
    $LogMessage = "[$(Get-Date)] [$Severity] - $Message"
    
    # Create the log file if it doesn't exist
    if (-not (Test-Path $FrameworkLogFile)) {
        $LogMessage | Set-Content -Path $FrameworkLogFile
        Write-Verbose $Message
        return
    }
    
    # Get current log content with thread-safe file access
    $mutex = New-Object System.Threading.Mutex($false, "GlobalFrameworkLogMutex")
    $mutex.WaitOne() | Out-Null
    
    try {
        $logContent = @(Get-Content -Path $FrameworkLogFile)
        
        # Add new message to the beginning of the array
        $logContent = @($LogMessage) + $logContent
        
        # Keep only the last 42 lines
        if ($logContent.Count -gt 42) {
            $logContent = $logContent[0..41]
        }
        
        # Write updated content back to file
        $logContent | Set-Content -Path $FrameworkLogFile
    }
    finally {
        $mutex.ReleaseMutex()
    }
    
    # Output to console based on severity
    switch ($Severity) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        default { Write-Verbose $Message }
    }
}

function Test-ModuleHealth {
    <#
    .SYNOPSIS
        Verifies module health and dependencies.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName
    )

    try {
        Write-FrameworkLog "Verifying module health: $ModuleName"
        
        $modulePath = Join-Path $ModulesPath $ModuleName
        $psd1Path = Join-Path $modulePath "$ModuleName.psd1"
        $psm1Path = Join-Path $modulePath "$ModuleName.psm1"

        # Check module directory
        if (-not (Test-Path $modulePath)) {
            throw "Module directory not found: $modulePath"
        }

        # Check module files
        if (-not (Test-Path $psd1Path)) {
            throw "Module manifest not found: $psd1Path"
        }
        
        if (-not (Test-Path $psm1Path)) {
            throw "Module script not found: $psm1Path"
        }

        # Check module manifest
        $manifest = Import-PowerShellDataFile -Path $psd1Path -ErrorAction Stop
        
        # Validate manifest required fields
        $requiredFields = @('ModuleVersion', 'Author', 'Description')
        foreach ($field in $requiredFields) {
            if (-not $manifest.ContainsKey($field)) {
                throw "Module manifest missing required field: $field"
            }
        }
        
        # Verify required directories
        $logDir = Join-Path $modulePath "Logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir | Out-Null
        }

        # Verify module can be imported
        try {
            Import-Module $psm1Path -Force -ErrorAction Stop
            Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
            return $true
        }
        catch {
            throw "Module import test failed: $_"
        }
    }
    catch {
        Write-FrameworkLog "Module health check failed: $_" -Severity 'Error'
        return $false
    }
}

function Show-ModuleOutput {
    <#
    .SYNOPSIS
        Displays module execution output including logs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName
    )

    try {
        $moduleLogDir = Join-Path $ModulesPath "$ModuleName\Logs"
        
        if (-not (Test-Path $moduleLogDir)) {
            Write-FrameworkLog "Module log directory not found: $moduleLogDir" -Severity 'Warning'
            return
        }

        # Get latest log file
        $latestLog = Get-ChildItem -Path $moduleLogDir -Filter "*.log" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestLog) {
            Write-Host "`nModule Log Output:" -ForegroundColor Cyan
            Get-Content -Path $latestLog.FullName | Write-Host
        }
        else {
            Write-FrameworkLog "No log files found in $moduleLogDir" -Severity 'Warning'
        }
    }
    catch {
        Write-FrameworkLog "Error displaying module output: $_" -Severity 'Error'
    }
}

function Update-PSModulePath {
    <#
    .SYNOPSIS
        Updates PSModulePath safely without duplicates.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $paths = $env:PSModulePath -split ';'
        if ($paths -notcontains $ModulesPath) {
            $env:PSModulePath = "$ModulesPath;$env:PSModulePath"
        }
    }
    catch {
        Write-FrameworkLog "Error updating PSModulePath: $_" -Severity 'Error'
        throw
    }
}

function Restore-PSModulePath {
    <#
    .SYNOPSIS
        Restores original PSModulePath.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $env:PSModulePath = $script:OriginalPSModulePath
    }
    catch {
        Write-FrameworkLog "Error restoring PSModulePath: $_" -Severity 'Error'
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
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [string[]]$ModuleParameters
    )

    try {
        Write-FrameworkLog "Starting module execution: $ModuleName"

        # Update PSModulePath
        Update-PSModulePath

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

        # Validate special parameters
        if ($paramList.ContainsKey('ScheduleReboot')) {
            if (-not [DateTime]::TryParse($paramList['ScheduleReboot'], [ref]$null)) {
                throw "Invalid ScheduleReboot time format. Use 'HH:mm' format."
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
        Write-FrameworkLog "Module execution failed: $_" -Severity 'Error'
        Write-Error "Module execution failed: $_"
        return $false
    }
    finally {
        # Restore original PSModulePath
        Restore-PSModulePath
    }
}

function Rotate-ModuleLogs {
    <#
    .SYNOPSIS
        Enhanced log rotation with error handling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$RetainCount = 3
    )

    try {
        $moduleLogDir = Join-Path $ModulesPath "$ModuleName\Logs"
        
        if (-not (Test-Path $moduleLogDir)) {
            return
        }

        # Rotate logs with exclusive file access
        $mutex = New-Object System.Threading.Mutex($false, "Global$($ModuleName)LogMutex")
        $mutex.WaitOne() | Out-Null

        try {
            $files = Get-ChildItem -Path $moduleLogDir -Filter "*.log" |
                Sort-Object LastWriteTime -Descending |
                Select-Object -Skip $RetainCount

            if ($files) {
                foreach ($file in $files) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    }
                    catch {
                        Write-FrameworkLog "Failed to remove log file $($file.Name): $_" -Severity 'Warning'
                    }
                }
                Write-FrameworkLog "Rotated $($files.Count) log files for $ModuleName"
            }
        }
        finally {
            $mutex.ReleaseMutex()
        }
    }
    catch {
        Write-FrameworkLog "Error during log rotation: $_" -Severity 'Error'
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
            $paramStr = $ModuleParameters | ForEach-Object { 
                # Properly escape special characters in parameters
                $param = $_.Replace('"', '\"').Replace('`', '``')
                "`"$param`""
            } -join ' '
            $argList += " -ModuleParameters $paramStr"
        }

        # Restart with elevation
        $process = Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-FrameworkLog "Elevated process failed with exit code: $($process.ExitCode)" -Severity 'Error'
        }

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
    Write-FrameworkLog "Critical error: $_" -Severity 'Error'
    Write-Error "Critical error: $_"
    exit 1
}
finally {
    Write-FrameworkLog "Framework execution completed"
    # Ensure PSModulePath is restored
    Restore-PSModulePath
}
