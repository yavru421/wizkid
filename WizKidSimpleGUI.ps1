# WizKid Simple GUI - Clean, Minimal, Robust Version

# Ensure $PSScriptRoot is set correctly when running as an EXE
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[xml]$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WizKid by John D Dondlinger" Height="600" Width="900"
    Background="#F5F5F5">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Background="#673AB7" Orientation="Horizontal">
            <TextBlock Text="WizKid" Margin="10" FontSize="22" FontWeight="Bold" Foreground="White"/>
            <Button x:Name="ScreenshotBtn" Content="📷 Screenshot" Margin="5" Padding="10,5" Background="#512DA8" Foreground="White" BorderThickness="0" ToolTip="Take a screenshot and analyze it."/>
            <Button x:Name="ClipboardBtn" Content="📋 Clipboard" Margin="5" Padding="10,5" Background="#512DA8" Foreground="White" BorderThickness="0" ToolTip="Paste an image from your clipboard for analysis."/>
            <Button x:Name="ClearChatBtn" Content="🧹 Clear Chat" Margin="5" Padding="10,5" Background="#512DA8" Foreground="White" BorderThickness="0" ToolTip="Clear the chat history."/>
            <Button x:Name="FeedbackBtn" Content="💡 Feedback" Margin="5" Padding="10,5" Background="#512DA8" Foreground="White" BorderThickness="0" ToolTip="Send feedback to help improve WizKid."/>
        </StackPanel>
        <ScrollViewer Grid.Row="1" Margin="10" Name="ChatScroller">
            <RichTextBox Name="ChatBox" IsReadOnly="True" Background="White" BorderThickness="1" BorderBrush="#DDDDDD">
                <FlowDocument>
                    <Paragraph>
                        <Bold>WizKid:</Bold> Hello! I can answer questions or analyze images. Type your question or use the buttons above!
                    </Paragraph>
                </FlowDocument>
            </RichTextBox>
        </ScrollViewer>
        <DockPanel Grid.Row="2" Margin="10">
            <Button DockPanel.Dock="Right" Name="SendBtn" Content="Send" Width="80" Height="40" Background="#673AB7" Foreground="White" BorderThickness="0" ToolTip="Send your message to WizKid."/>
            <TextBox Name="InputBox" Height="40" TextWrapping="Wrap" AcceptsReturn="True" VerticalContentAlignment="Center" Padding="5"/>
        </DockPanel>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get elements
$chatBox = $window.FindName("ChatBox")
$inputBox = $window.FindName("InputBox")
$sendBtn = $window.FindName("SendBtn")
$screenshotBtn = $window.FindName("ScreenshotBtn")
$clipboardBtn = $window.FindName("ClipboardBtn")
$clearChatBtn = $window.FindName("ClearChatBtn")
$feedbackBtn = $window.FindName("FeedbackBtn")
$chatScroller = $window.FindName("ChatScroller")

# State
$script:lastImagePath = $null
$script:isProcessingImage = $false

# API key prompt (if missing)
function Get-ApiKey {
    $envPath = Join-Path $PSScriptRoot ".env"
    $apiKey = $null
    if (Test-Path $envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match "^GROQ_API_KEY=(.*)$") {
                $apiKey = $matches[1]
            }
        }
    }
    if (-not $apiKey) {
        $apiKey = [System.Windows.Forms.Interaction]::InputBox("Enter your GROQ API Key:", "API Key Required", "")
        if ($apiKey) {
            Set-Content -Path $envPath -Value "GROQ_API_KEY=$apiKey"
        } else {
            Add-SystemMessageToChat("⚠️ API key is required to use WizKid.")
            return $null
        }
    }
    return $apiKey
}

# Chat helpers
function Add-UserMessageToChat($text) {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $boldRun = New-Object System.Windows.Documents.Bold
    $boldRun.Inlines.Add((New-Object System.Windows.Documents.Run("You: ")))
    $paragraph.Inlines.Add($boldRun)
    $textRun = New-Object System.Windows.Documents.Run($text)
    $paragraph.Inlines.Add($textRun)
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScroller.ScrollToEnd()
}
function Add-WizKidMessageToChat($text) {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $boldRun = New-Object System.Windows.Documents.Bold
    $boldRun.Inlines.Add((New-Object System.Windows.Documents.Run("WizKid: ")))
    $paragraph.Inlines.Add($boldRun)
    $textRun = New-Object System.Windows.Documents.Run($text)
    $paragraph.Inlines.Add($textRun)
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScroller.ScrollToEnd()
}
function Add-SystemMessageToChat($text) {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $paragraph.TextAlignment = [System.Windows.TextAlignment]::Center
    $italicRun = New-Object System.Windows.Documents.Italic
    $run = New-Object System.Windows.Documents.Run($text)
    $run.Foreground = [System.Windows.Media.Brushes]::Gray
    $italicRun.Inlines.Add($run)
    $paragraph.Inlines.Add($italicRun)
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScroller.ScrollToEnd()
}
function Add-ImageToChat($imagePath) {
    try {
        $paragraph = New-Object System.Windows.Documents.Paragraph
        $paragraph.TextAlignment = [System.Windows.TextAlignment]::Center
        $image = New-Object System.Windows.Controls.Image
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = New-Object System.Uri($imagePath, [System.UriKind]::Absolute)
        $bitmap.DecodePixelWidth = 450
        $bitmap.EndInit()
        $image.Source = $bitmap
        $image.Width = 450
        $container = New-Object System.Windows.Documents.InlineUIContainer($image)
        $paragraph.Inlines.Add($container)
        $chatBox.Document.Blocks.Add($paragraph)
        $chatScroller.ScrollToEnd()
        return $true
    } catch {
        Add-SystemMessageToChat("⚠️ Error displaying image: $($_.Exception.Message)")
        return $false
    }
}

# Main message processor (auto model selection)
function Process-UserMessage {
    param($userMessage)
    if (-not $userMessage) { return }
    try {
        $apiKey = Get-ApiKey
        if ($script:isProcessingImage -and $script:lastImagePath -and (Test-Path $script:lastImagePath)) {
            $model = "meta-llama/llama-4-scout-17b-16e-instruct"
        } else {
            $model = "compound-beta"
        }
        if (-not $apiKey) {
            Add-SystemMessageToChat("⚠️ API key not found or not set properly.")
            return
        }
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }
        if ($script:isProcessingImage -and $script:lastImagePath -and (Test-Path $script:lastImagePath)) {
            Add-SystemMessageToChat("Analyzing image...")
            $bytes = [IO.File]::ReadAllBytes($script:lastImagePath)
            $base64Image = [Convert]::ToBase64String($bytes)
            $payload = @{
                model = $model
                messages = @(
                    @{
                        role = "user"
                        content = @(
                            @{ type = "text"; text = $userMessage },
                            @{ type = "image_url"; image_url = @{ url = "data:image/png;base64,$base64Image" } }
                        )
                    }
                )
                max_tokens = 2048
            }
            $script:isProcessingImage = $false
        } else {
            Add-SystemMessageToChat("Thinking...")
            $payload = @{
                model = $model
                messages = @(
                    @{ role = "system"; content = "You are WizKid by John D Dondlinger, a helpful AI assistant." },
                    @{ role = "user"; content = $userMessage }
                )
            }
        }
        $json = ConvertTo-Json -InputObject $payload -Depth 10
        $response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $headers -Body $json
        $aiResponse = $response.choices[0].message.content
        Add-WizKidMessageToChat($aiResponse)
    } catch {
        Add-SystemMessageToChat("⚠️ Oops! Something went wrong. Please check your internet connection and API key, or try again later.")
    }
}

# Screenshot button
$screenshotBtn.Add_Click({
    try {
        Add-SystemMessageToChat("Taking a screenshot...")
        $currentState = $window.WindowState
        $window.WindowState = [System.Windows.WindowState]::Minimized
        Start-Sleep -Milliseconds 500
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $window.WindowState = $currentState
        $assetsDir = Join-Path $PSScriptRoot "assets"
        if (-not (Test-Path $assetsDir)) {
            New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $screenshotPath = Join-Path $assetsDir "screenshot_$timestamp.png"
        $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose(); $bitmap.Dispose()
        $script:lastImagePath = $screenshotPath
        Add-SystemMessageToChat("Screenshot captured!")
        Add-ImageToChat($screenshotPath)
        $script:isProcessingImage = $true
        Add-SystemMessageToChat("What would you like to know about this screenshot?")
    } catch {
        Add-SystemMessageToChat("⚠️ Error capturing screenshot: $($_.Exception.Message)")
    }
})

# Clipboard button
$clipboardBtn.Add_Click({
    try {
        Add-SystemMessageToChat("Checking clipboard for image...")
        $img = [Windows.Forms.Clipboard]::GetImage()
        if ($img) {
            $assetsDir = Join-Path $PSScriptRoot "assets"
            if (-not (Test-Path $assetsDir)) {
                New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
            }
            $clipboardPath = Join-Path $assetsDir "clipboard_image.png"
            $img.Save($clipboardPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $script:lastImagePath = $clipboardPath
            Add-SystemMessageToChat("📋 Clipboard image saved!")
            Add-ImageToChat($clipboardPath)
            $script:isProcessingImage = $true
            Add-SystemMessageToChat("💬 What would you like to know about this image?")
        } else {
            Add-SystemMessageToChat("⚠️ No image found in clipboard")
        }
    } catch {
        Add-SystemMessageToChat("⚠️ Error processing clipboard: $($_.Exception.Message)")
    }
})

# Clear chat button
$clearChatBtn.Add_Click({
    $chatBox.Document.Blocks.Clear()
    Add-SystemMessageToChat("Chat cleared.")
})

# Feedback button
$feedbackBtn.Add_Click({
    $feedback = [System.Windows.Forms.Interaction]::InputBox("Type your feedback below:", "Send Feedback", "")
    if ($feedback) {
        $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
        Add-Content -Path $logPath -Value "[$([datetime]::Now)] $feedback"
        Add-SystemMessageToChat("Thank you for your feedback!")
    }
})

# Send button
$sendBtn.Add_Click({
    $message = $inputBox.Text.Trim()
    if (-not [string]::IsNullOrEmpty($message)) {
        Add-UserMessageToChat($message)
        $userMessage = $message
        $inputBox.Clear()
        Process-UserMessage -userMessage $userMessage
    }
})

# Enter key to send
$inputBox.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq 'Return' -and -not $e.KeyboardDevice.Modifiers) {
        $sendBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        $e.Handled = $true
    }
})

# Disable Send button if input is empty
$inputBox.Add_TextChanged({
    if ([string]::IsNullOrWhiteSpace($inputBox.Text)) {
        $sendBtn.IsEnabled = $false
    } else {
        $sendBtn.IsEnabled = $true
    }
})
$sendBtn.IsEnabled = $false

# Show the window
$window.ShowDialog() | Out-Null
