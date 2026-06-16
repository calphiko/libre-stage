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
import { onMount, onDestroy } from 'svelte';
	import { getGigLiveMode, updateSongLiveMode, insertSongBefore, getSongs } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import SetlistOverviewPanel from '$lib/components/SetlistOverviewPanel.svelte';

  const { showError, showSuccess } = createMessageHelpers();

    let { parent = {}, meta = {} } = $props();

  const { gigId } = meta;

  let gig = $state(null);
  let allSongs = $state([]);
  let currentIndex = $state(0);
  let loading = $state(true);
  let showHelp = $state(false);
  let showSetlistOverview = $state(false);

  // Song einfügen
  let availableSongs = $state([]);
  let searchTerm = $state('');
  let showInsertSection = $state(false);

  // Touch/Swipe handling
  let touchStartX = $state(0);
  let touchStartY = $state(0);
  let touchEndX = $state(0);
  let isSwiping = $state(false);

  let currentSong = $derived(allSongs[currentIndex]);
  let previousSong = $derived(currentIndex > 0 ? allSongs[currentIndex - 1] : null);
  let nextSong = $derived(currentIndex < allSongs.length - 1 ? allSongs[currentIndex + 1] : null);
  let isFirstSong = $derived(currentIndex === 0);
  let isLastSong = $derived(currentIndex === allSongs.length - 1);
  let isFinished = $derived(currentIndex >= allSongs.length);
  let progress = $derived(allSongs.length > 0 ? ((currentIndex + 1) / allSongs.length) * 100 : 0);
  let filteredSongs = $derived(availableSongs.filter(song =>
    searchTerm === '' ||
    song.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    song.interpret.toLowerCase().includes(searchTerm.toLowerCase())
  ).slice(0, 10)); // Maximal 10 Ergebnisse

  onMount(async () => {
    await loadGigData();
    await loadAvailableSongs();
  });

  async function loadAvailableSongs() {
    try {
      availableSongs = await getSongs(null);
    } catch (e) {
      console.error('Fehler beim Laden der Songs:', e);
    }
  }

  async function loadGigData(skipAutoJump = false) {
    loading = true;
    try {
      gig = await getGigLiveMode(null, gigId);

      // Flatten alle Songs aus allen Sets in eine Liste
      allSongs = [];
      gig.sets.forEach((set, setIndex) => {
        set.songs.forEach((song, songIndex) => {
          allSongs.push({
            ...song,
            setIndex,
            setName: set.setlist_name || `Set ${setIndex + 1}`,
            setPosition: set.position,
            songIndex
          });
        });
      });

      // Nur beim initialen Load zum ersten nicht-markierten Song springen
      if (!skipAutoJump) {
        // Finde den ersten Song, der noch nicht markiert wurde (weder übersprungen noch Feedback)
        // oder starte am Ende wenn alle markiert sind
        let startIndex = 0;
        for (let i = 0; i < allSongs.length; i++) {
          const song = allSongs[i];
          const isMarked = song.uebersprungen || song.feedback !== null && song.feedback !== undefined;
          if (!isMarked) {
            startIndex = i;
            break;
          }
          // Wenn alle Songs markiert sind, setze auf das Ende
          if (i === allSongs.length - 1) {
            startIndex = allSongs.length; // Index außerhalb = "Fertig"
          }
        }
        currentIndex = startIndex;
      }

      loading = false;
    } catch (e) {
      showError(e.message ?? 'Fehler beim Laden des Live-Modus');
      loading = false;
    }
  }

  function goNext() {
    if (!isLastSong) {
      currentIndex++;
    }
  }

  function goPrevious() {
    if (!isFirstSong) {
      currentIndex--;
    }
  }

  // Keyboard Navigation
  function handleKeydown(e) {
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault();
      goNext();
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault();
      goPrevious();
   } else if (e.key === '1') {
      setFeedback(1);
    } else if (e.key === '2') {
      setFeedback(2);
    } else if (e.key === '3') {
      setFeedback(3);
    } else if (e.key === 'Escape') {
      if (showSetlistOverview) {
        showSetlistOverview = false;
      } else if (showHelp) {
        showHelp = false;
      } else {
        parent.onClose();
      }
    } else if (e.key === '?') {
      showHelp = !showHelp;
    } else if (e.key === 'l' || e.key === 'L') {
      showSetlistOverview = !showSetlistOverview;
    }
  }

  // Touch/Swipe handling
  function handleTouchStart(e) {
    // Verhindere Swipe wenn Benutzer in Input-Feld oder auf Button interagiert
    const target = e.target;
    if (target.tagName === 'INPUT' || target.tagName === 'BUTTON' || target.closest('.no-swipe') || target.closest('button')) {
      isSwiping = false;
      return;
    }

    touchStartX = e.changedTouches[0].screenX;
    touchStartY = e.changedTouches[0].screenY;
    isSwiping = true;
  }

  function handleTouchMove(e) {
    if (!isSwiping) return;

    // Zusätzliche Sicherheit: Wenn Touch auf Button/Input/no-swipe, breche ab
    const target = e.target;
    if (target.tagName === 'INPUT' || target.tagName === 'BUTTON' || target.closest('.no-swipe') || target.closest('button')) {
      isSwiping = false;
      return;
    }

    touchEndX = e.changedTouches[0].screenX;

    // Prüfe ob die horizontale Bewegung größer ist als die vertikale (echtes Swipen, nicht Scrollen)
    const deltaX = Math.abs(touchEndX - touchStartX);
    const deltaY = Math.abs(e.changedTouches[0].screenY - touchStartY);

    // Wenn vertikale Bewegung überwiegt, ist das wahrscheinlich Scrollen
    if (deltaY > deltaX) {
      isSwiping = false;
      return;
    }
  }

  function handleTouchEnd() {
    if (!isSwiping) return;
    isSwiping = false;

    const swipeThreshold = 50; // Mindestabstand in Pixeln
    const diff = touchStartX - touchEndX;

    if (Math.abs(diff) > swipeThreshold) {
      if (diff > 0) {
        // Nach links gewischt -> nächster Song
        goNext();
      } else {
        // Nach rechts gewischt -> vorheriger Song
        goPrevious();
      }
    }

    touchStartX = 0;
    touchStartY = 0;
    touchEndX = 0;
  }

  async function jumpToSong(targetIndex) {
    if (targetIndex === currentIndex) return;

    // Rückwärts-Sprung: einfach wechseln, nichts markieren
    if (targetIndex < currentIndex) {
      currentIndex = targetIndex;
      return;
    }

    // Vorwärts-Sprung: alle Songs von currentIndex bis targetIndex-1 als übersprungen markieren
    const songsToSkip = allSongs.slice(currentIndex, targetIndex).filter(
      s => !s.uebersprungen && s.feedback === null || s.feedback === undefined
    );

    try {
      await Promise.all(songsToSkip.map(song =>
        updateSongLiveMode(null, gigId, {
          id: song.id,
          uebersprungen: true,
          feedback: null
        })
      ));

      // Lokale Daten aktualisieren
      for (let i = currentIndex; i < targetIndex; i++) {
        if (!allSongs[i].uebersprungen) {
          allSongs[i].uebersprungen = true;
          allSongs[i].feedback = null;
        }
      }
      allSongs = [...allSongs];
    } catch (e) {
      showError(e.message ?? 'Fehler beim Markieren der übersprungenen Songs');
    }

    currentIndex = targetIndex;
  }

  async function toggleUebersprungen() {
    if (!currentSong) return;

    try {
      const newUebersprungen = !currentSong.uebersprungen;

      const updated = await updateSongLiveMode(null, gigId, {
        id: currentSong.id,
        uebersprungen: newUebersprungen,
        feedback: newUebersprungen ? null : currentSong.feedback
      });

      // Aktualisiere lokale Daten
      allSongs[currentIndex].uebersprungen = newUebersprungen;
      if (newUebersprungen) {
        allSongs[currentIndex].feedback = null;
      }
      allSongs = [...allSongs]; // Trigger reactivity

      if (newUebersprungen == true) {
        // Wenn das der letzte Song ist, zur Success-Karte wechseln
        if (isLastSong) {
          currentIndex = allSongs.length; // Index außerhalb = "Fertig"
        } else {
          goNext();
        }
      }

    } catch (e) {
      showError(e.message ?? 'Update fehlgeschlagen');
    }
  }



  async function setFeedback(rating) {
    if (!currentSong) return;

    try {
      const wasFeedbackSet = currentSong.feedback === rating;
      const newFeedback = wasFeedbackSet ? null : rating;

      const updated = await updateSongLiveMode(null, gigId, {
        id: currentSong.id,
        feedback: newFeedback
      });

      allSongs[currentIndex].feedback = newFeedback;
      allSongs = [...allSongs];

      // Automatisch zum nächsten Song wechseln, wenn Feedback gegeben wurde (nicht beim Entfernen)
      if (!wasFeedbackSet && newFeedback !== null) {
        setTimeout(() => {
          // Wenn das der letzte Song ist, zur Success-Karte wechseln
          if (isLastSong) {
            currentIndex = allSongs.length; // Index außerhalb = "Fertig"
          } else {
            goNext();
          }
        }, 300); // Kurze Verzögerung für visuelles Feedback
      }

    } catch (e) {
      showError(e.message ?? 'Update fehlgeschlagen');
    }
  }

  async function insertSong(songToInsert) {
    if (!songToInsert || !currentSong) return;

    try {
      const newSetSong = await insertSongBefore(null, gigId, currentSong.id, songToInsert.id);

      showSuccess(`"${songToInsert.title}" wurde vor dem aktuellen Song eingefügt`);

      // Reload Gig-Daten OHNE Auto-Jump
      await loadGigData(true);

      // Finde den neu eingefügten Song in der allSongs Liste
      // Er sollte die zurückgegebene ID haben
      const newIndex = allSongs.findIndex(s => s.id === newSetSong.id);
      if (newIndex !== -1) {
        currentIndex = newIndex;
      }

      // Zurücksetzen
      searchTerm = '';
      showInsertSection = false;

    } catch (e) {
      showError(e.message ?? 'Fehler beim Einfügen des Songs');
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

<div
  class="card p-0 w-[95vw] h-[95vh] flex flex-col bg-surface-100 dark:bg-surface-800 relative overflow-hidden shadow-2xl"
  ontouchstart={handleTouchStart}
  ontouchmove={handleTouchMove}
  ontouchend={handleTouchEnd}
>
  <!-- Header -->
  <header class="flex justify-between items-center p-3 md:p-4 border-b border-surface-300 dark:border-surface-700 bg-surface-200/50 dark:bg-surface-900/30 no-swipe">
    <div class="flex items-center gap-2">
      <span class="text-xl md:text-2xl">⚡</span>
      <div>
        <h2 class="h4 md:h3 font-bold text-primary-500">Live Mode</h2>
        {#if gig}
          <p class="text-[10px] md:text-xs text-surface-600 dark:text-surface-400 font-medium">
            {gig.name}
          </p>
        {/if}
      </div>
    </div>
    <div class="flex items-center gap-2">
      <button
        class="btn btn-sm variant-ghost flex items-center gap-1"
        onclick={() => showHelp = !showHelp}
        aria-label="Hilfe anzeigen"
        title="Hilfe (?)"
      >
        <svg class="w-4 h-4 md:w-5 md:h-5 text-surface-600 dark:text-surface-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <span class="hidden md:inline text-xs">Hilfe</span>
      </button>
      <button
        class="btn btn-sm variant-ghost {showSetlistOverview ? 'variant-filled-secondary text-white' : ''} flex items-center gap-1"
        onclick={() => showSetlistOverview = !showSetlistOverview}
        aria-label="Setlisten-Übersicht anzeigen"
        title="Setlisten-Übersicht (L)"
      >
        <svg class="w-4 h-4 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
        </svg>
        <span class="hidden md:inline text-xs">Ablauf</span>
      </button>
      <button
        class="btn-icon btn-icon-sm variant-ghost-error hover:variant-filled-error transition-all"
        onclick={() => parent?.close()}
        aria-label="Schließen"
      >
        ✕
      </button>
    </div>
  </header>

  {#if allSongs.length > 0 && !isFinished}
    <div class="px-3 md:px-6 pt-2 md:pt-4 pb-2">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-2 md:gap-4">
        <!-- Set-Fortschritt -->
        {#if currentSong}
          {@const currentSet = gig.sets.find(s => s.position === currentSong.setPosition)}
          {@const setProgress = currentSet ? ((currentSong.songIndex + 1) / currentSet.songs.length) * 100 : 0}
          <div class="card p-2 bg-surface-50 dark:bg-surface-900/50 border border-surface-200/60 dark:border-surface-700/40">
            <div class="flex justify-between items-center mb-0.5">
              <span class="text-[10px] md:text-xs font-semibold text-surface-600 dark:text-surface-400">
                📁 {currentSong.setName}
              </span>
              <span class="text-[10px] md:text-xs font-mono text-surface-500">
                Song {currentSong.songIndex + 1} / {currentSet?.songs.length || 0}
              </span>
            </div>
            <div class="w-full bg-surface-200 dark:bg-surface-800 rounded-full h-1.5 overflow-hidden">
              <div
                class="bg-secondary-500 h-1.5 rounded-full transition-all duration-300"
                style="width: {setProgress}%"
              ></div>
            </div>
          </div>
        {/if}

        <!-- Gesamtfortschritt -->
        <div class="card p-2 bg-surface-50 dark:bg-surface-900/50 border border-surface-200/60 dark:border-surface-700/40">
          <div class="flex justify-between items-center mb-0.5">
            <span class="text-[10px] md:text-xs font-semibold text-surface-600 dark:text-surface-400">
              📊 Gesamtfortschritt
            </span>
            <span class="text-[10px] md:text-xs font-mono text-surface-500">
              Song {currentIndex + 1} / {allSongs.length}
            </span>
          </div>
          <div class="w-full bg-surface-300 dark:bg-surface-700 rounded-full h-1.5 overflow-hidden">
            <div
              class="bg-primary-500 h-1.5 rounded-full transition-all duration-300"
              style="width: {progress}%"
            ></div>
          </div>
        </div>
      </div>
    </div>
  {:else if isFinished}
    <div class="px-3 md:px-6 pt-3 pb-2">
      <div class="card p-3 variant-soft-success flex items-center justify-between border border-success-500/20 shadow-sm animate-pulse">
        <span class="text-xs md:text-sm text-success-700 dark:text-success-300 font-bold flex items-center gap-1.5">
          🎉 Alle Songs erfolgreich abgeschlossen!
        </span>
        <div class="w-32 bg-success-200 dark:bg-success-900/60 rounded-full h-2 overflow-hidden">
          <div class="bg-success-500 h-2 rounded-full" style="width: 100%"></div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Help Section (Schwebt als Overlay, um das Layout nicht zu verzerren) -->
  {#if showHelp}
    <div class="absolute inset-0 bg-surface-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="card variant-filled-surface max-w-lg w-full p-4 md:p-6 shadow-2xl border border-surface-500 relative max-h-[85vh] overflow-y-auto">
        <button
          class="absolute top-3 right-3 btn-icon btn-icon-sm variant-ghost-surface hover:variant-filled"
          onclick={() => showHelp = false}
          aria-label="Hilfe schließen"
        >
          ✕
        </button>
        <h4 class="h3 font-bold mb-4 flex items-center gap-2 text-primary-500">
          <span>🎸</span>
          Live-Mode Anleitung
        </h4>

        <div class="space-y-4">
          <div class="card p-3 variant-soft-surface">
            <h5 class="font-semibold text-primary-500 mb-1.5 text-sm">🎯 Hauptfunktionen</h5>
            <ul class="list-disc list-inside space-y-1 text-xs">
              <li><strong>Navigation:</strong> Pfeiltasten ←→ oder Buttons nutzen (Mobile: Wischen)</li>
              <li><strong>Bewertung:</strong> 😊 = Super, 😐 = OK, 😞 = Schwach</li>
              <li><strong>Überspringen:</strong> Song wurde nicht gespielt</li>
              <li><strong>Song einfügen:</strong> Füge spontan Songs in die Setliste ein</li>
            </ul>
          </div>

          <div class="card p-3 variant-soft-secondary">
            <h5 class="font-semibold text-secondary-500 mb-1.5 text-sm">⌨️ Shortcuts</h5>
            <div class="grid grid-cols-2 gap-2 text-xs">
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">←</kbd> Vorheriger Song</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">→</kbd> Nächster Song</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">1</kbd> Bewertung: 😊</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">2</kbd> Bewertung: 😐</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">3</kbd> Bewertung: 😞</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">Escape</kbd> Schließen</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">?</kbd> Hilfe ein/aus</div>
              <div class="flex items-center gap-1.5"><kbd class="kbd kbd-sm">L</kbd> Setlisten-Liste</div>
            </div>
          </div>

          <div class="alert variant-soft-success py-2.5">
            <p class="text-xs">💡 <strong>Tipp:</strong> Alle Änderungen werden sofort gespeichert und sind in der Setliste sichtbar!</p>
          </div>
        </div>
        <div class="mt-4 flex justify-end">
          <button class="btn variant-filled-primary btn-sm font-semibold" onclick={() => showHelp = false}>Verstanden</button>
        </div>
      </div>
    </div>
  {/if}

  <!-- Content -->
  <div class="flex-1 overflow-y-auto p-2 md:p-4 h-full flex flex-col justify-between">
    {#if loading}
      <div class="flex justify-center items-center h-full my-auto">
        <div class="text-center">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p class="text-surface-600 dark:text-surface-400 font-medium">Lade Live-Daten...</p>
        </div>
      </div>
    {:else if allSongs.length === 0}
      <div class="text-center py-12 my-auto">
        <div class="text-4xl mb-2">📁</div>
        <p class="text-surface-600 dark:text-surface-400 font-semibold">Keine Songs in der Setliste gefunden</p>
      </div>
    {:else if isFinished}
      <!-- Fertig-Ansicht -->
      <div class="flex justify-center items-center h-full my-auto">
        <div class="text-center max-w-md p-6 card variant-soft-surface shadow-lg border border-surface-200 dark:border-surface-700">
          <div class="text-6xl md:text-8xl mb-6">🎉</div>
          <h3 class="h2 md:h1 mb-4 text-primary-500 font-bold">Fertig!</h3>
          <p class="text-base md:text-lg text-surface-600 dark:text-surface-300 mb-6">
            Alle Songs wurden markiert. Gute Arbeit, Band!
          </p>
          <div class="flex flex-col sm:flex-row justify-center gap-3 no-swipe">
            <button
              class="btn variant-filled-primary font-semibold flex items-center justify-center gap-1"
              onclick={() => currentIndex = 0}
            >
              🔄 Zurück zum Anfang
            </button>
            <button
              class="btn variant-filled-surface font-semibold"
              onclick={parent.onClose}
            >
              Schließen
            </button>
          </div>
        </div>
      </div>
    {:else if currentSong}
      <!-- Song Card mit Navigation -->
      <div class="flex items-stretch gap-1 md:gap-4 h-full flex-1">
        <!-- Previous Button -->
        <button
          class="btn variant-ghost-primary hover:variant-filled-primary flex flex-shrink-0 w-8 md:w-16 items-center justify-center transition-all no-swipe"
          onclick={goPrevious}
          disabled={isFirstSong}
          aria-label="Vorheriger Song"
          title="Vorheriger Song (Links/Oben)"
        >
          <svg class="w-6 h-6 md:w-8 md:h-8" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        </button>

        <!-- Song Content -->
        <div class="flex-1 min-w-0 relative flex flex-col justify-center py-2">
          <!-- Timeline-Linie (nur Desktop) -->
          <div class="hidden md:block absolute left-4 top-0 bottom-0 w-0.5 bg-gradient-to-b from-surface-300/35 via-primary-500/80 to-surface-300/35 dark:from-surface-700/35 dark:via-primary-400/80 dark:to-surface-700/35"></div>

          <!-- Vorheriger Song (Vorschau - Jetzt Anklickbar!) -->
          {#if previousSong}
            <button
              class="w-full text-left mb-3 group transition-transform hover:-translate-y-0.5 no-swipe"
              onclick={goPrevious}
              title="Zum vorherigen Song wechseln"
            >
              <div class="card variant-ghost-surface p-2.5 border border-surface-250/20 hover:border-surface-400 dark:hover:border-surface-600 transition-all relative">
                <!-- Timeline-Punkt -->
                <div class="hidden md:block absolute left-3.5 top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full bg-surface-400 dark:bg-surface-500 border border-surface-50 dark:border-surface-900 group-hover:bg-primary-500 transition-colors"></div>

                <div class="flex items-center gap-2 md:gap-3 md:ml-6">
                  <div class="text-surface-400 dark:text-surface-500 text-[10px] font-bold flex-shrink-0 hidden md:block">
                    ◀ VORHER
                  </div>
                  <div class="flex-1 min-w-0 opacity-60 group-hover:opacity-100 transition-opacity">
                    <div class="font-semibold text-xs md:text-sm truncate">
                      <span class="md:hidden text-surface-400 mr-1">↑</span>{previousSong.title}
                    </div>
                    <div class="text-[10px] md:text-xs text-surface-550 dark:text-surface-400 truncate hidden md:block">{previousSong.interpret}</div>
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    {#if previousSong.uebersprungen}
                      <span class="badge variant-soft-warning text-xs">⏭️</span>
                    {:else if previousSong.feedback}
                      <span class="text-sm md:text-base">
                        {previousSong.feedback === 1 ? '😐' : previousSong.feedback === 2 ? '😐' : '😍'}
                      </span>
                    {/if}
                  </div>
                </div>
              </div>
            </button>
          {/if}

          <!-- Aktueller Song (Hauptkarte) -->
          <div class="card variant-ghost p-3 md:p-5 gradient-bg dark:from-primary-950/40 dark:to-surface-900 ring-2 ring-primary-500 shadow-2xl relative flex flex-col justify-between border border-primary-500/20 rounded-2xl flex-1">
            <!-- Timeline-Punkt (größer) -->
            <div class="hidden md:block absolute left-2.5 top-1/2 -translate-y-1/2 w-4.5 h-4.5 rounded-full bg-primary-500 border-4 border-surface-50 dark:border-surface-900 shadow-md animate-pulse"></div>

            <!-- Song Info - Titel im Vordergrund -->
            <div class="text-center my-auto py-2">
              <h3 class="song-title mb-1.5 md:mb-3 break-words leading-tight tracking-tight text-surface-900 dark:text-white drop-shadow-sm">{currentSong.title}</h3>
              <div class="flex flex-wrap items-center justify-center gap-1.5 md:gap-2 text-xs md:text-sm text-surface-600 dark:text-surface-400">
                <span class="font-medium bg-surface-200/50 dark:bg-surface-800/60 px-2 md:px-2.5 py-0.5 md:py-1 rounded-full">{currentSong.interpret}</span>
                {#if currentSong.tone_key}
                  <span class="font-mono font-bold text-xs md:text-sm bg-primary-500/10 dark:bg-primary-500/25 text-primary-600 dark:text-primary-300 border border-primary-500/20 px-2 md:px-2.5 py-0.5 md:py-1 rounded-full shadow-sm">{currentSong.tone_key}</span>
                {/if}
                {#if currentSong.eingeschoben}
                  <span class="badge variant-soft-success text-xs flex items-center gap-0.5 px-2 py-0.5 md:py-1">➕ Eingeschoben</span>
                {/if}
              </div>
            </div>

            <!-- Kommentar-Sektion (Nur anzeigen, wenn vorhanden!) -->
            {#if currentSong.comment}
              <div class="alert variant-soft-warning mb-2 md:mb-3 p-2 md:p-2.5 rounded-xl flex items-start gap-2 border border-warning-500/20 shadow-sm">
                <span class="text-xs md:text-sm font-bold flex-shrink-0">⚠️ Notiz:</span>
                <p class="font-semibold text-[11px] md:text-xs text-warning-800 dark:text-warning-300 text-left leading-snug">
                  {currentSong.comment}
                </p>
              </div>
            {/if}

            <!-- Interaktions-Buttons in einer Zeile -->
            <div class="flex flex-wrap items-center justify-center gap-2 md:gap-3 my-1.5 md:my-3 no-swipe bg-surface-200/20 dark:bg-surface-900/40 p-1.5 md:p-2.5 rounded-xl border border-surface-200/50 dark:border-surface-700/30 w-full">
              <!-- Überspringen Button -->
              <button
                class="btn btn-md md:btn-lg py-2.5 md:py-4 px-3.5 md:px-6 text-sm md:text-lg font-bold transition-all rounded-xl {currentSong.uebersprungen ? 'variant-filled-warning scale-102 shadow-md' : 'variant-soft-surface hover:variant-soft-warning'}"
                onclick={toggleUebersprungen}
              >
                {currentSong.uebersprungen ? '⏭️ Übersprungen' : '⏭️ Überspringen'}
              </button>

              <!-- Feedback Buttons - nur wenn nicht übersprungen -->
              {#if !currentSong.uebersprungen}
                <div class="flex items-center gap-1.5 border-l border-surface-300 dark:border-surface-700 pl-2 md:pl-3">
                  <span class="text-xs font-semibold text-surface-600 dark:text-surface-400 hidden sm:inline">Bewertung:</span>
                  {#each [
                    { rating: 1, text: '😐 OK', activeClass: 'variant-filled-warning ring-2 ring-warning-500/40 text-black', defaultClass: 'variant-soft-warning hover:bg-warning-500/10' },
                    { rating: 2, text: '🙂 Gut', activeClass: 'variant-filled-success text-white ring-2 ring-success-500/40', defaultClass: 'variant-soft-success hover:bg-success-500/10' },
                    { rating: 3, text: '😍 Super', activeClass: 'variant-filled-error text-white ring-2 ring-error-500/40', defaultClass: 'variant-soft-error hover:bg-error-500/10' }
                  ] as { rating, text, activeClass, defaultClass }}
                    <button
                      class="btn btn-md md:btn-lg py-2.5 md:py-4 px-3.5 md:px-6 text-sm md:text-lg font-bold transition-all rounded-xl {currentSong.feedback === rating ? activeClass : defaultClass}"
                      onclick={() => setFeedback(rating)}
                      aria-label="Bewertung {text}"
                    >
                      {text}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Song einfügen Trigger-Button -->
            <div class="border-t border-surface-300 dark:border-surface-700/60 pt-2 mt-2 no-swipe">
              <button
                class="btn btn-xs md:btn-sm variant-soft-secondary w-full flex items-center justify-center gap-1.5 font-semibold py-1 md:py-1.5"
                onclick={() => showInsertSection = true}
              >
                <span>➕ Song einfügen</span>
              </button>
            </div>

            <!-- Mobile Navigation Hint -->
            <div class="md:hidden text-center mt-2 text-[10px] font-medium text-surface-500">
              👈 Wische für Navigation 👉
            </div>
          </div>

          <!-- Nächster Song (Vorschau) -->
          {#if nextSong}
            <button
              class="w-full text-left mt-3 group transition-transform hover:translate-y-0.5 no-swipe"
              onclick={goNext}
              title="Zum nächsten Song wechseln"
            >
              <div class="card variant-ghost-surface p-2.5 border border-surface-250/20 hover:border-surface-400 dark:hover:border-surface-600 transition-all relative">
                <!-- Timeline-Punkt -->
                <div class="hidden md:block absolute left-3.5 top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full bg-surface-400 dark:bg-surface-500 border border-surface-50 dark:border-surface-900 group-hover:bg-primary-500 transition-colors"></div>

                <div class="md:ml-6 flex items-center justify-between">
                  <div class="flex items-center gap-2 md:gap-3 flex-1 min-w-0 font-normal">
                    <div class="text-surface-400 dark:text-surface-500 text-[10px] font-bold flex-shrink-0 hidden md:block">
                      ▶ NÄSTES
                    </div>
                    <div class="flex-1 min-w-0 opacity-60 group-hover:opacity-100 transition-opacity">
                      <div class="font-semibold text-xs md:text-sm truncate">
                        <span class="md:hidden text-surface-400 mr-1">↓</span>{nextSong.title}
                      </div>
                      <div class="text-[10px] md:text-xs text-surface-550 dark:text-surface-400 truncate hidden md:block">{nextSong.interpret}</div>
                    </div>
                    {#if nextSong.comment}
                      <div class="hidden lg:block text-[11px] text-warning-600 dark:text-warning-400 italic truncate opacity-70 group-hover:opacity-100 transition-opacity">
                        💡 {nextSong.comment}
                      </div>
                    {/if}
                  </div>
                </div>
              </div>
            </button>
          {/if}
        </div>

        <!-- Next Button -->
        <button
          class="btn variant-ghost-primary hover:variant-filled-primary flex flex-shrink-0 w-8 md:w-16 items-center justify-center transition-all no-swipe"
          onclick={goNext}
          disabled={isLastSong}
          aria-label="Nächster Song"
          title="Nächster Song (Rechts/Unten)"
        >
          <svg class="w-6 h-6 md:w-8 md:h-8" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    {/if}
  </div>

  <!-- Footer mit Keyboard Shortcuts -->
  <footer class="hidden md:block border-t border-surface-300 dark:border-surface-700 p-2.5 bg-surface-50 dark:bg-surface-900/60 no-swipe">
    <div class="flex justify-center gap-6 text-[11px] text-surface-600 dark:text-surface-400 font-medium">
      <span>← / → Navigation</span>
      <span><kbd class="kbd kbd-sm">?</kbd> Hilfe</span>
      <span><kbd class="kbd kbd-sm">L</kbd> Liste</span>
      <span><kbd class="kbd kbd-sm">ESC</kbd> Schließen</span>
    </div>
  </footer>

  <!-- Song einfügen Overlay (Schwebt als Modal über der Hauptansicht) -->
  {#if showInsertSection}
    <div class="absolute inset-0 bg-surface-900/60 backdrop-blur-sm z-40 flex items-center justify-center p-4">
      <div class="card variant-filled-surface max-w-md w-full p-4 md:p-5 shadow-2xl border border-surface-500 relative max-h-[85vh] flex flex-col no-swipe">
        <button
          class="absolute top-3 right-3 btn-icon btn-icon-sm variant-ghost-surface hover:variant-filled"
          onclick={() => { showInsertSection = false; searchTerm = ''; }}
          aria-label="Schließen"
        >
          ✕
        </button>
        <h4 class="h3 font-bold mb-3 flex items-center gap-1.5 text-secondary-500">
          <span>➕</span>
          Song einfügen
        </h4>

        <div class="space-y-3 flex-1 flex flex-col min-h-0">
          <div class="space-y-1">
            <span class="text-xs font-semibold text-surface-400">Song aus Repertoire suchen</span>
            <div class="input-group input-group-sm flex items-center bg-surface-250 dark:bg-surface-800 rounded-lg p-1.5 border border-surface-300 dark:border-surface-700">
              <span class="px-1 text-surface-500 text-xs">🔍</span>
              <input
                type="text"
                class="bg-transparent border-0 ring-0 focus:ring-0 w-full text-xs outline-none px-1 text-white"
                placeholder="Titel oder Interpret eingeben..."
                bind:value={searchTerm}
              />
            </div>
          </div>

          {#if searchTerm.length > 0}
            <div class="overflow-y-auto space-y-1 pr-1 scrollbar-thin flex-1 min-h-0">
              {#each filteredSongs as song}
                <button
                  class="w-full text-left p-2 rounded-lg transition-all border bg-surface-100 dark:bg-surface-800 hover:bg-surface-200 dark:hover:bg-surface-700 border-transparent text-white"
                  onclick={() => insertSong(song)}
                >
                  <div class="font-bold text-xs md:text-sm">{song.title}</div>
                  <div class="text-[10px] md:text-xs opacity-80">{song.interpret}</div>
                </button>
              {:else}
                <p class="text-xs text-surface-400 p-2 text-center italic">
                  Keine Songs gefunden
                </p>
              {/each}
            </div>
          {/if}

        </div>
      </div>
    </div>
  {/if}

  <!-- Setlisten-Übersicht Slide-In-Panel -->
  <SetlistOverviewPanel
    {allSongs}
    {currentIndex}
    open={showSetlistOverview}
    onJump={(index) => jumpToSong(index)}
    onClose={() => { showSetlistOverview = false; }}
  />
</div>

<style>
  /* Verhindere Text-Selektion während Swipe */
  .card {
    user-select: none;
    -webkit-user-select: none;
  }

  /* Smooth transitions */
  .card {
    transition: transform 0.3s ease-out;
  }

  /* Erlaube normale Touch-Interaktion in no-swipe Bereichen */
  .no-swipe {
    user-select: auto;
    -webkit-user-select: auto;
    touch-action: auto;
  }

  .no-swipe input,
  .no-swipe button {
    user-select: auto;
    -webkit-user-select: auto;
  }

  .song-title {
    font-size: clamp(1.2rem, 3vw, 3.75rem);
    font-weight: bold;
    line-height: 1.2;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    text-overflow: ellipsis;
    word-wrap: break-word;
    hyphens: auto;
  }

  @media (min-width: 768px) {
    .song-title {
      font-size: clamp(2rem, 5vw, 4rem);
    }
  }
</style>

