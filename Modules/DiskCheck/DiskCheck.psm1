<#
.SYNOPSIS
    Performs disk health checks using CHKDSK.
.DESCRIPTION
    This module uses CHKDSK to verify file system integrity and detect disk errors.
.PARAMETER ModuleVerbose
    Enables verbose output for detailed operation information.
.PARAMETER RepairMode
    Enables repair mode to locate bad sectors and recover readable information.
.EXAMPLE
    Invoke-DiskCheck -ModuleVerbose -RepairMode
    Performs a disk check with verbose output and repair mode enabled.
.NOTES
    Ensure the script is run with administrator privileges for full functionality.
#>
function DiskCheck {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose,
        [switch]$RepairMode
    )

    # Determine the module's directory
    $ModuleDirectory = Split-Path $PSCommandPath -Parent

    # Create a log file path
    $LogFilePath = Join-Path $ModuleDirectory "DiskCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        # Start logging
        Start-Transcript -Path $LogFilePath -Append

        if ($ModuleVerbose) { Write-Verbose "Starting Disk Check..." }

        # Get all volumes
        $Volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }

        foreach ($Volume in $Volumes) {
            # Skip volumes without a drive letter
            if (-not $Volume.DriveLetter) {
                continue
            }

            if ($ModuleVerbose) { Write-Verbose "Checking volume: $($Volume.DriveLetter)" }

            try {
                # Construct CHKDSK command parameters
                $ChkdskArgs = "/f /r /x $($Volume.DriveLetter):"
                
                # If RepairMode is specified, add additional repair flags
                if ($RepairMode) {
                    $ChkdskArgs += " /b"  # Locate bad sectors
                }

                # Execute CHKDSK
                $Output = chkdsk.exe $ChkdskArgs

                # Log output
                if ($ModuleVerbose) { Write-Verbose $Output }
            }
            catch {
                Write-Error "Failed to check volume $($Volume.DriveLetter): $_"
            }
        }

        Write-Output "Disk Check Complete."
    }
    catch {
        Write-Error "Disk Check failed: $_"
    }
    finally {
        # Stop logging
        Stop-Transcript
    }
}

# Proxy function to handle parameters
function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose,
        [switch]$RepairMode
    )

    # Pass parameters to the DiskCheck function using splatting
    DiskCheck @PSBoundParameters
}

# Export the proxy function
Export-ModuleMember -Function Invoke-DiskCheck
