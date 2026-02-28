# Live Mode Feature

## Übersicht

Der Live Mode ermöglicht es, während eines Gigs in Echtzeit durch die Setliste zu navigieren und Feedback zu erfassen.

## Features

### Navigation
- **Desktop**: Pfeile links/rechts oder Pfeiltasten (←/→)
- **Mobile**: Swipe-Gesten (wische nach links/rechts)
- **Keyboard**: ↑/↓ für Navigation, ESC zum Schließen

### Song-Tracking
- **Übersprungen**: Markiere Songs, die nicht gespielt wurden
- **Eingeschoben**: Markiere Songs, die spontan eingefügt wurden
- **Feedback**: 5-Sterne-Bewertung pro Song

### UI-Elemente
- Progress Bar zeigt Fortschritt in der Setliste
- Aktuelle Set-Anzeige
- Song-Position und Tonart
- Kommentar-Anzeige falls vorhanden

## Verwendung

1. In der Gigs-Liste auf einen Gig klicken
2. Details aufklappen
3. Button "🎵 Live Mode" klicken
4. Durch Songs navigieren und Feedback erfassen

## Backend-Endpoints

### GET /gigs_lm/{gig_id}
Lädt Gig-Daten mit allen Songs und Live-Mode-Status

**Response:**
```json
{
  "id": 160,
  "name": "Schützenfest 2024",
  "datum": "2024-07-15",
  "sets": [
    {
      "id": 42,
      "position": 1,
      "setlist_name": "Set 1",
      "songs": [
        {
          "id": 123,
          "title": "Song Title",
          "interpret": "Artist",
          "position": 1,
          "tone_key": "C",
          "comment": null,
          "uebersprungen": false,
          "eingeschoben": false,
          "feedback": 5
        }
      ]
    }
  ]
}
```

### PUT /gigs_lm/{gig_id}/
Aktualisiert Live-Mode-Felder eines Songs

**Request Body:**
```json
{
  "id": 123,
  "uebersprungen": true
}
```

**Aktualisierbare Felder:**
- `uebersprungen` (bool)
- `eingeschoben` (bool)
- `feedback` (int, 1-5)

## Datenbank-Schema

### Neue Spalten in `set_songs`:
- `eingeschoben` (BOOLEAN, nullable)
- `uebersprungen` (BOOLEAN, nullable)
- `feedback` (INTEGER, nullable)

## Migration

```bash
python backend/migrations/add_live_mode_columns_to_db.py [/pfad/zur/db]
```

## Berechtigungen

Nur Benutzer mit `user_group = 'editor'` oder `'admin'` können den Live Mode nutzen.

