# --- SPLASH SCREEN: Show WizKid by John D Dondlinger Logo (ASCII Art) ---
function Show-WizKidLogo {
    $logoPath = Join-Path $PSScriptRoot 'wizkidlogo.txt'
    if (-not (Test-Path $logoPath)) { return }
    $lines = Get-Content $logoPath
    # Use only the second ASCII art block (after the empty line)
    $start = ($lines | Select-Object -Index (($lines | Select-String -Pattern '^$').LineNumber[0]))
    $logo = $lines[($lines.IndexOf($start) + 1)..($lines.Count - 1)]
    foreach ($line in $logo) {
        Write-Host $line -ForegroundColor Magenta
        Start-Sleep -Milliseconds 40
    }
    Write-Host ""
    Write-Host "by John D Dondlinger" -ForegroundColor Yellow
}

Show-WizKidLogo

# --- BASE64 ENCODE IMAGE (with debug) ---
function Get-ImageBase64($Path) {
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path" -ForegroundColor Red
        return $null
    }
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
        Write-Host "Read $($bytes.Length) bytes from $Path" -ForegroundColor Green
        $b64 = [Convert]::ToBase64String($bytes)
        Write-Host "Base64 preview: $($b64.Substring(0, [Math]::Min(60, $b64.Length)))..." -ForegroundColor Cyan
        return $b64
    } catch {
        Write-Host "Error reading or encoding file: $_" -ForegroundColor Red
        return $null
    }
}

# --- CONFIGURATION (with defaults) ---
$defaultApiKey = "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"
$GroqApiKey = $null
while (-not $GroqApiKey) {
    $GroqApiKey = Read-Host -Prompt "Enter your Groq API Key (required for WizKid by John D Dondlinger to function) [default: $defaultApiKey]"
    if ([string]::IsNullOrWhiteSpace($GroqApiKey)) {
        $GroqApiKey = $defaultApiKey
        Write-Host "Using default API key. Replace with your real key for full access." -ForegroundColor Yellow
    }
}
$env:GROQ_API_KEY = $GroqApiKey

function Start-GroqChat {
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
        } catch { Write-Host "Error: $_" -ForegroundColor Red }
    }
}

# --- MAIN MENU AND APPLICATION FLOW ---
function Show-Menu {
    Clear-Host
    Show-WizKidLogo
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                   MAIN MENU                    ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "1) 📷 Upload File to Groq" -ForegroundColor Cyan
    Write-Host "2) 📋 Download File from Groq" -ForegroundColor Cyan
    Write-Host "3) 💬 Chat with Groq" -ForegroundColor Cyan
    Write-Host "4) ⚙️  Set My Preferences" -ForegroundColor Cyan
    Write-Host "5) 🔧 Let WizKid Decide" -ForegroundColor Cyan
    Write-Host "6) 💡 Give Feedback to WizKid" -ForegroundColor Cyan
    Write-Host "0) 🚪 Exit" -ForegroundColor Red
    Write-Host ""
}

# --- MAIN APPLICATION LOOP ---
function Main {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Choose an option (0-6)"
        
        switch ($choice) {
            "1" { Write-Host "Upload File to Groq selected. This feature is coming soon!" -ForegroundColor Yellow }
            "2" { Write-Host "Download File from Groq selected. This feature is coming soon!" -ForegroundColor Yellow }
            "3" { Start-GroqChat }
            "4" { Write-Host "Set My Preferences selected. This feature is coming soon!" -ForegroundColor Yellow }
            "5" { Write-Host "Let WizKid Decide selected. This feature is coming soon!" -ForegroundColor Yellow }
            "6" { 
                Write-Host "Please type your feedback below. Type END on a new line when finished:" -ForegroundColor Yellow
                $feedback = ""
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $feedback += "$line`n"
                }
                if ($feedback) {
                    $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
                    Add-Content -Path $logPath -Value "[$([datetime]::Now)] $feedback"
                    Write-Host "Thank you for your feedback!" -ForegroundColor Green
                }
                Write-Host "Press Enter to return to menu..." -ForegroundColor Cyan
                [void][System.Console]::ReadKey()
            }
            "0" { 
                Write-Host "Thank you for using WizKid by John D Dondlinger!" -ForegroundColor Magenta
                Exit
            }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# --- START THE APPLICATION ---
Main