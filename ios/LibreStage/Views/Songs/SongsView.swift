// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SongsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = SongsViewModel()
    @State private var selectedSongForDetails: SongsDetailSheetItem?
    @State private var showCandidatesSheet = false
    @State private var showCreateSongSheet = false

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Songs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Songs")
                                .font(.headline)
                                .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCreateSongSheet = true
                        } label: {
                            Label("Song hinzufuegen", systemImage: "plus")
                        }
                    }
                }
                .headerBodyBlend()
        }
        .sheet(item: $selectedSongForDetails) { item in
            NavigationStack {
                SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
            }
        }
        .sheet(isPresented: $showCandidatesSheet) {
            NavigationStack {
                CandidatesView(modalPresentation: true)
            }
        }
        .sheet(isPresented: $showCreateSongSheet) {
            CreateSongSheet(vm: vm)
        }
        .errorBanner($vm.error)
        .task {
            await vm.loadSongFieldConfig()
            await vm.loadSongs()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if vm.isLoading && vm.songs.isEmpty {
            SkeletonList()
        } else if vm.songs.isEmpty {
            ContentUnavailableView("Keine Songs", systemImage: "music.note")
        } else {
            List {
                Section {
                    Button {
                        showCandidatesSheet = true
                    } label: {
                        Label("Song-Kandidaten bewerten", systemImage: "hand.thumbsup")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                Section("Repertoire (\(vm.filtered.count))") {
                    ForEach(vm.filtered) { song in
                        if let songId = song.id {
                            Button {
                                selectedSongForDetails = SongsDetailSheetItem(id: songId, title: song.title)
                            } label: {
                                SongRow(song: song)
                            }
                            .buttonStyle(.plain)
                        } else {
                            SongRow(song: song)
                        }
                    }
                }
            }
            .searchable(text: $vm.searchText, prompt: "Titel oder Interpret suchen")
            .refreshable { await vm.loadSongs() }
        }
    }
}

private struct CreateSongSheet: View {
    @Bindable var vm: SongsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SongDetailsDraft()

    var body: some View {
        NavigationStack {
            Form {
                Section("Song") {
                    ForEach(vm.songFields) { field in
                        editorView(for: field)
                    }
                }

                if vm.isCreatingSong {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Neuer Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            if await vm.createSong(draft: draft) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isCreatingSong)
                }
            }
            .task {
                setDefaultValuesIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func editorView(for field: SongFieldDefinition) -> some View {
        switch field.type {
        case .singerList:
            TextField(
                field.required ? "\(field.label) * (Name + Name)" : "\(field.label) (Name + Name)",
                text: binding(for: field.key)
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
            TextField(field.required ? "\(field.label) *" : field.label, text: binding(for: field.key))
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { draft.value(for: key) },
            set: { draft.setValue($0, for: key) }
        )
    }

    private func setDefaultValuesIfNeeded() {
        for field in vm.songFields where field.required && field.type == .option {
            let current = draft.value(for: field.key)
            guard current.isEmpty else { continue }

            if field.key == "status",
               let suggestion = field.options.first(where: { $0.key.lowercased() == "vorschlag" }) {
                draft.setValue(suggestion.key, for: field.key)
            } else if let first = field.options.first {
                draft.setValue(first.key, for: field.key)
            }
        }
    }
}

private struct SongsDetailSheetItem: Identifiable {
    let id: Int
    let title: String?
}

private struct SongRow: View {
    let song: SongOut

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(song.title ?? "–").font(.body)
                Spacer()
                if let dur = song.duration_formatted, dur != "00:00" {
                    Text(dur)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                if let interpret = song.interpret {
                    Text(interpret).font(.caption).foregroundStyle(.secondary)
                }
                if let key = song.tone_key {
                    Text(key)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let genre = song.genre {
                    Text(genre)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

