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
  import { getUser, getUserTodos, updateUserTodo, logout as apiLogout, getSeasonStatistics, getRehearsalList, getGigs, getICalURLs, toggleChecklistItemDone, exportAllSetlists } from '$lib/api.js';
  import { modalState } from '$lib/modalState.js';
  import ChecklistItemDetailModal from '$lib/components/ChecklistItemDetailModal.svelte';
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

  let pendingAvailabilityGigs = [];

  let calendarUrl = '';
  let seasonStats = null;
  let nextRehearsal = null;
  let nextGig = null;
  let calUrls = {
    open: '',
    internal: ''
  };

  let tabsBasic = 0;
  let showSeasonStats = true;
  let exportingSetlists = false;

  async function downloadAllSetlists() {
    exportingSetlists = true;
    try {
      const { blob, filename } = await exportAllSetlists();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showSuccess('Setlisten erfolgreich exportiert.');
    } catch (e) {
      showError('Fehler beim Exportieren der Setlisten: ' + e.message);
    } finally {
      exportingSetlists = false;
    }
  }

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
      } else if ((todos.gigChecklistTodos?.length ?? 0) > 0) {
          tabsBasic = 1;
      } else if ((todos.songsForFeedback?.length ?? 0) > 0) {
          tabsBasic = 2;
      } else if ((todos.surveysForFeedback?.length ?? 0) > 0) {
          tabsBasic = 3;
      } else if (pendingAvailabilityGigs.length > 0) {
          tabsBasic = 4;
      } else {
          tabsBasic = 5; // Zeige erledigte Todos, wenn keine offenen vorhanden sind
      }
  }

  onMount( async () => {
    try {
      user = await getUser();
      todos = await getUserTodos();
      pendingAvailabilityGigs = todos.pendingAvailabilityGigs ?? [];
      setTabIndex();
      calUrls = await getICalURLs();
      calendarUrl = `${import.meta.env.VITE_API_URL || 'http://localhost:8000'}`;
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

  async function markChecklistItemDone(item) {
      try {
        await toggleChecklistItemDone(null, item.gig_id, item.id);
        // Remove item from list optimistically
        todos = { ...todos, gigChecklistTodos: todos.gigChecklistTodos.filter(i => i.id !== item.id) };
        setTabIndex();
        showSuccess("Aufgabe als erledigt markiert");
      } catch (e) {
        showError(`Fehler: ${e.message}`);
      }
  }

  function openChecklistItemModal(item) {
    const canEdit = user?.user_group === 'editor' || user?.user_group === 'admin';
    modalState.trigger({
      component: ChecklistItemDetailModal,
      meta: {
        item,
        canEdit,
        onItemUpdated: async () => {
          todos = await getUserTodos().catch(() => todos);
          pendingAvailabilityGigs = todos.pendingAvailabilityGigs ?? [];
          setTabIndex();
        },
      },
    });
  }
</script>

<div class="ui-page ui-page-gradient">
  <div class="ui-card p-2 md:p-6 dashboard-main-card">
    {#if user}
      <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between mb-6">
        <div>
          <h2 class="h2 text-on-surface">Dashboard</h2>
        </div>
      </div>

      <div class="mt-7">
        <h2 class="text-xl font-semibold mb-2 text-on-surface">Deine Todos</h2>
        {#if (todos.songsForFeedback?.length ?? 0) == 0 && (todos.surveysForFeedback?.length ?? 0) == 0 && todos.notDoneTodos.length == 0 && pendingAvailabilityGigs.length == 0 && (todos.gigChecklistTodos?.length ?? 0) == 0}
          <div class="rounded-xl p-4 mt-4 shadow text-center dashboard-success-panel text-on-surface">
            Du hast keine offenen Todos! 🎉
          </div>
        {:else}
          <div class="ui-tabs mb-4">
            <button onclick={() => tabsBasic = 0} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 0 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {todos.notDoneTodos.length > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Offene Todos ({todos.notDoneTodos.length})</span>
              <span class="md:hidden">Offen ({todos.notDoneTodos.length})</span>
            </button>

            <button onclick={() => tabsBasic = 1} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 1 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {(todos.gigChecklistTodos?.length ?? 0) > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Checkliste ({todos.gigChecklistTodos?.length ?? 0})</span>
              <span class="md:hidden">✅ ({todos.gigChecklistTodos?.length ?? 0})</span>
            </button>

            <button onclick={() => tabsBasic = 2} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 2 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {(todos.songsForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Songs ({todos.songsForFeedback?.length ?? 0})</span>
              <span class="md:hidden">🎵 ({todos.songsForFeedback?.length ?? 0})</span>
            </button>

            <button onclick={() => tabsBasic = 3} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 3 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {(todos.surveysForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Abstimmungen ({todos.surveysForFeedback?.length ?? 0})</span>
              <span class="md:hidden">📊 ({todos.surveysForFeedback?.length ?? 0})</span>
            </button>

            <button onclick={() => tabsBasic = 4} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 4 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {pendingAvailabilityGigs.length > 0 ? 'font-bold' : ''}">
              <span class="hidden md:inline">Gig-Rückmeldungen ({pendingAvailabilityGigs.length})</span>
              <span class="md:hidden">👥 ({pendingAvailabilityGigs.length})</span>
            </button>

            <button onclick={() => tabsBasic = 5} class="ui-tab transition-colors whitespace-nowrap {tabsBasic === 5 ? 'ui-tab-active' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}">
              <span class="hidden md:inline">Erledigt ({todos.doneTodos.length})</span>
              <span class="md:hidden">✓ ({todos.doneTodos.length})</span>
            </button>
          </div>

          <div class="mt-4">
            {#if tabsBasic === 0}
              <div class="hidden md:block">
                <table class="ui-table mb-6 bg-surface-1 text-on-surface">
                  <thead class="text-on-surface">
                    <tr>
                      <th class="font-semibold py-2 px-3 border-b">Interpret</th>
                      <th class="font-semibold py-2 px-3 border-b">Titel</th>
                      <th class="font-semibold py-2 px-3 border-b">Todo</th>
                      <th class="font-semibold py-2 px-3 border-b">Done</th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each todos.notDoneTodos as td (td.id)}
                      <tr class="transition">
                        <td class="px-3 py-2">{td.song_interpret}</td>
                        <td class="px-3 py-2">{td.song_title}</td>
                        <td class="px-3 py-2">{td.todo}</td>
                        <td class="px-3 py-2">
                          <button
                            class="ui-btn ui-btn-primary px-3 py-0 text-base"
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
                  <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
                    <h5 class="font-bold mb-1 text-primary-900">{td.song_interpret} - {td.song_title}</h5>
                    <p class="mb-2 text-on-surface-variant">{td.todo}</p>
                    <button
                      class="ui-btn variant-filled-success w-full py-2"
                      onclick={() => markTodoAsDone(td)}
                    >✓</button>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 1}
              <!-- Gig-Checklisten-Todos -->
              {#if (todos.gigChecklistTodos?.length ?? 0) === 0}
                <p class="text-sm text-on-surface-variant italic">Keine offenen Checklisten-Aufgaben.</p>
              {:else}
                <div class="hidden md:block">
                  <table class="ui-table mb-6 bg-surface-1 text-on-surface">
                    <thead class="text-on-surface">
                      <tr>
                        <th class="font-semibold py-2 px-3 border-b">Gig</th>
                        <th class="font-semibold py-2 px-3 border-b">Datum</th>
                        <th class="font-semibold py-2 px-3 border-b">Aufgabe</th>
                        <th class="font-semibold py-2 px-3 border-b">Kategorie</th>
                        <th class="font-semibold py-2 px-3 border-b">Fälligkeit</th>
                        <th class="font-semibold py-2 px-3 border-b">Done</th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each todos.gigChecklistTodos as item (item.id)}
                        <tr class="transition cursor-pointer hover:bg-surface-100 dark:hover:bg-surface-800"
                            onclick={() => openChecklistItemModal(item)}>
                          <td class="px-3 py-2 font-medium">{item.gig_name}</td>
                          <td class="px-3 py-2 whitespace-nowrap">{item.gig_datum ? new Date(item.gig_datum).toLocaleDateString('de-DE') : '-'}</td>
                          <td class="px-3 py-2">{item.title}</td>
                          <td class="px-3 py-2 text-on-surface-variant">{item.category ?? '-'}</td>
                          <td class="px-3 py-2 whitespace-nowrap {item.due_datetime && new Date(item.due_datetime) < new Date() ? 'text-error-600 font-semibold' : 'text-on-surface-variant'}">
                            {item.due_datetime ? new Date(item.due_datetime).toLocaleDateString('de-DE') : '-'}
                          </td>
                          <td class="px-3 py-2" onclick={(e) => e.stopPropagation()}>
                            <button
                              class="ui-btn ui-btn-primary px-3 py-0 text-base"
                              onclick={() => markChecklistItemDone(item)}
                            >✓</button>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>
                <div class="block md:hidden mt-5">
                  {#each todos.gigChecklistTodos as item (item.id)}
                    <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
                      <button class="w-full text-left mb-1" onclick={() => openChecklistItemModal(item)}>
                        <h5 class="font-bold text-primary-900">{item.gig_name}</h5>
                        <p class="font-medium">{item.title}</p>
                        {#if item.category}
                          <p class="text-sm text-on-surface-variant">{item.category}</p>
                        {/if}
                        {#if item.due_datetime}
                          <p class="text-sm mb-1 {new Date(item.due_datetime) < new Date() ? 'text-error-600 font-semibold' : 'text-on-surface-variant'}">
                            Fällig: {new Date(item.due_datetime).toLocaleDateString('de-DE')}
                          </p>
                        {/if}
                      </button>
                      <button
                        class="ui-btn variant-filled-success w-full py-2"
                        onclick={() => markChecklistItemDone(item)}
                      >✓ Erledigt</button>
                    </div>
                  {/each}
                </div>
              {/if}
            {:else if tabsBasic === 2}
              <div class="hidden md:block">
                <table class="ui-table mb-1 bg-surface-1 text-on-surface">
                  <thead class="text-on-surface">
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
                  <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
                    <h5 class="font-bold mb-1">{s.interpret} - {s.title}</h5>
                    <p class="mb-2">Mein Feedback</p>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 3}
              <div class="hidden md:block">
                <table class="ui-table mb-1 bg-surface-1 text-on-surface">
                  <thead class="text-on-surface">
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
                  <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
                    <h5 class="font-bold mb-1">{sf.rf_survey}</h5>
                    <p class="mb-2">Mein Feedback</p>
                  </div>
                {/each}
              </div>
            {:else if tabsBasic === 4}
              <!-- Gig-Rückmeldungen ausstehend -->
              {#if pendingAvailabilityGigs.length === 0}
                <p class="text-sm text-on-surface-variant italic">Alle Gigs haben eine Rückmeldung von dir.</p>
              {:else}
                <div class="hidden md:block">
                  <table class="ui-table mb-6 bg-surface-1 text-on-surface">
                    <thead class="text-on-surface">
                      <tr>
                        <th class="font-semibold py-2 px-3 border-b">Datum</th>
                        <th class="font-semibold py-2 px-3 border-b">Name</th>
                        <th class="font-semibold py-2 px-3 border-b">Art</th>
                        <th class="font-semibold py-2 px-3 border-b"></th>
                      </tr>
                    </thead>
                    <tbody>
                      {#each pendingAvailabilityGigs as g (g.id)}
                        <tr class="transition">
                          <td class="px-3 py-2 whitespace-nowrap">{g.datum ? new Date(g.datum).toLocaleDateString('de-DE') : '-'}</td>
                          <td class="px-3 py-2 font-medium">{g.name}</td>
                          <td class="px-3 py-2 text-on-surface-variant">{g.kind_of_gig ?? '-'}</td>
                          <td class="px-3 py-2">
                            <a class="ui-btn ui-btn-primary px-3 py-1 text-sm" href="/gigs">Rückmelden</a>
                          </td>
                        </tr>
                      {/each}
                    </tbody>
                  </table>
                </div>

                <div class="block md:hidden mt-5">
                  {#each pendingAvailabilityGigs as g (g.id)}
                    <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
                      <h5 class="font-bold mb-1 text-primary-900">
                        {g.datum ? new Date(g.datum).toLocaleDateString('de-DE', { weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric' }) : '-'}
                      </h5>
                      <p class="mb-1 font-medium">{g.name}</p>
                      {#if g.kind_of_gig}
                        <p class="text-sm text-on-surface-variant mb-2">{g.kind_of_gig}</p>
                      {/if}
                      <a class="ui-btn ui-btn-primary w-full py-2 text-center block" href="/gigs">Rückmelden</a>
                    </div>
                  {/each}
                </div>
              {/if}
            {:else if tabsBasic === 5}
              <div class="hidden md:block">
                <table class="ui-table mb-1 bg-surface-1 text-on-surface">
                  <thead class="text-on-surface">
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
                  <div class="ui-card-muted p-4 mb-4 border border-outline-variant text-on-surface shadow">
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
          <div class="ui-card-muted p-4">
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
              <a class="ui-btn ui-btn-ghost" href="/proben">Zu Proben</a>
            </div>
          </div>

          <div class="ui-card-muted p-4">
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
              <a class="ui-btn ui-btn-ghost" href="/gigs">Zu Gigs</a>
            </div>
          </div>
        </div>
      </div>

      <hr class="my-7 border-outline-variant">

      <div>
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-xl font-semibold text-on-surface">Saison {new Date().getFullYear()}</h2>
          <button class="ui-btn ui-btn-ghost md:hidden" onclick={() => showSeasonStats = !showSeasonStats}>
            {showSeasonStats ? 'Weniger anzeigen' : 'Mehr anzeigen'}
          </button>
        </div>

        {#if seasonStats}
          <div class="grid grid-cols-1 md:grid-cols-2 gap-2 md:gap-3 mt-4 {showSeasonStats ? '' : 'hidden md:grid'}">
            <div class="ui-card-muted p-3 md:p-4 min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonGigProgressPlot
                playedGigCount={seasonStats.played_gig_count}
                gigCount={seasonStats.gig_count}
                titlePrefix="Gigs gespielt"
              />
            </div>

            <div class="ui-card-muted p-3 md:p-4 min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonSongMixPlot
                totalSongs={seasonStats.played_songs}
                uniqueSongs={seasonStats.unique_songs}
                titlePrefix="Gespielte Songs"
              />
            </div>

            <div class="ui-card-muted p-3 md:p-4 min-h-[240px] md:min-h-[260px] overflow-hidden">
              <SeasonFeedbackGaugePlot
                feedbackAvg={seasonStats.feedback_avg}
                feedbackCount={seasonStats.feedback_count}
                titlePrefix="Feedback-Durchschnitt"
              />
            </div>

            <div class="ui-card-muted p-3 md:p-4 min-h-[280px] md:min-h-[300px] overflow-hidden">
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
          <div class="ui-card-muted p-4 border border-primary-200">
            <h3 class="text-lg font-semibold text-surface-900 dark:text-surface-50 mb-2">Kalender-Abo</h3>
            <p class="text-sm text-primary-700 dark:text-primary-50 mb-3">
              Abonniere den Bandkalender, um alle Proben und Gigs in deiner Kalender-App zu sehen.
            </p>

            <p class="text-xs text-primary-700 dark:text-surface-50 mt-2">
                <a
                    href={`${calendarUrl}${calUrls.open}`}
                    class="inline-flex items-center justify-between rounded-lg border border-primary-300 bg-primary-50 px-3 py-1 text-sm font-semibold text-primary-900 hover:bg-primary-100 focus:outline-none focus:ring-2 focus:ring-primary-400"
                > Öffentlicher Kalender (für jeden)</a>
            </p>
            <p class="text-xs text-primary-700 dark:text-surface-50 mt-2">
                <a
                    href={`${calendarUrl}${calUrls.internal}`}
                    class="inline-flex items-center justify-between rounded-lg border border-primary-300 bg-primary-50 px-3 py-1 text-sm font-semibold text-primary-900 hover:bg-primary-100 focus:outline-none focus:ring-2 focus:ring-primary-400"
                > Interner Kalender (für dich und eventuell Lebensgefährten)</a>
            </p>
          </div>

          <div class="ui-card-muted p-4 border border-outline-variant">
            <h3 class="text-lg font-semibold text-on-surface mb-2">Dashboard-Hilfe</h3>
            <p class="text-sm text-on-surface-variant mb-3">
              Hier findest du eine kurze Erklärung zu Todos, Feedback und Aktionen.
            </p>
            <button class="ui-btn ui-btn-ghost" onclick={() => showHelp = !showHelp}>
              {showHelp ? 'Anleitung ausblenden' : 'Anleitung anzeigen'}
            </button>
          </div>
        </div>

        <div class="mt-6">
          <h2 class="text-xl font-semibold my-2 text-on-surface">Daten-Export</h2>
          <div class="ui-card-muted p-4 border border-secondary-200 flex flex-col md:flex-row md:items-center gap-4">
            <div class="flex-1">
              <h3 class="text-lg font-semibold text-on-surface mb-1">Alle Setlisten exportieren</h3>
              <p class="text-sm text-on-surface-variant">
                Exportiert alle Gig-Setlisten der Datenbank als JSON-Datei (inkl. Sets, Songs und Timing).
              </p>
            </div>
            <button
              class="ui-btn ui-btn-secondary shrink-0"
              onclick={downloadAllSetlists}
              disabled={exportingSetlists}
            >
              {#if exportingSetlists}
                <span class="animate-spin mr-2">⏳</span> Exportiere…
              {:else}
                ⬇ Setlisten herunterladen
              {/if}
            </button>
          </div>
        </div>

        {#if showHelp}
          <div class="ui-card-muted mt-4 p-4 md:p-6 dashboard-help-panel">
            <h3 class="h4 font-bold mb-4">Anleitung: Dashboard</h3>

            <div class="space-y-4">
              <div>
                <h4 class="font-semibold text-primary-500 mb-2">Uebersicht</h4>
                <p class="text-sm">Das Dashboard ist deine zentrale Anlaufstelle fuer offene Aufgaben und Feedback-Anfragen.</p>
              </div>

              <div>
                <h4 class="font-semibold text-secondary-500 mb-2">Die sechs Bereiche</h4>
                <ul class="list-disc list-inside space-y-1 text-sm">
                  <li><strong>Offene Todos:</strong> Deine persoenlichen Aufgaben fuer Songs.</li>
                  <li><strong>Checkliste:</strong> Offene Gig-Checklisten-Aufgaben, die dir zugewiesen sind.</li>
                  <li><strong>Songs:</strong> Songs, die auf dein Feedback warten.</li>
                  <li><strong>Abstimmungen:</strong> Umfragen, an denen du noch nicht teilgenommen hast.</li>
                  <li><strong>Gig-Rückmeldungen:</strong> Bevorstehende Gigs, für die du noch keine Verfügbarkeit gemeldet hast.</li>
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

<style>
  .dashboard-main-card {
    background:
      radial-gradient(920px 220px at 6% -25%, color-mix(in oklab, var(--color-primary-500) 14%, transparent), transparent 68%),
      linear-gradient(180deg,
        color-mix(in oklab, var(--color-surface-50) 95%, transparent) 0%,
        color-mix(in oklab, var(--color-surface-100) 92%, transparent) 100%);
  }

  :global(.dark) .dashboard-main-card {
    background:
      radial-gradient(920px 220px at 6% -25%, color-mix(in oklab, var(--color-primary-500) 24%, transparent), transparent 70%),
      linear-gradient(180deg,
        color-mix(in oklab, var(--color-surface-800) 86%, transparent) 0%,
        color-mix(in oklab, var(--color-surface-900) 92%, transparent) 100%);
  }

  .dashboard-success-panel {
    background:
      linear-gradient(145deg,
        color-mix(in oklab, var(--color-success-100) 96%, transparent),
        color-mix(in oklab, var(--color-success-200) 84%, transparent));
  }

  :global(.dark) .dashboard-success-panel {
    background:
      linear-gradient(145deg,
        color-mix(in oklab, var(--color-success-900) 64%, var(--color-surface-900)),
        color-mix(in oklab, var(--color-success-700) 44%, var(--color-surface-950)));
  }

  .dashboard-help-panel {
    background:
      linear-gradient(150deg,
        color-mix(in oklab, var(--color-tertiary-100) 44%, transparent),
        color-mix(in oklab, var(--color-surface-100) 88%, transparent));
  }

  :global(.dark) .dashboard-help-panel {
    background:
      linear-gradient(150deg,
        color-mix(in oklab, var(--color-tertiary-700) 32%, var(--color-surface-900)),
        color-mix(in oklab, var(--color-surface-900) 92%, transparent));
  }
</style>

