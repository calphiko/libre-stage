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
  import { flip } from 'svelte/animate';
  import { dndzone } from 'svelte-dnd-action';
  import {getFirstSinger, getColorBySinger } from '$lib/common.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { updateGigSetlist, getSong, getGigs, getSetlist } from '$lib/api.js';


  let {
    setlist = $bindable(),
    canUndo = $bindable(false),
    canRedo = $bindable(false),
    isUpdatingSpinner = $bindable(false)
  } = $props();
  const { showError, showSuccess } = createMessageHelpers();

  let isUpdating = $state(false);
  let updateError = $state(null);

  let dragOverSetIdx = $state(null);
  let dragOverSongId = $state(null);
  let dragInsertPos = $state(null); // Neue Position zum Einfügen

  
  let nextNegativeSetsongId = $state(-1);
  let deletingSongIds = $state(new Set());
  let draggingSetIdx = $state(null);
  let dropSetIdx = $state(null);
  let setDragPreviewEl = null;
  const MAX_HISTORY_ENTRIES = 50;
  let historyPast = $state([]);
  let historyFuture = $state([]);
  let historySetlistId = $state(null);
  let pendingSongsDragSnapshot = $state(null);
  let showPastSetImport = $state(false);
  let loadingPastGigs = $state(false);
  let loadingPastGigSets = $state(false);
  let pastGigOptions = $state([]);
  let selectedPastGigId = $state('');
  let pastGigSets = $state([]);
  let selectedPastSetId = $state('');

  let selectedPastGigOption = $derived(
    pastGigOptions.find((gigOption) => String(gigOption.id) === selectedPastGigId) ?? null
  );

  let selectedPastSetOption = $derived(
    pastGigSets.find((setOption) => String(setOption.id) === selectedPastSetId) ?? null
  );

  function cloneSetlistState(value) {
    if (value == null) return value;
    try {
      if (typeof structuredClone === 'function') return structuredClone(value);
    } catch (_err) {
      // Fallback for non-cloneable proxy/state values.
    }
    return JSON.parse(JSON.stringify(value));
  }

  function areSetlistsEqual(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
  }

  function notifyHistoryState() {
    canUndo = historyPast.length > 0;
    canRedo = historyFuture.length > 0;
  }

  function clearHistory() {
    historyPast = [];
    historyFuture = [];
    notifyHistoryState();
  }

  function pushHistorySnapshot(snapshot) {
    const clonedSnapshot = cloneSetlistState(snapshot);
    if (!clonedSnapshot) return;
    historyPast = [...historyPast, clonedSnapshot].slice(-MAX_HISTORY_ENTRIES);
    historyFuture = [];
    notifyHistoryState();
  }

  export function registerExternalHistorySnapshot(snapshot) {
    pushHistorySnapshot(snapshot);
  }

  export function resetHistoryFromExternalUpdate() {
    clearHistory();
  }

  async function applySetlistChange(mutator) {
    if (!setlist || isUpdating) return false;

    try {
      const draft = cloneSetlistState(setlist);
      mutator(draft);
      return await persistDraftWithHistory(draft);
    } catch (error) {
      console.error('Failed to apply setlist change:', error);
      showError('Änderung konnte nicht angewendet werden.');
      return false;
    }
  }

  async function persistDraftWithHistory(draft, beforeSnapshot = null) {
    const before = beforeSnapshot ? cloneSetlistState(beforeSnapshot) : cloneSetlistState(setlist);

    if (areSetlistsEqual(before, draft)) {
      return true;
    }

    pushHistorySnapshot(before);
    setlist = draft;
    const updated = await updateSetlist(draft);
    if (updated) {
      setlist = updated;
      return true;
    }

    historyPast = historyPast.slice(0, -1);
    notifyHistoryState();
    setlist = before;
    return false;
  }

  export async function undoLastChange() {
    if (!setlist || !historyPast.length || isUpdating) return;

    const current = cloneSetlistState(setlist);
    const baseVersion = current?.setlist_version ?? null;
    const previous = historyPast[historyPast.length - 1];
    historyPast = historyPast.slice(0, -1);
    historyFuture = [...historyFuture, current].slice(-MAX_HISTORY_ENTRIES);
    notifyHistoryState();

    const undoDraft = cloneSetlistState(previous);
    // Undo basiert auf dem aktuellen DB-Stand, nicht auf der alten Snapshot-Version.
    if (baseVersion) {
      undoDraft.setlist_version = baseVersion;
    }
    setlist = undoDraft;
    const updated = await updateSetlist(setlist, { showToast: false });
    if (updated) {
      setlist = updated;
      return;
    }

    historyPast = [...historyPast, previous].slice(-MAX_HISTORY_ENTRIES);
    historyFuture = historyFuture.slice(0, -1);
    setlist = current;
    notifyHistoryState();
    showError('Rückgängig konnte nicht gespeichert werden.');
  }

  export async function redoLastChange() {
    if (!setlist || !historyFuture.length || isUpdating) return;

    const current = cloneSetlistState(setlist);
    const baseVersion = current?.setlist_version ?? null;
    const next = historyFuture[historyFuture.length - 1];
    historyFuture = historyFuture.slice(0, -1);
    historyPast = [...historyPast, current].slice(-MAX_HISTORY_ENTRIES);
    notifyHistoryState();

    const redoDraft = cloneSetlistState(next);
    // Redo basiert ebenfalls auf dem zuletzt bestätigten Stand.
    if (baseVersion) {
      redoDraft.setlist_version = baseVersion;
    }
    setlist = redoDraft;
    const updated = await updateSetlist(setlist, { showToast: false });
    if (updated) {
      setlist = updated;
      return;
    }

    historyFuture = [...historyFuture, next].slice(-MAX_HISTORY_ENTRIES);
    historyPast = historyPast.slice(0, -1);
    setlist = current;
    notifyHistoryState();
    showError('Wiederholen konnte nicht gespeichert werden.');
  }

  $effect(() => {
    const currentId = setlist?.id ?? null;
    if (historySetlistId === null && currentId !== null) {
      historySetlistId = currentId;
      clearHistory();
      return;
    }
    if (currentId !== null && historySetlistId !== currentId) {
      historySetlistId = currentId;
      clearHistory();
    }
  });

  function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  function isGigInPast(datum) {
    if (!datum) return false;
    const parsed = new Date(`${datum}T00:00:00`);
    if (Number.isNaN(parsed.getTime())) return false;

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return parsed < today;
  }

  function formatGigOptionLabel(gig) {
    const datePart = gig?.datum ? gig.datum : 'ohne Datum';
    return `${datePart} - ${gig?.name ?? `Gig ${gig?.id ?? ''}`}`;
  }

  async function loadPastGigOptions() {
    loadingPastGigs = true;
    try {
      const gigs = await getGigs();
      const currentGigId = Number(setlist?.id);
      const options = (gigs ?? [])
        .filter((gig) => Number(gig.id) !== currentGigId)
        .filter((gig) => isGigInPast(gig.datum))
        .sort((a, b) => String(b.datum ?? '').localeCompare(String(a.datum ?? '')))
        .map((gig) => ({
          id: Number(gig.id),
          label: formatGigOptionLabel(gig),
        }));
      pastGigOptions = options;
    } catch (error) {
      console.error('Could not load past gigs:', error);
      showError('Vergangene Gigs konnten nicht geladen werden.');
    } finally {
      loadingPastGigs = false;
    }
  }

  async function loadSetsForPastGig(gigId) {
    if (!gigId) {
      pastGigSets = [];
      selectedPastSetId = '';
      return;
    }

    loadingPastGigSets = true;
    try {
      const sourceSetlist = await getSetlist(null, Number(gigId));
      pastGigSets = (sourceSetlist?.sets ?? []).map((setEntry) => ({
        id: Number(setEntry.gigset_id ?? setEntry.id),
        label: setEntry.setlist_name || setEntry.set_name || `Set ${setEntry.id ?? ''}`,
        source: setEntry,
      }));
      selectedPastSetId = pastGigSets.length ? String(pastGigSets[0].id) : '';
    } catch (error) {
      console.error('Could not load sets for past gig:', error);
      showError('Sets des ausgewählten Gigs konnten nicht geladen werden.');
      pastGigSets = [];
      selectedPastSetId = '';
    } finally {
      loadingPastGigSets = false;
    }
  }

  async function togglePastSetImport() {
    showPastSetImport = !showPastSetImport;
    if (!showPastSetImport) return;

    if (!pastGigOptions.length && !loadingPastGigs) {
      await loadPastGigOptions();
    }

    if (!selectedPastGigId && pastGigOptions.length) {
      selectedPastGigId = String(pastGigOptions[0].id);
      await loadSetsForPastGig(selectedPastGigId);
    }
  }

  function closePastSetImport() {
    showPastSetImport = false;
    selectedPastGigId = '';
    selectedPastSetId = '';
    pastGigSets = [];
  }

  function buildImportedSong(sourceSong) {
    const songId = Number(sourceSong?.song_id ?? sourceSong?.id);
    if (!songId) return null;
    return {
      ...sourceSong,
      id: songId,
      song_id: songId,
      setsong_id: nextNegativeSetsongId--,
      eingeschoben: null,
      uebersprungen: null,
      feedback: null,
    };
  }

  async function importSelectedPastSet() {
    if (isUpdating) return;
    const selected = pastGigSets.find((entry) => String(entry.id) === selectedPastSetId);
    if (!selected?.source) {
      showError('Bitte zuerst ein Set auswählen.');
      return;
    }

    const sourceSet = selected.source;
    const importedSongs = (sourceSet.songs ?? [])
      .map(buildImportedSong)
      .filter(Boolean);

    const importedSet = {
      songs: importedSongs,
      pause: sourceSet.pause || '00:10:00',
      setlist_name: sourceSet.setlist_name || sourceSet.set_name || '',
      set_name: sourceSet.set_name || sourceSet.setlist_name || 'Importiertes Set',
    };

    const ok = await applySetlistChange((draft) => {
      draft.sets.push(importedSet);
    });

    if (ok) {
      const importedSetName = importedSet.setlist_name || importedSet.set_name || 'Importiertes Set';
      const importedGigName = selectedPastGigOption?.label ?? 'vergangenem Gig';
      showSuccess(`Set "${importedSetName}" aus "${importedGigName}" wurde eingefügt.`);
      closePastSetImport();
    }
  }

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

    // Berücksichtigung von Datumsübergang (Mitternacht)
    // Wenn die Zielendzeit sehr früh am Morgen ist (< 6:00)
    // und die geplante Zeit später am "selben Tag" ist (aber > 6:00, also eher am Vorabend)
    // dann geht der Gig über Mitternacht hinaus
    let adjustedTargetMinutes = targetMinutes;
    if (targetMinutes < 6 * 60 && plannedMinutes > 6 * 60) {
      // Zielzeit ist früh am Morgen (nächster Tag)
      // und geplante Zeit ist später am Vorabend (> 6:00)
      // → Datumsüberlauf: addiere 24 Stunden zur Zielzeit für den Vergleich
      adjustedTargetMinutes += 24 * 60;
    }

    return plannedMinutes - adjustedTargetMinutes;
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

  function getReadableTextClass(backgroundColor) {
    const hex = (backgroundColor || '').replace('#', '');
    if (!/^[0-9A-Fa-f]{6}$/.test(hex)) return 'text-surface-900 dark:text-surface-100';

    const r = parseInt(hex.slice(0, 2), 16);
    const g = parseInt(hex.slice(2, 4), 16);
    const b = parseInt(hex.slice(4, 6), 16);
    const luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);

    return luminance > 150 ? 'text-surface-900 dark:text-surface-900' : 'text-surface-50 dark:text-surface-50';
  }

  function cleanDnDItems(items) {
    // Entferne nur Shadow-Elemente
    return items.filter(item => !item._dndShadowItem);
  }

  function moveSetInArray(sets, fromIdx, toIdx) {
    const next = [...sets];
    const [moved] = next.splice(fromIdx, 1);
    next.splice(toIdx, 0, moved);
    return next;
  }

  async function reorderSets(fromIdx, targetIdx) {
    if (!setlist?.sets?.length) return;
    if (fromIdx == null || targetIdx == null) return;

    const maxTarget = setlist.sets.length;
    const boundedTarget = Math.max(0, Math.min(targetIdx, maxTarget));
    const insertIdx = boundedTarget > fromIdx ? boundedTarget - 1 : boundedTarget;

    if (insertIdx === fromIdx) return;

    await applySetlistChange((draft) => {
      draft.sets = moveSetInArray(draft.sets, fromIdx, insertIdx);
    });
  }

  function resetSetDragState() {
    draggingSetIdx = null;
    dropSetIdx = null;
    clearSetDragPreview();
  }

  function clearSetDragPreview() {
    if (!setDragPreviewEl) return;
    setDragPreviewEl.remove();
    setDragPreviewEl = null;
  }

  function createSetDragPreview(sourceSetCard) {
    clearSetDragPreview();
    if (!sourceSetCard) return null;

    const preview = sourceSetCard.cloneNode(true);
    preview.classList.add('set-drag-preview');
    preview.classList.remove('set-is-dragging');
    preview.querySelectorAll('button, input, select, textarea').forEach((el) => {
      el.setAttribute('disabled', 'true');
    });

    preview.setAttribute('aria-hidden', 'true');
    preview.style.width = `${sourceSetCard.getBoundingClientRect().width}px`;
    document.body.appendChild(preview);
    setDragPreviewEl = preview;
    return preview;
  }

  function handleSetDragStart(setIdx, e) {
    if (isUpdating) return;
    draggingSetIdx = setIdx;
    dropSetIdx = setIdx;
    const sourceSetCard = e.currentTarget?.closest('.set-card');
    const preview = createSetDragPreview(sourceSetCard);
    if (preview) {
      const rect = preview.getBoundingClientRect();
      e.dataTransfer.setDragImage(preview, Math.min(36, rect.width / 2), 20);
    }
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', `set:${setIdx}`);
  }

  function handleSetSlotDragOver(targetIdx, e) {
    if (isUpdating || draggingSetIdx == null) return;
    e.preventDefault();
    dropSetIdx = targetIdx;
  }

  async function handleSetDropToSlot(targetIdx, e) {
    e.preventDefault();
    if (isUpdating || draggingSetIdx == null) return;
    await reorderSets(draggingSetIdx, targetIdx);
    resetSetDragState();
  }

  function handleSetEndDragOver(e) {
    if (isUpdating || draggingSetIdx == null) return;
    e.preventDefault();
    dropSetIdx = setlist?.sets?.length ?? null;
  }

  async function handleSetDropAtEnd(e) {
    e.preventDefault();
    if (isUpdating || draggingSetIdx == null || !setlist?.sets?.length) return;
    await reorderSets(draggingSetIdx, setlist.sets.length);
    resetSetDragState();
  }

  function handleSetDragEnd() {
    resetSetDragState();
  }

  function handleSongsConsider(setIdx, { detail }) {
    if (isUpdating) return;
    if (!pendingSongsDragSnapshot) {
      pendingSongsDragSnapshot = cloneSetlistState(setlist);
    }
    setlist.sets[setIdx].songs = cleanDnDItems(detail.items);
    setlist = { ...setlist }; // Triggert Reaktivität
  }

  async function handleSongsFinalize(setIdx, { detail }) {
    if (isUpdating) return;
    try {
      const processedSongs = cleanDnDItems(detail.items).map(song => {
        // Wenn der Song aus der SongList via svelte-dnd-action gezogen wurde, hat er eine ID beginnend mit "new-"
        if (typeof song.setsong_id === 'string' && song.setsong_id.startsWith('new-')) {
          const parts = song.setsong_id.split('-');
          const originalSongId = Number(parts[1]);
          return {
            ...song,
            id: originalSongId,
            // Backend erwartet in Songs immer song_id.
            song_id: originalSongId,
            // Neue temporäre negative setsong_id vergeben
            setsong_id: -Math.floor(Date.now() + Math.random() * 100000)
          };
        }
        // Fallback: Falls ein Song-Objekt ohne song_id reinkommt, aus id ableiten.
        if (song?.song_id == null && song?.id != null) {
          return {
            ...song,
            song_id: Number(song.id)
          };
        }
        return song;
      });

      const draft = cloneSetlistState(setlist);
      draft.sets[setIdx].songs = processedSongs;
      await persistDraftWithHistory(draft, pendingSongsDragSnapshot);
    } finally {
      pendingSongsDragSnapshot = null;
    }
  }

  async function handleDragOverSet(setIdx, e) {
    if (isUpdating) return;
    e.preventDefault();
    dragOverSetIdx = setIdx;
    dragOverSongId = e.dataTransfer.getData('text/plain');
    dragInsertPos = setlist.sets[setIdx].songs.length; // Standard: Ende der Liste

    let songInfo = await getSong(null, e.dataTransfer.getData('text/plain'));
    songInfo.setsong_id = nextNegativeSetsongId;
    nextNegativeSetsongId -= 1;

    await applySetlistChange((draft) => {
      draft.sets[setIdx].songs = [
        ...draft.sets[setIdx].songs.slice(0, dragInsertPos),
        songInfo,
        ...draft.sets[setIdx].songs.slice(dragInsertPos)
      ];
    });

  }

  function handleDragOverSong(setIdx, songIdx, e) {
    if (isUpdating) return;
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
    if (isUpdating) return;
    const newSet = {
      songs: [],
      pause: '00:10:00',
    };
    await applySetlistChange((draft) => {
      draft.sets.splice(idx, 0, newSet);
    });
  }

  async function addSetAtEnd() {
    if (isUpdating) return;
    const newSet = {
      songs: [],
      pause: '00:10:00',
      setlist_name: '',
      set_name: ''
    };
    await applySetlistChange((draft) => {
      draft.sets.push(newSet);
    });
  }

  async function removeSet(setIdx) {
    if (isUpdating) return;
    await applySetlistChange((draft) => {
      draft.sets.splice(setIdx, 1);
    });
  }

  async function removeSongFromSet(setIdx, setsong_id) {
    if (isUpdating) return;
    if (deletingSongIds.has(setsong_id)) return;

    deletingSongIds = new Set(deletingSongIds).add(setsong_id);
    try {
      // Erst visuelle Exit-Animation, dann Datenmutation.
      await wait(170);

      await applySetlistChange((draft) => {
        draft.sets[setIdx].songs = draft.sets[setIdx].songs.filter(
          s => s.setsong_id !== setsong_id
        );
      });
    } finally {
      deletingSongIds = new Set(deletingSongIds);
      deletingSongIds.delete(setsong_id);
    }
  }

  async function removeLastSongFromStack() {
    if (isUpdating) return;
    // Suche das letzte Set, das mindestens einen Song enthält.
    for (let setIdx = setlist.sets.length - 1; setIdx >= 0; setIdx--) {
      const songs = setlist.sets[setIdx].songs;
      if (!songs?.length) continue;

      const lastSong = songs[songs.length - 1];
      await removeSongFromSet(setIdx, lastSong.setsong_id);
      return;
    }
  }

  async function updateSetlist(data, options = {}) {
    const { showToast = true } = options;
    isUpdating = true;
    isUpdatingSpinner = true;
    updateError = null;
    try {
      const result = await updateGigSetlist(null, data.id, data);
      return result;
    } catch (error) {
      if (error?.code === 'SETLIST_CONFLICT' && error?.currentSetlist) {
        updateError = 'Setlist-Konflikt';
        setlist = error.currentSetlist;
        clearHistory();
        showError('Setliste wurde in der Zwischenzeit geändert. Deine Änderung wurde nicht gespeichert und diese Ansicht nun aktualisiert. Bitte versuche es nochmal.');
        return error.currentSetlist;
      }

      updateError = error.message;
      console.error('Failed to update setlist:', error);
      if (showToast) {
        showError(`Fehler beim Speichern: ${error.message}`);
      }
    } finally {
      isUpdating = false;
      isUpdatingSpinner = false;
    }
  }

  function handleKeyboardShortcuts(e) {
    if (isUpdating) return;

    const target = e.target;
    const isTypingTarget =
      target instanceof HTMLElement &&
      (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName));

    if (!isTypingTarget) {
      const isUndoShortcut = (e.ctrlKey || e.metaKey) && !e.altKey && e.key.toLowerCase() === 'z' && !e.shiftKey;
      const isRedoShortcut =
        (e.ctrlKey || e.metaKey) && !e.altKey &&
        (e.key.toLowerCase() === 'y' || (e.key.toLowerCase() === 'z' && e.shiftKey));

      if (isUndoShortcut) {
        e.preventDefault();
        undoLastChange();
        return;
      }

      if (isRedoShortcut) {
        e.preventDefault();
        redoLastChange();
        return;
      }
    }

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
    clearSetDragPreview();
  });
</script>

{#each setlist.sets as set, setIdx (set.gigset_id)}
  <div
    class="set-item"
    animate:flip={{ duration: 260 }}
  >
    <div
      class="set-drop-slot"
      class:set-drop-slot-visible={draggingSetIdx !== null}
      class:set-drop-slot-active={draggingSetIdx !== null && dropSetIdx === setIdx}
      ondragover={(e) => handleSetSlotDragOver(setIdx, e)}
      ondrop={(e) => handleSetDropToSlot(setIdx, e)}
    >
      {#if draggingSetIdx !== null && dropSetIdx === setIdx}
        <span>Hier einfügen</span>
      {/if}
    </div>
    <div
      class="set-card shadow-sm transition-all duration-200 hover:shadow-md"
      class:set-is-dragging={draggingSetIdx === setIdx}
    >
      {#if getPauseBeforeSet(setIdx)}
        <div class="pause-before-set flex items-center gap-1">
          <svg class="w-4 h-4 text-surface-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Pause: {getPauseBeforeSet(setIdx)} min
        </div>
      {/if}
      <div class="set-header">
         <button
           class="set-drag-handle"
           type="button"
           draggable={!isUpdating}
           aria-label={`Set ${setIdx + 1} verschieben`}
           title="Set verschieben"
           ondragstart={(e) => handleSetDragStart(setIdx, e)}
           ondragend={handleSetDragEnd}
           disabled={isUpdating}
         >
           <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 6h8M8 12h8M8 18h8" />
           </svg>
         </button>
         <button class="btn btn-sm variant-filled-primary min-h-[34px] font-bold px-2.5 py-0 touch-manipulation" onclick={() => insertSetBefore(setIdx)} disabled={isUpdating}>
            + Set davor
         </button>
         {#if draggingSetIdx === setIdx}
           <span class="drag-folder-meta">Ordner: {set.songs?.length ?? 0} Stuecke</span>
         {/if}
          <input
            type="text"
            class="setlist-name-input min-h-[34px]"
            value={set.setlist_name ?? ''}
            placeholder={`Set ${setIdx + 1}`}
            disabled={isUpdating}
            onblur={async (e) => {
              await applySetlistChange((draft) => {
                draft.sets[setIdx].setlist_name = e.target.value;
              });
            }}
         />
         <button class="btn btn-sm variant-filled-error min-h-[34px] min-w-[34px] flex items-center justify-center p-0 touch-manipulation" onclick={() => removeSet(setIdx)} disabled={isUpdating} aria-label="Set löschen">
              <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"></path>
              </svg>
         </button>
      </div>
      <div class="set-time-row flex items-center gap-1.5 px-2.5 py-1 text-sm font-semibold text-primary-500">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        Start: <span class="bg-primary-500/10 px-2 py-0.5 rounded text-primary-700 dark:text-primary-300 font-bold">{getSetStartTime(setIdx) || '--:--'}</span>
      </div>
      <div
        class="songs-drag-zone p-1.5 rounded-b-lg border-2 border-dashed border-transparent transition-colors duration-150 min-h-[52px]"
        use:dndzone={{
          items: set.songs,
          type: 'song-in-set',
          flipDurationMs: 220,
          dragDisabled: isUpdating,
          dropFromOthersDisabled: isUpdating
        }}
        onconsider={e => handleSongsConsider(setIdx, e)}
        onfinalize={e => handleSongsFinalize(setIdx, e)}
        ondragover={(e) => e.preventDefault()}
        ondrop={(e) => handleDragOverSet(setIdx, e)}
      >
        {#each set.songs as song, songIdx (song.setsong_id)}
          {@const isDuplicateSong = duplicateSongKeys.has(getSongDuplicateKey(song))}
          {@const singerColor = getColorBySinger(getFirstSinger(song.singer_lead))}
          <div class="song-in-set shadow-sm hover:shadow transition-shadow duration-150 {getReadableTextClass(singerColor)}" data-song-id={song.setsong_id}
          class:song-removing={deletingSongIds.has(song.setsong_id)}
          class:song-duplicate={isDuplicateSong}
          style="--song-singer-color:{singerColor};"
          animate:flip={{ duration: 180 }}
          >
            <span class="flex items-center gap-1.5 min-w-0 flex-grow py-0.5">
              <small class="song-time bg-black/10 dark:bg-black/20 px-1.5 py-0.5 rounded font-bold text-xs">{getSongStartTime(setIdx, songIdx) || '--:--'}</small>
              {#if song.brass === 1}
                <span class="text-base flex-shrink-0" title="Bläser">🎺</span>
              {/if}
              <span class="font-semibold text-xs truncate mr-1">{song.title}</span>
              {#if isDuplicateSong}
                <span class="duplicate-badge" title="Song kommt mehrfach in der Setliste vor">!</span>
              {/if}
              {#if song.comment}
                <small class="text-xs opacity-75 truncate max-w-[120px] italic">({song.comment})</small>
              {/if}
            </span>
            <button class="btn btn-sm variant-filled-error min-h-[34px] min-w-[34px] flex items-center justify-center p-0 ml-1.5 touch-manipulation"
                    aria-label="Song entfernen"
                    disabled={isUpdating}
                    onclick={() => removeSongFromSet(setIdx, song.setsong_id)}>
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        {/each}

        {#if !set.songs.length}
          <div class="empty-set-hint py-3">Ziehe Songs hierher…</div>
        {/if}
      </div>

      <div class="set-end-row px-2.5 py-1.5 border-t border-surface-200/50 dark:border-surface-700/60 bg-surface-100/10 dark:bg-surface-900/20 rounded-b-lg">
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
            class="pause-input min-h-[32px] w-[88px]"
            value={formatPauseForInput(set.pause)}
            disabled={isUpdating}
            onblur={async (e) => {
              const normalizedPause = normalizePauseForApi(e.target.value);
              await applySetlistChange((draft) => {
                draft.sets[setIdx].pause = normalizedPause;
              });
            }}
          />
        </div>

        {#if setIdx === (setlist.sets.length - 1) && getTargetGigEndTime()}
          {@const gigDiff = getGigEndDiffMinutes()}
          <div class="w-full flex flex-wrap gap-1.5 justify-end mt-1.5 pt-1.5 border-t border-surface-200/50 dark:border-surface-700/60">
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
  </div>

{/each}

<div
  class="set-drop-slot set-drop-end"
  class:set-drop-slot-visible={draggingSetIdx !== null}
  class:set-drop-slot-active={draggingSetIdx !== null && dropSetIdx === (setlist?.sets?.length ?? -1)}
  ondragover={handleSetEndDragOver}
  ondrop={handleSetDropAtEnd}
>
  {#if draggingSetIdx !== null && dropSetIdx === (setlist?.sets?.length ?? -1)}
    <span>Hier einfügen (am Ende)</span>
  {/if}
</div>

<div class="add-set-end-container">
  <button
    class="btn min-h-[38px] px-4 font-semibold shadow-sm transition-all duration-150 touch-manipulation rounded-lg"
    class:variant-filled-primary={showPastSetImport}
    class:variant-soft-primary={!showPastSetImport}
    onclick={togglePastSetImport}
    disabled={isUpdating}
  >
    {showPastSetImport ? 'Import schliessen' : 'Set aus vergangenem Gig'}
  </button>
  <button class="btn variant-filled-secondary hover:variant-filled-primary min-h-[38px] px-5 font-bold shadow-md transition-all duration-150 touch-manipulation rounded-lg" onclick={addSetAtEnd} disabled={isUpdating}>
    + Weiteres Set hinzufügen
  </button>
</div>

{#if showPastSetImport}
  <div class="past-set-import-panel card variant-soft-primary p-3">

    <div class="import-grid">
      <label class="label import-field">
        <span class="import-field-label">1) Gig auswählen</span>
        <select
          class="select"
          bind:value={selectedPastGigId}
          disabled={loadingPastGigs || isUpdating}
          onchange={async (e) => {
            selectedPastGigId = e.target.value;
            await loadSetsForPastGig(selectedPastGigId);
          }}
        >
          <option value="">Bitte wählen...</option>
          {#each pastGigOptions as gigOption}
            <option value={String(gigOption.id)}>{gigOption.label}</option>
          {/each}
        </select>
      </label>

      <label class="label import-field">
        <span class="import-field-label">2) Set auswählen</span>
        <select
          class="select"
          bind:value={selectedPastSetId}
          disabled={!selectedPastGigId || loadingPastGigSets || isUpdating}
        >
          <option value="">Bitte wählen...</option>
          {#each pastGigSets as setOption}
            <option value={String(setOption.id)}>{setOption.label}</option>
          {/each}
        </select>
      </label>
    </div>

    {#if selectedPastSetOption}
      <div class="import-preview-row">
        <span class="badge variant-soft-primary">Set: {selectedPastSetOption.label}</span>
        <span class="badge variant-soft-secondary">Songs: {selectedPastSetOption.source?.songs?.length ?? 0}</span>
      </div>
    {/if}

    <div class="import-action-row">
      <button
        class="btn variant-filled-success min-h-[38px]"
        onclick={importSelectedPastSet}
        disabled={!selectedPastSetId || loadingPastGigSets || isUpdating}
      >
        Als neues Set einfügen
      </button>
    </div>

    {#if loadingPastGigs || loadingPastGigSets}
      <div class="text-xs opacity-70 mt-2">Lade Daten...</div>
    {/if}
    {#if !loadingPastGigs && !pastGigOptions.length}
      <div class="text-xs opacity-70 mt-2">Keine vergangenen Gigs gefunden.</div>
    {/if}
  </div>
{/if}

<style>
.set-card   {
  background: color-mix(in oklab, light-dark(var(--color-surface-50), var(--color-surface-900)) 96%, transparent);
  border: 1px solid color-mix(in oklab, light-dark(var(--color-surface-300), var(--color-surface-600)) 70%, transparent);
  color: light-dark(rgb(var(--color-surface-900)), rgb(var(--color-surface-100)));
  border-radius: 14px;
  margin-bottom: 0.9rem;
  overflow: hidden;
}

.set-is-dragging {
  opacity: 0.88;
  transform: translateY(-2px) scale(1.01);
  border-color: rgb(var(--color-warning-500));
  background: linear-gradient(
    180deg,
    color-mix(in oklab, var(--color-warning-300) 52%, light-dark(var(--color-surface-100), var(--color-surface-800))) 0%,
    color-mix(in oklab, var(--color-warning-200) 24%, light-dark(var(--color-surface-50), var(--color-surface-900))) 24px
  );
  box-shadow: 0 10px 24px rgb(var(--color-warning-500) / 0.25);
  position: relative;
}

.set-is-dragging::before {
  content: '';
  position: absolute;
  top: -1px;
  left: 14px;
  width: 86px;
  height: 12px;
  border: 1px solid rgb(var(--color-warning-400));
  border-bottom: none;
  border-radius: 8px 8px 0 0;
  background: rgb(var(--color-warning-200));
}

.set-is-dragging::after {
  content: '';
  position: absolute;
  top: 12px;
  left: 18px;
  width: 78%;
  height: 6px;
  border-radius: 4px;
  background: repeating-linear-gradient(
    90deg,
    light-dark(rgb(var(--color-surface-300)), rgb(var(--color-surface-600))),
    light-dark(rgb(var(--color-surface-300)), rgb(var(--color-surface-600))) 10px,
    light-dark(rgb(var(--color-surface-100)), rgb(var(--color-surface-800))) 10px,
    light-dark(rgb(var(--color-surface-100)), rgb(var(--color-surface-800))) 20px
  );
  opacity: 0.8;
}

.set-drag-preview {
  position: fixed;
  top: -10000px;
  left: -10000px;
  z-index: 9999;
  pointer-events: none;
  transform: rotate(1.2deg);
  opacity: 0.95;
  max-height: 240px;
  overflow: hidden;
  box-shadow: 0 14px 34px rgb(0 0 0 / 0.28);
}

.set-drag-handle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border-radius: 8px;
  border: 1px dashed rgb(var(--color-surface-400));
  background: light-dark(rgb(var(--color-surface-50)), rgb(var(--color-surface-900)));
  color: light-dark(rgb(var(--color-surface-700)), rgb(var(--color-surface-200)));
  cursor: grab;
  flex-shrink: 0;
}

.set-drag-handle:active {
  cursor: grabbing;
}

.set-drag-handle:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.drag-folder-meta {
  font-size: 0.75rem;
  font-weight: 700;
  color: rgb(var(--color-warning-700));
  background: rgb(var(--color-warning-200) / 0.75);
  border: 1px solid rgb(var(--color-warning-400));
  border-radius: 999px;
  padding: 0.15rem 0.5rem;
  white-space: nowrap;
}

.song-in-set {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: var(--song-singer-color);
  background:
    linear-gradient(145deg,
      color-mix(in oklab, var(--song-singer-color) 92%, white) 0%,
      color-mix(in oklab, var(--song-singer-color) 82%, white) 100%) !important;
  margin-bottom: 4px;
  padding: 0.3rem 0.6rem;
  border-radius: 12px;
  border: 1px solid color-mix(in oklab, light-dark(black, white) 14%, transparent);
  transition: transform 170ms ease, opacity 170ms ease, margin 170ms ease, padding 170ms ease;
  transform-origin: left center;
  will-change: transform, opacity;
}

:global(.dark) .song-in-set {
  background:
    linear-gradient(145deg,
      color-mix(in oklab, var(--song-singer-color) 86%, #0f172a) 0%,
      color-mix(in oklab, var(--song-singer-color) 74%, #020617) 100%) !important;
}

.song-removing {
  transform: translateX(28px);
  opacity: 0;
  pointer-events: none;
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
  margin: 0.4rem 0.45rem 0.2rem;
  color: light-dark(rgb(var(--color-surface-600)), rgb(var(--color-surface-300)));
  font-size: 0.8rem;
  font-style: italic;
  font-weight: 500;
}

.set-end-row {
  color: light-dark(rgb(var(--color-primary-700)), rgb(var(--color-primary-300)));
  font-size: .88rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: .5em;
}

.gig-target-end {
  color: light-dark(rgb(var(--color-surface-600)), rgb(var(--color-surface-300)));
}

.gig-end-ok {
  font-weight: 700;
}

.gig-end-over {
  font-weight: 700;
}

.song-time {
  display: inline-block;
  color: inherit;
}

.pause-label {
  color: light-dark(rgb(var(--color-surface-600)), rgb(var(--color-surface-300)));
  font-size: .88rem;
}

.pause-input {
  border: 1px solid rgb(var(--color-surface-300));
  background: light-dark(rgb(var(--color-surface-50)), rgb(var(--color-surface-900)));
  color: light-dark(rgb(var(--color-surface-800)), rgb(var(--color-surface-100)));
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
  gap: 0.5rem;
  background: color-mix(in oklab, light-dark(var(--color-surface-100), var(--color-surface-850, var(--color-surface-900))) 92%, transparent);
  padding: .5rem 0.65rem;
  border-bottom: 1px solid light-dark(rgb(var(--color-surface-200)), rgb(var(--color-surface-700)));
}

.setlist-name-input {
  flex: 1;
  min-width: 100px;
  max-width: 100%;
  border: 1px solid color-mix(in oklab, var(--color-surface-500) 32%, transparent);
  background-color: light-dark(rgb(var(--color-surface-50)), rgb(var(--color-surface-900))) !important;
  background-image: none !important;
  color: light-dark(rgb(var(--color-surface-900)), rgb(var(--color-surface-50))) !important;
  border-radius: 0.7rem;
  font-size: 0.95rem;
  padding: .35rem .6rem;
  appearance: none;
  transition: border-color 120ms ease, box-shadow 120ms ease, background-color 120ms ease;
  font-weight: 600;
}

:global(.dark) .setlist-name-input {
  border-color: color-mix(in oklab, var(--color-surface-400) 36%, transparent);
  background-color: rgb(var(--color-surface-900)) !important;
  background-image: none !important;
  color: rgb(var(--color-surface-50)) !important;
}

.setlist-name-input:focus {
  border-color: var(--color-primary-500);
  outline: none;
  box-shadow: 0 0 0 3px color-mix(in oklab, var(--color-primary-500) 22%, transparent);
}

.setlist-name-input::placeholder {
  color: light-dark(rgb(var(--color-surface-500)), rgb(var(--color-surface-400)));
}

:global(.dark) .setlist-name-input:focus {
  border-color: rgb(var(--color-primary-400));
  box-shadow: inset 0 1px 0 rgb(var(--color-surface-600) / 0.45), 0 0 0 2px rgb(var(--color-primary-500) / 0.28);
}

.add-set-end-container {
  display: flex;
  justify-content: center;
  gap: 0.6rem;
  padding: 1rem 0;
  flex-wrap: wrap;
}

.past-set-import-panel {
  margin-top: -0.4rem;
  margin-bottom: 0.8rem;
  border: 1px solid color-mix(in oklab, var(--color-primary-500) 30%, transparent);
}

.import-headline-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 0.8rem;
  margin-bottom: 0.6rem;
}

.import-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
}

.import-field {
  gap: 0.3rem;
}

.import-field-label {
  font-size: 0.8rem;
  font-weight: 700;
  opacity: 0.85;
}

.import-preview-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  margin-top: 0.55rem;
}

.import-action-row {
  display: flex;
  justify-content: flex-end;
  margin-top: 0.55rem;
}

@media (max-width: 720px) {
  .import-grid {
    grid-template-columns: 1fr;
  }

  .import-action-row {
    justify-content: stretch;
  }

  .import-action-row .btn {
    width: 100%;
  }
}

.set-drop-slot {
  margin: 0;
  min-height: 0;
  max-height: 0;
  padding: 0;
  border: 1px dashed transparent;
  border-radius: 8px;
  color: transparent;
  text-align: center;
  font-size: 0.78rem;
  background: transparent;
  opacity: 0;
  overflow: hidden;
  pointer-events: none;
  transition: all 180ms ease;
}

.set-drop-slot-visible {
  margin: 0.18rem 0 0.22rem;
  min-height: 16px;
  max-height: 26px;
  border-color: transparent;
  opacity: 0;
  pointer-events: auto;
}

.set-drop-slot-active {
  min-height: 20px;
  max-height: 40px;
  padding: 0.45rem 0.75rem;
  border-color: rgb(var(--color-success-500));
  color: rgb(var(--color-success-700));
  background: rgb(var(--color-success-500) / 0.14);
  opacity: 1;
  transform: scaleY(1.06);
  animation: dndPulse 1.2s ease-in-out infinite;
}

.set-drop-end {
  margin-top: 0.3rem;
}

@keyframes dndPulse {
  0%,
  100% {
    box-shadow: 0 0 0 0 rgb(var(--color-success-500) / 0.2);
  }
  50% {
    box-shadow: 0 0 0 5px rgb(var(--color-success-500) / 0.1);
  }
}
</style>
