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
  import { onMount, onDestroy, mount, unmount } from 'svelte';
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { createGrid, ModuleRegistry, AllCommunityModule, themeQuartz } from 'ag-grid-community';
  import { getUser, adminUpdateUser, adminGetAllUsers, adminCreateUser, adminDeleteUser, logout as apiLogout} from '$lib/api.js';
  import { triggerSendPwResetToken } from '$lib/api_pw_reset.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import ToggleCellRenderer from '$lib/components/ToggleCellRenderer.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import { modalState } from '$lib/modalState.js';

  const { showError, showSuccess, showWarning } = createMessageHelpers();

  if (!ModuleRegistry.__registeredModules) {
    ModuleRegistry.registerModules([AllCommunityModule]);
  }

  let users = $state([]);
  let gridDiv;
  let gridApi;
  let isDark = false;
  let error = '';

  let showCreateForm = $state(false);
  let creating = $state(false);
  let nu_user_name = $state('');
  let nu_clear_name = $state('');
  let nu_email = $state('');
  let nu_user_pw = $state('');
  let nu_user_group = $state('user');
  let nu_musician = $state(false);
  let nu_is_singer = $state(false);

  function resetNewUser() {
    nu_user_name = '';
    nu_clear_name = '';
    nu_email = '';
    nu_user_pw = '';
    nu_user_group = 'user';
    nu_musician = false;
    nu_is_singer = false;
  }

  async function createUser() {
    if (!nu_user_name || !nu_user_pw || !nu_email) {
      showError('Bitte Username, E-Mail und Passwort ausfüllen');
      return;
    }
    creating = true;
    try {
      await adminCreateUser(null, {
        user_name: nu_user_name,
        clear_name: nu_clear_name,
        email: nu_email,
        user_pw: nu_user_pw,
        user_group: nu_user_group,
        musician: nu_musician,
        is_singer: nu_is_singer,
      });
      users = await adminGetAllUsers(null);
      gridApi?.setGridOption('rowData', users);
      showSuccess(`Benutzer „${nu_user_name}" angelegt`);
      resetNewUser();
      showCreateForm = false;
    } catch (e) {
      showError(e.message ?? 'Anlegen fehlgeschlagen');
    } finally {
      creating = false;
    }
  }

  async function deleteUser(id, name) {
    modalState.trigger({
      component: ConfirmModal,
      meta: {
        title: 'Benutzer löschen',
        message: `Möchtest du den Benutzer „${name}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`,
        confirmText: 'Löschen',
        cancelText: 'Abbrechen',
      },
      response: async (confirmed) => {
        if (!confirmed) return;
        try {
          await adminDeleteUser(null, id);
          users = await adminGetAllUsers(null);
          gridApi?.setGridOption('rowData', users);
          showSuccess(`Benutzer „${name}" gelöscht`);
        } catch (e) {
          showError(e.message ?? 'Löschen fehlgeschlagen');
        }
      }
    });
  }

  const makeToggleRenderer = (field) => {
      return class {
        init(params) {
          this._wrapper = document.createElement('div');
          this._wrapper.style.cssText = 'display:flex;align-items:center;height:100%;';
          this._component = mount(ToggleCellRenderer, {
            target: this._wrapper,
            props: {
              checked: params.value == 1,
              onChange: async (newChecked) => {
                const newValue = newChecked ? 1 : 0;
                params.node.setDataValue(field, newValue);
                try {
                  await adminUpdateUser(null, { ...params.data, [field]: newValue });
                  showSuccess('Gespeichert');
                } catch (e) {
                  showError('Konnte nicht gespeichert werden');
                }
              }
            }
          });
        }

        getGui() {
          return this._wrapper;
        }

        destroy() {
          if (this._component) unmount(this._component);
        }
      };
    };

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
      editable: false,
      filter: 'agTextColumnFilter',
      cellRenderer: makeToggleRenderer('musician'),
      minWidth: 130
    },
    {
      field: 'is_singer',
      headerName: 'Ist Sänger?',
      headerTooltip: 'Gibt an, ob der Benutzer Sänger ist. Falls ja, taucht er als Option als Sänger für einen Song auf.',
      editable: false,
      filter: 'agTextColumnFilter',
      cellRenderer: makeToggleRenderer('is_singer'),
      minWidth: 130
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
    },
    {
        field: 'delete',
        headerName: 'Löschen',
        cellRenderer: (params) => {
          const button = document.createElement('button');
          button.innerText = '🗑️';
          button.className = 'btn btn-sm variant-filled-error';
          button.title = 'Benutzer löschen';
          button.addEventListener('click', () => deleteUser(params.data.id, params.data.user_name));
          return button;
        },
        filter: false,
        sortable: false,
        editable: false,
        flex: 0,
        minWidth: 90
    }
  ];

  function updateTheme() {
    isDark = document.documentElement.classList.contains('dark') ||
             document.documentElement.getAttribute('data-theme') === 'dark';

    if (gridApi) {
      gridApi.updateGridOptions({
        theme: getThemeConfig(),
        columnDefs,
        enableBrowserTooltips: true,
        rowData: users,
        rowHeight: 52,
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

  $effect(() => { if (gridApi && users.length > 0) {
    gridApi.setGridOption('rowData', users);
  }
  });
</script>

<div class="mb-3 flex items-center gap-3">
  <button
    class="btn-icon variant-filled-primary w-8 h-4 rounded-full text-xl leading-none"
    onclick={() => showCreateForm = !showCreateForm}
    title="Neuen Benutzer anlegen"
  >+</button>
  <span class="text-sm text-on-surface-variant">Neuen Benutzer anlegen</span>
</div>

{#if showCreateForm}
  <form
    class="mb-4 p-4 border border-outline-variant rounded-xl bg-surface-1 grid grid-cols-1 md:grid-cols-2 gap-3"
    onsubmit={(e) => { e.preventDefault(); createUser(); }}
  >
    <input class="input rounded-lg px-3 py-2" type="text" bind:value={nu_user_name} placeholder="Username *" required />
    <input class="input rounded-lg px-3 py-2" type="text" bind:value={nu_clear_name} placeholder="Klarname" />
    <input class="input rounded-lg px-3 py-2" type="email" bind:value={nu_email} placeholder="E-Mail *" required />
    <input class="input rounded-lg px-3 py-2" type="password" bind:value={nu_user_pw} placeholder="Passwort *" required />
    <select class="input rounded-lg px-3 py-2" bind:value={nu_user_group}>
      <option value="user">user</option>
      <option value="editor">editor</option>
      <option value="admin">admin</option>
    </select>
    <div class="flex flex-col gap-2">
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={nu_musician} />
        Ist Musiker
      </label>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={nu_is_singer} />
        Ist Sänger
      </label>
    </div>
    <div class="md:col-span-2 flex gap-2">
      <button class="btn variant-filled-primary btn-sm" type="submit" disabled={creating}>
        {creating ? 'Anlegen…' : 'Benutzer anlegen'}
      </button>
      <button class="btn variant-ghost-surface btn-sm" type="button" onclick={() => { showCreateForm = false; resetNewUser(); }}>
        Abbrechen
      </button>
    </div>
  </form>
{/if}

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

  :global(.ag-cell [data-part="control"]) {
    display: flex !important;
    align-items: center !important;
  }
</style>
