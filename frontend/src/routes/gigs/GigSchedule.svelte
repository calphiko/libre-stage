<script>
  import { updateGigScheduleBulk } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';

  let {
    gig,
    canEdit = false,
    scheduleData = null,
    onScheduleUpdated = () => {}
  } = $props();

  const { showError, showSuccess } = createMessageHelpers();

  let editMode = $state(false);
  let formRows = $state([]);
  let inlineError = $state('');
  let savingAll = $state(false);
  let newRowCounter = 0;

  function toNaiveIso(datePart, timePart) {
    const safeTime = timePart?.length === 5 ? `${timePart}:00` : timePart;
    return `${datePart}T${safeTime}`;
  }

  function splitIsoToDateTime(iso) {
    const [datePart, timePartRaw] = String(iso ?? '').split('T');
    return {
      date: datePart ?? '',
      time: (timePartRaw ?? '').slice(0, 5)
    };
  }

  function formatDateTime(dtStr) {
    if (!dtStr) return '-';
    const dt = new Date(dtStr);
    if (Number.isNaN(dt.getTime())) return dtStr;
    return dt.toLocaleString('de-DE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  function buildFormRows() {
    formRows = (scheduleData?.items ?? []).map((item, index) => {
      const { date, time } = splitIsoToDateTime(item.item_datetime);
      return {
        row_key: item.id ?? `seed-${index}-${item.item_datetime}`,
        id: item.id,
        is_fixed: !!item.is_fixed,
        date,
        time,
        was: item.was ?? '',
        wer: item.wer ?? '',
        wo: item.wo ?? ''
      };
    }).sort((a, b) => {
      const aIso = toNaiveIso(a.date, a.time || '00:00');
      const bIso = toNaiveIso(b.date, b.time || '00:00');
      if (aIso < bIso) return -1;
      if (aIso > bIso) return 1;
      return (b.is_fixed ? 1 : 0) - (a.is_fixed ? 1 : 0);
    });
  }

  $effect(() => {
    if (editMode) {
      buildFormRows();
      inlineError = '';
    }
  });

  function addRow() {
    const newRow = {
      row_key: `new-${newRowCounter++}`,
      id: null,
      is_fixed: false,
      date: gig?.datum ?? '',
      time: '',
      was: '',
      wer: '',
      wo: ''
    };

    formRows = [
      ...formRows,
      newRow,
    ];
  }

  function hasCollision(targetIso, ignoreId = null) {
    const collidesWithFixed = formRows.some((row) => row.is_fixed && toNaiveIso(row.date, row.time) === targetIso);
    if (collidesWithFixed) return true;

    return formRows.some((row) => {
      if (row.is_fixed) return false;
      if (!row.date || !row.time) return false;
      const rowIso = toNaiveIso(row.date, row.time);
      return rowIso === targetIso && row.id !== ignoreId;
    });
  }

  function removeUnsavedRow(index) {
    formRows = formRows.filter((_, rowIndex) => rowIndex !== index);
  }

  async function saveAll() {
    inlineError = '';

    const editableRows = formRows.filter((row) => !row.is_fixed);
    for (const row of editableRows) {
      if (!row.date || !row.time || !row.was || !row.wer || !row.wo) {
        inlineError = 'Bitte alle flexiblen Eintraege vollstaendig ausfuellen.';
        return;
      }
      const itemDatetime = toNaiveIso(row.date, row.time);
      if (hasCollision(itemDatetime, row.id)) {
        inlineError = 'Ein Zeitpunkt ist doppelt oder kollidiert mit einem festen Eintrag.';
        return;
      }
    }

    const payload = {
      items: editableRows.map((row) => ({
        id: row.id ?? undefined,
        item_datetime: toNaiveIso(row.date, row.time),
        was: row.was,
        wer: row.wer,
        wo: row.wo,
      }))
    };

    savingAll = true;
    try {
      const updated = await updateGigScheduleBulk(null, gig.id, payload);
      onScheduleUpdated(updated);
      buildFormRows();
      showSuccess('Ablaufplan gespeichert');
    } catch (e) {
      inlineError = e.message ?? 'Fehler beim Speichern.';
      showError(inlineError);
    } finally {
      savingAll = false;
    }
  }

  function removeItem(row, index) {
    if (row.is_fixed) return;
    removeUnsavedRow(index);
  }
</script>

<div class="card variant-ghost-surface p-4 rounded-lg space-y-4">
  {#if !scheduleData}
    <p class="text-sm text-on-surface-variant">Ablaufplan wird geladen...</p>
  {:else}
    {#if canEdit}
      <div class="flex justify-end">
        <label class="flex items-center gap-2 text-sm cursor-pointer select-none">
          <span class="text-on-surface-variant">Edit-Mode</span>
          <input type="checkbox" class="checkbox" bind:checked={editMode} />
        </label>
      </div>
    {/if}

    {#if !editMode}
      <div class="space-y-2">
        {#if scheduleData.items.length === 0}
          <p class="text-sm text-on-surface-variant">Noch keine Eintraege vorhanden.</p>
        {:else}
          {#each scheduleData.items as item}
            <div class="flex flex-wrap items-center justify-between gap-2 border border-surface-300 dark:border-surface-700 rounded-md p-3">
              <div>
                <div class="font-semibold text-sm flex items-center gap-2">
                  <span>{formatDateTime(item.item_datetime)}</span>
                  {#if item.is_fixed}
                    <span class="badge variant-soft-secondary text-xs">fix</span>
                  {/if}
                </div>
                <div class="text-sm text-on-surface">{item.was}</div>
                <div class="text-xs text-on-surface-variant">{item.wer} - {item.wo}</div>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    {:else}
      <div class="space-y-3">
        <div class="flex justify-between items-center">
          <h5 class="font-semibold text-sm">Ablaufplan bearbeiten (komplett)</h5>
          <button type="button" class="btn btn-sm variant-filled-primary" onclick={addRow}>Eintrag hinzufuegen</button>
        </div>

        {#if formRows.filter((row) => !row.is_fixed).length === 0}
          <p class="text-sm text-on-surface-variant">Keine flexiblen Eintraege vorhanden.</p>
        {/if}

        {#each formRows as row, index (row.row_key)}
          <div class="p-3 rounded-md border border-surface-300 dark:border-surface-700 space-y-2">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
              <input class="input" type="date" bind:value={row.date} disabled={row.is_fixed} />
              <input class="input" type="time" bind:value={row.time} disabled={row.is_fixed} />
              <input class="input" type="text" bind:value={row.was} placeholder="Was" maxlength="512" disabled={row.is_fixed} />
              <input class="input" type="text" bind:value={row.wer} placeholder="Wer" maxlength="512" disabled={row.is_fixed} />
              <input class="input md:col-span-2" type="text" bind:value={row.wo} placeholder="Wo" maxlength="512" disabled={row.is_fixed} />
            </div>
            <div class="flex gap-2">
              {#if row.is_fixed}
                <span class="badge variant-soft-secondary text-xs">fix</span>
              {:else}
                <button
                  type="button"
                  class="btn btn-sm variant-filled-error"
                  onclick={() => removeItem(row, index)}
                >Loeschen</button>
              {/if}
            </div>
          </div>
        {/each}

        <div class="pt-2">
          <button type="button" class="btn btn-sm variant-filled-success" onclick={saveAll} disabled={savingAll}>
            Gesamten Ablaufplan speichern
          </button>
        </div>

        {#if inlineError}
          <p class="text-sm text-error-500">{inlineError}</p>
        {/if}
      </div>
    {/if}
  {/if}
</div>








