# WizKid PowerShell Edition - Image Utilities

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

Export-ModuleMember -Function Get-ImageBase64
