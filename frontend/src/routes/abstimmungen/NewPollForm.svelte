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
  import { getModalStore } from '@skeletonlabs/skeleton';
  import { SlideToggle } from '@skeletonlabs/skeleton';
  import {formatGermanDateTime} from '$lib/common.js';

  // Props vom Modal
  export let parent;

  const modalStore = getModalStore();

  let survey = {
    rf_survey: '',
    kind_of_survey: 'Terminfindung', // Default
    released: true,
    closed: false,
    fields: []
  };

  // UI State
  let newFieldValue = null;
  let flagZeitraum = 0; // 0 = Einzeltermine, 1 = Zeitraum
  let optionsError = null;
  let error = ''; // Globaler Fehler (z.B. "Keine Felder")
  let genError = ''; // Fehler spezifisch für die Generierung

  // --- ZEITRAUM LOGIK ---

  let fromDate = '';
  let toDate = '';
  let defaultTime = '10:00';
  let weekdays = {
      monday: false, tuesday: false, wednesday: false,
      thursday: false, friday: false, saturday: false, sunday: false
  };

  let errFrom = '';
  let errTo = '';

  // Hilfsfunktion: Gibt lokales Datum als YYYY-MM-DD zurück (Zeitzonen-sicher)
  function getLocalISOString(dateObj) {
      const year = dateObj.getFullYear();
      const month = String(dateObj.getMonth() + 1).padStart(2, '0');
      const day = String(dateObj.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
  }

  // 1. Sicheres "Heute" Datum bestimmen
  $: todayStr = getLocalISOString(new Date());

  // 2. Validierung: Startdatum
  $: {
      errFrom = '';
      if (fromDate) {
          if (fromDate < todayStr) {
              errFrom = 'Darf nicht in der Vergangenheit liegen.';
          }
      }
  }

  // 3. Validierung: Enddatum
  $: {
      errTo = '';
      if (toDate) {
          if (fromDate && toDate < fromDate) {
              errTo = 'Muss nach dem Startdatum liegen.';
          } else if (toDate < todayStr) {
              errTo = 'Darf nicht in der Vergangenheit liegen.';
          }
      }
  }

  // 4. Validierung: Wochentage
  $: hasSelectedWeekday = Object.values(weekdays).some(v => v);

  // 5. Gesamtzustand Button "Termine hinzufügen"
  // Aktiv wenn: Felder voll, keine Fehler, Wochentag gewählt
  $: canAddDates = (
      fromDate && !errFrom &&
      toDate && !errTo &&
      hasSelectedWeekday &&
      defaultTime
  );

  // Generierungs-Logik (Sicher mit While-Loop)
  function generateTimeSeq() {
    if (!fromDate || !toDate) return [];

    let output = [];
    // 'T00:00:00' sorgt dafür, dass wir sauber am Tagesanfang starten
    const start = new Date(fromDate + 'T00:00:00');
    const end = new Date(toDate + 'T00:00:00');

    const dayMap = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

    let current = new Date(start);

    while (current <= end) {
      const dayName = dayMap[current.getDay()];

      if (weekdays[dayName]) {
        const dateStr = getLocalISOString(current);
        output.push(`${dateStr}T${defaultTime}`);
      }
      // Einen Tag weiter springen
      current.setDate(current.getDate() + 1);
    }
    return output;
  }

  // Handler für den Button Klick
  function handleAddDates() {
      genError = '';
      const generatedDates = generateTimeSeq();

      // Fall 1: Keine Termine generiert (falsche Wochentage für den Zeitraum)
      if (generatedDates.length === 0) {
          genError = 'In diesem Zeitraum liegen keine der gewählten Wochentage.';
          return;
      }

      // --- DUPLIKAT-CHECK START ---

      // 1. Alle bereits existierenden Datumswerte in ein Set laden
      const existingSet = new Set(survey.fields.map(f => f.field_text));

      // 2. Die neuen Termine filtern: Behalte nur die, die NICHT im Set sind
      const uniqueNewDates = generatedDates.filter(date => !existingSet.has(date));

      // Fall 2: Es wurden zwar Termine generiert, aber alle existieren schon
      if (uniqueNewDates.length === 0) {
          genError = 'Alle Termine in diesem Zeitraum sind bereits hinzugefügt.';
          return;
      }

      // --- DUPLIKAT-CHECK ENDE ---

      // 3. Nur die neuen, einzigartigen Termine hinzufügen
      survey.fields = [
          ...survey.fields,
          ...uniqueNewDates.map(date => ({ field_text: date }))
      ];

      // Optional: Erfolgsmeldung oder Reset
      // fromDate = ''; toDate = '';
  }

  // --- STANDARD LOGIK ---

  // Submit Button Logic
  $: canSubmit = survey.rf_survey?.trim().length > 0 && survey.fields.length > 0;

  function addField() {
    optionsError = null;
    if (!newFieldValue) {
        optionsError = 'Bitte einen Wert eingeben.';
        return;
    };
    survey.fields = [...survey.fields, { field_text: newFieldValue }];
    newFieldValue = null;
  }

  function deleteField(field) {
        survey.fields = survey.fields.filter(f => f !== field);
  }

  function submit() {
    if (survey.fields.length === 0) {
        error = 'Bitte mindestens ein Feld hinzufügen.';
        return;
    }
    if ($modalStore[0].response) $modalStore[0].response(survey);
    modalStore.close();
  }
</script>

<div class="container w-50 max-h-screen overflow-y-auto p-4">
    <form class="card bg-surface-1 p-4 rounded shadow mb-4" on:submit|preventDefault={submit}>
      <h4 class="h5 mb-3">Neue Abstimmung</h4>

      <!-- TITEL -->
      <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
            <label class="whitespace-nowrap w-24">
               Titel: <span class="text-danger">*</span>
            </label>
            <input type="text" class="input flex-grow-1" bind:value={survey.rf_survey} placeholder="Titel eingeben" required />
      </div>

      <!-- ART -->
      <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
            <label class="whitespace-nowrap w-24">
               Art: <span class="text-danger">*</span>
            </label>
            <select class="input flex-grow-1" bind:value={survey.kind_of_survey} required>
               <option value="Meinungsumfrage">Meinungsumfrage</option>
               <option value="Terminfindung">Datumsumfrage</option>
            </select>
      </div>

      <div class="mb3">
         {#if survey.kind_of_survey === 'Terminfindung' }

           <!-- LISTE DER BEREITS HINZUGEFÜGTEN TERMINE -->
           <div class="flex flex-wrap gap-2 mb-4">
               {#each survey.fields as field}
                    <div class="chip variant-filled-surface flex items-center gap-2">
                     <!-- Schöne Anzeige: T durch Leerzeichen ersetzen -->
                     <span>{formatGermanDateTime(field.field_text)} Uhr</span>
                     <button type="button" class="btn-icon btn-icon-sm variant-filled-error" on:click={() => deleteField(field)}>✕</button>
                    </div>
               {/each}
           </div>

           <hr class="opacity-50">

           <!-- AUSWAHL MODUS -->
           <div class="mt-4">
                <label class="label mb-2">Eingabemethode:</label>
                <select class="input" bind:value={flagZeitraum}>
                   <option value={0}>Einzeltermine hinzufügen</option>
                   <option value={1}>Zeitraum generieren</option>
                </select>
            </div>

            <!-- EINZELTERMINE -->
            {#if flagZeitraum == 0}
                <div class="flex mt-4 gap-2">
                  <input
                    type="datetime-local"
                    class="input flex-grow-1"
                    bind:value={newFieldValue}
                    on:keydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addField(); }}}
                  />
                  <button type="button" class="btn variant-filled-primary" on:click={() => addField()}>+</button>
                </div>

            <!-- ZEITRAUM -->
            {:else}
                <div class="card p-4 variant-soft-surface mt-4 border border-surface-400/50">
                  <h6 class="h6 mb-3 font-bold">Zeitraum & Uhrzeit</h6>

                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <!-- VON DATUM -->
                    <label class="label">
                      <span>Von:</span>
                      <input
                        type="date"
                        class="input {errFrom ? 'input-error variant-form-material-error' : ''}"
                        bind:value={fromDate}
                        min={todayStr}
                      />
                      {#if errFrom}
                        <small class="text-error-500 block mt-1 leading-tight">{errFrom}</small>
                      {/if}
                    </label>

                    <!-- BIS DATUM -->
                    <label class="label">
                      <span>Bis:</span>
                      <input
                        type="date"
                        class="input {errTo ? 'input-error variant-form-material-error' : ''}"
                        bind:value={toDate}
                        min={fromDate || todayStr}
                        disabled={!fromDate || !!errFrom}
                      />
                      {#if errTo}
                        <small class="text-error-500 block mt-1 leading-tight">{errTo}</small>
                      {/if}
                    </label>

                    <!-- UHRZEIT -->
                    <label class="label">
                      <span>Uhrzeit:</span>
                      <input type="time" class="input" bind:value={defaultTime} />
                    </label>
                  </div>

                  <!-- WOCHENTAGE -->
                  <div class="mt-4">
                      <div class="flex justify-between items-center mb-2">
                        <h6 class="h6 font-bold">Wochentage:</h6>
                        {#if !hasSelectedWeekday}
                            <small class="text-warning-500">(Bitte Tag wählen)</small>
                        {/if}
                      </div>

                      <div class="flex flex-wrap gap-2">
                        {#each ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as day}
                            <SlideToggle
                                name={day}
                                bind:checked={weekdays[day]}
                                active="bg-primary-500"
                                size="sm"
                            >
                                {day.charAt(0).toUpperCase() + day.slice(1, 2)}
                            </SlideToggle>
                        {/each}
                      </div>
                  </div>

                  <!-- FEHLERMELDUNGEN -->
                  {#if genError}
                    <div class="alert variant-filled-error mt-4 transition-all">
                        {genError}
                    </div>
                  {/if}

                  <!-- ACTION BUTTON -->
                  <button
                    type="button"
                    class="btn variant-filled-success w-full mt-4"
                    disabled={!canAddDates}
                    on:click={handleAddDates}
                  >
                    {#if errFrom || errTo}
                        Bitte Fehler korrigieren
                    {:else if !fromDate || !toDate}
                        Zeitraum vervollständigen
                    {:else if !hasSelectedWeekday}
                        Wochentag wählen
                    {:else}
                        Termine hinzufügen
                    {/if}
                  </button>
                </div>
            {/if}

         {:else if survey.kind_of_survey === 'Meinungsumfrage' }
            <!-- MEINUNGSUMFRAGE PART -->
            {#if optionsError}
                <div class="text-error-500 mb-2">{optionsError}</div>
            {:else}
                {#each survey.fields as field}
                    <div class="m-4 flex">
                        <input class="input" disabled value="{field.field_text}" />
                        <button
                            type="button"
                            class="btn variant-filled-error border btn-sm ml-4"
                            on:click={() => deleteField(field)}
                        >x</button>
                    </div>
                {/each}
            {/if}
            <hr>
            <div class="ml-4 mt-4 flex">
                <input
                    type="text"
                    class="input"
                    bind:value={newFieldValue}
                    placeholder="Neue Option (mit Enter hinzufügen)"
                    on:keydown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          addField();
                        }
                    }}
                />
                <button
                    type="button"
                    class="btn variant-filled-primary border btn-sm ml-4"
                    on:click={() => addField()}
                >+</button>
            </div>
         {/if}
      </div>

      <!-- FOOTER BUTTONS -->
      <div class="flex justify-end gap-2 mt-6 border-t pt-4 border-surface-500/30">
        {#if error}
            <span class="text-error-500 flex items-center mr-4">{error}</span>
        {/if}
        <button class="btn variant-ringed-surface" type="button" on:click={modalStore.close}>Abbrechen</button>
        <button class="btn variant-filled-primary" type="submit" disabled={!canSubmit}>Erstellen</button>
      </div>
    </form>
</div>
