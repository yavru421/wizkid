# WizKid PowerShell Edition - Setup Utilities

function Test-WizKidDependencies {
    [CmdletBinding()]
    param()
    
    $dependencies = @{
        "PowerShell" = @{
            Test = { $PSVersionTable.PSVersion.Major -ge 5 }
            Message = "PowerShell 5.0 or higher"
        }
        "PresentationFramework" = @{
            Test = { 
                try { 
                    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
                    return $true 
                } catch { 
                    return $false 
                }
            }
            Message = ".NET WPF Framework"
        }
        "System.Windows.Forms" = @{
            Test = { 
                try { 
                    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                    return $true 
                } catch { 
                    return $false 
                }
            }
            Message = "Windows Forms"
        }
        "System.Drawing" = @{
            Test = { 
                try { 
                    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
                    return $true 
                } catch { 
                    return $false 
                }
            }
            Message = "System Drawing"
        }
    }
    
    $results = @{}
    foreach ($dep in $dependencies.GetEnumerator()) {
        $results[$dep.Key] = @{
            Name = $dep.Value.Message
            Success = & $dep.Value.Test
        }
    }
    
    return $results
}

function Initialize-WizKidEnvironment {
    [CmdletBinding()]
    param()
    
    $results = @{
        Success = $true
        Messages = @()
        Errors = @()
    }
    
    try {
        # Test dependencies
        $depResults = Test-WizKidDependencies
        foreach ($dep in $depResults.GetEnumerator()) {
            if ($dep.Value.Success) {
                $results.Messages += "✅ $($dep.Value.Name): OK"
            } else {
                $results.Success = $false
                $results.Errors += "❌ $($dep.Value.Name): FAILED"
            }
        }
        
        # Create required directories
        $directories = @("assets", "projects", "context")
        foreach ($dir in $directories) {
            $dirPath = Join-Path $PSScriptRoot "..\$dir"
            if (-not (Test-Path $dirPath)) {
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
                $results.Messages += "📁 Created directory: $dir"
            }
        }
        
        # Initialize log file
        $logPath = Join-Path $PSScriptRoot "..\application.log"
        if (-not (Test-Path $logPath)) {
            "WizKid Application Log - Initialized $(Get-Date)" | Out-File -FilePath $logPath
            $results.Messages += "📄 Initialized log file"
        }
        
        $results.Messages += "🚀 WizKid environment ready!"
        
    } catch {
        $results.Success = $false
        $results.Errors += "Setup error: $($_.Exception.Message)"
    }
    
    return $results
}

function Get-WizKidVersion {
    return @{
        Version = "2.0.0"
        Build = "2025.06.19"
        Author = "John D Dondlinger"
        Description = "AI-Powered Assistant with Screenshot Analysis and Research Tools"
    }
}

function Test-ApiConnection {
    [CmdletBinding()]
    param()
    
    try {
        $apiKey = Get-GroqApiKey
        if (-not $apiKey) {
            return @{
                Success = $false
                Message = "No API key configured"
            }
        }
        
        $testResult = Test-GroqApiKey -ApiKey $apiKey
        return @{
            Success = $testResult
            Message = if ($testResult) { "API connection successful" } else { "API connection failed" }
        }
    } catch {
        return @{
            Success = $false
            Message = "API test error: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Test-WizKidDependencies, Initialize-WizKidEnvironment, Get-WizKidVersion, Test-ApiConnection