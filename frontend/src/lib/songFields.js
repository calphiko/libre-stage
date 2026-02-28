import { appConfig } from './appConfig';

// Alle Song-Felder, die table, Filter, Sortierung etc. nutzen sollen:
export const songFields = [
  { key: 'title',     label: 'Titel' },
  { key: 'interpret', label: 'Interpret' },
  { key: 'genre',     label: 'Genre' },
  { key: 'status',    label: 'Status' },
  { key: 'singer_lead',    label: 'Sänger' }
  // Füge weitere Felder nach Bedarf hinzu!
];

export const songApproachFields = [
  { key: 'title',     label: 'Titel' },
  { key: 'interpret', label: 'Interpret' },
  { key: 'my_feedback',     label: 'Mein Feedback' },
  { key: 'feedback_summary',    label: 'Gesamtfeedback' },
  // Füge weitere Felder nach Bedarf hinzu!
];

export const songFieldsDetails = [
    { key: 'title', label: 'Titel', required: true},
    { key: 'interpret', label: 'Interpret', required: true},
    {
        key: 'genre',
        label: 'Genre',
        type:'option',
        required: true,
        options: [
            { key: 'Pop', label: 'Pop' },
            { key: 'Rock', label: 'Rock' },
            { key: 'Schlager', label: 'Schlager' },
            { key: 'Oldies', label: 'Oldies' },
            { key: 'Party', label: 'Party' },
            { key: 'Karneval', label: 'Karneval' },
            { key: 'Elektro', label: 'Elektro' },
            { key: '80s', label: '80s' },
            { key: '90s', label: '90s' },
            { key: 'Disco', label: 'Disco' }
        ]
    },
    {
        key: 'singer_lead',
        label: 'Sänger',
        type: "singer_list"
    },
    {
        key: 'singer_background',
        label: 'Background Gesang',
        type: "singer_list"
    },
    { key: 'composer', label: 'Komponist'},
    { key: 'texter', label: 'Texter'},
    { key: 'publisher', label: 'Publisher'},
    { key: 'arrangement', label: 'Arrangement'},
    {
        key: 'tone_key',
        label: 'Tonart',
        type: 'option',
        options:  [
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
            { key: 'Bm', label: 'Bm' }
        ]
    },
    {
        key: 'status',
        label: 'Status',
        type: 'option',
        required: true,
        options: [
            { key: 'vorschlag', label: 'vorschlag' },
            { key: 'angenommen', label: 'angenommen' },
            { key: 'proben', label: 'proben' },
            { key: 'spielbar', label: 'spielbar' },
            { key: 'bedarfsweise_proben', label: 'bedarfsweise_proben' }
        ]
    },
    { key: 'comment', label: 'Setlistenkommentar'},
    { key: 'ytlink', label: 'Youtube'},
    { key: 'duration', label: 'Dauer', type: 'time' },
    {
        key: 'brass',
        label: 'Bläser',
        type: 'option',
        options:  [
            { key:0, label: 'Nein' },
            { key:1, label: 'Ja' },
        ]
    },
];

export const gigFields = [
    { key: 'datum', label: 'Datum'},
    { key: 'name', label: 'Name'},
    { key: 'kind_of_gig', label: 'Veranstaltungsart'},
];

export const gigFieldsDetails = [
    { key:'name', label: 'Name', type:'text', required: true },
    { key:'datum', label: 'Datum', type:'date', required: true },
    {
        key:'kind_of_gig',
        label: 'Veranstaltungsart',
        required: true,
        type:'option',
        options: [
            { key:'Schützenfest', label: 'Schützenfest'},
            { key:'Karnevalssitzung', label: 'Karnevalssitzung'},
            { key:'Stadtfest', label: 'Stadtest'},
            { key:'Privatveranstaltung', label: 'Privatveranstaltung'},
            { key:'andere Veranstaltung', label: 'andere Veranstaltung'},
        ]
    },
    { key:'organizer', label: 'Veranstalter', type:'text' },
    { key:'venue', label: 'Veranstaltungsort', type:'text' },
    { key:'doors', label: 'Einlass', type:'time' },
    { key:'begin', label: 'Spielbeginn', type:'time', required: true },
    { key:'end', label: 'Spielende', type:'time' },
    {
        key:'status',
        label: 'Anfragenstatus',
        type:'option',
        options: [
            { key: 'anfrage', label: "anfrage"},
            { key: 'angenommen', label: "angenommen"},
            { key: 'abgelehnt', label: "abgelehnt"},
        ]
    },
    {
        key:'publish',
        label: 'veröffentlichen',
        type: 'option',
        options: [
            { key: 0, label: 'Nein' },
            { key: 1, label: 'Ja' }
        ]
    },
];

export const kindOfGigOptions = appConfig.gigTypes;
