# BIKEGRID

Ciclismo independiente y técnico en Chile.

Página estática en un solo archivo (`index.html`), hecha con Tailwind CSS (CDN) y Leaflet.js:

- Portada con el mapa como protagonista: búsqueda, accesos directos ("¿Qué buscas hoy?"), filtro por zona y ficha lateral de cada lugar
- Últimas noticias / Tech con etiquetas y tiempo de lectura
- Bolsa de empleo y convocatorias de paleros
- Anúnciate: ficha básica gratis y ficha destacada
- Formulario para registrar negocios (se guarda en Supabase y queda pendiente de revisión), publicar avisos o enviar datos (estos dos aún no se guardan)

**Sitio:** https://linvialabs.github.io/desviador/

## Español de Chile y UX de confianza

- **Español de Chile (tuteo):** el gate, la nota de privacidad y los errores ya no usan voseo ("Desbloquea el contacto", "Deja tu correo", "¿Qué pedaleas?", "Sin spam").
- **El gate promete solo lo que la ficha tiene:** un celular chileno (569…) o un número extranjero muestra **WhatsApp**; un fijo chileno (56 2…, 56 32…) muestra **Llamar** (`tel:`). Los dos van con el mismo desbloqueo por correo (`localStorage`, sin contraseña). Sin número, la ficha dice "Sin WhatsApp aún" con "¿Eres el dueño? Activa tu ficha", y el gate de Guardar usa un texto genérico.
- **Datos incompletos sin ruido:** las filas de horario y dirección vacías se ocultan (antes decían "Por confirmar"). "Redes y web no verificadas" quedó en una sola línea discreta. Nunca se inventan números, coordenadas ni horarios.
- **Vacíos honestos:** Bici Jobs lleva el badge "Próximamente" en el menú mientras no haya avisos reales, sin pestañas en 0. El buscador de candidatos muestra un estado vacío con CTA en vez de filtros en 0. Los accesos a Guías se ocultan hasta que exista el primer perfil. Se quitó el enlace muerto "Ver archivo", y los espacios publicitarios dicen "Espacio disponible".
- **Home más liviana:** el programa Trail Care (10%) se explica en un solo lugar (Planes, `#trailcare`) y el banner Ficha Pro de la home quedó compacto, con un CTA. Los precios no cambian.

**Consola en producción:** los 404 de `leads`, `ofertas_empleo`, `perfiles_tecnicos`, `eventos_ficha`, `marcas`, `comercio_marcas` y `reportes_pista` significan que esos SQL aún no se ejecutan. Mientras no exista `leads`, los correos del gate quedan en cola en el navegador de cada visitante. El 401/403 de `comercios` es el `grant` pendiente de `necesidad_personal`; la web lo recuerda por 12 h para no repetirlo. Si Open-Meteo responde 429 o 5xx, el clima se pausa 30 min sin romper la UI.

**Tailwind CDN:** el sitio usa `cdn.tailwindcss.com`, que avisa en la consola que no es para producción. Funciona igual. Pasar a un CSS compilado (Tailwind CLI) queda para otro PR.

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

El mapa, los pines y las fichas se ven sin cuenta. Solo **WhatsApp / Llamar**, **Postular** y **Guardar spot** piden una vez correo + "¿Qué pedaleas?". Tras completarlo, el navegador queda desbloqueado (`localStorage` → `desviador-gate`) y la acción se ejecuta.

**Destino de los leads (configurar una vez):**

1. **Supabase (principal):** ejecuta [`supabase/leads.sql`](supabase/leads.sql) en el SQL Editor (después de `schema.sql` y `admin.sql`). Crea la tabla `leads`: el público solo puede insertar; solo admins pueden leer. Los ves en **Table Editor → leads** (o *Export to CSV*).
2. **Respaldo opcional:** en [`supabase-config.js`](supabase-config.js) completa `LEADS_WEBHOOK_URL` con un endpoint que acepte `POST` JSON (por ejemplo, un formulario de [Formspree](https://formspree.io) o un Google Apps Script). Se usa solo si falla Supabase.

**No se pierden leads:** cada lead se guarda primero en `localStorage` (`desviador-leads-pendientes`) y se borra de ahí solo cuando llega a su destino; si falla, se reintenta en la próxima visita.

**Eventos (analytics mínimos):** `gate_opened`, `gate_submitted`, `gate_dismissed`, `whatsapp_clicked_after_unlock`. Se ven en la consola del navegador (`[BIKEGRID analytics]`), en `window.desviadorEvents` y se envían a `window.dataLayer` si agregas Google Tag Manager.

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

## Bici Jobs (portal de empleo)

Ejecuta [`supabase/empleos.sql`](supabase/empleos.sql) en Supabase → SQL Editor. Crea las tablas `ofertas_empleo` y `postulaciones`.

- **Ofertas:** cada tarjeta muestra puesto, empresa, comuna y región, modalidad, rango salarial (opcional) y área (Taller, Ventas, Logística, Guía). Las destacadas y las de negocios Pro llevan borde dorado y aparecen primero. Las fichas del mapa con "¿Buscas personal?" también aparecen como ofertas.
- **📩 Postular a este Trabajo:** el postulante deja nombre, WhatsApp, email, años de experiencia, enlace a CV/LinkedIn y un mensaje. Se abre WhatsApp hacia la tienda con todo ya redactado y se guarda una copia en `postulaciones`, que solo los admins pueden leer. Si la tienda no tiene WhatsApp, la postulación queda en la base para que la hagas llegar.
- **💼 Publicar Oferta de Trabajo** ($19.990 CLP o gratis con Plan Pro): el negocio completa el aviso y se abre el WhatsApp comercial (`SALES_WHATSAPP`) con el aviso redactado. El aviso queda en `ofertas_empleo` con estado `pendiente`. Cuando coordines el pago (o verifiques el Plan Pro, ver `pro_declarado`), cambia `estado` a `publicado`. Opcionalmente, pon `publicado_hasta` en hoy + 30 días y `destacado`, o vincula `comercio_id` a su ficha.
- Los avisos de ejemplo solo se ven cuando no hay base de datos conectada.

### Reclutamiento técnico: CV Técnico y buscador para tiendas

Ejecuta [`supabase/talento.sql`](supabase/talento.sql) (tabla `perfiles_tecnicos` y bucket privado `cvs-tecnicos`) y vuelve a ejecutar [`supabase/empleos.sql`](supabase/empleos.sql) (su sección 3 agrega `cargo`, `jornada`, `sucursal` y `requisitos_badges` a las vacantes). Ambos se pueden re-ejecutar.

- **CV Técnico Ciclista** (botón "Arma tu CV Técnico"): el postulante indica disponibilidad (nombre, comuna, región, modalidad Full-time / Part-time / Temporada), especialidades en chips, años y experiencia anterior, y adjunta un PDF (máx. 5 MB) o un enlace.
  - Especialidades: Transmisión (SRAM AXS, Shimano Di2, Mecánico tradicional) · Suspensiones & Frenos (Fox / RockShox, Purgado hidráulico) · E-Bikes (Bosch, Brose, Shimano Steps, Specialized) · Taller General (Enrayado, Diagnóstico de carbono, Montaje desde cero).
  - La ficha entra como `pendiente`. Revísala en Table Editor → `perfiles_tecnicos` y cambia `estado` a `publicado` para que aparezca en el buscador (`oculto` la retira).
  - El PDF queda en Storage → `cvs-tecnicos`, con el nombre guardado en `cv_path`. Solo los admins pueden abrirlo.
  - Una copia queda en el navegador del postulante: al postular a un aviso se completan sus datos y se agregan sus especialidades al mensaje de WhatsApp.
- **Buscador de candidatos** (sección "Talento técnico disponible"): filtros por grupo o especialidad exacta (por ejemplo, "E-Bikes → Diagnóstico Bosch"), por región o "Cerca de mi tienda" con radio de 10 a 100 km.
  - La distancia usa la ubicación aproximada del postulante si la compartió (redondeada a ±1 km) o, si no, el centro de su comuna.
  - El público solo ve nombre abreviado ("Matías R."), comuna, modalidad, especialidades y experiencia. Teléfono, email y CV nunca salen de la base.
  - "Solicitar contacto" abre WhatsApp comercial con la referencia del candidato: el contacto lo coordinas tú, y es un beneficio de la Ficha Pro.
- **Perfil Técnico Incógnito (Modo Anónimo):** switch destacado al inicio del CV Técnico, **activado por defecto**: "Activar Modo Incógnito (Ocultar mi nombre y tienda actual)".
  - En modo incógnito la tienda ve "Especialista E-Bike N° 4F2A1" (o "Mecánico N° …" si no domina una especialidad) con ubicación, años de experiencia, jornada y especialidades, pero nunca el nombre.
  - **Protección en la base, no solo en pantalla:** el nombre público es la columna `alias_publico`, que queda en `null` si el perfil es incógnito. `nombre_publico` dejó de ser legible para el público. Un perfil incógnito no guarda ubicación GPS (lo impide la restricción `perfiles_incognito_sin_gps`); la cercanía usa el centro de su comuna.
  - "Tienda o taller actual" es un campo **siempre privado**. Sirve para no presentar el perfil a su propio empleador, y el formulario avisa si la experiencia menciona esa tienda.
  - El código N° sale del `id` de la ficha y es estable: úsalo para identificar al candidato en Table Editor.
- **Solicitar Entrevista / Revelar Datos:** la tienda envía una propuesta (tienda, cargo, jornada, rango salarial, mensaje y WhatsApp). Se guarda en `solicitudes_entrevista` (solo admins) y se abre tu WhatsApp comercial con la referencia N°.
  - Flujo: le presentas la propuesta al candidato y, si la autoriza, cambias `estado` a `autorizada` y le envías a la tienda nombre y contacto. Si no, `rechazada`.
  - En perfiles públicos, el mismo flujo aparece como "Solicitar contacto".
  - Métricas: `cv_incognito_toggle`, `talent_contact` (con `incognito`) y `talent_reveal_sent`.
- **Publicar vacante (estandarizado):** cargo (Mecánico, Vendedor Técnico, Jefe de Tienda, Guía / Shuttle), especialidad opcional, jornada, sucursal y ubicación, requisitos clave en chips, más otros requisitos y responsabilidades. Las tarjetas muestran el cargo, la jornada, la sucursal y los requisitos clave.
  - Si aún no ejecutas la sección 3 de `empleos.sql`, la web guarda la vacante sin las columnas nuevas (el detalle igual queda en `puesto` y `requisitos`).
- Métricas: `cv_opened`, `cv_submitted`, `talent_filter`, `talent_contact`, `job_post_sent` (con cargo, jornada y cantidad de requisitos).

## Guías & Instructores

Ejecuta [`supabase/guias.sql`](supabase/guias.sql) en Supabase → SQL Editor. Agrega la categoría `guias` y los campos del perfil (`foto_url`, `zonas`, `certificaciones`, `idiomas`, `disciplinas`, `tarifa`).

- **Filtro 🧭 Guías & Instructores** en los accesos del mapa y en el directorio. Los pines de los guías tienen su propio color.
- **Ficha de perfil:** foto (o iniciales), sello `✔ Guía Verificado` (solo Guía PRO), zonas de cobertura, certificaciones, idiomas, disciplinas y tarifa orientativa. Incluye un cotizador (fecha, zona, disciplina y personas) con el botón `💬 Cotizar / Reservar Salida`, que abre WhatsApp hacia el guía con todo redactado.
- **Registro gratis (freemium):** el banner "🧭 Regístrate Gratis como Guía Local / Instructor", el filtro del directorio y cada perfil abren el formulario. El perfil entra directo a la base como ficha **pendiente**, y en el panel admin ves zonas, disciplinas, idiomas, certificaciones, tarifa y foto.
  - Antes de aprobar: verifica el perfil y ajusta el pin con **Editar** (se ubica en el centro de su comuna o región).
  - Si la base falla y hay `SALES_WHATSAPP`, el perfil se envía por WhatsApp como respaldo.
- **Guía PRO ($9.990/mes, opcional):** se activa con **Destacar**. Incluye sello `✔ Guía Verificado`, borde dorado, primero en el directorio, redes/web en el perfil y sugerencia en "Arma tu Viaje". Los guías gratis tienen perfil completo y reciben cotizaciones por WhatsApp, pero sin sello ni redes.
- La foto debe ser un enlace `https://` a una imagen (por ejemplo, de su web o Instagram).

## Planes y tarifas

La sección **Anúnciate** (`#anunciate`) muestra 3 planes y un bloque para marcas. Cada botón abre WhatsApp comercial (`SALES_WHATSAPP`) con el plan de interés ya escrito. Sin número configurado, cada botón lleva al flujo equivalente del sitio: formulario de negocio, registro de guía o ficha destacada.

| Plan | Precio | Cómo se activa |
|---|---|---|
| Gratis (Ficha básica) | $0 | Aprobar la ficha en el panel |
| Guía (perfil) | Gratis | Aprobar el perfil de guía en el panel |
| Guía PRO | $9.990/mes | **Destacar** el perfil del guía en el panel |
| Tienda / Taller PRO | $19.990/mes por local · 2° local + $9.990/mes · Enterprise (3+ locales) a medida | **Destacar** la ficha en el panel |
| Auspicios y banners regionales | A convenir | Por WhatsApp |

**Beneficios que entrega el sitio:**
- **PRO:**
  - pin dorado, borde gold y sello Verificado;
  - WhatsApp destacado en el directorio;
  - aparece primero en el directorio;
  - prioridad en 🚨 Urgencia, dentro de los talleres y tiendas técnicas;
  - avisos de Bici Jobs sin costo.
- **Guía:** aparece en la pantalla final de "Arma tu Viaje" ("Guías verificados para tu viaje") según la zona elegida.

**Informe mensual de visitas y clics:** ejecuta [`supabase/planes.sql`](supabase/planes.sql). Registra de forma anónima las vistas de cada ficha y los clics en WhatsApp, "Cómo llegar" y cotizaciones de guías. Para ver el informe del mes (SQL Editor):

```sql
select * from informe_mensual_fichas where mes = to_char(now(), 'YYYY-MM') order by vistas desc;
```

## Ecosistema digital (web y redes en las fichas)

Ejecuta [`supabase/redes.sql`](supabase/redes.sql). Agrega `website_url`, `instagram_handle`, `tiktok_handle`, `youtube_channel` y `strava_or_trailforks_url`, validados en la base (sin `javascript:`, usuarios válidos, mapas solo `https://`).

- **Fichas PRO y guías:** sección **🌐 Ecosistema Digital & Redes**.
  - Botones: `🌐 Ver Sitio Web / Catálogo`, `📸 Instagram` (abre la app en el celular), TikTok, YouTube y `🚵 Mapa de Pistas (Trailforks / Strava)`.
  - Con Instagram cargado, se despliega "Ver novedades de @usuario", con enlaces a publicaciones e historias.
- **Fichas gratis:** bloque bloqueado `🔒 Redes sociales y catálogo web no verificados.` con el botón "¿Eres el dueño? Vincula tu Instagram y Web activando tu Ficha Pro", que abre el modal de Ficha Pro.
- **Panel admin → Editar:** campos para web, Instagram, TikTok, YouTube y mapa de pistas. Acepta `@usuario`, `usuario` o la URL completa y los normaliza. Hasta ejecutar `redes.sql` aparecen desactivados.
- Los clics a redes y web se suman al informe mensual (`clics_redes` en `informe_mensual_fichas`).

## Escala del directorio (1.000+ fichas)

- **Fichas PRO siempre arriba:** en el directorio, en cada filtro y en la búsqueda del mapa, sin importar la comuna o categoría.
- **Carga de 20 en 20:** el directorio completo muestra 20 fichas y agrega 20 más al acercarse al final (`IntersectionObserver`). También hay un botón "Ver más" para teclado o navegadores sin soporte.
- **🧭 Guías Locales:** botón en el encabezado (y en el menú móvil) que filtra el mapa a guías sin mover la vista e indica cuántos hay en la zona visible. Si no hay, muestra todos los de Chile. Un segundo toque quita el filtro.

## Marca: BIKEGRID

- Antes se llamaba **DESVIADOR**. Todos los textos visibles, metadatos, logo (isotipo SVG de cuadrícula de nodos + piñón), favicon y mensajes de WhatsApp dicen **BIKEGRID**.
- La configuración ahora es `window.BIKEGRID_CONFIG` en `supabase-config.js`. El nombre anterior `DESVIADOR_CONFIG` sigue funcionando.
- **Se mantienen a propósito** las claves internas del navegador (`desviador-guardados`, `desviador-gate`, colas de envío…) y los eventos internos (`desviador:*`), para que los usuarios actuales no pierdan sus spots guardados, desbloqueos ni envíos pendientes.
- Este repositorio y su URL de GitHub Pages siguen llamándose `desviador`. Para la marca nueva, lo ideal es un dominio propio (ej. `bikegrid.cl` o `bikegrid.app`) apuntado a GitHub Pages.

## 🏷️ Marcas que trabaja cada ficha

Ejecuta [`supabase/marcas.sql`](supabase/marcas.sql). Crea un **catálogo único** de marcas (`marcas`) y la relación ficha–marca (`comercio_marcas`, donde `orden 0` es la **marca principal**).

- **Sin duplicados:** "Specialized", "specialized " y "SPECIALIZED" son la misma marca; la base calcula un `slug` normalizado (sin tildes ni mayúsculas) y no acepta repetidos. Cada marca nueva queda en el catálogo para reutilizarla después.
- **Sitio público:**
  - Cada tarjeta muestra su marca principal (🏷️ Specialized · principal).
  - La ficha muestra todas sus marcas; al tocar una, se abre el directorio filtrado.
  - El directorio tiene el filtro **🏷️ Marca** (autocompletado + marcas más trabajadas). Aparecen primero quienes tienen esa marca como **principal**, luego los PRO y después el resto.
  - La búsqueda por texto también encuentra marcas.
- **Registro:** el negocio puede indicar "Marcas que trabajas" (texto libre, en `marcas_sugeridas`). No se publica tal cual: el equipo las pasa al catálogo.
- **Panel admin → Editar → 🏷️ Marcas:**
  - Escribe y presiona Enter. Autocompleta desde el catálogo y reutiliza la marca si ya existe.
  - ☆ hace principal a una marca; ✕ la quita.
  - "Usar estas" carga las marcas sugeridas por el negocio.

## Diseño premium (sin emojis)

- **Iconos:** la interfaz no usa emojis. Los iconos son SVG monocromáticos (trazo 1,5 px, estilo Lucide) definidos como clases CSS: `<i class="i i-compass"></i>`. Toman el color del texto y no agregan dependencias externas.
- **Semáforo:** usa indicadores LED (`.led-green`, `.led-yellow`, `.led-red`, `.led-gray`).
- **Niveles del planificador:** usan los símbolos internacionales de dificultad (círculo verde, cuadrado azul, diamante negro y doble diamante).
- **Marca:** `BIKE` fino + `GRID` en verde de marca `#2e7d32` (clase `text-brand` / `bg-brand`). El isotipo combina una cuadrícula de nodos GPS con un piñón.
- **Navegación:** en mayúsculas con espaciado: MAPA · ESTADO DE PISTAS · BICI JOBS · DIRECTORIO PRO, más accesos a guías, shuttles, urgencia y el planificador.

## Tarifas por locales (multi-local / Enterprise)

La Ficha Pro se cobra por sucursal. Aparece en la sección de planes (`#multilocal`), en el banner "Activa tu Ficha Pro" y dentro del modal de verificación, donde el negocio elige cuántos locales tiene y el mensaje de WhatsApp se ajusta solo:

| Tramo | Precio | Incluye |
|---|---|---|
| Local único · Ficha Pro | $19.990 CLP / mes | Geolocalización GPS, Bici Jobs ilimitado, Sello Trail Care |
| 2° local · Segunda sucursal | + $9.990 CLP / mes | 50% de descuento en la segunda Ficha Pro |
| Plan Enterprise · 3 o más locales | Plan a medida | Plan corporativo consolidado con atención personalizada y beneficios de red |

El botón `data-plan="enterprise"` abre WhatsApp comercial con una plantilla corporativa (o el modal en modo Enterprise si `SALES_WHATSAPP` está vacío). Se reemplazó el antiguo selector mensual/semestral para no mostrar dos precios distintos para el mismo plan.

## Espacios publicitarios (BIKEGRID Ads)

Cuatro espacios con placeholders animados en CSS puro (cuadrícula en movimiento, brillo diagonal y texto con degradado; se detienen con `prefers-reduced-motion`):

| Espacio | `data-ad-slot` | Dónde | Tamaño |
|---|---|---|---|
| Leaderboard | `top` | Bajo la barra de navegación | 100% de ancho, 52–64 px de alto (máx. 80) |
| Rascacielos | `rail-left`, `rail-right` | Costados del contenido, solo ≥1280 px, visibles al dejar atrás el mapa y ocultos junto al pie de página | 160 × 600 px |
| Franja inferior | `footer` | Antes del footer, para cierres de campaña y marcas sponsor | 100% de ancho, ~56 px |

Los rascacielos nunca se muestran en pantallas de 768 px o menos. Para vender un espacio basta con configurar la creatividad en `supabase-config.js`, sin tocar el HTML:

```js
window.BIKEGRID_CONFIG = {
  // …
  ADS: {
    top:         { img: 'https://…/leaderboard-1600x80.jpg', url: 'https://marca.cl', alt: 'Marca X' },
    'rail-left': { img: 'https://…/sky-160x600.jpg',         url: 'https://tienda.cl' },
    footer:      { img: 'https://…/franja-1200x56.jpg',       url: 'https://evento.cl' },
  },
};
```

Solo se aceptan URLs `https://`. Los enlaces salen con `rel="sponsored noopener"`. Se registran `ad_impression` (una por espacio y visita, con al menos 50% visible) y `ad_clicked`; los CTA de los placeholders registran `plan_cta_clicked` con `via: publicidad:<espacio>`, útil para mostrar a un anunciante cuánta gente vio y tocó su espacio.
