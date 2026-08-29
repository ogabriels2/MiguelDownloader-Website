param([string] $Entrada, [string] $Saida)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$padX = 110; $padT = 44; $padB = 190; $raio = 14.0

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

# Distância assinada até um retângulo de cantos arredondados. Serve para desenhar a
# sombra como um degradê contínuo: empilhar retângulos opacos deixa degraus visíveis.
function DistRR([double]$px, [double]$py, [double]$cx, [double]$cy, [double]$bx, [double]$by, [double]$r) {
    $qx = [math]::Abs($px - $cx) - $bx + $r
    $qy = [math]::Abs($py - $cy) - $by + $r
    $mx = [math]::Max($qx, 0.0); $my = [math]::Max($qy, 0.0)
    return [math]::Sqrt($mx * $mx + $my * $my) + [math]::Min([math]::Max($qx, $qy), 0.0) - $r
}

$src = [Drawing.Bitmap]::FromFile($Entrada)
$W = $src.Width + $padX * 2
$H = $src.Height + $padT + $padB

$out = New-Object Drawing.Bitmap $W, $H, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($out)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'

# --- sombra ---------------------------------------------------------------
# Desenhada em escala reduzida e ampliada de volta: a interpolação é o borrão.
$s = 4
$sw = [int][math]::Ceiling($W / $s); $sh = [int][math]::Ceiling($H / $s)
$sombra = New-Object Drawing.Bitmap $sw, $sh, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)

$cx = ($padX + $src.Width / 2.0) / $s
$bx = ($src.Width / 2.0) / $s
$by = ($src.Height / 2.0) / $s
$rr = $raio / $s

# Duas sombras: uma larga e difusa, que é a luz da sala, e uma curta logo abaixo da
# janela, que é o contato com a superfície. Só a larga já deixa o objeto flutuando.
$camadas = @(
    @{ dy = 46.0; alcance = 96.0; forca = 74.0 },
    @{ dy = 12.0; alcance = 26.0; forca = 62.0 }
)

for ($y = 0; $y -lt $sh; $y++) {
    $py = $y + 0.5
    for ($x = 0; $x -lt $sw; $x++) {
        $px = $x + 0.5
        $acc = 0.0
        foreach ($c in $camadas) {
            $cy = ($padT + $src.Height / 2.0 + $c.dy) / $s
            $d = DistRR $px $py $cx $cy $bx $by $rr
            if ($d -le 0) { $a = $c.forca }
            else {
                $t = 1.0 - $d / ($c.alcance / $s)
                if ($t -le 0) { continue }
                $a = $c.forca * $t * $t
            }
            $acc = $acc + $a - ($acc * $a / 255.0)
        }
        $ai = [int][math]::Round($acc)
        if ($ai -le 0) { continue }
        if ($ai -gt 255) { $ai = 255 }
        $sombra.SetPixel($x, $y, [Drawing.Color]::FromArgb($ai, 0, 0, 0))
    }
}
$g.DrawImage($sombra, 0, 0, $W, $H)
$sombra.Dispose()

# --- a janela -------------------------------------------------------------
# Com os cantos arredondados que o Windows 11 desenha e o PrintWindow não captura.
$janela = RoundRect ([single]$padX) ([single]$padT) ([single]$src.Width) ([single]$src.Height) ([single]$raio)
$g.SetClip($janela)
$g.DrawImage($src, $padX, $padT, $src.Width, $src.Height)
$g.ResetClip()

# Um fio de luz na borda, como a que a tela de um monitor pega da sala.
$caneta = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(64, 255, 255, 255)), 1.4
$g.DrawPath($caneta, $janela)
$caneta.Dispose(); $janela.Dispose()

$g.Dispose()
$out.Save($Saida, [Drawing.Imaging.ImageFormat]::Png)
Write-Host ("{0} ({1}x{2})" -f (Split-Path $Saida -Leaf), $out.Width, $out.Height)
$out.Dispose(); $src.Dispose()
