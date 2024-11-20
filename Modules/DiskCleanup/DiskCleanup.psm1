<#
.SYNOPSIS
    Performs a detailed disk cleanup and provides informative console and log outputs.

.DESCRIPTION
    This module performs a comprehensive disk cleanup to remove unnecessary files and free up space. During the process, detailed information about the steps performed, results, and any errors are displayed and logged.

.PARAMETER VerboseOutput
    Enables verbose console output.

.EXAMPLE
    Invoke-DiskCleanup
    Performs disk cleanup with default settings and provides informative outputs.

.EXAMPLE
    Invoke-DiskCleanup -VerboseOutput
    Performs the cleanup and displays additional verbose information.

.NOTES
    This module has been enhanced to make console and log outputs significantly more informative. It follows PowerShell Best Practices and implements robust error handling and logging.

#>

function Invoke-DiskCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose console output.")]
        [switch]$VerboseOutput
    )

    begin {
        # Configuration of verbose output
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        # Initialization of the log file
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "DiskCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initializing disk cleanup..."
        Write-Verbose "Log file will be created at: $LogFile"
        "[$(Get-Date)] - Disk cleanup started." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Starting disk cleanup..."
            Write-Information "Disk cleanup is starting." -InformationAction Continue
            Write-Host "Starting disk cleanup..."

            # Platform check
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                # Check if 'cleanmgr.exe' exists
                $CleanMgrPath = Join-Path -Path $env:Windir -ChildPath "System32\cleanmgr.exe"

                if (Test-Path $CleanMgrPath) {
                    $CleanupArgs = "/sagerun:1"
                    Write-Verbose "Executing '$CleanMgrPath' with arguments '$CleanupArgs'"
                    Write-Host "Running 'cleanmgr.exe' with predefined settings..."

                    # Start cleanup and measure duration
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    Start-Process -FilePath $CleanMgrPath -ArgumentList $CleanupArgs -Wait -ErrorAction Stop
                    $Stopwatch.Stop()

                    Write-Verbose "Disk cleanup completed in $($Stopwatch.Elapsed.TotalSeconds) seconds."
                    Write-Host "Disk cleanup completed successfully."
                    "[$(Get-Date)] - Disk cleanup completed successfully in $($Stopwatch.Elapsed.TotalSeconds) seconds." | Add-Content -Path $LogFile

                    # Optional: Add information about freed up space
                    # Additional code could be added here to calculate and display the freed disk space
                }
                else {
                    $ErrorMessage = "The utility 'cleanmgr.exe' was not found."
                    Write-Error $ErrorMessage
                    "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
                }
            }
            else {
                $WarningMessage = "Disk cleanup is not available on this operating system."
                Write-Warning $WarningMessage
                "[$(Get-Date)] - WARNING: $WarningMessage" | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Error during disk cleanup: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Cleanup process completed."
        Write-Host "Cleanup process completed."
        "[$(Get-Date)] - Cleanup process completed." | Add-Content -Path $LogFile
        Write-Verbose "Details can be found in the log file: $LogFile"
    }
}
