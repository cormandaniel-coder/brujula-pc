-- =====================================================================
-- Brújula P&C · actualización 5
-- 1) Borrar el historial de un reporte o de todo un expediente (mes).
-- 2) Nombres de cursos y habilidades de la Academia editables desde la web.
-- Requiere haber ejecutado antes schema.sql y las actualizaciones 2, 3 y 4.
-- Pegar completo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- ---------- Borrar historial (solo Armando y Alvaro) ----------
-- p_cp: un reporte; p_mes: todos los reportes de ese mes ('2026-10').
-- Solo borra el registro del historial: no cambia sellos ni XP.
create or replace function public.clear_cp_history(p_cp uuid default null, p_mes text default null)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not public.is_admin() then raise exception 'Solo Armando o Alvaro' using errcode = '42501'; end if;
  if p_cp is null and p_mes is null then raise exception 'Indica el reporte o el mes'; end if;
  delete from public.cp_events e
   where (p_cp is not null and e.cp_id = p_cp)
      or (p_mes is not null and e.cp_id in (select c.id from public.checkpoints c where c.mes = p_mes));
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.clear_cp_history(uuid, text) from public, anon;
grant execute on function public.clear_cp_history(uuid, text) to authenticated;

-- ---------- Academia: nombres editables ----------
-- item_id: f1..f6, r1..r6, e1..e6, l1..l6 (especialidades) y x1..x3 (cursos comunes).
create table if not exists public.academy_items (
  item_id     text primary key check (item_id ~ '^[a-z][0-9]{1,2}$'),
  skill       text check (skill is null or char_length(skill) between 2 and 60),
  course      text not null check (char_length(course) between 3 and 120),
  updated_by  text,
  updated_at  timestamptz not null default now()
);
alter table public.academy_items enable row level security;
revoke all on public.academy_items from anon, authenticated;
grant select, insert, update, delete on public.academy_items to authenticated;
drop policy if exists ai_select on public.academy_items;
create policy ai_select on public.academy_items for select to authenticated using (true);
drop policy if exists ai_insert on public.academy_items;
create policy ai_insert on public.academy_items for insert to authenticated with check (public.is_admin());
drop policy if exists ai_update on public.academy_items;
create policy ai_update on public.academy_items for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists ai_delete on public.academy_items;
create policy ai_delete on public.academy_items for delete to authenticated using (public.is_admin());

-- Fecha de cada avance de la Academia (para saber en qué mes se completó un curso)
alter table public.progress add column if not exists updated_at timestamptz not null default now();
create or replace function public.touch_progress() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists progress_touch on public.progress;
create trigger progress_touch before insert or update on public.progress for each row execute function public.touch_progress();
