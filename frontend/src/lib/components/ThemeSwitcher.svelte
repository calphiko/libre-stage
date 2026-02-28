<script>
  import { currentTheme, availableThemes, colorMode, colorModes } from '$lib/themeStore';
</script>

<div class="space-y-4">
  <label class="label">
    <span class="text-on-surface-variant">Theme</span>
    <select class="select rounded-lg border border-outline-variant px-3 py-2 bg-surface-2 text-on-surface" bind:value={$currentTheme}>
      {#each availableThemes as theme}
        <option value={theme.value}>{theme.label}</option>
      {/each}
    </select>
  </label>

  <label class="label">
    <span class="text-on-surface-variant">Modus</span>
    <select class="select rounded-lg border border-outline-variant px-3 py-2 bg-surface-2 text-on-surface" bind:value={$colorMode}>
      {#each colorModes as mode}
        <option value={mode.value}>{mode.label}</option>
      {/each}
    </select>
  </label>
</div>
