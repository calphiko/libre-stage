// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct LiveModeView: View {
    let gig: GigOut
    @State private var vm = GigDetailViewModel()
    @State private var currentSongId: Int? = nil
    @State private var showInsertSheet = false
    @State private var showHelp = false
    @State private var insertSearchQuery = ""
    @State private var selectedInsertSongId: Int? = nil
    @Environment(AuthManager.self) private var authManager

    private var canWrite: Bool {
        authManager.userRole == .admin || authManager.userRole == .editor
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.liveMode == nil {
                SkeletonList()
            } else if vm.liveMode != nil {
                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let currentSong {
                                Label("Aktuell: \(currentSong.title)", systemImage: "record.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Song \(currentSongPosition)/\(orderedSongs.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Kein aktueller Song gewählt")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if !orderedSongs.isEmpty {
                            VStack(spacing: 8) {
                                if let currentSetName {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(currentSetName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text("Song \(currentSongIndexInSet)/\(currentSetSongCount)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        ProgressView(value: currentSetProgress)
                                            .tint(.purple)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Gesamtfortschritt")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("Song \(currentSongPosition)/\(orderedSongs.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: overallProgress)
                                        .tint(.accentColor)
                                }
                            }
                        }

                        if orderedSongs.isEmpty {
                            ContentUnavailableView("Keine Songs im Live-Mode", systemImage: "music.note.list")
                        } else {
                            HStack(spacing: 10) {
                                Button {
                                    if let currentSongId, let previousId = previousSongId(before: currentSongId) {
                                        self.currentSongId = previousId
                                    }
                                } label: {
                                    Label("Zurück", systemImage: "chevron.left")
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canGoPrevious)

                                Button {
                                    if let currentSongId, let nextId = nextSongId(after: currentSongId) {
                                        self.currentSongId = nextId
                                    }
                                } label: {
                                    Label("Weiter", systemImage: "chevron.right")
                                }
                                .buttonStyle(.bordered)
                                .disabled(!canGoNext)

                                Button {
                                    showHelp.toggle()
                                } label: {
                                    Label("Hilfe", systemImage: "questionmark.circle")
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                if canWrite {
                                    Button {
                                        insertSearchQuery = ""
                                        selectedInsertSongId = nil
                                        showInsertSheet = true
                                    } label: {
                                        Label("Song einschieben", systemImage: "plus.circle")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(currentSongId == nil)
                                }
                            }

                            if showHelp {
                                LiveModeHelpPanel()
                            }

                            if !canWrite {
                                Label("Nur Lesezugriff – Änderungen erfordern Editor-Rechte", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Live-Liste")
                                    .font(.headline)

                                ForEach(Array(windowedSongs.enumerated()), id: \.element.id) { index, song in
                                    VStack(spacing: 8) {
                                        LiveModeJumpRow(
                                            song: song,
                                            isCurrent: song.id == currentSongId,
                                            canWrite: canWrite,
                                            showTopConnector: index > 0,
                                            showBottomConnector: index < windowedSongs.count - 1,
                                            onJump: {
                                                Task {
                                                    if canWrite {
                                                        let ok = await vm.jumpToSong(
                                                            currentSongId: currentSongId,
                                                            targetSongId: song.id,
                                                            gigId: gig.id
                                                        )
                                                        if ok {
                                                            currentSongId = resolveCurrentSongId(preferredId: song.id)
                                                        }
                                                    } else {
                                                        currentSongId = resolveCurrentSongId(preferredId: song.id)
                                                    }
                                                }
                                            }
                                        )

                                        if song.id == currentSongId {
                                            LiveModeSongCard(
                                                song: song,
                                                canWrite: canWrite,
                                                previousSong: previousSong,
                                                nextSong: nextSong,
                                                onFeedback: { rating in
                                                    Task {
                                                        let newFeedback = (song.feedback == rating) ? nil : rating
                                                        let update = SongInSetLMUpdate(
                                                            id: song.id,
                                                            feedback: newFeedback,
                                                            includeFeedback: true
                                                        )
                                                        await vm.updateSong(update, gigId: gig.id)
                                                        if newFeedback == nil {
                                                            currentSongId = resolveCurrentSongId(preferredId: song.id)
                                                        } else {
                                                            currentSongId = resolveCurrentSongId(preferredId: nextSongId(after: song.id) ?? song.id)
                                                        }
                                                    }
                                                },
                                                onSkip: {
                                                    Task {
                                                        let newSkip = !(song.uebersprungen ?? false)
                                                        let update = SongInSetLMUpdate(
                                                            id: song.id,
                                                            uebersprungen: newSkip,
                                                            feedback: newSkip ? nil : song.feedback,
                                                            includeUebersprungen: true,
                                                            includeFeedback: newSkip
                                                        )
                                                        await vm.updateSong(update, gigId: gig.id)
                                                        if newSkip {
                                                            currentSongId = resolveCurrentSongId(preferredId: nextSongId(after: song.id) ?? song.id)
                                                        } else {
                                                            currentSongId = resolveCurrentSongId(preferredId: song.id)
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .refreshable {
                    await vm.loadLiveMode(gigId: gig.id)
                    currentSongId = resolveCurrentSongId(preferredId: currentSongId)
                }
            } else {
                ContentUnavailableView("Kein Live-Modus", systemImage: "bolt.slash")
            }
        }
        .navigationTitle("Live: \(gig.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .errorBanner($vm.error)
        .task {
            await vm.loadLiveMode(gigId: gig.id)
            await vm.loadSongs()
            currentSongId = resolveCurrentSongId(preferredId: currentSongId)
        }
        .onChange(of: orderedSongs.map(\.id)) { _, _ in
            currentSongId = resolveCurrentSongId(preferredId: currentSongId)
        }
        .sheet(isPresented: $showInsertSheet) {
            NavigationStack {
                List {
                    ForEach(Array(vm.filteredSongsForInsert(query: insertSearchQuery).enumerated()), id: \.offset) { _, song in
                        if let songId = song.id {
                            Button {
                                selectedInsertSongId = songId
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title ?? "Ohne Titel")
                                            .foregroundStyle(.primary)
                                        Text(song.interpret ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedInsertSongId == songId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                .searchable(text: $insertSearchQuery, prompt: "Song suchen")
                .navigationTitle("Song einschieben")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showInsertSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Einfügen") {
                            Task {
                                guard let selectedInsertSongId else { return }
                                guard let afterId = currentSongId ?? orderedSongs.last?.id else { return }
                                let inserted = await vm.insertSong(afterSetSongId: afterId, songId: selectedInsertSongId, gigId: gig.id)
                                currentSongId = resolveCurrentSongId(preferredId: inserted?.id)
                                showInsertSheet = false
                            }
                        }
                        .disabled(selectedInsertSongId == nil)
                    }
                }
            }
        }
    }

    private var orderedSongs: [SongInSetLM] {
        vm.orderedLiveSongs()
    }

    private var currentSong: SongInSetLM? {
        guard let currentSongId else { return nil }
        return orderedSongs.first(where: { $0.id == currentSongId })
    }

    private var windowedSongs: [SongInSetLM] {
        guard let currentSongId,
              let currentIndex = orderedSongs.firstIndex(where: { $0.id == currentSongId }) else {
            return orderedSongs
        }
        let startIndex = max(0, currentIndex - 1)
        return Array(orderedSongs[startIndex...])
    }

    private var currentSongPosition: Int {
        guard let currentSongId,
              let idx = orderedSongs.firstIndex(where: { $0.id == currentSongId }) else {
            return 0
        }
        return idx + 1
    }

    private var canGoPrevious: Bool {
        guard let currentSongId else { return false }
        return previousSongId(before: currentSongId) != nil
    }

    private var canGoNext: Bool {
        guard let currentSongId else { return false }
        return nextSongId(after: currentSongId) != nil
    }

    private func previousSongId(before songId: Int) -> Int? {
        guard let currentIndex = orderedSongs.firstIndex(where: { $0.id == songId }) else { return nil }
        let previousIndex = currentIndex - 1
        guard orderedSongs.indices.contains(previousIndex) else { return nil }
        return orderedSongs[previousIndex].id
    }

    private func nextSongId(after songId: Int) -> Int? {
        guard let currentIndex = orderedSongs.firstIndex(where: { $0.id == songId }) else { return nil }
        let nextIndex = currentIndex + 1
        guard orderedSongs.indices.contains(nextIndex) else { return nil }
        return orderedSongs[nextIndex].id
    }

    private func resolveCurrentSongId(preferredId: Int?) -> Int? {
        let ids = Set(orderedSongs.map(\.id))
        if let preferredId, ids.contains(preferredId) {
            return preferredId
        }
        if let firstOpen = vm.firstUnmarkedSongId(), ids.contains(firstOpen) {
            return firstOpen
        }
        return orderedSongs.first?.id
    }
}

private struct LiveModeSongCard: View {
    let song: SongInSetLM
    let canWrite: Bool
    let previousSong: SongInSetLM?
    let nextSong: SongInSetLM?
    let onFeedback: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let previousSong {
                HStack(spacing: 8) {
                    Text("VORHER")
                        .font(.caption2).bold()
                        .foregroundStyle(.secondary)
                    Text(previousSong.title)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(song.position).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(song.title)
                            .font(.title3).bold()
                            .strikethrough(song.uebersprungen ?? false)
                            .foregroundStyle((song.uebersprungen ?? false) ? .secondary : .primary)
                    }
                    Text(song.interpret)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if song.eingeschoben ?? false {
                    Text("Eingeschoben")
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                }
                if song.uebersprungen ?? false {
                    Text("Übersprungen")
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if let comment = song.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            HStack(spacing: 12) {
                Button {
                    onSkip()
                } label: {
                    Label(
                        (song.uebersprungen ?? false) ? "Rückgängig" : "Überspringen",
                        systemImage: (song.uebersprungen ?? false) ? "arrow.uturn.backward" : "forward.fill"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(!canWrite)

                Spacer()

                Text("Bewertung:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach([(1, "😐"), (2, "🙂"), (3, "😍")], id: \.0) { rating, emoji in
                    Button {
                        onFeedback(rating)
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .padding(6)
                            .background(song.feedback == rating ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canWrite)
                }
            }

            if let nextSong {
                HStack(spacing: 8) {
                    Text("ALS NÄCHSTES")
                        .font(.caption2).bold()
                        .foregroundStyle(.secondary)
                    Text(nextSong.title)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension LiveModeView {
    private var previousSong: SongInSetLM? {
        guard let currentSongId,
              let prevId = previousSongId(before: currentSongId) else { return nil }
        return orderedSongs.first(where: { $0.id == prevId })
    }

    private var nextSong: SongInSetLM? {
        guard let currentSongId,
              let nextId = nextSongId(after: currentSongId) else { return nil }
        return orderedSongs.first(where: { $0.id == nextId })
    }

    private var overallProgress: Double {
        guard !orderedSongs.isEmpty else { return 0 }
        return Double(currentSongPosition) / Double(orderedSongs.count)
    }

    private var currentSetName: String? {
        guard let currentSongId,
              let set = vm.liveMode?.sets.first(where: { set in
                  set.songs.contains(where: { $0.id == currentSongId })
              }) else { return nil }
        return set.setlist_name ?? "Set \(set.position)"
    }

    private var currentSetSongCount: Int {
        guard let currentSongId,
              let set = vm.liveMode?.sets.first(where: { set in
                  set.songs.contains(where: { $0.id == currentSongId })
              }) else { return 0 }
        return set.songs.count
    }

    private var currentSongIndexInSet: Int {
        guard let currentSongId,
              let set = vm.liveMode?.sets.first(where: { set in
                  set.songs.contains(where: { $0.id == currentSongId })
              }),
              let idx = set.songs.firstIndex(where: { $0.id == currentSongId }) else { return 0 }
        return idx + 1
    }

    private var currentSetProgress: Double {
        guard currentSetSongCount > 0 else { return 0 }
        return Double(currentSongIndexInSet) / Double(currentSetSongCount)
    }
}

private struct LiveModeJumpRow: View {
    let song: SongInSetLM
    let isCurrent: Bool
    let canWrite: Bool
    let showTopConnector: Bool
    let showBottomConnector: Bool
    let onJump: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(showTopConnector ? Color.secondary.opacity(0.4) : Color.clear)
                    .frame(width: 2, height: 10)
                Circle()
                    .fill(isCurrent ? .red : Color.secondary.opacity(0.55))
                    .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                Rectangle()
                    .fill(showBottomConnector ? Color.secondary.opacity(0.4) : Color.clear)
                    .frame(width: 2, height: 10)
            }
            .frame(width: 12)

            Text("\(song.position).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .lineLimit(1)
                    .foregroundStyle((song.uebersprungen ?? false) ? .secondary : .primary)
                    .strikethrough(song.uebersprungen ?? false)
                Text(song.interpret)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if canWrite {
                Button("Springen") { onJump() }
                    .buttonStyle(.bordered)
                    .font(.caption)
            } else {
                Button("Anzeigen") { onJump() }
                    .buttonStyle(.bordered)
                    .font(.caption)
            }
        }
        .padding(8)
        .background(isCurrent ? Color.red.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LiveModeHelpPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live-Mode Anleitung")
                .font(.headline)

            Text("Navigation: Mit Zurück/Weiter oder per Springen-Button in der Setliste.")
                .font(.caption)
            Text("Bewertung: 😐 / 🙂 / 😍 antippen. Nochmal tippen entfernt die Bewertung.")
                .font(.caption)
            Text("Überspringen: Markiert den Song als nicht gespielt.")
                .font(.caption)
            Text("Song einschieben: Fügt spontan einen Song nach dem aktuellen ein.")
                .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

