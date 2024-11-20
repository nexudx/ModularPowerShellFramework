@{
    ModuleVersion = '1.0.0'
    RootModule = 'WindowsUpdate.psm1'
    FunctionsToExport = 'Invoke-WindowsUpdate' # Export the proxy function
    # AliasesToExport = @{ 'WinUpdate' = 'Invoke-WindowsUpdate' } # Example alias
    PrivateData = @{
        PSData = @{
            # Module-specific parameters section removed as 'ModuleVerbose' is no longer used
        }
    }
}
