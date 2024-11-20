@{
    ModuleVersion = '1.0.0'
    RootModule = 'BrowserCacheCleanup.psm1'
    FunctionsToExport = 'Invoke-BrowserCacheCleanup'
    PrivateData = @{
        PSData = @{
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs verbose messages during browser cache cleanup.'
                }
            }
        }
    }
}
