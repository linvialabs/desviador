-- DESVIADOR · Guías & Instructores: categoría "guias" y campos del perfil
-- Ejecutar en Supabase → SQL Editor, después de schema.sql y admin.sql. Se puede re-ejecutar.

-- 1) Nueva categoría
alter table public.comercios drop constraint if exists comercios_categoria_check;
alter table public.comercios add constraint comercios_categoria_check
  check (categoria in ('talleres','tiendas','clases','senderos','tours','guias'));

-- 2) Campos del perfil de guía (vacíos para el resto de las fichas)
alter table public.comercios add column if not exists foto_url text
  check (foto_url ~* '^https://' and char_length(foto_url) <= 300);
alter table public.comercios add column if not exists zonas text[]
  check (cardinality(zonas) <= 12 and char_length(array_to_string(zonas, ',')) <= 400);
alter table public.comercios add column if not exists certificaciones text[]
  check (cardinality(certificaciones) <= 10 and char_length(array_to_string(certificaciones, ',')) <= 600);
alter table public.comercios add column if not exists idiomas text[]
  check (cardinality(idiomas) <= 6 and char_length(array_to_string(idiomas, ',')) <= 120);
alter table public.comercios add column if not exists disciplinas text[]
  check (disciplinas <@ array['enduro','gravel','emtb','downhill','xc','principiantes','ruta','bikepacking']::text[]);
alter table public.comercios add column if not exists tarifa text
  check (char_length(tarifa) <= 60);

-- 3) Permisos: el público lee el perfil (solo de fichas aprobadas, por la política existente)
--    y puede enviarlo al registrarse (queda pendiente, igual que cualquier ficha)
grant select (foto_url, zonas, certificaciones, idiomas, disciplinas, tarifa) on public.comercios to anon, authenticated;
grant insert (foto_url, zonas, certificaciones, idiomas, disciplinas, tarifa) on public.comercios to anon, authenticated;
grant update (foto_url, zonas, certificaciones, idiomas, disciplinas, tarifa) on public.comercios to authenticated; -- admins (política de admin.sql)
