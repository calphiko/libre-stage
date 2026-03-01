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
  import { getRehearsalList,
           getSongs, getUserList,
           updateRehearsals,
           createNewRehearsal,
           deleteRehearsal,
           getUser } from '$lib/api.js';

  import { getToastStore } from '@skeletonlabs/skeleton';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { popup } from '@skeletonlabs/skeleton';
  import { InfoIcon } from 'lucide-svelte';
  const { showError, showSuccess, showWarning } = createMessageHelpers(getToastStore());

  import NewRehearsalForm from './NewRehearsalForm.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import RehearsalCard from './RehearsalCard.svelte';

  import { onMount, tick } from 'svelte';
  import { Accordion,
            TabGroup,
            Tab,
            getModalStore
          } from '@skeletonlabs/skeleton';

  const modalStore = getModalStore();

  let rehearsals = [];
  let songs = [];
  let users = [];
  let user = null;
  let songsForSearch = [];

  let error = '';
  let showHelp = false;
  let tabSet = 0;
  let expandedRehId = null;
  let expandedSongId = null;
  let isUpdating = false;

  $: isEditor = user && (user.user_group === 'admin' || user.user_group === 'editor');

  $: now = new Date();
  $: upcomingRehearsals = rehearsals
    .filter(r => new Date(r.begin) >= now)
    .sort((a, b) => new Date(a.begin) - new Date(b.begin));
  $: pastRehearsals = rehearsals
    .filter(r => new Date(r.begin) < now)
    .sort((a, b) => new Date(b.begin) - new Date(a.begin));


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
    modalStore.trigger({
      type: 'component',
      component: { ref: ConfirmModal },
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
    modalStore.trigger({
      type: 'component',
      component: { ref: NewRehearsalForm },
      title: 'Neue Probe erstellen',
      body: 'complete the form below and then press submit!',
      response: (r) => r && addRehearsal(r)
    });
  }

  function handleCardUpdate(e) {
    updateRehearsal(e.detail.reh, e.detail.songId);
  }

  function handleCardDelete(e) {
    delRehearsal(e.detail.id, e.detail.date);
  }

  function handleCardSongToggle(e) {
    expandedSongId = expandedSongId !== e.detail.id ? e.detail.id : null;
  }
</script>

<div class="container mx-auto py-8 md:px-4 max-w-5xl">
  <div class="card bg-surface-2 rounded-lg shadow-lg md:border p-2 md:p-6">
    <div class="flex flex-col gap-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="h2 text-on-surface">Proben</h2>
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
          <h3 class="h4 font-bold mb-4">🎸 Anleitung: Proben-Verwaltung</h3>

          <div class="space-y-4">
            <!-- Grundfunktionen -->
            <div>
              <h4 class="font-semibold text-primary-500 mb-2">📋 Hauptfunktionen</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li><strong>Neue Probe hinzufügen:</strong> Klicke auf "Neue Probe hinzufügen" und wähle Datum/Zeit</li>
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

      <div class="flex flex-col gap-2">
        <div class="inline-flex items-center gap-2">
          <button
            class="btn variant-filled-primary btn-sm w-fit border mt-4 mb-4"
            on:click={openNewRehearsalModal}
          >
            Neue Probe hinzufügen
          </button>
          <span
            class="inline-block align-super cursor-help"
            use:popup={{ event: 'click', target: 'rehearsalInfo', placement: 'top' }}
          >
            <InfoIcon class="w-4 h-4 text-primary-500" />
          </span>
        </div>
        <div class="card p-4 variant-filled-secondary" data-popup="rehearsalInfo">
          <b>Neue Probe erstellen</b>
          <hr>
          <p>Hier kannst du ganz einfach eine neue Probe erstellen</p>
          <div class="arrow variant-filled-secondary" />
        </div>
      </div>

      {#if rehearsals.length > 0}
        <TabGroup>
          <Tab bind:group={tabSet} name="upcoming" value={0} class={upcomingRehearsals.length > 0 ? 'font-bold' : ''}>
            <span class="hidden md:inline">Bevorstehende Proben ({upcomingRehearsals.length})</span>
            <span class="md:hidden">📅 ({upcomingRehearsals.length})</span>
          </Tab>
          <Tab bind:group={tabSet} name="past" value={1}>
            <span class="hidden md:inline">Vergangene Proben ({pastRehearsals.length})</span>
            <span class="md:hidden">🕐 ({pastRehearsals.length})</span>
          </Tab>

          <svelte:fragment slot="panel">
            {#if tabSet === 0}
              {#if upcomingRehearsals.length === 0}
                <div class="rounded-xl bg-success-100 text-success-900 p-4 mt-6 shadow text-center">
                  Keine bevorstehenden Proben geplant. 🎉
                </div>
              {:else}
                <Accordion class="mt-4">
                  {#each upcomingRehearsals as reh (reh.id)}
                    <RehearsalCard
                      {reh}
                      {songs}
                      {songsForSearch}
                      {users}
                      {isEditor}
                      expanded={expandedRehId === reh.id}
                      {expandedSongId}
                      on:toggle={() => toggleExpand(reh.id)}
                      on:update={handleCardUpdate}
                      on:delete={handleCardDelete}
                      on:songtoggle={handleCardSongToggle}
                      on:error={(e) => showError(e.detail.message)}
                      on:warning={(e) => showWarning(e.detail.message)}
                      on:success={(e) => showSuccess(e.detail.message)}
                    />
                  {/each}
                </Accordion>
              {/if}
            {:else}
              {#if pastRehearsals.length === 0}
                <div class="rounded-xl bg-surface-100 text-surface-900 p-4 mt-6 shadow text-center">
                  Keine vergangenen Proben vorhanden.
                </div>
              {:else}
                <Accordion class="mt-4">
                  {#each pastRehearsals as reh (reh.id)}
                    <RehearsalCard
                      {reh}
                      {songs}
                      {songsForSearch}
                      {users}
                      {isEditor}
                      expanded={expandedRehId === reh.id}
                      {expandedSongId}
                      on:toggle={() => toggleExpand(reh.id)}
                      on:update={handleCardUpdate}
                      on:delete={handleCardDelete}
                      on:songtoggle={handleCardSongToggle}
                      on:error={(e) => showError(e.detail.message)}
                      on:warning={(e) => showWarning(e.detail.message)}
                      on:success={(e) => showSuccess(e.detail.message)}
                    />
                  {/each}
                </Accordion>
              {/if}
            {/if}
          </svelte:fragment>
        </TabGroup>
      {/if}


    </div>
  </div>
</div>


