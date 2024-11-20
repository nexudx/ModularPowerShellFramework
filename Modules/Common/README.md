# Common PowerShell Module

## Overview
The Common module serves as the core foundation for the ModularPowerShellFramework, providing essential shared functionality used by all other modules. It implements standardized logging, error handling, administrative privilege checking, and operation management functions.

## Core Features

### Logging System
- Standardized log formatting
- Automatic log directory management
- Log rotation with configurable retention
- Severity-based logging (Information, Warning, Error)
- Console output mirroring with appropriate styling

### Operation Management
- Operation lifecycle tracking
- Performance metrics
- Start/Stop operation handling
- Success/Failure status management
- Duration tracking

### Utility Functions
- Administrative privilege verification
- Size formatting (bytes to human-readable)
- Timestamp standardization
- Directory management
- Error handling

## Functions

### Write-ModuleLog
```powershell
Write-ModuleLog -Message "Operation completed" -Severity "Information" -ModuleName "YourModule"
```
Creates standardized log entries with:
- Timestamp
- Severity level
- Module context
- Automatic log directory management
- Console output mirroring

### Test-AdminPrivilege
```powershell
if (Test-AdminPrivilege) {
    # Perform privileged operation
}
```
Verifies if the current PowerShell session has administrator privileges.

### New-ModuleLogDirectory
```powershell
$logDir = New-ModuleLogDirectory -ModuleName "YourModule" -RetentionDays 30
```
- Creates module-specific log directories
- Implements log rotation
- Manages log retention
- Returns log directory path

### Get-FormattedSize
```powershell
$readableSize = Get-FormattedSize -Bytes 1234567
```
Converts byte values to human-readable formats (KB, MB, GB, TB).

### Get-TimeStamp
```powershell
$timestamp = Get-TimeStamp
```
Provides standardized timestamp formatting for consistent logging.

### Start-ModuleOperation
```powershell
$operationContext = Start-ModuleOperation -ModuleName "YourModule" -RequiresAdmin $true
```
Initializes module operations with:
- Log directory setup
- Administrative privilege verification
- Operation context tracking
- Error handling

### Stop-ModuleOperation
```powershell
Stop-ModuleOperation -ModuleName "YourModule" -StartTime $startTime -Success $true
```
Completes module operations with:
- Duration calculation
- Status logging
- Error reporting
- Performance metrics

## Usage Example

```powershell
# Initialize operation
$context = Start-ModuleOperation -ModuleName "ExampleModule" -RequiresAdmin $true

try {
    # Your module logic here
    Write-ModuleLog -Message "Processing..." -ModuleName "ExampleModule"
    
    # Format size output
    $size = Get-FormattedSize -Bytes 1234567
    Write-ModuleLog -Message "Processed size: $size" -ModuleName "ExampleModule"
    
    # Complete operation
    Stop-ModuleOperation -ModuleName "ExampleModule" -StartTime $context.StartTime -Success $true
}
catch {
    # Handle errors
    Write-ModuleLog -Message $_.Exception.Message -Severity "Error" -ModuleName "ExampleModule"
    Stop-ModuleOperation -ModuleName "ExampleModule" -StartTime $context.StartTime -Success $false -ErrorMessage $_.Exception.Message
}
```

## Best Practices

1. **Logging**
   - Use appropriate severity levels
   - Include contextual information
   - Maintain consistent message formatting
   - Implement proper error details

2. **Error Handling**
   - Always use try-catch blocks
   - Log both errors and exceptions
   - Provide meaningful error messages
   - Ensure proper operation cleanup

3. **Operation Management**
   - Track operation context
   - Monitor performance metrics
   - Handle cleanup properly
   - Maintain operation state

4. **Administrative Privileges**
   - Check privileges before operations
   - Provide clear error messages
   - Handle elevation requirements
   - Document privilege needs

## Integration Guidelines

1. **Module Implementation**
   ```powershell
   # Import Common module
   Import-Module Common

   # Initialize operation tracking
   $context = Start-ModuleOperation -ModuleName "YourModule"

   # Implement operation logic with proper logging
   Write-ModuleLog -Message "Starting process" -ModuleName "YourModule"

   # Handle completion
   Stop-ModuleOperation -ModuleName "YourModule" -StartTime $context.StartTime -Success $true
   ```

2. **Error Handling Integration**
   ```powershell
   try {
       # Your code here
   }
   catch {
       Write-ModuleLog -Message $_.Exception.Message -Severity "Error" -ModuleName "YourModule"
       throw
   }
   ```

## Requirements
- PowerShell 5.1 or later
- Write permissions for log directory creation
- Administrator privileges for certain operations

## Notes
- Log files are automatically rotated based on retention policy
- Operation tracking includes performance metrics
- All functions implement proper error handling
- Console output mirrors log entries with appropriate styling
