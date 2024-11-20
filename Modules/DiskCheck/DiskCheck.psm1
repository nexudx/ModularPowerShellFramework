<#
.SYNOPSIS
    Performs a detailed disk check and provides informative console and log outputs.

.DESCRIPTION
    This module performs a comprehensive check of disks and repairs errors if specified. During the process, detailed information about the steps performed, results, and any errors are displayed and logged.

.PARAMETER RepairMode
    Enables repair mode to automatically fix found errors.

.PARAMETER VerboseOutput
    Enables verbose console output.

.EXAMPLE
    Invoke-DiskCheck
    Performs a disk check with default settings and provides informative outputs.

.EXAMPLE
    Invoke-DiskCheck -RepairMode -VerboseOutput
    Performs the disk check in repair mode and displays additional verbose information.

.NOTES
    This module has been enhanced to make console and log outputs significantly more informative. It follows PowerShell Best Practices and implements robust error handling and logging.

#>

function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables repair mode.")]
        [switch]$RepairMode,

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
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "DiskCheckLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initializing disk check..."
        Write-Verbose "Log file will be created at: $LogFile"
        "[$(Get-Date)] - Disk check started." | Out-File -FilePath $LogFile -Encoding UTF8
    }

    process {
        try {
            Write-Verbose "Starting disk check..."
            Write-Information "Disk check is starting." -InformationAction Continue
            Write-Host "Starting disk check..."

            # Platform check
            if ($PSVersionTable.Platform -eq 'Win32NT') {
                # Create command line arguments
                $arguments = "/scan"

                if ($RepairMode.IsPresent) {
                    $arguments += " /forceofflinefix /perf"
                    Write-Verbose "Repair mode enabled."
                    Write-Host "Repair mode is enabled. Found errors will be automatically fixed."
                } else {
                    Write-Verbose "Repair mode not enabled."
                    Write-Host "Repair mode is not enabled. No changes will be made."
                }

                # Determine path to chkdsk.exe
                $ChkdskPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\chkdsk.exe"

                if (Test-Path $ChkdskPath) {
                    Write-Verbose "Executing '$ChkdskPath' with arguments '$arguments'"
                    Write-Host "Running 'chkdsk.exe' with the specified options..."

                    # Start the check and measure the duration
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                    # Create process information
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = $ChkdskPath
                    $processInfo.Arguments = $arguments
                    $processInfo.Verb = "runas"
                    $processInfo.UseShellExecute = $true

                    # Start process
                    $process = [System.Diagnostics.Process]::Start($processInfo)
                    $process.WaitForExit()
                    $Stopwatch.Stop()

                    Write-Verbose "Disk check completed in $($Stopwatch.Elapsed.TotalSeconds) seconds."
                    Write-Host "Disk check completed successfully."
                    "[$(Get-Date)] - Disk check completed successfully in $($Stopwatch.Elapsed.TotalSeconds) seconds." | Add-Content -Path $LogFile

                    # Optional: Evaluation of results
                    # Additional code could be added here to evaluate the results and report in more detail
                } else {
                    $ErrorMessage = "The utility 'chkdsk.exe' was not found."
                    Write-Error $ErrorMessage
                    "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
                }
            } else {
                $WarningMessage = "Disk check is not available on this operating system."
                Write-Warning $WarningMessage
                "[$(Get-Date)] - WARNING: $WarningMessage" | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Error during disk check: $($_.Exception.Message)"
            Write-Error $ErrorMessage
            "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Verbose "Disk check process completed."
        Write-Host "Disk check process completed."
        "[$(Get-Date)] - Disk check process completed." | Add-Content -Path $LogFile
        Write-Verbose "Details can be found in the log file: $LogFile"
    }
}
