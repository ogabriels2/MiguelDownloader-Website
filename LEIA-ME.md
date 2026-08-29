# Site do Miguel Downloader

Página de produto e download, mais os documentos que a distribuição exige. Bilíngue, estática, sem
build: são arquivos HTML que funcionam abrindo direto no navegador.

```
index.html            página inicial (pt-BR)
privacidade.html      política de privacidade  ← exigida pela Microsoft Store
licenca.html          licença de uso
terceiros.html        componentes de terceiros e oferta de código-fonte da GPL
404.html              página de erro, bilíngue
en/                   as mesmas quatro páginas em inglês
atualizar.ps1         sincroniza versão, tamanho e SHA-256 com a release mais recente
robots.txt sitemap.xml .nojekyll

ferramentas/          scripts que geram as imagens; não vão para o ar
  capturar.ps1        refaz a captura da janela num idioma e a emoldura
  emoldurar.ps1       canto arredondado e sombra, usado pelo capturar.ps1
  social.ps1          gera o cartão de compartilhamento de cada idioma

assets/site.css       o sistema visual inteiro; não há outro CSS
assets/janela.png     a janela do programa em português, com sombra (1580×994)
assets/janela-en.png  a mesma janela em inglês
assets/social.png     imagem de compartilhamento em português (1200×630)
assets/social-en.png  imagem de compartilhamento em inglês
assets/icon.svg       favicon
assets/icon-180.png   ícone de iOS
```

O CSS trabalha com dois fundos: o escuro (`--stage`), onde o produto aparece, e o claro
(`--paper`), onde se lê. As seções alternam entre eles. Bordas quase não existem: o que separa uma
coisa da outra é espaço.

## Publicar

O site vive num repositório público separado do aplicativo. Assim, mudanças de conteúdo e domínio
não criam uma nova versão do executável, e o repositório do programa continua concentrado em código,
pacotes e releases.

O workflow `.github/workflows/pages.yml` verifica os links e os metadados, monta somente os arquivos
públicos e publica pelo GitHub Pages. `LEIA-ME.md`, `MICROSOFT-STORE.md`, `atualizar.ps1` e a pasta
`ferramentas/` ficam no repositório, mas nunca entram no site servido.

Antes de enviar uma mudança:

```powershell
pwsh ferramentas/verificar.ps1
```

Cada push na branch `main` publica automaticamente. A origem do GitHub Pages deve permanecer como
**GitHub Actions**.

## Apontar o seu subdomínio

1. O domínio canônico é `migueldownloader.ogabriels.com`, gravado no arquivo `CNAME`.
2. Na Cloudflare, o registro `CNAME` de `migueldownloader` aponta para `ogabriels2.github.io` e
   fica inicialmente como **somente DNS** durante a emissão do certificado.
3. Em **Settings › Pages**, o domínio personalizado deve ser o mesmo e **Enforce HTTPS** deve ficar
   ativo assim que o certificado for emitido.
4. A conta do GitHub deve verificar `ogabriels.com` com o registro TXT de desafio exibido em
   **Settings › Pages**. Isso impede que outro repositório da plataforma reivindique o subdomínio.

Os endereços canônicos, o sitemap e o `404.html` já usam o domínio próprio. O verificador falha se
o endereço antigo voltar por engano.

## A cada versão nova do programa

```powershell
powershell -File atualizar.ps1
```

Lê a release mais recente pelo GitHub CLI e reescreve, nas duas páginas iniciais: o link do
instalador, a versão, o tamanho, a data (visível e no atributo `datetime`), o SHA-256 e os dados
estruturados. No fim relê os arquivos e confere que a soma e a tag ficaram lá; se não ficaram, ele
falha em vez de dizer que deu certo.

Um site de download que anuncia um SHA-256 velho é pior do que um que não anuncia nenhum: quem
confere encontra divergência e conclui, com razão, que o arquivo foi adulterado.

Para forçar uma versão específica: `powershell -File atualizar.ps1 -Tag v1.1.0`.

## Trocar a captura de tela

`janela.png` e `janela-en.png` são capturas reais da janela, uma em cada idioma, com o mesmo link
já analisado, recortadas com canto arredondado e sombra. Manter uma captura que não corresponde ao
que a pessoa baixa contradiz a única coisa que esta página promete, então refaça as duas sempre que
a interface mudar de forma visível.

```powershell
powershell -File ferramentas\capturar.ps1 -Idioma pt
powershell -File ferramentas\capturar.ps1 -Idioma en
```

O script abre o programa, deixa a janela em 1360×760, cola
`https://www.youtube.com/watch?v=aqz-KE-bpKQ`, espera a análise terminar e fotografa a janela com
`PrintWindow` — a tecla Print Screen traria junto a sombra do Windows, que depois brigaria com a
sombra desenhada aqui. Para o inglês ele troca `"Language"` em
`%APPDATA%\MiguelDownloader\settings.json` e **devolve o valor original no fim**, mesmo se algo
falhar no meio. Depois chama `ferramentas\emoldurar.ps1`: 110 px de folga nas laterais, 44 em cima,
190 embaixo, canto de 14 px, sombra desenhada por distância (empilhar camadas deixa degraus
visíveis) e um fio de luz branca a 25% na borda. O fundo sai transparente, para assentar no escuro
da página.

**Confira qual cópia do programa o script vai abrir.** Por padrão é a instalada, em
`%LOCALAPPDATA%\Programs\MiguelDownloader`, que é o certo: a captura tem de mostrar o que a pessoa
recebe. Só que uma instalação velha gera uma captura velha, e ela vira uma promessa falsa na página.
Instale a versão publicada antes de capturar, ou passe o caminho de outra compilação em `-Exe`.

As duas imagens precisam sair do mesmo tamanho de janela: se uma ficar mais alta que a outra, o
topo da página muda de altura quando a pessoa troca de idioma.

## Manutenção da identidade

A marca no cabeçalho é SVG escrito à mão nas páginas, com a mesma geometria do ícone do programa
(grade de 1024, seta em `458,250` e prateleira em `300,826`). Se o ícone mudar, ajuste os dois —
e também o desenho da marca dentro de `ferramentas/social.ps1`, que redesenha o mesmo ícone em GDI+.

O dourado do site vem do ícone, não da interface. O ícone é um degradê de `#FFDE7A` a `#E0950A`;
`--brass-lit` (`#f2b736`) é esse degradê achatado num tom só, que é o que a marca no cabeçalho
precisa. O acento da interface (`ThemeService.Accent`, `#E8A317`) é um pouco mais fechado, e
aparece nas capturas de tela. Os dois convivem bem porque saíram do mesmo lugar; se você mexer num,
olhe o outro.

Sobre o fundo claro, `#f2b736` não tem contraste para texto. Por isso existe `--brass` (`#90610a`),
o mesmo tom rebaixado até passar em 4,5:1. A regra do arquivo é essa: dourado claro só no escuro,
dourado fechado só no claro.

`social.png` e `social-en.png` (1200×630) são o que aparece quando alguém compartilha o link, cada
uma na língua da página que a referencia.
