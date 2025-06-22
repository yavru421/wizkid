# WizKid - WORKING VERSION - Chat Fixed
param([switch]$Console, [switch]$GUI)

# Import modules
$modulesPath = Join-Path $PSScriptRoot 'modules'
Import-Module (Join-Path $modulesPath 'ApiKeyManager.psm1') -Force
Import-Module (Join-Path $modulesPath 'GroqApiUtils.psm1') -Force
Import-Module (Join-Path $modulesPath 'WizKidGui.psm1') -Force
Import-Module (Join-Path $modulesPath 'ScreenshotUtils.psm1') -Force
Import-Module (Join-Path $modulesPath 'ImageUtils.psm1') -Force

# Clear environment variable to use .env file
$env:GROQ_API_KEY = $null

# Main GUI Function
function Start-WizKidGUI {
    try {
        Load-Xaml
        Initialize-UIElements
        Initialize-ChatSystem
        Setup-EventHandlers
        Show-WelcomeMessage
        Show-Window
    } catch {
        Write-Host "GUI Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

function Get-XamlDefinition {
    return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WizKid - AI Assistant" Height="700" Width="1000" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style x:Key="SidebarButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#9C27B0"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="250"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- Sidebar -->
        <DockPanel Grid.Column="0" Background="#E1BEE7">
            <TextBlock DockPanel.Dock="Top" Text="WizKid" FontSize="24" FontWeight="Bold" 
                       HorizontalAlignment="Center" Margin="10" Foreground="#4A148C"/>
            
            <ScrollViewer DockPanel.Dock="Top">
                <StackPanel>
                    <Expander Header="Main Actions" IsExpanded="True" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                        <StackPanel>
                            <Button Name="TakeScreenshotBtn" Content="Screenshot" Style="{StaticResource SidebarButtonStyle}"/>
                            <Button Name="ResearchAnalysisBtn" Content="Research" Style="{StaticResource SidebarButtonStyle}"/>
                            <Button Name="ChatBtn" Content="Chat" Style="{StaticResource SidebarButtonStyle}"/>
                        </StackPanel>
                    </Expander>
                    
                    <Expander Header="Settings" IsExpanded="False" Background="#D1C4E9" Foreground="#512DA8" FontWeight="Bold" Margin="10,10,10,0">
                        <StackPanel>
                            <Button Name="SettingsBtn" Content="Settings" Style="{StaticResource SidebarButtonStyle}"/>
                            <Button Name="HelpBtn" Content="Help" Style="{StaticResource SidebarButtonStyle}"/>
                        </StackPanel>
                    </Expander>
                </StackPanel>
            </ScrollViewer>
        </DockPanel>

        <!-- Main Content -->
        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <!-- Chat Area -->
            <ScrollViewer Name="ChatScrollViewer" Grid.Row="0" VerticalScrollBarVisibility="Auto" Margin="10">
                <ItemsControl Name="ChatBox" Background="#F5F5F5"/>
            </ScrollViewer>

            <!-- Input Area -->
            <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="10">
                <TextBox Name="InputTextBox" MinWidth="400" Height="30" VerticalAlignment="Center" FontSize="14"/>
                <Button Name="SendBtn" Content="Send" Width="80" Height="30" Margin="5,0,0,0" Background="#9C27B0" Foreground="White" FontWeight="Bold"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@
}

function Load-Xaml {
    try {
        $xamlContent = Get-XamlDefinition
        [xml]$xamlDoc = $xamlContent
        $reader = New-Object System.Xml.XmlNodeReader $xamlDoc
        $script:window = [Windows.Markup.XamlReader]::Load($reader)
        Write-Host "XAML loaded successfully" -ForegroundColor Green
    } catch {
        throw "Failed to load XAML: $($_.Exception.Message)"
    }
}

function Initialize-UIElements {
    try {
        $script:chatBox = $script:window.FindName('ChatBox')
        $script:chatScrollViewer = $script:window.FindName('ChatScrollViewer')
        $script:inputTextBox = $script:window.FindName('InputTextBox')
        $script:sendBtn = $script:window.FindName('SendBtn')
        $script:takeScreenshotBtn = $script:window.FindName('TakeScreenshotBtn')
        $script:researchBtn = $script:window.FindName('ResearchAnalysisBtn')
        $script:chatBtn = $script:window.FindName('ChatBtn')
        $script:settingsBtn = $script:window.FindName('SettingsBtn')
        $script:helpBtn = $script:window.FindName('HelpBtn')
        
        if (-not $script:chatBox) { throw "Failed to find UI element: ChatBox" }
        if (-not $script:sendBtn) { throw "Failed to find UI element: SendBtn" }
        
        Write-Host "All UI elements initialized successfully" -ForegroundColor Green
    } catch {
        throw "Failed to initialize UI elements: $($_.Exception.Message)"
    }
}

function Initialize-ChatSystem {
    try {
        $script:chatMessages = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        $script:chatBox.ItemsSource = $script:chatMessages
        $script:currentMode = "Chat"
        $script:lastScreenshotPath = $null
        Write-Host "Chat system initialized successfully" -ForegroundColor Green
    } catch {
        throw "Failed to initialize chat system: $($_.Exception.Message)"
    }
}

function Show-WelcomeMessage {
    try {
        $welcomeMsg = [PSCustomObject]@{
            Text = "Welcome! I'm WizKid. Type a message below to start chatting."
            Sender = "System"
        }
        $script:chatMessages.Add($welcomeMsg)
        
        if ([string]::IsNullOrWhiteSpace($script:WizKidApiKey)) {
            $apiMsg = [PSCustomObject]@{
                Text = "No API Key found. Please check your .env file or settings."
                Sender = "System"
            }
            $script:chatMessages.Add($apiMsg)
        }
    } catch {
        Write-Host "Warning: Could not show welcome message: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Show-Window {
    try {
        $script:window.ShowDialog() | Out-Null
    } catch {
        throw "Failed to show window: $($_.Exception.Message)"
    }
}

function Setup-EventHandlers {
    try {
        # Send button
        $script:sendBtn.Add_Click({ Handle-SendClick })
        
        # Screenshot button
        $script:takeScreenshotBtn.Add_Click({ Handle-ScreenshotClick })
        
        # Research button
        $script:researchBtn.Add_Click({ Handle-ResearchClick })
        
        # Chat button
        $script:chatBtn.Add_Click({ Handle-ChatClick })
        
        # Help button
        $script:helpBtn.Add_Click({ Handle-HelpClick })
        
        # Enter key support
        $script:inputTextBox.Add_KeyDown({ 
            param($s, $e)
            if ($e.Key -eq 'Return') {
                Handle-SendClick
                $e.Handled = $true
            }
        })
        
        Write-Host "Event handlers registered successfully" -ForegroundColor Green
    } catch {
        throw "Failed to register event handlers: $($_.Exception.Message)"
    }
}

function Handle-SendClick {
    try {
        $userInput = $script:inputTextBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($userInput)) { return }
        
        $script:inputTextBox.Clear()
        
        # Add user message
        $userMsg = [PSCustomObject]@{
            Text = "You: $userInput"
            Sender = "User"
        }
        $script:chatMessages.Add($userMsg)
        
        # Add thinking message
        $thinkingMsg = [PSCustomObject]@{
            Text = "WizKid is thinking..."
            Sender = "System"
        }
        $script:chatMessages.Add($thinkingMsg)
        
        # Disable UI while processing
        $script:sendBtn.IsEnabled = $false
        $script:inputTextBox.IsEnabled = $false
          # Send to API - check if we're in screenshot mode for follow-up questions
        try {
            if ($script:currentMode -eq "Screenshot" -and $script:lastScreenshotPath) {
                # Send follow-up question about screenshot with vision
                Invoke-ScreenshotAnalysis -ImagePath $script:lastScreenshotPath -Prompt $userInput -ApiKey $script:WizKidApiKey
                $script:chatMessages.Remove($thinkingMsg)
            } else {
                # Regular chat
                $result = Send-GroqMessage -Message $userInput -ApiKey $script:WizKidApiKey
                $script:chatMessages.Remove($thinkingMsg)
                
                if ($result.Success) {
                    $aiMsg = [PSCustomObject]@{
                        Text = "WizKid: $($result.Content)"
                        Sender = "AI"
                    }
                    $script:chatMessages.Add($aiMsg)
                } else {
                    $errorMsg = [PSCustomObject]@{
                        Text = "Error: $($result.Error)"
                        Sender = "System"
                    }
                    $script:chatMessages.Add($errorMsg)
                }
            }
        } catch {
            $script:chatMessages.Remove($thinkingMsg)
            $errorMsg = [PSCustomObject]@{
                Text = "Exception: $($_.Exception.Message)"
                Sender = "System"
            }
            $script:chatMessages.Add($errorMsg)
        } finally {
            # Re-enable UI
            $script:sendBtn.IsEnabled = $true
            $script:inputTextBox.IsEnabled = $true
        }
        
        # Scroll to bottom
        if ($script:chatScrollViewer) {
            $script:chatScrollViewer.ScrollToBottom()
        }
        
    } catch {
        $errorMsg = [PSCustomObject]@{
            Text = "Unexpected error: $($_.Exception.Message)"
            Sender = "System"
        }
        $script:chatMessages.Add($errorMsg)
        $script:sendBtn.IsEnabled = $true
        $script:inputTextBox.IsEnabled = $true
    }
}

function Handle-ScreenshotClick {
    try {
        $statusMsg = [PSCustomObject]@{
            Text = "Taking screenshot..."
            Sender = "System"
        }
        $script:chatMessages.Add($statusMsg)
        
        $script:window.WindowState = [System.Windows.WindowState]::Minimized
        Start-Sleep -Milliseconds 500
        $result = Take-WizKidScreenshot
        $script:window.WindowState = [System.Windows.WindowState]::Normal
        
        $script:chatMessages.Remove($statusMsg)
        
        if ($result.Success) {
            $successMsg = [PSCustomObject]@{
                Text = "Screenshot saved: $($result.Message)"
                Sender = "System"
            }
            $script:chatMessages.Add($successMsg)
            
            # Store screenshot path for vision analysis
            $script:lastScreenshotPath = $result.Path
            
            # Now analyze the screenshot with AI vision
            $analysisMsg = [PSCustomObject]@{
                Text = "WizKid is analyzing your screenshot..."
                Sender = "System"
            }
            $script:chatMessages.Add($analysisMsg)
            
            # Disable UI while analyzing
            $script:sendBtn.IsEnabled = $false
            $script:takeScreenshotBtn.IsEnabled = $false
            
            try {
                # Analyze screenshot with vision model
                Invoke-ScreenshotAnalysis -ImagePath $result.Path -ApiKey $script:WizKidApiKey
            } catch {
                $script:chatMessages.Remove($analysisMsg)
                $errorMsg = [PSCustomObject]@{
                    Text = "Screenshot analysis failed: $($_.Exception.Message)"
                    Sender = "System"
                }
                $script:chatMessages.Add($errorMsg)
            } finally {
                # Re-enable UI
                $script:sendBtn.IsEnabled = $true
                $script:takeScreenshotBtn.IsEnabled = $true
            }
        } else {
            $errorMsg = [PSCustomObject]@{
                Text = "Screenshot failed: $($result.Message)"
                Sender = "System"
            }
            $script:chatMessages.Add($errorMsg)
        }
    } catch {
        $errorMsg = [PSCustomObject]@{
            Text = "Screenshot error: $($_.Exception.Message)"
            Sender = "System"
        }
        $script:chatMessages.Add($errorMsg)
    }
}

function Handle-ResearchClick {
    $msg = [PSCustomObject]@{
        Text = "Research feature coming soon!"
        Sender = "System"
    }
    $script:chatMessages.Add($msg)
}

function Handle-ChatClick {
    $script:currentMode = "Chat"
    $script:lastScreenshotPath = $null
    $msg = [PSCustomObject]@{
        Text = "Switched to Chat mode - normal conversation"
        Sender = "System"
    }
    $script:chatMessages.Add($msg)
}

function Handle-HelpClick {
    $msg = [PSCustomObject]@{
        Text = "WizKid Help: Type messages to chat, click Screenshot to capture your screen, use Research for file analysis."
        Sender = "System"
    }
    $script:chatMessages.Add($msg)
}

# Screenshot analysis using vision model
function Invoke-ScreenshotAnalysis {
    param(
        [string]$ImagePath,
        [string]$Prompt = "Analyze this screenshot in detail. What do you see?",
        [string]$ApiKey
    )
    
    try {
        # Convert image to base64
        $base64Image = Get-ImageBase64 -Path $ImagePath
        
        if (-not $base64Image) {
            $errorMsg = [PSCustomObject]@{
                Text = "Failed to encode screenshot for analysis"
                Sender = "System"
            }
            $script:chatMessages.Add($errorMsg)
            return
        }

        if (-not $ApiKey) {
            $errorMsg = [PSCustomObject]@{
                Text = "API Key is missing for screenshot analysis"
                Sender = "System"
            }
            $script:chatMessages.Add($errorMsg)
            return
        }

        # Use the working Scout vision model
        $model = "meta-llama/llama-4-scout-17b-16e-instruct"
        
        $payload = @{
            model = $model
            messages = @(
                @{
                    role = "user"
                    content = @(
                        @{
                            type = "text"
                            text = $Prompt
                        },
                        @{
                            type = "image_url"
                            image_url = @{
                                url = "data:image/png;base64,$base64Image"
                            }
                        }
                    )
                }
            )
            max_tokens = 1000
            temperature = 0.3
        }
        
        $headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        }
        
        $json = ConvertTo-Json -InputObject $payload -Depth 10
        $response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers $headers -Body $json
        
        $analysis = $response.choices[0].message.content
        
        # Remove the "analyzing" message and add the analysis
        $analyzingMsg = $script:chatMessages | Where-Object { $_.Text -eq "WizKid is analyzing your screenshot..." } | Select-Object -First 1
        if ($analyzingMsg) {
            $script:chatMessages.Remove($analyzingMsg)
        }
        
        $aiMsg = [PSCustomObject]@{
            Text = "WizKid Vision Analysis: $analysis"
            Sender = "AI"
        }
        $script:chatMessages.Add($aiMsg)
        
        # Set mode to screenshot for follow-up questions
        $script:currentMode = "Screenshot"
        
    } catch {
        # Remove the "analyzing" message and add error
        $analyzingMsg = $script:chatMessages | Where-Object { $_.Text -eq "WizKid is analyzing your screenshot..." } | Select-Object -First 1
        if ($analyzingMsg) {
            $script:chatMessages.Remove($analyzingMsg)
        }
        
        $errorMsg = [PSCustomObject]@{
            Text = "Vision analysis failed: $($_.Exception.Message)"
            Sender = "System"
        }
        $script:chatMessages.Add($errorMsg)
    }
}

# Initialize GUI
$guiInit = Initialize-WizKidGui
if (-not $guiInit.Success) {
    Write-Host "GUI initialization failed: $($guiInit.Message)" -ForegroundColor Red
    exit 1
}

# Initialize API Key
$script:WizKidApiKey = Initialize-ApiKey
Write-Host "API Key loaded: $($script:WizKidApiKey.Substring(0,10))..." -ForegroundColor Green

# Start GUI
if ($GUI -or (-not $Console)) {
    Start-WizKidGUI
}
