# BrowserCacheCleanup PowerShell Module

## Overview
The BrowserCacheCleanup module provides efficient browser cache cleanup functionality with support for multiple browsers and parallel processing capabilities. It's designed to help system administrators and users manage browser cache storage effectively across different browser profiles.

## Features
- Multi-browser support:
  - Google Chrome
  - Mozilla Firefox
  - Microsoft Edge
  - Opera
  - Brave Browser
- Multiple profile handling for each browser
- Pre/post cleanup size reporting
- Process handling for locked files
- Parallel processing for improved performance
- Detailed logging functionality
- Support for forced cleanup with browser process management

## Requirements
- PowerShell 5.1 or later
- Administrator privileges recommended for optimal performance
- Windows operating system

## Installation
1. Copy the module folder to one of your PowerShell module directories:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Import the module:
   ```powershell
   Import-Module BrowserCacheCleanup
   ```

## Usage

### Basic Usage
```powershell
Invoke-BrowserCacheCleanup
```

### Advanced Usage
```powershell
# Clean cache with verbose output
Invoke-BrowserCacheCleanup -VerboseOutput

# Clean cache only if it exceeds 2GB
Invoke-BrowserCacheCleanup -ThresholdGB 2

# Force cleanup by closing browser processes if needed
Invoke-BrowserCacheCleanup -Force

# Combine parameters
Invoke-BrowserCacheCleanup -VerboseOutput -ThresholdGB 2 -Force
```

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| VerboseOutput | Switch | No | Enables detailed console output |
| ThresholdGB | Double | No | Only clean if cache size exceeds this value in GB |
| Force | Switch | No | Forces cleanup by closing browser processes if needed |

## Output
The cmdlet returns a hashtable containing detailed results for each browser:
- Initial cache size
- Final cache size
- Space freed
- Number of files processed
- Error count (if any)
- Profile-specific details

Example output:
```
Cache cleanup completed:
- Initial cache size: 3.45 GB
- Total space freed: 3.2 GB
- Files processed: 1234
- Browsers processed: 3
- Total errors: 0
```

## Logging
The module automatically maintains logs in the `Logs` directory within the module folder. Each cleanup operation creates a timestamped log file with detailed information about the process.

## Error Handling
- Implements robust error handling with try-catch blocks
- Handles locked files gracefully
- Provides detailed error messages in logs
- Continues processing despite individual file errors

## Security Considerations
- Runs with user's privileges
- Administrator rights recommended for full functionality
- Implements safe file handling practices
- Validates paths before operations

## Best Practices
1. Run with administrator privileges for best results
2. Close browsers before running forced cleanup
3. Use verbose output for troubleshooting
4. Review logs for detailed operation information
5. Regular cache cleanup scheduling recommended

## Version History
- 1.0.0: Initial release with core functionality

## Notes
- Some operations may require administrator privileges
- Performance varies based on cache size and system resources
- Browser processes will be terminated when using -Force parameter
