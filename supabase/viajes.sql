-- DESVIADOR · Planes de salida / viaje (configurador "Arma tu Salida / Viaje")
-- Ejecutar en Supabase → SQL Editor. Requiere admin.sql (usa public.is_admin()). Se puede re-ejecutar.

create table if not exists public.planes_viaje (
  id          uuid primary key default gen_random_uuid(),
  disciplina  text not null check (disciplina in ('enduro_dh','emtb','gravel','ruta','trail_xc')),
  nivel       text not null check (nivel in ('principiante','intermedio','avanzado','experto')),
  terreno     text not null check (terreno in ('seco','bosque','barro','rocoso')),
  duracion    text not null check (duracion in ('1_dia','fin_de_semana','expedicion')),
  servicios   text[] not null default '{}'
              check (servicios <@ array['shuttle','guia','arriendo','alojamiento','soporte']::text[]),
  zona        text not null check (zona in ('santiago','pucon','chillan','patagonia','abierto')),
  mes         text check (mes ~ '^\d{4}-\d{2}$'),          -- null = fecha flexible
  fecha       date,                                         -- fecha exacta opcional
  personas    int not null check (personas between 1 and 30),
  nombre      text not null check (char_length(nombre) between 2 and 80),
  telefono    text not null check (telefono ~ '^[0-9]{8,15}$'),
  email       text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  idioma      text not null default 'es' check (idioma in ('es','en')),
  estado      text not null default 'nuevo' check (estado in ('nuevo','contactado','propuesta','cerrado','descartado')),
  version     int not null default 1,
  created_at  timestamptz not null default now()
);
create index if not exists planes_viaje_created_at_idx on public.planes_viaje (created_at desc);

alter table public.planes_viaje enable row level security;

-- El público solo INSERTA (sin leer, editar ni borrar); no puede fijar el estado.
revoke all on public.planes_viaje from anon, authenticated;
grant insert (disciplina, nivel, terreno, duracion, servicios, zona, mes, fecha, personas, nombre, telefono, email, idioma, version)
  on public.planes_viaje to anon, authenticated;
drop policy if exists "Captura pública de planes" on public.planes_viaje;
create policy "Captura pública de planes"
  on public.planes_viaje for insert to anon, authenticated
  with check (estado = 'nuevo');

-- Solo admins los leen y actualizan (seguimiento: estado). También se ven en Table Editor → planes_viaje.
grant select, update (estado) on public.planes_viaje to authenticated;
drop policy if exists "Admins leen planes" on public.planes_viaje;
create policy "Admins leen planes" on public.planes_viaje for select to authenticated using (public.is_admin());
drop policy if exists "Admins actualizan planes" on public.planes_viaje;
create policy "Admins actualizan planes" on public.planes_viaje for update to authenticated using (public.is_admin()) with check (public.is_admin());
