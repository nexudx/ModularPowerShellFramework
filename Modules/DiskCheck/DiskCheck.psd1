@{
    ModuleVersion = '1.0.0'
    RootModule = 'DiskCheck.psm1'
    FunctionsToExport = @('Invoke-DiskCheck')
    Author = 'System Administrator'
    Description = @'
Enhanced disk health check and analysis module providing comprehensive disk information including:
- Space utilization and trends
- Volume health status
- File system details
- SMART status monitoring
- Performance metrics
- Hardware information
- Temperature monitoring
- Latency analysis
'@
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{
            ModuleName = 'Common'
            ModuleVersion = '1.0.0'
        }
    )
    PrivateData = @{
        PSData = @{
            Tags = @('Disk', 'Storage', 'Maintenance', 'Health', 'Performance', 'Monitoring')
            Parameters = @{
                RepairMode = @{
                    Type = 'Switch'
                    Description = 'Enables automatic repair operations using chkdsk.'
                    RequiresAdmin = $true
                    Impact = 'High - May require system restart'
                }
                VerboseOutput = @{
                    Type = 'Switch'
                    Description = 'Enables detailed console output including performance metrics.'
                    RequiresAdmin = $false
                    Impact = 'Low'
                }
                TargetDrives = @{
                    Type = 'String[]'
                    Description = 'Array of drive letters to check. If omitted, checks all fixed drives.'
                    RequiresAdmin = $false
                    Impact = 'Low'
                    Validation = '^[A-Z]:$'
                }
            }
            Examples = @(
                @{
                    Name = 'Basic Check'
                    Command = 'Invoke-DiskCheck'
                    Description = 'Performs basic health check on all drives'
                },
                @{
                    Name = 'Detailed Analysis'
                    Command = 'Invoke-DiskCheck -VerboseOutput'
                    Description = 'Performs detailed analysis with performance metrics'
                },
                @{
                    Name = 'Repair Mode'
                    Command = 'Invoke-DiskCheck -RepairMode -TargetDrives "C:", "D:"'
                    Description = 'Runs repair operations on specific drives'
                }
            )
            Diagnostics = @{
                PerformanceMetrics = @(
                    'Disk Read Latency',
                    'Disk Write Latency',
                    'Disk Queue Length',
                    'Disk Idle Time'
                )
                HealthIndicators = @(
                    'SMART Status',
                    'Volume Health',
                    'File System Integrity',
                    'Disk Temperature'
                )
            }
        }
    }
}
