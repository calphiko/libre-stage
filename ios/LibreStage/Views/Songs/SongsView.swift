// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SongsView: View {
    @State private var vm = SongsViewModel()
    @State private var selectedSongForDetails: SongsDetailSheetItem?

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Songs")
        }
        .sheet(item: $selectedSongForDetails) { item in
            NavigationStack {
                SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
            }
        }
        .errorBanner($vm.error)
        .task { await vm.loadSongs() }
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
                    NavigationLink {
                        CandidatesView()
                    } label: {
                        Label("Song-Kandidaten bewerten", systemImage: "hand.thumbsup")
                            .foregroundStyle(Color.accentColor)
                    }
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
