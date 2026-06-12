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

  function formatTime(dateLike) {
    return new Date(dateLike).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  }

  function formatRehearsalRangeLabel() {
    const beginDate = new Date(reh.begin);
    const endDate = reh.end ? new Date(reh.end) : null;
    const dateLabel = beginDate.toLocaleDateString('de-DE', dateOptions);
    const beginTime = formatTime(beginDate);

    if (!endDate) return `${dateLabel}, ${beginTime} Uhr`;

    const endTime = formatTime(endDate);
    const sameDay = beginDate.toDateString() === endDate.toDateString();
    if (sameDay) return `${dateLabel}, ${beginTime}-${endTime} Uhr`;

    const endDateLabel = endDate.toLocaleDateString('de-DE', dateOptions);
    return `${dateLabel}, ${beginTime} Uhr - ${endDateLabel}, ${endTime} Uhr`;
  }

  function formatDeleteRangeLabel() {
    const beginDate = new Date(reh.begin);
    const dateLabel = beginDate.toLocaleDateString('de-DE', {
      day: '2-digit', month: '2-digit', year: 'numeric'
    });
    const beginTime = formatTime(beginDate);
    const endTime = reh.end ? formatTime(reh.end) : null;
    return endTime ? `${dateLabel} (${beginTime}-${endTime} Uhr)` : `${dateLabel} (${beginTime} Uhr)`;
  }

  function splitHighlightParts(text, query) {
    const value = text == null ? '' : String(text);
    const normalizedQuery = query?.trim();

    if (!normalizedQuery) return [{ text: value, match: false }];

    const escapedQuery = normalizedQuery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(escapedQuery, 'gi');
    const parts = [];
    let lastIndex = 0;

    for (const match of value.matchAll(regex)) {
      const index = match.index ?? 0;
      if (index > lastIndex) {
        parts.push({ text: value.slice(lastIndex, index), match: false });
      }

      parts.push({ text: match[0], match: true });
      lastIndex = index + match[0].length;
    }

    if (lastIndex < value.length) {
      parts.push({ text: value.slice(lastIndex), match: false });
    }

    return parts.length > 0 ? parts : [{ text: value, match: false }];
  }

  function handleToggle() {
    ontoggle?.({ id: reh.id });
  }

  function handleDelete() {
    ondelete?.({ id: reh.id, date: formatDeleteRangeLabel() });
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
  {#snippet highlightedText(text)}
    {#each splitHighlightParts(text, searchQuery) as part, idx (`${idx}-${part.text}`)}
      {#if part.match}
        <mark class="bg-warning-200 dark:bg-warning-700 rounded px-0.5">{part.text}</mark>
      {:else}
        {part.text}
      {/if}
    {/each}
  {/snippet}

  <button
    type="button"
    class="w-full cursor-pointer p-4 hover:bg-surface-100 dark:hover:bg-surface-700 rounded-t-lg text-left flex items-center gap-2"
    onclick={handleToggle}
  >
    <span class="text-sm">{expanded ? '▼' : '▶'}</span>
    <span class="text-lg font-bold">
      {formatRehearsalRangeLabel()}
    </span>
    {#if isPast}
      <span class="ml-2 text-xs text-surface-400 italic">Protokoll</span>
    {/if}
  </button>

  {#if expanded}
  <div class="px-4 pb-4">

    {#if isPast}
      <!-- ── Protokoll-Ansicht (vergangene Probe) ── -->
      <div class="prose prose-sm dark:prose-invert max-w-none text-sm text-on-surface leading-relaxed">

        {#if reh.comment}
          <p class="whitespace-pre-wrap mb-4 text-surface-700 dark:text-surface-200">{@render highlightedText(reh.comment)}</p>
          <hr class="border-surface-300 dark:border-surface-600 mb-4" />
        {/if}

        {#if reh.songs.length === 0}
          <p class="italic text-surface-500 dark:text-surface-300">Keine Songs protokolliert.</p>
        {:else}
          {#each reh.songs as song (song.id ?? song.id_song)}
            <div class="mb-4 rounded-md border border-surface-200 dark:border-surface-700 px-3 py-2">
              <p class="font-semibold">
                {song.done ? '✔' : '·'}
                {@render highlightedText(`${song.interpret} – ${song.title}`)}
                {#if song.status}
                  <span class="font-normal text-surface-500 dark:text-surface-300 text-xs">({song.status})</span>
                {/if}
              </p>
              {#if song.todo}
                <p class="ml-4 mt-1 text-surface-700 dark:text-surface-200">Todo: {@render highlightedText(song.todo)}</p>
              {/if}
              {#if song.comment}
                <p class="ml-4 mt-1 text-surface-700 dark:text-surface-200">{@render highlightedText(song.comment)}</p>
              {/if}
              {#each song.song_todos ?? [] as std}
                <p class="ml-4 mt-1 text-surface-600 dark:text-surface-300">
                  {std.done ? '✔' : '⏳'} {users.find(u => u.id === std.id_user)?.clear_name ?? '?'}: {@render highlightedText(std.todo)}
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
            rehearsalId={reh.id}
            rehearsalBegin={reh.begin}
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
