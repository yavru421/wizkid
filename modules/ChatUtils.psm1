# WizKid PowerShell Edition - Chat Utilities

function Start-GroqChat {
    [CmdletBinding()]
    param([switch]$Persistent)
    
    $model = Read-Host "Model (compound-beta/meta-llama/llama-3-maverick-8b-8192) [default: compound-beta]"
    if (-not $model) { $model = "compound-beta" }
    Write-Host "Type 'exit' to quit chat and return to menu."
    $history = @(@{ role = 'system'; content = 'You are WizKid by John D Dondlinger, a helpful assistant.' })
    
    while ($true) {
        $msg = Read-Host "You"
        if ($msg -eq 'exit') { break }
        $history += @{ role = 'user'; content = @(@{ type = 'text'; text = $msg }) }
        $body = @{ model = $model; messages = $history } | ConvertTo-Json -Depth 10
        $headers = @{ 'Authorization' = "Bearer $env:GROQ_API_KEY"; 'Content-Type' = 'application/json' }
        try {
            $resp = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/chat/completions' -Method Post -Headers $headers -Body $body
            $result = $resp.choices[0].message.content
            Write-Host "Groq: $result`n"
            $history += @{ role = 'assistant'; content = @(@{ type = 'text'; text = $result }) }
        } catch { 
            Write-Host "Error: $_" -ForegroundColor Red 
        }
    }
}

function Send-GroqMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Model = "compound-beta",
        [array]$History = @(),
        [switch]$IncludeImage,
        [string]$ImagePath,
        [string]$ApiKey
    )
    
    if (-not $ApiKey) {
        throw "No API key provided to Send-GroqMessage."
    }
    
    $headers = @{ 
        'Authorization' = "Bearer $ApiKey"
        'Content-Type' = 'application/json' 
    }
    
    # Build message content
    $content = @(@{ type = 'text'; text = $Message })
    if ($IncludeImage -and $ImagePath -and (Test-Path $ImagePath)) {
        $base64Image = Get-ImageBase64 -Path $ImagePath
        if ($base64Image) {
            $content += @{ 
                type = 'image_url'
                image_url = @{ url = "data:image/jpeg;base64,$base64Image" }
            }
        }
    }
    
    # Add to history
    $messages = $History + @{ role = 'user'; content = $content }
    
    $body = @{ 
        model = $Model
        messages = $messages 
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri 'https://api.groq.com/openai/v1/chat/completions' -Method Post -Headers $headers -Body $body
        return @{
            Success = $true
            Content = $response.choices[0].message.content
            History = $messages + @{ role = 'assistant'; content = $response.choices[0].message.content }
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            History = $messages
        }
    }
}

Export-ModuleMember -Function Start-GroqChat, Send-GroqMessage