-- =====================================================================
-- Brújula P&C · actualización 2
-- Penalidades, rango protegido y Sala de entrenamiento (minijuegos).
-- Pegar completo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- ---------- Nuevos sellos para los reportes ----------
alter table public.checkpoints drop constraint if exists checkpoints_status_check;
alter table public.checkpoints add constraint checkpoints_status_check
  check (status in ('ok','obs','tarde','error','tarde_error','curso','pendiente'));

-- ---------- Rango protegido ----------
-- Guarda el rango más alto que alcanzó cada detective. Solo puede subir.
create table if not exists public.rank_floor (
  member_key  text primary key
              check (member_key in ('lider','analista','auxiliar','asistente')),
  rank        int  not null check (rank between 0 and 4),
  updated_at  timestamptz not null default now()
);

-- ---------- Partidas de la Sala de entrenamiento ----------
create table if not exists public.game_plays (
  id          uuid primary key default gen_random_uuid(),
  member_key  text not null check (member_key in ('jefe','lider','analista','auxiliar','asistente')),
  game        text not null check (game in ('quiz','errores','subebaja','ordena','parejas','diaria')),
  day         date not null default ((now() at time zone 'America/Lima')::date),
  correct     int  not null check (correct between 0 and 20),
  total       int  not null check (total between 1 and 20),
  created_at  timestamptz not null default now(),
  check (correct <= total)
);
-- una sola Pregunta del día por persona y por día
create unique index if not exists game_plays_diaria_unica
  on public.game_plays (member_key, day) where game = 'diaria';

-- ---------- Preguntas agregadas por Armando y Alvaro ----------
create table if not exists public.questions (
  id          uuid primary key default gen_random_uuid(),
  prompt      text not null check (char_length(prompt) between 5 and 300),
  options     jsonb not null check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) = 4),
  answer      int  not null check (answer between 0 and 3),
  explain     text not null default '' check (char_length(explain) <= 400),
  created_by  text not null check (created_by in ('jefe','lider')),
  created_at  timestamptz not null default now()
);

-- ---------- Seguridad ----------
alter table public.rank_floor enable row level security;
alter table public.game_plays enable row level security;
alter table public.questions  enable row level security;

revoke all on public.rank_floor, public.game_plays, public.questions from anon, authenticated;
grant select on public.rank_floor, public.game_plays, public.questions to authenticated;
grant insert, update        on public.rank_floor to authenticated;
grant insert, delete        on public.game_plays to authenticated;
grant insert, delete        on public.questions  to authenticated;

-- rank_floor: todos leen; solo Armando y Alvaro escriben, y el rango nunca baja
drop policy if exists rf_select on public.rank_floor;
create policy rf_select on public.rank_floor for select to authenticated using (true);
drop policy if exists rf_insert on public.rank_floor;
create policy rf_insert on public.rank_floor for insert to authenticated with check (public.is_admin());
drop policy if exists rf_update on public.rank_floor;
create policy rf_update on public.rank_floor for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.rank_floor_only_up()
returns trigger language plpgsql as $$
begin
  if new.rank < old.rank then new.rank := old.rank; end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists rank_floor_only_up on public.rank_floor;
create trigger rank_floor_only_up before update on public.rank_floor
  for each row execute function public.rank_floor_only_up();

-- game_plays: todos leen; cada uno registra solo sus propias partidas y solo con la fecha de hoy
drop policy if exists gp_select on public.game_plays;
create policy gp_select on public.game_plays for select to authenticated using (true);
drop policy if exists gp_insert on public.game_plays;
create policy gp_insert on public.game_plays for insert to authenticated
  with check (member_key = public.my_key() and day = (now() at time zone 'America/Lima')::date);
drop policy if exists gp_delete on public.game_plays;
create policy gp_delete on public.game_plays for delete to authenticated using (public.is_admin());

-- questions: todos leen; solo Armando y Alvaro agregan o borran
drop policy if exists q_select on public.questions;
create policy q_select on public.questions for select to authenticated using (true);
drop policy if exists q_insert on public.questions;
create policy q_insert on public.questions for insert to authenticated
  with check (public.is_admin() and created_by = public.my_key());
drop policy if exists q_delete on public.questions;
create policy q_delete on public.questions for delete to authenticated using (public.is_admin());
