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
