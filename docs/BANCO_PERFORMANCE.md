# Engenharia de Banco de Dados e Performance (PostgreSQL)

## Resultado da revisao

As consultas criticas usam parametros, transacoes e chaves estrangeiras. A operacao de criacao
de reserva usa `BEGIN`, bloqueio `FOR UPDATE`, validacao de conflitos e `COMMIT`, preservando a
atomicidade sob concorrencia. Os indices unicos parciais impedem duas reservas ativas para a
mesma cadeira/data ou para o mesmo usuario/data.

Foram adicionados indices alinhados a filtros e ordenacoes de crescimento:

- `idx_reservas_usuario_data_id`: listagem paginada das reservas do usuario;
- `idx_reservas_data_criado_id`: listagens administrativas ordenadas por data e criacao;
- `idx_historico_cadeira_criado_id`: historico de uma cadeira;
- `idx_historico_usuario_criado_id`: historico de um usuario;
- `idx_mfa_codes_usuario_utilizado_expira`: busca de codigo MFA ativo/expiracao;
- `idx_usuarios_sso`: localizacao de identidade SSO.

Os indices anteriores continuam sendo mantidos quando atendem filtros diferentes. Apos aplicar
novos indices em producao, execute `ANALYZE` nas tabelas alteradas e acompanhe uso antes de
remover qualquer indice potencialmente redundante.

## Evidencia de EXPLAIN

Os planos foram verificados no PostgreSQL do Compose. Em uma base pequena de homologacao, o
otimizador escolheu `Seq Scan` para algumas consultas mesmo com os novos indices, porque ler a
tabela inteira era mais barato. Isso e esperado. O criterio de aceite deve ser repetido com
volume representativo, quando o planner deve comparar os indices compostos com o custo real.

Consultas que devem ser acompanhadas:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, data_reserva, status
FROM reservas
WHERE usuario_id = 1
ORDER BY data_reserva DESC, id DESC
LIMIT 50 OFFSET 0;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, cadeira_id, criado_em, tipo_evento
FROM historico_reservas
WHERE cadeira_id = 1
ORDER BY criado_em DESC, id DESC
LIMIT 50 OFFSET 0;
```

Em producao, capture planos com `pg_stat_statements` e nao use `EXPLAIN ANALYZE` em consultas
destrutivas sem transacao controlada.

## Integridade e exclusao

- reservas apontam para usuarios e cadeiras; a exclusao de usuario/cadeira hoje usa `CASCADE`;
- auditoria de acessos usa `SET NULL` para manter o evento mesmo que o usuario seja removido;
- historico de reservas e imutavel por trigger, mas sua FK de usuario atualmente usa `CASCADE`;
- a politica operacional recomendada e desativar usuarios e cadeiras, em vez de excluir registros.

Antes de permitir exclusao fisica em producao, deve-se migrar a FK de `historico_reservas.usuario_id`
para `ON DELETE RESTRICT` ou `SET NULL` com coluna anulavel, preservando a trilha historica.

## Teste de carga em homologacao

1. Gerar pelo menos 1 milhao de reservas historicas, 100 mil usuarios e 100 mil eventos de historico.
2. Distribuir datas, escritorios, departamentos e status de forma semelhante a producao.
3. Executar cenarios concorrentes de criacao, consulta de minhas reservas, check-in, historico,
   relatorios e exportacoes.
4. Medir p50/p95/p99, throughput, locks, deadlocks, buffer cache hit, I/O, conexoes e uso de CPU.
5. Repetir com 2x e 5x o volume esperado para o proximo ciclo.

Metas iniciais:

- consultas paginadas comuns: p95 abaixo de 300 ms;
- criacao/check-in/cancelamento: p95 abaixo de 500 ms;
- relatorios filtrados: p95 abaixo de 2 s;
- zero deadlocks e zero violacoes de unicidade inesperadas;
- pool sem fila sustentada durante o pico.

## Plano de crescimento

- curto prazo: `ANALYZE`, `pg_stat_statements`, monitoramento de locks e teste com dados sintéticos;
- medio prazo: particionar `reservas` e `historico_reservas` por data se o volume justificar;
- relatorios: criar agregacoes/materialized views para dashboards frequentes, sem recalcular joins completos;
- paginação: preferir cursor/keyset em telas com offsets muito altos;
- infraestrutura: pool por instancia, limites de conexao e replicas de leitura para consultas pesadas;
- governanca: revisar indices a cada aumento de 2x no volume e apos mudancas de filtros.