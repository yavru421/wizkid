# WizKid PowerShell Edition - GUI Utilities

# Initializes the necessary assemblies for a WPF GUI.
function Initialize-WizKidGui {
    [CmdletBinding()]
    param()
    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        return @{ Success = $true; Message = "GUI assemblies loaded successfully" }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Message = "Failed to load GUI assemblies: $($_.Exception.Message)" }
    }
}

# Adds a formatted message to the main chat with bubble UI.
function Add-ChatMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$WizSenderLabel,
        [System.Windows.Media.Brush]$Color = [System.Windows.Media.Brushes]::Gray,
        [System.Windows.FontWeight]$FontWeight = [System.Windows.FontWeights]::Normal,
        [System.Windows.FontStyle]$FontStyle = [System.Windows.FontStyles]::Normal
    )

    if (-not $script:chatBox) { return }

    try {
        # Determine sender type for bubble styling
        $senderType = "System"
        if ($WizSenderLabel -like "*You*" -or $WizSenderLabel -like "*User*") {
            $senderType = "User"
        } elseif ($WizSenderLabel -like "*WizKid*" -or $WizSenderLabel -like "*AI*") {
            $senderType = "AI"
        }
          # Create message object for data binding
        $messageObj = New-Object PSObject -Property @{
            Text = if ($WizSenderLabel) { "$WizSenderLabel`n$Message" } else { $Message }
            Sender = $senderType
            Timestamp = Get-Date
        }
        
        # Add to the chat messages collection (set up properly in main script)
        if ($script:chatMessages) {
            $script:chatMessages.Add($messageObj)
        } else {
            Write-Host "Warning: Chat messages collection not available" -ForegroundColor Yellow
        }
        
        # Auto-scroll to bottom
        if ($script:chatScrollViewer) {
            $script:chatScrollViewer.ScrollToBottom()
        }

        # Also log to console and file
        $logType = if ($WizSenderLabel) { $WizSenderLabel.ToUpper() } else { "SYSTEM" }
        Write-Host ("{0}: {1}" -f $logType, $Message) -ForegroundColor Green
        # Assuming Write-SessionLog is available from another module
        if (Get-Command Write-SessionLog -ErrorAction SilentlyContinue) {
            Write-SessionLog -Type $logType -Content $Message
        }
    }
    catch {
        Write-Host "Error adding chat message: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Export-ModuleMember -Function Initialize-WizKidGui, Add-ChatMessage
