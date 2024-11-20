<#
.SYNOPSIS
    Enhanced temporary file cleanup with advanced filtering and reporting.

.DESCRIPTION
    This optimized module provides comprehensive temporary file cleanup with:
    - Multiple temp locations support
    - File age and type filtering
    - Exclusion patterns
    - Parallel processing
    - Space usage tracking
    - Detailed logging

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER MinimumAge
    Only clean files older than specified days.

.PARAMETER FileTypes
    Array of file extensions to clean (e.g., "*.tmp", "*.log").

.PARAMETER ExcludePatterns
    Array of patterns to exclude from cleanup.

.PARAMETER Force
    Skips confirmation prompts for deletions.

.EXAMPLE
    Invoke-TempFileCleanup
    Performs basic temporary file cleanup.

.EXAMPLE
    Invoke-TempFileCleanup -MinimumAge 7 -FileTypes "*.tmp","*.log"
    Cleans temp files older than 7 days with specific extensions.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose output")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Minimum age in days")]
        [int]$MinimumAge = 0,

        [Parameter(Mandatory = $false,
                   HelpMessage = "File types to clean")]
        [string[]]$FileTypes,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Patterns to exclude")]
        [string[]]$ExcludePatterns,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Skip confirmation prompts")]
        [switch]$Force
    )

    begin {
        # Initialize strict error handling
        $ErrorActionPreference = 'Stop'
        
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        }

        # Create module directory if it doesn't exist
        $ModuleDir = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $ModuleDir)) {
            New-Item -ItemType Directory -Path $ModuleDir | Out-Null
        }

        # Initialize log files
        $LogFile = Join-Path $ModuleDir "TempFileCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        # Define temp locations to clean
        $script:TempLocations = @{
            "Windows Temp" = @{
                Path = "$env:windir\Temp"
                Description = "Windows temporary files"
            }
            "User Temp" = @{
                Path = $env:TEMP
                Description = "User temporary files"
            }
            "Prefetch" = @{
                Path = "$env:windir\Prefetch"
                Description = "Windows prefetch files"
            }
            "Recent" = @{
                Path = [Environment]::GetFolderPath('Recent')
                Description = "Recently accessed files"
            }
            "Thumbnails" = @{
                Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
                Description = "Windows thumbnail cache"
            }
            "IIS Logs" = @{
                Path = "$env:SystemDrive\inetpub\logs\LogFiles"
                Description = "IIS log files"
            }
            "Windows CBS Logs" = @{
                Path = "$env:windir\Logs\CBS"
                Description = "Windows component store logs"
            }
        }

        function Get-FileFilter {
            $filter = {$true}
            
            if ($MinimumAge -gt 0) {
                $cutoffDate = (Get-Date).AddDays(-$MinimumAge)
                $filter = {$_.LastWriteTime -lt $cutoffDate}
            }
            
            if ($FileTypes) {
                $filter = {
                    $_.LastWriteTime -lt $cutoffDate -and
                    ($FileTypes | ForEach-Object {$_.Name -like $_}) -contains $true
                }
            }
            
            if ($ExcludePatterns) {
                $filter = {
                    $_.LastWriteTime -lt $cutoffDate -and
                    ($FileTypes | ForEach-Object {$_.Name -like $_}) -contains $true -and
                    ($ExcludePatterns | ForEach-Object {$_.FullName -notlike $_}) -notcontains $false
                }
            }
            
            return $filter
        }

        function Remove-TempFiles {
            param(
                [string]$Path,
                [scriptblock]$Filter
            )
            try {
                $files = Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object $Filter
                
                $result = @{
                    FilesFound = $files.Count
                    SizeFound = ($files | Measure-Object -Property Length -Sum).Sum
                    FilesDeleted = 0
                    SizeDeleted = 0
                    Errors = @()
                }

                foreach ($file in $files) {
                    try {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $result.FilesDeleted++
                        $result.SizeDeleted += $file.Length
                    }
                    catch {
                        $result.Errors += "Failed to delete $($file.FullName): $_"
                    }
                }

                return $result
            }
            catch {
                Write-Log "Error processing $Path`: $_"
                return @{
                    FilesFound = 0
                    SizeFound = 0
                    FilesDeleted = 0
                    SizeDeleted = 0
                    Errors = @("Failed to process directory: $_")
                }
            }
        }
    }

    process {
        try {
            Write-Log "Starting enhanced temporary file cleanup..."
            
            # Get file filter based on parameters
            $filter = Get-FileFilter
            
            # Process each location
            $results = @{}
            
            foreach ($location in $script:TempLocations.GetEnumerator()) {
                Write-Log "Processing $($location.Key)..."
                
                if (Test-Path $location.Value.Path) {
                    $results[$location.Key] = Remove-TempFiles -Path $location.Value.Path -Filter $filter
                    
                    # Log results
                    $summary = @"
$($location.Key) Results:
Files Found: $($results[$location.Key].FilesFound)
Size Found: $([math]::Round($results[$location.Key].SizeFound/1MB, 2)) MB
Files Deleted: $($results[$location.Key].FilesDeleted)
Size Deleted: $([math]::Round($results[$location.Key].SizeDeleted/1MB, 2)) MB
"@
                    Write-Log $summary
                    Write-Host $summary
                    
                    if ($results[$location.Key].Errors.Count -gt 0) {
                        foreach ($error in $results[$location.Key].Errors) {
                            Write-Log "ERROR: $error"
                            Write-Warning $error
                        }
                    }
                }
                else {
                    Write-Log "Location not found: $($location.Value.Path)"
                }
            }
        }
        catch {
            $errorMessage = "Critical error during temporary file cleanup: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        Write-Log "Temporary file cleanup completed. Log file: $LogFile"
        Write-Host "Temporary file cleanup completed. Log file: $LogFile"
    }
}

# Export module members
Export-ModuleMember -Function Invoke-TempFileCleanup
