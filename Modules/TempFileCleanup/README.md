# TempFileCleanup PowerShell Module

## Overview
The TempFileCleanup module provides comprehensive temporary file cleanup capabilities with advanced filtering, reporting, and logging features. It targets multiple temporary file locations across the Windows system and offers detailed insights into the cleanup process.

## Features
- Multiple temporary location support
- Advanced file filtering options
- Age-based cleanup
- File type filtering
- Pattern exclusion
- Parallel processing
- Space usage tracking
- HTML report generation
- Detailed logging system

## Supported Cleanup Locations
- Windows Temp directory
- User Temp directory
- Windows Prefetch
- Recent items
- Windows Explorer thumbnails
- IIS logs
- Windows CBS logs

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
   Import-Module TempFileCleanup
   ```

## Usage

### Basic Usage
```powershell
# Basic cleanup with default settings
Invoke-TempFileCleanup

# Cleanup with HTML report generation
Invoke-TempFileCleanup -GenerateReport

# Cleanup files older than 7 days
Invoke-TempFileCleanup -MinimumAge 7

# Cleanup specific file types
Invoke-TempFileCleanup -FileTypes "*.tmp","*.log"
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| VerboseOutput | Switch | No | Enables detailed console output |
| MinimumAge | Int | No | Only clean files older than specified days |
| FileTypes | String[] | No | Array of file extensions to clean (e.g., "*.tmp", "*.log") |
| ExcludePatterns | String[] | No | Array of patterns to exclude from cleanup |
| GenerateReport | Switch | No | Generates a detailed HTML report |
| Force | Switch | No | Skips confirmation prompts |

## HTML Report
When enabled, generates a comprehensive report including:
- Cleanup timestamp
- Applied settings
- Results per location
  - Files found/deleted
  - Space found/freed
  - Error details
- Overall summary
- Visual presentation with CSS styling

## Logging
- Automatic log creation for each operation
- Timestamped entries
- Detailed error reporting
- Success/failure tracking
- Space utilization statistics
- Logs stored in module's Logs directory

## Error Handling
- Robust error handling for all operations
- Detailed error logging
- Safe operation termination
- Per-file error tracking
- Comprehensive error reporting

## Best Practices
1. Run with administrator privileges
2. Use -MinimumAge to avoid deleting recent files
3. Test with -VerboseOutput before bulk cleanup
4. Review HTML reports for cleanup verification
5. Maintain exclusion patterns for critical files
6. Schedule regular cleanup operations

## Security Considerations
- Requires elevated privileges for full access
- Safe handling of system files
- Pattern-based exclusion support
- Confirmation prompts for safety
- No system file modification

## Performance Features
- Parallel processing capabilities
- Efficient file enumeration
- Optimized deletion routines
- Progress tracking
- Resource usage monitoring

## Output Information
The module provides detailed cleanup results including:
- Files processed
- Space recovered
- Error counts
- Location-specific details
- Overall statistics

Example console output:
```
Windows Temp Results:
Files Found: 150
Size Found: 250.5 MB
Files Deleted: 148
Size Deleted: 248.3 MB
```

## Version History
- 1.0.0: Initial release
  - Core cleanup functionality
  - HTML reporting
  - Advanced filtering
  - Multi-location support

## Notes
- Some operations require administrator privileges
- System files are protected from deletion
- Performance varies with file count and system load
- HTML reports require write permissions
- Some files may be locked by running processes

## Troubleshooting
1. Run with -VerboseOutput for detailed operation logs
2. Check HTML reports for specific error details
3. Review log files for operation history
4. Verify administrator privileges
5. Ensure target locations are accessible

## Module Structure
```
TempFileCleanup/
├── TempFileCleanup.psm1
├── TempFileCleanup.psd1
├── Logs/
└── README.md
