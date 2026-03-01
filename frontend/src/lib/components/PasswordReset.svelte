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
    import { resetPassword } from '$lib/api_pw_reset.js';
    import { onMount } from 'svelte';

    export let token = '';
    export let user;

    let newPassword1 = '';
    let newPassword2 = '';
    let showPassword = false;
    let passwordErrors = [];
    let errorMsg = '';
    let successMsg = '';
    let loading = false;

    onMount(() => {
        // Reset form state when component mounts
        newPassword1 = '';
        newPassword2 = '';
        showPassword = false;
        passwordErrors = [];
        errorMsg = '';
        successMsg = '';
        loading = false;
    });

    function togglePasswordVisibility() {
        showPassword = !showPassword;
    }



  function isLongEnough(pw) {
    return pw.length >= 8;
  }
  function hasUpper(pw) {
    return /[A-Z]/.test(pw);
  }
  function hasNumber(pw) {
    return /[0-9]/.test(pw);
  }
  function hasSpecial(pw) {
    return /[-_!@#$%^&*(),.?":{}|<>]/.test(pw);
  }
  function passwordsMatch(p1, p2) {
    return p1 === p2;
  }

  $: canSubmit = (() => {
        const result = passwordsMatch(newPassword1, newPassword2) &&
            isLongEnough(newPassword1) &&
            hasUpper(newPassword1) &&
            hasNumber(newPassword1) &&
            hasSpecial(newPassword1);
        return result;
    })();

  $: passwordErrors = (() => {
      const errors = [];
      if (newPassword1 || newPassword2) {
        if (!passwordsMatch(newPassword1, newPassword2)) {
          errors.push("Die neuen Passwörter stimmen nicht überein.");
        }
        if (!isLongEnough(newPassword1)) {
          errors.push("Mindestens 8 Zeichen.");
        }
        if (!hasUpper(newPassword1)) {
          errors.push("Mindestens ein Großbuchstabe.");
        }
        if (!hasNumber(newPassword1)) {
          errors.push("Mindestens eine Zahl.");
        }
        if (!hasSpecial(newPassword1)) {
          errors.push("Mindestens ein Sonderzeichen.");
        }
      }
      return errors;
  })();

    async function handlePasswordChange() {
       errorMsg = "";
       successMsg = "";
       loading = true;
       try {
          let res = await resetPassword(token, newPassword1);
          successMsg = "Passwort erfolgreich geändert!";
       } catch(e) {
          errorMsg = "Fehler beim Ändern des Passworts. " + (e.message || "");

          newPassword1 = ""; newPassword2 = "";
       } finally {
          loading = false;
       }
    }

</script>


<!-- Passwort ändern Bereich -->
  <div class="mt-9">
    <h3 class="text-xl font-semibold mb-3 text-on-surface">Passwort ändern für User {user.user_name}</h3>
    <form class="flex flex-col gap-5">
      <div class="flex flex-col md:flex-row md:items-center gap-2">
        <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Neues Passwort</label>
        <div class="relative flex-1">
          {#if showPassword}
            <input type="text"
                   class="input rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
                   bind:value={newPassword1}
                   autocomplete="new-password"
                   required />
          {:else}
            <input type="password"
                   class="input rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
                   bind:value={newPassword1}
                   autocomplete="new-password"
                   required />
          {/if}
          <button
            type="button"
            class="absolute right-2 top-1/2 -translate-y-1/2 text-lg text-outline-variant opacity-90 hover:opacity-100"
            on:click={togglePasswordVisibility}
            aria-label={showPassword ? 'Passwort verbergen' : 'Passwort anzeigen'}>
            {showPassword ? '🙈' : '👁️'}
          </button>
        </div>
      </div>
      <div class="flex flex-col md:flex-row md:items-center gap-2">
        <label class="min-w-[140px] text-on-surface-variant mb-1 md:mb-0">Neues Passwort wiederholen</label>
        <input type="password"
               class="input flex-1 rounded-lg border border-outline-variant px-3 py-2 text-base bg-surface-2 text-on-surface"
               bind:value={newPassword2}
               autocomplete="new-password"
               required />
      </div>

      {#if passwordErrors.length}
      <div>
        <ul class="text-error-700 dark:text-error-200 text-sm my-2 list-disc ml-4">
          {#each passwordErrors as msg}
            <li>{msg}</li>
          {/each}
        </ul>
      </div>
      {/if}
      <div class="flex items-center gap-3 pt-2">
        <button
          class="btn variant-filled-primary rounded-lg px-5 py-2 font-semibold text-base"
          disabled={!canSubmit || loading}
          on:click={handlePasswordChange}>
          Passwort ändern
        </button>
        {#if errorMsg}
          <span class="text-error-700 text-sm">{errorMsg}</span>
        {:else if successMsg}
          <span class="text-success-700 text-sm">{successMsg}</span>
        {/if}
      </div>
    </form>
  </div>