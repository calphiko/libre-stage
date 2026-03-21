// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct RehearsalDetailView: View {
    // Unveränderliche Referenz auf die Original-Probe (für isPast-Berechnung)
    let rehearsal: RehListElem
    let vm: RehearsalsViewModel

    // Lokale, mutierbare Kopie für die Edit-Ansicht
    @State private var localReh: RehListElem
    @State private var showSongPicker = false
    @State private var showDeleteConfirm = false
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    init(rehearsal: RehListElem, vm: RehearsalsViewModel) {
        self.rehearsal = rehearsal
        self.vm = vm
        self._localReh = State(initialValue: rehearsal)
    }

    var isPast: Bool {
        guard let d = vm.parseDate(localReh.begin) else { return false }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: d)
        comps.day = (comps.day ?? 0) + 1
        comps.hour = 23; comps.minute = 59; comps.second = 59
        return (cal.date(from: comps) ?? Date.distantPast) < Date()
    }

    var isEditor: Bool { authManager.userRole == .admin || authManager.userRole == .editor }
    var isAdmin:  Bool { authManager.userRole == .admin }

    var body: some View {
        Group {
            if isPast {
                protocolView
            } else {
                editView
            }
        }
        .navigationTitle(vm.formatRangeLabel(localReh))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPast && isAdmin {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            "Probe löschen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                Task {
                    await vm.delete(localReh)
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }

    // MARK: - Protokoll-Ansicht (vergangene Probe, read-only)

    private var protocolView: some View {
        List {
            Section("Zeitraum") {
                timeInfoRows
            }
            if let comment = localReh.comment, !comment.isEmpty {
                Section("Probenkommentar") {
                    Text(comment).foregroundStyle(.secondary)
                }
            }
            Section("Songs (\(localReh.songs.count))") {
                if localReh.songs.isEmpty {
                    Text("Keine Songs protokolliert.")
                        .foregroundStyle(.secondary).italic()
                } else {
                    ForEach(localReh.songs) { song in
                        ProtocolSongRow(song: song, users: vm.users)
                    }
                }
            }
        }
    }

    // MARK: - Edit-Ansicht (bevorstehende Probe)

    private var editView: some View {
        List {
            Section("Zeitraum") {
                timeInfoRows
            }

            Section("Probenkommentar") {
                TextField("Kommentar zur Probe …", text: Binding(
                    get: { localReh.comment ?? "" },
                    set: { localReh.comment = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3...8)
                .onSubmit { save() }
                if localReh.comment?.isEmpty == false {
                    Button("Speichern") { save() }
                        .font(.caption)
                }
            }

            Section {
                Button {
                    showSongPicker = true
                } label: {
                    Label("Song hinzufügen", systemImage: "plus.circle")
                }
            } header: {
                Text("Songs (\(localReh.songs.count))")
            }

            if !localReh.songs.isEmpty {
                Section {
                    ForEach($localReh.songs) { $song in
                        NavigationLink {
                            RehearsalSongDetailView(
                                song: $song,
                                users: vm.users,
                                statusOptions: vm.rehearsalSongStatuses,
                                onUpdate: { save() }
                            )
                        } label: {
                            EditSongRow(song: song)
                        }
                    }
                    .onDelete { indices in
                        localReh.songs.remove(atOffsets: indices)
                        save()
                    }
                }
            }
        }
        .sheet(isPresented: $showSongPicker) {
            SongPickerSheet(
                songs: vm.songs,
                alreadyAdded: localReh.songs.map { $0.id_song }
            ) { song, todo in
                addSong(song, todo: todo)
            }
        }
    }

    // MARK: - Hilfsviews

    @ViewBuilder
    private var timeInfoRows: some View {
        LabeledContent("Beginn", value: vm.formatDateTime(localReh.begin))
        if let end = localReh.end {
            LabeledContent("Ende", value: vm.formatTime(end) + " Uhr")
        }
    }

    // MARK: - Aktionen

    private func save() {
        Task { await vm.update(localReh) }
    }

    private func addSong(_ song: SongOut, todo: String) {
        guard let songId = song.id else { return }
        guard !localReh.songs.contains(where: { $0.id_song == songId }) else { return }
        let newSong = SongInReh(
            id: nil,
            id_rehearsal: localReh.id,
            id_song: songId,
            interpret: song.interpret ?? "",
            title: song.title ?? "",
            status: song.status ?? "vorschlag",
            comment: nil,
            setlist_comment: song.comment,
            todo: todo.isEmpty ? nil : todo,
            song_todos: [],
            done: false
        )
        localReh.songs.append(newSong)
        save()
    }
}

// MARK: - ProtocolSongRow

private struct ProtocolSongRow: View {
    let song: SongInReh
    let users: [UserListElem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: song.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(song.done ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(song.interpret) – \(song.title)").font(.body)
                        Spacer()
                        RehStatusBadge(status: song.status)
                    }
                    if let todo = song.todo, !todo.isEmpty {
                        Label(todo, systemImage: "exclamationmark.circle")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    if let comment = song.comment, !comment.isEmpty {
                        Text(comment).font(.caption2).foregroundStyle(.secondary)
                    }
                    ForEach(song.song_todos) { std in
                        HStack(spacing: 4) {
                            Image(systemName: std.done ? "checkmark.circle.fill" : "clock")
                                .foregroundStyle(std.done ? .green : .orange)
                                .font(.caption2)
                            let name = users.first(where: { $0.id == std.id_user })?.clear_name ?? "?"
                            Text("\(name): \(std.todo)")
                                .font(.caption2).foregroundStyle(.secondary)
                                .strikethrough(std.done)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EditSongRow

private struct EditSongRow: View {
    let song: SongInReh

    var body: some View {
        HStack {
            Image(systemName: song.done ? "checkmark.circle.fill" : "music.note")
                .foregroundStyle(song.done ? .green : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(song.interpret) – \(song.title)").font(.body)
                if let todo = song.todo, !todo.isEmpty {
                    Text(todo).font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer()
            RehStatusBadge(status: song.status)
        }
    }
}

// MARK: - RehStatusBadge

struct RehStatusBadge: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "vorschlag":  return .blue
        case "angenommen": return .cyan
        case "proben":     return .orange
        case "spielbar":   return .green
        case "retired":    return .red
        default:           return .secondary
        }
    }

    var body: some View {
        Text(status)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
