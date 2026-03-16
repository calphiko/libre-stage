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
  import { modalState } from '$lib/modalState.js';

  let begin = $state('');
  let end = $state('');
  let comment = $state('');
  let error = $state('');

  function submit() {
    error = '';

    if (!begin) {
      error = 'Bitte eine Startzeit auswählen.';
      return;
    }

    if (end && new Date(end) <= new Date(begin)) {
      error = 'Die Endzeit muss nach der Startzeit liegen.';
      return;
    }

    modalState.close({ begin, end: end || null, comment });
  }
</script>

<form class="card bg-surface-1 p-4 rounded shadow mb-4 modal-base" onsubmit={(e) => { e.preventDefault(); submit(); }}>
  <h4 class="h5 mb-3">Neue Probe</h4>

  <div class="mb-3">
    <label class="form-label" for="reh-begin">Start (Datum & Zeit)</label>
    <input id="reh-begin" type="datetime-local" class="input" bind:value={begin} required />
  </div>

  <div class="mb-3">
    <label class="form-label" for="reh-end">Ende (optional)</label>
    <input id="reh-end" type="datetime-local" class="input" bind:value={end} min={begin || undefined} />
  </div>

  {#if error}
    <div class="mb-3 text-error">{error}</div>
  {/if}

  <div class="mb-3">
    <label class="form-label" for="reh-comment">Kommentar</label>
    <textarea id="reh-comment" class="input" rows="2" bind:value={comment}></textarea>
  </div>

  <div class="flex justify-end gap-2 mt-2">
    <button class="btn btn-secondary" type="button" onclick={() => modalState.close()}>Abbrechen</button>
    <button class="btn btn-primary" type="submit">Erstellen</button>
  </div>
</form>
