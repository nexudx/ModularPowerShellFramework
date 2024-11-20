@{
    ModuleVersion = '1.0.0'
    RootModule = 'BrowserCacheCleanup.psm1'
    Author = 'System Administrator'
    Description = 'Module for cleaning browser caches to free up disk space and improve browser performance'
    FunctionsToExport = 'Invoke-BrowserCacheCleanup'
    PrivateData = @{
        PSData = @{
            # 'Parameters' Sektion entfernt, da 'ModuleVerbose' nicht mehr verwendet wird
        }
    }
}
