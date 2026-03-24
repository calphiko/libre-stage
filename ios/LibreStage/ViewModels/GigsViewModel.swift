// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class GigsViewModel {
    var gigs: [GigOut] = []
    var isLoading = false
    var error: AppError?

    @MainActor
    func upsertGig(_ updatedGig: GigOut) {
        if let index = gigs.firstIndex(where: { $0.id == updatedGig.id }) {
            gigs[index] = updatedGig
        } else {
            gigs.insert(updatedGig, at: 0)
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            gigs = try await APIClient.shared.get(path: "/gigs/")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }
}

@Observable
final class GigDetailViewModel {
    var setlist: GigSetlistOut? = nil
    var liveMode: GigSetListLiveMode? = nil
    var liveModeAvailability: LiveModeAvailability? = nil
    var gigFields: [GigFieldDefinition] = GigFieldDefinition.fromConfig(nil)
    var songs: [SongOut] = []
    var isLoading = false
    var isSaving = false
    var error: AppError?

    @MainActor
    func loadGigFieldConfig() async {
        do {
            let config: FrontendAppConfig = try await APIClient.shared.get(path: "/public/app_config")
            gigFields = GigFieldDefinition.fromConfig(config)
        } catch {
            gigFields = GigFieldDefinition.fromConfig(nil)
        }
    }

    @MainActor
    func loadSetlist(gigId: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            setlist = try await APIClient.shared.get(path: "/gigs/\(gigId)/setlist")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadLiveMode(gigId: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            liveMode = try await APIClient.shared.get(path: "/gigs_lm/\(gigId)")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadSongs() async {
        do {
            songs = try await APIClient.shared.get(path: "/songs/")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func saveGig(gigId: Int, draft: GigDetailsDraft) async -> GigOut? {
        isSaving = true
        defer { isSaving = false }

        do {
            let request = try draft.toUpdateRequest(id: gigId)
            let updated: GigOut = try await APIClient.shared.put(path: "/gigs/\(gigId)", body: request)
            return updated
        } catch let e as GigDetailsDraft.ValidationError {
            error = .serverError(statusCode: 400, detail: e.localizedDescription)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }

        return nil
    }

    @MainActor
    func loadLiveModeAvailability(gigId: Int, force: Bool = false) async {
        do {
            liveModeAvailability = try await APIClient.shared.get(
                path: "/gigs/\(gigId)/livemode_available",
                queryItems: [URLQueryItem(name: "force", value: force ? "true" : "false")]
            )
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func downloadSetlistPDF(gig: GigOut) async -> URL? {
        await downloadGigFile(
            path: "/gigs/\(gig.id)/setlist.pdf",
            fallbackFilename: sanitizedFilename(base: gig.name ?? "setlist", suffix: "setlist", ext: "pdf")
        )
    }

    @MainActor
    func downloadGemaList(gig: GigOut) async -> URL? {
        await downloadGigFile(
            path: "/gigs/\(gig.id)/gemalist",
            fallbackFilename: sanitizedFilename(base: gig.name ?? "gemaliste", suffix: "gemaliste", ext: "xlsx")
        )
    }

    @MainActor
    func updateSong(_ update: SongInSetLMUpdate, gigId: Int, reloadAfterUpdate: Bool = true) async {
        do {
            let _: SongInSetLM = try await APIClient.shared.put(
                path: "/gigs_lm/\(gigId)/",
                body: update
            )
            if reloadAfterUpdate {
                await loadLiveMode(gigId: gigId)
            }
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func insertSong(afterSetSongId: Int, songId: Int, gigId: Int) async -> SongInSetLM? {
        do {
            let inserted: SongInSetLM = try await APIClient.shared.post(
                path: "/gigs_lm/\(gigId)/insert-song?after_setsong_id=\(afterSetSongId)&song_id=\(songId)",
                body: EmptyInsertBody()
            )
            await loadLiveMode(gigId: gigId)
            return inserted
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
        return nil
    }

    @MainActor
    func jumpToSong(currentSongId: Int?, targetSongId: Int, gigId: Int) async -> Bool {
        let ordered = orderedLiveSongs()
        guard let targetIndex = ordered.firstIndex(where: { $0.id == targetSongId }) else {
            return false
        }

        guard let currentSongId,
              let currentIndex = ordered.firstIndex(where: { $0.id == currentSongId }) else {
            return true
        }

        if targetIndex <= currentIndex {
            return true
        }

        let songsToSkip = ordered[currentIndex..<targetIndex].filter {
            !($0.uebersprungen ?? false) && $0.feedback == nil
        }

        for song in songsToSkip {
            let update = SongInSetLMUpdate(
                id: song.id,
                uebersprungen: true,
                feedback: nil,
                includeUebersprungen: true,
                includeFeedback: true
            )
            await updateSong(update, gigId: gigId, reloadAfterUpdate: false)
        }

        await loadLiveMode(gigId: gigId)
        return true
    }

    func orderedLiveSongs() -> [SongInSetLM] {
        guard let liveMode else { return [] }
        return liveMode.sets
            .sorted { $0.position < $1.position }
            .flatMap { set in
                set.songs.sorted { $0.position < $1.position }
            }
    }

    func firstUnmarkedSongId() -> Int? {
        orderedLiveSongs().first(where: { !($0.uebersprungen ?? false) && $0.feedback == nil })?.id
    }

    func filteredSongsForInsert(query: String) -> [SongOut] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(songs.prefix(25)) }
        return songs.filter { song in
            let title = song.title ?? ""
            let interpret = song.interpret ?? ""
            return title.localizedCaseInsensitiveContains(trimmed)
                || interpret.localizedCaseInsensitiveContains(trimmed)
        }
        .prefix(25)
        .map { $0 }
    }

    private struct EmptyInsertBody: Encodable {}

    @MainActor
    private func downloadGigFile(path: String, fallbackFilename: String) async -> URL? {
        do {
            let downloaded = try await APIClient.shared.download(path: path)
            let filename = downloaded.suggestedFilename?.isEmpty == false ? downloaded.suggestedFilename! : fallbackFilename
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try downloaded.data.write(to: url, options: .atomic)
            return url
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
        return nil
    }

    private func sanitizedFilename(base: String, suffix: String, ext: String) -> String {
        let cleanedBase = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = cleanedBase.isEmpty ? suffix : cleanedBase
        return "\(stem)_\(suffix).\(ext)"
    }
}
