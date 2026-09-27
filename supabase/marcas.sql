-- BIKEGRID · Marcas que trabaja cada ficha (Specialized, Fox, Shimano…)
-- Ejecutar en Supabase → SQL Editor, después de schema.sql y admin.sql. Se puede re-ejecutar.
-- Catálogo único: "Specialized", "specialized " y "SPECIALIZED" son la misma marca (mismo slug).

-- 1) Catálogo de marcas
create table if not exists public.marcas (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null check (char_length(nombre) between 2 and 40),
  slug       text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now()
);

-- Slug normalizado (minúsculas, sin tildes ni símbolos): la llave que evita duplicados
create or replace function public.marca_slug(txt text) returns text
language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(translate(txt, 'ÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇáàäâéèëêíìïîóòöôúùüûñç', 'AAAAEEEEIIIIOOOOUUUUNCaaaaeeeeiiiioooouuuunc')), '[^a-z0-9]+', '-', 'g'))
$$;
create or replace function public.marcas_normalizar() returns trigger
language plpgsql as $$
begin
  new.nombre := trim(regexp_replace(new.nombre, '\s+', ' ', 'g'));
  new.slug := public.marca_slug(new.nombre);
  return new;
end $$;
drop trigger if exists marcas_normalizar on public.marcas;
create trigger marcas_normalizar before insert or update on public.marcas
  for each row execute function public.marcas_normalizar();

-- 2) Qué marcas trabaja cada ficha. orden 0 = marca principal
create table if not exists public.comercio_marcas (
  comercio_id uuid not null references public.comercios(id) on delete cascade,
  marca_id    uuid not null references public.marcas(id) on delete cascade,
  orden       smallint not null default 0 check (orden between 0 and 20),
  primary key (comercio_id, marca_id)
);
create index if not exists comercio_marcas_marca_idx on public.comercio_marcas (marca_id, orden);

-- 3) Marcas que sugiere el negocio al registrarse (texto libre; el equipo las pasa al catálogo)
alter table public.comercios add column if not exists marcas_sugeridas text check (char_length(marcas_sugeridas) <= 200);
grant insert (marcas_sugeridas) on public.comercios to anon, authenticated;
grant update (marcas_sugeridas) on public.comercios to authenticated;

-- 4) Permisos: el público lee el catálogo y las marcas de fichas aprobadas; solo admins escriben
alter table public.marcas enable row level security;
alter table public.comercio_marcas enable row level security;
revoke all on public.marcas, public.comercio_marcas from anon, authenticated;
grant select on public.marcas, public.comercio_marcas to anon, authenticated;
grant insert, update, delete on public.marcas, public.comercio_marcas to authenticated;

drop policy if exists "Catálogo de marcas público" on public.marcas;
create policy "Catálogo de marcas público" on public.marcas for select to anon, authenticated using (true);
drop policy if exists "Admins gestionan marcas" on public.marcas;
create policy "Admins gestionan marcas" on public.marcas for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Marcas de fichas aprobadas" on public.comercio_marcas;
create policy "Marcas de fichas aprobadas" on public.comercio_marcas for select to anon, authenticated
  using (exists (select 1 from public.comercios c where c.id = comercio_id and c.estado = 'aprobado'));
drop policy if exists "Admins gestionan marcas de fichas" on public.comercio_marcas;
create policy "Admins gestionan marcas de fichas" on public.comercio_marcas for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Carga rápida por SQL (opcional): asignar marcas a una ficha por nombre, la primera es la principal
-- insert into public.marcas (nombre) values ('Specialized'), ('Fox') on conflict (slug) do nothing;  -- (el slug lo calcula el trigger)
-- insert into public.comercio_marcas (comercio_id, marca_id, orden)
--   select c.id, m.id, x.orden from public.comercios c
--   join (values ('specialized', 0), ('fox', 1)) as x(slug, orden) on true
--   join public.marcas m on m.slug = x.slug
--   where c.nombre_comercio = 'Bike Panul Store' on conflict do nothing;
