-- Add a covering B-tree index for each public-schema foreign key that has
-- no existing valid index with the FK columns as its leading key columns.
-- This is additive only: it does not change data, constraints, RLS, or grants.
do $$
declare
  fk record;
  column_list text;
  index_name text;
begin
  for fk in
    select c.conname,
           c.conrelid,
           c.conkey,
           n.nspname as schema_name,
           t.relname as table_name
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1
        from pg_index i
        where i.indrelid = c.conrelid
          and i.indisvalid
          and i.indisready
          and (
            select array_agg(i.indkey[k] order by k)
            from generate_series(0, array_length(c.conkey, 1) - 1) k
          ) = c.conkey
      )
  loop
    select string_agg(format('%I', a.attname), ', ' order by u.ord)
      into column_list
    from unnest(fk.conkey) with ordinality as u(attnum, ord)
    join pg_attribute a
      on a.attrelid = fk.conrelid
     and a.attnum = u.attnum;

    index_name := 'idx_fk_' || left(fk.table_name, 18) || '_' || substr(md5(fk.conname), 1, 12);
    execute format(
      'create index if not exists %I on %I.%I (%s)',
      index_name, fk.schema_name, fk.table_name, column_list
    );
  end loop;
end
$$;
