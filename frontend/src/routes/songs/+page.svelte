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
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { songFields, songApproachFields, getSongFieldsDetails } from '$lib/songFields.js';
  import { appConfig } from '$lib/appConfig.js';
  import {
    getSongs,
    getUser,
    updateSong,
    deleteSong,
    createNewSong,
    getSongsCandidates,
    updateSongCandidateFeedback,
    acceptSongApproach, logout as apiLogout} from '$lib/api.js';

  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { InfoIcon } from 'lucide-svelte';

  const { showError, showSuccess, showWarning } = createMessageHelpers();

  import NewSongForm from './NewSongForm.svelte';
  import SongDetailsModal from '$lib/components/SongDetailsModal.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';

  import { modalState } from '$lib/modalState.js';
import AgGrid from '$lib/components/AgGrid.svelte';
  function handleRowClick(event) {
    openModal(event.data);
  }

  

    let user = $state(null);
  let songs = $state([]);
  let filteredSongsMobile=[];
  let filterStringMobile = $state("");
  let error = $state('');
  let search = $state('');
  let sortField = $state('title');
  let sortAsc = $state(true);


  let showRetired = $state(false);
  let rulesVisible = $state(false);
  let showHelp = $state(false);
  let tabSet = $state(1); // Tab-Steuerung: 0 = Songs, 1 = Vorschläge
  let gridApi;

  let expandedSongId = $state(null);
  let editSongId = $state(null);
  let editBuffer = $state({});

  let songFieldsDetails = $derived(getSongFieldsDetails($appConfig));

  let { data } = $props();

  function toggleRules() {
    rulesVisible = !rulesVisible;
  }

  function openModal(song) {
    modalState.trigger({
    component: SongDetailsModal,
    meta: {
      songId: song.id
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


  const columnDefs = songFields.map(f => ({
      field: f.key,
      headerName: f.label,
      sortable: true,
      filter: 'agTextColumnFilter',
      floatingFilter: true,
      resizable: true,
      flex: 1,
      filterParams: {
        filterOptions: ['contains'],
        suppressAndOrCondition: true,
        debounceMs: 200,
        buttons: ['reset']
      },
      floatingFilterComponentParams: {
        suppressFilterButton: true
      }
  }));


  const defaultColDef = {
    sortable: true,
    filter: true,
    resizable: true
  };

  // Master-Detail Configuration – Detail wird via Modal geöffnet, nicht inline
  const detailCellRendererParams = {
    detailGridOptions: {
      columnDefs: [
        ...songFields.map(f => ({
          field: f.key,
          headerName: f.label,
          editable: false
        }))
      ],
      defaultColDef: {
        flex: 1
      }
    },
    getDetailRowData: (params) => {
      params.successCallback([params.data]);
    }
  };

  function onGridReady(params) {
    gridApi = params.api;}

  function onRowClicked(event) {
    const node = event.node;
    node.setExpanded(!node.expanded);
  }

  function onFirstDataRendered(params) {
    params.api.sizeColumnsToFit();
  }

  // Custom Detail Panel Renderer
  function DetailCellRenderer() {}

  DetailCellRenderer.prototype.init = function(params) {
    this.eGui = document.createElement('div');
    this.eGui.className = 'p-4 space-y-2 bg-surface-70';

    const song = params.data;
    const isEditing = editSongId === song.id;

    this.eGui.innerHTML = `
      <h3 class="text-lg font-semibold text-primary-900 dark:text-primary-200">
        ${song.title}
      </h3>
      <div id="detail-content-${song.id}"></div>
    `;

    setTimeout(() => {
      this.renderDetailContent(song);
    }, 0);
  };

  DetailCellRenderer.prototype.renderDetailContent = function(song) {
    const container = document.getElementById(`detail-content-${song.id}`);
    if (!container) return;

    const isEditing = editSongId === song.id;

    if (isEditing) {
      this.renderEditForm(container, song);
    } else {
      this.renderDetailsView(container, song);
    }
  };

  DetailCellRenderer.prototype.renderEditForm = function(container, song) {
    const fields = [...songFields, ...songFieldsDetails];
    const formHtml = `
      <form class="space-y-3" id="edit-form-${song.id}">
        ${fields.map(f => `
          <label class="block">
            <span class="text-sm font-medium text-surface-700 dark:text-surface-200">${f.label}</span>
            <input
              type="text"
              class="input mt-1 w-full text-surface-600 dark:text-surface-200"
              name="${f.key}"
              value="${editBuffer[f.key] || ''}" />
          </label>
        `).join('')}
        <div class="flex gap-2">
          <button type="submit" class="btn btn-sm variant-filled-success">Speichern</button>
          <button type="button" class="btn btn-sm variant-ghost" id="cancel-${song.id}">Abbrechen</button>
        </div>
      </form>
    `;

    container.innerHTML = formHtml;
    document.getElementById(`edit-form-${song.id}`).addEventListener('submit', (e) => {
      e.preventDefault();
      saveEdit(song);
    });

    document.getElementById(`cancel-${song.id}`).addEventListener('click', () => {
      cancelEdit();gridApi.redrawRows();
    });

    // Update editBuffer on input change
    fields.forEach(f => {
      const input = container.querySelector(`input[name="${f.key}"]`);
      input.addEventListener('input', (e) => {
        editBuffer[f.key] = e.target.value;
      });
    });
  };

  DetailCellRenderer.prototype.renderDetailsView = function(container, song) {
    const detailsHtml = `
      <ul class="divide-y divide-surface-300 text-sm">
        ${songFieldsDetails.map(f => `
          <li class="flex justify-between py-1">
            <span class="text-surface-800 dark:text-surface-200">${f.label}</span>
            <span class="text-surface-700 dark:text-surface-300">${song[f.key] ?? '–'}</span>
          </li>
        `).join('')}
      </ul><div class="flex gap-2 mt-3">
        ${canEdit() ? `<button class="btn btn-sm variant-filled-primary" id="edit-${song.id}">Bearbeiten</button>` : ''}
        ${song.status !== 'retired' && canEdit() ? `
          <div class="inline-flex items-center gap-2">
            <button class="btn btn-sm variant-filled-error" id="delete-${song.id}">Löschen</button>
          </div>
        ` : ''}
      </div>
    `;

    container.innerHTML = detailsHtml;

    if (canEdit()) {
      document.getElementById(`edit-${song.id}`)?.addEventListener('click', () => {
        startEdit(song);gridApi.redrawRows();
      });
    }

    if (song.status !== 'retired' && canEdit()) {
      document.getElementById(`delete-${song.id}`)?.addEventListener('click', () => {
        setSongToRetired(song.id, song.title, song.interpret);
      });
    }
  };

  DetailCellRenderer.prototype.getGui = function() {
    return this.eGui;
  };

  let rowData = $derived(filteredSongs);

  // PATCH-Request für Song-Änderung (ins $lib/api.js auslagern)

  function openNewSongModal() {
    modalState.trigger({
      component: NewSongForm,
      title: 'Neuen Song erstellen',
      response: (r) => {
        if (r) addSong(r);
      },
      close: modalState.close
    });
  }

  async function addSong(newSong) {
    try {
        await createNewSong(newSong, null)
        await refreshSongLists();
        showSuccess("Neuer Song hinzugefügt");
    } catch (e) {
      showError(e.message ?? "Fehler beim Hinzufügen des Songs");
    }
  }

  function startEdit(song) {
    editSongId = song.id;
    // Tiefe Kopie der Songdaten (nicht Reference!)
    editBuffer = { ...song };
    showSuccess("Bearbeiten gestartet");
  }

  function cancelEdit() {
    editSongId = null;
    editBuffer = {};
  }

 async function openSongDetailsModal(song) {
      modalState.trigger({
        component: SongDetailsModal,
        meta: { songId: song.id },
        response: async (r) => {
      if (r?.action === 'updated' || r?.action === 'delete') {
            await refreshSongLists();
          }
      }
      });
 }

   async function refreshSongLists() {
      // Temporäre Variable verwenden
      const newSongs = await getSongs();
      const newVorschlaege = await getSongsCandidates();

      // Erst zuweisen, dann console.log zum Debuggen
      songs = newSongs;
      vorschlaegeSongs = newVorschlaege;

      console.log('Songs aktualisiert:', songs.length);
      console.log('Vorschläge aktualisiert:', vorschlaegeSongs.length);
  }

  async function saveEdit(song, formData) {
      try {
        await updateSong(song.id, formData, null);
        await refreshSongLists();
        showSuccess('Song erfolgreich aktualisiert');
      } catch (e) {
        showError(e.message ?? "Update fehlgeschlagen");
      }
  }

  async function setSongToRetired(songId, songTitle, songInterpret) {
    const songName = songInterpret ? `${songInterpret} - ${songTitle}` : songTitle;

    modalState.trigger({
      component: ConfirmModal,
      meta: {
        title: 'Song löschen',
        message: `Möchten Sie den Song "${songName}" wirklich löschen? Der Song wird als "retired" markiert und aus der aktiven Liste entfernt.`,
        confirmText: 'Löschen',
        cancelText: 'Abbrechen',
        confirmButtonClass: 'btn variant-filled-error',
        cancelButtonClass: 'btn variant-outline-secondary'
      },
      response: async (confirmed) => {
        if (confirmed) {
          try {
            await deleteSong(songId, null);
            await refreshSongLists();
            showSuccess('Song erfolgreich gelöscht');
          } catch (e) {
            showError(e.message ?? 'Fehler beim Löschen des Songs.');
          }
        }
      }
    });
  }

  function toggleExpand(id) {
    expandedSongId = expandedSongId === id ? null : id;
  }

  function toggleShowRetired() {
    showRetired = !showRetired;
  }

let vorschlaegeSongs = $state([]);

let filteredSongs = $derived(songs
  .filter(song => song.status !== 'vorschlag' &&
     (showRetired || song.status !== 'retired')
  ).sort((a, b) => {
    let vA = a[sortField] ?? '';
    let vB = b[sortField] ?? '';
    if (typeof vA === 'string') vA = vA.toLowerCase();
    if (typeof vB === 'string') vB = vB.toLowerCase();
    if (vA < vB) return sortAsc ? -1 : 1;
    if (vA > vB) return sortAsc ? 1 : -1;
    return 0;
  }));

  function setSort(field) {
    if (sortField === field) {
      sortAsc = !sortAsc;
    } else {
      sortField = field;
      sortAsc = true;
    }
  }

  function mobileFilter() {
    filteredSongsMobile = songs.filter(song =>
        song.title.toLowerCase().includes(filterStringMobile.toLowerCase()) ||
        song.interpret.toLowerCase().includes(filterStringMobile.toLowerCase())  &&
      (showRetired || song.status !== 'retired')
    );
  }

  function logout() {
        // Wird von apiLogout() gehandhabt
  }

  onMount(async () => {
    try {
      user = await getUser();
    } catch(e) {
      error = 'Fehler: ' + (e.message ?? '');
      console.error('Songs load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
    songs = await getSongs();
    vorschlaegeSongs = await getSongsCandidates();
    if (vorschlaegeSongs.length === 0 ) { tabSet = 0; } else {tabSet = 1;}
  });


  function getFeedbackStats(feedbacks) {
        const total = feedbacks.length;
        if (total === 0) return {
            relative: { a: 0, na: 0 },
            absolute: { a: 0, na: 0, o: 0, sum: 0 }
        };

        const counts = { a: 0, o: 0, na: 0 };
        feedbacks.forEach(fb => {
            if (counts.hasOwnProperty(fb.feedback)) counts[fb.feedback]++;
        });

        const votesSum = counts.a + counts.na;

        const normalized = {
            relative: {
                a: votesSum > 0 ? Math.round((counts.a / votesSum) * 100) : 0,
                na: votesSum > 0 ? Math.round((counts.na / votesSum) * 100) : 0
            },
            absolute: {
                a: counts.a,
                na: counts.na,
                o: counts.o,
                sum: total
            }
        };

        // Sicherstellen, dass a + na = 100% ergibt (nur wenn Votes existieren)
        if (votesSum > 0 && normalized.relative.a + normalized.relative.na !== 100) {
            normalized.relative.na = 100 - normalized.relative.a;
        }

        return normalized;
  }



  function getUserFeedback(feedbackObj) {

      if (!feedbackObj || !user?.id) return null;

      const userFeedback = feedbackObj.find(f => f.user_id === user.id);

      return userFeedback?.feedback || null;
  }

  async function submitFeedback(song, feedback) {
    let newFeedbackObj = {
        'user_id': user.id,
        'song_id': song.id,
        'feedback': feedback
    };

    //Find Feedback-Object of User
    let existingUserFeedback = song.feedbacks.find(fb => fb.user_id === user.id);

    if (existingUserFeedback) {
        if (existingUserFeedback.feedback === feedback) {
            // Delete feedback if same feedback is given again
            song.feedbacks = song.feedbacks.filter(fb => fb.user_id !== user.id);
        }
        //Update existing feedback
        existingUserFeedback.feedback = feedback;
    } else {
        //Add new feedback
        song.feedbacks.push(newFeedbackObj);
    }

    // update vorschlageSongs feedbacks
    try {
        const apiAnswer = await updateSongCandidateFeedback(null, song.id, song.feedbacks);
        vorschlaegeSongs = vorschlaegeSongs.map(s =>
          s.id === song.id ? { ...s, feedbacks: apiAnswer } : s
        );
    } catch (e) {
        showError(e.message ?? "Fehler beim Speichern des Feedbacks");
    }
  }

  async function acceptSong(song) {
    try {
        await acceptSongApproach(song.id, null)
        await refreshSongLists();
        showSuccess('Song erfolgreich aktualisiert');
      } catch (e) {
        showError(e.message ?? "Update fehlgeschlagen");
      }
  }

  function canEdit() {
    return user && (user.user_group === 'admin' || user.user_group === 'editor');
  }
</script>



<div class="max-w-8xl mx-auto py-8 md:px-4">


  <div class="card bg-surface-2 rounded-3xl shadow-md md:border md:border-outline-variant p-2 md:p-8">


    <div class="flex flex-col md:flex-row md:justify-between md:items-center md:mb-6">
        <h3 class="h2 mb-4 text-on-surface">Songs</h3>
        <button
          class="btn variant-ghost-surface btn-sm mb-4 md:mb-0"
          onclick={() => showHelp = !showHelp}
          aria-label="Hilfe anzeigen"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <span class="hidden md:inline ml-2">Hilfe</span>
        </button>
    </div>

    {#if showHelp}
      <div class="card variant-ghost-surface mt-4 mb-6 p-4 md:p-6">
        <h3 class="h4 font-bold mb-4">🎵 Anleitung: Songs-Verwaltung</h3>

        <div class="space-y-4">
          <!-- Grundfunktionen -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-2">📋 Hauptfunktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Neuen Song hinzufügen:</strong> Klicke auf "Neuen Song hinzufügen" und fülle das Formular aus</li>
              <li><strong>Song bearbeiten:</strong> Klicke auf einen Song in der Tabelle, um Details zu sehen und zu bearbeiten</li>
              <li><strong>Song-Status ändern:</strong> Im Detail-Modal kannst du den Status ändern (Neu → Proben → Spielbereit → Archiviert)</li>
              <li><strong>Song löschen:</strong> Im Detail-Modal gibt es eine Löschen-Option (nur für Admins/Editoren)</li>
            </ul>
          </div>

          <!-- Die zwei Tabs -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-2">📂 Die zwei Tabs</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Songs ({filteredSongs.length}):</strong> Alle regulären Songs in der Datenbank</li>
              <li><strong>Vorschläge ({vorschlaegeSongs.length}):</strong> Neue Song-Vorschläge, über die abgestimmt werden kann</li>
            </ul>
          </div>

          <!-- Desktop vs Mobile -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-2">💻 Desktop vs. 📱 Mobile</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Desktop:</strong> Interaktive Tabelle mit Sortier-, Filter- und Suchfunktionen</li>
              <li><strong>Mobile:</strong> Kartendarstellung mit Suchfeld und kompakter Ansicht</li>
            </ul>
          </div>

          <!-- Song-Vorschläge -->
          <div>
            <h4 class="font-semibold text-warning-500 mb-2">💡 Song-Vorschläge</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Vorschlag bewerten:</strong> Gib Feedback (👍/👎/🤷) zu Song-Vorschlägen im Vorschläge-Tab</li>
              <li><strong>Vorschlag übernehmen:</strong> Akzeptierte Vorschläge (≥50% Ja bei min. 4 Stimmen) werden zu regulären Songs</li>
              <li><strong>Nur Admins/Editoren</strong> können Vorschläge final übernehmen</li>
            </ul>
          </div>

          <!-- Archivierte Songs -->
          <div>
            <h4 class="font-semibold text-error-500 mb-2">📦 Archivierte Songs</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>Songs mit Status "Archiviert" werden standardmäßig ausgeblendet</li>
              <li>Über den Filter "Gelöschte Songs anzeigen" kannst du sie einblenden</li>
              <li>Archivierte Songs können nicht in Setlisten verwendet werden</li>
            </ul>
          </div>

          <!-- Tipps -->
          <div class="alert variant-soft-primary">
            <div class="alert-message">
              <h4 class="font-semibold mb-1">💡 Tipp</h4>
              <p class="text-sm">Nutze die Filter- und Suchfunktionen (Desktop) um schnell den gewünschten Song zu finden!</p>
            </div>
          </div>
        </div>
      </div>
    {/if}

    <div class="inline-flex items-center gap-2">
      <button class="btn variant-filled-primary btn-sm w-fit border mt-4 md:mb-4" onclick={openNewSongModal}>
        Neuen Song hinzufügen
      </button>
      <span
        class="inline-block align-super cursor-help"
      >
        <InfoIcon class="w-4 h-4 text-primary-500" />
      </span>
    </div>
    <div class="card p-4 variant-filled-secondary" data-popup="newSongInfo">
      <b>Neuen Song erstellen</b>
      <hr>
      <p>Hier kannst du ganz einfach einen neuen Song erstellen</p>
      <div class="arrow variant-filled-secondary" />
    </div>

    <!-- Tab-Navigation -->
    <div class="flex border-b border-surface-300 dark:border-surface-600 mb-4 gap-1">
      <button onclick={() => tabSet = 1} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 1 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {vorschlaegeSongs.length > 0 ? 'font-bold' : ''}">
        <span>Vorschläge ({vorschlaegeSongs.length})</span>
      </button>

      <button onclick={() => tabSet = 0} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 0 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}">
        <span>Songs ({filteredSongs.length})</span>
      </button>

      <div class="mt-4">
        {#if tabSet === 0}
          <!-- Tab 1: Songs -->
          <div class="flex flex-col md:flex-row md:items-center md:justify-between mb-1 md:gap-4 mt-4">
            <div class="flex items-center md:gap-2">
              <div class="inline-flex items-center gap-2">
                <button type="button" class="btn btn-sm {showRetired ? 'variant-filled-primary' : 'variant-ghost'}  w-fit border mt-4 mb-4" onclick={toggleShowRetired}>
                  Gelöschte Songs anzeigen
                </button>
                <span
                  class="inline-block align-super cursor-help"
                >
                  <InfoIcon class="w-4 h-4 text-primary-500" />
                </span>
              </div>
              <div class="card p-4 variant-filled-secondary" data-popup="showDelSongsInfo">
                <b>Gelöschte Songs anzeigen</b>
                <hr>
                <p>Wird ein Song als gelöscht markiert, wird er nicht wirklich gelöscht um auch vergangene Setlisten konsistent zu halten.</p>
                <p>Standardmäßig sind diese Songs hier aber ausgeblendet. Mit diesem Schalter kannst du die Songs ein- oder ausblenden.</p>
                <div class="arrow variant-filled-secondary" />
              </div>
            </div>
          </div>

          {#if error}
            <div class="alert alert-danger">{error}</div>
          {/if}

          <div class="hidden md:block"> <!-- Tabelle nur ab md sichtbar -->
            <div class="ag-theme-alpine" style="height: 600px; width: 100%;">
              <AgGrid
                  {rowData}
                  {columnDefs}
                  onRowClicked={handleRowClick}
                />
            </div>

            {#if expandedSongId}
              {@const song = filteredSongs.find(s => s.id === expandedSongId)}
              {#if song}
                <div class="card p-4 mt-4 bg-surface-100 dark:bg-surface-800">
                  <div class="flex justify-between items-start mb-4">
                    <h3 class="h3">{song.title}</h3>
                    <button
                      class="btn btn-sm variant-ghost"
                      onclick={() => expandedSongId = null}
                    >
                      ✕
                    </button>
                  </div>

                  {#if editSongId === song.id}
                    <!-- Bearbeiten-Modus -->
                    <form class="space-y-3" onsubmit={() => saveEdit(song)}>
                      {#each [...songFields, ...songFieldsDetails] as f}
                        <label class="block">
                          <span class="text-sm font-medium">{f.label}</span>
                          <input
                            type="text"
                            class="input mt-1 w-full"
                            bind:value={editBuffer[f.key]}
                          />
                        </label>
                      {/each}
                      <div class="flex gap-2">
                        <button type="submit" class="btn btn-sm variant-filled-success">
                          Speichern
                        </button>
                        <button
                          type="button"
                          class="btn btn-sm variant-ghost"
                          onclick={cancelEdit}
                        >
                          Abbrechen
                        </button>
                      </div>
                    </form>
                  {:else}
                    <!-- Detail-Ansicht -->
                    <ul class="divide-y divide-surface-300">
                      {#each songFieldsDetails as f}
                        <li class="flex justify-between py-2">
                          <span class="font-semibold">{f.label}</span>
                          <span>{song[f.key] ?? '–'}</span>
                        </li>
                      {/each}
                    </ul><div class="flex gap-2 mt-4">
                      {#if canEdit()}
                        <button
                          class="btn variant-filled-primary btn-sm"
                          onclick={() => startEdit(song)}
                        >
                          Bearbeiten
                        </button>
                      {/if}
                      {#if song.status !== 'retired' && canEdit()}
                        <button
                          class="btn variant-filled-error btn-sm"
                          onclick={() => setSongToRetired(song.id, song.title, song.interpret)}
                        >
                          Löschen
                        </button>
                      {/if}
                    </div>
                  {/if}
                </div>
              {:else}
                <div class="card p-4 mt-4 bg-warning-100">
                  <p>Song nicht gefunden</p>
                </div>
              {/if}
            {/if}
          </div>

          <!-- Kartenansicht für mobile Geräte -->
          <div class="grid gap-3 md:hidden">
            <input
              type="text"
              class="input w-full mb-3 bg-surface border-none focus:ring-primary text-surface-200"
              placeholder="Suche Songs..."
              bind:value={filterStringMobile}
              oninput={mobileFilter} />
            {#each filteredSongs as song (song.id)}
              <div class="card variant-filled-surface rounded-xl shadow-sm p-4 bg-surface-50">
                <div class="flex justify-between items-start">
                  <h3 class="text-lg font-semibold text-primary-800 dark:text-primary-200">{song.title}</h3>
                  <button class="btn btn-sm variant-tonal" onclick={() => toggleExpand(song.id)}>
                    {#if expandedSongId === song.id}
                      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M7 10a1 1 0 011-1h4a1 1 0 110 2H8a1 1 0 01-1-1z" clip-rule="evenodd"></path>
                      </svg>
                    {:else}
                      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"></path>
                      </svg>
                    {/if}
                  </button>
                </div>

                <!-- Kompakte Metadaten -->
                <dl class="divide-y divide-surface-300 text-sm mt-2">
                  {#each songFields.filter(f => f.key !== 'title') as f}
                    <div class="flex justify-between py-1">
                      <dt class="text-surface-900">{f.label}</dt>
                      <dd class="text-surface-900">{song[f.key] ?? '–'}</dd>
                    </div>
                  {/each}
                </dl>

                <!-- Erweiterte Details -->
                {#if expandedSongId === song.id}
                  <div class="mt-3 border-t border-surface-300 pt-2 space-y-1">
                    <p class="text-xs text-surface-900">Details zu: {song.title}</p>
                    {#each songFieldsDetails as f}
                      <div class="flex justify-between py-1 text-sm">
                        <span class="text-surface-800">{f.label}</span>
                        <span class="text-surface-800">{song[f.key] ?? '–'}</span>
                      </div>
                    {/each}
                  </div>
                {/if}
              </div>
            {/each}
          </div>

        {:else if tabSet === 1}
          <!-- Tab 2: Vorschläge -->
          {#if vorschlaegeSongs.length === 0}
            <p class="text-on-surface-variant italic mt-4">Keine Song-Vorschläge vorhanden</p>
          {:else}
            <!-- Regeln als Info-Box -->
            <div class="card variant-soft-warning mb-6 mt-4">
              <button
                type="button"
                class="w-full p-4 text-left hover:bg-warning-50 dark:hover:bg-warning-900/10 transition-colors rounded-lg"
                onclick={toggleRules}
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <svg class="w-6 h-6 text-warning-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
                    </svg>
                    <h3 class="font-semibold text-warning-900 dark:text-warning-100">
                      📋 Regeln für Song-Vorschläge
                    </h3>
                  </div>
                  <svg
                    class="w-5 h-5 text-warning-700 dark:text-warning-300 transition-transform {rulesVisible ? 'rotate-180' : ''}"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                  </svg>
                </div>
              </button>

              {#if rulesVisible}
                <div class="px-4 pb-4 pt-2">
                  <ul class="space-y-2 text-sm text-warning-900 dark:text-warning-100">
                    <li class="flex gap-2">
                      <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
                      <span>Jeder Song wird zunächst als Vorschlag angelegt, außer er ist extern gefordert oder als dringend markiert</span>
                    </li>
                    <li class="flex gap-2">
                      <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
                      <span>Abstimmungen können digital oder persönlich erfolgen</span>
                    </li>
                    <li class="flex gap-2">
                      <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
                      <span><strong>Persönliche Abstimmung:</strong> Ein Song kann direkt als angenommen eingetragen werden, wenn die anwesenden Stimmberechtigten mehrheitlich zustimmen (Enthaltungen zählen nicht)</span>
                    </li>
                    <li class="flex gap-2">
                      <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
                      <span><strong>Digitale Abstimmung:</strong> Ein Song ist zur Übernahme freigegeben, wenn (a) der Ja-Anteil unter den gültigen Stimmen (Ja+Nein) ≥50% beträgt und (b) mindestens 4 gültige Stimmen abgegeben wurden (Enthaltungen zählen nicht)</span>
                    </li>
                    <li class="flex gap-2">
                      <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
                      <span>Admins/Editoren dürfen einen zur Übernahme freigegebenen Song auf angenommen setzen; Abweichungen vom Abstimmungsergebnis (z.B. Dringlichkeit) müssen kurz begründet werden</span>
                    </li>
                  </ul>
                </div>
              {/if}
            </div>

            <div class="overflow-x-auto rounded-xl shadow-md p-4">
              <table class="w-full border-collapse text-surface-100">
                <thead class="bg-surface-400 text-sm font-medium uppercase">
                  <tr>
                    {#each songApproachFields as f}
                      <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">
                        {f.label}
                      </th>
                    {/each}
                    {#if canEdit()}
                      <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">Aktion</th>
                    {/if}
                  </tr>
                </thead>
                <tbody>
                  {#each vorschlaegeSongs as song (song.id)}
                    {@const userFeedbackType = getUserFeedback(song.feedbacks)}
                    <tr class="dark:hover:bg-surface-700 cursor-pointer transition-colors text-surface-900 dark:text-surface-100 hover:bg-surface-300"
                        onclick={() => toggleExpand(song.id)}>
                        <td onclick={() => openSongDetailsModal(song)}>{song.title}</td>
                        <td onclick={() => openSongDetailsModal(song)}>{song.interpret}</td>
                       {#if user.musician}
                            <td>
                                <button
                                    class="btn btn-sm {userFeedbackType === 'a' ? 'variant-filled-success' : 'variant-outline-success'}"
                                    onclick={() => submitFeedback(song, 'a')}
                                >
                                    👍
                                </button>
                                <button
                                    class="btn btn-sm {userFeedbackType === 'na' ? 'variant-filled-error' : 'variant-outline-error'}"
                                    onclick={() => submitFeedback(song, 'na')}
                                >
                                    👎
                                </button>
                                <button
                                    class="btn btn-sm {userFeedbackType === 'o' ? 'variant-filled-warning' : 'variant-outline-warning'}"
                                    onclick={() => submitFeedback(song, 'o')}
                                >
                                    🤷
                                </button>
                           </td>
                       {:else}
                            <td>--</td>
                       {/if}
                       <td class="px-2">
                            {#if song.feedbacks && song.feedbacks.length > 0}
                                {@const stats = getFeedbackStats(song.feedbacks)}
                                <div style="display: inline-flex; align-items: center; gap: 8px; width: 100%;">
                                    <div
                                        style="position: relative; display: flex; width: 100%; flex: 0 0 80%; height: 20px; background-color: #e0e0e0; border: 1px solid #ccc; border-radius: 4px; overflow: hidden;"
                                        title="Gesamtstimmen: ∑ {stats.absolute.sum} | 👍 {stats.absolute.a} | 👎 {stats.absolute.na} | 🤷: {stats.absolute.o}"
                                    >
                                        {#if stats.relative.a > 0}
                                            <div style="background-color: green; width: {stats.relative.a}%; height: 100%;"></div>
                                        {/if}
                                        {#if stats.relative.na > 0}
                                            <div style="background-color: red; width: {stats.relative.na}%; height: 100%;"></div>
                                        {/if}
                                        <div style="position: absolute; left: 50%; top: 0; bottom: 0; border-left: 2px dashed black;"></div>
                                    </div>
                                    <span class="text-xs whitespace-nowrap" style="flex: 0 0 20%;">🤷: {stats.absolute.o}</span>
                                </div>
                            {:else}
                                <div style="position: relative; display: flex; width: 80%; height: 20px; background-color: #e0e0e0; border: 1px solid #ccc; border-radius: 4px; overflow: hidden;"></div>
                            {/if}
                       </td>
                       {#if canEdit()}
                            {@const stats = getFeedbackStats(song.feedbacks)}
                            <td>
                                {#if stats.relative.a >= 50 && stats.absolute.sum >= 4}
                                    <button
                                        class="btn variant-filled-success rounded-lg px-3 py-0 text-base font-semibold"
                                        onclick={() => acceptSong(song)}
                                    >
                                        ✓
                                    </button>
                                {/if}
                            </td>
                        {/if}
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        {/if}
      </div></div>
  </div>
</div>

<style>
/* Entferne nicht mehr benötigte CSS */
</style>

