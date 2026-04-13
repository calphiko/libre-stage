// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct RehearsalSongDetailView: View {
    @Binding var song: SongInReh
    let users: [UserListElem]
    let statusOptions: [String]
    let onUpdate: () -> Void

    @State private var newTodoUserId: Int? = nil
    @State private var newTodoText = ""
    @State private var commentDraft = ""
    @State private var setlistCommentDraft = ""
    @State private var todoDraft = ""
    @State private var selectedSongForDetails: RehearsalSongDetailSheetItem?

    var body: some View {
        List {
            Section("Song") {
                Button {
                    selectedSongForDetails = RehearsalSongDetailSheetItem(id: song.id_song, title: song.title)
                } label: {
                    Label("Song-Details anzeigen", systemImage: "music.note.list")
                }
                .buttonStyle(.plain)
            }

            // MARK: - Status-Buttons
            Section("Status") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(statusOptions, id: \.self) { status in
                            Button {
                                song.status = status
                                onUpdate()
                            } label: {
                                Text(status)
                                    .font(.caption).bold()
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(
                                        song.status == status
                                            ? statusColor(status)
                                            : Color.secondary.opacity(0.12)
                                    )
                                    .foregroundStyle(
                                        song.status == status ? .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Erledigt-Toggle
            Section {
                Toggle(isOn: Binding(
                    get: { song.done },
                    set: { song.done = $0; onUpdate() }
                )) {
                    Label(
                        song.done ? "Erledigt ✔" : "Als erledigt markieren",
                        systemImage: song.done ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(song.done ? .green : .primary)
                }
                .tint(.green)
            }

            // MARK: - Felder
            Section("Felder") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Todo").font(.caption).foregroundStyle(.secondary)
                    TextField("Was gibts zu tun?", text: Binding(
                        get: { song.todo ?? "" },
                        set: { song.todo = $0.isEmpty ? nil : $0 }
                    ))
                    .onSubmit { onUpdate() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Setlist-Kommentar").font(.caption).foregroundStyle(.secondary)
                    TextField("Kommentar für die Setlist", text: Binding(
                        get: { song.setlist_comment ?? "" },
                        set: { song.setlist_comment = $0.isEmpty ? nil : $0 }
                    ))
                    .onSubmit { onUpdate() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Proben-Kommentar").font(.caption).foregroundStyle(.secondary)
                    TextField("Notizen zur Probe …", text: Binding(
                        get: { song.comment ?? "" },
                        set: { song.comment = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit { onUpdate() }
                }

                Button("Felder speichern") { onUpdate() }
                    .font(.caption)
            }

            // MARK: - Todos
            Section("Todos fürs nächste Mal") {
                if song.song_todos.isEmpty {
                    Text("Noch keine Todos.")
                        .foregroundStyle(.secondary).italic()
                        .font(.caption)
                } else {
                    ForEach(song.song_todos) { std in
                        HStack(spacing: 8) {
                            Image(
                                systemName: std.done
                                    ? "checkmark.circle.fill"
                                    : "clock"
                            )
                            .foregroundStyle(std.done ? .green : .orange)
                            .font(.body)
                            VStack(alignment: .leading, spacing: 2) {
                                let name = users.first(where: { $0.id == std.id_user })?.clear_name ?? "?"
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(std.todo)
                                    .strikethrough(std.done)
                                    .foregroundStyle(std.done ? .secondary : .primary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // MARK: - Neues Todo hinzufügen
            if !users.isEmpty {
                Section("Neues Todo") {
                    Picker("Wer?", selection: $newTodoUserId) {
                        Text("Person auswählen …").tag(nil as Int?)
                        ForEach(users) { u in
                            Text(u.clear_name).tag(u.id as Int?)
                        }
                    }

                    HStack {
                        TextField("Was soll getan werden?", text: $newTodoText)
                        Button {
                            addTodo()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(
                                    newTodoUserId != nil && !newTodoText.isEmpty
                                        ? .blue : .secondary
                                )
                        }
                        .disabled(newTodoUserId == nil || newTodoText.isEmpty)
                    }
                }
            }
        }
        .softCardContainer()
        .appShellBackground()
        .navigationTitle("\(song.interpret) – \(song.title)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSongForDetails) { item in
            NavigationStack {
                SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
            }
        }
    }

    // MARK: - Hilfsmethoden

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "vorschlag":  return .blue
        case "angenommen": return .cyan
        case "proben":     return .orange
        case "spielbar":   return .green
        case "retired":    return .red
        default:           return .gray
        }
    }

    private func addTodo() {
        guard let userId = newTodoUserId, !newTodoText.isEmpty else { return }
        let newTodo = TodoInSong(
            id: nil,
            id_song: song.id_song,
            id_reh: song.id_rehearsal,
            id_user: userId,
            todo: newTodoText,
            dt: nil,
            done: false
        )
        song.song_todos.append(newTodo)
        onUpdate()
        newTodoUserId = nil
        newTodoText = ""
    }
}

private struct RehearsalSongDetailSheetItem: Identifiable {
    let id: Int
    let title: String?
}

