<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

<script>
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { getUser, getUserTodos, updateUserTodo, logout as apiLogout, getSeasonStatistics, getRehearsalList, getGigs } from '$lib/api.js';
  import SeasonGigProgressPlot from '$lib/plots/seasonGigProgressPlot.svelte';
  import SeasonSongMixPlot from '$lib/plots/seasonSongMixPlot.svelte';
  import SeasonFeedbackGaugePlot from '$lib/plots/seasonFeedbackGaugePlot.svelte';
  import SeasonGenreTopPlot from '$lib/plots/seasonGenreTopPlot.svelte';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  const { showError, showSuccess } = createMessageHelpers();



  let user = null;
  let error = '';
  let showHelp = false;
  let todos = {
      notDoneTodos: [],
      doneTodos: []
  };

  let calendarUrl = '';
  let seasonStats = null;
  let nextRehearsal = null;
  let nextGig = null;

  let tabsBasic = 0;
  let showSeasonStats = false;

  function parseDateSafe(value) {
    if (!value) return null;
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  function findNextRehearsal(rehearsals) {
    const now = new Date();
    return (rehearsals || [])
      .filter((reh) => parseDateSafe(reh.begin) && parseDateSafe(reh.begin) >= now)
      .sort((a, b) => new Date(a.begin) - new Date(b.begin))[0] ?? null;
  }

  function findNextGig(gigs) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return (gigs || [])
      .filter((gig) => parseDateSafe(gig.datum) && parseDateSafe(gig.datum) >= today)
      .sort((a, b) => new Date(a.datum) - new Date(b.datum))[0] ?? null;
  }

  function formatDateTime(dateValue, options = {}) {
    const parsed = parseDateSafe(dateValue);
    if (!parsed) return 'Unbekanntes Datum';
    return parsed.toLocaleString('de-DE', options);
  }

  function setTabIndex() {
    if (todos.notDoneTodos.length > 0) {
          tabsBasic = 0;
      } else if ((todos.songsForFeedback?.length ?? 0) > 0) {
          tabsBasic = 1;
      } else if ((todos.surveysForFeedback?.length ?? 0) > 0) {
          tabsBasic = 2;
      } else {
          tabsBasic = 3; // Zeige erledigte Todos, wenn keine offenen vorhanden sind
      }
  }

  onMount( async () => {
    try {
      user = await getUser();
      todos = await getUserTodos();
      setTabIndex();
      calendarUrl = `${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/ical/`;
      calendarUrl = calendarUrl.replace(/^https:\/\//, 'webcal://');

      // Lade Saisonstatistiken für das aktuelle Jahr
      const currentYear = new Date().getFullYear();
      const [stats, rehearsals, gigs] = await Promise.all([
        getSeasonStatistics(currentYear),
        getRehearsalList(),
        getGigs(null, ''),
      ]);

      seasonStats = stats;
      nextRehearsal = findNextRehearsal(rehearsals);
      nextGig = findNextGig(gigs);
    } catch(e) {
      // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
      error = 'Nicht eingeloggt oder Session abgelaufen';
      console.error('Dashboard load error:', e);
    }
  });

  async function logout() {
    try {
      await apiLogout();
    } catch (e) {
      console.error('Logout error:', e);
    }
    goto('/');
  }

  async function markTodoAsDone(td) {
      if (!td) {
        showError("Keine Todo-ID angegeben");
        return;
      }

      try {
        todos = await updateUserTodo(null, td);
        setTabIndex();
        showSuccess("Todo als erledigt markiert");
      } catch (e) {
        showError(`Fehler beim Aktualisieren: ${e.message}`);
      }
  }
</script>

<div class="max-w-6xl md:mx-auto py-6 md:px-3">
  <div class="card bg-surface-2 rounded-2xl shadow-lg p-2 md:p-6 md:border md:border-outline-variant">
    {#if user}
      <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between mb-6">
        <div>
          <h2 class="h2 text-on-surface">Dashboard</h2>
          <p class="text-lg text-on-surface mt-1">
            Willkommen, <span class="font-semibold">{user.user_name}</span>!
          </p>
          <div class="mt-3 flex flex-wrap gap-2">
            <span class="inline-block px-3 py-1 rounded bg-primary-100 text-primary-900 text-sm">
              {user.user_group}
            </span>
            <span class="inline-block px-3 py-1 rounded bg-secondary-100 text-secondary-900 text-sm">
              Offen: {todos.notDoneTodos.length}
            </span>
            <span class="inline-block px-3 py-1 rounded bg-tertiary-100 text-tertiary-900 text-sm">
              Feedback: {(todos.songsForFeedback?.length ?? 0) + (todos.surveysForFeedback?.length ?? 0)}
            </span>
          </div>
        </div>
      </div>

      <div class="mt-7">
        <h2 class="text-xl font-semibold mb-2 text-on-surface">Deine Todos</h2>
        {#if (todos.songsForFeedback?.length ?? 0) == 0 && (todos.surveysForFeedback?.length ?? 0) == 0 && todos.notDoneTodos.length == 0}
          <div class="rounded-xl bg-success-100 text-success-900 p-4 mt-4 shadow text-center">
            Du hast keine offenen Todos! 🎉
          </div>
        {:else}
          <div class="flex border-b border-surface-300 dark:border-surface-600 mb-4 gap-1 overflow-x-auto">
            <button onclick={() => tabsBasic = 0} class="px-4 py-2 rounded-t-lg transition-colors whitespace-nowrap {tabsBasic === 0 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {todos.notDoneTodos.length > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Offene Todos ({todos.notDoneTodos.length})</span>
              <span class="md:hidden">Offen ({todos.notDoneTodos.length})</span>
            </button>

            <button onclick={() => tabsBasic = 1} class="px-4 py-2 rounded-t-lg transition-colors whitespace-nowrap {tabsBasic === 1 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {(todos.songsForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Songs ({todos.songsForFeedback?.length ?? 0})</span>
              <span class="md:hidden">🎵 ({todos.songsForFeedback?.length ?? 0})</span>
            </button>

            <button onclick={() => tabsBasic = 2} class="px-4 py-2 rounded-t-lg transition-colors whitespace-nowrap {tabsBasic === 2 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {(todos.surveysForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Abstimmungen ({todos.surveysForFeedback?.length ?? 0})</span>
              <span class="md:hidden">📊 ({todos.surveysForFeedback?.length ?? 0})</span>
            </button>

            <button onclick={() => tabsBasic = 3} class="px-4 py-2 rounded-t-lg transition-colors whitespace-nowrap {tabsBasic === 3 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}">
              <span class="hidden md:inline">Erledigt ({todos.doneTodos.length})</span>
              <span class="md:hidden">✓ ({todos.doneTodos.length})</span>
            </button>
          </div>

          <div class="mt-4">
            {#if tabsBasic === 0}
              <div class="hidden md:block">
                <table class="w-full border-collapse rounded-xl shadow mb-6 bg-surface-1 text-on-surface">
                  <thead class="bg-primary-50 text-primary-900">
                    <tr>
                      <th class="font-semibold py-2 px-3 border-b">Interpret</th>
                      <th class="font-semibold py-2 px-3 border-b">Titel</th>
                      <th class="font-semibold py-2 px-3 border-b">Todo</th>
                      <th class="font-semibold py-2 px-3 border-b">Done</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each todos.notDoneTodos as td (td.id)}
                      <tr class="hover:bg-secondary-50/60 transition">
                        <td class="px-3 py-2">{td.song_interpret}</td>
                        <td class="px-3 py-2">{td.song_title}</td>
                        <td class="px-3 py-2">{td.todo}</td>
                        <td class="px-3 py-2">
                          <button
                            class="btn variant-filled-primary rounded-lg px-3 py-0 text-base font-semibold"
                            onclick={() => markTodoAsDone(td)}
                          >✓</button>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>

              <div class="block md:hidden mt-5">
                {#each todos.notDoneTodos as td (td.id)}
                  <div class="bg-secondary-200 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                    <h5 class="font-bold mb-1 text-primary-900">{td.song_interpret} - {td.song_title}</h5>
                    <p class="mb-2 text-on-surface-variant">{td.todo}</p>
                    <button
                      class="btn variant-filled-success w-full rounded-lg py-2 font-semibold"
                      onclick={() => markTodoAsDone(td)}
                    >✓</button>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 1}
              <div class="hidden md:block">
                <table class="w-full border-collapse rounded-xl shadow mb-1 bg-surface-1 text-on-surface">
                  <thead class="bg-tertiary-50 text-tertiary-900">
                    <tr>
                      <th class="font-semibold py-2 px-3 border-b">Interpret</th>
                      <th class="font-semibold py-2 px-3 border-b">Titel</th>
                      <th class="font-semibold py-2 px-3 border-b">Mein Feedback</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each todos.songsForFeedback as s (s.id)}
                      <tr>
                        <td class="px-3 py-2">{s.interpret}</td>
                        <td class="px-3 py-2">{s.title}</td>
                        <td class="px-3 py-2">Mein Feedback</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>

              <div class="block md:hidden mt-5">
                {#each todos.songsForFeedback as s (s.id)}
                  <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                    <h5 class="font-bold mb-1">{s.interpret} - {s.title}</h5>
                    <p class="mb-2">Mein Feedback</p>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 2}
              <div class="hidden md:block">
                <table class="w-full border-collapse rounded-xl shadow mb-1 bg-surface-1 text-on-surface">
                  <thead class="bg-tertiary-50 text-tertiary-900">
                    <tr>
                      <th class="font-semibold py-2 px-3 border-b">Umfragegrund</th>
                      <th class="font-semibold py-2 px-3 border-b">Feedback</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each todos.surveysForFeedback as sf (sf.id)}
                      <tr>
                        <td class="px-3 py-2">{sf.rf_survey}</td>
                        <td class="px-3 py-2">Mein Feedback</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>

              <div class="block md:hidden mt-5">
                {#each todos.surveysForFeedback as sf (sf.id)}
                  <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                    <h5 class="font-bold mb-1">{sf.rf_survey}</h5>
                    <p class="mb-2">Mein Feedback</p>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 3}
              <div class="hidden md:block">
                <table class="w-full border-collapse rounded-xl shadow mb-1 bg-surface-1 text-on-surface">
                  <thead class="bg-tertiary-50 text-tertiary-900">
                    <tr>
                      <th class="font-semibold py-2 px-3 border-b">Interpret</th>
                      <th class="font-semibold py-2 px-3 border-b">Titel</th>
                      <th class="font-semibold py-2 px-3 border-b">Todo</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each todos.doneTodos as td (td.id)}
                      <tr>
                        <td class="px-3 py-2">{td.song_interpret}</td>
                        <td class="px-3 py-2">{td.song_title}</td>
                        <td class="px-3 py-2 text-tertiary-700 font-medium">{td.todo}</td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>

              <div class="block md:hidden mt-5">
                {#each todos.doneTodos as td (td.id)}
                  <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                    <h5 class="font-bold mb-1">{td.song_interpret} - {td.song_title}</h5>
                    <p class="mb-2">{td.todo}</p>
                  </div>
                {/each}
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <hr class="my-7 border-outline-variant">

      <div>
        <h2 class="text-xl font-semibold mb-2 text-on-surface">Nächste Termine</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
          <div class="card variant-ghost-primary p-4 rounded-lg">
            <div class="text-sm text-on-surface-variant mb-1">Nächste Probe</div>
            {#if nextRehearsal}
              <div class="text-lg font-semibold text-on-surface">
                {formatDateTime(nextRehearsal.begin, { weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
              </div>
              {#if nextRehearsal.comment}
                <div class="text-sm text-on-surface-variant mt-1 truncate">{nextRehearsal.comment}</div>
              {/if}
            {:else}
              <div class="text-lg font-semibold text-on-surface">Keine Probe geplant</div>
            {/if}
            <div class="mt-3">
              <a class="btn variant-ghost-primary btn-sm" href="/proben">Zu Proben</a>
            </div>
          </div>

          <div class="card variant-ghost-secondary p-4 rounded-lg">
            <div class="text-sm text-on-surface-variant mb-1">Nächster Auftritt</div>
            {#if nextGig}
              <div class="text-lg font-semibold text-on-surface">
                {formatDateTime(nextGig.datum, { weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric' })}
              </div>
              <div class="text-sm text-on-surface-variant mt-1 truncate">{nextGig.name || 'Ohne Titel'}</div>
            {:else}
              <div class="text-lg font-semibold text-on-surface">Kein Auftritt geplant</div>
            {/if}
            <div class="mt-3">
              <a class="btn variant-ghost-secondary btn-sm" href="/gigs">Zu Gigs</a>
            </div>
          </div>
        </div>
      </div>

      <hr class="my-7 border-outline-variant">

      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-xl font-semibold text-on-surface">Saison {new Date().getFullYear()}</h2>
          <button class="btn variant-ghost-surface btn-sm md:hidden" onclick={() => showSeasonStats = !showSeasonStats}>
            {showSeasonStats ? 'Weniger anzeigen' : 'Mehr anzeigen'}
          </button>
        </div>

        {#if seasonStats}
          <div class="grid grid-cols-1 md:grid-cols-2 gap-2 md:gap-3 mt-4 {showSeasonStats ? '' : 'hidden md:grid'}">
            <div class="card variant-ghost-primary p-3 md:p-4 rounded-lg min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonGigProgressPlot
                playedGigCount={seasonStats.played_gig_count}
                gigCount={seasonStats.gig_count}
                titlePrefix="Gigs gespielt"
              />
            </div>

            <div class="card variant-ghost-secondary p-3 md:p-4 rounded-lg min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonSongMixPlot
                totalSongs={seasonStats.total_songs}
                uniqueSongs={seasonStats.unique_songs}
                titlePrefix="Songs gesamt vs. Unique"
              />
            </div>

            <div class="card variant-ghost-warning p-3 md:p-4 rounded-lg min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonFeedbackGaugePlot
                feedbackAvg={seasonStats.feedback_avg}
                feedbackCount={seasonStats.feedback_count}
                titlePrefix="Feedback-Durchschnitt"
              />
            </div>

            <div class="card variant-ghost-tertiary p-3 md:p-4 rounded-lg min-h-[280px] md:min-h-[300px] overflow-hidden">
              <SeasonGenreTopPlot
                genreDistribution={seasonStats.genre_distribution}
                topN={5}
                titlePrefix="Genres in dieser Saison"
              />
            </div>
          </div>
        {:else}
          <div class="text-on-surface-variant text-sm mt-3">Keine Saisonstatistiken verfügbar.</div>
        {/if}
      </div>

      <hr class="my-7 border-outline-variant">

      <div>
        <h2 class="text-xl font-semibold my-2 text-on-surface">Service & Hilfe</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <div class="p-4 rounded-xl border border-primary-200">
            <h3 class="text-lg font-semibold text-surface-900 dark:text-surface-50 mb-2">Kalender-Abo</h3>
            <p class="text-sm text-primary-700 dark:text-primary-50 mb-3">
              Abonniere den Bandkalender, um alle Proben und Gigs in deiner Kalender-App zu sehen.
            </p>
            <div class="flex gap-2">
              <input
                type="text"
                readonly
                value={calendarUrl}
                class="input flex-1 text-sm"
              />
              <button
                class="btn variant-filled-primary"
                onclick={() => navigator.clipboard.writeText(calendarUrl)}
              >
                Kopieren
              </button>
            </div>
            <p class="text-xs text-primary-700 dark:text-surface-50 mt-2">
              Füge diese URL als Kalender-Abo in deiner Kalender-App hinzu.
            </p>
          </div>

          <div class="p-4 rounded-xl border border-outline-variant">
            <h3 class="text-lg font-semibold text-on-surface mb-2">Dashboard-Hilfe</h3>
            <p class="text-sm text-on-surface-variant mb-3">
              Hier findest du eine kurze Erklärung zu Todos, Feedback und Aktionen.
            </p>
            <button class="btn variant-ghost-surface btn-sm" onclick={() => showHelp = !showHelp}>
              {showHelp ? 'Anleitung ausblenden' : 'Anleitung anzeigen'}
            </button>
          </div>
        </div>

        {#if showHelp}
          <div class="card variant-ghost-surface mt-4 p-4 md:p-6">
            <h3 class="h4 font-bold mb-4">Anleitung: Dashboard</h3>

            <div class="space-y-4">
              <div>
                <h4 class="font-semibold text-primary-500 mb-2">Uebersicht</h4>
                <p class="text-sm">Das Dashboard ist deine zentrale Anlaufstelle fuer offene Aufgaben und Feedback-Anfragen.</p>
              </div>

              <div>
                <h4 class="font-semibold text-secondary-500 mb-2">Die vier Bereiche</h4>
                <ul class="list-disc list-inside space-y-1 text-sm">
                  <li><strong>Offene Todos:</strong> Deine persoenlichen Aufgaben fuer Songs.</li>
                  <li><strong>Songs:</strong> Songs, die auf dein Feedback warten.</li>
                  <li><strong>Abstimmungen:</strong> Umfragen, an denen du noch nicht teilgenommen hast.</li>
                  <li><strong>Erledigt:</strong> Alle abgeschlossenen Todos zur Uebersicht.</li>
                </ul>
              </div>

              <div>
                <h4 class="font-semibold text-tertiary-500 mb-2">Aktionen</h4>
                <ul class="list-disc list-inside space-y-1 text-sm">
                  <li><strong>Todo abhaken:</strong> Klicke auf "✓", um ein Todo als erledigt zu markieren.</li>
                  <li><strong>Song bewerten:</strong> Nutze dein Feedback bei Songs und Abstimmungen.</li>
                </ul>
              </div>
            </div>
          </div>
        {/if}
      </div>
    {:else if error}
      <h2 class="h2 text-on-surface mb-4">Dashboard</h2>
      <div class="rounded-xl bg-error-100 text-error-900 p-4 mt-6 shadow text-center">{error}</div>
    {:else}
      <h2 class="h2 text-on-surface mb-4">Dashboard</h2>
      <div class="text-on-surface-variant text-center my-8">Lade Dashboard...</div>
    {/if}
  </div>
</div>
