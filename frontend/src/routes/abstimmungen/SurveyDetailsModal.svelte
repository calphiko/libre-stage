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
  import { appendSurveyFields, getSurveyDetails } from '$lib/api.js';
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
  let newOption = $state('');
  let addingOption = $state(false);
  let optionError = $state('');
  let optionSuccess = $state('');

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

  async function handleAddOption() {
    optionError = '';
    optionSuccess = '';

    const value = (newOption || '').trim();
    if (!value) {
      optionError = 'Bitte eine Antwortoption eingeben.';
      return;
    }

    const existingFieldTexts = (details?.fields ?? []).map((field) => (field.field_text || '').trim().toLowerCase());
    if (existingFieldTexts.includes(value.toLowerCase())) {
      optionError = 'Diese Antwortoption existiert bereits.';
      return;
    }

    addingOption = true;
    try {
      details = await appendSurveyFields(null, survey.id, [{ field_text: value }]);
      newOption = '';
      optionSuccess = 'Antwortoption erfolgreich hinzugefuegt.';
    } catch (e) {
      optionError = e?.message || 'Antwortoption konnte nicht hinzugefuegt werden.';
    } finally {
      addingOption = false;
    }
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
        {#if !survey.closed}
          <div class="space-y-2 border border-outline-variant rounded-md p-2">
            <label class="text-xs text-on-surface-variant" for="add-survey-option">
              Neue Antwortoption hinzufuegen
            </label>
            <div class="flex flex-col sm:flex-row gap-2">
              <input
                id="add-survey-option"
                class="input flex-1"
                type={details?.kind_of_survey === 'Terminfindung' ? 'datetime-local' : 'text'}
                bind:value={newOption}
                placeholder={details?.kind_of_survey === 'Terminfindung' ? 'Neuer Termin' : 'Neue Option'}
                onkeydown={(e) => e.key === 'Enter' && handleAddOption()}
              />
              <button
                type="button"
                class="btn btn-xs variant-filled-primary"
                onclick={handleAddOption}
                disabled={addingOption}
              >{addingOption ? 'Speichere...' : 'Hinzufuegen'}</button>
            </div>
            <p class="text-[11px] text-on-surface-variant">
              Vorhandene Antwortoptionen koennen nicht geloescht werden.
            </p>
            {#if optionError}
              <p class="text-xs text-error-500">{optionError}</p>
            {/if}
            {#if optionSuccess}
              <p class="text-xs text-success-500">{optionSuccess}</p>
            {/if}
          </div>
        {/if}
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







