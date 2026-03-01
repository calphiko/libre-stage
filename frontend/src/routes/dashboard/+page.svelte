// libre-stage - Band rehearsal and gig management software
// Copyright (C) 2026  libre-stage contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

<script>
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { getUser, getUserTodos, updateUserTodo, logout as apiLogout } from '$lib/api.js';
  import { TabGroup, Tab, TabAnchor, Paginator } from '@skeletonlabs/skeleton';

  import { getToastStore } from '@skeletonlabs/skeleton';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  const { showError, showSuccess, showWarning } = createMessageHelpers(getToastStore());

  //components
  import RoleTable from '$lib/components/RoleTable.svelte';

  let user = null;
  let error = '';
  let showHelp = false;
  let todos = {
      notDoneTodos: [],
      doneTodos: []
  };

  let calendarUrl = '';

  let tabsBasic = 0;

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
    <div class="flex items-center justify-between mb-4">
      <h2 class="h2 text-on-surface">Dashboard</h2>
      <button
        class="btn variant-ghost-surface btn-sm"
        on:click={() => showHelp = !showHelp}
        aria-label="Hilfe anzeigen"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <span class="hidden md:inline ml-2">Hilfe</span>
      </button>
    </div>

    {#if showHelp}
      <div class="card variant-ghost-surface mt-4 mb-6 p-4 md:p-6">
        <h3 class="h4 font-bold mb-4">📊 Anleitung: Dashboard</h3>

        <div class="space-y-4">
          <!-- Übersicht -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-2">🏠 Übersicht</h4>
            <p class="text-sm">Das Dashboard ist deine zentrale Anlaufstelle für alle offenen Aufgaben und Feedback-Anfragen.</p>
          </div>

          <!-- Tabs -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-2">📑 Die vier Bereiche</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Offene Todos:</strong> Deine persönlichen Aufgaben für Songs (z.B. "Text lernen", "Solo üben")</li>
              <li><strong>Songs:</strong> Songs, die auf dein Feedback warten (Bewertung mit 👍/👎/🤷)</li>
              <li><strong>Abstimmungen:</strong> Umfragen, an denen du noch nicht teilgenommen hast</li>
              <li><strong>Erledigt:</strong> Alle abgeschlossenen Todos zur Übersicht</li>
            </ul>
          </div>

          <!-- Aktionen -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-2">✅ Aktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Todo abhaken:</strong> Klicke auf "✓" um ein Todo als erledigt zu markieren</li>
              <li><strong>Song bewerten:</strong> Wähle 👍 (Ja), 👎 (Nein) oder 🤷 (Vielleicht) für jeden Song</li>
              <li><strong>Abstimmen:</strong> Klicke auf eine Umfrage, um deine Stimme abzugeben</li>
            </ul>
          </div>

          <!-- Kalender -->
          <div>
            <h4 class="font-semibold text-success-500 mb-2">📅 Kalender-Abonnement</h4>
            <p class="text-sm">
              Unten findest du einen Button zum Abonnieren des Bandkalenders.
              Damit werden alle Auftritte und Proben automatisch in deinen Kalender (Google, Apple, Outlook) importiert.
            </p>
          </div>
        </div>
      </div>
    {/if}

    {#if user}
      <p class="text-lg text-on-surface">
        Willkommen, <span class="font-semibold">{user.user_name}</span>!
      </p>
      <div class="my-3">
        <span class="inline-block px-3 py-1 rounded bg-primary-100 text-primary-900 text-sm">
           {user.user_group}
        </span>
      </div>

      <div class="mt-7">
        <h2 class="text-xl font-semibold mb-2 text-on-surface">Deine Todos!</h2>
        <div class="">
            {#if (todos.songsForFeedback?.length ?? 0) == 0 && (todos.surveysForFeedback?.length ?? 0) == 0 && todos.notDoneTodos.length == 0}
              <div class="rounded-xl bg-success-100 text-success-900 p-4 mt-6 shadow text-center">
                Du hast keine offenen Todos! 🎉
              </div>
            {:else}
            <!-- Desktop-Tabelle -->

                <TabGroup>
                    <Tab bind:group={tabsBasic} name="offen" value={0} class={todos.notDoneTodos.length > 0 ? 'font-bold' : ''}>
                        <span class="hidden md:inline">Offene Todos ({todos.notDoneTodos.length})</span>
                        <span class="md:hidden">Offen ({todos.notDoneTodos.length})</span>
                    </Tab>

                    <Tab bind:group={tabsBasic} name="songsForFeedback" value={1} class={(todos.songsForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}>
                        <span class="hidden md:inline">Songs ({todos.songsForFeedback?.length ?? 0})</span>
                        <span class="md:hidden">🎵 ({todos.songsForFeedback?.length ?? 0})</span>
                    </Tab>

                    <Tab bind:group={tabsBasic} name="surveysForFeedback" value={2} class={(todos.surveysForFeedback?.length ?? 0) > 0 ? 'font-bold' : ''}>
                        <span class="hidden md:inline">Abstimmungen ({todos.surveysForFeedback?.length ?? 0})</span>
                        <span class="md:hidden">📊 ({todos.surveysForFeedback?.length ?? 0})</span>
                    </Tab>

                    <Tab bind:group={tabsBasic} name="done" value={3}>
                        <span class="hidden md:inline">Erledigt ({todos.doneTodos.length})</span>
                        <span class="md:hidden">✓ ({todos.doneTodos.length})</span>
                    </Tab>

                    <svelte:fragment slot="panel">
                        {#if tabsBasic === 0}
                            <!-- Desktop Ansicht offene Todos -->
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
                                                        on:click={() => markTodoAsDone(td)}
                                                    >✓</button>
                                                </td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>

                            </div>
                            <!-- Mobile Card-Ansicht offene Todos -->

                            <div class="block md:hidden mt-5">

                                {#each todos.notDoneTodos as td (td.id)}
                                    <div class="bg-secondary-200 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                                        <h5 class="font-bold mb-1 text-primary-900">{td.song_interpret} - {td.song_title}</h5>
                                        <p class="mb-2 text-on-surface-variant">{td.todo}</p>
                                        <button
                                            class="btn variant-filled-success w-full rounded-lg py-2 font-semibold"
                                            on:click={() => markTodoAsDone(td)}
                                        >✓</button>
                                    </div>
                                {/each}
                            </div>

                        {:else if tabsBasic === 1}
                            <!-- Desktop Ansicht Songs for Feedback -->
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
                                                <td class="px-3 py-2 ">Mein Feedback</td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            </div>
                            <!-- Mobile Card-Ansicht Songs For Feedback -->
                            <div class="block md:hidden mt-5">
                                {#each todos.songsForFeedback as s (s.id)}
                                    <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                                        <h5 class="font-bold mb-1">{s.interpret} - {s.title}</h5>
                                        <p class="mb-2">Mein Feedback</p>
                                    </div>
                                {/each}
                            </div>
                        {:else if tabsBasic === 2}
                            <!-- Desktop Ansicht Surveys For Feedback -->
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
                            <!-- Mobile Card-Ansicht Surveys for Feedback -->
                            <div class="block md:hidden mt-5">
                                {#each todos.surveysForFeedback as sf (sf.id)}
                                    <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                                        <h5 class="font-bold mb-1">{sf.rf_survey}</h5>
                                        <p class="mb-2">Mein Feedback</p>
                                    </div>
                                {/each}
                            </div>
                        {:else if tabsBasic === 3}
                            <!-- Desktop Ansicht erledigte Todos -->
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
                            <!-- Mobile Card-Ansicht erledigte Todos -->
                            <div class="block md:hidden mt-5">
                                {#each todos.doneTodos as td (td.id)}
                                    <div class="bg-success-100 rounded-xl p-4 mb-4 border border-success-300 text-success-900 shadow">
                                        <h5 class="font-bold mb-1">{td.song_interpret} - {td.song_title}</h5>
                                        <p class="mb-2">{td.todo}</p>
                                    </div>
                                {/each}
                            </div>
                        {/if}
                    </svelte:fragment>
                </TabGroup>

            {/if}

           <h2 class="text-xl font-semibold my-2 text-on-surface">Kalender-Abo</h2>
           <div class="mt-6 p-4 rounded-xl border border-primary-200">
              <h3 class="text-lg font-semibold text-surface-900 dark:text-surface-50 mb-2">📅 Kalender-Abo</h3>
              <p class="text-sm text-primary-700 dark:text-primary-50 mb-3">
                Abonniere den Bandkalender, um alle Proben und Gigs in deiner Kalender-App zu sehen.
              </p><div class="flex gap-2">
                <input
                  type="text"
                  readonly
                  value={calendarUrl}
                  class="input flex-1 bg-white text-sm"
                />
                <button
                  class="btn variant-filled-primary"
                  on:click={() => navigator.clipboard.writeText(calendarUrl)}
                >
                  Kopieren
                </button>
              </div>
              <p class="text-xs text-primary-700 dark:text-surface-50 mt-2">
                Füge diese URL als Kalender-Abo in deiner Kalender-App hinzu.
              </p>
            </div>
        </div>
      </div>

      <hr class="my-7 border-outline-variant">

      <div class="mt-6">
        <h2 class="text-xl font-semibold text-on-surface mb-2">Fehlende Features!</h2>
        <ul class="list-disc ml-5 text-on-surface-variant">
          <li>Statistische Auswertungen</li>
          <li>User Markierung für zu probende Songs</li>
        </ul>
      </div>

      <hr class="my-7 border-outline-variant">

      <div class="mt-6">
        <h2 class="text-xl font-semibold text-on-surface mb-2">Bekannte Bugs!</h2>
        <ul class="list-disc ml-5 text-on-surface-variant">
        </ul>
      </div>
      <hr class="my-7 border-outline-variant">
      <h2 class ="text-xl font-semibold text-on-surface mb-2">Rollenberechtigungen</h2>
      <RoleTable/>

    {:else if error}
      <div class="rounded-xl bg-error-100 text-error-900 p-4 mt-6 shadow text-center">{error}</div>
    {:else}
      <div class="text-on-surface-variant text-center my-8">Lade Dashboard...</div>
    {/if}
  </div>
</div>
