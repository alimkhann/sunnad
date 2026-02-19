#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <target_db_url> <dump_file.sql>" >&2
  exit 1
fi

target_db_url="$1"
dump_file="$2"

if [[ ! -f "$dump_file" ]]; then
  echo "Dump file not found: $dump_file" >&2
  exit 1
fi

psql "$target_db_url" -v ON_ERROR_STOP=1 -f "$dump_file"

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
