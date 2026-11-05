import { defineConfig } from 'astro/config';

// Statischer Build. Vorschau auf GitHub Pages unter /kido.
// Fuer All-Inkl mit eigener Domain: site anpassen und base entfernen
// (oder per Env: ASTRO_SITE / ASTRO_BASE setzen).
export default defineConfig({
  output: 'static',
  site: process.env.ASTRO_SITE ?? 'https://jakob-krey.github.io',
  base: process.env.ASTRO_BASE ?? '/kido',
});
