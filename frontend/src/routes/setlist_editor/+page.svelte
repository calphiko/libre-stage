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
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import SetList from './SetList.svelte';
  import SongList from './SongList.svelte';
  import { get } from 'svelte/store';
  import { gigIdForEditor } from '$lib/stores.js';
  import { getSetlist, updateGigSetlist, getSongs, getUser, getSong, logout as apiLogout} from '$lib/api.js';



  let { data } = $props();
  console.log(data);

  let songs = $state([]);
  let setlist = $state(null);
  let error = $state('');
  let user = $state(null);
  let showHelp = $state(false);



    const gigId = get(gigIdForEditor);
  console.log("gigId:", gigId);



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
      setlist = await getSetlist(null, gigId);
      console.log(setlist);
    } catch (e) {
      error = e.message;
    }
  });

  export async function addSongToSetListEnd(song) {
      console.log("Füge Song hinzu:", song);
      console.log("Aktuelle Setliste:", setlist);

      if (!setlist || !setlist.sets || setlist.sets.length === 0) {
        error = 'Setliste nicht geladen oder keine Sets vorhanden';
        return;
      }

      try {
        // Song-Info vom Server holen (wie in handleDragOverSet)
        const songInfo = await getSong(null, song);

        // Temporäre negative setsong_id vergeben
        songInfo.setsong_id = -Math.floor(Date.now() + Math.random() * 1000);

        // Immutable Update
        const newSetlist = { ...setlist };
        newSetlist.sets = [...newSetlist.sets];

        const lastSetIndex = newSetlist.sets.length - 1;
        const lastSet = { ...newSetlist.sets[lastSetIndex] };
        lastSet.songs = [...lastSet.songs, songInfo];

        newSetlist.sets[lastSetIndex] = lastSet;
        setlist = newSetlist;

        console.log("Setlist nach Import:", setlist);
        // API-Call wie in handleDragOverSet
        setlist = await updateGigSetlist(null, setlist.id, newSetlist);
        console.log("Setlist nach API Call:", setlist);
      } catch (e) {
        error = `Fehler beim Hinzufügen: ${e.message}`;
        console.error(e);
      }
  }



</script>

<div class="container max-w-full lg:max-w-7xl lg:px-4">
  <!-- Header -->
  <header class="mb-6">
    <div class="flex items-center justify-between">
      <h1 class="h2 font-bold">
        {#if setlist}
          Setliste: <span class="text-primary-500">{setlist.name}</span>
        {:else}
          <span class="opacity-50">Lade Setliste...</span>
        {/if}
      </h1>
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
      <div class="card variant-ghost-surface mt-4 p-4 md:p-6">
        <h3 class="h4 font-bold mb-4">🎹 Anleitung: Setlist-Editor</h3>

        <div class="space-y-4">
          <!-- Grundfunktionen -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-2">📋 Grundfunktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Songs hinzufügen:</strong> Ziehe Songs aus der linken Liste in die Setliste (Drag & Drop)</li>
              <li><strong>Reihenfolge ändern:</strong> Ziehe Songs innerhalb der Setliste an eine neue Position</li>
              <li><strong>Songs zwischen Sets verschieben:</strong> Ziehe Songs von einem Set in ein anderes</li>
              <li><strong>Songs entfernen:</strong> Klicke auf das "×" neben einem Song</li>
            </ul>
          </div>

          <!-- Keyboard Shortcuts -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-2">⌨️ Keyboard-Shortcuts</h4>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
              <div class="flex items-center gap-2">
                <kbd class="kbd">Enter</kbd>
                <span class="opacity-75">Ersten gefilterten Song ans Ende hinzufügen (im Suchfeld)</span>
              </div>
              <div class="flex items-center gap-2">
                <kbd class="kbd">Strg/⌘</kbd> + <kbd class="kbd">Shift</kbd> + <kbd class="kbd">N</kbd>
                <span class="opacity-75">Neues Set am Ende hinzufügen</span>
              </div>
            </div>
          </div>

          <!-- Sets verwalten -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-2">📁 Sets verwalten</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Neues Set:</strong> Klicke auf "+ Neues Set" oder nutze <kbd class="kbd">Strg/⌘+Shift+N</kbd></li>
              <li><strong>Set umbenennen:</strong> Klicke auf den Set-Namen</li>
              <li><strong>Pause setzen:</strong> Klicke auf die Pause-Zeit</li>
              <li><strong>Set löschen:</strong> Klicke auf das "🗑️" Symbol beim Set</li>
              <li><strong>Set-Reihenfolge:</strong> Ziehe Sets per Drag & Drop</li>
            </ul>
          </div>

          <!-- Filter & Suche -->
          <div>
            <h4 class="font-semibold text-success-500 mb-2">🔍 Filter & Suche</h4>
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
              <p class="text-sm">Alle Änderungen werden automatisch gespeichert! Du musst nicht manuell speichern.</p>
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
  <div class="editor-grid">
    <!-- Song List Column (Sticky) -->
    <div class="editor-col sticky-col card variant-filled-surface">
      <div class="card-header pb-3 border-b border-surface-400/30">
        <h3 class="h4 font-bold flex items-center gap-2">
          <svg class="w-5 h-5 text-primary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
          </svg>
          Alle Songs
        </h3>
      </div>
      <div class="card-body pt-3">
        {#if songs.length}
          <SongList {songs} {addSongToSetListEnd} />
        {:else}
          <div class="flex flex-col items-center justify-center py-12 opacity-60">
            <div class="animate-pulse">
              <svg class="w-12 h-12 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
      <div class="card-header pb-3 border-b border-surface-400/30">
        <h3 class="h4 font-bold flex items-center gap-2">
          <svg class="w-5 h-5 text-secondary-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
          </svg>
          Setliste
        </h3>
      </div>
      <div class="card-body pt-3">
        {#if setlist}
          <SetList bind:setlist />
        {:else}
          <div class="flex flex-col items-center justify-center py-12 opacity-60">
            <div class="animate-pulse">
              <svg class="w-12 h-12 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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
  .editor-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.5rem;
    margin: 0 auto;
  }

  .editor-col {
    border-radius: var(--theme-rounded-container);
    overflow: hidden;
  }

  .sticky-col {
    position: sticky;
    top: 1rem;
    align-self: flex-start;
    max-height: calc(100vh - 2rem);
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

  /* Responsive Layout */
  @media (max-width: 1024px) {
    .editor-grid {
      grid-template-columns: 1fr;
      gap: 1.5rem;
    }

    .sticky-col {
      position: relative;
      top: 0;
      max-height: 500px;
    }
  }

  @media (max-width: 640px) {
    .editor-grid {
      gap: 1rem;
    }

    .sticky-col {
      max-height: 400px;
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
