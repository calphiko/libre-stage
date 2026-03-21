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
    var isLoading = false
    var error: AppError?

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
    func updateSong(_ update: SongInSetLMUpdate, gigId: Int) async {
        do {
            let updated: GigSetListLiveMode = try await APIClient.shared.patch(
                path: "/gigs_lm/setsong/\(update.id)",
                body: update
            )
            liveMode = updated
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }
}
