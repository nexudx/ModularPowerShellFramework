@{
    ModuleVersion = '1.0.0'
    RootModule = 'PerformanceOptimization.psm1'
    FunctionsToExport = @(
        'Invoke-PerformanceOptimization',
        'Get-SystemPerformanceMetrics'
    )
    PrivateData = @{
        PSData = @{}
    }
}
