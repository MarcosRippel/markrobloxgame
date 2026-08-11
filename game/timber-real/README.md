# Desmatamento

**Nome comercial: Desmatamento** (a pasta/slug interno segue `timber-real`).
Protótipo Roblox (Rojo + Luau) de um jogo de derrubada de árvore onde **a
árvore é um sólido de verdade que se desfaz exatamente onde você corta**.

Este diretório contém, por enquanto, apenas o **spike M0** — o experimento que
decide se a mecânica é viável na plataforma.

## A ideia

O tronco não tem barra de vida. Ele tem **geometria**. O movimento da ferramenta
vira um sólido, esse sólido é subtraído do tronco, e o impacto estilhaça a
madeira em volta do ponto de contato. Cada ferramenta muda a **forma** do corte:

| Ferramenta | Corte | Resíduo |
|---|---|---|
| Facão | sweep fino e raso, oblíquo | muitas lascas pequenas |
| Machado | cunha em V, entalhe fundo | lascas grandes |
| Serra manual | kerf reto e fino, avanço lento | serragem |
| Motosserra | kerf largo, avanço rápido | jato de serragem + estilhaço |

No M0 só o **machado** está ligado.

## A pergunta que o M0 responde

A mecânica depende de quatro APIs do `GeometryService`:

| API | Papel |
|---|---|
| `SweepPartAsync` | o movimento da lâmina vira um sólido de corte |
| `SubtractAsync` | esse sólido é removido do tronco |
| `GenerateFragmentSites` | sites voronoi no ponto de impacto |
| `FragmentAsync` | estilhaça a madeira em pedaços de forma natural |

Elas estão atrás do beta de Studio **"Solid Modeling On Meshes"**. A pergunta do
spike é se funcionam numa experience **publicada**, para um jogador comum.

- **Funcionam** → Plano A: corte de geometria real.
- **Não funcionam** → Plano B: tronco pré-segmentado com estados de dano, atrás
  da mesma interface `CortadorServidor.cortar`.

## Rodar

```powershell
rojo serve default.project.json
```

No Studio: **File ⟩ Beta Features ⟩ Solid Modeling On Meshes** (ligar e
reiniciar), abrir um baseplate novo, plugin Rojo → **Connect**.

O `BootServidor` monta a clareira sozinho — 3 troncos, chão e HUD. Nada precisa
ser construído à mão. Clique num tronco ou tecle `F`.

O painel no canto superior esquerdo dá o veredito (`PLANO A VIVE` / `PARCIAL` /
`PLANO B`), a latência de cada operação, golpes descartados pela fila, cacos no
chão e FPS. O título mostra `STUDIO` ou `PUBLICADO`.

## Estrutura

```
src/
  ReplicatedStorage/
    Net.lua                    remotes num lugar só
    ConfiguracaoTimber.lua     todo número tunável
  ServerScriptService/
    BootServidor.server.lua    monta a clareira e liga a rede
    Server/
      CortadorServidor.lua     a fachada do corte (sweep → subtract → fragment)
      FilaGeometria.lua        teto de operações async concorrentes
      DetritoServidor.lua      cacos, orçamento e varrição
      DiagnosticoServidor.lua  o veredito do M0
  StarterPlayer/StarterPlayerScripts/
    GestoCliente.client.lua    grava o arco do golpe e manda pro servidor
    HUDCliente.client.lua      painel de medição
  StarterPack/Machado/         Tool sem handle
```

## Notas de engenharia

- **Corte é server-authoritative.** O cliente descreve o gesto; o servidor
  resolve a geometria. CSG no cliente não replica pro servidor.
- **Operações de geometria são caras e assíncronas.** `FilaGeometria` limita a
  2 concorrentes e descarta golpe redundante — sem isso, uma motosserra segurada
  vira dezenas de subtracts por segundo.
- **Fragmentos precisam de coleta.** `DetritoServidor` limita a 8 por golpe e
  120 vivos, com `Debris` de 25s.
- **Meshes precisam ser watertight** para as operações funcionarem. O M0 usa um
  `Part` cilindro (watertight por natureza), então **não** testa esse problema —
  isso é teste separado, com mesh de árvore real.

## Limites do spike

Sem economia, sem queda do tronco, sem rebrote, sem loja. Validação de alcance e
cadência, mas sem anti-cheat sério. Tudo isso vem depois do veredito.

---

Código de criação (design, economia, pipeline de assets) é fechado.
