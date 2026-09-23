# DESVIADOR

Ciclismo independiente y técnico en Chile.

Página estática en un solo archivo (`index.html`), hecha con Tailwind CSS (CDN) y Leaflet.js:

- Portada con el mapa como protagonista: búsqueda, accesos directos ("¿Qué buscas hoy?"), filtro por zona y ficha lateral de cada lugar
- Últimas noticias / Tech con etiquetas y tiempo de lectura
- Bolsa de empleo y convocatorias de paleros
- Anúnciate: ficha básica gratis y ficha destacada
- Formulario para registrar negocios, publicar avisos o enviar datos (por ahora no envía datos a ningún servidor)

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
