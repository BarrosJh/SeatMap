# Política de Backup, Restore e Continuidade Operacional

## Política

- Backup lógico completo do PostgreSQL executado diariamente fora do horário de pico.
- Retenção mínima local: 30 dias, aplicada pelos scripts de automação (`scripts/backup.sh` ou `scripts/backup.ps1` - consulte [Guia Operacional de Scripts](operations/SCRIPTS.md)).
- Uma copia deve ser enviada para armazenamento externo ao host (object storage ou servidor de backup) apos o checksum.
- Retencao recomendada externa: 12 backups mensais e 7 diarios. O storage externo deve usar criptografia e versionamento.
- O volume Docker `pgdata` e persistencia operacional, nao substitui backup.
- O RPO alvo e de 24 horas para a rotina diaria. Para RPO menor, agendar dumps mais frequentes ou WAL archiving.
- O RTO alvo e de 2 horas, condicionado a disponibilidade do PostgreSQL, backup e credenciais.

## Agendamento automatico

Linux cron, todos os dias as 02:00:

```cron
0 2 * * * cd /opt/seatmap && /usr/bin/env DB_HOST=127.0.0.1 DB_PORT=5432 DB_NAME=seatmap_db DB_USER=seatmap_user DB_PASSWORD='INJETAR_FORA_DO_CRON' BACKUP_DIR=/var/backups/seatmap RETENTION_DAYS=30 /bin/bash scripts/backup.sh >> /var/log/seatmap-backup.log 2>&1
```

Nao coloque senha diretamente no crontab em producao. Use `.pgpass`, secret manager ou um unit/job com secret injetado.

Windows Task Scheduler:

```text
Programa: powershell.exe
Argumentos: -NoProfile -ExecutionPolicy Bypass -File C:\SeatMap\scripts\backup.ps1 -BackupDir C:\SeatMap\backups -RetentionDays 30
Frequencia: diaria, 02:00
```

O job deve gerar alerta quando o processo terminar com codigo diferente de zero e deve copiar o
`.sql.gz` e o `.sha256` para o armazenamento externo.

## Teste de restauracao controlado

O teste deve usar um banco separado, nunca o banco de producao:

```bash
createdb -h localhost -U seatmap_user seatmap_restore_test
CONFIRM_RESTORE=YES DB_NAME=seatmap_restore_test ./scripts/restore.sh backups/seatmap_backup_YYYYMMDD_HHMMSS.sql.gz
```

Depois da restauracao:

```bash
psql -h localhost -U seatmap_user -d seatmap_restore_test -c "SELECT COUNT(*) FROM usuarios; SELECT COUNT(*) FROM reservas; SELECT COUNT(*) FROM auditoria_acessos;"
curl -fsS http://localhost:3000/api/health/ready
```

O teste e considerado aprovado quando o checksum e validado, o restore termina sem erro, as
consultas de verificacao respondem e a aplicacao consegue executar a readiness contra o banco
testado. Registre data, arquivo, duracao, tamanho, contagens e resultado.

No Windows, use:

```powershell
.\scripts\restore.ps1 -BackupFile .\backups\seatmap_backup_YYYYMMDD_HHMMSS.sql.gz -DbName seatmap_restore_test -ConfirmRestore
```

As rotinas recusam restore sem checksum e sem confirmacao explicita para reduzir o risco de
sobrescrever o banco errado.

## Recuperacao de incidente

1. Declarar o incidente e registrar horario, operador e ambiente afetado.
2. Consultar `/api/health/live`, `/api/health/ready` e logs pelo `X-Correlation-Id`.
3. Se o banco estiver indisponivel, impedir novo trafego usando readiness e preservar o volume original.
4. Escolher o ultimo backup com checksum valido e confirmar que o destino e o banco de recuperacao.
5. Restaurar primeiro em ambiente controlado e executar as verificacoes de contagem e integridade.
6. Para recuperacao de producao, pausar a API, fazer snapshot do estado atual e restaurar no banco aprovado.
7. Executar migrations compativeis, subir a API e validar login, reservas, auditoria, WebSocket e health checks.
8. Liberar trafego gradualmente e monitorar erros 5xx, latencia, conexoes do pool e novas reservas.
9. Registrar perdas entre o ultimo backup e a falha, acoes executadas e evidencias do teste.

## Rollback de deploy

1. Identificar a imagem/tag anterior que estava saudavel.
2. Pausar o rollout e manter o banco ativo se o schema for compativel.
3. Reimplantar a versao anterior sem executar seed destrutivo.
4. Se houve migration irreversivel, nao tentar rollback SQL automatico: restaurar snapshot/backup em banco separado, validar e planejar cutover.
5. Validar `/api/health/ready`, login, criacao/cancelamento de reserva, auditoria e metricas.
6. Manter a versao anterior ate o novo deploy passar por smoke test e janela de observacao.

Nunca use `docker compose down -v` como procedimento de recuperacao: isso remove o volume
`pgdata` e pode destruir a unica copia operacional dos dados.
