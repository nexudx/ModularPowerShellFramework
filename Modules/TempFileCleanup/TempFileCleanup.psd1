@{
    ModuleVersion = '1.0.0'
    RootModule = 'TempFileCleanup.psm1'
    FunctionsToExport = 'Invoke-TempFileCleanup'
    PrivateData = @{
        PSData = @{
            # 'Parameters' Sektion entfernt, da 'ModuleVerbose' nicht mehr verwendet wird
        }
    }
}
