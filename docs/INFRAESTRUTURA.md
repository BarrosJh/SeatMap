# Deploy e infraestrutura

## Ambientes

O `docker-compose.yml` é destinado ao desenvolvimento local. Em staging e produção:

- forneça os segredos pelo gerenciador de secrets do ambiente;
- defina `NODE_ENV=staging` ou `NODE_ENV=production`;
- defina `INTERNAL_HEALTH_TOKEN` com pelo menos 32 caracteres;
- defina `TRUST_PROXY_HOPS` conforme o número real de proxies confiáveis;
- não publique a porta do PostgreSQL para redes externas;
- use imagens fixadas por digest no orquestrador.

## Probes

`/api/health/live` é a probe pública de liveness e não expõe memória ou uptime.
`/api/health/ready`, `/api/health/metrics` e `/api/health` exigem o header
`x-health-token` em staging e produção. O readiness não devolve detalhes do erro do banco.

## Concorrência

Com o backend e o banco disponíveis, execute o cenário de duas tentativas para o mesmo assento:

```powershell
k6 run concurrency_test.js
```

Variáveis obrigatórias: `BASE_URL`, `AUTH_TOKEN`, `SEAT_ID` e `RESERVATION_DATE`.
O teste espera uma única reserva bem-sucedida e conflito/erro de negócio nas demais tentativas.

## Escala horizontal

O rate limiting padrão usa memória local do processo. Antes de escalar horizontalmente, configure
um store compartilhado compatível com `express-rate-limit` ou imponha o limite no API gateway.
As métricas em memória devem ser exportadas para uma plataforma de observabilidade antes de usar
os valores para SLOs ou alertas históricos.

## Teste de carga

Em operação normal, o limite de autenticação por IP é `50/minuto` e o limite global da API é
`900/minuto`. Para homologação, o limite global pode ser ampliado somente com `LOAD_TEST_MODE=true` e
`LOAD_TEST_RATE_LIMIT_MAX` definido no ambiente do teste. Essas variáveis não devem ser ativadas
em produção. Após a carga, confirme que `LOAD_TEST_MODE=false` antes de promover o ambiente.