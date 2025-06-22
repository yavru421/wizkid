# WizKid PowerShell Edition - API Utilities

function Invoke-GroqApi {
    param (
        $Uri, $Method, $Headers, $Body
    )
    $maxRetries = 3
    $retryCount = 0
    $success = $false
    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            $resp = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body
            $success = $true
            return $resp
        } catch {
            $retryCount++
            if ($retryCount -eq $maxRetries) {
                Write-Host "Failed after $maxRetries retries: $_" -ForegroundColor Red
                throw
            } else {
                Write-Host "Error on attempt $retryCount/$maxRetries. Retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Upload-GroqFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$Purpose = "assistants"
    )
    $ApiKey = $env:GROQ_API_KEY
    if ([string]::IsNullOrEmpty($ApiKey)) {
        Write-Error "GROQ_API_KEY environment variable not set."
        return $null
    }
    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found at $FilePath"
        return $null
    }
    $Uri = "https://api.groq.com/openai/v1/files"
    $Headers = @{
        "Authorization" = "Bearer $ApiKey"
    }
    $Form = @{
        "file"    = Get-Item -Path $FilePath
        "purpose" = $Purpose
    }
    try {
        Write-Host "Uploading $FilePath to Groq with purpose '$Purpose'..." -ForegroundColor Yellow
        $Response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Form $Form
        Write-Host "File uploaded successfully. File ID: $($Response.id)" -ForegroundColor Green
        return $Response
    } catch {
        Write-Error "Error uploading file to Groq: $($_.Exception.Message)"
        return $null
    }
}

function Download-GroqFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileId,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    $ApiKey = $env:GROQ_API_KEY
    if ([string]::IsNullOrEmpty($ApiKey)) {
        Write-Error "GROQ_API_KEY environment variable not set."
        return $null
    }
    $Uri = "https://api.groq.com/openai/v1/files/$FileId/content"
    $Headers = @{
        "Authorization" = "Bearer $ApiKey"
    }
    try {
        Write-Host "Downloading file ID $FileId from Groq to $OutputPath..." -ForegroundColor Yellow
        Invoke-RestMethod -Uri $Uri -Method Get -Headers $Headers -OutFile $OutputPath
        Write-Host "File downloaded successfully to $OutputPath." -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Error downloading file from Groq: $($_.Exception.Message)"
        return $false
    }
}

function Send-GroqMessage {
    param(
        [string]$Message,
        [string]$ApiKey,
        [string]$Model = 'llama3-8b-8192'
    )
    
    if (-not $ApiKey) {
        return @{ Success = $false; Error = "API Key is missing." }
    }

    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type"  = "application/json"
    }
    
    $body = @{
        messages = @(
            @{ role = "user"; content = $Message }
        )
        model      = $Model
        temperature = 0.3
        max_tokens = 1024
        top_p = 1
        stream = $false
        stop = $null
    } | ConvertTo-Json

    try {
        $response = Invoke-GroqApi -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $headers -Body $body
        $content = $response.choices[0].message.content
        return @{ Success = $true; Content = $content }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

Export-ModuleMember -Function Invoke-GroqApi, Upload-GroqFile, Download-GroqFile, Send-GroqMessage
