-- DESVIADOR · esquema de Supabase (copia del bloque SQL de index.html)
-- Ejecutar una vez en Supabase → SQL Editor.


-- 1) TABLA PRINCIPAL DE COMERCIOS Y SENDEROS
create table if not exists public.comercios (
  id                 uuid primary key default gen_random_uuid(),
  nombre_comercio    text not null check (char_length(nombre_comercio) between 3 and 80),
  categoria          text not null check (categoria in ('talleres','tiendas','clases','senderos','tours')),
  region             text not null check (region in ('arica','tarapaca','antofagasta','atacama','coquimbo','valparaiso','metropolitana','ohiggins','maule','nuble','biobio','araucania','losrios','loslagos','aysen','magallanes')),
  comuna             text check (char_length(comuna) <= 60),
  direccion          text check (char_length(direccion) <= 120),
  latitud            numeric not null check (latitud between -56.8 and -17.2),
  longitud           numeric not null check (longitud between -77.5 and -65.5),
  whatsapp           text check (whatsapp ~ '^[0-9]{8,15}$'),
  horario            text check (char_length(horario) <= 80),
  descripcion        text check (char_length(descripcion) <= 600),
  contacto_admin     text check (char_length(contacto_admin) <= 120),     -- PRIVADO: nombre/celular del dueño
  necesidad_personal text check (char_length(necesidad_personal) <= 200), -- PRIVADO: si busca mecánico/vendedor
  solicita_destacado boolean not null default false,                      -- PRIVADO: pidió ficha destacada
  es_amigo_trail     boolean not null default false,                      -- Sello "Amiga del Trail" (solo lo asigna el admin)
  destacado          boolean not null default false,                      -- Ficha destacada pagada (solo lo asigna el admin)
  estado             text not null default 'pendiente' check (estado in ('pendiente','aprobado','rechazado')),
  created_at         timestamptz not null default now()
);
create index if not exists comercios_estado_idx on public.comercios (estado);

-- 2) POLÍTICAS DE SEGURIDAD (RLS)
alter table public.comercios enable row level security;

drop policy if exists "Lectura pública de comercios aprobados" on public.comercios;
create policy "Lectura pública de comercios aprobados"
  on public.comercios for select to anon, authenticated
  using (estado = 'aprobado');

drop policy if exists "Inserción pública de solicitudes" on public.comercios;
create policy "Inserción pública de solicitudes"
  on public.comercios for insert to anon, authenticated
  with check (estado = 'pendiente' and es_amigo_trail = false and destacado = false);

-- 3) PERMISOS POR COLUMNA
-- RLS filtra FILAS, no columnas: sin esto, contacto_admin sería legible por cualquiera.
-- El público solo puede leer las columnas de la ficha y solo puede escribir las del formulario
-- (estado, sellos, id y fecha quedan siempre con su valor por defecto).
revoke all on public.comercios from anon, authenticated;
grant select (id, nombre_comercio, categoria, region, comuna, direccion, latitud, longitud,
              whatsapp, horario, descripcion, es_amigo_trail, destacado, estado)
  on public.comercios to anon, authenticated;
grant insert (nombre_comercio, categoria, region, comuna, direccion, latitud, longitud,
              whatsapp, horario, descripcion, contacto_admin, necesidad_personal, solicita_destacado)
  on public.comercios to anon, authenticated;

-- 4) (Opcional) Cargar los 7 puntos iniciales ya aprobados. Ejecutar solo una vez.
insert into public.comercios (nombre_comercio, categoria, region, comuna, latitud, longitud, estado) values
  ('Multibike / Specialized Concepción',   'tiendas',  'biobio',        'Concepción',            -36.8275, -73.0503, 'aprobado'),
  ('Giant / Liv Vitacura',                 'tiendas',  'metropolitana', 'Vitacura',              -33.3881, -70.5678, 'aprobado'),
  ('Laguna Off Road / Bici Taller Temuco', 'talleres', 'araucania',     'Temuco',                -38.7397, -72.5901, 'aprobado'),
  ('Bikepark Nevados de Chillán',          'senderos', 'nuble',         'Pinto',                 -36.9061, -71.4111, 'aprobado'),
  ('Parque Las Palmas',                    'senderos', 'valparaiso',    'Puchuncaví',            -32.7412, -71.4015, 'aprobado'),
  ('Huilo Huilo Outdoor Experience',       'senderos', 'losrios',       'Panguipulli (Neltume)', -39.8667, -71.9167, 'aprobado'),
  ('El Durazno',                           'senderos', 'metropolitana', 'Lo Barnechea',          -33.3486, -70.4958, 'aprobado');

-- APROBAR UNA SOLICITUD: Table Editor → comercios → cambia "estado" a 'aprobado'
-- (y marca es_amigo_trail / destacado si corresponde).
