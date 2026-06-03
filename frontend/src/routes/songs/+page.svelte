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
  import { songFields, getSongFieldsDetails } from '$lib/songFields.js';
  import { appConfig } from '$lib/appConfig.js';
  import {
    getSongs,
    getUser,
    getUserList,
    updateSong,
    deleteSong,
    createNewSong,
    getSongsCandidates,
    updateSongCandidateFeedback,
    acceptSongApproach, logout as apiLogout} from '$lib/api.js';

  import { createMessageHelpers } from '$lib/Messages.svelte';

  const { showError, showSuccess, showWarning } = createMessageHelpers();

  import NewSongForm from './NewSongForm.svelte';
  import SongDetailsModal from '$lib/components/SongDetailsModal.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';

  import { modalState } from '$lib/modalState.js';
  import AgGrid from '$lib/components/AgGrid.svelte';
  function handleRowClick(event) {
    openModal(event.data);
  }

  

    let user = $state({ user_name: null, user_group: null, id: null, musician: false });
  let songs = $state([]);
  let filteredSongsMobile = $state([]);
  let filterStringMobile = $state("");
  let error = $state('');
  let search = $state('');
  let sortField = $state('title');
  let sortAsc = $state(true);


  let rulesVisible = $state(false);
  let showHelp = $state(false);
  let tabSet = $state(1); // Tab-Steuerung: 0 = Songs, 1 = Vorschläge
  let gridApi;
  let gridContainerEl = $state(null);
  let desktopGridHeight = $state(600);

  let expandedSongId = $state(null);
  let editSongId = $state(null);
  let editBuffer = $state({});

  let songFieldsDetails = $derived(getSongFieldsDetails($appConfig));
  let allSongColumns = $derived(
    [...songFields, ...songFieldsDetails].filter((field, index, list) =>
      list.findIndex(candidate => candidate.key === field.key) === index
    )
  );
  const defaultVisibleColumnKeys = songFields.map(field => field.key);
  let visibleColumnKeys = $state([...defaultVisibleColumnKeys]);

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


  let statusValues = $derived(
    [...new Set(songs.map(s => s.status).filter(Boolean))]
  );

  // Custom Status-Filter (Popup mit Checkboxen, Community-only)
  class StatusFilter {
    init(params) {
      this.params = params;
      this.selectedValues = null; // null = alle ausgewählt (kein Filter aktiv)
      this.eGui = document.createElement('div');
      this.eGui.classList.add('ag-status-filter');
    }

    _getAllValues() {
      const values = new Set();
      this.params.api.forEachNode(node => {
        if (node.data?.status) values.add(node.data.status);
      });
      return [...values].sort();
    }

    getGui() {
      const allValues = this._getAllValues();
      this.eGui.innerHTML = '';

      const isDarkMode = document.documentElement.classList.contains('dark');
      const bgColor = isDarkMode ? '#1e293b' : '#f8fafc';
      const textColor = isDarkMode ? '#f8fafc' : '#0f172a';

      const container = document.createElement('div');
      container.style.padding = '10px';
      container.style.minWidth = '180px';
      container.style.backgroundColor = bgColor;
      container.style.color = textColor;

      // "Alle" Checkbox
      const allLabel = document.createElement('label');
      allLabel.style.cssText = 'display: flex; align-items: center; gap: 6px; cursor: pointer; font-weight: 600; margin-bottom: 6px;';
      const allCb = document.createElement('input');
      allCb.type = 'checkbox';
      allCb.checked = this.selectedValues === null;
      allLabel.appendChild(allCb);
      allLabel.appendChild(document.createTextNode('Alle'));
      container.appendChild(allLabel);

      const hr1 = document.createElement('hr');
      hr1.style.cssText = 'margin: 4px 0 8px 0; border-color: var(--ag-border-color, #ccc);';
      container.appendChild(hr1);

      const optionsDiv = document.createElement('div');
      const checkboxes = [];

      allValues.forEach(val => {
        const label = document.createElement('label');
        label.style.cssText = 'display: flex; align-items: center; gap: 6px; cursor: pointer; padding: 3px 0;';
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.value = val;
        cb.checked = this.selectedValues === null || this.selectedValues.has(val);
        cb.addEventListener('change', () => {
          if (this.selectedValues === null) {
            this.selectedValues = new Set(allValues);
          }
          if (cb.checked) {
            this.selectedValues.add(val);
          } else {
            this.selectedValues.delete(val);
          }
          allCb.checked = this.selectedValues.size === allValues.length;
          if (this.selectedValues.size === allValues.length) {
            this.selectedValues = null;
          }
          this.params.filterChangedCallback();
        });
        checkboxes.push(cb);
        label.appendChild(cb);
        label.appendChild(document.createTextNode(val));
        optionsDiv.appendChild(label);
      });
      container.appendChild(optionsDiv);

      allCb.addEventListener('change', () => {
        if (allCb.checked) {
          this.selectedValues = null;
          checkboxes.forEach(cb => cb.checked = true);
        } else {
          this.selectedValues = new Set();
          checkboxes.forEach(cb => cb.checked = false);
        }
        this.params.filterChangedCallback();
      });

      const hr2 = document.createElement('hr');
      hr2.style.cssText = 'margin: 8px 0 4px 0; border-color: var(--ag-border-color, #ccc);';
      container.appendChild(hr2);

      const btnDiv = document.createElement('div');
      btnDiv.style.cssText = 'margin-top: 6px; text-align: right;';
      const resetBtn = document.createElement('button');
      resetBtn.textContent = 'Reset';
      resetBtn.id = 'resetBtn';
      resetBtn.style.cssText = 'padding: 4px 14px; border-radius: 6px; border: none; cursor: pointer;';
      resetBtn.addEventListener('click', () => {
        this.selectedValues = null;
        allCb.checked = true;
        checkboxes.forEach(cb => cb.checked = true);
        this.params.filterChangedCallback();
      });
      btnDiv.appendChild(resetBtn);
      container.appendChild(btnDiv);

      this.eGui.appendChild(container);
      return this.eGui;
    }

    doesFilterPass(params) {
      if (this.selectedValues === null) return true;
      return this.selectedValues.has(params.data?.status);
    }

    isFilterActive() {
      return this.selectedValues !== null;
    }

    getModel() {
      if (this.selectedValues === null) return null;
      return { values: [...this.selectedValues] };
    }

    setModel(model) {
      if (!model) {
        this.selectedValues = null;
      } else {
        this.selectedValues = new Set(model.values);
      }
    }

    applyFilterFromFloating(model) {
      if (!model) {
        this.selectedValues = null;
      } else {
        this.selectedValues = new Set(model.values);
      }
      this.params.filterChangedCallback();
    }

    destroy() {}
  }

  // Custom Floating-Filter: Checkbox-Optionsmenü (Popup) statt Dropdown
  class StatusFloatingFilter {
    init(params) {
      this.params = params;
      this.popupVisible = false;
      this.allValues = [];

      // Container
      this.eGui = document.createElement('div');
      this.eGui.style.cssText = 'width: 100%; display: flex; align-items: center; height: 100%; position: relative;';

      // Button der den aktuellen Status anzeigt und das Popup öffnet
      this.btn = document.createElement('button');
      this.btn.type = 'button';

      // Farben basierend auf Dark/Light Mode
      const isDarkMode = document.documentElement.classList.contains('dark');
      const btnBg = isDarkMode ? '#1e293b' : '#f8fafc';  // surface-800 : surface-50
      const btnBorder = isDarkMode ? '#475569' : '#cbd5e1'; // surface-600 : surface-300
      const btnText = isDarkMode ? '#f8fafc' : '#0f172a'; // surface-50 : surface-900

      this.btn.style.cssText = `width: 100%; padding: 4px 8px; border-radius: 6px; font-size: 12px; border: 1px solid ${btnBorder}; background: ${btnBg}; color: ${btnText}; cursor: pointer; text-align: left; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`;
      this.btn.textContent = 'Alle';
      this.btn.addEventListener('click', (e) => {
        e.stopPropagation();
        this._togglePopup();
      });
      this.eGui.appendChild(this.btn);

      // Popup-Container
      this.popup = document.createElement('div');
      this.popup.classList.add('ag-status-filter', 'ag-status-floating-popup');

      // Fallback-Farben für Light und Dark Mode (wiederverwendet isDarkMode von oben)
      const bgColor = isDarkMode ? '#1e293b' : '#f8fafc';  // surface-800 : surface-50
      const borderColor = isDarkMode ? '#475569' : '#cbd5e1'; // surface-600 : surface-300
      const textColor = isDarkMode ? '#f8fafc' : '#0f172a'; // surface-50 : surface-900

      // Styles einzeln setzen für maximale Priorität
      this.popup.style.display = 'none';
      this.popup.style.position = 'absolute';
      this.popup.style.top = '100%';
      this.popup.style.left = '0';
      this.popup.style.zIndex = '9999';
      this.popup.style.minWidth = '180px';
      this.popup.style.padding = '10px';
      this.popup.style.borderRadius = '8px';
      this.popup.style.backgroundColor = bgColor;
      this.popup.style.border = `1px solid ${borderColor}`;
      this.popup.style.color = textColor;
      this.popup.style.boxShadow = `0 4px 16px rgba(0, 0, 0, ${isDarkMode ? '0.3' : '0.15'})`;

      this.eGui.appendChild(this.popup);

      // Klick außerhalb schließt das Popup
      this._onDocClick = (e) => {
        if (this.popupVisible && !this.popup.contains(e.target) && e.target !== this.btn) {
          this._hidePopup();
        }
      };
      document.addEventListener('click', this._onDocClick, true);
    }

    _togglePopup() {
      if (this.popupVisible) {
        this._hidePopup();
      } else {
        this._showPopup();
      }
    }

    _showPopup() {
      this._buildPopup();
      this.popup.style.display = 'block';
      this.popupVisible = true;
    }

    _hidePopup() {
      this.popup.style.display = 'none';
      this.popupVisible = false;
    }

    _getSelectedFromParent(callback) {
      this.params.parentFilterInstance(instance => {
        const model = instance.getModel();
        callback(model ? new Set(model.values) : null);
      });
    }

    _buildPopup() {
      this.popup.innerHTML = '';

      // Aktuelle Werte aus dem Grid lesen
      const allValues = new Set();
      this.params.api.forEachNode(node => {
        if (node.data?.status) allValues.add(node.data.status);
      });
      this.allValues = [...allValues].sort();

      // Aktuelles Filter-Model vom Parent lesen
      this.params.parentFilterInstance(instance => {
        const model = instance.getModel();
        const selected = model ? new Set(model.values) : null; // null = alle

        // "Alle" Checkbox
        const allLabel = document.createElement('label');
        allLabel.style.cssText = 'display: flex; align-items: center; gap: 6px; cursor: pointer; font-weight: 600; margin-bottom: 6px;';
        const allCb = document.createElement('input');
        allCb.type = 'checkbox';
        allCb.checked = selected === null;
        allLabel.appendChild(allCb);
        allLabel.appendChild(document.createTextNode('Alle'));
        this.popup.appendChild(allLabel);

        const hr1 = document.createElement('hr');
        hr1.style.cssText = 'margin: 4px 0 6px 0; border-color: var(--ag-border-color, #ccc);';
        this.popup.appendChild(hr1);

        const checkboxes = [];

        this.allValues.forEach(val => {
          const label = document.createElement('label');
          label.style.cssText = 'display: flex; align-items: center; gap: 6px; cursor: pointer; padding: 3px 0;';
          const cb = document.createElement('input');
          cb.type = 'checkbox';
          cb.value = val;
          cb.checked = selected === null || selected.has(val);
          cb.addEventListener('change', () => {
            this._onCheckboxChange(cb, allCb, checkboxes);
          });
          checkboxes.push(cb);
          label.appendChild(cb);
          label.appendChild(document.createTextNode(val));
          this.popup.appendChild(label);
        });

        allCb.addEventListener('change', () => {
          if (allCb.checked) {
            checkboxes.forEach(cb => cb.checked = true);
            instance.applyFilterFromFloating(null);
          } else {
            checkboxes.forEach(cb => cb.checked = false);
            instance.applyFilterFromFloating({ values: [] });
          }
        });
      });
    }

    _onCheckboxChange(changedCb, allCb, checkboxes) {
      this.params.parentFilterInstance(instance => {
        const checkedVals = checkboxes.filter(cb => cb.checked).map(cb => cb.value);
        allCb.checked = checkedVals.length === this.allValues.length;
        if (checkedVals.length === this.allValues.length) {
          instance.applyFilterFromFloating(null);
        } else {
          instance.applyFilterFromFloating({ values: checkedVals });
        }
      });
    }

    _getSummaryText(parentModel) {
      if (!parentModel) return 'Alle';
      const vals = parentModel.values || [];
      if (vals.length === 0) return '(keine)';
      if (vals.length === 1) return vals[0];
      if (vals.length <= 3) return vals.join(', ');
      return `${vals.length} gewählt`;
    }

    getGui() { return this.eGui; }

    onParentModelChanged(parentModel) {
      this.btn.textContent = this._getSummaryText(parentModel);
      // Visuelles Feedback: Button-Style wenn Filter aktiv
      if (parentModel) {
        this.btn.style.fontWeight = '600';
      } else {
        this.btn.style.fontWeight = 'normal';
      }
    }

    destroy() {
      document.removeEventListener('click', this._onDocClick, true);
    }
  }

  let columnDefs = $derived(allSongColumns.map(f => {
    if (f.key === 'status') {
      return {
        field: f.key,
        headerName: f.label,
        hide: !visibleColumnKeys.includes(f.key),
        sortable: true,
        filter: StatusFilter,
        floatingFilter: true,
        floatingFilterComponent: StatusFloatingFilter,
        suppressFloatingFilterButton: true,
        resizable: true,
        flex: 1,
      };
    }
    return {
      field: f.key,
      headerName: f.label,
      hide: !visibleColumnKeys.includes(f.key),
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
    };
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
    gridApi = params.api;
    syncGridColumnVisibility();
    refreshGridHeight();
  }

  function scheduleGridLayout() {
    if (!gridApi) return;
    requestAnimationFrame(() => {
      gridApi.doLayout();
      gridApi.sizeColumnsToFit();
    });
  }

  function refreshGridHeight() {
    if (!browser || !gridContainerEl) {
      scheduleGridLayout();
      return;
    }

    requestAnimationFrame(() => {
      const rect = gridContainerEl.getBoundingClientRect();
      const availableHeight = Math.floor(window.innerHeight - rect.top - 12);
      desktopGridHeight = Math.max(420, availableHeight);
      scheduleGridLayout();
    });
  }

  function syncGridColumnVisibility() {
    if (!gridApi) return;

    const visibleSet = new Set(visibleColumnKeys);
    const visibleKeys = allSongColumns
      .map(column => column.key)
      .filter(key => visibleSet.has(key));
    const hiddenKeys = allSongColumns
      .map(column => column.key)
      .filter(key => !visibleSet.has(key));

    if (visibleKeys.length > 0) {
      gridApi.setColumnsVisible(visibleKeys, true);
    }
    if (hiddenKeys.length > 0) {
      gridApi.setColumnsVisible(hiddenKeys, false);
    }

    if (visibleKeys.length > 0) {
      scheduleGridLayout();
    }
  }

  function toggleColumnVisibility(columnKey) {
    if (visibleColumnKeys.includes(columnKey)) {
      visibleColumnKeys = visibleColumnKeys.filter(key => key !== columnKey);
    } else {
      visibleColumnKeys = [...visibleColumnKeys, columnKey];
    }
    syncGridColumnVisibility();
  }

  function showAllColumns() {
    visibleColumnKeys = allSongColumns.map(column => column.key);
    syncGridColumnVisibility();
  }

  function resetToDefaultColumns() {
    visibleColumnKeys = [...defaultVisibleColumnKeys];
    syncGridColumnVisibility();
  }

  // Wird aufgerufen sobald die ersten Daten im Grid gerendert sind
  function onFirstDataRendered(params) {
    refreshGridHeight();
    // Initalen Status-Filter setzen: 'retired' abwählen
    const allStatuses = [];
    params.api.forEachNode(node => {
      if (node.data?.status && !allStatuses.includes(node.data.status)) {
        allStatuses.push(node.data.status);
      }
    });
    const withoutRetired = allStatuses.filter(s => s !== 'retired');
    if (withoutRetired.length < allStatuses.length) {
      // Nur filtern wenn 'retired' überhaupt existiert
      params.api.setFilterModel({
        status: { values: withoutRetired }
      });
    }
  }

  onMount(() => {
    if (!browser) return;
    const onResize = () => refreshGridHeight();
    window.addEventListener('resize', onResize);

    const resizeObserver = new ResizeObserver(() => {
      refreshGridHeight();
    });

    if (gridContainerEl) {
      resizeObserver.observe(gridContainerEl);
    }

    refreshGridHeight();

    return () => {
      window.removeEventListener('resize', onResize);
      resizeObserver.disconnect();
    };
  });

  function onRowClicked(event) {
    const node = event.node;
    node.setExpanded(!node.expanded);
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
      props: {
        existingSongs: songs
      },
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
      mobileFilter();
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

let vorschlaegeSongs = $state([]);
let totalMusicians = $state(0);

let filteredSongs = $derived(songs
  .filter(song => song.status !== 'vorschlag'
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
      song.status !== 'retired' &&
      song.status !== 'vorschlag' &&
      (
        song.title.toLowerCase().includes(filterStringMobile.toLowerCase()) ||
        song.interpret.toLowerCase().includes(filterStringMobile.toLowerCase())
      )
    );
  }

  function logout() {
        // Wird von apiLogout() gehandhabt
  }

  onMount(async () => {
    try {
      user = await getUser();
    } catch(e) {
      user = { user_name: null, user_group: null, id: null, musician: false };
      error = 'Fehler: ' + (e.message ?? '');
      console.error('Songs load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
    songs = await getSongs();
    vorschlaegeSongs = await getSongsCandidates();
    try {
      const musicianList = await getUserList(null);
      totalMusicians = Array.isArray(musicianList) ? musicianList.length : 0;
    } catch(e) {
      console.error('Konnte Musikerliste nicht laden:', e);
    }
    mobileFilter();
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



<div class="max-w-8xl mx-auto py-3 md:py-4 md:px-4 h-full min-h-full w-full flex flex-col">


  <div class="card bg-surface-2 rounded-2xl shadow-md md:border md:border-outline-variant p-2 md:p-4 lg:p-5 flex-1 flex flex-col min-h-0">


    <div class="flex flex-col md:flex-row md:justify-between md:items-center gap-2 md:gap-3 md:mb-3">
        <div class="flex items-center gap-2 mb-2 md:mb-0">
          <h3 class="h2 text-on-surface">Songs</h3>
          {#if canEdit()}
            <button
              class="btn-icon variant-filled-primary w-8 h-4 rounded-full text-xl leading-none"
              onclick={openNewSongModal}
              title="Neuen Song hinzufügen"
            >+</button>
          {/if}
        </div>
        <button
          class="btn variant-ghost-surface btn-sm mb-2 md:mb-0"
          onclick={() => {
            showHelp = !showHelp;
            refreshGridHeight();
          }}
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
              <li><strong>Abstimmungsergebnis:</strong> ∑ abgegebene / Stimmberechtigte – plus farbige Badges für Ja, Nein und Enthaltungen</li>
              <li><strong>Quorum:</strong> Mindestens 75 % aller Stimmberechtigten müssen abgestimmt haben</li>
              <li><strong>Freigabe-Button ✓ (grün):</strong> Erscheint für Admins/Editoren sobald Quorum erreicht und ≥ 50 % Ja-Stimmen vorliegen</li>
              <li><strong>Nur Admins/Editoren</strong> können Vorschläge final übernehmen</li>
            </ul>
          </div>

          <!-- Archivierte Songs -->
          <div>
            <h4 class="font-semibold text-error-500 mb-2">📦 Archivierte Songs</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>Songs mit Status "Archiviert" werden standardmäßig ausgeblendet</li>
              <li>Über den <strong>Status-Filter</strong> in der Tabellenspalte kannst du "retired" hinzuwählen</li>
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


    <!-- Tab-Navigation -->
    <div class="flex border-b border-surface-300 dark:border-surface-600 mb-2 gap-1">
      <button onclick={() => { tabSet = 1; refreshGridHeight(); }} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 1 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'} {vorschlaegeSongs.length > 0 ? 'font-bold' : ''}">
        <span>Vorschläge ({vorschlaegeSongs.length})</span>
      </button>

      <button onclick={() => { tabSet = 0; refreshGridHeight(); }} class="px-4 py-2 rounded-t-lg transition-colors {tabSet === 0 ? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500' : 'hover:bg-surface-100 dark:hover:bg-surface-800'}">
        <span>Songs ({filteredSongs.length})</span>
      </button>
    </div>
    <div class="flex-1 min-h-0 flex flex-col">

      <div class="mt-2 flex-1 min-h-0 flex flex-col">
        {#if tabSet === 0}
          <!-- Tab 1: Songs -->

          {#if error}
            <div class="alert alert-danger">{error}</div>
          {/if}

          <div class="hidden md:flex md:flex-col md:flex-1 md:min-h-0"> <!-- Tabelle nur ab md sichtbar -->
            <details class="mb-3 rounded-lg border border-surface-300 dark:border-surface-600 bg-surface-100 dark:bg-surface-800" ontoggle={refreshGridHeight}>
              <summary class="cursor-pointer px-4 py-2 font-semibold">Spaltenauswahl</summary>
              <div class="px-4 pb-4 pt-2">
                <div class="mb-3 flex items-center gap-2">
                  <button
                    type="button"
                    class="btn btn-sm variant-soft-primary"
                    onclick={showAllColumns}
                  >Alle anzeigen</button>
                  <button
                    type="button"
                    class="btn btn-sm variant-soft-secondary"
                    onclick={resetToDefaultColumns}
                  >Standardansicht</button>
                </div>
                <div class="grid grid-cols-2 lg:grid-cols-4 gap-2">
                  {#each allSongColumns as column}
                    <label class="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        checked={visibleColumnKeys.includes(column.key)}
                        onchange={() => toggleColumnVisibility(column.key)}
                      />
                      <span>{column.label}</span>
                    </label>
                  {/each}
                </div>
              </div>
            </details>

            <div
              class="ag-theme-alpine flex-1 min-h-[420px]"
              bind:this={gridContainerEl}
              style="height: {desktopGridHeight}px; width: 100%;"
            >
              <AgGrid
                  {rowData}
                  {columnDefs}
                  onRowClicked={handleRowClick}
                  {onGridReady}
                  {onFirstDataRendered}
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
            {#each filteredSongsMobile as song (song.id)}
              <div class="card variant-filled-surface rounded-xl shadow-sm p-4 bg-surface-50">
                <div class="flex justify-between items-start">
                  <h3 class="text-lg font-semibold text-primary-800 dark:text-primary-200">{song.title}</h3>
                  <button class="btn btn-sm variant-tonal" onclick={() => openSongDetailsModal(song)}>

                      <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd"></path>
                      </svg>

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
                      <span><strong>Digitale Abstimmung:</strong> Ein Song ist zur Übernahme freigegeben, wenn (a) der Ja-Anteil unter den gültigen Stimmen (Ja+Nein) ≥50% beträgt, (b) mindestens 4 gültige Stimmen abgegeben wurden (Enthaltungen zählen nicht) und (c) mindestens 90% aller Stimmberechtigten abgestimmt haben</span>
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
                    <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">Titel</th>
                    <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">Interpret</th>
                    <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">Abstimmung</th>
                    {#if canEdit()}
                      <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200">Aktion</th>
                    {/if}
                  </tr>
                </thead>
                <tbody>
                  {#each vorschlaegeSongs as song (song.id)}
                    {@const userFeedbackType = getUserFeedback(song.feedbacks)}
                    {@const stats = getFeedbackStats(song.feedbacks)}
                    {@const validVotes = stats.absolute.a + stats.absolute.na + stats.absolute.o}
                    {@const validYesNo = stats.absolute.a + stats.absolute.na}
                    {@const quorumTarget = totalMusicians > 0 ? Math.max(3, Math.floor(totalMusicians * 0.75)) : null}
                    {@const quorumReached = quorumTarget === null || validVotes >= quorumTarget}
                    {@const canAccept = quorumReached && stats.absolute.a >= validYesNo / 2 && validYesNo > 0}
                    <tr class="song-row dark:hover:bg-surface-700 cursor-pointer transition-colors text-surface-900 dark:text-surface-100 hover:bg-surface-300 rounded-lg"
                        onclick={() => toggleExpand(song.id)}>
                        <td class="px-3 py-3" onclick={() => openSongDetailsModal(song)}>{song.title}</td>
                        <td class="px-3 py-3" onclick={() => openSongDetailsModal(song)}>{song.interpret}</td>
                       <td class="px-2 py-3">
                            <div class="vote-summary flex flex-col items-start gap-1 md:flex-row md:items-center md:flex-wrap">
                                <!-- Gesamtstimmen und Quorum-Fortschritt -->
                                <span class="vote-total" title="{validVotes} von {totalMusicians} Stimmberechtigten haben abgestimmt{quorumTarget ? ` (Quorum: ${quorumTarget} = 75%)` : ''}">
                                    ∑ {validVotes} / {totalMusicians > 0 ? totalMusicians : '?'}
                                </span>
                                <!-- Ja-Stimmen -->
                                <button
                                    type="button"
                                    class="w-20 justify-center vote-badge vote-btn vote-yes {userFeedbackType === 'a' ? 'is-selected' : ''}"
                                    title="Ja stimmen"
                                    onclick={(e) => {
                                      e.stopPropagation();
                                      if (user?.musician) submitFeedback(song, 'a');
                                    }}
                                    disabled={!user?.musician}
                                >
                                    👍 {stats.absolute.a}
                                    {#if stats.absolute.a + stats.absolute.na > 0}
                                        <span class="vote-pct">({stats.relative.a}%)</span>
                                    {/if}
                                </button>
                                <!-- Nein-Stimmen -->
                                <button
                                    type="button"
                                    class="w-20 justify-center vote-badge vote-btn vote-no {userFeedbackType === 'na' ? 'is-selected' : ''}"
                                    title="Nein stimmen"
                                    onclick={(e) => {
                                      e.stopPropagation();
                                      if (user?.musician) submitFeedback(song, 'na');
                                    }}
                                    disabled={!user?.musician}
                                >
                                    👎 {stats.absolute.na}
                                    {#if stats.absolute.a + stats.absolute.na > 0}
                                        <span class="vote-pct">({stats.relative.na}%)</span>
                                    {/if}
                                </button>
                                <!-- Enthaltungen -->
                                {#if stats.absolute.o > 0 || user?.musician}
                                    <button
                                        type="button"
                                        class="w-20 justify-center vote-badge vote-btn vote-abstain {userFeedbackType === 'o' ? 'is-selected' : ''}"
                                        title="Enthaltung"
                                        onclick={(e) => {
                                          e.stopPropagation();
                                          if (user?.musician) submitFeedback(song, 'o');
                                        }}
                                        disabled={!user?.musician}
                                    >
                                        🤷 {stats.absolute.o}
                                    </button>
                                {/if}
                            </div>
                       </td>
                       {#if canEdit() && canAccept}
                            <td class="px-3 py-3">
                                <button
                                    class="btn variant-filled-success rounded-lg px-3 py-0 text-base font-semibold"
                                    onclick={() => acceptSong(song)}
                                >
                                    ✓
                                </button>
                            </td>
                        {:else}
                            <td class="px-3 py-3">
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
  /* Vote-Summary: kompakte Badge-Anzeige für Abstimmungsergebnisse */
  .vote-summary {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 5px;
  }

  .vote-total {
    font-size: 0.78rem;
    font-weight: 600;
    color: inherit;
    white-space: nowrap;
  }

  .vote-badge {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    padding: 1px 7px;
    border-radius: 999px;
    font-size: 0.78rem;
    font-weight: 600;
    white-space: nowrap;
  }

  .vote-btn {
    cursor: pointer;
    transition: transform 120ms ease, filter 120ms ease;
  }

  .vote-btn:hover:not(:disabled) {
    filter: brightness(1.05);
    transform: translateY(-1px);
  }

  .vote-btn:disabled {
    cursor: default;
    opacity: 0.85;
  }

  .vote-btn.is-selected {
    box-shadow: inset 0 0 0 1px currentColor;
    filter: saturate(1.2);
  }

  .vote-yes {
    background-color: rgba(34, 197, 94, 0.18);
    color: #16a34a;
    border: 1px solid rgba(34, 197, 94, 0.4);
  }
  :global(.dark) .vote-yes {
    background-color: rgba(34, 197, 94, 0.2);
    color: #4ade80;
    border-color: rgba(74, 222, 128, 0.35);
  }

  .vote-no {
    background-color: rgba(239, 68, 68, 0.15);
    color: #dc2626;
    border: 1px solid rgba(239, 68, 68, 0.35);
  }
  :global(.dark) .vote-no {
    background-color: rgba(239, 68, 68, 0.2);
    color: #f87171;
    border-color: rgba(248, 113, 113, 0.35);
  }

  .vote-abstain {
    background-color: rgba(234, 179, 8, 0.13);
    color: #a16207;
    border: 1px solid rgba(234, 179, 8, 0.3);
  }
  :global(.dark) .vote-abstain {
    background-color: rgba(234, 179, 8, 0.18);
    color: #fde047;
    border-color: rgba(253, 224, 71, 0.3);
  }

  .vote-pct {
    font-weight: 400;
    opacity: 0.8;
    font-size: 0.72rem;
  }

  /* Dezente gestrichelte Trennlinie zwischen Vorschlags-Zeilen */
  .song-row td {
    border-bottom: 1px dashed rgba(148, 163, 184, 0.45);
  }

  :global(.dark) .song-row td {
    border-bottom-color: rgba(148, 163, 184, 0.3);
  }


</style>

