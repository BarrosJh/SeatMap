#!/usr/bin/env bash
# ==============================================================================
# SeatMap PostgreSQL Backup Script (Enterprise Automated Backup & Retention)
# ==============================================================================
# Executa rotina diária de pg_dump com compressão gzip, checksum SHA256 e
# exclusão automática de arquivos de backup com mais de 30 dias (política de retenção).
#
# Uso:
#   ./scripts/backup.sh
#   PGHOST=localhost PGPORT=5432 PGUSER=postgres PGDATABASE=seatmap ./scripts/backup.sh
# ==============================================================================

set -euo pipefail

# Configurações de Banco de Dados (com fallbacks para variáveis de ambiente)
DB_HOST="${DB_HOST:-${PGHOST:-localhost}}"
DB_PORT="${DB_PORT:-${PGPORT:-5432}}"
DB_USER="${DB_USER:-${PGUSER:-postgres}}"
DB_NAME="${DB_NAME:-${PGDATABASE:-seatmap}}"
BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Formatação de Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="seatmap_backup_${TIMESTAMP}.sql.gz"
BACKUP_FILEPATH="${BACKUP_DIR}/${BACKUP_FILENAME}"
CHECKSUM_FILEPATH="${BACKUP_FILEPATH}.sha256"

# Criação do diretório de destino
mkdir -p "${BACKUP_DIR}"

echo "================================================================================"
echo " [SeatMap] Iniciando Rotina de Backup do PostgreSQL"
echo " Data/Hora : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Host      : ${DB_HOST}:${DB_PORT}"
echo " Banco     : ${DB_NAME}"
echo " Destino   : ${BACKUP_FILEPATH}"
echo " Retenção  : ${RETENTION_DAYS} dias"
echo "================================================================================"

# Verificação do utilitário pg_dump
if ! command -v pg_dump &> /dev/null; then
    echo "[-] ERRO: O comando 'pg_dump' não foi encontrado no PATH do sistema." >&2
    exit 1
fi

# Execução do dump com compressão gzip
echo "[*] Executando pg_dump e comprimindo dados..."
START_TIME=$(date +%s)

export PGPASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"
pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
    --format=plain \
    --no-owner \
    --no-acl \
    --clean \
    --if-exists \
    | gzip -9 > "${BACKUP_FILEPATH}"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Validação do arquivo gerado
if [ ! -s "${BACKUP_FILEPATH}" ]; then
    echo "[-] ERRO: O arquivo de backup gerado está vazio ou não foi criado." >&2
    rm -f "${BACKUP_FILEPATH}"
    exit 1
fi

FILE_SIZE=$(du -h "${BACKUP_FILEPATH}" | cut -f1)
echo "[+] Backup concluído com sucesso em ${DURATION}s! Tamanho: ${FILE_SIZE}"

# Geração de Checksum de Integridade (SHA256)
echo "[*] Calculando checksum SHA-256..."
if command -v sha256sum &> /dev/null; then
    sha256sum "${BACKUP_FILEPATH}" > "${CHECKSUM_FILEPATH}"
elif command -v shasum &> /dev/null; then
    shasum -a 256 "${BACKUP_FILEPATH}" > "${CHECKSUM_FILEPATH}"
fi
echo "[+] Checksum gravado em: ${CHECKSUM_FILEPATH}"

# Aplicação da Política de Retenção (Exclui backups com mais de N dias)
echo "[*] Aplicando política de retenção (removendo backups com mais de ${RETENTION_DAYS} dias)..."
PURGED_COUNT=0
while IFS= read -r old_backup; do
    if [ -n "${old_backup}" ]; then
        echo "    [-] Removendo backup expirado: $(basename "${old_backup}")"
        rm -f "${old_backup}" "${old_backup}.sha256"
        PURGED_COUNT=$((PURGED_COUNT + 1))
    fi
done < <(find "${BACKUP_DIR}" -type f -name "seatmap_backup_*.sql.gz" -mtime +"${RETENTION_DAYS}")

echo "[+] Política de retenção aplicada. ${PURGED_COUNT} arquivo(s) expirado(s) removido(s)."
echo "================================================================================"
echo " [SeatMap] Processo de Backup Finalizado com Sucesso!"
echo "================================================================================"
exit 0

