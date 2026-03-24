// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct CandidatesView: View {
    @State private var vm = SongsViewModel()
    @Environment(AuthManager.self) private var authManager

    private var isEditor: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    private var isMusician: Bool {
        authManager.currentUser?.musician ?? false
    }

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
                        totalEligibleVoters: vm.totalEligibleVoters,
                        currentUserId: authManager.currentUser?.id ?? -1,
                        canVote: isMusician,
                        canAccept: isEditor,
                        onVote: { feedbacks in
                            Task {
                                await vm.submitCandidateFeedback(
                                    songId: song.id,
                                    feedbacks: feedbacks
                                )
                            }
                        },
                        onAccept: {
                            Task {
                                await vm.acceptCandidate(songId: song.id)
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
    let totalEligibleVoters: Int
    let currentUserId: Int
    let canVote: Bool
    let canAccept: Bool
    let onVote: ([SongFeedbackIn]) -> Void
    let onAccept: () -> Void

    private struct FeedbackStats {
        let relativeYes: Int
        let relativeNo: Int
        let yes: Int
        let no: Int
        let abstain: Int
        let sum: Int
    }

    private var myFeedback: String? {
        song.feedbacks.first { $0.user_id == currentUserId }?.feedback
    }

    private var stats: FeedbackStats {
        let yes = song.feedbacks.filter { $0.feedback == "a" }.count
        let no = song.feedbacks.filter { $0.feedback == "na" }.count
        let abstain = song.feedbacks.filter { $0.feedback == "o" }.count
        let sum = yes + no + abstain
        let yesNo = yes + no
        let relativeYes = yesNo > 0 ? Int((Double(yes) / Double(yesNo) * 100.0).rounded()) : 0
        let relativeNo = yesNo > 0 ? 100 - relativeYes : 0
        return FeedbackStats(relativeYes: relativeYes, relativeNo: relativeNo, yes: yes, no: no, abstain: abstain, sum: sum)
    }

    private var quorumTarget: Int? {
        guard totalEligibleVoters > 0 else { return nil }
        return max(3, Int(Double(totalEligibleVoters) * 0.75))
    }

    private var quorumReached: Bool {
        guard let quorumTarget else { return true }
        return stats.sum >= quorumTarget
    }

    private var canAcceptSong: Bool {
        let yesNo = stats.yes + stats.no
        return quorumReached && yesNo > 0 && stats.yes >= yesNo / 2
    }

    private func submitVote(_ value: String) {
        var next = song.feedbacks

        if let idx = next.firstIndex(where: { $0.user_id == currentUserId }) {
            if next[idx].feedback == value {
                next.remove(at: idx)
            } else {
                next[idx] = SongFeedbackBase(song_id: song.id, user_id: currentUserId, feedback: value)
            }
        } else {
            next.append(SongFeedbackBase(song_id: song.id, user_id: currentUserId, feedback: value))
        }

        let payload = next.map { SongFeedbackIn(song_id: $0.song_id, user_id: $0.user_id, feedback: $0.feedback) }
        onVote(payload)
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
                Text("∑ \(stats.sum) / \(totalEligibleVoters > 0 ? String(totalEligibleVoters) : "?")")
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
                voteButton(icon: "👍", value: "a")
                voteButton(icon: "👎", value: "na")
                voteButton(icon: "🤷", value: "o")
                if !canVote {
                    Text("--")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text("👍 \(stats.yes)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())

                Text("👎 \(stats.no)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Capsule())

                if stats.abstain > 0 {
                    Text("🤷 \(stats.abstain)")
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }

                if stats.yes + stats.no > 0 {
                    Text("Ja \(stats.relativeYes)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Nein \(stats.relativeNo)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let quorumTarget {
                Text("Quorum: \(stats.sum)/\(quorumTarget) (75%)")
                    .font(.caption2)
                    .foregroundStyle(quorumReached ? .green : .secondary)
            }

            if canAccept && canAcceptSong {
                Button {
                    onAccept()
                } label: {
                    Label("Vorschlag uebernehmen", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            if let my = myFeedback {
                Text("Dein Feedback: \(labelForFeedback(my))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    @ViewBuilder
    private func voteButton(icon: String, value: String) -> some View {
        Button {
            guard canVote else { return }
            submitVote(value)
        } label: {
            Text(icon)
                .font(.title3)
                .padding(6)
                .background(myFeedback == value ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(myFeedback == value ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canVote)
    }

    private func labelForFeedback(_ value: String) -> String {
        switch value {
        case "a": return "Ja"
        case "na": return "Nein"
        case "o": return "Enthaltung"
        default: return value
        }
    }
}

