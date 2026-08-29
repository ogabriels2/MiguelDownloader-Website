<#
.SYNOPSIS
    Verifica a versão publicável do site antes do GitHub Pages.

.DESCRIPTION
    Falha se houver link local quebrado, domínio canônico antigo, metadado essencial ausente,
    CNAME incorreto ou arquivo público vazio. Não faz requisições externas: o deploy continua
    reproduzível mesmo se um serviço de terceiros estiver indisponível.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$domain = 'https://migueldownloader.ogabriels.com'
$errors = [Collections.Generic.List[string]]::new()

function Add-Error([string] $Message) { $errors.Add($Message) }

$cname = (Get-Content -Raw -LiteralPath (Join-Path $root 'CNAME')).Trim()
if ($cname -ne 'migueldownloader.ogabriels.com') {
    Add-Error "CNAME inesperado: '$cname'."
}

$htmlFiles = @(Get-ChildItem -LiteralPath $root -Filter '*.html' -File)
$htmlFiles += @(Get-ChildItem -LiteralPath (Join-Path $root 'en') -Filter '*.html' -File)

foreach ($file in $htmlFiles) {
    $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
    $text = [IO.File]::ReadAllText($file.FullName)

    if ($text -notmatch '<html\s+lang="[^"]+"') { Add-Error "$relative não declara o idioma." }
    if ($text -notmatch '<title>[^<]+</title>') { Add-Error "$relative não tem título." }
    if ($relative -ne '404.html' -and $text -notmatch '<meta\s+name="description"\s+content="[^"]+"') {
        Add-Error "$relative não tem descrição."
    }
    if ($relative -ne '404.html' -and $text -notmatch ('<link\s+rel="canonical"\s+href="' + [regex]::Escape($domain))) {
        Add-Error "$relative não aponta para o domínio canônico."
    }
    if ($text.Contains('ogabriels2.github.io/MiguelDownloader') -or
        $text -match '(?:href|src)="/MiguelDownloader/') {
        Add-Error "$relative ainda contém o endereço antigo do GitHub Pages."
    }

    $attributes = [regex]::Matches($text, '(?:href|src)="([^"]+)"')
    foreach ($match in $attributes) {
        $value = $match.Groups[1].Value
        if ($value -match '^(?:https?:|mailto:|#|data:)' -or [string]::IsNullOrWhiteSpace($value)) { continue }

        $pathOnly = ($value -split '[?#]', 2)[0]
        if (-not $pathOnly) { continue }

        if ($pathOnly.StartsWith('/')) {
            $candidate = Join-Path $root $pathOnly.TrimStart('/')
        } else {
            $candidate = Join-Path $file.DirectoryName $pathOnly
        }
        $candidate = [IO.Path]::GetFullPath($candidate)

        if ((Test-Path -LiteralPath $candidate -PathType Container)) {
            $candidate = Join-Path $candidate 'index.html'
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            Add-Error "$relative referencia um arquivo inexistente: $value"
        }
    }
}

$requiredPublicFiles = @(
    '.nojekyll', '404.html', 'index.html', 'privacidade.html', 'suporte.html',
    'licenca.html', 'terceiros.html', 'robots.txt', 'sitemap.xml',
    'en/index.html', 'en/privacy.html', 'en/support.html', 'en/licence.html',
    'en/third-party.html', 'assets/site.css', 'assets/icon.svg', 'assets/social.png',
    'assets/social-en.png', 'assets/janela.png', 'assets/janela-en.png'
)
foreach ($relative in $requiredPublicFiles) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Error "Arquivo público ausente: $relative"
    } elseif ($relative -ne '.nojekyll' -and (Get-Item -LiteralPath $path).Length -eq 0) {
        Add-Error "Arquivo público vazio: $relative"
    }
}

try { [void][xml](Get-Content -Raw -LiteralPath (Join-Path $root 'sitemap.xml')) }
catch { Add-Error "sitemap.xml inválido: $($_.Exception.Message)" }

$homePage = Get-Content -Raw -LiteralPath (Join-Path $root 'index.html')
$jsonLd = [regex]::Match($homePage, '<script\s+type="application/ld\+json">\s*(.*?)\s*</script>', 'Singleline')
if (-not $jsonLd.Success) {
    Add-Error 'index.html não contém JSON-LD.'
} else {
    try { [void]($jsonLd.Groups[1].Value | ConvertFrom-Json) }
    catch { Add-Error "JSON-LD inválido: $($_.Exception.Message)" }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    throw "O site tem $($errors.Count) erro(s)."
}

Write-Host "Site verificado: $($htmlFiles.Count) páginas e $($requiredPublicFiles.Count) arquivos públicos." -ForegroundColor Green
