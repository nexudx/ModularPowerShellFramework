@{
    ModuleVersion = '1.0.0'
    RootModule = 'WindowsUpdate.psm1'
    Author = 'System Administrator'
    Description = 'Module for managing and installing Windows Updates'
    FunctionsToExport = 'Invoke-WindowsUpdate' # Export the proxy function
    # AliasesToExport = @{ 'WinUpdate' = 'Invoke-WindowsUpdate' } # Example alias
    PrivateData = @{
        PSData = @{
            # Module-specific parameters section removed as 'ModuleVerbose' is no longer used
        }
    }
}
