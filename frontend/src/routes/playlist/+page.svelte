<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
-->

<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import {
    getPlaylistConfig,
    getPlaylistSongs,
    addPlaylistSong,
    deletePlaylistSong,
    ratePlaylistSong,
    deletePlaylistRating,
    searchStreamingTracks,
    triggerPlaylistSync,
  } from '$lib/api.js';
  import { getUser } from '$lib/api.js';
  import { toastState } from '$lib/toast.js';

  // ── State ──────────────────────────────────────────────────────────────────
  let user = $state({ user_name: null, user_group: null });
  let config = $state({ enabled: false, spotify_enabled: false, tidal_enabled: false, min_rating_for_sync: 3.5 });
  let songs = $state([]);
  let loading = $state(true);
  let syncing = $state(false);

  // Propose modal
  let showProposeModal = $state(false);
  let searchQuery = $state('');
  let searchPlatform = $state('spotify');
  let searchResults = $state([]);
  let searching = $state(false);
  let selectedResult = $state(null);
  let manualTitle = $state('');
  let manualArtist = $state('');
  let manualAlbum = $state('');
  let proposeMode = $state('search'); // 'search' | 'manual'

  // Rating modal
  let ratingModalSong = $state(null);
  let pendingRating = $state(0);
  let pendingComment = $state('');

  // ── Helpers ────────────────────────────────────────────────────────────────
  function starLabel(n) {
    return n === 1 ? '⭐' : n === 2 ? '⭐⭐' : n === 3 ? '⭐⭐⭐' : n === 4 ? '⭐⭐⭐⭐' : '⭐⭐⭐⭐⭐';
  }

  function syncBadge(song) {
    const badges = [];
    if (config.spotify_enabled) badges.push(song.is_synced_spotify ? '🟢 Spotify' : '⚫ Spotify');
    if (config.tidal_enabled) badges.push(song.is_synced_tidal ? '🟢 Tidal' : '⚫ Tidal');
    return badges.join('  ');
  }

  // ── Data loading ──────────────────────────────────────────────────────────���
  async function loadData() {
    loading = true;
    try {
      [config, songs, user] = await Promise.all([
        getPlaylistConfig(),
        getPlaylistSongs(),
        getUser(),
      ]);
      if (!config.enabled) {
        goto('/dashboard');
        return;
      }
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      loading = false;
    }
  }

  onMount(loadData);

  // ── Search & propose ───────────────────────────────────────────────────────
  async function doSearch() {
    if (!searchQuery.trim()) return;
    searching = true;
    searchResults = [];
    try {
      searchResults = await searchStreamingTracks(searchQuery.trim(), searchPlatform);
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      searching = false;
    }
  }

  function selectResult(r) {
    selectedResult = r;
  }

  async function proposeSelected() {
    const data = selectedResult
      ? {
          title: selectedResult.title,
          artist: selectedResult.artist,
          album: selectedResult.album,
          isrc: selectedResult.isrc,
          spotify_track_id: selectedResult.spotify_track_id,
          tidal_track_id: selectedResult.tidal_track_id,
          cover_url: selectedResult.cover_url,
        }
      : {
          title: manualTitle.trim(),
          artist: manualArtist.trim(),
          album: manualAlbum.trim(),
        };

    if (!data.title || !data.artist) {
      toastState.show('Titel und Interpret sind erforderlich', 'warning');
      return;
    }
    try {
      await addPlaylistSong(data);
      toastState.show('Song vorgeschlagen ✓', 'success');
      showProposeModal = false;
      resetPropose();
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  function resetPropose() {
    searchQuery = '';
    searchResults = [];
    selectedResult = null;
    manualTitle = '';
    manualArtist = '';
    manualAlbum = '';
    proposeMode = 'search';
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  async function removeSong(song) {
    if (!confirm(`"${song.title}" wirklich entfernen?`)) return;
    try {
      await deletePlaylistSong(song.id);
      toastState.show('Song entfernt', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  // ── Rating ─────────────────────────────────────────────────────────────────
  function openRating(song) {
    ratingModalSong = song;
    pendingRating = song.my_rating ?? 0;
    pendingComment = song.my_comment ?? '';
  }

  async function submitRating() {
    if (!pendingRating) {
      toastState.show('Bitte Bewertung auswählen', 'warning');
      return;
    }
    try {
      await ratePlaylistSong(ratingModalSong.id, pendingRating, pendingComment || null);
      toastState.show('Bewertung gespeichert ✓', 'success');
      ratingModalSong = null;
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  async function removeRating(song) {
    try {
      await deletePlaylistRating(song.id);
      toastState.show('Bewertung entfernt', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    }
  }

  // ── Sync ───────────────────────────────────────────────────────────────────
  async function doSync() {
    syncing = true;
    try {
      const result = await triggerPlaylistSync();
      const parts = [];
      for (const [platform, r] of Object.entries(result)) {
        if (r.status === 'error') {
          parts.push(`${platform}: ❌ ${r.message}`);
        } else {
          parts.push(`${platform}: +${r.added} / -${r.removed}`);
        }
      }
      toastState.show(parts.join(' | ') || 'Sync abgeschlossen', 'success');
      await loadData();
    } catch (e) {
      toastState.show(e.message, 'error');
    } finally {
      syncing = false;
    }
  }
</script>

<svelte:head><title>Playlist</title></svelte:head>

{#if loading}
  <div class="flex items-center justify-center h-40">
    <span class="text-surface-500">Lade Playlist…</span>
  </div>
{:else}

<div class="max-w-4xl mx-auto p-4 space-y-4">

  <!-- Header -->
  <div class="flex flex-wrap items-center justify-between gap-2">
    <h1 class="text-xl font-bold">🎵 Inspiration-Playlist</h1>
    <div class="flex gap-2 flex-wrap">
      {#if user.user_group === 'admin'}
        <button
          class="ui-btn ui-btn-secondary text-sm"
          onclick={() => goto('/admin/streaming')}
        >⚙ Streaming-Einstellungen</button>
        <button
          class="ui-btn ui-btn-secondary text-sm"
          onclick={doSync}
          disabled={syncing}
        >{syncing ? 'Sync…' : '🔄 Jetzt syncen'}</button>
      {/if}
      <button class="ui-btn ui-btn-primary text-sm" onclick={() => showProposeModal = true}>
        + Song vorschlagen
      </button>
    </div>
  </div>

  <!-- Info banner -->
  <p class="text-sm text-surface-500">
    Songs mit Ø-Bewertung ≥ {config.min_rating_for_sync} ⭐ werden automatisch synchronisiert.
    {#if config.spotify_enabled}🟢 Spotify{/if}
    {#if config.tidal_enabled}&nbsp;🟢 Tidal{/if}
  </p>

  <!-- Song list -->
  {#if songs.length === 0}
    <div class="text-center py-16 text-surface-400">
      <p class="text-4xl mb-3">🎶</p>
      <p>Noch keine Songs vorgeschlagen.</p>
      <button class="ui-btn ui-btn-primary mt-4" onclick={() => showProposeModal = true}>Ersten Song vorschlagen</button>
    </div>
  {:else}
    <div class="space-y-3">
      {#each songs as song (song.id)}
        <div class="bg-surface-100 dark:bg-surface-800 rounded-xl p-4 flex gap-4 shadow-sm">
          <!-- Cover -->
          {#if song.cover_url}
            <img src={song.cover_url} alt="Cover" class="w-14 h-14 rounded-lg object-cover flex-shrink-0" />
          {:else}
            <div class="w-14 h-14 rounded-lg bg-surface-200 dark:bg-surface-700 flex items-center justify-center flex-shrink-0 text-2xl">🎵</div>
          {/if}

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <div class="font-semibold truncate">{song.title}</div>
            <div class="text-sm text-surface-500 truncate">{song.artist}{song.album ? ` · ${song.album}` : ''}</div>
            <div class="text-xs text-surface-400 mt-0.5">von {song.proposed_by}</div>

            <!-- Sync badges -->
            {#if config.spotify_enabled || config.tidal_enabled}
              <div class="text-xs mt-1 text-surface-400">{syncBadge(song)}</div>
            {/if}
          </div>

          <!-- Rating summary -->
          <div class="flex flex-col items-end justify-between gap-1 flex-shrink-0">
            <div class="text-center">
              <div class="text-lg font-bold">{song.avg_rating ?? '–'}</div>
              <div class="text-xs text-surface-400">{song.rating_count} Bew.</div>
            </div>

            <!-- Own rating -->
            <div class="flex gap-1">
              {#if song.my_rating}
                <button
                  class="ui-btn ui-btn-ghost text-xs"
                  onclick={() => openRating(song)}
                  title="Bewertung ändern"
                >{'⭐'.repeat(song.my_rating)}</button>
                <button
                  class="ui-btn ui-btn-ghost text-xs text-red-500"
                  onclick={() => removeRating(song)}
                  title="Bewertung entfernen"
                >✕</button>
              {:else}
                <button
                  class="ui-btn ui-btn-secondary text-xs"
                  onclick={() => openRating(song)}
                >Bewerten</button>
              {/if}

              {#if user.user_group === 'admin' || song.proposed_by_id === user.id}
                <button
                  class="ui-btn ui-btn-ghost text-xs text-red-500"
                  onclick={() => removeSong(song)}
                  title="Song entfernen"
                >🗑</button>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<!-- ── Propose Modal ──────────────────────────────────────────────────────── -->
{#if showProposeModal}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={(e) => { if (e.target === e.currentTarget) { showProposeModal = false; resetPropose(); } }}>
    <div class="bg-surface-50 dark:bg-surface-900 rounded-2xl shadow-xl w-full max-w-lg p-6 space-y-4">
      <h2 class="text-lg font-bold">🎵 Song vorschlagen</h2>

      <!-- Mode toggle -->
      <div class="flex gap-2">
        <button
          class="ui-btn text-sm {proposeMode === 'search' ? 'ui-btn-primary' : 'ui-btn-ghost'}"
          onclick={() => proposeMode = 'search'}
        >Suchen</button>
        <button
          class="ui-btn text-sm {proposeMode === 'manual' ? 'ui-btn-primary' : 'ui-btn-ghost'}"
          onclick={() => proposeMode = 'manual'}
        >Manuell eingeben</button>
      </div>

      {#if proposeMode === 'search'}
        <!-- Platform selector -->
        {#if config.spotify_enabled || config.tidal_enabled}
          <div class="flex gap-2">
            {#if config.spotify_enabled}
              <button
                class="ui-btn text-sm {searchPlatform === 'spotify' ? 'ui-btn-primary' : 'ui-btn-ghost'}"
                onclick={() => searchPlatform = 'spotify'}
              >Spotify</button>
            {/if}
            {#if config.tidal_enabled}
              <button
                class="ui-btn text-sm {searchPlatform === 'tidal' ? 'ui-btn-primary' : 'ui-btn-ghost'}"
                onclick={() => searchPlatform = 'tidal'}
              >Tidal</button>
            {/if}
          </div>
        {/if}

        <!-- Search input -->
        <div class="flex gap-2">
          <input
            type="text"
            class="ui-input flex-1 text-sm"
            placeholder="Titel oder Interpret suchen…"
            bind:value={searchQuery}
            onkeydown={(e) => e.key === 'Enter' && doSearch()}
          />
          <button class="ui-btn ui-btn-primary text-sm" onclick={doSearch} disabled={searching}>
            {searching ? '…' : '🔍'}
          </button>
        </div>

        <!-- Results -->
        {#if searchResults.length > 0}
          <div class="space-y-2 max-h-56 overflow-y-auto">
            {#each searchResults as r}
              <button
                class="w-full text-left p-3 rounded-lg border-2 transition-colors
                  {selectedResult === r
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/30'
                    : 'border-surface-200 dark:border-surface-700 hover:border-primary-300'}"
                onclick={() => selectResult(r)}
              >
                <div class="font-medium text-sm">{r.title}</div>
                <div class="text-xs text-surface-500">{r.artist}{r.album ? ` · ${r.album}` : ''}</div>
                {#if r.isrc}<div class="text-xs text-surface-400">ISRC: {r.isrc}</div>{/if}
              </button>
            {/each}
          </div>
        {:else if !searching && searchQuery}
          <p class="text-sm text-surface-400 text-center py-2">Keine Ergebnisse</p>
        {/if}

        {#if !config.spotify_enabled && !config.tidal_enabled}
          <p class="text-sm text-amber-600 dark:text-amber-400">
            ⚠ Kein Streaming-Dienst verbunden – bitte manuell eingeben.
          </p>
        {/if}
      {:else}
        <!-- Manual entry -->
        <div class="space-y-2">
          <input class="ui-input w-full text-sm" placeholder="Titel *" bind:value={manualTitle} />
          <input class="ui-input w-full text-sm" placeholder="Interpret *" bind:value={manualArtist} />
          <input class="ui-input w-full text-sm" placeholder="Album (optional)" bind:value={manualAlbum} />
        </div>
      {/if}

      <!-- Actions -->
      <div class="flex justify-end gap-2 pt-1">
        <button class="ui-btn ui-btn-ghost text-sm" onclick={() => { showProposeModal = false; resetPropose(); }}>
          Abbrechen
        </button>
        <button
          class="ui-btn ui-btn-primary text-sm"
          disabled={proposeMode === 'search' ? !selectedResult : !manualTitle || !manualArtist}
          onclick={proposeSelected}
        >
          Vorschlagen
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ── Rating Modal ───────────────────────────────────────────────────────── -->
{#if ratingModalSong}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" onclick={(e) => { if (e.target === e.currentTarget) ratingModalSong = null; }}>
    <div class="bg-surface-50 dark:bg-surface-900 rounded-2xl shadow-xl w-full max-w-sm p-6 space-y-4">
      <h2 class="text-lg font-bold">Bewertung</h2>
      <p class="text-sm text-surface-500">"{ratingModalSong.title}" von {ratingModalSong.artist}</p>

      <!-- Stars -->
      <div class="flex gap-2 justify-center text-3xl">
        {#each [1,2,3,4,5] as star}
          <button
            class="transition-transform hover:scale-110 {pendingRating >= star ? 'text-yellow-400' : 'text-surface-300'}"
            onclick={() => pendingRating = star}
          >★</button>
        {/each}
      </div>
      {#if pendingRating}
        <p class="text-center text-sm text-surface-500">{starLabel(pendingRating)}</p>
      {/if}

      <!-- Comment -->
      <textarea
        class="ui-input w-full text-sm resize-none"
        rows="2"
        placeholder="Kommentar (optional)"
        bind:value={pendingComment}
      ></textarea>

      <div class="flex justify-end gap-2">
        <button class="ui-btn ui-btn-ghost text-sm" onclick={() => ratingModalSong = null}>Abbrechen</button>
        <button class="ui-btn ui-btn-primary text-sm" onclick={submitRating} disabled={!pendingRating}>
          Speichern
        </button>
      </div>
    </div>
  </div>
{/if}

{/if}



