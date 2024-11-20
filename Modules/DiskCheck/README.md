# DiskCheck PowerShell Module

## Overview
The DiskCheck module provides comprehensive disk health analysis and monitoring capabilities for Windows systems. It offers detailed insights into disk space utilization, volume health status, file system information, and hardware details across multiple drives.

## Features
- Comprehensive disk health analysis
- Detailed volume information reporting
- Multiple drive support
- Automatic repair capabilities (via chkdsk)
- Detailed logging functionality
- Support for both HDD and SSD drives
- Hardware information reporting
- Customizable target drive selection

## Requirements
- PowerShell 5.1 or later
- Windows operating system
- Administrator privileges for full functionality (especially repair mode)

## Installation
1. Copy the module folder to one of your PowerShell module directories:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Import the module:
   ```powershell
   Import-Module DiskCheck
   ```

## Usage

### Basic Usage
```powershell
# Check all fixed drives
Invoke-DiskCheck

# Check specific drives
Invoke-DiskCheck -TargetDrives "C:", "D:"

# Check with repair mode
Invoke-DiskCheck -RepairMode

# Check with verbose output
Invoke-DiskCheck -VerboseOutput
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| RepairMode | Switch | No | Enables repair mode to fix found errors using chkdsk |
| VerboseOutput | Switch | No | Enables detailed console output |
| TargetDrives | String[] | No | Array of specific drive letters to check. If omitted, checks all fixed drives |

## Output Information
The module provides detailed information for each drive, including:

### Volume Information
- Drive letter and label
- File system type
- Health status
- Total size
- Free space
- Used space
- Percentage free

### Disk Information
- Disk number
- Model
- Media type (HDD/SSD)
- Bus type
- Health status
- Operational status
- Firmware version
- Partition style

## Logging
- Automatic log creation for each operation
- Logs stored in module's Logs directory
- Timestamped log files
- Detailed operation tracking
- Error logging and troubleshooting information

## Error Handling
- Robust error handling with detailed error messages
- Graceful handling of inaccessible drives
- Comprehensive logging of errors
- Safe operation termination on critical errors

## Best Practices
1. Run with administrator privileges for full functionality
2. Use repair mode cautiously and only when necessary
3. Regular disk health monitoring recommended
4. Review logs for detailed operation information
5. Back up important data before running repair operations

## Security Considerations
- Requires elevated privileges for repair operations
- Safe read-only operations by default
- Careful handling of system drives
- No modification of system files without explicit permission

## Version History
- 1.0.0: Initial release with core functionality
  - Basic disk health checking
  - Volume information reporting
  - Repair mode capability
  - Logging system

## Notes
- Some operations require administrator privileges
- Repair mode uses Windows' built-in chkdsk utility
- Performance may vary based on drive size and system load
- Always backup important data before running repair operations

## Tags
- Disk
- Storage
- Maintenance
- Health

## Author
System Administrator
