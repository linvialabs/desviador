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
2. Pega y ejecuta [`supabase/schema.sql`](supabase/schema.sql) (el mismo SQL está comentado al inicio del `<script>` de `index.html`).
3. En **Project Settings → API** copia la *Project URL* y la *anon public key* y pégalas en `SUPABASE_URL` y `SUPABASE_ANON_KEY` dentro de `index.html`.

Mientras no estén configuradas, el mapa muestra los puntos de respaldo ("datos de ejemplo") y el registro de negocios queda desactivado.

**Aprobar una solicitud:** Table Editor → `comercios` → cambia `estado` a `aprobado` (y marca `es_amigo_trail` o `destacado` si corresponde).

**Qué protege el esquema:** el público solo lee filas aprobadas y solo las columnas de la ficha (`contacto_admin`, `necesidad_personal` y `solicita_destacado` son privadas); solo puede insertar solicitudes pendientes y no puede asignarse sellos, aprobarse, editar ni borrar.
