// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class DashboardViewModel {
    var todoList: UserTodoList? = nil
    var currentSeasonStatistics: SeasonStatistics? = nil
    var nextRehearsal: RehListElem? = nil
    var nextGig: GigOut? = nil
    var error: AppError?
    var isLoading = false

    var totalBadgeCount: Int {
        guard let t = todoList else { return 0 }
        return t.todo.filter { !$0.done }.count
             + t.songs_to_feedback.count
             + t.surveys_to_feedback.count
    }

    var todoBadgeCount: Int {
        todoList?.todo.filter { !$0.done }.count ?? 0
    }

    var surveyBadgeCount: Int {
        todoList?.surveys_to_feedback.count ?? 0
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedTodos: UserTodoList = APIClient.shared.get(path: "/user_todos")
            async let loadedRehearsals: [RehListElem] = APIClient.shared.get(path: "/reh/")
            async let loadedGigs: [GigOut] = APIClient.shared.get(path: "/gigs/")

            let currentYear = Calendar.current.component(.year, from: Date())
            async let loadedSeasonStats: SeasonStatistics = APIClient.shared.get(
                path: "/gigs/statistics",
                queryItems: [URLQueryItem(name: "jahr", value: String(currentYear))]
            )

            let (todos, rehearsals, gigs, seasonStats) = try await (
                loadedTodos,
                loadedRehearsals,
                loadedGigs,
                loadedSeasonStats
            )

            todoList = todos
            currentSeasonStatistics = seasonStats
            nextRehearsal = findNextRehearsal(in: rehearsals)
            nextGig = findNextGig(in: gigs)
        } catch let e as AppError {
            error = e
            currentSeasonStatistics = nil
            nextRehearsal = nil
            nextGig = nil
        } catch {
            self.error = .networkError(error)
            currentSeasonStatistics = nil
            nextRehearsal = nil
            nextGig = nil
        }
    }

    @MainActor
    func markDone(_ todo: UserTodo) async {
        do {
            todoList = try await APIClient.shared.put(path: "/user_todos_done", body: todo)
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    private func findNextRehearsal(in rehearsals: [RehListElem]) -> RehListElem? {
        let now = Date()
        return rehearsals
            .filter { reh in
                guard let date = parseDateSafe(reh.begin) else { return false }
                return date >= now
            }
            .min { lhs, rhs in
                (parseDateSafe(lhs.begin) ?? .distantFuture) < (parseDateSafe(rhs.begin) ?? .distantFuture)
            }
    }

    private func findNextGig(in gigs: [GigOut]) -> GigOut? {
        let today = Calendar.current.startOfDay(for: Date())
        return gigs
            .filter { gig in
                guard let dateRaw = gig.datum, let date = parseDateSafe(dateRaw) else { return false }
                return date >= today
            }
            .min { lhs, rhs in
                (parseDateSafe(lhs.datum) ?? .distantFuture) < (parseDateSafe(rhs.datum) ?? .distantFuture)
            }
    }

    private func parseDateSafe(_ value: String?) -> Date? {
        guard let value else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let fullDate = ISO8601DateFormatter()
        fullDate.formatOptions = [.withFullDate]
        if let date = fullDate.date(from: value) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: value)
    }
}

