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

struct SongRehearsalHistoryTodo: Codable, Identifiable {
    let id: Int
    let id_user: Int
    let todo: String
    let done: Bool
}

struct SongRehearsalHistoryEntry: Codable, Identifiable {
    let rehearsal_id: Int
    let rehearsal_date: String
    let comment: String?
    let todo: String?
    let done: Bool
    let rehearsal_comment: String?
    let todos: [SongRehearsalHistoryTodo]

    var id: Int { rehearsal_id }
}

struct GigPlayedEntry: Codable, Identifiable {
    let gig_id: Int
    let gig_name: String
    let gig_date: String
    let feedback: Int?
    let uebersprungen: Bool?
    let eingeschoben: Bool?

    var id: Int { gig_id }
}

struct CompanionSong: Codable, Identifiable {
    let song_id: Int
    let title: String
    let interpret: String
    let count: Int

    var id: Int { song_id }
}

struct SongStatistics: Codable {
    let rehearsal_count: Int
    let first_rehearsal: String?
    let last_rehearsal: String?

    let gig_count: Int
    let gigs_played: [GigPlayedEntry]

    let feedback_count: Int
    let feedback_avg: Double?
    let feedback_distribution: [String: Int]
    let skipped_count: Int
    let inserted_count: Int

    let companion_songs: [CompanionSong]
}

enum DynamicValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported dynamic value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var asString: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .double(let value): return String(value)
        case .null: return ""
        }
    }
}

struct AppConfigOption: Codable {
    let key: DynamicValue
    let label: String
}

struct FrontendAppConfig: Codable {
    let genres: [AppConfigOption]
    let songStatuses: [AppConfigOption]
    let tonekeys: [AppConfigOption]
}

enum SongFieldType {
    case text
    case option
    case time
    case date
    case singerList
}

struct SongFieldOption: Identifiable {
    let key: String
    let label: String

    var id: String { "\(key)|\(label)" }
}

struct SongFieldDefinition: Identifiable {
    let key: String
    let label: String
    let type: SongFieldType
    let required: Bool
    let options: [SongFieldOption]

    var id: String { key }

    static func fromConfig(_ config: FrontendAppConfig?) -> [SongFieldDefinition] {
        let genres = config?.genres.map { SongFieldOption(key: $0.key.asString, label: $0.label) } ?? []
        let toneKeys = config?.tonekeys.map { SongFieldOption(key: $0.key.asString, label: $0.label) } ?? []
        let statuses = config?.songStatuses.map { SongFieldOption(key: $0.key.asString, label: $0.label) } ?? []

        return [
            SongFieldDefinition(key: "title", label: "Titel", type: .text, required: true, options: []),
            SongFieldDefinition(key: "interpret", label: "Interpret", type: .text, required: true, options: []),
            SongFieldDefinition(key: "genre", label: "Genre", type: .option, required: true, options: genres),
            SongFieldDefinition(key: "singer_lead", label: "Sänger", type: .singerList, required: false, options: []),
            SongFieldDefinition(key: "singer_background", label: "Background Gesang", type: .singerList, required: false, options: []),
            SongFieldDefinition(key: "composer", label: "Komponist", type: .text, required: false, options: []),
            SongFieldDefinition(key: "texter", label: "Texter", type: .text, required: false, options: []),
            SongFieldDefinition(key: "publisher", label: "Publisher", type: .text, required: false, options: []),
            SongFieldDefinition(key: "arrangement", label: "Arrangement", type: .text, required: false, options: []),
            SongFieldDefinition(key: "tone_key", label: "Tonart", type: .option, required: false, options: toneKeys),
            SongFieldDefinition(key: "status", label: "Status", type: .option, required: true, options: statuses),
            SongFieldDefinition(key: "comment", label: "Setlistenkommentar", type: .text, required: false, options: []),
            SongFieldDefinition(key: "ytlink", label: "Youtube", type: .text, required: false, options: []),
            SongFieldDefinition(key: "duration", label: "Dauer", type: .time, required: false, options: []),
            SongFieldDefinition(
                key: "brass",
                label: "Bläser",
                type: .option,
                required: false,
                options: [
                    SongFieldOption(key: "0", label: "Nein"),
                    SongFieldOption(key: "1", label: "Ja")
                ]
            ),
            SongFieldDefinition(key: "text", label: "Text", type: .text, required: false, options: [])
        ]
    }
}

struct SongUpdateRequest: Encodable {
    let id: Int
    let title: String
    let interpret: String
    let genre: String
    let singer_background: String?
    let singer_lead: String?
    let composer: String?
    let texter: String?
    let publisher: String?
    let arrangement: String?
    let tone_key: String?
    let status: String
    let comment: String?
    let ytlink: String?
    let brass: Int?
    let text: String?
    let duration: String?

    enum CodingKeys: String, CodingKey {
        case id, title, interpret, genre, singer_background, singer_lead
        case composer, texter, publisher, arrangement, tone_key, status
        case comment, ytlink, brass, text, duration
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(interpret, forKey: .interpret)
        try c.encode(genre, forKey: .genre)
        try c.encode(status, forKey: .status)

        try c.encodeIfPresent(singer_background, forKey: .singer_background)
        try c.encodeIfPresent(singer_lead, forKey: .singer_lead)
        try c.encodeIfPresent(composer, forKey: .composer)
        try c.encodeIfPresent(texter, forKey: .texter)
        try c.encodeIfPresent(publisher, forKey: .publisher)
        try c.encodeIfPresent(arrangement, forKey: .arrangement)
        try c.encodeIfPresent(tone_key, forKey: .tone_key)
        try c.encodeIfPresent(comment, forKey: .comment)
        try c.encodeIfPresent(ytlink, forKey: .ytlink)
        try c.encodeIfPresent(brass, forKey: .brass)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(duration, forKey: .duration)
    }
}

struct SongDetailsDraft {
    var title: String = ""
    var interpret: String = ""
    var genre: String = ""
    var singer_background: [String] = []
    var singer_lead: [String] = []
    var composer: String = ""
    var texter: String = ""
    var publisher: String = ""
    var arrangement: String = ""
    var tone_key: String = ""
    var status: String = ""
    var comment: String = ""
    var ytlink: String = ""
    var text: String = ""
    var brassText: String = ""
    var duration: String = ""

    enum ValidationError: LocalizedError {
        case missingField(String)
        case invalidBrass

        var errorDescription: String? {
            switch self {
            case .missingField(let field):
                return "Pflichtfeld fehlt: \(field)"
            case .invalidBrass:
                return "Blasinstrument muss eine Zahl sein."
            }
        }
    }

    init() {}

    init(song: SongInSetOut) {
        title = song.title
        interpret = song.interpret ?? ""
        genre = song.genre ?? ""
        singer_background = Self.parseSingers(song.singer_background)
        singer_lead = Self.parseSingers(song.singer_lead)
        composer = song.composer ?? ""
        texter = song.texter ?? ""
        publisher = song.publisher ?? ""
        arrangement = song.arrangement ?? ""
        tone_key = song.tone_key ?? ""
        status = song.status ?? ""
        comment = song.comment ?? ""
        ytlink = song.ytlink ?? ""
        text = song.text ?? ""
        brassText = song.brass.map(String.init) ?? ""
        duration = song.duration ?? ""
    }

    func value(for key: String) -> String {
        switch key {
        case "title": return title
        case "interpret": return interpret
        case "genre": return genre
        case "singer_lead": return Self.joinSingers(singer_lead)
        case "singer_background": return Self.joinSingers(singer_background)
        case "composer": return composer
        case "texter": return texter
        case "publisher": return publisher
        case "arrangement": return arrangement
        case "tone_key": return tone_key
        case "status": return status
        case "comment": return comment
        case "ytlink": return ytlink
        case "duration": return duration
        case "brass": return brassText
        case "text": return text
        default: return ""
        }
    }

    mutating func setValue(_ value: String, for key: String) {
        switch key {
        case "title": title = value
        case "interpret": interpret = value
        case "genre": genre = value
        case "singer_lead": singer_lead = Self.parseSingers(value)
        case "singer_background": singer_background = Self.parseSingers(value)
        case "composer": composer = value
        case "texter": texter = value
        case "publisher": publisher = value
        case "arrangement": arrangement = value
        case "tone_key": tone_key = value
        case "status": status = value
        case "comment": comment = value
        case "ytlink": ytlink = value
        case "duration": duration = value
        case "brass": brassText = value
        case "text": text = value
        default: break
        }
    }

    func singers(for key: String) -> [String] {
        switch key {
        case "singer_lead": return singer_lead
        case "singer_background": return singer_background
        default: return []
        }
    }

    mutating func setSingers(_ values: [String], for key: String) {
        let normalized = Self.normalizeSingers(values)
        switch key {
        case "singer_lead": singer_lead = normalized
        case "singer_background": singer_background = normalized
        default: break
        }
    }

    func toUpdateRequest(id: Int) throws -> SongUpdateRequest {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInterpret = interpret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGenre = genre.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty { throw ValidationError.missingField("Titel") }
        if trimmedInterpret.isEmpty { throw ValidationError.missingField("Interpret") }
        if trimmedGenre.isEmpty { throw ValidationError.missingField("Genre") }
        if trimmedStatus.isEmpty { throw ValidationError.missingField("Status") }

        let trimmedBrass = brassText.trimmingCharacters(in: .whitespacesAndNewlines)
        let brass: Int?
        if trimmedBrass.isEmpty {
            brass = nil
        } else if let value = Int(trimmedBrass) {
            brass = value
        } else {
            throw ValidationError.invalidBrass
        }

        func nilIfEmpty(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        func nilIfEmptySingers(_ values: [String]) -> String? {
            let joined = Self.joinSingers(values)
            return joined.isEmpty ? nil : joined
        }

        return SongUpdateRequest(
            id: id,
            title: trimmedTitle,
            interpret: trimmedInterpret,
            genre: trimmedGenre,
            singer_background: nilIfEmptySingers(singer_background),
            singer_lead: nilIfEmptySingers(singer_lead),
            composer: nilIfEmpty(composer),
            texter: nilIfEmpty(texter),
            publisher: nilIfEmpty(publisher),
            arrangement: nilIfEmpty(arrangement),
            tone_key: nilIfEmpty(tone_key),
            status: trimmedStatus,
            comment: nilIfEmpty(comment),
            ytlink: nilIfEmpty(ytlink),
            brass: brass,
            text: nilIfEmpty(text),
            duration: nilIfEmpty(duration)
        )
    }

    private static func parseSingers(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        return normalizeSingers(raw.components(separatedBy: "+"))
    }

    private static func joinSingers(_ values: [String]) -> String {
        normalizeSingers(values).joined(separator: " + ")
    }

    private static func normalizeSingers(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let dedupKey = trimmed.lowercased()
            guard seen.insert(dedupKey).inserted else { continue }
            normalized.append(trimmed)
        }

        return normalized
    }
}

