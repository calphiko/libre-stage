<script>
  import { dndzone } from 'svelte-dnd-action';
  import { getFirstSinger, getColorBySinger } from '$lib/common.js';


  export let songs = [];
  export let addSongToSetListEnd;


  let genreFilter = '';
  let statusFilter = ['spielbar', 'proben'];
  let singerFilter = '';
  let searchFilter = '';
  let showFilters = false;
  let open = new Set();

  $: genres = Array.from(new Set(songs.map(s => s.genre))).sort();
  $: statuses = Array.from(new Set(songs.map(s => s.status))).sort();
  $: singers = Array.from(new Set(songs.map(s => s.singer_lead_short))).sort();

  $: filtered = songs.filter(song =>
    (!genreFilter || song.genre === genreFilter) &&
    (!statusFilter.length || statusFilter.includes(song.status)) &&
    (!singerFilter || song.singer_lead_short === singerFilter) &&
    (!searchFilter ||
      (song.title && song.title.toLowerCase().includes(searchFilter.trim().toLowerCase())) ||
      (song.interpret && song.interpret.toLowerCase().includes(searchFilter.trim().toLowerCase()))
    )
  );

  function toggleOpen(id) {
    if (open.has(id)) open.delete(id);
    else open.add(id);
    open = new Set(open);
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
    if (e.key === 'Enter' && filtered.length > 0) {
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
      on:keydown={handleSearchKeydown}
    />
    <button
      class="btn variant-filled-surface"
      type="button"
      on:click={() => showFilters = !showFilters}
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
          <select class="select" bind:value={singerFilter}>
            <option value=''>Alle</option>
            {#each singers as singer}
              <option value={singer}>{singer}</option>
            {/each}
          </select>
        </label>

        <!-- Genre Filter -->
        <label class="label">
          <span class="font-semibold mb-2">Genre</span>
          <select class="select" bind:value={genreFilter}>
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
    <div class="space-y-2 ">
      {#each filtered as song (song.id)}
        <button
          type="button"
          draggable="true"
          on:dragstart={(event) => event.dataTransfer.setData('text/plain', song.id)}
          class="card rounded-sm song-item w-full text-surface-900 dark:text-surface-950  transition-all duration-200 hover:scale-[1.01] cursor-grab active:cursor-grabbing {open.has(song.id) ? 'ring-2 ring-primary-500' : ''} py-0"
          style="background-color:{getColorBySinger(song.singer_lead_short)}"

        >
          <div class="p-3 py-2">
            <!-- Header -->
            <div>
            <div class="flex justify-between items-start gap-3 ">
              <div class="flex-grow min-w-0 text-left">
                <p class=" text-base leading-tight">{song.title} - <span class="text-sm opacity-70">{song.interpret}</span></p>

              </div>
              <div class=" btn btn-sm variant-filled-primary flex-shrink-0 py-0" on:click={() => addSongToSetListEnd(song.id)}>
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"></path>
                    </svg>
              </div>
              <div class=" btn btn-sm py-0 variant-filled-secondary flex-shrink-0 transition-transform duration-200 {open.has(song.id) ? 'rotate-180' : ''}" on:click={() => toggleOpen(song.id)}>
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd"></path>
                </svg>
              </div>
            </div>

            <!-- Expanded Details -->
            {#if open.has(song.id)}
              <hr class="!border-t !border-surface-400 dark:!border-surface-600 my-3" />
              <div class="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
                <div><span class="opacity-60">Genre:</span> <span class="font-medium">{song.genre}</span></div>
                <div><span class="opacity-60">Status:</span> <span class="font-medium">{song.status}</span></div>
                <div><span class="opacity-60">Lead:</span> <span class="font-medium">{song.singer_lead_short}</span></div>
                <div><span class="opacity-60">Dauer:</span> <span class="font-medium">{song.duration}</span></div>
                <div><span class="opacity-60">Kommentar:</span> <span class="font-medium">{song.comment}</span></div>
              </div>
            {/if}
          </div>
        </button>
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
  .song-list-container {
    max-height: calc(100vh - 320px);
    min-height: 300px;
    overflow-y: auto;
  }

  .song-item {
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .song-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  }

  .song-item:active {
    transform: scale(0.98);
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
