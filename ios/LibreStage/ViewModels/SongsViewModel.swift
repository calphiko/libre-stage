// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class SongsViewModel {
    var songs: [SongOut] = []
    var candidates: [SongCandidateOut] = []
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
            candidates = try await APIClient.shared.get(path: "/songs/candidates/")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func submitFeedback(songId: Int, userId: Int, feedback: String) async {
        let body = SongFeedbackIn(song_id: songId, user_id: userId, feedback: feedback)
        do {
            let _: EmptyResponse = try await APIClient.shared.post(
                path: "/songs/\(songId)/feedback",
                body: body
            )
            await loadCandidates()
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }
}

