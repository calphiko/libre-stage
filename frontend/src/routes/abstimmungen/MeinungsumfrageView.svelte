<script>
  import { updateSurveyFeedback } from '$lib/api.js';
  import { browser } from '$app/environment';
  import { shortFormatGermanDate } from '$lib/common.js';
  import SurveyPlot from '$lib/plots/surveyPlot.svelte';

  export let survey;
  export let users;
  export let user;

  $: userById = new Map(users.map(u => [u.id, u]));

  const hasCurrentUserFeedback = (field) => {
    return field.feedbacks?.some((fb) => Number(fb.id_user) === Number(user?.id));
  };

  const getMaxFeedbackCount = () => {
    if (!survey.fields?.length) return 0;
    return Math.max(...survey.fields.map(f => f.feedbacks?.length ?? 0));
  };

  const isTopVoted = (field) => {
    const maxCount = getMaxFeedbackCount();
    return maxCount > 0 && (field.feedbacks?.length ?? 0) === maxCount;
  };

  const getAllFeedbacks = (surveyFields) => {
    return surveyFields.flatMap(f =>
      (f.feedbacks || [])
        .filter(fb => fb.value !== null)
        .map(fb => ({
          id_sv_field: f.id,
          id_user: fb.id_user,
          value: fb.value,
          comment: fb.comment || null
        }))
    );
  };

  const toggleFeedback = async (field) => {
    if (!user || survey.closed) return;

    const fieldId = field.id;
    const userId = user.id;

    // Find existing feedback index
    const existingFeedbackIndex = field.feedbacks?.findIndex(
      fb => Number(fb.id_user) === Number(userId)
    );

    const feedbackExists = existingFeedbackIndex !== undefined && existingFeedbackIndex >= 0;

    if (feedbackExists) {
      // Remove feedback from local state
      field.feedbacks.splice(existingFeedbackIndex, 1);
    } else {
      // Add new feedback to local state
      const newFeedback = {
        id_sv_field: fieldId,
        id_user: userId,
        value: 'a',
        comment: null
      };

      if (!field.feedbacks) {
        field.feedbacks = [];
      }
      field.feedbacks.push(newFeedback);
    }

     const getMaxFeedbackCount = () => {
        if (!survey.fields?.length) return 0;
        return Math.max(...survey.fields.map(f => f.feedbacks?.length ?? 0));
      };

      const isTopVoted = (field) => {
        const maxCount = getMaxFeedbackCount();
        return maxCount > 0 && (field.feedbacks?.length ?? 0) === maxCount;
      };

    try {
      // Collect all feedbacks (excluding removed ones)
      const allFeedbacks = getAllFeedbacks(survey.fields);

      // Send to backend
      const updatedSurvey = await updateSurveyFeedback(null, survey.id, allFeedbacks);

      // THIS IS KEY: Reassign the entire survey object to trigger reactivity
      survey = updatedSurvey;

    } catch (error) {
      console.error('Fehler beim Aktualisieren des Feedbacks:', error);
      // Revert changes on error
      survey = survey; // Force re-render
    }
  };
</script>

<div class="space-y-4">
  <div>
    <h3 class="text-xl font-semibold text-on-surface">
      {survey.rf_survey}
    </h3>
    <p class="text-sm text-on-surface-variant">
      Meinungsumfrage ·
      {#if survey.closed}
        geschlossen
      {:else if survey.released}
        veröffentlicht
      {:else}
        Entwurf
      {/if}
    </p>
    <p class="text-sm text-on-surface-variant block md:hidden">
      Erstellt von
      {userById.get(survey.user_created)?.user_name ?? survey.user_created}
      am {shortFormatGermanDate(survey.release_date)}
    </p>
  </div>

  <SurveyPlot {survey} {users}/>

  {#if survey.fields && survey.fields.length}
    <ul class="space-y-3">
      {#each survey.fields as field (field.id)}
          <li
            class="w-full text-left rounded-lg px-4 py-3 transition-colors
              {!survey.closed ? 'cursor-pointer' : 'cursor-not-allowed'}
              {isTopVoted(field)
                ? 'border-2 border-primary shadow-lg shadow-primary/30 ring-2 ring-primary/20'
                : 'border border-outline-variant'}
              {hasCurrentUserFeedback(field)
                ? 'bg-green-200 dark:bg-green-700'
                : 'bg-surface-1 hover:bg-surface-2'}"
            on:click={() => toggleFeedback(field)}
            role="button"
            tabindex="0"
          >
          <div class="flex items-center justify-between">
              <span class="{isTopVoted(field) ? 'font-bold' : 'font-medium'}">{field.field_text}</span>
              <span class="text-sm text-on-surface-variant">
                {field.feedbacks?.length ?? 0} Stimme{field.feedbacks?.length !== 1 ? 'n' : ''}
              </span>
          </div>

          {#if field.feedbacks && field.feedbacks.length}
            <details class="mt-2">
              <summary
                class="cursor-pointer text-sm text-secondary-500 hover:text-secondary-400"
                on:click|stopPropagation
              >
                Feedbacks anzeigen ({field.feedbacks.length})
              </summary>
              <ul class="mt-2 space-y-1 text-sm">
                {#each field.feedbacks as fb (fb.id_user)}
                  <li class="text-on-surface-variant">
                    {userById.get(Number(fb.id_user))?.clear_name || 'Unbekannter Nutzer'}
                    {#if fb.comment?.trim()}
                      – {fb.comment}
                    {/if}
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