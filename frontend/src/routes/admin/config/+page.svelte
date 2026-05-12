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
  import { getUser, adminGetSoftConfig, adminUpdateSoftConfig } from '$lib/api.js';
  import { loadAppConfig } from '$lib/appConfig.js';
  import { formatGermanDateTime } from '$lib/common.js';
  import { toastState } from '$lib/toast.js';

  const objectKeys = ['genres', 'gigTypes', 'songStatuses', 'gigStatuses', 'tonekeys'];
  const stringKeys = ['rehearsalSongStatuses'];

  let loading = $state(true);
  let saving = $state(false);
  let updatedAt = $state('');

  let form = $state({
    genres: [],
    gigTypes: [],
    songStatuses: [],
    gigStatuses: [],
    tonekeys: [],
    rehearsalSongStatuses: []
  });

  let original = $state(null);

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function humanizeKey(key) {
    return key
      .replace(/([A-Z])/g, ' $1')
      .replace(/^./, (c) => c.toUpperCase());
  }

  function addObjectEntry(key) {
    form[key] = [...form[key], { key: '', label: '' }];
  }

  function removeObjectEntry(key, index) {
    form[key] = form[key].filter((_, i) => i !== index);
  }

  function addStringEntry(key) {
    form[key] = [...form[key], ''];
  }

  function removeStringEntry(key, index) {
    form[key] = form[key].filter((_, i) => i !== index);
  }

  function resetForm() {
    if (!original) return;
    form = deepClone(original);
  }

  async function saveConfig() {
    saving = true;

    try {
      const response = await adminUpdateSoftConfig(form);
      form = deepClone(response.data);
      original = deepClone(response.data);
      await loadAppConfig(true);
      toastState.add({ type: 'success', message: 'Konfiguration wurde gespeichert.' });
    } catch (e) {
      toastState.add({ type: 'error', message: e.message || 'Konfiguration konnte nicht gespeichert werden.' });
    } finally {
      saving = false;
    }
  }

  onMount(async () => {
    try {
      const user = await getUser();
      if (!user || user.user_group !== 'admin') {
        toastState.add({ type: 'warning', message: 'Nur Admins duerfen diese Seite aufrufen.' });
        await goto('/dashboard');
        return;
      }

      const response = await adminGetSoftConfig();
      form = deepClone(response.data);
      original = deepClone(response.data);
      updatedAt = response.meta?.updatedAt || '';
    } catch (e) {
      toastState.add({ type: 'error', message: e.message || 'Konfiguration konnte nicht geladen werden.' });
    } finally {
      loading = false;
    }
  });
</script>

<div class="card max-w-7xl mx-auto my-7 px-5 py-6 bg-surface-1 rounded-xl shadow border border-outline-variant">
  <div class="flex items-center justify-between mb-4">
    <h2 class="h2 text-on-surface">Admin-Konfiguration</h2>
    {#if updatedAt}
      <span class="text-sm text-on-surface-variant">Stand: {formatGermanDateTime(updatedAt)}</span>
    {/if}
  </div>

  {#if loading}
    <p class="text-on-surface-variant">Lade Konfiguration...</p>
  {:else}
    <div class="space-y-6">
      {#each objectKeys as key}
        <section class="card variant-ghost-surface p-4 rounded-lg">
          <div class="flex items-center justify-between mb-3">
            <h3 class="h4 text-on-surface">{humanizeKey(key)}</h3>
            <button
              type="button"
              class="btn-icon variant-filled-primary w-8 h-8 rounded-full text-xl leading-none"
              onclick={() => addObjectEntry(key)}
              title="Eintrag hinzufuegen"
              aria-label="Eintrag hinzufuegen"
            >+</button>
          </div>

          <div class="space-y-2">
            {#each form[key] as item, index}
              <div class="grid grid-cols-12 gap-2">
                <input
                  class="input col-span-4"
                  placeholder="Key"
                  bind:value={item.key}
                />
                <input
                  class="input col-span-7"
                  placeholder="Label"
                  bind:value={item.label}
                />
                <button
                  type="button"
                  class="btn-icon btn-icon-sm variant-filled-error col-span-1"
                  onclick={() => removeObjectEntry(key, index)}
                  title="Eintrag entfernen"
                  aria-label="Eintrag entfernen"
                >-</button>
              </div>
            {/each}
          </div>
        </section>
      {/each}

      {#each stringKeys as key}
        <section class="card variant-ghost-surface p-4 rounded-lg">
          <div class="flex items-center justify-between mb-3">
            <h3 class="h4 text-on-surface">{humanizeKey(key)}</h3>
            <button
              type="button"
              class="btn-icon variant-filled-primary w-8 h-8 rounded-full text-xl leading-none"
              onclick={() => addStringEntry(key)}
              title="Eintrag hinzufuegen"
              aria-label="Eintrag hinzufuegen"
            >+</button>
          </div>

          <div class="space-y-2">
            {#each form[key] as item, index}
              <div class="grid grid-cols-12 gap-2">
                <input
                  class="input col-span-11"
                  placeholder="Status"
                  bind:value={form[key][index]}
                />
                <button
                  type="button"
                  class="btn-icon btn-icon-sm variant-filled-error col-span-1"
                  onclick={() => removeStringEntry(key, index)}
                  title="Eintrag entfernen"
                  aria-label="Eintrag entfernen"
                >-</button>
              </div>
            {/each}
          </div>
        </section>
      {/each}
    </div>

    <div class="flex gap-2 mt-6">
      <button class="btn btn-outline-secondary" onclick={resetForm} disabled={saving}>Verwerfen</button>
      <button class="btn btn-primary" onclick={saveConfig} disabled={saving}>
        {#if saving}Speichere...{:else}Speichern{/if}
      </button>
    </div>
  {/if}
</div>



