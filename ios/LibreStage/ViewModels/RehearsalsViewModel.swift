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
        return rehearsals
            .filter { !isPast($0) }
            .sorted {
                (parseDate($0.begin) ?? Date.distantFuture) < (parseDate($1.begin) ?? Date.distantFuture)
            }
    }

    var pastRehearsals: [RehListElem] {
        return rehearsals
            .filter { isPast($0) }
            .sorted {
                (parseDate($0.begin) ?? Date.distantPast) > (parseDate($1.begin) ?? Date.distantPast)
            }
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
    func update(_ rehearsal: RehListElem) async -> RehListElem? {
        do {
            let request = RehUpdateRequest(from: rehearsal)
            let updated: [RehListElem] = try await APIClient.shared.put(path: "/reh/", body: request)
            if let idx = rehearsals.firstIndex(where: { $0.id == rehearsal.id }),
               let fresh = updated.first(where: { $0.id == rehearsal.id }) {
                rehearsals[idx] = fresh
                return fresh
            } else {
                rehearsals = updated
                return updated.first(where: { $0.id == rehearsal.id })
            }
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
        return nil
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

        // Fallbacks fuer APIs ohne Zeitzone (z. B. 2026-03-23T19:00:00)
        let posix = Locale(identifier: "en_US_POSIX")
        let tz = TimeZone.current
        let apiFormatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in apiFormatters {
            let df = DateFormatter()
            df.locale = posix
            df.timeZone = tz
            df.dateFormat = format
            if let d = df.date(from: str) { return d }
        }

        // Fallback: "yyyy-MM-dd HH:mm:ss" (DB-Format)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = posix
        df.timeZone = tz
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
        guard let beginDate = parseDate(reh.begin) else { return reh.begin }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.dateFormat = "dd.MM.yyyy"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "de_DE")
        timeFormatter.dateFormat = "HH:mm"

        let dateText = dateFormatter.string(from: beginDate)
        let beginTime = timeFormatter.string(from: beginDate)

        guard let endDate = eventEndDate(for: reh) else {
            return "\(dateText) - \(beginTime)"
        }

        let endTime = timeFormatter.string(from: endDate)
        if Calendar.current.isDate(beginDate, inSameDayAs: endDate) {
            return "\(dateText) - \(beginTime) - \(endTime)"
        }

        let endDateText = dateFormatter.string(from: endDate)
        return "\(dateText) - \(beginTime) - \(endDateText) \(endTime)"
    }

    func isPast(_ reh: RehListElem, now: Date = Date()) -> Bool {
        guard let boundary = eventEndDate(for: reh) else { return false }
        return boundary < now
    }

    // MARK: - Privat

    private func eventEndDate(for reh: RehListElem) -> Date? {
        if let end = reh.end, let endDate = parseDate(end) {
            return endDate
        }
        return parseDate(reh.begin)
    }

    func clearError() { error = nil }
}
