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
	import '../app.css';
	import { currentTheme, colorMode } from '$lib/themeStore';
	import { slide } from 'svelte/transition';
	import { shortFormatGermanDate } from '$lib/common.js';
	import AppLogo from '$lib/components/Logo.svelte';
	import ToastOverlay from '$lib/components/ToastOverlay.svelte';
	import ModalOverlay from '$lib/components/ModalOverlay.svelte';

	import { afterNavigate } from '$app/navigation';
	import { onMount } from 'svelte';
	import { getUser, getVersionJson, logout as apiLogout } from '$lib/api.js';
	import { loadAppConfig } from '$lib/appConfig.js';

	let { children } = $props();

	let version = $state('0.0.0');
	let version_title = $state('');
	let version_date = $state('1970-01-01T00:00:00Z');
	let version_branch = $state('');
	let version_description = $state('');

	let user = $state({
		user_name: null,
		user_group: null
	});

	let sidebarOpen = $state(false);

	const publicPaths = ['/', '/login', '/password_reset'];
	function isPublicPath(pathname: string) {
		return publicPaths.includes(pathname) || pathname.startsWith('/password_reset');
	}

	async function tryLoadUser() {
		try {
			user = await getUser();
		} catch(e) {
			user = { user_name: null, user_group: null };
		}
	}

	async function logout() {
		try {
			await apiLogout();
		} catch (e) {
			console.error('Logout error:', e);
		}
		location.href = '/';
	}

	onMount(async () => {
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

		try {
			await loadAppConfig();
		} catch (e) {
			console.error('Could not load app config', e);
		}

		// User immer laden — auch auf der Login-Seite (Cookie könnte noch gültig sein)
		await tryLoadUser();
	});

	// Nach clientseitiger Navigation User nachladen (z.B. nach Redirect von / → /dashboard)
	afterNavigate(async ({ to }) => {
		if (to && !isPublicPath(to.url.pathname) && !user.user_name) {
			await tryLoadUser();
		}
	});

	function closeOnNavigate() {
		sidebarOpen = false;
	}
</script>

<ToastOverlay />
<ModalOverlay />

<div class="flex h-screen w-screen">
	{#if sidebarOpen && user.user_name}
		<aside class="w-56 shrink-0 bg-surface-100 dark:bg-surface-800 p-4 shadow-lg"
			in:slide={{ x: -224, duration: 250 }}
			out:slide={{ x: -224, duration: 250 }}>

			<button class="px-3 py-2 rounded-lg hover:bg-surface-200 dark:hover:bg-surface-700 mb-4" onclick={() => sidebarOpen = false}>
				〈 Menü
			</button>
			<nav class="space-y-2">
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/dashboard" onclick={closeOnNavigate}>Dashboard</a>
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/gigs" onclick={closeOnNavigate}>Gigs</a>
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/songs" onclick={closeOnNavigate}>Songs</a>
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/proben" onclick={closeOnNavigate}>Proben</a>
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/abstimmungen" onclick={closeOnNavigate}>Abstimmungen</a>
				<a class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700" href="/benutzer" onclick={closeOnNavigate}>Einstellungen</a>
				<button class="block py-1 px-3 rounded hover:bg-surface-200 dark:hover:bg-surface-700 w-full text-left" onclick={() => { logout(); closeOnNavigate(); }}>Logout</button>
			</nav>
		</aside>
	{/if}
	<div class={sidebarOpen && user.user_name ? 'flex-1 flex flex-col h-full overflow-hidden' : 'w-full flex flex-col h-full overflow-hidden'}>
		<!-- Header -->
		{#if user.user_name}
			<header class="bg-surface-100 dark:bg-surface-800 shadow-sm px-4 py-2 flex items-center gap-4">
				{#if !(sidebarOpen && user.user_name)}
					<button class="px-3 py-2 rounded-lg hover:bg-surface-200 dark:hover:bg-surface-700" onclick={() => sidebarOpen = true}>
						☰ Menü
					</button>
				{/if}
				<!-- Desktop -->
				<a href="/dashboard" class="hidden md:flex items-center gap-2">
					<AppLogo size="3rem" />
					<strong class="text-xl uppercase">{version_title}</strong>
				</a>
				<!-- Mobile -->
				<a href="/dashboard" class="md:hidden flex items-center gap-2">
					<AppLogo size="2.5rem" />
					<strong class="text-xl uppercase">{version_title}</strong>
				</a>
			</header>
		{/if}

		<!-- Main Content -->
		<main class="flex-1 overflow-y-auto">
			{@render children()}
		</main>

		<!-- Footer -->
		{#if user.user_name}
			<footer class="bg-surface-100 dark:bg-surface-800 p-4 text-center text-sm text-surface-600 dark:text-surface-300">
				<span>{version_title} {version} {version_branch} ({shortFormatGermanDate(version_date)})</span><br>
				<span>{version_description} • © {new Date().getFullYear()} <a href="https://pakleds-patentoffice.de" target="_blank" rel="noopener noreferrer" class="underline hover:text-surface-900 dark:hover:text-white">Pakled's Patent Office</a></span>
			</footer>
		{/if}
	</div>
</div>

