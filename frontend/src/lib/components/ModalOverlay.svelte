<!--
  Modal overlay component - replaces Skeleton v2 <Modal/>
  Uses a global modal store for triggering modals from anywhere.
-->
<script>
  import { modalState } from '$lib/modalState.js';
  import { fade, fly } from 'svelte/transition';

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
</script>

<svelte:window onkeydown={handleKeydown} />

{#if $modalState}
  {@const ModalComponent = $modalState.component}
  <div
    class="fixed inset-0 z-[999] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
    transition:fade={{ duration: 150 }}
    onclick={handleBackdropClick}
    role="dialog"
    aria-modal="true"
  >
    <div
      class="max-h-[90vh] overflow-y-auto"
      transition:fly={{ y: 20, duration: 200 }}
    >
      {#if ModalComponent}
        <ModalComponent
          {...($modalState.props || {})}
          parent={{ close: modalState.close }}
        />
      {/if}
    </div>
  </div>
{/if}
