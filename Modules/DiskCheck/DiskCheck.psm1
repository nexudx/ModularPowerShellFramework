<#
.SYNOPSIS
    Enhanced disk health check and analysis.

.DESCRIPTION
    This optimized module performs comprehensive disk health analysis including:
    - Disk space utilization
    - Volume health status
    - File system information
    - Multiple drive support

.PARAMETER RepairMode
    Enables repair mode to automatically fix found errors.

.PARAMETER VerboseOutput
    Enables verbose console output.

.PARAMETER TargetDrives
    Array of specific drive letters to check. If omitted, checks all fixed drives.

.EXAMPLE
    Invoke-DiskCheck
    Performs a basic disk check on all drives.

.EXAMPLE
    Invoke-DiskCheck -RepairMode -VerboseOutput -TargetDrives "C:", "D:"
    Performs detailed analysis on C: and D: drives with repair mode.

.NOTES
    Requires Administrator privileges for full functionality.
#>

function Invoke-DiskCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables repair mode.")]
        [switch]$RepairMode,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Enables verbose console output.")]
        [switch]$VerboseOutput,

        [Parameter(Mandatory = $false,
                   HelpMessage = "Specific drives to check")]
        [string[]]$TargetDrives
    )

    begin {
        # Initialize strict error handling
        $ErrorActionPreference = 'Stop'
        
        if ($VerboseOutput.IsPresent) {
            $VerbosePreference = 'Continue'
        }

        # Create module directory if it doesn't exist
        $ModuleDir = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $ModuleDir)) {
            New-Item -ItemType Directory -Path $ModuleDir | Out-Null
        }

        # Initialize log file in module directory
        $LogFile = Join-Path $ModuleDir "DiskCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        function Write-Log {
            param([string]$Message)
            $LogMessage = "[$(Get-Date)] - $Message"
            $LogMessage | Add-Content -Path $LogFile
            Write-Verbose $Message
        }

        function Get-MediaTypeString {
            param([string]$MediaType)
            switch ($MediaType) {
                0 { "Unspecified" }
                3 { "HDD" }
                4 { "SSD" }
                5 { "SCM" }
                default { $MediaType }
            }
        }

        function Get-DriveInfo {
            param([string]$DriveLetter)
            try {
                # Get basic volume information
                $volume = Get-Volume -DriveLetter $DriveLetter[0] -ErrorAction Stop
                
                # Get corresponding disk information
                $partition = $volume | Get-Partition
                $disk = $partition | Get-Disk

                # Get physical disk for additional properties
                $physicalDisk = Get-PhysicalDisk -DeviceNumber $disk.Number

                return @{
                    Volume = @{
                        DriveLetter = $volume.DriveLetter
                        Label = $volume.FileSystemLabel
                        FileSystem = $volume.FileSystem
                        HealthStatus = $volume.HealthStatus
                        SizeTotal = $volume.Size
                        SizeFree = $volume.SizeRemaining
                        SizeUsed = ($volume.Size - $volume.SizeRemaining)
                        PercentFree = [math]::Round(($volume.SizeRemaining / $volume.Size) * 100, 2)
                    }
                    Disk = @{
                        Number = $disk.Number
                        Model = $physicalDisk.Model
                        MediaType = (Get-MediaTypeString $physicalDisk.MediaType)
                        BusType = $disk.BusType
                        HealthStatus = $disk.HealthStatus
                        OperationalStatus = $disk.OperationalStatus
                        Size = $disk.Size
                        PartitionStyle = $disk.PartitionStyle
                        FirmwareVersion = $physicalDisk.FirmwareVersion
                    }
                }
            }
            catch {
                Write-Log "Unable to get drive information for $DriveLetter`: $_"
                return $null
            }
        }

        function Invoke-ChkDsk {
            param(
                [string]$DriveLetter,
                [switch]$Repair
            )
            try {
                $ChkdskPath = Join-Path -Path $env:SystemRoot -ChildPath "System32\chkdsk.exe"
                if (-not (Test-Path $ChkdskPath)) {
                    throw "chkdsk.exe not found"
                }

                $arguments = "$DriveLetter /scan"
                if ($Repair) {
                    $arguments += " /f"
                }

                $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                $processInfo.FileName = $ChkdskPath
                $processInfo.Arguments = $arguments
                $processInfo.Verb = "runas"
                $processInfo.UseShellExecute = $true
                $processInfo.RedirectStandardOutput = $false

                $process = [System.Diagnostics.Process]::Start($processInfo)
                $process.WaitForExit()

                return @{
                    ExitCode = $process.ExitCode
                    Success = $process.ExitCode -eq 0
                }
            }
            catch {
                Write-Log "Error running chkdsk on drive $DriveLetter`: $_"
                return @{
                    ExitCode = -1
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
    }

    process {
        try {
            Write-Log "Starting disk check..."
            
            # Get all fixed drives if none specified
            if (-not $TargetDrives) {
                $TargetDrives = Get-Volume | 
                    Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } |
                    Select-Object -ExpandProperty DriveLetter |
                    ForEach-Object { "$_`:" }
            }

            foreach ($drive in $TargetDrives) {
                Write-Log "Analyzing drive $drive..."
                
                # Get drive information
                $driveInfo = Get-DriveInfo -DriveLetter $drive
                
                if ($driveInfo) {
                    # Run chkdsk if repair mode enabled
                    if ($RepairMode) {
                        Write-Log "Running chkdsk on $drive..."
                        $driveInfo.ChkDsk = Invoke-ChkDsk -DriveLetter $drive -Repair
                    }

                    # Output summary
                    $summary = @"

Drive $drive Summary:
-------------------------
Label: $($driveInfo.Volume.Label)
File System: $($driveInfo.Volume.FileSystem)
Health Status: $($driveInfo.Volume.HealthStatus)
Space: $([math]::Round($driveInfo.Volume.SizeFree/1GB, 2))GB free of $([math]::Round($driveInfo.Volume.SizeTotal/1GB, 2))GB ($($driveInfo.Volume.PercentFree)% free)
Disk Model: $($driveInfo.Disk.Model)
Media Type: $($driveInfo.Disk.MediaType)
Bus Type: $($driveInfo.Disk.BusType)
Disk Health: $($driveInfo.Disk.HealthStatus)
Firmware Version: $($driveInfo.Disk.FirmwareVersion)
"@
                    if ($driveInfo.ChkDsk) {
                        $summary += "`nChkDsk Status: $(if ($driveInfo.ChkDsk.Success) { 'Passed' } else { 'Failed' })"
                    }

                    Write-Host $summary
                    Write-Log $summary
                }
            }
        }
        catch {
            $errorMessage = "Critical error during disk check: $_"
            Write-Log $errorMessage
            Write-Error $errorMessage
        }
    }

    end {
        $summary = "`nDisk check completed. Log file: $LogFile"
        Write-Log $summary
        Write-Host $summary
    }
}

# Export module members
Export-ModuleMember -Function Invoke-DiskCheck
