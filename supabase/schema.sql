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
  ticket_price numeric(8, 2) not null default 0 check (ticket_price >= 0),
  status text not null default 'open' check (status in ('open', 'closed', 'complete')),
  created_at timestamptz not null default now()
);

alter table public.games
  add column if not exists ticket_price numeric(8, 2) not null default 0
  check (ticket_price >= 0);

-- Ticket numbers per team: 15 for a starting side, 23 including subs.
alter table public.games
  add column if not exists players_per_team int not null default 15
  check (players_per_team between 1 and 30);

create table if not exists picks (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  player_name text not null,
  team text not null check (team in ('home', 'away')),
  number int not null check (number >= 1),
  claimed_at timestamptz not null default now(),
  unique (game_id, team, number)
);

create index if not exists picks_game_id_idx on picks (game_id);

-- The upper limit per game comes from games.players_per_team and is enforced
-- by draw_slot(), so replace the old fixed 1-15 check.
alter table public.picks drop constraint if exists picks_number_check;
alter table public.picks add constraint picks_number_check check (number >= 1);

-- Lock players_per_team once any ticket has been drawn for the game.
create or replace function guard_players_per_team()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.players_per_team <> old.players_per_team and exists (
    select 1 from public.picks where game_id = old.id
  ) then
    raise exception 'Players per team cannot change after tickets are drawn';
  end if;
  return new;
end;
$$;

drop trigger if exists games_guard_players_per_team on games;
create trigger games_guard_players_per_team
  before update of players_per_team on games
  for each row execute function guard_players_per_team();

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
  ) < v_game.players_per_team * 2 then
    raise exception 'A game can only be completed when all % tickets are drawn',
      v_game.players_per_team * 2;
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
  v_players int;
begin
  select status, players_per_team into v_status, v_players
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
      select 'home' as team, n as number from generate_series(1, v_players) n
      union all
      select 'away' as team, n as number from generate_series(1, v_players) n
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

      if (select count(*) from public.picks where game_id = p_game_id) >= v_players * 2 then
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
drop policy if exists "admins can update games" on games;
create policy "admins can update games" on games
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
drop policy if exists "admins can delete games" on games;
create policy "admins can delete games" on games
  for delete to authenticated using (public.is_admin());

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
