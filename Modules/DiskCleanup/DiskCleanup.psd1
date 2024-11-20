@{
    ModuleVersion = '1.0.0'
    RootModule    = 'DiskCleanup.psm1'
    FunctionsToExport = 'Invoke-DiskCleanup'
    PrivateData = @{
        PSData = @{
            # 'Parameters' Sektion entfernt, da 'ModuleVerbose' nicht mehr verwendet wird
        }
    }
}
