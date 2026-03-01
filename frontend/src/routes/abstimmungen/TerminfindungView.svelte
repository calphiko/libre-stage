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
  import { updateSurveyFeedback } from '$lib/api.js';
  import { browser } from '$app/environment';
  import { formatGermanDateTime } from '$lib/common.js';
  import { shortFormatGermanDate } from '$lib/common.js';
  import { writable } from 'svelte/store';


  export let survey;  // Termin-Umfrage mit fields[]
  export let users = [];
  export let user = {};    // aktueller User
  export let updateFeedback; // function({ field, user, value })

  let hoveredFieldId = null;

  // Helper: Map User-ID → User
  $: userById = new Map(users.map(u => [Number(u.id), u]));

  $: sortedFields = [...survey.fields].sort((a, b) =>
    new Date(a.field_text) - new Date(b.field_text)
  );


  // Create a reactive dark mode store
  const isDarkMode = writable(false);

  // Update on mount and observe changes
  if (browser) {
     isDarkMode.set(document.documentElement.classList.contains('dark'));

      const observer = new MutationObserver(() => {
          console.log('Dark mode changed:', document.documentElement.classList.contains('dark'));

          isDarkMode.set(document.documentElement.classList.contains('dark'));
      });

      observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['class']
      });
  }


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

  const getHeatmapStyle = (field) => {
    const yesCount = field.feedbacks?.filter(fb => fb.value === 'a').length ?? 0;
    if (yesCount == 0) return 'background-color: rgba(0,0,0,0);';
    const maxCount = Math.max(...survey.fields.map(f =>
      f.feedbacks?.filter(fb => fb.value === 'a').length ?? 0
    ));

    if (maxCount === 0) return 'background-color: #f8f9fa;';

    const darkMode = $isDarkMode;
    const intensity = (yesCount / maxCount) * 100;
    const hue = 120 * (intensity / 100);
    const saturation = 35 + (intensity * 0.25);

    const lightness = darkMode
      ? 25 + (intensity * 0.15)
      : 55 + (intensity * 0.15);

    const textColor = darkMode ? '#e2e8f0' : '#334155';

    return `background-color: hsl(${hue}, ${saturation}%, ${lightness}%); color: ${textColor};`;
  };

  $: heatmapStyles = new Map(
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
  );

</script>

<div class="space-y-4 relative">

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

  <div class="hidden md:block w-full ">
  <div class="overflow-x-auto rounded pb-4" style="scrollbar-width: thick; scrollbar-color: #3b82f6 #e5e7eb;">

   <table class="border-collapse">
      <thead>
        <tr>
          <th class="px-2 py-1 text-left sticky left-0 bg-surface z-10"></th>
          {#each sortedFields as field}
            <th
              class="border border-gray-300 dark:border-gray-600 rotated-header transition-colors"
              class:bg-primary={hoveredFieldId === field.id}
              class:bg-opacity-80={hoveredFieldId === field.id}
              on:mouseenter={() => hoveredFieldId = field.id}
              on:mouseleave={() => hoveredFieldId = null}
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
                  on:mouseenter={() => hoveredFieldId = field.id}
                  on:mouseleave={() => hoveredFieldId = null}
                  on:click={() => {
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
                  on:mouseenter={() => hoveredFieldId = field.id}
                  on:mouseleave={() => hoveredFieldId = null}
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
              on:mouseenter={() => hoveredFieldId = field.id}
              on:mouseleave={() => hoveredFieldId = null}
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
  <!-- Mobile: Karten-Layout -->
  <div class="md:hidden space-y-6">
  <!-- Aktueller User zuerst -->
  {#if user}
    {@const currentUser = users.find(u => u.id === user.id)}
    {#if currentUser}
      <div class="card variant-soft-primary p-4">
        <h4 class="font-bold text-lg mb-3">{currentUser.user_name}</h4>
        <div class="space-y-2">
          {#each sortedFields as field}
            {@const feedback = getFeedbackFor(field, currentUser.id)}
            <button
              class={`w-full p-3 rounded-lg text-left ${feedbackClass(feedback?.value)} ${!survey.closed ? 'active:scale-95' : 'opacity-50'}`}
              disabled={survey.closed}
              on:click={() => {
                if (survey.closed) return;
                const next = nextFeedbackValue(feedback?.value);
                setNewFeedback(field, currentUser.id, next);
              }}
            >
              <div class="text-sm font-medium">{formatGermanDateTime(field.field_text)}</div>
              <div class="text-xs opacity-80 mt-1">
                {#if feedback?.value === 'a'}✓ Ja
                {:else if feedback?.value === 'm'}~ Vielleicht
                {:else if feedback?.value === 'o'}✗ Nein
                {:else}– Keine Angabe
                {/if}
              </div>
            </button>
          {/each}
        </div>
      </div>
    {/if}
  {/if}

  <!-- Andere User (ausklappbar) -->
  {#if users.filter(u => !user || u.id !== user.id).length > 0}
    <details class="card variant-soft p-4">
      <summary class="cursor-pointer font-semibold text-lg mb-3">
        Andere Teilnehmer ({users.filter(u => !user || u.id !== user.id).length})
      </summary>
      <div class="space-y-4 mt-4">
        {#each users as u}
          {#if !user || u.id !== user.id}
            <div class="border border-outline-variant rounded-lg p-3">
              <h4 class="font-semibold mb-2">{u.user_name}</h4>
              <div class="space-y-2">
                {#each sortedFields as field}
                  {@const feedback = getFeedbackFor(field, u.id)}
                  <div class={`p-3 rounded-lg ${feedbackClass(feedback?.value)}`}>
                    <div class="text-sm">{formatGermanDateTime(field.field_text)}</div>
                    <div class="text-xs opacity-80 mt-1">
                      {#if feedback?.value === 'a'}✓ Ja
                      {:else if feedback?.value === 'm'}~ Vielleicht
                      {:else if feedback?.value === 'o'}✗ Nein
                      {:else}– Keine Angabe
                      {/if}
                    </div>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        {/each}
      </div>
    </details>
  {/if}

  <!-- Summen -->
  <div class="card variant-soft-tertiary p-4">
    <h4 class="font-bold text-lg mb-3">Summen</h4>
    <div class="space-y-2">
      {#each sortedFields as field}
          {@const yesCount = (field.feedbacks?.filter(fb => fb.value === 'a').length ?? 0) - (field.feedbacks?.filter(fb => fb.value === 'o').length ?? 0)}
          {@const maybeCount = field.feedbacks?.filter(fb => fb.value === 'm').length ?? 0}
          {@const _ = $isDarkMode}
          <td
            class="px-2 py-1 border border-gray-300 dark:border-gray-600 text-center transition-colors"
            class:ring-4={hoveredFieldId === field.id}
            class:ring-primary={hoveredFieldId === field.id}
            class:brightness-110={hoveredFieldId === field.id}
            style={getHeatmapStyle(field)}
            on:mouseenter={() => hoveredFieldId = field.id}
            on:mouseleave={() => hoveredFieldId = null}
          >
            <div class="font-semibold text-lg">{yesCount}</div>
            <div class="text-xs opacity-80">({maybeCount})</div>
          </td>
      {/each}
    </div>
  </div>
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
</style>