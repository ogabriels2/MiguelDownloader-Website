<#
.SYNOPSIS
    Sincroniza o site com a release mais recente publicada no GitHub.

.DESCRIPTION
    O pior defeito que um site de download pode ter é anunciar uma versão que não é mais a atual,
    ou pior, uma soma SHA-256 que não corresponde ao arquivo que a pessoa acabou de baixar. Quem
    confere e vê divergência conclui que o arquivo foi adulterado, e está certo em concluir.

    Este script lê a release mais recente, pega tamanho e soma reais de cada arquivo, e reescreve
    os pontos do site que mencionam esses valores: as duas páginas iniciais, os dados estruturados
    e o sitemap.

    Rode depois de publicar cada versão nova, antes de subir o site.

.NOTES
    Precisa do GitHub CLI autenticado (gh auth login).
    Uso:  powershell -File atualizar.ps1
          powershell -File atualizar.ps1 -Tag v1.1.0
#>
[CmdletBinding()]
param(
    [string] $Tag,
    [string] $Repositorio = 'ogabriels2/MiguelDownloader'
)

$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path

function Falhar($mensagem) { Write-Host "  ERRO: $mensagem" -ForegroundColor Red; exit 1 }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Falhar 'O GitHub CLI (gh) não está instalado ou não está no PATH.'
}

if (-not $Tag) {
    $Tag = (gh release view --repo $Repositorio --json tagName --jq '.tagName' 2>$null)
    if (-not $Tag) { Falhar "Não consegui ler a release mais recente de $Repositorio." }
}
$versao = $Tag.TrimStart('v')
Write-Host "Release: $Tag (versão $versao)" -ForegroundColor Cyan

$ativos = gh release view $Tag --repo $Repositorio --json assets,publishedAt | ConvertFrom-Json

# Em UTC, que é o fuso em que o GitHub carimba e mostra a release. Converter para a hora local
# faria a data do site divergir da data da release sempre que a publicação sair de madrugada.
$publicado = ([datetime]$ativos.publishedAt).ToUniversalTime().ToString('yyyy-MM-dd')
$publicadoExtenso = @{
    'pt' = ([datetime]$ativos.publishedAt).ToUniversalTime().ToString('dd', [Globalization.CultureInfo]::InvariantCulture) +
           ' de ' + @('janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro')[([datetime]$ativos.publishedAt).ToUniversalTime().Month - 1] +
           ' de ' + ([datetime]$ativos.publishedAt).ToUniversalTime().Year
    'en' = ([datetime]$ativos.publishedAt).ToUniversalTime().ToString('d MMMM yyyy', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))
}

function Ativo($padrao) {
    $a = $ativos.assets | Where-Object { $_.name -like $padrao } | Select-Object -First 1
    if (-not $a) { Falhar "Nenhum arquivo da release casa com '$padrao'." }
    return $a
}

$setup = Ativo '*Setup.exe'
$portatil = Ativo '*Portable.zip'

# As somas vêm do checksums.txt publicado junto, que é a mesma fonte que a pessoa vai conferir.
$tmp = Join-Path ([IO.Path]::GetTempPath()) "md-checksums-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    gh release download $Tag --repo $Repositorio --pattern checksums.txt --dir $tmp --clobber 2>$null | Out-Null
    $linhas = Get-Content (Join-Path $tmp 'checksums.txt')
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

function Soma($nome) {
    $linha = $linhas | Where-Object { $_ -match [regex]::Escape($nome) } | Select-Object -First 1
    if (-not $linha) { Falhar "checksums.txt não traz uma linha para $nome." }
    return ($linha -split '\s+')[0]
}

$shaSetup = Soma $setup.name
$mbSetup = [math]::Round($setup.size / 1MB, 1)
$mbPortatil = [math]::Round($portatil.size / 1MB, 1)

# Convertidos com a cultura invariante de propósito. Num Windows em português, "$mbSetup" sai
# como 198,6, e a vírgula iria parar na página em inglês e no JSON-LD, onde o separador tem de
# ser ponto. A página escolhe o separador dela mais abaixo.
$mbSetupTexto = $mbSetup.ToString([Globalization.CultureInfo]::InvariantCulture)
$mbPortatilTexto = $mbPortatil.ToString([Globalization.CultureInfo]::InvariantCulture)

Write-Host ("  {0,-42} {1,7:N1} MB  {2}" -f $setup.name, $mbSetup, $shaSetup.Substring(0, 16) + '…')
Write-Host ("  {0,-42} {1,7:N1} MB" -f $portatil.name, $mbPortatil)

# --- reescrita ---------------------------------------------------------------------------------
# Cada substituição é ancorada num padrão específico. Uma troca ampla demais silenciosamente
# estragaria texto que só por acaso parece um número de versão.
$paginas = @(
    @{ Arquivo = Join-Path $aqui 'index.html';    Rotulo = 'index.html';    Decimal = ','; Idioma = 'pt' }
    @{ Arquivo = Join-Path $aqui 'en\index.html'; Rotulo = 'en\index.html'; Decimal = '.'; Idioma = 'en' }
)

foreach ($p in $paginas) {
    if (-not (Test-Path $p.Arquivo)) { Falhar "Não encontrei $($p.Arquivo)." }
    $t = [IO.File]::ReadAllText($p.Arquivo, [Text.UTF8Encoding]::new($false))
    $antes = $t

    $mbS = $mbSetupTexto.Replace('.', $p.Decimal)
    $mbP = $mbPortatilTexto.Replace('.', $p.Decimal)

    $t = [regex]::Replace($t, '(releases/download/)v[\d.]+(/)', "`${1}$Tag`${2}")
    $t = [regex]::Replace($t, '(id="sha">)[0-9a-f]{64}(</code>)', "`${1}$shaSetup`${2}")
    $t = [regex]::Replace($t, '(Portable\.zip">[^<(]*\()[\d.,]+(&nbsp;MB\))', "`${1}$mbP`${2}")

    # Versão e tamanho aparecem duas vezes em cada página: na linha ao lado do botão e na lista
    # de dados do rodapé da seção de download. Ancorados no rótulo, que é o que distingue um
    # campo do outro dentro da mesma lista.
    $t = [regex]::Replace($t, '(<b class="mono">)[\d.]+(</b> · <b class="mono">)[\d.,]+(&nbsp;MB</b>)', "`${1}$versao`${2}$mbS`${3}")
    $t = [regex]::Replace($t, '(<dt>(?:Versão|Version)</dt><dd class="mono">)[\d.]+(</dd>)', "`${1}$versao`${2}")
    $t = [regex]::Replace($t, '(<dt>(?:Tamanho|Size)</dt><dd class="mono">)[\d.,]+(&nbsp;MB</dd>)', "`${1}$mbS`${2}")

    $t = [regex]::Replace($t, '("softwareVersion":\s*")[\d.]+(")', "`${1}$versao`${2}")
    $t = [regex]::Replace($t, '("datePublished":\s*")[\d-]+(")', "`${1}$publicado`${2}")
    $t = [regex]::Replace($t, '("fileSize":\s*")[\d.,]+ MB(")', "`${1}$mbSetupTexto MB`${2}")

    # A data visível e a do atributo datetime andam juntas. Atualizar só uma das duas deixaria a
    # página dizendo uma coisa para a pessoa e outra para quem lê o HTML.
    $t = [regex]::Replace($t, '<time datetime="[\d-]+">[^<]+</time>',
                          "<time datetime=`"$publicado`">$($publicadoExtenso[$p.Idioma])</time>")

    if ($t -eq $antes) {
        Write-Host "  $($p.Rotulo): nada mudou (já estava atualizado)" -ForegroundColor DarkGray
    } else {
        [IO.File]::WriteAllText($p.Arquivo, $t, [Text.UTF8Encoding]::new($false))
        Write-Host "  $($p.Rotulo): atualizado" -ForegroundColor Green
    }
}

# A data das páginas no sitemap acompanha a release.
$sitemap = Join-Path $aqui 'sitemap.xml'
if (Test-Path $sitemap) {
    $t = [IO.File]::ReadAllText($sitemap, [Text.UTF8Encoding]::new($false))
    $t = [regex]::Replace($t, '<lastmod>[\d-]+</lastmod>', "<lastmod>$publicado</lastmod>")
    [IO.File]::WriteAllText($sitemap, $t, [Text.UTF8Encoding]::new($false))
    Write-Host '  sitemap.xml: datas atualizadas' -ForegroundColor Green
}

# --- conferência -------------------------------------------------------------------------------
# Reler o que foi gravado é o que impede este script de dizer "pronto" depois de uma substituição
# que não casou.
$erros = 0
foreach ($p in $paginas) {
    $t = [IO.File]::ReadAllText($p.Arquivo, [Text.UTF8Encoding]::new($false))
    $nome = $p.Rotulo
    $mbS = $mbSetupTexto.Replace('.', $p.Decimal)
    if ($t -notmatch [regex]::Escape($shaSetup)) { Write-Host "  FALHA: a soma não ficou em $nome" -ForegroundColor Red; $erros++ }
    if ($t -notmatch [regex]::Escape("/download/$Tag/")) { Write-Host "  FALHA: o link não aponta para $Tag em $nome" -ForegroundColor Red; $erros++ }
    # Um link certo com uma versão velha ao lado é pior do que um site desatualizado inteiro:
    # parece conferido. Cada lugar que mostra versão ou tamanho é conferido separadamente.
    if (([regex]::Matches($t, '(?<=<b class="mono">)' + [regex]::Escape($versao) + '(?=</b>)')).Count -lt 1) { Write-Host "  FALHA: a versão não ficou na linha do botão em $nome" -ForegroundColor Red; $erros++ }
    if ($t -notmatch ('<dd class="mono">' + [regex]::Escape($versao) + '</dd>')) { Write-Host "  FALHA: a versão não ficou na lista de dados em $nome" -ForegroundColor Red; $erros++ }
    if (([regex]::Matches($t, [regex]::Escape($mbS) + '&nbsp;MB')).Count -lt 2) { Write-Host "  FALHA: o tamanho não ficou nos dois lugares em $nome" -ForegroundColor Red; $erros++ }
    if ($t -notmatch ('"softwareVersion":\s*"' + [regex]::Escape($versao) + '"')) { Write-Host "  FALHA: os dados estruturados ficaram com outra versão em $nome" -ForegroundColor Red; $erros++ }
}

if ($erros -gt 0) { exit 1 }
Write-Host "`nSite sincronizado com $Tag." -ForegroundColor Cyan
