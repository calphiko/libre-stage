// src/lib/api.js

// Basis-URL zu deinem Backend, manchmal ggf. anpassen
export const API_URL = import.meta.env.VITE_API_URL;

let isRefreshing = false;
let refreshPromise = null;
let refreshFailedRecently = false;
let lastRefreshAttempt = 0;
const REFRESH_COOLDOWN_MS = 5000; // 5 Sekunden Cooldown nach fehlgeschlagenem Refresh
let csrfTokenCache = null;

// Redirect-Schutz
let isRedirecting = false;
let authenticationFailed = false; // Blockiert alle weiteren Requests

// Legacy-Aufräumhilfe: entfernt alte localStorage-Tokenreste
function clearTokens() {
  csrfTokenCache = null;
  if (typeof localStorage === 'undefined') return;
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
}

function getCookieValue(name) {
  if (typeof document === 'undefined') return null;
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length !== 2) return null;
  return parts.pop().split(';').shift() ?? null;
}

function rememberCsrfToken(value) {
  if (typeof value !== 'string') return;
  const normalized = value.trim();
  if (!normalized) return;
  csrfTokenCache = normalized;
}

function getCsrfToken() {
  const cookieToken = getCookieValue('csrf_token');
  if (cookieToken) {
    rememberCsrfToken(cookieToken);
    return cookieToken;
  }
  return csrfTokenCache;
}

async function ensureCsrfToken() {
  const existing = getCsrfToken();
  if (existing) return existing;

  try {
    const res = await fetch(`${API_URL}/csrf`, {
      method: 'GET',
      credentials: 'include',
    });
    if (!res.ok) return null;

    const payload = await res.json().catch(() => ({}));
    rememberCsrfToken(payload?.csrf_token);
    return getCsrfToken();
  } catch (_err) {
    return null;
  }
}

async function readErrorDetail(response, fallbackMessage) {
  const data = await response.json().catch(() => ({}));
  return data.detail || fallbackMessage;
}

/**
 * Prüft ob wir auf der Login-Seite sind
 */
function isOnLoginPage() {
  if (typeof window === 'undefined') return false;
  const path = window.location.pathname;
  return path === '/' || path === '/login' || path === '/password_reset';
}

/**
 * Versucht Session automatisch zu refreshen
 * Mit Schutz gegen Race Conditions und Endlosschleifen
 */
async function refreshTokens() {
  if (authenticationFailed) {
    throw new Error('Authentication already failed');
  }

  const now = Date.now();
  if (refreshFailedRecently && (now - lastRefreshAttempt) < REFRESH_COOLDOWN_MS) {
    throw new Error('Refresh recently failed, waiting for cooldown');
  }

  if (isRefreshing && refreshPromise) {
    return refreshPromise;
  }

  isRefreshing = true;
  lastRefreshAttempt = now;

  refreshPromise = (async () => {
    try {
      const res = await fetch(`${API_URL}/refresh`, {
        method: 'POST',
        credentials: 'include',
      });

      if (!res.ok) {
        const detail = await readErrorDetail(res, 'Token refresh failed');
        refreshFailedRecently = true;
        authenticationFailed = true;
        throw new Error(detail);
      }

      const payload = await res.json().catch(() => ({}));
      rememberCsrfToken(payload?.csrf_token);

      refreshFailedRecently = false;
      authenticationFailed = false;
      return true;
    } catch (e) {
      refreshFailedRecently = true;
      authenticationFailed = true;
      throw e;
    } finally {
      isRefreshing = false;
      refreshPromise = null;
    }
  })();

  return refreshPromise;
}

/**
 * Leitet zum Login um (nur einmal, mit Schutz)
 */
function redirectToLogin() {
  if (isRedirecting) return;
  if (typeof window === 'undefined') return;
  if (isOnLoginPage()) return;

  isRedirecting = true;
  authenticationFailed = true;
  clearTokens();

  window.location.href = '/';
}

/**
 * Wrapper für fetch mit Cookie-Auth und automatischem Session-Refresh bei 401
 */
async function fetchWithAuth(url, options = {}, retryCount = 0) {
  const MAX_RETRIES = 1;

  if (authenticationFailed) {
    throw new Error('Authentication failed - please login again');
  }

  const requestOptions = {
    ...options,
    credentials: 'include',
    headers: {
      ...options.headers,
    },
  };

  const method = (requestOptions.method ?? 'GET').toUpperCase();
  const requiresCsrf = !['GET', 'HEAD', 'OPTIONS'].includes(method);
  if (requiresCsrf) {
    let csrfToken = await ensureCsrfToken();

    if (csrfToken) {
      requestOptions.headers['X-CSRF-Token'] = csrfToken;
    }
  }

  let res = await fetch(url, requestOptions);

  if (res.status === 403) {
    const detail = await readErrorDetail(res, 'Request blocked by security policy');

    if (requiresCsrf && detail === 'CSRF validation failed' && retryCount < MAX_RETRIES && !authenticationFailed) {
      try {
        const refreshedCsrfToken = await ensureCsrfToken();
        if (refreshedCsrfToken) {
          requestOptions.headers['X-CSRF-Token'] = refreshedCsrfToken;
        }
        res = await fetch(url, requestOptions);
      } catch (_err) {
        throw new Error(detail);
      }

      if (res.status === 403) {
        const retryDetail = await readErrorDetail(res, 'Request blocked by security policy');
        throw new Error(retryDetail);
      }
    } else {
      throw new Error(detail);
    }
  }

  if (res.status === 401 && retryCount < MAX_RETRIES && !authenticationFailed) {
    try {
      await refreshTokens();
      if (requiresCsrf) {
        const refreshedCsrfToken = getCsrfToken();
        if (refreshedCsrfToken) {
          requestOptions.headers['X-CSRF-Token'] = refreshedCsrfToken;
        }
      }
      res = await fetch(url, requestOptions);

      if (res.status === 403) {
        const detail = await readErrorDetail(res, 'Request blocked by security policy');
        throw new Error(detail);
      }

      if (res.status === 401) {
        const detail = await readErrorDetail(res, 'Authentication failed after refresh');
        authenticationFailed = true;
        if (!isOnLoginPage()) {
          redirectToLogin();
        }
        throw new Error(detail);
      }
    } catch (e) {
      authenticationFailed = true;
      if (!isOnLoginPage()) {
        redirectToLogin();
      }
      throw new Error(e?.message || 'Authentication failed');
    }
  } else if (res.status === 401) {
    const detail = await readErrorDetail(res, 'Authentication failed');
    authenticationFailed = true;
    if (!isOnLoginPage()) {
      redirectToLogin();
    }
    throw new Error(detail);
  }

  return res;
}

export async function login(username, password) {
  refreshFailedRecently = false;
  isRedirecting = false;
  authenticationFailed = false;

  const res = await fetch(`${API_URL}/login`, {
    method: 'POST',
    credentials: 'include',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username, password })
  });

  if (!res.ok) {
    const error = await res.json().catch(() => ({ detail: 'Login failed' }));
    throw new Error(error.detail || 'Login failed');
  }

  const payload = await res.json();
  rememberCsrfToken(payload?.csrf_token);

  // Alte localStorage-Token nach erfolgreichem Cookie-Login entfernen
  clearTokens();
  rememberCsrfToken(payload?.csrf_token);
  return payload;
}

export async function logout() {
  refreshFailedRecently = false;
  isRedirecting = false;
  authenticationFailed = false;

  try {
    const headers = {
      'Content-Type': 'application/json'
    };
    const csrfToken = await ensureCsrfToken();
    if (csrfToken) {
      headers['X-CSRF-Token'] = csrfToken;
    }

    await fetch(`${API_URL}/logout`, {
      method: 'POST',
      credentials: 'include',
      headers
    });
  } catch (e) {
    console.error('Logout request failed:', e);
  } finally {
    clearTokens();
  }

  return { message: 'Logged out' };
}

export async function getUser(token) {
  const res = await fetchWithAuth(`${API_URL}/me`, {
    method: 'GET'
  });
  if (!res.ok) throw new Error('User not found');
  return res.json();
}

export async function getUserList(token) {
  const res = await fetchWithAuth(`${API_URL}/user_list`, {
    method: 'GET'
  });
  if (!res.ok) throw new Error('Users list could not be load');
  return res.json();
}

export async function updateUser(token, data) {
    console.log('update user');
    const res = await fetchWithAuth(`${API_URL}/update_user`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function changePasswordByUser(token, data) {
    console.log("update password by user");
    const res = await fetchWithAuth(`${API_URL}/change_password`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function addNewGig(token, data) {
  const res = await fetchWithAuth(`${API_URL}/gigs/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function delGig(token, gigId) {
  console.log("Delete Gig: ");
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function getGigs(token, jahr = '') {
  const url = jahr
    ? `${API_URL}/gigs/?jahr=${encodeURIComponent(jahr)}`
    : `${API_URL}/gigs/`;
  const res = await fetchWithAuth(url, {
    method: 'GET'
  });
  if (!res.ok) throw new Error('Could not get gigs');
  return res.json();
}

export async function getGigSchedule(token, gigId) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule/`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' }
  });
  if (!res.ok) throw new Error('Ablaufplan konnte nicht geladen werden');
  return res.json();
}

export async function getGigSchedulePDF(token, gigId) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule.pdf`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' }
  });
  if (!res.ok) throw new Error('Ablaufplan-PDF konnte nicht geladen werden');
  return res.blob();
}

export async function createGigScheduleItem(token, gigId, payload) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Ablaufplan-Eintrag konnte nicht erstellt werden');
  }
  return res.json();
}

export async function updateGigScheduleItem(token, gigId, itemId, payload) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule/${itemId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Ablaufplan-Eintrag konnte nicht aktualisiert werden');
  }
  return res.json();
}

export async function updateGigScheduleBulk(token, gigId, payload) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule/`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Ablaufplan konnte nicht gespeichert werden');
  }
  return res.json();
}

export async function deleteGigScheduleItem(token, gigId, itemId) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/schedule/${itemId}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' }
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Ablaufplan-Eintrag konnte nicht geloescht werden');
  }
  return res.json();
}

export async function updateGig(gigId, data, token) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
  }

export async function updateSong(songId, data, token) {
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function acceptSongApproach(songId, token) {
    console.log("Accept Song Suggestion");
    const res = await fetchWithAuth(`${API_URL}/songs/candidates/accept/${songId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json'
        }
    });
}

export async function createNewSong(data, token) {
    const res = await fetchWithAuth(`${API_URL}/songs/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Create Song fehlgeschlagen');
    return res.json();
}

export async function deleteSong(songId, token) {
    console.log("Delete Song ");
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json'
        },
      });
      if (!res.ok) throw new Error('Delete fehlgeschlagen');
      return res.json();
  }

export async function getSongs(token) {
    const res = await fetchWithAuth(`${API_URL}/songs/`, {
      method: 'GET'
    });
    if (!res.ok) throw new Error('Songs nicht geladen');
    return res.json();
  }

export async function getSongsCandidates(token) {
    const res = await fetchWithAuth(`${API_URL}/songs/candidates/`, {
      method: 'GET'
    });
    if (!res.ok) throw new Error('Songs nicht geladen');

    return res.json();
  }

export async function getSongCrawlerMetadata(interpret, title) {
  const params = new URLSearchParams({ interpret, title });
  const res = await fetchWithAuth(`${API_URL}/songs/crawler/metadata?${params.toString()}`, {
    method: 'GET'
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Song-Metadaten konnten nicht geladen werden');
  }
  return res.json();
}

  export async function updateSongCandidateFeedback(token, songId, feedback) {
    const response = await fetchWithAuth(`${API_URL}/songs/candidates/feedback/${songId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(feedback)
    });
    if (!response.ok) throw new Error('Failed to update song candidate feedback');

    return response.json();
  }

export async function getGemaListFile(token, gigId) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/gemalist`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    return res.blob();
}

export async function getSetlistPDF(token, gigId, design = 'dark') {
    const params = new URLSearchParams();
    if (design && design !== 'dark') {
      params.set('design', design);
    }
    const query = params.toString();
    const url = `${API_URL}/gigs/${gigId}/setlist.pdf${query ? `?${query}` : ''}`;
    const res = await fetchWithAuth(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    return res.blob();                   // <—— liefert einen echten Blob
}

export async function getSetlist(token, gigId) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/setlist`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}: ${res.statusText}`);
    }

    return res.json();
}

export async function updateGigSetlist(token, gigId, data) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/update_setlist/`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      let responseBody = null;
      try {
        responseBody = await res.json();
      } catch (_err) {
        responseBody = null;
      }

      const detail = responseBody?.detail;

      if (res.status === 409 && detail?.code === 'SETLIST_CONFLICT') {
        const conflictError = new Error(detail?.message || 'Setlist-Konflikt erkannt');
        conflictError.code = 'SETLIST_CONFLICT';
        conflictError.status = 409;
        conflictError.currentSetlist = detail?.current_setlist ?? null;
        throw conflictError;
      }

      const message =
        typeof detail === 'string'
          ? detail
          : detail?.message || responseBody?.message || `HTTP ${res.status}: ${res.statusText}`;
      throw new Error(message || 'Update fehlgeschlagen');
    }

    return res.json();
}

export async function getGigSetlistAvailability(token, gigId) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/setlist_available`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!res.ok) throw new Error('Could not get setlist availability');
    return res.json();
}

export async function getSong(token, songId) {
    const res = await fetchWithAuth(`${API_URL}/songs/info/${songId}`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Song not found');
    return res.json();
}

export async function getSongDetails(songId) {
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Song not found');
    return res.json();
}

export async function getSongRehearsalHistory(songId, limit = 3) {
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}/rehearsal_history?limit=${limit}`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Proben-Historie konnte nicht geladen werden');
    return res.json();
}

export async function getSongStatistics(songId) {
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}/statistics`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Song-Statistiken konnten nicht geladen werden');
    return res.json();
}

export async function getSongFeedbackHistory(songId) {
    const res = await fetchWithAuth(`${API_URL}/songs/${songId}/feedback`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Abstimmungsverhalten konnte nicht geladen werden');
    return res.json();
}

export async function getSeasonStatistics(jahr) {
    const url = jahr
        ? `${API_URL}/gigs/statistics?jahr=${encodeURIComponent(jahr)}`
        : `${API_URL}/gigs/statistics`;
    const res = await fetchWithAuth(url, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error('Saisonstatistiken konnten nicht geladen werden');
    return res.json();
}

export async function getGigStatistics(gigId) {
    const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/statistics`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error('Gig-Statistiken konnten nicht geladen werden');
    return res.json();
}

export async function getGenrePalette() {
    const res = await fetchWithAuth(`${API_URL}/gigs/genre_palette`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error('Genre-Palette konnte nicht geladen werden');
    return res.json();
}

export async function getRehearsalList(token) {
    const res = await fetchWithAuth(`${API_URL}/reh/`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        },
    });
    if (!res.ok) throw new Error('Rehearsals');
    return res.json();
}

export async function updateRehearsals(token, data) {
    const res = await fetchWithAuth(`${API_URL}/reh/`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function createNewRehearsal(token, data) {
    const res = await fetchWithAuth(`${API_URL}/reh/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function deleteRehearsal(token, rehId) {
    const res = await fetchWithAuth(`${API_URL}/reh/${rehId}`, {
            method: 'DELETE',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function getUserTodos(token) {
    const res = await fetchWithAuth(`${API_URL}/user_todos`, {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');

    console.log("Fetching Todos from API");
    const todos = await res.json();
    const doneTodos = todos.todo.filter(todo => todo.done === true);
    const notDoneTodos = todos.todo.filter(todo => todo.done === false);

    return {
        doneTodos,
        notDoneTodos,
        songsForFeedback: todos.songs_to_feedback,
        surveysForFeedback:  todos.surveys_to_feedback
    };
}

export async function updateUserTodo(token, td) {
    const res = await fetchWithAuth(`${API_URL}/user_todos_done`, {
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(td),
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');

    const todos = await res.json();
    //console.log("API: Aktualisierte Todos", todos);
    const doneTodos = todos.todo.filter(todo => todo.done === true);
    const notDoneTodos = todos.todo.filter(todo => todo.done === false);

    return {
        doneTodos,
        notDoneTodos,
        songsForFeedback: todos.songs_to_feedback,
        surveysForFeedback:  todos.surveys_to_feedback
    };

}

export async function getSurveys( token ) {
    const res = await fetchWithAuth(`${API_URL}/surveys/`, {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function getSurveyDetails( token , surveyId) {
    const res = await fetchWithAuth(`${API_URL}/surveys/${surveyId}`, {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json'
            },

    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function updateSurveyFeedback(token, surveyId, feedbacks) {
  console.log('Updating survey feedback');
  const response = await fetchWithAuth(`${API_URL}/surveys/${surveyId}/feedback`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(feedbacks)
  });
  if (!response.ok) throw new Error('Failed to update survey feedback');

  return response.json();
}

export async function sendSurveyReminder(surveyId) {
    console.log('Sending survey reminder');
    const response = await fetchWithAuth(`${API_URL}/surveys/reminder/${surveyId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
    });
    if (!response.ok) throw new Error('Failed to send survey reminder');
    return response.json();
}

// ===== LIVE MODE API =====

export async function getGigLiveMode(token, gigId) {
  const res = await fetchWithAuth(`${API_URL}/gigs_lm/${gigId}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function updateSongLiveMode(token, gigId, songData) {
  console.log('Updating song in live mode:', songData);
  const res = await fetchWithAuth(`${API_URL}/gigs_lm/${gigId}/`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(songData)
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function insertSongAfter(token, gigId, afterSetSongId, songId) {
  console.log('Inserting song after:', afterSetSongId, 'song:', songId);
  const res = await fetchWithAuth(`${API_URL}/gigs_lm/${gigId}/insert-song?after_setsong_id=${afterSetSongId}&song_id=${songId}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function insertSongBefore(token, gigId, beforeSetSongId, songId) {
  console.log('Inserting song before:', beforeSetSongId, 'song:', songId);
  const res = await fetchWithAuth(`${API_URL}/gigs_lm/${gigId}/insert-song?before_setsong_id=${beforeSetSongId}&song_id=${songId}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function getLiveModeAvailability(token, gigId, force = false) {
  const res = await fetchWithAuth(`${API_URL}/gigs/${gigId}/livemode_available?force=${force}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    }
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function getLiveModeAvailabilityBatch(token, gigIds) {
  const res = await fetchWithAuth(`${API_URL}/gigs/livemode_available_batch`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(gigIds)
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  }
  return res.json();
}

export async function createSurvey(token, data) {
    const res = await fetchWithAuth(`${API_URL}/surveys/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error('Create survey failed');
    return res.json();
}

export async function deleteSurvey(token, surveyId) {
    const res = await fetchWithAuth(`${API_URL}/surveys/${surveyId}`, {
            method: 'DELETE',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Delete survey failed');
    return res.json();
}

export async function archiveSurvey(token, surveyId) {
    const res = await fetchWithAuth(`${API_URL}/surveys/close/${surveyId}`, {
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Archive survey failed');
    return res.json();
}

export async function appendSurveyFields(token, surveyId, fields) {
    const response = await fetchWithAuth(`${API_URL}/surveys/${surveyId}/fields`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ fields })
    });

    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error(err.detail ?? 'Failed to append survey fields');
    }

    return response.json();
}

export async function getVersionJson() {
    const res = await fetch(`${API_URL}/version`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json'
        }
    });
    if (!res.ok) throw new Error('Could not get the version string from API');
    return res.json();
}

export async function adminGetAllUsers(token) {
    const res = await fetchWithAuth(`${API_URL}/admin/users`, {
            method: 'GET',
            headers: {
              'Content-Type': 'application/json'
            }
    });
    if (!res.ok) throw new Error('Update fehlgeschlagen');
    return res.json();
}

export async function adminCreateUser(token, data) {
    const res = await fetchWithAuth(`${API_URL}/admin/users`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? 'Benutzer konnte nicht angelegt werden');
    }
    return res.json();
}

export async function adminDeactivateUser(token, userId) {
    const res = await fetchWithAuth(`${API_URL}/admin/users/${userId}`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' }
    });
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? 'Benutzer konnte nicht deaktiviert werden');
    }
    return res.json();
}

export async function adminActivateUser(token, userId) {
    const res = await fetchWithAuth(`${API_URL}/admin/users/${userId}/activate`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' }
    });
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail ?? 'Benutzer konnte nicht aktiviert werden');
    }
    return res.json();
}


export async function adminUpdateUser(token, data) {
    const response = await fetchWithAuth(`${API_URL}/admin/users/${data.id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(data)
  });
  if (!response.ok) throw new Error('Admin update user failed');

  return response.json();
}

export async function getSingers(token){
    const response = await fetchWithAuth(`${API_URL}/songs/singers`, {
        method: 'GET',
      });
      if (!response.ok) throw new Error('Getting Singers failed');

      return response.json();
    }

// ===== APP CONFIG API =====

let _appConfigCache = null;
let _appConfigPromise = null;

export function invalidateAppConfigCache() {
  _appConfigCache = null;
  _appConfigPromise = null;
}

/**
 * Lädt die App-Konfiguration vom Backend (öffentlicher Endpoint, kein Auth).
 * Das Ergebnis wird im Speicher gecached, sodass nur ein Request pro Seitenladen erfolgt.
 */
export async function getAppConfig(forceReload = false) {
  if (forceReload) {
    invalidateAppConfigCache();
  }

  if (_appConfigCache) return _appConfigCache;
  if (_appConfigPromise) return _appConfigPromise;

  _appConfigPromise = (async () => {
    const res = await fetch(`${API_URL}/public/app_config`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    });
    if (!res.ok) throw new Error('App-Konfiguration konnte nicht geladen werden');
    _appConfigCache = await res.json();
    return _appConfigCache;
  })();

  return _appConfigPromise;
}

export async function adminGetSoftConfig() {
  const res = await fetchWithAuth(`${API_URL}/admin/config/soft`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' }
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Konfiguration konnte nicht geladen werden');
  }
  return res.json();
}

export async function adminUpdateSoftConfig(payload) {
  const res = await fetchWithAuth(`${API_URL}/admin/config/soft`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail ?? 'Konfiguration konnte nicht gespeichert werden');
  }
  invalidateAppConfigCache();
  return res.json();
}


export async function getAppLogo() {
    const response = await fetch(`${API_URL}/public/logo`, {
        method: 'GET',
    });
    if (!response.ok) throw new Error('Getting app logo failed');

    return response.blob();
}

export async function triggerSendPwResetToken(user_id) {
    const res = await fetchWithAuth(`${API_URL}/admin/trigger_password_reset/${user_id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
    });
    if (!res.ok) throw new Error('Senden des Reset-Links fehlgeschlagen');
    return res.json();
}
