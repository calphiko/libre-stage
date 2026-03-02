// src/lib/songFields.js
// Feld-Definitionen für Songs und Gigs.
// Options-Arrays werden dynamisch aus der App-Konfiguration erzeugt.

// Statische Felder ohne Options – unverändert nutzbar
export const songFields = [
  { key: 'title',     label: 'Titel' },
  { key: 'interpret', label: 'Interpret' },
  { key: 'genre',     label: 'Genre' },
  { key: 'status',    label: 'Status' },
  { key: 'singer_lead',    label: 'Sänger' }
];

export const songApproachFields = [
  { key: 'title',     label: 'Titel' },
  { key: 'interpret', label: 'Interpret' },
  { key: 'my_feedback',     label: 'Mein Feedback' },
  { key: 'feedback_summary',    label: 'Gesamtfeedback' },
];

export const gigFields = [
    { key: 'datum', label: 'Datum'},
    { key: 'name', label: 'Name'},
    { key: 'kind_of_gig', label: 'Veranstaltungsart'},
];

/**
 * Erzeugt die detaillierten Song-Feld-Definitionen mit Options aus der Config.
 * @param {object} config - Die geladene App-Konfiguration
 * @returns {Array} songFieldsDetails
 */
export function getSongFieldsDetails(config) {
  return [
    { key: 'title', label: 'Titel', required: true },
    { key: 'interpret', label: 'Interpret', required: true },
    {
      key: 'genre',
      label: 'Genre',
      type: 'option',
      required: true,
      options: config?.genres ?? []
    },
    {
      key: 'singer_lead',
      label: 'Sänger',
      type: 'singer_list'
    },
    {
      key: 'singer_background',
      label: 'Background Gesang',
      type: 'singer_list'
    },
    { key: 'composer', label: 'Komponist' },
    { key: 'texter', label: 'Texter' },
    { key: 'publisher', label: 'Publisher' },
    { key: 'arrangement', label: 'Arrangement' },
    {
      key: 'tone_key',
      label: 'Tonart',
      type: 'option',
      options: config?.tonekeys ?? []
    },
    {
      key: 'status',
      label: 'Status',
      type: 'option',
      required: true,
      options: config?.songStatuses ?? []
    },
    { key: 'comment', label: 'Setlistenkommentar' },
    { key: 'ytlink', label: 'Youtube' },
    { key: 'duration', label: 'Dauer', type: 'time' },
    {
      key: 'brass',
      label: 'Bläser',
      type: 'option',
      options: [
        { key: 0, label: 'Nein' },
        { key: 1, label: 'Ja' },
      ]
    },
  ];
}

/**
 * Erzeugt die detaillierten Gig-Feld-Definitionen mit Options aus der Config.
 * @param {object} config - Die geladene App-Konfiguration
 * @returns {Array} gigFieldsDetails
 */
export function getGigFieldsDetails(config) {
  return [
    { key: 'name', label: 'Name', type: 'text', required: true },
    { key: 'datum', label: 'Datum', type: 'date', required: true },
    {
      key: 'kind_of_gig',
      label: 'Veranstaltungsart',
      required: true,
      type: 'option',
      options: config?.gigTypes ?? []
    },
    { key: 'organizer', label: 'Veranstalter', type: 'text' },
    { key: 'venue', label: 'Veranstaltungsort', type: 'text' },
    { key: 'doors', label: 'Einlass', type: 'time' },
    { key: 'begin', label: 'Spielbeginn', type: 'time', required: true },
    { key: 'end', label: 'Spielende', type: 'time' },
    {
      key: 'status',
      label: 'Anfragenstatus',
      type: 'option',
      options: config?.gigStatuses ?? []
    },
    {
      key: 'publish',
      label: 'veröffentlichen',
      type: 'option',
      options: [
        { key: 0, label: 'Nein' },
        { key: 1, label: 'Ja' }
      ]
    },
  ];
}

/**
 * Gibt die Veranstaltungsart-Options aus der Config zurück.
 * @param {object} config - Die geladene App-Konfiguration
 * @returns {Array} kindOfGigOptions
 */
export function getKindOfGigOptions(config) {
  return config?.gigTypes ?? [];
}
