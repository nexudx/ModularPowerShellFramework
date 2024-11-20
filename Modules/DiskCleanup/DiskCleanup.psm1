# Import common module
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) "Common\Common.psm1")

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
        # Initialize module operation
        $operation = Start-ModuleOperation -ModuleName 'DiskCleanup'
        if (-not $operation.Success) {
            throw "Failed to initialize DiskCleanup operation"
        }

        # Get initial drive space
        $InitialSpace = (Get-PSDrive -Name $Drive[0]).Free
        Write-ModuleLog -Message "Initial free space: $([math]::Round($InitialSpace/1GB, 2)) GB" -ModuleName 'DiskCleanup'
    }

    process {
        try {
            Write-ModuleLog -Message "Starting disk cleanup on drive $Drive" -ModuleName 'DiskCleanup'

            # 1. Clean Windows Temp folders
            $TempPaths = @(
                $env:TEMP,
                "$env:SystemRoot\Temp",
                "$env:SystemRoot\Prefetch"
            )

            foreach ($Path in $TempPaths) {
                if (Test-Path $Path) {
                    Write-ModuleLog -Message "Cleaning temporary files in: $Path" -ModuleName 'DiskCleanup'
                    Get-ChildItem -Path $Path -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }

            # 2. Clean Downloads folder if not skipped
            if (-not $SkipDownloads) {
                $DownloadsPath = [Environment]::GetFolderPath('UserProfile') + '\Downloads'
                if ((Test-Path $DownloadsPath) -and ($Force -or $PSCmdlet.ShouldProcess($DownloadsPath, "Clear Downloads folder"))) {
                    Write-ModuleLog -Message "Cleaning Downloads folder" -ModuleName 'DiskCleanup'
                    Get-ChildItem -Path $DownloadsPath -Recurse -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
            }

            # 3. Empty Recycle Bin
            if ($Force -or $PSCmdlet.ShouldProcess("Recycle Bin", "Empty")) {
                Write-ModuleLog -Message "Emptying Recycle Bin" -ModuleName 'DiskCleanup'
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            }

            # 4. Run Windows Disk Cleanup utility
            $CleanMgr = Join-Path $env:SystemRoot "System32\cleanmgr.exe"
            if (Test-Path $CleanMgr) {
                Write-ModuleLog -Message "Running Windows Disk Cleanup" -ModuleName 'DiskCleanup'
                Start-Process -FilePath $CleanMgr -ArgumentList "/sagerun:1 /d $Drive" -Wait -NoNewWindow
            }

            # 5. Clean Windows Update files
            Write-ModuleLog -Message "Cleaning Windows Update files" -ModuleName 'DiskCleanup'
            Start-Process -FilePath "dism.exe" -ArgumentList "/online /cleanup-image /startcomponentcleanup" -Wait -NoNewWindow

            # Calculate space freed
            $FinalSpace = (Get-PSDrive -Name $Drive[0]).Free
            Write-ModuleLog -Message "Final free space: $([math]::Round($FinalSpace/1GB, 2)) GB" -ModuleName 'DiskCleanup'
            
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
"@
            Write-ModuleLog -Message $Summary -ModuleName 'DiskCleanup'
            Write-Host $Summary

            # Complete module operation successfully
            Stop-ModuleOperation -ModuleName 'DiskCleanup' -StartTime $operation.StartTime -Success $true
        }
        catch {
            $ErrorMessage = "Error during disk cleanup: $_"
            Write-ModuleLog -Message $ErrorMessage -Severity 'Error' -ModuleName 'DiskCleanup'
            Stop-ModuleOperation -ModuleName 'DiskCleanup' -StartTime $operation.StartTime -Success $false -ErrorMessage $_.Exception.Message
            throw
        }
    }

    end {
        Write-ModuleLog -Message "Disk cleanup completed" -ModuleName 'DiskCleanup'
    }
}

Export-ModuleMember -Function Invoke-DiskCleanup
