// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct UserTodo: Codable, Identifiable {
    let id: Int
    let todo: String
    let user_name: String
    let song_title: String
    let song_interpret: String
    let done: Bool
    let dt: String?
}

struct SongForFeedback: Codable, Identifiable {
    let id: Int
    let title: String
    let interpret: String
    let status: String
}

struct SurveyForFeedback: Codable, Identifiable {
    let id: Int
    let kind_of_survey: String
    let rf_survey: String
    let release_date: String?
}

struct GigChecklistTodo: Codable, Identifiable {
    let id: Int
    let gig_id: Int
    let gig_name: String
    let gig_datum: String?
    let title: String
    let category: String?
    let due_datetime: String?

    var isOverdue: Bool {
        guard let raw = due_datetime else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) { return date < Date() }
        // fallback ohne Fraktion
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = f2.date(from: raw) { return date < Date() }
        return false
    }
}

struct PendingAvailabilityGig: Codable, Identifiable {
    let id: Int
    let name: String?
    let datum: String?
    let kind_of_gig: String?
}

struct UserTodoList: Codable {
    let todo: [UserTodo]
    let songs_to_feedback: [SongForFeedback]
    let surveys_to_feedback: [SurveyForFeedback]
    let pending_gigs: [PendingAvailabilityGig]
    let gig_checklist_todos: [GigChecklistTodo]
}

struct PasswordUpdateRequest: Encodable {
    let user_id: Int
    let old_password: String
    let new_password: String
}

