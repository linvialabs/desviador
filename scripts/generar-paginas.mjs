#!/usr/bin/env node
// Genera HTML estático por tienda y por comuna.
//
// Por defecto lee Supabase en solo lectura (REST, SELECT). El filtro es el mismo
// que el mapa: tabla comercios, columna estado, valor "aprobado".
// No hay INSERT, UPDATE ni DELETE. No se ejecuta SQL.
//
//   node scripts/generar-paginas.mjs
//   node scripts/generar-paginas.mjs --muestra
//   node scripts/generar-paginas.mjs --forzar
//
// --muestra usa datos/fichas-muestra.json y no abre la red.
// --forzar salta la salvaguarda (0 fichas o caída bajo el 80% del último manifiesto).
// Un fallo de red o de HTTP nunca reescribe tienda/, comuna/ ni sitemap.xml.

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SITIO = 'https://linvialabs.github.io/desviador';
const MANIFIESTO = join(raiz, 'datos', 'ultimo-manifiesto.json');
const MUESTRA = join(raiz, 'datos', 'fichas-muestra.json');
const UMBRAL = 0.8;
const REGIONES = {
  arica: 'Arica y Parinacota',
  tarapaca: 'Tarapacá',
  antofagasta: 'Antofagasta',
  atacama: 'Atacama',
  coquimbo: 'Coquimbo',
  valparaiso: 'Valparaíso',
  metropolitana: 'Santiago (RM)',
  ohiggins: "O'Higgins",
  maule: 'Maule',
  nuble: 'Chillán (Ñuble)',
  biobio: 'Biobío',
  araucania: 'Araucanía',
  losrios: 'Los Ríos',
  loslagos: 'Los Lagos',
  aysen: 'Aysén',
  magallanes: 'Magallanes',
};
const TIPOS = {
  tiendas: 'Tienda',
  talleres: 'Taller',
  senderos: 'Cerro',
  clases: 'Escuela',
  tours: 'Shuttle',
  guias: 'Guía',
};
// Mismas columnas públicas que el mapa puede leer (grant del schema). No pide marcas ni datos privados.
const COLUMNAS = 'id,nombre_comercio,categoria,region,comuna,direccion,latitud,longitud,whatsapp,horario,descripcion,destacado,estado';

const args = process.argv.slice(2);
const muestra = args.includes('--muestra');
const forzar = args.includes('--forzar');

function slugify(value) {
  return String(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function fallar(mensaje) {
  console.error(mensaje);
  console.error('No se tocaron tienda/, comuna/ ni sitemap.xml.');
  process.exit(1);
}

function credenciales() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (url && key) return { url: url.replace(/\/$/, ''), key };
  if (process.env.GITHUB_ACTIONS === 'true') {
    throw new Error('En Actions hacen falta SUPABASE_URL y SUPABASE_ANON_KEY (secrets o variables del repo).');
  }
  const src = readFileSync(join(raiz, 'supabase-config.js'), 'utf8');
  const delArchivo = {
    url: src.match(/SUPABASE_URL:\s*'([^']+)'/)?.[1],
    key: src.match(/SUPABASE_ANON_KEY:\s*'([^']+)'/)?.[1],
  };
  if (!delArchivo.url || !delArchivo.key || delArchivo.url.startsWith('TU_')) {
    throw new Error('No encontré SUPABASE_URL ni SUPABASE_ANON_KEY.');
  }
  return { url: delArchivo.url.replace(/\/$/, ''), key: delArchivo.key };
}

async function leerSupabase() {
  const { url, key } = credenciales();
  const fichas = [];
  const tamano = 1000;
  for (let desde = 0; desde < 20000; desde += tamano) {
    const endpoint = `${url}/rest/v1/comercios?select=${COLUMNAS}&estado=eq.aprobado&order=nombre_comercio.asc`;
    let res;
    try {
      res = await fetch(endpoint, {
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          Accept: 'application/json',
          Range: `${desde}-${desde + tamano - 1}`,
        },
      });
    } catch (error) {
      throw new Error(`No pude consultar Supabase: ${error.message}`);
    }
    if (!res.ok) {
      const texto = await res.text();
      throw new Error(`Supabase respondió ${res.status}: ${texto.slice(0, 180)}`);
    }
    const filas = await res.json();
    if (!Array.isArray(filas)) throw new Error('La respuesta de Supabase no es una lista.');
    for (const fila of filas) {
      if (fila.estado && fila.estado !== 'aprobado') continue;
      fichas.push({
        id: fila.id,
        nombre: fila.nombre_comercio,
        categoria: fila.categoria,
        region: fila.region,
        comuna: fila.comuna || '',
        direccion: fila.direccion || '',
        horario: fila.horario || '',
        descripcion: fila.descripcion || '',
        destacado: !!fila.destacado,
      });
    }
    if (filas.length < tamano) break;
  }
  return fichas.filter((f) => f.nombre && f.comuna);
}

function leerMuestra() {
  const crudo = JSON.parse(readFileSync(MUESTRA, 'utf8'));
  return (crudo.fichas || []).filter((f) => {
    if (!f || !f.nombre || !f.comuna || f.demo) return false;
    if (f.estado && f.estado !== 'aprobado') return false;
    return true;
  });
}

function leerManifiesto() {
  if (!existsSync(MANIFIESTO)) return null;
  try {
    return JSON.parse(readFileSync(MANIFIESTO, 'utf8'));
  } catch {
    return null;
  }
}

function salvaguarda(cantidad, anterior) {
  if (forzar) {
    console.warn('--forzar: se salta la salvaguarda.');
    return;
  }
  if (!cantidad) {
    fallar('La consulta devolvió 0 fichas aprobadas. No reescribo las páginas.');
  }
  const previas = Number(anterior?.cantidad) || 0;
  if (previas > 0 && cantidad < previas * UMBRAL) {
    fallar(`Llegaron ${cantidad} fichas y el último manifiesto tiene ${previas} (bajo el 80%). No reescribo las páginas. Usa --forzar si de verdad quieres seguir.`);
  }
}

function preparar(fichas) {
  const usados = new Set();
  for (const f of fichas) {
    let slug = `${slugify(f.nombre)}-${slugify(f.comuna)}`;
    if (!slug) slug = slugify(f.id || 'ficha');
    if (usados.has(slug)) slug = `${slug}-${slugify(f.id || usados.size)}`;
    usados.add(slug);
    f.slug = slug;
    f.tipo = TIPOS[f.categoria] || 'Lugar';
    f.regionLabel = REGIONES[f.region] || f.region || '';
    f.comunaSlug = slugify(f.comuna);
  }
  return fichas;
}

function pagina({ titulo, descripcion, canonical, cuerpo }) {
  return `<!DOCTYPE html>
<html lang="es-CL">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${esc(titulo)}</title>
  <meta name="description" content="${esc(descripcion)}" />
  <link rel="canonical" href="${esc(canonical)}" />
  <meta property="og:title" content="${esc(titulo)}" />
  <meta property="og:description" content="${esc(descripcion)}" />
  <meta property="og:url" content="${esc(canonical)}" />
  <meta property="og:type" content="website" />
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content="${esc(titulo)}" />
  <meta name="twitter:description" content="${esc(descripcion)}" />
  <style>
    :root { color-scheme: light; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, sans-serif; background: #f6f1e7; color: #241f19; }
    a { color: #276b2b; }
    header, main, footer { padding: 1rem 1.1rem; }
    header { background: #15120e; color: #f6f1e7; }
    header a { color: #f6f1e7; text-decoration: none; font-weight: 700; letter-spacing: .04em; }
    h1 { font-size: 1.7rem; line-height: 1.1; margin: .4rem 0 .35rem; }
    .tipo { margin: 0; color: #54473a; }
    ul { padding-left: 1.1rem; }
    li { margin: .45rem 0; }
    .mapa { display: inline-block; margin-top: 1rem; background: #2e7d32; color: #f6f1e7; text-decoration: none; font-weight: 700; padding: .7rem 1rem; border-radius: .7rem; }
    footer { color: #54473a; font-size: .85rem; }
  </style>
</head>
<body>
  <header><a href="../../index.html">BIKEGRID</a></header>
  <main>
    ${cuerpo}
  </main>
  <footer>
    <p>BIKEGRID opera este mapa de tiendas, talleres y cerros en Chile.</p>
    <p>¿Hay un error o quieres retirar esta ficha? <a href="../../index.html#registrar">Pide la corrección o el retiro</a>.</p>
  </footer>
</body>
</html>
`;
}

function escribir(dir, html) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'index.html'), html);
}

function publicar(fichas, origen) {
  rmSync(join(raiz, 'tienda'), { recursive: true, force: true });
  rmSync(join(raiz, 'comuna'), { recursive: true, force: true });

  const urls = [`${SITIO}/`];
  for (const f of fichas) {
    const canonical = `${SITIO}/tienda/${f.slug}/`;
    const titulo = `${f.nombre} en ${f.comuna} | BIKEGRID`;
    const marcas = Array.isArray(f.marcas) && f.marcas.length ? ` Trabaja ${f.marcas.join(', ')}.` : '';
    const descripcion = `${f.tipo} en ${f.comuna}, ${f.regionLabel}. ${f.nombre} está en el mapa de BIKEGRID.${marcas}`.trim();
    const extras = [
      f.descripcion ? `<p>${esc(f.descripcion)}</p>` : '',
      f.horario ? `<p>Horario: ${esc(f.horario)}</p>` : '',
      f.direccion ? `<p>${esc(f.direccion)}</p>` : '',
    ].join('');
    const cuerpo = `
    <p class="tipo">${esc(f.tipo)} · ${esc(f.comuna)} · ${esc(f.regionLabel)}</p>
    <h1>${esc(f.nombre)}</h1>
    <p>${esc(descripcion)}</p>
    ${extras}
    <p><a href="../../comuna/${esc(f.comunaSlug)}/">Más lugares en ${esc(f.comuna)}</a></p>
    <a class="mapa" href="../../index.html">Ver en el mapa</a>`;
    escribir(join(raiz, 'tienda', f.slug), pagina({ titulo, descripcion, canonical, cuerpo }));
    urls.push(canonical);
  }

  const porComuna = new Map();
  for (const f of fichas) {
    if (!porComuna.has(f.comunaSlug)) porComuna.set(f.comunaSlug, []);
    porComuna.get(f.comunaSlug).push(f);
  }
  for (const [comunaSlug, lista] of porComuna) {
    const comuna = lista[0].comuna;
    const regionLabel = lista[0].regionLabel;
    const canonical = `${SITIO}/comuna/${comunaSlug}/`;
    const titulo = `Tiendas, talleres y cerros en ${comuna} | BIKEGRID`;
    const nombres = lista.map((f) => f.nombre).join(', ');
    const verbo = lista.length === 1 ? 'Míralo' : 'Míralos';
    const descripcion = `En ${comuna}, ${regionLabel}: ${nombres}. ${verbo} en el mapa de BIKEGRID.`;
    const items = lista.map((f) => `<li><a href="../../tienda/${esc(f.slug)}/">${esc(f.nombre)}</a> · ${esc(f.tipo)}</li>`).join('');
    const cuerpo = `
    <p class="tipo">${esc(regionLabel)}</p>
    <h1>En ${esc(comuna)}</h1>
    <p>${esc(descripcion)}</p>
    <ul>${items}</ul>
    <a class="mapa" href="../../index.html">Ver el mapa de Chile</a>`;
    escribir(join(raiz, 'comuna', comunaSlug), pagina({ titulo, descripcion, canonical, cuerpo }));
    urls.push(canonical);
  }

  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((loc) => `  <url><loc>${loc}</loc></url>`).join('\n')}
</urlset>
`;
  writeFileSync(join(raiz, 'sitemap.xml'), sitemap);
  const slugs = fichas.map((f) => f.slug).sort();
  writeFileSync(MANIFIESTO, `${JSON.stringify({
    generadoEn: new Date().toISOString(),
    origen,
    filtro: 'comercios.estado = aprobado',
    cantidad: fichas.length,
    slugs,
  }, null, 2)}\n`);
  console.log(`Listo (${origen}): ${fichas.length} tiendas, ${porComuna.size} comunas, ${urls.length} URLs en sitemap.xml`);
}

const anterior = leerManifiesto();
let fichas;
let origen;
try {
  if (muestra) {
    origen = 'muestra';
    fichas = leerMuestra();
  } else {
    origen = 'supabase';
    fichas = await leerSupabase();
  }
} catch (error) {
  fallar(error.message);
}

preparar(fichas);
salvaguarda(fichas.length, anterior);
publicar(fichas, origen);
