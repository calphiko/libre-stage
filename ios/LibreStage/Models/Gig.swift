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

enum GigFieldType {
    case text
    case option
    case time
    case date
}

struct GigFieldDefinition: Identifiable {
    let key: String
    let label: String
    let type: GigFieldType
    let required: Bool
    let options: [SongFieldOption]

    var id: String { key }

    static func fromConfig(_ config: FrontendAppConfig?) -> [GigFieldDefinition] {
        let gigTypes = config?.gigTypes.map { SongFieldOption(key: $0.key.asString, label: $0.label) } ?? []
        let gigStatuses = config?.gigStatuses.map { SongFieldOption(key: $0.key.asString, label: $0.label) } ?? []

        return [
            GigFieldDefinition(key: "name", label: "Name", type: .text, required: true, options: []),
            GigFieldDefinition(key: "datum", label: "Datum", type: .date, required: true, options: []),
            GigFieldDefinition(key: "kind_of_gig", label: "Veranstaltungsart", type: .option, required: true, options: gigTypes),
            GigFieldDefinition(key: "organizer", label: "Veranstalter", type: .text, required: false, options: []),
            GigFieldDefinition(key: "venue", label: "Veranstaltungsort", type: .text, required: false, options: []),
            GigFieldDefinition(key: "doors", label: "Einlass", type: .time, required: false, options: []),
            GigFieldDefinition(key: "begin", label: "Spielbeginn", type: .time, required: true, options: []),
            GigFieldDefinition(key: "end", label: "Spielende", type: .time, required: false, options: []),
            GigFieldDefinition(key: "status", label: "Anfragenstatus", type: .option, required: false, options: gigStatuses),
            GigFieldDefinition(
                key: "publish",
                label: "veroeffentlichen",
                type: .option,
                required: false,
                options: [
                    SongFieldOption(key: "0", label: "Nein"),
                    SongFieldOption(key: "1", label: "Ja")
                ]
            )
        ]
    }
}

struct GigUpdateRequest: Encodable {
    let id: Int
    let name: String
    let datum: String
    let venue: String?
    let kind_of_gig: String
    let doors: String?
    let begin: String
    let end: String?
    let organizer: String?
    let status: String?
    let publish: Int?
}

struct GigCreateRequest: Encodable {
    let name: String
    let datum: String
    let venue: String?
    let kind_of_gig: String
    let doors: String?
    let begin: String
    let end: String?
    let organizer: String?
    let status: String?
    let publish: Int?
}

struct GigDetailsDraft {
    var name: String = ""
    var datum: String = ""
    var venue: String = ""
    var kind_of_gig: String = ""
    var doors: String = ""
    var begin: String = ""
    var end: String = ""
    var organizer: String = ""
    var status: String = ""
    var publishText: String = ""

    enum ValidationError: LocalizedError {
        case missingField(String)
        case invalidTime(String)
        case invalidPublish

        var errorDescription: String? {
            switch self {
            case .missingField(let field):
                return "Pflichtfeld fehlt: \(field)"
            case .invalidTime(let field):
                return "Ungueltige Zeit in Feld: \(field). Erwartet HH:MM oder HH:MM:SS."
            case .invalidPublish:
                return "Veroeffentlichen muss 0 oder 1 sein."
            }
        }
    }

    init() {}

    init(gig: GigOut) {
        name = gig.name ?? ""
        datum = gig.datum ?? ""
        venue = gig.venue ?? ""
        kind_of_gig = gig.kind_of_gig ?? ""
        doors = Self.normalizeTimeForForm(gig.doors)
        begin = Self.normalizeTimeForForm(gig.begin)
        end = Self.normalizeTimeForForm(gig.end)
        organizer = gig.organizer ?? ""
        status = gig.status ?? ""
        publishText = gig.publish.map(String.init) ?? ""
    }

    func value(for key: String) -> String {
        switch key {
        case "name": return name
        case "datum": return datum
        case "venue": return venue
        case "kind_of_gig": return kind_of_gig
        case "doors": return doors
        case "begin": return begin
        case "end": return end
        case "organizer": return organizer
        case "status": return status
        case "publish": return publishText
        default: return ""
        }
    }

    mutating func setValue(_ value: String, for key: String) {
        switch key {
        case "name": name = value
        case "datum": datum = value
        case "venue": venue = value
        case "kind_of_gig": kind_of_gig = value
        case "doors": doors = value
        case "begin": begin = value
        case "end": end = value
        case "organizer": organizer = value
        case "status": status = value
        case "publish": publishText = value
        default: break
        }
    }

    func toUpdateRequest(id: Int) throws -> GigUpdateRequest {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDate = datum.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKind = kind_of_gig.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBegin = begin.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty { throw ValidationError.missingField("Name") }
        if trimmedDate.isEmpty { throw ValidationError.missingField("Datum") }
        if trimmedKind.isEmpty { throw ValidationError.missingField("Veranstaltungsart") }
        if trimmedBegin.isEmpty { throw ValidationError.missingField("Spielbeginn") }

        let normalizedBegin = try normalizeTime(trimmedBegin, field: "Spielbeginn")
        let normalizedDoors = try normalizeOptionalTime(doors, field: "Einlass")
        let normalizedEnd = try normalizeOptionalTime(end, field: "Spielende")

        let trimmedPublish = publishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let publish: Int?
        if trimmedPublish.isEmpty {
            publish = nil
        } else if let value = Int(trimmedPublish), value == 0 || value == 1 {
            publish = value
        } else {
            throw ValidationError.invalidPublish
        }

        func nilIfEmpty(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return GigUpdateRequest(
            id: id,
            name: trimmedName,
            datum: trimmedDate,
            venue: nilIfEmpty(venue),
            kind_of_gig: trimmedKind,
            doors: normalizedDoors,
            begin: normalizedBegin,
            end: normalizedEnd,
            organizer: nilIfEmpty(organizer),
            status: nilIfEmpty(status),
            publish: publish
        )
    }

    func toCreateRequest() throws -> GigCreateRequest {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDate = datum.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKind = kind_of_gig.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBegin = begin.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty { throw ValidationError.missingField("Name") }
        if trimmedDate.isEmpty { throw ValidationError.missingField("Datum") }
        if trimmedKind.isEmpty { throw ValidationError.missingField("Veranstaltungsart") }
        if trimmedBegin.isEmpty { throw ValidationError.missingField("Spielbeginn") }

        let normalizedBegin = try normalizeTime(trimmedBegin, field: "Spielbeginn")
        let normalizedDoors = try normalizeOptionalTime(doors, field: "Einlass")
        let normalizedEnd = try normalizeOptionalTime(end, field: "Spielende")

        let trimmedPublish = publishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let publish: Int?
        if trimmedPublish.isEmpty {
            publish = nil
        } else if let value = Int(trimmedPublish), value == 0 || value == 1 {
            publish = value
        } else {
            throw ValidationError.invalidPublish
        }

        func nilIfEmpty(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return GigCreateRequest(
            name: trimmedName,
            datum: trimmedDate,
            venue: nilIfEmpty(venue),
            kind_of_gig: trimmedKind,
            doors: normalizedDoors,
            begin: normalizedBegin,
            end: normalizedEnd,
            organizer: nilIfEmpty(organizer),
            status: nilIfEmpty(status),
            publish: publish
        )
    }

    private func normalizeOptionalTime(_ raw: String, field: String) throws -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return try normalizeTime(trimmed, field: field)
    }

    private func normalizeTime(_ raw: String, field: String) throws -> String {
        let parts = raw.split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              parts.allSatisfy({ Int($0) != nil }) else {
            throw ValidationError.invalidTime(field)
        }

        let hh = Int(parts[0]) ?? -1
        let mm = Int(parts[1]) ?? -1
        let ss = parts.count == 3 ? (Int(parts[2]) ?? -1) : 0

        guard (0...23).contains(hh), (0...59).contains(mm), (0...59).contains(ss) else {
            throw ValidationError.invalidTime(field)
        }

        return String(format: "%02d:%02d:%02d", hh, mm, ss)
    }

    private static func normalizeTimeForForm(_ raw: String?) -> String {
        guard let raw else { return "" }
        let parts = raw.split(separator: ":")
        guard parts.count >= 2 else { return raw }
        let hh = String(parts[0]).leftPadding(toLength: 2, withPad: "0")
        let mm = String(parts[1]).leftPadding(toLength: 2, withPad: "0")
        return "\(hh):\(mm)"
    }
}

private extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        guard count < toLength else { return self }
        return String(repeating: String(character), count: toLength - count) + self
    }
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

// MARK: - Gig Schedule

struct GigScheduleItemOut: Codable, Identifiable {
    let id: Int?
    let gig_id: Int
    let item_datetime: String
    let was: String
    let wer: String
    let wo: String
    let is_fixed: Bool

    var stableId: String {
        if let id {
            return "id-\(id)"
        }
        return "fixed-\(item_datetime)-\(was)-\(wer)-\(wo)"
    }
}

struct GigScheduleOut: Codable {
    let items: [GigScheduleItemOut]
}

struct GigScheduleBulkItemIn: Encodable {
    let id: Int?
    let item_datetime: String
    let was: String
    let wer: String
    let wo: String
}

struct GigScheduleBulkUpdateIn: Encodable {
    let items: [GigScheduleBulkItemIn]
}

// MARK: - Statistics

struct GigOverviewEntry: Codable, Identifiable {
    let gig_id: Int
    let gig_name: String
    let gig_date: String
    let song_count: Int
    let skipped_count: Int
    let inserted_count: Int
    let feedback_avg: Double?

    var id: Int { gig_id }
}

struct TopSongEntry: Codable, Identifiable {
    let song_id: Int
    let title: String
    let interpret: String
    let count: Int

    var id: Int { song_id }
}

struct SeasonStatistics: Codable {
    let jahr: Int?
    let gig_count: Int
    let played_gig_count: Int
    let total_songs: Int
    let unique_songs: Int
    let skipped_count: Int
    let inserted_count: Int
    let feedback_count: Int
    let feedback_avg: Double?
    let feedback_distribution: [String: Int]
    let genre_distribution: [String: Int]
    let top_songs: [TopSongEntry]
    let gigs_overview: [GigOverviewEntry]
}

struct GigStatsSongEntry: Codable, Identifiable {
    let song_id: Int
    let title: String
    let interpret: String
    let position: Int
    let feedback: Int?
    let uebersprungen: Bool?
    let eingeschoben: Bool?

    var id: Int { song_id * 10_000 + position }
}

struct GigStatsSetEntry: Codable, Identifiable {
    let set_name: String
    let feedback_avg: Double?
    let songs: [GigStatsSongEntry]

    var id: String { set_name }
}

struct GigStatistics: Codable {
    let gig_id: Int
    let gig_name: String
    let gig_date: String
    let song_count: Int
    let skipped_count: Int
    let inserted_count: Int
    let feedback_count: Int
    let feedback_avg: Double?
    let feedback_distribution: [String: Int]
    let genre_distribution: [String: Int]
    let sets: [GigStatsSetEntry]
}

