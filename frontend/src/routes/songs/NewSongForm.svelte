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
  import { modalState } from '$lib/modalState.js';
  import { getSongFieldsDetails } from '$lib/songFields.js';
  import { appConfig } from '$lib/appConfig.js';
  import { findBestSongDuplicate } from '$lib/songDuplicateCheck.js';
  import { getSongCrawlerMetadata } from '$lib/api.js';
  import { fade, fly } from 'svelte/transition';
  import SingersList from '$lib/components/SingersList.svelte';

  // Diese Props werden vom Modal übergeben
  let { response = () => {}, parent, existingSongs = [] } = $props();

  function buildInitialSong(fields) {
      const initial = {};
      for (const f of fields ?? []) {
        if (f.type === 'multi_select') initial[f.key] = [];
      }
      return initial;
  }

  let songFieldsDetails = $derived(getSongFieldsDetails($appConfig));
  let song = $state(buildInitialSong(getSongFieldsDetails($appConfig)));

  // multi_select-Felder müssen als Array initialisiert sein, da SingersList kein null/undefined verarbeitet
  $effect(() => {
    songFieldsDetails.forEach(f => {
      if (f.type === 'multi_select' && !Array.isArray(song[f.key])) {
        song[f.key] = [];
      }
    });
  });
  let duplicateMatch = $state(null);
  let isMetadataLoading = $state(false);
  let lastMetadataKey = $state('');
  let metadataDebounceTimer;
  let lastRequestedMetadataKey = '';
  let lastMetadataRequestAt = 0;
  let titleBlurred = $state(false);
  let interpretBlurred = $state(false);
  const METADATA_DEBOUNCE_MS = 350;
  const METADATA_COOLDOWN_MS = 10000;

  function getStatusLabel(statusKey) {
    const found = ($appConfig?.songStatuses ?? []).find((s) => s?.key === statusKey);
    return found?.label ?? statusKey ?? 'unbekannt';
  }

  function checkDuplicate() {
    const result = findBestSongDuplicate(song, existingSongs);
    duplicateMatch = result?.song ?? null;
  }

  async function maybeFetchSongMetadata() {
    const title = song.title?.trim();
    const interpret = song.interpret?.trim();
    if (!title || !interpret) return;

    const metadataKey = `${interpret}::${title}`.toLowerCase();
    if (metadataKey === lastMetadataKey || isMetadataLoading) return;

    // Verhindert wiederholte API-Calls fuer denselben Suchbegriff in kurzer Zeit.
    if (
      metadataKey === lastRequestedMetadataKey &&
      Date.now() - lastMetadataRequestAt < METADATA_COOLDOWN_MS
    ) {
      return;
    }

    lastRequestedMetadataKey = metadataKey;
    lastMetadataRequestAt = Date.now();

    // Alte Metadaten sofort entfernen, sobald eine neue Suche gestartet wird.
    song.duration = '';
    song.composer = '';
    song.texter = '';
    song.ytlink = '';

    isMetadataLoading = true;
    try {
      const data = await getSongCrawlerMetadata(interpret, title);
      lastMetadataKey = metadataKey;

      if (data?.duration) {
        song.duration = data.duration;
      }
      if (data?.composer) {
        song.composer = data.composer;
      }
      if (data?.texter) {
        song.texter = data.texter;
      }
      if (data?.ytlink) {
        song.ytlink = data.ytlink;
      }
    } catch {
      // Keine Metadaten gefunden oder API nicht erreichbar -> Formular bleibt editierbar.
    } finally {
      isMetadataLoading = false;
    }
  }

  function scheduleMetadataFetch() {
    if (metadataDebounceTimer) {
      clearTimeout(metadataDebounceTimer);
    }
    metadataDebounceTimer = setTimeout(() => {
      maybeFetchSongMetadata();
    }, METADATA_DEBOUNCE_MS);
  }

  function markBlurAndMaybeFetch(fieldKey) {
    if (fieldKey === 'title') {
      titleBlurred = true;
    }
    if (fieldKey === 'interpret') {
      interpretBlurred = true;
    }
    if (titleBlurred && interpretBlurred) {
      scheduleMetadataFetch();
    }
  }

  function submit() {
    const dataToSend = { ...song };
    getSongFieldsDetails($appConfig).forEach(field => {
      if (field.type === 'multi_select' && Array.isArray(dataToSend[field.key])) {
        dataToSend[field.key] = dataToSend[field.key].join(' + ');
      }
    });
    modalState.close(dataToSend)
  }

</script>

<div class="card p-6 space-y-4 max-w-4xl w-[90vw] max-h-[90vh] flex flex-col modal-base">
    <header class="flex justify-between items-center flex-shrink-0">
      <h4 class="h5 mb-3">Neuer Song</h4>
    </header>
    <div class="overflow-y-auto flex-grow">
        <form class=" card bg-surface-1 p-4 rounded shadow mb-4" onsubmit={submit}>
          {#each songFieldsDetails as songField}
            {#if songField.type === 'multi_select'}
                <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
                  <label>{songField.label}</label>
                  <SingersList
                    bind:selected={song[songField.key]}
                    options={songField.options ?? []}
                    placeholder="{songField.label} hinzufügen"
                  />
                </div>
            {:else if songField.type != "singer_list"}
                <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
                  <label>
                    {songField.label}
                    {#if songField.required}
                      <span class="text-danger ms-1" style="color:red; white-space:nowrap;">*</span>
                    {/if}
                  </label>

                  {#if songField.type === 'option' && Array.isArray(songField.options)}
                    <select
                      class="input flex-grow-1 select"
                      bind:value={song[songField.key]}
                      required={songField.required}
                    >
                      {#each songField.options as o}
                        <option value={o.key}>{o.label}</option>
                      {/each}
                    </select>
                  {:else if songField.type === "time"}
                    <input
                      type="time"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      placeholder={songField.label}
                      required={songField.required}
                      step="1"
                    />
                  {:else if songField.type === "date"}
                    <input
                      type="date"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      placeholder={songField.label}
                      required={songField.required}
                    />
                  {:else}
                    <input
                      type="text"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      oninput={() => {
                        if (songField.key === 'title' || songField.key === 'interpret') {
                          lastMetadataKey = '';
                          lastRequestedMetadataKey = '';
                          if (songField.key === 'title') {
                            titleBlurred = false;
                          }
                          if (songField.key === 'interpret') {
                            interpretBlurred = false;
                          }
                          checkDuplicate();
                        }
                      }}
                          onchange={() => {
                            if (songField.key === 'title' || songField.key === 'interpret') {
                              lastMetadataKey = '';
                              lastRequestedMetadataKey = '';
                              if (songField.key === 'title') {
                                titleBlurred = false;
                              }
                              if (songField.key === 'interpret') {
                                interpretBlurred = false;
                              }
                              checkDuplicate();
                            }
                          }}
                      onblur={() => {
                        if (songField.key === 'title' || songField.key === 'interpret') {
                          markBlurAndMaybeFetch(songField.key);
                        }
                      }}
                      placeholder={songField.label}
                      required={songField.required}
                      minlength="1"
                      maxlength="255"
                      pattern=".*\S+.*"
                    />
                  {/if}
                </div>

                {#if songField.key === 'interpret' && duplicateMatch}
                  <div
                    class="mt-2 mb-3"
                    in:fade={{ duration: 220 }}
                    out:fade={{ duration: 140 }}
                  >
                  <div
                    class="alert variant-soft-warning rounded-xl border border-warning-300/50 shadow-sm"
                    role="status"
                    aria-live="polite"
                    in:fly={{ y: -6, duration: 220 }}
                    out:fly={{ y: -4, duration: 140 }}
                  >
                    <div class="alert-message flex items-start gap-2 leading-relaxed">
                      <span class="text-warning-600 dark:text-warning-400 mt-[1px]">⚠</span>
                      <span>
                        Dieser Song ist wahrscheinlich bereits vorhanden: <strong>{duplicateMatch.interpret} - {duplicateMatch.title}</strong>
                        (Status: <strong>{getStatusLabel(duplicateMatch.status)}</strong>). Du kannst trotzdem speichern.
                      </span>
                    </div>
                  </div>
                  </div>
                {/if}

                {#if songField.key === 'interpret' && isMetadataLoading}
                  <div class="mt-1 mb-3 text-sm text-surface-600 dark:text-surface-300 flex items-center gap-2" role="status" aria-live="polite">
                    <span class="inline-block w-4 h-4 border-2 border-surface-400 border-t-primary-500 rounded-full animate-spin" aria-hidden="true"></span>
                    <span>Lade Metadaten...</span>
                  </div>
                {/if}
            {/if}
          {/each}

          <div class="flex justify-end gap-2 mt-2">
            <button class="btn btn-secondary border" type="button" onclick={modalState.close}>Abbrechen</button>
            <button class="btn btn-primary border" type="submit">Erstellen</button>
          </div>
        </form>
    </div>
</div>