@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ServiceStatusMonitor.psm1'

    # Version number of this module.
    ModuleVersion = '2.0.0'

    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789012'

    # Author of this module
    Author = 'System Administrator'

    # Company or vendor of this module
    CompanyName = 'Organization'

    # Copyright statement for this module
    Copyright = '(c) 2023. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Enhanced Windows Service Status Monitor with comprehensive change detection, state tracking, and detailed logging capabilities.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Functions to export from this module
    FunctionsToExport = @('Invoke-ServiceStatusMonitor')

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Windows', 'Services', 'Monitoring', 'Status', 'Change-Detection')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 2.0.0
- Complete rewrite with enhanced functionality
- Added JSON-based state tracking
- Improved change detection for new and removed services
- Enhanced logging with structured data
- Added service property monitoring
- Implemented log retention management
'@
        }
    }
}
