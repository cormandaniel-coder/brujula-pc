-- =====================================================================
-- Brújula P&C · esquema de base de datos
-- Pegar completo en Supabase → SQL Editor → New query → Run
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- ---------- Perfiles (uno por persona del equipo) ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  member_key  text unique not null
              check (member_key in ('jefe','lider','analista','auxiliar','asistente')),
  alias       text check (alias is null or char_length(alias) <= 40),
  look        jsonb check (look is null or pg_column_size(look) < 2048)
);

-- ---------- Reportes mensuales (checkpoints) ----------
create table if not exists public.checkpoints (
  id          uuid primary key default gen_random_uuid(),
  mes         text not null check (mes ~ '^[0-9]{4}-[0-9]{2}$'),
  name        text not null check (char_length(name) between 1 and 120),
  descr       text not null default '' check (char_length(descr) <= 240),
  due         date not null,
  resp        text not null check (resp in ('jefe','lider','analista','auxiliar','asistente')),
  co          text not null check (co   in ('jefe','lider','analista','auxiliar','asistente')),
  status      text not null default 'pendiente'
              check (status in ('ok','obs','tarde','curso','pendiente')),
  created_at  timestamptz not null default now()
);

-- ---------- Ideas ----------
create table if not exists public.ideas (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (char_length(title) between 1 and 120),
  descr       text not null default '' check (char_length(descr) <= 240),
  author      text not null check (author in ('jefe','lider','analista','auxiliar','asistente')),
  stage       text not null default 'propuesta'
              check (stage in ('propuesta','analisis','piloto','implementada')),
  hours       numeric not null default 0 check (hours >= 0 and hours <= 80),
  created_at  timestamptz not null default now()
);

-- ---------- Avance en la Academia ----------
-- state: 'none' | 'progress:NN' | 'done' | 'taught'
create table if not exists public.progress (
  member_key  text not null check (member_key in ('jefe','lider','analista','auxiliar','asistente')),
  item_id     text not null check (char_length(item_id) <= 20),
  state       text not null check (state in ('none','done','taught') or state ~ '^progress:[0-9]{1,3}$'),
  primary key (member_key, item_id)
);

-- ---------- Funciones auxiliares ----------
create or replace function public.my_key()
returns text language sql stable security definer set search_path = public as $$
  select member_key from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.my_key() in ('jefe','lider'), false)
$$;

-- ---------- Al crear un usuario, se crea su perfil ----------
-- El usuario se llama como su clave: armando@brujula.app → se vincula por el
-- texto antes de la arroba (jefe, lider, analista, auxiliar o asistente).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, member_key)
  values (new.id, split_part(new.email, '@', 1));
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Seguridad: nadie entra sin sesión ----------
alter table public.profiles    enable row level security;
alter table public.checkpoints enable row level security;
alter table public.ideas       enable row level security;
alter table public.progress    enable row level security;

revoke all on public.profiles, public.checkpoints, public.ideas, public.progress from anon, authenticated;
grant select on public.profiles, public.checkpoints, public.ideas, public.progress to authenticated;
grant update (alias, look)           on public.profiles    to authenticated;
grant insert, update, delete         on public.checkpoints to authenticated;
grant insert, update, delete         on public.ideas       to authenticated;
grant insert, update, delete         on public.progress    to authenticated;

-- profiles: todos ven a todos; cada uno edita solo su alias y su look
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated using (true);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- checkpoints: todos leen; solo Armando y Alvaro escriben
drop policy if exists cp_select on public.checkpoints;
create policy cp_select on public.checkpoints for select to authenticated using (true);
drop policy if exists cp_insert on public.checkpoints;
create policy cp_insert on public.checkpoints for insert to authenticated with check (public.is_admin());
drop policy if exists cp_update on public.checkpoints;
create policy cp_update on public.checkpoints for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists cp_delete on public.checkpoints;
create policy cp_delete on public.checkpoints for delete to authenticated using (public.is_admin());

-- ideas: todos leen; cualquiera propone la suya (siempre como "propuesta");
-- solo Armando y Alvaro cambian etapa, horas o borran
drop policy if exists ideas_select on public.ideas;
create policy ideas_select on public.ideas for select to authenticated using (true);
drop policy if exists ideas_insert on public.ideas;
create policy ideas_insert on public.ideas for insert to authenticated
  with check (author = public.my_key() and stage = 'propuesta');
drop policy if exists ideas_update on public.ideas;
create policy ideas_update on public.ideas for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists ideas_delete on public.ideas;
create policy ideas_delete on public.ideas for delete to authenticated using (public.is_admin());

-- progress: todos leen; solo Armando y Alvaro validan cursos
drop policy if exists progress_select on public.progress;
create policy progress_select on public.progress for select to authenticated using (true);
drop policy if exists progress_insert on public.progress;
create policy progress_insert on public.progress for insert to authenticated with check (public.is_admin());
drop policy if exists progress_update on public.progress;
create policy progress_update on public.progress for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists progress_delete on public.progress;
create policy progress_delete on public.progress for delete to authenticated using (public.is_admin());

-- ---------- Datos de ejemplo (reemplazar luego desde Administrar) ----------
insert into public.checkpoints (mes, name, descr, due, resp, co, status)
select * from (values
  ('2026-10','Control de acuerdos y requerimientos','Seguimiento de acuerdos de comités y pedidos de otras áreas.', date '2026-10-05','asistente','auxiliar','ok'),
  ('2026-10','Gastos operativos por centro de costo','Gasto del mes por agencia y área, comparado con el mes anterior.', date '2026-10-07','asistente','analista','ok'),
  ('2026-10','Ejecución presupuestal','Real vs. presupuesto del mes y acumulado, con variaciones relevantes.', date '2026-10-08','auxiliar','asistente','ok'),
  ('2026-10','Tablero de indicadores por agencia','Colocaciones, captaciones, morosidad y eficiencia por agencia.', date '2026-10-09','analista','auxiliar','ok'),
  ('2026-10','Informe de gestión mensual','Resultados del mes y explicación de desviaciones para Gerencia.', date '2026-10-12','analista','lider','ok'),
  ('2026-10','Proyección de cierre (forecast)','Estimado de cierre del año con escenarios base y conservador.', date '2026-10-28','lider','analista','curso'),
  ('2026-10','Informe para Directorio','Presentación consolidada de resultados para la sesión de Directorio.', date '2026-10-30','lider','auxiliar','pendiente')
) as v(mes,name,descr,due,resp,co,status)
where not exists (select 1 from public.checkpoints);

insert into public.ideas (title, descr, author, stage, hours)
select * from (values
  ('Consolidar la ejecución presupuestal con Power Query','Reemplaza el copiado manual de los archivos de cada agencia.','auxiliar','implementada',6),
  ('Calendario compartido de cierre con alertas','Recordatorio automático dos días antes de cada vencimiento.','asistente','implementada',3),
  ('Plantilla estándar de análisis de variaciones','El mismo formato para explicar desviaciones en todos los informes.','analista','piloto',4),
  ('Dashboard de indicadores por agencia en Power BI','El tablero mensual se actualiza solo desde la base.','analista','analisis',8),
  ('Checklist de revisión antes de cada envío','Lista corta que usa el copiloto: cifras, formatos y fuentes.','lider','propuesta',2),
  ('Repositorio único de versiones finales','Una carpeta por expediente con nombres de archivo estándar.','asistente','propuesta',2)
) as v(title,descr,author,stage,hours)
where not exists (select 1 from public.ideas);

insert into public.progress (member_key, item_id, state)
select * from (values
  ('analista','f1','done'),('analista','f2','done'),('analista','f3','progress:40'),('analista','f4','taught'),('analista','f5','done'),
  ('auxiliar','r1','done'),('auxiliar','r2','progress:60'),('auxiliar','r4','taught'),('auxiliar','r5','progress:20'),
  ('asistente','e1','done'),('asistente','e2','done'),('asistente','e4','taught'),('asistente','e5','progress:50'),
  ('lider','l1','done'),('lider','l2','done'),('lider','l3','progress:30'),('lider','l4','done'),('lider','l5','progress:70'),
  ('lider','x1','done'),('analista','x1','done'),('auxiliar','x1','done'),('asistente','x1','progress:65'),
  ('lider','x2','taught'),('analista','x2','done'),('auxiliar','x2','progress:30'),
  ('lider','x3','done'),('analista','x3','progress:50'),('asistente','x3','done')
) as v(member_key,item_id,state)
where not exists (select 1 from public.progress);
