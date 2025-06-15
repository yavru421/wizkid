# WizKid PowerShell Edition - Logging Utilities

function Write-SessionLog {
    param($Type, $Content)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp][$Type] $Content"
    Add-Content -Path $LogPath -Value $entry
}
