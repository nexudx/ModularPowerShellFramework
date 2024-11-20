# DiskCheck Module

## Overview
The DiskCheck module provides comprehensive disk health analysis and monitoring capabilities. It performs detailed checks of disk health, performance metrics, and system status while providing repair capabilities when needed.

## Features
- 🔍 **Comprehensive Health Checks**
  - Volume health status
  - File system integrity
  - SMART status monitoring
  - Temperature tracking
  
- 📊 **Performance Analysis**
  - Read/Write latency measurements
  - Disk queue length monitoring
  - Idle time tracking
  - I/O performance metrics
  
- 💾 **Storage Management**
  - Space utilization tracking
  - Trend analysis
  - Capacity planning metrics
  
- 🛠️ **Repair Capabilities**
  - Automatic CHKDSK integration
  - File system error correction
  - Bad sector management
  
## Requirements
- PowerShell 5.1 or higher
- Windows Operating System
- Administrator privileges (for repair operations)
- Storage management PowerShell modules

## Installation
The module is part of the ModularPowerShellFramework. No additional installation steps are required if you're using the framework.

## Usage

### Basic Health Check
```powershell
# Check all drives
Invoke-DiskCheck

# Check specific drives
Invoke-DiskCheck -TargetDrives "C:", "D:"
```

### Detailed Analysis
```powershell
# Detailed check with verbose output
Invoke-DiskCheck -VerboseOutput

# Performance-focused analysis
Invoke-DiskCheck -VerboseOutput -TargetDrives "C:" | Select-Object Performance
```

### Repair Operations
```powershell
# Run with repair mode (requires admin)
Invoke-DiskCheck -RepairMode -TargetDrives "C:"

# Repair with detailed logging
Invoke-DiskCheck -RepairMode -VerboseOutput -TargetDrives "C:", "D:"
```

## Parameters

### RepairMode
- **Type**: Switch
- **Required**: No
- **Admin Required**: Yes
- **Impact**: High
- **Description**: Enables automatic repair operations using CHKDSK
- **Example**:
  ```powershell
  Invoke-DiskCheck -RepairMode
  ```

### VerboseOutput
- **Type**: Switch
- **Required**: No
- **Admin Required**: No
- **Impact**: Low
- **Description**: Enables detailed console output including performance metrics
- **Example**:
  ```powershell
  Invoke-DiskCheck -VerboseOutput
  ```

### TargetDrives
- **Type**: String[]
- **Required**: No
- **Admin Required**: No
- **Impact**: Low
- **Description**: Array of drive letters to check. If omitted, checks all fixed drives
- **Validation**: Must be valid drive letters (e.g., "C:", "D:")
- **Example**:
  ```powershell
  Invoke-DiskCheck -TargetDrives "C:", "D:"
  ```

## Output

### Drive Summary
```
Drive C: Summary:
-------------------------
Label: System
File System: NTFS
Health Status: Healthy
Space: 50.25 GB free of 250.00 GB (20.1% free)
Disk Model: Samsung SSD 970 EVO
Media Type: SSD
Bus Type: NVMe
Disk Health: Healthy
SMART Status: OK
Temperature: 35°C
Performance:
  Read Latency: 0.2ms
  Write Latency: 0.3ms
  Idle Time: 95%
```

## Logging
- Logs are stored in the module's Logs directory
- Log files follow the naming pattern: DiskCheck_YYYYMMDD.log
- Log rotation occurs automatically after 30 days
- Includes severity levels: Information, Warning, Error

## Error Handling
The module implements comprehensive error handling:
- Validates all input parameters
- Catches and logs all exceptions
- Provides detailed error messages
- Implements graceful fallback mechanisms

## Performance Considerations
- Minimal impact during basic checks
- Higher resource usage during detailed analysis
- May impact system performance during repair operations
- Implements throttling for intensive operations

## Best Practices
1. Run basic checks regularly (daily/weekly)
2. Schedule detailed analysis during off-peak hours
3. Review logs periodically for trending issues
4. Use repair mode only when necessary
5. Keep regular backups before running repairs

## Troubleshooting
Common issues and solutions:

### Access Denied
```powershell
# Solution: Run PowerShell as Administrator
Start-Process powershell -Verb RunAs
```

### Drive Not Found
```powershell
# Verify drive existence
Get-Volume | Select-Object DriveLetter
```

### Performance Impact
```powershell
# Use targeted analysis
Invoke-DiskCheck -TargetDrives "C:" -VerboseOutput
```

## Integration
The module integrates with:
- Windows Event Log
- Storage Management APIs
- Performance Monitor
- SMART monitoring systems

## Version History
- 1.0.0
  - Initial release
  - Basic health checks
  - Performance monitoring
  - Repair capabilities
