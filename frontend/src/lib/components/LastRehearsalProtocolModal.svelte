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
  import { onMount } from 'svelte';
  import { getRehearsalList } from '$lib/api.js';

  let { parent = {}, meta = {} } = $props();

  const {
    songId,
    songTitle = '',
    songInterpret = '',
    currentRehearsalId = null,
    currentRehearsalBegin = null,
    users = []
  } = meta;

  let loading = $state(true);
  let error = $state('');
  let rehearsal = $state(null);
  let songEntry = $state(null);

  function getUserName(userId) {
    const user = users.find((u) => u.id === userId);
    return user?.clear_name || user?.user_name || 'Unbekannt';
  }

  function formatDateTime(dateLike) {
    if (!dateLike) return '-';
    const dt = new Date(dateLike);
    return dt.toLocaleDateString('de-DE', {
      weekday: 'long',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    }) + ' ' + dt.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }) + ' Uhr';
  }

  onMount(async () => {
    try {
      const rehearsalList = await getRehearsalList();
      const currentBegin = currentRehearsalBegin ? new Date(currentRehearsalBegin) : null;

      const candidates = (rehearsalList || [])
        .filter((reh) => reh.id !== currentRehearsalId)
        .filter((reh) => reh.songs?.some((s) => s.id_song === songId))
        .filter((reh) => {
          if (!currentBegin || Number.isNaN(currentBegin.getTime())) return true;
          return new Date(reh.begin) < currentBegin;
        })
        .sort((a, b) => new Date(b.begin) - new Date(a.begin));

      if (candidates.length === 0) {
        rehearsal = null;
        songEntry = null;
        return;
      }

      rehearsal = candidates[0];
      songEntry = rehearsal.songs.find((s) => s.id_song === songId) ?? null;
    } catch (e) {
      error = e?.message ?? 'Protokoll konnte nicht geladen werden';
      console.error('LastRehearsalProtocolModal load error:', e);
    } finally {
      loading = false;
    }
  });
</script>

<div class="card p-6 max-w-3xl w-[90vw] max-h-[90vh] flex flex-col modal-base">
  <header class="flex justify-between items-start mb-4 flex-shrink-0 gap-4">
    <div>
      <h2 class="h3">Letzte Probe mit diesem Song</h2>
      <p class="text-sm text-on-surface-variant">{songInterpret} - {songTitle}</p>
    </div>
    <button class="btn-icon btn-icon-sm variant-ghost" onclick={() => parent?.close()}>✕</button>
  </header>

  {#if loading}
    <div class="flex justify-center items-center py-12 flex-grow">
      <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
    </div>
  {:else if error}
    <div class="alert variant-filled-error flex-grow">
      <p>{error}</p>
    </div>
  {:else if !rehearsal || !songEntry}
    <div class="flex-grow text-sm text-on-surface-variant py-4">
      Für diesen Song wurde vor der aktuellen Probe noch kein Protokoll gefunden.
    </div>
  {:else}
    <div class="overflow-y-auto flex-grow min-h-0 space-y-4">
      <div class="card variant-ghost-surface p-3 rounded-lg">
        <div class="flex items-center justify-between">
          <span class="font-semibold">Probe</span>
          <span class="text-sm">{formatDateTime(rehearsal.begin)}</span>
        </div>
      </div>

      <div class="space-y-3">
        <div>
          <span class="text-xs font-semibold text-on-surface-variant">Song-Status</span>
          <div class="mt-1">
            {#if songEntry.done}
              <span class="badge variant-soft-success text-xs">✓ erledigt</span>
            {:else}
              <span class="badge variant-soft-warning text-xs">⏳ offen</span>
            {/if}
          </div>
        </div>

        <div>
          <span class="text-xs font-semibold text-on-surface-variant">Todo (allgemein)</span>
          <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1 whitespace-pre-wrap">{songEntry.todo || 'Kein Todo hinterlegt.'}</p>
        </div>

        <div>
          <span class="text-xs font-semibold text-on-surface-variant">Proben-Kommentar</span>
          <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1 whitespace-pre-wrap">{songEntry.comment || 'Kein Proben-Kommentar hinterlegt.'}</p>
        </div>

        <div>
          <span class="text-xs font-semibold text-on-surface-variant">Setlist-Kommentar</span>
          <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1 whitespace-pre-wrap">{songEntry.setlist_comment || 'Kein Setlist-Kommentar hinterlegt.'}</p>
        </div>

        <div>
          <span class="text-xs font-semibold text-on-surface-variant">Persoenliche Todos</span>
          {#if (songEntry.song_todos ?? []).length === 0}
            <p class="text-sm bg-surface-200 dark:bg-surface-700 rounded p-2 mt-1">Keine persoenlichen Todos hinterlegt.</p>
          {:else}
            <ul class="mt-1 space-y-1">
              {#each songEntry.song_todos as t}
                <li class="flex items-center gap-2 text-sm bg-surface-200 dark:bg-surface-700 rounded px-2 py-1">
                  <span class="{t.done ? 'text-success-500' : 'text-warning-500'}">{t.done ? '✔' : '⏳'}</span>
                  <span class="font-medium">{getUserName(t.id_user)}:</span>
                  <span class:line-through={t.done}>{t.todo}</span>
                </li>
              {/each}
            </ul>
          {/if}
        </div>

        {#if rehearsal.comment}
          <details class="mt-2">
            <summary class="text-xs text-on-surface-variant cursor-pointer hover:text-primary-500">
              Allgemeiner Proben-Kommentar anzeigen
            </summary>
            <p class="text-xs bg-surface-100 dark:bg-surface-800 rounded p-2 mt-1 whitespace-pre-wrap">{rehearsal.comment}</p>
          </details>
        {/if}
      </div>
    </div>
  {/if}

  <footer class="flex gap-2 justify-end pt-4 mt-2 flex-shrink-0 border-t border-surface-300">
    <button class="btn variant-ghost" onclick={() => parent?.close()}>Schliessen</button>
  </footer>
</div>

