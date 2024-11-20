# DiskCleanup PowerShell Module

## Navigation
- [🏠 Main Documentation](../../README.md)
- Other Modules:
  - [🌐 BrowserCacheCleanup](../BrowserCacheCleanup/README.md)
  - [💽 DiskCheck](../DiskCheck/README.md)
  - [🗑️ TempFileCleanup](../TempFileCleanup/README.md)
  - [🔄 WindowsUpdate](../WindowsUpdate/README.md)

## Overview
The DiskCleanup module provides streamlined disk cleanup operations for Windows systems. It performs essential cleanup tasks to free up disk space by removing temporary files, cleaning downloads, emptying the recycle bin, and managing Windows Update files.

## Features
- Windows temporary files cleanup
- User temporary files removal
- Downloads folder management
- Recycle bin emptying
- Windows Update cleanup
- Detailed logging of all operations
- Space savings reporting
- Support for multiple drives
- Optional confirmation prompts

## Requirements
- PowerShell 5.1 or later
- Windows operating system
- Administrator privileges for full functionality

## Installation
1. Copy the module folder to one of your PowerShell module directories:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Import the module:
   ```powershell
   Import-Module DiskCleanup
   ```

## Usage

### Basic Usage
```powershell
# Clean system drive with confirmations
Invoke-DiskCleanup

# Clean specific drive without confirmations
Invoke-DiskCleanup -Drive "D:" -Force

# Clean without touching Downloads folder
Invoke-DiskCleanup -SkipDownloads
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Drive | String | No | Target drive letter for cleanup (e.g., "C:"). Defaults to system drive |
| SkipDownloads | Switch | No | Skip cleaning the Downloads folder |
| Force | Switch | No | Suppress confirmation prompts |

## Cleanup Operations

### 1. Windows Temporary Files
- System temp folder cleanup
- Windows temp folder cleanup
- Prefetch folder cleanup

### 2. User Files
- User temporary files removal
- Downloads folder cleanup (optional)

### 3. System Cleanup
- Recycle Bin emptying
- Windows Disk Cleanup utility execution
- Windows Update component cleanup

## Output Information
The module provides detailed cleanup results including:
- Initial free space
- Final free space
- Total space freed
- Location of detailed log file

Example output:
```
Cleanup Summary for Drive C:
-------------------------------
Initial Free Space: 50.25 GB
Final Free Space: 65.75 GB
Space Freed: 15.50 GB
Log File: [path to log file]
```

## Logging
- Automatic log creation for each cleanup operation
- Timestamped entries for all actions
- Detailed error reporting
- Space utilization tracking
- Logs stored in module's Logs directory

## Error Handling
- Robust error handling for all operations
- Graceful handling of locked files
- Detailed error logging
- Safe operation termination on critical errors

## Best Practices
1. Run with administrator privileges
2. Backup important data before cleanup
3. Use -SkipDownloads when uncertain about Downloads folder contents
4. Review logs after cleanup operations
5. Schedule regular cleanup operations

## Security Considerations
- Requires elevated privileges for full functionality
- Confirmation prompts for potentially destructive operations
- Safe handling of system files
- No modification of protected system areas

## Version History
- 2.0.0: Current version
  - Enhanced error handling
  - Improved space calculation
  - Added force option
  - Extended logging capabilities

## Notes
- Some operations require administrator privileges
- Windows Update cleanup may take significant time
- Space freed may vary based on system state
- Some files may be locked by running processes

## Tags
- Cleanup
- Maintenance
- Storage

## Author
System Administrator
