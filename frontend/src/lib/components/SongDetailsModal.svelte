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
  import { onMount } from 'svelte';
  import { getModalStore } from '@skeletonlabs/skeleton';
  import { songFieldsDetails } from '$lib/songFields.js';
  import { getSong, getUser, updateSong, deleteSong, getSingers, getSongRehearsalHistory, getUserList, getSongStatistics } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { getToastStore } from '@skeletonlabs/skeleton';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import SingersList from '$lib/components/SingersList.svelte';

  const modalStore = getModalStore();
  const { showError, showSuccess } = createMessageHelpers(getToastStore());

  export let parent;

  // Nur songId wird übergeben
  const { songId } = $modalStore[0].meta;

  let song = null;
  let loading = true;
  let error = '';
  let canEdit = false;
  let tabSet = 0;
  let isEditing = false;
  let editBuffer = {};
  let singers = [];
  let isSaving = false;
  let rehearsalHistory = [];
  let users = [];
  let historyLoading = false;
  let statistics = null;
  let statsLoading = false;

  function statsEnabled() {
    if (song.status == 'vorschlag') return false;
    return true;
  }


  onMount(async () => {
    try {
      const [songData, userData, singerData, userList] = await Promise.all([
        getSong(null, songId),
        getUser(),
        getSingers(),
        getUserList()
      ]);

      song = songData;
      editBuffer = { ...song };
      canEdit = userData && (userData.user_group === 'admin' || userData.user_group === 'editor');
      singers = singerData || [];
      users = userList || [];
    } catch (e) {
      error = e.message || 'Song konnte nicht geladen werden';
      console.error('SongDetailsModal load error:', e);
    } finally {
      loading = false;
    }
  });

  function getUserName(userId) {
    const user = users.find(u => u.id === userId);
    return user?.clear_name || user?.user_name || 'Unbekannt';
  }

  function formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('de-DE', {
      weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric'
    });
  }

  async function loadRehearsalHistory() {
    if (rehearsalHistory.length > 0) return; // Schon geladen
    historyLoading = true;
    try {
      rehearsalHistory = await getSongRehearsalHistory(songId, 3);
    } catch (e) {
      console.error('Rehearsal history load error:', e);
    } finally {
      historyLoading = false;
    }
  }

  // Lade History wenn Tab 2 geöffnet wird
  $: if (tabSet === 2) loadRehearsalHistory();

  async function loadStatistics() {
    if (statistics) return;
    statsLoading = true;
    try {
      statistics = await getSongStatistics(songId);
    } catch (e) {
      console.error('Statistics load error:', e);
    } finally {
      statsLoading = false;
    }
  }

  // Lade Statistiken wenn Tab 1 geöffnet wird
  $: if (tabSet === 1) loadStatistics();

  const feedbackEmoji = { 1: '😞', 2: '😐', 3: '😊' };
  const feedbackLabel = { 1: 'Schwach', 2: 'OK', 3: 'Super' };

  function startEdit() {
    isEditing = true;
    editBuffer = { ...song };
    songFieldsDetails.forEach(field => {
      if (field.type === 'singer_list' && typeof editBuffer[field.key] === 'string') {
        editBuffer[field.key] = editBuffer[field.key]
          .split('+')
          .map(s => s.trim())
          .filter(s => s.length > 0);
      }
    });
  }

  function cancelEdit() {
    isEditing = false;
    editBuffer = { ...song };
  }

  async function saveEdit() {
    if (isSaving) return;
    isSaving = true;
    try {
      const dataToSend = { ...editBuffer };
      songFieldsDetails.forEach(field => {
        if (field.type === 'singer_list' && Array.isArray(dataToSend[field.key])) {
          dataToSend[field.key] = dataToSend[field.key].join(' + ');
        }
      });

      const updatedSong = await updateSong(song.id, dataToSend, null);
      showSuccess('Song erfolgreich aktualisiert');
      isEditing = false;

      const songData = updatedSong || dataToSend;
      song = { ...song, ...songData };
      editBuffer = { ...song };

      if ($modalStore[0]?.response) {
        $modalStore[0].response({ action: 'updated', data: { ...song } });
      }

      modalStore.close();
    } catch (e) {
      showError(e.message ?? 'Update fehlgeschlagen');
    } finally {
      isSaving = false;
    }
  }

  async function handleDelete() {
    const songName = song.interpret ? `${song.interpret} - ${song.title}` : song.title;
    const parentResponse = $modalStore[0]?.response;
    const id = song.id;

    modalStore.close();

    setTimeout(() => {
      modalStore.trigger({
        type: 'component',
        component: { ref: ConfirmModal },
        meta: {
          title: 'Song löschen',
          message: `Möchten Sie den Song "${songName}" wirklich löschen? Der Song wird als "retired" markiert und aus der aktiven Liste entfernt.`,
          confirmText: 'Löschen',
          cancelText: 'Abbrechen',
          confirmButtonClass: 'btn variant-filled-error',
          cancelButtonClass: 'btn variant-outline-secondary'
        },
        response: async (confirmed) => {
          if (confirmed) {
            try {
              await deleteSong(id, null);
              showSuccess('Song erfolgreich gelöscht');
              if (parentResponse) {
                parentResponse({ action: 'delete' });
              }
            } catch (e) {
              showError(e.message ?? 'Löschen fehlgeschlagen');
            }
          }
        }
      });
    }, 200);
  }
</script>
<div class="card p-6 max-w-4xl w-full max-h-[90vh] flex flex-col">

  <!-- Header -->
  <header class="flex justify-between items-center mb-4 flex-shrink-0">
    <h2 class="h2">{song?.title ?? 'Song laden...'}</h2>
    <button class="btn-icon btn-icon-sm variant-ghost" on:click={parent.onClose}>✕</button>
  </header>

  {#if loading}
    <div class="flex justify-center items-center py-12 flex-grow">
      <div class="text-center">
        <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500 mx-auto mb-4"></div>
        <p class="text-surface-600 dark:text-surface-400">Lade Song-Details...</p>
      </div>
    </div>
  {:else if error}
    <div class="alert variant-filled-error flex-grow">
      <p>{error}</p>
    </div>
    <footer class="flex gap-2 justify-end pt-4 flex-shrink-0">
      <button class="btn variant-ghost" on:click={parent.onClose}>Schließen</button>
    </footer>
  {:else if song}
    <!-- Manuell gebaute Tabs -->
    <div class="flex gap-1 mb-4 flex-shrink-0 border-b border-surface-300">
      <button
        class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 0 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
        on:click={() => tabSet = 0}
      >Details</button>
      <button
        class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 1 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
        on:click={() => tabSet = 1} disabled={!statsEnabled()}
      >Statistik</button>
      <button
        class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 2 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
        on:click={() => tabSet = 2} disabled={!statsEnabled()}
      >Proben</button>
    </div>

    <!-- Panel -->
    {#if tabSet === 0}
      <div class="flex flex-col min-h-0 flex-grow">
        {#if isEditing}
          <!-- Edit Mode -->
          <div class="overflow-y-auto flex-grow min-h-0">
            <form class="space-y-3 pr-1" on:submit|preventDefault={saveEdit}>
              {#each songFieldsDetails as songField}
                <div class="mb-3 flex items-center gap-2 flex-nowrap">
                  <label class="flex-shrink-0 w-36 text-sm font-medium">
                    {songField.label}
                    {#if songField.required}<span class="text-error-500 ms-1">*</span>{/if}
                  </label>
                  {#if songField.type === 'option' && Array.isArray(songField.options)}
                    <select class="input flex-grow" bind:value={editBuffer[songField.key]} required={songField.required}>
                      {#each songField.options as o}
                        <option value={o.key}>{o.label}</option>
                      {/each}
                    </select>
                  {:else if songField.type === 'time'}
                    <input type="time" step="1" class="input flex-grow" bind:value={editBuffer[songField.key]} placeholder={songField.label} required={songField.required} />
                  {:else if songField.type === 'date'}
                    <input type="date" class="input flex-grow" bind:value={editBuffer[songField.key]} placeholder={songField.label} required={songField.required} />
                  {:else if songField.type === 'singer_list'}
                    <SingersList
                      class="flex-grow"
                      bind:selected={editBuffer[songField.key]}
                      options={singers}
                      placeholder="Sänger hinzufügen"
                    />
                  {:else}
                    <input type="text" class="input flex-grow" bind:value={editBuffer[songField.key]} placeholder={songField.label} required={songField.required} minlength="1" maxlength="255" pattern=".*\S+.*" />
                  {/if}
                </div>
              {/each}
            </form>
          </div>
          <footer class="flex gap-2 justify-end pt-4 mt-2 flex-shrink-0 border-t border-surface-300">
            <button type="button" class="btn variant-filled-primary" disabled={isSaving} on:click={saveEdit}>
              {isSaving ? 'Wird gespeichert...' : 'Speichern'}
            </button>
            <button type="button" class="btn variant-ghost" on:click={cancelEdit}>Abbrechen</button>
          </footer>

        {:else}
          <!-- Detail View -->
          <div class="overflow-y-auto flex-grow min-h-0">
            {#each songFieldsDetails as f}
              <div class="flex justify-between py-2 border-b border-surface-300 text-sm">
                <span class="font-semibold text-on-surface-variant">{f.label}</span>
                <span class="text-right ml-4">{song[f.key] ?? '–'}</span>
              </div>
            {/each}
          </div>
          <footer class="flex gap-2 justify-end pt-4 mt-2 flex-shrink-0 border-t border-surface-300">
            {#if canEdit}
              <button class="btn variant-filled-primary" on:click={startEdit}>Bearbeiten</button>
            {/if}
            {#if song.status !== 'retired' && canEdit}
              <button class="btn variant-filled-error" on:click={handleDelete}>Löschen</button>
            {/if}
            <button class="btn variant-ghost" on:click={parent.onClose}>Schließen</button>
          </footer>
        {/if}
      </div>

    {:else if tabSet === 1}
      <div class="overflow-y-auto flex-grow min-h-0 p-2">
        {#if statsLoading}
          <div class="flex justify-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
          </div>
        {:else if !statistics}
          <p class="text-on-surface-variant text-center py-8">Statistiken konnten nicht geladen werden.</p>
        {:else}
          <div class="space-y-5">

            <!-- Übersicht -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div class="card variant-ghost-primary p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-primary-500">{statistics.rehearsal_count}</div>
                <div class="text-xs text-on-surface-variant">Proben</div>
              </div>
              <div class="card variant-ghost-secondary p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-secondary-500">{statistics.gig_count}</div>
                <div class="text-xs text-on-surface-variant">Auftritte</div>
              </div>
              <div class="card variant-ghost-tertiary p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-tertiary-500">{statistics.skipped_count}</div>
                <div class="text-xs text-on-surface-variant">Übersprungen</div>
              </div>
              <div class="card variant-ghost-warning p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-warning-500">{statistics.inserted_count}</div>
                <div class="text-xs text-on-surface-variant">Eingeschoben</div>
              </div>
            </div>

            <!-- Zeitraum -->
            {#if statistics.first_rehearsal}
              <div class="card variant-ghost-surface p-3 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-2">📅 Zeitraum</h4>
                <div class="flex justify-between text-sm">
                  <span>Erste Probe: <strong>{formatDate(statistics.first_rehearsal)}</strong></span>
                  <span>Letzte Probe: <strong>{formatDate(statistics.last_rehearsal)}</strong></span>
                </div>
              </div>
            {/if}

            <!-- Live-Mode Bewertungen -->
            {#if statistics.feedback_count > 0}
              <div class="card variant-ghost-surface p-3 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-3">⭐ Live-Bewertungen</h4>
                <div class="flex items-center gap-4 mb-3">
                  <div class="text-center">
                    <div class="text-3xl">{statistics.feedback_avg >= 2.5 ? '😊' : statistics.feedback_avg >= 1.5 ? '😐' : '😞'}</div>
                    <div class="text-xs text-on-surface-variant mt-1">Ø {statistics.feedback_avg}</div>
                  </div>
                  <div class="flex-grow space-y-1.5">
                    {#each [3, 2, 1] as rating}
                      {@const count = statistics.feedback_distribution[rating] || 0}
                      {@const pct = Math.round((count / statistics.feedback_count) * 100)}
                      <div class="flex items-center gap-2 text-sm">
                        <span class="w-6 text-center">{feedbackEmoji[rating]}</span>
                        <div class="flex-grow bg-surface-300 dark:bg-surface-700 rounded-full h-3">
                          <div
                            class="h-3 rounded-full transition-all {rating === 3 ? 'bg-success-500' : rating === 2 ? 'bg-warning-500' : 'bg-error-500'}"
                            style="width: {pct}%"
                          ></div>
                        </div>
                        <span class="w-16 text-right text-xs text-on-surface-variant">{count}× ({pct}%)</span>
                      </div>
                    {/each}
                  </div>
                </div>
              </div>
            {:else}
              <div class="card variant-ghost-surface p-3 rounded-lg text-center">
                <p class="text-sm text-on-surface-variant">Noch keine Live-Bewertungen vorhanden.</p>
              </div>
            {/if}

            <!-- Auftritte -->
            {#if statistics.gigs_played.length > 0}
              <div class="card variant-ghost-surface p-3 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-2">🎤 Auftritte</h4>
                <div class="space-y-1">
                  {#each statistics.gigs_played as gig}
                    <div class="flex items-center justify-between text-sm py-1 border-b border-surface-300 last:border-0">
                      <div>
                        <span class="font-medium">{gig.gig_name}</span>
                        <span class="text-xs text-on-surface-variant ml-2">{formatDate(gig.gig_date)}</span>
                      </div>
                      <div class="flex items-center gap-1">
                        {#if gig.uebersprungen}
                          <span class="text-xs text-error-500" title="Übersprungen">⏭</span>
                        {:else if gig.eingeschoben}
                          <span class="text-xs text-warning-500" title="Eingeschoben">📌</span>
                        {/if}
                        {#if gig.feedback != null}
                          <span title={feedbackLabel[gig.feedback]}>{feedbackEmoji[gig.feedback]}</span>
                        {:else}
                          <span class="text-xs text-surface-400">–</span>
                        {/if}
                      </div>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}

            <!-- Häufige Set-Begleiter -->
            {#if statistics.companion_songs.length > 0}
              <div class="card variant-ghost-surface p-3 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-2">🤝 Häufig zusammen im Set</h4>
                <div class="space-y-1">
                  {#each statistics.companion_songs as comp}
                    <div class="flex items-center justify-between text-sm py-1 border-b border-surface-300 last:border-0">
                      <div>
                        <span class="font-medium">{comp.title}</span>
                        <span class="text-xs text-on-surface-variant ml-1">– {comp.interpret}</span>
                      </div>
                      <span class="badge variant-soft-primary text-xs">{comp.count}×</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}

          </div>
        {/if}
      </div>
    {:else if tabSet === 2}
      <div class="overflow-y-auto flex-grow min-h-0 p-2">
        {#if historyLoading}
          <div class="flex justify-center py-8">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
          </div>
        {:else if rehearsalHistory.length === 0}
          <p class="text-on-surface-variant text-center py-8">Dieser Song wurde bisher in keiner Probe gespielt.</p>
        {:else}
          <div class="space-y-4">
            {#each rehearsalHistory as entry}
              <div class="card variant-ghost-surface p-4 rounded-lg">
                <!-- Proben-Kopf -->
                <div class="flex items-center justify-between mb-3">
                  <h4 class="font-semibold text-sm text-on-surface">
                    📅 {formatDate(entry.rehearsal_date)}
                  </h4>
                  {#if entry.done}
                    <span class="badge variant-soft-success text-xs">✓ erledigt</span>
                  {:else}
                    <span class="badge variant-soft-warning text-xs">⏳ offen</span>
                  {/if}
                </div>

                <!-- Song-Kommentar aus der Probe -->
                {#if entry.comment}
                  <div class="mb-2">
                    <span class="text-xs font-semibold text-on-surface-variant">Proben-Notiz:</span>
                    <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1">{entry.comment}</p>
                  </div>
                {/if}

                <!-- Todo -->
                {#if entry.todo}
                  <div class="mb-2">
                    <span class="text-xs font-semibold text-on-surface-variant">Todo:</span>
                    <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1">{entry.todo}</p>
                  </div>
                {/if}

                <!-- Persönliche Todos -->
                {#if entry.todos.length > 0}
                  <div>
                    <span class="text-xs font-semibold text-on-surface-variant">Persönliche Todos:</span>
                    <ul class="mt-1 space-y-1">
                      {#each entry.todos as t}
                        <li class="flex items-center gap-2 text-sm bg-surface-200 dark:bg-surface-700 rounded px-2 py-1">
                          <span class="{t.done ? 'text-success-500' : 'text-warning-500'}">
                            {t.done ? '✔' : '⏳'}
                          </span>
                          <span class="font-medium">{getUserName(t.id_user)}:</span>
                          <span class:line-through={t.done}>{t.todo}</span>
                        </li>
                      {/each}
                    </ul>
                  </div>
                {/if}

                <!-- Allgemeiner Proben-Kommentar (der gesamten Probe) -->
                {#if entry.rehearsal_comment}
                  <details class="mt-2">
                    <summary class="text-xs text-on-surface-variant cursor-pointer hover:text-primary-500">
                      📝 Allgemeiner Proben-Kommentar anzeigen
                    </summary>
                    <p class="text-xs bg-surface-100 dark:bg-surface-800 rounded p-2 mt-1 whitespace-pre-wrap">{entry.rehearsal_comment}</p>
                  </details>
                {/if}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}

  {/if}

</div>
