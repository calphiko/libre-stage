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
  import { onMount, onDestroy } from 'svelte';
  import { createGrid, ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';

  if (!ModuleRegistry.__registeredModules) {
    ModuleRegistry.registerModules([AllCommunityModule]);
  }

  export let rowData = [];
  export let columnDefs = [];
  export let onRowClicked = null;

  let gridDiv;
  let gridApi;
  let isDark = false;

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

    // Filter Row Background (das fehlte!)
    floatingFiltersHeight: 40,
    headerHeight: 40,

    // Filter Inputs
    inputBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-100))',
    inputBorderColor: isDark ? 'rgb(var(--color-surface-600))' : 'rgb(var(--color-surface-400))',
    inputFocusBorderColor: isDark ? 'rgb(var(--color-primary-500))' : 'rgb(var(--color-primary-600))',
    inputTextColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',

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
      suppressRowHoverHighlight: false,
      rowSelection: 'single'
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

  $: if (gridApi) {
    gridApi.setGridOption('rowData', rowData);
  }

  $: if (gridApi) {
    gridApi.setGridOption('columnDefs', columnDefs);
  }
</script>

<div bind:this={gridDiv} style="height: 600px; width: 100%;"></div>

<style>
  :global(.ag-text-field-input),
  :global(.ag-input-field-input) {
    background-color: rgb(var(--color-surface-200)) !important;
    color: rgb(var(--color-surface-900)) !important;
    border: 2px solid rgb(var(--color-surface-400)) !important;
    border-radius: 8px !important;
    padding: 6px 12px !important;
    font-size: 14px !important;
  }

  :global(.dark .ag-text-field-input),
  :global(.dark .ag-input-field-input) {
    background-color: rgb(var(--color-surface-700)) !important;
    color: rgb(var(--color-surface-50)) !important;
    border: 2px solid rgb(var(--color-surface-500)) !important;
  }

  :global(.ag-text-field-input:focus),
  :global(.ag-input-field-input:focus) {
    border-color: rgb(var(--color-primary-600)) !important;
    outline: 2px solid rgb(var(--color-primary-600) / 0.3) !important;
    outline-offset: 2px !important;
    box-shadow: 0 0 0 3px rgb(var(--color-primary-600) / 0.1) !important;
  }

  :global(.dark .ag-text-field-input:focus),
  :global(.dark .ag-input-field-input:focus) {
    border-color: rgb(var(--color-primary-500)) !important;
    outline: 2px solid rgb(var(--color-primary-500) / 0.3) !important;
    box-shadow: 0 0 0 3px rgb(var(--color-primary-500) / 0.1) !important;
  }

  :global(.ag-text-field-input::placeholder),
  :global(.ag-input-field-input::placeholder) {
    color: rgb(var(--color-surface-500)) !important;
    opacity: 0.7 !important;
  }
</style>
