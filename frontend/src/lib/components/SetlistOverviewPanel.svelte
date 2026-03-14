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
  import { tick } from 'svelte';

  let { allSongs = [], currentIndex = 0, onJump, onClose, open = false } = $props();

  // Gruppiere Songs nach Set-Name
  let groupedSets = $derived(() => {
    const sets = [];
    let currentSet = null;
    for (let i = 0; i < allSongs.length; i++) {
      const song = allSongs[i];
      if (!currentSet || currentSet.name !== song.setName) {
        currentSet = { name: song.setName, songs: [] };
        sets.push(currentSet);
      }
      currentSet.songs.push({ ...song, globalIndex: i });
    }
    return sets;
  });

  // Ref auf das aktive Element zum Scrollen
  let activeElement = $state(null);

  $effect(() => {
    if (open && activeElement) {
      tick().then(() => {
        activeElement?.scrollIntoView({ block: 'center' });
      });
    }
  });

  function handleJump(index) {
    onJump?.(index);
    onClose?.();
  }

  function feedbackEmoji(feedback) {
    if (feedback === 1) return '😐';
    if (feedback === 2) return '🙂';
    if (feedback === 3) return '😍';
    return null;
  }

  function setActiveRef(node, isActive) {
    if (isActive) activeElement = node;
    return {
      update(newIsActive) {
        if (newIsActive) activeElement = node;
      },
      destroy() {
        if (activeElement === node) activeElement = null;
      }
    };
  }

  // Fortschritts-Zähler pro Set
  function setStats(songs) {
    const done = songs.filter(s => s.uebersprungen || (s.feedback !== null && s.feedback !== undefined)).length;
    return { done, total: songs.length };
  }
</script>

<!-- Backdrop -->
<div
  class="absolute inset-0 z-10 flex {open ? '' : 'pointer-events-none'}"
  role="presentation"
>
  <!-- Klickbarer Backdrop -->
  <button
    class="flex-1 cursor-default transition-opacity duration-300 {open ? 'bg-black/40 opacity-100' : 'opacity-0'}"
    onclick={onClose}
    aria-label="Panel schließen"
    tabindex="-1"
  ></button>

  <!-- Panel -->
  <div
    class="no-swipe w-full sm:w-80 h-full flex flex-col bg-surface-100 dark:bg-surface-800 shadow-2xl overflow-hidden
           transform transition-transform duration-300 {open ? 'translate-x-0' : 'translate-x-full'}"
  >
    <!-- Panel Header -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-surface-300 dark:border-surface-600 flex-shrink-0">
      <div>
        <h3 class="font-bold text-base">📋 Setliste</h3>
        <p class="text-xs text-surface-500 dark:text-surface-400">
          {allSongs.filter(s => s.uebersprungen || (s.feedback !== null && s.feedback !== undefined)).length}
          / {allSongs.length} Songs abgeschlossen
        </p>
      </div>
      <button
        class="btn-icon btn-icon-sm variant-ghost"
        onclick={onClose}
        aria-label="Setlisten-Übersicht schließen"
      >
        ✕
      </button>
    </div>

    <!-- Song-Liste -->
    <div class="flex-1 overflow-y-auto py-2">
      {#each groupedSets() as set}
        {@const stats = setStats(set.songs)}
        <!-- Set-Überschrift -->
        <div class="sticky top-0 z-10 px-4 py-1.5 bg-surface-200 dark:bg-surface-700 border-b border-surface-300 dark:border-surface-600 flex items-center justify-between">
          <span class="text-xs font-bold uppercase tracking-wide text-surface-600 dark:text-surface-300">
            {set.name}
          </span>
          <span class="text-xs text-surface-500 dark:text-surface-400">
            {stats.done}/{stats.total}
          </span>
        </div>

        <!-- Songs des Sets -->
        {#each set.songs as song}
          {@const isActive = song.globalIndex === currentIndex}
          {@const isDone = song.uebersprungen || (song.feedback !== null && song.feedback !== undefined)}
          <button
            class="w-full text-left px-4 py-2.5 flex items-center gap-3 transition-colors
                   {isActive
                     ? 'bg-primary-100 dark:bg-primary-900/40 ring-2 ring-inset ring-primary-500'
                     : 'hover:bg-surface-200 dark:hover:bg-surface-700'}
                   {isDone && !isActive ? 'opacity-60' : ''}"
            onclick={() => handleJump(song.globalIndex)}
            use:setActiveRef={isActive}
          >
            <!-- Positionsnummer -->
            <span class="text-xs text-surface-400 dark:text-surface-500 w-5 text-right flex-shrink-0 font-mono">
              {song.songIndex + 1}
            </span>

            <!-- Song-Info -->
            <div class="flex-1 min-w-0">
              <div class="text-sm font-{isActive ? 'bold' : 'medium'} truncate {isActive ? 'text-primary-700 dark:text-primary-300' : ''}">
                {song.title}
              </div>
              <div class="text-xs text-surface-500 dark:text-surface-400 truncate">
                {song.interpret}{song.tone_key ? ` · ${song.tone_key}` : ''}
              </div>
            </div>

            <!-- Status-Icons -->
            <div class="flex items-center gap-1 flex-shrink-0">
              {#if isActive}
                <span class="text-xs font-bold text-primary-500">▶</span>
              {/if}
              {#if song.eingeschoben}
                <span class="text-xs" title="Spontan eingefügt">➕</span>
              {/if}
              {#if song.uebersprungen}
                <span class="text-xs" title="Übersprungen">⏭️</span>
              {:else if song.feedback}
                <span class="text-sm" title="Feedback gegeben">{feedbackEmoji(song.feedback)}</span>
              {/if}
            </div>
          </button>
        {/each}
      {/each}

      <!-- Leerraum am Ende -->
      <div class="h-4"></div>
    </div>

    <!-- Panel Footer -->
    <div class="flex-shrink-0 px-4 py-2 border-t border-surface-300 dark:border-surface-600 text-xs text-surface-500 dark:text-surface-400 text-center">
      <kbd class="kbd kbd-sm">L</kbd> Schließen · Klick zum Springen
    </div>
  </div>
</div>




