<#
.SYNOPSIS
    Enhanced disk health check and analysis.

.DESCRIPTION
    Performs comprehensive disk health analysis including:
    - Disk space utilization
    - Volume health status
    - File system information
    - SMART status checks
    - Performance metrics
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

# Import common module
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) "Common\Common.psm1")

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
    [CmdletBinding()]
    param([string]$DriveLetter)
    
    try {
        # Get basic volume information
        $volume = Get-Volume -DriveLetter $DriveLetter[0] -ErrorAction Stop
        
        # Get corresponding disk information
        $partition = $volume | Get-Partition
        $disk = $partition | Get-Disk
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
                Temperature = $physicalDisk.Temperature
                SmartStatus = $physicalDisk.HealthStatus
            }
            Performance = @{
                ReadLatency = $physicalDisk.ReadLatency
                WriteLatency = $physicalDisk.WriteLatency
                IdleTime = $physicalDisk.IdleTime
            }
        }
    }
    catch {
        Write-ModuleLog -Message "Unable to get drive information for $DriveLetter`: $_" -Severity 'Error' -ModuleName 'DiskCheck'
        return $null
    }
}

function Invoke-ChkDsk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter,
        
        [Parameter(Mandatory = $false)]
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
        Write-ModuleLog -Message "Error running chkdsk on drive $DriveLetter`: $_" -Severity 'Error' -ModuleName 'DiskCheck'
        return @{
            ExitCode = -1
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

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
        # Initialize module operation
        $operation = Start-ModuleOperation -ModuleName 'DiskCheck' -RequiresAdmin $RepairMode
        if (-not $operation.Success) {
            throw "Failed to initialize DiskCheck operation"
        }

        if ($VerboseOutput) {
            $VerbosePreference = 'Continue'
        }
    }

    process {
        try {
            Write-ModuleLog -Message "Starting disk check..." -ModuleName 'DiskCheck'
            
            # Get all fixed drives if none specified
            if (-not $TargetDrives) {
                $TargetDrives = Get-Volume | 
                    Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } |
                    Select-Object -ExpandProperty DriveLetter |
                    ForEach-Object { "$_`:" }
            }

            $results = @{}
            foreach ($drive in $TargetDrives) {
                Write-ModuleLog -Message "Analyzing drive $drive..." -ModuleName 'DiskCheck'
                
                # Get drive information
                $driveInfo = Get-DriveInfo -DriveLetter $drive
                
                if ($driveInfo) {
                    # Run chkdsk if repair mode enabled
                    if ($RepairMode) {
                        Write-ModuleLog -Message "Running chkdsk on $drive..." -ModuleName 'DiskCheck'
                        $driveInfo.ChkDsk = Invoke-ChkDsk -DriveLetter $drive -Repair
                    }

                    $results[$drive] = $driveInfo

                    # Output summary
                    $summary = @"

Drive $drive Summary:
-------------------------
Label: $($driveInfo.Volume.Label)
File System: $($driveInfo.Volume.FileSystem)
Health Status: $($driveInfo.Volume.HealthStatus)
Space: $(Get-FormattedSize $driveInfo.Volume.SizeFree) free of $(Get-FormattedSize $driveInfo.Volume.SizeTotal) ($($driveInfo.Volume.PercentFree)% free)
Disk Model: $($driveInfo.Disk.Model)
Media Type: $($driveInfo.Disk.MediaType)
Bus Type: $($driveInfo.Disk.BusType)
Disk Health: $($driveInfo.Disk.HealthStatus)
SMART Status: $($driveInfo.Disk.SmartStatus)
Temperature: $($driveInfo.Disk.Temperature)°C
Performance:
  Read Latency: $($driveInfo.Performance.ReadLatency)ms
  Write Latency: $($driveInfo.Performance.WriteLatency)ms
  Idle Time: $($driveInfo.Performance.IdleTime)%
Firmware Version: $($driveInfo.Disk.FirmwareVersion)
"@
                    if ($driveInfo.ChkDsk) {
                        $summary += "`nChkDsk Status: $(if ($driveInfo.ChkDsk.Success) { 'Passed' } else { 'Failed' })"
                    }

                    Write-Host $summary
                    Write-ModuleLog -Message $summary -ModuleName 'DiskCheck'
                }
            }

            return $results
        }
        catch {
            $errorMessage = "Critical error during disk check: $_"
            Write-ModuleLog -Message $errorMessage -Severity 'Error' -ModuleName 'DiskCheck'
            throw $_
        }
    }

    end {
        # Complete module operation
        Stop-ModuleOperation -ModuleName 'DiskCheck' -StartTime $operation.StartTime -Success $true
    }
}

# Export module members
Export-ModuleMember -Function Invoke-DiskCheck
