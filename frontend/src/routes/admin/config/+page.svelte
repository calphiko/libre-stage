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
  const timingKeys = [
    'DEFAULT_SONG_DURATION_SECONDS',
    'DEFAULT_INTER_SONG_BREAK_SECONDS',
    'DEFAULT_SET_PAUSE_SECONDS'
  ];
  const timingLabels = {
    DEFAULT_SONG_DURATION_SECONDS: 'Standard Songdauer',
    DEFAULT_INTER_SONG_BREAK_SECONDS: 'Standard Songpause',
    DEFAULT_SET_PAUSE_SECONDS: 'Standard Setpause'
  };
  const timingDefaults = {
    DEFAULT_SONG_DURATION_SECONDS: 240,
    DEFAULT_INTER_SONG_BREAK_SECONDS: 30,
    DEFAULT_SET_PAUSE_SECONDS: 600
  };

  let loading = $state(true);
  let saving = $state(false);
  let updatedAt = $state('');

  let form = $state({
    genres: [],
    gigTypes: [],
    songStatuses: [],
    gigStatuses: [],
    tonekeys: [],
    rehearsalSongStatuses: [],
    setlist_timing: []
  });

  let original = $state(null);
  let timingPickerValues = $state({});

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function humanizeKey(key) {
    return key
      .replace(/([A-Z])/g, ' $1')
      .replace(/^./, (c) => c.toUpperCase());
  }

  function normalizeTimingValue(value, fallback = 0) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(0, Math.round(parsed));
  }

  function secondsToTimePicker(totalSeconds) {
    const safeSeconds = Math.min(86399, normalizeTimingValue(totalSeconds, 0));
    const hours = String(Math.floor(safeSeconds / 3600)).padStart(2, '0');
    const minutes = String(Math.floor((safeSeconds % 3600) / 60)).padStart(2, '0');
    const seconds = String(safeSeconds % 60).padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
  }

  function timePickerToSeconds(value, fallback = 0) {
    if (typeof value !== 'string' || !value.trim()) return fallback;
    const parts = value.split(':').map((part) => Number(part));
    if (parts.some((part) => !Number.isInteger(part) || part < 0)) return fallback;

    if (parts.length === 2) {
      const [hours, minutes] = parts;
      if (minutes > 59) return fallback;
      return hours * 3600 + minutes * 60;
    }

    if (parts.length === 3) {
      const [hours, minutes, seconds] = parts;
      if (minutes > 59 || seconds > 59) return fallback;
      return hours * 3600 + minutes * 60 + seconds;
    }

    return fallback;
  }

  function normalizeSetlistTiming(list) {
    const merged = {};
    for (const item of list ?? []) {
      if (!item || typeof item !== 'object') continue;
      for (const [key, value] of Object.entries(item)) {
        if (!timingKeys.includes(key)) continue;
        merged[key] = normalizeTimingValue(value, timingDefaults[key]);
      }
    }

    return timingKeys.map((key) => ({ [key]: merged[key] ?? timingDefaults[key] }));
  }

  function getTimingValue(key) {
    const found = (form.setlist_timing ?? []).find((item) => item && typeof item === 'object' && key in item);
    return normalizeTimingValue(found?.[key], timingDefaults[key]);
  }

  function updateTimingValue(key, value) {
    const normalized = normalizeSetlistTiming(form.setlist_timing);
    form.setlist_timing = normalized.map((entry) =>
      key in entry ? { [key]: normalizeTimingValue(value, timingDefaults[key]) } : entry
    );
  }

  function syncTimingPickers() {
    const nextValues = {};
    for (const key of timingKeys) {
      nextValues[key] = secondsToTimePicker(getTimingValue(key));
    }
    timingPickerValues = nextValues;
  }

  function updateTimingFromPicker(key, value) {
    timingPickerValues[key] = value;
    const fallback = getTimingValue(key);
    updateTimingValue(key, timePickerToSeconds(value, fallback));
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
    form.setlist_timing = normalizeSetlistTiming(form.setlist_timing);
    syncTimingPickers();
  }

  async function saveConfig() {
    saving = true;

    try {
      const payload = {
        ...deepClone(form),
        setlist_timing: normalizeSetlistTiming(form.setlist_timing)
      };
      const response = await adminUpdateSoftConfig(payload);
      form = deepClone(response.data);
      form.setlist_timing = normalizeSetlistTiming(form.setlist_timing);
      syncTimingPickers();
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
      form.setlist_timing = normalizeSetlistTiming(form.setlist_timing);
      syncTimingPickers();
      original = deepClone(response.data);
      updatedAt = response.meta?.updatedAt || '';
    } catch (e) {
      toastState.add({ type: 'error', message: e.message || 'Konfiguration konnte nicht geladen werden.' });
    } finally {
      loading = false;
    }
  });
</script>

<div class="ui-page ui-card px-5 py-6">
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
        <section class="ui-card-muted p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="h4 text-on-surface">{humanizeKey(key)}</h3>
            <button
              type="button"
              class="ui-btn ui-btn-primary w-8 h-8 rounded-full text-xl leading-none"
              onclick={() => addObjectEntry(key)}
              title="Eintrag hinzufuegen"
              aria-label="Eintrag hinzufuegen"
            >+</button>
          </div>

          <div class="space-y-2">
            {#each form[key] as item, index}
              <div class="grid grid-cols-12 gap-2">
                <input
                  class="ui-input col-span-4"
                  placeholder="Key"
                  bind:value={item.key}
                />
                <input
                  class="ui-input col-span-7"
                  placeholder="Label"
                  bind:value={item.label}
                />
                <button
                  type="button"
                  class="ui-btn variant-filled-error col-span-1"
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
        <section class="ui-card-muted p-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="h4 text-on-surface">{humanizeKey(key)}</h3>
            <button
              type="button"
              class="ui-btn ui-btn-primary w-8 h-8 rounded-full text-xl leading-none"
              onclick={() => addStringEntry(key)}
              title="Eintrag hinzufuegen"
              aria-label="Eintrag hinzufuegen"
            >+</button>
          </div>

          <div class="space-y-2">
            {#each form[key] as item, index}
              <div class="grid grid-cols-12 gap-2">
                <input
                  class="ui-input col-span-11"
                  placeholder="Status"
                  bind:value={form[key][index]}
                />
                <button
                  type="button"
                  class="ui-btn variant-filled-error col-span-1"
                  onclick={() => removeStringEntry(key, index)}
                  title="Eintrag entfernen"
                  aria-label="Eintrag entfernen"
                >-</button>
              </div>
            {/each}
          </div>
        </section>
      {/each}

      <section class="ui-card-muted p-4">
        <div class="flex items-center justify-between mb-3">
          <h3 class="h4 text-on-surface">Setlist Timing</h3>
        </div>

        <div class="space-y-2">
          {#each timingKeys as key}
            <div class="grid grid-cols-12 gap-2 items-center">
              <div class="col-span-8">
                <label class="text-on-surface" for={`timing-${key}`}>{timingLabels[key]}</label>

              </div>
              <input
                id={`timing-${key}`}
                class="ui-input col-span-4"
                type="time"
                step="1"
                value={timingPickerValues[key] ?? secondsToTimePicker(getTimingValue(key))}
                oninput={(e) => updateTimingFromPicker(key, e.currentTarget.value)}
              />
            </div>
          {/each}
        </div>
      </section>
    </div>

    <div class="flex gap-2 mt-6">
      <button class="ui-btn ui-btn-ghost" onclick={resetForm} disabled={saving}>Verwerfen</button>
      <button class="ui-btn ui-btn-primary" onclick={saveConfig} disabled={saving}>
        {#if saving}Speichere...{:else}Speichern{/if}
      </button>
    </div>
  {/if}
</div>



