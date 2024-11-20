# WindowsUpdate PowerShell Module

## Overview
The WindowsUpdate module provides enhanced Windows Update management capabilities with advanced filtering, reporting, and control features. It offers comprehensive update management including categorization, bandwidth control, and detailed reporting.

## Features
- Update filtering and categorization
- Update history tracking
- Bandwidth control for downloads
- Scheduled reboot management
- HTML report generation
- Detailed logging system
- KB exclusion support
- Offline update capability

## Requirements
- PowerShell 5.1 or later
- Windows operating system
- Administrator privileges
- PSWindowsUpdate module (auto-installed if missing)

## Installation
1. Copy the module folder to one of your PowerShell module directories:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Import the module:
   ```powershell
   Import-Module WindowsUpdate
   ```

## Usage

### Basic Usage
```powershell
# Install all available updates
Invoke-WindowsUpdate

# Install only security and critical updates
Invoke-WindowsUpdate -Categories "Security","Critical"

# Install updates with bandwidth limit and report
Invoke-WindowsUpdate -MaxBandwidth 10 -GenerateReport

# Install updates and schedule reboot
Invoke-WindowsUpdate -ScheduleReboot "22:00"
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| VerboseOutput | Switch | No | Enables detailed console output |
| Categories | String[] | No | Update categories to include (Security, Critical, Important, Optional) |
| MaxBandwidth | Int | No | Maximum bandwidth in Mbps for update downloads |
| ExcludeKBs | String[] | No | KB numbers to exclude from installation |
| GenerateReport | Switch | No | Generates a detailed HTML report |
| ScheduleReboot | String | No | Schedule reboot time after updates (e.g., "22:00") |
| Force | Switch | No | Skips confirmation prompts |

## HTML Report Features
The generated report includes:
- Update installation timestamp
- Overall statistics
  - Total updates
  - Successful installations
  - Failed installations
  - Installation duration
- Detailed update information
  - Update title
  - KB number
  - Category
  - Installation status
- Visual status indicators
- Formatted tables for easy reading

## Update History Tracking
- JSON-based history storage
- Tracks all update operations
- Includes installation dates
- Records success/failure status
- Maintains KB numbers
- Searchable history file

## Logging System
- Automatic log creation
- Timestamped entries
- Operation tracking
- Error logging
- Success/failure recording
- Bandwidth usage tracking
- Logs stored in module's Logs directory

## Bandwidth Management
- Configurable download speed limits
- BITS integration
- Automatic throttling
- Network impact control
- Progress monitoring

## Error Handling
- Robust error management
- Detailed error logging
- Recovery procedures
- Status tracking
- Rollback capability
- Comprehensive reporting

## Best Practices
1. Run with administrator privileges
2. Schedule updates during off-hours
3. Use bandwidth limits on busy networks
4. Review HTML reports after updates
5. Maintain update history
6. Test critical updates in staging
7. Plan reboot windows carefully

## Security Considerations
- Requires elevated privileges
- Secure update sources
- Validation of updates
- Protected history storage
- Safe reboot handling
- Controlled execution

## Performance Features
- Efficient update scanning
- Optimized download handling
- Parallel processing where possible
- Resource usage monitoring
- Network impact control

## Troubleshooting
1. Check logs for detailed error information
2. Verify network connectivity
3. Confirm administrator privileges
4. Review update history
5. Check Windows Update service status
6. Validate PSWindowsUpdate module

## Module Structure
```
WindowsUpdate/
├── WindowsUpdate.psm1
├── WindowsUpdate.psd1
├── Logs/
│   ├── UpdateHistory.json
│   └── [Generated logs and reports]
└── README.md
```

## Version History
- 1.0.0: Initial release
  - Core update functionality
  - HTML reporting
  - Bandwidth control
  - History tracking

## Notes
- Some updates may require multiple reboots
- Network conditions affect download speed
- System state impacts update success
- Some updates may be prerequisites
- Reboot scheduling requires planning
- History file grows over time

## Dependencies
- PSWindowsUpdate module (auto-installed)
- Windows Update service
- BITS service for downloads
- Administrative privileges
