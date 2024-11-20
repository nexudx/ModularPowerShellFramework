@{
    ModuleVersion = '1.0.0'
    RootModule = 'BrowserCacheCleanup.psm1'
    FunctionsToExport = 'Invoke-BrowserCacheCleanup'
    PrivateData = @{
        PSData = @{
            # 'Parameters' Sektion entfernt, da 'ModuleVerbose' nicht mehr verwendet wird
        }
    }
}
