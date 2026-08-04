# Fronteira do repositório público

Lembrete permanente. Este repo é **cara pública** do jogo — não da infra.

## Pode

1. Código/assets do experience (Luau, Rojo, mapas).
2. Landing estática do hub (`hub/`).
3. Docs de jogador / colaborador de jogo.

## Não pode (rejeitar PR/commit)

1. Skills de AI, `.grok/`, `_LAB`, dicionários de design/monetização de referência.
2. **Senhas, tokens, API keys, cookies, `.env`.**
3. **Paths de máquina** (`D:\…`, `C:\Users\…`).
4. **IPs internos, `127.0.0.1`, portas de origin, configs de túnel/DNS/cloudflared/orquestrador.**
5. Logins de admin, bootstrap de painel, connection strings, dumps de status de lab.
6. Nome/URL do repositório privado de build **só** se necessário em uma linha de “código fechado”; sem inventário do que tem lá.

O motor de criação fica em repositório **privado**.  
Se não tem certeza se algo é público: **não commitar**.
