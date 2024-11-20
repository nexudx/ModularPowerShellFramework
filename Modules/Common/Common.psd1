@{
    ModuleVersion = '1.0.0'
    RootModule = 'Common.psm1'
    FunctionsToExport = @(
        'Write-ModuleLog',
        'Test-AdminPrivilege',
        'New-ModuleLogDirectory',
        'Get-FormattedSize',
        'Get-TimeStamp',
        'Start-ModuleOperation',
        'Stop-ModuleOperation'
    )
    Author = 'System Administrator'
    Description = 'Common utilities and functions shared across framework modules'
    PowerShellVersion = '5.1'
    PrivateData = @{
        PSData = @{
            Tags = @('Common', 'Utilities', 'Logging')
        }
    }
}
