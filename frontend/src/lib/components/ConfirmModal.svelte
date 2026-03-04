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
  import { modalState } from '$lib/modalState.js';

    let { parent, meta = {} } = $props();

  let title = $state(meta.title ?? 'Bestätigung erforderlich');
  let message = $state(meta.message ?? 'Sind Sie sicher, dass Sie fortfahren möchten?');
  let confirmText = $state(meta.confirmText ?? 'Bestätigen');
  let cancelText = $state(meta.cancelText ?? 'Abbrechen');

  function confirm() {
    modalState.close(true);
  }

  function cancel() {
    modalState.close(false);
  }
</script>

<div class="bg-surface-50 dark:bg-surface-800 rounded-xl p-6 space-y-4 max-w-lg w-full shadow-xl">
  <header>
    <h3 class="text-xl font-semibold">{title}</h3>
  </header>

  <div class="text-surface-600 dark:text-surface-300">
    <p>{message}</p>
  </div>

  <footer class="flex justify-end gap-3 mt-6">
    <button
      type="button"
      class="px-4 py-2 rounded-lg border border-surface-300 dark:border-surface-600 hover:bg-surface-100 dark:hover:bg-surface-700"
      onclick={cancel}
    >
      {cancelText}
    </button>
    <button
      type="button"
      class="px-4 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700"
      onclick={confirm}
    >
      {confirmText}
    </button>
  </footer>
</div>
