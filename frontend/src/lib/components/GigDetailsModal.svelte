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
  import {
    updateGig,
    getGigSetlistAvailability,
    getSetlistPDF,
    getGemaListFile,
    getGigSchedule,
    getGigSchedulePDF,
    getGigStatistics,
    getGenrePalette
  } from '$lib/api.js';
  import { formatTime } from '$lib/common.js';
  import { getGigFieldsDetails } from '$lib/songFields.js';
  import { appConfig } from '$lib/appConfig.js';
  import { modalState } from '$lib/modalState.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import GigSchedule from '../../routes/gigs/GigSchedule.svelte';
  import GenreDistributionPlot from '$lib/plots/genreDistributionPlot.svelte';
  import FeedbackDistributionPlot from '$lib/plots/feedbackDistributionPlot.svelte';

  const { showError, showSuccess } = createMessageHelpers();

  let { meta = {} } = $props();

  const {
    gig: initialGig = null,
    canEdit = false,
    isAdmin = false,
    liveModeStatus = null,
    onGigUpdated = () => {},
    onDeleteGig = () => {},
    onEditSetlist = () => {},
    onOpenLiveMode = () => {},
    onUnlockLiveMode = () => {}
  } = meta;

  let gigFieldsDetails = $derived(getGigFieldsDetails($appConfig));

  let gig = $state(initialGig ? { ...initialGig } : null);
  let isEditing = $state(false);
  let isSaving = $state(false);
  let editBuffer = $state({});
  let tabSet = $state(0);
  let scheduleLoading = $state(false);
  let scheduleData = $state(null);
  let statsLoading = $state(false);
  let statsError = $state('');
  let statistics = $state(null);
  let genrePalette = $state({});
  let liveMode = $state(liveModeStatus ? { ...liveModeStatus } : null);

  const feedbackEmoji = { 3: '😍', 2: '😊', 1: '😐' };

  function dateToIsoString(date) {
    if (!date) return '';
    const dt = new Date(date);
    if (isNaN(dt)) return date;
    return dt.toISOString().split('T')[0];
  }

  function formatDateDE(isoString) {
    if (!isoString) isoString = dateToIsoString(isoString);
    const dt = new Date(isoString);
    if (isNaN(dt)) return isoString;
    return dt.toLocaleDateString('de-DE');
  }

  function normalizeTimeWithSeconds(value) {
    if (typeof value !== 'string') return value;
    const trimmed = value.trim();
    if (!trimmed) return '';

    const match = trimmed.match(/^(\d{1,2}):(\d{2})(?::(\d{2}))?$/);
    if (!match) return value;

    const hh = match[1].padStart(2, '0');
    const mm = match[2];
    const ss = match[3] ?? '00';
    return `${hh}:${mm}:${ss}`;
  }

  function normalizeGigTimeFields(record) {
    const normalized = { ...record };
    for (const field of gigFieldsDetails) {
      if (field.type === 'time' && normalized[field.key] != null) {
        normalized[field.key] = normalizeTimeWithSeconds(normalized[field.key]);
      }
    }
    return normalized;
  }

  function startEdit() {
    if (!canEdit || !gig) return;
    isEditing = true;
    editBuffer = normalizeGigTimeFields(gig);
  }

  function cancelEdit() {
    isEditing = false;
    editBuffer = {};
  }

  function handleStammdatenEditToggle(event) {
    const checked = !!event?.currentTarget?.checked;
    if (checked) {
      startEdit();
      return;
    }
    cancelEdit();
  }

  async function saveEdit() {
    if (!gig?.id || isSaving) return;

    isSaving = true;
    try {
      const payload = normalizeGigTimeFields(editBuffer);
      const updated = await updateGig(gig.id, payload, null);
      gig = { ...gig, ...payload, ...(updated || {}) };
      onGigUpdated(gig);
      isEditing = false;
      editBuffer = {};
      showSuccess('Gig erfolgreich aktualisiert');
    } catch (e) {
      showError(e.message ?? 'Update fehlgeschlagen');
    } finally {
      isSaving = false;
    }
  }

  function closeAndRun(callback) {
    modalState.close();
    setTimeout(callback, 150);
  }

  function handleDelete() {
    if (!gig) return;
    closeAndRun(() => onDeleteGig(gig));
  }

  function handleEditSetlist() {
    if (!gig?.id) return;
    closeAndRun(() => onEditSetlist(gig.id));
  }

  async function loadSchedule(force = false) {
    if (!gig?.id) return;
    if (scheduleData && !force) return;

    scheduleLoading = true;
    try {
      scheduleData = await getGigSchedule(null, gig.id);
    } catch (e) {
      showError(e.message ?? 'Ablaufplan konnte nicht geladen werden');
    } finally {
      scheduleLoading = false;
    }
  }

  function handleScheduleUpdated(data) {
    scheduleData = data;
  }

  function feedbackLabel(avg) {
    if (avg == null) return '-';
    if (avg >= 2.5) return '😍';
    if (avg >= 1.5) return '😊';
    return '😐';
  }

  function handleOpenLiveMode() {
    if (!gig?.id) return;
    closeAndRun(() => onOpenLiveMode(gig.id));
  }

  async function handleUnlockLiveMode() {
    if (!gig?.id) return;
    try {
      await onUnlockLiveMode(gig.id);
      if (liveMode) {
        liveMode = { ...liveMode, available: true, forced: true };
      } else {
        liveMode = { available: true, forced: true, can_force: false };
      }
      showSuccess('Live Mode wurde entsperrt');
    } catch (e) {
      showError(e.message ?? 'Live Mode konnte nicht entsperrt werden');
    }
  }

  async function exportSchedulePdf() {
    if (!gig?.id) return;
    try {
      const blob = await getGigSchedulePDF(null, gig.id);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `ablaufplan_${gig.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (e) {
      showError(e.message ?? 'Ablaufplan-PDF konnte nicht exportiert werden');
    }
  }

  async function loadStats(force = false) {
    if (!gig?.id) return;
    if (statistics && !force) return;

    statsLoading = true;
    statsError = '';
    try {
      const [stats, paletteOut] = await Promise.all([getGigStatistics(gig.id), getGenrePalette()]);
      statistics = stats;
      genrePalette = paletteOut?.palette ?? {};
    } catch (e) {
      statsError = e.message ?? 'Statistik konnte nicht geladen werden';
      showError(statsError);
    } finally {
      statsLoading = false;
    }
  }

  async function getGemaList() {
    if (!gig?.id) return;

    const setlistAvailability = await getGigSetlistAvailability(null, gig.id);
    if (!setlistAvailability.setlist_available) {
      showError('Fuer diesen Gig ist keine Setliste verfuegbar.');
      return;
    }

    try {
      const blob = await getGemaListFile(null, gig.id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Liedfolge_${gig.name}_${formatDateDE(gig.datum)}.xlsx`;
      a.target = '_blank';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 5000);
    } catch (e) {
      showError(e.message ?? 'Setliste drucken fehlgeschlagen');
    }
  }

  async function getSetlist(design = 'dark') {
    if (!gig?.id) return;

    const setlistAvailability = await getGigSetlistAvailability(null, gig.id);
    if (!setlistAvailability.setlist_available) {
      showError('Fuer diesen Gig ist keine Setliste verfuegbar.');
      return;
    }

    try {
      const blob = await getSetlistPDF(null, gig.id, design);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      const suffix = design === 'print' ? '_druckfreundlich' : '';
      a.download = `setlist_${gig.name}_${formatDateDE(gig.datum)}${suffix}.pdf`;
      a.target = '_blank';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 5000);
    } catch (e) {
      showError(e.message ?? 'Setliste drucken fehlgeschlagen');
    }
  }

  $effect(() => {
    if (tabSet === 2) loadSchedule();
  });

  $effect(() => {
    if (tabSet === 3) loadStats();
  });
</script>

<div class="card p-5 w-[96vw] max-w-7xl h-[90vh] flex flex-col modal-base">
  <header class="flex justify-between items-center mb-4 flex-shrink-0">
    <h2 class="h3">Details zu {gig?.name ?? 'Gig'}</h2>
    <button class="btn-icon btn-icon-sm variant-ghost" onclick={() => modalState.close()}>✕</button>
  </header>

  <div class="flex gap-1 mb-4 flex-shrink-0 border-b border-surface-300">
    <button
      class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 0 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
      onclick={() => tabSet = 0}
    >Übersicht</button>
    <button
      class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 1 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
      onclick={() => tabSet = 1}
    >Stammdaten</button>
    <button
      class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 2 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
      onclick={() => tabSet = 2}
    >Ablaufplan</button>
    <button
      class="btn btn-sm rounded-b-none border-b-2 transition-colors {tabSet === 3 ? 'border-primary-500 variant-soft-primary' : 'border-transparent variant-ghost'}"
      onclick={() => tabSet = 3}
    >Statistik</button>
  </div>

  <div class="overflow-y-auto flex-grow min-h-0 pr-1">
    {#if !gig}
      <div class="alert variant-filled-error">
        <p>Gig-Daten konnten nicht geladen werden.</p>
      </div>
    {:else if tabSet === 0}
      <div class="space-y-3">
        <div class="card variant-ghost-surface p-4 rounded-lg">
          <h4 class="text-sm font-semibold mb-3">Wichtigste Stammdaten</h4>
          <div class="grid grid-cols-1 gap-3 text-sm">
            <div class="flex justify-between gap-3 border-b border-surface-300 pb-1">
              <span class="text-on-surface-variant">Name</span>
              <span class="font-medium text-right">{gig.name ?? '-'}</span>
            </div>
            <div class="flex justify-between gap-3 border-b border-surface-300 pb-1">
              <span class="text-on-surface-variant">Datum</span>
              <span class="font-medium text-right">{gig.datum ? formatDateDE(gig.datum) : '-'}</span>
            </div>
            <div class="flex justify-between gap-3 border-b border-surface-300 pb-1">
              <span class="text-on-surface-variant">Art</span>
              <span class="font-medium text-right">{gig.kind_of_gig ?? '-'}</span>
            </div>
            <div class="flex justify-between gap-3 border-b border-surface-300 pb-1">
              <span class="text-on-surface-variant">Beginn</span>
              <span class="font-medium text-right">{gig.begin ? `${formatTime(gig.begin)} Uhr` : '-'}</span>
            </div>
          </div>
        </div>

        <div class="card variant-ghost-surface p-4 rounded-lg space-y-2">
          <h4 class="text-sm font-semibold">Schnellaktionen</h4>
          <div class="flex flex-col gap-2">
            <button class="btn variant-outline-primary btn-sm border border-surface-400" onclick={() => getSetlist()}>Setliste drucken</button>
            <button class="btn variant-outline-primary btn-sm border border-primary-500" onclick={() => getSetlist('print')}>
              Setliste drucken (druckfreundlich)
            </button>
            <button class="btn variant-outline-primary btn-sm w-full justify-start border border-primary-500" onclick={getGemaList}>GEMA-Liste drucken</button>
            <button class="btn variant-outline-primary btn-sm w-full justify-start border border-primary-500" onclick={exportSchedulePdf}>Ablaufplan drucken</button>
            {#if canEdit}
              <button class="btn variant-filled-primary btn-sm w-full justify-start" onclick={handleEditSetlist}>Setliste bearbeiten</button>

              {#if liveMode}
                {#if liveMode.available}
                  <button class="btn variant-filled-secondary btn-sm w-full justify-start" onclick={handleOpenLiveMode}>
                    Live Mode
                    {#if liveMode.forced}
                      <span class="badge variant-soft-warning ml-1 text-xs">Entsperrt</span>
                    {/if}
                  </button>
                {:else if liveMode.can_force}
                  <button class="btn variant-soft-warning btn-sm w-full justify-start" onclick={handleUnlockLiveMode}>Live Mode entsperren</button>
                {/if}
              {/if}
            {/if}
          </div>
        </div>
      </div>
    {:else if tabSet === 1}
      {#if canEdit}
        <div class="flex justify-end mb-3">
          <label class="flex items-center gap-2 text-sm cursor-pointer select-none">
            <span class="text-on-surface-variant">Edit-Mode</span>
            <input
              type="checkbox"
              class="checkbox"
              checked={isEditing}
              onchange={handleStammdatenEditToggle}
              disabled={isSaving}
            />
          </label>
        </div>
      {/if}

      {#if isEditing}
        <form class="space-y-4" onsubmit={saveEdit}>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            {#each gigFieldsDetails as f}
              <div class="mb-2">
                <label class="block">
                  <span class="text-sm font-medium text-on-surface">
                    {f.label}
                    {#if f.required}<span class="text-error-500">*</span>{/if}
                  </span>
                  {#if f.type === 'option' && Array.isArray(f.options)}
                    <select class="input mt-1 w-full" bind:value={editBuffer[f.key]} required={f.required}>
                      {#each f.options as o}
                        <option value={o.key}>{o.label}</option>
                      {/each}
                    </select>
                  {:else if f.type === 'date'}
                    <input type="date" class="input mt-1 w-full" bind:value={editBuffer[f.key]} required={f.required} />
                  {:else if f.type === 'time'}
                    <input type="time" class="input mt-1 w-full" step="1" bind:value={editBuffer[f.key]} required={f.required} />
                  {:else}
                    <input type="text" class="input mt-1 w-full" bind:value={editBuffer[f.key]} placeholder={f.label} required={f.required} />
                  {/if}
                </label>
              </div>
            {/each}
          </div>
        </form>
      {:else}
        <ul class="divide-y divide-surface-300 mb-4">
          {#each gigFieldsDetails as f}
            <li class="flex justify-between py-3 gap-4">
              <span class="font-semibold text-on-surface">{f.label}</span>
              <span class="text-on-surface-variant text-right">
                {#if f.key === 'datum' && gig[f.key]}
                  {formatDateDE(gig[f.key])}
                {:else if f.type === 'time' && gig[f.key]}
                  {formatTime(gig[f.key])} Uhr
                {:else}
                  {gig[f.key] ?? '-'}
                {/if}
              </span>
            </li>
          {/each}
        </ul>

        <div class="space-y-2">
          {#if canEdit}
            <div class="flex flex-wrap gap-2">
              <button class="btn variant-filled-primary btn-sm" onclick={handleEditSetlist}>Setliste bearbeiten</button>

              {#if liveMode}
                {#if liveMode.available}
                  <button class="btn variant-filled-secondary btn-sm" onclick={handleOpenLiveMode}>
                    Live Mode
                    {#if liveMode.forced}
                      <span class="badge variant-soft-warning ml-1 text-xs">Entsperrt</span>
                    {/if}
                  </button>
                {:else if liveMode.can_force}
                  <button class="btn variant-soft-warning btn-sm" onclick={handleUnlockLiveMode}>Live Mode entsperren</button>
                {/if}
              {/if}

              {#if canEdit}
                <button class="btn variant-filled-error btn-sm" onclick={handleDelete}>Löschen</button>
              {/if}
            </div>
          {/if}

          <div class="flex flex-wrap gap-2 pt-2 border-t border-surface-300">
            <button class="btn variant-outline-primary btn-sm border border-primary-500" onclick={getGemaList}>GEMA-Liste drucken</button>
            <button class="btn variant-outline-primary btn-sm border border-primary-500" onclick={() => getSetlist()}>Setliste drucken</button>
            <button class="btn variant-outline-primary btn-sm border border-primary-500" onclick={() => getSetlist('print')}>
              Setliste drucken (druckfreundlich)
            </button>
          </div>
        </div>
      {/if}
    {:else if tabSet === 2}
      <div class="space-y-3">
        <div class="flex justify-end gap-2">
          <button type="button" class="btn btn-sm variant-outline-secondary border border-secondary-500" onclick={() => loadSchedule(true)}>Neu laden</button>
          <button type="button" class="btn btn-sm variant-outline-primary border border-primary-500" onclick={exportSchedulePdf}>PDF exportieren</button>
        </div>

        {#if scheduleLoading && !scheduleData}
          <div class="flex justify-center py-12">
            <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
          </div>
        {:else}
          <GigSchedule
            gig={gig}
            canEdit={canEdit}
            scheduleData={scheduleData}
            onScheduleUpdated={handleScheduleUpdated}
          />
        {/if}
      </div>
    {:else if tabSet === 3}
      <div class="space-y-3">
        <div class="flex justify-end">
          <button type="button" class="btn btn-sm variant-outline-secondary border border-secondary-500" onclick={() => loadStats(true)}>Neu laden</button>
        </div>

        {#if statsLoading && !statistics}
          <div class="flex justify-center py-12">
            <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
          </div>
        {:else if statsError}
          <div class="alert variant-filled-error">
            <p>{statsError}</p>
          </div>
        {:else if statistics}
          <div class="space-y-4">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div class="card variant-ghost-primary p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-primary-500">{statistics.song_count}</div>
                <div class="text-xs text-on-surface-variant">Songs</div>
              </div>
              <div class="card variant-ghost-warning p-3 text-center rounded-lg">
                <div class="text-2xl font-bold text-warning-500">{statistics.skipped_count}</div>
                <div class="text-xs text-on-surface-variant">Uebersprungen</div>
              </div>
              <div class="card variant-ghost-surface p-3 text-center rounded-lg">
                <div class="text-2xl font-bold">{statistics.inserted_count}</div>
                <div class="text-xs text-on-surface-variant">Eingeschoben</div>
              </div>
              <div class="card variant-ghost-surface p-3 text-center rounded-lg">
                {#if statistics.feedback_avg != null}
                  <div class="text-2xl font-bold">{feedbackLabel(statistics.feedback_avg)}</div>
                  <div class="text-xs text-on-surface-variant">Ø {statistics.feedback_avg}</div>
                {:else}
                  <div class="text-2xl font-bold text-surface-400">-</div>
                  <div class="text-xs text-on-surface-variant">Ø Feedback</div>
                {/if}
              </div>
            </div>

            {#if statistics.feedback_count > 0}
              <div class="card variant-ghost-surface p-4 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-3">Live-Bewertungen ({statistics.feedback_count} gesamt)</h4>
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
                      <span class="w-20 text-right text-xs text-on-surface-variant">{count}x ({pct}%)</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}

            {#if Object.keys(statistics.genre_distribution ?? {}).length > 0 || (statistics.genre_timeline?.length ?? 0) > 0}
              <div class="card variant-ghost-surface p-4 rounded-lg">
                <h4 class="text-xs font-semibold text-on-surface-variant mb-3">Verteilungen</h4>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                  {#if statistics.feedback_count > 0}
                    <FeedbackDistributionPlot
                      feedbackDistribution={statistics.feedback_distribution}
                      feedbackCount={statistics.feedback_count}
                      titlePrefix="Gig-Bewertungen"
                    />
                  {/if}
                  <GenreDistributionPlot
                    genreDistribution={statistics.genre_distribution}
                    genreTimeline={statistics.genre_timeline ?? []}
                    genrePalette={genrePalette}
                    titlePrefix="Genre"
                    showTimeline={false}
                  />
                </div>
                <div class="mt-4 border-t border-surface-300 dark:border-surface-700 pt-3">
                  <GenreDistributionPlot
                    genreDistribution={statistics.genre_distribution}
                    genreTimeline={statistics.genre_timeline ?? []}
                    genrePalette={genrePalette}
                    titlePrefix="Genre"
                    showDistribution={false}
                  />
                </div>
              </div>
            {/if}

            {#if statistics.sets?.length > 0}
              {#each statistics.sets as set}
                <div class="card variant-ghost-surface p-4 rounded-lg">
                  <div class="flex items-center justify-between mb-3">
                    <h4 class="text-sm font-semibold">{set.set_name}</h4>
                    {#if set.feedback_avg != null}
                      <span class="text-xs text-on-surface-variant">Ø {feedbackLabel(set.feedback_avg)} {set.feedback_avg}</span>
                    {:else}
                      <span class="text-xs text-on-surface-variant">Kein Feedback</span>
                    {/if}
                  </div>

                  <div class="overflow-x-auto">
                    <table class="w-full text-sm">
                      <thead>
                        <tr class="border-b border-surface-300 dark:border-surface-700">
                          <th class="text-right py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-8">#</th>
                          <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold">Titel</th>
                          <th class="text-left py-1.5 px-2 text-xs text-on-surface-variant font-semibold hidden sm:table-cell">Interpret</th>
                          <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-10">Bew.</th>
                          <th class="text-center py-1.5 px-2 text-xs text-on-surface-variant font-semibold w-10"></th>
                        </tr>
                      </thead>
                      <tbody>
                        {#each set.songs as song}
                          <tr class="border-b border-surface-200 dark:border-surface-800 last:border-0 {song.uebersprungen ? 'opacity-50' : ''}">
                            <td class="py-1.5 px-2 text-right text-xs text-on-surface-variant">{song.position}</td>
                            <td class="py-1.5 px-2 font-medium max-w-[180px] truncate">
                              {song.title}
                              {#if song.uebersprungen}
                                <span class="text-xs text-warning-500 ml-1" title="Uebersprungen">Skip</span>
                              {/if}
                              {#if song.eingeschoben}
                                <span class="text-xs text-secondary-500 ml-1" title="Eingeschoben">Ins</span>
                              {/if}
                            </td>
                            <td class="py-1.5 px-2 text-xs text-on-surface-variant hidden sm:table-cell">{song.interpret}</td>
                            <td class="py-1.5 px-2 text-center">
                              {#if song.feedback != null}
                                <span title={song.feedback === 3 ? 'Gut' : song.feedback === 2 ? 'Mittel' : 'Schlecht'}>
                                  {feedbackEmoji[song.feedback]}
                                </span>
                              {:else}
                                <span class="text-xs text-surface-400">-</span>
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
                <p class="text-sm text-on-surface-variant">Noch keine Setliste fuer diesen Gig vorhanden.</p>
              </div>
            {/if}
          </div>
        {:else}
          <p class="text-sm text-on-surface-variant">Keine Statistikdaten verfuegbar.</p>
        {/if}
      </div>
    {/if}
  </div>

  <footer class="flex gap-2 justify-end pt-4 mt-2 flex-shrink-0 border-t border-surface-300">
    {#if isEditing}
      <button type="button" class="btn variant-filled-success" disabled={isSaving} onclick={saveEdit}>
        {isSaving ? 'Wird gespeichert...' : 'Speichern'}
      </button>
      <button type="button" class="btn variant-outline-secondary border border-secondary-500" onclick={cancelEdit}>Abbrechen</button>
    {/if}
    <button class="btn variant-ghost" onclick={() => modalState.close()}>Schließen</button>
  </footer>
</div>

<style>
  :global(.modal-base .btn.variant-outline-primary),
  :global(.modal-base .btn.variant-outline-secondary),
  :global(.modal-base .btn.variant-outline-surface) {
    border-width: 1px !important;
    border-style: solid !important;
    border-color: currentColor !important;
  }
</style>





