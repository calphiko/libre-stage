// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum UserGroup: String, Codable {
    case admin
    case editor
    case user

    // Graceful fallback – unknown DB values (e.g. "Musician") fall back to .user
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UserGroup(rawValue: raw) ?? .user
    }
}

enum UserStatus: String, Codable {
    case active
    case deactivated

    // Graceful fallback – unknown or null-derived values fall back to .active
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UserStatus(rawValue: raw) ?? .active
    }
}

struct UserOut: Codable, Identifiable {
    let id: Int
    let user_name: String
    let user_group: UserGroup
    let email: String
    let clear_name: String?   // nullable in DB
    let musician: Bool?       // nullable in DB (backend setzt 0, aber Fallback)
    let is_singer: Bool?      // nullable in DB
    let mm_username: String?
    let status: UserStatus
}

struct UserListElem: Codable, Identifiable {
    let id: Int
    let user_name: String
    let clear_name: String
    let email: String
}
