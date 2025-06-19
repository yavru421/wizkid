# WizKid - Comprehensive PowerShell GUI Application
# Combined from all WizKid variants by John D Dondlinger
# Features: GUI Chat, Screenshot Analysis, Project Management, Settings, Console Mode

param(
    [switch]$Console,
    [switch]$GUI
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Ensure PSScriptRoot is set correctly when running as an EXE
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $script:PSScriptRoot = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
}

# Helper to add a recent action - MOVED TO TOP before any function that uses it
function Add-RecentAction {
    param($actionText)
    $recentPanel = $script:recentActionsPanel
    if ($recentPanel) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $actionText
        $btn.Margin = '0,2,0,2'
        $btn.Height = 28
        $btn.Background = [System.Windows.Media.Brushes]::White
        $btn.Foreground = [System.Windows.Media.Brushes]::Purple
        $btn.FontSize = 13
        $btn.HorizontalAlignment = 'Stretch'
        # Only add event handler if inputTextBox exists
        if ($script:inputTextBox) {
            $btn.Add_Click({ $script:inputTextBox.Text = $actionText })
        }
        $recentPanel.Children.Insert(0, $btn)
        # Limit to 5 recent actions
        while ($recentPanel.Children.Count -gt 5) { $recentPanel.Children.RemoveAt($recentPanel.Children.Count-1) }
    }
}

# --- SPLASH SCREEN: Show WizKid ASCII Logo ---
function Show-WizKidLogo {
    $logoPath = Join-Path $PSScriptRoot 'wizkidlogo.txt'
    if (-not (Test-Path $logoPath)) { return }
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

# --- CONSOLE MODE FUNCTIONS ---
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

function Show-ConsoleMenu {
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

function Start-ConsoleMode {
    # Configuration (with defaults)
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

    while ($true) {
        Show-ConsoleMenu
        $choice = Read-Host "Choose an option (0-7)"
        
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
            "7" {
                Write-Host "Switching to GUI mode..." -ForegroundColor Green
                Start-Sleep -Seconds 1
                return "GUI"
            }
            "0" { 
                Write-Host "Thank you for using WizKid by John D Dondlinger!" -ForegroundColor Magenta
                Exit
            }
            default { Write-Host "Invalid option. Please try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# --- GUI MODE FUNCTIONS ---
# API key management
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
            if ($script:chatBox) {
                Add-SystemMessageToChat("⚠️ API key is required to use WizKid.")
            } else {
                Write-Host "⚠️ API key is required to use WizKid." -ForegroundColor Red
            }
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
        <ScrollViewer Grid.Column="0" Background="#F3E5F5" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,0,0">
                <Expander Header="Recent Actions" Name="RecentActionsExpander" IsExpanded="True" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                    <StackPanel Name="RecentActionsPanel" />
                </Expander>
                <Expander Header="Main Actions" IsExpanded="True" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                    <StackPanel>
                        <Button Name="SendMessageBtn" Content="Ask a Question" Style="{StaticResource SidebarButtonStyle}" ToolTip="Start a chat with WizKid."/>
                        <Button Name="TakeScreenshotBtn" Content="Take Screenshot" Style="{StaticResource SidebarButtonStyle}" ToolTip="Capture your screen and ask questions about it."/>
                    </StackPanel>
                </Expander>
                <Expander Header="Context" IsExpanded="False" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                    <StackPanel>
                        <Button Name="UploadFileBtn" Content="Upload File(s)" Style="{StaticResource SidebarButtonStyle}" ToolTip="Upload files for WizKid to process."/>
                        <Button Name="ViewContextBtn" Content="View Context Files" Style="{StaticResource SidebarButtonStyle}" ToolTip="View or select uploaded files for analysis."/>
                    </StackPanel>
                </Expander>
                <Expander Header="Settings &amp; Help" IsExpanded="False" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                    <StackPanel>
                        <Button Name="SettingsBtn" Content="Settings" Style="{StaticResource SidebarButtonStyle}" ToolTip="Manage your WizKid settings."/>
                        <Button Name="HelpBtn" Content="Help" Style="{StaticResource SidebarButtonStyle}" ToolTip="Learn about WizKid and how to use it."/>
                        <Button Name="ReportProblemBtn" Content="Report Issue" Style="{StaticResource SidebarButtonStyle}" ToolTip="Report an issue or get help."/>
                        <Button Name="FeedbackBtn" Content="Send Feedback" Style="{StaticResource SidebarButtonStyle}" ToolTip="Send feedback to help improve WizKid."/>
                        <Button Name="ConsoleBtn" Content="Switch to Console" Style="{StaticResource SidebarButtonStyle}" ToolTip="Switch to console mode."/>
                    </StackPanel>
                </Expander>
            </StackPanel>
        </ScrollViewer>
        
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
            
            <!-- Chat Messages Area -->
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

# --- XAML for Compact Mode ---
$compactXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WizKid Compact" Height="100" Width="100"
        WindowStyle="None" AllowsTransparency="True" Background="#673AB7"
        Topmost="True" ShowInTaskbar="True">
    <Grid>
        <Ellipse Fill="#673AB7" Width="80" Height="80" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        <Image Name="LogoImage" Width="48" Height="48" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Grid>
</Window>
"@

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
    
    $script:chatBox.Document.Blocks.Add($paragraph)
    $script:chatScrollViewer.ScrollToBottom()
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
    
    $script:chatBox.Document.Blocks.Add($paragraph)
    $script:chatScrollViewer.ScrollToBottom()
}

function Add-SystemMessageToChat($message, $color = "Gray") {
    $paragraph = New-Object System.Windows.Documents.Paragraph
    $systemRun = New-Object System.Windows.Documents.Run
    $systemRun.Text = $message
    $systemRun.Foreground = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Colors]::$color)
    $systemRun.FontStyle = "Italic"
    $paragraph.Inlines.Add($systemRun)
    $paragraph.TextAlignment = "Center"
    
    $script:chatBox.Document.Blocks.Add($paragraph)
    $script:chatScrollViewer.ScrollToBottom()
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
        $script:chatBox.Document.Blocks.Add($paragraph)
        $script:chatScrollViewer.ScrollToBottom()
        # Add Analyze Image button after image
        $analyzeBtn = New-Object System.Windows.Controls.Button
        $analyzeBtn.Content = "Analyze Image (Coming Soon)"
        $analyzeBtn.Margin = '0,8,0,8'
        $analyzeBtn.Width = 180
        $analyzeBtn.Height = 36
        $analyzeBtn.Background = [System.Windows.Media.Brushes]::MediumPurple
        $analyzeBtn.Foreground = [System.Windows.Media.Brushes]::White
        $analyzeBtn.FontWeight = 'Bold'
        $analyzeBtn.HorizontalAlignment = 'Center'
        $analyzeBtn.Add_Click({
            Add-SystemMessageToChat("Image analysis is coming soon! If you want to integrate real image analysis, let me know.")
        })
        $btnContainer = New-Object System.Windows.Documents.BlockUIContainer($analyzeBtn)
        $script:chatBox.Document.Blocks.Add($btnContainer)
        $script:chatScrollViewer.ScrollToBottom()
        return $true
    }
    catch {
        Add-SystemMessageToChat("Failed to add image: $($_.Exception.Message)", "Red")
        return $false
    }
}

# Helper: Get selected model for chat only
function Get-SelectedChatModel {
    $selected = $script:modelComboBox.SelectedItem.Content
    switch ($selected) {
        'Scout (Default)' { return 'compound-beta' }
        'Maverick' { return 'compound-beta' }
        'Compound Beta' { return 'compound-beta' }
        default { return 'compound-beta' }
    }
}

# Helper: Get selected model from ComboBox
function Get-SelectedModel {
    $selected = $script:modelComboBox.SelectedItem.Content
    switch ($selected) {
        'Scout (Default)' { return 'meta-llama/llama-4-scout-17b-16e-instruct' }
        'Maverick' { return 'meta-llama/llama-4-maverick-8b-8192' }
        'Compound Beta' { return 'compound-beta' }
        default { return 'compound-beta' }
    }
}

function Start-GUIMode {
    param([switch]$QuickScreenshot, [switch]$ClipboardAction)
    # Convert the XAML string to XML object
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $script:window = [Windows.Markup.XamlReader]::Load($reader)

    # Get UI elements
    $script:takeScreenshotBtn = $window.FindName('TakeScreenshotBtn')
    if (-not $script:takeScreenshotBtn) { throw "TakeScreenshotBtn not found in XAML." }
    $script:sendBtn = $window.FindName('SendBtn')
    if (-not $script:sendBtn) { throw "SendBtn not found in XAML." }
    $script:feedbackBtn = $window.FindName('FeedbackBtn')
    $script:chatScrollViewer = $window.FindName('ChatScrollViewer')
    $script:chatBox = $window.FindName('ChatBox')
    $script:inputTextBox = $window.FindName('InputTextBox')
    $script:modelComboBox = $window.FindName('ModelComboBox')
    $script:settingsBtn = $window.FindName('SettingsBtn')
    $script:helpBtn = $window.FindName('HelpBtn')
    $script:reportProblemBtn = $window.FindName('ReportProblemBtn')
    $script:consoleBtn = $window.FindName('ConsoleBtn')
    $script:uploadFileBtn = $window.FindName('UploadFileBtn')
    $script:viewContextBtn = $window.FindName('ViewContextBtn')
    $script:patternSelector = $window.FindName('PatternSelector')
    $script:recentActionsPanel = $window.FindName('RecentActionsPanel')

    # Initialize state variables
    $script:currentMode = "Chat"
    $script:lastScreenshotPath = $null

    # Project folder system
    $projectsRoot = Join-Path $PSScriptRoot 'projects'
    if (-not (Test-Path $projectsRoot)) {
        New-Item -ItemType Directory -Path $projectsRoot | Out-Null
    }

    # Configure event handlers
    Set-EventHandlers

    # Show welcome message
    Add-SystemMessageToChat("Welcome! I'm WizKid, your helpful assistant. How can I help you today?")

    # Show the window (blocking, responsive)
    $window.ShowDialog() | Out-Null
    if ($QuickScreenshot) {
        # Trigger screenshot after window is loaded and idle
        $window.Dispatcher.InvokeAsync({
            $script:takeScreenshotBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
        }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
    }
}

function Set-EventHandlers {
    # Screenshot button logic
    $script:takeScreenshotBtn.Add_Click({
        Add-RecentAction 'Screenshot taken'
        try {
            Add-SystemMessageToChat("Taking a screenshot...")
            $currentState = $script:window.WindowState
            $script:window.WindowState = [System.Windows.WindowState]::Minimized
            Start-Sleep -Milliseconds 500
            $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
            $script:window.WindowState = $currentState
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

    # Feedback button logic
    $script:feedbackBtn.Add_Click({
        Add-Type -AssemblyName Microsoft.VisualBasic
        $feedback = [Microsoft.VisualBasic.Interaction]::InputBox("Please provide your feedback:", "Send Feedback", "")
        if ($feedback) {
            $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
            Add-Content -Path $logPath -Value "[$([datetime]::Now)] $feedback"
            Add-SystemMessageToChat("Thank you for your feedback!")
        } else {
            Add-SystemMessageToChat("Feedback cancelled.")
        }
    })

    # Send button logic
    $script:sendBtn.Add_Click({
        $userInput = $script:inputTextBox.Text.Trim()
        if ($userInput) { Add-RecentAction $userInput }
        $script:inputTextBox.Clear()
        $apiKey = Get-ApiKey
        if (-not $apiKey) { return }
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }
        # Step 1: Ask Groq to recommend a pattern
        $patternPayload = @{
            model = Get-SelectedChatModel
            messages = @(
                @{ role = "system"; content = "You are an expert prompt engineer. When given a user prompt, you respond with the best pattern name only." },
                @{ role = "user"; content = $userInput }
            )
            max_tokens = 10
            temperature = 0.2
        }
        try {
            $patternJson = ConvertTo-Json -InputObject $patternPayload -Depth 10
            $patternResponse = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $headers -Body $patternJson
            $pattern = $patternResponse.choices[0].message.content.Trim()
            Add-SystemMessageToChat("(WizKid chose pattern: $pattern)")
        } catch {
            $pattern = "Zero Shot"
            Add-SystemMessageToChat("(Pattern selection failed, using Zero Shot)")
        }
        # Step 2: Build the actual prompt using the chosen pattern
        $prompt = $userInput
        switch ($pattern) {
            "Zero Shot" {
                $prompt = "Please answer the following as clearly as possible.\n" + $userInput
            }
            "Few Shot" {
                $prompt = "Example 1:\nInput: What is 2+2?\nOutput: 4\nNow, process this input:\nInput: $userInput\nOutput:"
            }
            "Chain of Thought" {
                $prompt = "Let's think step by step.\n" + $userInput
            }
            "Guided CoT" {
                $prompt = "Analyze using these steps: 1. Extract info 2. Identify issue 3. Assess urgency 4. Suggest actions.\n" + $userInput
            }
            "ReAct" {
                $prompt = "SYSTEM: You can use tools like Search[query]. USER: $userInput"
            }
            "CoVe" {
                $prompt = "Phase 1: Draft analysis\nPhase 2: List verification questions\nPhase 3: Answer questions\nPhase 4: Revise analysis\nInput: $userInput"
            }
            "Chain of Density" {
                $prompt = "Summarize the following in exactly 25 words. Each round, add 1-2 new details and compress as needed. Repeat 4 times.\nText: $userInput"
            }
            default {}
        }
        $model = Get-SelectedChatModel
        Add-SystemMessageToChat("Thinking with model: $model using pattern: $pattern ...")
        $payload = @{
            model = $model
            messages = @(
                @{ role = "system"; content = "You are WizKid by John D Dondlinger, a helpful AI assistant." },
                @{ role = "user"; content = $prompt }
            )
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

    # Enable Enter key to send messages
    if ($script:inputTextBox) {
        $script:inputTextBox.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq 'Return' -and -not $e.KeyboardDevice.Modifiers) {
                $script:sendBtn.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
                $e.Handled = $true
            }
        })
        
        # Disable Send button if input is empty
        $script:inputTextBox.Add_TextChanged({
            if ([string]::IsNullOrWhiteSpace($script:inputTextBox.Text)) {
                $script:sendBtn.IsEnabled = $false
            } else {
                $script:sendBtn.IsEnabled = $true
            }
        })
        $script:sendBtn.IsEnabled = $false
    }

    # Basic implementations for other buttons
    $script:helpBtn.Add_Click({
        [System.Windows.MessageBox]::Show("WizKid by John D Dondlinger`n`nYour friendly computer assistant.`n`nFeatures:`n- Chat with AI`n- Screenshot analysis`n- Project management`n- Settings management", "About WizKid", 'OK', 'Information')
    })

    $script:settingsBtn.Add_Click({
        $envPath = Join-Path $PSScriptRoot ".env"
        $currentKey = $null
        if (Test-Path $envPath) {
            Get-Content $envPath | ForEach-Object {
                if ($_ -match "^GROQ_API_KEY=(.*)$") {
                    $currentKey = $matches[1]
                }
            }
        }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $apiKey = [Microsoft.VisualBasic.Interaction]::InputBox("Enter your GROQ API Key:", "API Key", $currentKey)
        if ($apiKey) {
            Set-Content -Path $envPath -Value "GROQ_API_KEY=$apiKey"
            Add-SystemMessageToChat("API key saved.")
        } else {
            Add-SystemMessageToChat("API key entry cancelled.")
        }
    })

    $script:reportProblemBtn.Add_Click({
        Add-Type -AssemblyName Microsoft.VisualBasic
        $report = [Microsoft.VisualBasic.Interaction]::InputBox("Describe the problem you're experiencing:", "Report Problem", "")
        if ($report) {
            $logPath = Join-Path $PSScriptRoot "WizKid_Feedback.log"
            Add-Content -Path $logPath -Value "[PROBLEM REPORT $([datetime]::Now)] $report"
            Add-SystemMessageToChat("Thank you for your report!")
        }
    })
}

# --- AUDIO FUNCTIONS ---
function Start-AudioFile {
    param([string]$AudioFileName)
    $audioPath = Join-Path (Join-Path $PSScriptRoot 'audio') $AudioFileName
    if (Test-Path $audioPath) {
        $player = New-Object System.Media.SoundPlayer $audioPath
        $player.Play()
    }
}

function Start-TooltipAudio {
    param([string]$TooltipType)
    $audioFiles = @{
        "TakeScreenshot" = "tooltip_take_screenshot.wav"
        "OpenProject" = "tooltip_open_project_folder.wav"
        "ManageProjects" = "tooltip_manage_projects.wav"
        "Help" = "tooltip_help___about.wav"
        "ReportProblem" = "tooltip_report_a_problem.wav"
        "Feedback" = "tooltip_give_feedback.wav"
        "Intro" = "wizkid_intro.wav"
    }
    if ($audioFiles.ContainsKey($TooltipType)) {
        Start-AudioFile $audioFiles[$TooltipType]
    }
}

# --- MAIN EXECUTION LOGIC ---
# Always launch full GUI mode by default
if ($Console) {
    Show-WizKidLogo
    Start-ConsoleMode
} elseif ($GUI -or $args.Count -eq 0) {
    Start-GUIMode
} else {
    Show-WizKidLogo
    Write-Host "Choose your preferred mode:" -ForegroundColor Cyan
    Write-Host "1) GUI Mode (Recommended)" -ForegroundColor Green
    Write-Host "2) Console Mode" -ForegroundColor Yellow
    Write-Host ""
    $modeChoice = Read-Host "Enter choice (1-2) [default: 1]"
    if ($modeChoice -eq "2") {
        Start-ConsoleMode
    } else {
        Start-GUIMode
    }
}
