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
  import { login } from '$lib/api.js';
  import { invalidateAll } from '$app/navigation';


  let username = '';
  let password = '';
  let error = '';
  let loading = false;


  // Falls eingeloggt (durch Cookie), prüfe /me Endpoint
  // Dies wird durch Server-Side Rendering oder onMount geprüft

  async function doLogin() {
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

<div class="container h-full mx-auto flex justify-center items-center">
	<div class="space-y-10 text-center flex flex-col items-center w-full">
        <!-- Login Box -->

        <div class="grid place-items-center min-h-[80vh] bg-surface-1 p-6 w-full">
            <div class="flex flex-col lg:flex-row items-center justify-center gap-8 lg:gap-12 w-full max-w-4xl">
                <!-- Logo -->
                <div class="logo-container flex-shrink-0">
                    <img src="/Logo.svg" alt="Logo" class="logo-img" />
                </div>

                <!-- Login Form -->
                <form
                    on:submit|preventDefault={doLogin}
                    class="max-w-sm w-full bg-surface-2 p-8 rounded-2xl shadow-md space-y-6 border border-outline-variant"
                >
                    <h2 class="text-3xl font-semibold text-center mb-8 text-on-surface">Login</h2>

                    <div class="form-field">
                        <label for="username" class="form-label text-on-surface-variant">Benutzername</label>
                        <input
                            id="username"
                            type="text"
                            class="form-input variant-soft w-full"
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
                            class="form-input variant-soft w-full"
                            placeholder="Passwort"
                            bind:value={password}
                            required
                        />
                    </div>

                    <!-- Modern-style Primary Button -->
                    <button
                        type="submit"
                        class="btn variant-filled-primary w-full h-12 text-lg tracking-wide rounded-lg"
                        disabled={loading}
                    >
                        {loading ? '...' : 'Einloggen'}
                    </button>

                    {#if error}
                        <div class="p-3 mt-3 rounded-lg bg-error-100 text-error-900 text-center">
                            {error}
                        </div>
                    {/if}
                </form>
            </div>
        </div>
	</div>
</div>

<style lang="postcss">
	figure {
		@apply flex relative flex-col;
	}
	figure svg,
	.img-bg {
		@apply w-64 h-64 md:w-80 md:h-80;
	}
	.img-bg {
		@apply absolute z-[-1] rounded-full blur-[50px] transition-all;
		animation: pulse 5s cubic-bezier(0, 0, 0, 0.5) infinite,
			glow 5s linear infinite;
	}
	@keyframes glow {
		0% {
			@apply bg-primary-400/50;
		}
		33% {
			@apply bg-secondary-400/50;
		}
		66% {
			@apply bg-tertiary-400/50;
		}
		100% {
			@apply bg-primary-400/50;
		}
	}
	@keyframes pulse {
		50% {
			transform: scale(1.5);
		}
	}

    .logo-container {
        @apply flex items-center justify-center;
    }

    .logo-img {
        width: 320px;
        height: 250px;
        object-fit: contain;
    }

    @media (max-width: 1023px) {
        .logo-container {
            @apply mb-4;
        }
        .logo-img {
            width: 240px;
            height: 190px;
            object-fit: contain;
        }
    }
</style>
