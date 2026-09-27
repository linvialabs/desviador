-- BIKEGRID · Bici Jobs: ofertas de trabajo y postulaciones
-- Ejecutar en Supabase → SQL Editor. Requiere schema.sql y admin.sql (usa public.is_admin()). Se puede re-ejecutar.

-- ============ 1. Ofertas de trabajo ============
-- Flujo: el negocio envía el aviso desde la web (queda "pendiente") → coordinas el pago o su Plan Pro por WhatsApp
-- → en Table Editor cambias estado a 'publicado' (y opcionalmente publicado_hasta = hoy + 30 días).
create table if not exists public.ofertas_empleo (
  id              uuid primary key default gen_random_uuid(),
  comercio_id     uuid references public.comercios(id) on delete set null,   -- ficha del negocio en el mapa (opcional, la asignas tú)
  empresa         text not null check (char_length(empresa) between 2 and 80),
  puesto          text not null check (char_length(puesto) between 3 and 80),
  area            text not null default 'otro' check (area in ('taller','ventas','logistica','guia','otro')),
  modalidad       text not null default 'presencial' check (modalidad in ('presencial','terreno','mixto')),
  comuna          text not null check (char_length(comuna) between 2 and 60),
  region          text not null check (region in ('arica','tarapaca','antofagasta','atacama','coquimbo','valparaiso','metropolitana','ohiggins','maule','nuble','biobio','araucania','losrios','loslagos','aysen','magallanes')),
  sueldo          text check (char_length(sueldo) <= 60),
  descripcion     text not null check (char_length(descripcion) between 15 and 800),
  requisitos      text not null check (char_length(requisitos) between 5 and 600),
  whatsapp        text not null check (whatsapp ~ '^[0-9]{8,15}$'),           -- donde el negocio recibe los CVs (público)
  pro_declarado   boolean not null default false,                             -- el negocio dice tener Plan Pro (verifícalo)
  destacado       boolean not null default false,
  estado          text not null default 'pendiente' check (estado in ('pendiente','publicado','cerrado')),
  publicado_hasta date,                                                       -- null = sin vencimiento
  created_at      timestamptz not null default now()
);
create index if not exists ofertas_empleo_estado_idx on public.ofertas_empleo (estado, created_at desc);

alter table public.ofertas_empleo enable row level security;
revoke all on public.ofertas_empleo from anon, authenticated;

-- El público ve solo avisos publicados y vigentes
grant select (id, comercio_id, empresa, puesto, area, modalidad, comuna, region, sueldo, descripcion, requisitos, whatsapp, destacado, created_at)
  on public.ofertas_empleo to anon, authenticated;
drop policy if exists "Ofertas publicadas visibles" on public.ofertas_empleo;
create policy "Ofertas publicadas visibles" on public.ofertas_empleo for select to anon, authenticated
  using (estado = 'publicado' and (publicado_hasta is null or publicado_hasta >= current_date));

-- El público envía avisos, que siempre quedan pendientes (no puede publicarlos, destacarlos ni asignar una ficha)
grant insert (empresa, puesto, area, modalidad, comuna, region, sueldo, descripcion, requisitos, whatsapp, pro_declarado)
  on public.ofertas_empleo to anon, authenticated;
drop policy if exists "Envío público de ofertas" on public.ofertas_empleo;
create policy "Envío público de ofertas" on public.ofertas_empleo for insert to anon, authenticated
  with check (estado = 'pendiente' and not destacado and comercio_id is null and publicado_hasta is null);

-- Admins: todo
grant select, insert, update, delete on public.ofertas_empleo to authenticated;
drop policy if exists "Admins leen ofertas" on public.ofertas_empleo;
create policy "Admins leen ofertas" on public.ofertas_empleo for select to authenticated using (public.is_admin());
drop policy if exists "Admins crean ofertas" on public.ofertas_empleo;
create policy "Admins crean ofertas" on public.ofertas_empleo for insert to authenticated with check (public.is_admin());
drop policy if exists "Admins editan ofertas" on public.ofertas_empleo;
create policy "Admins editan ofertas" on public.ofertas_empleo for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins borran ofertas" on public.ofertas_empleo;
create policy "Admins borran ofertas" on public.ofertas_empleo for delete to authenticated using (public.is_admin());

-- ============ 2. Postulaciones ============
-- Copia de cada postulación (además del WhatsApp a la tienda). Datos personales: solo admins los leen.
create table if not exists public.postulaciones (
  id          uuid primary key default gen_random_uuid(),
  oferta_id   uuid references public.ofertas_empleo(id) on delete set null,
  comercio_id uuid references public.comercios(id) on delete set null,
  puesto      text not null check (char_length(puesto) <= 120),
  empresa     text not null check (char_length(empresa) <= 120),
  nombre      text not null check (char_length(nombre) between 2 and 80),
  telefono    text not null check (telefono ~ '^[0-9]{8,15}$'),
  email       text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  experiencia text not null check (experiencia in ('menos_1','1_2','3_5','6_10','mas_10')),
  cv_url      text check (cv_url ~* '^https?://' and char_length(cv_url) <= 300),
  mensaje     text check (char_length(mensaje) <= 400),
  created_at  timestamptz not null default now()
);
create index if not exists postulaciones_created_at_idx on public.postulaciones (created_at desc);

alter table public.postulaciones enable row level security;
revoke all on public.postulaciones from anon, authenticated;
grant insert (oferta_id, comercio_id, puesto, empresa, nombre, telefono, email, experiencia, cv_url, mensaje)
  on public.postulaciones to anon, authenticated;
drop policy if exists "Postulación pública" on public.postulaciones;
create policy "Postulación pública" on public.postulaciones for insert to anon, authenticated with check (true);

grant select, delete on public.postulaciones to authenticated;
drop policy if exists "Admins leen postulaciones" on public.postulaciones;
create policy "Admins leen postulaciones" on public.postulaciones for select to authenticated using (public.is_admin());
drop policy if exists "Admins borran postulaciones" on public.postulaciones;
create policy "Admins borran postulaciones" on public.postulaciones for delete to authenticated using (public.is_admin());

-- ============ 3. Vacantes estandarizadas (publicador para tiendas) ============
-- Columnas nuevas del formulario "Publicar vacante". La web sigue funcionando sin ellas (usa puesto / requisitos).
alter table public.ofertas_empleo add column if not exists cargo text
  check (cargo in ('mecanico','vendedor_tecnico','jefe_tienda','guia_shuttle'));
alter table public.ofertas_empleo add column if not exists jornada text
  check (jornada in ('full_time','part_time','temporada'));
alter table public.ofertas_empleo add column if not exists sucursal text
  check (char_length(sucursal) <= 80);
alter table public.ofertas_empleo add column if not exists requisitos_badges text[] not null default '{}'
  check (cardinality(requisitos_badges) <= 12 and requisitos_badges <@ array[
    'sram_axs','shimano_di2','mecanico_tradicional','fox_rockshox','purgado_hidraulico',
    'ebike_bosch','ebike_brose','ebike_shimano_steps','ebike_specialized','enrayado','carbono','montaje']::text[]);
grant select (cargo, jornada, sucursal, requisitos_badges) on public.ofertas_empleo to anon, authenticated;
grant insert (cargo, jornada, sucursal, requisitos_badges) on public.ofertas_empleo to anon, authenticated;
