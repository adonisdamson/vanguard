-- 0023_operator_avatars.sql — operators get profile photos.
-- Stored in the existing private member-photos bucket under the operator's
-- own uid folder, displayed via signed URLs like member photos.

alter table app_users add column if not exists avatar_path text;

-- The old insert policy limited uploads to personnel/admin (member photos).
-- Operators of EVERY role need to upload their own avatar; ownership is
-- still enforced by the own-folder check.
drop policy if exists member_photos_insert on storage.objects;
create policy member_photos_insert on storage.objects for insert
with check (
  bucket_id = 'member-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
  and auth.role() = 'authenticated'
);
