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
  import { songFieldsDetails } from '$lib/songFields.js';

  // Diese Props werden vom Modal übergeben
  export let response = () => {};
  export let parent;

  const modalStore = getModalStore();

  let song = {};

  function submit() {
    //console.log("Song: ", song);

    if ($modalStore[0].response) $modalStore[0].response(song)
    //response({ datum, name });
    modalStore.close();
  }

</script>

<div class="card p-6 space-y-4 max-w-4xl w-full max-h-[90vh] flex flex-col">
    <header class="flex justify-between items-center flex-shrink-0">
      <h4 class="h5 mb-3">Neuer Song</h4>
    </header>
    <div class="overflow-y-auto flex-grow">
        <form class=" card bg-surface-1 p-4 rounded shadow mb-4" on:submit|preventDefault={submit}>
          {#each songFieldsDetails as songField}
            {#if songField.type != "singer_list"}
                <div class="mb-3 d-flex align-items-center gap-2 flex-nowrap">
                  <label>
                    {songField.label}
                    {#if songField.required}
                      <span class="text-danger ms-1" style="color:red; white-space:nowrap;">*</span>
                    {/if}
                  </label>

                  {#if songField.type === 'option' && Array.isArray(songField.options)}
                    <select
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      required={songField.required}
                    >
                      {#each songField.options as o}
                        <option value={o.key}>{o.label}</option>
                      {/each}
                    </select>
                  {:else if songField.type === "time"}
                    <input
                      type="time"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      placeholder={songField.label}
                      required={songField.required}
                      step="1"
                    />
                  {:else if songField.type === "date"}
                    <input
                      type="date"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      placeholder={songField.label}
                      required={songField.required}
                    />
                  {:else}
                    <input
                      type="text"
                      class="input flex-grow-1"
                      bind:value={song[songField.key]}
                      placeholder={songField.label}
                      required={songField.required}
                      minlength="1"
                      maxlength="255"
                      pattern=".*\S+.*"
                    />
                  {/if}
                </div>
            {/if}
          {/each}

          <div class="flex justify-end gap-2 mt-2">
            <button class="btn btn-secondary border" type="button" on:click={modalStore.close}>Abbrechen</button>
            <button class="btn btn-primary border" type="submit">Erstellen</button>
          </div>
        </form>
    </div>
</div>