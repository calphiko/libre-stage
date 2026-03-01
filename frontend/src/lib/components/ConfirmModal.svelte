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

  // Props vom Modal
  export let parent;

  const modalStore = getModalStore();

  // Default-Werte
  let title = 'Bestätigung erforderlich';
  let message = 'Sind Sie sicher, dass Sie fortfahren möchten?';
  let confirmText = 'Bestätigen';
  let cancelText = 'Abbrechen';
  let confirmButtonClass = 'btn variant-filled-error';
  let cancelButtonClass = 'btn variant-outline-secondary';

  // Überschreibe mit meta-Daten, falls vorhanden
  if ($modalStore[0]?.meta) {
    title = $modalStore[0].meta.title ?? title;
    message = $modalStore[0].meta.message ?? message;
    confirmText = $modalStore[0].meta.confirmText ?? confirmText;
    cancelText = $modalStore[0].meta.cancelText ?? cancelText;
    confirmButtonClass = $modalStore[0].meta.confirmButtonClass ?? confirmButtonClass;
    cancelButtonClass = $modalStore[0].meta.cancelButtonClass ?? cancelButtonClass;
  }

  function confirm() {
    if ($modalStore[0].response) {
      $modalStore[0].response(true);
    }
    modalStore.close();
  }

  function cancel() {
    if ($modalStore[0].response) {
      $modalStore[0].response(false);
    }
    modalStore.close();
  }
</script>

<div class="card p-6 space-y-4 max-w-lg w-full">
  <header>
    <h3 class="h3 font-semibold text-on-surface">{title}</h3>
  </header>

  <div class="text-on-surface-variant">
    <p>{message}</p>
  </div>

  <footer class="flex justify-end gap-3 mt-6">
    <button
      type="button"
      class={cancelButtonClass}
      on:click={cancel}
    >
      {cancelText}
    </button>
    <button
      type="button"
      class={confirmButtonClass}
      on:click={confirm}
    >
      {confirmText}
    </button>
  </footer>
</div>


