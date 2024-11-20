@{
    ModuleVersion = '1.0.0'
    RootModule = 'DiskCheck.psm1'
    FunctionsToExport = 'Invoke-DiskCheck'
    Author = 'System Administrator'
    Description = 'Enhanced disk health check and analysis module providing detailed disk information including space utilization, health status, and hardware details.'
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            Tags = @('Disk', 'Storage', 'Maintenance', 'Health')
            Parameters = @{
                RepairMode = @{
                    Type = 'Switch'
                    Description = 'Performs additional repair operations using chkdsk.'
                }
                VerboseOutput = @{
                    Type = 'Switch'
                    Description = 'Enables detailed console output.'
                }
                TargetDrives = @{
                    Type = 'String[]'
                    Description = 'Specific drives to check. If omitted, checks all fixed drives.'
                }
            }
        }
    }
}
