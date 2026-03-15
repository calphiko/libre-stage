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
  import { tick } from 'svelte';
  import RehearsalSongCard from './RehearsalSongCard.svelte';
  import { appConfig } from '$lib/appConfig.js';

  let { reh, songs = [], songsForSearch = [], users = [], isEditor = false, isPast = false, searchQuery = '', expanded = false, expandedSongId = null, ontoggle, onupdate, ondelete, onsongtoggle, onerror, onwarning, onsuccess } = $props();

  let statusOptions = $derived($appConfig?.rehearsalSongStatuses ?? []);

  const dateOptions = {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  };

  let searchTerm = $state('');
  let selectedSong = $state(null);
  let newSongTodo = $state('');
  let songToAddInput;

  function highlight(text, query) {
    if (!query?.trim() || !text) return text ?? '';
    const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return String(text).replace(
      new RegExp(`(${escaped})`, 'gi'),
      '<mark class="bg-warning-200 dark:bg-warning-700 rounded px-0.5">$1</mark>'
    );
  }


  function handleToggle() {
    ontoggle?.({ id: reh.id });
  }

  function handleDelete() {
    const dateStr = new Date(reh.begin).toLocaleDateString('de-DE', {
      day: '2-digit', month: '2-digit', year: 'numeric'
    });
    ondelete?.({ id: reh.id, date: dateStr });
  }

  function handleUpdate(songId = null) {
    onupdate?.({ reh, songId });
  }

  function handleSongToggle(e) {
    onsongtoggle?.({ id: e.id });
  }

  function handleSongRemove(e) {
    reh.songs = reh.songs.filter(s => s.id !== e.id);
    handleUpdate(null);
  }

  function handleSongDone(e) {
    e.song.done = !e.song.done;
    handleUpdate(e.song.id);
  }

  function handleStatusChange(e) {
    e.song.status = e.status;
    handleUpdate(e.song.id);
  }

  function handleSongUpdate() {
    handleUpdate(expandedSongId);
  }

  function handleAddTodo(e) {
    const { song, userId, todoText } = e;
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
      onerror?.({ message: 'Bitte wähle einen gültigen Song aus.' });
      searchTerm = '';
      await tick();
      songToAddInput?.focus();
      return;
    }

    const alreadyPresent = reh.songs.some(s => s.id_song === selectedSong.id);
    if (alreadyPresent) {
      onwarning?.({ message: `Der Song "${selectedSong.title}" ist bereits in dieser Probe enthalten.` });
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
    onsuccess?.({ message: `Der Song "${selectedSong.title}" wurde zur Probe hinzugefügt.` });

    selectedSong = null;
    newSongTodo = '';
    searchTerm = '';
    await tick();
    songToAddInput?.focus();
  }
</script>

<div class="border border-outline-variant rounded-lg mb-2 bg-surface-1">
  <button
    type="button"
    class="w-full cursor-pointer p-4 hover:bg-surface-100 dark:hover:bg-surface-700 rounded-t-lg text-left flex items-center gap-2"
    onclick={handleToggle}
  >
    <span class="text-sm">{expanded ? '▼' : '▶'}</span>
    <span class="text-lg font-bold">
      {new Date(reh.begin).toLocaleString(undefined, dateOptions)}
    </span>
    {#if isPast}
      <span class="ml-2 text-xs text-surface-400 italic">Protokoll</span>
    {/if}
  </button>

  {#if expanded}
  <div class="px-4 pb-4">

    {#if isPast}
      <!-- ── Protokoll-Ansicht (vergangene Probe) ── -->
      <div class="prose prose-sm dark:prose-invert max-w-none text-sm text-on-surface">

        {#if reh.comment}
          <p class="whitespace-pre-wrap mb-4 text-surface-600 dark:text-surface-300">{@html highlight(reh.comment, searchQuery)}</p>
          <hr class="border-surface-200 dark:border-surface-700 mb-4" />
        {/if}

        {#if reh.songs.length === 0}
          <p class="italic text-surface-400">Keine Songs protokolliert.</p>
        {:else}
          {#each reh.songs as song (song.id ?? song.id_song)}
            <div class="mb-3">
              <p class="font-semibold">
                {song.done ? '✔' : '·'}
                {@html highlight(`${song.interpret} – ${song.title}`, searchQuery)}
                {#if song.status}
                  <span class="font-normal text-surface-400 text-xs">({song.status})</span>
                {/if}
              </p>
              {#if song.todo}
                <p class="ml-4 text-surface-500">Todo: {@html highlight(song.todo, searchQuery)}</p>
              {/if}
              {#if song.comment}
                <p class="ml-4 text-surface-500">{@html highlight(song.comment, searchQuery)}</p>
              {/if}
              {#each song.song_todos ?? [] as std}
                <p class="ml-4 text-surface-400">
                  {std.done ? '✔' : '⏳'} {users.find(u => u.id === std.id_user)?.clear_name ?? '?'}: {@html highlight(std.todo, searchQuery)}
                </p>
              {/each}
            </div>
          {/each}
        {/if}
      </div>

    {:else}
      <!-- ── Edit-Ansicht (bevorstehende Probe) ── -->
      {#if isEditor}
        <button
          class="btn variant-filled-error btn-sm text-sm float-left mb-3 border"
          title="Probe löschen"
          onclick={handleDelete}
        >🗑️ Probe löschen</button>
      {/if}

      <div class="mb-5 clear-both">
        <textarea
          class="input w-full rounded-md" rows="7"
          bind:value={reh.comment}
          onblur={() => handleUpdate(expandedSongId)}
          placeholder="Probenkommentar"
        ></textarea>
      </div>

      <form class="mb-6 border-t pt-3" onsubmit={(e) => { e.preventDefault(); addSongTodo(); }}>
        <h6 class="font-bold text-base mb-2">Song mit Todo</h6>
        <div class="flex flex-col gap-2">
          {#if songsForSearch.length > 0}
            <input
              class="input w-full mb-1"
              type="text"
              list="songs-datalist-{reh.id}"
              id="songToAdd-{reh.id}"
              bind:this={songToAddInput}
              bind:value={searchTerm}
              placeholder="Song eingeben"
              autocomplete="off"
              oninput={(e) => {
                const selected = songsForSearch.find(s => s.label === e.target.value);
                if (selected) {
                  selectedSong = songs.find(s => s.id === selected.value);
                }
              }}
            />
            <datalist id="songs-datalist-{reh.id}">
              {#each songsForSearch as songOption}
                <option value={songOption.label}></option>
              {/each}
            </datalist>
          {/if}
        </div>
        <div class="my-2">
          <input
            class="input w-full" type="text"
            bind:value={newSongTodo} required
            placeholder="Was gibts zu tun?"
          />
        </div>
        <button class="btn variant-filled-primary btn-sm border mt-2 w-fit" type="submit">
          Hinzufügen
        </button>
      </form>

      <div class="border-t pt-3">
        {#each reh.songs as song (song.id ?? song.id_song)}
          <RehearsalSongCard
            {song}
            {users}
            {statusOptions}
            expanded={expandedSongId === song.id}
            ontoggle={handleSongToggle}
            onremove={handleSongRemove}
            ondone={handleSongDone}
            onstatuschange={handleStatusChange}
            onupdate={handleSongUpdate}
            onaddtodo={handleAddTodo}
          />
        {/each}
      </div>
    {/if}

  </div>
  {/if}
</div>

