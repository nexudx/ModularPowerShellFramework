![ModularPowerShellFramework Banner](docs/static/img/banner.webp)

# Modular PowerShell Framework

A robust, modular PowerShell framework designed for system maintenance and administration tasks. This framework provides a structured approach to executing various system maintenance operations with advanced logging, error handling, and reporting capabilities.

## Features

- 🔌 **Modular Architecture**: Easily extendable with plug-and-play modules
- 📝 **Comprehensive Logging**: Detailed logging with rotation for both framework and individual modules
- 🛡️ **Enhanced Error Handling**: Robust error capture and reporting
- 🔐 **Automatic Privilege Elevation**: Seamless handling of administrator privileges
- 🔄 **Parameter Validation**: Thorough validation of module parameters
- 📈 **Performance Monitoring**: Execution time tracking and performance metrics
- 🔍 **Health Checks**: Automated module health verification
- 📊 **Detailed Reporting**: Structured output for all operations

## Available Modules

### Common
Core module providing shared functionality across all modules:
```powershell
# Common module is automatically imported by other modules
# Contains shared utilities for:
# - Logging
# - Error handling
# - Parameter validation
# - Performance monitoring
```

### BrowserCacheCleanup
Efficiently manages browser cache files across multiple browsers:
```powershell
# Clean all browser caches
.\Main.ps1 -ModuleName "BrowserCacheCleanup"

# Clean specific browser with size threshold
.\Main.ps1 -ModuleName "BrowserCacheCleanup" -ModuleParameters @("-BrowserType", "Chrome", "-ThresholdMB", "1000")
```

### DiskCheck
Comprehensive disk health analysis and maintenance:
```powershell
# Basic health check
.\Main.ps1 -ModuleName "DiskCheck"

# Detailed analysis with repair
.\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-RepairMode", "-VerboseOutput", "-TargetDrives", "C:", "D:")
```

### DiskCleanup
Advanced disk space management:
```powershell
# Standard cleanup
.\Main.ps1 -ModuleName "DiskCleanup"

# Aggressive cleanup with specific targets
.\Main.ps1 -ModuleName "DiskCleanup" -ModuleParameters @("-AggressiveMode", "-TargetPaths", "C:\Windows\Temp", "C:\Users\*\AppData\Local\Temp")
```

### PerformanceOptimization
System performance analysis and optimization:
```powershell
# Basic optimization
.\Main.ps1 -ModuleName "PerformanceOptimization"

# Targeted optimization with monitoring
.\Main.ps1 -ModuleName "PerformanceOptimization" -ModuleParameters @("-Areas", "CPU,Memory,Network", "-MonitorDuration", "3600")
```

### ServiceStatusMonitor
Windows service monitoring and management:
```powershell
# Monitor critical services
.\Main.ps1 -ModuleName "ServiceStatusMonitor"

# Monitor specific services with alerts
.\Main.ps1 -ModuleName "ServiceStatusMonitor" -ModuleParameters @("-Services", "wuauserv,spooler", "-AlertThreshold", "300")
```

### TempFileCleanup
Temporary file management:
```powershell
# Standard cleanup
.\Main.ps1 -ModuleName "TempFileCleanup"

# Age-based cleanup with exclusions
.\Main.ps1 -ModuleName "TempFileCleanup" -ModuleParameters @("-MaxAge", "7", "-ExcludePaths", "C:\Important\Temp")
```

### WindowsUpdate
Windows Update management:
```powershell
# Check for updates
.\Main.ps1 -ModuleName "WindowsUpdate"

# Install specific updates
.\Main.ps1 -ModuleName "WindowsUpdate" -ModuleParameters @("-Install", "-Categories", "Security,Critical")
```

## Requirements

- PowerShell 5.1 or higher
- Windows Operating System
- Administrator privileges for full functionality
- .NET Framework 4.7.2 or higher

## Installation

1. Clone the repository:
```powershell
git clone https://github.com/yourusername/ModularPowerShellFramework.git
```

2. Navigate to the framework directory:
```powershell
cd ModularPowerShellFramework
```

3. Verify installation:
```powershell
.\Main.ps1 -ModuleName "DiskCheck"
```

## Framework Architecture

### Directory Structure
```
ModularPowerShellFramework/
├── Main.ps1                 # Main framework script
├── docs/                    # Documentation
│   └── static/             # Static assets for documentation
│       └── img/            # Documentation images
├── Modules/                 # Module directory
│   ├── Common/             # Shared functionality
│   │   ├── Common.psd1     # Common module manifest
│   │   └── Common.psm1     # Common module implementation
│   ├── BrowserCacheCleanup/
│   ├── DiskCheck/
│   ├── DiskCleanup/
│   ├── PerformanceOptimization/
│   ├── ServiceStatusMonitor/
│   ├── TempFileCleanup/
│   └── WindowsUpdate/
└── Logs/                    # Framework logs
```

### Module Structure
Each module follows a standardized structure:
```
ModuleName/
├── ModuleName.psd1         # Module manifest
├── ModuleName.psm1         # Module implementation
├── README.md               # Module documentation
├── Tests/                  # Module tests
└── Logs/                  # Module-specific logs
```

## Module Dependencies

The framework uses a hierarchical dependency structure:

1. **Common Module**: Base dependency for all modules
   - Provides core logging functionality
   - Implements shared error handling
   - Offers utility functions
   - Manages performance monitoring

2. **Module Dependencies**:
   - DiskCleanup depends on DiskCheck for space analysis
   - PerformanceOptimization uses ServiceStatusMonitor for service management
   - WindowsUpdate requires elevated privileges managed by Common

## Creating New Modules

1. Create a new directory under `Modules/` with your module name
2. Use the following template structure:

```powershell
# ModuleName.psd1
@{
    ModuleVersion = '1.0.0'
    RootModule = 'ModuleName.psm1'
    FunctionsToExport = @('Invoke-ModuleName')
    Author = 'Your Name'
    Description = 'Module description'
    PowerShellVersion = '5.1'
    RequiredModules = @('Common')  # Add module dependencies
    PrivateData = @{
        PSData = @{
            Tags = @('Tag1', 'Tag2')
            Parameters = @{
                # Define parameters here
            }
        }
    }
}

# ModuleName.psm1
function Invoke-ModuleName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$CustomParameter
    )

    begin {
        # Import required modules
        Import-Module -Name Common

        # Initialize logging
        $ModuleLogDir = Join-Path $PSScriptRoot "Logs"
        if (-not (Test-Path $ModuleLogDir)) {
            New-Item -ItemType Directory -Path $ModuleLogDir | Out-Null
        }
    }

    process {
        try {
            # Main module logic
        }
        catch {
            # Error handling
            Write-Error $_
        }
    }

    end {
        # Cleanup and summary
    }
}

Export-ModuleMember -Function Invoke-ModuleName
```

## Best Practices

1. **Error Handling**
   - Use try-catch blocks for critical operations
   - Log all errors with appropriate context
   - Implement proper cleanup in catch blocks

2. **Logging**
   - Use structured logging with timestamps
   - Include severity levels
   - Rotate logs to manage disk space

3. **Parameter Validation**
   - Implement thorough parameter validation
   - Use appropriate parameter attributes
   - Document parameter requirements

4. **Performance**
   - Optimize operations for large datasets
   - Implement progress reporting
   - Consider parallel processing where appropriate

5. **Security**
   - Validate input data
   - Handle credentials securely
   - Implement least privilege principle

## Contributing

1. **Fork the Repository**
   - Create your feature branch
   - Follow the existing module structure
   - Maintain consistent naming conventions

2. **Development Guidelines**
   - Write comprehensive tests
   - Update module documentation
   - Follow PowerShell best practices
   - Use the Common module for shared functionality

3. **Submit Changes**
   - Create detailed pull requests
   - Include test results
   - Update relevant documentation

4. **Code Review**
   - Address review comments
   - Ensure all tests pass
   - Verify documentation accuracy

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- PowerShell Team for the robust scripting platform
- Community contributors and testers
- Open source PowerShell module authors for inspiration
