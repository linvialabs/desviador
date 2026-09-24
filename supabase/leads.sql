-- DESVIADOR · Leads del gate de contacto (correo + qué pedalea)
-- Ejecutar en Supabase → SQL Editor. Requiere admin.sql (usa public.is_admin()). Se puede re-ejecutar.

create table if not exists public.leads (
  id           uuid primary key default gen_random_uuid(),
  email        text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
  intereses    text[] not null default '{}'
               check (intereses <@ array['mtb_enduro','ebike','ruta_gravel','kids_familia','dh_bikepark']::text[]),
  accion       text check (accion in ('whatsapp','postular','guardar')),  -- qué quería hacer al desbloquear
  comercio_ref text check (char_length(comercio_ref) <= 80),               -- ficha desde donde se desbloqueó
  version      int not null default 1,
  created_at   timestamptz not null default now()
);
create index if not exists leads_created_at_idx on public.leads (created_at desc);

alter table public.leads enable row level security;

-- El público solo puede INSERTAR (no leer, editar ni borrar): los correos no quedan expuestos.
revoke all on public.leads from anon, authenticated;
grant insert (email, intereses, accion, comercio_ref, version) on public.leads to anon, authenticated;
drop policy if exists "Captura pública de leads" on public.leads;
create policy "Captura pública de leads"
  on public.leads for insert to anon, authenticated
  with check (true);

-- Solo admins pueden leerlos (también se ven en Table Editor → leads).
grant select on public.leads to authenticated;
drop policy if exists "Admins leen leads" on public.leads;
create policy "Admins leen leads"
  on public.leads for select to authenticated
  using (public.is_admin());
