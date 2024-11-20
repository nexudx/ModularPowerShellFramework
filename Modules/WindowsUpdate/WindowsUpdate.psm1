<#
.SYNOPSIS
    Installs Windows Updates.
.DESCRIPTION
    This module provides a function to install available Windows Updates.
.PARAMETER ModuleVerbose
    Enables verbose output for detailed operation information.
.EXAMPLE
    Invoke-WindowsUpdate -ModuleVerbose
    Installs available Windows Updates with verbose output enabled.
.NOTES
    Ensure the script is run with administrator privileges for full functionality.
#>
function WindowsUpdate {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Determine the module's directory
    $ModuleDirectory = Split-Path $PSCommandPath -Parent

    # Create a log file path
    $LogFilePath = Join-Path $ModuleDirectory "WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

    try {
        # Start logging
        Start-Transcript -Path $LogFilePath -Append

        if ($ModuleVerbose) { Write-Verbose "Starting Windows Update process..." }

        # Register PSGallery if it's not already registered
        if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
            if ($ModuleVerbose) { Write-Verbose "Registering PSGallery..." }
            Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2 -InstallationPolicy Trusted -ErrorAction Stop
        }

        # Check if the Windows Update module is already installed
        if (-not (Get-Module PSWindowsUpdate -ListAvailable)) {
            if ($ModuleVerbose) { Write-Verbose "Installing PSWindowsUpdate module..." }
            Install-Module PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
        }

        Import-Module PSWindowsUpdate -ErrorAction Stop

        if ($ModuleVerbose) { Write-Verbose "Searching for available updates..." }
        
        # Use -AcceptAll to automatically accept updates
        $updates = Get-WindowsUpdate -AcceptAll -ErrorAction Stop

        if ($updates) {
            if ($ModuleVerbose) { Write-Verbose "Installing updates..." }
            
            # Use -AcceptAll to automatically install updates
            $updates | Install-WindowsUpdate -AcceptAll -ForceInstall -ErrorAction Stop

            Write-Output "Windows Updates installed successfully."
        }
        else {
            Write-Output "No Windows Updates found."
        }
    }
    catch {
        Write-Error "Failed to install Windows Updates: $_"
    }
    finally {
        # Stop logging
        Stop-Transcript
    }
}

# Proxy function to handle the -ModuleVerbose parameter
function Invoke-WindowsUpdate {
    [CmdletBinding()]
    param(
        [switch]$ModuleVerbose
    )

    # Pass parameters to the WindowsUpdate function using splatting
    WindowsUpdate @PSBoundParameters
}

# Export the proxy function
Export-ModuleMember -Function Invoke-WindowsUpdate
