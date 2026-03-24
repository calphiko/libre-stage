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

    private enum CodingKeys: String, CodingKey {
        case id, user_name, user_group, email, clear_name, musician, is_singer, mm_username, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? -1
        user_name = try c.decodeIfPresent(String.self, forKey: .user_name) ?? ""

        let rawGroup = try c.decodeIfPresent(String.self, forKey: .user_group) ?? UserGroup.user.rawValue
        user_group = UserGroup(rawValue: rawGroup) ?? .user

        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        clear_name = try c.decodeIfPresent(String.self, forKey: .clear_name) ?? ""
        musician = try c.decodeIfPresent(Bool.self, forKey: .musician) ?? false
        is_singer = try c.decodeIfPresent(Bool.self, forKey: .is_singer) ?? false
        mm_username = try c.decodeIfPresent(String.self, forKey: .mm_username)

        let rawStatus = try c.decodeIfPresent(String.self, forKey: .status) ?? UserStatus.active.rawValue
        status = UserStatus(rawValue: rawStatus) ?? .active
    }
}

struct UserListElem: Codable, Identifiable {
    let id: Int
    let user_name: String
    let clear_name: String
    let email: String

    private enum CodingKeys: String, CodingKey {
        case id, user_name, clear_name, email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? -1
        user_name = try c.decodeIfPresent(String.self, forKey: .user_name) ?? ""
        clear_name = try c.decodeIfPresent(String.self, forKey: .clear_name) ?? user_name
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
    }
}
