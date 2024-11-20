<#
.SYNOPSIS
    Installs available Windows Updates with detailed console and log outputs.

.DESCRIPTION
    This module checks for available Windows Updates and installs them.
    During the process, detailed information about the steps performed, found updates, installation progress, and any errors are displayed and logged.
    All actions are saved in a log file in the temporary directory.

.PARAMETER VerboseOutput
    Enables verbose console output to display additional debugging information.

.EXAMPLE
    Invoke-WindowsUpdate
    Installs available Windows Updates with standard console and log outputs.

.EXAMPLE
    Invoke-WindowsUpdate -VerboseOutput
    Installs available Windows Updates with verbose console and log outputs.

.NOTES
    Version:        1.2.0
    Author:         Your Name
    Creation Date:  11/20/2023
    Last Modified:  11/20/2023
#>

function Invoke-WindowsUpdate {
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
            Write-Verbose "Verbose output enabled."
        } else {
            $VerbosePreference = 'SilentlyContinue'
        }

        # Initialization of the log file
        $LogFile = Join-Path -Path $env:TEMP -ChildPath "WindowsUpdateLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        Write-Verbose "Initializing Windows Update process..."
        Write-Verbose "Log file will be created at: $LogFile"
        "[$(Get-Date)] - Windows Update process started." | Out-File -FilePath $LogFile -Encoding UTF8

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Initializing Windows Update process..."
    }

    process {
        try {
            # Checking for available updates
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking for available updates..."
            Write-Information "Checking for available updates..." -InformationAction Continue
            Write-Verbose "Retrieving available updates..."

            # Requires the PSWindowsUpdate module
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Write-Verbose "PSWindowsUpdate module not found. Installing module..."
                Install-Module -Name PSWindowsUpdate -Force -ErrorAction Stop
                Write-Verbose "PSWindowsUpdate module successfully installed."
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
            } else {
                Write-Verbose "PSWindowsUpdate module is present."
                Import-Module -Name PSWindowsUpdate -ErrorAction Stop
            }

            $updates = Get-WindowsUpdate -ErrorAction Stop
            $updateCount = $updates.Count

            if ($updateCount -gt 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Found $updateCount updates."
                Write-Verbose "Found updates:"
                foreach ($update in $updates) {
                    Write-Verbose " - $($update.Title)"
                    "[$(Get-Date)] - Found update: $($update.Title)" | Add-Content -Path $LogFile
                }

                # Installation of the updates
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Installing available updates..."
                Write-Information "Starting installation of updates..." -InformationAction Continue
                Write-Verbose "Starting installation of updates..."

                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction Stop
                $Stopwatch.Stop()

                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Updates successfully installed."
                Write-Verbose "Installation completed in $($Stopwatch.Elapsed.TotalMinutes.ToString("N2")) minutes."
                "[$(Get-Date)] - Updates successfully installed in $($Stopwatch.Elapsed.TotalMinutes.ToString("N2")) minutes." | Add-Content -Path $LogFile
            } else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] No updates available."
                Write-Verbose "No updates were found."
                "[$(Get-Date)] - No updates available." | Add-Content -Path $LogFile
            }
        }
        catch {
            $ErrorMessage = "Error during the installation of Windows Updates: $($_.Exception.Message)"
            Write-Error "[$(Get-Date -Format 'HH:mm:ss')] $ErrorMessage"
            "[$(Get-Date)] - ERROR: $ErrorMessage" | Add-Content -Path $LogFile
        }
    }

    end {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Windows Update process completed."
        Write-Verbose "Windows Update process completed."
        "[$(Get-Date)] - Windows Update process completed." | Add-Content -Path $LogFile
        Write-Verbose "You can find details in the log file: $LogFile"
    }
}
