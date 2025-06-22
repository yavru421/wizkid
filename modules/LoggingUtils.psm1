# WizKid PowerShell Edition - Logging Utilities

# Initialize log path
$script:LogPath = Join-Path $PSScriptRoot "..\application.log"

function Write-SessionLog {
    [CmdletBinding()]
    param(
        [string]$Type,
        [string]$Content
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $entry = "[$timestamp][$Type][WizKid] $Content"
        Add-Content -Path $script:LogPath -Value $entry -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging doesn't work
    }
}

function Get-LogPath {
    return $script:LogPath
}

function Set-LogPath {
    [CmdletBinding()]
    param([string]$Path)
    $script:LogPath = $Path
}

function Clear-SessionLog {
    [CmdletBinding()]
    param()
    
    try {
        if (Test-Path $script:LogPath) {
            Clear-Content -Path $script:LogPath
            Write-SessionLog -Type "INFO" -Content "Log file cleared"
        }
    }
    catch {
        Write-Host "Failed to clear log: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Write-SessionLog, Get-LogPath, Set-LogPath, Clear-SessionLog
