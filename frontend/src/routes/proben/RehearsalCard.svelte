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
  import { Accordion, AccordionItem, Autocomplete } from '@skeletonlabs/skeleton';
  import { createEventDispatcher, tick } from 'svelte';
  import RehearsalSongCard from './RehearsalSongCard.svelte';
  import { appConfig } from '$lib/appConfig.js';

  const dispatch = createEventDispatcher();

  export let reh;
  export let songs = [];
  export let songsForSearch = [];
  export let users = [];
  export let isEditor = false;
  export let expanded = false;
  export let expandedSongId = null;

  $: statusOptions = $appConfig?.rehearsalSongStatuses ?? [];

  const dateOptions = {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  };

  let searchTerm = '';
  let selectedSong = null;
  let newSongTodo = '';
  let songToAddInput;

  function onSelect(event) {
    searchTerm = songsForSearch.find(s => s.value === event.detail.value)?.label ?? '';
    selectedSong = songs.find(s => s.id === event.detail.value);
  }

  function handleToggle() {
    dispatch('toggle', { id: reh.id });
  }

  function handleDelete() {
    const dateStr = new Date(reh.begin).toLocaleDateString('de-DE', {
      day: '2-digit', month: '2-digit', year: 'numeric'
    });
    dispatch('delete', { id: reh.id, date: dateStr });
  }

  function handleUpdate(songId = null) {
    dispatch('update', { reh, songId });
  }

  function handleSongToggle(e) {
    dispatch('songtoggle', { id: e.detail.id });
  }

  function handleSongRemove(e) {
    reh.songs = reh.songs.filter(s => s.id !== e.detail.id);
    handleUpdate(null);
  }

  function handleSongDone(e) {
    e.detail.song.done = !e.detail.song.done;
    handleUpdate(e.detail.song.id);
  }

  function handleStatusChange(e) {
    e.detail.song.status = e.detail.status;
    handleUpdate(e.detail.song.id);
  }

  function handleSongUpdate() {
    handleUpdate(expandedSongId);
  }

  function handleAddTodo(e) {
    const { song, userId, todoText } = e.detail;
    const newTodo = {
      id: null,
      id_reh: song.id_rehearsal,
      id_song: song.id_song,
      id_user: userId,
      todo: todoText,
      done: false,
      dt: reh.begin
    };
    song.song_todos = [...song.song_todos, newTodo];
    handleUpdate(expandedSongId);
  }

  async function addSongTodo() {
    if (!selectedSong) {
      dispatch('error', { message: 'Bitte wähle einen gültigen Song aus.' });
      searchTerm = '';
      await tick();
      songToAddInput?.focus();
      return;
    }

    const alreadyPresent = reh.songs.some(s => s.id_song === selectedSong.id);
    if (alreadyPresent) {
      dispatch('warning', { message: `Der Song "${selectedSong.title}" ist bereits in dieser Probe enthalten.` });
      selectedSong = null;
      newSongTodo = '';
      searchTerm = '';
      await tick();
      songToAddInput?.focus();
      return;
    }

    const newSong = {
      id: null,
      id_rehearsal: reh.id,
      id_song: selectedSong.id,
      interpret: selectedSong.interpret,
      title: selectedSong.title,
      status: selectedSong.status,
      setlist_comment: selectedSong.comment,
      comment: '',
      todo: newSongTodo,
      song_todos: [],
      done: false,
    };
    reh.songs = [...reh.songs, newSong];
    handleUpdate(null);
    dispatch('success', { message: `Der Song "${selectedSong.title}" wurde zur Probe hinzugefügt.` });

    selectedSong = null;
    newSongTodo = '';
    searchTerm = '';
    await tick();
    songToAddInput?.focus();
  }
</script>

<AccordionItem
  open={expanded}
  on:toggle={handleToggle}
  class="border border-outline-variant rounded-lg mb-2 bg-surface-1"
>
  <svelte:fragment slot="summary">
    <span class="text-lg font-bold">
      {new Date(reh.begin).toLocaleString(undefined, dateOptions)}
    </span>
  </svelte:fragment>

  <svelte:fragment slot="content">
    <div class="px-4">
      {#if isEditor}
        <button
          class="btn variant-filled-error btn-sm text-sm float-left mb-3 border"
          title="Probe löschen"
          on:click|stopPropagation={handleDelete}
        >🗑️ Probe löschen</button>
      {/if}

      <div class="mb-5 clear-both">
        <textarea
          class="input w-full rounded-md" rows="7"
          bind:value={reh.comment}
          on:blur|stopPropagation={() => handleUpdate(expandedSongId)}
          placeholder="Probenkommentar"
        />
      </div>

      <form class="mb-6 border-t pt-3" on:submit|preventDefault={addSongTodo}>
        <h6 class="font-bold text-base mb-2">Song mit Todo</h6>
        <div class="flex flex-col gap-2">
          {#if songsForSearch.length > 0}
            <div class="relative overflow-auto">
              <input
                class="input w-full mb-1" type="search"
                id="songToAdd-{reh.id}"
                bind:this={songToAddInput}
                bind:value={searchTerm}
                placeholder="Song eingeben" autocomplete="off"
                on:focus|stopPropagation on:click|stopPropagation
              />
              {#if searchTerm?.trim()}
                <div class="card w-full max-w-md max-h-48 p-4 overflow-y-auto" tabindex="-1">
                  <Autocomplete
                    options={songsForSearch}
                    bind:input={searchTerm}
                    on:selection={onSelect}
                    class="w-full"
                  />
                </div>
              {/if}
            </div>
          {/if}
        </div>
        <div class="my-2">
          <input
            class="input w-full" type="text"
            bind:value={newSongTodo} required
            placeholder="Was gibts zu tun?"
            on:focus|stopPropagation on:click|stopPropagation
          />
        </div>
        <button class="btn variant-filled-primary btn-sm border mt-2 w-fit" type="submit">
          Hinzufügen
        </button>
      </form>

      <Accordion class="border-t pt-3">
        {#each reh.songs as song (song.id ?? song.id_song)}
          <RehearsalSongCard
            {song}
            {users}
            {statusOptions}
            expanded={expandedSongId === song.id}
            on:toggle={handleSongToggle}
            on:remove={handleSongRemove}
            on:done={handleSongDone}
            on:statuschange={handleStatusChange}
            on:update={handleSongUpdate}
            on:addtodo={handleAddTodo}
          />
        {/each}
      </Accordion>
    </div>
  </svelte:fragment>
</AccordionItem>

