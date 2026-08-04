# Hub — game.terpens.com.br

Landing pública dos jogos Roblox da Terpens.

## O que é

HTML/CSS/JS estático: brand, CTAs, tracking (GA4/Ads).  
**Não** contém painel admin, credenciais, paths de máquina nem config de infraestrutura.

## Rodar local (só preview da landing)

```bash
cd hub
python server.py
```

Abre o servidor de arquivos estáticos no endereço impresso no terminal.

Site público: **https://game.terpens.com.br**

## Tracking

IDs de medição ficam no front (`js/tracking.js` + `TERPENS_TRACKING` no `index.html`) — o navegador do visitante já os vê. Não colocar secrets de API, tokens OAuth ou senhas neste repo.

## Brand

Favicon e OG alinhados ao site [terpens.com.br](https://terpens.com.br).
