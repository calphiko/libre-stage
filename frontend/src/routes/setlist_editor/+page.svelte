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
  import { onMount, onDestroy, tick } from 'svelte';
  import SetList from './SetList.svelte';
  import SongList from './SongList.svelte';
  import { get } from 'svelte/store';
  import { gigIdForEditor } from '$lib/stores.js';
  import { getSetlist, updateGigSetlist, getSongs, getUser, getSong, getSingerColors } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { overrideItemIdKeyNameBeforeInitialisingDndZones } from 'svelte-dnd-action';

  import { Circle2 } from 'svelte-loading-spinners';

  overrideItemIdKeyNameBeforeInitialisingDndZones('setsong_id');
  const { showError, showWarning } = createMessageHelpers();


  let { data } = $props();
  console.log(data);

  let songs = $state([]);
  let setlist = $state(null);
  let singerColors = $state({});
  let error = $state('');
  let user = $state(null);
  let showHelp = $state(false);
  let setlistEndAnchor;
  let setListRef = $state(null);
  let canUndo = $state(false);
  let canRedo = $state(false);
  let setlistPollingIntervalId = null;
  let isSetlistPollingInFlight = false;
  const SETLIST_POLL_INTERVAL_MS = 10000;

  let isUpdatingSpinner = $state(false);

  function cloneSetlistState(value) {
    if (value == null) return value;
    try {
      if (typeof structuredClone === 'function') return structuredClone(value);
    } catch (_err) {
      // Fallback for non-cloneable proxy/state values.
    }
    return JSON.parse(JSON.stringify(value));
  }

  const gigId = get(gigIdForEditor);
  console.log("gigId:", gigId);

  // Sänger-Farben bei Setlist-Änderungen automatisch aktualisieren
  $effect(() => {
    if (!setlist?.setlist_version) return;
    getSingerColors(null, gigId)
      .then(colors => { singerColors = colors; })
      .catch(e => console.warn('Could not refresh singer colors:', e));
  });

  async function pollForNewerSetlistVersion() {
    if (!setlist?.id || isSetlistPollingInFlight) return;
    if (typeof document !== 'undefined' && document.hidden) return;

    isSetlistPollingInFlight = true;
    try {
      const latest = await getSetlist(null, gigId);
      if (!latest) return;

      const localVersion = setlist?.setlist_version ?? null;
      const remoteVersion = latest?.setlist_version ?? null;

      if (localVersion && remoteVersion && localVersion !== remoteVersion) {
        setlist = latest;
        setListRef?.resetHistoryFromExternalUpdate?.();
        showWarning('Setliste wurde extern aktualisiert. Die Ansicht wurde neu geladen.');
      }
    } catch (e) {
      console.warn('Setlist polling failed:', e);
    } finally {
      isSetlistPollingInFlight = false;
    }
  }

  onMount(async () => {
    try {
      user = await getUser();

    } catch(e) {
      error = 'Userauthentifizierung fehlgeschlagen';
      console.error('Setlist editor load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
    try {
      songs = await getSongs();
    } catch (e) {
      error = e.message;
    }

    try {
      singerColors = await getSingerColors(null, gigId);
    } catch (e) {
      console.warn('Could not load initial singer colors:', e);
    }

    try {
      setlist = await getSetlist(null, gigId);
      console.log(setlist);
      setlistPollingIntervalId = setInterval(pollForNewerSetlistVersion, SETLIST_POLL_INTERVAL_MS);
    } catch (e) {
      error = e.message;
    }
  });

  onDestroy(() => {
    if (setlistPollingIntervalId) {
      clearInterval(setlistPollingIntervalId);
      setlistPollingIntervalId = null;
    }
  });

  export async function addSongToSetListEnd(song) {
      await addSongToSet(song, null);
  }

  export async function addSongToSet(song, setIdx = null) {
      console.log("Füge Song hinzu:", song, "zu SetIndex:", setIdx);
      console.log("Aktuelle Setliste:", setlist);

      if (!setlist || !setlist.sets || setlist.sets.length === 0) {
        error = 'Setliste nicht geladen oder keine Sets vorhanden';
        return;
      }

      let targetSetIndex = setIdx;
      if (targetSetIndex === null || targetSetIndex === undefined || targetSetIndex < 0 || targetSetIndex >= setlist.sets.length) {
        targetSetIndex = setlist.sets.length - 1;
      }

      try {
        const previousSetlist = cloneSetlistState(setlist);

        // Song-Info vom Server holen (wie in handleDragOverSet)
        const songInfo = await getSong(null, song);

        // Temporäre negative setsong_id vergeben
        songInfo.setsong_id = -Math.floor(Date.now() + Math.random() * 1000);

        // Immutable Update
        const newSetlist = { ...setlist };
        newSetlist.sets = [...newSetlist.sets];

        const targetSet = { ...newSetlist.sets[targetSetIndex] };
        targetSet.songs = [...targetSet.songs, songInfo];

        newSetlist.sets[targetSetIndex] = targetSet;
        setlist = newSetlist;

        // Nach dem Einfügen zum Ende der Setliste scrollen.
        await tick();
        setlistEndAnchor?.scrollIntoView({ behavior: 'smooth', block: 'end' });

        console.log("Setlist nach Import:", setlist);
        // API-Call wie in handleDragOverSet
        setlist = await updateGigSetlist(null, setlist.id, newSetlist);
        setListRef?.registerExternalHistorySnapshot(previousSetlist);
        console.log("Setlist nach API Call:", setlist);
      } catch (e) {
        if (e?.code === 'SETLIST_CONFLICT' && e?.currentSetlist) {
          setlist = e.currentSetlist;
          setListRef?.resetHistoryFromExternalUpdate?.();
          showError('Setliste wurde in der Zwischenzeit geaendert. Bitte Aktion erneut ausfuehren.');
          error = '';
          return;
        }
        error = `Fehler beim Hinzufügen: ${e.message}`;
        console.error(e);
      }
  }
</script>

<div class="container w-full max-w-none mx-auto px-2 md:px-4 setlist-editor-compact h-full min-h-0 flex flex-col">
  <!-- Header -->
  <header class="mb-3 flex-shrink-0">
    <div class="flex items-center justify-between">
      <h1 class="h2 font-bold">
        {#if setlist}
          Setliste: <span class="text-primary-500">{setlist.name}</span>
        {:else}
          <span class="opacity-50">Lade Setliste...</span>
        {/if}
      </h1>
      <div class="flex items-center gap-1 ml-2">
       {#if isUpdatingSpinner}
            <Circle2 size="20" />
        {/if}


        <button
          class="btn variant-filled-primary btn-sm"
          onclick={() => showHelp = !showHelp}
          aria-label="Hilfe anzeigen"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <span class="hidden md:inline ml-1">Hilfe</span>
        </button>

        <button
          class="btn variant-filled-primary btn-sm"
          onclick={() => setListRef?.undoLastChange()}
          disabled={!canUndo}
          aria-label="Rueckgaengig"
          title="Rueckgaengig (Strg/Cmd+Z)"
        >
          <span aria-hidden="true">&#8630;</span>
        </button>
        <button
          class="btn variant-filled-primary btn-sm"
          onclick={() => setListRef?.redoLastChange()}
          disabled={!canRedo}
          aria-label="Wiederholen"
          title="Wiederholen (Strg/Cmd+Y)"
        >
          <span aria-hidden="true">&#8631;</span>
        </button>
      </div>
    </div>

    {#if showHelp}
      <div class="card variant-ghost-surface mt-2 p-2 md:p-3">
        <h3 class="h4 font-bold mb-2">🎹 Anleitung: Setlist-Editor</h3>

        <div class="space-y-2">
          <!-- Grundfunktionen -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-1">📋 Grundfunktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Songs hinzufügen:</strong> Ziehe Songs aus der linken Liste in die Setliste (Drag & Drop)</li>
              <li><strong>Reihenfolge ändern:</strong> Ziehe Songs innerhalb der Setliste an eine neue Position</li>
              <li><strong>Songs zwischen Sets verschieben:</strong> Ziehe Songs von einem Set in ein anderes</li>
              <li><strong>Songs entfernen:</strong> Klicke auf das "×" neben einem Song</li>
            </ul>
          </div>

          <!-- Keyboard Shortcuts -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-1">⌨️ Keyboard-Shortcuts</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-1.5 text-sm">
              <div class="flex items-center gap-2">
                <kbd class="kbd">Enter</kbd>
                <span class="opacity-75">Ersten gefilterten Song ans Ende hinzufügen (im Suchfeld)</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Opt/Alt</kbd> + <kbd class="kbd">Shift</kbd> + <kbd class="kbd">1-4</kbd>
                <span class="opacity-75">Gefilterten Song 1-4 direkt ans Ende hinzufügen (im Suchfeld)</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Shift</kbd> + <kbd class="kbd">Enter</kbd>
                <span class="opacity-75">Neues Set am Ende hinzufügen</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Shift</kbd> + <kbd class="kbd">⌫</kbd>
                <span class="opacity-75">Letzten Song des Stacks entfernen</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Z</kbd>
                <span class="opacity-75">Letzte Aenderung rueckgaengig machen</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Y</kbd>
                <span class="opacity-75">Rueckgaengig gemachte Aenderung wiederholen</span>
              </div>
            </div>
          </div>

          <!-- Sets verwalten -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-1">📁 Sets verwalten</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Neues Set:</strong> Klicke auf "+ Neues Set" oder nutze <kbd class="kbd">Strg/⌘+Shift+Enter</kbd></li>
              <li><strong>Set umbenennen:</strong> Klicke auf den Set-Namen</li>
              <li><strong>Pause setzen:</strong> Klicke auf die Pause-Zeit</li>
              <li><strong>Set aus vergangenem Gig:</strong> Nutze den Button <em>Set aus vergangenem Gig</em>, waehle Gig und Set und fuege es als neues Set ein</li>
              <li><strong>Set löschen:</strong> Klicke auf das "🗑️" Symbol beim Set</li>
              <li><strong>Set-Reihenfolge:</strong> Ziehe Sets per Drag & Drop</li>
            </ul>
          </div>

          <div>
            <h4 class="font-semibold text-info-500 mb-1">📦 Import aus vergangenem Gig</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>Es werden <strong>nur Setname und Songs</strong> uebernommen</li>
              <li><strong>Live-Daten</strong> wie Bewertungen und uebersprungene Songs werden <strong>nicht</strong> mitkopiert</li>
              <li>Nach erfolgreichem Einfuegen erscheint eine <strong>Toast-Meldung</strong> als Bestaetigung</li>
            </ul>
          </div>

          <!-- Filter & Suche -->
          <div>
            <h4 class="font-semibold text-success-500 mb-1">🔍 Filter & Suche</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>Suche nach Titel oder Interpret im Suchfeld</li>
              <li>Filtere nach Status (Neu, Proben, Spielbereit)</li>
              <li>Filtere nach Sänger/in über die Badges</li>
            </ul>
          </div>

          <!-- Tipps -->
          <div class="alert variant-soft-primary">
            <div class="alert-message">
              <h4 class="font-semibold mb-1">💡 Tipp</h4>
              <p class="text-sm">Alle Änderungen werden automatisch gespeichert! Du musst nicht manuell speichern. Erfolgreiche Set-Importe werden zusaetzlich per Toast bestaetigt.</p>
            </div>
          </div>
        </div>
      </div>
    {/if}

    {#if error}
      <div class="alert variant-filled-error mt-2">
        <p>{error}</p>
      </div>
    {/if}
  </header>

  <!-- Editor Grid -->
  <div class="editor-grid flex-1 min-h-0">
    <!-- Song List Column (Sticky) -->
    <div class="editor-col sticky-col card variant-ghost-surface">
      <div class="card-header pb-1 border-b border-surface-400/30">
        <h3 class="h4 font-bold flex items-center gap-2">
          <svg class="w-5 h-5 text-primary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
          </svg>
          Alle Songs
        </h3>
      </div>
      <div class="card-body pt-1 flex-1 min-h-0 flex flex-col">
        {#if songs.length}
          <SongList {songs} {addSongToSetListEnd} {addSongToSet} setlist={setlist} {singerColors} />
        {:else}
          <div class="flex flex-col items-center justify-center py-6 opacity-60">
            <div class="animate-pulse">
              <svg class="w-10 h-10 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
            </div>
            <p class="text-sm">Lade Songs...</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Setlist Column -->
    <div class="editor-col card variant-ghost-surface">
      <div class="card-header pb-1 border-b border-surface-400/30">
        <h3 class="h4 font-bold flex items-center gap-2">
          <svg class="w-5 h-5 text-secondary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
          </svg>
          Setliste
        </h3>
      </div>
      <div class="card-body pt-1 flex-1 min-h-0 overflow-y-auto">
        {#if setlist}
          <SetList bind:setlist bind:canUndo bind:canRedo bind:this={setListRef} bind:isUpdatingSpinner {singerColors}/>
          <div bind:this={setlistEndAnchor}></div>
        {:else}
          <div class="flex flex-col items-center justify-center py-6 opacity-60">
            <div class="animate-pulse">
              <svg class="w-10 h-10 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
            </div>
            <p class="text-sm">Lade Setliste...</p>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<style>
  .setlist-editor-compact :global(.btn) {
    min-height: 1.9rem;
    padding-top: 0.2rem;
    padding-bottom: 0.2rem;
    line-height: 1.1;
  }

  .setlist-editor-compact :global(.btn-sm) {
    min-height: 1.7rem;
    padding-top: 0.125rem;
    padding-bottom: 0.125rem;
  }

  .setlist-editor-compact :global(.btn-xs) {
    min-height: 1.5rem;
    padding-top: 0.1rem;
    padding-bottom: 0.1rem;
  }

  .editor-grid {
    display: grid;
    grid-template-columns: 1fr 1.2fr;
    gap: 0.5rem;
    width: 100%;
    margin: 0;
    min-height: 0;
  }

  .editor-col {
    display: flex;
    flex-direction: column;
    min-height: 0;
    border-radius: 14px;
    border: 1px solid color-mix(in oklab, light-dark(var(--color-surface-300), var(--color-surface-700)) 60%, transparent);
    background: color-mix(in oklab, light-dark(var(--color-surface-50), var(--color-surface-900)) 97%, transparent);
    overflow: hidden;
  }

  .editor-col .card-header {
    background: color-mix(in oklab, light-dark(var(--color-surface-100), var(--color-surface-800)) 88%, transparent);
  }

  .sticky-col {
    position: sticky;
    top: 0.5rem;
    align-self: stretch;
    max-height: calc(100% - 0.5rem);
    overflow-y: auto;
  }

  /* Custom Scrollbar für sticky column */
  .sticky-col::-webkit-scrollbar {
    width: 6px;
  }

  .sticky-col::-webkit-scrollbar-track {
    background: transparent;
  }

  .sticky-col::-webkit-scrollbar-thumb {
    background: rgb(var(--color-surface-400) / 0.3);
    border-radius: 3px;
  }

  .sticky-col::-webkit-scrollbar-thumb:hover {
    background: rgb(var(--color-surface-500) / 0.5);
  }

  /* Responsive Layout optimized for Tablets */
  @media (max-width: 768px) {
    .editor-grid {
      grid-template-columns: 1fr;
      gap: 0.75rem;
    }

    .sticky-col {
      position: relative;
      top: 0;
      max-height: 420px;
    }
  }

  @media (max-width: 640px) {
    .editor-grid {
      gap: 0.5rem;
    }

    .sticky-col {
      max-height: 320px;
    }
  }

  /* Animation für Loading-Spinner */
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .animate-pulse {
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }

  @keyframes pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.5;
    }
  }
</style>
