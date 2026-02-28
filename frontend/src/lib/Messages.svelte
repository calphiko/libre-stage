<!-- lib/Messages.svelte -->
<script context="module">
  export function createMessageHelpers(toastStore) {
    return {
      showError(message, autohide = 5000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-error',
          autohide: true,
          timeout: autohide
        });
      },
      showSuccess(message, autohide = 3000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-success',
          autohide: true,
          timeout: autohide
        });
      },
      showWarning(message, autohide = 4000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-warning',
          autohide: true,
          timeout: autohide
        });
      }
    };
  }
</script>
