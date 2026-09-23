# DESVIADOR

Ciclismo independiente y técnico en Chile.

Página estática en un solo archivo (`index.html`), hecha con Tailwind CSS (CDN) y Leaflet.js:

- Últimas noticias / Tech
- Mapa comunitario con puntos reales de Chile, filtros por categoría y por zona, y capas oscura, satelital, híbrida, topográfica y OSM
- Bolsa de trabajo y comunidad
- Formulario de envío anónimo (por ahora solo en la página; no envía datos a ningún servidor)

**Sitio:** https://linvialabs.github.io/desviador/

## Editar los puntos del mapa

En `index.html`, busca `const puntosIniciales = [` y agrega objetos con este formato:

```js
{ id: 'mi-taller', nombre: 'Mi Taller', categoria: 'talleres', ciudad: 'Valdivia', region: 'losrios', coords: [-39.81, -73.24] },
```

Categorías: `tiendas`, `talleres`, `clases`, `senderos`, `tours`.
Regiones: `valparaiso`, `metropolitana`, `nuble`, `biobio`, `araucania`, `losrios` (se definen en `REGIONES`).
