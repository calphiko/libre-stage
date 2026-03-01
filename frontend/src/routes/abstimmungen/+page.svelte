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
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { getUser, getSurveys, getSurveyDetails, getUserList, updateSurveyFeedback, createSurvey, deleteSurvey, archiveSurvey, logout as apiLogout} from '$lib/api.js';
  import { shortFormatGermanDate } from '$lib/common.js';

  import { getToastStore } from '@skeletonlabs/skeleton';
  import { TabGroup, Tab } from '@skeletonlabs/skeleton';
  import { createMessageHelpers } from '$lib/Messages.svelte';

  const { showError, showSuccess, showWarning } = createMessageHelpers(getToastStore());


  import { Accordion,
            AccordionItem,
            Autocomplete,
            ProgressRadial
          } from '@skeletonlabs/skeleton';

  import TerminfindungView from './TerminfindungView.svelte';
  import MeinungsumfrageView from './MeinungsumfrageView.svelte';
  import AuftrittsanfrageView from './AuftrittsanfrageView.svelte';
  import ConfirmModal from '$lib/components/ConfirmModal.svelte';

  let user = null;
  let error = '';
  let rulesVisible = false;
  let showHelp = false;
  let tabSet = 0; // Tab-Steuerung
  let closedSurveysFilter = ''; // Filter für abgeschlossene Umfragen

  let surveys = [];
  export let users = [];

  let openValue = [];
  let loading = {};
  let details = {};

  $: userById = new Map(users.map(u => [u.id, u]));
  $: activeSurveys = surveys.filter(s => !s.closed);
  $: closedSurveys = surveys.filter(s => s.closed);

  // Gefilterte abgeschlossene Umfragen
  $: filteredClosedSurveys = closedSurveys.filter(survey => {
    if (!closedSurveysFilter.trim()) return true;

    const searchLower = closedSurveysFilter.toLowerCase();
    const titleMatch = survey.rf_survey?.toLowerCase().includes(searchLower);
    const creatorMatch = userById.get(survey.user_created)?.user_name?.toLowerCase().includes(searchLower);

    return titleMatch || creatorMatch;
  });

  import {
    getModalStore
  } from '@skeletonlabs/skeleton';

  import NewPollForm from './NewPollForm.svelte';

  const modalStore = getModalStore();


  onMount(async () => {
    try {
      user = await getUser();

    } catch(e) {
      error = 'User/Gigs konnten nicht geladen werden';
      showError(e);
      console.error('User/Gigs konnten nicht geladen werden', e);
      return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
    }
    try {
        surveys = await getSurveys();
        //showSuccess('Abstimmungen geladen');
    } catch(e) {
        error = 'Abstimmungen konnten nicht geladen werden';
        showError(e);
        console.error('Abstimmungen konnten nicht geladen werden', e);
    }

    try {
        users = await getUserList();
    } catch(e) {
        error = 'User konnten nicht geladen werden';
        console.warning('User konnten nicht geladen werden', e);
    }
  });

  function logout() {
        goto('/');
  }

  function openNewModal() {
    modalStore.trigger({
      type: 'component',
      component: { ref: NewPollForm },
      title: 'Neue Abstimmung erstellen',
      response: (r) => {
        if (r) addSurvey(r);
      },
      close: modalStore.close
    });
  }

  async function addSurvey(newSurvey) {
    if (!newSurvey) return;
    try {
      surveys  = await createSurvey(null, newSurvey);
    } catch (e) {
        showError('Fehler beim Erstellen der Umfrage.');
        console.error('Fehler beim Erstellen der Umfrage:', e);
    }
  }

  async function getSurveyD(surveyId) {
    try {
      const details = await getSurveyDetails(null, surveyId);
      return details;
    } catch (e) {
      showError('Fehler beim Laden der Umfragedetails.');
      console.error('Fehler beim Laden der Umfragedetails:', e);
      return null;
    }
  }

  async function handleItemToggle(event, surveyId) {
    const { open } = event.detail; // v2: event.detail.open = true/false[web:26]

    if (!open) return; // nur beim Öffnen laden

    // Scroll zum Accordion-Header
    if (open) {
      setTimeout(() => {
        // Finde das Accordion-Element über die data-survey-id
        const accordionElement = document.querySelector(`[data-survey-id="${surveyId}"]`);
        if (accordionElement) {
          accordionElement.scrollIntoView({
            behavior: 'smooth',
            block: 'start',
            inline: 'nearest'
          });
        }
      }, 150); // Etwas längere Verzögerung für sichere Öffnung
    }

    if (!details[surveyId] && !loading[surveyId]) {
      loading = { ...loading, [surveyId]: true };
      const d = await getSurveyD(surveyId);
      details = { ...details, [surveyId]: d };
      loading = { ...loading, [surveyId]: false };
    }
  }

  async function removeSurvey(surveyId, surveyName) {
    modalStore.trigger({
      type: 'component',
      component: { ref: ConfirmModal },
      meta: {
        title: 'Abstimmung löschen',
        message: `Möchten Sie die Abstimmung "${surveyName}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`,
        confirmText: 'Löschen',
        cancelText: 'Abbrechen',
        confirmButtonClass: 'btn variant-filled-error',
        cancelButtonClass: 'btn variant-outline-secondary'
      },
      response: async (confirmed) => {
        if (confirmed) {
          try {
            surveys = await deleteSurvey(null, surveyId);
            showSuccess('Abstimmung erfolgreich gelöscht');
          } catch (e) {
            showError('Fehler beim Löschen der Umfrage. (Wenn es Feedback gibt, kann die Umfrage nicht gelöscht werden)');
            console.error('Fehler beim Löschen der Umfrage:', e);
          }
        }
      }
    });
  }
  async function closeSurvey(surveyId, surveyName) {
    modalStore.trigger({
      type: 'component',
      component: { ref: ConfirmModal },
      meta: {
        title: 'Abstimmung archivieren',
        message: `Möchten Sie die Abstimmung "${surveyName}" wirklich archivieren? Archivierte Abstimmungen können nicht mehr bearbeitet werden.`,
        confirmText: 'Archivieren',
        cancelText: 'Abbrechen',
        confirmButtonClass: 'btn variant-filled-warning',
        cancelButtonClass: 'btn variant-outline-secondary'
      },
      response: async (confirmed) => {
        if (confirmed) {
          try {
            surveys = await archiveSurvey(null, surveyId);
            showSuccess('Abstimmung erfolgreich archiviert');
          } catch (e) {
            showError('Fehler beim Archivieren der Umfrage.');
            console.error('Fehler beim Archivieren der Umfrage:', e);
          }
        }
      }
    });
  }

  function toggleRules() {
    rulesVisible = !rulesVisible;
  }


</script>

<div class="max-w-6xl md:mx-auto py-6 md:px-3">
  <div class="card bg-surface-2 rounded-2xl shadow-lg p-2 md:p-6 md:border md:border-outline-variant">
    <div class="flex items-center justify-between mb-4">
      <h2 class="h2 text-on-surface">Abstimmungen</h2>
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
        <h3 class="h4 font-bold mb-4">🗳️ Anleitung: Abstimmungen</h3>

        <div class="space-y-4">
          <!-- Grundfunktionen -->
          <div>
            <h4 class="font-semibold text-primary-500 mb-2">📊 Hauptfunktionen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Neue Abstimmung:</strong> Klicke auf "Neue Abstimmung" und wähle den Typ (Terminfindung oder Meinungsumfrage)</li>
              <li><strong>Abstimmen:</strong> Klicke auf eine Umfrage, um Details zu sehen und deine Stimme abzugeben</li>
              <li><strong>Archivieren:</strong> Als Ersteller kannst du deine Umfrage archivieren (nur du siehst den Button)</li>
              <li><strong>Löschen:</strong> Nur möglich, wenn noch kein Feedback vorhanden ist</li>
            </ul>
          </div>

          <!-- Die zwei Bereiche -->
          <div>
            <h4 class="font-semibold text-secondary-500 mb-2">📂 Die zwei Tabs</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Laufende Umfragen ({activeSurveys.length}):</strong> Alle aktiven Abstimmungen, an denen du teilnehmen kannst. Wenn du eine Umfrage erstellt hast, siehst du hier auch die Buttons zum Archivieren und Löschen.</li>
              <li><strong>Abgeschlossene Umfragen ({closedSurveys.length}):</strong> Archivierte Abstimmungen (nur noch lesbar). Diese Liste kann sehr lang werden - nutze das Suchfeld zum Filtern!</li>
            </ul>
          </div>

          <!-- Filter-Funktion -->
          <div>
            <h4 class="font-semibold text-tertiary-500 mb-2">🔍 Filter-Funktion</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Suche:</strong> Im Tab "Abgeschlossene Umfragen" findest du ein Suchfeld</li>
              <li><strong>Durchsucht:</strong> Titel der Umfrage und Name des Erstellers</li>
              <li><strong>Live-Suche:</strong> Ergebnisse werden sofort beim Tippen aktualisiert</li>
              <li><strong>Filter löschen:</strong> Klicke auf "✕" im Suchfeld, um den Filter zurückzusetzen</li>
            </ul>
          </div>

          <!-- Typen -->
          <div>
            <h4 class="font-semibold text-success-500 mb-2">🎯 Abstimmungstypen</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Terminfindung:</strong> Koordiniere Proben, Auftritte etc. mit Ja/Nein/Vielleicht-Optionen</li>
              <li><strong>Meinungsumfrage:</strong> Stelle Fragen mit vordefinierten Antwortmöglichkeiten</li>
            </ul>
          </div>

          <!-- Bedienung -->
          <div>
            <h4 class="font-semibold text-warning-500 mb-2">⚙️ Bedienung</h4>
            <ul class="list-disc list-inside space-y-1 text-sm">
              <li><strong>Accordion öffnen:</strong> Klicke auf eine Umfrage, um Details zu sehen - die Seite scrollt automatisch zum Header</li>
              <li><strong>Tab-Wechsel:</strong> Die Anzahl der Umfragen wird in Klammern angezeigt</li>
              <li><strong>Mobile-optimiert:</strong> Alle Funktionen sind auch auf dem Smartphone nutzbar</li>
            </ul>
          </div>

          <!-- Wichtige Regeln -->
          <div class="alert variant-soft-warning">
            <div class="alert-message">
              <h4 class="font-semibold mb-1">⚠️ Wichtig</h4>
              <ul class="list-disc list-inside space-y-1 text-sm">
                <li>Der <strong>Ersteller</strong> ist für die Auswertung verantwortlich</li>
                <li>Vorhandene Antwortoptionen können <strong>nicht geändert</strong> werden (Integrität!)</li>
                <li>Neue Antwortmöglichkeiten hinzufügen? → Andere Bandmitglieder informieren!</li>
                <li>Nach Auswertung: Umfrage <strong>archivieren</strong>, damit sie in "Abgeschlossene Umfragen" verschoben wird</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    {/if}

    <button class="btn variant-filled-primary btn-sm w-fit border mt-4 mb-4" on:click={openNewModal}>
          Neue Abstimmung
    </button>

    <!-- Regeln als Info-Box -->
    <div class="card variant-soft-warning mb-6">
      <button
        type="button"
        class="w-full p-4 text-left hover:bg-warning-50 dark:hover:bg-warning-900/10 transition-colors rounded-lg"
        on:click={toggleRules}
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <svg class="w-6 h-6 text-warning-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
            </svg>
            <h3 class="font-semibold text-warning-900 dark:text-warning-100">
              📋 Wichtige Regeln für Abstimmungen
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
              <span>Jeder kann eine Abstimmung zu jedem Thema erstellen</span>
            </li>
            <li class="flex gap-2">
              <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
              <span>Jeder kann an jeder Abstimmung teilnehmen</span>
            </li>
            <li class="flex gap-2">
              <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
              <span>Der Ersteller einer Abstimmung ist für die Auswertung und Kommunikation der Ergebnisse verantwortlich</span>
            </li>
            <li class="flex gap-2">
              <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
              <span>Abstimmungen mit Ergebnis sollten archiviert werden</span>
            </li>
            <li class="flex gap-2">
              <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
              <span>Vorhandene Antwortoptionen können <strong>nicht bearbeitet oder gelöscht</strong> werden (Schutz der Integrität bereits abgegebener Stimmen)</span>
            </li>
            <li class="flex gap-2">
              <span class="text-warning-600 dark:text-warning-400 font-bold">•</span>
              <span>Wenn du neue Antwortmöglichkeiten hinzufügst, informiere bitte deine Bandkollegen</span>
            </li>
          </ul>
        </div>
      {/if}
    </div>

    <TabGroup>
        <Tab bind:group={tabSet} name="active" value={0} class={activeSurveys.length > 0 ? 'font-bold' : ''}>
          <span>Laufende Umfragen ({activeSurveys.length})</span>
        </Tab>
        <Tab bind:group={tabSet} name="closed" value={1}>
          <span>Abgeschlossene Umfragen ({closedSurveys.length})</span>
        </Tab>

      <svelte:fragment slot="panel">
        {#if tabSet === 0}
            <!-- Laufende Umfragen -->
            {#if activeSurveys.length === 0}
                <p class="text-on-surface-variant italic mt-4">Keine laufenden Umfragen</p>
              {:else}
                <Accordion class="space-y-3 mt-4">
                  {#each activeSurveys as survey (survey.id)}
                    <AccordionItem on:toggle={(event) => handleItemToggle(event, survey.id)} class="survey-item" data-survey-id={survey.id}>
                      <svelte:fragment slot="summary">
                        <div class="flex justify-between items-center w-full p-2">
                          <span class="font-medium text-on-surface w-60/100">{survey.rf_survey}</span>
                          <span class="text-sm text-on-surface-variant w-40/100 hidden md:block">
                            {userById.get(survey.user_created)?.user_name ?? survey.user_created}
                            {shortFormatGermanDate(survey.release_date)}
                            {#if survey.user_created === user?.id }
                              <button
                                type="button"
                                class="md:ml-2 btn variant-filled-warning btn-sm py-0"
                                on:click|stopPropagation={() => {
                                  closeSurvey(survey.id, survey.rf_survey);
                                }}>
                                Archivieren
                              </button>
                              <button
                                type="button"
                                class="md:ml-2 btn variant-filled-error btn-sm py-0"
                                on:click|stopPropagation={() => {
                                  removeSurvey(survey.id, survey.rf_survey);
                                }}
                                >
                                ✕
                              </button>
                            {/if}
                          </span>
                        </div>
                      </svelte:fragment>

                      <svelte:fragment slot="content">
                        {#if loading[survey.id]}
                          <div class="md:p-4 border-t border-outline-variant flex justify-between items-center">
                            <ProgressRadial
                              stroke={80}
                              meter="stroke-secondary-500"
                              track="stroke-secondary-500/30"
                              strokeLinecap="round"
                              value={undefined}
                            />
                          </div>
                        {:else if details[survey.id]}
                          <div class="md:p-4 border-t border-outline-variant">
                            {#if details[survey.id].kind_of_survey === 'Terminfindung'}
                              {#if user}
                                <TerminfindungView
                                  survey={details[survey.id]}
                                  users={users}
                                  {user}
                                />
                              {:else}
                                <div>Benutzerdaten werden geladen…</div>
                              {/if}
                            {:else if details[survey.id].kind_of_survey === 'Meinungsumfrage'}
                              <MeinungsumfrageView survey={details[survey.id]} users={users} user={user} />
                            {:else}
                              <div>Unbekannter Survey-Typ.</div>
                            {/if}
                          </div>
                        {/if}
                      </svelte:fragment>
                    </AccordionItem>
                  {/each}
                </Accordion>
              {/if}

        {:else if tabSet === 1}
            <!-- Abgeschlossene Umfragen -->
            {#if closedSurveys.length === 0}
                <p class="text-on-surface-variant italic mt-4">Keine abgeschlossenen Umfragen</p>
              {:else}
                <!-- Suchfeld für abgeschlossene Umfragen -->
                <div class="mt-4 mb-3">
                  <div class="input-group input-group-divider grid-cols-[auto_1fr_auto]">
                    <div class="input-group-shim">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                    </div>
                    <input
                      type="search"
                      bind:value={closedSurveysFilter}
                      placeholder="Suche nach Titel oder Ersteller..."
                      class="input"
                    />

                  </div>
                  {#if closedSurveysFilter && filteredClosedSurveys.length !== closedSurveys.length}
                    <p class="text-sm text-on-surface-variant mt-2">
                      {filteredClosedSurveys.length} von {closedSurveys.length} Umfrage{closedSurveys.length !== 1 ? 'n' : ''}
                    </p>
                  {/if}
                </div>

                {#if filteredClosedSurveys.length === 0}
                  <p class="text-on-surface-variant italic mt-4">Keine Umfragen gefunden</p>
                {:else}
                <Accordion class="space-y-3 mt-4">
                  {#each filteredClosedSurveys as survey (survey.id)}
                    <AccordionItem on:toggle={(event) => handleItemToggle(event, survey.id)} class="survey-item survey-item-closed" data-survey-id={survey.id}>
                      <svelte:fragment slot="summary">
                        <div class="flex justify-between items-center w-full p-2">
                          <span class="font-medium text-on-surface w-60/100">{survey.rf_survey}</span>
                          <span class="text-sm text-on-surface-variant w-40/100 hidden md:block">
                            {userById.get(survey.user_created)?.user_name ?? survey.user_created}
                            {shortFormatGermanDate(survey.release_date)}
                            <span class="badge variant-filled py-1">geschlossen</span>
                            {#if survey.user_created === user?.id }
                              <button
                                type="button"
                                class="md:ml-2 btn variant-filled-error btn-sm py-0"
                                on:click|stopPropagation={() => {
                                  removeSurvey(survey.id, survey.rf_survey);
                                }}
                                >
                                ✕
                              </button>
                            {/if}
                          </span>
                        </div>
                      </svelte:fragment>

                      <svelte:fragment slot="content">
                        {#if loading[survey.id]}
                          <div class="md:p-4 border-t border-outline-variant flex justify-between items-center">
                            <ProgressRadial
                              stroke={80}
                              meter="stroke-secondary-500"
                              track="stroke-secondary-500/30"
                              strokeLinecap="round"
                              value={undefined}
                            />
                          </div>
                        {:else if details[survey.id]}
                          <div class="md:p-4 border-t border-outline-variant">
                            {#if details[survey.id].kind_of_survey === 'Terminfindung'}
                              {#if user}
                                <TerminfindungView
                                  survey={details[survey.id]}
                                  users={users}
                                  {user}
                                />
                              {:else}
                                <div>Benutzerdaten werden geladen…</div>
                              {/if}
                            {:else if details[survey.id].kind_of_survey === 'Meinungsumfrage'}
                              <MeinungsumfrageView survey={details[survey.id]} users={users} user={user} />
                            {:else}
                              <div>Unbekannter Survey-Typ.</div>
                            {/if}
                          </div>
                        {/if}
                      </svelte:fragment>
                    </AccordionItem>
                  {/each}
                </Accordion>
                {/if}
              {/if}
        {/if}
      </svelte:fragment>
    </TabGroup>


    {#if error}
      <div class="mt-4 p-4 bg-red-100 text-red-800 rounded">
        {error}
      </div>
    {/if}
  </div>
</div>

<style>

/* Styling für Survey-Items */
:global(.survey-item) {
  background-color: rgba(var(--color-surface-300) / 0.3);
  border: 1px solid rgba(var(--color-outline-variant) / 0.5);
  border-radius: 0.75rem;
  padding: 0.5rem;
  margin-bottom: 0.75rem;
  transition: all 0.2s ease;
}

:global(.survey-item:hover) {
  background-color: rgba(var(--color-surface-300) / 0.5);
  border-color: rgba(var(--color-outline-variant) / 0.8);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

:global(.survey-item-closed) {
  background-color: rgba(var(--color-surface-200) / 0.2);
  opacity: 0.85;
}

:global(.survey-item-closed:hover) {
  opacity: 1;
}

/* Dark Mode Anpassungen */
:global(.dark .survey-item) {
  background-color: rgba(255, 255, 255, 0.03);
  border-color: rgba(255, 255, 255, 0.1);
}

:global(.dark .survey-item:hover) {
  background-color: rgba(255, 255, 255, 0.06);
  border-color: rgba(255, 255, 255, 0.15);
}

:global(.dark .survey-item-closed) {
  background-color: rgba(255, 255, 255, 0.02);
}

</style>