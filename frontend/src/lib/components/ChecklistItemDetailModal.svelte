<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors
  SPDX-License-Identifier: GPL-3.0-or-later
-->

<script>
  import { onMount } from 'svelte';
  import { modalState } from '$lib/modalState.js';
  import {
    getGigChecklist,
    toggleChecklistItemDone,
    updateChecklistItem,
    getUserList,
  } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';

  const { showError, showSuccess } = createMessageHelpers();

  let { meta = {} } = $props();
  const {
    item: initialItem,
    canEdit = false,
    onItemUpdated = () => {},
  } = meta;

  // ── State ──────────────────────────────────────────────────────────────────
  /** @type {any} */
  let item = $state(null);
  let loading = $state(true);
  let saving  = $state(false);
  let editMode = $state(false);
  let form = $state(emptyForm());
  /** @type {any[]} */
  let musicians = $state([]);
  let usedCategories = $derived(item ? [] : []);

  function emptyForm() {
    return { title: '', category: '', assignee_user_id: null, assignee_name: '',
             due_datetime: '', done: false, position: 0, comment: '' };
  }

  // ── Load full item on mount ─────────────────────────────────────────────────
  onMount(async () => {
    try {
      const items = await getGigChecklist(null, initialItem.gig_id);
      item = items.find(i => i.id === initialItem.id) ?? { ...initialItem };
    } catch {
      item = { ...initialItem };
    } finally {
      loading = false;
    }
  });

  // ── Helpers ─────────────────────────────────────────────────────────────────
  async function loadMusicians() {
    if (musicians.length) return;
    try {
      const all = await getUserList();
      musicians = all.filter(u => u.musician !== false);
    } catch { /* non-fatal */ }
  }

  function formatDT(val) {
    if (!val) return '–';
    return new Date(val).toLocaleString('de-DE', {
      day: '2-digit', month: '2-digit', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  }

  function formatDate(val) {
    if (!val) return '–';
    return new Date(val).toLocaleDateString('de-DE', {
      weekday: 'short', day: '2-digit', month: '2-digit', year: 'numeric',
    });
  }

  // ── Toggle done ─────────────────────────────────────────────────────────────
  async function toggleDone() {
    saving = true;
    try {
      const items = await toggleChecklistItemDone(null, item.gig_id, item.id);
      const updated = items.find(i => i.id === item.id);
      if (updated) item = updated;
      onItemUpdated(items);
      showSuccess(item.done ? 'Als erledigt markiert' : 'Als offen markiert');
    } catch (e) {
      showError(e.message ?? 'Fehler');
    } finally {
      saving = false;
    }
  }

  // ── Edit form ────────────────────────────────────────────────────────────────
  function openEdit() {
    form = {
      title:            item.title,
      category:         item.category ?? '',
      assignee_user_id: item.assignee_user_id ?? null,
      assignee_name:    item.assignee_name ?? '',
      due_datetime:     item.due_datetime ? item.due_datetime.slice(0, 16) : '',
      done:             item.done,
      position:         item.position ?? 0,
      comment:          item.comment ?? '',
    };
    editMode = true;
    loadMusicians();
  }

  function cancelEdit() {
    editMode = false;
  }

  async function saveEdit(e) {
    e.preventDefault();
    saving = true;
    const payload = {
      title:            form.title.trim(),
      category:         form.category.trim() || null,
      assignee_user_id: form.assignee_user_id || null,
      assignee_name:    form.assignee_user_id ? null : (form.assignee_name.trim() || null),
      due_datetime:     form.due_datetime || null,
      done:             form.done,
      position:         form.position,
      comment:          form.comment.trim() || null,
    };
    try {
      const items = await updateChecklistItem(null, item.gig_id, item.id, payload);
      const updated = items.find(i => i.id === item.id);
      if (updated) item = updated;
      onItemUpdated(items);
      editMode = false;
      showSuccess('Aufgabe gespeichert');
    } catch (e) {
      showError(e.message ?? 'Fehler beim Speichern');
    } finally {
      saving = false;
    }
  }
</script>

<div class="card p-5 w-[96vw] max-w-lg flex flex-col modal-base gap-4">

  <!-- Header -->
  <header class="flex justify-between items-start gap-3 flex-shrink-0">
    <div class="flex items-center gap-2 flex-wrap min-w-0">
      <span class="text-lg font-semibold truncate">
        {loading ? '…' : (item?.title ?? initialItem.title)}
      </span>
      {#if !loading && item}
        <span class="badge {item.done ? 'variant-soft-success' : 'variant-soft-warning'} text-xs flex-shrink-0">
          {item.done ? '✓ Erledigt' : '○ Offen'}
        </span>
      {/if}
    </div>
    <button class="btn-icon btn-icon-sm variant-ghost flex-shrink-0" onclick={() => modalState.close()}>✕</button>
  </header>

  {#if loading}
    <div class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
    </div>

  {:else if item}

    {#if !editMode}
      <!-- ── Detail view ─────────��────────────────────────────────────── -->
      <div class="space-y-3 text-sm overflow-y-auto max-h-[60vh] pr-1">

        <!-- Gig info -->
        <div class="card variant-ghost-surface p-3 rounded-lg space-y-1.5">
          <div class="flex justify-between gap-2">
            <span class="text-on-surface-variant">Gig</span>
            <span class="font-medium text-right">
              {item.gig?.name ?? initialItem.gig_name ?? '–'}
            </span>
          </div>
          {#if initialItem.gig_datum || item.gig?.datum}
            <div class="flex justify-between gap-2">
              <span class="text-on-surface-variant">Datum</span>
              <span class="font-medium">{formatDate(initialItem.gig_datum ?? item.gig?.datum)}</span>
            </div>
          {/if}
          {#if item.category}
            <div class="flex justify-between gap-2">
              <span class="text-on-surface-variant">Kategorie</span>
              <span class="badge variant-ghost text-xs">{item.category}</span>
            </div>
          {/if}
        </div>

        <!-- Assignee + Due -->
        {#if item.assignee_clear_name || item.assignee_name || item.due_datetime}
          <div class="card variant-ghost-surface p-3 rounded-lg space-y-1.5">
            {#if item.assignee_clear_name || item.assignee_name}
              <div class="flex justify-between gap-2">
                <span class="text-on-surface-variant">👤 Zuständig</span>
                <span class="font-medium">{item.assignee_clear_name || item.assignee_name}</span>
              </div>
            {/if}
            {#if item.due_datetime}
              {@const isOverdue = !item.done && new Date(item.due_datetime) < new Date()}
              <div class="flex justify-between gap-2">
                <span class="text-on-surface-variant">🕐 Fällig</span>
                <span class="font-medium {isOverdue ? 'text-error-600 dark:text-error-400' : ''}">
                  {formatDT(item.due_datetime)}
                  {#if isOverdue}<span class="text-xs ml-1">(überfällig)</span>{/if}
                </span>
              </div>
            {/if}
          </div>
        {/if}

        <!-- Comment -->
        {#if item.comment}
          <div class="card variant-ghost-surface p-3 rounded-lg">
            <p class="text-xs font-semibold text-on-surface-variant mb-1">💬 Kommentar / Ergebnis</p>
            <p class="text-sm whitespace-pre-wrap">{item.comment}</p>
          </div>
        {:else}
          <p class="text-xs text-on-surface-variant italic px-1">Noch kein Kommentar hinterlegt.</p>
        {/if}
      </div>

      <!-- Actions -->
      {#if canEdit}
        <div class="flex flex-wrap gap-2 pt-2 border-t border-surface-300 flex-shrink-0">
          <button
            class="btn btn-sm {item.done ? 'variant-outline-warning border border-warning-500' : 'variant-filled-success'}"
            onclick={toggleDone}
            disabled={saving}
          >
            {item.done ? '↩ Als offen markieren' : '✓ Erledigt'}
          </button>
          <button class="btn btn-sm variant-filled-primary" onclick={openEdit}>
            ✏️ Bearbeiten
          </button>
        </div>
      {/if}

    {:else}
      <!-- ── Edit form ────────────────────────────────────────────────── -->
      <form class="space-y-2 overflow-y-auto max-h-[65vh] pr-1" onsubmit={saveEdit}>

        <div class="grid grid-cols-1 gap-2">
          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Titel *</label>
            <input class="input input-sm w-full" type="text" bind:value={form.title} required />
          </div>

          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Kategorie</label>
            <input class="input input-sm w-full" type="text" list="detail-cats"
                   bind:value={form.category} placeholder="z.B. Equipment" />
            <datalist id="detail-cats">
              <option value="Equipment"></option>
              <option value="Soundcheck"></option>
              <option value="Aufbau"></option>
              <option value="Abbau"></option>
              <option value="Sonstiges"></option>
            </datalist>
          </div>

          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Fällig am</label>
            <input class="input input-sm w-full" type="datetime-local" bind:value={form.due_datetime} />
          </div>

          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Zuständig (Bandmitglied)</label>
            <select class="input input-sm w-full" bind:value={form.assignee_user_id}
                    onchange={() => { if (form.assignee_user_id) form.assignee_name = ''; }}>
              <option value={null}>– Keine Auswahl –</option>
              {#each musicians as m}
                <option value={m.id}>{m.clear_name || m.user_name}</option>
              {/each}
            </select>
          </div>

          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Zuständig (extern)</label>
            <input class="input input-sm w-full" type="text" bind:value={form.assignee_name}
                   placeholder="Name der externen Person" disabled={!!form.assignee_user_id} />
          </div>

          <label class="flex items-center gap-2 text-xs cursor-pointer">
            <input type="checkbox" class="checkbox" bind:checked={form.done} />
            Erledigt
          </label>

          <div>
            <label class="text-xs text-on-surface-variant block mb-0.5">Kommentar / Ergebnis</label>
            <textarea class="textarea textarea-sm w-full text-xs" rows="3"
                      bind:value={form.comment}
                      placeholder="z.B. Erledigt – PA steht bereit."></textarea>
          </div>
        </div>

        <div class="flex gap-2 pt-2 border-t border-surface-300 flex-shrink-0">
          <button class="btn btn-sm variant-filled-primary" type="submit" disabled={saving}>
            {saving ? 'Speichern…' : 'Speichern'}
          </button>
          <button class="btn btn-sm variant-ghost border" type="button" onclick={cancelEdit}>
            Abbrechen
          </button>
        </div>
      </form>
    {/if}

  {:else}
    <p class="text-sm text-on-surface-variant italic">Aufgabe nicht gefunden.</p>
  {/if}

  <!-- Footer -->
  {#if !editMode}
    <footer class="flex justify-end pt-2 border-t border-surface-300 flex-shrink-0">
      <button class="btn variant-ghost btn-sm" onclick={() => modalState.close()}>Schließen</button>
    </footer>
  {/if}

</div>

