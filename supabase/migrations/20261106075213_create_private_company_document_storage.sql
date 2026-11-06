insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bokan-company-documents',
  'bokan-company-documents',
  false,
  26214400,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "BOKAN company members read own documents"
on storage.objects for select
to authenticated
using (
  bucket_id = 'bokan-company-documents'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = ((storage.foldername(name))[1])::uuid
      and m.user_id = (select auth.uid()) and m.is_active
  )
);

create policy "BOKAN company members upload own documents"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'bokan-company-documents'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = ((storage.foldername(name))[1])::uuid
      and m.user_id = (select auth.uid()) and m.is_active
  )
);

create policy "BOKAN company managers update own documents"
on storage.objects for update
to authenticated
using (
  bucket_id = 'bokan-company-documents'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = ((storage.foldername(name))[1])::uuid
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
)
with check (
  bucket_id = 'bokan-company-documents'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = ((storage.foldername(name))[1])::uuid
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);

create policy "BOKAN company managers delete own documents"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'bokan-company-documents'
  and coalesce((storage.foldername(name))[1], '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id = ((storage.foldername(name))[1])::uuid
      and m.user_id = (select auth.uid()) and m.is_active
      and m.role in ('owner','admin','manager')
  )
);