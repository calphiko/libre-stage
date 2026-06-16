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
  let { reh, isPast = false, onopen } = $props();

  const dateOptions = {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  };

  function formatTime(dateLike) {
    return new Date(dateLike).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  }

  function formatRehearsalRangeLabel() {
    const beginDate = new Date(reh.begin);
    const endDate = reh.end ? new Date(reh.end) : null;
    const dateLabel = beginDate.toLocaleDateString('de-DE', dateOptions);
    const beginTime = formatTime(beginDate);

    if (!endDate) return `${dateLabel}, ${beginTime} Uhr`;

    const endTime = formatTime(endDate);
    const sameDay = beginDate.toDateString() === endDate.toDateString();
    if (sameDay) return `${dateLabel}, ${beginTime}-${endTime} Uhr`;

    const endDateLabel = endDate.toLocaleDateString('de-DE', dateOptions);
    return `${dateLabel}, ${beginTime} Uhr - ${endDateLabel}, ${endTime} Uhr`;
  }

  function handleOpen() {
    onopen?.({ id: reh.id });
  }
</script>

<div class="border border-outline-variant rounded-lg mb-1.5 bg-surface-1">
  <button
    type="button"
    class="w-full cursor-pointer px-3 py-2.5 hover:bg-surface-100 dark:hover:bg-surface-700 rounded-lg text-left flex items-center justify-between gap-2"
    onclick={handleOpen}
  >
    <div class="flex items-center gap-2">
      <span class="text-xs">▶</span>
      <span class="text-sm md:text-base font-semibold">{formatRehearsalRangeLabel()}</span>
      {#if isPast}
        <span class="ml-2 text-xs text-surface-400 italic">Protokoll</span>
      {/if}
    </div>
    <span class="text-xs text-on-surface-variant">Details</span>
  </button>
</div>
