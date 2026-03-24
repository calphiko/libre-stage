// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class SongsViewModel {
    var songs: [SongOut] = []
    var candidates: [SongCandidateOut] = []
    var totalEligibleVoters: Int = 0
    var isLoading = false
    var error: AppError?
    var searchText = ""

    var filtered: [SongOut] {
        guard !searchText.isEmpty else { return songs }
        return songs.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.interpret ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    @MainActor
    func loadSongs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            songs = try await APIClient.shared.get(path: "/songs/")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadCandidates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let fetchedCandidates: [SongCandidateOut] = APIClient.shared.get(path: "/songs/candidates/")
            async let users: [UserListElem] = APIClient.shared.get(path: "/user_list")
            candidates = try await fetchedCandidates
            totalEligibleVoters = try await users.count
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func submitCandidateFeedback(songId: Int, feedbacks: [SongFeedbackIn]) async {
        do {
            let _: [SongFeedbackBase] = try await APIClient.shared.put(
                path: "/songs/candidates/feedback/\(songId)",
                body: feedbacks
            )
            await loadCandidates()
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func acceptCandidate(songId: Int) async {
        do {
            let _: [SongOut] = try await APIClient.shared.put(
                path: "/songs/candidates/accept/\(songId)",
                body: EmptyBody()
            )
            await loadCandidates()
            await loadSongs()
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }
}

private struct EmptyBody: Encodable {}

