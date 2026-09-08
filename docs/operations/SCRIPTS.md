# 🛠️ Scripts Operacionais do SeatMap (Backup & Restore)

Este diretório contém os scripts corporativos de automação para salvaguarda e recuperação de dados do banco de dados PostgreSQL do sistema SeatMap.

---

## 📁 Estrutura de Arquivos

| Arquivo | Plataforma | Descrição |
|---|---|---|
| `backup.sh` | Linux / Docker / macOS | Realiza `pg_dump`, compacta com `gzip -9`, gera hash SHA-256 e purga backups com mais de 30 dias. |
| `backup.ps1` | Windows Server / Dev | Realiza `pg_dump`, compacta nativamente em GZip via .NET, gera hash SHA-256 e purga backups com mais de 30 dias. |
| `restore.sh` | Linux / Docker / macOS | Valida o hash SHA-256, desconecta sessões ativas e restaura o banco de dados via `psql`. |
| `restore.ps1` | Windows Server / Dev | Valida o hash SHA-256, encerra conexões ativas no PostgreSQL e restaura o banco de forma transacional. |

---

## 🚀 Como Executar Manualmente

### No Linux / macOS / Contêiner Docker
```bash
# Executar backup diário
chmod +x ./scripts/backup.sh ./scripts/restore.sh
./scripts/backup.sh

# Restaurar backup específico
./scripts/restore.sh backups/seatmap_backup_20260907_120000.sql.gz
```

### No Windows (PowerShell)
```powershell
# Executar backup diário
.\scripts\backup.ps1

# Restaurar backup específico
.\scripts\restore.ps1 -BackupFile "backups\seatmap_backup_20260907_120000.sql.gz"
```

---

## ⏰ Agendamento Automatizado

### 1. Linux Cron Job (Rotina Diária às 02:00 AM)
Edite a crontab do servidor:
```bash
crontab -e
```
Adicione a linha:
```cron
0 2 * * * /opt/seatmap/scripts/backup.sh >> /var/log/seatmap_backup.log 2>&1
```

### 2. Windows Task Scheduler (Agendador de Tarefas)
Execute no PowerShell como Administrador para criar a tarefa diária às 02:00 AM:
```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Assentos\scripts\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "SeatMap_PostgreSQL_Daily_Backup" -Action $action -Trigger $trigger -Principal $principal -Description "Rotina diária de backup com compressão e retenção de 30 dias."
```

---

## 🔒 Variáveis de Ambiente Suportadas

- `DB_HOST` / `PGHOST`: Host do PostgreSQL (padrão: `localhost`).
- `DB_PORT` / `PGPORT`: Porta do PostgreSQL (padrão: `5432`).
- `DB_USER` / `PGUSER`: Usuário do banco (padrão: `postgres`).
- `DB_NAME` / `PGDATABASE`: Nome da base de dados (padrão: `seatmap`).
- `DB_PASSWORD` / `PGPASSWORD`: Senha de acesso ao banco.
- `BACKUP_DIR`: Diretório de saída dos backups (padrão: `../backups`).
- `RETENTION_DAYS`: Dias de retenção antes da exclusão automática (padrão: `30`).

