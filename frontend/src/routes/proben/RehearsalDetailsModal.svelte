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
	import { tick } from 'svelte';
	import { modalState } from '$lib/modalState.js';
	import RehearsalSongCard from './RehearsalSongCard.svelte';
	import AvailabilityWidget from '$lib/components/AvailabilityWidget.svelte';
	import { appConfig } from '$lib/appConfig.js';

	let {
		parent,
		reh,
		songs = [],
		songsForSearch = [],
		users = [],
		isEditor = false,
		isPast = false,
		searchQuery = '',
		currentUserId = null,
		onupdate,
		ondelete,
		onerror,
		onwarning,
		onsuccess
	} = $props();

	let statusOptions = $derived($appConfig?.rehearsalSongStatuses ?? []);

	// Verfügbarkeits-Sektion
	let showAvailability = $state(false);

	// Musiker-Liste für den Widget (nur Musiker)
	let musicianList = $derived(users.filter((u) => u.musician !== false));

	const dateOptions = {
		weekday: 'long',
		year: 'numeric',
		month: 'long',
		day: 'numeric'
	};

	let searchTerm = $state('');
	let selectedSong = $state(null);
	let newSongTodo = $state('');
	let songToAddInput;
	let expandedSongId = $state(null);
	let canEdit = $derived(!!isEditor);
	let scheduleError = $state('');

	function toDatetimeLocalValue(dateLike) {
		if (!dateLike) return '';
		const date = new Date(dateLike);
		if (Number.isNaN(date.getTime())) return '';
		const pad = (value) => String(value).padStart(2, '0');
		return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
	}

	let beginInput = $state('');
	let endInput = $state('');

	$effect(() => {
		beginInput = toDatetimeLocalValue(reh.begin);
		endInput = toDatetimeLocalValue(reh.end);
	});

	function formatTime(dateLike) {
		return new Date(dateLike).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
	}

	function formatRehearsalRangeLabel() {
		const beginDate = new Date(reh.begin);
		const endDate = reh.end ? new Date(reh.end) : null;
		const dateLabel = beginDate.toLocaleDateString('de-DE', dateOptions);
		const beginTime = formatTime(beginDate);

		if (!endDate) return `${dateLabel}, ${beginTime} Uhr`;

		const endTime = formatTime(endDate);
		const sameDay = beginDate.toDateString() === endDate.toDateString();
		if (sameDay) return `${dateLabel}, ${beginTime}-${endTime} Uhr`;

		const endDateLabel = endDate.toLocaleDateString('de-DE', dateOptions);
		return `${dateLabel}, ${beginTime} Uhr - ${endDateLabel}, ${endTime} Uhr`;
	}

	function formatDeleteRangeLabel() {
		const beginDate = new Date(reh.begin);
		const dateLabel = beginDate.toLocaleDateString('de-DE', {
			day: '2-digit',
			month: '2-digit',
			year: 'numeric'
		});
		const beginTime = formatTime(beginDate);
		const endTime = reh.end ? formatTime(reh.end) : null;
		return endTime
			? `${dateLabel} (${beginTime}-${endTime} Uhr)`
			: `${dateLabel} (${beginTime} Uhr)`;
	}

	function splitHighlightParts(text, query) {
		const value = text == null ? '' : String(text);
		const normalizedQuery = query?.trim();

		if (!normalizedQuery) return [{ text: value, match: false }];

		const escapedQuery = normalizedQuery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
		const regex = new RegExp(escapedQuery, 'gi');
		const parts = [];
		let lastIndex = 0;

		for (const match of value.matchAll(regex)) {
			const index = match.index ?? 0;
			if (index > lastIndex) {
				parts.push({ text: value.slice(lastIndex, index), match: false });
			}

			parts.push({ text: match[0], match: true });
			lastIndex = index + match[0].length;
		}

		if (lastIndex < value.length) {
			parts.push({ text: value.slice(lastIndex), match: false });
		}

		return parts.length > 0 ? parts : [{ text: value, match: false }];
	}

	function handleDelete() {
		if (!canEdit) return;
		ondelete?.({ id: reh.id, date: formatDeleteRangeLabel() });
	}

	function handleUpdate(songId = null) {
		if (!canEdit) return;
		onupdate?.({ reh, songId });
	}

	function handleSongToggle(e) {
		expandedSongId = expandedSongId !== e.id ? e.id : null;
	}

	function handleSongRemove(e) {
		if (!canEdit) return;
		reh.songs = reh.songs.filter((s) => s.id !== e.id);
		handleUpdate(null);
	}

	function handleSongDone(e) {
		if (!canEdit) return;
		e.song.done = !e.song.done;
		handleUpdate(e.song.id);
	}

	function handleStatusChange(e) {
		if (!canEdit) return;
		e.song.status = e.status;
		handleUpdate(e.song.id);
	}

	function handleSongUpdate() {
		if (!canEdit) return;
		handleUpdate(expandedSongId);
	}

	function handleScheduleUpdate() {
		if (!canEdit || isPast) return;

		if (!beginInput) {
			scheduleError = 'Bitte eine Startzeit auswählen.';
			return;
		}

		if (endInput && new Date(endInput) <= new Date(beginInput)) {
			scheduleError = 'Die Endzeit muss nach der Startzeit liegen.';
			return;
		}

		scheduleError = '';
		reh.begin = beginInput;
		reh.end = endInput || null;
		handleUpdate(expandedSongId);
	}

	function handleAddTodo(e) {
		if (!canEdit) return;
		const { song, userId, todoText } = e;
		const newTodo = {
			id: null,
			id_reh: song.id_rehearsal,
			id_song: song.id_song,
			id_user: userId,
			todo: todoText,
			done: false,
			dt: reh.begin
		};
		song.song_todos = [...song.song_todos, newTodo];
		handleUpdate(expandedSongId);
	}

	async function addSongTodo() {
		if (!canEdit) return;
		if (!selectedSong) {
			onerror?.({ message: 'Bitte wähle einen gültigen Song aus.' });
			searchTerm = '';
			await tick();
			songToAddInput?.focus();
			return;
		}

		const alreadyPresent = reh.songs.some((s) => s.id_song === selectedSong.id);
		if (alreadyPresent) {
			onwarning?.({
				message: `Der Song "${selectedSong.title}" ist bereits in dieser Probe enthalten.`
			});
			selectedSong = null;
			newSongTodo = '';
			searchTerm = '';
			await tick();
			songToAddInput?.focus();
			return;
		}

		const newSong = {
			id: null,
			id_rehearsal: reh.id,
			id_song: selectedSong.id,
			interpret: selectedSong.interpret,
			title: selectedSong.title,
			status: selectedSong.status,
			setlist_comment: selectedSong.comment,
			comment: '',
			todo: newSongTodo,
			song_todos: [],
			done: false
		};
		reh.songs = [...reh.songs, newSong];
		handleUpdate(null);
		onsuccess?.({ message: `Der Song "${selectedSong.title}" wurde zur Probe hinzugefügt.` });

		selectedSong = null;
		newSongTodo = '';
		searchTerm = '';
		await tick();
		songToAddInput?.focus();
	}
</script>

<div
	class="card p-4 md:p-5 w-[96vw] max-w-6xl h-[90vh] flex flex-col modal-base reh-modal-compact text-sm"
>
	{#snippet highlightedText(text)}
		{#each splitHighlightParts(text, searchQuery) as part, idx (`${idx}-${part.text}`)}
			{#if part.match}
				<mark class="bg-warning-200 dark:bg-warning-700 rounded px-0.5">{part.text}</mark>
			{:else}
				{part.text}
			{/if}
		{/each}
	{/snippet}

	<header
		class="mb-3 flex items-start justify-between gap-3 border-b border-outline-variant pb-2.5 flex-shrink-0"
	>
		<div>
			<h3 class="text-base font-semibold text-on-surface">{formatRehearsalRangeLabel()}</h3>
			{#if isPast}
				<p class="mt-1 text-xs text-surface-400 italic">Protokoll</p>
			{/if}
		</div>
		<button
			type="button"
			class="btn-icon btn-icon-sm variant-ghost"
			onclick={() => modalState.close()}>✕</button
		>
	</header>

	<!-- Verfügbarkeit -->
	<div class="flex-shrink-0 mb-2 border border-outline-variant rounded-lg overflow-hidden">
		<button
			type="button"
			class="w-full flex items-center justify-between px-3 py-2 text-xs font-semibold bg-surface-100 dark:bg-surface-800 hover:bg-surface-200 dark:hover:bg-surface-700 transition-colors"
			onclick={() => (showAvailability = !showAvailability)}
		>
			<span>📅 Verfügbarkeit</span>
			<span class="text-on-surface-variant">{showAvailability ? '▲' : '▼'}</span>
		</button>
		{#if showAvailability}
			<div class="p-3">
				<AvailabilityWidget
					eventType="rehearsal"
					eventId={reh.id}
					{currentUserId}
					musicians={musicianList}
				/>
			</div>
		{/if}
	</div>

	<div class="flex-1 overflow-y-auto pr-1">
		{#if isPast}
			<div
				class="prose prose-sm dark:prose-invert max-w-none text-xs text-on-surface leading-relaxed"
			>
				{#if reh.comment}
					<p class="whitespace-pre-wrap mb-4 text-surface-700 dark:text-surface-200">
						{@render highlightedText(reh.comment)}
					</p>
					<hr class="border-surface-300 dark:border-surface-600 mb-4" />
				{/if}

				{#if reh.songs.length === 0}
					<p class="italic text-surface-500 dark:text-surface-300">Keine Songs protokolliert.</p>
				{:else}
					{#each reh.songs as song (song.id ?? song.id_song)}
						<div
							class="mb-4 rounded-md border border-surface-200 dark:border-surface-700 px-3 py-2"
						>
							<p class="font-semibold">
								{song.done ? '✔' : '·'}
								{@render highlightedText(`${song.interpret} - ${song.title}`)}
								{#if song.status}
									<span class="font-normal text-surface-500 dark:text-surface-300 text-xs"
										>({song.status})</span
									>
								{/if}
							</p>
							{#if song.todo}
								<p class="ml-4 mt-1 text-surface-700 dark:text-surface-200">
									Todo: {@render highlightedText(song.todo)}
								</p>
							{/if}
							{#if song.comment}
								<p class="ml-4 mt-1 text-surface-700 dark:text-surface-200">
									{@render highlightedText(song.comment)}
								</p>
							{/if}
							{#each song.song_todos ?? [] as std}
								<p class="ml-4 mt-1 text-surface-600 dark:text-surface-300">
									{std.done ? '✔' : '⏳'}
									{users.find((u) => u.id === std.id_user)?.clear_name ?? '?'}: {@render highlightedText(
										std.todo
									)}
								</p>
							{/each}
						</div>
					{/each}
				{/if}
			</div>
		{:else}
			{#if canEdit}
				<button
					class="btn btn-xs variant-filled-error text-xs float-left mb-2 border"
					title="Probe löschen"
					onclick={handleDelete}>Probe löschen</button
				>
			{/if}

			<div class="mb-4 clear-both">
				<h6 class="font-bold text-sm mb-1.5">Stammdaten</h6>
				<div class="grid grid-cols-1 md:grid-cols-2 gap-2">
					<div>
						<label class="form-label" for="reh-begin-{reh.id}">Beginn</label>
						<input
							id="reh-begin-{reh.id}"
							class="input input-sm w-full rounded-md"
							type="datetime-local"
							bind:value={beginInput}
							onblur={handleScheduleUpdate}
							disabled={!canEdit}
							required
						/>
					</div>
					<div>
						<label class="form-label" for="reh-end-{reh.id}">Ende</label>
						<input
							id="reh-end-{reh.id}"
							class="input input-sm w-full rounded-md"
							type="datetime-local"
							bind:value={endInput}
							min={beginInput || undefined}
							onblur={handleScheduleUpdate}
							disabled={!canEdit}
						/>
					</div>
				</div>
				{#if scheduleError}
					<p class="text-error text-xs mt-1">{scheduleError}</p>
				{/if}
			</div>

			<div class="mb-4 clear-both">
				<textarea
					class="input input-sm w-full rounded-md"
					rows="6"
					bind:value={reh.comment}
					onblur={() => handleUpdate(expandedSongId)}
					placeholder="Probenkommentar"
					disabled={!canEdit}
				></textarea>
			</div>

			<form
				class="mb-4 border-t pt-2.5"
				onsubmit={(e) => {
					e.preventDefault();
					if (canEdit) addSongTodo();
				}}
			>
				<h6 class="font-bold text-sm mb-1.5">Song mit Todo</h6>
				<div class="flex flex-col gap-2">
					{#if songsForSearch.length > 0}
						<input
							class="input input-sm w-full mb-1 text-sm"
							type="text"
							list="songs-datalist-{reh.id}"
							id="songToAdd-{reh.id}"
							bind:this={songToAddInput}
							bind:value={searchTerm}
							placeholder="Song eingeben"
							autocomplete="off"
							disabled={!canEdit}
							oninput={(e) => {
								const selected = songsForSearch.find((s) => s.label === e.target.value);
								if (selected) {
									selectedSong = songs.find((s) => s.id === selected.value);
								}
							}}
						/>
						<datalist id="songs-datalist-{reh.id}">
							{#each songsForSearch as songOption}
								<option value={songOption.label}></option>
							{/each}
						</datalist>
					{/if}
				</div>
				<div class="my-2">
					<input
						class="input input-sm w-full text-sm"
						type="text"
						bind:value={newSongTodo}
						required
						placeholder="Was gibts zu tun?"
						disabled={!canEdit}
					/>
				</div>
				<button
					class="btn btn-xs variant-filled-primary border mt-1.5 w-fit"
					type="submit"
					disabled={!canEdit}
				>
					Hinzufügen
				</button>
			</form>

			<div class="border-t pt-2.5">
				{#each reh.songs as song (song.id ?? song.id_song)}
					<RehearsalSongCard
						{song}
						{users}
						rehearsalId={reh.id}
						rehearsalBegin={reh.begin}
						{statusOptions}
						{canEdit}
						expanded={expandedSongId === song.id}
						ontoggle={handleSongToggle}
						onremove={handleSongRemove}
						ondone={handleSongDone}
						onstatuschange={handleStatusChange}
						onupdate={handleSongUpdate}
						onaddtodo={handleAddTodo}
					/>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.reh-modal-compact :global(.btn) {
		font-size: 0.75rem;
		line-height: 1.1;
		min-height: 1.9rem;
		padding: 0.3rem 0.55rem;
	}

	.reh-modal-compact :global(.btn-sm) {
		font-size: 0.7rem;
		min-height: 1.75rem;
		padding: 0.25rem 0.5rem;
	}

	.reh-modal-compact :global(.input),
	.reh-modal-compact :global(select),
	.reh-modal-compact :global(textarea) {
		font-size: 0.8rem;
		line-height: 1.25;
	}

	.reh-modal-compact :global(.form-label) {
		font-size: 0.72rem;
	}
</style>
