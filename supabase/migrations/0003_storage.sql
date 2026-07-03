-- Create the bucket (private)
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', false)
on conflict (id) do nothing;

-- Any authenticated operator can view photos (needed for review + directory screens)
create policy member_photos_select on storage.objects for select
using (bucket_id = 'member-photos' and auth.role() = 'authenticated');

-- Personnel/Admin can upload only into their own UID-named folder
create policy member_photos_insert on storage.objects for insert
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and get_my_role() in ('personnel', 'admin')
);

-- Same rule for replacing a photo
create policy member_photos_update on storage.objects for update
using (
  bucket_id = 'member-photos'
  and ((storage.foldername(name))[1] = auth.uid()::text or get_my_role() = 'admin')
);

-- Only admin can delete photos outright
create policy member_photos_delete on storage.objects for delete
using (bucket_id = 'member-photos' and get_my_role() = 'admin');
