<#
.SYNOPSIS
    Performs system disk cleanup and frees up disk space.
.DESCRIPTION
    This module provides comprehensive disk cleanup functionality, 
    removing temporary files, system files, and other unnecessary data.
.PARAMETER ModuleVerbose
    Enables verbose output for detailed operation information.
.EXAMPLE
    Invoke-DiskCleanup -ModuleVerbose
    Performs a disk cleanup with verbose output enabled.
.NOTES
    Ensure the script is run with administrator privileges for full functionality.
#>
function DiskCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Determine the module's directory
    $ModuleDirectory = Split-Path $PSCommandPath -Parent

    # Create a log file path
    $LogFilePath = Join-Path $ModuleDirectory "DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        # Start logging
        Start-Transcript -Path $LogFilePath -Append

        if ($ModuleVerbose) { Write-Verbose "Starting Disk Cleanup..." }

        # Clean Temporary Files
        if ($ModuleVerbose) { Write-Verbose "Cleaning Temporary Files..." }
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clean Windows Update Cache
        if ($ModuleVerbose) { Write-Verbose "Cleaning Windows Update Cache..." }
        Stop-Service -Name wuauserv -Force
        Remove-Item -Path "$env:WINDIR\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv

        # Clean Downloaded Program Files
        if ($ModuleVerbose) { Write-Verbose "Cleaning Downloaded Program Files..." }
        Remove-Item -Path "$env:WINDIR\Downloaded Program Files\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clean Prefetch Data
        if ($ModuleVerbose) { Write-Verbose "Cleaning Prefetch Data..." }
        Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Run Built-in Disk Cleanup Utility with all options
        if ($ModuleVerbose) { Write-Verbose "Running Built-in Disk Cleanup Utility..." }
        Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -Wait

        Write-Output "Disk Cleanup completed successfully."
    }
    catch {
        Write-Error "Disk Cleanup failed: $_"
    }
    finally {
        # Stop logging
        Stop-Transcript
    }
}

# Proxy function to handle the -ModuleVerbose parameter
function Invoke-DiskCleanup {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Pass parameters to the DiskCleanup function using splatting
    DiskCleanup @PSBoundParameters
}

# Export the proxy function
Export-ModuleMember -Function Invoke-DiskCleanup
