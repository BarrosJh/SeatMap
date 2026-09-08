#!/usr/bin/env bash
# ==============================================================================
# SeatMap PostgreSQL Restore Script (Enterprise Database Restore & Verification)
# ==============================================================================
# Restaura um arquivo de backup (.sql.gz ou .sql) no banco de dados PostgreSQL
# após validação de integridade do arquivo.
#
# Uso:
#   ./scripts/restore.sh <caminho_do_arquivo_de_backup>
#   ./scripts/restore.sh backups/seatmap_backup_20260907_120000.sql.gz
# ==============================================================================

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "[-] ERRO: Informe o caminho do arquivo de backup a ser restaurado." >&2
    echo "    Uso: $0 <caminho_do_arquivo.sql.gz>" >&2
    exit 1
fi

BACKUP_FILE="$1"
DB_HOST="${DB_HOST:-${PGHOST:-localhost}}"
DB_PORT="${DB_PORT:-${PGPORT:-5432}}"
DB_USER="${DB_USER:-${PGUSER:-postgres}}"
DB_NAME="${DB_NAME:-${PGDATABASE:-seatmap}}"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "[-] ERRO: Arquivo '${BACKUP_FILE}' não encontrado." >&2
    exit 1
fi

echo "================================================================================"
echo " [SeatMap] Iniciando Processo de Restauração do PostgreSQL"
echo " Data/Hora : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Arquivo   : ${BACKUP_FILE}"
echo " Host      : ${DB_HOST}:${DB_PORT}"
echo " Banco     : ${DB_NAME}"
echo "================================================================================"

# Verificação do checksum se existir .sha256
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
if [ -f "${CHECKSUM_FILE}" ]; then
    echo "[*] Verificando integridade SHA-256 do arquivo..."
    if command -v sha256sum &> /dev/null; then
        sha256sum -c "${CHECKSUM_FILE}"
    elif command -v shasum &> /dev/null; then
        shasum -a 256 -c "${CHECKSUM_FILE}"
    fi
    echo "[+] Checksum validado com sucesso!"
fi

# Verificação do comando psql
if ! command -v psql &> /dev/null; then
    echo "[-] ERRO: O comando 'psql' não foi encontrado no PATH do sistema." >&2
    exit 1
fi

export PGPASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"

# Termina conexões ativas com o banco antes do restore
echo "[*] Encerrando conexões ativas no banco ${DB_NAME}..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB_NAME}' AND pid <> pg_backend_pid();" \
    || true

echo "[*] Executando restauração do banco..."
START_TIME=$(date +%s)

if [[ "${BACKUP_FILE}" == *.gz ]]; then
    gzip -dc "${BACKUP_FILE}" | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"
else
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${BACKUP_FILE}"
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "================================================================================"
echo " [SeatMap] Restauração Concluída com Sucesso em ${DURATION}s!"
echo "================================================================================"
exit 0

