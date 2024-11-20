@{
    ModuleVersion = '1.0.0'
    RootModule = 'PerformanceOptimization.psm1'
    Author = 'System Administrator'
    Description = 'Module for optimizing system performance through various tuning and configuration adjustments'
    FunctionsToExport = @(
        'Invoke-PerformanceOptimization',
        'Get-SystemPerformanceMetrics'
    )
    PrivateData = @{
        PSData = @{}
    }
}
