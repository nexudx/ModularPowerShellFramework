@{
    ModuleVersion = '1.0.0'
    RootModule = 'DiskCheck.psm1'
    FunctionsToExport = 'Invoke-DiskCheck'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs detailed messages during disk check.'
                }
                RepairMode = @{
                    Type = 'Switch'
                    Description = 'Performs additional repair operations, including bad sector scanning.'
                }
            }
        }
    }
}
