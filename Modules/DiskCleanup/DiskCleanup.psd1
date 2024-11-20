@{
    ModuleVersion = '1.0.0'
    RootModule = 'DiskCleanup.psm1'
    FunctionsToExport = 'Invoke-DiskCleanup'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs verbose messages during disk cleanup.'
                }
            }
        }
    }
}
