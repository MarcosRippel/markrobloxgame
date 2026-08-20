# Desmatamento

**Nome comercial: Desmatamento** (a pasta/slug interno segue `timber-real`).
Protótipo Roblox (Rojo + Luau) de um jogo de derrubada de árvore onde **a
árvore é um sólido de verdade que se desfaz exatamente onde você corta**.

## A ideia

O tronco não tem barra de vida. Ele tem **geometria**. O movimento da ferramenta
vira um sólido, esse sólido é subtraído do tronco, e o impacto estilhaça a
madeira em volta do ponto de contato. Cada ferramenta muda a **forma** do corte:

| Ferramenta | Corte | Resíduo | Estado |
|---|---|---|---|
| Facão | sweep fino e raso, oblíquo | muitas lascas pequenas | ✅ |
| Machado | cunha em V, entalhe fundo | lascas grandes | ✅ |
| Serra manual | kerf reto e fino, avanço lento | serragem | ⬜ |
| Motosserra | kerf largo, avanço rápido | jato de serragem + estilhaço | ⬜ |

Porque o corte é geométrico, **técnica importa**: o dinheiro sai do volume
removido, e uma tora limpa (entalhe na direção da queda + corte de trás) vale
muito mais que picar o tronco em lasca aleatória.

## Viabilidade — respondida

A mecânica depende de quatro APIs do `GeometryService`:

| API | Papel |
|---|---|
| `SweepPartAsync` | o movimento da lâmina vira um sólido de corte |
| `SubtractAsync` | esse sólido é removido do tronco |
| `GenerateFragmentSites` | sites voronoi no ponto de impacto |
| `FragmentAsync` | estilhaça a madeira em pedaços de forma natural |

Elas estão atrás do beta de Studio **"Solid Modeling On Meshes"**, e a pergunta
que abriu o projeto era se funcionariam numa experience **publicada**, para um
jogador comum. Um spike descartável foi feito só pra responder isso.

**Funcionam.** O corte geométrico real é o caminho, e o plano B (tronco
pré-segmentado com estados de dano, atrás da mesma interface
`CortadorServidor.cortar`) foi arquivado.

## O que já roda

- Corte geométrico real, **server-authoritative**, com fila de operações.
- Árvore como `Model` com copa, **tombamento por limiar de massa** e direção de
  queda derivada de onde o entalhe foi feito.
- Ciclo **toco → brotos → nova árvore** no mesmo lugar.
- 7 espécies com pesos de raridade, incluindo uma Árvore de Ouro rara.
- Economia: `$` = volume removido × valor da espécie × qualidade do corte.
- Duas ferramentas (facão e machado), cada uma com gesto e geometria próprios.
- Feedback de impacto: serragem direcional, poeira, flash, tremor de câmera,
  FOV punch no clímax da queda, e o som da queda amarrado ao impacto no solo.

Falta: serra manual e motosserra, persistência, máquinas/automação e prestígio.

## Multiplayer — lote por jogador

O servidor é compartilhado (8 jogadores), mas **cada jogador tem seu lote
físico** numa grade de posições fixas, com suas próprias árvores reais e
cortáveis desde o spawn. `StreamingEnabled` com raio reduzido faz cada um
carregar só o próprio lote.

Isso substituiu um gerenciador de proximidade que promovia e rebaixava árvores
conforme o jogador andava — ele era a raiz de quatro bugs de uma vez (árvore
trocando de espécie, árvore grande sumindo antes de o jogador chegar, geometria
malformada, e crescimento reciclado antes de virar tora aproveitável).

## Rodar

```powershell
rojo serve default.project.json
```

No Studio: **File ⟩ Beta Features ⟩ Solid Modeling On Meshes** (ligar e
reiniciar), abrir um baseplate novo, plugin Rojo → **Connect**.

O `BootServidor` monta o cenário sozinho e o `LoteServidor` entrega um lote no
`PlayerAdded`. Nada precisa ser construído à mão. Equipe uma ferramenta e
clique numa árvore.

## Estrutura

```
src/
  ReplicatedStorage/
    Net.lua                    remotes num lugar só
    ConfiguracaoTimber.lua     todo número tunável
    Catalogo/
      Assets.lua               IDs de asset, tipados e curados
      Especies.lua             espécies, pesos de raridade e valor
    Math/DropBreathing.lua     tabela de caos gerada offline
    Modelos/                   modelos vendorizados (sem LoadAsset em runtime)
  ServerScriptService/
    BootServidor.server.lua    cenário, rede e diagnóstico
    CenarioVisual.server.lua   backdrop de floresta, montanhas, atmosfera
    ConstruirFerramentas.server.lua  blockout das ferramentas em código
    Server/
      CortadorServidor.lua     a fachada do corte (sweep → subtract → fragment)
      FilaGeometria.lua        teto de operações async concorrentes
      DetritoServidor.lua      cacos, orçamento e varrição
      ArvoreServidor.lua       construção, crescimento, tombamento, rebrote
      LoteServidor.lua         um lote físico por jogador
      EconomiaServidor.lua     $ por volume × espécie × qualidade
      DiagnosticoServidor.lua  painel de medição
  StarterPlayer/StarterPlayerScripts/
    GestoCliente.client.lua    grava o arco do golpe e manda pro servidor
    BalancoCliente.client.lua  animação do swing (antecipação/impacto/recuo)
    FeedbackCliente.client.lua camada de juice, client-side e imediata
    AmbienteCliente.client.lua som ambiente
    HUDCliente.client.lua      HUD de $ e painel
  StarterPack/                 Tools (Machado, Facão)
```

## Notas de engenharia

- **Corte é server-authoritative.** O cliente descreve o gesto; o servidor
  resolve a geometria. CSG no cliente não replica pro servidor.
- **Operações de geometria são caras e assíncronas.** `FilaGeometria` limita a
  2 concorrentes e descarta golpe redundante — sem isso, uma motosserra segurada
  vira dezenas de subtracts por segundo.
- **Fragmentos precisam de coleta.** `DetritoServidor` limita por golpe e por
  total vivo, com `Debris`.
- **Meshes precisam ser watertight** para as operações funcionarem.
- **Feedback não espera o servidor.** A camada de juice dispara no ponto do
  raycast que o cliente já tem; quando o resultado real chega, o número corrige.
  Sem isso o golpe fica borrachudo.
- **Nada de `LoadAsset` em runtime.** Modelos são vendorizados no repo.

---

Código de criação (design, economia detalhada, pipeline de assets) é fechado.
