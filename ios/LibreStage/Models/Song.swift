// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SongOut: Codable, Identifiable {
    let id: Int?
    let title: String?
    let interpret: String?
    let genre: String?
    let singer_background: String?
    let singer_lead: String?
    let composer: String?
    let texter: String?
    let publisher: String?
    let arrangement: String?
    let tone_key: String?
    let status: String?
    let comment: String?
    let ytlink: String?
    let duration: String?
    let brass: Int?
    let duration_formatted: String?
    let singer_lead_short: String?
}

struct SongFeedbackBase: Codable {
    let song_id: Int
    let user_id: Int
    let feedback: String
}

struct SongCandidateOut: Codable, Identifiable {
    let id: Int
    let title: String
    let interpret: String
    let genre: String?
    let singer_lead: String?
    let singer_background: String?
    let composer: String?
    let tone_key: String?
    let status: String?
    let ytlink: String?
    let brass: Int?
    let duration: String?
    let feedbacks: [SongFeedbackBase]
}

struct SongFeedbackIn: Encodable {
    let song_id: Int
    let user_id: Int
    let feedback: String
}

