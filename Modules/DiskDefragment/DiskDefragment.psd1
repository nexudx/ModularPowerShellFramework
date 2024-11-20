@{
    ModuleVersion = '1.0.0'
    RootModule = 'DiskDefragment.psm1'
    FunctionsToExport = 'Invoke-DiskDefragment'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs detailed messages during disk defragmentation.'
                }
            }
        }
    }
}
