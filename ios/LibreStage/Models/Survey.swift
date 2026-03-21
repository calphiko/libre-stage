// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - List

struct SurveyList: Codable, Identifiable, Hashable {
    let id: Int
    let kind_of_survey: String
    let rf_survey: String
    let released: Bool
    let closed: Bool
    let release_date: String
    let user_created: Int
}

// MARK: - Detail

struct SurveyFeedbackOut: Codable {
    let id: Int?
    let id_sv_field: Int
    let id_user: Int
    let value: String?
    let comment: String?
}

struct SurveyFieldsOut: Codable, Identifiable {
    let id: Int
    let id_survey: Int
    let field_text: String
    var feedbacks: [SurveyFeedbackOut]
}

struct SurveyQuestionOut: Codable, Identifiable {
    let id: Int
    let kind_of_survey: String
    let rf_survey: String
    let released: Bool
    let release_date: String
    let closed: Bool
    var fields: [SurveyFieldsOut]
    let user_created: Int
}

// MARK: - Create

struct SurveyFieldIn: Encodable {
    let field_text: String
}

struct SurveyIn: Encodable {
    let kind_of_survey: String
    let rf_survey: String
    let released: Bool
    let closed: Bool
    let fields: [SurveyFieldIn]
}

// MARK: - Feedback Update  (PUT /surveys/{id}/feedback)

struct SurveyFeedbackPayload: Encodable {
    let id_sv_field: Int
    let id_user: Int
    let value: String?
    let comment: String?
}

// MARK: - Reminder

struct ReminderDetail: Codable, Equatable {
    let user: String
    let channel: String
}

struct ReminderResponse: Codable, Equatable {
    let message: String
    let details: [ReminderDetail]
}
