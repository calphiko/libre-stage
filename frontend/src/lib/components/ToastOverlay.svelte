<!--
  Toast overlay component - replaces Skeleton v2 <Toast/>
-->
<script>
  import { toastState } from '$lib/toast.js';
  import { fly } from 'svelte/transition';
</script>

{#if $toastState.length > 0}
  <div class="fixed top-4 right-4 z-[9999] flex flex-col gap-2 max-w-sm">
    {#each $toastState as toast (toast.id)}
      <div
        transition:fly={{ x: 300, duration: 300 }}
        class="rounded-lg px-4 py-3 text-sm font-medium shadow-lg
          {toast.type === 'error' ? 'bg-red-600 text-white' : ''}
          {toast.type === 'success' ? 'bg-green-600 text-white' : ''}
          {toast.type === 'warning' ? 'bg-yellow-500 text-black' : ''}
          {!toast.type ? 'bg-surface-700 text-white' : ''}"
      >
        <div class="flex items-center justify-between gap-3">
          <span>{toast.message}</span>
          <button
            class="text-current opacity-70 hover:opacity-100 font-bold text-lg leading-none"
            onclick={() => toastState.remove(toast.id)}
          >
            ✕
          </button>
        </div>
      </div>
    {/each}
  </div>
{/if}

