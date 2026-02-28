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


