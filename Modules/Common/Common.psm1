# Common PowerShell Framework Functions

#Region Logging Functions
function Write-ModuleLog {
    <#
    .SYNOPSIS
        Writes a log entry with standardized formatting.
    .DESCRIPTION
        Creates a timestamped log entry with severity level and ensures proper log directory structure.
    .PARAMETER Message
        The message to log.
    .PARAMETER Severity
        The severity level of the log entry (Information, Warning, Error).
    .PARAMETER ModuleName
        The name of the module generating the log.
    .PARAMETER LogDirectory
        Optional custom log directory path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',
        
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory
    )

    try {
        if (-not $LogDirectory) {
            $LogDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) "$ModuleName\Logs"
        }

        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }

        $LogFile = Join-Path $LogDirectory "$ModuleName`_$(Get-Date -Format 'yyyyMMdd').log"
        $TimeStamp = Get-TimeStamp
        $LogMessage = "[$TimeStamp] [$Severity] - $Message"
        
        Add-Content -Path $LogFile -Value $LogMessage -Encoding UTF8

        # Mirror to console with appropriate styling
        switch ($Severity) {
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message }
            default { Write-Verbose $Message }
        }
    }
    catch {
        Write-Error "Failed to write to log: $_"
    }
}

function New-ModuleLogDirectory {
    <#
    .SYNOPSIS
        Creates a log directory for a module if it doesn't exist.
    .DESCRIPTION
        Ensures the module has a proper log directory structure and handles rotation.
    .PARAMETER ModuleName
        The name of the module requiring the log directory.
    .PARAMETER RetentionDays
        Number of days to retain log files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [int]$RetentionDays = 30
    )

    try {
        $LogDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) "$ModuleName\Logs"
        
        if (-not (Test-Path $LogDirectory)) {
            New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        }

        # Cleanup old logs
        Get-ChildItem -Path $LogDirectory -Filter "*.log" |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
            Remove-Item -Force

        return $LogDirectory
    }
    catch {
        Write-Error "Failed to create/manage log directory: $_"
        return $null
    }
}
#EndRegion

#Region Utility Functions
function Test-AdminPrivilege {
    <#
    .SYNOPSIS
        Checks if the current PowerShell session has administrator privileges.
    .DESCRIPTION
        Verifies if the current user context has elevated privileges.
    #>
    [CmdletBinding()]
    param()
    
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FormattedSize {
    <#
    .SYNOPSIS
        Converts bytes to human-readable size format.
    .DESCRIPTION
        Formats byte sizes into KB, MB, GB, TB with appropriate precision.
    .PARAMETER Bytes
        The size in bytes to format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )
    
    $sizes = 'Bytes,KB,MB,GB,TB'
    $order = 0
    while ($Bytes -ge 1024 -and $order -lt 4) {
        $Bytes = $Bytes/1024
        $order++
    }
    return "{0:N2} {1}" -f $Bytes, ($sizes -split ',')[$order]
}

function Get-TimeStamp {
    <#
    .SYNOPSIS
        Gets a standardized timestamp string.
    .DESCRIPTION
        Returns a formatted timestamp for consistent logging.
    #>
    [CmdletBinding()]
    param()
    
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Start-ModuleOperation {
    <#
    .SYNOPSIS
        Initializes a module operation with proper logging and validation.
    .DESCRIPTION
        Sets up the environment for a module operation, including log initialization
        and privilege checking.
    .PARAMETER ModuleName
        The name of the module starting operation.
    .PARAMETER RequiresAdmin
        Whether the operation requires administrator privileges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $false)]
        [bool]$RequiresAdmin = $false
    )

    try {
        $LogDir = New-ModuleLogDirectory -ModuleName $ModuleName
        Write-ModuleLog -Message "Starting $ModuleName operation" -ModuleName $ModuleName -LogDirectory $LogDir

        if ($RequiresAdmin -and -not (Test-AdminPrivilege)) {
            throw "This operation requires administrator privileges"
        }

        return @{
            StartTime = Get-Date
            LogDirectory = $LogDir
            Success = $true
        }
    }
    catch {
        Write-ModuleLog -Message "Failed to start operation: $_" -Severity 'Error' -ModuleName $ModuleName
        return @{
            StartTime = Get-Date
            Success = $false
            Error = $_
        }
    }
}

function Stop-ModuleOperation {
    <#
    .SYNOPSIS
        Completes a module operation with proper logging and cleanup.
    .DESCRIPTION
        Handles the completion of a module operation, including performance metrics
        and final status logging.
    .PARAMETER ModuleName
        The name of the module completing operation.
    .PARAMETER StartTime
        The start time of the operation for duration calculation.
    .PARAMETER Success
        Whether the operation completed successfully.
    .PARAMETER ErrorMessage
        Optional error message if operation failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,
        
        [Parameter(Mandatory = $true)]
        [bool]$Success,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage
    )

    try {
        $Duration = (Get-Date) - $StartTime
        $Status = if ($Success) { "completed successfully" } else { "failed" }
        
        $Message = "$ModuleName operation $Status. Duration: $($Duration.TotalSeconds) seconds"
        if (-not $Success -and $ErrorMessage) {
            $Message += ". Error: $ErrorMessage"
        }

        Write-ModuleLog -Message $Message -Severity $(if ($Success) { 'Information' } else { 'Error' }) -ModuleName $ModuleName
    }
    catch {
        Write-ModuleLog -Message "Error in Stop-ModuleOperation: $_" -Severity 'Error' -ModuleName $ModuleName
    }
}
#EndRegion

# Export module members
Export-ModuleMember -Function @(
    'Write-ModuleLog',
    'Test-AdminPrivilege',
    'New-ModuleLogDirectory',
    'Get-FormattedSize',
    'Get-TimeStamp',
    'Start-ModuleOperation',
    'Stop-ModuleOperation'
)
