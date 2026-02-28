export  function getFirstSinger(lead) {
    if (!lead) return '';
    return lead.split(/[,+]/)[0].trim();
}
export  function getColorBySinger(singer) {
    // Dynamische Farbzuweisung basierend auf dem Sänger-Namen
    const palette = [
      '#CBF8CB', '#CAE2FF', '#F6D3EF', '#FFE0B2', '#D1C4E9',
      '#B2DFDB', '#FFCDD2', '#FFF9C4', '#B2EBF2', '#C5CAE9',
    ];
    if (!singer) return '#E6E8EB';
    // Simple hash des Namens für konsistente Farbzuweisung
    let hash = 0;
    for (let i = 0; i < singer.length; i++) {
      hash = singer.charCodeAt(i) + ((hash << 5) - hash);
    }
    return palette[Math.abs(hash) % palette.length];
}

export function formatGermanDateTime (dateTimeString) {
    if (!dateTimeString) return '';
    try {
      const date = new Date(dateTimeString);
      return date.toLocaleString('de-DE', {
        weekday: 'short',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (e) {
      console.error('Error formatting date:', e);
      return dateTimeString;
    }
  };

  export function shortFormatGermanDate (dateTimeString) {
    if (!dateTimeString) return '';
    try {
      const date = new Date(dateTimeString);
      return date.toLocaleString('de-DE', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      });
    } catch (e) {
      console.error('Error formatting date:', e);
      return dateTimeString;
    }
  };

  export function formatTime(timeString) {
      if (!timeString) return '';
      // Wenn es bereits im Format HH:MM ist
      if (timeString.includes(':')) {
        return timeString.slice(0, 5); // z.B. "20:30:00" → "20:30"
      }
      // Fallback
      return timeString;
  }