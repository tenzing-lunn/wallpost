-- Phase 1 posts: wall + public posts, media, comments, likes, tags, reports.
-- See Context.md → Walls / Feeds for the product rules this enforces.

-- ─── Tables ─────────────────────────────────────────────────────────────────

-- Only the author posts. kind decides who can read:
--   wall   → the author's connections
--   public → anyone at the author's school (and followers' home feeds)
create table public.posts (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in ('wall', 'public')),
  body       text,
  link_url   text,                         -- preview generated in a later step
  location   text,                         -- free-text place name, never GPS
  hashtags   text[] not null default '{}', -- stored lowercase, without '#'
  created_at timestamptz not null default now(),
  edited_at  timestamptz
);

create index posts_author_created_idx on public.posts (author_id, created_at desc);
create index posts_hashtags_idx on public.posts using gin (hashtags);

-- One row per photo/video, in display order. Files live in Storage (next step).
create table public.post_media (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.posts (id) on delete cascade,
  position     int  not null check (position >= 0),
  media_type   text not null check (media_type in ('photo', 'video')),
  storage_path text not null,
  unique (post_id, position)
);

create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id) on delete cascade,
  body       text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index comments_post_idx on public.comments (post_id, created_at);

-- Same pattern as follows: the pair is the key, so a double like is impossible.
create table public.likes (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  post_id    uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create index likes_post_idx on public.likes (post_id);

-- A tag on a post (comment_id null) or on a comment of that post.
create table public.tags (
  id             uuid primary key default gen_random_uuid(),
  post_id        uuid not null references public.posts (id) on delete cascade,
  comment_id     uuid references public.comments (id) on delete cascade,
  tagged_user_id uuid not null references public.profiles (id) on delete cascade,
  tagged_by      uuid not null references public.profiles (id) on delete cascade,
  created_at     timestamptz not null default now(),
  unique nulls not distinct (post_id, comment_id, tagged_user_id)
);

create index tags_tagged_user_idx on public.tags (tagged_user_id);

-- Write-only for users; reviewed by admins with the service role.
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  post_id     uuid not null references public.posts (id) on delete cascade,
  comment_id  uuid references public.comments (id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now()
);

-- ─── Helpers ────────────────────────────────────────────────────────────────

-- The single visibility rule every post-related table reuses.
create function public.can_see_post(p uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.posts po
    where po.id = p
      and (
        po.author_id = auth.uid()
        or (po.kind = 'public' and public.same_school(po.author_id))
        or (po.kind = 'wall'   and public.are_connected(auth.uid(), po.author_id))
      )
  );
$$;

create function public.is_post_author(p uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.posts where id = p and author_id = auth.uid());
$$;

-- ─── Triggers ───────────────────────────────────────────────────────────────

-- Hashtags: lowercase, no '#', no blanks or duplicates.
-- Edits: author and kind are fixed; edited_at is stamped.
create function public.before_post_write()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.hashtags := coalesce(array(
    select distinct lower(ltrim(trim(t), '#'))
    from unnest(new.hashtags) as t
    where ltrim(trim(t), '#') <> ''
  ), '{}');

  if tg_op = 'UPDATE' then
    if new.author_id <> old.author_id or new.kind <> old.kind then
      raise exception 'cannot change a post''s author or kind';
    end if;
    new.created_at := old.created_at;
    new.edited_at := now();
  end if;
  return new;
end;
$$;

create trigger posts_before_write
  before insert or update on public.posts
  for each row execute function public.before_post_write();

-- Tags: you can only tag your own connections, only in your own post or comment.
create function public.before_tag_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.are_connected(new.tagged_by, new.tagged_user_id) then
    raise exception 'you can only tag your connections';
  end if;

  if new.comment_id is null then
    if not exists (select 1 from public.posts
                   where id = new.post_id and author_id = new.tagged_by) then
      raise exception 'you can only tag people in your own posts';
    end if;
  else
    if not exists (select 1 from public.comments
                   where id = new.comment_id and post_id = new.post_id
                     and author_id = new.tagged_by) then
      raise exception 'you can only tag people in your own comments';
    end if;
  end if;
  return new;
end;
$$;

create trigger tags_before_insert
  before insert on public.tags
  for each row execute function public.before_tag_insert();

-- ─── Row Level Security ─────────────────────────────────────────────────────

alter table public.posts      enable row level security;
alter table public.post_media enable row level security;
alter table public.comments   enable row level security;
alter table public.likes      enable row level security;
alter table public.tags       enable row level security;
alter table public.reports    enable row level security;

-- posts
create policy "read posts I'm allowed to see" on public.posts
  for select to authenticated using (public.can_see_post(id));
create policy "post as myself" on public.posts
  for insert to authenticated with check (author_id = auth.uid());
create policy "edit my posts" on public.posts
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "delete my posts" on public.posts
  for delete to authenticated using (author_id = auth.uid());

-- post_media: visible with the post; managed by the post's author.
create policy "read media of visible posts" on public.post_media
  for select to authenticated using (public.can_see_post(post_id));
create policy "add media to my posts" on public.post_media
  for insert to authenticated with check (public.is_post_author(post_id));
create policy "update media on my posts" on public.post_media
  for update to authenticated
  using (public.is_post_author(post_id)) with check (public.is_post_author(post_id));
create policy "remove media from my posts" on public.post_media
  for delete to authenticated using (public.is_post_author(post_id));

-- comments: if you can see the post, you can comment.
create policy "read comments on visible posts" on public.comments
  for select to authenticated using (public.can_see_post(post_id));
create policy "comment on visible posts" on public.comments
  for insert to authenticated
  with check (author_id = auth.uid() and public.can_see_post(post_id));
create policy "delete my comments or comments on my posts" on public.comments
  for delete to authenticated
  using (author_id = auth.uid() or public.is_post_author(post_id));

-- likes
create policy "read likes on visible posts" on public.likes
  for select to authenticated using (public.can_see_post(post_id));
create policy "like visible posts" on public.likes
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_see_post(post_id));
create policy "unlike" on public.likes
  for delete to authenticated using (user_id = auth.uid());

-- tags: the tagged person always sees their own tag (for the "connect to see" prompt);
-- everyone else sees tags only on posts they can see.
create policy "read my tags and tags on visible posts" on public.tags
  for select to authenticated
  using (tagged_user_id = auth.uid() or public.can_see_post(post_id));
create policy "tag as myself" on public.tags
  for insert to authenticated with check (tagged_by = auth.uid());
create policy "untag myself or remove my tags" on public.tags
  for delete to authenticated
  using (tagged_user_id = auth.uid() or tagged_by = auth.uid());

-- reports: anyone who can see a post can report it; no user can read reports.
create policy "report visible posts" on public.reports
  for insert to authenticated
  with check (reporter_id = auth.uid() and public.can_see_post(post_id));

-- ─── Read helpers for the app ───────────────────────────────────────────────

-- Locked wall: one row per wall post with only its shape. No text, author, or time.
create function public.wall_preview(owner uuid)
returns table (shape text)
language sql stable security definer set search_path = ''
as $$
  select case
           when exists (select 1 from public.post_media m
                        where m.post_id = p.id and m.media_type = 'video') then 'video'
           when exists (select 1 from public.post_media m
                        where m.post_id = p.id) then 'photo'
           else 'text'
         end
  from public.posts p
  where p.author_id = owner
    and p.kind = 'wall'
    and (owner = auth.uid() or public.same_school(owner))
  order by p.created_at desc;
$$;

-- My tags, with whose post they're on and whether I can see it yet.
create function public.my_tags()
returns table (tag_id uuid, post_id uuid, comment_id uuid, tagged_by uuid,
               post_author_id uuid, can_see boolean)
language sql stable security definer set search_path = ''
as $$
  select t.id, t.post_id, t.comment_id, t.tagged_by, p.author_id, public.can_see_post(p.id)
  from public.tags t
  join public.posts p on p.id = t.post_id
  where t.tagged_user_id = auth.uid();
$$;

-- Home feed: my posts, public posts from people I follow, wall posts from my connections.
-- RLS still applies (security_invoker). The app orders by created_at.
create view public.home_feed with (security_invoker = true) as
select p.*
from public.posts p
where p.author_id = auth.uid()
   or (p.kind = 'public' and exists (
         select 1 from public.follows f
         where f.follower_id = auth.uid() and f.followed_id = p.author_id))
   or (p.kind = 'wall' and public.are_connected(auth.uid(), p.author_id));
