// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class SongDetailsViewModel {
    var song: SongInSetOut?
    var songFields: [SongFieldDefinition] = SongFieldDefinition.fromConfig(nil)
    var singerOptions: [String] = []
    var statistics: SongStatistics?
    var rehearsalHistory: [SongRehearsalHistoryEntry] = []

    var isLoading = false
    var isSaving = false
    var isStatisticsLoading = false
    var isRehearsalHistoryLoading = false

    var rehearsalHistoryLoaded = false
    var error: AppError?

    @MainActor
    func loadSong(songId: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let base: SongInSetOut = try await APIClient.shared.get(path: "/songs/info/\(songId)")
            song = base

            // /songs/info liefert nicht alle SongIn-Felder; fehlende Werte aus /songs/ auffuellen.
            if let enriched = try? await fetchEnrichedSong(songId: songId) {
                song = mergeSong(base: base, enriched: enriched)
            }
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
            // Fallback auf lokale Defaults, damit der Editor auch ohne Config weiter funktioniert.
            songFields = SongFieldDefinition.fromConfig(nil)
        }
    }

    @MainActor
    func loadSingerOptions() async {
        do {
            let singers: [String] = try await APIClient.shared.get(path: "/songs/singers")
            singerOptions = singers
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    private func fetchEnrichedSong(songId: Int) async throws -> SongOut? {
        let allSongs: [SongOut] = try await APIClient.shared.get(path: "/songs/")
        return allSongs.first(where: { $0.id == songId })
    }

    private func mergeSong(base: SongInSetOut, enriched: SongOut?) -> SongInSetOut {
        SongInSetOut(
            id: base.id,
            setsong_id: base.setsong_id,
            song_id: base.song_id,
            position: base.position,
            title: base.title,
            duration: base.duration ?? enriched?.duration,
            singer_lead: base.singer_lead ?? enriched?.singer_lead,
            singer_background: base.singer_background ?? enriched?.singer_background,
            interpret: base.interpret ?? enriched?.interpret,
            genre: base.genre ?? enriched?.genre,
            composer: base.composer ?? enriched?.composer,
            texter: base.texter ?? enriched?.texter,
            publisher: base.publisher ?? enriched?.publisher,
            arrangement: base.arrangement ?? enriched?.arrangement,
            tone_key: base.tone_key ?? enriched?.tone_key,
            ytlink: base.ytlink ?? enriched?.ytlink,
            comment: base.comment ?? enriched?.comment,
            text: base.text,
            brass: base.brass ?? enriched?.brass,
            status: base.status ?? enriched?.status
        )
    }

    @MainActor
    func loadStatistics(songId: Int) async {
        if statistics != nil || isStatisticsLoading { return }
        isStatisticsLoading = true
        defer { isStatisticsLoading = false }

        do {
            statistics = try await APIClient.shared.get(path: "/songs/\(songId)/statistics")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadRehearsalHistory(songId: Int, limit: Int = 3) async {
        if rehearsalHistoryLoaded || isRehearsalHistoryLoading { return }
        isRehearsalHistoryLoading = true
        defer {
            isRehearsalHistoryLoading = false
            rehearsalHistoryLoaded = true
        }

        do {
            rehearsalHistory = try await APIClient.shared.get(
                path: "/songs/\(songId)/rehearsal_history",
                queryItems: [URLQueryItem(name: "limit", value: String(limit))]
            )
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func save(songId: Int, draft: SongDetailsDraft) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let request = try draft.toUpdateRequest(id: songId)
            let _: SongOut = try await APIClient.shared.put(path: "/songs/\(songId)", body: request)
            await loadSong(songId: songId)
            return true
        } catch let e as SongDetailsDraft.ValidationError {
            error = .serverError(statusCode: 400, detail: e.localizedDescription)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }

        return false
    }
}


