param(
    [string]$Action = ''
)

Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Action param: $Action at $(Get-Date)"

# --- ENV FILE LOADING ---
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([A-Za-z_][A-Za-z0-9_]*)=(.*)$") {
            $name, $value = $matches[1], $matches[2]
            [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

# --- MODULE IMPORTS ---
Import-Module "$PSScriptRoot\modules\GroqApiUtils.psm1"
Import-Module "$PSScriptRoot\modules\ImageUtils.psm1"
Import-Module "$PSScriptRoot\modules\UIUtils.psm1"
Import-Module "$PSScriptRoot\modules\LoggingUtils.psm1"

# --- SCREENSHOT CAPTURE ---
function Get-Screenshot {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $bmp.Save($ScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        Write-Host "Screenshot saved to $ScreenshotPath"
        return $ScreenshotPath
    } catch {
        Write-Host "Error getting screenshot: $_" -ForegroundColor Red
        return $null
    }
}

# --- CLIPBOARD IMAGE ANALYSIS ---
function Get-ClipboardImage {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $img = [Windows.Forms.Clipboard]::GetImage()
        if ($img) {
            $path = Join-Path $AssetsDir "clipboard_image.png"
            $img.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Clipboard image saved to $path"
            return $path
        } else {
            Write-Host "No image found in clipboard." -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "Clipboard access error: $_" -ForegroundColor Red
        return $null
    }
}

# --- ACTION HANDLER ---
if ($Action) {
    Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Entered action handler: $Action at $(Get-Date)"
    switch ($Action) {
        'Screenshot' {
            Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Screenshot Analysis triggered from GUI at $(Get-Date)"
            Invoke-ScreenshotAnalysis
        }
        'Chat' {
            Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Groq Chat triggered from GUI at $(Get-Date)"
            Start-GroqChat
        }
        'Clipboard' {
            Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Clipboard Image Analysis triggered from GUI at $(Get-Date)"
            Invoke-ClipboardImageAnalysis
        }
        Default {
            Add-Content -Path "$PSScriptRoot\ScreenHelp.log" -Value "[DEBUG] Unknown action: $Action at $(Get-Date)"
        }
    }
    exit
}

function Show-WizKidHeader {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        WizKid by John D Dondlinger                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Call header at the start
Show-WizKidHeader

# --- CONSTANTS ---
# Prefer environment variable for API key, fallback to hardcoded if not set
if ($env:GROQ_API_KEY) {
    $GroqApiKey = $env:GROQ_API_KEY
} else {
    $GroqApiKey = "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"
}
if (-not $GroqApiKey) {
    Write-Host "Error: Groq API Key is not set." -ForegroundColor Red
    exit
}
$AssetsDir = Join-Path $PSScriptRoot "assets"
$ScreenshotPath = Join-Path $AssetsDir "screenshot.png"
$LogPath = Join-Path $PSScriptRoot "WizKid_by_John_D_Dondlinger.log"

# --- API KEY MANAGEMENT ---
function Get-GroqApiKey {
    return $GroqApiKey
}

# --- API REQUEST WITH RETRY ---
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

# --- BASE64 ENCODE IMAGE WITH SIZE CHECK ---
function Get-ImageBase64 {
    param($Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path" -ForegroundColor Red
        return $null
    }
    $maxSizeBytes = 2MB
    $fileInfo = Get-Item $Path
    if ($fileInfo.Length -gt $maxSizeBytes) {
        Write-Host "Warning: File size $($fileInfo.Length) bytes exceeds $maxSizeBytes bytes. Large files may impact performance or exceed API limits." -ForegroundColor Yellow
        $proceed = Read-Host "Continue with encoding? (y/n)"
        if ($proceed -ne "y") {
            Write-Host "Aborted base64 encoding for large file." -ForegroundColor Red
            return $null
        }
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

# --- CONSOLIDATED GROQ VISION API CALL (for Screenshot and Clipboard) ---
function Invoke-GroqVisionAnalysis {
    param(
        [string]$ImagePath,
        [string]$Question
    )
    if (-not $ImagePath -or -not (Test-Path $ImagePath)) {
        Write-Host "Invalid image path provided to Invoke-GroqVisionAnalysis." -ForegroundColor Red
        return
    }
    if ([string]::IsNullOrWhiteSpace($Question)) {
        Write-Host "Question cannot be empty for Invoke-GroqVisionAnalysis." -ForegroundColor Red
        return
    }

    $model = Read-Host -Prompt "Model for Vision (Scout/Maverick) [default: Maverick]"
    if ([string]::IsNullOrWhiteSpace($model)) { $model = "Maverick" }
    # LLaVA model is specifically for vision tasks, Maverick and Scout are text models.
    # Using llava-v1.5-7b-tool-use as an example, replace with the correct Groq vision model if different.
    # The Groq documentation should specify which models support image input.
    # For now, let's assume a generic vision model endpoint or a specific model that supports the required multimodal input.
    # The previous code used Maverick/Scout which might not be correct for vision.
    # Let's stick to the user's choice for now but this is a key area for API docs check.
    $modelId = if ($model -eq "Scout") { "meta-llama/llama-4-scout-17b-16e-instruct" } else { "llava-v1.5-7b-tool-use" } # Example vision model
    # Reverted to Maverick as per user's previous choice, but this needs verification for vision capabilities with Groq.
    $modelId = if ($model -eq "Scout") { "meta-llama/llama-4-scout-17b-16e-instruct" } else { "meta-llama/llama-3-maverick-8b-8192" }


    $img64 = Get-ImageBase64 -Path $ImagePath
    if (-not $img64) {
        Write-Host "Failed to encode image or image is empty. Aborting vision analysis." -ForegroundColor Red
        return
    }

    # Constructing the JSON payload manually to ensure correct structure for messages array
    # This structure is critical for the Groq API when sending image data.
    $escapedQuestion = $Question -replace '"', '\"'; # Escape double quotes in the question
    $body = @"
{
  "model": "$modelId",
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "$escapedQuestion" },
        { "type": "image_url", "image_url": { "url": "data:image/png;base64,$img64" } }
      ]
    }
  ],
  "max_tokens": 2048
}
"@
    Write-Host "\n--- DEBUG: JSON payload to Groq Vision API ---" -ForegroundColor Yellow
    Write-Host $body

    $headers = @{ 
        "Authorization" = "Bearer $GroqApiKey"; 
        "Content-Type" = "application/json" 
    }
    $endpoint = "https://api.groq.com/openai/v1/chat/completions" # Standard chat completions endpoint

    Write-Host "Sending image and question to Groq Vision API..."
    try {
        # Using Invoke-GroqApi for consistency with retries
        $resp = Invoke-GroqApi -Uri $endpoint -Method Post -Headers $headers -Body $body
        if ($resp -and $resp.choices -and $resp.choices.Count -gt 0) {
            $result = $resp.choices[0].message.content
            Write-Host "\n--- ANALYSIS RESULT ---" -ForegroundColor Green
            Write-Host $result
            Write-SessionLog "VisionAnalysis" "Image analysis successful for $ImagePath"
        } else {
            Write-Host "No valid response or choices received from API." -ForegroundColor Red
            Write-Host "API Response: $($resp | ConvertTo-Json -Depth 5)"
            Write-SessionLog "VisionAnalysisError" "No valid response from API for $ImagePath. Response: $($resp | ConvertTo-Json -Depth 5)"
        }
    } catch {
        Write-Host "Error during Groq Vision API call: $_" -ForegroundColor Red
        Write-Host "Exception Details: $($_.Exception | Format-List * -Force)"
        Write-SessionLog "VisionAnalysisError" "API call failed for $ImagePath. Error: $_.Exception.Message"
    }
}

# --- SCREENSHOT ANALYSIS (Wrapper) ---
function Invoke-ScreenshotAnalysis {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ImagePath,

        [Parameter(Mandatory=$false)]
        [string]$Question = "What is in this image?",

        [Parameter(Mandatory=$false)]
        [string]$Model = "meta-llama/llama-4-scout-17b-16e-instruct" # Explicitly set to scout model for vision
    )

    Write-Host "Starting screenshot analysis for: $ImagePath" -ForegroundColor Green
    Write-Host "Question: $Question" -ForegroundColor Cyan
    Write-Host "Model: $Model" -ForegroundColor Cyan

    if (-not (Test-Path $ImagePath)) {
        Write-Error "Screenshot file not found at $ImagePath"
        return $null
    }

    $ApiKey = $env:GROQ_API_KEY
    if ([string]::IsNullOrEmpty($ApiKey)) {
        Write-Error "GROQ_API_KEY environment variable not set."
        return $null
    }

    $Base64Image = Get-ImageBase64 -Path $ImagePath
    if ([string]::IsNullOrEmpty($Base64Image)) {
        Write-Error "Failed to get base64 string for image."
        return $null
    }

    $Headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type"  = "application/json"
    }

    # Construct the payload matching the notebook's working version
    # Simplified by removing max_tokens and temperature for now
    $Payload = @{
        "messages" = @(
            @{
                "role"    = "user"
                "content" = @(
                    @{
                        "type" = "text"
                        "text" = $Question
                    },
                    @{
                        "type"      = "image_url"
                        "image_url" = @{
                            # Assuming PNG format for screenshots. Adjust to image/jpeg if needed.
                            "url" = "data:image/png;base64,$Base64Image"
                        }
                    }
                )
            }
        )
        "model"    = $Model
    }

    $JsonPayload = ConvertTo-Json -InputObject $Payload -Depth 10
    Write-Host "Attempting to send the following JSON payload to Groq API:" -ForegroundColor Yellow
    Write-Host $JsonPayload -ForegroundColor Gray # Debug: Print the JSON payload

    try {
        $Response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $Headers -Body $JsonPayload
        Write-Host "API Response Received." -ForegroundColor Green
        return $Response.choices[0].message.content
    } catch {
        Write-Error "Error calling Groq API: $($_.Exception.Message)"
        # Attempt to get more details from the response, if available
        if ($_.Exception.Response) {
            Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            $errorResponse = $_.Exception.Response.GetResponseStream()
            $streamReader = New-Object System.IO.StreamReader($errorResponse)
            $errorBody = $streamReader.ReadToEnd()
            $streamReader.Close()
            $errorResponse.Close()
            Write-Host "Response Body: $errorBody" -ForegroundColor Red
        }
        return $null
    }
}

# --- CLIPBOARD IMAGE ANALYSIS (Wrapper) ---
function Invoke-ClipboardImageAnalysis {
    $clipboardImagePath = Get-ClipboardImage
    if (-not $clipboardImagePath) {
        Write-Host "Failed to get image from clipboard or no image present." -ForegroundColor Yellow
        return
    }
    $question = Read-Host -Prompt "Enter your question about the clipboard image"
    if ([string]::IsNullOrWhiteSpace($question)) {
        Write-Host "Question cannot be empty." -ForegroundColor Red
        return
    }
    Invoke-GroqVisionAnalysis -ImagePath $clipboardImagePath -Question $question
}

# --- GROQ CHAT API CALL ---
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
            $history += @{ role = 'assistant'; content = $result } # FIX: content is a string for assistant
        } catch { Write-Host "Error: $_" -ForegroundColor Red }
    }
}

# --- SESSION LOGGING ---
function Write-SessionLog {
    param($Type, $Content)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp][$Type] $Content"
    Add-Content -Path $LogPath -Value $entry
}

# --- UTILITY: Write-BoxedText ---
function Write-BoxedText($lines, $color = "Cyan", $emoji = $null) {
    if (-not $lines -or $lines.Count -eq 0) { return }
    $maxLen = ($lines | Measure-Object -Maximum Length).Maximum
    $top = "+" + ("-" * ($maxLen + 2)) + "+"
    $bottom = "+" + ("-" * ($maxLen + 2)) + "+"
    Write-Host ""
    Write-Host $top -ForegroundColor $color
    foreach ($line in $lines) {
        $pad = " " * ($maxLen - $line.Length)
        $prefix = if ($emoji) { "$emoji " } else { "  " }
        Write-Host ("| $prefix$line$pad |") -ForegroundColor $color
    }
    Write-Host $bottom -ForegroundColor $color
    Write-Host ""
}

# --- SPLASH SCREEN: Show 0250.png as ASCII Art ---
function Show-SplashScreen {
    $imgPath = Join-Path $PSScriptRoot "0250.png"
    if (-not (Test-Path $imgPath)) { return }
    try {
        Add-Type -AssemblyName System.Drawing
        $bmp = [System.Drawing.Bitmap]::FromFile($imgPath)
        $minWidth = 5
        $minHeight = 5
        if ($bmp.Width -lt $minWidth -or $bmp.Height -lt $minHeight) {
            Write-Warning "Splash image is too small (minimum size: ${minWidth}x${minHeight}). Skipping splash screen."
            return
        }
        $width = 36  # Reduced width for half-screen
        $height = [int]($bmp.Height * ($width / $bmp.Width) * 0.7)  # Adjusted aspect ratio for better fit
        $resized = New-Object System.Drawing.Bitmap $bmp, $width, $height
        $ascii = @()
        $chars = " .:-=+*%@#"  # Use a readable character set
        for ($y = 0; $y -lt $resized.Height; $y++) {
            $line = ""
            for ($x = 0; $x -lt $resized.Width; $x++) {
                $pixel = $resized.GetPixel($x, $y)
                $gray = [int](($pixel.R + $pixel.G + $pixel.B) / 3)
                $idx = [int](($gray / 255) * ($chars.Length - 1))
                $line += $chars[$idx]
            }
            $ascii += $line
        }
        Write-Host ""
        foreach ($l in $ascii) { Write-Host $l -ForegroundColor Cyan }
        Write-Host ""
        Start-Sleep -Seconds 2
        $bmp.Dispose(); $resized.Dispose()
    } catch { Write-Host "(Splash screen error: $_)" -ForegroundColor Yellow }
}

# --- UPDATED MAIN MENU ---
function Main {
    if (-not (Test-Path $AssetsDir)) { New-Item -ItemType Directory -Path $AssetsDir | Out-Null }
    Show-SplashScreen
    while ($true) {
        Show-WizKidHeader
        $menuLines = @(
            "WizKid by John D Dondlinger",
            "Your Friendly Computer Helper 🧙‍♂️",
            "",
            "1) 🖼️  Analyze Screenshot",
            "2) 📋  Analyze Clipboard Image",
            "3) 🗨️  Chat with WizKid",
            "4) 🧠  Smart Contextual Q&A",
            "5) 🎤  Voice Input (Experimental)",
            "",
            "6) 🧑‍💻  Review Code File",
            "7) 📝  Summarize Text",
            "8) ❓  Explain Error Message",
            "",
            "9) 🖥️  Organize Desktop Files",
            "10) 📥  Organize Downloads",
            "11) 🧹  Clean Temp Files",
            "",
            "12) ⬆️  Upload File to Groq",
            "13) ⬇️  Download File from Groq",
            "",
            "14) 👤  Set My Preferences",
            "15) 🛠️  Let WizKid Decide",
            "16) 💡  Give Feedback to WizKid",
            "",
            "0) 🚪  Exit"
        )
        Write-BoxedText $menuLines "Cyan" "💡"
        $choice = Read-Host -Prompt "Choose an option (0-16):"
        switch ($choice) {
            "1" { # Analyze Screenshot
                Show-WizKidHeader
                Write-BoxedText @("Analyze Screenshot", "Capture your screen and ask a question!") "Green" "🖼️"
                $screenshotPath = Get-Screenshot
                if ($screenshotPath) {
                    $question = Read-Host "What would you like to know about this screenshot?"
                    Invoke-ScreenshotAnalysis -ImagePath $screenshotPath -Question $question
                    Write-SessionLog "ScreenshotAnalysis" "Screenshot analyzed."
                } else {
                    Write-Host "Screenshot could not be captured." -ForegroundColor Red
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "2" { # Analyze Clipboard Image
                Show-WizKidHeader
                Write-BoxedText @("Clipboard Image Analysis", "Analyze an image from your clipboard!") "Blue" "📋"
                Invoke-ClipboardImageAnalysis
                Write-SessionLog "ClipboardAnalysis" "Clipboard image analyzed."
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "3" { # Chat with WizKid
                Show-WizKidHeader
                Write-BoxedText @("Chat with WizKid", "Ask anything!") "Yellow" "🗨️"
                Start-GroqChat
                Write-SessionLog "GroqChat" "Chat session started."
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "4" { # Smart Contextual Q&A
                Write-BoxedText @("Smart Contextual Q&A", "Describe your complex question or scenario. Type END to finish.") "Cyan" "🧠"
                $input = @()
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $input += $line
                }
                $input = $input -join "`n"
                if (-not $input) {
                    Write-Host "No input provided." -ForegroundColor Red
                } else {
                    $prefs = Get-UserPreferences
                    $prompt = "[User: $($prefs.name)] [Style: $($prefs.style)] Please answer thoughtfully: $input"
                    $response = Invoke-GroqChat -Prompt $prompt
                    Write-Host "`n--- WizKid's Answer ---`n$response" -ForegroundColor Green
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "5" { # Voice Input
                Write-BoxedText @("Voice Input (Experimental)", "Speak your question after the beep. Requires Windows Speech Recognition.") "Cyan" "🎤"
                try {
                    Add-Type -AssemblyName System.Speech
                    $recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
                    $recognizer.SetInputToDefaultAudioDevice()
                    $grammar = New-Object System.Speech.Recognition.DictationGrammar
                    $recognizer.LoadGrammar($grammar)
                    [System.Console]::Beep(800, 300)
                    Write-Host "Listening... (speak now)"
                    $result = $recognizer.Recognize()
                    if ($result) {
                        Write-Host "You said: $($result.Text)" -ForegroundColor Yellow
                        $response = Invoke-GroqChat -Prompt $result.Text
                        Write-Host "`n--- WizKid's Answer ---`n$response" -ForegroundColor Green
                    } else {
                        Write-Host "No speech recognized." -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Voice input not available on this system." -ForegroundColor Red
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "6" { # Review Code File
                Show-WizKidHeader
                Write-BoxedText @("Review Code File", "Select a code file for review and suggestions.") "Yellow" "🧑‍💻"
                Add-Type -AssemblyName System.Windows.Forms
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Title = "Select a code file for review"
                $dialog.Filter = "Code files (*.ps1;*.py;*.js;*.ts;*.sh;*.bat;*.ahk;*.vbs;*.cs;*.cpp;*.c;*.java)|*.ps1;*.py;*.js;*.ts;*.sh;*.bat;*.ahk;*.vbs;*.cs;*.cpp;*.c;*.java|All files (*.*)|*.*"
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $filePath = $dialog.FileName
                    $code = Get-Content $filePath -Raw
                    $response = Invoke-GroqChat -Prompt "Please review the following code and suggest improvements, bugs, or best practices:`n$code"
                    Write-Host "`n--- Code Review Suggestions ---`n$response" -ForegroundColor Green
                } else {
                    Write-Host "No file selected. Returning to menu." -ForegroundColor Yellow
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "7" { # Summarize Text
                Show-WizKidHeader
                Write-BoxedText @("Summarize Text", "Paste your text for summarization. Type END on a new line to finish.") "Yellow" "📝"
                $text = @()
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $text += $line
                }
                $text = $text -join "`n"
                if (-not $text) {
                    Write-Host "No text provided for summarization." -ForegroundColor Red
                } else {
                    $response = Invoke-GroqChat -Prompt "Please summarize the following text in simple terms:`n$text"
                    Write-Host "`n--- Summary ---`n$response" -ForegroundColor Green
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "8" { # Explain Error Message
                Show-WizKidHeader
                Write-BoxedText @("Explain Error Message", "Paste your error message for a plain-English explanation. Type END on a new line to finish.") "Yellow" "❓"
                $errtext = @()
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $errtext += $line
                }
                $errtext = $errtext -join "`n"
                if (-not $errtext) {
                    Write-Host "No error message provided." -ForegroundColor Red
                } else {
                    $response = Invoke-GroqChat -Prompt "Explain this error message in plain English and suggest how to fix it:`n$errtext"
                    Write-Host "`n--- Explanation ---`n$response" -ForegroundColor Green
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "9" { Show-WizKidHeader; Invoke-OrganizeDesktop; Write-SessionLog "OrganizeDesktop" "Desktop organized."; Write-Host "Press Enter to return to menu..."; [void][System.Console]::ReadLine() }
            "10" { Show-WizKidHeader; Invoke-OrganizeDownloads; Write-SessionLog "OrganizeDownloads" "Downloads organized."; Write-Host "Press Enter to return to menu..."; [void][System.Console]::ReadLine() }
            "11" { Show-WizKidHeader; Invoke-CleanTempFiles; Write-SessionLog "CleanTempFiles" "Temp files cleaned."; Write-Host "Press Enter to return to menu..."; [void][System.Console]::ReadLine() }
            "12" { # Upload File to Groq
                Show-WizKidHeader
                Write-BoxedText @("Upload File to Groq", "Send a file to Groq for use with the API.") "Magenta" "⬆️"
                Add-Type -AssemblyName System.Windows.Forms
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Title = "Select a file to upload to Groq"
                $dialog.Filter = "All files (*.*)|*.*"
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $filePath = $dialog.FileName
                    $purpose = Read-Host "Enter the purpose for this file (default: assistants)"
                    if ([string]::IsNullOrWhiteSpace($purpose)) { $purpose = "assistants" }
                    $result = Upload-GroqFile -FilePath $filePath -Purpose $purpose
                    if ($result) {
                        Write-Host "File uploaded! Groq File ID: $($result.id)" -ForegroundColor Green
                    } else {
                        Write-Host "File upload failed." -ForegroundColor Red
                    }
                } else {
                    Write-Host "No file selected. Returning to menu." -ForegroundColor Yellow
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "13" { # Download File from Groq
                Show-WizKidHeader
                Write-BoxedText @("Download File from Groq", "Retrieve a file from Groq using its File ID.") "Magenta" "⬇️"
                $fileId = Read-Host "Enter the Groq File ID to download"
                $outputPath = Read-Host "Enter the full path where you want to save the file"
                $success = Download-GroqFile -FileId $fileId -OutputPath $outputPath
                if ($success) {
                    Write-Host "File downloaded to $outputPath!" -ForegroundColor Green
                } else {
                    Write-Host "File download failed." -ForegroundColor Red
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "14" { # Set My Preferences
                Write-BoxedText @("Set My Preferences", "Personalize your WizKid experience.") "Cyan" "👤"
                $prefs = Get-UserPreferences
                $name = Read-Host "Enter your name [$($prefs.name)]"
                $style = Read-Host "Preferred style (friendly/formal) [$($prefs.style)]"
                if ($name) { $prefs.name = $name }
                if ($style) { $prefs.style = $style }
                Set-UserPreferences $prefs
                Write-Host "Preferences saved!" -ForegroundColor Green
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "15" { # Let WizKid Decide
                Write-BoxedText @("Let WizKid Decide", "Describe your problem and let WizKid suggest the best tool.") "Cyan" "🛠️"
                $desc = @()
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $desc += $line
                }
                $desc = $desc -join "`n"
                if (-not $desc) {
                    Write-Host "No description provided." -ForegroundColor Red
                } else {
                    $response = Invoke-GroqChat -Prompt "Given this user problem, suggest the best menu option or tool from the WizKid app and explain why: $desc"
                    Write-Host "`n--- WizKid Suggests ---`n$response" -ForegroundColor Green
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "16" { # Give Feedback
                Write-BoxedText @("Give Feedback to WizKid", "Type your feedback or suggestions. Type END to finish.") "Cyan" "💡"
                $fb = @()
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $fb += $line
                }
                $fb = $fb -join "`n"
                if ($fb) {
                    $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
                    Add-Content -Path $logPath -Value ("[" + (Get-Date) + "] " + $fb)
                    Write-Host "Thank you for your feedback!" -ForegroundColor Green
                } else {
                    Write-Host "No feedback entered." -ForegroundColor Yellow
                }
                Write-Host "Press Enter to return to menu..."
                [void][System.Console]::ReadLine()
            }
            "0" {
                Show-WizKidHeader
                Write-BoxedText @("Goodbye!", "Thanks for using WizKid!") "Magenta" "👋"
                Write-SessionLog "Exit" "App exited."
                break
            }
            Default {
                Write-Host "Invalid option. Please choose 0-16." -ForegroundColor Red
                Start-Sleep -Seconds 1.5
            }
        }
    }
}

# --- ENTRY POINT ---
Main
exit

# SIG # Begin signature block
# MIIFjwYJKoZIhvcNAQcCoIIFgDCCBXwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDOnhjeF/FlK34C
# yS/0NrnSJ5ZCl5//i5ZeCwLAdU4LpKCCAwYwggMCMIIB6qADAgECAhAX6FuFVZcO
# lU6Cer1izYuDMA0GCSqGSIb3DQEBCwUAMBkxFzAVBgNVBAMMDlNjcmVlbkhlbHBV
# c2VyMB4XDTI1MDYxNTA1MDI1N1oXDTI2MDYxNTA1MjI1N1owGTEXMBUGA1UEAwwO
# U2NyZWVuSGVscFVzZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
# /T9h1EleDJ3kDFwYgbQhiWzZZ/QgYAStWzINBLigoLxp6EuQsjf1wWOMDNXuHA14
# GNE4lng4y5a0LLu6sIprJxQcIXjxma/B9YEUfd/cbnKpJ4beN9RjPgIKclaHoudA
# tIEPB5xGrYiBHFF5vbA4jRMU7e6/ZUKSn4GBe6fUSPOIATYCvN85tX6pxUUXIjau
# lL0tcGzV84v3QFl3xRGxmekUhVsZwXG5DdUd+/fww2YhCkFrFVolB7LAb3de6fTu
# yESKQWbE/uoKzKL39Nkv1TvY+mmUjTGgAklrPs83CJC0u7MN8mhM4Q9JdgTlU1DV
# MgzUNlP49XE8SqQXQTEFAgMBAAGjRjBEMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUXPjtiu4a8gEwSO52EswCpfvvGv8wDQYJ
# KoZIhvcNAQELBQADggEBALEzXb0xTMxJP+eEg7JQNLIYVc+H2/q1BZgzIBwdmpse
# 2zUZWZK/LkfAazgoUFUypXTEh+YxJoTGIMar+8F9aTmqXWnTOWUx+cF2Mja9oVsU
# HdS+OTNtxTxYDaJGxovDykIKcyjhCYbCUQ0OQMhWnQBwo0i/KY2vuO7JADF8hdga
# QUixwmw7iLRM01M4cKxf3TMJSoRb2QSKBU8Whq+c1sPX9bWCGc5oOk/d8mcQ4sBx
# DbBO9TIQl6caIj0A4OO4RYEbgPPynjFZMkEH3mSlQcAFdcLUjQfV7HDs4SVegsr7
# maHlM4ntpwAdzZH9tQAk8QcT5CWrMfFfJM6seWL+nxoxggHfMIIB2wIBATAtMBkx
# FzAVBgNVBAMMDlNjcmVlbkhlbHBVc2VyAhAX6FuFVZcOlU6Cer1izYuDMA0GCWCG
# SAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# LwYJKoZIhvcNAQkEMSIEIOhxZs4SBCqBdEDO+GS64JKIHDgfQUgcKCp5ONFRcoEQ
# MA0GCSqGSIb3DQEBAQUABIIBABnHKdOquDbXnrxV/+0/3RySXvBdFJmg4v62Qm2Q
# ZVuzDecIHZbQDJlbMGvQZbtuEjcNmjGoavIMGqDejrzBYbn9aBfwkZoqsXLDnych
# U4iB43fgVowNavnIoDYXK4gySvXXOS4ne6am8vH9ajP7xGZoKSvzIXYBFOK0wZnx
# L5p7OiWDV5m0Z29tTQvJ99X20M6MGawLPYS1AoBtejcuy2wkRpt3J1+69kEOQI4H
# rPcxrsSNn9rFQv9hV8iU7B+YieCdnV2LxhoZGO/GdHd0bczTmvq74WMzAAMjHTW9
# gzQrzV4pwxxrbE3e26OgZw2xHuxqV2ACRhurAA3dpeojcLs=
# SIG # End signature block
