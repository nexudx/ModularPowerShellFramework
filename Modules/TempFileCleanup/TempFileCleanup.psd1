@{
    ModuleVersion = '1.0.0'
    RootModule = 'TempFileCleanup.psm1'
    Author = 'System Administrator'
    Description = 'Module for cleaning up temporary files to free up disk space'
    FunctionsToExport = 'Invoke-TempFileCleanup'
    PrivateData = @{
        PSData = @{
            # 'Parameters' section removed as 'ModuleVerbose' is no longer used
        }
    }
}
