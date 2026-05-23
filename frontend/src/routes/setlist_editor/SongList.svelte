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
  import { dndzone } from 'svelte-dnd-action';
  import { getFirstSinger, getColorBySinger } from '$lib/common.js';


  let { songs = [], addSongToSetListEnd, addSongToSet = null, setlist = null } = $props();


  let genreFilter = $state('');
  let statusFilter = $state(['spielbar', 'proben']);
  let singerFilter = $state('');
  let searchFilter = $state('');
  let showFilters = $state(false);
  let open = $state(new Set());
  let activeSetSelectorSongId = $state(null);

  let genres = $derived(Array.from(new Set(songs.map(s => s.genre))).sort());
  let statuses = $derived(Array.from(new Set(songs.map(s => s.status))).sort());
  let singers = $derived(Array.from(new Set(songs.map(s => s.singer_lead_short))).sort());

  let filtered = $derived(songs.filter(song =>
    (!genreFilter || song.genre === genreFilter) &&
    (!statusFilter.length || statusFilter.includes(song.status)) &&
    (!singerFilter || song.singer_lead_short === singerFilter) &&
    (!searchFilter ||
      (song.title && song.title.toLowerCase().includes(searchFilter.trim().toLowerCase())) ||
      (song.interpret && song.interpret.toLowerCase().includes(searchFilter.trim().toLowerCase()))
    )
  ));

  let dndItems = $state([]);
  $effect(() => {
    dndItems = filtered.map(song => ({
      ...song,
      setsong_id: `new-${song.id}-${Math.floor(Math.random() * 1000000)}`
    }));
  });

  function handleDndConsider(e) {
    dndItems = e.detail.items;
  }

  function handleDndFinalize(e) {
    // Regeneriere die Liste der Dnd-Elemente mit neuen IDs, damit sie erneut gezogen werden können
    dndItems = filtered.map(song => ({
      ...song,
      setsong_id: `new-${song.id}-${Math.floor(Math.random() * 1000000)}`
    }));
  }

  function toggleOpen(id) {
    if (open.has(id)) open.delete(id);
    else open.add(id);
    open = new Set(open);
  }

  function handleAddButtonClick(songId) {
    if (addSongToSet && setlist && setlist.sets && setlist.sets.length > 1) {
      activeSetSelectorSongId = activeSetSelectorSongId === songId ? null : songId;
    } else {
      addSongToSetListEnd(songId);
    }
  }

  // Dynamische Farbzuweisung für Sänger via Skeleton-Varianten
  const singerVariants = [
    'variant-soft-primary',
    'variant-soft-secondary',
    'variant-soft-tertiary',
    'variant-soft-success',
    'variant-soft-warning',
    'variant-soft-error',
  ];
  const singerVariantCache = {};

  function getSingerSkeletonVariant(singer) {
    const name = getFirstSinger(singer);
    if (!name) return 'variant-soft-surface';
    if (!singerVariantCache[name]) {
      let hash = 0;
      for (let i = 0; i < name.length; i++) {
        hash = name.charCodeAt(i) + ((hash << 5) - hash);
      }
      singerVariantCache[name] = singerVariants[Math.abs(hash) % singerVariants.length];
    }
    return singerVariantCache[name];
  }

  function getSingerVariant(singer) {
    const firstName = getFirstSinger(singer);
    console.log(firstName);
    return getColorBySinger(firstName) || 'variant-soft-surface';
  }

  function handleSearchKeydown(e) {
    const isAddByIndexShortcut =
      (e.metaKey || e.ctrlKey) &&
      e.altKey &&
      e.shiftKey &&
      /^Digit[1-4]$/.test(e.code);

    if (isAddByIndexShortcut) {
      e.preventDefault();
      const index = Number(e.code.replace('Digit', '')) - 1;
      if (filtered[index]) {
        addSongToSetListEnd(filtered[index].id);
      }
      return;
    }

    const hasModifier = e.ctrlKey || e.metaKey || e.shiftKey || e.altKey;
    if (e.key === 'Enter' && !hasModifier && filtered.length > 0) {
      e.preventDefault();
      // Füge ersten Song aus gefilterter Liste hinzu
      addSongToSetListEnd(filtered[0].id);
      // Optional: Suchfeld leeren nach Hinzufügen
      searchFilter = '';
    }
  }
</script>

<div class="p-4 space-y-4">
  <!-- Search & Filter Toolbar -->
  <div class="flex flex-wrap gap-3 items-center">
    <input
      type="search"
      class="input"
      style="flex: 1; min-width: 240px;"
      placeholder="🔍 Suche Titel, Interpret..."
      bind:value={searchFilter}
      onkeydown={handleSearchKeydown}
    />
    <button
      class="btn variant-filled-surface min-h-[42px] touch-manipulation"
      type="button"
      onclick={() => showFilters = !showFilters}
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"></path>
      </svg>
      <span class="ml-2">{showFilters ? 'Filter ausblenden' : 'Filter anzeigen'}</span>
    </button>
  </div>

  <!-- Filter Panel -->
  {#if showFilters}
  <div class="card p-4 variant-filled-surface">
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <!-- Left Column: Singer & Genre -->
      <div class="space-y-4">
        <!-- Singer Filter -->
        <label class="label">
          <span class="font-semibold mb-2">Lead-Sänger</span>
          <select class="select min-h-[40px]" bind:value={singerFilter}>
            <option value=''>Alle</option>
            {#each singers as singer}
              <option value={singer}>{singer}</option>
            {/each}
          </select>
        </label>

        <!-- Genre Filter -->
        <label class="label">
          <span class="font-semibold mb-2">Genre</span>
          <select class="select min-h-[40px]" bind:value={genreFilter}>
            <option value=''>Alle Genres</option>
            {#each genres as genre}
              <option value={genre}>{genre}</option>
            {/each}
          </select>
        </label>
      </div>

      <!-- Right Column: Status -->
      <label class="label">
        <span class="font-semibold mb-2">Status</span>
        <select
          class="select"
          bind:value={statusFilter}
          multiple
          size={Math.min(6, statuses.length)}
        >
          {#each statuses as status}
            <option value={status}>{status}</option>
          {/each}
        </select>
        <span class="text-xs opacity-50 mt-1">Mehrfachauswahl mit STRG/CMD</span>
      </label>
    </div>
  </div>
{/if}


  <!-- Song List Container -->
  <div class="song-list-container card variant-ghost-surface bg-primary">
    <div
      class="space-y-2"
      use:dndzone={{
        items: dndItems,
        type: 'song-in-set',
        dragDisabled: false,
        dropTargetDisabled: true,
        flipDurationMs: 150
      }}
      onconsider={handleDndConsider}
      onfinalize={handleDndFinalize}
    >
      {#each dndItems as song (song.setsong_id)}
        <div
          class="card rounded-sm song-item w-full text-surface-900 dark:text-surface-950 transition-all duration-200 hover:scale-[1.01] {open.has(song.id) ? 'ring-2 ring-primary-500' : ''} py-0"
          style="background-color:{getColorBySinger(song.singer_lead_short)}"
        >
          <div class="p-3 py-2">
            <!-- Header -->
            <div>
              <div class="flex justify-between items-center gap-3">
                <div
                  class="flex-grow min-w-0 text-left cursor-grab active:cursor-grabbing p-1 touch-manipulation"
                >
                  <p class="text-base leading-tight font-semibold">{song.title}</p>
                  <p class="text-xs opacity-75">{song.interpret}</p>
                </div>
                <div class="flex items-center gap-2">
                  <!-- Touch-freundlicher Add-Button -->
                  <button
                    class="btn btn-sm variant-filled-primary flex-shrink-0 min-h-[40px] min-w-[40px] flex items-center justify-center p-0 touch-manipulation"
                    aria-label="Song hinzufügen"
                    onclick={() => handleAddButtonClick(song.id)}
                  >
                    <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"></path>
                    </svg>
                  </button>

                  <!-- Info/Expand Button -->
                  <button
                    class="btn btn-sm variant-filled-secondary flex-shrink-0 min-h-[40px] min-w-[40px] flex items-center justify-center p-0 transition-transform duration-200 touch-manipulation {open.has(song.id) ? 'rotate-180' : ''}"
                    aria-label="Info anzeigen"
                    onclick={() => toggleOpen(song.id)}
                  >
                    <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                    </svg>
                  </button>
                </div>
              </div>

              <!-- Tablet-freundlicher Set-Wähler, wenn auf das "+" in einer Setlist mit mehreren Sets geklickt wurde -->
              {#if activeSetSelectorSongId === song.id && setlist && setlist.sets && setlist.sets.length > 1}
                <div class="mt-2 p-2.5 bg-white/40 dark:bg-black/35 rounded-md border border-black/10 dark:border-white/10 flex flex-col gap-1.5 animate-fadeIn">
                  <span class="text-xs font-bold text-surface-700 dark:text-surface-200">Ziel-Set auswählen:</span>
                  <div class="flex flex-wrap gap-1.5">
                    {#each setlist.sets as set, setIdx}
                      <button
                        type="button"
                        class="btn btn-xs variant-filled-success hover:variant-filled-primary transition-colors text-white py-1.5 px-3 font-semibold text-xs touch-manipulation rounded"
                        onclick={() => {
                          if (addSongToSet) {
                            addSongToSet(song.id, setIdx);
                          } else {
                            addSongToSetListEnd(song.id);
                          }
                          activeSetSelectorSongId = null;
                        }}
                      >
                        {set.setlist_name || `Set ${setIdx + 1}`}
                      </button>
                    {/each}
                    <button
                      type="button"
                      class="btn btn-xs variant-soft-surface py-1.5 px-3 text-xs touch-manipulation font-semibold rounded"
                      onclick={() => activeSetSelectorSongId = null}
                    >
                      Abbrechen
                    </button>
                  </div>
                </div>
              {/if}
            </div>

            <!-- Expanded Details -->
            {#if open.has(song.id)}
              <hr class="!border-t !border-surface-400 dark:!border-surface-600 my-2" />
              <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm p-1">
                <div><span class="opacity-60 font-semibold">Genre:</span> <span class="font-medium">{song.genre || '-'}</span></div>
                <div><span class="opacity-60 font-semibold">Status:</span> <span class="font-medium">{song.status || '-'}</span></div>
                <div><span class="opacity-60 font-semibold">Lead:</span> <span class="font-medium">{song.singer_lead_short || '-'}</span></div>
                <div><span class="opacity-60 font-semibold">Dauer:</span> <span class="font-medium">{song.duration || '-'}</span></div>
                <div class="col-span-2"><span class="opacity-60 font-semibold">Kommentar:</span> <span class="font-medium">{song.comment || '-'}</span></div>
              </div>
            {/if}
          </div>
        </div>
      {/each}

      {#if filtered.length === 0}
        <div class="text-center py-12">
          <svg class="w-20 h-20 mx-auto mb-4 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
          </svg>
          <p class="text-lg font-medium opacity-70">Keine Songs gefunden</p>
          <p class="text-sm opacity-50 mt-1">Versuche andere Filtereinstellungen</p>
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(-4px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .animate-fadeIn {
    animation: fadeIn 0.15s ease-out forwards;
  }

  .song-list-container {
    max-height: calc(100vh - 280px);
    min-height: 300px;
    overflow-y: auto;
  }

  .song-item {
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .song-item:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  /* Touch-optimierter Active-Zustand */
  .song-item:active {
    transform: scale(0.995);
  }

  /* Custom scrollbar für bessere Skeleton-Integration */
  .song-list-container::-webkit-scrollbar {
    width: 8px;
  }

  .song-list-container::-webkit-scrollbar-track {
    background: transparent;
  }

  .song-list-container::-webkit-scrollbar-thumb {
    background: rgb(var(--color-surface-400) / 0.5);
    border-radius: 2px;
  }

  .song-list-container::-webkit-scrollbar-thumb:hover {
    background: rgb(var(--color-surface-500) / 0.7);
  }
</style>
