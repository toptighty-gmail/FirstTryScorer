-- First Try Scorer — schema, RPC, and RLS policies.
-- Run this once in the Supabase SQL editor for your project.

create extension if not exists pgcrypto;

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
begin
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

create policy "teams are readable by anyone" on teams
  for select using (true);
create policy "anyone can add a team" on teams
  for insert with check (true);

create policy "games are readable by anyone" on games
  for select using (true);
create policy "anyone can create a game" on games
  for insert with check (true);

create policy "picks are readable by anyone" on picks
  for select using (true);
-- No insert/update/delete policies on picks: all writes go through the
-- security-definer draw_slot() function above.

grant execute on function draw_slot(uuid, text) to anon, authenticated;
