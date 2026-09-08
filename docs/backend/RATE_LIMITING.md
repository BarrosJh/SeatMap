# Bloco 5 - Rate limiting, brute force e abuso

Os limitadores usam `express-rate-limit` com armazenamento em memoria. Cada instancia do
processo mantem suas proprias janelas; em producao com mais de uma instancia, o `store` deve
ser substituido por Redis ou outro armazenamento compartilhado para manter o limite global.

Quando um limite e excedido, a API retorna HTTP 429, registra um alerta estruturado no logger
e grava um evento na tabela `auditoria_acessos`.

## Regras aplicadas

| Superficie | Chave | Janela | Limite |
| --- | --- | --- | ---: |
| API global | IP | 1 minuto | 900 |
| Autenticacao geral | IP | 1 minuto | 50 |
| Login, SSO e recuperacao | login/e-mail ou IP | 15 minutos | 5 |
| Painel administrativo | IP | 1 minuto | 60 |
| Acoes administrativas | usuario autenticado ou IP | 1 minuto | 30 |
| Consultas administrativas pesadas | usuario autenticado ou IP | 1 minuto | 20 |
| Exportacao CSV/XLSX/PDF | usuario autenticado ou IP | 10 minutos | 5 |
| Teste SMTP | usuario autenticado ou IP | 10 minutos | 5 |
| Importacao em lote | usuario autenticado ou IP | 10 minutos | 5 |

## Protecao contra brute force

O login tambem possui bloqueio de conta depois de cinco senhas incorretas, implementado no
controller de autenticacao. O rate limit por IP e por login cobre distribuicao de tentativas,
enquanto o bloqueio da conta cobre repeticao contra um usuario especifico.

O limite por IP da autenticacao foi dimensionado para uma abertura corporativa distribuida,
em que muitos usuarios podem compartilhar o mesmo NAT, sem permitir um burst excessivo de
tentativas. O limite por conta/login de 5 tentativas em 15 minutos e o bloqueio de conta
continuam ativos. Ajuste `AUTH_IP_RATE_LIMIT_MAX` somente conforme o volume real e monitore
falhas de login, sem remover a protecao por conta.

## Alertas e auditoria

Os bloqueios geram os eventos:

- `LOGIN_CONTA_BLOQUEADA` para abuso de autenticacao;
- `ABUSO_API_BLOQUEADO` para trafego, acoes e consultas;
- `ABUSO_EXPORTACAO_BLOQUEADO` para exportacoes;
- `ABUSO_LOTE_BLOQUEADO` para operacoes em lote.

O alerta inclui rota, metodo, IP, usuario quando autenticado, categoria e chave de limitacao,
sem registrar tokens ou senhas.

O limite global considera todas as requisicoes do IP, inclusive o fluxo de abertura da agenda.
O valor padrao de 900 por minuto acomoda aproximadamente tres requisicoes por usuario em um
burst de 300 usuarios. Ajuste `GLOBAL_RATE_LIMIT_MAX` conforme os endpoints realmente usados e monitore
HTTP 429; os limites especificos de autenticacao continuam valendo separadamente.