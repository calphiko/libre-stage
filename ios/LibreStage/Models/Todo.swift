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

struct UserTodoList: Codable {
    let todo: [UserTodo]
    let songs_to_feedback: [SongForFeedback]
    let surveys_to_feedback: [SurveyForFeedback]
}

struct PasswordUpdateRequest: Encodable {
    let user_id: Int
    let old_password: String
    let new_password: String
}

