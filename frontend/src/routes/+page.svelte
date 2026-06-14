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
  import { browser } from '$app/environment';
  import { goto } from '$app/navigation';
  import { login, getAppLogo, getUser } from '$lib/api.js';
  import { invalidateAll } from '$app/navigation';
  import { onMount } from 'svelte';


  let username = '';
  let password = '';
  let error = '';
  let loading = false;
  let logoUrl = null;

  onMount(async () => {
    // Prüfe ob bereits eingeloggt — wenn ja, weiterleiten zu /dashboard
    try {
      await getUser();
      goto('/dashboard');
      return;
    } catch (e) {
      // Nicht eingeloggt — Login-Seite zeigen
    }

    try {
      const blob = await getAppLogo();
      logoUrl = URL.createObjectURL(blob);
    } catch (e) {
      console.warn('Logo konnte nicht geladen werden:', e.message);
    }
  });

  async function doLogin(event) {
    event?.preventDefault?.();
    error = '';
    loading = true;
    try {
      const data = await login(username, password);
      // Token ist jetzt in HttpOnly Cookie gespeichert
      location.href = '/dashboard';
    } catch(e) {
      error = e.message || 'Login fehlgeschlagen';
    } finally {
      loading = false;
    }
  }
</script>

<div class="ui-page h-full grid place-items-center">
	<div class="text-center flex flex-col items-center w-full">
        <!-- Login Box -->

        <div class="grid place-items-center min-h-[70vh] p-3 sm:p-5 w-full">
            <div class="flex flex-col lg:flex-row items-center justify-center gap-4 sm:gap-6 lg:gap-10 w-full max-w-3xl">
                <!-- Logo -->
                <div class="logo-container flex-shrink-0 ">
                    <img src="{logoUrl}" alt="Logo" class="logo-img" />
                </div>

                <!-- Login Form -->
                <form
                    onsubmit={doLogin}
                    class="ui-card max-w-[22rem] w-full p-5 sm:p-6 space-y-4"
                >
                    <h2 class="text-2xl font-semibold text-center mb-3 sm:mb-4 text-on-surface">Login</h2>

                    <div class="form-field">
                        <label for="username" class="form-label text-on-surface-variant">Benutzername</label>
                        <input
                            id="username"
                            type="text"
                            class="ui-input"
                            placeholder="Benutzername"
                            bind:value={username}
                            required
                        />
                    </div>

                    <div class="form-field">
                        <label for="password" class="form-label text-on-surface-variant">Passwort</label>
                        <input
                            id="password"
                            type="password"
                            class="ui-input"
                            placeholder="Passwort"
                            bind:value={password}
                            required
                        />
                    </div>

                    <!-- Modern-style Primary Button -->
                    <button
                        type="submit"
                        class="ui-btn ui-btn-primary w-full h-10 text-base tracking-wide"
                        disabled={loading}
                    >
                        {loading ? '...' : 'Einloggen'}
                    </button>

                    {#if error}
                        <div class="p-2 mt-1 rounded-md bg-error-100 text-error-900 text-center text-sm">
                            {error}
                        </div>
                    {/if}
                </form>
            </div>
        </div>
	</div>
</div>

<style>
	.logo-container {
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.logo-img {
    width: 260px;
    height: 200px;
		object-fit: contain;
	}

	@media (max-width: 1023px) {
		.logo-container {
      margin-bottom: 0.35rem;
		}
		.logo-img {
      width: 190px;
      height: 145px;
			object-fit: contain;
		}
	}
</style>
