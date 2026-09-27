-- DESVIADOR · Ecosistema digital de las fichas: web, Instagram, TikTok, YouTube y mapa de pistas
-- Ejecutar en Supabase → SQL Editor, después de schema.sql y admin.sql. Se puede re-ejecutar.
-- El sitio los muestra solo en fichas Pro (destacado) y guías; se cargan desde el panel admin (Editar).

alter table public.comercios add column if not exists website_url text
  check (website_url ~* '^https?://[^[:space:]/]+\.[^[:space:]]+$' and char_length(website_url) <= 300);
alter table public.comercios add column if not exists instagram_handle text
  check (instagram_handle ~ '^[A-Za-z0-9._]{1,30}$');
alter table public.comercios add column if not exists tiktok_handle text
  check (tiktok_handle ~ '^[A-Za-z0-9._]{2,24}$');
alter table public.comercios add column if not exists youtube_channel text
  check (char_length(youtube_channel) <= 200 and (youtube_channel ~ '^[A-Za-z0-9._-]{3,100}$' or youtube_channel ~* '^https://(www\.)?(youtube\.com|youtu\.be)/'));
alter table public.comercios add column if not exists strava_or_trailforks_url text
  check (strava_or_trailforks_url ~* '^https://' and char_length(strava_or_trailforks_url) <= 300);

-- Lectura pública (son datos públicos del negocio) · edición solo admins (política de admin.sql)
grant select (website_url, instagram_handle, tiktok_handle, youtube_channel, strava_or_trailforks_url) on public.comercios to anon, authenticated;
grant update (website_url, instagram_handle, tiktok_handle, youtube_channel, strava_or_trailforks_url) on public.comercios to authenticated;

-- Informe mensual: los clics a redes y web cuentan como "redes" (solo si ya ejecutaste planes.sql)
do $$
begin
  if to_regclass('public.eventos_ficha') is not null then
    alter table public.eventos_ficha drop constraint if exists eventos_ficha_tipo_check;
    alter table public.eventos_ficha add constraint eventos_ficha_tipo_check
      check (tipo in ('vista','whatsapp','como_llegar','cotizar','redes'));
    execute $v$
      create or replace view public.informe_mensual_fichas with (security_invoker = true) as
      select c.id as comercio_id, c.nombre_comercio, c.categoria, c.comuna, c.destacado as es_pro,
        to_char(date_trunc('month', e.created_at at time zone 'America/Santiago'), 'YYYY-MM') as mes,
        count(*) filter (where e.tipo = 'vista') as vistas,
        count(*) filter (where e.tipo = 'whatsapp') as clics_whatsapp,
        count(*) filter (where e.tipo = 'como_llegar') as clics_como_llegar,
        count(*) filter (where e.tipo = 'cotizar') as cotizaciones,
        count(*) filter (where e.tipo = 'redes') as clics_redes
      from public.eventos_ficha e join public.comercios c on c.id = e.comercio_id
      group by c.id, c.nombre_comercio, c.categoria, c.comuna, c.destacado, 6
    $v$;
  end if;
end $$;
