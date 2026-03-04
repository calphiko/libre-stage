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
  import { browser } from '$app/environment';
  import { onMount, onDestroy } from 'svelte';
  import { dndzone, overrideItemIdKeyNameBeforeInitialisingDndZones } from 'svelte-dnd-action';
  import {getFirstSinger, getColorBySinger } from '$lib/common.js';
  import { updateGigSetlist, getSong, logout as apiLogout} from '$lib/api.js';

  overrideItemIdKeyNameBeforeInitialisingDndZones('setsong_id');

  let { setlist } = $props();
  let setIndex = $state(1);

  let isUpdating = $state(false);
  let updateError = $state(null);

  let dragOverSetIdx = $state(null);
  let dragOverSongId = $state(null);
  let dragInsertPos = $state(null); // Neue Position zum Einfügen

  
  let nextNegativeSetsongId = $state(-1);

  function cleanDnDItems(items) {
    // Entferne nur Shadow-Elemente
    return items.filter(item => !item._dndShadowItem);
  }

  function handleSongsConsider(setIdx, { detail }) {
    setlist.sets[setIdx].songs = cleanDnDItems(detail.items);
    setlist = { ...setlist }; // Triggert Reaktivität
  }

  async function handleSongsFinalize(setIdx, { detail }) {
    setlist.sets[setIdx].songs = cleanDnDItems(detail.items);
    setlist = { ...setlist };

    await updateSetlist(setlist);
  }

  async function handleDragOverSet(setIdx, e) {
    e.preventDefault();
    dragOverSetIdx = setIdx;
    dragOverSongId = e.dataTransfer.getData('text/plain');
    dragInsertPos = setlist.sets[setIdx].songs.length; // Standard: Ende der Liste

    let songInfo = await getSong(null, e.dataTransfer.getData('text/plain'));
    songInfo.setsong_id = nextNegativeSetsongId;
    nextNegativeSetsongId -= 1;

    setlist.sets[setIdx].songs = [
      ...setlist.sets[setIdx].songs.slice(0, dragInsertPos),
      songInfo,
      ...setlist.sets[setIdx].songs.slice(dragInsertPos)
    ];
    setlist = { ...setlist };

    console.log("Setlistn ach Import:", setlist);
    setlist = await updateSetlist(setlist);
    console.log("Setlistn ach API Call:", setlist);

  }

  function handleDragOverSong(setIdx, songIdx, e) {
    e.preventDefault();
    dragOverSetIdx = setIdx;
    dragOverSongId = e.dataTransfer.getData('text/plain');
    dragInsertPos = songIdx; // Marker vor diesem Song
  }

  function handleDragLeave() {
    dragOverSetIdx = null;
    dragOverSongId = null;
    dragInsertPos = null;
  }

  function insertSetBefore(idx) {
    const newSet = {
      songs: [],
      pause: '00:10:00',

    };
    setlist.sets.splice(idx, 0, newSet);
    setlist = { ...setlist };
    updateSetlist(setlist);
  }

  function addSetAtEnd() {
    const newSet = {
      songs: [],
      pause: '00:10:00',
      setlist_name: '',
      set_name: ''
      // ggf. weitere Felder
    };
    setlist.sets.push(newSet);
    setlist = { ...setlist };
    updateSetlist(setlist);
  }
  function removeSet(setIdx) {
    setlist.sets.splice(setIdx, 1);
    setlist = { ...setlist };
    updateSetlist(setlist);
  }

  async function removeSongFromSet(setIdx, setsong_id) {
    // Save original state for rollback
    const originalSongs = [...setlist.sets[setIdx].songs];

    // Optimistic update
    setlist.sets[setIdx].songs = setlist.sets[setIdx].songs.filter(
      s => s.setsong_id !== setsong_id
    );
    setlist = { ...setlist };

    try {
      await updateSetlist(setlist);
      //showSuccess('Song erfolgreich entfernt');
    } catch (error) {
      // Rollback on error
      setlist.sets[setIdx].songs = originalSongs;
      setlist = { ...setlist };
      //showError(`Fehler beim Entfernen des Songs: ${error.message}`);
    }
  }

  async function updateSetlist(data) {
    isUpdating = true;
    updateError = null;
    try {
      const result = await updateGigSetlist(null, data.id, data);
      return result;
    } catch (error) {
      updateError = error.message;
      console.error('Failed to update setlist:', error);
      //showError(`Fehler beim Speichern: ${error.message}`);
    } finally {
      isUpdating = false;
    }
  }

  function handleKeyboardShortcuts(e) {
    // Strg/Cmd + Shift + N -> Neues Set am Ende hinzufügen
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'N') {
      e.preventDefault();
      addSetAtEnd();
    }
  }

  onMount(() => {
    if (browser) {
      window.addEventListener('keydown', handleKeyboardShortcuts);
    }
  });

  onDestroy(() => {
    if (browser) {
      window.removeEventListener('keydown', handleKeyboardShortcuts);
    }
  });
</script>


{#each setlist.sets as set, setIdx (set.gigset_id)}
  <div class="set-card">
    <div class="set-header ">
       <button class="btn btn-sm variant-filled-primary py-0" onclick={() => insertSetBefore(setIdx)}>
          + Set
       </button>
       <input
          type="text"
          class="setlist-name-input"
          bind:value={set.setlist_name}
          placeholder={`Set ${setIdx + 1}`}
          onblur={() => updateSetlist(setlist)}
       />
       <button class="btn btn-sm variant-filled-error py-0" onclick={() => removeSet(setIdx)}>
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4 10a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1z" clip-rule="evenodd"></path>
            </svg>
       </button>
    </div>
    <div
      use:dndzone={{
        items: set.songs,
        type: 'song-in-set',
        flipDurationMs: 150
      }}
      onconsider={e => handleSongsConsider(setIdx, e)}
      onfinalize={e => handleSongsFinalize(setIdx, e)}
      ondragover={(e) => e.preventDefault()}
      ondrop={(e) => handleDragOverSet(setIdx, e)}
    >
      {#each set.songs as song (song.setsong_id)}
        <div class="song-in-set text-surface-900 dark:text-surface-950" data-song-id={song.setsong_id}
        style="background: {getColorBySinger(getFirstSinger(song.singer_lead))};"
        >
          <span>
          {#if song.brass === 1}
            🎺
          {/if}
          {song.title}   <small>{song.comment}</small>     </span>
          <button class="btn btn-sm variant-filled-error py-0"
                  onclick={() => removeSongFromSet(setIdx, song.setsong_id)}>
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4 10a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1z" clip-rule="evenodd"></path>
            </svg>
          </button>
        </div>
      {/each}

      {#if !set.songs.length}
        <div class="empty-set-hint">Ziehe Songs hierher…</div>
      {/if}
    </div>

    {#if set.pause}
      <div style="margin:.2em 0 .7em;font-style:italic;color:#888">
        Pause: {set.pause}
      </div>
    {/if}
  </div>

{/each}

<div class="add-set-end-container">
  <button class="insert-btn" onclick={addSetAtEnd}>
    + Set
  </button>
</div>

<style>
.set-card   {  border:1.5px solid #76a7db; border-radius:2px;
              margin-bottom:0.5em; padding:0.5em 0.5em .25em; }

.song-in-set{ display:flex; justify-content:space-between; align-items:center;
              background:#e7f1fb; margin-bottom:4px; padding:.33em .6em;
              border-radius:6px; }
.empty-set-hint{ color:#7895a9; font-style:italic; text-align:center; opacity:.75; }
.pause{ margin:.2em 0 .7em; font-style:italic; color:#888; }

.set-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  //gap: 1em;
  background: linear-gradient(90deg, #e2ecfa 65%, #d8f0fe 100%);
  border-radius: 10px 10px 0 0;
  padding: .8em 1.1em .7em;
  box-shadow: 0 2px 8px rgba(90,150,220,0.08);
  border-bottom: 1.7px solid #93b6e7;
}

.set-header b {
  font-size: 1.11em;
  color: #2585da;
  letter-spacing: 0.5px;
  margin-right: .6em;
}

.setlist-name-input {
  flex: 1 1 180px;
  min-width: 120px;
  max-width: 250px;
  border: 1.2px solid #b2d4fa;
  background: #f4fbff;
  color: #2574b6;
  border-radius: 5px;
  font-size: 1em;
  padding: .28em .7em;
  margin-left: .1em;
  transition: border-color 0.18s;
}
.setlist-name-input:focus {
  border-color: #3c9ad8;
  outline: none;
}

.insert-btn {
  background: linear-gradient(88deg, #8ec8f8, #368adf);
  color: #fff;
  border: none;
  border-radius: 6px;
  padding: .37em 1.2em;
  font-weight: bold;
  font-size: 1em;
  box-shadow: 0 1.5px 7px rgba(90, 142, 185, 0.12);
  transition: background 0.25s, box-shadow 0.25s, transform 0.15s;
  cursor: pointer;
  outline: none;
  margin-right: .5em;
}

.insert-btn:hover, .insert-btn:focus {
  background: linear-gradient(90deg, #60b0ea, #276bb9);
  box-shadow: 0 4px 16px rgba(30, 80, 160, 0.12);
  transform: translateY(-2px) scale(1.03);
}

.add-set-end-container {
  display: flex;
  justify-content: flex;
  padding: 1.2em 0 .5em;
}
</style>

