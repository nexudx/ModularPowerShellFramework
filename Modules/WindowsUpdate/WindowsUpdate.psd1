@{
    ModuleVersion = '1.0.0'
    RootModule = 'WindowsUpdate.psm1'
    FunctionsToExport = 'Invoke-WindowsUpdate' # Export the proxy function
    # AliasesToExport = @{ 'WinUpdate' = 'Invoke-WindowsUpdate' } # Example alias
    PrivateData = @{
        PSData = @{
            # Example of how to add module-specific parameters (not directly supported, but can be used for documentation)
            Parameters = @{
                ModuleVerbose = @{
                    Type = 'Switch'
                    Description = 'Outputs verbose messages during execution.'
                }
            }
        }
    }
}
