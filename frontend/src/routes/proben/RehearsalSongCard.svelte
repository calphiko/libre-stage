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
  import SongDetailsModal from '$lib/components/SongDetailsModal.svelte';
  import LastRehearsalProtocolModal from '$lib/components/LastRehearsalProtocolModal.svelte';

  let {
    song,
    users = [],
    rehearsalId = null,
    rehearsalBegin = null,
    canEdit = false,
    expanded = false,
    statusOptions = [],
    ontoggle,
    onremove,
    ondone,
    onstatuschange,
    onupdate,
    onaddtodo
  } = $props();

  let newTodoUserId = $state('');
  let newTodoText = $state('');

  function getStatusButtonClass(currentStatus, buttonStatus) {
    if (currentStatus === buttonStatus) {
      if (buttonStatus === 'retired') return 'btn-status-retired';
      return 'btn-status-success';
    }
    if (buttonStatus === 'retired') return 'btn-status-outline-retired';
    return 'btn-status-outline';
  }

  function handleToggle() {
    ontoggle?.({ id: song.id });
  }

  function handleRemove() {
    if (!canEdit) return;
    onremove?.({ id: song.id });
  }

  function handleDone() {
    if (!canEdit) return;
    ondone?.({ song });
  }

  function handleStatusChange(status) {
    if (!canEdit) return;
    onstatuschange?.({ status, song });
  }

  function handleBlur() {
    if (!canEdit) return;
    onupdate?.();
  }

  function handleAddTodo() {
    if (!canEdit) return;
    if (newTodoUserId && newTodoText) {
      onaddtodo?.({
        song,
        userId: Number(newTodoUserId),
        todoText: newTodoText
      });
      newTodoUserId = '';
      newTodoText = '';
    }
  }

  function openModal(id) {
    modalState.trigger({
      component: SongDetailsModal,
      meta: {
        songId: id
      }
    });
  }

  function openLastProtocolModal() {
    modalState.trigger({
      component: LastRehearsalProtocolModal,
      meta: {
        songId: song.id_song,
        songTitle: song.title,
        songInterpret: song.interpret,
        currentRehearsalId: rehearsalId,
        currentRehearsalBegin: rehearsalBegin,
        users
      }
    });
  }
</script>

<div class="border border-outline-variant rounded-lg mb-2 bg-surface-1">
  <button
    type="button"
    class="w-full cursor-pointer p-3 hover:bg-surface-100 dark:hover:bg-surface-700 rounded-t-lg text-left flex items-center gap-2"
    onclick={handleToggle}
  >
    <span class="text-xs">{expanded ? '▼' : '▶'}</span>
    {#if song.done}
      <span style="color: lightgreen;">✔</span>
    {:else}
      <span>♪</span>
    {/if}
    <span class="font-bold text-base">{song.interpret} - {song.title}</span>
  </button>

  {#if expanded}
  <div class="px-3 pb-3">
    <div class="flex gap-2 mb-4">
      <button
        class="btn variant-filled-error border btn-sm"
        title="Song entfernen"
        onclick={handleRemove}
        disabled={!canEdit}
      >✖</button>
      <button
        class="btn variant-filled-secondary btn-sm"
        onclick={openLastProtocolModal}
      >Letzte Probe</button>
      <button
        class="btn variant-filled-primary btn-sm"
        onclick={() => openModal(song.id_song)}
      >Details</button>
      <button
        class="btn variant-filled-success btn-sm"
        onclick={handleDone}
        disabled={!canEdit}
      >erledigt</button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
      <div>
        <label class="form-label">Status</label>
        <div class="flex gap-1 flex-wrap mt-1">
          {#each statusOptions as status}
            <button
              class="btn btn-sm {getStatusButtonClass(song.status, status)}"
              onclick={() => handleStatusChange(status)}
              disabled={!canEdit}
            >{status}</button>
          {/each}
        </div>
      </div>
      <div>
        <label class="form-label">Todo</label>
        <input
          class="input w-full" type="text"
          bind:value={song.todo}
          onblur={handleBlur}
          disabled={!canEdit}

        />
      </div>
      <div>
        <label class="form-label">Setlist Kommentar</label>
        <input
          class="input w-full" type="text"
          bind:value={song.setlist_comment}
          onblur={handleBlur}
          disabled={!canEdit}

        />
      </div>
      <div>
        <label class="form-label">Proben Kommentar</label>
        <textarea
          class="input w-full" rows="2"
          bind:value={song.comment}
          onblur={handleBlur}
          disabled={!canEdit}
        ></textarea>
      </div>
    </div>

    <div>
      <label class="form-label">Todos fürs nächste Mal</label>
      <div class="flex flex-col gap-2 mb-2">
        {#each song.song_todos as std}
          <span>
            {users.find(u => u.id === std.id_user)?.clear_name ?? 'Unbekannt'}: {std.todo}
            <span class="{std.done ? 'done-icon' : 'open-icon'}">
              {std.done ? '✔' : '⏳'}
            </span>
          </span>
        {/each}
      </div>
      <form class="flex gap-2 mt-2 flex-wrap" onsubmit={(e) => { e.preventDefault(); if (canEdit) handleAddTodo(); }}>
        <select
          bind:value={newTodoUserId}
          class="input w-full max-w-xs select" required
          disabled={!canEdit}

        >
          <option value="" disabled selected>Wer?</option>
          {#each users as u}
            <option value={u.id}>{u.clear_name}</option>
          {/each}
        </select>
        <input
          type="text"
          bind:value={newTodoText}
          class="input w-full max-w-xs"
          placeholder="Was soll getan werden?" required
          disabled={!canEdit}

          onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleAddTodo(); } }}
        />
        <button type="submit" class="btn variant-filled-primary btn-outline btn-sm" disabled={!canEdit}>
          Todo hinzufügen
        </button>
      </form>
    </div>
  </div>
  {/if}
</div>

<style>
  :global(.btn-status-success) {
    background-color: #4ade80;
    color: #fff;
    border: none;
  }
  :global(.btn-status-retired) {
    background-color: #ef4444;
    color: #fff;
    border: none;
  }
  :global(.btn-status-outline-retired) {
    background: transparent !important;
    color: #ef4444 !important;
    border-style: solid !important;
    border-width: 1px !important;
    border-color: #ef4444 !important;
  }
  :global(.btn-status-outline) {
    background: transparent !important;
    color: rgb(var(--color-on-surface)) !important;
    border-style: solid !important;
    border-width: 1px !important;
    border-color: rgb(var(--color-outline-variant)) !important;
  }
  .done-icon {
    color: lightgreen;
  }
  .open-icon {
    color: orange;
  }


</style>
