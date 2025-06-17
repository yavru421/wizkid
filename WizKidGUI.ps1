# WizKid GUI - PowerShell with WPF GUI [REPLACED WITH NEW VERSION]
# This script creates a proper GUI window with chat-first design and sidebar menu

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Ensure $PSScriptRoot is set correctly when running as an EXE
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

# API key prompt (from SimpleGUI)
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
        Add-Type -AssemblyName Microsoft.VisualBasic
        $apiKey = [Microsoft.VisualBasic.Interaction]::InputBox("Enter your GROQ API Key:", "API Key Required", "")
        if ($apiKey) {
            Set-Content -Path $envPath -Value "GROQ_API_KEY=$apiKey"
        } else {
            Add-SystemMessageToChat("⚠️ API key is required to use WizKid.")
            return $null
        }
    }
    return $apiKey
}

# Create the XAML for our window
$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="WizKid by John D Dondlinger" Height="700" Width="1000">
    <Window.Resources>
        <Style x:Key="SidebarButtonStyle" TargetType="Button">
            <Setter Property="Width" Value="180" />
            <Setter Property="Height" Value="40" />
            <Setter Property="Margin" Value="0,5,0,5" />
            <Setter Property="Background" Value="#673AB7" />
            <Setter Property="Foreground" Value="White" />
            <Setter Property="FontSize" Value="14" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                BorderThickness="0"
                                CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#512DA8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <DropShadowEffect x:Key="DropShadowEffect" Color="#512DA8" BlurRadius="12" ShadowDepth="2" Opacity="0.18"/>
    </Window.Resources>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="200"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- Left Sidebar with Features -->
        <Grid Grid.Column="0" Background="#F3E5F5">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            
            <!-- Logo Area -->
            <Border Grid.Row="0" Height="80" Background="#673AB7">
                <TextBlock Text="WizKid" FontWeight="Bold" FontSize="24" Foreground="White"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            
            <!-- Enhanced Sidebar with icons, separators, and section labels -->
            <StackPanel Grid.Row="1" Margin="10,20,10,10">
                <TextBlock Text="Features" FontWeight="Bold" Margin="0,0,0,10" FontSize="16" Foreground="#512DA8"/>
                <Button Name="TakeScreenshotBtn" Content="📷 Take Screenshot" Style="{StaticResource SidebarButtonStyle}" ToolTip="Capture your screen and ask questions about it."/>
                <Separator Margin="0,10,0,10"/>
                <TextBlock Text="Projects" FontWeight="Bold" Margin="0,0,0,10" FontSize="16" Foreground="#512DA8"/>
                <Button Name="OpenProjectBtn" Content="📁 Open Project Folder" Style="{StaticResource SidebarButtonStyle}" ToolTip="Open or create a project folder to organize your work."/>
                <Button Name="ManageProjectsBtn" Content="🗂️ Manage Projects" Style="{StaticResource SidebarButtonStyle}" ToolTip="View, switch, or delete your projects."/>
                <Separator Margin="0,10,0,10"/>
                <TextBlock Text="Assistance" FontWeight="Bold" Margin="0,0,0,10" FontSize="16" Foreground="#512DA8"/>
                <Button Name="HelpBtn" Content="❓ Help / About" Style="{StaticResource SidebarButtonStyle}" ToolTip="Learn about WizKid and how to use it."/>
                <Button Name="ReportProblemBtn" Content="🚩 Report a Problem" Style="{StaticResource SidebarButtonStyle}" ToolTip="Report an issue or get help."/>
                <Button Name="FeedbackBtn" Content="💡 Give Feedback" Style="{StaticResource SidebarButtonStyle}" ToolTip="Send feedback to help improve WizKid."/>
                <Separator Margin="0,10,0,10"/>
                <TextBlock Text="Settings" FontWeight="Bold" Margin="0,0,0,10" FontSize="16" Foreground="#512DA8"/>
                <Button Name="SettingsBtn" Content="⚙️ Settings" Style="{StaticResource SidebarButtonStyle}" ToolTip="Manage your WizKid settings."/>
            </StackPanel>
        </Grid>
        
        <!-- Main Chat Area -->
        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Chat Header -->
            <Border Grid.Row="0" Background="#EDE7F6" Height="50" Padding="15,0,15,0">
                <Grid>
                    <TextBlock Text="Chat with WizKid" FontWeight="Bold" FontSize="18" VerticalAlignment="Center"/>
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                        <ComboBox Name="ModelComboBox" Width="150" SelectedIndex="0" VerticalAlignment="Center">
                            <ComboBoxItem Content="Scout (Default)"/>
                            <ComboBoxItem Content="Maverick"/>
                            <ComboBoxItem Content="Compound Beta"/>
                        </ComboBox>
                    </StackPanel>
                </Grid>
            </Border>
            
            <!-- Chat Messages Area - Using RichTextBox for embedded images -->
            <Border Grid.Row="1" Grid.Column="1" Margin="20,20,20,20" Background="#FAFAFF" CornerRadius="12" 
                    Effect="{DynamicResource DropShadowEffect}">
                <ScrollViewer Name="ChatScrollViewer" VerticalScrollBarVisibility="Auto">
                    <RichTextBox Name="ChatBox" IsReadOnly="True" Background="White" BorderThickness="0" Padding="15" 
                                 VerticalAlignment="Stretch" HorizontalAlignment="Stretch" FontSize="15"/>
                </ScrollViewer>
            </Border>
            
            <!-- Input Area -->
            <Grid Grid.Row="2" Margin="10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox Name="InputTextBox" Grid.Column="0" Height="60" TextWrapping="Wrap" AcceptsReturn="True"
                         VerticalContentAlignment="Center" Padding="10,5,10,5" FontSize="14"/>
                <Button Name="SendBtn" Grid.Column="1" Content="Send" Width="80" Height="60" 
                        Background="#673AB7" Foreground="White" FontSize="16" FontWeight="Bold"
                        Margin="10,0,0,0" BorderThickness="0"/>
            </Grid>
        </Grid>
    </Grid>
</Window>
"@

# Convert the XAML string to XML object
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI elements
$takeScreenshotBtn = $window.FindName('TakeScreenshotBtn')
$openProjectBtn = $window.FindName('OpenProjectBtn')
$manageProjectsBtn = $window.FindName('ManageProjectsBtn')
$feedbackBtn = $window.FindName('FeedbackBtn')
$chatScrollViewer = $window.FindName('ChatScrollViewer')
$chatBox = $window.FindName('ChatBox')
$inputTextBox = $window.FindName('InputTextBox')
$sendBtn = $window.FindName('SendBtn')
$modelComboBox = $window.FindName('ModelComboBox')
$settingsBtn = $window.FindName('SettingsBtn')
$helpBtn = $window.FindName('HelpBtn')
$reportProblemBtn = $window.FindName('ReportProblemBtn')

# Initialize state variables
$script:currentMode = "Chat"
$script:chatHistory = @(@{ role = 'system'; content = 'You are WizKid by John D Dondlinger, a helpful assistant.' })
$script:lastScreenshot = $null
$script:lastScreenshotPath = $null
$script:isProcessing = $false

# Project folder system
$projectsRoot = Join-Path $PSScriptRoot 'projects'
if (-not (Test-Path $projectsRoot)) {
    New-Item -ItemType Directory -Path $projectsRoot | Out-Null
}

# Helper functions for rich text chat display
function Add-UserMessageToChat($message) {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $userRun = New-Object System.Windows.Documents.Run
    $userRun.Text = "You: "
    $userRun.FontWeight = "Bold"
    $userRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::DarkBlue)
    $paragraph.Inlines.Add($userRun)
    
    $messageRun = New-Object System.Windows.Documents.Run
    $messageRun.Text = $message
    $paragraph.Inlines.Add($messageRun)
    
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScrollViewer.ScrollToBottom()
}

function Add-AIMessageToChat($message) {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $aiRun = New-Object System.Windows.Documents.Run
    $aiRun.Text = "WizKid: "
    $aiRun.FontWeight = "Bold"
    $aiRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::Purple)
    $paragraph.Inlines.Add($aiRun)
    
    $messageRun = New-Object System.Windows.Documents.Run
    $messageRun.Text = $message
    $paragraph.Inlines.Add($messageRun)
    
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScrollViewer.ScrollToBottom()
}

function Add-SystemMessageToChat($message, $color = "Gray") {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $systemRun = New-Object System.Windows.Documents.Run
    $systemRun.Text = $message
    $systemRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::$color)
    $systemRun.FontStyle = "Italic"
    $paragraph.Inlines.Add($systemRun)
    $paragraph.TextAlignment = "Center"
    
    $chatBox.Document.Blocks.Add($paragraph)
    $chatScrollViewer.ScrollToBottom()
}

function Add-ImageToChat($imagePath) {
    try {
        $paragraph = New-Object System.Windows.Documents.Paragraph
        $paragraph.TextAlignment = "Center"
        
        $image = New-Object System.Windows.Controls.Image
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = New-Object System.Uri($imagePath, [System.UriKind]::Absolute)
        $bitmap.DecodePixelWidth = 500 # Set max width
        $bitmap.EndInit()
        
        $image.Source = $bitmap
        $image.Width = 500
        
        $container = New-Object System.Windows.Documents.InlineUIContainer($image)
        $paragraph.Inlines.Add($container)
        
        $chatBox.Document.Blocks.Add($paragraph)
        $chatScrollViewer.ScrollToBottom()
        
        return $true
    }
    catch {
        Add-SystemMessageToChat("Failed to add image: $($_.Exception.Message)", "Red")
        return $false
    }
}

# Helper function to run PowerShell scripts
function Invoke-PowerShellScript {
    param($ScriptPath, $Arguments = @())
    
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "powershell.exe"
    $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null
    
    $output = $process.StandardOutput.ReadToEnd()
    $errors = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    return @{
        Output = $output
        Errors = $errors
        ExitCode = $process.ExitCode
    }
}

# Helper: Get selected model for chat only
function Get-SelectedChatModel {
    $selected = $modelComboBox.SelectedItem.Content
    switch ($selected) {
        'Scout (Default)' { return 'compound-beta' } # For chat, always use compound-beta
        'Maverick' { return 'compound-beta' }
        'Compound Beta' { return 'compound-beta' }
        default { return 'compound-beta' }
    }
}

# Helper: Get selected model from ComboBox
function Get-SelectedModel {
    $selected = $modelComboBox.SelectedItem.Content
    switch ($selected) {
        'Scout (Default)' { return 'meta-llama/llama-4-scout-17b-16e-instruct' }
        'Maverick' { return 'meta-llama/llama-4-maverick-8b-8192' }
        'Compound Beta' { return 'compound-beta' }
        default { return 'compound-beta' }
    }
}

# Add Windows TTS support
Add-Type -AssemblyName System.Speech
$global:synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

function Speak-Tooltip($text) {
    $global:synth.SpeakAsyncCancelAll()
    $global:synth.SpeakAsync($text)
}

function Set-WizKidVoice {
    param($voiceName)
    try {
        $global:synth.SelectVoice($voiceName)
    } catch {
        # fallback to default
        $global:synth.SelectVoice('Microsoft Zira Desktop')
    }
    $global:synth.Rate = -1  # Slightly slower for smoothness
    $global:synth.Volume = 100
}

function Get-AvailableVoices {
    return $global:synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }
}

# On startup, set default voice
Set-WizKidVoice 'Microsoft Zira Desktop'

# Fun, witty WizKid TTS lines and animated chat intro
$wizKidIntros = @(
    "Hey there! I'm WizKid, your digital sidekick. Ready to zap your tech troubles!",
    "Welcome! WizKid here—let's make your computer life a breeze.",
    "Need a hand? Or maybe a byte? WizKid's got you covered!",
    "I'm WizKid, your friendly computer wizard. Ask me anything!"
)

function Show-WizKidIntro {
    $msg = Get-Random -InputObject $wizKidIntros
    $window.Opacity = 0
    $window.Show()
    for ($i = 0; $i -le 10; $i++) {
        $window.Opacity = $i/10
        Start-Sleep -Milliseconds 40
    }
    Add-SystemMessageToChat($msg)
    $global:synth.SpeakAsync($msg)
}

# Fix: Show window immediately, then run fade-in and TTS asynchronously to avoid black/frozen screen
$window.Opacity = 0
$window.Show()

Start-Job -ScriptBlock {
    Start-Sleep -Milliseconds 200
    [System.Windows.Application]::Current.Dispatcher.Invoke({
        for ($i = 0; $i -le 10; $i++) {
            $window.Opacity = $i/10
            Start-Sleep -Milliseconds 40
        }
        $msg = Get-Random -InputObject $wizKidIntros
        Add-SystemMessageToChat($msg)
        Invoke-GroqTTS $msg "Celeste-PlayAI"
    })
} | Out-Null

# Show the window
$window.ShowDialog() | Out-Null

# Button Events
# Screenshot button logic (uses selected model for vision)
$takeScreenshotBtn.Add_Click({
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
        $script:lastScreenshotPath = $screenshotPath
        Add-SystemMessageToChat("Screenshot captured!")
        Add-ImageToChat($screenshotPath)
        $script:currentMode = "Screenshot"
        Add-SystemMessageToChat("What would you like to know about this screenshot? (Model: " + (Get-SelectedModel) + ")")
    } catch {
        Add-SystemMessageToChat("⚠️ Error capturing screenshot: $($_.Exception.Message)")
    }
})

# Feedback button logic (from SimpleGUI, adapted for GUI)
$feedbackBtn.Add_Click({
    Add-Type -AssemblyName Microsoft.VisualBasic
    $feedback = [Microsoft.VisualBasic.Interaction]::InputBox("Type your feedback below:", "Send Feedback", "")
    if ($feedback) {
        $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
        Add-Content -Path $logPath -Value "[$([datetime]::Now)] $feedback"
        Add-SystemMessageToChat("Thank you for your feedback!")
    }
})

# Send button logic (from SimpleGUI, robust chat handling)
$sendBtn.Add_Click({
    $userInput = $inputTextBox.Text.Trim()
    if (-not $userInput) { return }
    Add-UserMessageToChat($userInput)
    $inputTextBox.Clear()
    $apiKey = Get-ApiKey
    if (-not $apiKey) { return }
    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }
    if ($script:currentMode -eq "Screenshot" -or $script:currentMode -eq "Clipboard") {
        $model = 'meta-llama/llama-4-scout-17b-16e-instruct' # Always use Scout for vision
        if ($script:lastScreenshotPath -and (Test-Path $script:lastScreenshotPath)) {
            Add-SystemMessageToChat("Analyzing image with model: $model ...")
            $bytes = [IO.File]::ReadAllBytes($script:lastScreenshotPath)
            $base64Image = [Convert]::ToBase64String($bytes)
            $payload = @{
                model = $model
                messages = @(
                    @{
                        role = "user"
                        content = @(
                            @{ type = "text"; text = $userInput },
                            @{ type = "image_url"; image_url = @{ url = "data:image/png;base64,$base64Image" } }
                        )
                    }
                )
                max_tokens = 2048
            }
        } else {
            Add-SystemMessageToChat("⚠️ No image available for analysis.")
            return
        }
    } else {
        $model = Get-SelectedChatModel
        Add-SystemMessageToChat("Thinking with model: $model ...")
        $payload = @{
            model = $model
            messages = @(
                @{ role = "system"; content = "You are WizKid by John D Dondlinger, a helpful AI assistant." },
                @{ role = "user"; content = $userInput }
            )
        }
    }
    try {
        $json = ConvertTo-Json -InputObject $payload -Depth 10
        $response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $headers -Body $json
        $aiResponse = $response.choices[0].message.content
        Add-AIMessageToChat($aiResponse)
    } catch {
        Add-SystemMessageToChat("⚠️ Oops! Something went wrong. Please check your internet connection and API key, or try again later.")
    }
    $script:currentMode = "Chat"
})

# Settings window XAML
# Add Voice selection to Settings window
$settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Settings" Height="400" Width="400" WindowStartupLocation="CenterOwner">
    <StackPanel Margin="20">
        <TextBlock Text="Settings" FontWeight="Bold" FontSize="18" Margin="0,0,0,15"/>
        <TextBlock Text="Chat Model:" Margin="0,10,0,0"/>
        <ComboBox Name="ChatModelComboBox" SelectedIndex="0">
            <ComboBoxItem Content="compound-beta"/>
        </ComboBox>
        <TextBlock Text="Vision Model:" Margin="0,10,0,0"/>
        <ComboBox Name="VisionModelComboBox" SelectedIndex="0">
            <ComboBoxItem Content="meta-llama/llama-4-scout-17b-16e-instruct"/>
        </ComboBox>
        <TextBlock Text="Voice (for spoken tooltips):" Margin="0,10,0,0"/>
        <ComboBox Name="VoiceComboBox"/>
        <TextBlock Text="API Key:" Margin="0,10,0,0"/>
        <PasswordBox Name="ApiKeyBox"/>
        <Button Name="SaveSettingsBtn" Content="Save" Margin="0,20,0,0" Width="80" HorizontalAlignment="Right"/>
    </StackPanel>
</Window>
"@

function Show-SettingsWindow {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($settingsXaml))
    $settingsWindow = [Windows.Markup.XamlReader]::Load($reader)
    $voiceComboBox = $settingsWindow.FindName('VoiceComboBox')
    $apiKeyBox = $settingsWindow.FindName('ApiKeyBox')
    $saveSettingsBtn = $settingsWindow.FindName('SaveSettingsBtn')
    # Populate voices
    $voices = Get-AvailableVoices
    $voices | ForEach-Object { $voiceComboBox.Items.Add($_) }
    $voiceComboBox.SelectedItem = $global:synth.Voice.Name
    # Load current API key (if any)
    $envPath = Join-Path $PSScriptRoot ".env"
    $apiKey = $null
    if (Test-Path $envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match "^GROQ_API_KEY=(.*)$") {
                $apiKey = $matches[1]
            }
        }
    }
    if ($apiKey) { $apiKeyBox.Password = $apiKey }
    $saveSettingsBtn.Add_Click({
        $newApiKey = $apiKeyBox.Password
        if ($newApiKey) {
            Set-Content -Path $envPath -Value "GROQ_API_KEY=$newApiKey"
        }
        $chosenVoice = $voiceComboBox.SelectedItem
        if ($chosenVoice) {
            Set-WizKidVoice $chosenVoice
            Set-Content -Path (Join-Path $PSScriptRoot 'wizkid_settings.txt') -Value "voice=$chosenVoice"
        }
        $settingsWindow.Close()
        Add-SystemMessageToChat("Settings saved.")
    })
    $settingsWindow.Owner = $window
    $settingsWindow.ShowDialog() | Out-Null
}

$settingsBtn.Add_Click({ Show-SettingsWindow })

# Help/About dialog
$helpXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="About WizKid" Height="350" Width="420" WindowStartupLocation="CenterOwner">
    <StackPanel Margin="20">
        <TextBlock Text="Welcome to WizKid!" FontWeight="Bold" FontSize="18" Margin="0,0,0,15"/>
        <TextBlock TextWrapping="Wrap">
WizKid is your friendly computer helper. You can ask questions, get help with screenshots or images, and report problems you experience on your computer. 

How to use:
- Type your question and click Send.
- Use the Screenshot or Clipboard buttons to analyze images.
- Use the Settings menu to manage your API key.
- Click 'Report a Problem' to send feedback or get support.
        </TextBlock>
        <Button Name="CloseHelpBtn" Content="Close" Margin="0,20,0,0" Width="80" HorizontalAlignment="Right"/>
    </StackPanel>
</Window>
"@

function Show-HelpWindow {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($helpXaml))
    $helpWindow = [Windows.Markup.XamlReader]::Load($reader)
    $closeBtn = $helpWindow.FindName('CloseHelpBtn')
    $closeBtn.Add_Click({ $helpWindow.Close() })
    $helpWindow.Owner = $window
    $helpWindow.ShowDialog() | Out-Null
}

$helpBtn.Add_Click({ Show-HelpWindow })

# Report a Problem dialog
$reportXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Report a Problem" Height="320" Width="420" WindowStartupLocation="CenterOwner">
    <StackPanel Margin="20">
        <TextBlock Text="Report a Problem or Get Help" FontWeight="Bold" FontSize="18" Margin="0,0,0,15"/>
        <TextBlock TextWrapping="Wrap">Describe the issue you are experiencing. WizKid will log your report and help you as best as possible.</TextBlock>
        <TextBox Name="ProblemBox" Height="100" Margin="0,10,0,0" TextWrapping="Wrap" AcceptsReturn="True"/>
        <Button Name="SendReportBtn" Content="Send Report" Margin="0,20,0,0" Width="120" HorizontalAlignment="Right"/>
    </StackPanel>
</Window>
"@

function Show-ReportWindow {
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($reportXaml))
    $reportWindow = [Windows.Markup.XamlReader]::Load($reader)
    $problemBox = $reportWindow.FindName('ProblemBox')
    $sendBtn = $reportWindow.FindName('SendReportBtn')
    $sendBtn.Add_Click({
        $report = $problemBox.Text.Trim()
        if ($report) {
            $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
            Add-Content -Path $logPath -Value "[REPORT $([datetime]::Now)] $report"
            Add-SystemMessageToChat("Thank you for your report! WizKid will do its best to help.")
            $reportWindow.Close()
        } else {
            [System.Windows.MessageBox]::Show("Please describe your problem before sending.", "Missing Information", 'OK', 'Warning')
        }
    })
    $reportWindow.Owner = $window
    $reportWindow.ShowDialog() | Out-Null
}

$reportProblemBtn.Add_Click({ Show-ReportWindow })

# Project folder system
$projectsRoot = Join-Path $PSScriptRoot 'projects'
if (-not (Test-Path $projectsRoot)) {
    New-Item -ItemType Directory -Path $projectsRoot | Out-Null
}

function Show-OpenProjectDialog {
    Add-Type -AssemblyName System.Windows.Forms
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select or create a project folder."
    $folderDialog.SelectedPath = $projectsRoot
    if ($folderDialog.ShowDialog() -eq 'OK') {
        $selectedPath = $folderDialog.SelectedPath
        Add-SystemMessageToChat("Project folder opened: $selectedPath")
        $script:currentProject = $selectedPath
    }
}

function Show-ManageProjectsDialog {
    $projects = Get-ChildItem -Path $projectsRoot -Directory | Select-Object -ExpandProperty Name
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Manage Projects" Height="350" Width="400" WindowStartupLocation="CenterOwner">
    <StackPanel Margin="20">
        <TextBlock Text="Your Projects" FontWeight="Bold" FontSize="18" Margin="0,0,0,15"/>
        <ListBox Name="ProjectsList" Height="180"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
            <Button Name="SwitchBtn" Content="Switch" Width="80" Margin="0,0,10,0"/>
            <Button Name="DeleteBtn" Content="Delete" Width="80"/>
            <Button Name="CloseBtn" Content="Close" Width="80" Margin="10,0,0,0"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $projWindow = [Windows.Markup.XamlReader]::Load($reader)
    $listBox = $projWindow.FindName('ProjectsList')
    $switchBtn = $projWindow.FindName('SwitchBtn')
    $deleteBtn = $projWindow.FindName('DeleteBtn')
    $closeBtn = $projWindow.FindName('CloseBtn')
    $projects | ForEach-Object { $listBox.Items.Add($_) }
    $switchBtn.Add_Click({
        if ($listBox.SelectedItem) {
            $script:currentProject = Join-Path $projectsRoot $listBox.SelectedItem
            Add-SystemMessageToChat("Switched to project: $($listBox.SelectedItem)")
            $projWindow.Close()
        }
    })
    $deleteBtn.Add_Click({
        if ($listBox.SelectedItem) {
            $projName = $listBox.SelectedItem
            $projPath = Join-Path $projectsRoot $projName
            Remove-Item -Path $projPath -Recurse -Force
            $listBox.Items.Remove($projName)
            Add-SystemMessageToChat("Deleted project: $projName")
        }
    })
    $closeBtn.Add_Click({ $projWindow.Close() })
    $projWindow.Owner = $window
    $projWindow.ShowDialog() | Out-Null
}

$openProjectBtn.Add_Click({ Show-OpenProjectDialog })
$manageProjectsBtn.Add_Click({ Show-ManageProjectsDialog })

# Change default WizKid tooltip voice to Celeste-PlayAI (calm, professional)
function Read-Tooltip {
    param([string]$text)
    $line = Get-Random -InputObject $wizKidTooltipLines
    Invoke-GroqTTS "$line $text" "Celeste-PlayAI"
}

# Attach Groq TTS to sidebar button tooltips
$takeScreenshotBtn.Add_MouseEnter({ Read-Tooltip 'Capture your screen and ask questions about it.' })
$openProjectBtn.Add_MouseEnter({ Read-Tooltip 'Open or create a project folder to organize your work.' })
$manageProjectsBtn.Add_MouseEnter({ Read-Tooltip 'View, switch, or delete your projects.' })
$helpBtn.Add_MouseEnter({ Read-Tooltip 'Learn about WizKid and how to use it.' })
$reportProblemBtn.Add_MouseEnter({ Read-Tooltip 'Report an issue or get help.' })
$feedbackBtn.Add_MouseEnter({ Read-Tooltip 'Send feedback to help improve WizKid.' })
$settingsBtn.Add_MouseEnter({ Read-Tooltip 'Manage your WizKid settings.' })

# Groq TTS function
function Invoke-GroqTTS {
    param(
        [string]$text,
        [string]$voice = "Fritz-PlayAI"
    )
    $apiKey = Get-ApiKey
    if (-not $apiKey) { return }
    $audioDir = Join-Path $PSScriptRoot 'audio'
    if (-not (Test-Path $audioDir)) { New-Item -ItemType Directory -Path $audioDir | Out-Null }
    $outputPath = Join-Path $audioDir "wizkid_tts.wav"
    $url = "https://api.groq.com/openai/v1/audio/speech"
    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }
    $payload = @{
        model = "playai-tts"
        input = $text
        voice = $voice
        response_format = "wav"
    } | ConvertTo-Json
    try {
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $payload -OutFile $outputPath
        # Play the audio (WAV)
        Add-Type -AssemblyName presentationcore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open([Uri]::new($outputPath))
        $player.Volume = 1.0
        $player.Play()
    } catch {
        Add-SystemMessageToChat("TTS error: $($_.Exception.Message)")
    }
}
