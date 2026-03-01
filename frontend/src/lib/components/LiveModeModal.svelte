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
  import { getModalStore } from '@skeletonlabs/skeleton';
  import { onMount, onDestroy } from 'svelte';
	import { getGigLiveMode, updateSongLiveMode, insertSongAfter, getSongs } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { getToastStore } from '@skeletonlabs/skeleton';

  const modalStore = getModalStore();
  const { showError, showSuccess } = createMessageHelpers(getToastStore());

  export let parent;

  const { gigId } = $modalStore[0].meta;

  let gig = null;
  let allSongs = [];
  let currentIndex = 0;
  let loading = true;
  let showHelp = false;

  // Song einfügen
  let availableSongs = [];
  let searchTerm = '';
  let selectedSongToInsert = null;
  let showInsertSection = false;

  // Touch/Swipe handling
  let touchStartX = 0;
  let touchStartY = 0;
  let touchEndX = 0;
  let isSwiping = false;

  $: currentSong = allSongs[currentIndex];
  $: previousSong = currentIndex > 0 ? allSongs[currentIndex - 1] : null;
  $: nextSong = currentIndex < allSongs.length - 1 ? allSongs[currentIndex + 1] : null;
  $: isFirstSong = currentIndex === 0;
  $: isLastSong = currentIndex === allSongs.length - 1;
  $: isFinished = currentIndex >= allSongs.length;
  $: progress = allSongs.length > 0 ? ((currentIndex + 1) / allSongs.length) * 100 : 0;
  $: filteredSongs = availableSongs.filter(song =>
    searchTerm === '' ||
    song.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    song.interpret.toLowerCase().includes(searchTerm.toLowerCase())
  ).slice(0, 10); // Maximal 10 Ergebnisse

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
      setFeedback(3);1
    } else if (e.key === 'Escape') {
      parent.onClose();
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

  async function insertSong() {
    if (!selectedSongToInsert || !currentSong) return;

    try {
      const currentSetSongId = currentSong.id; // Merke die aktuelle SetSong ID

      const newSetSong = await insertSongAfter(null, gigId, currentSong.id, selectedSongToInsert.id);

      showSuccess(`"${selectedSongToInsert.title}" wurde nach dem aktuellen Song eingefügt`);

      // Reload Gig-Daten OHNE Auto-Jump
      await loadGigData(true);

      // Finde den neu eingefügten Song in der allSongs Liste
      // Er sollte die zurückgegebene ID haben
      const newIndex = allSongs.findIndex(s => s.id === newSetSong.id);
      if (newIndex !== -1) {
        currentIndex = newIndex;
      } else {
        // Fallback: Finde den ursprünglichen Song und gehe eins weiter
        const originalIndex = allSongs.findIndex(s => s.id === currentSetSongId);
        if (originalIndex !== -1 && originalIndex < allSongs.length - 1) {
          currentIndex = originalIndex + 1;
        }
      }

      // Zurücksetzen
      searchTerm = '';
      selectedSongToInsert = null;
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
  class="card p-0 w-full max-w-5xl h-[95vh] flex flex-col bg-surface-100 dark:bg-surface-800"
  on:touchstart={handleTouchStart}
  on:touchmove={handleTouchMove}
  on:touchend={handleTouchEnd}
>
  <!-- Header -->
  <header class="flex justify-between items-center p-3 md:p-4 border-b border-surface-300 no-swipe">
    <div class="flex">
      <h2 class="h4 md:h3">🎵 Live Mode</h2>
      {#if gig}
        <p class="text-xs md:text-sm text-surface-600 dark:text-surface-400">
          {gig.name}
        </p>
      {/if}
    </div>
    <div class="flex items-center gap-2">
      <button
        class="btn-icon btn-icon-sm variant-ghost"
        on:click={() => showHelp = !showHelp}
        aria-label="Hilfe anzeigen"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
      </button>
      <button
        class="btn-icon btn-icon-sm variant-ghost"
        on:click={parent.onClose}
        aria-label="Schließen"
      >
        ✕
      </button>
    </div>
  </header>



  {#if allSongs.length > 0 && !isFinished}
    <div class="px-3 md:px-6 pt-2 md:pt-4 pb-2 space-y-2">
      <!-- Set-Fortschritt -->
       {#if currentSong}
            {@const currentSet = gig.sets.find(s => s.position === currentSong.setPosition)}
            {@const setProgress = currentSet ? ((currentSong.songIndex + 1) / currentSet.songs.length) * 100 : 0}
            <div>
              <div class="flex justify-between items-center mb-0.5">
                <span class="text-xs font-medium text-surface-600 dark:text-surface-400">
                  {currentSong.setName}
                </span>
                <span class="text-xs text-surface-500 dark:text-surface-500">
                  Song {currentSong.songIndex + 1} / {currentSet?.songs.length || 0}
                </span>
              </div>
              <div class="w-full bg-surface-200 dark:bg-surface-800 rounded-full h-1.5">
                <div
                  class="bg-secondary-500 h-1.5 rounded-full transition-all duration-300"
                  style="width: {setProgress}%"
                ></div>
              </div></div>
       {/if}

      <!-- Gesamtfortschritt -->
      <div>
        <div class="flex justify-between items-center mb-0.5">
          <span class="text-xs font-medium text-surface-600 dark:text-surface-400">
            Gesamtfortschritt
          </span>
          <span class="text-xs text-surface-500 dark:text-surface-500">
            Song {currentIndex + 1} / {allSongs.length}
          </span>
        </div>
        <div class="w-full bg-surface-300 dark:bg-surface-700 rounded-full h-1">
          <div
            class="bg-primary-500 h-1.5 rounded-full transition-all duration-300"
            style="width: {progress}%"
          ></div>
        </div>
      </div>
    </div>
  {:else if isFinished}
    <div class="px-3 md:px-6 pt-2 md:pt-4 pb-2">
      <div class="flex justify-between items-center mb-1">
        <span class="text-xs text-success-600 dark:text-success-400 font-semibold">
          ✅ Alle Songs abgeschlossen
        </span>
      </div>
      <div class="w-full bg-surface-300 dark:bg-surface-700 rounded-full h-1 md:h-2">
        <div class="bg-success-500 h-1.5 md:h-2 rounded-full" style="width: 100%"></div>
      </div>
    </div>
  {/if}

<!-- Help Section -->
{#if showHelp}
  <div class="px-3 md:px-6 pt-2">
    <div class="card variant-ghost-surface p-3 md:p-4 text-sm">
      <h4 class="font-bold mb-3 flex items-center gap-2">
        <span class="text-lg">🎸</span>
        Live-Mode Anleitung
      </h4>

      <div class="space-y-2">
        <div>
          <h5 class="font-semibold text-primary-500 mb-1">🎯 Hauptfunktionen</h5>
          <ul class="list-disc list-inside space-y-1 text-xs">
            <li><strong>Navigation:</strong> Pfeiltasten ←→ oder Buttons nutzen (Mobile: Wischen)</li>
            <li><strong>Bewertung:</strong> 😊 = Super, 😐 = OK, 😞 = Schwach</li>
            <li><strong>Überspringen:</strong> Song wurde nicht gespielt</li>
            <li><strong>Song einfügen:</strong> Füge spontan Songs in die Setliste ein</li>
          </ul>
        </div>

        <div>
          <h5 class="font-semibold text-secondary-500 mb-1">⌨️ Shortcuts</h5>
          <div class="grid grid-cols-1 gap-1 text-xs">
            <div><kbd class="kbd kbd-sm">←</kbd> Vorheriger Song</div>
            <div><kbd class="kbd kbd-sm">→</kbd> Nächster Song</div>
            <div><kbd class="kbd kbd-sm">1</kbd> Bewertung: 😊</div>
            <div><kbd class="kbd kbd-sm">2</kbd> Bewertung: 😐</div>
            <div><kbd class="kbd kbd-sm">3</kbd> Bewertung: 😞</div>
            <div><kbd class="kbd kbd-sm">Leertaste</kbd> Überspringen</div>
          </div>
        </div>

        <div class="alert variant-soft-primary py-2">
            <p class="text-xs">💡 <strong>Tipp:</strong> Alle Änderungen werden sofort gespeichert und sind in der Setliste sichtbar!</p>
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Content -->
  <div class="flex-1 overflow-y-auto p-2 md:p-4 h-full">
    {#if loading}
      <div class="flex justify-center items-center h-full">
        <div class="text-center">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p class="text-surface-600 dark:text-surface-400">Lade Live-Daten...</p>
        </div>
      </div>
    {:else if allSongs.length === 0}
      <div class="text-center py-12">
        <p class="text-surface-600 dark:text-surface-400">Keine Songs in der Setliste gefunden</p>
      </div>
    {:else if isFinished}
      <!-- Fertig-Ansicht -->
      <div class="flex justify-center items-center h-full">
        <div class="text-center">
          <div class="text-6xl md:text-8xl mb-6">🎉</div>
          <h3 class="h2 md:h1 mb-4 text-primary-500">Fertig!</h3>
          <p class="text-lg md:text-xl text-surface-600 dark:text-surface-400 mb-6">
            Alle Songs wurden markiert.
          </p>
          <div class="flex flex-wrap justify-center gap-3 no-swipe">
            <button
              class="btn variant-filled-primary"
              on:click={() => currentIndex = 0}
            >
              🔄 Zurück zum Anfang
            </button>
            <button
              class="btn variant-filled-surface"
              on:click={parent.onClose}
            >
              Schließen
            </button>
          </div>
        </div>
      </div>
    {:else if currentSong}
      <!-- Song Card mit Navigation -->
      <div class="flex items-center gap-1 md:gap-4 h-full">
        <!-- Previous Button -->
        <button
          class="btn variant-filled-primary flex md:flex flex-shrink-0 w-8 md:w-auto h-32 md:h-auto px-1 md:px-4 no-swipe"
          on:click={goPrevious}
          disabled={isFirstSong}
          aria-label="Vorheriger Song"
        >
          <svg class="w-4 h-4 md:w-6 md:h-6" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        </button>

        <!-- Song Content -->
        <div class="flex-1 min-w-0 relative">
          <!-- Timeline-Linie (nur Desktop) -->
          <div class="hidden md:block absolute left-4 top-0 bottom-0 w-1 bg-gradient-to-b from-surface-300 via-primary-500 to-surface-300 dark:from-surface-600 dark:via-primary-400 dark:to-surface-600"></div>

          <!-- Vorheriger Song (Vorschau) -->
          {#if previousSong}
            <button
              class="w-full text-left mb-2 group"
              disabled="1"
            >
              <div class="card variant-ghost-surface p-2 hover:variant-soft-surface transition-all relative">
                <!-- Timeline-Punkt -->
                <div class="hidden md:block absolute left-3 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-surface-400 dark:bg-surface-500 border-2 border-surface-50 dark:border-surface-900"></div>

                <div class="flex items-center gap-2 md:gap-3 md:ml-6">
                  <div class="text-surface-400 dark:text-surface-500 text-xs font-semibold flex-shrink-0 hidden md:block">
                    VORHER
                  </div>
                  <div class="flex-1 min-w-0 opacity-50 group-hover:opacity-75 transition-opacity">
                    <div class="font-semibold text-xs md:text-sm truncate">
                      <span class="md:hidden text-surface-400 mr-2">↑</span>{previousSong.title}
                    </div>
                    <div class="text-xs text-surface-500 dark:text-surface-400 truncate hidden md:block">{previousSong.interpret}</div>
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    {#if previousSong.uebersprungen}
                      <span class="badge variant-soft-warning text-xs">⏭️</span>
                    {:else if previousSong.feedback}
                      <span class="text-sm md:text-base">
                        {previousSong.feedback === 1 ? '😐' : previousSong.feedback === 2 ? '🙂' : '😍'}
                      </span>
                    {/if}
                  </div>
                </div>
              </div>
            </button>
          {/if}

          <!-- Aktueller Song (Hauptkarte) -->
          <div class="card variant-ghost p-4 md:p-6 gradient-bg dark:from-primary-950 dark:to-surface-900 ring-2 ring-primary-500 shadow-xl relative ">
            <!-- Timeline-Punkt (größer) -->
            <div class="hidden md:block absolute left-2 top-1/2 -translate-y-1/2 w-5 h-5 rounded-full bg-primary-500 border-4 border-surface-50 dark:border-surface-900 shadow-lg animate-pulse"></div>

            <!-- Song Info - Titel im Vordergrund -->
            <div class="text-center mb-6">
              <h3 class="song-title mb-3 break-words leading-tight">{currentSong.title}</h3>
              <div class="flex items-center justify-center gap-2 text-sm md:text-base text-surface-500 dark:text-surface-400">
                <span>{currentSong.interpret}</span>
                {#if currentSong.tone_key}
                  <span class="text-surface-400">•</span>
                  <span class="font-mono font-semibold text-primary-600 dark:text-primary-400">{currentSong.tone_key}</span>
                {/if}
                {#if currentSong.eingeschoben}
                  <span class="text-surface-400">•</span>
                  <span class="badge variant-soft-success text-xs">➕</span>
                {/if}
              </div>
            </div>

            {#if currentSong.comment}
              <div class="warning variant-soft-warning mb-4 p-3  h-12">
                <div class="error-message gap-2">
                  <p class="font-bold text-sm"> {currentSong.comment}</p>
                </div>
              </div>
           {:else}
              <div class="warning  mb-4 p-3 h-12">
                <div class="error-message gap-2">
                  <p class="font-bold text-sm"></p>
                </div>
              </div>
            {/if}

            <!-- Interaktions-Buttons in einer Zeile -->
            <div class="flex flex-wrap items-center justify-center gap-2 md:gap-3 mb-4 no-swipe">
              <!-- Überspringen Button -->
              <button
                class="btn btn-sm md:btn-md {currentSong.uebersprungen ? 'variant-filled-warning' : 'variant-soft-surface'}"
                on:click={toggleUebersprungen}
              >
                {currentSong.uebersprungen ? '⏭️ Übersprungen' : '⏭️ Überspringen'}
              </button>

              <!-- Feedback Buttons - nur wenn nicht übersprungen -->
              {#if !currentSong.uebersprungen}
                <div class="flex items-center gap-1 md:gap-2 border-l border-surface-300 dark:border-surface-600 pl-2 md:pl-3">
                  <span class="text-xs md:text-sm text-surface-600 dark:text-surface-400 mr-1">Bewertung:</span>
                  {#each [
                    { rating: 1, filled: '😐', empty: '😐' },
                    { rating: 2, filled: '🙂', empty: '🙂' },
                    { rating: 3, filled: '😍', empty: '😍' }
                  ] as { rating, filled, empty }}
                    <button
                      class="btn-icon btn-icon-sm md:btn-icon {currentSong.feedback === rating ? 'variant-filled-primary' : 'variant-soft-surface'} text-xl md:text-2xl"
                      on:click={() => setFeedback(rating)}
                      aria-label="{rating} Sterne"
                    >
                      {currentSong.feedback === rating ? filled : empty}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>

            <!-- Song einfügen -->
            <div class="border-t border-surface-300 dark:border-surface-700 pt-3 mt-3 no-swipe">
              <button
                class="btn btn-sm variant-soft-secondary w-full mb-2"
                on:click={() => showInsertSection = !showInsertSection}
              >
                {showInsertSection ? '✖️ Abbrechen' : '➕ Song einfügen'}
              </button>

              {#if showInsertSection}
                <div class="space-y-2">
                  <label class="label">
                    <span class="text-xs md:text-sm">Song aus Repertoire suchen</span>
                    <input
                      type="text"
                      class="input input-sm"
                      placeholder="Titel oder Interpret..."
                      bind:value={searchTerm}
                    />
                  </label>

                  {#if searchTerm.length > 0}
                    <div class="max-h-32 md:max-h-48 overflow-y-auto space-y-1">
                      {#each filteredSongs as song}
                        <button
                          class="w-full text-left p-2 rounded-lg transition-colors {selectedSongToInsert?.id === song.id ? 'bg-primary-500 text-white' : 'bg-surface-200 dark:bg-surface-700 hover:bg-surface-300 dark:hover:bg-surface-600'}"
                          on:click={() => selectedSongToInsert = song}
                        >
                          <div class="font-semibold text-sm">{song.title}</div>
                          <div class="text-xs opacity-75">{song.interpret}</div>
                        </button>
                      {:else}
                        <p class="text-xs md:text-sm text-surface-600 dark:text-surface-400 p-2">
                          Keine Songs gefunden
                        </p>
                      {/each}
                    </div>
                  {/if}

                  {#if selectedSongToInsert}
                    <button
                      class="btn btn-sm variant-filled-primary w-full"
                      on:click={insertSong}
                    >
                      ➕ "{selectedSongToInsert.title}" einfügen
                    </button>
                  {/if}
                </div>
              {/if}
            </div>

            <!-- Mobile Navigation Hint -->
            <div class="md:hidden text-center mt-3 text-xs text-surface-500">
              👈 Wische für Navigation 👉
            </div>
          </div>

          <!-- Nächster Song (Vorschau) -->
          {#if nextSong}
            <button
              class="w-full text-left mt-2 group"
              on:click={goNext}
            >
              <div class="card variant-ghost-surface p-2 hover:variant-soft-surface transition-all relative">
                <!-- Timeline-Punkt -->
                <div class="hidden md:block absolute left-3 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-surface-400 dark:bg-surface-500 border-2 border-surface-50 dark:border-surface-900"></div>

                <div class="md:ml-6">
                  <div class="flex items-center gap-2 md:gap-3">
                    <div class="text-surface-400 dark:text-surface-500 text-xs font-semibold flex-shrink-0 hidden md:block">
                      ALS NÄCHSTES
                    </div>
                    <div class="flex-1 min-w-0 opacity-50 group-hover:opacity-75 transition-opacity">
                      <div class="font-semibold text-xs md:text-sm truncate">
                        <span class="md:hidden text-surface-400 mr-2">↓</span>{nextSong.title}
                      </div>
                      <div class="text-xs text-surface-500 dark:text-surface-400 truncate hidden md:block">{nextSong.interpret}</div>
                    </div>
                  {#if nextSong.comment}
                    <div class="mt-1 ml-0 md:ml-20 text-xs text-warning-600 dark:text-warning-400 italic truncate opacity-70 group-hover:opacity-90 transition-opacity">
                      💡 {nextSong.comment}
                    </div>
                  {/if}
                </div>
              </div>
            </button>
          {/if}
        </div>

        <!-- Next Button -->
        <button
          class="btn variant-filled-primary flex md:flex flex-shrink-0 w-8 md:w-auto h-32 md:h-auto px-1 md:px-4 no-swipe"
          on:click={goNext}
          disabled={isLastSong}
          aria-label="Nächster Song"
        >
          <svg class="w-4 h-4 md:w-6 md:h-6" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    {/if}
  </div>

  <!-- Footer mit Keyboard Shortcuts -->
  <footer class="hidden md:block border-t border-surface-300 p-3 bg-surface-50 dark:bg-surface-900">
    <div class="flex justify-center gap-6 text-xs text-surface-600 dark:text-surface-400">
      <span>← → Navigation</span>
      <span>ESC Schließen</span>
    </div>
  </footer>
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

