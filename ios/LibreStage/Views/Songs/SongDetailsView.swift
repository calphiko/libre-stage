// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SongDetailsView: View {
	let songId: Int
	let initialTitle: String?
	let modalPresentation: Bool

	@State private var vm = SongDetailsViewModel()
	@State private var selectedTab: SongDetailsTab = .details
	@State private var isEditing = false
	@State private var draft = SongDetailsDraft()

	@Environment(AuthManager.self) private var authManager
	@Environment(\.dismiss) private var dismiss

	init(songId: Int, initialTitle: String? = nil, modalPresentation: Bool = false) {
		self.songId = songId
		self.initialTitle = initialTitle
		self.modalPresentation = modalPresentation
	}

	private var canEdit: Bool {
		authManager.userRole == .admin || authManager.userRole == .editor
	}

	private var statsEnabled: Bool {
		vm.song?.status?.lowercased() != "vorschlag"
	}

	var body: some View {
		Group {
			if vm.isLoading && vm.song == nil {
				SkeletonList()
			} else if vm.song == nil {
				ContentUnavailableView("Song nicht gefunden", systemImage: "music.note")
			} else {
				VStack(spacing: 0) {
					SongDetailsTabBar(selectedTab: $selectedTab, statsEnabled: statsEnabled)
					tabContent
				}
			}
		}
		.navigationTitle(vm.song?.title ?? initialTitle ?? "Song")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if modalPresentation {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Fertig") {
						dismiss()
					}
				}
			}
		}
		.errorBanner($vm.error)
		.task {
			await vm.loadSongFieldConfig()
			await vm.loadSingerOptions()
			await vm.loadSong(songId: songId)
			if let song = vm.song {
				draft = SongDetailsDraft(song: song)
			}
		}
		.task(id: selectedTab) {
			guard selectedTab != .details, statsEnabled else { return }
			if selectedTab == .statistics {
				await vm.loadStatistics(songId: songId)
			} else {
				await vm.loadRehearsalHistory(songId: songId)
			}
		}
	}

	@ViewBuilder
	private var tabContent: some View {
		switch selectedTab {
		case .details:
			detailsTab
		case .statistics:
			statisticsTab
		case .rehearsals:
			rehearsalsTab
		}
	}

	private var detailsTab: some View {
		List {
			if isEditing {
				Section("Bearbeiten") {
					ForEach(vm.songFields) { field in
						editorView(for: field)
					}
				}

				Section {
					Button {
						Task {
							if await vm.save(songId: songId, draft: draft) {
								isEditing = false
								if let song = vm.song {
									draft = SongDetailsDraft(song: song)
								}
							}
						}
					} label: {
						if vm.isSaving {
							ProgressView()
						} else {
							Text("Speichern")
						}
					}
					.disabled(vm.isSaving)

					Button("Abbrechen", role: .cancel) {
						isEditing = false
						if let song = vm.song {
							draft = SongDetailsDraft(song: song)
						}
					}
				}
			} else if let song = vm.song {
				Section("Details") {
					ForEach(vm.songFields) { field in
						SongDetailLine(
							label: field.label,
							value: displayValue(for: field)
						)
					}
				}

				if canEdit {
					Section {
						Button("Bearbeiten") {
							draft = SongDetailsDraft(song: song)
							isEditing = true
						}
					}
				}
			}
		}
	}

	@ViewBuilder
	private func editorView(for field: SongFieldDefinition) -> some View {
		switch field.type {
		case .singerList:
			SingerMultiSelectField(
				label: field.required ? "\(field.label) *" : field.label,
				options: vm.singerOptions,
				selection: singerBinding(for: field.key)
			)
		case .option:
			Picker(field.required ? "\(field.label) *" : field.label, selection: binding(for: field.key)) {
				if !field.required {
					Text("-").tag("")
				}
				ForEach(field.options) { option in
					Text(option.label).tag(option.key)
				}
			}
		case .time:
			TextField(
				field.required ? "\(field.label) * (HH:MM:SS)" : "\(field.label) (HH:MM:SS)",
				text: binding(for: field.key)
			)
			.textInputAutocapitalization(.never)
		case .date:
			TextField(
				field.required ? "\(field.label) * (YYYY-MM-DD)" : "\(field.label) (YYYY-MM-DD)",
				text: binding(for: field.key)
			)
			.textInputAutocapitalization(.never)
		case .text:
			if field.key == "text" || field.key == "comment" {
				TextField(
					field.required ? "\(field.label) *" : field.label,
					text: binding(for: field.key),
					axis: .vertical
				)
				.lineLimit(3...8)
			} else {
				TextField(field.required ? "\(field.label) *" : field.label, text: binding(for: field.key))
			}
		}
	}

	private func binding(for key: String) -> Binding<String> {
		Binding(
			get: { draft.value(for: key) },
			set: { draft.setValue($0, for: key) }
		)
	}

	private func singerBinding(for key: String) -> Binding<[String]> {
		Binding(
			get: { draft.singers(for: key) },
			set: { draft.setSingers($0, for: key) }
		)
	}

	private func displayValue(for field: SongFieldDefinition) -> String? {
		let raw = draft.value(for: field.key)
		guard !raw.isEmpty else { return nil }

		if field.type == .option,
		   let option = field.options.first(where: { $0.key == raw }) {
			return option.label
		}

		return raw
	}

	private var statisticsTab: some View {
		List {
			if vm.isStatisticsLoading {
				Section {
					HStack {
						Spacer()
						ProgressView()
						Spacer()
					}
				}
			} else if let stats = vm.statistics {
				Section("Uebersicht") {
					LabeledContent("Proben", value: String(stats.rehearsal_count))
					LabeledContent("Auftritte", value: String(stats.gig_count))
					LabeledContent("Uebersprungen", value: String(stats.skipped_count))
					LabeledContent("Eingeschoben", value: String(stats.inserted_count))
					if let avg = stats.feedback_avg {
						LabeledContent("Live-Bewertung", value: String(format: "%.2f", avg))
					}
				}

				Section("Zeitraum") {
					SongDetailLine(label: "Erste Probe", value: stats.first_rehearsal)
					SongDetailLine(label: "Letzte Probe", value: stats.last_rehearsal)
				}

				if !stats.gigs_played.isEmpty {
					Section("Gespielte Gigs") {
						ForEach(stats.gigs_played) { gig in
							VStack(alignment: .leading, spacing: 2) {
								Text(gig.gig_name).font(.body)
								Text(gig.gig_date).font(.caption).foregroundStyle(.secondary)
							}
						}
					}
				}
			} else {
				Section {
					Text("Statistiken konnten nicht geladen werden.")
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	private var rehearsalsTab: some View {
		List {
			if vm.isRehearsalHistoryLoading {
				Section {
					HStack {
						Spacer()
						ProgressView()
						Spacer()
					}
				}
			} else if vm.rehearsalHistory.isEmpty {
				Section {
					Text("Keine Probenhistorie vorhanden.")
						.foregroundStyle(.secondary)
				}
			} else {
				Section("Letzte Proben") {
					ForEach(vm.rehearsalHistory) { entry in
						VStack(alignment: .leading, spacing: 4) {
							Text(entry.rehearsal_date).font(.caption).foregroundStyle(.secondary)
							if let todo = entry.todo, !todo.isEmpty {
								Label(todo, systemImage: "exclamationmark.circle")
									.font(.subheadline)
							}
							if let comment = entry.comment, !comment.isEmpty {
								Text(comment)
									.font(.subheadline)
									.foregroundStyle(.secondary)
							}
							ForEach(entry.todos) { todo in
								HStack(spacing: 6) {
									Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
										.foregroundStyle(todo.done ? .green : .orange)
									Text(todo.todo)
										.font(.caption)
										.strikethrough(todo.done)
								}
							}
						}
						.padding(.vertical, 2)
					}
				}
			}
		}
	}
}

private enum SongDetailsTab {
	case details
	case statistics
	case rehearsals
}

private struct SongDetailsTabBar: View {
	@Binding var selectedTab: SongDetailsTab
	let statsEnabled: Bool

	var body: some View {
		HStack(spacing: 8) {
			tabButton(title: "Details", tab: .details, enabled: true)
			tabButton(title: "Statistik", tab: .statistics, enabled: statsEnabled)
			tabButton(title: "Proben", tab: .rehearsals, enabled: statsEnabled)
		}
		.padding(.horizontal)
		.padding(.vertical, 10)
		.background(Color(.systemGroupedBackground))
	}

	private func tabButton(title: String, tab: SongDetailsTab, enabled: Bool) -> some View {
		Button {
			selectedTab = tab
		} label: {
			Text(title)
				.font(.caption.bold())
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)
				.background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
				.foregroundStyle(enabled ? .primary : .secondary)
				.clipShape(Capsule())
		}
		.buttonStyle(.plain)
		.disabled(!enabled)
	}
}

private struct SongDetailLine: View {
	let label: String
	let value: String?

	var body: some View {
		if let value, !value.isEmpty {
			LabeledContent(label, value: value)
		}
	}
}

private struct SingerMultiSelectField: View {
	let label: String
	let options: [String]
	@Binding var selection: [String]

	private var availableOptions: [String] {
		options.filter { !selection.contains($0) }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(label)
				.font(.subheadline)
				.foregroundStyle(.secondary)

			Menu {
				if options.isEmpty {
					Text("Keine Saenger verfuegbar")
				} else {
					ForEach(options, id: \.self) { singer in
						Button {
							toggle(singer)
						} label: {
							if selection.contains(singer) {
								Label(singer, systemImage: "checkmark")
							} else {
								Text(singer)
							}
						}
					}
				}
			} label: {
				HStack {
					Text(availableOptions.isEmpty ? "Alle Saenger ausgewaehlt" : "Saenger waehlen")
					Spacer()
					Image(systemName: "chevron.down")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.vertical, 10)
				.padding(.horizontal, 12)
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 8))
			}

			if selection.isEmpty {
				Text("Keine Auswahl")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 8) {
						ForEach(selection, id: \.self) { singer in
							HStack(spacing: 6) {
								Text(singer)
									.font(.caption)
								Button {
									remove(singer)
								} label: {
									Image(systemName: "xmark")
										.font(.caption2.bold())
								}
								.buttonStyle(.plain)
							}
							.padding(.vertical, 6)
							.padding(.horizontal, 10)
							.background(Color.accentColor.opacity(0.15))
							.clipShape(Capsule())
						}
					}
				}
			}
		}
	}

	private func toggle(_ singer: String) {
		if selection.contains(singer) {
			remove(singer)
		} else {
			selection.append(singer)
		}
	}

	private func remove(_ singer: String) {
		selection.removeAll { $0 == singer }
	}
}

