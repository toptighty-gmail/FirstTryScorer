-- First Try Scorer — schema, RPC, and RLS policies.
-- Run in the Supabase SQL editor. Policies and functions are safe to reapply.

create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- Promote an existing Auth user by email when needed:
-- insert into public.profiles (id, is_admin)
-- select id, true from auth.users where email = 'admin@example.com'
-- on conflict (id) do update set is_admin = excluded.is_admin;

alter table profiles enable row level security;

drop policy if exists "users can read their own profile" on profiles;
create policy "users can read their own profile" on profiles
  for select to authenticated using (id = auth.uid());

create or replace function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  );
$$;

revoke all on function is_admin() from public, anon;
grant execute on function is_admin() to authenticated;

create table if not exists teams (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists games (
  id uuid primary key default gen_random_uuid(),
  match_date date not null,
  home_team_id uuid not null references teams(id),
  away_team_id uuid not null references teams(id),
  join_code text not null unique,
  status text not null default 'open' check (status in ('open', 'closed', 'complete')),
  created_at timestamptz not null default now()
);

create table if not exists picks (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  player_name text not null,
  team text not null check (team in ('home', 'away')),
  number int not null check (number between 1 and 15),
  claimed_at timestamptz not null default now(),
  unique (game_id, team, number)
);

create index if not exists picks_game_id_idx on picks (game_id);

create or replace function close_game(p_game_id uuid, p_status text default 'closed')
returns public.games
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.games;
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Only administrators can end a draw';
  end if;

  if p_status not in ('closed', 'complete') then
    raise exception 'Status must be closed or complete';
  end if;

  select * into v_game
  from public.games
  where id = p_game_id
  for update;

  if v_game is null then
    raise exception 'Game not found';
  end if;

  if v_game.status <> 'open' then
    raise exception 'Game has already ended';
  end if;

  if p_status = 'complete' and (
    select count(*) from public.picks where game_id = p_game_id
  ) < 30 then
    raise exception 'A game can only be completed when all 30 tickets are drawn';
  end if;

  update public.games
  set status = p_status
  where id = p_game_id
  returning * into v_game;

  return v_game;
end;
$$;

revoke all on function close_game(uuid, text) from public, anon;
grant execute on function close_game(uuid, text) to authenticated;

-- Draws one random unclaimed (team, number) slot for a game and assigns it
-- to the given player. Retries on a rare unique-constraint race so two
-- simultaneous draws can never collide on the same slot.
create or replace function draw_slot(p_game_id uuid, p_player_name text)
returns table (team text, number int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team text;
  v_number int;
  v_attempts int := 0;
  v_status text;
begin
  select status into v_status
  from public.games
  where id = p_game_id
  for update;

  if not found then
    raise exception 'Game not found';
  end if;

  if v_status <> 'open' then
    raise exception 'This draw is closed';
  end if;

  loop
    v_attempts := v_attempts + 1;
    if v_attempts > 20 then
      raise exception 'No slots available for this game';
    end if;

    select pool.team, pool.number
      into v_team, v_number
    from (
      select 'home' as team, n as number from generate_series(1, 15) n
      union all
      select 'away' as team, n as number from generate_series(1, 15) n
    ) pool
    where not exists (
      select 1 from picks p
      where p.game_id = p_game_id
        and p.team = pool.team
        and p.number = pool.number
    )
    order by random()
    limit 1;

    if v_team is null then
      raise exception 'No slots available for this game';
    end if;

    begin
      insert into picks (game_id, player_name, team, number)
      values (p_game_id, p_player_name, v_team, v_number);

      if (select count(*) from public.picks where game_id = p_game_id) = 30 then
        update public.games set status = 'complete' where id = p_game_id;
      end if;

      return query select v_team, v_number;
      return;
    exception when unique_violation then
      -- Someone else grabbed that slot first; loop and try again.
      v_team := null;
      v_number := null;
    end;
  end loop;
end;
$$;

alter table teams enable row level security;
alter table games enable row level security;
alter table picks enable row level security;

drop policy if exists "teams are readable by anyone" on teams;
create policy "teams are readable by anyone" on teams
  for select using (true);
drop policy if exists "anyone can add a team" on teams;
drop policy if exists "admins can add teams" on teams;
create policy "admins can add teams" on teams
  for insert to authenticated with check (public.is_admin());

drop policy if exists "games are readable by anyone" on games;
create policy "games are readable by anyone" on games
  for select using (true);
drop policy if exists "anyone can create a game" on games;
drop policy if exists "admins can create games" on games;
create policy "admins can create games" on games
  for insert to authenticated with check (public.is_admin());

drop policy if exists "picks are readable by anyone" on picks;
create policy "picks are readable by anyone" on picks
  for select using (true);
-- No insert/update/delete policies on picks: all writes go through the
-- security-definer draw_slot() function above.

revoke all on function draw_slot(uuid, text) from public;
grant execute on function draw_slot(uuid, text) to anon, authenticated;

-- Enable the picks stream used by the live game board. This is safe to rerun.
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'picks'
  ) then
    execute 'alter publication supabase_realtime add table public.picks';
  end if;
end;
$$;
