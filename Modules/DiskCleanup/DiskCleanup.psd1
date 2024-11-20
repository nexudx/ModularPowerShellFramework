@{
    RootModule = 'DiskCleanup.psm1'
    ModuleVersion = '2.0.0'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'System Administrator'
    Description = 'Streamlined disk cleanup module for efficient system maintenance'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Invoke-DiskCleanup')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Cleanup', 'Maintenance', 'Storage')
            ProjectUri = ''
            LicenseUri = ''
        }
    }
}
