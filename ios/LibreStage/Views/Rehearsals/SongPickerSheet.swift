// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SongPickerSheet: View {
    let songs: [SongOut]
    let alreadyAdded: [Int]
    let onAdd: (SongOut, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var todoText = ""
    @State private var selectedSong: SongOut? = nil

    var availableSongs: [SongOut] {
        songs.filter { s in
            guard let id = s.id else { return false }
            return !alreadyAdded.contains(id)
        }
    }

    var filteredSongs: [SongOut] {
        guard !searchText.isEmpty else { return availableSongs }
        return availableSongs.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.interpret ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Ausgewählter Song + Todo-Eingabe
                if let selected = selectedSong {
                    Section("Ausgewählter Song") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.title ?? "–").font(.headline)
                                Text(selected.interpret ?? "–")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                selectedSong = nil
                                todoText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section("Todo (optional)") {
                        TextField("Was gibts zu tun?", text: $todoText)
                            .formFieldSurface()
                    }

                    Section {
                        Button {
                            onAdd(selected, todoText)
                            dismiss()
                        } label: {
                            Label("Zur Probe hinzufügen", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // Song-Auswahl
                Section(selectedSong == nil ? "Song wählen" : "Anderer Song") {
                    if filteredSongs.isEmpty {
                        Text(searchText.isEmpty
                             ? "Alle Songs bereits hinzugefügt."
                             : "Kein Song gefunden.")
                            .foregroundStyle(.secondary).italic()
                    } else {
                        ForEach(filteredSongs) { song in
                            Button {
                                selectedSong = song
                                todoText = ""
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title ?? "–")
                                            .foregroundStyle(.primary)
                                        Text(song.interpret ?? "–")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedSong?.id == song.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .softCardContainer()
            .appShellBackground()
            .searchable(text: $searchText, prompt: "Interpret oder Titel suchen")
            .navigationTitle("Song hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

