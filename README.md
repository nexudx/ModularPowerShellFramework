# Modular PowerShell Framework

A robust, modular PowerShell framework designed for system maintenance and administration tasks. This framework provides a structured approach to executing various system maintenance operations with advanced logging, error handling, and reporting capabilities.

## Features

- 🔌 **Modular Architecture**: Easily extendable with plug-and-play modules
- 📝 **Comprehensive Logging**: Detailed logging with rotation for both framework and individual modules
- 🛡️ **Enhanced Error Handling**: Robust error capture and reporting
- 📊 **HTML Report Generation**: Visual representation of execution results
- 🔐 **Automatic Privilege Elevation**: Seamless handling of administrator privileges
- 🔄 **Parameter Validation**: Thorough validation of module parameters
- 📈 **Performance Monitoring**: Execution time tracking and performance metrics

## Available Modules

- **BrowserCacheCleanup**: Cleans browser cache files
- **DiskCheck**: Performs comprehensive disk health analysis
- **DiskCleanup**: Manages disk space by cleaning unnecessary files
- **PerformanceOptimization**: Provides system performance optimization with monitoring and analysis
- **ServiceStatusMonitor**: Tracks Windows service status changes with comprehensive monitoring
- **TempFileCleanup**: Removes temporary system files
- **WindowsUpdate**: Manages Windows Update operations

## Requirements

- PowerShell 5.1 or higher
- Windows Operating System
- Administrator privileges for full functionality

## Installation

1. Clone the repository:
```powershell
git clone https://github.com/yourusername/ModularPowerShellFramework.git
```

2. Navigate to the framework directory:
```powershell
cd ModularPowerShellFramework
```

## Usage

### Basic Usage

Run the framework without parameters to see the module selection menu:
```powershell
.\Main.ps1
```

### Direct Module Execution

Execute a specific module with parameters:
```powershell
.\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-RepairMode", "-VerboseOutput")
```

### Module-Specific Examples

#### DiskCheck Module
```powershell
# Basic disk check on all drives
.\Main.ps1 -ModuleName "DiskCheck"

# Detailed check with repair mode on specific drives
.\Main.ps1 -ModuleName "DiskCheck" -ModuleParameters @("-RepairMode", "-VerboseOutput", "-TargetDrives", "C:", "D:")
```

#### ServiceStatusMonitor Module
```powershell
# Monitor all services
.\Main.ps1 -ModuleName "ServiceStatusMonitor"

# Monitor specific services with verbose output
.\Main.ps1 -ModuleName "ServiceStatusMonitor" -ModuleParameters @("-TargetServices", "wuauserv,spooler", "-VerboseOutput")
```

#### PerformanceOptimization Module
```powershell
# Basic performance optimization
.\Main.ps1 -ModuleName "PerformanceOptimization"

# Optimize specific areas with verbose output
.\Main.ps1 -ModuleName "PerformanceOptimization" -ModuleParameters @("-Areas", "CPU,Memory,Network", "-VerboseOutput")
```

## Framework Architecture

### Directory Structure
```
ModularPowerShellFramework/
├── Main.ps1                 # Main framework script
├── Modules/                 # Module directory
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
Each module follows a consistent structure:
```
ModuleName/
├── ModuleName.psd1         # Module manifest
├── ModuleName.psm1         # Module implementation
├── README.md               # Module documentation
└── Logs/                   # Module-specific logs
```

## Creating New Modules

1. Create a new directory under `Modules/` with your module name
2. Create the module manifest (.psd1) and implementation (.psm1) files
3. Implement the required `Invoke-ModuleName` function
4. Follow the established logging and error handling patterns

Example module template:
```powershell
function Invoke-NewModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$CustomParameter
    )

    begin {
        # Initialize logging
    }

    process {
        try {
            # Main module logic
        }
        catch {
            # Error handling
        }
    }

    end {
        # Cleanup and summary
    }
}

Export-ModuleMember -Function Invoke-NewModule
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- PowerShell Team for the robust scripting platform
- Community contributors and testers
