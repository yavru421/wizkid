# WizKid PowerShell Edition - API Key Management

# Default API key for WizKid
$script:DefaultGroqApiKey = "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"

function Get-GroqApiKey {
    [CmdletBinding()]
    param()
    
    # Check if environment variable is set
    if ($env:GROQ_API_KEY -and -not [string]::IsNullOrWhiteSpace($env:GROQ_API_KEY)) {
        return $env:GROQ_API_KEY
    }
    
    # Try to load from .env file
    $envFilePath = Join-Path -Path $PSScriptRoot -ChildPath "..\.env"
    if (Test-Path $envFilePath) {
        $envContent = Get-Content $envFilePath
        foreach ($line in $envContent) {
            if ($line -match '^GROQ_API_KEY=(.+)$') {
                $apiKey = $Matches[1].Trim()
                if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
                    $env:GROQ_API_KEY = $apiKey
                    Write-Host "Loaded API key from .env file" -ForegroundColor Green
                    return $apiKey
                }
            }
        }
    }
    
    # Use default key if no environment variable or .env file
    Write-Host "Using default Groq API key. Set GROQ_API_KEY environment variable for your own key." -ForegroundColor Yellow
    return $script:DefaultGroqApiKey
}

function Set-GroqApiKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApiKey
    )
    
    $env:GROQ_API_KEY = $ApiKey
    Write-Host "Groq API key set successfully" -ForegroundColor Green
}

function Initialize-ApiKey {
    [CmdletBinding()]
    param()
    
    $apiKey = Get-GroqApiKey
    if (-not $apiKey) {
        Write-Host "No API key found. Please set your Groq API key." -ForegroundColor Red
        $inputKey = Read-Host "Enter your Groq API Key (or press Enter to use default)"
        if ([string]::IsNullOrWhiteSpace($inputKey)) {
            $apiKey = $script:DefaultGroqApiKey
            Write-Host "Using default API key" -ForegroundColor Yellow
        } else {
            $apiKey = $inputKey
        }
        Set-GroqApiKey -ApiKey $apiKey
    }
    return $apiKey
}

function Test-GroqApiKey {
    [CmdletBinding()]
    param(
        [string]$ApiKey
    )
    
    if (-not $ApiKey) {
        $ApiKey = Get-GroqApiKey
    }
    
    try {
        $headers = @{
            'Authorization' = "Bearer $ApiKey"
            'Content-Type' = 'application/json'
        }
        
        $body = @{
            model = "compound-beta"
            messages = @(@{
                role = "user"
                content = "test"
            })
            max_tokens = 1
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/chat/completions' -Method Post -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "API key is valid" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "API key test failed: $_" -ForegroundColor Red
        return $false
    }
}

# Auto-initialize API key when module loads
$env:GROQ_API_KEY = Get-GroqApiKey

Export-ModuleMember -Function Get-GroqApiKey, Set-GroqApiKey, Initialize-ApiKey, Test-GroqApiKey