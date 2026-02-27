#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <target_db_url> <schema_dump> <data_dump> [roles_dump]" >&2
  exit 1
fi

target_db_url="$1"
schema_dump="$2"
data_dump="$3"
roles_dump="${4:-}"

if [[ ! -f "$schema_dump" ]]; then
  echo "Schema dump not found: $schema_dump" >&2
  exit 1
fi

if [[ ! -f "$data_dump" ]]; then
  echo "Data dump not found: $data_dump" >&2
  exit 1
fi

if [[ "${schema_dump##*.}" == "enc" || "${data_dump##*.}" == "enc" || ( -n "$roles_dump" && "${roles_dump##*.}" == "enc" ) ]]; then
  if [[ -z "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]]; then
    echo "BACKUP_ENCRYPTION_PASSPHRASE must be set to decrypt .enc artifacts." >&2
    exit 1
  fi
fi

workdir="$(mktemp -d)"
cleanup() {
  rm -rf "$workdir"
}
trap cleanup EXIT

prepare_dump() {
  local source_file="$1"
  local target_file="$2"
  if [[ "${source_file##*.}" == "enc" ]]; then
    openssl enc -d -aes-256-cbc -pbkdf2 -in "$source_file" -out "$target_file" -pass env:BACKUP_ENCRYPTION_PASSPHRASE
  else
    cp "$source_file" "$target_file"
  fi
}

prepared_schema="${workdir}/schema.sql"
prepared_data="${workdir}/data.sql"
prepare_dump "$schema_dump" "$prepared_schema"
prepare_dump "$data_dump" "$prepared_data"

psql "$target_db_url" -v ON_ERROR_STOP=1 -f "$prepared_schema"

if [[ -n "$roles_dump" ]]; then
  if [[ ! -f "$roles_dump" ]]; then
    echo "Roles dump not found: $roles_dump" >&2
    exit 1
  fi
  prepared_roles="${workdir}/roles.sql"
  prepare_dump "$roles_dump" "$prepared_roles"
  if [[ "${RESTORE_INCLUDE_ROLES:-false}" == "true" ]]; then
    psql "$target_db_url" -v ON_ERROR_STOP=1 -f "$prepared_roles"
  fi
fi

psql "$target_db_url" -v ON_ERROR_STOP=1 -f "$prepared_data"

echo "Restore complete. Running basic verification queries..."
psql "$target_db_url" -v ON_ERROR_STOP=1 <<'SQL'
select 'profiles' as table_name, count(*) as row_count from public.profiles
union all
select 'habits', count(*) from public.habits
union all
select 'habit_completions', count(*) from public.habit_completions
union all
select 'groups', count(*) from public.groups
union all
select 'quotes', count(*) from public.quotes;
SQL

echo "Restore verification finished."
