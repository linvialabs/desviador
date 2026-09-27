-- DESVIADOR · Medición para el "Informe mensual de visitas y clics" del Plan PRO
-- Ejecutar en Supabase → SQL Editor. Requiere schema.sql y admin.sql (usa public.is_admin()). Se puede re-ejecutar.
-- Anónimo: solo se guarda la ficha, el tipo de evento y la fecha (nada del visitante).

create table if not exists public.eventos_ficha (
  id          bigint generated always as identity primary key,
  comercio_id uuid not null references public.comercios(id) on delete cascade,
  tipo        text not null check (tipo in ('vista','whatsapp','como_llegar','cotizar','redes')),
  created_at  timestamptz not null default now()
);
create index if not exists eventos_ficha_comercio_idx on public.eventos_ficha (comercio_id, created_at desc);

alter table public.eventos_ficha enable row level security;
revoke all on public.eventos_ficha from anon, authenticated;

-- El sitio registra eventos solo de fichas aprobadas; nadie del público puede leerlos
grant insert (comercio_id, tipo) on public.eventos_ficha to anon, authenticated;
drop policy if exists "Registro anónimo de eventos" on public.eventos_ficha;
create policy "Registro anónimo de eventos" on public.eventos_ficha for insert to anon, authenticated
  with check (exists (select 1 from public.comercios c where c.id = comercio_id and c.estado = 'aprobado'));

grant select on public.eventos_ficha to authenticated;
drop policy if exists "Admins leen eventos" on public.eventos_ficha;
create policy "Admins leen eventos" on public.eventos_ficha for select to authenticated using (public.is_admin());

-- Informe mensual por ficha (hora de Chile). Solo admins ven datos: la vista respeta las políticas de la tabla.
create or replace view public.informe_mensual_fichas with (security_invoker = true) as
select
  c.id                                                    as comercio_id,
  c.nombre_comercio,
  c.categoria,
  c.comuna,
  c.destacado                                             as es_pro,
  to_char(date_trunc('month', e.created_at at time zone 'America/Santiago'), 'YYYY-MM') as mes,
  count(*) filter (where e.tipo = 'vista')                as vistas,
  count(*) filter (where e.tipo = 'whatsapp')             as clics_whatsapp,
  count(*) filter (where e.tipo = 'como_llegar')          as clics_como_llegar,
  count(*) filter (where e.tipo = 'cotizar')              as cotizaciones,
  count(*) filter (where e.tipo = 'redes')                as clics_redes
from public.eventos_ficha e
join public.comercios c on c.id = e.comercio_id
group by c.id, c.nombre_comercio, c.categoria, c.comuna, c.destacado, 6;

revoke all on public.informe_mensual_fichas from anon;
grant select on public.informe_mensual_fichas to authenticated;

-- Uso (SQL Editor): select * from informe_mensual_fichas where mes = to_char(now(), 'YYYY-MM') order by vistas desc;
