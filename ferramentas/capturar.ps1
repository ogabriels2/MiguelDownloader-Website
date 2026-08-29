<#
.SYNOPSIS
    Refaz a captura da janela do programa, num idioma, e a emoldura para a página.

.DESCRIPTION
    Abre o programa, cola o mesmo link de sempre, espera a análise terminar e fotografa a
    janela com PrintWindow. Depois chama emoldurar.ps1, que recorta os cantos e desenha a
    sombra. O resultado vai direto para assets\.

    Para o inglês, o script troca o idioma em settings.json e devolve o valor original no
    fim, inclusive se algo falhar no meio. É a configuração do seu programa: não a deixe
    trocada.

    Uso:  powershell -File ferramentas\capturar.ps1 -Idioma pt
          powershell -File ferramentas\capturar.ps1 -Idioma en
#>
param(
    [ValidateSet('pt','en')] [string] $Idioma = 'pt',
    [string] $Exe,
    [string] $Url = 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    [int] $Largura = 1360,
    [int] $Altura = 760
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@ -Language CSharp

$raiz = Split-Path $PSScriptRoot -Parent
if (-not $Exe) {
    $Exe = Join-Path $env:LOCALAPPDATA 'Programs\MiguelDownloader\MiguelDownloader.exe'
}
if (-not (Test-Path $Exe)) {
    throw "Não achei o programa em $Exe. Passe o caminho em -Exe."
}

$botao = @{ pt = 'Analisar'; en = 'Analyze' }[$Idioma]
$saida = @{ pt = 'janela.png'; en = 'janela-en.png' }[$Idioma]
$codigo = @{ pt = 'pt-BR'; en = 'en' }[$Idioma]

$cfg = Join-Path $env:APPDATA 'MiguelDownloader\settings.json'
$bak = Join-Path $env:TEMP ('settings-antes-captura-' + [guid]::NewGuid().ToString('N') + '.json')
$mexeu = $false
if (Test-Path $cfg) {
    Copy-Item $cfg $bak -Force
    $mexeu = $true
}

try {
    if ($mexeu) {
        $t = [IO.File]::ReadAllText($cfg, [Text.UTF8Encoding]::new($false))
        $novo = [regex]::Replace($t, '("Language"\s*:\s*)"[^"]*"', '${1}"' + $codigo + '"')
        if ($novo -eq $t -and $t -notmatch '"Language"') { throw 'não encontrei o campo Language em settings.json' }
        [IO.File]::WriteAllText($cfg, $novo, [Text.UTF8Encoding]::new($false))
    }

    Get-Process MiguelDownloader -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 2
    Start-Process $Exe | Out-Null
    Start-Sleep 4
    $p = Get-Process MiguelDownloader | Select-Object -First 1
    for ($i = 0; $i -lt 80; $i++) { Start-Sleep -Milliseconds 500; $p.Refresh(); if ($p.MainWindowHandle -ne 0) { break } }
    $h = $p.MainWindowHandle
    if (-not $h -or $h -eq [IntPtr]::Zero) { throw 'a janela do programa não apareceu' }
    $root = [Windows.Automation.AutomationElement]::FromHandle($h)
    Start-Sleep 8
    [Win]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, $Largura, $Altura, 0x0004) | Out-Null
    Start-Sleep 2

    function Achar($prop, $valor, $segundos) {
        $c = New-Object Windows.Automation.PropertyCondition($prop, $valor)
        for ($t = 0; $t -lt $segundos * 2; $t++) {
            $e = $root.FindFirst([Windows.Automation.TreeScope]::Descendants, $c)
            if ($e) { return $e }
            Start-Sleep -Milliseconds 500
        }
        return $null
    }

    $box = Achar ([Windows.Automation.AutomationElement]::AutomationIdProperty) 'UrlBox' 20
    if (-not $box) { throw 'não achei a caixa de endereço' }
    $box.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern).SetValue($Url)
    Start-Sleep 2

    $b = Achar ([Windows.Automation.AutomationElement]::NameProperty) $botao 15
    if (-not $b) { throw "não achei o botão '$botao' — a interface não está em $Idioma?" }
    $b.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
    Start-Sleep 40

    $r = New-Object Win+RECT; [Win]::GetWindowRect($h, [ref] $r) | Out-Null
    $bmp = New-Object Drawing.Bitmap(($r.R - $r.L), ($r.B - $r.T))
    $g = [Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
    [Win]::PrintWindow($h, $dc, 2) | Out-Null
    $g.ReleaseHdc($dc); $g.Dispose()
    $cru = Join-Path $env:TEMP ('janela-crua-' + $Idioma + '.png')
    $bmp.Save($cru, [Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("capturado: {0}x{1}" -f $bmp.Width, $bmp.Height)
    $bmp.Dispose()

    $p.CloseMainWindow() | Out-Null
    if (-not $p.WaitForExit(25000)) { $p.Kill() }
    Start-Sleep 2

    & (Join-Path $PSScriptRoot 'emoldurar.ps1') -Entrada $cru -Saida (Join-Path $raiz "assets\$saida")

    # A captura sem moldura fica guardada: é dela que saem as imagens da listagem da
    # Microsoft Store, que pede a janela crua, sem sombra desenhada em volta.
    Write-Host "janela sem moldura: $cru"
}
finally {
    Get-Process MiguelDownloader -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep 1
    if ($mexeu) {
        Copy-Item $bak $cfg -Force
        Remove-Item $bak -Force -ErrorAction SilentlyContinue
        Write-Host 'settings.json devolvido ao estado anterior' -ForegroundColor Green
    }
}
