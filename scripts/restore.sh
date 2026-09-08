#!/usr/bin/env bash
# Restore controlado de um backup plain SQL.gz do SeatMap.
# Uso seguro:
#   CONFIRM_RESTORE=YES ./scripts/restore.sh backups/seatmap_backup_*.sql.gz

set -euo pipefail

BACKUP_FILE="${1:-}"
DB_HOST="${DB_HOST:-${PGHOST:-localhost}}"
DB_PORT="${DB_PORT:-${PGPORT:-5432}}"
DB_USER="${DB_USER:-${PGUSER:-seatmap_user}}"
DB_NAME="${DB_NAME:-${PGDATABASE:-seatmap_db}}"

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "Uso: CONFIRM_RESTORE=YES $0 <arquivo.sql.gz>" >&2
  exit 2
fi

if [ "${CONFIRM_RESTORE:-NO}" != "YES" ]; then
  echo "Restore bloqueado. Defina CONFIRM_RESTORE=YES explicitamente." >&2
  exit 2
fi

if ! command -v gzip >/dev/null 2>&1 || ! command -v psql >/dev/null 2>&1; then
  echo "gzip e psql precisam estar disponiveis no PATH." >&2
  exit 1
fi

export PGPASSWORD="${DB_PASSWORD:-${PGPASSWORD:-}}"

if [ -f "${BACKUP_FILE}.sha256" ]; then
  echo "[*] Verificando checksum SHA-256..."
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "${BACKUP_FILE}.sha256"
  elif command -v shasum >/dev/null 2>&1; then
    EXPECTED="$(awk '{print $1}' "${BACKUP_FILE}.sha256")"
    ACTUAL="$(shasum -a 256 "${BACKUP_FILE}" | awk '{print $1}')"
    [ "${EXPECTED}" = "${ACTUAL}" ] || { echo "Checksum invalido." >&2; exit 1; }
  else
    echo "Nao foi possivel validar checksum: sha256sum/shasum ausente." >&2
    exit 1
  fi
else
  echo "Arquivo de checksum ausente: restore cancelado." >&2
  exit 1
fi

echo "[*] Validando compressao do backup..."
gzip -t "${BACKUP_FILE}"

echo "[*] Restaurando ${BACKUP_FILE} em ${DB_NAME}@${DB_HOST}:${DB_PORT}..."
gzip -dc "${BACKUP_FILE}" | psql \
  --host "${DB_HOST}" \
  --port "${DB_PORT}" \
  --username "${DB_USER}" \
  --dbname "${DB_NAME}" \
  --set ON_ERROR_STOP=1 \
  --single-transaction

echo "[*] Executando verificacao pos-restore..."
psql --host "${DB_HOST}" --port "${DB_PORT}" --username "${DB_USER}" --dbname "${DB_NAME}" --set ON_ERROR_STOP=1 <<'SQL'
SELECT current_database() AS database,
       (SELECT COUNT(*) FROM usuarios) AS usuarios,
       (SELECT COUNT(*) FROM reservas) AS reservas,
       (SELECT COUNT(*) FROM auditoria_acessos) AS auditoria_acessos;
SQL

echo "[+] Restore concluido e verificacao pos-restore executada."


