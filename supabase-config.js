// Configuración de Supabase compartida por ciclismo.html (sitio público) y admin.html (panel).
// Pega aquí los datos de Supabase → Project Settings → API.
// La anon key es pública por diseño: la seguridad la dan las políticas del SQL (supabase/schema.sql y supabase/admin.sql).
// NUNCA pegues aquí la service_role key.
window.DESVIADOR_CONFIG = {
  SUPABASE_URL: 'https://ynlrlqtxhueznrrrnlda.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_5ytCZP2agnKihBXxK8Ipuw_4JWHajPd',
  // Opcional: respaldo para los leads del gate (correo + qué pedalea) si Supabase falla.
  // Ej: endpoint de Formspree (https://formspree.io/f/xxxx) o Google Apps Script. Vacío = solo Supabase.
  LEADS_WEBHOOK_URL: '',
  // WhatsApp comercial de DESVIADOR para "Activa tu Ficha Pro" (solo dígitos, con 56). Vacío = se usa el formulario.
  SALES_WHATSAPP: '',
};
