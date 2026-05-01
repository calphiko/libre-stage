/**
 * Normalisiert Strings fuer robusten Textvergleich.
 * - Lowercase
 * - Akzente entfernen
 * - Sonderzeichen zu Leerzeichen
 * - Mehrfach-Leerzeichen reduzieren
 */
export function normalizeSongText(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function sortTokens(value) {
  return normalizeSongText(value)
    .split(' ')
    .filter(Boolean)
    .sort()
    .join(' ');
}

function levenshteinDistance(a, b) {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;

  const prev = new Array(b.length + 1);
  const curr = new Array(b.length + 1);

  for (let j = 0; j <= b.length; j += 1) prev[j] = j;

  for (let i = 1; i <= a.length; i += 1) {
    curr[0] = i;
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      curr[j] = Math.min(
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost
      );
    }
    for (let j = 0; j <= b.length; j += 1) prev[j] = curr[j];
  }

  return prev[b.length];
}

function similarity(a, b) {
  if (!a || !b) return 0;
  if (a === b) return 1;
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  return 1 - levenshteinDistance(a, b) / maxLen;
}

function bestFieldScore(left, right) {
  const direct = similarity(normalizeSongText(left), normalizeSongText(right));
  const tokenSorted = similarity(sortTokens(left), sortTokens(right));
  return Math.max(direct, tokenSorted);
}

/**
 * Findet den besten Dubletten-Treffer fuer die Kombination aus Titel+Interpret.
 * Liefert null, wenn keine ausreichend gute Uebereinstimmung gefunden wurde.
 */
export function findBestSongDuplicate(candidate, songs = []) {
  const candidateTitle = normalizeSongText(candidate?.title);
  const candidateInterpret = normalizeSongText(candidate?.interpret);

  if (!candidateTitle || !candidateInterpret) return null;

  let bestMatch = null;

  for (const song of songs) {
    const songTitle = normalizeSongText(song?.title);
    const songInterpret = normalizeSongText(song?.interpret);
    if (!songTitle || !songInterpret) continue;

    const exact = candidateTitle === songTitle && candidateInterpret === songInterpret;
    const titleScore = bestFieldScore(candidateTitle, songTitle);
    const interpretScore = bestFieldScore(candidateInterpret, songInterpret);
    const combinedScore = exact ? 1 : titleScore * 0.6 + interpretScore * 0.4;

    const passesBalancedThreshold =
      exact ||
      (titleScore >= 0.84 && interpretScore >= 0.84) ||
      combinedScore >= 0.88;

    if (!passesBalancedThreshold) continue;

    if (!bestMatch || combinedScore > bestMatch.score) {
      bestMatch = {
        score: combinedScore,
        song
      };
    }
  }

  return bestMatch;
}
