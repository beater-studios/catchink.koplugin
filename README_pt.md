<p align="center">
  <strong>Um registrador de Pokédex no KOReader, feito para e-ink. Em português, inglês e espanhol.</strong>
</p>

<p align="center">
  <a href="#o-que-faz">O que faz</a> ·
  <a href="#instalação">Instalação</a> ·
  <a href="#como-usar">Como usar</a> ·
  <a href="README.md">Read in English</a>
</p>

## O que faz

<table>
  <tr>
    <td width="25%" align="center"><img src="docs/screenshots/box.png" alt="Uma caixa de 30 de Red e Blue, com capturados, vistos e faltando"><br><sub><b>Caixas como nos jogos</b></sub></td>
    <td width="25%" align="center"><img src="docs/screenshots/card.png" alt="A ficha do Bulbasaur com sprite, tipos, descrição e data da captura"><br><sub><b>Uma ficha para cada Pokémon</b></sub></td>
    <td width="25%" align="center"><img src="docs/screenshots/evolution.png" alt="A cadeia evolutiva do Eevee com a condição de cada ramo"><br><sub><b>Evoluções com condições</b></sub></td>
    <td width="25%" align="center"><img src="docs/screenshots/profiles.png" alt="Quatro perfis: normal, shiny, alfa e Living Dex"><br><sub><b>Várias Pokédex ao mesmo tempo</b></sub></td>
  </tr>
</table>

Marque os Pokémon que você pegou em cada jogo, numa tela que fica horas ao lado do console sem reflexo.

- **27 jogos**, de Red / Blue a Legends: Z-A, cada um com a sua Pokédex regional (as três de Kalos juntas; Isle of Armor, Crown Tundra, Teal Mask, Indigo Disk e Mega Dimension embaixo do jogo).
- **Formas em cada jogo:** um perfil que conta formas mostra as que cada jogo tem (Vulpix de Alola em Sun / Moon e Sword / Shield, as letras de Unown em Gold / Silver, as formas de Hisui em Legends: Arceus), nunca as que só existem em batalha.
- **A nacional** junta todos os jogos de um perfil. Capturas sem jogo (no HOME, por exemplo) são marcadas nela.
- **Perfis:** quantas Pokédex você quiser, a partir de um modelo: normal, shiny, alfa (os Legends), Living Dex (formas e gêneros) ou do seu jeito, escolhendo sprites, modo de gênero, formas e jogos.
- **Caixas de 30 e lista:** um toque marca ou desmarca, com desfazer; segurar abre a ficha. O que falta aparece como silhueta. Também dá para marcar visto e indisponível (shiny bloqueado, só de evento), e os indisponíveis saem do total.
- **Filtros e busca:** geração, até dois tipos, capturados, faltando, vistos ou indisponíveis, lendário, mítico, bebê ou com formas, por nome ou número, em ordem de número regional, nacional ou nome.
- **A ficha,** em seis páginas: geral (sprite, categoria, tipos, tamanho, a descrição do jogo, situação, data da captura e nota), status (status base, habilidades, captura e criação, gênero), evolução (a cadeia com cada condição e marcar a linha inteira), formas (normal e shiny), no jogo (onde encontrar e golpes por nível) e no perfil (em quais jogos você já tem).
- **Progresso** por geração e por jogo, com os últimos 7 dias.
- **Sprites:** três pacotes trazem o conjunto base, o base com shiny ou nenhuma sprite; as sprites de cada jogo (ícones de caixa de Sun / Moon em diante) são baixadas no aparelho. Um jogo sem o seu conjunto usa o base e avisa uma vez por visita.
- **Três idiomas:** português, inglês e espanhol. Golpes, habilidades e lugares ficam com os nomes oficiais em inglês na interface em português.
- **Tela de descanso própria:** quando o aparelho dorme com o CatchInk aberto e a tela de descanso do KOReader mostra a capa do livro, aparece a capa do CatchInk no lugar.

## Instalação

1. Baixe um dos três pacotes da [última versão](https://github.com/beater-studios/catchink.koplugin/releases/latest). Eles só mudam nas sprites que vêm dentro:

   | Pacote | Sprites dentro | Tamanho |
   |---|---|---|
   | `catchink.koplugin.zip` (recomendado) | o conjunto base | cerca de 4,2 MB |
   | `catchink.koplugin-shiny.zip` | o conjunto base, normal e shiny | cerca de 6,2 MB |
   | `catchink.koplugin-nosprites.zip` | nenhuma, todos os conjuntos são baixados no aparelho | cerca de 1,9 MB |

2. Descompacte na pasta `plugins` do KOReader, para ficar `koreader/plugins/catchink.koplugin/`.
3. Reinicie o KOReader. O plugin fica em **Ferramentas > CatchInk**.
4. Para usar as sprites de cada jogo, ou os conjuntos que o seu pacote não traz, abra **Sprites** no menu da tela inicial e baixe pelo Wi-Fi.

A soma de verificação de cada pacote está no arquivo `.sha256` dele. Os perfis ficam em `koreader/settings/catchink.lua`, as capturas de cada perfil em `koreader/settings/catchink_profile_<id>.lua` (a versão 0.1.0 as guardava em `koreader/catchink/`, e elas mudam de lugar na primeira abertura) e as sprites em `koreader/catchink/sprites/`. Para desinstalar, apague `koreader/plugins/catchink.koplugin/`, os arquivos `catchink*.lua` de `koreader/settings/` e a pasta `koreader/catchink/`.

## Como usar

1. **Crie um perfil:** escolha um modelo e, se quiser, mude o nome, as sprites (normais ou shiny), o modo de gênero, as formas e os jogos. Um perfil novo pode começar com as capturas de outro.
2. **Abra um jogo** na lista do perfil, ou a Pokédex nacional no alto. Arraste ou use as setas para trocar de caixa.
3. **Toque** num Pokémon para marcar como capturado e toque de novo para desmarcar. O "Desfazer" fica embaixo por alguns segundos.
4. **Segure** para abrir a ficha. Na página geral, marque como não visto, visto, capturado ou indisponível, mude a data da captura e escreva uma nota. Arraste para ir ao próximo.
5. **Filtros, busca e progresso** ficam na barra de baixo. Toque num filtro do alto para tirar.
6. **Sprites:** o botão de imagem no alto de um jogo escolhe o conjunto dele. A tela Sprites baixa, continua e apaga conjuntos. Os downloads correm com o plugin aberto, e o aparelho fica acordado enquanto isso.

## Créditos e licença

Dados: [PokeAPI](https://pokeapi.co/), [PKHeX](https://github.com/kwsch/PKHeX) para os encontros dos jogos mais novos e as formas de cada jogo, e [Serebii.net](https://www.serebii.net/pokearth/sinnoh/) para as chances de encontro de Brilliant Diamond e Shining Pearl. Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites) (o conjunto base vem no plugin, os outros são baixados no seu aparelho); as imagens são © The Pokémon Company. Textos em português traduzidos pela Beater Studios.

O CatchInk é um projeto não oficial, feito por fãs. Não é afiliado, endossado nem patrocinado pela Nintendo, Game Freak, Creatures Inc. ou The Pokémon Company. Pokémon e os nomes relacionados são marcas dos seus donos.

GPL-3.0-only. Veja [LICENSE](LICENSE) e [NOTICE](NOTICE).
