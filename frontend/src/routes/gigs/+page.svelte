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
  import { getUser, getGigs, addNewGig, delGig, getLiveModeAvailability, getLiveModeAvailabilityBatch } from '$lib/api.js';
  import { gigFields } from '$lib/songFields.js';
  import { gigIdForEditor } from '$lib/stores.js';

  import { createMessageHelpers } from '$lib/Messages.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';
  import LiveModeModal from '$lib/components/LiveModeModal.svelte';
  import GigDetailsModal from '$lib/components/GigDetailsModal.svelte';
  import SeasonStatsModal from './SeasonStatsModal.svelte';

  const { showError, showSuccess } = createMessageHelpers();

  import NewGigForm from './NewGigForm.svelte';

  import { modalState } from '$lib/modalState.js';


    let user = $state({ user_name: null, user_group: null });
  let gigs = $state([]);
  let jahre = $state([]);
  let jahr = $state('');
  let error = $state('');
  let showHelp = $state(false);
  let liveModeStatus = $state({}); // Key: gigId, Value: { available, can_force, forced, reason }

  onMount(async () => {
    try {
      user = await getUser();

    } catch(e) {
      user = { user_name: null, user_group: null };
      error = 'User/Gigs konnten nicht geladen werden';
      console.error('Gigs load error:', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
    gigs = await getGigs(null, '');
      jahre = Array.from(new Set(gigs.map(g => g.datum?.slice(0,4)))).filter(Boolean).sort(); // ggf. gig.datum?.slice(0,4)

      const aktuellesJahr = String(new Date().getFullYear());

      // 4. Prüfe, ob das aktuelle Jahr in der Jahresliste vorkommt
      if (jahre.includes(aktuellesJahr)) {
        jahr = aktuellesJahr;        // <- Variable: DropDown-Wert!
      } else if (jahre.length) {
        jahr = jahre[jahre.length - 1]; // Fallback: jüngstes Jahr
      } else {
        jahr = '';
      }

      // 5. Hole die Gigs GEFILTERT für das aktuelle Jahr (oder Fallback)
      gigs = await getGigs(null, jahr);

      // 6. Lade Live-Mode-Status für alle Gigs (nur für Editoren/Admins)
      if (user && (user.user_group === 'editor' || user.user_group === 'admin')) {
        await loadLiveModeStatus();
      }
  });

  async function loadLiveModeStatus() {
    //console.log('Loading Live-Mode status for', gigs.length, 'gigs');

    if (gigs.length === 0) {
      liveModeStatus = {};
      return;
    }

    try {
      // Ein einzelner API-Call für alle Gigs
      const gigIds = gigs.map(g => g.id);
      const statuses = await getLiveModeAvailabilityBatch(null, gigIds);

      // statuses ist ein Object: { "1": {...}, "2": {...}, ... }
      // Konvertiere String-Keys zu Numbers
      liveModeStatus = {};
      Object.entries(statuses).forEach(([gigIdStr, status]) => {
        const gigId = parseInt(gigIdStr);
        liveModeStatus[gigId] = status;
        //console.log(`Gig ${gigId}:`, status);
      });

      //console.log('Final liveModeStatus:', liveModeStatus);
    } catch (e) {
      console.error('Fehler beim Laden der Live-Mode-Status:', e);
      // Fallback: Alle auf unavailable setzen
      liveModeStatus = {};
      gigs.forEach(gig => {
        liveModeStatus[gig.id] = { available: false, can_force: false };
      });
    }
  }

  async function unlockLiveMode(gigId) {
    try {
      const status = await getLiveModeAvailability(null, gigId, true);
      liveModeStatus[gigId] = status;
      liveModeStatus = { ...liveModeStatus }; // Trigger reactivity
      showSuccess('Live-Mode entsperrt');
    } catch (e) {
      showError(e.message ?? 'Fehler beim Entsperren des Live-Modus');
    }
  }
  async function onJahrChange() {
    try {
      gigs = await getGigs(null, jahr);
    } catch {
      gigs = [];
    }
  }

  function dateToIsoString(date) {
    if (!date) return '';
    const dt = new Date(date);
    if (isNaN(dt)) return date;
    return dt.toISOString().split('T')[0];
  }

  function formatDateDE(isoString) {
    if (!isoString) isoString = dateToIsoString(isoString);
    const dt = new Date(isoString);
    if (isNaN(dt)) return isoString;
    return dt.toLocaleDateString('de-DE');
  }

  let canEdit = $derived(user?.user_group === 'editor' || user?.user_group === 'admin');
  let isAdmin = $derived(user?.user_group === 'admin');

  // Reactive: Wenn sich das Jahr ändert, lade Gigs und Live-Mode-Status neu
  $effect(() => { if (browser && jahr) {
    reloadGigsForYear();
  }
  });

  async function reloadGigsForYear() {
    try {
      gigs = await getGigs(null, jahr);

      // Lade Live-Mode-Status für Editoren/Admins
      if (user && (user.user_group === 'editor' || user.user_group === 'admin')) {
        await loadLiveModeStatus();
      }
    } catch (e) {
      console.error('Fehler beim Laden der Gigs:', e);
    }
  }

  function handleGigUpdated(updatedGig) {
    if (!updatedGig?.id) return;
    gigs = gigs.map((g) => (g.id === updatedGig.id ? { ...g, ...updatedGig } : g));
  }

  async function addGig(gig) {
    try {
        gigs = await addNewGig(null, gig);
    } catch (e) {
        showError(e.message ?? "Update fehlgeschlagen");
    }
  }

  async function deleteGig(gigId, gigName) {
    modalState.trigger({
      component: ConfirmModal,
      meta: {
        title: 'Gig löschen',
        message: `Möchten Sie den Gig "${gigName}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`,
        confirmText: 'Löschen',
        cancelText: 'Abbrechen',
        confirmButtonClass: 'btn variant-filled-error',
        cancelButtonClass: 'btn variant-outline-secondary'
      },
      response: async (confirmed) => {
        if (confirmed) {
          try {
            gigs = await delGig(null, gigId);
            showSuccess('Gig erfolgreich gelöscht');
          } catch (e) {
            showError(e.message ?? "Löschen fehlgeschlagen");
          }
        }
      }
    });
  }

  function openGigDetailsModal(gig) {
    modalState.trigger({
      component: GigDetailsModal,
      meta: {
        gig,
        canEdit,
        isAdmin,
        liveModeStatus: liveModeStatus[gig.id] ?? null,
        onGigUpdated: handleGigUpdated,
        onDeleteGig: (gigToDelete) => deleteGig(gigToDelete.id, gigToDelete.name),
        onEditSetlist: gotoSetlistEditor,
        onOpenLiveMode: openLiveModeModal,
        onUnlockLiveMode: unlockLiveMode
      }
    });
  }

  function openNewGigModal() {
    modalState.trigger({
      component: NewGigForm,
      title: 'Neuen Gig erstellen',
      response: (r) => {
        if (r) addGig(r);
      },
      close: modalState.close
    });
  }

  function gotoSetlistEditor(gigId) {
    gigIdForEditor.set(gigId);
    goto(`/setlist_editor`);
  }

  function isPast(datum) {
    if (!datum) return false;
    return new Date(datum) < new Date(new Date().toDateString()); // Vergleich ohne Uhrzeit
  }

  function openLiveModeModal(gigId) {
    modalState.trigger({
      component: LiveModeModal,
      meta: { gigId },
      backdropClasses: 'bg-surface-500/50 backdrop-blur-sm'
    });
  }

</script>

<div class="max-w-6xl mx-auto py-8 md:px-4">
  <div class="card bg-surface-2 rounded-3xl shadow-md md:border md:border-outline-variant p-2 md:p-8">
    <div class="flex flex-col md:flex-row md:justify-between md:items-center mb-6">
      <div class="flex items-center gap-3 mb-4">
        <h2 class="h2 text-on-surface">Gigs‑Liste</h2>
        {#if canEdit}
          <button
            class="btn-icon variant-filled-primary w-8 h-4 rounded-full text-xl leading-none"
            onclick={openNewGigModal}
            title="Neuen Gig hinzufügen"
          >+</button>
        {/if}
      </div>
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
        <h3 class="h4 font-bold mb-4">🎤 Anleitung: Gigs-Verwaltung</h3>

        <div class="space-y-4">
          <!-- Grundfunktionen -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-2">📋 Hauptfunktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Neuen Gig hinzufügen:</strong> Klicke auf "Neuen Gig hinzufügen" (nur Editoren/Admins)</li>
              <li><strong>Gig-Details ansehen:</strong> Klicke auf einen Gig, um das Detail-Modal zu oeffnen</li>
              <li><strong>Gig bearbeiten:</strong> Im Detail-Modal auf "Stammdaten bearbeiten" klicken (nur Editoren/Admins)</li>
              <li><strong>Setliste bearbeiten:</strong> Klicke auf "Setliste bearbeiten" (wenn vorhanden)</li>
              <li><strong>Ablaufplan:</strong> Im Gig-Detail-Modal den Tab "Ablaufplan" oeffnen</li>
            </ul>
          </div>

          <!-- Jahresfilter -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-2">📅 Jahresfilter</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li>Wähle ein Jahr aus dem Dropdown, um nur Gigs dieses Jahres anzuzeigen</li>
              <li>Wähle "Alle", um alle Gigs unabhängig vom Jahr zu sehen</li>
            </ul>
          </div>

          <!-- Live-Mode -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-2">🎸 Live-Mode</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Was ist der Live-Mode?</strong> Ein spezieller Modus für während des Auftritts</li>
              <li><strong>Wann verfügbar?</strong> Automatisch am Tag des Auftritts (für Editoren/Admins)</li>
              <li><strong>Freischalten:</strong> Admins können den Live-Mode auch manuell freischalten</li>
              <li><strong>Funktionen:</strong> Songs bewerten, überspringen, einschieben - alles während des Gigs!</li>
            </ul>
          </div>

          <!-- Dokumenten-Export -->
          <div>
            <h4 class="font-semibold text-success-500 mb-2">📄 Dokumente</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Setliste drucken:</strong> Exportiert die Setliste als PDF</li>
              <li><strong>GEMA-Liste drucken:</strong> Exportiert die GEMA-Liste als PDF (wichtig für Anmeldung!)</li>
            </ul>
          </div>

          <!-- Gig-Status -->
          <div>
            <h4 class="font-semibold text-warning-500 mb-2">🏷️ Status-Optionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Anfrage:</strong> Potentieller Auftritt, noch nicht bestätigt</li>
              <li><strong>Bestätigt:</strong> Auftritt ist fix</li>
              <li><strong>Abgesagt:</strong> Auftritt wurde abgesagt</li>
            </ul>
          </div>
        </div>
      </div>
    {/if}


    <div class="mb-5 flex flex-col md:flex-row md:justify-between md:items-center">
      <div class="flex flex-wrap items-center gap-3">
        <div>          <label for="jahr" class="form-label text-on-surface-variant font-medium">Jahr wählen:</label>
          <select
              id="jahr"
              bind:value={jahr}
              onchange={onJahrChange}
              class="form-input variant-soft w-auto inline-block rounded-md px-5 bg-surface-200 dark:bg-surface-700 py-2"
          >
            {#each jahre.slice().reverse() as y}
               <option value={y} class="bg-surface-300 dark:bg-surface-700">{y}</option>
            {/each}
             <option value="" class="bg-surface-300 dark:bg-surface-700">Alle</option>
          </select>
        </div>
        <button
          class="btn variant-ghost-secondary btn-sm"
          onclick={() => modalState.trigger({ component: SeasonStatsModal, meta: { jahr } })}
          disabled={!jahr}
          title={!jahr ? 'Bitte zuerst ein Jahr auswählen' : `Statistik für ${jahr} anzeigen`}
        >
          📊 Saisonstatistik
        </button>
      </div>
    </div>

    {#if gigs.length > 0}
      <!-- Desktop Layout -->
      <div class="hidden md:block">
        <table
          class="w-full border-collapse bg-surface-1 text-on-surface rounded-2xl overflow-hidden shadow-sm"
        >
          <thead class="bg-surface text-primary-100 text-sm font-medium uppercase">
            <tr>
              <th class="px-3 py-2 text-left text-surface-900 dark:text-surface-200 w-6"></th>
              {#each gigFields as f}
                <th class="px-3 py-2 text-left cursor-pointer text-surface-900 dark:text-surface-200">{f.label}</th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each gigs as gig (gig.id)}
              <tr
                class="transition cursor-pointer {isPast(gig.datum)
                  ? 'opacity-50 dark:opacity-40 hover:opacity-80 dark:hover:opacity-60 bg-surface-50 dark:bg-surface-900'
                  : 'dark:hover:bg-surface-700 hover:bg-surface-300'}"
                onclick={() => openGigDetailsModal(gig)}
              >
                <td class="py-2 px-3 text-center">
                  {#if isPast(gig.datum)}
                    <span class="text-success-600 dark:text-success-400 font-bold" title="Vergangener Gig">✓</span>
                  {/if}
                </td>
                {#each gigFields as f}
                  {#if f.key === 'datum'}
                    <td class="py-2 px-3">{formatDateDE(gig[f.key])}</td>
                  {:else}
                    <td class="py-2 px-3">{gig[f.key]}</td>
                  {/if}
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <!-- Mobile Layout -->
      <div class="block md:hidden mt-5 space-y-4">
        {#each gigs as gig (gig.id)}
          <div class="rounded-2xl p-4 shadow border border-outline-variant transition
            {isPast(gig.datum)
              ? 'bg-surface-50 dark:bg-surface-900 opacity-60 hover:opacity-90'
              : 'bg-surface-1'}">
            <div class="flex justify-between items-start">
              <div class="flex-1" onclick={() => openGigDetailsModal(gig)}>
                <div class="flex items-center gap-2 mb-1">
                  {#if isPast(gig.datum)}
                    <span class="badge variant-soft-success text-xs px-1.5 py-0.5">✓ gewesen</span>
                  {/if}
                  <p class="font-semibold text-on-primary">{gig.name}</p>
                </div>
                <p class="text-sm text-on-surface-variant mb-1">
                  {formatDateDE(gig.datum)} – {gig.kind_of_gig}
                </p>
              </div>
              <button class="btn btn-sm variant-tonal" onclick={() => openGigDetailsModal(gig)}>Details</button>
            </div>
          </div>
        {/each}
      </div>
    {:else}
      <p class="text-center text-on-surface-variant py-6">Keine Gigs gefunden.</p>
    {/if}

    {#if error}
      <div class="mt-4 p-4 rounded-lg bg-error-50 text-error-900 border border-error-200 text-center shadow">
        {error}
      </div>
    {/if}
  </div>
</div>
