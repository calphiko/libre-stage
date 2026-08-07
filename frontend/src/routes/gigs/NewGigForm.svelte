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
  import { modalState } from '$lib/modalState.js';
  import { getGigFieldsDetails } from '$lib/songFields.js';
  import { appConfig } from '$lib/appConfig.js';
  import { getGigs } from '$lib/api.js';

  // Diese Props werden vom Modal übergeben
  let { parent } = $props();

  let gigFieldsDetails = $derived(getGigFieldsDetails($appConfig));

  let gig = $state({});
  let error = $state('');
  let pastGigs = $state([]);
  let selectedTemplateId = $state('');

  const EXCLUDED_COPY_KEYS = new Set(['id', 'name', 'datum']);

  function normalizeTimeValue(value) {
    if (!value) return '';
    return String(value).slice(0, 5);
  }

  function normalizeForField(field, value) {
    if (value == null) return '';
    if (field.type === 'time') return normalizeTimeValue(value);
    return value;
  }

  onMount(async () => {
    try {
      const allGigs = await getGigs(null, '');
      pastGigs = allGigs
        .sort((a, b) => new Date(b.datum) - new Date(a.datum));
    } catch (e) {
      error = e?.message ?? 'Vergangene Gigs konnten nicht geladen werden';
      pastGigs = [];
    }
  });

  function applyTemplate() {
    const template = pastGigs.find((g) => String(g.id) === String(selectedTemplateId));
    if (!template) return;

    const copiedValues = {};
    for (const field of gigFieldsDetails) {
      if (EXCLUDED_COPY_KEYS.has(field.key)) continue;
      copiedValues[field.key] = normalizeForField(field, template[field.key]);
    }

    gig = { ...gig, ...copiedValues };
  }

  function submit(event) {
    event.preventDefault();
    modalState.close(gig);
  }
</script>

<div class="card p-6 space-y-4 max-w-4xl w-[90vw] max-h-[90vh] flex flex-col modal-base">
  <header class="flex justify-between items-center flex-shrink-0">
    <h2 class="h5 mb-3">Neuer Gig</h2>
    <button
      class="btn-icon btn-icon-sm variant-ghost"
      type="button"
      aria-label="Modal schließen"
      onclick={modalState.close}
    >✕</button>
  </header>
  <div class="overflow-y-auto flex-grow">
    <form class=" card bg-surface-1 p-4 rounded shadow mb-4" onsubmit={submit}>
      <details class="mb-4 p-3 rounded bg-surface-2">
        <summary class="cursor-pointer font-medium">Stammdaten aus vergangenem Gig übernehmen</summary>
        <div class="mt-3 flex gap-2 items-center">
          <select class="input flex-grow-1 select" bind:value={selectedTemplateId}>
            <option value="">Bitte Gig auswählen</option>
            {#each pastGigs as templateGig}
              <option value={templateGig.id}>
                {new Date(templateGig.datum).toLocaleDateString('de-DE')} - {templateGig.name}
              </option>
            {/each}
          </select>
          <button
            type="button"
            class="btn variant-outline-primary border"
            onclick={applyTemplate}
            disabled={!selectedTemplateId}
          >
            Übernehmen
          </button>
        </div>
      </details>

      {#if error}
        <div class="mb-3 text-red-600 text-sm">{error}</div>
      {/if}

      {#each gigFieldsDetails as gigField}
        <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
          <label>{gigField.label}
            {#if gigField.required}
              <span class="text-danger ms-1" style="color:'red'; white-space:nowrap;">*</span>
            {/if}
          </label>
          {#if gigField.type == 'option' && Array.isArray(gigField.options)}
            <select
              class="input flex-grow-1 select"
              bind:value={gig[gigField.key]}
              required={gigField.required}
            >
              {#each gigField.options as o}
                <option value={o.key}>{o.label}</option>
              {/each}
            </select>
          {:else if gigField.type == "text"}
            <input
              type="text"
              class="input flex-grow-1"
              bind:value={gig[gigField.key]}
              placeholder={gigField.label}
              required={gigField.required}
            />
          {:else if gigField.type == "date"}
            <input
              type="date"
              class="input flex-grow-1"
              bind:value={gig[gigField.key]}
              placeholder={gigField.label}
              required={gigField.required}
            />
          {:else if gigField.type == "time"}
            <input
              type="time"
              class="input flex-grow-1"
              bind:value={gig[gigField.key]}
              placeholder={gigField.label}
              required={gigField.required}
            />
          {/if}

        </div>
      {/each}

      <div class="flex justify-end gap-2 mt-2">
        <button class="btn variant-outline-secondary border" type="button" onclick={modalState.close}>Abbrechen</button>
        <button class="btn variant-filled-success border" type="submit">Erstellen</button>
      </div>
    </form>
  </div>
</div>

<style>
 .input {
    display: block;
 }
</style>