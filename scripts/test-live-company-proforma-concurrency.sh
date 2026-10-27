#!/usr/bin/env bash
set -euo pipefail

: "${PGHOST:?PGHOST is required}"
: "${PGPORT:?PGPORT is required}"
: "${PGUSER:?PGUSER is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
: "${PGDATABASE:?PGDATABASE is required}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_save() {
  psql -X -qAt -v ON_ERROR_STOP=1 <<'SQL'
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false);
SELECT (public.bokan_save_proforma(
  'PRIME',
  NULL,
  jsonb_build_object(
    'customer', 'Concurrent Test',
    'tin', '987654321',
    'date', current_date::text,
    'vatPct', 15,
    'discountPct', 0,
    'items', jsonb_build_array(jsonb_build_object(
      'description', 'Concurrency test item', 'qty', 1, 'unit_price', 1000
    )),
    'terms', jsonb_build_array()
  )
)).proforma_no;
SQL
}

run_save >"$tmpdir/first" &
pid1=$!
run_save >"$tmpdir/second" &
pid2=$!
wait "$pid1"
wait "$pid2"

first="$(tail -n 1 "$tmpdir/first" | tr -d '[:space:]')"
second="$(tail -n 1 "$tmpdir/second" | tr -d '[:space:]')"
if [[ -z "$first" || -z "$second" || "$first" == "$second" ]]; then
  echo "FAIL: concurrent saves returned blank or duplicate numbers: '$first' '$second'" >&2
  exit 1
fi
if [[ "$first" != "CONCU1000" && "$first" != "CONCU1001" ]]; then
  echo "FAIL: unexpected first concurrent number: $first" >&2
  exit 1
fi
if [[ "$second" != "CONCU1000" && "$second" != "CONCU1001" ]]; then
  echo "FAIL: unexpected second concurrent number: $second" >&2
  exit 1
fi
echo "PASS: concurrent UUID-company Proforma saves allocate distinct numbers ($first, $second)"
