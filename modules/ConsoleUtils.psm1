# WizKid PowerShell Edition - Console Utilities

function Show-WizKidLogo {
    [CmdletBinding()]
    param()
    
    $logoPath = Join-Path $PSScriptRoot '..\wizkidlogo.txt'
    if (-not (Test-Path $logoPath)) { 
        Write-Host "WizKid" -ForegroundColor Magenta
        return 
    }
    
    $lines = Get-Content $logoPath
    # Use only the second ASCII art block (after the empty line)
    $emptyLineIndex = ($lines | Select-String -Pattern '^$').LineNumber
    if ($emptyLineIndex -and $emptyLineIndex.Count -gt 0) {
        $start = $emptyLineIndex[0]
        $logo = $lines[$start..($lines.Count - 1)]
        foreach ($line in $logo) {
            Write-Host $line -ForegroundColor Magenta
            Start-Sleep -Milliseconds 40
        }
    }
    Write-Host ""
    Write-Host "by John D Dondlinger" -ForegroundColor Yellow
}

function Show-ConsoleMenu {
    [CmdletBinding()]
    param()
    
    Clear-Host
    Show-WizKidLogo
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                   MAIN MENU                    ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "1) Upload File to Groq" -ForegroundColor Cyan
    Write-Host "2) Download File from Groq" -ForegroundColor Cyan
    Write-Host "3) Chat with Groq" -ForegroundColor Cyan
    Write-Host "4) Set My Preferences" -ForegroundColor Cyan  
    Write-Host "5) Let WizKid Decide" -ForegroundColor Cyan
    Write-Host "6) Give Feedback to WizKid" -ForegroundColor Cyan
    Write-Host "7) Switch to GUI Mode" -ForegroundColor Green
    Write-Host "0) Exit" -ForegroundColor Red
    Write-Host ""
}

function Write-WizKidStatus {
    [CmdletBinding()]
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    $prefix = switch ($Level) {
        "Success" { "✅" }
        "Warning" { "⚠️" }
        "Error" { "❌" }
        "Info" { "ℹ️" }
        default { "•" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Get-UserChoice {
    [CmdletBinding()]
    param(
        [string]$Prompt = "Choose an option",
        [string[]]$ValidChoices = @(),
        [string]$Default = ""
    )
    
    do {
        if ($ValidChoices.Count -gt 0) {
            $choiceText = "($($ValidChoices -join '/'))"
            if ($Default) {
                $choiceText += " [default: $Default]"
            }
            $fullPrompt = "$Prompt $choiceText"
        } else {
            $fullPrompt = $Prompt
        }
        
        $choice = Read-Host $fullPrompt
        
        if ([string]::IsNullOrWhiteSpace($choice) -and $Default) {
            return $Default
        }
        
        if ($ValidChoices.Count -eq 0 -or $choice -in $ValidChoices) {
            return $choice
        }
        
        Write-WizKidStatus "Invalid choice. Please try again." "Warning"
    } while ($true)
}

function Start-ConsoleMode {
    [CmdletBinding()]
    param()
    
    # Initialize API key using the ApiKeyManager module
    $GroqApiKey = Initialize-ApiKey
    
    while ($true) {
        Show-ConsoleMenu
        $choice = Get-UserChoice -Prompt "Choose an option (0-7)" -ValidChoices @("0","1","2","3","4","5","6","7")
        
        switch ($choice) {
            "1" { Write-WizKidStatus "Upload File to Groq selected. This feature is coming soon!" "Warning" }
            "2" { Write-WizKidStatus "Download File from Groq selected. This feature is coming soon!" "Warning" }
            "3" { Start-GroqChat }
            "4" { Write-WizKidStatus "Set My Preferences selected. This feature is coming soon!" "Warning" }
            "5" { Write-WizKidStatus "Let WizKid Decide selected. This feature is coming soon!" "Warning" }
            "6" { 
                Write-Host "Please type your feedback below. Type END on a new line when finished:" -ForegroundColor Yellow
                $feedback = ""
                while ($true) {
                    $line = Read-Host
                    if ($line -eq "END") { break }
                    $feedback += "$line`n"
                }
                if ($feedback) {
                    $logPath = Join-Path $PSScriptRoot "..\WizKid_Feedback.log"
                    Add-Content -Path $logPath -Value "[$([datetime]::Now)] $feedback"
                    Write-WizKidStatus "Thank you for your feedback!" "Success"
                } else {
                    Write-WizKidStatus "No feedback provided." "Warning"
                }
            }
            "7" { 
                Write-WizKidStatus "Switching to GUI mode..." "Info"
                return "GUI"
            }
            "0" { 
                Write-WizKidStatus "Goodbye!" "Info"
                return "EXIT"
            }
        }
        
        if ($choice -ne "0") {
            Read-Host "Press Enter to continue..."
        }
    }
}

Export-ModuleMember -Function Show-WizKidLogo, Show-ConsoleMenu, Write-WizKidStatus, Get-UserChoice, Start-ConsoleMode