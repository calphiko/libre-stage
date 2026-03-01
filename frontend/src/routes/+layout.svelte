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
	import '../app.postcss';
	import { AppShell, AppBar } from '@skeletonlabs/skeleton';
	import { currentTheme, colorMode } from '$lib/themeStore';

    import { initializeStores, Modal } from '@skeletonlabs/skeleton';
    initializeStores();

	import { invalidateAll } from '$app/navigation';

	import { Toast } from '@skeletonlabs/skeleton';


	import hljs from 'highlight.js/lib/core';
	import 'highlight.js/styles/github-dark.css';
	import { storeHighlightJs } from '@skeletonlabs/skeleton';
	import xml from 'highlight.js/lib/languages/xml'; // for HTML
	import css from 'highlight.js/lib/languages/css';
	import javascript from 'highlight.js/lib/languages/javascript';
	import typescript from 'highlight.js/lib/languages/typescript';
	import { slide } from 'svelte/transition';

	import { shortFormatGermanDate } from '$lib/common.js';
	import AppLogo from '$lib/components/Logo.svelte';

	hljs.registerLanguage('xml', xml); // for HTML
	hljs.registerLanguage('css', css);
	hljs.registerLanguage('javascript', javascript);
	hljs.registerLanguage('typescript', typescript);
	storeHighlightJs.set(hljs);

	// Floating UI for Popups
	import { computePosition, autoUpdate, flip, shift, offset, arrow } from '@floating-ui/dom';
	import { storePopup } from '@skeletonlabs/skeleton';
	storePopup.set({ computePosition, autoUpdate, flip, shift, offset, arrow });

	import { browser } from '$app/environment';
    import { goto } from '$app/navigation';
    import { onMount } from 'svelte';
    import { getUser, getVersionJson, logout as apiLogout } from '$lib/api.js';

    let version = '0.0.0'; // Oder importiere aus einer package.json
    let version_title = '';
    let version_date = '1970-01-01T00:00:00Z';
    let version_branch = '';
    let version_description = '';

    let user = {
       user_name: null,
       user_group: null
    };

    let sidebarOpen = false;

    async function logout() {
      try {
        await apiLogout();
      } catch (e) {
        console.error('Logout error:', e);
      }
      location.href = '/';
    }

    onMount(async () => {
      // Prüfe ob wir auf einer öffentlichen Seite sind (Login, Password Reset)
      const publicPaths = ['/', '/login', '/password_reset'];
      const isPublicPage = publicPaths.includes(window.location.pathname) ||
                           window.location.pathname.startsWith('/password_reset');

      try {
          const data = await getVersionJson();
          version = data.release;
          version_title = data.title;
          version_date = data.date;
          version_branch = data.release_branch;
          version_description = data.description;
      } catch (e) {
          console.error('Could not load version', e);
      }

      // Nur User laden wenn wir nicht auf einer öffentlichen Seite sind
      if (!isPublicPage) {
        try {
          user = await getUser();
        } catch(e) {
          console.error('User konnte nicht geladen werden', e);
          // api.js kümmert sich um die Umleitung
        }
      }
    });

    function closeOnNavigate() {
        sidebarOpen = false;
    }

</script>


<Modal />
<Toast />

<div class="flex h-screen w-screen">
    {#if sidebarOpen && user.user_name}
        <aside class="w-56 shrink-0 bg-surface-500/5 p-4 shadow-lg"
        in:slide={{ x: -224, duration: 250 }}
        out:slide={{ x: -224, duration: 250 }}>

            <button class="btn btn-ghost-surface mb-4" on:click={() => sidebarOpen = false}>
                〈 Menü
            </button>
            <nav class="space-y-2">
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/dashboard" on:click={closeOnNavigate}>Dashboard</a>
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/gigs" on:click={closeOnNavigate}>Gigs</a>
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/songs" on:click={closeOnNavigate}>Songs</a>
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/proben" on:click={closeOnNavigate}>Proben</a>
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/abstimmungen" on:click={closeOnNavigate}>Abstimmungen</a>
                <a class="block py-1 px-3 rounded hover:bg-surface-400/10" href="/benutzer" on:click={closeOnNavigate}>Einstellungen</a>



                <button class="block py-1 px-3 rounded hover:bg-surface-400/10 w-full text-left" on:click={logout} on:click={closeOnNavigate}>Logout</button>
            </nav>
        </aside>
    {/if}
    <main class={sidebarOpen && user.user_name ? 'flex-1' : 'w-full'}>
        <AppShell>
            <svelte:fragment slot="header">
                {#if user.user_name}
                <AppBar>
                    <svelte:fragment slot="trail">

                    </svelte:fragment>
                    <svelte:fragment slot="lead">
                        <!-- Menü-Button im Header, wenn Sidebar versteckt -->
                        {#if !(sidebarOpen && user.user_name)}
                            <button class="btn btn-ghost-surface" on:click={() => sidebarOpen = true}>
                                ☰ Menü
                            </button>
                        {/if}
                        <!-- Desktop: Logo + voller Text -->
                        <a href="/dashboard" class="hidden md:flex items-center gap-2 ">
                          <AppLogo size="3rem" class="py-0 my-0"/>
                          <strong class="text-xl text-on surface uppercase">{version_title}</strong>
                        </a>
                        <!-- Mobile: Logo + kurzer Name -->
                        <a href="/dashboard" class="md:hidden flex items-center gap-2 ">
                          <AppLogo size="2.5rem" class="py-0 my-0"/>
                          <strong class="text-xl text-on surface uppercase">{version_title}</strong>
                        </a>
                    </svelte:fragment>
                </AppBar>
                {/if}
            </svelte:fragment>
            <!-- Toggle-Button im Main, wenn Sidebar ausgeblendet -->

            <slot />

            <svelte:fragment slot="pageFooter">
                {#if user.user_name}
                <footer class="bg-surface-500/5 p-4 text-center text-sm text-surface-600-300-token">
                    <span>{version_title} {version} {version_branch} ({shortFormatGermanDate(version_date)})</span> • <span>© {new Date().getFullYear()} Band Manager</span><br>
                    <span>{version_description}</span>
                </footer>
                {/if}
            </svelte:fragment>
        </AppShell>
    </main>
</div>

text
<style>
    .sidebar {
        transition: width 0.25s cubic-bezier(0.4,0,0.2,1), opacity 0.2s;
        overflow: hidden;
    }
    .sidebar.closed {
        width: 0;
        opacity: 0;
        pointer-events: none;
    }
    .sidebar.open {
        width: 14rem; /* entspricht w-56 */
        opacity: 1;
    }
</style>