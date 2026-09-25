# DESVIADOR

Ciclismo independiente y técnico en Chile.

Página estática en un solo archivo (`index.html`), hecha con Tailwind CSS (CDN) y Leaflet.js:

- Portada con el mapa como protagonista: búsqueda, accesos directos ("¿Qué buscas hoy?"), filtro por zona y ficha lateral de cada lugar
- Últimas noticias / Tech con etiquetas y tiempo de lectura
- Bolsa de empleo y convocatorias de paleros
- Anúnciate: ficha básica gratis y ficha destacada
- Formulario para registrar negocios (se guarda en Supabase y queda pendiente de revisión), publicar avisos o enviar datos (estos dos aún no se guardan)

**Sitio:** https://linvialabs.github.io/desviador/

## Editar los puntos del mapa

En `index.html`, busca `const puntosIniciales = [` y agrega objetos con este formato:

```js
{ id: 'mi-taller', nombre: 'Mi Taller', categoria: 'talleres', comuna: 'Valdivia', region: 'losrios', coords: [-39.81, -73.24],
  verificado: true, destacado: false, direccion: 'Av. Ejemplo 123', whatsapp: '569XXXXXXXX', horario: 'Lun a Vie 10:00–19:00' },
```

Si `whatsapp` tiene número, la ficha muestra el botón "WhatsApp directo". Lo que dejes en `null` aparece como "Por confirmar".

Categorías: `tiendas`, `talleres`, `clases`, `senderos`, `tours`.
Regiones: `valparaiso`, `metropolitana`, `nuble`, `biobio`, `araucania`, `losrios` (se definen en `REGIONES`).

## Conectar Supabase

1. Crea un proyecto en https://supabase.com y abre **SQL Editor**.
2. Ejecuta [`supabase/schema.sql`](supabase/schema.sql): crea la tabla `comercios`, sus reglas de seguridad y carga los 7 puntos iniciales.
3. En **Project Settings → API** copia la *Project URL* y la *anon public key* y pégalas en [`supabase-config.js`](supabase-config.js). Las usan el sitio y el panel. **Nunca** pegues la `service_role key`.

Mientras no estén configuradas, el mapa muestra los puntos de respaldo ("datos de ejemplo") y el registro de negocios queda desactivado.

**Qué protege el esquema:** el público solo lee filas aprobadas y solo las columnas de la ficha (`contacto_admin` y `solicita_destacado` son privadas; `necesidad_personal` es pública y alimenta Bici Jobs); solo puede insertar solicitudes pendientes y no puede asignarse sellos, aprobarse, editar ni borrar.

## Panel de administración (`admin.html`)

1. Ejecuta [`supabase/admin.sql`](supabase/admin.sql) en el SQL Editor (después de `schema.sql`).
2. En **Authentication → Users → Add user** crea tu usuario (correo y contraseña, marcando *Auto Confirm User*).
3. En la última sección de `admin.sql`, reemplaza `TU_CORREO_ADMIN@ejemplo.cl` por ese correo y ejecútala: eso te agrega a la tabla `admins`.
4. Recomendado: en **Authentication → Sign In / Providers → Email** desactiva *Allow new users to sign up*.
5. Entra a `https://linvialabs.github.io/desviador/admin.html`.

Solo los usuarios de la tabla `admins` pueden ver datos privados, aprobar, editar o eliminar. Una cuenta creada por otra persona puede iniciar sesión, pero el panel la rechaza y la base de datos no le permite cambiar nada.

## Leads del gate de contacto (correo + qué pedalea)

El mapa, los pines y las fichas se ven sin cuenta. Solo **WhatsApp**, **Postular** y **Guardar spot** piden una vez correo + "¿Qué pedaleás?". Tras completarlo, el navegador queda desbloqueado (`localStorage` → `desviador-gate`) y la acción se ejecuta.

**Destino de los leads (configurar una vez):**

1. **Supabase (principal):** ejecuta [`supabase/leads.sql`](supabase/leads.sql) en el SQL Editor (después de `schema.sql` y `admin.sql`). Crea la tabla `leads`: el público solo puede insertar; solo admins pueden leer. Los ves en **Table Editor → leads** (o *Export to CSV*).
2. **Respaldo opcional:** en [`supabase-config.js`](supabase-config.js) completa `LEADS_WEBHOOK_URL` con un endpoint que acepte `POST` JSON (por ejemplo, un formulario de [Formspree](https://formspree.io) o un Google Apps Script). Se usa solo si falla Supabase.

**No se pierden leads:** cada lead se guarda primero en `localStorage` (`desviador-leads-pendientes`) y se borra de ahí solo cuando llega a su destino; si falla, se reintenta en la próxima visita.

**Eventos (analytics mínimos):** `gate_opened`, `gate_submitted`, `gate_dismissed`, `whatsapp_clicked_after_unlock`. Se ven en la consola del navegador (`[DESVIADOR analytics]`), en `window.desviadorEvents` y se envían a `window.dataLayer` si agregas Google Tag Manager.

**Para probar de nuevo el modal:** en la consola del navegador, `localStorage.removeItem('desviador-gate')` y recarga.

## Ficha Pro (monetización B2B)

- Una ficha es **Pro** cuando el equipo le activa **Destacar** en el panel (o si algún día existe la columna `is_pro`). Se ve con borde dorado, sello `✔ Verificado`, botón `💬 Contactar por WhatsApp` y aparece primero en el directorio.
- Las fichas que no son Pro muestran `⚙️ ¿Eres el dueño? Activa tu Ficha Pro`, y el directorio completo tiene un banner para registrar o destacar negocios.
- Para que esos botones abran WhatsApp con el mensaje ya escrito, completa `SALES_WHATSAPP` en [`supabase-config.js`](supabase-config.js) (solo dígitos, con 56; ej. `56912345678`). Si queda vacío, se abre el formulario de registro con el nombre, la comuna y el pin ya cargados, y la solicitud llega al panel como “Pide destacado”.

## Arma tu Salida / Viaje (configurador de 4 pasos)

- Botón `🗺️ Arma tu Salida / Viaje` en el encabezado (y flotante en móviles). Pide disciplina, nivel y terreno, logística y servicios, destino, fecha, grupo y contacto.
- **WhatsApp:** edita `const WHATSAPP_ADMIN = '569XXXXXXXX'` en `index.html`, o completa `SALES_WHATSAPP` en `supabase-config.js`. Se usa el primero que sea un número válido. Al enviar, se abre WhatsApp con el plan ya redactado.
- **Guardar los planes:** ejecuta [`supabase/viajes.sql`](supabase/viajes.sql) en Supabase → SQL Editor. Crea la tabla `planes_viaje`, donde el público solo puede insertar y solo los admins leen y cambian `estado` (nuevo → contactado → propuesta → cerrado/descartado).
- **Webhook opcional:** completa `TRIP_WEBHOOK_URL` en `supabase-config.js` (Make, n8n, Apps Script) para recibir cada plan como JSON y avisarte al instante.
- Si la red falla, el plan queda en cola en el navegador y se reintenta en la próxima visita.

## Utilidades del día (semáforo, cupos shuttle, urgencia)

Ejecuta [`supabase/utilidades.sql`](supabase/utilidades.sql) en Supabase → SQL Editor. Crea dos tablas.

### 🚦 Estado de cerros y pistas
- Los bikeparks y senderos muestran `🟢 ABIERTO / SECO`, `🟡 PRECAUCIÓN / BARRO` o `🔴 CERRADO / MANTENIMIENTO`: un punto de color en el pin, una etiqueta en la tarjeta y el detalle en la ficha.
- Cualquiera puede reportar desde la ficha con `📢 Reportar Estado`: estado más un comentario breve. Cada reporte se muestra 72 horas y manda el más reciente. Un mismo navegador puede reportar un spot una vez cada 30 minutos.
- Tabla `reportes_pista`: el público inserta (solo sobre fichas aprobadas) y ve las últimas 72 h. Borra reportes falsos desde Table Editor.
- **Estado automático por clima (Open-Meteo, gratis y sin API key):** para cada bikepark se consulta la lluvia de los últimos 7 días, en una sola llamada para todos los cerros. La respuesta queda en caché 3 horas en el navegador.
  - `🔴 CERRADO / BARRO PEGADO` si llovió más de 12 mm en 24 h o más de 20 mm en 48 h.
  - `🟢 SECO / GRIP PERFECTO` si en 48 h llovió entre 3 y 12 mm.
  - `🟡 PRECAUCIÓN / MUY SECO` si en 7 días llovió 0 mm.
  - `🟢 ABIERTO / SECO` en cualquier otro caso.
- **Prioridad:** un reporte de la comunidad de menos de 24 h prevalece sobre el clima (`📢 Validado por la comunidad`). Si no hay, se muestra el cálculo (`🤖 Calculado por Clima / Satélite`). Si Open-Meteo no responde, se usa el último reporte de la comunidad de hasta 72 h.
- Opcional: `REPORTS_WEBHOOK_URL` en `supabase-config.js` avisa cada reporte a Make o n8n. Sin base ni webhook, el reporte se envía por WhatsApp a `SALES_WHATSAPP`.

### 🚐 Cupos Shuttle
- Tabla `salidas_shuttle`. Por ahora, las salidas las publicas tú en Table Editor, con destino, región, punto de encuentro, fecha y hora (`sale_at`), cupos, precio, WhatsApp del operador y notas.
- Cuando un operador te avisa que vendió cupos, baja `cupos_disponibles`. Para ocultar una salida, marca `publicado = false`.
- Cada salida tiene un botón `💬 Reservar Cupo por WhatsApp` con el mensaje ya armado hacia el operador.

### 🚨 Repuesto / Taller de urgencia
- Usa el GPS (o la comuna elegida a mano si no hay permiso) para mostrar talleres y tiendas a 5, 10 o 20 km. Primero aparecen los que hacen mantención o venden repuestos, luego el resto por distancia.
- Cada resultado tiene `🧭 Cómo llegar` (Google Maps o Waze) y `💬 Consultar Stock WhatsApp`. Este botón no pasa por el gate de correo: en una emergencia no se piden datos.
