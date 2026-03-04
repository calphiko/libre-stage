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
  import { onMount, onDestroy } from 'svelte';
  import { createGrid, ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';

  if (!ModuleRegistry.__registeredModules) {
    ModuleRegistry.registerModules([AllCommunityModule]);
  }

  let { rowData = [], columnDefs = [], onRowClicked = null, onGridReady = null, onFirstDataRendered = null } = $props();


  let gridDiv;
  let gridApi;
  let isDark = $state(false);

  function updateTheme() {
    isDark = document.documentElement.classList.contains('dark') ||
             document.documentElement.getAttribute('data-theme') === 'dark';

    if (gridApi) {
      gridApi.updateGridOptions({
        theme: getThemeConfig()
      });
    }
  }

  function getThemeConfig() {
  return themeQuartz.withParams({
    // Skeleton Surface Colors
    backgroundColor: isDark ? 'rgb(var(--color-surface-900))' : 'rgb(var(--color-surface-50))',
    foregroundColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',

    // Header
    headerBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-100))',
    headerFontWeight: 600,
    headerTextColor: isDark ? 'rgb(var(--color-surface-200))' : 'rgb(var(--color-surface-700))',

    // Rows
    oddRowBackgroundColor: isDark ? 'rgb(var(--color-surface-850))' : 'rgb(var(--color-surface-100))',

    // Hover & Selection
    rowHoverColor: isDark ? 'rgb(var(--color-primary-800) / 0.3)' : 'rgb(var(--color-primary-200) / 0.5)',
    selectedRowBackgroundColor: isDark ? 'rgb(var(--color-primary-900) / 0.5)' : 'rgb(var(--color-primary-100))',

    // Borders
    borderColor: isDark ? 'rgb(var(--color-surface-700))' : 'rgb(var(--color-surface-300))',

    // Filter Row
    floatingFiltersHeight: 40,
    headerHeight: 40,

    // Filter Inputs
    inputBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-100))',
    inputBorderColor: isDark ? 'rgb(var(--color-surface-600))' : 'rgb(var(--color-surface-400))',
    inputFocusBorderColor: isDark ? 'rgb(var(--color-primary-500))' : 'rgb(var(--color-primary-600))',
    inputTextColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',

    // Filter Popup Panel
    panelBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-50))',
    dialogBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-50))',
    menuBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-50))',
    menuTextColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',
    menuBorder: isDark ? '1px solid rgb(var(--color-surface-600))' : '1px solid rgb(var(--color-surface-300))',
    menuSeparatorColor: isDark ? 'rgb(var(--color-surface-600))' : 'rgb(var(--color-surface-300))',
    filterToolPanelGroupBorder: isDark ? 'rgb(var(--color-surface-600))' : 'rgb(var(--color-surface-300))',

    // Spacing
    spacing: 8,
    borderRadius: 12,
    wrapperBorderRadius: 12,

    // Font
    fontSize: 14,
    fontFamily: 'inherit'
  });
}

  onMount(() => {
    updateTheme();

    gridApi = createGrid(gridDiv, {
      theme: getThemeConfig(),
      columnDefs,
      rowData,
      defaultColDef: {
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
        }
      },
      onRowClicked: (event) => {
        if (onRowClicked) {
          onRowClicked(event);
        }
      },
      onGridReady: (params) => {
        if (onGridReady) {
          onGridReady(params);
        }
      },
      onFirstDataRendered: (params) => {
        if (onFirstDataRendered) {
          onFirstDataRendered(params);
        }
      },
      suppressRowHoverHighlight: false,
      rowSelection: { mode: 'singleRow' }
    });

    const observer = new MutationObserver(updateTheme);
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class', 'data-theme']
    });

    return () => observer.disconnect();
  });

  onDestroy(() => {
    if (gridApi) {
      gridApi.destroy();
    }
  });

  $effect(() => {
    if (gridApi) {
      gridApi.setGridOption('rowData', rowData);
    }
  });

  $effect(() => {
    if (gridApi) {
      gridApi.setGridOption('columnDefs', columnDefs);
    }
  });
</script>

<div bind:this={gridDiv} style="height: 600px; width: 100%;"></div>

<style>
  /* Floating Filter Inputs (Textfelder in der Filter-Zeile) */
  :global(.ag-text-field-input),
  :global(.ag-input-field-input) {
    background-color: #f8fafc !important;
    color: #0f172a !important;
    border: 1px solid #cbd5e1 !important;
    border-radius: 6px !important;
    padding: 6px 10px !important;
    font-size: 13px !important;
    transition: border-color 0.15s, box-shadow 0.15s !important;
  }

  :global(.dark .ag-text-field-input),
  :global(.dark .ag-input-field-input) {
    background-color: #1e293b !important;
    color: #f8fafc !important;
    border: 1px solid #475569 !important;
  }

  :global(.ag-text-field-input:focus),
  :global(.ag-input-field-input:focus) {
    border-color: #3b82f6 !important;
    outline: none !important;
    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2) !important;
  }

  :global(.dark .ag-text-field-input:focus),
  :global(.dark .ag-input-field-input:focus) {
    border-color: #60a5fa !important;
    box-shadow: 0 0 0 2px rgba(96, 165, 250, 0.25) !important;
  }

  :global(.ag-text-field-input::placeholder),
  :global(.ag-input-field-input::placeholder) {
    color: #94a3b8 !important;
    opacity: 0.8 !important;
  }

  :global(.dark .ag-text-field-input::placeholder),
  :global(.dark .ag-input-field-input::placeholder) {
    color: #64748b !important;
  }

  /* Floating-Filter-Zeile Hintergrund */
  :global(.ag-floating-filter-body) {
    background-color: transparent !important;
  }

  /* Custom Status-Filter Select in Floating Filter */
  :global(.ag-floating-filter button) {
    background-color: #f8fafc !important;  /* surface-50 */
    color: #0f172a !important;  /* surface-900 */
    border: 1px solid #cbd5e1 !important;  /* surface-300 */
  }

  :global(.dark .ag-floating-filter button) {
    background-color: #1e293b !important;  /* surface-800 */
    color: #f8fafc !important;  /* surface-50 */
    border: 1px solid #475569 !important;  /* surface-600 */
  }

  :global(.ag-floating-filter button:hover) {
    background-color: #f1f5f9 !important;  /* surface-100 */
  }

  :global(.dark .ag-floating-filter button:hover) {
    background-color: #334155 !important;  /* surface-700 */
  }

  /* Filter-Popup Hintergrund */
  :global(.ag-filter),
  :global(.ag-filter-toolpanel-instance),
  :global(.ag-popup-child) {
    background-color: rgb(var(--color-surface-50)) !important;
    color: rgb(var(--color-surface-900)) !important;
    border: 1px solid rgb(var(--color-surface-300)) !important;
    border-radius: 8px !important;
    box-shadow: 0 4px 16px rgb(0 0 0 / 0.12) !important;
  }

  :global(.dark .ag-filter),
  :global(.dark .ag-filter-toolpanel-instance),
  :global(.dark .ag-popup-child) {
    background-color: rgb(var(--color-surface-800)) !important;
    color: rgb(var(--color-surface-50)) !important;
    border: 1px solid rgb(var(--color-surface-600)) !important;
    box-shadow: 0 4px 16px rgb(0 0 0 / 0.3) !important;
  }

  /* Custom Status-Filter Popup Styling */
  :global(.ag-status-filter) {
    background-color: rgb(var(--color-surface-50)) !important;
    color: rgb(var(--color-surface-900)) !important;
  }

  :global(.dark .ag-status-filter) {
    background-color: rgb(var(--color-surface-800)) !important;
    color: rgb(var(--color-surface-50)) !important;
  }

  /* Floating-Filter Status-Popup (das im Floating-Filter aufpoppt) */
  :global(.ag-status-floating-popup) {
    background-color: rgb(var(--color-surface-50)) !important;
    color: rgb(var(--color-surface-900)) !important;
    border: 1px solid rgb(var(--color-surface-300)) !important;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12) !important;
  }

  :global(.dark .ag-status-floating-popup) {
    background-color: rgb(var(--color-surface-800)) !important;
    color: rgb(var(--color-surface-50)) !important;
    border: 1px solid rgb(var(--color-surface-600)) !important;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3) !important;
  }

  :global(.ag-status-filter input[type="checkbox"]) {
    accent-color: rgb(var(--color-primary-500));
  }

  :global(.ag-status-filter #resetBtn) {
    background-color: rgb(var(--color-primary-500)) !important;
    color: white !important;
  }

  :global(.ag-status-filter #resetBtn:hover) {
    background-color: rgb(var(--color-primary-600)) !important;
  }

  /* Labels und Text im Filter-Popup */
  :global(.ag-filter label),
  :global(.ag-filter .ag-label),
  :global(.ag-filter .ag-filter-condition-operator),
  :global(.ag-popup-child label),
  :global(.ag-popup-child .ag-label) {
    color: #0f172a !important;  /* surface-900 */
  }

  :global(.dark .ag-filter label),
  :global(.dark .ag-filter .ag-label),
  :global(.dark .ag-popup-child label),
  :global(.dark .ag-popup-child .ag-label) {
    color: #f8fafc !important;  /* surface-50 */
  }

  /* Buttons im Filter-Popup */
  :global(.ag-filter .ag-standard-button) {
    background-color: #3b82f6 !important;  /* primary-500 */
    color: white !important;
    border-radius: 6px !important;
    border: none !important;
    padding: 4px 12px !important;
    cursor: pointer !important;
  }

  :global(.ag-filter .ag-standard-button:hover) {
    background-color: #2563eb !important;  /* primary-600 */
  }
</style>
