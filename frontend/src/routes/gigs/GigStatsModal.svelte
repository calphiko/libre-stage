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
  import { getGigStatistics } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { modalState } from '$lib/modalState.js';

  const { showError } = createMessageHelpers();

  let { parent = {}, meta = {} } = $props();
  const { gigId, gigName } = meta;

  let statistics = $state(null);
  let loading = $state(true);
  let error = $state('');

  const feedbackEmoji = { 3: '😊', 2: '😐', 1: '😞' };

  function feedbackLabel(avg) {
    if (avg == null) return '–';
    if (avg >= 2.5) return '😊';
    if (avg >= 1.5) return '😐';
    return '😞';
  }

  onMount(async () => {
    try {
      statistics = await getGigStatistics(gigId);
    } catch (e) {
      error = e.message;
      showError(e.message);
    } finally {
      loading = false;
    }
  });
</script>

<div class="card p-6 space-y-4 w-[80vw] max-w-3xl max-h-[90vh] flex flex-col modal-base">
  <!-- Header -->
  <header class="flex justify-between items-center flex-shrink-0">
    <h2 class="h3">📈 {gigName ?? 'Gig-Statistik'}</h2>
    <button class="btn-icon btn-icon-sm variant-ghost" onclick={() => modalState.close()}>✕</button>
  </header>

  <!-- Content -->
  <div class="overflow-y-auto flex-grow min-h-0 space-y-5 pr-1">

    {#if loading}
      <div class="flex justify-center py-12">
        <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
      </div>

    {:else if error}
      <div class="alert variant-filled-error">
        <p>{error}</p>
      </div>

    {:else if statistics}

      <!-- Übersichtskacheln -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="card variant-ghost-primary p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-primary-500">{statistics.song_count}</div>
          <div class="text-xs text-on-surface-variant">Songs</div>
        </div>
        <div class="card variant-ghost-warning p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-warning-500">{statistics.skipped_count}</div>
          <div class="text-xs text-on-surface-variant">⏭ Übersprungen</div>
        </div>
        <div class="card variant-ghost-surface p-3 text-center rounded-lg">
          <div class="text-2xl font-bold">{statistics.inserted_count}</div>
          <div class="text-xs text-on-surface-variant">📌 Eingeschoben</div>
        </div>
        <div class="card variant-ghost-surface p-3 text-center rounded-lg">
          {#if statistics.feedback_avg != null}
            <div class="text-2xl font-bold">{feedbackLabel(statistics.feedback_avg)}</div>
            <div class="text-xs text-on-surface-variant">Ø {statistics.feedback_avg}</div>
          {:else}
            <div class="text-2xl font-bold text-surface-400">–</div>
            <div class="text-xs text-on-surface-variant">Ø Feedback</div>
          {/if}
        </div>
      </div>

      <!-- Live-Feedback-Balkendiagramm -->
      {#if statistics.feedback_count > 0}
        <div class="card variant-ghost-surface p-4 rounded-lg">
          <h4 class="text-xs font-semibold text-on-surface-variant mb-3">⭐ Live-Bewertungen ({statistics.feedback_count} gesamt)</h4>
          <div class="space-y-2">
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
                <span class="w-20 text-right text-xs text-on-surface-variant">{count}× ({pct}%)</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}

      <!-- Genre-Verteilung -->
      {#if Object.keys(statistics.genre_distribution).length > 0}
        {@const genreTotal = Object.values(statistics.genre_distribution).reduce((a, b) => a + b, 0)}
        {@const genresSorted = Object.entries(statistics.genre_distribution).sort((a, b) => b[1] - a[1])}
        <div class="card variant-ghost-surface p-4 rounded-lg">
          <h4 class="text-xs font-semibold text-on-surface-variant mb-3">🎸 Genres</h4>
          <div class="space-y-2">
            {#each genresSorted as [genre, count]}
              {@const pct = Math.round((count / genreTotal) * 100)}
              <div class="flex items-center gap-2 text-sm">
                <span class="w-24 truncate text-xs text-on-surface-variant flex-shrink-0">{genre}</span>
                <div class="flex-grow bg-surface-300 dark:bg-surface-700 rounded-full h-3">
                  <div
                    class="h-3 rounded-full bg-tertiary-500 transition-all"
                    style="width: {pct}%"
                  ></div>
                </div>
                <span class="w-20 text-right text-xs text-on-surface-variant flex-shrink-0">{count}× ({pct}%)</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}

      <!-- Set-Sektionen -->
      {#if statistics.sets.length > 0}
        {#each statistics.sets as set}
          <div class="card variant-ghost-surface p-4 rounded-lg">
            <!-- Set-Header -->
            <div class="flex items-center justify-between mb-3">
              <h4 class="text-sm font-semibold">{set.set_name}</h4>
              {#if set.feedback_avg != null}
                <span class="text-xs text-on-surface-variant">
                  Ø {feedbackLabel(set.feedback_avg)} {set.feedback_avg}
                </span>
              {:else}
                <span class="text-xs text-on-surface-variant">Kein Feedback</span>
              {/if}
            </div>

            <!-- Song-Tabelle -->
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-surface-300 dark:border-surface-700">
                    <th class="text-right py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-8">#</th>
                    <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Titel</th>
                    <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold hidden sm:table-cell">Interpret</th>
                    <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-10">⭐</th>
                    <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-10"></th>
                  </tr>
                </thead>
                <tbody>
                  {#each set.songs as song}
                    <tr class="border-b border-surface-200 dark:border-surface-800 last:border-0
                      {song.uebersprungen ? 'opacity-50' : ''}">
                      <td class="py-1.5 px-2 text-right text-xs text-on-surface-variant">{song.position}</td>
                      <td class="py-1.5 px-2 font-medium max-w-[180px] truncate">
                        {song.title}
                        {#if song.uebersprungen}
                          <span class="text-xs text-warning-500 ml-1" title="Übersprungen">⏭</span>
                        {/if}
                        {#if song.eingeschoben}
                          <span class="text-xs text-secondary-500 ml-1" title="Eingeschoben">📌</span>
                        {/if}
                      </td>
                      <td class="py-1.5 px-2 text-xs text-on-surface-variant hidden sm:table-cell">{song.interpret}</td>
                      <td class="py-1.5 px-2 text-center">
                        {#if song.feedback != null}
                          <span title={song.feedback === 3 ? 'Gut' : song.feedback === 2 ? 'Mittel' : 'Schlecht'}>
                            {feedbackEmoji[song.feedback]}
                          </span>
                        {:else}
                          <span class="text-xs text-surface-400">–</span>
                        {/if}
                      </td>
                      <td class="py-1.5 px-2 text-center"></td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/each}
      {:else}
        <div class="card variant-ghost-surface p-6 rounded-lg text-center">
          <p class="text-sm text-on-surface-variant">Noch keine Setliste für diesen Gig vorhanden.</p>
        </div>
      {/if}

    {/if}
  </div>

  <!-- Footer -->
  <footer class="flex justify-end pt-2 flex-shrink-0 border-t border-surface-300 dark:border-surface-700">
    <button class="btn variant-ghost" onclick={() => modalState.close()}>Schließen</button>
  </footer>
</div>

