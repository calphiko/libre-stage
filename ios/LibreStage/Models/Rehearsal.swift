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

struct TodoInSongRequest: Encodable {
    let id: Int?
    let id_song: Int
    let id_reh: Int
    let id_user: Int
    let todo: String
    let dt: String?
    let done: Bool

    enum CodingKeys: String, CodingKey {
        case id, id_song, id_reh, id_user, todo, dt, done
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(id_song, forKey: .id_song)
        try c.encode(id_reh, forKey: .id_reh)
        try c.encode(id_user, forKey: .id_user)
        try c.encode(todo, forKey: .todo)
        if let dt {
            try c.encode(dt, forKey: .dt)
        } else {
            try c.encodeNil(forKey: .dt)
        }
        try c.encode(done, forKey: .done)
    }
}

struct SongInRehRequest: Encodable {
    let id: Int?
    let id_rehearsal: Int
    let id_song: Int
    let interpret: String
    let title: String
    let status: String
    let comment: String?
    let setlist_comment: String?
    let todo: String?
    let song_todos: [TodoInSongRequest]
    let done: Bool

    enum CodingKeys: String, CodingKey {
        case id, id_rehearsal, id_song, interpret, title, status, comment, setlist_comment, todo, song_todos, done
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encode(id_rehearsal, forKey: .id_rehearsal)
        try c.encode(id_song, forKey: .id_song)
        try c.encode(interpret, forKey: .interpret)
        try c.encode(title, forKey: .title)
        try c.encode(status, forKey: .status)
        if let comment {
            try c.encode(comment, forKey: .comment)
        } else {
            try c.encodeNil(forKey: .comment)
        }
        if let setlist_comment {
            try c.encode(setlist_comment, forKey: .setlist_comment)
        } else {
            try c.encodeNil(forKey: .setlist_comment)
        }
        if let todo {
            try c.encode(todo, forKey: .todo)
        } else {
            try c.encodeNil(forKey: .todo)
        }
        try c.encode(song_todos, forKey: .song_todos)
        try c.encode(done, forKey: .done)
    }
}

struct RehUpdateRequest: Encodable {
    let id: Int
    let begin: String
    let end: String?
    let comment: String?
    let ical: String?
    let songs: [SongInRehRequest]

    init(from reh: RehListElem) {
        self.id = reh.id
        self.begin = reh.begin
        self.end = reh.end

        let trimmedComment = reh.comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.comment = trimmedComment.isEmpty ? "" : trimmedComment
        self.ical = reh.ical
        self.songs = reh.songs.map { song in
            SongInRehRequest(
                id: song.id,
                id_rehearsal: song.id_rehearsal,
                id_song: song.id_song,
                interpret: song.interpret,
                title: song.title,
                status: song.status,
                comment: song.comment,
                setlist_comment: song.setlist_comment,
                todo: song.todo,
                song_todos: song.song_todos.map { todo in
                    TodoInSongRequest(
                        id: todo.id,
                        id_song: todo.id_song,
                        id_reh: todo.id_reh,
                        id_user: todo.id_user,
                        todo: todo.todo,
                        dt: todo.dt,
                        done: todo.done
                    )
                },
                done: song.done
            )
        }
    }
}

