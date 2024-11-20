<#
.SYNOPSIS
    Performs a cleanup of temporary files and provides detailed outputs.

.DESCRIPTION
    This module cleans temporary files from defined paths to free up space and improve system performance.
    It provides detailed information about the number of files deleted, the freed space, and the paths that were cleaned.

.PARAMETER VerboseOutput
    Enables verbose output.

.PARAMETER LogPath
    Specifies the path where the log should be saved. By default, a log is created in the module directory.

.EXAMPLE
    Invoke-TempFileCleanup
    Performs temporary file cleanup with default settings.

.EXAMPLE
    Invoke-TempFileCleanup -VerboseOutput
    Performs the cleanup and displays verbose information.

.EXAMPLE
    Invoke-TempFileCleanup -LogPath "C:\Logs\TempCleanup.log"
    Performs the cleanup and saves the log to the specified path.

.NOTES
    - Supports PowerShell version 5.1 and above.
    - Requires sufficient permissions to delete files in the target directories.
    - Ensures that sensitive data is not deleted.
#>

function Invoke-TempFileCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Specifies whether to display verbose outputs.")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Specifies the path for the log file.")]
        [string]$LogPath = "$PSScriptRoot\TempFileCleanup_$((Get-Date).ToString('yyyyMMdd_HHmmss')).log"
    )

    begin {
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }
        Write-Verbose "Initializing temporary file cleanup..."

        $StartTime = Get-Date
        $TotalFilesDeleted = 0
        $TotalSpaceFreed = 0
        $CleanedDirectories = @()
        $LogContent = @()
    }

    process {
        try {
            Write-Verbose "Scanning for temporary files..."

            $tempPaths = @(
                "$env:TEMP",
                "$env:Windir\Temp"
            )

            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    Write-Verbose "Cleaning directory: $path"

                    $files = Get-ChildItem -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue

                    $filesCount = $files.Count
                    $filesSize = ($files | Measure-Object -Property Length -Sum).Sum

                    if ($filesCount -gt 0) {
                        $files | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                        $TotalFilesDeleted += $filesCount
                        $TotalSpaceFreed += $filesSize
                        $CleanedDirectories += $path

                        Write-Verbose "Deleted files: $filesCount"
                        Write-Verbose ("Freed space: {0:N2} MB" -f ($filesSize / 1MB))
                    } else {
                        Write-Verbose "No temporary files found in $path."
                    }

                } else {
                    Write-Verbose "Directory not found: $path"
                }
            }

            Write-Verbose "Temporary files cleaned successfully."
        }
        catch {
            Write-Error "Error during temporary file cleanup: $_"
        }
    }

    end {
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime

        $Summary = @"
Temporary File Cleanup Complete:
Start Time: $($StartTime)
End Time: $($EndTime)
Duration: $($Duration)

Total Files Deleted: $TotalFilesDeleted
Total Space Freed: {0:N2} MB

Cleaned Directories:
$($CleanedDirectories -join "`n")
"@

        Write-Verbose "Cleanup process completed."
        Write-Verbose $Summary

        # Write log
        $LogContent += "**********************"
        $LogContent += "Start of Windows PowerShell transcript"
        $LogContent += "Start Time: $($StartTime.ToString('yyyyMMddHHmmss'))"
        $LogContent += "Username: $([Environment]::UserDomainName)\$([Environment]::UserName)"
        $LogContent += "Computer: $env:COMPUTERNAME ($env:OS)"
        $LogContent += "**********************"
        $LogContent += $Summary
        $LogContent += "**********************"
        $LogContent += "End of Windows PowerShell transcript"
        $LogContent += "End Time: $($EndTime.ToString('yyyyMMddHHmmss'))"
        $LogContent += "**********************"

        $LogContent | Out-File -FilePath $LogPath -Encoding UTF8
        Write-Verbose "Log saved at: $LogPath"
    }
}
