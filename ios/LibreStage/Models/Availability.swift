// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - API Response Types

struct AvailabilityEntry: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let user_name: String
    let clear_name: String?
    let status: String       // "available" | "unavailable" | "maybe"
    let comment: String?
    let substitute_name: String?
    let substitute_user_id: Int?
    let substitute_clear_name: String?

    var displayName: String {
        let name = clear_name ?? ""
        return name.isEmpty ? user_name : name
    }
}

struct AvailabilitySummary: Codable {
    let available: Int
    let unavailable: Int
    let maybe: Int
}

struct EventAvailabilityOut: Codable {
    let availabilities: [AvailabilityEntry]
    let summary: AvailabilitySummary
    let my_status: String?
}

// MARK: - API Request Types

struct AvailabilityIn: Encodable {
    let status: String
    let comment: String?
    let substitute_name: String?
    let substitute_user_id: Int?
}

