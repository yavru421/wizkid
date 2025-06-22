# WizKid PowerShell Edition - Screenshot Utilities

function Take-WizKidScreenshot {
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [int]$DelayMs = 500
    )
    
    try {
        Start-Sleep -Milliseconds $DelayMs
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $assetsDir = Join-Path $PSScriptRoot "..\assets"
            if (-not (Test-Path $assetsDir)) {
                New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
            }
            $OutputPath = Join-Path $assetsDir "screenshot_$timestamp.png"
        }
        
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()
        
        return @{
            Success = $true
            Path = $OutputPath
            Message = "Screenshot saved to: $OutputPath"
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Message = "Failed to take screenshot: $($_.Exception.Message)"
        }
    }
}

function Get-ScreenInfo {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    return @{
        Width = $screen.Bounds.Width
        Height = $screen.Bounds.Height
        WorkingArea = $screen.WorkingArea
        DeviceName = $screen.DeviceName
        Primary = $screen.Primary
    }
}

Export-ModuleMember -Function Take-WizKidScreenshot, Get-ScreenInfo