# Frontend UI-Inventar und Standardisierung

Stand: 2026-06-04

## Erfasste UI-Elemente (Ist-Zustand)

- Navigation: Header, Sidebar, Footer (`frontend/src/routes/+layout.svelte`)
- Seitengerueste: Container, Karten, Abschnittsbloecke (`card`, `variant-*`)
- Formularelemente: `input`, `select`, `textarea`, Labels, Hilfetexte
- Aktionen: Buttons in vielen Varianten (`btn`, `btn-primary`, `btn-outline-*`, `variant-*`)
- Statusdarstellung: Badges/Chips, Alerts, Toasts
- Datenanzeige: Tabellen und mobile Karten-Listen
- Interaktion: Tabs (z. B. Dashboard), Modals, Toggle-Elemente
- Spezialkomponenten: AG Grid, Plot-Komponenten, Kalender-URL-Block

## Auffaelligkeiten

- Mischbetrieb aus mehreren Stilansaetzen (Tailwind Utility, Skeleton Variants, lokale CSS-Styles)
- Inkonsistente Radius-/Padding-/Shadow-Werte bei Karten und Formularen
- Unterschiedliche Button-Hierarchien und Zustandsdarstellungen
- Teilweise lokale Ueberschreibungen, die globale Konsistenz unterlaufen

## Standardisierte UI-Elemente (Soll-Zustand)

Die folgenden Basisklassen wurden als Design-Grundlage eingefuehrt:

- Layout: `ui-page`, `ui-divider`, `ui-subtle`
- Surface: `ui-card`, `ui-card-muted`
- Form: `ui-input`, `ui-select`, `ui-textarea`
- Aktionen: `ui-btn`, `ui-btn-primary`, `ui-btn-secondary`, `ui-btn-ghost`
- Status: `ui-badge`
- Navigation/Struktur: `ui-tabs`, `ui-tab`, `ui-tab-active`
- Daten: `ui-table`

## Kompatibilitaet

Bestehende Klassen werden auf den neuen Stil gemappt, damit bestehende Seiten sofort profitieren:

- `card` -> moderne Card-Darstellung
- `btn`, `btn-primary`, `btn-outline-*` -> einheitliche Buttons
- `input`, `select`, `textarea.input` -> einheitliche Formularfelder
- `badge` -> einheitliche Badge-Darstellung

## Bereits umgesetzt in dieser Iteration

- Globale UI-Primitiven und Kompatibilitaets-Mapping in `frontend/src/app.css`
- Seitenmigration auf die neuen Primitiven:
  - `frontend/src/routes/+page.svelte` (Login)
  - `frontend/src/routes/+layout.svelte` (Header/Sidebar/Footer)
  - `frontend/src/routes/dashboard/+page.svelte` (Tabs, Tabellen, Karten, Badges)
  - `frontend/src/routes/benutzer/+page.svelte` (Profilformular und Kartenkonsistenz)
  - `frontend/src/routes/admin/config/+page.svelte` (Form- und Aktionskonsistenz)

