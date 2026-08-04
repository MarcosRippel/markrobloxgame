# markrobloxgame

Repositório **público** do(s) experience(s) Roblox da Terpens.

Site: **https://game.terpens.com.br**

## O que é este repo

- Código Luau / Rojo do jogo (quando houver)
- Hub estático público (`hub/`) — landing + tags de analytics
- Docs **do jogo** para jogadores e colaboradores

## O que NÃO entra neste repo

| Proibido | Motivo |
|----------|--------|
| Skills de AI, lab `_LAB`, playbooks | ficam no repositório **privado** de build |
| Tokens, cookies, API keys, senhas | **nunca** no git |
| Paths de disco (`D:\…`), IPs internos, portas de origin | infra privada |
| Config de túnel/DNS/orquestrador/cloudflared | infra privada |
| Logins de admin / bootstrap de painel | infra privada |
| Notas de “como a fábrica funciona por dentro” | privado |

Se um PR trouxer qualquer item da tabela: **rejeitar**. Ver `PUBLIC-BOUNDARY.md`.

## Status

| Peça | Estado |
|------|--------|
| Experience Roblox (Rojo) | bootstrap / protótipos em `game/` |
| Hub público | landing em `hub/` → [game.terpens.com.br](https://game.terpens.com.br) |

## Stack (jogo)

| Camada | Tecnologia |
|--------|------------|
| Engine / IDE | [Rojo](https://rojo.space/) + Roblox Studio |
| Linguagem | **Luau** |
| Sync | Rojo (`default.project.json`) |
| Hub web | HTML/CSS/JS estático em `hub/` |

Stack da **fábrica** (física, brain, skills, corpus): só no repositório privado.

### Layout previsto do experience

```
src/
  ReplicatedStorage/   # shared (Net, Config, catálogos)
  ServerScriptService/ # autoridade / economia / gamepass
  StarterPlayer/       # cliente (HUD, feedback, input)
```

## Hub web (`hub/`)

```bash
cd hub
python server.py
```

- Tracking: `hub/js/tracking.js`
- Brand: [terpens.com.br](https://terpens.com.br)

## Licença / contribuições

A definir. Uso sob controle do autor.
