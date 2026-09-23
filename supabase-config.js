// Configuración de Supabase compartida por ciclismo.html (sitio público) y admin.html (panel).
// Pega aquí los datos de Supabase → Project Settings → API.
// La anon key es pública por diseño: la seguridad la dan las políticas del SQL (supabase/schema.sql y supabase/admin.sql).
// NUNCA pegues aquí la service_role key.
window.DESVIADOR_CONFIG = {
  SUPABASE_URL: 'https://ynlrlqtxhueznrrrnlda.supabase.co',
  SUPABASE_ANON_KEY: 'TU_SUPABASE_ANON_KEY_AQUI',
};
