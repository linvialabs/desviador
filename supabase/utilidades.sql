-- DESVIADOR · Utilidades del día: semáforo de senderos (reportes de la comunidad) y bolsa de cupos shuttle
-- Ejecutar en Supabase → SQL Editor. Requiere schema.sql y admin.sql (usa public.is_admin()). Se puede re-ejecutar.

-- ============ 1. Reportes de estado de cerros / bikeparks ============
create table if not exists public.reportes_pista (
  id          uuid primary key default gen_random_uuid(),
  comercio_id uuid not null references public.comercios(id) on delete cascade,
  estado      text not null check (estado in ('abierto','precaucion','cerrado')),
  comentario  text check (char_length(comentario) <= 140),
  created_at  timestamptz not null default now()
);
create index if not exists reportes_pista_recientes_idx on public.reportes_pista (created_at desc);

alter table public.reportes_pista enable row level security;
revoke all on public.reportes_pista from anon, authenticated;

-- Cualquiera reporta (solo estado y comentario; la fecha la pone el servidor), y solo sobre fichas aprobadas
grant insert (comercio_id, estado, comentario) on public.reportes_pista to anon, authenticated;
drop policy if exists "Reporte público de estado" on public.reportes_pista;
create policy "Reporte público de estado" on public.reportes_pista for insert to anon, authenticated
  with check (exists (select 1 from public.comercios c where c.id = comercio_id and c.estado = 'aprobado'));

-- El público ve solo los reportes de las últimas 72 horas
grant select (comercio_id, estado, comentario, created_at) on public.reportes_pista to anon, authenticated;
drop policy if exists "Reportes recientes visibles" on public.reportes_pista;
create policy "Reportes recientes visibles" on public.reportes_pista for select to anon, authenticated
  using (created_at > now() - interval '72 hours');

-- Admins: ven todo el historial y borran reportes falsos u ofensivos
grant select, delete on public.reportes_pista to authenticated;
drop policy if exists "Admins leen reportes" on public.reportes_pista;
create policy "Admins leen reportes" on public.reportes_pista for select to authenticated using (public.is_admin());
drop policy if exists "Admins borran reportes" on public.reportes_pista;
create policy "Admins borran reportes" on public.reportes_pista for delete to authenticated using (public.is_admin());

-- ============ 2. Bolsa de shuttles: salidas programadas con cupos ============
create table if not exists public.salidas_shuttle (
  id                uuid primary key default gen_random_uuid(),
  comercio_id       uuid references public.comercios(id) on delete set null,  -- operador en el directorio (opcional)
  operador          text not null check (char_length(operador) between 2 and 80),
  destino           text not null check (char_length(destino) between 2 and 80),
  region            text not null check (region in ('arica','tarapaca','antofagasta','atacama','coquimbo','valparaiso','metropolitana','ohiggins','maule','nuble','biobio','araucania','losrios','loslagos','aysen','magallanes')),
  punto_encuentro   text check (char_length(punto_encuentro) <= 100),
  sale_at           timestamptz not null,
  cupos_total       int not null check (cupos_total between 1 and 60),
  cupos_disponibles int not null check (cupos_disponibles >= 0 and cupos_disponibles <= cupos_total),
  precio            int check (precio is null or precio >= 0),                 -- CLP por persona
  whatsapp          text not null check (whatsapp ~ '^[0-9]{8,15}$'),
  notas             text check (char_length(notas) <= 200),
  publicado         boolean not null default true,
  created_at        timestamptz not null default now()
);
create index if not exists salidas_shuttle_sale_at_idx on public.salidas_shuttle (sale_at);

alter table public.salidas_shuttle enable row level security;
revoke all on public.salidas_shuttle from anon, authenticated;

-- El público ve las salidas publicadas que aún no parten (o partieron hace menos de 1 h)
grant select (id, operador, destino, region, punto_encuentro, sale_at, cupos_total, cupos_disponibles, precio, whatsapp, notas)
  on public.salidas_shuttle to anon, authenticated;
drop policy if exists "Salidas publicadas visibles" on public.salidas_shuttle;
create policy "Salidas publicadas visibles" on public.salidas_shuttle for select to anon, authenticated
  using (publicado and sale_at > now() - interval '1 hour');

-- Admins publican, editan cupos y borran (Table Editor → salidas_shuttle)
grant select, insert, update, delete on public.salidas_shuttle to authenticated;
drop policy if exists "Admins leen salidas" on public.salidas_shuttle;
create policy "Admins leen salidas" on public.salidas_shuttle for select to authenticated using (public.is_admin());
drop policy if exists "Admins crean salidas" on public.salidas_shuttle;
create policy "Admins crean salidas" on public.salidas_shuttle for insert to authenticated with check (public.is_admin());
drop policy if exists "Admins editan salidas" on public.salidas_shuttle;
create policy "Admins editan salidas" on public.salidas_shuttle for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins borran salidas" on public.salidas_shuttle;
create policy "Admins borran salidas" on public.salidas_shuttle for delete to authenticated using (public.is_admin());
