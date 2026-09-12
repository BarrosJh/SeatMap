# Observabilidade e Resposta a Incidentes (Backend)

## Logs

O logger central em `src/utils/logger` produz entradas estruturadas com timestamp, nivel,
servico, ambiente, mensagem, contexto e `correlationId`. Em producao, use `LOG_FORMAT=json`
e encaminhe stdout/stderr para o coletor central da plataforma (por exemplo, Loki, ELK ou
CloudWatch). O mecanismo de sanitização e mascaramento remove senhas, tokens, segredos, CPF e dados de cartao antes da saida.

Cada request recebe ou propaga `X-Correlation-Id`. O mesmo identificador aparece no log de
entrada/saida, nos controllers e nos erros tratados, permitindo buscar uma transacao completa.

## Dashboard de operacao

Endpoints:

- `GET /api/health/live`: processo responsivo, uptime e memoria;
- `GET /api/health/ready`: readiness e conectividade/latencia do PostgreSQL;
- `GET /api/health/metrics`: dashboard JSON com requests, erros, latencia media/p95, rotas,
  concorrencia, memoria e alertas recentes;
- `GET /api/admin/ti/status`: visao complementar de banco, pool, WebSocket e memoria.

O endpoint de metrics retorna `503` quando ja houve erro 5xx no processo desde o ultimo restart.
Os dados sao intencionalmente em memoria e devem ser exportados por um coletor antes de reiniciar
o processo quando for necessaria analise historica.

## Alertas

O `MetricsService` gera alerta estruturado para:

- resposta HTTP 5xx;
- falha de PostgreSQL/readiness;
- rejeicao de `uncaughtException` ou `unhandledRejection`;
- request com latencia igual ou superior a 2 segundos;
- concorrencia igual ou superior a 100 requests ativos.

Os alertas sao mantidos no dashboard e enviados ao logger com cooldown de 60 segundos para
evitar tempestade de logs. O coletor central deve criar notificacao para `level=error` e para
`context.alertType`.

## Procedimento de resposta

1. Consultar `/api/health/metrics` e `/api/health/ready` para separar falha de processo de falha do banco.
2. Capturar o `X-Correlation-Id` da requisicao afetada e buscar todos os logs desse identificador.
3. Verificar `HTTP_5XX`, `DEPENDENCY_FAILURE`, `SLOW_REQUEST` e `HIGH_CONCURRENCY` no dashboard.
4. Se o PostgreSQL estiver indisponivel, retirar a instancia do balanceador via readiness e preservar o pool/logs.
5. Se houver pico de latencia ou concorrencia, limitar trafego/exportacoes e verificar as rotas no ranking de uso.
6. Registrar horario, impacto, alertas, correlation IDs e acao tomada no incidente.
7. Depois da recuperacao, revisar logs e metricas do periodo e criar teste ou ajuste preventivo.
