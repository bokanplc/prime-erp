-- Private tenant-scoped document storage.
begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bokan-erp-documents',
  'bokan-erp-documents',
  false,
  10485760,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists bokan_documents_member_read on storage.objects;
create policy bokan_documents_member_read
on storage.objects for select to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and coalesce((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$', false)
  and private.is_company_member(((storage.foldername(name))[1])::uuid)
);

drop policy if exists bokan_documents_workspace_upload on storage.objects;
create policy bokan_documents_workspace_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'bokan-erp-documents'
  and coalesce((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$', false)
  and private.has_company_role(
    ((storage.foldername(name))[1])::uuid,
    array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[]
  )
);

drop policy if exists bokan_documents_workspace_update on storage.objects;
create policy bokan_documents_workspace_update
on storage.objects for update to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and coalesce((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$', false)
  and private.has_company_role(
    ((storage.foldername(name))[1])::uuid,
    array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[]
  )
)
with check (
  bucket_id = 'bokan-erp-documents'
  and coalesce((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$', false)
  and private.has_company_role(
    ((storage.foldername(name))[1])::uuid,
    array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[]
  )
);

drop policy if exists bokan_documents_manager_delete on storage.objects;
create policy bokan_documents_manager_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and coalesce((storage.foldername(name))[1] ~* '^[0-9a-f-]{36}$', false)
  and private.has_company_role(
    ((storage.foldername(name))[1])::uuid,
    array['owner','admin','manager']::public.company_role[]
  )
);

commit;
