// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class RehearsalsViewModel {
    var rehearsals: [RehListElem] = []
    var songs: [SongOut] = []
    var users: [UserListElem] = []
    var isLoading = false
    var error: AppError?

    // Entspricht appConfig.json → rehearsalSongStatuses
    let rehearsalSongStatuses = ["vorschlag", "angenommen", "proben", "spielbar", "retired"]

    // MARK: - Abgeleitete Listen

    var upcomingRehearsals: [RehListElem] {
        let now = Date()
        return rehearsals
            .filter { endOfNextDay($0.begin) >= now }
            .sorted { $0.begin < $1.begin }
    }

    var pastRehearsals: [RehListElem] {
        let now = Date()
        return rehearsals
            .filter { endOfNextDay($0.begin) < now }
            .sorted { $0.begin > $1.begin }
    }

    // MARK: - Laden

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let rehs: [RehListElem]    = APIClient.shared.get(path: "/reh/")
            async let sngs: [SongOut]        = APIClient.shared.get(path: "/songs/")
            async let usrs: [UserListElem]   = APIClient.shared.get(path: "/user_list")
            rehearsals = try await rehs
            songs      = try await sngs
            users      = try await usrs
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Erstellen

    @MainActor
    func create(_ request: RehCreateRequest) async {
        isLoading = true
        defer { isLoading = false }
        do {
            rehearsals = try await APIClient.shared.post(path: "/reh/", body: request)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Aktualisieren

    @MainActor
    func update(_ rehearsal: RehListElem) async {
        do {
            let updated: [RehListElem] = try await APIClient.shared.put(path: "/reh/", body: rehearsal)
            if let idx = rehearsals.firstIndex(where: { $0.id == rehearsal.id }),
               let fresh = updated.first(where: { $0.id == rehearsal.id }) {
                rehearsals[idx] = fresh
            } else {
                rehearsals = updated
            }
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Löschen

    @MainActor
    func delete(_ rehearsal: RehListElem) async {
        isLoading = true
        defer { isLoading = false }
        do {
            rehearsals = try await APIClient.shared.delete(path: "/reh/\(rehearsal.id)")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Filterung vergangene Proben

    func filteredPastRehearsals(query: String) -> [RehListElem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return pastRehearsals }
        let ql = q.lowercased()
        return pastRehearsals.filter { reh in
            let dateStr = formatDate(reh.begin).lowercased()
            let commentMatch = reh.comment?.lowercased().contains(ql) ?? false
            let songMatch = reh.songs.contains {
                $0.title.lowercased().contains(ql) || $0.interpret.lowercased().contains(ql)
            }
            return dateStr.contains(ql) || commentMatch || songMatch
        }
    }

    // MARK: - Song-Suche für Picker

    func filteredSongs(query: String) -> [SongOut] {
        guard !query.isEmpty else { return songs }
        return songs.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.interpret ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Datum-Helfer

    func parseDate(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: str) { return d }
        // Fallback: "yyyy-MM-dd HH:mm:ss" (DB-Format)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "de_DE")
        return df.date(from: str)
    }

    func formatDate(_ str: String) -> String {
        guard let d = parseDate(str) else { return str }
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateStyle = .full
        df.timeStyle = .none
        return df.string(from: d)
    }

    func formatDateTime(_ str: String) -> String {
        guard let d = parseDate(str) else { return str }
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: d)
    }

    func formatTime(_ str: String) -> String {
        guard let d = parseDate(str) else { return "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }

    func formatRangeLabel(_ reh: RehListElem) -> String {
        let dateStr = formatDate(reh.begin)
        let beginTime = formatTime(reh.begin)
        guard let end = reh.end else { return "\(dateStr), \(beginTime) Uhr" }
        let endTime = formatTime(end)
        return "\(dateStr), \(beginTime)–\(endTime) Uhr"
    }

    // MARK: - Privat

    private func endOfNextDay(_ str: String) -> Date {
        guard let d = parseDate(str) else { return Date.distantPast }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: d)
        comps.day = (comps.day ?? 0) + 1
        comps.hour = 23; comps.minute = 59; comps.second = 59
        return cal.date(from: comps) ?? Date.distantPast
    }

    func clearError() { error = nil }
}
