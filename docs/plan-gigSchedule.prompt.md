# Plan: Ablaufplan (Schedule) für Gigs – Final

Ein neues Feature, das pro Gig einen chronologischen Ablaufplan erstellt. Feste Zeitpunkte aus dem Gig-Profil werden automatisch eingeblendet; zusätzliche Einträge in einer neuen `gig_schedule_items`-Tabelle. Datetimes als naive UTC. Kollisionen (auch gegen feste Einträge) werden im Frontend und Backend verhindert. Feste Einträge ohne Zeit (`None`) werden ignoriert.

## Schritte

1. **Neues DB-Model** in [models.py](../backend/models.py): Klasse `GigScheduleItem` mit `id`, `gig_id` (FK → `gigs`), `item_datetime` (DateTime, naive UTC), `was` (String 512), `wer` (String 512), `wo` (String 512); `UniqueConstraint("gig_id", "item_datetime")`; `relationship` `schedule_items` in `Gig` sortiert nach `item_datetime`.

2. **Alembic-Migration** via `task db:revision MSG="add_gig_schedule_items"`, prüfen, dann `task db:migrate`.

3. **Pydantic-Schemas** in [schemas.py](../backend/schemas.py): `GigScheduleItemIn`, `GigScheduleItemOut` (+ `is_fixed: bool`), `GigScheduleOut` (kombinierte, nach `item_datetime` sortierte Liste). Feste Einträge aus `gig.datum` + `doors`/`begin`/`end` (nur wenn nicht `None`) als naive UTC-datetimes mit `is_fixed=True`.

4. **API-Endpunkte** in [gigs.py](../backend/routers/gigs.py): `GET /{gig_id}/schedule/` (alle authentifizierten User), `POST`, `PUT`, `DELETE` (Editor/Admin). Bei `POST`/`PUT`:
   - Kollision mit anderen freien Einträgen per DB-Query prüfen (bei `PUT` eigenen Eintrag ausschließen)
   - Kollision mit festen Zeitpunkten (`doors`/`begin`/`end` + `datum`) prüfen
   - Beides → `HTTP 409 Conflict` mit sprechender Fehlermeldung; `UniqueConstraint` als letzter Schutz.

5. **Frontend-Komponente** `GigSchedule.svelte` unter [`frontend/src/routes/gigs/`](../frontend/src/routes/gigs/): Timeline-Darstellung, feste Einträge mit Badge „fix", nicht bearbeit-/löschbar. Formular (Datum vorbelegt mit `gig.datum`, Uhrzeit, Was, Wer, Wo). Vor jedem API-Call Kollisionsprüfung gegen alle geladenen Einträge (feste + freie) – bei Treffer Inline-Fehlermeldung, kein Request.

6. **Integration** in [+page.svelte](../frontend/src/routes/gigs/+page.svelte): `GigSchedule`-Komponente als Abschnitt „📋 Ablaufplan" im aufgeklappten Gig-Panel; Schedule-Daten beim Aufklappen laden.

7. **Demo-Daten** in [init_demo_db.py](../backend/migrations/init_demo_db.py): Pro Demo-Gig mehrere `GigScheduleItem`-Einträge über verschiedene Tage (z. B. Aufbau am Vortag, Soundcheck, Essenszeit, Abbau nach dem Gig) als naive UTC-datetimes, alle ohne Kollision mit den jeweiligen festen Gig-Zeiten.

## Randbedingungen & Entscheidungen

- **Datetimes:** Naive UTC, konsistent mit bestehenden Feldern im Projekt. Keine Timezone-Konvertierung nötig, spätere Migration möglich.
- **Eindeutigkeit:** `UniqueConstraint("gig_id", "item_datetime")` auf DB-Ebene; zusätzlich explizite Prüfung im Backend vor dem Insert/Update (bei `PUT` eigenen Eintrag ausschließen).
- **Feste Einträge ohne Zeit:** Falls `doors`/`begin`/`end` am Gig `None` sind, werden sie weder angezeigt noch in der Kollisionsprüfung berücksichtigt.
- **Kollision feste ↔ freie Einträge:** Backend und Frontend verhindern, dass ein freier Eintrag denselben Zeitpunkt wie ein fester Eintrag (Einlass, Spielbeginn, Spielende) bekommt.
- **Mehrtägige Pläne:** `item_datetime` enthält Datum + Zeit; Datum ist frei wählbar (z. B. Aufbau am Vortag).
- **Berechtigungen:** Lesen → alle authentifizierten User; Schreiben (POST/PUT/DELETE) → Editor/Admin.
- **409-Fehler im Frontend:** Auch wenn das Frontend Kollisionen vorab abfängt, wird ein API-`409`-Fehler als Toast/Snackbar angezeigt (Fallback bei veraltetem lokalem State).
- **Reihenfolge bei gleicher Zeit:** Durch das Kollisionsverbot nicht möglich; feste Einträge werden trotzdem vor freien sortiert, falls der Constraint umgangen würde.

