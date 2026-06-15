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

<script lang="ts">
  import { updateSurveyFeedback } from '$lib/api.js';
  import { shortFormatGermanDate } from '$lib/common.js';
  import SurveyPlot from '$lib/plots/surveyPlot.svelte';

  let { survey, users, user, showHeader = true } = $props();

  // Farbpalette — Index-basiert zyklisch zugeordnet
  const FIELD_COLORS = [
    '#3b82f6', // blau
    '#f59e0b', // amber
    '#10b981', // grün
    '#ef4444', // rot
    '#8b5cf6', // violett
    '#06b6d4', // cyan
    '#f97316', // orange
    '#ec4899', // pink
    '#84cc16', // lime
    '#14b8a6', // teal
  ];

  let userById = $derived(new Map(users.map(u => [u.id, u])));

  // Farben-Array für den Plot — volle Farben, Index-basiert
  let fieldColors = $derived(
    survey.fields?.map((_: any, i: number) => FIELD_COLORS[i % FIELD_COLORS.length]) ?? []
  );

  const hasCurrentUserFeedback = (field) =>
    field.feedbacks?.some((fb) => Number(fb.id_user) === Number(user?.id));

  const getMaxFeedbackCount = () => {
    if (!survey.fields?.length) return 0;
    return Math.max(...survey.fields.map(f => f.feedbacks?.length ?? 0));
  };

  const isTopVoted = (field) => {
    const maxCount = getMaxFeedbackCount();
    return maxCount > 0 && (field.feedbacks?.length ?? 0) === maxCount;
  };

  const getAllFeedbacks = (surveyFields) =>
    surveyFields.flatMap(f =>
      (f.feedbacks || [])
        .filter(fb => fb.value !== null)
        .map(fb => ({
          id_sv_field: f.id,
          id_user: fb.id_user,
          value: fb.value,
          comment: fb.comment || null
        }))
    );

  const toggleFeedback = async (field) => {
    if (!user || survey.closed) return;

    const fieldId = field.id;
    const userId = user.id;

    const existingFeedbackIndex = field.feedbacks?.findIndex(
      fb => Number(fb.id_user) === Number(userId)
    );
    const feedbackExists = existingFeedbackIndex !== undefined && existingFeedbackIndex >= 0;

    if (feedbackExists) {
      field.feedbacks.splice(existingFeedbackIndex, 1);
    } else {
      if (!field.feedbacks) field.feedbacks = [];
      field.feedbacks.push({ id_sv_field: fieldId, id_user: userId, value: 'a', comment: null });
    }

    try {
      const allFeedbacks = getAllFeedbacks(survey.fields);
      const updatedSurvey = await updateSurveyFeedback(null, survey.id, allFeedbacks);
      survey = updatedSurvey;
    } catch (error) {
      console.error('Fehler beim Aktualisieren des Feedbacks:', error);
      survey = survey;
    }
  };
</script>

<div class="space-y-2.5 text-sm">
  {#if showHeader}
  <div>
    <h3 class="text-lg font-semibold text-on-surface">{survey.rf_survey}</h3>
    <p class="text-xs text-on-surface-variant">
      Meinungsumfrage ·
      {#if survey.closed}geschlossen
      {:else if survey.released}veröffentlicht
      {:else}Entwurf{/if}
    </p>
    <p class="text-xs text-on-surface-variant block md:hidden">
      Erstellt von {userById.get(survey.user_created)?.user_name ?? survey.user_created}
      am {shortFormatGermanDate(survey.release_date)}
    </p>
  </div>
  {/if}

  <SurveyPlot {survey} {users} {fieldColors} barHeight={260} donutHeight={260} />

  {#if survey.fields && survey.fields.length}
    <ul class="space-y-2">
      {#each survey.fields as field, index (field.id)}
        {@const selected = hasCurrentUserFeedback(field)}
        {@const color = FIELD_COLORS[index % FIELD_COLORS.length]}
        {@const top = isTopVoted(field)}
        <li
          class="w-full text-left rounded-md px-3 py-2 transition-all duration-200 border
            {!survey.closed ? 'cursor-pointer' : 'cursor-not-allowed'}"
          style="
            background-color: {selected ? color + '22' : 'transparent'};
            border-color: {selected ? color : 'rgba(var(--color-surface-300-700), 0.5)'};
            {top ? `box-shadow: 0 4px 12px ${color}40;` : ''}
          "
          onclick={() => toggleFeedback(field)}
          role="button"
          tabindex="0"
          onkeydown={(e) => e.key === 'Enter' && toggleFeedback(field)}
        >
          <div class="flex items-center gap-3">
            <!-- Farbiger Nummern-Badge: ausgegraut wenn nicht gewählt, farbig wenn gewählt -->
            <span
              class="flex-shrink-0 w-6 h-6 rounded-full flex items-center justify-center text-[11px] font-bold text-white transition-all duration-200"
              style="background-color: {selected ? color : color + '60'}; {selected ? `box-shadow: 0 0 8px ${color}80;` : ''}"
            >
              {index + 1}
            </span>

            <div class="flex-1 flex items-center justify-between gap-2">
              <span class="text-sm {top ? 'font-bold' : 'font-medium'} {selected ? 'text-on-surface' : 'text-on-surface-variant'} transition-colors">
                {field.field_text}
              </span>
              <span class="text-xs text-on-surface-variant whitespace-nowrap">
                {field.feedbacks?.length ?? 0} Stimme{field.feedbacks?.length !== 1 ? 'n' : ''}
              </span>
            </div>
          </div>

          {#if field.feedbacks && field.feedbacks.length}
            <details class="mt-1.5 ml-8">
              <summary
                class="cursor-pointer text-xs text-secondary-500 hover:text-secondary-400"
                onclick={(e) => e.stopPropagation()}
              >
                Feedbacks anzeigen ({field.feedbacks.length})
              </summary>
              <ul class="mt-1.5 space-y-0.5 text-xs">
                {#each field.feedbacks as fb (fb.id_user)}
                  <li class="text-on-surface-variant">
                    {userById.get(Number(fb.id_user))?.clear_name ?? 'Unbekannter Nutzer'}
                    {#if fb.comment?.trim()} – {fb.comment}{/if}
                  </li>
                {/each}
              </ul>
            </details>
          {/if}
        </li>
      {/each}
    </ul>
  {:else}
    <p class="text-on-surface-variant italic">
      Für diese Meinungsumfrage sind noch keine Antwortoptionen definiert.
    </p>
  {/if}
</div>

