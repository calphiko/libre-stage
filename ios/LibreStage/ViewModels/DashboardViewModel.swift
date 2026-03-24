// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class DashboardViewModel {
    var todoList: UserTodoList? = nil
    var isLoading = false
    var error: AppError?

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
            todoList = try await APIClient.shared.get(path: "/user_todos")
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .networkError(error)
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
}

