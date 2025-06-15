# WizKid PowerShell Edition - UI Utilities

function Show-WizKidHeader {
    Clear-Host
    $wizKidBanner = @"
$___       __   ___  ________  ___  __    ___  ________     
|\  \     |\  \|\  \|\_____  \|\  \|\  \ |\  \|\   ___ \    
\ \  \    \ \  \ \  \\|___/  /\ \  \/  /|\ \  \ \  \_|\ \   
$\ \  \  __\ \  \ \  \   /  / /\ \   ___  \ \  \ \  \ \\ \  
$ \ \  \|\__\_\  \ \  \ /  /_/__\ \  \\ \  \ \  \ \  \_\\ \ 
$  \ \____________\ \__\\________\ \__\\ \__\ \__\ \_______\
    \|____________|\|__|\|_______|\|__| \|__|\|__|\|_______|
                                                            
                                                            
                                                            
"@
    Write-Host $wizKidBanner -ForegroundColor Magenta
}

function Write-BoxedText($lines, $color = "Cyan", $emoji = $null) {
    if (-not $lines -or $lines.Count -eq 0) { return }
    $maxLen = ($lines | Measure-Object -Maximum Length).Maximum
    $top = "┏" + ("━" * ($maxLen + 2)) + "┓"
    $bottom = "┗" + ("━" * ($maxLen + 2)) + "┛"
    Write-Host ""
    Write-Host $top -ForegroundColor $color
    foreach ($line in $lines) {
        $pad = " " * ($maxLen - $line.Length)
        $prefix = if ($emoji) { "$emoji " } else { "  " }
        Write-Host ("┃ $prefix$line$pad ┃") -ForegroundColor $color
    }
    Write-Host $bottom -ForegroundColor $color
    Write-Host ""
}
