@{
    ModuleVersion = '1.0.0'
    RootModule = 'TempFileCleanup.psm1'
    FunctionsToExport = 'Invoke-TempFileCleanup'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs detailed messages during temporary file cleanup.'
                }
            }
        }
    }
}
