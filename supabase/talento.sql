-- BIKEGRID · Bici Jobs: CV Técnico Ciclista y reclutamiento para tiendas
-- Ejecutar en Supabase → SQL Editor después de schema.sql, admin.sql y empleos.sql (usa public.is_admin()). Se puede re-ejecutar.

-- ============ 1. Fichas técnicas de postulantes ============
-- Flujo: el postulante arma su CV Técnico en la web (queda "pendiente") → lo revisas en Table Editor
-- → cambias estado a 'publicado' y aparece en el buscador de candidatos de las tiendas.
-- Público: nombre abreviado ("Matías R."), comuna, especialidades y experiencia. Nunca teléfono, email ni CV.
create table if not exists public.perfiles_tecnicos (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null check (char_length(nombre) between 2 and 80),
  nombre_publico   text generated always as (
                     initcap(split_part(regexp_replace(btrim(nombre), '\s+', ' ', 'g'), ' ', 1))
                     || coalesce(' ' || upper(nullif(left(split_part(regexp_replace(btrim(nombre), '\s+', ' ', 'g'), ' ', 2), 1), '')) || '.', '')
                   ) stored,
  telefono         text not null check (telefono ~ '^[0-9]{8,15}$'),
  email            text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  comuna           text not null check (char_length(comuna) between 2 and 60),
  region           text not null check (region in ('arica','tarapaca','antofagasta','atacama','coquimbo','valparaiso','metropolitana','ohiggins','maule','nuble','biobio','araucania','losrios','loslagos','aysen','magallanes')),
  lat              numeric(5,2) check (lat between -56 and -17),      -- ubicación aproximada (±1 km), opcional
  lng              numeric(5,2) check (lng between -110 and -66),
  jornadas         text[] not null check (cardinality(jornadas) between 1 and 3 and jornadas <@ array['full_time','part_time','temporada']::text[]),
  especialidades   text[] not null check (cardinality(especialidades) between 1 and 12 and especialidades <@ array[
                     'sram_axs','shimano_di2','mecanico_tradicional','fox_rockshox','purgado_hidraulico',
                     'ebike_bosch','ebike_brose','ebike_shimano_steps','ebike_specialized','enrayado','carbono','montaje']::text[]),
  experiencia_anos text not null check (experiencia_anos in ('menos_1','1_2','3_5','6_10','mas_10')),
  experiencia      text check (char_length(experiencia) <= 600),     -- tiendas, talleres o carreras anteriores
  cv_url           text check (cv_url ~* '^https://' and char_length(cv_url) <= 300),
  cv_path          text check (cv_path ~ '^[A-Za-z0-9-]{8,64}\.pdf$'), -- archivo en el bucket privado cvs-tecnicos
  estado           text not null default 'pendiente' check (estado in ('pendiente','publicado','oculto')),
  created_at       timestamptz not null default now()
);
create index if not exists perfiles_tecnicos_estado_idx on public.perfiles_tecnicos (estado, created_at desc);
create index if not exists perfiles_tecnicos_especialidades_idx on public.perfiles_tecnicos using gin (especialidades);

alter table public.perfiles_tecnicos enable row level security;
revoke all on public.perfiles_tecnicos from anon, authenticated;

-- Visitantes: solo fichas publicadas y solo columnas no sensibles
grant select (id, nombre_publico, comuna, region, lat, lng, jornadas, especialidades, experiencia_anos, experiencia, created_at)
  on public.perfiles_tecnicos to anon;
drop policy if exists "Fichas técnicas publicadas" on public.perfiles_tecnicos;
create policy "Fichas técnicas publicadas" on public.perfiles_tecnicos for select to anon
  using (estado = 'publicado');

-- Cualquiera puede enviar su ficha; siempre queda pendiente
grant insert (nombre, telefono, email, comuna, region, lat, lng, jornadas, especialidades, experiencia_anos, experiencia, cv_url, cv_path)
  on public.perfiles_tecnicos to anon, authenticated;
drop policy if exists "Envío público de fichas técnicas" on public.perfiles_tecnicos;
create policy "Envío público de fichas técnicas" on public.perfiles_tecnicos for insert to anon, authenticated
  with check (estado = 'pendiente');

-- Admins: todo (datos de contacto incluidos)
grant select, update, delete on public.perfiles_tecnicos to authenticated;
drop policy if exists "Admins leen fichas técnicas" on public.perfiles_tecnicos;
create policy "Admins leen fichas técnicas" on public.perfiles_tecnicos for select to authenticated using (public.is_admin());
drop policy if exists "Admins editan fichas técnicas" on public.perfiles_tecnicos;
create policy "Admins editan fichas técnicas" on public.perfiles_tecnicos for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins borran fichas técnicas" on public.perfiles_tecnicos;
create policy "Admins borran fichas técnicas" on public.perfiles_tecnicos for delete to authenticated using (public.is_admin());

-- ============ 2. CV en PDF (Storage privado) ============
-- Bucket privado: el público solo puede SUBIR un PDF (máx. 5 MB) con nombre aleatorio; solo admins lo leen o borran.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cvs-tecnicos', 'cvs-tecnicos', false, 5242880, array['application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Subida pública de CV técnico" on storage.objects;
create policy "Subida pública de CV técnico" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'cvs-tecnicos' and name ~ '^[A-Za-z0-9-]{8,64}\.pdf$');
drop policy if exists "Admins leen CV técnicos" on storage.objects;
create policy "Admins leen CV técnicos" on storage.objects for select to authenticated
  using (bucket_id = 'cvs-tecnicos' and public.is_admin());
drop policy if exists "Admins borran CV técnicos" on storage.objects;
create policy "Admins borran CV técnicos" on storage.objects for delete to authenticated
  using (bucket_id = 'cvs-tecnicos' and public.is_admin());
