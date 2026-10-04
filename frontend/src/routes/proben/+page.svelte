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
	import {
		getRehearsalList,
		getPastRehearsals,
		getSongs,
		getUserList,
		updateRehearsals,
		createNewRehearsal,
		deleteRehearsal,
		getUser
	} from '$lib/api.js';

	import { createMessageHelpers } from '$lib/Messages.svelte';
	const { showError, showSuccess, showWarning } = createMessageHelpers();

	import NewRehearsalForm from './NewRehearsalForm.svelte';
	import ConfirmModal from '$lib/components/ConfirmModal.svelte';
	import RehearsalCard from './RehearsalCard.svelte';
	import RehearsalDetailsModal from './RehearsalDetailsModal.svelte';
	import RehearsalMonthPlot from '$lib/plots/rehearsalMonthPlot.svelte';
	import { modalState } from '$lib/modalState.js';

	import { onMount } from 'svelte';

	let rehearsals = $state([]);
	let pastRehearsals = $state([]);
	let pastTotal = $state(0);
	let songs = $state([]);
	let users = $state([]);
	let user = $state({ user_name: null, user_group: null });
	let songsForSearch = $state([]);

	let error = $state('');
	let showHelp = $state(false);
	let tabSet = $state(0);
	let isUpdating = $state(false);

	let isEditor = $derived(user && (user.user_group === 'admin' || user.user_group === 'editor'));

	let now = $derived(new Date());

	function endOfNextDay(dateStr) {
		const d = new Date(dateStr);
		d.setDate(d.getDate() + 1);
		d.setHours(23, 59, 59, 999);
		return d;
	}

	let upcomingRehearsals = $derived(
		rehearsals
			.filter((r) => endOfNextDay(r.begin) >= now)
			.sort((a, b) => new Date(a.begin) - new Date(b.begin))
	);

	let pastRehearsalsFilter = $state('');
	let isLoadingPast = $state(false);
	const pastPageLimit = 20;
	let hasMorePast = $derived(pastRehearsals.length < pastTotal);
	let pastSearchTimer = null;
	let allRehearsals = $derived([...rehearsals, ...pastRehearsals]);
	let rehearsalStats = $derived(getRehearsalStats(allRehearsals));
	let topSongsPage = $state(0);
	const topSongsPageSize = 5;
	let topSongsPageCount = $derived(
		Math.max(1, Math.ceil((rehearsalStats.topSongs?.length ?? 0) / topSongsPageSize))
	);
	let paginatedTopSongs = $derived(
		(rehearsalStats.topSongs ?? []).slice(
			topSongsPage * topSongsPageSize,
			(topSongsPage + 1) * topSongsPageSize
		)
	);

	$effect(() => {
		const maxPage = Math.max(0, topSongsPageCount - 1);
		if (topSongsPage > maxPage) {
			topSongsPage = maxPage;
		}
	});

	let rehearsalPeriod = $state('month');
	let rehearsalMonthData = $derived(
		rehearsalPeriod === 'year'
			? buildRehearsalYearData(allRehearsals)
			: buildRehearsalMonthData(allRehearsals)
	);
	let rehearsalSongsPerPeriodData = $derived(
		rehearsalPeriod === 'year'
			? buildRehearsalSongsPerYearData(allRehearsals)
			: buildRehearsalSongsPerMonthData(allRehearsals)
	);
	let rehearsalTrend = $derived(getTrendStats(rehearsalMonthData));
	let songsPerRehearsalTrend = $derived(getTrendStats(rehearsalSongsPerPeriodData));

	function buildRehearsalMonthData(rehearsalSet) {
		const monthCounts = new Map();

		for (const rehearsal of rehearsalSet) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (!begin || Number.isNaN(begin.getTime())) continue;

			const monthKey = `${begin.getFullYear()}-${String(begin.getMonth() + 1).padStart(2, '0')}`;
			const label = begin.toLocaleDateString('de-DE', { month: 'short', year: 'numeric' });

			const current = monthCounts.get(monthKey) ?? { monthKey, label, count: 0 };
			current.count += 1;
			monthCounts.set(monthKey, current);
		}

		return [...monthCounts.values()].sort((a, b) => a.monthKey.localeCompare(b.monthKey));
	}

	function buildRehearsalYearData(rehearsalSet) {
		const yearCounts = new Map();

		for (const rehearsal of rehearsalSet) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (!begin || Number.isNaN(begin.getTime())) continue;

			const yearKey = String(begin.getFullYear());
			const current = yearCounts.get(yearKey) ?? { yearKey, label: yearKey, count: 0 };
			current.count += 1;
			yearCounts.set(yearKey, current);
		}

		return [...yearCounts.values()].sort((a, b) => a.yearKey.localeCompare(b.yearKey));
	}

	function buildRehearsalSongsPerMonthData(rehearsalSet) {
		const monthTotals = new Map();

		for (const rehearsal of rehearsalSet) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (!begin || Number.isNaN(begin.getTime())) continue;

			const monthKey = `${begin.getFullYear()}-${String(begin.getMonth() + 1).padStart(2, '0')}`;
			const label = begin.toLocaleDateString('de-DE', { month: 'short', year: 'numeric' });
			const current = monthTotals.get(monthKey) ?? {
				monthKey,
				label,
				totalSongs: 0,
				count: 0
			};
			current.totalSongs += Array.isArray(rehearsal?.songs) ? rehearsal.songs.length : 0;
			current.count += 1;
			monthTotals.set(monthKey, current);
		}

		return [...monthTotals.values()]
			.sort((a, b) => a.monthKey.localeCompare(b.monthKey))
			.map((item) => ({
				...item,
				count: item.count > 0 ? item.totalSongs / item.count : 0,
				label: item.label
			}));
	}

	function buildRehearsalSongsPerYearData(rehearsalSet) {
		const yearTotals = new Map();

		for (const rehearsal of rehearsalSet) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (!begin || Number.isNaN(begin.getTime())) continue;

			const yearKey = String(begin.getFullYear());
			const current = yearTotals.get(yearKey) ?? {
				yearKey,
				label: yearKey,
				totalSongs: 0,
				count: 0
			};
			current.totalSongs += Array.isArray(rehearsal?.songs) ? rehearsal.songs.length : 0;
			current.count += 1;
			yearTotals.set(yearKey, current);
		}

		return [...yearTotals.values()]
			.sort((a, b) => Number(a.yearKey) - Number(b.yearKey))
			.map((item) => ({
				...item,
				count: item.count > 0 ? item.totalSongs / item.count : 0,
				label: item.label
			}));
	}

	function getTrendStats(data) {
		if (!Array.isArray(data) || data.length < 2) return null;

		const current = Number(data.at(-1)?.count ?? 0);
		const previous = Number(data.at(-2)?.count ?? 0);
		const delta = current - previous;
		const percent = previous === 0 ? (current === 0 ? 0 : 100) : (delta / previous) * 100;

		return {
			current,
			previous,
			delta,
			percent,
			isPositive: delta >= 0,
			direction: delta >= 0 ? '↑' : '↓'
		};
	}

	function getSongDisplayName(song) {
		if (!song) return 'Unbekannt';
		const interpret = song.interpret || 'Unbekannter Interpret';
		const title = song.title || 'Unbekannter Titel';
		return `${interpret} – ${title}`;
	}

	function formatDurationMinutes(minutes) {
		if (!Number.isFinite(minutes) || minutes <= 0) return '–';
		const hours = Math.floor(minutes / 60);
		const mins = Math.round(minutes % 60);
		if (hours > 0) {
			return `${hours}h ${mins}m`;
		}
		return `${mins}m`;
	}

	function getRehearsalStats(rehearsalSet) {
		const rehearsalsToAnalyze = Array.isArray(rehearsalSet) ? rehearsalSet.filter(Boolean) : [];

		if (rehearsalsToAnalyze.length === 0) {
			return {
				totalRehearsals: 0,
				totalSongEntries: 0,
				averageSongsPerRehearsal: 0,
				averageSongsPerRehearsalYearly: 0,
				averageDurationMinutes: 0,
				openTodos: 0,
				totalTodos: 0,
				topSongs: [],
				mostActiveMonth: null,
				biggestRehearsal: null
			};
		}

		const songCounts = new Map();
		const monthCounts = new Map();
		let totalSongEntries = 0;
		let totalTodos = 0;
		let openTodos = 0;
		let totalMinutes = 0;
		let biggestRehearsal = null;

		for (const rehearsal of rehearsalsToAnalyze) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (begin && !Number.isNaN(begin.getTime())) {
				const monthKey = begin.toLocaleDateString('de-DE', { month: 'long', year: 'numeric' });
				monthCounts.set(monthKey, (monthCounts.get(monthKey) ?? 0) + 1);
			}

			const rehearsalSongs = Array.isArray(rehearsal?.songs) ? rehearsal.songs : [];
			const rehearsalSongCount = rehearsalSongs.length;
			totalSongEntries += rehearsalSongCount;

			if (rehearsalSongCount > (biggestRehearsal?.songCount ?? -1)) {
				biggestRehearsal = {
					id: rehearsal.id,
					begin: rehearsal.begin,
					songCount: rehearsalSongCount
				};
			}

			const rehearsalDurationMinutes = (() => {
				const beginDate = rehearsal?.begin ? new Date(rehearsal.begin) : null;
				const endDate = rehearsal?.end ? new Date(rehearsal.end) : null;
				if (
					!beginDate ||
					Number.isNaN(beginDate.getTime()) ||
					!endDate ||
					Number.isNaN(endDate.getTime())
				) {
					return 0;
				}
				return (endDate.getTime() - beginDate.getTime()) / 60000;
			})();
			totalMinutes += rehearsalDurationMinutes;

			for (const song of rehearsalSongs) {
				const songKey = getSongDisplayName(song);
				songCounts.set(songKey, (songCounts.get(songKey) ?? 0) + 1);

				if (Array.isArray(song.song_todos)) {
					totalTodos += song.song_todos.length;
					openTodos += song.song_todos.filter((todo) => !todo.done).length;
				}
			}
		}

		const topSongs = [...songCounts.entries()]
			.map(([name, count]) => ({ name, count }))
			.sort((a, b) => b.count - a.count)
			.slice(0, 5);

		const mostActiveMonth = [...monthCounts.entries()].sort((a, b) => b[1] - a[1])[0] ?? null;
		const yearlyAverages = new Map();
		for (const rehearsal of rehearsalsToAnalyze) {
			const begin = rehearsal?.begin ? new Date(rehearsal.begin) : null;
			if (!begin || Number.isNaN(begin.getTime())) continue;

			const yearKey = String(begin.getFullYear());
			const current = yearlyAverages.get(yearKey) ?? { totalSongs: 0, count: 0 };
			current.totalSongs += Array.isArray(rehearsal?.songs) ? rehearsal.songs.length : 0;
			current.count += 1;
			yearlyAverages.set(yearKey, current);
		}

		const yearlyAveragesList = [...yearlyAverages.entries()].map(([year, values]) => ({
			year,
			average: values.count > 0 ? values.totalSongs / values.count : 0
		}));
		const latestYearAverage = yearlyAveragesList.sort((a, b) => Number(b.year) - Number(a.year))[0];

		return {
			totalRehearsals: rehearsalsToAnalyze.length,
			totalSongEntries,
			averageSongsPerRehearsal:
				rehearsalsToAnalyze.length > 0 ? totalSongEntries / rehearsalsToAnalyze.length : 0,
			averageSongsPerRehearsalYearly: latestYearAverage ? latestYearAverage.average : 0,
			averageDurationMinutes:
				rehearsalsToAnalyze.length > 0 ? totalMinutes / rehearsalsToAnalyze.length : 0,
			openTodos,
			totalTodos,
			topSongs,
			mostActiveMonth: mostActiveMonth
				? { label: mostActiveMonth[0], count: mostActiveMonth[1] }
				: null,
			biggestRehearsal
		};
	}

	async function loadPastRehearsals({ reset = false } = {}) {
		if (isLoadingPast) return;
		isLoadingPast = true;
		try {
			const skip = reset ? 0 : pastRehearsals.length;
			const page = await getPastRehearsals(null, {
				query: pastRehearsalsFilter.trim(),
				skip,
				limit: pastPageLimit
			});
			if (reset) {
				pastRehearsals = page.items ?? [];
			} else {
				pastRehearsals = [...pastRehearsals, ...(page.items ?? [])];
			}
			pastTotal = page.total ?? 0;
		} catch (e) {
			showError('Vergangene Proben konnten nicht geladen werden');
			console.error('Vergangene Proben load error:', e);
		} finally {
			isLoadingPast = false;
		}
	}

	function queuePastSearch() {
		if (pastSearchTimer) clearTimeout(pastSearchTimer);
		pastSearchTimer = setTimeout(() => {
			loadPastRehearsals({ reset: true });
		}, 250);
	}

	async function openPastTab() {
		tabSet = 1;
		if (pastRehearsals.length === 0) {
			await loadPastRehearsals({ reset: true });
		}
	}

	function buildSongsForSearch() {
		return songs.map((song) => ({
			label: `${song.interpret} - ${song.title}`,
			value: song.id
		}));
	}

	onMount(async () => {
		try {
			user = await getUser();
		} catch (e) {
			user = { user_name: null, user_group: null };
			error = 'User/Gigs konnten nicht geladen werden';
			console.error('Proben load error:', e);
			return; // Bei Auth-Fehlern wird automatisch von api.js umgeleitet
		}

		try {
			rehearsals = await getRehearsalList(null, { limit: 200 });
			songs = await getSongs();
			songsForSearch = buildSongsForSearch();
			users = await getUserList();
			await loadPastRehearsals({ reset: true });
		} catch (e) {
			error = 'Probenliste konnte nicht geladen werden';
			console.error('Probenliste load error:', e);
			// Bei Auth-Fehlern wird automatisch von api.js umgeleitet
		}
	});

	async function updateRehearsal(data) {
		if (isUpdating) return;
		isUpdating = true;

		try {
			await updateRehearsals(null, data);
			rehearsals = await getRehearsalList(null, { limit: 200 });
			if (tabSet === 1) {
				await loadPastRehearsals({ reset: true });
			}
		} finally {
			isUpdating = false;
		}
	}

	async function addRehearsal(data) {
		await createNewRehearsal(null, data);
		rehearsals = await getRehearsalList(null, { limit: 200 });
		if (tabSet === 1) {
			await loadPastRehearsals({ reset: true });
		}
	}

	async function delRehearsal(rehId, rehDate) {
		modalState.trigger({
			component: ConfirmModal,
			meta: {
				title: 'Probe löschen',
				message: `Möchten Sie die Probe vom ${rehDate} wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`,
				confirmText: 'Löschen',
				cancelText: 'Abbrechen',
				confirmButtonClass: 'btn variant-filled-error',
				cancelButtonClass: 'btn variant-outline-secondary'
			},
			response: async (confirmed) => {
				if (confirmed) {
					try {
						await deleteRehearsal(null, rehId);
						rehearsals = await getRehearsalList(null, { limit: 200 });
						if (tabSet === 1) {
							await loadPastRehearsals({ reset: true });
						}
						modalState.close();
						showSuccess('Probe erfolgreich gelöscht');
					} catch (e) {
						showError('Fehler beim Löschen der Probe');
						console.error('Fehler beim Löschen der Probe:', e);
					}
				}
			}
		});
	}

	function openNewRehearsalModal() {
		modalState.trigger({
			component: NewRehearsalForm,
			title: 'Neue Probe erstellen',
			body: 'Startzeit wählen, optional Endzeit ergänzen und speichern.',
			response: (r) => r && addRehearsal(r)
		});
	}

	function openRehearsalDetails(reh, isPast = false, searchQuery = '') {
		modalState.trigger({
			component: RehearsalDetailsModal,
			props: {
				reh,
				songs,
				songsForSearch,
				users,
				isEditor,
				isPast,
				searchQuery,
				currentUserId: user?.id ?? null,
				onupdate: (e) => updateRehearsal(e.reh),
				ondelete: (e) => delRehearsal(e.id, e.date),
				onerror: (e) => showError(e.message),
				onwarning: (e) => showWarning(e.message),
				onsuccess: (e) => showSuccess(e.message)
			}
		});
	}
</script>

<div class="container mx-auto py-6 md:px-4 max-w-5xl proben-compact">
	<div class="card bg-surface-2 rounded-lg shadow-lg md:border p-2 md:p-5">
		<div class="flex flex-col gap-4">
			<div class="flex items-center justify-between mb-2">
				<div class="flex items-center gap-3">
					<h2 class="h2 text-on-surface">Proben</h2>
					{#if isEditor}
						<button
							class="btn-icon variant-filled-primary w-8 h-4 rounded-full text-xl leading-none"
							onclick={openNewRehearsalModal}
							title="Neue Probe erstellen">+</button
						>
					{/if}
				</div>
				<button
					class="btn variant-ghost-surface btn-sm"
					onclick={() => (showHelp = !showHelp)}
					aria-label="Hilfe anzeigen"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							stroke-width="2"
							d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
						/>
					</svg>
					<span class="hidden md:inline ml-2">Hilfe</span>
				</button>
			</div>

			{#if showHelp}
				<div class="card variant-ghost-surface mt-2 mb-4 p-3 md:p-4">
					<h3 class="h4 font-bold mb-4">🎸 Anleitung: Proben-Verwaltung</h3>

					<div class="space-y-4">
						<!-- Grundfunktionen -->
						<div>
							<h4 class="font-semibold text-primary-500 mb-2">📋 Hauptfunktionen</h4>
							<ul class="list-disc list-inside space-y-1 text-sm">
								<li>
									<strong>Neue Probe hinzufügen:</strong> Klicke auf "Neue Probe hinzufügen" und wähle
									Startzeit, optional auch die Endzeit
								</li>
								<li>
									<strong>Probe oeffnen:</strong> Klicke auf eine Probe, um die Details im Modal zu sehen
								</li>
								<li>
									<strong>Song hinzufügen:</strong> Wähle einen Song aus und gib optional ein Todo an
								</li>
								<li>
									<strong>Song-Details ansehen:</strong> Klicke auf einen Song in der Probe für Details
								</li>
							</ul>
						</div>

						<!-- Songs verwalten -->
						<div>
							<h4 class="font-semibold text-secondary-500 mb-2">🎵 Songs in Proben</h4>
							<ul class="list-disc list-inside space-y-1 text-sm">
								<li>
									<strong>Status ändern:</strong> Im Song-Detail kannst du den Status ändern (vorschlag,
									angenommen, proben, spielbar, retired)
								</li>
								<li>
									<strong>Song als erledigt markieren:</strong> Klicke auf "erledigt" um den Song abzuhaken
									✔
								</li>
								<li>
									<strong>Kommentare hinzufügen:</strong> Nutze "Proben Kommentar" für Notizen zur Probe
									und "Setlist Kommentar" für die Setliste
								</li>
								<li>
									<strong>Song entfernen:</strong> Klicke auf "✖" um den Song aus der Probe zu entfernen
								</li>
							</ul>
						</div>

						<!-- Vergangene Proben -->
						<div>
							<h4 class="font-semibold text-warning-500 mb-2">🕐 Vergangene Proben</h4>
							<ul class="list-disc list-inside space-y-1 text-sm">
								<li>
									Vergangene Proben werden als <strong>Protokoll</strong> (read-only) angezeigt – keine
									Bearbeitung möglich
								</li>
								<li>
									Das Protokoll zeigt Probenkommentar, alle Songs mit Status, Todos und Kommentaren
								</li>
								<li>
									<strong>Suche (außen):</strong> Filtere alle vergangenen Proben nach Datum, Song-Titel,
									Interpret oder Kommentar
								</li>
								<li>
									<strong>Suche (innen):</strong> Innerhalb des geoeffneten Probe-Details-Modals kannst
									du die Songs direkt durchsuchen
								</li>
							</ul>
						</div>

						<!-- Todos -->
						<div>
							<h4 class="font-semibold text-tertiary-500 mb-2">✅ Todos verwalten</h4>
							<ul class="list-disc list-inside space-y-1 text-sm">
								<li>
									<strong>Allgemeines Todo:</strong> Gib ein Todo beim Hinzufügen eines Songs an
								</li>
								<li>
									<strong>Persönliche Todos:</strong> Weise im Song-Detail spezifische Todos einzelnen
									Bandmitgliedern zu
								</li>
								<li><strong>Todo-Status:</strong> ⏳ = offen, ✔ = erledigt</li>
								<li>
									<strong>Dashboard:</strong> Alle offenen Todos erscheinen auf deinem Dashboard
								</li>
							</ul>
						</div>

						<!-- Probe löschen -->
						<div>
							<h4 class="font-semibold text-warning-500 mb-2">🗑️ Probe löschen</h4>
							<p class="text-sm">
								Nur Editoren/Admins können Proben löschen. Klicke auf "🗑️ Probe löschen" im
								Detail-Bereich.
							</p>
						</div>

						<!-- Tipps -->
						<div class="alert variant-soft-primary">
							<div class="alert-message">
								<h4 class="font-semibold mb-1">💡 Tipp</h4>
								<p class="text-sm">
									Nutze das Suchfeld, um schnell Songs zu finden. Der Status-Wechsel wird
									automatisch gespeichert!
								</p>
							</div>
						</div>
					</div>
				</div>
			{/if}

			<div
				class="flex border-b border-surface-300 dark:border-surface-600 mb-3 gap-1 text-sm overflow-x-auto"
			>
				<button
					onclick={() => (tabSet = 0)}
					class="px-3 py-1.5 rounded-t-lg transition-colors whitespace-nowrap {tabSet === 0
						? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500'
						: 'hover:bg-surface-100 dark:hover:bg-surface-800'} {upcomingRehearsals.length > 0
						? 'font-bold'
						: ''}"
				>
					<span class="hidden md:inline">Aktuelle Proben ({upcomingRehearsals.length})</span>
					<span class="md:hidden">📅 ({upcomingRehearsals.length})</span>
				</button>
				<button
					onclick={openPastTab}
					class="px-3 py-1.5 rounded-t-lg transition-colors whitespace-nowrap {tabSet === 1
						? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500'
						: 'hover:bg-surface-100 dark:hover:bg-surface-800'}"
				>
					<span class="hidden md:inline">Vergangene Proben ({pastTotal})</span>
					<span class="md:hidden">🕐 ({pastTotal})</span>
				</button>
				<button
					onclick={() => (tabSet = 2)}
					class="px-3 py-1.5 rounded-t-lg transition-colors whitespace-nowrap {tabSet === 2
						? 'bg-surface-200 dark:bg-surface-700 font-bold border-b-2 border-primary-500'
						: 'hover:bg-surface-100 dark:hover:bg-surface-800'}"
				>
					<span class="hidden md:inline">Statistiken</span>
					<span class="md:hidden">📈</span>
				</button>
			</div>

			<div class="mt-2">
				{#if tabSet === 0}
					{#if upcomingRehearsals.length === 0}
						<div
							class="rounded-xl bg-success-100 text-success-900 p-3 mt-4 shadow text-center text-sm"
						>
							Keine bevorstehenden Proben geplant.
						</div>
					{:else}
						<div class="mt-2">
							{#each upcomingRehearsals as reh (reh.id)}
								<RehearsalCard {reh} onopen={() => openRehearsalDetails(reh)} />
							{/each}
						</div>
					{/if}
				{:else if tabSet === 1}
					{#if pastTotal === 0}
						<div
							class="rounded-xl bg-surface-100 text-surface-900 p-3 mt-4 shadow text-center text-sm"
						>
							Keine vergangenen Proben vorhanden.
						</div>
					{:else}
						<!-- Suchfeld -->
						<div class="mt-2 mb-2">
							<div
								class="flex items-center gap-1.5 border border-outline-variant rounded-lg px-2.5 py-1.5 bg-surface-1"
							>
								<svg
									class="w-4 h-4 text-on-surface-variant"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
									/>
								</svg>
								<input
									type="search"
									bind:value={pastRehearsalsFilter}
									oninput={queuePastSearch}
									placeholder="Suche nach Datum, Song oder Kommentar..."
									class="input input-sm border-none bg-transparent flex-1 p-0 text-sm focus:ring-0"
								/>
							</div>
							{#if pastRehearsalsFilter}
								<p class="text-xs text-on-surface-variant mt-1.5">
									{pastRehearsals.length} von {pastTotal} Probe{pastTotal !== 1 ? 'n' : ''}
								</p>
							{/if}
						</div>

						{#if pastRehearsals.length === 0}
							<p class="text-on-surface-variant italic text-sm mt-3">Keine Proben gefunden.</p>
						{:else}
							<div class="mt-2">
								{#each pastRehearsals as reh (reh.id)}
									<RehearsalCard
										{reh}
										isPast={true}
										onopen={() => openRehearsalDetails(reh, true, pastRehearsalsFilter)}
									/>
								{/each}
							</div>
							{#if hasMorePast}
								<div class="mt-3 text-center">
									<button
										class="btn variant-ghost-surface btn-sm"
										onclick={() => loadPastRehearsals()}
									>
										Mehr laden
									</button>
								</div>
							{/if}
						{/if}
					{/if}
				{:else if allRehearsals.length === 0}
					<div
						class="rounded-xl bg-surface-100 text-surface-900 p-3 mt-4 shadow text-center text-sm"
					>
						Noch keine Proben zum Auswerten vorhanden.
					</div>
				{:else}
					<div class="grid gap-3 md:grid-cols-2 xl:grid-cols-5">
						<div class="card variant-ghost-primary p-4 rounded-lg">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">Proben</div>
							<div class="mt-2 text-2xl font-bold text-primary-500">
								{rehearsalStats.totalRehearsals}
							</div>
						</div>
						<div class="card variant-ghost-secondary p-4 rounded-lg">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">
								Songs gesamt
							</div>
							<div class="mt-2 text-2xl font-bold text-secondary-500">
								{rehearsalStats.totalSongEntries}
							</div>
						</div>
						<div class="card variant-ghost-warning p-4 rounded-lg">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">
								Ø Songs/Probe
							</div>
							<div class="mt-2 text-2xl font-bold text-warning-500">
								{rehearsalStats.averageSongsPerRehearsal.toFixed(1)}
							</div>
						</div>
						<div class="card variant-ghost-tertiary p-4 rounded-lg">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">
								Ø Songs/Probe/Jahr
							</div>
							<div class="mt-2 text-2xl font-bold text-tertiary-500">
								{rehearsalStats.averageSongsPerRehearsalYearly.toFixed(1)}
							</div>
						</div>
						<div class="card variant-ghost-surface p-4 rounded-lg">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">Ø Dauer</div>
							<div class="mt-2 text-2xl font-bold">
								{formatDurationMinutes(rehearsalStats.averageDurationMinutes)}
							</div>
						</div>
					</div>

					<div class="card variant-ghost-surface p-4 rounded-lg mt-4">
						<div class="mb-3 flex items-center justify-between gap-3">
							<div class="text-xs uppercase tracking-wide text-on-surface-variant">Trend</div>
							<div class="inline-flex rounded-full bg-surface-200 dark:bg-surface-700 p-1">
								<button
									class="rounded-full px-3 py-1 text-xs font-medium transition-colors {rehearsalPeriod ===
									'month'
										? 'bg-primary-500 text-white'
										: 'text-on-surface-variant'}"
									onclick={() => (rehearsalPeriod = 'month')}
								>
									Monat
								</button>
								<button
									class="rounded-full px-3 py-1 text-xs font-medium transition-colors {rehearsalPeriod ===
									'year'
										? 'bg-primary-500 text-white'
										: 'text-on-surface-variant'}"
									onclick={() => (rehearsalPeriod = 'year')}
								>
									Jahr
								</button>
							</div>
						</div>

						<div class="grid gap-4">
							<div class="rounded-xl border border-surface-300 dark:border-surface-700 p-3">
								<RehearsalMonthPlot
									data={rehearsalMonthData}
									period={rehearsalPeriod}
									title={rehearsalPeriod === 'year' ? 'Proben / Jahr' : 'Proben / Monat'}
									valueFormatter={(value) => `${value} Proben`}
									color="#22c55e"
								/>
								{#if rehearsalTrend}
									<p class="mt-2 text-xs text-on-surface-variant">
										<span class={rehearsalTrend.isPositive ? 'text-success-600' : 'text-error-600'}>
											{rehearsalTrend.direction}
											{Math.abs(rehearsalTrend.percent).toFixed(1)}%
										</span>
										gegenüber dem vorherigen {rehearsalPeriod === 'year' ? 'Jahr' : 'Monat'}
									</p>
								{/if}
							</div>

							<div class="rounded-xl border border-surface-300 dark:border-surface-700 p-3">
								<RehearsalMonthPlot
									data={rehearsalSongsPerPeriodData}
									period={rehearsalPeriod}
									title={rehearsalPeriod === 'year'
										? 'Songs pro Probe / Jahr'
										: 'Songs pro Probe / Monat'}
									valueFormatter={(value) => `${value.toFixed(1)} Songs/Probe`}
									color="#3b82f6"
								/>
								{#if songsPerRehearsalTrend}
									<p class="mt-2 text-xs text-on-surface-variant">
										<span
											class={songsPerRehearsalTrend.isPositive
												? 'text-success-600'
												: 'text-error-600'}
										>
											{songsPerRehearsalTrend.direction}
											{Math.abs(songsPerRehearsalTrend.percent).toFixed(1)}%
										</span>
										gegenüber dem vorherigen {rehearsalPeriod === 'year' ? 'Jahr' : 'Monat'}
									</p>
								{/if}
							</div>
						</div>
					</div>

					<div class="grid gap-4 lg:grid-cols-2 mt-4">
						<div class="card variant-ghost-surface p-4 rounded-lg">
							<div class="mb-3 flex items-center justify-between gap-2">
								<h3 class="text-sm font-semibold">Top-Songs</h3>
								{#if topSongsPageCount > 1}
									<div class="flex items-center gap-1.5 text-xs text-on-surface-variant">
										<button
											type="button"
											class="btn btn-sm variant-ghost-surface px-2 py-1 min-h-0 h-7 text-[10px] disabled:opacity-40 disabled:cursor-not-allowed"
											disabled={topSongsPage === 0}
											onclick={() => (topSongsPage = Math.max(0, topSongsPage - 1))}
										>
											Zurück
										</button>
										<span class="min-w-[3.5rem] text-center"
											>{topSongsPage + 1} / {topSongsPageCount}</span
										>
										<button
											type="button"
											class="btn btn-sm variant-ghost-surface px-2 py-1 min-h-0 h-7 text-[10px] disabled:opacity-40 disabled:cursor-not-allowed"
											disabled={topSongsPage >= topSongsPageCount - 1}
											onclick={() =>
												(topSongsPage = Math.min(topSongsPageCount - 1, topSongsPage + 1))}
										>
											Weiter
										</button>
									</div>
								{/if}
							</div>
							{#if rehearsalStats.topSongs.length > 0}
								<ul class="space-y-2 text-sm">
									{#each paginatedTopSongs as song, index}
										<li class="flex items-center justify-between gap-3">
											<span class="text-on-surface-variant">
												#{topSongsPage * topSongsPageSize + index + 1}
												{song.name}
											</span>
											<span class="font-semibold">{song.count}×</span>
										</li>
									{/each}
								</ul>
							{:else}
								<p class="text-sm text-on-surface-variant">
									Noch keine Song-Häufigkeiten verfügbar.
								</p>
							{/if}
						</div>

						<div class="card variant-ghost-surface p-4 rounded-lg space-y-3">
							<h3 class="text-sm font-semibold">Proben-Merkmale</h3>
							<div class="flex items-center justify-between text-sm">
								<span class="text-on-surface-variant">Aktivster Monat</span>
								<span class="font-semibold">
									{rehearsalStats.mostActiveMonth
										? `${rehearsalStats.mostActiveMonth.label} (${rehearsalStats.mostActiveMonth.count})`
										: '–'}
								</span>
							</div>
							<div class="flex items-center justify-between text-sm">
								<span class="text-on-surface-variant">Größte Probe</span>
								<span class="font-semibold">
									{rehearsalStats.biggestRehearsal
										? `${rehearsalStats.biggestRehearsal.songCount} Songs`
										: '–'}
								</span>
							</div>
							<div class="flex items-center justify-between text-sm">
								<span class="text-on-surface-variant">Todos offen</span>
								<span class="font-semibold"
									>{rehearsalStats.openTodos} / {rehearsalStats.totalTodos}</span
								>
							</div>
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>
</div>

<style>
	.proben-compact :global(.h2) {
		font-size: 1.35rem;
		line-height: 1.2;
	}

	.proben-compact :global(.btn-sm) {
		min-height: 1.8rem;
		font-size: 0.78rem;
	}
</style>
