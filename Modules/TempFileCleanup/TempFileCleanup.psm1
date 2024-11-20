# Module-level variables
$script:ModuleRoot = $PSScriptRoot
$script:LogMutex = New-Object System.Threading.Mutex($false, "GlobalTempFileCleanupLogMutex")

# Define cleanup locations
$script:TempLocations = @{
    "Windows Temp" = @{
        Path = "$env:windir\Temp"
        Description = "Windows temporary files"
        Pattern = "*\Temp"
    }
    "User Temp" = @{
        Path = $env:TEMP
        Description = "User temporary files"
        Pattern = "*\Temp"
    }
    "Prefetch" = @{
        Path = "$env:windir\Prefetch"
        Description = "Windows prefetch files"
        Pattern = "*\Prefetch"
    }
    "Recent" = @{
        Path = [Environment]::GetFolderPath('Recent')
        Description = "Recently accessed files"
        Pattern = "*\Recent"
    }
    "Thumbnails" = @{
        Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        Description = "Windows thumbnail cache"
        Pattern = "*\Explorer"
    }
    "IIS Logs" = @{
        Path = "$env:SystemDrive\inetpub\logs\LogFiles"
        Description = "IIS log files"
        Pattern = "*\LogFiles"
    }
    "Windows CBS Logs" = @{
        Path = "$env:windir\Logs\CBS"
        Description = "Windows component store logs"
        Pattern = "*\CBS"
    }
}

function Write-CleanupLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information'
    )
    
    $LogDir = Join-Path $script:ModuleRoot "Logs"
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    $LogFile = Join-Path $LogDir "TempFileCleanup_$(Get-Date -Format 'yyyyMMdd').log"
    $LogMessage = "[$(Get-Date)] [$Severity] - $Message"
    
    $script:LogMutex.WaitOne() | Out-Null
    try {
        Add-Content -Path $LogFile -Value $LogMessage
        
        switch ($Severity) {
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message }
            default { Write-Verbose $Message }
        }
    }
    finally {
        $script:LogMutex.ReleaseMutex()
    }
}

function Test-FileLock {
    param([string]$Path)
    
    try {
        $file = [System.IO.File]::Open($Path, 'Open', 'Read', 'None')
        $file.Close()
        $file.Dispose()
        return $false
    }
    catch {
        return $true
    }
}

function Remove-TempFilesInternal {
    param(
        [string]$Path,
        [string]$Pattern,
        [int]$MinAge = 0,
        [string[]]$FileTypes,
        [string[]]$ExcludePatterns
    )

    $result = @{
        FilesFound = 0
        SizeFound = 0
        FilesDeleted = 0
        SizeDeleted = 0
        LockedFiles = 0
        Errors = @()
    }

    try {
        # Basic path validation
        if (-not $Path -or -not (Test-Path $Path -ErrorAction SilentlyContinue)) {
            return $result
        }

        # Build filter
        $filter = {$true}
        if ($MinAge -gt 0) {
            $cutoffDate = (Get-Date).AddDays(-$MinAge)
            $filter = {$_.LastWriteTime -lt $cutoffDate}
        }
        
        if ($FileTypes) {
            $filter = {
                $file = $_
                ($_.LastWriteTime -lt $cutoffDate) -and
                ($FileTypes | Where-Object { $file.Name -like $_ })
            }
        }

        # Get matching files
        $files = Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object $filter

        if (-not $files) { return $result }

        $result.FilesFound = $files.Count
        $result.SizeFound = ($files | Measure-Object -Property Length -Sum).Sum

        foreach ($file in $files) {
            if (Test-FileLock $file.FullName) {
                $result.LockedFiles++
                continue
            }

            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $result.FilesDeleted++
                $result.SizeDeleted += $file.Length
            }
            catch {
                $result.Errors += "Failed to delete $($file.FullName): $_"
            }
        }
    }
    catch {
        $result.Errors += "Error processing $Path`: $_"
    }

    return $result
}

function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 365)]
        [int]$MinimumAge = 0,

        [Parameter(Mandatory = $false)]
        [string[]]$FileTypes,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePatterns,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    try {
        Write-CleanupLog "Starting temporary file cleanup..."
        
        $results = @{}
        $totalSaved = 0
        $totalFiles = 0
        $totalLocked = 0
        $totalErrors = 0

        foreach ($location in $script:TempLocations.GetEnumerator()) {
            Write-CleanupLog "Processing $($location.Key)..."
            
            $result = Remove-TempFilesInternal `
                -Path $location.Value.Path `
                -Pattern $location.Value.Pattern `
                -MinAge $MinimumAge `
                -FileTypes $FileTypes `
                -ExcludePatterns $ExcludePatterns

            $summary = @"
$($location.Key) Results:
Files Found: $($result.FilesFound)
Size Found: $([math]::Round($result.SizeFound/1MB, 2)) MB
Files Deleted: $($result.FilesDeleted)
Size Deleted: $([math]::Round($result.SizeDeleted/1MB, 2)) MB
Locked Files: $($result.LockedFiles)
"@
            Write-CleanupLog $summary
            Write-Host $summary

            if ($result.Errors.Count -gt 0) {
                foreach ($error in $result.Errors) {
                    Write-CleanupLog "ERROR: $error" -Severity 'Warning'
                }
            }

            $totalSaved += $result.SizeDeleted
            $totalFiles += $result.FilesDeleted
            $totalLocked += $result.LockedFiles
            $totalErrors += $result.Errors.Count
        }

        $finalSummary = @"

Cleanup Complete:
Total Files Deleted: $totalFiles
Total Space Saved: $([math]::Round($totalSaved/1MB, 2)) MB
Total Locked Files: $totalLocked
Total Errors: $totalErrors
"@
        Write-CleanupLog $finalSummary
        Write-Host $finalSummary
    }
    catch {
        Write-CleanupLog "Critical error during cleanup: $_" -Severity 'Error'
        throw
    }
}

# Export module members
Export-ModuleMember -Function Invoke-TempFileCleanup
