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
  import { updateSurveyFeedback } from '$lib/api.js';
  import { formatGermanDateTime } from '$lib/common.js';
  import { shortFormatGermanDate } from '$lib/common.js';
  import { isDarkMode } from '$lib/themeStore';

    let { survey, users = [], user = {}, updateFeedback, showHeader = true } = $props();

  let hoveredFieldId = $state(null);

  // Helper: Map User-ID → User
  let userById = $derived(new Map(users.map(u => [Number(u.id), u])));

  let sortedFields = $derived([...survey.fields].sort((a, b) =>
    new Date(a.field_text) - new Date(b.field_text)
  ));




  // Helper: Feedback eines Users für ein bestimmtes Feld
  const getFeedbackFor = (field, userId) =>
    field.feedbacks?.find(fb => Number(fb.id_user) === Number(userId));

  // Farbklassen je nach Wert
  const feedbackClass = (value) => {
      if (value === 'a') return 'bg-green-200 dark:bg-green-700';
      if (value === 'o') return 'bg-red-200 dark:bg-red-700';
      if (value === 'm') return 'bg-yellow-200 dark:bg-yellow-700';
      return 'bg-surface-1';
  };

  const nextFeedbackValue = (current) => {
    if (current === 'a') return 'm';
    if (current === 'm') return 'o';
    if (current === 'o') return null; // wieder leer
    return 'a'; // bisher kein Wert
  };

  const feedbackSymbol = (value) => {
    if (value === 'a') return '✓';
    if (value === 'm') return '~';
    if (value === 'o') return '✗';
    return '–';
  };

  const feedbackText = (value) => {
    if (value === 'a') return 'Ja';
    if (value === 'm') return 'Vielleicht';
    if (value === 'o') return 'Nein';
    return 'Keine Angabe';
  };

  const compactHeaderLabel = (fieldText) => {
    const parsed = new Date(fieldText);
    if (Number.isNaN(parsed.getTime())) {
      return shortFormatGermanDate(fieldText);
    }

    const datePart = parsed.toLocaleDateString('de-DE', {
      day: '2-digit',
      month: '2-digit'
    });
    const timePart = parsed.toLocaleTimeString('de-DE', {
      hour: '2-digit',
      minute: '2-digit'
    });
    return `${datePart}\n${timePart}`;
  };

  const setNewFeedback = async (field, userId, value) => {
    // Prevent feedback changes if survey is closed
    if (survey.closed) return;

    // Find the field in the survey
    const fieldIndex = survey.fields.findIndex(f => f.id === field.id);
    if (fieldIndex === -1) return;

    // Find existing feedback for this user in this field
    const feedbackIndex = survey.fields[fieldIndex].feedbacks?.findIndex(
      fb => Number(fb.id_user) === Number(userId)
    );

    // Update or add the feedback locally first
    if (feedbackIndex !== undefined && feedbackIndex >= 0) {
      // Update existing feedback
      survey.fields[fieldIndex].feedbacks[feedbackIndex].value = value;
    } else {
      // Add new feedback
      if (!survey.fields[fieldIndex].feedbacks) {
        survey.fields[fieldIndex].feedbacks = [];
      }
      survey.fields[fieldIndex].feedbacks.push({
        id_sv_field: field.id,
        id_user: userId,
        value: value,
        comment: null
      });
    }

    // Collect all feedbacks from all fields
    const allFeedbacks = survey.fields.flatMap(f =>
      (f.feedbacks || []).map(fb => ({
        id_sv_field: f.id,
        id_user: fb.id_user,
        value: fb.value,
        comment: fb.comment || null
      }))
    );

    try {
      // Send all feedbacks to backend
      const updatedSurvey = await updateSurveyFeedback(null, survey.id, allFeedbacks);

      // Update local survey object with the response
      survey = updatedSurvey;

    } catch (error) {
      console.error('Fehler beim Aktualisieren des Feedbacks:', error);
      // Optionally show error to user or revert local changes
    }
  };

  let heatmapStyles = $derived(new Map(
      sortedFields.map(field => {
        const yesCount = field.feedbacks?.filter(fb => fb.value === 'a').length ?? 0;
        if (yesCount === 0) return [field.id, 'background-color: rgba(0,0,0,0);'];

        const maxCount = Math.max(...survey.fields.map(f =>
          f.feedbacks?.filter(fb => fb.value === 'a').length ?? 0
        ));

        if (maxCount === 0) return [field.id, 'background-color: #f8f9fa;'];

        const intensity = (yesCount / maxCount) * 100;
        const hue = 120 * (intensity / 100);
        const saturation = 35 + (intensity * 0.25);
        const lightness = $isDarkMode
          ? 25 + (intensity * 0.15)
          : 55 + (intensity * 0.15);
        const textColor = $isDarkMode ? '#e2e8f0' : '#334155';

        return [field.id, `background-color: hsl(${hue}, ${saturation}%, ${lightness}%); color: ${textColor};`];
      })
  ));

</script>

<div class="space-y-4 relative">

  {#if showHeader}
  <div>
    <h3 class="text-xl font-semibold text-on-surface">
      {survey.rf_survey}
    </h3>

    <p class="text-sm text-on-surface-variant">
      Terminumfrage ·
      {#if survey.closed}
        geschlossen
      {:else if survey.released}
        veröffentlicht
      {:else}
        Entwurf
      {/if}
      {#if user && Number(survey.user_created) === Number(user.id)}
          <button
                type="button"
                class="ml-4 btn variant-filled-primary btn-sm"
                disabled
          >
          ⚙️
          </button>

      {/if}
    </p>
    <p class="text-sm text-on-surface-variant block md:hidden">
      Erstellt von
      {userById.get(survey.user_created)?.user_name ?? survey.user_created}
      am {shortFormatGermanDate(survey.release_date)}
    </p>
  </div>
  {/if}

  <div class="hidden md:block w-full ">
  <div class="overflow-x-auto rounded pb-4" style="scrollbar-width: thick; scrollbar-color: #3b82f6 #e5e7eb;">

   <table class="border-collapse mx-auto">
      <thead>
        <tr>
          <th class="px-2 py-1 text-left sticky left-0 bg-surface z-10"></th>
          {#each sortedFields as field}
            <th
              class="border border-gray-300 dark:border-gray-600 rotated-header transition-colors"
              class:bg-primary={hoveredFieldId === field.id}
              class:bg-opacity-80={hoveredFieldId === field.id}
              onmouseenter={() => hoveredFieldId = field.id}
              onmouseleave={() => hoveredFieldId = null}
            >
              <span
                    class:font-bold={hoveredFieldId === field.id}
                    class:text-primary-500={hoveredFieldId === field.id}
              >
                {formatGermanDateTime(field.field_text)}
              </span>
            </th>
          {/each}
        </tr>
      </thead>
      <tbody>
        {#each users as u}
          {#if user && u.id === user.id}
            <tr class="spacing-row">
              <td colspan="{survey.fields.length + 1}"></td>
            </tr>
            <tr class="user-row font-bold">
              <td class="px-2 py-1 border border-gray-300 dark:border-gray-600 text-left sticky left-0 bg-surface z-10">
                {u.user_name}
              </td>
              {#each sortedFields as field}
                <td
                  class={`px-2 py-1 border border-gray-300 dark:border-gray-600 text-center transition-colors ${!survey.closed ? 'cursor-pointer' : 'cursor-not-allowed'} ${feedbackClass(getFeedbackFor(field, u.id)?.value)}`}
                  class:ring-2={hoveredFieldId === field.id}
                  class:ring-secondary={hoveredFieldId === field.id}
                  class:brightness-110={hoveredFieldId === field.id}
                  onmouseenter={() => hoveredFieldId = field.id}
                  onmouseleave={() => hoveredFieldId = null}
                  onclick={() => {
                    if (survey.closed) return;
                    const next = nextFeedbackValue(getFeedbackFor(field, u.id)?.value);
                    setNewFeedback(field, u.id, next);
                  }}
                >
                </td>
              {/each}
            </tr>
            <tr class="spacing-row">
              <td colspan="{survey.fields.length + 1}"></td>
            </tr>
          {:else}
            <tr>
              <td class="px-2 py-1 border border-gray-300 dark:border-gray-600 text-left">
                {u.user_name}
              </td>
              {#each sortedFields as field}
                <td
                  class={`px-2 py-1 border border-gray-300 dark:border-gray-600 text-center transition-colors ${feedbackClass(getFeedbackFor(field, u.id)?.value)}`}
                  class:ring-4={hoveredFieldId === field.id}
                  class:ring-secondary={hoveredFieldId === field.id}
                  class:brightness-110={hoveredFieldId === field.id}
                  onmouseenter={() => hoveredFieldId = field.id}
                  onmouseleave={() => hoveredFieldId = null}
                >
                </td>
              {/each}
            </tr>
          {/if}
        {/each}
        <tr class="sum-row">
          <td class="px-2 py-1 border border-gray-300 dark:border-gray-600 text-left">
            Summe
          </td>
          {#each sortedFields as field}
            {@const yesCount = (field.feedbacks?.filter(fb => fb.value === 'a').length ?? 0) - (field.feedbacks?.filter(fb => fb.value === 'o').length ?? 0)}
            {@const maybeCount = field.feedbacks?.filter(fb => fb.value === 'm').length ?? 0}
            <td
              class="px-2 py-1 border border-gray-300 dark:border-gray-600 text-center transition-colors"
              class:ring-4={hoveredFieldId === field.id}
              class:ring-primary={hoveredFieldId === field.id}
              class:brightness-110={hoveredFieldId === field.id}
              style={heatmapStyles.get(field.id)}
              onmouseenter={() => hoveredFieldId = field.id}
              onmouseleave={() => hoveredFieldId = null}
            >
              <div class="font-semibold text-lg">{yesCount}</div>
              <div class="text-xs opacity-80">({maybeCount})</div>
            </td>
          {/each}
        </tr>
      </tbody>
    </table>


  </div>
  </div>
  <!-- Mobile: kompakte Matrix -->
  <div class="md:hidden space-y-3">
    <div class="rounded-lg border border-outline-variant overflow-hidden">
      <div class="overflow-x-auto" style="scrollbar-width: thin;">
        <table class="min-w-max border-collapse text-xs mx-auto">
          <thead>
            <tr>
              <th class="px-2 py-2 text-left sticky left-0 bg-surface z-20 border border-gray-300 dark:border-gray-600 min-w-[9rem]">
                Teilnehmer
              </th>
              {#each sortedFields as field}
                <th class="mobile-compact-header border border-gray-300 dark:border-gray-600 bg-surface z-10" title={formatGermanDateTime(field.field_text)}>
                  <span class="font-semibold">{compactHeaderLabel(field.field_text)}</span>
                </th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#if user}
              {@const currentUser = users.find(u => Number(u.id) === Number(user.id))}
              {#if currentUser}
                <tr class="mobile-spacing-row">
                  <td colspan={sortedFields.length + 1}></td>
                </tr>
                <tr class="font-semibold mobile-user-row mobile-editable-row">
                  <td class="px-2 py-2 border border-gray-300 dark:border-gray-600 sticky left-0 bg-surface z-20">
                    <div class="leading-tight">{currentUser.user_name}</div>
                  </td>
                  {#each sortedFields as field}
                    {@const feedback = getFeedbackFor(field, currentUser.id)}
                    <td class="border border-gray-300 dark:border-gray-600 p-1">
                      <button
                        class={`w-10 h-10 rounded-md text-sm transition-colors ${feedbackClass(feedback?.value)} ${!survey.closed ? 'active:scale-95 cursor-pointer ring-1 ring-primary-300 dark:ring-primary-700' : 'opacity-60 cursor-not-allowed'}`}
                        disabled={survey.closed}
                        aria-label={`${formatGermanDateTime(field.field_text)}: ${feedbackText(feedback?.value)}`}
                        onclick={() => {
                          if (survey.closed) return;
                          const next = nextFeedbackValue(feedback?.value);
                          setNewFeedback(field, currentUser.id, next);
                        }}
                      >
                        {feedbackSymbol(feedback?.value)}
                      </button>
                    </td>
                  {/each}
                </tr>
                <tr class="mobile-spacing-row">
                  <td colspan={sortedFields.length + 1}></td>
                </tr>
                {#if users.filter(u => Number(u.id) !== Number(user.id)).length > 0}
                  <tr class="mobile-divider-row">
                    <td colspan={sortedFields.length + 1}></td>
                  </tr>
                {/if}
              {/if}
            {/if}

            {#each users.filter(u => !user || Number(u.id) !== Number(user.id)) as u}
              <tr class="mobile-user-row">
                <td class="px-2 py-2 border border-gray-300 dark:border-gray-600 sticky left-0 bg-surface z-10">
                  {u.user_name}
                </td>
                {#each sortedFields as field}
                  {@const feedback = getFeedbackFor(field, u.id)}
                  <td class="border border-gray-300 dark:border-gray-600 p-1">
                    <div
                      class={`w-10 h-10 rounded-md text-sm flex items-center justify-center opacity-85 ${feedbackClass(feedback?.value)}`}
                      aria-label={`${u.user_name}, ${formatGermanDateTime(field.field_text)}: ${feedbackText(feedback?.value)}`}
                    >
                      {feedbackSymbol(feedback?.value)}
                    </div>
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
          <tfoot>
            <tr>
              <td class="px-2 py-2 border border-gray-300 dark:border-gray-600 sticky left-0 bg-surface z-20 font-semibold">
                Summe
              </td>
              {#each sortedFields as field}
                {@const yesCount = (field.feedbacks?.filter(fb => fb.value === 'a').length ?? 0) - (field.feedbacks?.filter(fb => fb.value === 'o').length ?? 0)}
                {@const maybeCount = field.feedbacks?.filter(fb => fb.value === 'm').length ?? 0}
                <td
                  class="px-1 py-1 border border-gray-300 dark:border-gray-600 text-center"
                  style={heatmapStyles.get(field.id)}
                >
                  <div class="font-semibold leading-none">{yesCount}</div>
                  <div class="text-[10px] opacity-80 leading-none mt-1">({maybeCount})</div>
                </td>
              {/each}
            </tr>
          </tfoot>
        </table>
      </div>
    </div>

    <p class="text-xs text-on-surface-variant px-1">
      Legende: ✓ Ja, ~ Vielleicht, ✗ Nein, – Keine Angabe
    </p>
  </div>

</div>


<style>
  .rotated-header {
      height: 140px;
      white-space: nowrap;
      padding: 0;
      vertical-align: bottom;
      border: none;
    }

  .rotated-header > span {
        display: block;
        transform: translate(40px, 0px) rotate(315deg);
        transform-origin: left bottom;
        width: 40px;
        border-bottom: 1px solid rgb(209 213 219); /* gray-300 */
        padding: 6px 2px;
  }

  :global(.dark) .rotated-header > span {
        border-bottom: 1px solid rgb(75 85 99); /* gray-600 */
  }

  .user-row {
      border: 2px solid;
      padding-top: 20px;
      padding-bottom: 20px;
      //background-color: rgba(255, 255, 255, 0.5);
    }

  .sum-row {
      border: 1px solid;
      padding-top: 20px;
      padding-bottom: 20px;
      //background-color: rgba(255, 255, 255, 0.5);
    }

  .mobile-compact-header {
      min-width: 58px;
      width: 58px;
      padding: 4px 2px;
      vertical-align: middle;
    }

  .mobile-compact-header > span {
      display: block;
      width: 100%;
      line-height: 1.05;
      font-size: 11px;
      text-align: center;
      white-space: pre;
    }

  .mobile-user-row td {
      border-bottom-width: 2px;
    }

  .mobile-editable-row td {
      border-top-width: 2px;
      border-bottom-width: 2px;
      border-color: rgb(96 165 250);
      background: color-mix(in srgb, rgb(59 130 246) 8%, transparent);
    }

  :global(.dark) .mobile-editable-row td {
      border-color: rgb(59 130 246);
      background: color-mix(in srgb, rgb(59 130 246) 16%, transparent);
    }

  .mobile-spacing-row td {
      height: 8px;
      padding: 0;
      border: 0;
      background: transparent;
    }

  .mobile-divider-row td {
      height: 6px;
      padding: 0;
      border: 0;
      border-top: 2px solid rgb(203 213 225);
      background: transparent;
    }

  :global(.dark) .mobile-divider-row td {
      border-top-color: rgb(71 85 105);
    }
</style>