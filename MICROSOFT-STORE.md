# Publicar na Microsoft Store

O que o Partner Center vai pedir, o que já está pronto, o que falta, e dois riscos que valem ser
decididos antes de enviar.

Estado observado no repositório em 29 de agosto de 2026: identidade reservada
(`ogabriels.MiguelDownloader`), publisher `CN=3A079706-B200-4828-AA8B-78BC8F2289C0`, envio em
rascunho, e um workflow `store-package.yml` que gera o MSIX não assinado para envio.

---

## Pronto

**Pacote MSIX.** O workflow constrói e valida, e anexa o pacote como artefato da execução. O
Partner Center assina o pacote com o seu certificado de publisher no momento do envio, então o
MSIX não assinado é exatamente o que se envia.

**Identidade.** `AppxManifest.xml.template` já traz Name, Publisher e PublisherDisplayName iguais
aos do Partner Center. Se divergirem em um caractere, o envio é recusado.

**Capacidades.** `internetClient` e `runFullTrust`. A segunda coloca o app na fila de revisão
manual, o que é normal para aplicativo desktop empacotado e alonga a certificação.

**Imagens do pacote.** `build/store/Assets` tem StoreLogo, Square44, Square71, Square150,
Square310, Wide310x150 e SplashScreen.

**Política de privacidade.** Exigência absoluta: sem uma URL pública, o envio não passa. Use
`https://migueldownloader.ogabriels.com/privacidade.html` ou a versão em inglês, conforme o idioma
principal da listagem. O suporte fica em `https://migueldownloader.ogabriels.com/suporte.html`.

**Política 10.2.9, que proíbe aplicativo que baixa código executável fora do mecanismo da Store.**
Isto já está tratado: `DistributionInfo.UpdatesManagedExternally` retorna verdadeiro quando o
processo tem identidade de pacote, e nesse modo o app não baixa `yt-dlp` nem se auto-atualiza. Vale
demonstrar isso na nota para o revisor.

---

## Falta preparar

**Capturas de tela da listagem.** Mínimo uma, no formato 1366×768 ou 1920×1080. Recomendo três: a
janela com um link analisado, a fila com downloads em andamento, e a tela de configurações.
Para a primeira, `ferramentas\capturar.ps1 -Largura 1366 -Altura 768` já faz o trabalho: no fim
ele imprime o caminho da janela sem moldura, que é o que a Store quer — a sombra desenhada para o
site atrapalha ali.

**Textos da listagem**, por idioma (português e inglês):

- Descrição, até 10.000 caracteres. As seções "O que ele faz / não faz" deste site são um bom
  ponto de partida, e a honestidade sobre limites costuma ajudar na revisão em vez de atrapalhar.
- Até 20 palavras-chave.
- Texto curto promocional, até 200 caracteres.
- Notas da versão.

**Classificação etária.** Você responde um questionário e a IARC gera as classificações. Um
baixador de mídia normalmente cai em "livre", mas responda com cuidado à pergunta sobre acesso a
conteúdo não filtrado da internet, porque o app abre o que o usuário pedir.

**Nota para o revisor.** Explique em uma frase o que o app faz, que os binários de terceiros vão
dentro do pacote e não são baixados, e como testar (colar um link público do YouTube). Revisor sem
contexto reprova por engano.

**Mercados e preço.** Gratuito. Decida se publica no mundo todo ou só no Brasil.

---

## Risco 1 resolvido: perfil LGPL exclusivo da Store

Os termos padrão da Microsoft Store podem entrar em conflito com a GPLv3 usada pelo FFmpeg da
distribuição comum. Por isso, o MSIX não reutiliza essa compilação.

`build/store/tools.lock.json` fixa o arquivo compartilhado
`ffmpeg-master-latest-win64-lgpl-shared.zip` de
[BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases), sob LGPL-3.0-or-later, e
confere o arquivo e cada executável/DLL por SHA-256. O build da Store falha se o próprio FFmpeg não
declarar LGPL ou se aparecer `--enable-gpl` na configuração.

Essa variante não inclui x264/x265. Para as raras conversões exigidas por um contêiner escolhido
manualmente, o app usa `libopenh264` em MP4 e `libvpx-vp9` em WebM. O empacotamento executa um teste
real de codificação H.264 e valida o resultado com o `ffprobe`. Downloads automáticos continuam no
caminho normal de remux sem perda.

---

## Risco 2: a Store já removeu aplicativos que baixam de plataformas de vídeo

A Microsoft aplica políticas de conteúdo que alcançam aplicativos cujo propósito principal seja
baixar de serviços de terceiros, quando isso conflita com os termos desses serviços. Já houve
remoção de baixadores de YouTube da loja.

Não há correção de engenharia para isso. O que ajuda na revisão é o que este produto já faz de
verdade e o site já diz: não contorna DRM, não acessa conteúdo restrito a assinantes, e coloca a
responsabilidade pelo conteúdo em quem usa. Diga isso na nota ao revisor, com as palavras da
licença de uso.

Se a reprovação vier por política de conteúdo, ela não é negociável por recurso técnico, e a
distribuição pelo site continua sendo o caminho.

---

## Ordem sugerida

1. Publicar este site, para ter as URLs de privacidade e suporte.
2. Gerar o MSIX pelo workflow e baixar o artefato.
3. Preencher a listagem, as capturas e a classificação etária.
4. Escrever a nota ao revisor.
5. Enviar.

A certificação de um app com `runFullTrust` costuma levar mais tempo que a de um app puramente
UWP, porque passa por revisão manual.
