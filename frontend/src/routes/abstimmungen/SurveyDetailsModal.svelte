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
  import { getSurveyDetails } from '$lib/api.js';
  import { shortFormatGermanDate } from '$lib/common.js';
  import { modalState } from '$lib/modalState.js';

  import TerminfindungView from './TerminfindungView.svelte';
  import MeinungsumfrageView from './MeinungsumfrageView.svelte';

  let {
    survey,
    users = [],
    user = null,
    onarchive,
    ondelete,
    onreminder,
    onerror
  } = $props();

  let details = $state(null);
  let loading = $state(true);
  let tabSet = $state(0);

  let userById = $derived(new Map(users.map(u => [u.id, u])));
  let creatorName = $derived(userById.get(survey.user_created)?.clear_name ?? '');
  let isOwner = $derived(Number(survey.user_created) === Number(user?.id));
  let canManageActive = $derived(!survey.closed && isOwner);
  let canDeleteClosed = $derived(survey.closed && isOwner);

  onMount(async () => {
    try {
      details = await getSurveyDetails(null, survey.id);
    } catch (e) {
      onerror?.({ message: 'Fehler beim Laden der Umfragedetails.' });
      console.error('Fehler beim Laden der Umfragedetails:', e);
    } finally {
      loading = false;
    }
  });

  function handleArchive() {
    onarchive?.({ id: survey.id, name: survey.rf_survey });
  }

  function handleDelete() {
    ondelete?.({ id: survey.id, name: survey.rf_survey });
  }

  function handleReminder() {
    onreminder?.({ id: survey.id });
  }
</script>

<div class="card p-2.5 sm:p-4 md:p-5 w-full max-w-6xl h-[96dvh] sm:h-[90vh] md:h-[88vh] flex flex-col modal-base text-sm overflow-hidden min-w-0">
  <header class="flex justify-between items-start gap-2 mb-2 border-b border-outline-variant pb-2 flex-shrink-0 min-h-0">
    <div class="min-w-0">
      <h2 class="text-sm sm:text-base md:text-lg font-semibold text-on-surface truncate">{survey.rf_survey}</h2>
      <p class="text-[11px] sm:text-xs text-on-surface-variant mt-0.5 truncate">
        {survey.kind_of_survey} · {creatorName} · {shortFormatGermanDate(survey.release_date)} · {survey.closed ? 'geschlossen' : 'laufend'}
      </p>
    </div>
    <button class="btn-icon btn-icon-sm variant-ghost" onclick={() => modalState.close()}>✕</button>
  </header>

  <div class="flex border-b border-surface-300 dark:border-surface-600 mb-2 gap-1 text-[11px] sm:text-xs flex-shrink-0 overflow-x-auto">
    <button
      onclick={() => tabSet = 0}
      class="px-2.5 sm:px-3 py-1 rounded-t-lg whitespace-nowrap transition-colors {tabSet === 0 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}"
    >Details</button>
    {#if isOwner}
      <button
        onclick={() => tabSet = 1}
        class="px-2.5 sm:px-3 py-1 rounded-t-lg whitespace-nowrap transition-colors {tabSet === 1 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}"
      >Administration</button>
    {/if}
  </div>

  <div class="flex-1 overflow-y-auto pr-0 md:pr-1 pb-1 min-h-0">
    {#if tabSet === 1 && isOwner}
      <div class="border border-outline-variant rounded-lg p-3 space-y-2">
        <p class="text-xs text-on-surface-variant">Verwaltung dieser Abstimmung</p>
        <div class="flex flex-col items-stretch sm:items-start gap-2">
        {#if canManageActive}
          <button type="button" class="btn btn-xs variant-filled-warning" onclick={handleReminder}>
            Säumige User erinnern
          </button>
          <button type="button" class="btn btn-xs variant-filled-warning" onclick={handleArchive}>
            Archivieren
          </button>
        {/if}
        {#if canManageActive || canDeleteClosed}
          <button type="button" class="btn btn-xs variant-filled-error" onclick={handleDelete}>
            Loeschen
          </button>
        {/if}
        </div>
      </div>
    {:else}
      {#if loading}
        <div class="border border-outline-variant rounded-lg flex justify-center items-center py-8">
          <div class="inline-block animate-spin rounded-full h-7 w-7 border-b-2 border-secondary-500"></div>
        </div>
      {:else if details}
        {#if details.kind_of_survey === 'Terminfindung'}
          {#if user}
            <TerminfindungView survey={details} {users} {user} showHeader={false} />
          {:else}
            <div>Benutzerdaten werden geladen...</div>
          {/if}
        {:else if details.kind_of_survey === 'Meinungsumfrage'}
          <MeinungsumfrageView survey={details} {users} {user} showHeader={false} />
        {:else}
          <div>Unbekannter Survey-Typ.</div>
        {/if}
      {:else}
        <p class="italic text-on-surface-variant">Details konnten nicht geladen werden.</p>
      {/if}
    {/if}
  </div>
</div>







