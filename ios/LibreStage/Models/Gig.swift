// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct GigOut: Codable, Identifiable {
    let id: Int
    let name: String?
    let datum: String?
    let venue: String?
    let organizer: String?
    let kind_of_gig: String?
    let doors: String?
    let begin: String?
    let end: String?
    let status: String?
    let publish: Int?
}

struct SongInSetOut: Codable, Identifiable {
    let id: Int
    let setsong_id: Int?
    let song_id: Int
    let position: Int?
    let title: String
    let duration: String?
    let singer_lead: String?
    let singer_background: String?
    let interpret: String?
    let genre: String?
    let tone_key: String?
    let ytlink: String?
    let comment: String?
    let brass: Int?
    let status: String?
}

struct SetInGigOut: Codable, Identifiable {
    let id: Int?
    let gigset_id: Int?
    let set_id: Int?
    let set_name: String?
    let pause: String?
    let setlist_name: String?
    let songs: [SongInSetOut]
}

struct GigSetlistOut: Codable, Identifiable {
    let id: Int
    let name: String
    let datum: String?
    let organizer: String?
    let kind_of_gig: String?
    let venue: String?
    let doors: String?
    let begin: String?
    let end: String?
    let status: String?
    let publish: String?
    let sets: [SetInGigOut]
}

// MARK: - Live Mode

struct SongInSetLM: Codable, Identifiable {
    let id: Int          // SetSong ID
    let title: String
    let interpret: String
    let position: Int
    let tone_key: String?
    let comment: String?
    let uebersprungen: Bool?
    let eingeschoben: Bool?
    let feedback: Int?
}

struct SetInGigLM: Codable, Identifiable {
    let id: Int
    let position: Int
    let pause: String?
    let setlist_name: String?
    let songs: [SongInSetLM]
}

struct GigSetListLiveMode: Codable, Identifiable {
    let id: Int
    let name: String
    let datum: String?
    let doors: String?
    let begin: String?
    let end: String?
    let sets: [SetInGigLM]
}

// MARK: - Live Mode Update

struct SongInSetLMUpdate: Encodable {
    let id: Int
    let uebersprungen: Bool?
    let eingeschoben: Bool?
    let feedback: Int?
}

