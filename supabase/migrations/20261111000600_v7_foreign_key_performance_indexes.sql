-- Cover every public-schema foreign key with a matching leading-column index.
-- Additive only: no business data or stock/accounting structures are created.
do $v7_indexes$
declare
  fk record;
  is_covered boolean;
  index_name text;
begin
  for fk in
    select
      c.conrelid as table_oid,
      c.conname as constraint_name,
      c.conkey as key_columns,
      n.nspname as schema_name,
      t.relname as table_name,
      string_agg(format('%I', a.attname), ', ' order by k.ord) as column_list
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    cross join lateral unnest(c.conkey) with ordinality as k(attnum, ord)
    join pg_attribute a on a.attrelid = t.oid and a.attnum = k.attnum
    where c.contype = 'f' and n.nspname = 'public'
    group by c.conrelid, c.conname, c.conkey, n.nspname, t.relname
  loop
    select exists (
      select 1
      from pg_index i
      where i.indrelid = fk.table_oid
        and i.indisvalid
        and i.indisready
        and (
          select array_agg(x.attnum::smallint order by x.ord)
          from unnest(i.indkey) with ordinality as x(attnum, ord)
          where x.ord <= cardinality(fk.key_columns)
        ) = fk.key_columns
    ) into is_covered;

    if not is_covered then
      index_name := left(
        'idx_' || fk.table_name || '_' || substr(md5(fk.constraint_name), 1, 10),
        63
      );
      execute format(
        'create index if not exists %I on %I.%I (%s)',
        index_name,
        fk.schema_name,
        fk.table_name,
        fk.column_list
      );
    end if;
  end loop;
end
$v7_indexes$;
