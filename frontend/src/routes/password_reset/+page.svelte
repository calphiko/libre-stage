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
