# Desky - Interactive Quality & Testing Runner

function Show-Header {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "              Desky - Interactive Test & Dev Suite               " -ForegroundColor Yellow
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Run-Tests {
    Show-Header
    Write-Host "[1] Executando suite completa de testes e analise de codigo..." -ForegroundColor Cyan
    Write-Host ""
    & "$PSScriptRoot\run_all_tests.ps1"
    Write-Host ""
    Write-Host "Pressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
    [void][System.Console]::ReadKey($true)
}

function Start-DesktopApp {
    Show-Header
    Write-Host "[2] Iniciando Desky Desktop (Windows)..." -ForegroundColor Cyan
    Write-Host ""
    Push-Location "$PSScriptRoot\.."
    try {
        flutter run -d windows
    } finally {
        Pop-Location
    }
    Write-Host ""
    Write-Host "Pressione qualquer tecla para voltar ao menu..." -ForegroundColor Gray
    [void][System.Console]::ReadKey($true)
}

do {
    Show-Header
    Write-Host "Escolha uma opcao:" -ForegroundColor White
    Write-Host "  [1] Executar suite de testes e analise estatica" -ForegroundColor Cyan
    Write-Host "  [2] Executar Desky Desktop no Windows (flutter run)" -ForegroundColor Magenta
    Write-Host "  [0] Sair" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Opcao: " -ForegroundColor Yellow -NoNewline
    $choice = Read-Host

    switch ($choice) {
        '1' { Run-Tests }
        '2' { Start-DesktopApp }
        '0' { break }
        default {
            Write-Host "Opcao invalida. Tente novamente." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne '0')

Show-Header
Write-Host "Obrigado por usar o Desky!" -ForegroundColor Cyan
