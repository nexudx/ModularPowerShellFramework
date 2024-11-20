<#
.SYNOPSIS
    Performs efficient disk cleanup operations on specified drives.

.DESCRIPTION
    Streamlined disk cleanup module that performs essential cleanup tasks:
    - Windows temporary files
    - User temporary files
    - Downloads folder cleanup
    - Recycle bin emptying
    - Windows Update cleanup

.PARAMETER Drive
    Target drive letter for cleanup. Defaults to system drive if not specified.

.PARAMETER SkipDownloads
    Skip cleaning the Downloads folder.

.PARAMETER Force
    Suppress confirmation prompts.

.EXAMPLE
    Invoke-DiskCleanup
    Performs cleanup on system drive with confirmations.

.EXAMPLE
    Invoke-DiskCleanup -Drive "D:" -Force
    Performs cleanup on D: drive without confirmations.

.NOTES
    Requires Administrator privileges for full functionality.
#>
function Invoke-DiskCleanup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0)]
        [ValidatePattern('^[A-Za-z]:$')]
        [string]$Drive = $env:SystemDrive,

        [switch]$SkipDownloads,

        [switch]$Force
    )

    begin {
        # Initialize logging
        $LogPath = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        $LogFile = Join-Path $LogPath "DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        function Write-CleanupLog {
            param([string]$Message)
            $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            "$TimeStamp - $Message" | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        # Get initial drive space
        $InitialSpace = (Get-PSDrive -Name $Drive[0]).Free
        Write-CleanupLog "Initial free space: $([math]::Round($InitialSpace/1GB, 2)) GB"
    }

    process {
        try {
            Write-CleanupLog "Starting disk cleanup on drive $Drive"

            # 1. Clean Windows Temp folders
            $TempPaths = @(
                $env:TEMP,
                "$env:SystemRoot\Temp",
                "$env:SystemRoot\Prefetch"
            )

            foreach ($Path in $TempPaths) {
                if (Test-Path $Path) {
                    Write-CleanupLog "Cleaning temporary files in: $Path"
                    Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }

            # 2. Clean Downloads folder if not skipped
            if (-not $SkipDownloads) {
                $DownloadsPath = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
                if ((Test-Path $DownloadsPath) -and ($Force -or $PSCmdlet.ShouldProcess($DownloadsPath, "Clear Downloads folder"))) {
                    Write-CleanupLog "Cleaning Downloads folder"
                    Get-ChildItem -Path $DownloadsPath -Recurse -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
            }

            # 3. Empty Recycle Bin
            if ($Force -or $PSCmdlet.ShouldProcess("Recycle Bin", "Empty")) {
                Write-CleanupLog "Emptying Recycle Bin"
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            }

            # 4. Run Windows Disk Cleanup utility
            $CleanMgr = Join-Path $env:SystemRoot "System32\cleanmgr.exe"
            if (Test-Path $CleanMgr) {
                Write-CleanupLog "Running Windows Disk Cleanup"
                Start-Process -FilePath $CleanMgr -ArgumentList "/sagerun:1 /d $Drive" -Wait -NoNewWindow
            }

            # 5. Clean Windows Update files
            Write-CleanupLog "Cleaning Windows Update files"
            Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -NoNewWindow

            # Calculate space freed
            $FinalSpace = (Get-PSDrive -Name $Drive[0]).Free
            Write-CleanupLog "Final free space: $([math]::Round($FinalSpace/1GB, 2)) GB"
            
            $SpaceFreed = $FinalSpace - $InitialSpace
            $SpaceFreedGB = [math]::Round($SpaceFreed/1GB, 2)
            
            # Ensure we don't show negative space freed
            $SpaceFreedDisplay = if ($SpaceFreedGB -lt 0) { "0.00" } else { $SpaceFreedGB }
            
            $Summary = @"
Cleanup Summary for Drive $Drive
-------------------------------
Initial Free Space: $([math]::Round($InitialSpace/1GB, 2)) GB
Final Free Space: $([math]::Round($FinalSpace/1GB, 2)) GB
Space Freed: $SpaceFreedDisplay GB
Log File: $LogFile
"@
            Write-CleanupLog $Summary
            Write-Host $Summary
        }
        catch {
            $ErrorMessage = "Error during disk cleanup: $_"
            Write-CleanupLog $ErrorMessage
            Write-Error $ErrorMessage
        }
    }

    end {
        Write-CleanupLog "Disk cleanup completed"
    }
}

Export-ModuleMember -Function Invoke-DiskCleanup
