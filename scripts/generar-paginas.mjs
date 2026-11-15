#!/usr/bin/env node
// Genera HTML estático por tienda y por comuna.
// Por defecto lee datos/fichas-muestra.json y no usa la red.
// No escribe en Supabase. No publica. Reemplaza las carpetas tienda/ y comuna/ y el sitemap.xml.
//
//   node scripts/generar-paginas.mjs
//   node scripts/generar-paginas.mjs --entrada datos/fichas-muestra.json
//
// Un workflow de GitHub Actions que corra esto queda como decisión de Nicolás.
// No está en .github/workflows para que no se dispare en main.

import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SITIO = 'https://linvialabs.github.io/desviador';
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

const args = process.argv.slice(2);
const entradaFlag = args.indexOf('--entrada');
const entrada = resolve(raiz, entradaFlag >= 0 ? args[entradaFlag + 1] : 'datos/fichas-muestra.json');

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

const crudo = JSON.parse(readFileSync(entrada, 'utf8'));
const fichas = (crudo.fichas || []).filter((f) => f && f.nombre && f.comuna && !f.demo);
if (!fichas.length) {
  console.error('No hay fichas en', entrada);
  process.exit(1);
}

const usados = new Set();
for (const f of fichas) {
  let slug = `${slugify(f.nombre)}-${slugify(f.comuna)}`;
  if (usados.has(slug)) slug = `${slug}-${slugify(f.id || slug)}`;
  usados.add(slug);
  f.slug = slug;
  f.tipo = TIPOS[f.categoria] || 'Lugar';
  f.regionLabel = REGIONES[f.region] || f.region || '';
  f.comunaSlug = slugify(f.comuna);
}

rmSync(join(raiz, 'tienda'), { recursive: true, force: true });
rmSync(join(raiz, 'comuna'), { recursive: true, force: true });

const urls = [`${SITIO}/`];

for (const f of fichas) {
  const canonical = `${SITIO}/tienda/${f.slug}/`;
  const titulo = `${f.nombre} en ${f.comuna} | BIKEGRID`;
  const marcas = Array.isArray(f.marcas) && f.marcas.length ? ` Trabaja ${f.marcas.join(', ')}.` : '';
  const descripcion = `${f.tipo} en ${f.comuna}, ${f.regionLabel}. ${f.nombre} está en el mapa de BIKEGRID.${marcas}`.trim();
  const extras = [
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

console.log(`Listo: ${fichas.length} tiendas, ${porComuna.size} comunas, ${urls.length} URLs en sitemap.xml`);
