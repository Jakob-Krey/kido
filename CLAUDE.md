# Kido – Familien-Angebote-Finder

Website für Eltern: Alter des Kindes + Ort eingeben, passende Kurse, Spielgruppen,
Ferienprogramme und Events aus geprüften lokalen Quellen bekommen, mit kurzer
KI-Zusammenfassung. MVP: Mülheim an der Ruhr, Kinder 0–12 Jahre, **ohne Mailversand,
ohne Werbung, ohne Anmeldung**.

## Hauptquelle für Kontext

**Notion (Gründungsidee, immer zuerst lesen, wenn Produktfragen offen sind):**
https://app.notion.com/p/Gr-ndungsidee-Kido-40de8923052e8149b1f3e641678ed9d1

Per Notion-MCP (`notion-fetch`) abrufbar. Dort stehen Datenschema-Entwurf, Architektur,
KI-Einbindung, Quellen-Regeln, Roadmap, Monetarisierung. Notion ist die Wahrheit für
Produktentscheidungen; diese Datei fasst nur zusammen, was für den Code wichtig ist.

Weitere Links:
- To-dos (inkl. MVP): Todoist-Projekt „Familien-Angebote-Finder“ https://app.todoist.com/app/project/6hvr2P9g6vJjPXhw
- Supabase-Dashboard: https://supabase.com/dashboard/project/hbddgbxuazaqmblvlzts
- Roadmap: https://jakob-krey.github.io/Roadmap
- Vorschau (GitHub Pages): https://jakob-krey.github.io/kido/

## Stack & Architektur

- **Frontend:** Astro, statischer Build (`src/`, `public/`)
- **DB:** Supabase Postgres (Frankfurt), Schema in `supabase/migrations/`
- **Backend:** Supabase Edge Function (TypeScript): Alter + Ort → DB-Abfrage → KI-Zusammenfassung.
  Logik schlank und getrennt halten, damit ein späterer Umzug leicht ist. (noch nicht gebaut)
- **Crawler:** Python + Crawl4AI, nächtlich per GitHub Actions. Hash pro Seite, KI-Extraktion
  nur bei Änderung (günstiges Modell, Structured Output). (noch nicht gebaut)
- Kein Live-Crawling pro Anfrage.

## Feste Regeln

- Nur **manuell geprüfte Quellen** (robots.txt, Nutzungsbedingungen, seriöser Anbieter).
- **DSGVO:** keine Personennamen oder Telefonnummern von Ansprechpersonen im Schema.
- **Keine Secrets im Repo oder Frontend.** Nie den `service_role`-Key ins Frontend; im Browser nur
  `PUBLIC_*` (URL, anon-Key). Schreibzugriff nur über service_role (Crawler).
- Die KI nutzt **ausschließlich Datensätze aus der DB**; jedes Angebot mit Quelle, Link und
  „Angaben ohne Gewähr“.
- Abgelaufene Angebote werden ausgeblendet (`gueltig_bis`).
- Rate-Limit und Ausgabelimit an der Edge Function.
- Zeitfelder (Start/Ende mit Zeitzone Europe/Berlin) bleiben Pflicht, damit der spätere
  Kalender-Export ohne Schemaänderung geht.

## Arbeitsweise

- Sprache: Deutsch (UI, Doku, Commit-Texte nach Bedarf).
- Supabase-Zugriff per CLI; Migrationen in `supabase/migrations/`, RLS für alle Tabellen.
- Deploy: GitHub Pages (Vorschau, `.github/workflows/deploy-pages.yml`, Push auf `main`);
  später All-Inkl mit eigener Domain (`ASTRO_SITE`/`ASTRO_BASE` anpassen, FTP-Action).
- To-dos und Erinnerungen immer in Todoist anlegen, nicht hier ausformulieren.

## Befehle

```bash
npm install
npm run dev      # lokaler Server
npm run build    # statischer Build nach dist/
```

Env-Vorlage: `.env.example`. Ohne `PUBLIC_SUPABASE_URL` läuft die Seite im Demo-Modus.

## Offene Punkte (Details in Todoist)

- Edge Function `search-offers`
- Crawler und erste geprüfte Quellen
- Impressum und Datenschutzerklärung (Pflicht vor öffentlichem Start)
- Analytics (DSGVO-konform), AV-Verträge
- All-Inkl-Deployment mit eigener Domain
