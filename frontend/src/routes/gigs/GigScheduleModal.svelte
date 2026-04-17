<script>
  import { onMount } from 'svelte';
  import { getGigSchedule, getGigSchedulePDF } from '$lib/api.js';
  import { createMessageHelpers } from '$lib/Messages.svelte';
  import { modalState } from '$lib/modalState.js';
  import GigSchedule from './GigSchedule.svelte';

  const { showError } = createMessageHelpers();

  let { meta = {} } = $props();
  const { gig, canEdit = false, scheduleData: initialScheduleData = null, onScheduleUpdated = () => {} } = meta;

  let loading = $state(false);
  let scheduleData = $state(initialScheduleData);

  async function loadSchedule(force = false) {
    if (!gig?.id) return;
    if (scheduleData && !force) return;

    loading = true;
    try {
      scheduleData = await getGigSchedule(null, gig.id);
      onScheduleUpdated(scheduleData);
    } catch (e) {
      showError(e.message ?? 'Ablaufplan konnte nicht geladen werden');
    } finally {
      loading = false;
    }
  }

  function handleScheduleUpdated(data) {
    scheduleData = data;
    onScheduleUpdated(data);
  }

  async function exportPdf() {
    if (!gig?.id) return;
    try {
      const blob = await getGigSchedulePDF(null, gig.id);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `ablaufplan_${gig.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (e) {
      showError(e.message ?? 'Ablaufplan-PDF konnte nicht exportiert werden');
    }
  }

  onMount(async () => {
    await loadSchedule();
  });
</script>

<div class="card p-6 space-y-4 w-[90vw] max-w-4xl max-h-[90vh] flex flex-col modal-base">
  <header class="flex justify-between items-center flex-shrink-0">
    <h2 class="h3">📋 Ablaufplan - {gig?.name ?? 'Gig'}</h2>
    <div class="flex items-center gap-2">
      <button type="button" class="btn btn-sm variant-outline-primary" onclick={exportPdf}>PDF exportieren</button>
      <button type="button" class="btn-icon btn-icon-sm variant-ghost" onclick={() => modalState.close()}>✕</button>
    </div>
  </header>

  <div class="overflow-y-auto flex-grow min-h-0 space-y-4 pr-1">
    {#if loading && !scheduleData}
      <div class="flex justify-center py-12">
        <div class="animate-spin rounded-full h-10 w-10 border-b-2 border-primary-500"></div>
      </div>
    {:else}
      <GigSchedule
        gig={gig}
        canEdit={canEdit}
        scheduleData={scheduleData}
        onScheduleUpdated={handleScheduleUpdated}
      />
    {/if}
  </div>

  <footer class="flex justify-between pt-2 flex-shrink-0 border-t border-surface-300 dark:border-surface-700">
    <button type="button" class="btn btn-sm variant-outline-secondary" onclick={() => loadSchedule(true)}>Neu laden</button>
    <button type="button" class="btn variant-ghost" onclick={() => modalState.close()}>Schliessen</button>
  </footer>
</div>


