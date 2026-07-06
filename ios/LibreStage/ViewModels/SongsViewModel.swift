// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class SongsViewModel {
    var songs: [SongOut] = []
    var candidates: [SongCandidateOut] = []
    var openCandidateVotesCount: Int = 0
    var totalEligibleVoters: Int = 0
    var songFields: [SongFieldDefinition] = SongFieldDefinition.fromConfig(nil)
    var isLoading = false
    var isCreatingSong = false
    var error: AppError?
    var searchText = ""
    var selectedDanceStyleFilter = ""

    var availableDanceStyles: [String] {
        Array(
            Set(
                songs.compactMap {
                    let style = ($0.dance_styles ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return style.isEmpty ? nil : style
                }
            )
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var filtered: [SongOut] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return songs.filter { song in
            let matchesDanceStyle = selectedDanceStyleFilter.isEmpty
                || (song.dance_styles ?? "").caseInsensitiveCompare(selectedDanceStyleFilter) == .orderedSame

            guard matchesDanceStyle else { return false }

            guard !query.isEmpty else { return true }

            return (song.title ?? "").localizedCaseInsensitiveContains(query)
                || (song.interpret ?? "").localizedCaseInsensitiveContains(query)
                || (song.dance_styles ?? "").localizedCaseInsensitiveContains(query)
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
    func loadOpenCandidateVotesCount() async {
        do {
            let todos: UserTodoList = try await APIClient.shared.get(path: "/user_todos")
            openCandidateVotesCount = todos.songs_to_feedback.count
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
    func loadSongFieldConfig() async {
        do {
            let config: FrontendAppConfig = try await APIClient.shared.get(path: "/public/app_config")
            songFields = SongFieldDefinition.fromConfig(config)
        } catch {
            songFields = SongFieldDefinition.fromConfig(nil)
        }
    }


    @MainActor
    func createSong(draft: SongDetailsDraft) async -> SongOut? {
        isCreatingSong = true
        defer { isCreatingSong = false }

        do {
            let request = try draft.toCreateRequest()
            let created: SongOut = try await APIClient.shared.post(path: "/songs/", body: request)
            await loadSongs()
            return created
        } catch let e as SongDetailsDraft.ValidationError {
            error = .serverError(statusCode: 400, detail: e.localizedDescription)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }

        return nil
    }

    @MainActor
    func fetchSongCrawlerMetadata(interpret: String, title: String) async throws -> SongCrawlerMetadataOut {
        let query = [
            URLQueryItem(name: "interpret", value: interpret),
            URLQueryItem(name: "title", value: title)
        ]

        return try await APIClient.shared.get(path: "/songs/crawler/metadata", queryItems: query)
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

