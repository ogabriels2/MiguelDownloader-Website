<#
.SYNOPSIS
    Gera a imagem de compartilhamento (Open Graph) de uma das duas páginas iniciais.

.DESCRIPTION
    É o cartão que aparece quando alguém cola o link no WhatsApp, no Slack ou no X. Repete o
    fundo escuro, a marca e a frase da página, para quem clica não estranhar o que encontra.

    Uso:  powershell -File ferramentas\social.ps1 -Idioma pt
          powershell -File ferramentas\social.ps1 -Idioma en
#>
param([ValidateSet('pt','en')] [string] $Idioma = 'pt')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$texto = @{
    pt = @{
        L1 = 'Cole um link.'; L2 = 'Receba o arquivo.'; Cauda = 'arquivo.'
        Lead1 = 'Baixador de vídeo e música para Windows.'
        Lead2 = 'Mostra só os formatos que a fonte publica de verdade.'
        Saida = 'social.png'
    }
    en = @{
        L1 = 'Paste a link.'; L2 = 'Get the file.'; Cauda = 'file.'
        Lead1 = 'A video and music downloader for Windows.'
        Lead2 = 'It offers only the formats the source actually publishes.'
        Saida = 'social-en.png'
    }
}[$Idioma]

$W = 1200; $H = 630
$stage    = [Drawing.Color]::FromArgb(20,18,15)
$tile     = [Drawing.Color]::FromArgb(36,29,18)
$bone     = [Drawing.Color]::FromArgb(240,236,227)
$boneSoft = [Drawing.Color]::FromArgb(164,156,142)
$brass    = [Drawing.Color]::FromArgb(242,183,54)

$bmp = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'ClearTypeGridFit'
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear($stage)

# The page's single bloom, painted per pixel on a small bitmap and scaled up.
# Concentric rings band badly at this size; interpolation does not.
$bw = 200; $bh = 120
$glow = New-Object Drawing.Bitmap $bw, $bh, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
for ($y = 0; $y -lt $bh; $y++) {
    for ($x = 0; $x -lt $bw; $x++) {
        $dx = ($x - ($bw - 1) / 2.0) / (($bw - 1) / 2.0)
        $dy = ($y - ($bh - 1) / 2.0) / (($bh - 1) / 2.0)
        $d = [math]::Sqrt($dx * $dx + $dy * $dy)
        if ($d -ge 1) { continue }
        $a = [int][math]::Round(40 * (1 - $d) * (1 - $d))
        if ($a -le 0) { continue }
        $glow.SetPixel($x, $y, [Drawing.Color]::FromArgb($a, 242, 183, 54))
    }
}
$g.DrawImage($glow, 240, 210, 1180, 640)
$glow.Dispose()

function RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# --- wordmark -------------------------------------------------------------
$mx = 100.0; $my = 96.0; $ms = 46.0
$tilePath = RoundRect $mx $my $ms $ms ($ms * 0.18)
$tb = New-Object Drawing.SolidBrush $tile
$g.FillPath($tb, $tilePath); $tb.Dispose(); $tilePath.Dispose()

$gb = New-Object Drawing.SolidBrush $brass
$u = $ms / 1024.0
$g.FillRectangle($gb, [single]($mx + 458*$u), [single]($my + 250*$u), [single](108*$u), [single](300*$u))
$tri = @(
  (New-Object Drawing.PointF ([single]($mx + 316*$u), [single]($my + 520*$u))),
  (New-Object Drawing.PointF ([single]($mx + 708*$u), [single]($my + 520*$u))),
  (New-Object Drawing.PointF ([single]($mx + 512*$u), [single]($my + 742*$u)))
)
$g.FillPolygon($gb, $tri)
$barPath = RoundRect ([single]($mx + 300*$u)) ([single]($my + 826*$u)) ([single](424*$u)) ([single](76*$u)) ([single](38*$u))
$g.FillPath($gb, $barPath); $barPath.Dispose()

$boneBrush = New-Object Drawing.SolidBrush $bone
$softBrush = New-Object Drawing.SolidBrush $boneSoft
$fmt = [Drawing.StringFormat]::GenericTypographic

$fMark = New-Object Drawing.Font 'Segoe UI', 25, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$g.DrawString('Miguel Downloader', $fMark, $boneBrush, [single]($mx + $ms + 16), [single]($my + 10), $fmt)

# --- headline -------------------------------------------------------------
$fHead = New-Object Drawing.Font 'Segoe UI', 82, ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
$x0 = 100.0; $y0 = 286.0; $lh = 96.0
$g.DrawString($texto.L1, $fHead, $boneBrush, [single]$x0, [single]$y0, $fmt)

# Medida como o todo menos o fim: GenericTypographic descarta o espaço final, então medir
# "Receba o " direto joga a palavra dourada por cima da última letra.
$wAll = $g.MeasureString($texto.L2, $fHead, [Drawing.PointF]::Empty, $fmt).Width
$wTail = $g.MeasureString($texto.Cauda, $fHead, [Drawing.PointF]::Empty, $fmt).Width
$cabeca = $texto.L2.Substring(0, $texto.L2.Length - $texto.Cauda.Length).TrimEnd()
$g.DrawString($cabeca, $fHead, $boneBrush, [single]$x0, [single]($y0 + $lh), $fmt)
$g.DrawString($texto.Cauda, $fHead, $gb, [single]($x0 + $wAll - $wTail), [single]($y0 + $lh), $fmt)

# --- lead -----------------------------------------------------------------
$fLead = New-Object Drawing.Font 'Segoe UI', 28, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$g.DrawString($texto.Lead1, $fLead, $softBrush, [single]$x0, [single]($y0 + $lh * 2 + 30), $fmt)
$g.DrawString($texto.Lead2, $fLead, $softBrush, [single]$x0, [single]($y0 + $lh * 2 + 70), $fmt)

$g.Dispose()
$out = Join-Path (Split-Path $PSScriptRoot -Parent) ('assets\' + $texto.Saida)
$bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host ("{0} ({1}x{2})" -f $texto.Saida, $W, $H)
