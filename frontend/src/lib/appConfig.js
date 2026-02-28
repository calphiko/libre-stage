// src/lib/appConfig.js
// Zentrale Konfiguration für anpassbare Werte.
// Diese Datei kann bei Deployment/Fork angepasst werden,
// ohne den restlichen Code zu ändern.

export const appConfig = {
  // Genres für Songs
  genres: [
    { key: 'Pop', label: 'Pop' },
    { key: 'Rock', label: 'Rock' },
    { key: 'Schlager', label: 'Schlager' },
    { key: 'Oldies', label: 'Oldies' },
    { key: 'Party', label: 'Party' },
    { key: 'Karneval', label: 'Karneval' },
    { key: 'Elektro', label: 'Elektro' },
    { key: '80s', label: '80s' },
    { key: '90s', label: '90s' },
    { key: 'Disco', label: 'Disco' },
  ],

  // Veranstaltungsarten
  gigTypes: [
    { key: 'Schützenfest', label: 'Schützenfest' },
    { key: 'Karnevalssitzung', label: 'Karnevalssitzung' },
    { key: 'Stadtfest', label: 'Stadtfest' },
    { key: 'Privatveranstaltung', label: 'Privatveranstaltung' },
    { key: 'andere Veranstaltung', label: 'andere Veranstaltung' },
  ],

  // Song-Statuses
  songStatuses: [
    { key: 'vorschlag', label: 'vorschlag' },
    { key: 'angenommen', label: 'angenommen' },
    { key: 'proben', label: 'proben' },
    { key: 'spielbar', label: 'spielbar' },
    { key: 'bedarfsweise_proben', label: 'bedarfsweise_proben' },
  ],

  // Gig-Anfrage-Statuses
  gigStatuses: [
    { key: 'anfrage', label: 'anfrage' },
    { key: 'angenommen', label: 'angenommen' },
    { key: 'abgelehnt', label: 'abgelehnt' },
  ],

  // Tonarten (musikalische Tonarten – universell, keine Anpassung nötig)
  toneKeys: [
    { key: null, label: '' },
    { key: 'C', label: 'C' },
    { key: 'C#', label: 'C#' },
    { key: 'Db', label: 'Db' },
    { key: 'D', label: 'D' },
    { key: 'D#', label: 'D#' },
    { key: 'Eb', label: 'Eb' },
    { key: 'E', label: 'E' },
    { key: 'F', label: 'F' },
    { key: 'F#', label: 'F#' },
    { key: 'Gb', label: 'Gb' },
    { key: 'G', label: 'G' },
    { key: 'G#', label: 'G#' },
    { key: 'Ab', label: 'Ab' },
    { key: 'A', label: 'A' },
    { key: 'A#', label: 'A#' },
    { key: 'Bb', label: 'Bb' },
    { key: 'H', label: 'H' },
    { key: 'B', label: 'B' },
    { key: 'Cm', label: 'Cm' },
    { key: 'C#m', label: 'C#m' },
    { key: 'Dbm', label: 'Dbm' },
    { key: 'Dm', label: 'Dm' },
    { key: 'D#m', label: 'D#m' },
    { key: 'Ebm', label: 'Ebm' },
    { key: 'Em', label: 'Em' },
    { key: 'Fm', label: 'Fm' },
    { key: 'F#m', label: 'F#m' },
    { key: 'Gbm', label: 'Gbm' },
    { key: 'Gm', label: 'Gm' },
    { key: 'G#m', label: 'G#m' },
    { key: 'Abm', label: 'Abm' },
    { key: 'Am', label: 'Am' },
    { key: 'A#m', label: 'A#m' },
    { key: 'Bbm', label: 'Bbm' },
    { key: 'Hm', label: 'Hm' },
    { key: 'Bm', label: 'Bm' },
  ],

  // Proben-Song-Statuses (inkl. retired)
  rehearsalSongStatuses: ['vorschlag', 'angenommen', 'proben', 'spielbar', 'retired'],
};

