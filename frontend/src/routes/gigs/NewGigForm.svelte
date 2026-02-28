<script>
  import { getModalStore } from '@skeletonlabs/skeleton';
  import { gigFieldsDetails, kindOfGigOptions } from '$lib/songFields.js';

  // Diese Props werden vom Modal übergeben
  export let response = () => {};
  export let parent;

  const modalStore = getModalStore();



  let gig = {};

  let error = '';

  function submit() {
    console.log("Gig: ", gig);

    if ($modalStore[0].response) $modalStore[0].response(gig)
    //response({ datum, name });
    modalStore.close();
  }
</script>


<div class="card p-6 space-y-4 max-w-4xl w-full max-h-[90vh] flex flex-col">
    <header class="flex justify-between items-center flex-shrink-0">
        <h2 class="h5 mb-3">Neuer Gig</h2>
    </header>
    <div class="overflow-y-auto flex-grow">
        <form class=" card bg-surface-1 p-4 rounded shadow mb-4" on:submit|preventDefault={submit}>
        {#each gigFieldsDetails as gigField}
          <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
            <label>{gigField.label}
            {#if gigField.required}
              <span class="text-danger ms-1" style="color:'red'; white-space:nowrap;">*</span>
            {/if}
            </label>
            {#if gigField.type == 'option' && Array.isArray(gigField.options)}
              <select
                class="input flex-grow-1"
                bind:value={gig[gigField.key]}
                required={gigField.required}
              >
                {#each gigField.options as o}
                  <option value={o.key}>{o.label}</option>
                {/each}
              </select>
            {:else if gigField.type == "text"}
              <input
                type="text"
                class="input flex-grow-1"
                bind:value={gig[gigField.key]}
                placeholder={gigField.label}
                required={gigField.required}
              />
            {:else if gigField.type == "date"}
              <input
                type="date"
                class="input flex-grow-1"
                bind:value={gig[gigField.key]}
                placeholder={gigField.label}
                required={gigField.required}
              />
            {:else if gigField.type == "time"}
              <input
                type="time"
                class="input flex-grow-1"
                bind:value={gig[gigField.key]}
                placeholder={gigField.label}
                required={gigField.required}
              />
            {/if}

          </div>
        {/each}

      <div class="flex justify-end gap-2 mt-2">
        <button class="btn variant-outline-secondary border" type="button" on:click={modalStore.close}>Abbrechen</button>
        <button class="btn variant-filled-success border" type="submit">Erstellen</button>
      </div>
    </form>
  </div>
</div>

<style>
 .input {
    display: block;
 }
</style>