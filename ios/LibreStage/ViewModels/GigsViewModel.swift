// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class GigsViewModel {
    var gigs: [GigOut] = []
    var seasonStatistics: SeasonStatistics? = nil
    var gigFields: [GigFieldDefinition] = GigFieldDefinition.fromConfig(nil)
    var error: AppError?
    var isLoading = false
    var isSeasonStatisticsLoading = false
    var isCreatingGig = false

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
            PushNotificationService.shared.observeGigs(gigs)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadSeasonStatistics(year: Int?) async {
        isSeasonStatisticsLoading = true
        defer { isSeasonStatisticsLoading = false }

        do {
            let query = year.map { [URLQueryItem(name: "jahr", value: String($0))] } ?? []
            seasonStatistics = try await APIClient.shared.get(path: "/gigs/statistics", queryItems: query)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

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
    func createGig(draft: GigDetailsDraft) async -> GigOut? {
        isCreatingGig = true
        defer { isCreatingGig = false }

        do {
            let request = try draft.toCreateRequest()
            let createdList: [GigOut] = try await APIClient.shared.post(path: "/gigs/", body: request)
            gigs = createdList
            PushNotificationService.shared.markGigsAsSeen(createdList)
            return createdList.last
        } catch let e as GigDetailsDraft.ValidationError {
            error = .serverError(statusCode: 400, detail: e.localizedDescription)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }

        return nil
    }
}

@Observable
final class GigDetailViewModel {
    var setlist: GigSetlistOut? = nil
    var gigSchedule: GigScheduleOut? = nil
    var liveMode: GigSetListLiveMode? = nil
    var liveModeAvailability: LiveModeAvailability? = nil
    var gigFields: [GigFieldDefinition] = GigFieldDefinition.fromConfig(nil)
    var songs: [SongOut] = []
    var isLoading = false
    var gigStatistics: GigStatistics? = nil
    var isSaving = false
    var isGigScheduleLoading = false
    var isGigScheduleSaving = false
    var isGigStatisticsLoading = false
    var error: AppError?

    // Availability
    var availability: EventAvailabilityOut? = nil
    var isAvailabilityLoading = false
    var isAvailabilitySaving = false

    // Checklist
    var checklist: [GigChecklistItem] = []
    var isChecklistLoading = false

    // Users (für Assignee-Auswahl)
    var users: [UserListElem] = []
    var isUsersLoading = false

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
    func loadGigSchedule(gigId: Int) async {
        isGigScheduleLoading = true
        defer { isGigScheduleLoading = false }

        do {
            gigSchedule = try await APIClient.shared.get(path: "/gigs/\(gigId)/schedule/")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func saveGigScheduleBulk(gigId: Int, payload: GigScheduleBulkUpdateIn) async -> GigScheduleOut? {
        isGigScheduleSaving = true
        defer { isGigScheduleSaving = false }

        do {
            let updated: GigScheduleOut = try await APIClient.shared.put(path: "/gigs/\(gigId)/schedule/", body: payload)
            gigSchedule = updated
            return updated
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }

        return nil
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
    func loadGigStatistics(gigId: Int) async {
        isGigStatisticsLoading = true
        defer { isGigStatisticsLoading = false }

        do {
            gigStatistics = try await APIClient.shared.get(path: "/gigs/\(gigId)/statistics")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Availability

    @MainActor
    func loadAvailability(gigId: Int) async {
        isAvailabilityLoading = true
        defer { isAvailabilityLoading = false }
        do {
            availability = try await APIClient.shared.get(path: "/availability/gig/\(gigId)")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func setAvailability(gigId: Int, data: AvailabilityIn) async {
        isAvailabilitySaving = true
        defer { isAvailabilitySaving = false }
        do {
            availability = try await APIClient.shared.put(path: "/availability/gig/\(gigId)", body: data)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func deleteAvailability(gigId: Int) async {
        isAvailabilitySaving = true
        defer { isAvailabilitySaving = false }
        do {
            availability = try await APIClient.shared.delete(path: "/availability/gig/\(gigId)")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Checklist

    @MainActor
    func loadChecklist(gigId: Int) async {
        isChecklistLoading = true
        defer { isChecklistLoading = false }
        do {
            checklist = try await APIClient.shared.get(path: "/gigs/\(gigId)/checklist")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func createChecklistItem(gigId: Int, item: GigChecklistItemIn) async {
        do {
            checklist = try await APIClient.shared.post(path: "/gigs/\(gigId)/checklist", body: item)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func updateChecklistItem(gigId: Int, itemId: Int, item: GigChecklistItemIn) async {
        do {
            checklist = try await APIClient.shared.put(path: "/gigs/\(gigId)/checklist/\(itemId)", body: item)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func toggleChecklistItemDone(gigId: Int, itemId: Int) async {
        do {
            checklist = try await APIClient.shared.patch(path: "/gigs/\(gigId)/checklist/\(itemId)/done", body: EmptyBody())
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func deleteChecklistItem(gigId: Int, itemId: Int) async {
        do {
            checklist = try await APIClient.shared.delete(path: "/gigs/\(gigId)/checklist/\(itemId)")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func loadUsersIfNeeded() async {
        guard users.isEmpty, !isUsersLoading else { return }
        isUsersLoading = true
        defer { isUsersLoading = false }
        do {
            users = try await APIClient.shared.get(path: "/user_list")
        } catch {
            // nicht-kritisch – Picker bleibt einfach leer
        }
    }

    private struct EmptyBody: Encodable {}

    @MainActor
    func downloadSetlistPDF(gig: GigOut) async -> URL? {
        await downloadGigFile(
            path: "/gigs/\(gig.id)/setlist.pdf",
            fallbackFilename: sanitizedFilename(base: gig.name ?? "setlist", suffix: "setlist", ext: "pdf")
        )
    }

    @MainActor
    func downloadForScoreSetlist(gig: GigOut) async -> URL? {
        await downloadGigFile(
            path: "/gigs/\(gig.id)/forscore-setlist",
            fallbackFilename: sanitizedFilename(base: gig.name ?? "setlist", suffix: "setlist", ext: "4ss")
        )
    }

    @MainActor
    func downloadSchedulePDF(gig: GigOut) async -> URL? {
        await downloadGigFile(
            path: "/gigs/\(gig.id)/schedule.pdf",
            fallbackFilename: sanitizedFilename(base: gig.name ?? "ablaufplan", suffix: "ablaufplan", ext: "pdf")
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
