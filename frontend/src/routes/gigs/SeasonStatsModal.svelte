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
  import { getSeasonStatistics } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { modalState } from '$lib/modalState.js';

  const { showError } = createMessageHelpers();

  let { parent = {}, meta = {} } = $props();
  const { jahr } = meta;

  let statistics = $state(null);
  let loading = $state(true);
  let error = $state('');

  const feedbackEmoji = { 3: '😊', 2: '😐', 1: '😞' };

  function formatDate(isoString) {
    if (!isoString) return '–';
    return new Date(isoString).toLocaleDateString('de-DE');
  }

  onMount(async () => {
    try {
      statistics = await getSeasonStatistics(jahr);
    } catch (e) {
      error = e.message;
      showError(e.message);
    } finally {
      loading = false;
    }
  });
</script>

<div class="card p-6 space-y-4 w-[80vw] max-w-3xl max-h-[90vh] flex flex-col">
  <!-- Header -->
  <header class="flex justify-between items-center flex-shrink-0">
    <h2 class="h3">📊 Saisonstatistik {jahr ? jahr : 'Alle Jahre'}</h2>
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
      <div class="grid grid-cols-3 md:grid-cols-6 gap-3">
        <div class="card variant-ghost-primary p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-primary-500">{statistics.gig_count}</div>
          <div class="text-xs text-on-surface-variant">Gigs</div>
        </div>
        <div class="card variant-ghost-secondary p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-secondary-500">{statistics.total_songs}</div>
          <div class="text-xs text-on-surface-variant">Songs gesamt</div>
        </div>
        <div class="card variant-ghost-tertiary p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-tertiary-500">{statistics.unique_songs}</div>
          <div class="text-xs text-on-surface-variant">Unique Songs</div>
        </div>
        <div class="card variant-ghost-warning p-3 text-center rounded-lg">
          <div class="text-2xl font-bold text-warning-500">{statistics.skipped_count}</div>
          <div class="text-xs text-on-surface-variant">Übersprungen</div>
        </div>
        <div class="card variant-ghost-surface p-3 text-center rounded-lg">
          <div class="text-2xl font-bold">{statistics.inserted_count}</div>
          <div class="text-xs text-on-surface-variant">Eingeschoben</div>
        </div>
        <div class="card variant-ghost-surface p-3 text-center rounded-lg">
          {#if statistics.feedback_avg != null}
            <div class="text-2xl font-bold">
              {statistics.feedback_avg >= 2.5 ? '😊' : statistics.feedback_avg >= 1.5 ? '😐' : '😞'}
            </div>
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

      <!-- Top Songs -->
      {#if statistics.top_songs.length > 0}
        <div class="card variant-ghost-surface p-4 rounded-lg">
          <h4 class="text-xs font-semibold text-on-surface-variant mb-3">🏆 Meistgespielte Songs</h4>
          <div class="space-y-1">
            {#each statistics.top_songs as song, i}
              <div class="flex items-center justify-between text-sm py-1.5 border-b border-surface-300 dark:border-surface-700 last:border-0">
                <div class="flex items-center gap-2 min-w-0">
                  <span class="text-xs font-bold text-on-surface-variant w-5 text-right flex-shrink-0">
                    {i + 1}.
                  </span>
                  <div class="min-w-0">
                    <span class="font-medium truncate block">{song.title}</span>
                    <span class="text-xs text-on-surface-variant">{song.interpret}</span>
                  </div>
                </div>
                <span class="badge variant-soft-primary text-xs flex-shrink-0 ml-2">{song.count}×</span>
              </div>
            {/each}
          </div>
        </div>
      {/if}

      <!-- Gig-Übersicht -->
      {#if statistics.gigs_overview.length > 0}
        <div class="card variant-ghost-surface p-4 rounded-lg">
          <h4 class="text-xs font-semibold text-on-surface-variant mb-3">🎤 Gig-Übersicht</h4>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-surface-300 dark:border-surface-700">
                  <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Datum</th>
                  <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Name</th>
                  <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Songs</th>
                  <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold">⏭</th>
                  <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold">📌</th>
                  <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Ø ⭐</th>
                </tr>
              </thead>
              <tbody>
                {#each statistics.gigs_overview as gig}
                  <tr class="border-b border-surface-200 dark:border-surface-800 hover:bg-surface-200 dark:hover:bg-surface-700 transition-colors">
                    <td class="py-1.5 px-2 text-xs text-on-surface-variant whitespace-nowrap">{formatDate(gig.gig_date)}</td>
                    <td class="py-1.5 px-2 font-medium max-w-[200px] truncate">{gig.gig_name}</td>
                    <td class="py-1.5 px-2 text-center">{gig.song_count}</td>
                    <td class="py-1.5 px-2 text-center">
                      {#if gig.skipped_count > 0}
                        <span class="text-error-500">{gig.skipped_count}</span>
                      {:else}
                        <span class="text-surface-400">–</span>
                      {/if}
                    </td>
                    <td class="py-1.5 px-2 text-center">
                      {#if gig.inserted_count > 0}
                        <span class="text-warning-500">{gig.inserted_count}</span>
                      {:else}
                        <span class="text-surface-400">–</span>
                      {/if}
                    </td>
                    <td class="py-1.5 px-2 text-center">
                      {#if gig.feedback_avg != null}
                        <span>{gig.feedback_avg >= 2.5 ? '😊' : gig.feedback_avg >= 1.5 ? '😐' : '😞'} {gig.feedback_avg}</span>
                      {:else}
                        <span class="text-surface-400">–</span>
                      {/if}
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        </div>
      {:else}
        <div class="card variant-ghost-surface p-4 rounded-lg text-center">
          <p class="text-sm text-on-surface-variant">Keine Gigs für diesen Zeitraum gefunden.</p>
        </div>
      {/if}

    {/if}
  </div>

  <!-- Footer -->
  <footer class="flex justify-end pt-2 flex-shrink-0 border-t border-surface-300 dark:border-surface-700">
    <button class="btn variant-ghost" onclick={() => modalState.close()}>Schließen</button>
  </footer>
</div>

