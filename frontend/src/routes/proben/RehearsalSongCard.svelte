// libre-stage - Band rehearsal and gig management software
// Copyright (C) 2026  libre-stage contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

<script>
  import { AccordionItem } from '@skeletonlabs/skeleton';
  import { createEventDispatcher } from 'svelte';

  import { getModalStore  } from '@skeletonlabs/skeleton';
  import SongDetailsModal from '$lib/components/SongDetailsModal.svelte';


  const dispatch = createEventDispatcher();

  export let song;
  export let users = [];
  export let expanded = false;
  export let statusOptions = [];

  let newTodoUserId = '';
  let newTodoText = '';

  const modalStore = getModalStore();

  function getStatusButtonClass(currentStatus, buttonStatus) {
    if (currentStatus === buttonStatus) {
      if (buttonStatus === 'retired') return 'btn-status-retired';
      return 'btn-status-success';
    }
    if (buttonStatus === 'retired') return 'btn-status-outline-retired';
    return '';
  }

  function handleToggle() {
    dispatch('toggle', { id: song.id });
    console.log(song)
  }

  function handleRemove() {
    dispatch('remove', { id: song.id });
  }

  function handleDone() {
    dispatch('done', { song });
  }

  function handleStatusChange(status) {
    dispatch('statuschange', { status, song });
  }

  function handleBlur() {
    dispatch('update');
  }

  function handleAddTodo() {
    if (newTodoUserId && newTodoText) {
      dispatch('addtodo', {
        song,
        userId: Number(newTodoUserId),
        todoText: newTodoText
      });
      newTodoUserId = '';
      newTodoText = '';
    }
  }

  function openModal(id) {
    modalStore.trigger({
    type: 'component',
    component: { ref: SongDetailsModal },
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

<AccordionItem
  open={expanded}
  on:toggle={handleToggle}
  class="border border-outline-variant rounded-lg mb-2 bg-surface-1"
>
  <svelte:fragment slot="lead">
    {#if song.done}
      <span style="color: lightgreen;">✔</span>
    {:else}
      <span>♪</span>
    {/if}
  </svelte:fragment>

  <svelte:fragment slot="summary">
    <span class="font-bold text-base">{song.interpret} - {song.title}</span>
  </svelte:fragment>

  <svelte:fragment slot="content">
    <div class="flex justify-between items-center mb-2 gap-2">
      <button
        class="btn variant-filled-error border btn-sm"
        title="Song entfernen"
        on:click|stopPropagation={handleRemove}
      >✖</button>
      <button
        class="btn variant-filled-primary btn-sm"
        on:click|stopPropagation={() => openModal(song.id_song)}
      >Details</button>
      <button
        class="btn variant-filled-success btn-sm"
        on:click|stopPropagation={handleDone}
      >erledigt</button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-4">
      <div>
        <label class="form-label">Status</label>
        <div class="flex gap-1 flex-wrap mt-1">
          {#each statusOptions as status}
            <button
              class="btn btn-sm {getStatusButtonClass(song.status, status)}"
              on:click|stopPropagation={() => handleStatusChange(status)}
            >{status}</button>
          {/each}
        </div>
      </div>
      <div>
        <label class="form-label">Todo</label>
        <input
          class="input w-full" type="text"
          bind:value={song.todo}
          on:blur|stopPropagation={handleBlur}
          on:focus|stopPropagation on:click|stopPropagation
        />
      </div>
      <div>
        <label class="form-label">Setlist Kommentar</label>
        <input
          class="input w-full" type="text"
          bind:value={song.setlist_comment}
          on:blur|stopPropagation={handleBlur}
          on:focus|stopPropagation on:click|stopPropagation
        />
      </div>
      <div>
        <label class="form-label">Proben Kommentar</label>
        <textarea
          class="input w-full" rows="2"
          bind:value={song.comment}
          on:blur|stopPropagation={handleBlur}
          on:focus|stopPropagation on:click|stopPropagation
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
      <form class="flex gap-2 mt-2 flex-wrap" on:submit|preventDefault={handleAddTodo}>
        <select
          bind:value={newTodoUserId}
          class="input w-full max-w-xs" required
          on:focus|stopPropagation on:click|stopPropagation
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
          on:focus|stopPropagation on:click|stopPropagation
          on:keydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleAddTodo(); } }}
        />
        <button type="submit" class="btn variant-filled-primary btn-outline btn-sm">
          Todo hinzufügen
        </button>
      </form>
    </div>
  </svelte:fragment>
</AccordionItem>

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

