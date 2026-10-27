-- =====================================================================
-- Brújula P&C · actualización 4
-- Personaje vivo, autoservicio de reportes con historial, reconocimientos,
-- preguntas propuestas por el equipo, votos y comentarios en ideas,
-- y reinicio de temporada.
-- Requiere haber ejecutado antes schema.sql, actualizacion-2.sql y actualizacion-3.sql.
-- Pegar completo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

create or replace function public.lima_today()
returns date language sql stable as $$ select (now() at time zone 'America/Lima')::date $$;

-- ---------- Reportes: entrega, evidencia, revisión y validación ----------
alter table public.checkpoints drop constraint if exists checkpoints_status_check;
alter table public.checkpoints add constraint checkpoints_status_check
  check (status in ('pendiente','curso','entregado','ok','obs','tarde','error','tarde_error'));
alter table public.checkpoints add column if not exists delivered_at    timestamptz;
alter table public.checkpoints add column if not exists evidence        text;
alter table public.checkpoints add column if not exists reviewed_at     timestamptz;
alter table public.checkpoints add column if not exists review_note     text;
alter table public.checkpoints add column if not exists validation_note text;
alter table public.checkpoints drop constraint if exists checkpoints_text_len;
alter table public.checkpoints add constraint checkpoints_text_len check (
  (evidence is null or char_length(evidence) <= 300) and
  (review_note is null or char_length(review_note) <= 280) and
  (validation_note is null or char_length(validation_note) <= 280));

-- Historial de cada reporte (solo se escribe desde las funciones de abajo)
create table if not exists public.cp_events (
  id          uuid primary key default gen_random_uuid(),
  cp_id       uuid not null references public.checkpoints(id) on delete cascade,
  actor       text not null,
  kind        text not null check (kind in ('entrega','revision','validacion')),
  from_status text,
  to_status   text,
  note        text check (note is null or char_length(note) <= 280),
  created_at  timestamptz not null default now()
);
alter table public.cp_events enable row level security;
revoke all on public.cp_events from anon, authenticated;
grant select on public.cp_events to authenticated;
-- El historial (que puede incluir penalidades) lo ven solo el responsable, el copiloto, Armando y Alvaro
drop policy if exists ev_select on public.cp_events;
create policy ev_select on public.cp_events for select to authenticated using (
  public.is_admin() or exists (select 1 from public.checkpoints c where c.id = cp_id and (c.resp = public.my_key() or c.co = public.my_key())));

-- El responsable marca su avance: en curso, entregado (o vuelve a pendiente)
create or replace function public.report_progress(p_id uuid, p_status text, p_evidence text default null, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare c public.checkpoints; k text := public.my_key();
begin
  select * into c from public.checkpoints where id = p_id;
  if not found then raise exception 'El reporte no existe'; end if;
  if c.resp is distinct from k and not public.is_admin() then raise exception 'Solo el responsable puede marcar su avance' using errcode = '42501'; end if;
  if p_status not in ('pendiente','curso','entregado') then raise exception 'Estado no permitido' using errcode = '42501'; end if;
  if c.status in ('ok','obs','tarde','error','tarde_error') then raise exception 'El reporte ya fue validado' using errcode = '42501'; end if;
  update public.checkpoints
     set status = p_status,
         delivered_at = case when p_status = 'entregado' then now() else null end,
         evidence = coalesce(nullif(trim(p_evidence), ''), evidence)
   where id = p_id;
  insert into public.cp_events (cp_id, actor, kind, from_status, to_status, note)
  values (p_id, coalesce(k, '?'), 'entrega', c.status, p_status, nullif(trim(p_note), ''));
end $$;

-- El copiloto deja constancia de su revisión
create or replace function public.report_review(p_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare c public.checkpoints; k text := public.my_key();
begin
  select * into c from public.checkpoints where id = p_id;
  if not found then raise exception 'El reporte no existe'; end if;
  if c.co is distinct from k then raise exception 'Solo el copiloto registra la revisión' using errcode = '42501'; end if;
  update public.checkpoints set reviewed_at = now(), review_note = nullif(trim(p_note), '') where id = p_id;
  insert into public.cp_events (cp_id, actor, kind, from_status, to_status, note)
  values (p_id, k, 'revision', c.status, c.status, nullif(trim(p_note), ''));
end $$;

-- Armando o Alvaro ponen el sello final. Observaciones, errores o tardanza exigen comentario.
create or replace function public.report_validate(p_id uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare c public.checkpoints; k text := public.my_key();
begin
  if not public.is_admin() then raise exception 'Solo Armando o Alvaro validan' using errcode = '42501'; end if;
  select * into c from public.checkpoints where id = p_id;
  if not found then raise exception 'El reporte no existe'; end if;
  if p_status not in ('pendiente','curso','entregado','ok','obs','tarde','error','tarde_error') then raise exception 'Estado no permitido'; end if;
  if p_status in ('obs','tarde','error','tarde_error') and coalesce(trim(p_note), '') = '' then
    raise exception 'Escribe el motivo' using errcode = '22023';
  end if;
  update public.checkpoints
     set status = p_status,
         validation_note = nullif(trim(p_note), ''),
         delivered_at = case when p_status in ('pendiente','curso') then null
                             when delivered_at is null and p_status <> 'entregado' then now()
                             else delivered_at end
   where id = p_id;
  insert into public.cp_events (cp_id, actor, kind, from_status, to_status, note)
  values (p_id, k, 'validacion', c.status, p_status, nullif(trim(p_note), ''));
end $$;

revoke all on function public.report_progress(uuid, text, text, text) from public, anon;
revoke all on function public.report_review(uuid, text) from public, anon;
revoke all on function public.report_validate(uuid, text, text) from public, anon;
grant execute on function public.report_progress(uuid, text, text, text) to authenticated;
grant execute on function public.report_review(uuid, text) to authenticated;
grant execute on function public.report_validate(uuid, text, text) to authenticated;

-- ---------- Visitas y reconocimientos (mantienen vivo al detective) ----------
create table if not exists public.actions (
  id          uuid primary key default gen_random_uuid(),
  member_key  text not null check (member_key in ('jefe','lider','analista','auxiliar','asistente')),
  kind        text not null check (kind in ('visita','reconocimiento')),
  target      text check (target is null or target in ('jefe','lider','analista','auxiliar','asistente')),
  note        text check (note is null or char_length(note) <= 140),
  day         date not null default public.lima_today(),
  created_at  timestamptz not null default now()
);
create unique index if not exists actions_visita_dia on public.actions (member_key, day) where kind = 'visita';
create unique index if not exists actions_reco_dia   on public.actions (member_key, day) where kind = 'reconocimiento';
alter table public.actions enable row level security;
revoke all on public.actions from anon, authenticated;
grant select, insert on public.actions to authenticated;
drop policy if exists ac_select on public.actions;
create policy ac_select on public.actions for select to authenticated using (true);
drop policy if exists ac_insert on public.actions;
create policy ac_insert on public.actions for insert to authenticated with check (
  member_key = public.my_key() and day = public.lima_today() and
  ((kind = 'visita' and target is null) or
   (kind = 'reconocimiento' and target is not null and target <> member_key and char_length(coalesce(note, '')) between 3 and 140)));

-- ---------- Preguntas propuestas por todo el equipo ----------
alter table public.questions add column if not exists status text not null default 'aprobada';
alter table public.questions drop constraint if exists questions_status_check;
alter table public.questions add constraint questions_status_check check (status in ('propuesta','aprobada'));
alter table public.questions drop constraint if exists questions_created_by_check;
alter table public.questions add constraint questions_created_by_check
  check (created_by in ('jefe','lider','analista','auxiliar','asistente'));
grant update (status, prompt, options, answer, explain) on public.questions to authenticated;
drop policy if exists q_insert on public.questions;
create policy q_insert on public.questions for insert to authenticated
  with check (created_by = public.my_key() and (public.is_admin() or status = 'propuesta'));
drop policy if exists q_update on public.questions;
create policy q_update on public.questions for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- Ideas: responsable, siguiente paso, apoyos y comentarios ----------
alter table public.ideas add column if not exists owner text;
alter table public.ideas add column if not exists next_step text;
alter table public.ideas drop constraint if exists ideas_owner_check;
alter table public.ideas add constraint ideas_owner_check check (
  (owner is null or owner in ('jefe','lider','analista','auxiliar','asistente')) and
  (next_step is null or char_length(next_step) <= 160));

create table if not exists public.idea_votes (
  idea_id     uuid not null references public.ideas(id) on delete cascade,
  member_key  text not null check (member_key in ('jefe','lider','analista','auxiliar','asistente')),
  created_at  timestamptz not null default now(),
  primary key (idea_id, member_key)
);
create table if not exists public.idea_comments (
  id          uuid primary key default gen_random_uuid(),
  idea_id     uuid not null references public.ideas(id) on delete cascade,
  author      text not null check (author in ('jefe','lider','analista','auxiliar','asistente')),
  body        text not null check (char_length(body) between 1 and 280),
  created_at  timestamptz not null default now()
);
alter table public.idea_votes enable row level security;
alter table public.idea_comments enable row level security;
revoke all on public.idea_votes, public.idea_comments from anon, authenticated;
grant select, insert, delete on public.idea_votes, public.idea_comments to authenticated;
drop policy if exists iv_select on public.idea_votes;
create policy iv_select on public.idea_votes for select to authenticated using (true);
drop policy if exists iv_insert on public.idea_votes;
create policy iv_insert on public.idea_votes for insert to authenticated with check (member_key = public.my_key());
drop policy if exists iv_delete on public.idea_votes;
create policy iv_delete on public.idea_votes for delete to authenticated using (member_key = public.my_key());
drop policy if exists ic_select on public.idea_comments;
create policy ic_select on public.idea_comments for select to authenticated using (true);
drop policy if exists ic_insert on public.idea_comments;
create policy ic_insert on public.idea_comments for insert to authenticated with check (author = public.my_key());
drop policy if exists ic_delete on public.idea_comments;
create policy ic_delete on public.idea_comments for delete to authenticated using (author = public.my_key() or public.is_admin());

-- ---------- Empezar la temporada de cero (borra los datos de ejemplo) ----------
-- Borra reportes, ideas, avance de la Academia, rangos guardados, partidas y acciones.
-- Conserva usuarios, alias, looks, fotos y preguntas.
create or replace function public.reset_season()
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Solo Armando o Alvaro' using errcode = '42501'; end if;
  delete from public.checkpoints where true;
  delete from public.ideas where true;
  delete from public.progress where true;
  delete from public.rank_floor where true;
  delete from public.game_plays where true;
  delete from public.actions where true;
end $$;
revoke all on function public.reset_season() from public, anon;
grant execute on function public.reset_season() to authenticated;
