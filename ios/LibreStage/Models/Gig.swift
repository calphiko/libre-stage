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
    let composer: String?
    let texter: String?
    let publisher: String?
    let arrangement: String?
    let tone_key: String?
    let ytlink: String?
    let comment: String?
    let text: String?
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

    private let uebersprungen: Bool?
    private let eingeschoben: Bool?
    private let feedback: Int?

    private let includeUebersprungen: Bool
    private let includeEingeschoben: Bool
    private let includeFeedback: Bool

    init(
        id: Int,
        uebersprungen: Bool? = nil,
        eingeschoben: Bool? = nil,
        feedback: Int? = nil,
        includeUebersprungen: Bool = false,
        includeEingeschoben: Bool = false,
        includeFeedback: Bool = false
    ) {
        self.id = id
        self.uebersprungen = uebersprungen
        self.eingeschoben = eingeschoben
        self.feedback = feedback
        self.includeUebersprungen = includeUebersprungen
        self.includeEingeschoben = includeEingeschoben
        self.includeFeedback = includeFeedback
    }

    enum CodingKeys: String, CodingKey {
        case id, uebersprungen, eingeschoben, feedback
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)

        if includeUebersprungen {
            if let uebersprungen {
                try c.encode(uebersprungen, forKey: .uebersprungen)
            } else {
                try c.encodeNil(forKey: .uebersprungen)
            }
        }

        if includeEingeschoben {
            if let eingeschoben {
                try c.encode(eingeschoben, forKey: .eingeschoben)
            } else {
                try c.encodeNil(forKey: .eingeschoben)
            }
        }

        if includeFeedback {
            if let feedback {
                try c.encode(feedback, forKey: .feedback)
            } else {
                try c.encodeNil(forKey: .feedback)
            }
        }
    }
}

struct LiveModeAvailability: Codable {
    let available: Bool
    let reason: String?
    let can_force: Bool?
    let forced: Bool?
    let gig_date: String?
}

