<#
.SYNOPSIS
    Performs defragmentation on traditional Hard Disk Drives (HDDs).
.DESCRIPTION
    This module checks disk types and defragments only traditional HDDs, 
    avoiding unnecessary operations on SSDs which can reduce their lifespan.
.PARAMETER ModuleVerbose
    Enables verbose output for detailed operation information.
.EXAMPLE
    Invoke-DiskDefragment -ModuleVerbose
    Performs defragmentation on HDDs with verbose output enabled.
.NOTES
    Ensure the script is run with administrator privileges for full functionality.
#>
function DiskDefragment {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Determine the module's directory
    $ModuleDirectory = Split-Path $PSCommandPath -Parent

    # Create a log file path
    $LogFilePath = Join-Path $ModuleDirectory "DiskDefragment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        # Start logging
        Start-Transcript -Path $LogFilePath -Append

        if ($ModuleVerbose) { Write-Verbose "Starting Disk Defragmentation..." }

        # Get all volumes
        $Volumes = Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' }

        # Track defragmentation results
        $DefragmentedVolumes = @()
        $SkippedVolumes = @()

        foreach ($Volume in $Volumes) {
            # Get disk information
            $DiskInfo = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $Volume.Path.Replace('\\?\', '') }

            if ($DiskInfo) {
                # Check if the disk is an HDD (MediaType 3 represents HDD)
                if ($DiskInfo.MediaType -eq 3) {
                    if ($ModuleVerbose) { Write-Verbose "Defragmenting volume: $($Volume.DriveLetter)" }

                    # Use Optimize-Volume cmdlet for defragmentation
                    Optimize-Volume -DriveLetter $Volume.DriveLetter -Verbose:$ModuleVerbose -ErrorAction Stop

                    $DefragmentedVolumes += $Volume.DriveLetter
                }
                else {
                    if ($ModuleVerbose) { Write-Verbose "Skipping volume $($Volume.DriveLetter): Not an HDD" }
                    $SkippedVolumes += $Volume.DriveLetter
                }
            }
        }

        # Output defragmentation summary
        Write-Output "Disk Defragmentation Complete:"
        Write-Output "Defragmented Volumes:"
        $DefragmentedVolumes | ForEach-Object { Write-Output $_ }
        
        Write-Output "`nSkipped Volumes:"
        $SkippedVolumes | ForEach-Object { Write-Output $_ }
    }
    catch {
        Write-Error "Disk Defragmentation failed: $_"
    }
    finally {
        # Stop logging
        Stop-Transcript
    }
}

# Proxy function to handle the -ModuleVerbose parameter
function Invoke-DiskDefragment {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Pass parameters to the DiskDefragment function using splatting
    DiskDefragment @PSBoundParameters
}

# Export the proxy function
Export-ModuleMember -Function Invoke-DiskDefragment
