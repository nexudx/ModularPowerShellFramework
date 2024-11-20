@{
    ModuleVersion = '1.0.0'
    RootModule    = 'DiskCheck.psm1'
    FunctionsToExport = 'Invoke-DiskCheck'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                RepairMode = @{
                    Type = 'Switch'
                    Description = 'Performs additional repair operations, including bad sector scanning.'
                }
            }
        }
    }
}
