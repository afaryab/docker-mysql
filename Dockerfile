# syntax=docker/dockerfile:1
FROM mysql:8.0

# Install cron & tzdata (for schedules), plus openssl (optional encryption)
RUN microdnf update && microdnf install -y \
      cronie tzdata ca-certificates openssl \
  && microdnf clean all

# Backup location (mount this as a volume in production)
ENV BACKUP_DIR=/backups

# Schedules (cron expressions)
ENV BACKUP_CRON="0 3 * * *" \
    USAGE_CRON="5 3 * * *" \
    PRUNE_CRON="15 3 * * *"

# Retention (set either/both)
ENV RETAIN_DAYS="" \
    RETAIN_COUNT=""

# Extra mysqldump options (tune as needed)
ENV MYSQL_BACKUP_OPTS="--single-transaction --routines --events --triggers --hex-blob --default-character-set=utf8mb4 --set-gtid-purged=OFF"

# Optional at-rest encryption for backups:
#   BACKUP_ENCRYPT="aes-256-cbc"   (any OpenSSL cipher)
#   BACKUP_ENCRYPT_PASSWORD="your-strong-passphrase"
ENV BACKUP_ENCRYPT="" \
    BACKUP_ENCRYPT_PASSWORD="" \
    AUTO_RECOVER="true"

# Timezone for cron
ENV TZ=UTC

# --- Backup script ---
ADD --chown=root:root <<'EOF' /usr/local/bin/backup.sh
#!/usr/bin/env bash
set -Eeuo pipefail

: "${BACKUP_DIR:=/backups}"
mkdir -p "${BACKUP_DIR}"

STAMP="$(date +%F_%H-%M-%S)"
HOST="${HOSTNAME:-mysql}"
BASENAME="mysql-${HOST}-${STAMP}.sql.gz"
OUT="${BACKUP_DIR}/${BASENAME}"

# Prefer socket auth inside the same container
SOCKET="/var/run/mysqld/mysqld.sock"

# Root auth via env provided by MySQL image (MYSQL_ROOT_PASSWORD)
if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  echo "[backup] ERROR: MYSQL_ROOT_PASSWORD is not set." >&2
  exit 1
fi

echo "[backup] Starting dump at ${STAMP}..."
# Dump all databases (skip transient schemas via --ignore-table wildcards if desired)
# NOTE: performance_schema & sys are tiny; keeping them is harmless. Adjust if you prefer.
set -o pipefail
if [[ -n "${BACKUP_ENCRYPT}" && -n "${BACKUP_ENCRYPT_PASSWORD}" ]]; then
  mysqldump \
    --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
    --all-databases ${MYSQL_BACKUP_OPTS} \
  | gzip -9 \
  | openssl enc -"${BACKUP_ENCRYPT}" -pass env:BACKUP_ENCRYPT_PASSWORD -salt \
  > "${OUT}.enc"
  FINAL="${OUT}.enc"
else
  mysqldump \
    --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" \
    --all-databases ${MYSQL_BACKUP_OPTS} \
  | gzip -9 > "${OUT}"
  FINAL="${OUT}"
fi

# Write a small sidecar manifest
cat > "${FINAL}.meta.json" <<JSON
{
  "created_at": "$(date -Is)",
  "host": "${HOST}",
  "file": "$(basename "${FINAL}")",
  "encrypted": $( [[ -n "${BACKUP_ENCRYPT}" && -n "${BACKUP_ENCRYPT_PASSWORD}" ]] && echo true || echo false )
}
JSON

echo "[backup] Completed: ${FINAL}"
EOF
RUN chmod +x /usr/local/bin/backup.sh

# --- Prune script ---
ADD --chown=root:root <<'EOF' /usr/local/bin/prune_backups.sh
#!/usr/bin/env bash
set -Eeuo pipefail

: "${BACKUP_DIR:=/backups}"
: "${RETAIN_DAYS:=}"
: "${RETAIN_COUNT:=}"

mkdir -p "${BACKUP_DIR}"

echo "[prune] Running prune policy..."

# Prune by age (days)
if [[ -n "${RETAIN_DAYS}" ]]; then
  if [[ "${RETAIN_DAYS}" =~ ^[0-9]+$ ]]; then
    # Remove .gz, .enc, and .meta.json older than RETAIN_DAYS
    find "${BACKUP_DIR}" -type f \( -name '*.sql.gz' -o -name '*.sql.gz.enc' -o -name '*.meta.json' \) -mtime +"${RETAIN_DAYS}" -print -delete
    echo "[prune] Deleted files older than ${RETAIN_DAYS} days."
  else
    echo "[prune] WARN: RETAIN_DAYS is not an integer, skipping age prune."
  fi
fi

# Prune by count (keep newest N)
if [[ -n "${RETAIN_COUNT}" ]]; then
  if [[ "${RETAIN_COUNT}" =~ ^[0-9]+$ ]]; then
    # Work on base backups (either .gz or .gz.enc)
    mapfile -t files < <(ls -1t "${BACKUP_DIR}"/mysql-*.sql.gz* 2>/dev/null || true)
    if (( ${#files[@]} > RETAIN_COUNT )); then
      to_delete=( "${files[@]:${RETAIN_COUNT}}" )
      for f in "${to_delete[@]}"; do
        echo "[prune] Deleting ${f}"
        rm -f -- "$f"
        # Remove sidecar meta if present
        rm -f -- "${f}.meta.json" "${f%.enc}.meta.json" 2>/dev/null || true
      done
      echo "[prune] Kept latest ${RETAIN_COUNT}; pruned $((${#to_delete[@]})) older backups."
    else
      echo "[prune] Nothing to prune by count (have ${#files[@]}, keep ${RETAIN_COUNT})."
    fi
  else
    echo "[prune] WARN: RETAIN_COUNT is not an integer, skipping count prune."
  fi
fi

echo "[prune] Done."
EOF
RUN chmod +x /usr/local/bin/prune_backups.sh

# --- Usage report script ---
ADD --chown=root:root <<'EOF' /usr/local/bin/usage_report.sh
#!/usr/bin/env bash
set -Eeuo pipefail

: "${BACKUP_DIR:=/backups}"
mkdir -p "${BACKUP_DIR}/usage"

SOCKET="/var/run/mysqld/mysqld.sock"

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  echo "[usage] ERROR: MYSQL_ROOT_PASSWORD is not set." >&2
  exit 1
fi

STAMP_DATE="$(date +%F)"
OUT="${BACKUP_DIR}/usage/${STAMP_DATE}.json"

# DB sizes by schema as JSON (MySQL 8+)
DB_JSON="$(mysql --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "
  SELECT COALESCE(
    JSON_OBJECTAGG(
      table_schema,
      JSON_OBJECT(
        'size_bytes', CAST(SUM(data_length + index_length) AS UNSIGNED),
        'table_count', COUNT(*),
        'row_estimate', CAST(SUM(table_rows) AS UNSIGNED)
      )
    ),
    JSON_OBJECT()
  )
  FROM information_schema.tables
  WHERE table_schema NOT IN ('information_schema','performance_schema','mysql','sys');
")"

# Global status snippets
UPTIME="$(mysql --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "
  SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='UPTIME';
" || echo 0)"

THREADS="$(mysql --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "
  SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME='THREADS_CONNECTED';
" || echo 0)"

# Data directory apparent size
DATADIR="$(mysql --protocol=SOCKET --socket="${SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "SHOW VARIABLES LIKE 'datadir';" | awk '{print $2}')"
DATADIR_BYTES="$(du -sb "${DATADIR:-/var/lib/mysql}" 2>/dev/null | awk '{print $1}')"

# Backups directory size
BACKUPS_BYTES="$(du -sb "${BACKUP_DIR}" 2>/dev/null | awk '{print $1}')"

cat > "${OUT}" <<JSON
{
  "timestamp": "$(date -Is)",
  "host": "${HOSTNAME:-mysql}",
  "uptime_seconds": ${UPTIME:-0},
  "threads_connected": ${THREADS:-0},
  "datadir_bytes": ${DATADIR_BYTES:-0},
  "backups_dir_bytes": ${BACKUPS_BYTES:-0},
  "databases": ${DB_JSON:-{}}
}
JSON

echo "[usage] Wrote ${OUT}"
EOF
RUN chmod +x /usr/local/bin/usage_report.sh

# --- Auto-recovery script ---
ADD --chown=root:root <<'EOF' /usr/local/bin/auto_recover.sh
#!/usr/bin/env bash
set -Eeuo pipefail

: "${BACKUP_DIR:=/backups}"
: "${MYSQL_ROOT_PASSWORD:=}"
: "${AUTO_RECOVER:=true}"

# Only attempt recovery if AUTO_RECOVER is enabled
if [[ "${AUTO_RECOVER}" != "true" ]]; then
  echo "[recovery] Auto-recovery disabled (AUTO_RECOVER != true)"
  exit 0
fi

# Check if this is a fresh MySQL installation (no existing databases)
DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
if [[ -f "${DATADIR}/mysql/user.frm" ]] || [[ -f "${DATADIR}/mysql/user.MYD" ]] || [[ -d "${DATADIR}/mysql" ]] || [[ -f "${DATADIR}/auto.cnf" ]]; then
  echo "[recovery] MySQL data directory appears to have existing data, skipping recovery"
  exit 0
fi

echo "[recovery] Fresh MySQL installation detected, checking for backups..."

if [[ ! -d "${BACKUP_DIR}" ]]; then
  echo "[recovery] No backup directory found at ${BACKUP_DIR}, proceeding with fresh install"
  exit 0
fi

# Find the latest backup file
LATEST_BACKUP=""
if ls "${BACKUP_DIR}"/mysql-*.sql.gz.enc >/dev/null 2>&1; then
  LATEST_BACKUP="$(ls -1t "${BACKUP_DIR}"/mysql-*.sql.gz.enc | head -1)"
elif ls "${BACKUP_DIR}"/mysql-*.sql.gz >/dev/null 2>&1; then
  LATEST_BACKUP="$(ls -1t "${BACKUP_DIR}"/mysql-*.sql.gz | head -1)"
fi

if [[ -z "${LATEST_BACKUP}" ]]; then
  echo "[recovery] No backup files found, proceeding with fresh install"
  exit 0
fi

echo "[recovery] Found latest backup: ${LATEST_BACKUP}"

# Start MySQL temporarily for restoration
echo "[recovery] Starting MySQL for restoration..."
mysqld --user=mysql --datadir="${DATADIR}" --skip-networking --socket=/tmp/mysql_recovery.sock &
MYSQL_PID=$!

# Wait for MySQL to be ready
for i in {1..30}; do
  if mysql --protocol=SOCKET --socket=/tmp/mysql_recovery.sock -e "SELECT 1" >/dev/null 2>&1; then
    echo "[recovery] MySQL is ready for restoration"
    break
  fi
  echo "[recovery] Waiting for MySQL to start... ($i/30)"
  sleep 2
done

# Check if MySQL started successfully
if ! mysql --protocol=SOCKET --socket=/tmp/mysql_recovery.sock -e "SELECT 1" >/dev/null 2>&1; then
  echo "[recovery] ERROR: Failed to start MySQL for recovery"
  kill $MYSQL_PID 2>/dev/null || true
  exit 1
fi

# Restore from backup
echo "[recovery] Restoring from backup..."
set -o pipefail

if [[ "${LATEST_BACKUP}" == *.enc ]]; then
  # Encrypted backup
  if [[ -z "${BACKUP_ENCRYPT_PASSWORD:-}" ]]; then
    echo "[recovery] ERROR: Encrypted backup found but BACKUP_ENCRYPT_PASSWORD not set"
    kill $MYSQL_PID 2>/dev/null || true
    exit 1
  fi
  
  openssl enc -d -"${BACKUP_ENCRYPT:-aes-256-cbc}" -pass env:BACKUP_ENCRYPT_PASSWORD -salt -in "${LATEST_BACKUP}" \
  | gunzip \
  | mysql --protocol=SOCKET --socket=/tmp/mysql_recovery.sock
else
  # Unencrypted backup
  gunzip -c "${LATEST_BACKUP}" \
  | mysql --protocol=SOCKET --socket=/tmp/mysql_recovery.sock
fi

echo "[recovery] Backup restoration completed successfully"

# Stop the temporary MySQL instance
kill $MYSQL_PID 2>/dev/null || true
wait $MYSQL_PID 2>/dev/null || true

echo "[recovery] Recovery process completed"
EOF
RUN chmod +x /usr/local/bin/auto_recover.sh

# --- Entrypoint wrapper: auto-recovery, start cron, install crontab, then exec upstream ---
ADD --chown=root:root <<'EOF' /usr/local/bin/start-with-cron.sh
#!/usr/bin/env bash
set -Eeuo pipefail

: "${BACKUP_CRON:=0 3 * * *}"
: "${USAGE_CRON:=5 3 * * *}"
: "${PRUNE_CRON:=15 3 * * *}"
: "${AUTO_RECOVER:=true}"

mkdir -p "${BACKUP_DIR:-/backups}"

# Attempt auto-recovery from latest backup if fresh install
if [[ "${AUTO_RECOVER}" == "true" ]]; then
  echo "[init] Checking for auto-recovery..."
  /usr/local/bin/auto_recover.sh || true
fi

# Build root's crontab (cron picks up env via explicit export block)
CRON_ENV_BLOCK=$(cat <<ENV
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TZ=${TZ:-UTC}
BACKUP_DIR=${BACKUP_DIR:-/backups}
RETAIN_DAYS=${RETAIN_DAYS:-}
RETAIN_COUNT=${RETAIN_COUNT:-}
MYSQL_BACKUP_OPTS=${MYSQL_BACKUP_OPTS:-}
BACKUP_ENCRYPT=${BACKUP_ENCRYPT:-}
BACKUP_ENCRYPT_PASSWORD=${BACKUP_ENCRYPT_PASSWORD:-}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-}
AUTO_RECOVER=${AUTO_RECOVER:-true}
ENV
)

CRON_FILE="/tmp/cron.$$"
{
  echo "${CRON_ENV_BLOCK}"
  echo "${BACKUP_CRON}   /usr/local/bin/backup.sh >> /proc/1/fd/1 2>&1"
  echo "${USAGE_CRON}    /usr/local/bin/usage_report.sh >> /proc/1/fd/1 2>&1"
  echo "${PRUNE_CRON}    /usr/local/bin/prune_backups.sh >> /proc/1/fd/1 2>&1"
} > "${CRON_FILE}"

crontab "${CRON_FILE}"
rm -f "${CRON_FILE}"

# Start cron in background (using crond)
crond || service cron start >/dev/null 2>&1

# Hand off to the original MySQL entrypoint/CMD
exec /entrypoint.sh "$@"
EOF
RUN chmod +x /usr/local/bin/start-with-cron.sh

# Keep upstream entrypoint, just change CMD to our wrapper
ENTRYPOINT ["/usr/local/bin/start-with-cron.sh"]
CMD ["mysqld"]
