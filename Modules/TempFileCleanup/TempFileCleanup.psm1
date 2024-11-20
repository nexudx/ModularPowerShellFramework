<#
.SYNOPSIS
    Removes temporary files from various system and user locations.
.DESCRIPTION
    Comprehensive temporary file cleanup module that removes files from 
    multiple temporary file directories, including user and system temp folders.
.PARAMETER ModuleVerbose
    Enables verbose output for detailed operation information.
.EXAMPLE
    Invoke-TempFileCleanup -ModuleVerbose
    Performs a temporary file cleanup with verbose output enabled.
.NOTES
    Ensure the script is run with administrator privileges for full functionality.
#>
function TempFileCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Determine the module's directory
    $ModuleDirectory = Split-Path $PSCommandPath -Parent

    # Create a log file path
    $LogFilePath = Join-Path $ModuleDirectory "TempFileCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        # Start logging
        Start-Transcript -Path $LogFilePath -Append

        if ($ModuleVerbose) { Write-Verbose "Starting Temporary File Cleanup..." }

        # List of temp directories to clean
        $TempDirectories = @(
            "$env:TEMP",
            "$env:WINDIR\Temp",
            "$env:USERPROFILE\AppData\Local\Temp",
            "$env:SYSTEMROOT\Temp",
            "$env:SYSTEMROOT\System32\config\systemprofile\AppData\Local\Temp"
        )

        # Additional browser and application temp directories
        $BrowserTempDirs = @(
            "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache",
            "$env:USERPROFILE\AppData\Local\Mozilla\Firefox\Profiles\*.default\cache2",
            "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Cache"
        )

        # Track total files and size cleaned
        $TotalFilesCleaned = 0
        $TotalSizeCleaned = 0
        $CleanedFiles = @()
        $CleanedDirectories = @()

        # Clean system temp directories
        foreach ($TempDir in $TempDirectories) {
            if (Test-Path $TempDir) {
                if ($ModuleVerbose) { Write-Verbose "Cleaning temp directory: $TempDir" }
                
                $FilesToRemove = Get-ChildItem $TempDir -Recurse -File -ErrorAction SilentlyContinue | 
                    Where-Object { 
                        $_.LastAccessTime -lt (Get-Date).AddDays(-7) -or 
                        $_.CreationTime -lt (Get-Date).AddDays(-7)
                    }
                
                $FilesToRemove | ForEach-Object {
                    try {
                        $TotalSizeCleaned += $_.Length
                        $CleanedFiles += $_.FullName
                        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                        $TotalFilesCleaned++
                    }
                    catch {
                        if ($ModuleVerbose) { Write-Verbose "Could not remove file: $($_.FullName)" }
                    }
                }

                $CleanedDirectories += $TempDir
            }
        }

        # Clean browser cache directories
        foreach ($BrowserDir in $BrowserTempDirs) {
            $MatchingDirs = Resolve-Path $BrowserDir -ErrorAction SilentlyContinue
            
            if ($MatchingDirs) {
                foreach ($Dir in $MatchingDirs) {
                    if (Test-Path $Dir) {
                        if ($ModuleVerbose) { Write-Verbose "Cleaning browser cache: $Dir" }
                        
                        $FilesToRemove = Get-ChildItem $Dir -Recurse -File -ErrorAction SilentlyContinue
                        
                        $FilesToRemove | ForEach-Object {
                            try {
                                $TotalSizeCleaned += $_.Length
                                $CleanedFiles += $_.FullName
                                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                                $TotalFilesCleaned++
                            }
                            catch {
                                if ($ModuleVerbose) { Write-Verbose "Could not remove browser cache file: $($_.FullName)" }
                            }
                        }

                        $CleanedDirectories += $Dir
                    }
                }
            }
        }

        # Output cleanup summary
        Write-Output "Temporary File Cleanup Complete:"
        Write-Output "Total Files Cleaned: $TotalFilesCleaned"
        Write-Output "Total Space Freed: $([math]::Round($TotalSizeCleaned / 1MB, 2)) MB"
        
        Write-Output "`nCleaned Directories:"
        $CleanedDirectories | ForEach-Object { Write-Output $_ }
        
        Write-Output "`nCleaned Files:"
        $CleanedFiles | ForEach-Object { Write-Output $_ }
    }
    catch {
        Write-Error "Temporary File Cleanup failed: $_"
    }
    finally {
        # Stop logging
        Stop-Transcript
    }
}

# Proxy function to handle the -ModuleVerbose parameter
function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Pass parameters to the TempFileCleanup function using splatting
    TempFileCleanup @PSBoundParameters
}

# Export the proxy function
Export-ModuleMember -Function Invoke-TempFileCleanup
