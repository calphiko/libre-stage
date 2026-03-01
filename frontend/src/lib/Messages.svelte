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

<!-- lib/Messages.svelte -->
<script context="module">
  export function createMessageHelpers(toastStore) {
    return {
      showError(message, autohide = 5000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-error',
          autohide: true,
          timeout: autohide
        });
      },
      showSuccess(message, autohide = 3000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-success',
          autohide: true,
          timeout: autohide
        });
      },
      showWarning(message, autohide = 4000) {
        toastStore.trigger({
          message,
          background: 'variant-filled-warning',
          autohide: true,
          timeout: autohide
        });
      }
    };
  }
</script>
