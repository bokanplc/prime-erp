-- Harden storage folder membership checks without casting user-controlled paths.
begin;

drop policy if exists bokan_documents_member_read on storage.objects;
create policy bokan_documents_member_read
on storage.objects for select to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
  )
);

drop policy if exists bokan_documents_workspace_upload on storage.objects;
create policy bokan_documents_workspace_upload
on storage.objects for insert to authenticated
with check (
  bucket_id = 'bokan-erp-documents'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[])
  )
);

drop policy if exists bokan_documents_workspace_update on storage.objects;
create policy bokan_documents_workspace_update
on storage.objects for update to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[])
  )
)
with check (
  bucket_id = 'bokan-erp-documents'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(array['owner','admin','manager','sales','purchasing','operations','data_entry']::public.company_role[])
  )
);

drop policy if exists bokan_documents_manager_delete on storage.objects;
create policy bokan_documents_manager_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(array['owner','admin','manager']::public.company_role[])
  )
);

commit;
