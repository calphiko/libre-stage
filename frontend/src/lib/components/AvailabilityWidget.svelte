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
  import { getAvailability, setAvailability, deleteAvailability } from '$lib/api.js';

  /**
   * @typedef {{ id: number, user_name: string, clear_name?: string, musician?: boolean }} UserLike
   */

  let {
    /** @type {'rehearsal'|'gig'} */
    eventType,
    /** @type {number} */
    eventId,
    /** @type {number|null} */
    currentUserId = null,
    /**
     * Optional list of all band musicians.
     * When provided the widget also shows who has not responded yet.
     * @type {UserLike[]}
     */
    musicians = [],
    /**
     * Wenn true, ist das Event vergangen – Rückmeldungen können nur gelesen,
     * nicht mehr geändert werden.
     */
    readonly = false,
  } = $props();

  // ── State ─────────────────────────────────────────────────────────────────
  /** @type {{ availabilities: any[], summary: Record<string,number>, my_status: string|null }|null} */
  let data = $state(null);
  let loading = $state(false);
  let saving  = $state(false);
  let error   = $state('');

  // Own-entry form
  let myStatus        = $state('');   // 'available' | 'unavailable' | 'maybe' | ''
  let myComment       = $state('');
  let substituteName  = $state('');
  let substituteUserId = $state(null);

  // ── Derived ───────────────────────────────��───────────────────────────────
  let showSubstituteForm = $derived(myStatus === 'unavailable');

  let available   = $derived(data?.availabilities?.filter(a => a.status === 'available')   ?? []);
  let maybe       = $derived(data?.availabilities?.filter(a => a.status === 'maybe')       ?? []);
  let unavailable = $derived(data?.availabilities?.filter(a => a.status === 'unavailable') ?? []);

  let respondedIds = $derived(new Set(data?.availabilities?.map(a => a.user_id) ?? []));
  let notResponded = $derived(
    musicians.filter(m => m.musician !== false && !respondedIds.has(m.id))
  );

  // Musician dropdown for substitute selection (exclude current user)
  let substituteOptions = $derived(
    musicians.filter(m => m.musician !== false && m.id !== currentUserId)
  );

  // ── Helpers ───────────────────────────────────────────────────────────────
  function displayName(entry) {
    return entry.clear_name || entry.user_name || '?';
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  async function load() {
    if (!eventId) return;
    loading = true;
    error   = '';
    try {
      data = await getAvailability(null, eventType, eventId);
      const mine = data?.availabilities?.find(a => a.user_id === currentUserId);
      if (mine) {
        myStatus         = mine.status;
        myComment        = mine.comment        ?? '';
        substituteName   = mine.substitute_name ?? '';
        substituteUserId = mine.substitute_user_id ?? null;
      } else {
        myStatus = myComment = substituteName = '';
        substituteUserId = null;
      }
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }

  async function save() {
    if (!myStatus || saving) return;
    saving = true;
    error  = '';
    try {
      data = await setAvailability(null, eventType, eventId, {
        status:              myStatus,
        comment:             myComment             || null,
        substitute_name:     substituteName        || null,
        substitute_user_id:  substituteUserId      || null,
      });
    } catch (e) {
      error = e.message;
    } finally {
      saving = false;
    }
  }

  async function selectStatus(status) {
    myStatus = status;
    if (status !== 'unavailable') {
      substituteName   = '';
      substituteUserId = null;
    }
    await save();
  }

  async function clearEntry() {
    if (saving) return;
    saving = true;
    error  = '';
    try {
      data             = await deleteAvailability(null, eventType, eventId);
      myStatus         = myComment = substituteName = '';
      substituteUserId = null;
    } catch (e) {
      error = e.message;
    } finally {
      saving = false;
    }
  }

  function onSubstituteUserChange() {
    if (substituteUserId) {
      const u = substituteOptions.find(m => m.id == substituteUserId);
      substituteName = u ? (u.clear_name || u.user_name) : '';
    } else {
      substituteName = '';
    }
    save();
  }

  onMount(load);
</script>

<div class="availability-widget text-sm">

  {#if loading}
    <p class="text-xs text-on-surface-variant py-2">Lade Verfügbarkeiten …</p>

  {:else}

    <!-- ── Eigene Verfügbarkeit ─────────────────────────────────────── -->
    <div class="mb-3">
      <p class="text-xs font-semibold text-on-surface-variant mb-1.5">Meine Verfügbarkeit:</p>

      {#if readonly}
        <p class="text-xs text-on-surface-variant italic">
          🔒 Vergangenes Event – keine Rückmeldung mehr möglich.
        </p>
        {#if myStatus}
          <div class="mt-1.5 flex gap-2">
            {#if myStatus === 'available'}
              <span class="badge variant-filled-success text-xs">✅ Dabei</span>
            {:else if myStatus === 'maybe'}
              <span class="badge variant-filled-warning text-xs">❓ Vielleicht</span>
            {:else if myStatus === 'unavailable'}
              <span class="badge variant-filled-error text-xs">❌ Nicht dabei</span>
            {/if}
          </div>
        {/if}
      {:else}
        <div class="flex flex-wrap gap-2">

          <button
            class="btn btn-sm border {myStatus === 'available'
              ? 'variant-filled-success'
              : 'variant-ghost-success border-success-400'}"
            onclick={() => selectStatus('available')}
            disabled={saving}
            title="Ich bin dabei"
          >✅ Dabei</button>

          <button
            class="btn btn-sm border {myStatus === 'maybe'
              ? 'variant-filled-warning'
              : 'variant-ghost-warning border-warning-400'}"
            onclick={() => selectStatus('maybe')}
            disabled={saving}
            title="Ich bin vielleicht dabei"
          >❓ Vielleicht</button>

          <button
            class="btn btn-sm border {myStatus === 'unavailable'
              ? 'variant-filled-error'
              : 'variant-ghost-error border-error-400'}"
            onclick={() => selectStatus('unavailable')}
            disabled={saving}
            title="Ich bin nicht dabei"
          >❌ Nicht dabei</button>

          {#if myStatus}
            <button
              class="btn btn-sm variant-ghost text-on-surface-variant"
              onclick={clearEntry}
              disabled={saving}
              title="Rückmeldung zurückziehen"
            >✕</button>
          {/if}

        </div>
      {/if}
    </div>

    <!-- ── Aushilfe (nur wenn "Nicht dabei") ─────────────────────── -->
    {#if showSubstituteForm && !readonly}
      <div class="mb-3 p-2.5 rounded-lg bg-surface-100 dark:bg-surface-800 border border-outline-variant">
        <p class="text-xs font-semibold mb-2">🔄 Aushilfe eintragen</p>

        {#if substituteOptions.length > 0}
          <label class="text-xs text-on-surface-variant block mb-1">Bandmitglied als Aushilfe:</label>
          <select
            class="input input-sm w-full mb-2 text-xs"
            bind:value={substituteUserId}
            onchange={onSubstituteUserChange}
          >
            <option value={null}>– Externe Aushilfe –</option>
            {#each substituteOptions as m}
              <option value={m.id}>{m.clear_name || m.user_name}</option>
            {/each}
          </select>
        {/if}

        {#if !substituteUserId}
          <label class="text-xs text-on-surface-variant block mb-1">Name der externen Aushilfe:</label>
          <input
            class="input input-sm w-full text-xs"
            type="text"
            placeholder="z.B. Max Mustermann"
            bind:value={substituteName}
            onblur={save}
          />
        {/if}
      </div>
    {/if}

    <!-- ── Kommentar ──────────────────────────────────────────────── -->
    {#if myStatus && !readonly}
      <div class="mb-3">
        <input
          class="input input-sm w-full text-xs"
          type="text"
          placeholder="Kommentar (optional)"
          bind:value={myComment}
          onblur={save}
        />
      </div>
    {/if}

    <!-- Speichern-Spinner -->
    {#if saving && !readonly}
      <p class="text-xs text-on-surface-variant mb-2">Wird gespeichert …</p>
    {/if}

    {#if error}
      <p class="text-xs text-error-500 mb-2">{error}</p>
    {/if}

    <!-- ── Übersicht ───────────────────────────────────────────────── -->
    {#if data}
      <div class="mt-2 border-t border-outline-variant pt-2.5 space-y-2">

        <!-- Zähler-Zeile -->
        <div class="flex flex-wrap gap-3 text-xs font-medium">
          <span class="text-success-600 dark:text-success-400">
            ✅ {data.summary?.available ?? 0} Dabei
          </span>
          <span class="text-warning-600 dark:text-warning-400">
            ❓ {data.summary?.maybe ?? 0} Vielleicht
          </span>
          <span class="text-error-600 dark:text-error-400">
            ❌ {data.summary?.unavailable ?? 0} Nicht dabei
          </span>
          {#if notResponded.length > 0}
            <span class="text-on-surface-variant">
              ⏳ {notResponded.length} ohne Rückmeldung
            </span>
          {/if}
        </div>

        <!-- Dabei -->
        {#if available.length > 0}
          <div>
            <p class="text-xs font-semibold text-success-600 dark:text-success-400 mb-1">Dabei:</p>
            <div class="flex flex-wrap gap-1">
              {#each available as a}
                <span class="badge variant-soft-success text-xs" title={a.comment || ''}>
                  {displayName(a)}
                </span>
              {/each}
            </div>
          </div>
        {/if}

        <!-- Vielleicht -->
        {#if maybe.length > 0}
          <div>
            <p class="text-xs font-semibold text-warning-600 dark:text-warning-400 mb-1">Vielleicht:</p>
            <div class="flex flex-wrap gap-1">
              {#each maybe as a}
                <span class="badge variant-soft-warning text-xs" title={a.comment || ''}>
                  {displayName(a)}
                </span>
              {/each}
            </div>
          </div>
        {/if}

        <!-- Nicht dabei -->
        {#if unavailable.length > 0}
          <div>
            <p class="text-xs font-semibold text-error-600 dark:text-error-400 mb-1">Nicht dabei:</p>
            <div class="space-y-1">
              {#each unavailable as a}
                <div class="flex flex-wrap items-center gap-1.5 text-xs">
                  <span class="badge variant-soft-error">{displayName(a)}</span>
                  {#if a.substitute_clear_name || a.substitute_name}
                    <span class="text-on-surface-variant">
                      → Aushilfe: <strong>{a.substitute_clear_name || a.substitute_name}</strong>
                    </span>
                  {/if}
                  {#if a.comment}
                    <span class="text-on-surface-variant italic">„{a.comment}"</span>
                  {/if}
                </div>
              {/each}
            </div>
          </div>
        {/if}

        <!-- Keine Rückmeldung -->
        {#if notResponded.length > 0}
          <div>
            <p class="text-xs font-semibold text-on-surface-variant mb-1">Keine Rückmeldung:</p>
            <div class="flex flex-wrap gap-1">
              {#each notResponded as m}
                <span class="badge variant-ghost text-xs">
                  {m.clear_name || m.user_name}
                </span>
              {/each}
            </div>
          </div>
        {/if}

      </div>
    {/if}

  {/if}
</div>

