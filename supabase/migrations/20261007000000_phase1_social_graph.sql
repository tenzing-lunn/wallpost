-- Phase 1 social graph: profiles, follows, connections.
-- See Context.md for the product rules this enforces.

-- ─── Tables ─────────────────────────────────────────────────────────────────

-- Base profile: visible to anyone at the same school.
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  school_domain text not null,            -- set from the verified email, never by the client
  name          text not null,
  photo_url     text,
  major         text,
  created_at    timestamptz not null default now()
);

-- Upgraded profile: visible only to the user and their connections.
-- Separate table because RLS grants access per row, not per column.
create table public.profile_details (
  id         uuid primary key references public.profiles (id) on delete cascade,
  birthdate  date                          -- age is computed from this
);

-- One row per direction: (A, B) means A follows B. No approval needed.
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followed_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

-- One row per pair. Declining deletes the row, so status is only pending/accepted.
create table public.connections (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  accepted_at  timestamptz,
  primary key (requester_id, recipient_id),
  check (requester_id <> recipient_id)
);

-- A→B and B→A are the same pair: allow only one row per pair, whichever direction.
create unique index connections_one_row_per_pair
  on public.connections (least(requester_id, recipient_id), greatest(requester_id, recipient_id));

create index follows_followed_idx on public.follows (followed_id);
create index connections_recipient_idx on public.connections (recipient_id);

-- ─── Helpers used by policies ───────────────────────────────────────────────
-- security definer so they can read the tables without re-triggering RLS.

create function public.my_school()
returns text
language sql stable security definer set search_path = ''
as $$
  select school_domain from public.profiles where id = auth.uid();
$$;

create function public.same_school(other uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = other and school_domain = public.my_school()
  );
$$;

create function public.are_connected(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.connections
    where status = 'accepted'
      and ((requester_id = a and recipient_id = b) or (requester_id = b and recipient_id = a))
  );
$$;

-- ─── Triggers ───────────────────────────────────────────────────────────────

-- school_domain comes from the verified auth email and can't be changed.
create function public.set_school_domain()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    new.school_domain := old.school_domain;
    return new;
  end if;

  select lower(split_part(email, '@', 2)) into new.school_domain
  from auth.users where id = new.id;

  if new.school_domain is null or new.school_domain = '' then
    raise exception 'profile has no verified email';
  end if;
  return new;
end;
$$;

create trigger profiles_set_school_domain
  before insert or update on public.profiles
  for each row execute function public.set_school_domain();

-- New request: always starts pending. If the other person already asked,
-- accept their request instead of creating a second row.
create function public.before_connection_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  new.status := 'pending';
  new.accepted_at := null;

  update public.connections
     set status = 'accepted'
   where requester_id = new.recipient_id
     and recipient_id = new.requester_id
     and status = 'pending';

  if found then
    return null;  -- the existing row was accepted; skip this insert
  end if;
  return new;
end;
$$;

create trigger connections_before_insert
  before insert on public.connections
  for each row execute function public.before_connection_insert();

-- Sending a request makes the sender follow the recipient.
create function public.after_connection_insert()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.follows (follower_id, followed_id)
  values (new.requester_id, new.recipient_id)
  on conflict do nothing;
  return new;
end;
$$;

create trigger connections_after_insert
  after insert on public.connections
  for each row execute function public.after_connection_insert();

-- The pair can't be changed; accepting stamps accepted_at.
create function public.before_connection_update()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.requester_id <> old.requester_id or new.recipient_id <> old.recipient_id then
    raise exception 'cannot change who a connection is between';
  end if;
  if old.status = 'pending' and new.status = 'accepted' then
    new.accepted_at := now();
  end if;
  return new;
end;
$$;

create trigger connections_before_update
  before update on public.connections
  for each row execute function public.before_connection_update();

-- Accepting means both people follow each other.
create function public.after_connection_accept()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.follows (follower_id, followed_id)
  values (new.requester_id, new.recipient_id),
         (new.recipient_id, new.requester_id)
  on conflict do nothing;
  return new;
end;
$$;

create trigger connections_after_accept
  after update on public.connections
  for each row
  when (old.status = 'pending' and new.status = 'accepted')
  execute function public.after_connection_accept();

-- Removing a connection: the remover stops following; the other person keeps following.
create function public.after_connection_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.status = 'accepted' and auth.uid() is not null then
    delete from public.follows
     where follower_id = auth.uid()
       and followed_id = case when auth.uid() = old.requester_id
                              then old.recipient_id else old.requester_id end;
  end if;
  return old;
end;
$$;

create trigger connections_after_delete
  after delete on public.connections
  for each row execute function public.after_connection_delete();

-- ─── Row Level Security ─────────────────────────────────────────────────────

alter table public.profiles        enable row level security;
alter table public.profile_details enable row level security;
alter table public.follows         enable row level security;
alter table public.connections     enable row level security;

-- profiles: anyone at your school can read; you manage your own.
create policy "read profiles at my school" on public.profiles
  for select to authenticated using (school_domain = public.my_school());
create policy "create my profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy "update my profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- profile_details: only you and your connections.
create policy "read details of me and my connections" on public.profile_details
  for select to authenticated
  using (id = auth.uid() or public.are_connected(auth.uid(), id));
create policy "create my details" on public.profile_details
  for insert to authenticated with check (id = auth.uid());
create policy "update my details" on public.profile_details
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- follows: visible at your school (for counts); you follow/unfollow as yourself.
create policy "read follows at my school" on public.follows
  for select to authenticated using (public.same_school(followed_id));
create policy "follow someone at my school" on public.follows
  for insert to authenticated
  with check (follower_id = auth.uid() and public.same_school(followed_id));
create policy "unfollow" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

-- connections: pending requests are private to the pair; accepted ones are visible at your school.
create policy "read my requests and connections at my school" on public.connections
  for select to authenticated
  using (
    auth.uid() in (requester_id, recipient_id)
    or (status = 'accepted' and public.same_school(requester_id))
  );
create policy "send a request" on public.connections
  for insert to authenticated
  with check (requester_id = auth.uid() and public.same_school(recipient_id));
create policy "accept a request sent to me" on public.connections
  for update to authenticated
  using (recipient_id = auth.uid() and status = 'pending')
  with check (status = 'accepted');
-- Covers cancel (requester), decline (recipient), and disconnect (either).
create policy "cancel, decline, or disconnect" on public.connections
  for delete to authenticated using (auth.uid() in (requester_id, recipient_id));

-- ─── Counts ─────────────────────────────────────────────────────────────────
-- Computed from rows, not stored. security_invoker means the viewer's RLS applies.

create view public.profile_stats with (security_invoker = true) as
select
  p.id,
  (select count(*) from public.follows f where f.followed_id = p.id) as follower_count,
  (select count(*) from public.follows f where f.follower_id = p.id) as following_count,
  (select count(*) from public.connections c
    where c.status = 'accepted' and p.id in (c.requester_id, c.recipient_id)) as connection_count
from public.profiles p;
