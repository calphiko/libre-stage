// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - API Response Types

struct GigChecklistItem: Codable, Identifiable {
    let id: Int
    let gig_id: Int
    let title: String
    let category: String?
    let assignee_user_id: Int?
    let assignee_name: String?
    let assignee_clear_name: String?
    let done: Bool
    let due_datetime: String?   // ISO datetime string, z.B. "2026-07-08T18:00:00"
    let position: Int?
    let comment: String?

    var displayAssignee: String? {
        let name = assignee_clear_name ?? assignee_name ?? ""
        return name.isEmpty ? nil : name
    }
}

// MARK: - API Request Types

struct GigChecklistItemIn: Encodable {
    let title: String
    let category: String?
    let assignee_user_id: Int?
    let assignee_name: String?
    let done: Bool
    let due_datetime: String?
    let position: Int?
    let comment: String?
}

