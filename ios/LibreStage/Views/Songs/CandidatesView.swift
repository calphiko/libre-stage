// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CandidatesView: View {
    @State private var vm = SongsViewModel()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if vm.isLoading && vm.candidates.isEmpty {
                SkeletonList()
            } else if vm.candidates.isEmpty {
                ContentUnavailableView("Keine Kandidaten", systemImage: "hand.thumbsup")
            } else {
                List(vm.candidates) { song in
                    CandidateRow(
                        song: song,
                        currentUserId: authManager.currentUser?.id ?? -1,
                        onVote: { feedback in
                            Task {
                                await vm.submitFeedback(
                                    songId: song.id,
                                    userId: authManager.currentUser?.id ?? -1,
                                    feedback: feedback
                                )
                            }
                        }
                    )
                }
                .refreshable { await vm.loadCandidates() }
            }
        }
        .navigationTitle("Kandidaten")
        .errorBanner($vm.error)
        .task { await vm.loadCandidates() }
    }
}

private struct CandidateRow: View {
    let song: SongCandidateOut
    let currentUserId: Int
    let onVote: (String) -> Void

    private var myFeedback: String? {
        song.feedbacks.first { $0.user_id == currentUserId }?.feedback
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.headline)
                    Text(song.interpret).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                // Total votes badge
                Text("\(song.feedbacks.count) Votes")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let genre = song.genre {
                Text(genre).font(.caption).foregroundStyle(.secondary)
            }

            // Vote buttons
            HStack(spacing: 10) {
                Text("Dein Vote:").font(.caption).foregroundStyle(.secondary)
                ForEach(["👍", "👎", "🤷"], id: \.self) { emoji in
                    Button {
                        onVote(emoji)
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .padding(6)
                            .background(myFeedback == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(myFeedback == emoji ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                if let my = myFeedback {
                    Text("(\(my))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let link = song.ytlink, let url = URL(string: link) {
                Link(destination: url) {
                    Label("YouTube", systemImage: "play.rectangle.fill")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

