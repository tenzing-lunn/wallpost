-- Phase 1 media storage: two private buckets, locked by the same rule as posts.
-- Files live at {post_id}/{file}; Storage RLS reads the post id from the path
-- and runs can_see_post() on every request, so a copied link is useless to
-- anyone who couldn't see the post.

-- ─── Buckets ────────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('wall-media',   'wall-media',   false, 52428800,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime']),
  ('public-media', 'public-media', false, 52428800,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'video/mp4', 'video/quicktime']);

-- ─── Helpers ────────────────────────────────────────────────────────────────

-- First folder of an object path as a post id, or null if it isn't a uuid.
create function public.path_post_id(object_name text)
returns uuid
language sql immutable set search_path = ''
as $$
  select case
    when split_part(object_name, '/', 1)
         ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(object_name, '/', 1)::uuid
  end;
$$;

-- You can upload only into your own post's folder, in the bucket matching its kind.
create function public.can_upload_media(bucket text, object_name text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.posts
    where id = public.path_post_id(object_name)
      and author_id = auth.uid()
      and kind = case bucket when 'wall-media'   then 'wall'
                             when 'public-media' then 'public' end
  );
$$;

-- A post_media row must point inside its own post's folder.
alter table public.post_media
  add constraint post_media_path_in_post_folder
  check (storage_path like post_id::text || '/%');

-- ─── Storage RLS ────────────────────────────────────────────────────────────

create policy "open media of posts I can see" on storage.objects
  for select to authenticated
  using (bucket_id in ('wall-media', 'public-media')
         and public.can_see_post(public.path_post_id(name)));

create policy "upload media to my posts" on storage.objects
  for insert to authenticated
  with check (bucket_id in ('wall-media', 'public-media')
              and public.can_upload_media(bucket_id, name));

create policy "replace media on my posts" on storage.objects
  for update to authenticated
  using (bucket_id in ('wall-media', 'public-media')
         and public.can_upload_media(bucket_id, name))
  with check (bucket_id in ('wall-media', 'public-media')
              and public.can_upload_media(bucket_id, name));

create policy "delete media from my posts" on storage.objects
  for delete to authenticated
  using (bucket_id in ('wall-media', 'public-media')
         and public.is_post_author(public.path_post_id(name)));
