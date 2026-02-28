<script>
	// --- Props ---

	// Definition der Rollen
	export let roles = ['User', 'Editor', 'Admin'];

	// Definition der Struktur: Kategorien und ihre zugehörigen Aktionen
	export let schema = [
		{
			category: 'Gigs',
			actions: ['Gigs anzeigen', 'Gigs erstellen', 'Gigs bearbeiten', 'Gigs löschen']
		},
		{
			category: 'Setlisten',
			actions: ['Setlist anzeigen', 'Setlist bearbeiten', 'Setlist PDF erstellen','GEMA-Liste generieren']
		},
		{
			category: 'Songs',
			actions: ['Songs anzeigen', 'Songs bearbeiten', 'Songs vorschlagen', 'Songs löschen']
		},
		{
			category: 'Proben',
			actions: ['Proben anzeigen', 'Proben bearbeiten', 'Proben erstellen', 'Proben löschen']
		},
		{
			category: 'Umfragen',
			actions: ['Umfragen anzeigen', 'Umfragen bearbeiten', 'Umfragen erstellen', 'Umfragen löschen']
		},
		{
			category: 'System',
			actions: ['User hinzufügen', 'User löschen', 'Neues Passwort antriggern']
		}

	];

	// Die effektiven Berechtigungen pro Rolle
	export let permissions = {
	'User': [
		'Gigs anzeigen',
		'Setlist anzeigen',
		'Setlist PDF erstellen',
		'GEMA-Liste generieren',
		'Songs anzeigen',
		'Songs vorschlagen',
		'Proben anzeigen',
		'Proben bearbeiten',
		'Umfragen anzeigen',
		'Umfragen erstellen',
		'Umfragen bearbeiten',
		'Umfragen löschen'
	],
	'Editor': [
		'Gigs anzeigen',
		'Gigs erstellen',
		'Gigs bearbeiten',
		'Gigs löschen',
		'Setlist anzeigen',
		'Setlist bearbeiten',
		'Setlist PDF erstellen',
		'GEMA-Liste generieren',
		'Songs anzeigen',
		'Songs vorschlagen',
		'Songs bearbeiten',
		'Songs löschen',
		'Proben anzeigen',
		'Proben erstellen',
		'Proben bearbeiten',
		'Umfragen anzeigen',
		'Umfragen erstellen',
		'Umfragen bearbeiten',
		'Umfragen löschen'
	],
	'Admin': [
		'Gigs anzeigen',
		'Gigs erstellen',
		'Gigs bearbeiten',
		'Gigs löschen',
		'Setlist anzeigen',
		'Setlist bearbeiten',
		'Setlist PDF erstellen',
		'GEMA-Liste generieren',
		'Songs anzeigen',
		'Songs vorschlagen',
		'Songs bearbeiten',
		'Songs löschen',
		'Proben anzeigen',
		'Proben erstellen',
		'Proben bearbeiten',
		'Proben löschen',
		'Umfragen anzeigen',
		'Umfragen erstellen',
		'Umfragen bearbeiten',
		'Umfragen löschen',
		'User hinzufügen',
		'User löschen',
		'Neues Passwort antriggern'
	]
};

	// Helper: Check permission
	function can(role, action) {
		return permissions[role]?.includes(action);
	}
</script>

<div class="table-container">

	<!-- ============================================== -->
	<!-- DESKTOP TABLE (Rollen = Zeilen, Rechte = Spalten) -->
	<!-- Sichtbar ab 'md' (768px) oder 'lg' (1024px) je nach Wunsch -->
	<!-- ============================================== -->
	<table class="table table-hover hidden lg:table">
		<thead>
			<!-- Oberste Header-Zeile: Kategorien -->
			<tr class="bg-surface-active-token">
				<th class="!align-bottom uppercase tracking-wider font-bold">Rolle</th>
				{#each schema as group}
					<!-- 'colspan' spannt über alle Aktionen der Gruppe -->
					<th
						class="text-center font-bold border-l border-surface-500/20"
						colspan={group.actions.length}
					>
						{group.category}
					</th>
				{/each}
			</tr>
			<!-- Zweite Header-Zeile: Einzelne Aktionen (Vertikal) -->
			<tr class="bg-surface-active-token">
				<!-- Leere Zelle unter "Rolle" -->
				<th></th>
				{#each schema as group}
					{#each group.actions as action, i}
						<th class="!align-bottom !p-2 h-32 border-surface-500/20 {i === 0 ? 'border-l' : ''}">
							<!-- Tailwind Arbitrary Value für vertikalen Text -->
							<div class="[writing-mode:vertical-rl] rotate-180 whitespace-nowrap w-full text-left">
								{action}
							</div>
						</th>
					{/each}
				{/each}
			</tr>
		</thead>
		<tbody>
			{#each roles as role}
				<tr>
					<td class="font-bold whitespace-nowrap">{role}</td>
					{#each schema as group}
						{#each group.actions as action, i}
							<td class="text-center border-surface-500/20 {i === 0 ? 'border-l' : ''}">
								{#if can(role, action)}
									<!-- Skeleton Success Token -->
									<span class="text-success-500 text-xl">✅</span>
								{:else}
									<!-- Skeleton Error Token (oder opacity-20 für dezenteren Look) -->
									<span class="text-surface-400 opacity-60 text-xl">❌</span>
								{/if}
							</td>
						{/each}
					{/each}
				</tr>
			{/each}
		</tbody>
	</table>


	<!-- ============================================== -->
	<!-- MOBILE TABLE (Rechte = Zeilen, Rollen = Spalten) -->
	<!-- Sichtbar bis 'lg' -->
	<!-- ============================================== -->
	<table class="table lg:hidden">
		<thead>
			<tr class="bg-surface-active-token">
				<th class="font-bold">Aktion</th>
				{#each roles as role}
					<th class="text-center font-bold w-16">{role}</th>
				{/each}
			</tr>
		</thead>
		<tbody>
			{#each schema as group}
				<!-- Kategorie-Trennzeile -->
				<!-- 'variant-soft-surface' oder 'bg-surface-200-700-token' für den Trenner-Look -->
				<tr class="variant-soft-surface font-bold">
					<td colspan={roles.length + 1} class="!py-2 !px-4 text-sm uppercase tracking-wide opacity-70">
						{group.category}
					</td>
				</tr>

				<!-- Aktionen -->
				{#each group.actions as action}
					<tr>
						<td class="align-middle">{action}</td>
						{#each roles as role}
							<td class="text-center align-middle">
								{#if can(role, action)}
									<span class="text-success-500 text-lg">✅</span>
								{:else}
									<span class="text-surface-400 opacity-60 text-lg">❌</span>
								{/if}
							</td>
						{/each}
					</tr>
				{/each}
			{/each}
		</tbody>
	</table>

</div>
