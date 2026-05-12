// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SoftConfigOut: Codable {
    let genres: [AppConfigOption]
    let gigTypes: [AppConfigOption]
    let songStatuses: [AppConfigOption]
    let gigStatuses: [AppConfigOption]
    let tonekeys: [AppConfigOption]
    let rehearsalSongStatuses: [String]
}

struct SoftConfigMeta: Codable {
    let editableKeys: [String]
    let updatedAt: String
}

struct SoftConfigAdminResponse: Codable {
    let data: SoftConfigOut
    let meta: SoftConfigMeta
}

struct SoftConfigOptionPayload: Codable {
    let key: String?
    let label: String
}

struct SoftConfigUpdateRequest: Codable {
    let genres: [SoftConfigOptionPayload]
    let gigTypes: [SoftConfigOptionPayload]
    let songStatuses: [SoftConfigOptionPayload]
    let gigStatuses: [SoftConfigOptionPayload]
    let tonekeys: [SoftConfigOptionPayload]
    let rehearsalSongStatuses: [String]
}

struct SoftConfigUpdateResponse: Codable {
    let message: String
    let updatedKeys: [String]
    let data: SoftConfigOut
}

extension FrontendAppConfig {
    init(from softConfig: SoftConfigOut) {
        self.genres = softConfig.genres
        self.gigTypes = softConfig.gigTypes
        self.songStatuses = softConfig.songStatuses
        self.gigStatuses = softConfig.gigStatuses
        self.tonekeys = softConfig.tonekeys
        self.rehearsalSongStatuses = softConfig.rehearsalSongStatuses
    }
}

