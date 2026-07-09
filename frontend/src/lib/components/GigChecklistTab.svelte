<!--
  libre-stage - Band rehearsal and gig management software
  Copyright (C) 2026  libre-stage contributors
  SPDX-License-Identifier: GPL-3.0-or-later
-->

<script>
  import { onMount } from 'svelte';
  import {
    getGigChecklist,
    createChecklistItem,
    updateChecklistItem,
    toggleChecklistItemDone,
    deleteChecklistItem,
    getUserList,
  } from '$lib/api.js';
  import { modalState } from '$lib/modalState.js';
  import ChecklistItemDetailModal from '$lib/components/ChecklistItemDetailModal.svelte';

  /** @type {{ id: number, datum?: string, begin?: string }} */
  let { gig = null, canEdit = false } = $props();

  // ── State ──────────────────────────────────────────────────────────────────
  /** @type {any[]} */
  let items = $state([]);
  let loading = $state(false);
  let error   = $state('');

  // Users for assignee dropdown
  /** @type {any[]} */
  let musicians = $state([]);

  // Form state
  let formOpen = $state(false);
  let editingItem = $state(null);   // null = new, else existing item
  let form = $state(emptyForm());

  function emptyForm() {
    return {
      title: '',
      category: '',
      assignee_user_id: null,
      assignee_name: '',
      due_datetime: '',
      done: false,
      position: 0,
      comment: '',
    };
  }

  // ── View mode ──────────────────────────────────────────────────────────────
  /** @type {'list' | 'kanban'} */
  let viewMode = $state('list');

  // ── Derived ────────────────────────────────────────────────────────────────
  /** True wenn das Gig-Datum in der Vergangenheit liegt (Vergleich ohne Uhrzeit) */
  let gigIsPast = $derived(
    gig?.datum ? new Date(gig.datum) < new Date(new Date().toDateString()) : false
  );

  let total = $derived(items.length);
  let doneCount = $derived(items.filter(i => i.done).length);
  let progressPct = $derived(total > 0 ? Math.round((doneCount / total) * 100) : 0);

  // Group items by category
  let grouped = $derived(() => {
    /** @type {Record<string, any[]>} */
    const g = {};
    for (const item of items) {
      const cat = item.category || '(ohne Kategorie)';
      if (!g[cat]) g[cat] = [];
      g[cat].push(item);
    }
    return g;
  });

  // Kanban columns
  let openItems = $derived(items.filter(i => !i.done));
  let doneItems = $derived(items.filter(i => i.done));

  // Categories used so far (for datalist)
  let usedCategories = $derived([...new Set(items.map(i => i.category).filter(Boolean))]);

  // ── API calls ──────────────────────────────────────────────────────────────
  async function load() {
    if (!gig?.id) return;
    loading = true; error = '';
    try {
      items = await getGigChecklist(null, gig.id);
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function loadMusicians() {
    if (musicians.length) return;
    try {
      const all = await getUserList();
      musicians = all.filter(u => u.musician !== false);
    } catch { /* non-fatal */ }
  }

  async function toggle(item) {
    try {
      items = await toggleChecklistItemDone(null, gig.id, item.id);
    } catch (e) {
      error = e.message;
    }
  }

  async function remove(item) {
    try {
      items = await deleteChecklistItem(null, gig.id, item.id);
    } catch (e) {
      error = e.message;
    }
  }

  function openNew() {
    if (gigIsPast) return;
    editingItem = null;
    form = emptyForm();
    formOpen = true;
    loadMusicians();
  }

  function openEdit(item) {
    editingItem = item;
    form = {
      title: item.title,
      category: item.category ?? '',
      assignee_user_id: item.assignee_user_id ?? null,
      assignee_name: item.assignee_name ?? '',
      due_datetime: item.due_datetime
        ? item.due_datetime.slice(0, 16)   // 'YYYY-MM-DDTHH:MM'
        : '',
      done: item.done,
      position: item.position,
      comment: item.comment ?? '',
    };
    formOpen = true;
    loadMusicians();
  }

  async function saveForm(e) {
    e.preventDefault();
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
      if (editingItem) {
        items = await updateChecklistItem(null, gig.id, editingItem.id, payload);
      } else {
        items = await createChecklistItem(null, gig.id, payload);
      }
      formOpen = false;
    } catch (err) {
      error = err.message;
    }
  }

  function cancelForm() {
    formOpen = false;
    editingItem = null;
  }

  function openDetail(item) {
    modalState.trigger({
      component: ChecklistItemDetailModal,
      meta: {
        item: { ...item, gig_id: gig.id, gig_name: gig.name, gig_datum: gig.datum },
        canEdit,
        onItemUpdated: (updatedItems) => { items = updatedItems; },
      },
    });
  }

  onMount(load);
</script>

<div class="checklist-tab text-sm space-y-3">

  <!-- ── Header: progress + view toggle ──────────────────────────────── -->
  <div class="flex items-center justify-between gap-3 flex-wrap">
    <div class="flex items-center gap-3 flex-1 min-w-0">
      <!-- Progress bar -->
      {#if total > 0}
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 mb-0.5">
            <span class="text-xs text-on-surface-variant">{doneCount}/{total} erledigt</span>
            <span class="text-xs font-semibold {progressPct === 100 ? 'text-success-600' : 'text-primary-500'}">{progressPct} %</span>
          </div>
          <div class="w-full bg-surface-200 dark:bg-surface-700 rounded-full h-2">
            <div
              class="h-2 rounded-full transition-all duration-300 {progressPct === 100 ? 'bg-success-500' : 'bg-primary-500'}"
              style="width:{progressPct}%"
            ></div>
          </div>
        </div>
      {:else}
        <span class="text-xs text-on-surface-variant italic">Noch keine Einträge</span>
      {/if}
    </div>

    <!-- Actions -->
    <div class="flex gap-1 flex-shrink-0 items-center">
      <!-- View toggle -->
      <div class="flex rounded-lg overflow-hidden border border-outline-variant text-xs">
        <button
          class="px-2 py-1 transition-colors {viewMode === 'list'
            ? 'bg-primary-500 text-white'
            : 'bg-surface-1 hover:bg-surface-200 dark:hover:bg-surface-700'}"
          type="button"
          title="Listenansicht"
          onclick={() => viewMode = 'list'}
        >☰ OPL</button>
        <button
          class="px-2 py-1 transition-colors border-l border-outline-variant {viewMode === 'kanban'
            ? 'bg-primary-500 text-white'
            : 'bg-surface-1 hover:bg-surface-200 dark:hover:bg-surface-700'}"
          type="button"
          title="Kanban-Board"
          onclick={() => viewMode = 'kanban'}
        >⬛ Kanban</button>
      </div>
      {#if canEdit && !gigIsPast}
        <button class="btn btn-sm variant-filled-primary" onclick={openNew}>+</button>
      {:else if canEdit && gigIsPast}
        <span class="text-xs text-on-surface-variant italic" title="Vergangene Gigs können nicht mehr bearbeitet werden">
          🔒
        </span>
      {/if}
    </div>
  </div>

  {#if error}
    <p class="text-xs text-error-500">{error}</p>
  {/if}

  <!-- ── Add/Edit form ────────────────────────────────────────────────── -->
  {#if formOpen && canEdit && !gigIsPast}
    <form
      class="card variant-ghost-surface p-3 rounded-lg space-y-2 border border-outline-variant"
      onsubmit={saveForm}
    >
      <h5 class="text-xs font-semibold">{editingItem ? 'Eintrag bearbeiten' : 'Neuer Eintrag'}</h5>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-2">
        <!-- Title -->
        <div class="md:col-span-2">
          <label class="text-xs text-on-surface-variant block mb-0.5">Titel *</label>
          <input
            class="input input-sm w-full"
            type="text"
            bind:value={form.title}
            required
            placeholder="z.B. PA-Anlage laden"
          />
        </div>

        <!-- Category -->
        <div>
          <label class="text-xs text-on-surface-variant block mb-0.5">Kategorie</label>
          <input
            class="input input-sm w-full"
            type="text"
            list="checklist-cats"
            bind:value={form.category}
            placeholder="z.B. Equipment"
          />
          <datalist id="checklist-cats">
            {#each usedCategories as cat}
              <option value={cat}></option>
            {/each}
            <option value="Equipment"></option>
            <option value="Soundcheck"></option>
            <option value="Aufbau"></option>
            <option value="Abbau"></option>
            <option value="Sonstiges"></option>
          </datalist>
        </div>

        <!-- Fälligkeitsdatum -->
        <div>
          <label class="text-xs text-on-surface-variant block mb-0.5">Fällig am</label>
          <input
            class="input input-sm w-full"
            type="datetime-local"
            bind:value={form.due_datetime}
          />
        </div>

        <!-- Zuständig (Bandmitglied) -->
        <div>
          <label class="text-xs text-on-surface-variant block mb-0.5">Zuständig (Bandmitglied)</label>
          <select
            class="input input-sm w-full"
            bind:value={form.assignee_user_id}
            onchange={() => { if (form.assignee_user_id) form.assignee_name = ''; }}
          >
            <option value={null}>– Keine Auswahl –</option>
            {#each musicians as m}
              <option value={m.id}>{m.clear_name || m.user_name}</option>
            {/each}
          </select>
        </div>

        <!-- Zuständig (freier Text) -->
        <div>
          <label class="text-xs text-on-surface-variant block mb-0.5">Zuständig (extern)</label>
          <input
            class="input input-sm w-full"
            type="text"
            bind:value={form.assignee_name}
            placeholder="Name der externen Person"
            disabled={!!form.assignee_user_id}
          />
        </div>
      </div>

      <!-- Done checkbox when editing -->
      {#if editingItem}
        <label class="flex items-center gap-2 text-xs cursor-pointer">
          <input type="checkbox" class="checkbox" bind:checked={form.done} />
          Bereits erledigt
        </label>
      {/if}

      <!-- Kommentar / Protokoll -->
      <div class="md:col-span-2">
        <label class="text-xs text-on-surface-variant block mb-0.5">Kommentar / Ergebnis</label>
        <textarea
          class="textarea textarea-sm w-full text-xs"
          rows="2"
          bind:value={form.comment}
          placeholder="z.B. Erledigt – PA steht bereit. Kabel fehlt noch."
        ></textarea>
      </div>

      <div class="flex gap-2 mt-1">
        <button class="btn btn-sm variant-filled-primary border" type="submit">
          {editingItem ? 'Speichern' : 'Hinzufügen'}
        </button>
        <button class="btn btn-sm variant-ghost border" type="button" onclick={cancelForm}>
          Abbrechen
        </button>
      </div>
    </form>
  {/if}

  <!-- ── List view ────────────────────────────────────────────────────── -->
  {#if loading}
      <p class="text-xs text-on-surface-variant">Lade …</p>
    {:else if total === 0}
      <div class="text-center py-6 text-on-surface-variant text-xs italic">
        Noch keine Einträge. {canEdit ? 'Klicke auf „+ Eintrag" um loszulegen.' : ''}
      </div>
    {:else if viewMode === 'list'}
      {#each Object.entries(grouped()) as [cat, catItems]}
        <div>
          <p class="text-xs font-semibold text-on-surface-variant mb-1 uppercase tracking-wide">{cat}</p>
          <div class="space-y-1">
            {#each catItems as item (item.id)}
              <div class="flex items-center gap-2 px-2 py-1.5 rounded-lg
                          border border-outline-variant
                          {item.done ? 'opacity-60 bg-surface-100 dark:bg-surface-800' : 'bg-surface-1'}">

                <!-- Checkbox -->
                <button
                  class="flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center
                         transition-colors
                         {canEdit ? 'cursor-pointer' : 'cursor-default'}
                         {item.done
                           ? 'border-success-500 bg-success-500 text-white'
                           : 'border-outline-variant ' + (canEdit ? 'hover:border-primary-500' : '')}"
                  type="button"
                  onclick={() => canEdit && toggle(item)}
                  title={canEdit ? (item.done ? 'Als offen markieren' : 'Als erledigt markieren') : ''}
                  disabled={!canEdit}
                >
                  {#if item.done}
                    <span class="text-xs leading-none">✓</span>
                  {/if}
                </button>

                <!-- Title + meta -->
                <button
                  class="flex-1 min-w-0 text-left cursor-pointer hover:opacity-80 transition-opacity"
                  type="button"
                  onclick={() => openDetail(item)}
                >
                  <span class="text-xs font-medium {item.done ? 'line-through' : ''}">{item.title}</span>
                  <div class="flex flex-wrap gap-2 mt-0.5 text-xs text-on-surface-variant">
                    {#if item.due_datetime}
                      <span title="Fällig am">
                        🕐 {new Date(item.due_datetime).toLocaleString('de-DE', {
                          day: '2-digit', month: '2-digit', year: '2-digit',
                          hour: '2-digit', minute: '2-digit'
                        })}
                      </span>
                    {/if}
                    {#if item.assignee_clear_name || item.assignee_name}
                      <span title="Zuständig">
                        👤 {item.assignee_clear_name || item.assignee_name}
                      </span>
                    {/if}
                  </div>
                  {#if item.comment}
                    <p class="text-xs text-on-surface-variant italic mt-0.5 break-words">
                      💬 {item.comment}
                    </p>
                  {/if}
                </button>

                <!-- Actions (editor only) -->
                {#if canEdit}
                  <div class="flex-shrink-0 flex gap-1">
                    <button
                      class="btn-icon btn-icon-sm variant-ghost text-xs"
                      onclick={() => openEdit(item)}
                      title="Bearbeiten"
                    >✏️</button>
                    <button
                      class="btn-icon btn-icon-sm variant-ghost text-xs text-error-500"
                      onclick={() => remove(item)}
                      title="Löschen"
                    >🗑</button>
                  </div>
                {/if}

              </div>
            {/each}
          </div>
        </div>
      {/each}

    {:else}
      <!-- ── Kanban view ──────────────────────────────────────────────── -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">

        <!-- Column: Offen -->
        <div class="flex flex-col gap-2">
          <div class="flex items-center gap-2 pb-1 border-b-2 border-warning-400">
            <span class="text-xs font-bold uppercase tracking-wide text-warning-600 dark:text-warning-400">
              Offen
            </span>
            <span class="ml-auto text-xs font-semibold bg-warning-100 dark:bg-warning-900 text-warning-700 dark:text-warning-300 rounded-full px-2 py-0.5">
              {openItems.length}
            </span>
          </div>
          {#if openItems.length === 0}
            <p class="text-xs text-on-surface-variant italic text-center py-4">Keine offenen Punkte 🎉</p>
          {:else}
            {#each openItems as item (item.id)}
              <div class="card bg-surface-1 border border-outline-variant rounded-xl p-3 shadow-sm hover:shadow-md transition-shadow space-y-1.5">
                <!-- Header: title + actions -->
                <div class="flex items-start gap-1">
                  <button
                    class="flex-1 text-left text-xs font-semibold leading-snug hover:opacity-80 transition-opacity"
                    type="button"
                    onclick={() => openDetail(item)}
                  >{item.title}</button>
                  {#if canEdit}
                    <div class="flex gap-0.5 flex-shrink-0 mt-0.5">
                      <button
                        class="btn-icon btn-icon-sm variant-ghost text-xs"
                        onclick={() => openEdit(item)}
                        title="Bearbeiten"
                      >✏️</button>
                      <button
                        class="btn-icon btn-icon-sm variant-ghost text-xs text-error-500"
                        onclick={() => remove(item)}
                        title="Löschen"
                      >🗑</button>
                    </div>
                  {/if}
                </div>
                <!-- Category badge -->
                {#if item.category}
                  <span class="inline-block text-xs bg-primary-100 dark:bg-primary-900 text-primary-700 dark:text-primary-300 rounded-full px-2 py-0.5 leading-none">
                    {item.category}
                  </span>
                {/if}
                <!-- Meta -->
                <div class="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-on-surface-variant">
                  {#if item.due_datetime}
                    <span title="Fällig am">🕐 {new Date(item.due_datetime).toLocaleString('de-DE', {
                      day: '2-digit', month: '2-digit', year: '2-digit',
                      hour: '2-digit', minute: '2-digit'
                    })}</span>
                  {/if}
                  {#if item.assignee_clear_name || item.assignee_name}
                    <span title="Zuständig">👤 {item.assignee_clear_name || item.assignee_name}</span>
                  {/if}
                </div>
                {#if item.comment}
                  <p class="text-xs text-on-surface-variant italic break-words">💬 {item.comment}</p>
                {/if}
                <!-- Mark done button -->
                {#if canEdit}
                  <button
                    class="w-full mt-1 btn btn-sm variant-ghost border border-success-500 text-success-600 dark:text-success-400 hover:bg-success-50 dark:hover:bg-success-950 text-xs"
                    type="button"
                    onclick={() => toggle(item)}
                  >✓ Als erledigt markieren</button>
                {/if}
              </div>
            {/each}
          {/if}
        </div>

        <!-- Column: Erledigt -->
        <div class="flex flex-col gap-2">
          <div class="flex items-center gap-2 pb-1 border-b-2 border-success-400">
            <span class="text-xs font-bold uppercase tracking-wide text-success-600 dark:text-success-400">
              Erledigt
            </span>
            <span class="ml-auto text-xs font-semibold bg-success-100 dark:bg-success-900 text-success-700 dark:text-success-300 rounded-full px-2 py-0.5">
              {doneItems.length}
            </span>
          </div>
          {#if doneItems.length === 0}
            <p class="text-xs text-on-surface-variant italic text-center py-4">Noch nichts erledigt.</p>
          {:else}
            {#each doneItems as item (item.id)}
              <div class="card bg-surface-100 dark:bg-surface-800 border border-outline-variant rounded-xl p-3 shadow-sm opacity-70 hover:opacity-90 transition-opacity space-y-1.5">
                <!-- Header: title + actions -->
                <div class="flex items-start gap-1">
                  <button
                    class="flex-1 text-left text-xs font-semibold leading-snug line-through hover:opacity-80 transition-opacity"
                    type="button"
                    onclick={() => openDetail(item)}
                  >{item.title}</button>
                  {#if canEdit}
                    <div class="flex gap-0.5 flex-shrink-0 mt-0.5">
                      <button
                        class="btn-icon btn-icon-sm variant-ghost text-xs"
                        onclick={() => openEdit(item)}
                        title="Bearbeiten"
                      >✏️</button>
                      <button
                        class="btn-icon btn-icon-sm variant-ghost text-xs text-error-500"
                        onclick={() => remove(item)}
                        title="Löschen"
                      >🗑</button>
                    </div>
                  {/if}
                </div>
                <!-- Category badge -->
                {#if item.category}
                  <span class="inline-block text-xs bg-surface-200 dark:bg-surface-700 text-on-surface-variant rounded-full px-2 py-0.5 leading-none">
                    {item.category}
                  </span>
                {/if}
                <!-- Meta -->
                <div class="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-on-surface-variant">
                  {#if item.due_datetime}
                    <span title="Fällig am">🕐 {new Date(item.due_datetime).toLocaleString('de-DE', {
                      day: '2-digit', month: '2-digit', year: '2-digit',
                      hour: '2-digit', minute: '2-digit'
                    })}</span>
                  {/if}
                  {#if item.assignee_clear_name || item.assignee_name}
                    <span title="Zuständig">👤 {item.assignee_clear_name || item.assignee_name}</span>
                  {/if}
                </div>
                {#if item.comment}
                  <p class="text-xs text-on-surface-variant italic break-words">💬 {item.comment}</p>
                {/if}
                <!-- Mark open button -->
                {#if canEdit}
                  <button
                    class="w-full mt-1 btn btn-sm variant-ghost border border-outline-variant text-on-surface-variant hover:bg-surface-200 dark:hover:bg-surface-700 text-xs"
                    type="button"
                    onclick={() => toggle(item)}
                  >↩ Als offen markieren</button>
                {/if}
              </div>
            {/each}
          {/if}
        </div>

      </div>
    {/if}

</div>









