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
  import { getModalStore } from '@skeletonlabs/skeleton';

  // Diese Props werden vom Modal übergeben
  export let response = () => {};
  export let parent;

  const modalStore = getModalStore();



  let begin = '';
  let comment = '';
  let error = '';

  function submit() {

    if (!begin) {
      error = 'Bitte ein Datum/Zeit auswählen!';
      console.log(error);
      return;
    }

    if ($modalStore[0].response) $modalStore[0].response({begin, comment})
    //response({ begin, comment });
    modalStore.close();
  }
</script>


<form class="card bg-surface-1 p-4 rounded shadow mb-4" on:submit|preventDefault={submit}>
  <h4 class="h5 mb-3">Neue Probe</h4>
  <div class="mb-3">
    <label class="form-label" for="reh-date">Datum & Zeit</label>
    <input id="reh-date" type="datetime-local" class="input" bind:value={begin} required />
    {#if error}
      <div class="text-error">{error}</div>
    {/if}
  </div>
  <div class="mb-3">
    <label class="form-label" for="reh-comment">Kommentar</label>
    <textarea id="reh-comment" class="input" rows="2" bind:value={comment}></textarea>
  </div>
  <div class="flex justify-end gap-2 mt-2">
    <button class="btn btn-secondary" type="button" on:click={modalStore.close}>Abbrechen</button>
    <button class="btn btn-primary" type="submit">Erstellen</button>
  </div>
</form>
