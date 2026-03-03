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
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { createGrid, ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
  import { getUser, adminUpdateUser, adminGetAllUsers, logout as apiLogout} from '$lib/api.js';
  import { triggerSendPwResetToken } from '$lib/api_pw_reset.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';

  const { showError, showSuccess, showWarning } = createMessageHelpers();


  if (!ModuleRegistry.__registeredModules) {
    ModuleRegistry.registerModules([AllCommunityModule]);
  }

  let users = [];
    let gridDiv;
  let gridApi;
  let isDark = false;
  let error = '';

  const columnDefs = [
    {
      field: 'user_name',
      headerName: 'Username',
      headerTooltip: 'Eindeutiger Benutzername für Login. Darf nicht doppelt vorkommen.',
      editable: true,
      filter: 'agTextColumnFilter'
    },
    {
      field: 'clear_name',
      headerName: 'Klarname',
      editable: true,
      filter: 'agTextColumnFilter'
    },
    {
      field: 'email',
      headerName: 'Email',
      headerTooltip: 'Muss zwingend eine gültige Email-Adresse sein.',
      editable: true,
      filter: 'agTextColumnFilter'
    },
    {
      field: 'mm_username',
      headerName: 'Mattermost Username',
      headerTooltip: 'Für benachrichtigungen via Mattermost.',
      editable: true,
      filter: 'agTextColumnFilter'
    },
    {
      field: 'user_group',
      headerName: 'Rolle',
      headerTooltip: 'Admin: Volle Rechte, Editor: Bearbeiten, User: Nur Lesen',
      editable: true,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: {
        values: ['admin', 'editor', 'user']
      },
      filter: 'agTextColumnFilter'
    },
    {
      field: 'musician',
      headerName: 'Ist Musiker?',
      headerTooltip: 'Gibt an, ob der Benutzer Musiker ist. Nur Musiker haben in Abstimmungen ein Stimmrecht.',
      editable: true,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: {
        values: [1, 0],
        labels: ['Ja', 'Nein']
      },
      filter: 'agTextColumnFilter'
    },
     {
      field: 'is_singer',
      headerName: 'Ist Sänger?',
      headerTooltip: 'Gibt an, ob der Benutzer Sänger ist. Falls ja, taucht er als Option als Sänger für einen Song auf.',
      editable: true,
      cellEditor: 'agSelectCellEditor',
      cellEditorParams: {
        values: [1, 0],
        labels: ['Ja', 'Nein']
      },
      filter: 'agTextColumnFilter'
    },
    {
        field: 'password_reset',
        headerName: 'Passwort zurücksetzen',
        headerTooltip: 'Sendet dem Benutzer einen Link zum Zurücksetzen des Passworts',
        cellRenderer: (params) => {
          const button = document.createElement('button');
          button.innerText = 'Reset Password';
          button.className = 'btn btn-sm variant-filled-warning';
          button.addEventListener('click', async () => {
            try {
              await triggerSendPwResetToken(params.data.id);
              showSuccess(`Passwort-Reset-Link an ${params.data.email} gesendet`);
            } catch (e) {
              showError('Passwort-Reset konnte nicht gesendet werden' + (e.message ? `: ${e.message}` : ''));
            }
          });
          return button;
        },
        filter: false,
        sortable: false,
        editable: false,
        flex: 0,
        minWidth: 180
    }
  ];

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
      backgroundColor: isDark ? 'rgb(var(--color-surface-900))' : 'rgb(var(--color-surface-50))',
      foregroundColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',
      headerBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-100))',
      headerFontWeight: 600,
      headerTextColor: isDark ? 'rgb(var(--color-surface-200))' : 'rgb(var(--color-surface-700))',
      oddRowBackgroundColor: isDark ? 'rgb(var(--color-surface-850))' : 'rgb(var(--color-surface-100))',
      rowHoverColor: isDark ? 'rgb(var(--color-primary-800) / 0.3)' : 'rgb(var(--color-primary-200) / 0.5)',
      selectedRowBackgroundColor: isDark ? 'rgb(var(--color-primary-900) / 0.5)' : 'rgb(var(--color-primary-100))',
      borderColor: isDark ? 'rgb(var(--color-surface-700))' : 'rgb(var(--color-surface-300))',
      floatingFiltersHeight: 40,
      headerHeight: 40,
      inputBackgroundColor: isDark ? 'rgb(var(--color-surface-800))' : 'rgb(var(--color-surface-100))',
      inputBorderColor: isDark ? 'rgb(var(--color-surface-600))' : 'rgb(var(--color-surface-400))',
      inputFocusBorderColor: isDark ? 'rgb(var(--color-primary-500))' : 'rgb(var(--color-primary-600))',
      inputTextColor: isDark ? 'rgb(var(--color-surface-50))' : 'rgb(var(--color-surface-900))',
      spacing: 8,
      borderRadius: 12,
      wrapperBorderRadius: 12,
      fontSize: 14,
      fontFamily: 'inherit'
    });
  }

  async function onCellValueChanged(event) {
    try {
      const updatedUser = event.data;
      await adminUpdateUser(null, updatedUser);
      showSuccess('Benutzer erfolgreich aktualisiert');
    } catch (e) {
      showError('Benutzer konnte nicht aktualisiert werden');
      users = await adminGetAllUsers(null);
      event.api.refreshCells({ rowNodes: [event.node], force: true });
    }
  }

  onMount(async () => {

    try {
      await getUser();
      users = await adminGetAllUsers(null);
    } catch (e) {
      error = 'User konnten nicht geladen werden';
      console.error('UserAdminTable load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }

    updateTheme();

    gridApi = createGrid(gridDiv, {
      theme: getThemeConfig(),
      columnDefs,
      enableBrowserTooltips: true,
      rowData: users,
      defaultColDef: {
        sortable: true,
        filter: 'agTextColumnFilter',
        floatingFilter: true,
        resizable: true,
        flex: 1,
        minWidth: 100,
        filterParams: {
          filterOptions: ['contains'],
          suppressAndOrCondition: true,
          debounceMs: 200,
          buttons: ['reset']
        }
      },
      onCellValueChanged,
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

  $effect(() => { if (gridApi && users.length > 0) {
    gridApi.setGridOption('rowData', users);
  }
  });
</script>

<div bind:this={gridDiv} style="height: 500px; width: 100%;"></div>

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
