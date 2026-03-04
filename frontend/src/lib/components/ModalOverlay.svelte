<!--
  Modal overlay component - replaces Skeleton v2 <Modal/>
  Uses a global modal store for triggering modals from anywhere.
-->
<script>
  import { modalState } from '$lib/modalState.js';
  import { fade, fly } from 'svelte/transition';

  // Lokale Kopie — bleibt während der Ausblend-Animation erhalten
  // auch wenn $modalState bereits null ist
  let currentModal = $state(null);

  $effect(() => {
    if ($modalState !== null) {
      currentModal = $modalState;
    }
  });

  function handleBackdropClick(e) {
    if (e.target === e.currentTarget) {
      modalState.close();
    }
  }

  function handleKeydown(e) {
    if (e.key === 'Escape') {
      modalState.close();
    }
  }

  function onOutroEnd() {
    // Erst nach der Transition leeren
    currentModal = null;
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if $modalState}
  {@const ModalComponent = currentModal?.component}
  <div
    class="fixed inset-0 z-[999] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
    transition:fade={{ duration: 150 }}
    onclick={handleBackdropClick}
    role="dialog"
    aria-modal="true"
    onoutroend={onOutroEnd}
  >
    <div
      class="max-h-[90vh] overflow-y-auto"
      transition:fly={{ y: 20, duration: 200 }}
      onclick={(e) => e.stopPropagation()}
    >
      {#if ModalComponent}
        <ModalComponent
          {...(currentModal?.props || {})}
          parent={{ close: modalState.close }}
        />
      {/if}
    </div>
  </div>
{/if}
