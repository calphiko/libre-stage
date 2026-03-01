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
  import { getUser, updateUser, changePasswordByUser, getUserList, logout as apiLogout} from '$lib/api.js';
  import ThemeSwitcher from '$lib/components/ThemeSwitcher.svelte';
  import UserAdminTable from '$lib/components/UserAdminTable.svelte';
  import PasswordChange from '$lib/components/PasswordChange.svelte';


    let user = {};
  let showHelp = false;

  let edit = {
    user_name: false,
    clear_name: false,
    user_group: false,
    email: false,
  };

  let temp = {
    user_name: "",
    clear_name: "",
    user_group: "",
    email: "",
  };

   // API-Update-Funktion (Beispiel: anpassen für echte API-Aufrufe)
  async function updateUserField(field) {
    user[field] = temp[field];
    user = await updateUser(null, user);
    edit[field] = false;
  }

  function toggleEdit(field) {
    if (edit[field]) {
      updateUserField(field);
    } else {
      temp[field] = user[field];
      edit[field] = true;
    }
  }


  onMount(async () => {
    try {
      user = await getUser();


        temp = {
            user_name: user.user_name,
            clear_name: user.clear_name,
            user_group: user.user_group,
            email: user.email,
        };
    } catch(e) {
      error = 'User konnten nicht geladen werden';
      console.error('Benutzer load error:', e);
      // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
  });


  $: isAdmin = user && (user.user_group === 'admin');

</script>

<div class="card max-w-7xl mx-auto my-7 px-5 py-6 bg-surface-1 rounded-xl shadow border border-outline-variant">
  <div class="flex items-center justify-between mb-4">
    <h2 class="h2 text-on-surface">Benutzerverwaltung</h2>
    <button
      class="btn variant-ghost-surface btn-sm"
      on:click={() => showHelp = !showHelp}
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
      <h3 class="h4 font-bold mb-4">👤 Anleitung: Benutzerverwaltung</h3>

      <div class="space-y-4">
        <!-- Profil -->
        <div>
          <h4 class="font-semibold text-primary-500 mb-2">👤 Dein Profil</h4>
          <ul class="list-disc list-inside space-y-1 text-sm">
            <li><strong>Klarname bearbeiten:</strong> Klicke auf ✎ neben dem Klarname-Feld, bearbeite den Namen und klicke auf ✔</li>
            <li><strong>Email bearbeiten:</strong> Klicke auf ✎ neben dem Email-Feld, bearbeite die Email und klicke auf ✔</li>
            <li><strong>Username & Berechtigung:</strong> Diese Felder können nur von Admins geändert werden</li>
          </ul>
        </div>

        <!-- Passwort -->
        <div>
          <h4 class="font-semibold text-secondary-500 mb-2">🔒 Passwort ändern</h4>
          <ul class="list-disc list-inside space-y-1 text-sm">
            <li>Gib dein altes Passwort ein</li>
            <li>Gib zweimal dein neues Passwort ein</li>
            <li><strong>Anforderungen:</strong> Mind. 8 Zeichen, 1 Großbuchstabe, 1 Kleinbuchstabe, 1 Zahl, 1 Sonderzeichen</li>
          </ul>
        </div>

        <!-- Theme -->
        <div>
          <h4 class="font-semibold text-tertiary-500 mb-2">🎨 Design/Theme</h4>
          <p class="text-sm">Wähle zwischen hellem und dunklem Design - deine Präferenz wird gespeichert!</p>
        </div>

        <!-- Admin-Bereich -->
        <div>
          <h4 class="font-semibold text-warning-500 mb-2">👑 Admin-Bereich</h4>
          <p class="text-sm">
            Nur Admins sehen den "Alle Benutzer"-Bereich, wo sie Benutzer verwalten, Berechtigungen ändern und neue Benutzer anlegen können.
          </p>
        </div>

        <!-- Berechtigungsstufen -->
        <div class="alert variant-soft-primary">
          <div class="alert-message">
            <h4 class="font-semibold mb-1">🏷️ Berechtigungsstufen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>User:</strong> Kann Songs ansehen, an Abstimmungen teilnehmen, eigene Todos sehen</li>
              <li><strong>Editor:</strong> Kann zusätzlich Songs, Gigs und Proben bearbeiten</li>
              <li><strong>Admin:</strong> Vollzugriff inkl. Benutzerverwaltung</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  {/if}

  <!-- Benutzer-Felder -->
  <form class="flex flex-col gap-6">
    <!-- Username -->
    <div class="flex flex-col md:flex-row md:items-center gap-2">
      <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Username</label>
      <input type="text"
             class="input flex-1 rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
             bind:value={temp.user_name}
             disabled={!edit.user_name}
             on:keydown={(e) => e.key === 'Enter' && updateUserField('user_name')}
      />
    </div>

    <!-- Klarname mit Edit-Button -->
    <div class="flex flex-col md:flex-row md:items-center gap-2">
      <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Klarname</label>
      <div class="flex flex-1 gap-2">
        <input type="text"
              class="input w-full rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface text-on-surface"
              bind:value={temp.clear_name}
              disabled={!edit.clear_name}
              on:keydown={(e) => e.key === 'Enter' && updateUserField('clear_name')}
        />
        <button class="btn btn-outline-primary btn-sm self-center" on:click={() => toggleEdit('clear_name')}>
          {#if edit.clear_name}✔{:else}✎{/if}
        </button>
      </div>
    </div>

    <!-- Berechtigung -->
    <div class="flex flex-col md:flex-row md:items-center gap-2">
      <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Berechtigung</label>
      <input type="text"
             class="input flex-1 rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
             bind:value={temp.user_group}
             disabled={!edit.user_group}
             on:keydown={(e) => e.key === 'Enter' && updateUserField('user_group')}
      />
    </div>

    <!-- Email mit Edit-Button -->
    <div class="flex flex-col md:flex-row md:items-center gap-2">
      <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Email</label>
      <div class="flex flex-1 gap-2">
        <input type="email"
              class="input w-full rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
              bind:value={temp.email}
              disabled={!edit.email}
              on:keydown={(e) => e.key === 'Enter' && updateUserField('email')}
        />
        <button class="btn btn-outline-primary btn-sm self-center" on:click={() => toggleEdit('email')}>
          {#if edit.email}✔{:else}✎{/if}
        </button>
      </div>
    </div>
  </form>

  <hr class="my-8">

  <ThemeSwitcher />

  <hr class="my-8">

 <!-- Passwort ändern -->
 <PasswordChange {user} />

  <!-- Kasten für Rollen-Management (nur Admin) -->
  {#if isAdmin}
    <div class="bg-surface-2 rounded-xl shadow p-5 mt-7 border border-outline-variant">
      <h3 class="text-xl font-semibold mb-3 text-on-surface">Benutzer & Rollenverwaltung</h3>
      <!-- Hier kann z. B. eine Rollenliste, Auswahl oder entsprechende Controls ergänzt werden -->
      <UserAdminTable />
    </div>
  {/if}
</div>

<style>
table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  margin-bottom: 0;
  background: none;
}

tbody tr {
  border-bottom: 1px solid #e3e8ee;
  transition: background 0.15s;
}

tbody tr:last-child {
  border-bottom: none;
}

td {
  padding: .75em 1.1em;
  font-size: 1.045em;
  color: #2461a9;
  vertical-align: middle;
}

td:first-child {
  font-weight: 600;
  background: #edf5fb;
  border-radius: 8px 0 0 8px;
  min-width: 130px;
  color: #295886;
  letter-spacing: 0.05em;
}

td:last-child {
  background: #f7fbff;
  border-radius: 0 8px 8px 0;
  color: #1a293a;
}

@media (max-width: 600px) {
  td, th {
    padding: .7em .5em;
    font-size: 0.98em;
  }
  .card {
    padding: 1.2em !important;
  }
}

/* Zusätzliche Details für das Card-Design */
.card {
  border-radius: 1.2em;
  border: none;
  box-shadow: 0 2px 12px 0 #486faf14;
  //background: #fafbfc;
}

.pw-input-group {
  position: relative;
  display: flex;
  align-items: center;
}
.pw-input-group input {
  padding-right: 2.5em; /* Platz für den Button */
}
.pw-input-group button {
  position: absolute;
  right: 0.5em;
  border: None;
  cursor: pointer;
  font-size: 1.0em;
}
</style>