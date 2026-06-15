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
  import { getRehearsalList,
           getSongs, getUserList,
           updateRehearsals,
           createNewRehearsal,
           deleteRehearsal,
           getUser } from '$lib/api.js';

  import { createMessageHelpers } from '$lib/Messages.svelte';
  const { showError, showSuccess, showWarning } = createMessageHelpers();

  import NewRehearsalForm from './NewRehearsalForm.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import RehearsalCard from './RehearsalCard.svelte';
  import { modalState } from '$lib/modalState.js';

  import { onMount, tick } from 'svelte';
  

  let rehearsals = $state([]);
  let songs = $state([]);
  let users = $state([]);
  let user = $state({ user_name: null, user_group: null });
  let songsForSearch = $state([]);

  let error = $state('');
  let showHelp = $state(false);
  let tabSet = $state(0);
  let expandedRehId = $state(null);
  let expandedSongId = $state(null);
  let isUpdating = $state(false);

  let isEditor = $derived(user && (user.user_group === 'admin' || user.user_group === 'editor'));

  let now = $derived(new Date());

  function endOfNextDay(dateStr) {
    const d = new Date(dateStr);
    d.setDate(d.getDate() + 1);
    d.setHours(23, 59, 59, 999);
    return d;
  }

  let upcomingRehearsals = $derived(rehearsals
    .filter(r => endOfNextDay(r.begin) >= now)
    .sort((a, b) => new Date(a.begin) - new Date(b.begin)));
  let pastRehearsals = $derived(rehearsals
    .filter(r => endOfNextDay(r.begin) < now)
    .sort((a, b) => new Date(b.begin) - new Date(a.begin)));

  let pastRehearsalsFilter = $state('');
  let filteredPastRehearsals = $derived(pastRehearsals.filter(reh => {
    if (!pastRehearsalsFilter.trim()) return true;
    const q = pastRehearsalsFilter.toLowerCase();
    const dateStr = new Date(reh.begin).toLocaleDateString('de-DE', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).toLowerCase();
    const commentMatch = reh.comment?.toLowerCase().includes(q);
    const songMatch = reh.songs?.some(s =>
      s.title?.toLowerCase().includes(q) ||
      s.interpret?.toLowerCase().includes(q)
    );
    return dateStr.includes(q) || commentMatch || songMatch;
  }));


  function buildSongsForSearch() {
    return songs.map(song => ({
      label: `${song.interpret} - ${song.title}`,
      value: song.id
    }));
  }

  onMount(async () => {
    try {
      user = await getUser();
    } catch(e) {
      user = { user_name: null, user_group: null };
      error = 'User/Gigs konnten nicht geladen werden';
      console.error('Proben load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }

    try {
      rehearsals = await getRehearsalList();
      songs = await getSongs();
      songsForSearch = buildSongsForSearch();
      users = await getUserList();
    } catch(e) {
      error = 'Probenliste konnte nicht geladen werden';
      console.error('Probenliste load error:', e);
      // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
  });

  function toggleExpand(id) {
    expandedRehId = expandedRehId !== id ? id : null;
  }

  async function updateRehearsal(data, expSId = null) {
    if (isUpdating) return;
    isUpdating = true;

    const savedRehId = data.id;
    const savedSongId = expSId;

    try {
      const updatedRehearsals = await updateRehearsals(null, data);

      // Update only the changed rehearsal to preserve local state
      const index = rehearsals.findIndex(r => r.id === data.id);
      if (index !== -1) {
        const updatedReh = updatedRehearsals.find(r => r.id === data.id);
        if (updatedReh) {
          rehearsals[index] = updatedReh;
          rehearsals = [...rehearsals];
        }
      } else {
        rehearsals = updatedRehearsals;
      }

      await tick();
      expandedRehId = savedRehId;
      expandedSongId = savedSongId;
    } finally {
      isUpdating = false;
    }
  }

  async function addRehearsal(data) {
    rehearsals = await createNewRehearsal(null, data);
  }

  async function delRehearsal(rehId, rehDate) {
    modalState.trigger({
      component: ConfirmModal,
      meta: {
        title: 'Probe löschen',
        message: `Möchten Sie die Probe vom ${rehDate} wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`,
        confirmText: 'Löschen',
        cancelText: 'Abbrechen',
        confirmButtonClass: 'btn variant-filled-error',
        cancelButtonClass: 'btn variant-outline-secondary'
      },
      response: async (confirmed) => {
        if (confirmed) {
          try {
            rehearsals = await deleteRehearsal(null, rehId);
            expandedRehId = null;
            showSuccess('Probe erfolgreich gelöscht');
          } catch (e) {
            showError('Fehler beim Löschen der Probe');
            console.error('Fehler beim Löschen der Probe:', e);
          }
        }
      }
    });
  }

  function openNewRehearsalModal() {
    modalState.trigger({
      component: NewRehearsalForm,
      title: 'Neue Probe erstellen',
      body: 'Startzeit wählen, optional Endzeit ergänzen und speichern.',
      response: (r) => r && addRehearsal(r)
    });
  }

  function handleCardUpdate(e) {
    updateRehearsal(e.reh, e.songId);
  }

  function handleCardDelete(e) {
    delRehearsal(e.id, e.date);
  }

  function handleCardSongToggle(e) {
    expandedSongId = expandedSongId !== e.id ? e.id : null;
  }
</script>

<div class="container mx-auto py-8 md:px-4 max-w-5xl">
  <div class="card bg-surface-2 rounded-lg shadow-lg md:border p-2 md:p-6">
    <div class="flex flex-col gap-6">
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center gap-3">
          <h2 class="h2 text-on-surface">Proben</h2>
          {#if isEditor}
            <button
              class="btn-icon variant-filled-primary w-8 h-4 rounded-full text-xl leading-none"
              onclick={openNewRehearsalModal}
              title="Neue Probe erstellen"
            >+</button>
          {/if}
        </div>
        <button
          class="btn variant-ghost-surface btn-sm"
          onclick={() => showHelp = !showHelp}
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
          <h3 class="h4 font-bold mb-4">🎸 Anleitung: Proben-Verwaltung</h3>

          <div class="space-y-4">
            <!-- Grundfunktionen -->
            <div>
              <h4 class="font-semibold text-primary-500 mb-2">📋 Hauptfunktionen</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li><strong>Neue Probe hinzufügen:</strong> Klicke auf "Neue Probe hinzufügen" und wähle Startzeit, optional auch die Endzeit</li>
                <li><strong>Probe aufklappen:</strong> Klicke auf eine Probe, um Details zu sehen</li>
                <li><strong>Song hinzufügen:</strong> Wähle einen Song aus und gib optional ein Todo an</li>
                <li><strong>Song-Details ansehen:</strong> Klicke auf einen Song in der Probe für Details</li>
              </ul>
            </div>

            <!-- Songs verwalten -->
            <div>
              <h4 class="font-semibold text-secondary-500 mb-2">🎵 Songs in Proben</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li><strong>Status ändern:</strong> Im Song-Detail kannst du den Status ändern (vorschlag, angenommen, proben, spielbar, retired)</li>
                <li><strong>Song als erledigt markieren:</strong> Klicke auf "erledigt" um den Song abzuhaken ✔</li>
                <li><strong>Kommentare hinzufügen:</strong> Nutze "Proben Kommentar" für Notizen zur Probe und "Setlist Kommentar" für die Setliste</li>
                <li><strong>Song entfernen:</strong> Klicke auf "✖" um den Song aus der Probe zu entfernen</li>
              </ul>
            </div>

            <!-- Vergangene Proben -->
            <div>
              <h4 class="font-semibold text-warning-500 mb-2">🕐 Vergangene Proben</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li>Vergangene Proben werden als <strong>Protokoll</strong> (read-only) angezeigt – keine Bearbeitung möglich</li>
                <li>Das Protokoll zeigt Probenkommentar, alle Songs mit Status, Todos und Kommentaren</li>
                <li><strong>Suche (außen):</strong> Filtere alle vergangenen Proben nach Datum, Song-Titel, Interpret oder Kommentar</li>
                <li><strong>Suche (innen):</strong> Innerhalb einer aufgeklappten Probe kannst du die Songs direkt durchsuchen</li>
              </ul>
            </div>

            <!-- Todos -->
            <div>
              <h4 class="font-semibold text-tertiary-500 mb-2">✅ Todos verwalten</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li><strong>Allgemeines Todo:</strong> Gib ein Todo beim Hinzufügen eines Songs an</li>
                <li><strong>Persönliche Todos:</strong> Weise im Song-Detail spezifische Todos einzelnen Bandmitgliedern zu</li>
                <li><strong>Todo-Status:</strong> ⏳ = offen, ✔ = erledigt</li>
                <li><strong>Dashboard:</strong> Alle offenen Todos erscheinen auf deinem Dashboard</li>
              </ul>
            </div>

            <!-- Probe löschen -->
            <div>
              <h4 class="font-semibold text-warning-500 mb-2">🗑️ Probe löschen</h4>
              <p class="text-sm">Nur Editoren/Admins können Proben löschen. Klicke auf "🗑️ Probe löschen" im Detail-Bereich.</p>
            </div>

            <!-- Tipps -->
            <div class="alert variant-soft-primary">
              <div class="alert-message">
                <h4 class="font-semibold mb-1">💡 Tipp</h4>
                <p class="text-sm">Nutze das Suchfeld, um schnell Songs zu finden. Der Status-Wechsel wird automatisch gespeichert!</p>
              </div>
            </div>
          </div>
        </div>
      {/if}


      {#if rehearsals.length > 0}
        <div class="flex border-b border-surface-300 dark:border-surface-600 mb-4 gap-1">
          <button onclick={() => tabSet = 0} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 0 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {upcomingRehearsals.length > 0 ? 'font-bold' : ''}">
            <span class="hidden md:inline">Aktuelle Proben ({upcomingRehearsals.length})</span>
            <span class="md:hidden">📅 ({upcomingRehearsals.length})</span>
          </button>
          <button onclick={() => tabSet = 1} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 1 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}">
            <span class="hidden md:inline">Vergangene Proben ({pastRehearsals.length})</span>
            <span class="md:hidden">🕐 ({pastRehearsals.length})</span>
          </button>
        </div>

        <div class="mt-4">
          {#if tabSet === 0}
            {#if upcomingRehearsals.length === 0}
              <div class="rounded-xl bg-success-100 text-success-900 p-4 mt-6 shadow text-center">
                Keine bevorstehenden Proben geplant.
              </div>
            {:else}
              <div class="mt-4">
                {#each upcomingRehearsals as reh (reh.id)}
                  <RehearsalCard
                    {reh}
                    {songs}
                    {songsForSearch}
                    {users}
                    {isEditor}
                    expanded={expandedRehId === reh.id}
                    {expandedSongId}
                    ontoggle={() => toggleExpand(reh.id)}
                    onupdate={handleCardUpdate}
                    ondelete={handleCardDelete}
                    onsongtoggle={handleCardSongToggle}
                    onerror={(e) => showError(e.message)}
                    onwarning={(e) => showWarning(e.message)}
                    onsuccess={(e) => showSuccess(e.message)}
                  />
                {/each}
              </div>
            {/if}
          {:else}
            {#if pastRehearsals.length === 0}
              <div class="rounded-xl bg-surface-100 text-surface-900 p-4 mt-6 shadow text-center">
                Keine vergangenen Proben vorhanden.
              </div>
            {:else}
              <!-- Suchfeld -->
              <div class="mt-4 mb-3">
                <div class="flex items-center gap-2 border border-outline-variant rounded-lg px-3 py-2 bg-surface-1">
                  <svg class="w-5 h-5 text-on-surface-variant" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                  </svg>
                  <input
                    type="search"
                    bind:value={pastRehearsalsFilter}
                    placeholder="Suche nach Datum, Song oder Kommentar..."
                    class="input border-none bg-transparent flex-1 p-0 focus:ring-0"
                  />
                </div>
                {#if pastRehearsalsFilter && filteredPastRehearsals.length !== pastRehearsals.length}
                  <p class="text-sm text-on-surface-variant mt-2">
                    {filteredPastRehearsals.length} von {pastRehearsals.length} Probe{pastRehearsals.length !== 1 ? 'n' : ''}
                  </p>
                {/if}
              </div>

              {#if filteredPastRehearsals.length === 0}
                <p class="text-on-surface-variant italic mt-4">Keine Proben gefunden.</p>
              {:else}
                <div class="mt-2">
                  {#each filteredPastRehearsals as reh (reh.id)}
                    <RehearsalCard
                      {reh}
                      {songs}
                      {songsForSearch}
                      {users}
                      {isEditor}
                      isPast={true}
                      searchQuery={pastRehearsalsFilter}
                      expanded={expandedRehId === reh.id}
                      {expandedSongId}
                      ontoggle={() => toggleExpand(reh.id)}
                      onupdate={handleCardUpdate}
                      ondelete={handleCardDelete}
                      onsongtoggle={handleCardSongToggle}
                      onerror={(e) => showError(e.message)}
                      onwarning={(e) => showWarning(e.message)}
                      onsuccess={(e) => showSuccess(e.message)}
                    />
                  {/each}
                </div>
              {/if}
            {/if}
          {/if}
        </div>
      {/if}


    </div>
  </div>
</div>


