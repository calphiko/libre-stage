// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct LiveModeView: View {
    let gig: GigOut
    @State private var vm = GigDetailViewModel()
    @Environment(AuthManager.self) private var authManager

    private var canWrite: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.liveMode == nil {
                SkeletonList()
            } else if let lm = vm.liveMode {
                List {
                    // Read-only banner for regular users
                    if !canWrite {
                        Section {
                            Label("Nur Lesezugriff – Änderungen erfordern Editor-Rechte", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    ForEach(lm.sets) { set in
                        Section(set.setlist_name ?? "Set \(set.position)") {
                            ForEach(set.songs) { song in
                                LiveModeSongRow(
                                    song: song,
                                    canWrite: canWrite,
                                    onFeedback: { rating in
                                        Task {
                                            let update = SongInSetLMUpdate(
                                                id: song.id,
                                                uebersprungen: song.uebersprungen,
                                                eingeschoben: song.eingeschoben,
                                                feedback: rating
                                            )
                                            await vm.updateSong(update, gigId: gig.id)
                                        }
                                    },
                                    onSkip: {
                                        Task {
                                            let update = SongInSetLMUpdate(
                                                id: song.id,
                                                uebersprungen: !(song.uebersprungen ?? false),
                                                eingeschoben: song.eingeschoben,
                                                feedback: song.feedback
                                            )
                                            await vm.updateSong(update, gigId: gig.id)
                                        }
                                    }
                                )
                            }
                            if let pause = set.pause {
                                Label("Pause: \(pause)", systemImage: "pause.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .refreshable { await vm.loadLiveMode(gigId: gig.id) }
            } else {
                ContentUnavailableView("Kein Live-Modus", systemImage: "bolt.slash")
            }
        }
        .navigationTitle("Live: \(gig.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($vm.error)
        .task { await vm.loadLiveMode(gigId: gig.id) }
    }
}

private struct LiveModeSongRow: View {
    let song: SongInSetLM
    let canWrite: Bool
    let onFeedback: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(song.position).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(song.title)
                            .font(.body)
                            .strikethrough(song.uebersprungen ?? false)
                            .foregroundStyle((song.uebersprungen ?? false) ? .secondary : .primary)
                    }
                    Text(song.interpret)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Status badges
                if song.eingeschoben ?? false {
                    Text("Eingeschoben")
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                if song.uebersprungen ?? false {
                    Text("Übersprungen")
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            // Controls
            HStack(spacing: 12) {
                // Skip button
                Button {
                    onSkip()
                } label: {
                    Label(
                        (song.uebersprungen ?? false) ? "Rückgängig" : "Überspringen",
                        systemImage: (song.uebersprungen ?? false) ? "arrow.uturn.backward" : "forward.fill"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(!canWrite)

                Spacer()

                // Feedback stars 1–3
                ForEach(1...3, id: \.self) { star in
                    Button {
                        onFeedback(star)
                    } label: {
                        Image(systemName: (song.feedback ?? 0) >= star ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canWrite)
                }
            }

            if let comment = song.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
}

