// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct TodoInSong: Codable, Identifiable {
    var id: Int?
    var id_song: Int
    var id_reh: Int
    var id_user: Int
    var todo: String
    var dt: String?
    var done: Bool
}

struct SongInReh: Codable, Identifiable {
    var id: Int?
    var id_rehearsal: Int
    var id_song: Int
    var interpret: String
    var title: String
    var status: String
    var comment: String?
    var setlist_comment: String?
    var todo: String?
    var song_todos: [TodoInSong]
    var done: Bool
}

struct RehListElem: Codable, Identifiable {
    var id: Int
    var begin: String
    var end: String?
    var comment: String?
    var ical: String?
    var songs: [SongInReh]
}

struct RehCreateRequest: Encodable {
    let begin: String
    let end: String?
    let comment: String?
}
