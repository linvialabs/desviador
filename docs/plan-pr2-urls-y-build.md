# Plan del segundo PR: URL propia y salida del CDN

La parte de URLs propias está en el draft con base `producto-v1`. El generador, por defecto, lee Supabase en solo lectura (`comercios.estado = aprobado`) y tiene salvaguarda contra una caída brusca. `--muestra` sigue sirviendo para probar sin red. El workflow manual está en `.github/workflows/generar-paginas.yml` (`workflow_dispatch` solamente). No despliega Pages ni toca `main`. Salir del CDN de Tailwind sigue para un tercer PR.

Publicar el HTML generado a GitHub Pages sigue siendo un OK aparte de Nicolás.

El orden es el que pidió Nicolás: primero una URL propia por tienda y por comuna, después salir del CDN de Tailwind.

El sitio hoy es un solo `index.html` en GitHub Pages, en `https://linvialabs.github.io/desviador/`. El archivo `.nojekyll` ya existe, así que Pages no pasa el HTML por Jekyll.

## 1. URL propia por tienda y por comuna

### Para qué

Google hoy ve una sola dirección. Una ficha y una comuna no tienen página propia, así que no compiten por búsquedas como «taller de bicicletas en Ñuñoa».

### Paso de build

Hace falta un paso que genere HTML estático, porque GitHub Pages no ejecuta el sitio en un servidor.

1. Un script (Node, sin framework) lee de Supabase solo filas `estado = aprobado` y solo columnas públicas: nombre, categoría, comuna, región, coordenadas y, si están, horario y marcas.
2. Escribe una carpeta por ficha y otra por comuna:
   - `tienda/<slug>/index.html`
   - `comuna/<slug>/index.html`
3. Cada archivo trae `<title>`, meta description y un enlace al mapa (`/?ficha=<id>` o el ancla que ya abre el drawer). El slug sale del nombre y la comuna, sin tildes y en minúsculas.
4. Un workflow de GitHub Actions corre el script cuando se pide, no en cada visita. El resultado se commitea o se publica como artefacto de Pages.

La base del sitio es `/desviador/`. Las rutas nuevas tienen que incluir ese prefijo en los enlaces, o Pages las busca en la raíz del usuario y responden 404.

### Alternativa sin build

Se puede hacer sin generar archivos, con el truco de `404.html` de GitHub Pages: copiar `index.html` a `404.html` para que `/desviador/tienda/algo` cargue la misma página. El JavaScript lee la ruta y abre la ficha.

Eso no le da a Google un HTML distinto por tienda. El título y el texto llegan después, por JavaScript y por Supabase. Sirve para compartir un link. No sirve como página propia para el buscador. Por eso el camino recomendado es el HTML estático. La alternativa sin build queda como puente si Nicolás quiere los links antes del generador.

### Archivos nuevos

- `scripts/generar-paginas.mjs`: el generador.
- `tienda/` y `comuna/`: el HTML generado. No se edita a mano.
- `.github/workflows/paginas-estaticas.yml`: corre el generador y publica, solo cuando Nicolás lo active.
- Nada de esto entra en `producto-v1`.

No hace falta un framework ni un bundler. El script usa el cliente de Supabase que ya está en el sitio, o `fetch` a la API REST con la anon key.

### Riesgos

- **GitHub Pages.** El sitio es un project site: la raíz es `/desviador/`, no el dominio. Un archivo en `tienda/foo/index.html` se publica en `https://linvialabs.github.io/desviador/tienda/foo/`. Si el generador escribe enlaces como `/tienda/foo`, Pages los pierde. Hay que probar una ficha y una comuna en el entorno de preview antes de tocar `main`.
- **SEO.** Publicar fichas pendientes, duplicar la portada sin `canonical`, o dejar páginas de una ficha retirada produce contenido fino o duplicado. Cada página lleva `link rel="canonical"` a su propia URL. Si una ficha deja de estar aprobada, el siguiente generador borra su carpeta. No se inventan textos: el título es el nombre y la comuna que ya están en la base.
- **Datos de Supabase.** El generador usa la anon key y las columnas que el público ya puede leer. No usa la `service_role` ni escribe en la base. Si la consulta falla, el script se detiene y no publica un árbol a medias. Las páginas quedan viejas hasta la próxima corrida: una ficha recién aprobada no aparece sola.
- **Mantenimiento.** Alguien tiene que volver a correr el generador cuando se aprueba, se edita o se retira una ficha. Si el slug cambia, el URL anterior queda roto salvo que el generador deje una redirección (una página mínima que apunte a la nueva). Conviene una tabla o un archivo de slugs anteriores.

### Cómo revertir

Borrar `tienda/`, `comuna/`, el script y el workflow, y volver a publicar `main`. La portada en `index.html` no depende de esas carpetas. Los links viejos pasan a 404, que es el mismo resultado que hoy si alguien inventa una ruta. No hay migración de base que deshacer.

## 2. Salir del CDN de Tailwind

Esto va después de las URLs. El CDN (`https://cdn.tailwindcss.com`) compila las clases en el navegador y avisa que no es para producción. En la medición del 15-11-2026 pesaba unos 127 KB, aparte del HTML.

### Paso de build

1. Instalar la CLI de Tailwind en una máquina de desarrollo o en Actions. No queda como dependencia de ejecución del sitio.
2. Un `tailwind.config.js` con la paleta que hoy está en el `<script>` de `index.html` (soil, sand, moss, ochre, brand, Barlow).
3. Un `estilos.css` de entrada que importa Tailwind y las reglas propias que hoy viven en el `<style>` de `index.html` (mapa, fichas, iconos).
4. `npx tailwindcss -i estilos.src.css -o estilos.css --minify`, mirando `index.html`.
5. En `index.html`, sacar el `<script src="https://cdn.tailwindcss.com">` y el `tailwind.config` en línea, y poner `<link rel="stylesheet" href="estilos.css">`.

El sitio en Pages sigue siendo archivos estáticos. El build ocurre antes de subir, no en el navegador.

### Alternativa sin build

Compilar el CSS una vez en el computador de Nicolás y commitear `estilos.css`. El repositorio no gana un paso de CI. Cada cambio de clases pide volver a correr la CLI y subir el CSS. Si no se hace, la página queda sin el estilo nuevo.

Seguir en el CDN es la otra alternativa, y es lo que hay hoy. No mejora el peso ni el aviso de producción.

No conviene pegar el CSS a mano: el archivo de utilidades es enorme y se desactualiza solo.

### Archivos nuevos

- `estilos.src.css`: entrada de Tailwind y el CSS propio.
- `estilos.css`: el resultado, el que carga la página.
- `tailwind.config.js`: paleta y rutas a escanear (`index.html`).
- El `package.json` solo si se elige el workflow. Si se commitea el CSS ya compilado, no hace falta en el repo.

### Riesgos

- **GitHub Pages.** `estilos.css` tiene que viajar junto al HTML. Un link absoluto al CDN que se olvida deja la página sin estilos. Probar en local con el servidor estático, sin red de Tailwind, antes de publicar.
- **Clases armadas en JavaScript.** Tailwind solo incluye las clases que ve escritas enteras. En `index.html` hay muchas clases dentro de plantillas. Si alguna se arma por pedazos (`bg-${color}`), esa regla no entra al CSS y el elemento queda sin fondo. Hay que revisar el diff visual en 375 px y en 1440 px, y listar en `safelist` las que se construyan.
- **SEO.** El CSS no cambia las URLs. El riesgo es de pintura: si el CSS falta, Google igual lee el texto, pero la revisión humana del celular falla. No meter el CSS inline entero en `index.html`: el archivo ya pesa más de 450 KB.
- **Datos de Supabase.** Este cambio no los toca.
- **Mantenimiento.** Dos fuentes de verdad si el `<style>` de `index.html` y `estilos.src.css` divergen. El PR debe mover las reglas propias a un solo archivo y borrar el duplicado. Quien edite clases en el HTML tiene que recordar regenerar `estilos.css` si no hay CI.

### Cómo revertir

Volver a poner el `<script>` del CDN y el `tailwind.config` en línea, y quitar el `<link>` a `estilos.css`. Se pueden borrar `estilos.css`, `estilos.src.css` y `tailwind.config.js`. No hay datos que migrar. El commit anterior del HTML restaura la portada tal como está en `producto-v1`.
