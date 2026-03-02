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

  let { song, users = [], expanded = false, statusOptions = [], ontoggle, onremove, ondone, onstatuschange, onupdate, onaddtodo } = $props();

  let newTodoUserId = $state('');
  let newTodoText = $state('');

  function getStatusButtonClass(currentStatus, buttonStatus) {
    if (currentStatus === buttonStatus) {
      if (buttonStatus === 'retired') return 'btn-status-retired';
      return 'btn-status-success';
    }
    if (buttonStatus === 'retired') return 'btn-status-outline-retired';
    return '';
  }

  function handleToggle() {
    ontoggle?.({ id: song.id });
    console.log(song)
  }

  function handleRemove() {
    onremove?.({ id: song.id });
  }

  function handleDone() {
    ondone?.({ song });
  }

  function handleStatusChange(status) {
    onstatuschange?.({ status, song });
  }

  function handleBlur() {
    onupdate?.();
  }

  function handleAddTodo() {
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
    },
    response: async (result) => {
      if (result?.action === 'updated') {
        await refreshSongLists();
      } else if (result?.action === 'delete') {
        await refreshSongLists();
      }
    }
    });
  }
</script>

<details 
  open={expanded}
  ontoggle={handleToggle}
  class="border border-outline-variant rounded-lg mb-2 bg-surface-1"
>
  <div>
    {#if song.done}
      <span style="color: lightgreen;">✔</span>
    {:else}
      <span>♪</span>
    {/if}
  </div>

  <div class="font-semibold">
    <span class="font-bold text-base">{song.interpret} - {song.title}</span>
  </div>

  <div>
    <div class="flex justify-between items-center mb-2 gap-2">
      <button
        class="btn variant-filled-error border btn-sm"
        title="Song entfernen"
        onclick={handleRemove}
      >✖</button>
      <button
        class="btn variant-filled-primary btn-sm"
        onclick={() => openModal(song.id_song)}
      >Details</button>
      <button
        class="btn variant-filled-success btn-sm"
        onclick={handleDone}
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
          
        />
      </div>
      <div>
        <label class="form-label">Setlist Kommentar</label>
        <input
          class="input w-full" type="text"
          bind:value={song.setlist_comment}
          onblur={handleBlur}
          
        />
      </div>
      <div>
        <label class="form-label">Proben Kommentar</label>
        <textarea
          class="input w-full" rows="2"
          bind:value={song.comment}
          onblur={handleBlur}
          
        />
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
      <form class="flex gap-2 mt-2 flex-wrap" onsubmit={handleAddTodo}>
        <select
          bind:value={newTodoUserId}
          class="input w-full max-w-xs" required
          
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
          
          onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleAddTodo(); } }}
        />
        <button type="submit" class="btn variant-filled-primary btn-outline btn-sm">
          Todo hinzufügen
        </button>
      </form>
    </div>
  </div>
</details>

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
    background: #fff;
    color: #ef4444;
    border: 2px solid #ef4444;
  }
  .done-icon {
    color: lightgreen;
  }
  .open-icon {
    color: orange;
  }
</style>
