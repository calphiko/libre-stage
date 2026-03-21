// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct GigDetailView: View {
    let gig: GigOut
    @State private var vm = GigDetailViewModel()

    var body: some View {
        Group {
            if vm.isLoading && vm.setlist == nil {
                SkeletonList()
            } else if let setlist = vm.setlist {
                List {
                    // MARK: Gig Info
                    Section("Infos") {
                        GigInfoRow(label: "Datum",       value: gig.datum)
                        GigInfoRow(label: "Venue",       value: gig.venue)
                        GigInfoRow(label: "Veranstalter",value: gig.organizer)
                        GigInfoRow(label: "Art",         value: gig.kind_of_gig)
                        GigInfoRow(label: "Einlass",     value: gig.doors)
                        GigInfoRow(label: "Beginn",      value: gig.begin)
                        GigInfoRow(label: "Ende",        value: gig.end)
                        GigInfoRow(label: "Status",      value: gig.status)
                    }

                    // MARK: Setlist
                    ForEach(setlist.sets) { set in
                        Section(set.setlist_name ?? set.set_name ?? "Set") {
                            ForEach(Array(set.songs.enumerated()), id: \.element.id) { idx, song in
                                SetlistSongRow(index: idx + 1, song: song)
                            }
                            if let pause = set.pause {
                                Label("Pause: \(pause)", systemImage: "pause.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // MARK: Live-Modus Button
                    Section {
                        NavigationLink {
                            LiveModeView(gig: gig)
                        } label: {
                            Label("Live-Modus starten", systemImage: "bolt.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.accentColor)
                    }
                }
                .refreshable { await vm.loadSetlist(gigId: gig.id) }
            } else {
                ContentUnavailableView("Keine Setlist", systemImage: "music.note.list")
            }
        }
        .navigationTitle(gig.name ?? "Gig")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($vm.error)
        .task { await vm.loadSetlist(gigId: gig.id) }
    }
}

private struct GigInfoRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

private struct SetlistSongRow: View {
    let index: Int
    let song: SongInSetOut

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.body)
                if let interpret = song.interpret {
                    Text(interpret).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let key = song.tone_key {
                Text(key)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

