# Checklist de release

## Antes do merge

- [ ] PR descreve objetivo, risco, impacto e rollback.
- [ ] `quality-gate` passou.
- [ ] `npm audit` nao encontrou vulnerabilidade alta/critica nova.
- [ ] Testes backend e frontend passaram.
- [ ] Nenhum segredo ou dado sensivel foi adicionado.
- [ ] Migrations e indices foram revisados.
- [ ] Mudancas de seguranca receberam aprovacao dos owners.

## Antes de staging

- [ ] Backup recente confirmado.
- [ ] Tag/commit do artefato registrado.
- [ ] Variaveis e secrets de staging conferidos.
- [ ] Plano de rollback anexado ao ticket.

## Promocao para producao

- [ ] `/api/health/ready` passou em staging.
- [ ] `/api/health/metrics` respondeu sem degradacao inesperada.
- [ ] Login, refresh/logout, criacao de reserva, cancelamento e auditoria foram testados.
- [ ] Logs com correlation ID estao chegando ao coletor.
- [ ] Aprovacao manual de staging registrada.
- [ ] Aprovacao de producao registrada.

## Pos-deploy

- [ ] Health checks verdes.
- [ ] Erros 5xx e latencia dentro do limite.
- [ ] Pool do banco sem fila sustentada.
- [ ] WebSocket conectado.
- [ ] Nenhum alerta critico novo.
- [ ] Resultado da janela de observacao registrado.
