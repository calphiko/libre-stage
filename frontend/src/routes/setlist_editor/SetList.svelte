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
  import { dndzone } from 'svelte-dnd-action';
  import {getFirstSinger, getColorBySinger } from '$lib/common.js';
  import { updateGigSetlist, getSong, logout as apiLogout} from '$lib/api.js';


  let { setlist = $bindable() } = $props();
  let setIndex = $state(1);

  let isUpdating = $state(false);
  let updateError = $state(null);

  let dragOverSetIdx = $state(null);
  let dragOverSongId = $state(null);
  let dragInsertPos = $state(null); // Neue Position zum Einfügen

  
  let nextNegativeSetsongId = $state(-1);

  function formatPauseForInput(value) {
    if (!value) return '';
    const txt = String(value);
    return txt.length >= 5 ? txt.slice(0, 5) : txt;
  }

  function normalizePauseForApi(value) {
    const trimmed = (value ?? '').trim();
    if (!trimmed) return null;
    if (/^\d{2}:\d{2}$/.test(trimmed)) return `${trimmed}:00`;
    return trimmed;
  }

  function getSongDuplicateKey(song) {
    if (song?.id != null) return `id:${song.id}`;
    return `name:${song?.interpret ?? ''}::${song?.title ?? ''}`;
  }

  function getDuplicateSongKeys() {
    const counts = new Map();
    for (const set of setlist?.sets ?? []) {
      for (const song of set?.songs ?? []) {
        const key = getSongDuplicateKey(song);
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
    }
    return new Set(
      [...counts.entries()]
        .filter(([, count]) => count > 1)
        .map(([key]) => key)
    );
  }

  let duplicateSongKeys = $derived(getDuplicateSongKeys());

  function getSetPositionByIndex(setIdx) {
    return String(setIdx + 1);
  }

  function getSetStartTime(setIdx) {
    const setPos = getSetPositionByIndex(setIdx);
    const starts = setlist?.timing?.schedule?.[setPos] ?? [];
    return starts[0] ?? '';
  }

  function getSetEndTime(setIdx) {
    const setPos = getSetPositionByIndex(setIdx);
    return setlist?.timing?.set_end?.[setPos] ?? '';
  }

  function toHHMM(value) {
    if (!value) return '';
    const txt = String(value).trim();
    return txt.length >= 5 ? txt.slice(0, 5) : '';
  }

  function hhmmToMinutes(value) {
    if (!value || !/^\d{2}:\d{2}$/.test(value)) return null;
    const [hours, minutes] = value.split(':').map(Number);
    return (hours * 60) + minutes;
  }

  function getPlannedGigEndTime() {
    const setEnds = Object.entries(setlist?.timing?.set_end ?? {});
    if (!setEnds.length) return '';
    setEnds.sort((a, b) => Number(a[0]) - Number(b[0]));
    return toHHMM(setEnds[setEnds.length - 1][1]);
  }

  function getTargetGigEndTime() {
    return toHHMM(setlist?.end);
  }

  function getGigEndDiffMinutes() {
    const target = getTargetGigEndTime();
    const planned = getPlannedGigEndTime();
    const targetMinutes = hhmmToMinutes(target);
    const plannedMinutes = hhmmToMinutes(planned);
    if (targetMinutes == null || plannedMinutes == null) return null;
    return plannedMinutes - targetMinutes;
  }

  function getSongStartTime(setIdx, songIdx) {
    const setPos = getSetPositionByIndex(setIdx);
    const starts = setlist?.timing?.schedule?.[setPos] ?? [];
    return starts[songIdx] ?? '';
  }

  function getPauseBeforeSet(setIdx) {
    if (setIdx <= 0) return null;
    const setPos = getSetPositionByIndex(setIdx);
    return setlist?.timing?.pause_before?.[setPos] ?? null;
  }

  function cleanDnDItems(items) {
    // Entferne nur Shadow-Elemente
    return items.filter(item => !item._dndShadowItem);
  }

  function handleSongsConsider(setIdx, { detail }) {
    setlist.sets[setIdx].songs = cleanDnDItems(detail.items);
    setlist = { ...setlist }; // Triggert Reaktivität
  }

  async function handleSongsFinalize(setIdx, { detail }) {
    const processedSongs = cleanDnDItems(detail.items).map(song => {
      // Wenn der Song aus der SongList via svelte-dnd-action gezogen wurde, hat er eine ID beginnend mit "new-"
      if (typeof song.setsong_id === 'string' && song.setsong_id.startsWith('new-')) {
        const parts = song.setsong_id.split('-');
        const originalSongId = Number(parts[1]);
        return {
          ...song,
          id: originalSongId,
          // Neue temporäre negative setsong_id vergeben
          setsong_id: -Math.floor(Date.now() + Math.random() * 100000)
        };
      }
      return song;
    });

    setlist.sets[setIdx].songs = processedSongs;
    setlist = { ...setlist };

    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
  }

  function applyUpdatedSetlist(updated, fallback = null) {
    if (updated) {
      setlist = updated;
      return true;
    }
    if (fallback) {
      setlist = fallback;
    }
    return false;
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
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
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

  async function insertSetBefore(idx) {
    const newSet = {
      songs: [],
      pause: '00:10:00',
    };
    setlist.sets.splice(idx, 0, newSet);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
  }

  async function addSetAtEnd() {
    const newSet = {
      songs: [],
      pause: '00:10:00',
      setlist_name: '',
      set_name: ''
    };
    setlist.sets.push(newSet);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
  }

  async function removeSet(setIdx) {
    setlist.sets.splice(setIdx, 1);
    setlist = { ...setlist };
    const updated = await updateSetlist(setlist);
    if (updated) setlist = updated;
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
      const updated = await updateSetlist(setlist);
      if (!applyUpdatedSetlist(updated)) {
        setlist.sets[setIdx].songs = originalSongs;
        setlist = { ...setlist };
      }
      //showSuccess('Song erfolgreich entfernt');
    } catch (error) {
      // Rollback on error
      setlist.sets[setIdx].songs = originalSongs;
      setlist = { ...setlist };
      //showError(`Fehler beim Entfernen des Songs: ${error.message}`);
    }
  }

  async function removeLastSongFromStack() {
    // Suche das letzte Set, das mindestens einen Song enthält.
    for (let setIdx = setlist.sets.length - 1; setIdx >= 0; setIdx--) {
      const songs = setlist.sets[setIdx].songs;
      if (!songs?.length) continue;

      const lastSong = songs[songs.length - 1];
      await removeSongFromSet(setIdx, lastSong.setsong_id);
      return;
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
    const isAddSetShortcut =
      (e.ctrlKey || e.metaKey) &&
      e.shiftKey &&
      (e.key === 'Enter' || e.code === 'Enter');
    const isRemoveLastSongShortcut =
      (e.ctrlKey || e.metaKey) && e.shiftKey && (e.key === 'Backspace' || e.key === 'Delete');

    if (isRemoveLastSongShortcut) {
      e.preventDefault();
      removeLastSongFromStack();
      return;
    }

    // Strg/Cmd + Shift + Enter -> Neues Set am Ende hinzufügen
    if (isAddSetShortcut) {
      e.preventDefault();
      addSetAtEnd();
      return;
    }

    const target = e.target;
    const isTypingTarget =
      target instanceof HTMLElement &&
      (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName));

    if (isTypingTarget) return;
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
  {@const pauseBeforeSet = getPauseBeforeSet(setIdx)}
  <div class="set-card shadow-sm transition-all duration-200 hover:shadow-md">
    {#if pauseBeforeSet}
      <div class="pause-before-set flex items-center gap-1">
        <svg class="w-4 h-4 text-surface-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        Pause: {pauseBeforeSet} min
      </div>
    {/if}
    <div class="set-header">
       <button class="btn btn-sm variant-filled-primary min-h-[38px] font-bold px-3 py-0 touch-manipulation" onclick={() => insertSetBefore(setIdx)} disabled={isUpdating}>
          + Set davor
       </button>
       <input
          type="text"
          class="setlist-name-input min-h-[38px]"
          value={set.setlist_name ?? ''}
          placeholder={`Set ${setIdx + 1}`}
          oninput={(e) => {
            // Nur lokale DOM-Mutation – kein Svelte-Neurender, kein Cursor-Sprung
            setlist.sets[setIdx].setlist_name = e.target.value;
          }}
          onblur={(e) => {
            // Tiefe Kopie via JSON um den Svelte-5-Proxy zu de-proxyfizieren,
            // dann den aktuellen DOM-Wert reinschreiben und ans Backend senden.
            // KEIN setlist = ... hier → kein Neurender → kein Zurückspringen.
            const snapshot = JSON.parse(JSON.stringify(setlist));
            snapshot.sets[setIdx].setlist_name = e.target.value;
            (async () => {
              const updated = await updateSetlist(snapshot);
              if (updated) setlist = updated;
            })();
          }}
       />
       <button class="btn btn-sm variant-filled-error min-h-[38px] min-w-[38px] flex items-center justify-center p-0 touch-manipulation" onclick={() => removeSet(setIdx)} disabled={isUpdating} aria-label="Set löschen">
            <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"></path>
            </svg>
       </button>
    </div>
    <div class="set-time-row flex items-center gap-1.5 px-3 py-1.5 text-sm font-semibold text-primary-500">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      Start: <span class="bg-primary-500/10 px-2 py-0.5 rounded text-primary-700 dark:text-primary-300 font-bold">{getSetStartTime(setIdx) || '--:--'}</span>
    </div>
    <div
      class="songs-drag-zone p-2 rounded-b-lg border-2 border-dashed border-transparent transition-colors duration-150 min-h-[60px]"
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
      {#each set.songs as song, songIdx (song.setsong_id)}
        {@const isDuplicateSong = duplicateSongKeys.has(getSongDuplicateKey(song))}
        <div class="song-in-set text-surface-900 dark:text-surface-950 shadow-sm hover:shadow transition-shadow duration-150" data-song-id={song.setsong_id}
        class:song-duplicate={isDuplicateSong}
        style="background: {getColorBySinger(getFirstSinger(song.singer_lead))};"
        >
          <span class="flex items-center gap-1.5 min-w-0 flex-grow py-1">
            <small class="song-time bg-black/10 dark:bg-black/20 px-1.5 py-0.5 rounded font-bold text-xs">{getSongStartTime(setIdx, songIdx) || '--:--'}</small>
            {#if song.brass === 1}
              <span class="text-base flex-shrink-0" title="Bläser">🎺</span>
            {/if}
            <span class="font-semibold text-sm truncate mr-1">{song.title}</span>
            {#if isDuplicateSong}
              <span class="duplicate-badge" title="Song kommt mehrfach in der Setliste vor">!</span>
            {/if}
            {#if song.comment}
              <small class="text-xs opacity-75 truncate max-w-[120px] italic">({song.comment})</small>
            {/if}
          </span>
          <button class="btn btn-sm variant-filled-error min-h-[36px] min-w-[36px] flex items-center justify-center p-0 ml-2 touch-manipulation"
                  aria-label="Song entfernen"
                  onclick={() => removeSongFromSet(setIdx, song.setsong_id)}>
            <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      {/each}

      {#if !set.songs.length}
        <div class="empty-set-hint py-4">Ziehe Songs hierher…</div>
      {/if}
    </div>

    <div class="set-end-row px-3 py-2 border-t border-surface-200/50 bg-surface-100/10 rounded-b-lg">
      <div class="flex items-center gap-1">
        <svg class="w-4 h-4 opacity-75" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14"></path>
        </svg>
        <span>Ende: <strong class="bg-surface-200/50 px-2 py-0.5 rounded text-surface-800 dark:text-surface-200">{getSetEndTime(setIdx) || '--:--'}</strong></span>
      </div>

      <div class="flex items-center gap-1.5 ml-auto">
        <label class="pause-label flex items-center gap-1" for={`pause-${setIdx}`}>
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Pause:
        </label>
        <input
          id={`pause-${setIdx}`}
          type="time"
          step="60"
          class="pause-input min-h-[34px] w-[95px]"
          value={formatPauseForInput(set.pause)}
          oninput={(e) => {
            setlist.sets[setIdx].pause = e.target.value;
          }}
          onblur={async (e) => {
            const normalizedPause = normalizePauseForApi(e.target.value);
            setlist.sets[setIdx].pause = normalizedPause;
            const snapshot = JSON.parse(JSON.stringify(setlist));
            snapshot.sets[setIdx].pause = normalizedPause;
            const updated = await updateSetlist(snapshot);
            if (updated) setlist = updated;
          }}
        />
      </div>

      {#if setIdx === (setlist.sets.length - 1) && getTargetGigEndTime()}
        {@const gigDiff = getGigEndDiffMinutes()}
        <div class="w-full flex flex-wrap gap-2 justify-end mt-2 pt-2 border-t border-surface-200/50">
          <span class="gig-target-end text-xs">Ziel: <strong>{getTargetGigEndTime()}</strong></span>
          {#if gigDiff != null}
            {#if gigDiff >= 0}
              <span class="gig-end-ok text-xs text-success-500 bg-success-500/10 px-2 py-0.5 rounded">Plan-Ende: {getPlannedGigEndTime() || '--:--'}</span>
            {:else}
              <span class="gig-end-over text-xs text-error-500 bg-error-500/10 px-2 py-0.5 rounded">-{Math.abs(gigDiff)} min</span>
            {/if}
          {/if}
        </div>
      {/if}
    </div>
  </div>

{/each}

<div class="add-set-end-container">
  <button class="btn variant-filled-secondary hover:variant-filled-primary min-h-[42px] px-6 font-bold shadow-md transition-all duration-150 touch-manipulation rounded-lg" onclick={addSetAtEnd} disabled={isUpdating}>
    + Weiteres Set hinzufügen
  </button>
</div>

<style>
.set-card   {
  background: rgb(var(--color-surface-50));
  border: 1px solid rgb(var(--color-surface-200));
  border-radius: 12px;
  margin-bottom: 1.25rem;
  overflow: hidden;
}

.song-in-set {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: white;
  margin-bottom: 6px;
  padding: 0.4rem 0.75rem;
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.song-duplicate {
  border: 1.5px solid #dc2626;
}

.duplicate-badge {
  display: inline-block;
  margin: 0 .35em;
  color: #dc2626;
  font-weight: 700;
}

.empty-set-hint {
  color: rgb(var(--color-surface-500));
  font-style: italic;
  text-align: center;
  opacity: 0.75;
}

.pause-before-set {
  margin: 0.5rem 0.5rem 0.25rem;
  color: rgb(var(--color-surface-600));
  font-size: 0.85rem;
  font-style: italic;
  font-weight: 500;
}

.set-end-row {
  color: #1e5d91;
  font-size: .88rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: .5em;
}

.gig-target-end {
  color: rgb(var(--color-surface-600));
}

.gig-end-ok {
  font-weight: 700;
}

.gig-end-over {
  font-weight: 700;
}

.song-time {
  display: inline-block;
  color: rgb(var(--color-surface-700));
}

.pause-label {
  color: rgb(var(--color-surface-600));
  font-size: .88rem;
}

.pause-input {
  border: 1px solid rgb(var(--color-surface-300));
  background: white;
  color: rgb(var(--color-surface-800));
  border-radius: 6px;
  padding: .2em .5em;
  font-size: .88rem;
}

.pause-input:focus {
  outline: none;
  border-color: rgb(var(--color-primary-500));
}

.set-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  background: rgb(var(--color-surface-100));
  padding: .65rem 0.75rem;
  border-bottom: 1px solid rgb(var(--color-surface-200));
}

.setlist-name-input {
  flex: 1;
  min-width: 100px;
  max-width: 100%;
  border: 1px solid rgb(var(--color-surface-300));
  background: white;
  color: rgb(var(--color-surface-900));
  border-radius: 6px;
  font-size: 0.95rem;
  padding: .35rem .6rem;
  transition: border-color 0.18s;
  font-weight: 600;
}

.setlist-name-input:focus {
  border-color: rgb(var(--color-primary-500));
  outline: none;
}

.add-set-end-container {
  display: flex;
  justify-content: center;
  padding: 1.5rem 0;
}
</style>
