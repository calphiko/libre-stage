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
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { onMount } from 'svelte';
    import { verifyPwResetToken } from '$lib/api_pw_reset.js';
    import PasswordReset from '$lib/components/PasswordReset.svelte'

    let user = '';
    let token = '';
    let tokenVerified = false;
    const requireOldPassword = false;

    let errorMessage = "";

    onMount(async () => {
        console.log('onMount started');
        console.log('Current URL:', window.location.href);
        token = $page.url.searchParams.get('token');

        if (!token) {
            errorMessage = "Der Link ist ungültig"
            return;
        }
        // Trigger password reset token sending
        try {
            user = await verifyPwResetToken(token);
            tokenVerified = true
        } catch (e) {
            errorMessage=e;
            console.error("Error: ", e)
        }
    });
</script>

{#if errorMessage}
    <div class="alert variant-filled-error">
        <div class="alert-message">
            <p>{errorMessage}</p>
        </div>
    </div>
{ :else }
    {#if tokenVerified}
        <PasswordReset {token} {user}  />

    {/if}
{/if}
