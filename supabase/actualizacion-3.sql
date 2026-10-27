-- =====================================================================
-- Brújula P&C · actualización 3
-- Fotos del equipo en un espacio PRIVADO de Supabase Storage.
-- Solo las ven personas que iniciaron sesión. No se guardan en GitHub.
-- Pegar completo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- Carpeta privada "fotos": máximo 1 MB por foto, solo JPG, PNG o WEBP
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false, file_size_limit = 1048576, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- Cada foto se llama <clave>.jpg (jefe.jpg, lider.jpg, analista.jpg, auxiliar.jpg, asistente.jpg)
-- Ver: cualquier persona con sesión iniciada.
drop policy if exists fotos_select on storage.objects;
create policy fotos_select on storage.objects for select to authenticated
  using (bucket_id = 'fotos');

-- Subir o cambiar: Armando y Alvaro, cualquier foto; los demás, solo la suya.
drop policy if exists fotos_insert on storage.objects;
create policy fotos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (public.is_admin() or name = public.my_key() || '.jpg'));

drop policy if exists fotos_update on storage.objects;
create policy fotos_update on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (public.is_admin() or name = public.my_key() || '.jpg'))
  with check (bucket_id = 'fotos' and (public.is_admin() or name = public.my_key() || '.jpg'));

drop policy if exists fotos_delete on storage.objects;
create policy fotos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (public.is_admin() or name = public.my_key() || '.jpg'));
