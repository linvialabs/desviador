-- DESVIADOR · Panel de administración
-- Ejecutar en Supabase → SQL Editor DESPUÉS de schema.sql. Se puede volver a ejecutar sin problema.

-- 1) Lista de administradores (se edita solo desde el SQL Editor / Table Editor de Supabase)
create table if not exists public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

-- 2) ¿El usuario que hace la consulta es admin?
create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- 3) Lectura completa (incluye columnas privadas) solo para admins
create or replace function public.admin_comercios()
returns setof public.comercios
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'No autorizado' using errcode = '42501';
  end if;
  return query select * from public.comercios order by created_at desc;
end $$;
revoke all on function public.admin_comercios() from public, anon;
grant execute on function public.admin_comercios() to authenticated;

-- 4) Ver, editar y eliminar filas: solo admins (las políticas se suman a las públicas)
drop policy if exists "Admins ven todas las filas" on public.comercios;
create policy "Admins ven todas las filas"
  on public.comercios for select to authenticated
  using (public.is_admin());

drop policy if exists "Admins editan comercios" on public.comercios;
create policy "Admins editan comercios"
  on public.comercios for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins eliminan comercios" on public.comercios;
create policy "Admins eliminan comercios"
  on public.comercios for delete to authenticated
  using (public.is_admin());

grant update (nombre_comercio, categoria, region, comuna, direccion, latitud, longitud, whatsapp, horario,
              descripcion, contacto_admin, necesidad_personal, solicita_destacado, es_amigo_trail, destacado, estado)
  on public.comercios to authenticated;
grant delete on public.comercios to authenticated;

-- 5) Darte acceso: crea tu usuario en Authentication → Users → "Add user" y luego
--    reemplaza el correo y ejecuta esta línea.
insert into public.admins (user_id)
select id from auth.users where email = 'TU_CORREO_ADMIN@ejemplo.cl'
on conflict do nothing;
