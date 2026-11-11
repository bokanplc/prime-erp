-- Permit an uploader to remove an unregistered file after a failed metadata save.
begin;
drop policy if exists bokan_documents_uploader_cleanup on storage.objects;
create policy bokan_documents_uploader_cleanup
on storage.objects for delete to authenticated
using (
  bucket_id = 'bokan-erp-documents'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1 from public.company_memberships m
    where m.company_id::text = (storage.foldername(name))[1]
      and m.user_id = (select auth.uid())
      and m.is_active = true
  )
);
commit;
