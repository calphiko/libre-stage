// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers

struct SetlistEditorSheet: View {
    let gigId: Int
    let gigName: String
    let onSaved: ((GigSetlistOut) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var vm = SetlistEditorViewModel()
    @State private var draft: EditableSetlist?
    @State private var songSearch = ""
    @State private var selectedSetIndex = 0
    @State private var statusFilter = ""
    @State private var singerFilter = ""
    @State private var pendingAutoSave: Task<Void, Never>?
    @State private var setlistPollingTask: Task<Void, Never>?
    @State private var dirtySetNameIndices: Set<Int> = []
    @State private var dirtyPauseIndices: Set<Int> = []
    @State private var activeDropTarget: DropTarget?
    @State private var showExternalUpdateAlert = false
    @FocusState private var focusedSetNameIndex: Int?
    @FocusState private var focusedPauseIndex: Int?

    private var availableStatuses: [String] {
        Array(Set(vm.songs.compactMap { $0.status?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted()
    }

    private var availableSingers: [String] {
        Array(Set(vm.songs.compactMap { $0.singer_lead_short?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted()
    }

    private var filteredSongs: [SongOut] {
        let query = songSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return vm.songs.filter { song in
            let matchesQuery = query.isEmpty
                || (song.title ?? "").lowercased().contains(query)
                || (song.interpret ?? "").lowercased().contains(query)
            let matchesStatus = statusFilter.isEmpty || (song.status ?? "") == statusFilter
            let matchesSinger = singerFilter.isEmpty || (song.singer_lead_short ?? "") == singerFilter
            return matchesQuery && matchesStatus && matchesSinger
        }
    }

    private var duplicateSongIds: Set<Int> {
        guard let draft else { return [] }
        var counts: [Int: Int] = [:]
        for set in draft.sets {
            for song in set.songs {
                counts[song.songId, default: 0] += 1
            }
        }
        return Set(counts.compactMap { key, count in count > 1 ? key : nil })
    }

    private var totalTimingSummary: String? {
        let timing = totalTimingComponents()
        let setSeconds = timing.sets
        let pauseSeconds = timing.pauses
        let total = timing.total
        guard total > 0 else { return nil }

        var summary = "Sets: \(formatDuration(seconds: setSeconds))"
        if pauseSeconds > 0 {
            summary += " + Pausen: \(formatDuration(seconds: pauseSeconds))"
        }
        summary += " = \(formatDuration(seconds: total))"
        return summary
    }

    private var extrapolatedEndSummary: String? {
        guard let draft else { return nil }
        let total = totalTimingComponents().total
        guard total > 0 else { return nil }
        return extrapolatedSetlistEndTime(begin: draft.begin, additionalSeconds: total)
    }

    private var plannedEndDeltaSummary: (value: String, isReached: Bool)? {
        guard let draft else { return nil }
        guard let planned = plannedGigDurationSeconds(begin: draft.begin, end: draft.end) else { return nil }

        let actual = totalTimingComponents().total
        let diff = actual - planned
        let prefix = diff >= 0 ? "+" : "-"
        let value = "\(prefix)\(formatDuration(seconds: abs(diff)))"
        return (value, diff >= 0)
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Lade Setlist...")
                } else if draft != nil {
                    GeometryReader { geo in
                        let leftWidth = max(260.0, min(380.0, geo.size.width * 0.34))
                        Group {
                            if horizontalSizeClass == .compact {
                                VStack(spacing: 12) {
                                    songsPanel(width: geo.size.width - 24)
                                        .frame(maxHeight: 280)
                                    setsPanel
                                }
                            } else {
                                HStack(spacing: 12) {
                                    songsPanel(width: leftWidth)
                                    setsPanel
                                }
                            }
                        }
                        .padding(12)
                    }
                } else {
                    ContentUnavailableView(
                        "Setlisten-Editor nicht verfuegbar",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Die Setliste konnte nicht geladen werden.")
                    )
                }
            }
            .navigationTitle("Setliste: \(gigName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zurueck") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSaving {
                        ProgressView()
                    } else {
                        Text("Auto-Save")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                guard draft == nil else { return }
                if let loaded = await vm.load(gigId: gigId) {
                    draft = EditableSetlist(from: loaded)
                }
                startSetlistPolling()
            }
            .onDisappear {
                pendingAutoSave?.cancel()
                pendingAutoSave = nil
                setlistPollingTask?.cancel()
                setlistPollingTask = nil
            }
        }
        .errorBanner($vm.error)
        .alert("Setliste aktualisiert", isPresented: $showExternalUpdateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die Setliste wurde zwischenzeitlich von einer anderen Sitzung geaendert und neu geladen.")
        }
    }

    @ViewBuilder
    private func songsPanel(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alle Songs")
                .font(.headline)

            TextField("Song suchen...", text: $songSearch)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if let first = filteredSongs.first {
                        addSong(first)
                    }
                }

            HStack(spacing: 8) {
                Picker("Status", selection: $statusFilter) {
                    Text("Status: Alle").tag("")
                    ForEach(availableStatuses, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }

                Picker("Lead", selection: $singerFilter) {
                    Text("Lead: Alle").tag("")
                    ForEach(availableSingers, id: \.self) { singer in
                        Text(singer).tag(singer)
                    }
                }
            }
            .pickerStyle(.menu)

            Divider()

            List(Array(filteredSongs.enumerated()), id: \.offset) { _, song in
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title ?? "Ohne Titel")
                            .font(.subheadline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let singer = song.singer_lead_short, !singer.isEmpty {
                                Text(singer)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(singerColor(for: singer).opacity(0.25))
                                    .clipShape(Capsule())
                            }
                            if let status = song.status, !status.isEmpty {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        if let interpret = song.interpret, !interpret.isEmpty {
                            Text(interpret)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("In ausgewaehltes Set") {
                            addSong(song)
                        }
                        if let draft {
                            Divider()
                            ForEach(addTargets) { target in
                                Button(target.name) {
                                    addSong(song, toSet: target.index)
                                }
                            }
                            .disabled(draft.sets.isEmpty)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .disabled(draft?.sets.isEmpty == true)
                }
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onDrag {
                    let payload = dragPayloadForLibrarySong(song)
                    return NSItemProvider(object: payload as NSString)
                } preview: {
                    dragPreview(title: song.title ?? "Ohne Titel", subtitle: song.interpret)
                }
            }
            .listStyle(.plain)
        }
        .frame(width: width)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var setsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sets")
                    .font(.headline)
                Spacer()
                Button {
                    mutateDraft { $0.addSet() }
                } label: {
                    Label("Set", systemImage: "plus")
                }
            }

            if let draft, !draft.sets.isEmpty {
                Picker("Ziel-Set", selection: $selectedSetIndex) {
                    ForEach(Array(draft.sets.enumerated()), id: \.offset) { idx, set in
                        Text(set.displayName(index: idx)).tag(idx)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedSetIndex) { oldIndex, _ in
                    saveSetNameIfNeeded(index: oldIndex)
                    savePauseIfNeeded(index: oldIndex)
                }
            }

            ScrollView {
                VStack(spacing: 12) {
                    if let draft {
                        ForEach(Array(draft.sets.enumerated()), id: \.offset) { setIdx, _ in
                            setCard(setIndex: setIdx)
                        }
                    }
                }
                .padding(.bottom, 6)
            }

            if let totalTimingSummary {
                LabeledContent("Zeitkalkulation", value: totalTimingSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let extrapolatedEndSummary {
                LabeledContent("Hochgerechnetes Ende", value: extrapolatedEndSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let plannedEndDeltaSummary {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Differenz zu geplantem Ende")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(plannedEndDeltaSummary.value)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(plannedEndDeltaSummary.isReached ? .green : .red)
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func setCard(setIndex: Int) -> some View {
        if let set = draft?.sets[safe: setIndex] {
            VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(
                    "Set-Name",
                    text: Binding(
                        get: { draft?.sets[safe: setIndex]?.setlistName ?? "" },
                        set: { newValue in
                            guard let currentDraft = draft, currentDraft.sets.indices.contains(setIndex) else { return }
                            draft?.sets[setIndex].setlistName = newValue
                            dirtySetNameIndices.insert(setIndex)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedSetNameIndex, equals: setIndex)
                .onChange(of: focusedSetNameIndex) { oldIndex, _ in
                    if let oldIndex {
                        saveSetNameIfNeeded(index: oldIndex)
                    }
                }

                Button {
                    draft?.moveSet(from: setIndex, to: setIndex - 1)
                    normalizeSelectedSetIndex()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .disabled(setIndex == 0)

                Button {
                    draft?.moveSet(from: setIndex, to: setIndex + 1)
                    normalizeSelectedSetIndex()
                } label: {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .disabled(setIndex >= (draft?.sets.count ?? 0) - 1)

                Button(role: .destructive) {
                    draft?.removeSet(at: setIndex)
                    normalizeSelectedSetIndex()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled((draft?.sets.count ?? 0) <= 1)
            }

            HStack(spacing: 10) {
                Text("Pause")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "HH:MM",
                    text: Binding(
                        get: { draft?.sets[safe: setIndex]?.pauseText ?? "" },
                        set: { newValue in
                            guard let currentDraft = draft, currentDraft.sets.indices.contains(setIndex) else { return }
                            draft?.sets[setIndex].pauseText = normalizedPauseEditorText(newValue)
                            dirtyPauseIndices.insert(setIndex)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .keyboardType(.numbersAndPunctuation)
                .focused($focusedPauseIndex, equals: setIndex)
                .onSubmit {
                    savePauseIfNeeded(index: setIndex)
                }
                .onChange(of: focusedPauseIndex) { oldIndex, _ in
                    if let oldIndex {
                        savePauseIfNeeded(index: oldIndex)
                    }
                }
            }

            if let timingSummary = setTimingSummary(for: setIndex) {
                LabeledContent("Zeitkalkulation", value: timingSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Array(set.songs.enumerated()), id: \.offset) { songIdx, song in
                    HStack(spacing: 8) {
                        Text("\(songIdx + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(song.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if duplicateSongIds.contains(song.songId) {
                                    Text("!")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.red.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            if let interpret = song.interpret, !interpret.isEmpty {
                                Text(interpret)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            mutateDraft {
                                $0.moveSongInSet(setIndex: setIndex, from: songIdx, to: songIdx - 1)
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .disabled(songIdx == 0)

                        Button {
                            mutateDraft {
                                $0.moveSongInSet(setIndex: setIndex, from: songIdx, to: songIdx + 1)
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .disabled(songIdx >= set.songs.count - 1)

                        Button(role: .destructive) {
                            mutateDraft {
                                $0.removeSong(setIndex: setIndex, songIndex: songIdx)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)

                        Menu {
                            ForEach(songMoveTargets(excluding: setIndex)) { target in
                                Button(target.name) {
                                    mutateDraft {
                                        $0.moveSongAcrossSets(fromSet: setIndex, songIndex: songIdx, toSet: target.index)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.right.arrow.left.circle")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .disabled((draft?.sets.count ?? 0) <= 1)
                    }
                    .padding(.vertical, 1)
                    .contentShape(Rectangle())
                    .onDrag {
                        NSItemProvider(object: dragPayloadForSetSong(setIndex: setIndex, songIndex: songIdx, songId: song.songId) as NSString)
                    } preview: {
                        dragPreview(title: song.title, subtitle: song.interpret)
                    }
                    .onDrop(of: SetSongDropDelegate.supportedTypeIdentifiers, delegate: SetSongDropDelegate(
                        targetSetIndex: setIndex,
                        targetSongIndex: songIdx,
                        onEntered: {
                            activeDropTarget = DropTarget(setIndex: setIndex, songIndex: songIdx)
                        },
                        onExited: {
                            if activeDropTarget == DropTarget(setIndex: setIndex, songIndex: songIdx) {
                                activeDropTarget = nil
                            }
                        },
                        onCompleted: {
                            activeDropTarget = nil
                        },
                        onPayload: { payload, destinationSetIndex, destinationSongIndex in
                            handleDroppedPayload(payload, toSetIndex: destinationSetIndex, toSongIndex: destinationSongIndex)
                        }
                    ))
                    .overlay {
                        if activeDropTarget == DropTarget(setIndex: setIndex, songIndex: songIdx) {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }
                }

                if set.songs.isEmpty {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.08))
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Songs hierher ziehen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                        .onDrop(of: SetSongDropDelegate.supportedTypeIdentifiers, delegate: SetSongDropDelegate(
                            targetSetIndex: setIndex,
                            targetSongIndex: 0,
                            onEntered: {
                                activeDropTarget = DropTarget(setIndex: setIndex, songIndex: 0)
                            },
                            onExited: {
                                if activeDropTarget == DropTarget(setIndex: setIndex, songIndex: 0) {
                                    activeDropTarget = nil
                                }
                            },
                            onCompleted: {
                                activeDropTarget = nil
                            },
                            onPayload: { payload, destinationSetIndex, destinationSongIndex in
                                handleDroppedPayload(payload, toSetIndex: destinationSetIndex, toSongIndex: destinationSongIndex)
                            }
                        ))
                } else {
                    endDropZone(setIndex: setIndex, songCount: set.songs.count)
                }
            }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedSetIndex == setIndex ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .onTapGesture {
                focusedSetNameIndex = nil
                focusedPauseIndex = nil
                selectedSetIndex = setIndex
            }
        } else {
            EmptyView()
        }
    }

    private func addSong(_ song: SongOut) {
        addSong(song, toSet: nil)
    }

    private func addSong(_ song: SongOut, toSet setIndex: Int?) {
        guard let songId = song.id else { return }
        mutateDraft { working in
            if let setIndex {
                selectedSetIndex = setIndex
            }
            normalizeSelectedSetIndex()
            working.addSong(
                songId: songId,
                title: song.title ?? "Ohne Titel",
                duration: song.duration,
                singerLead: song.singer_lead,
                singerBackground: song.singer_background,
                interpret: song.interpret,
                genre: song.genre,
                toneKey: song.tone_key,
                ytlink: song.ytlink,
                comment: song.comment,
                brass: song.brass,
                status: song.status,
                toSetIndex: selectedSetIndex
            )
        }
    }

    private func normalizeSelectedSetIndex() {
        let count = draft?.sets.count ?? 0
        if count == 0 {
            selectedSetIndex = 0
            return
        }
        selectedSetIndex = min(max(selectedSetIndex, 0), count - 1)
    }

    private func singerColor(for singer: String) -> Color {
        let palette: [Color] = [
            .blue, .purple, .green, .orange, .pink, .teal, .indigo, .mint
        ]
        let index = abs(singer.lowercased().hashValue) % palette.count
        return palette[index]
    }

    private func songMoveTargets(excluding setIndex: Int) -> [SongMoveTarget] {
        guard let draft else { return [] }
        return draft.sets.enumerated().compactMap { index, set in
            guard index != setIndex else { return nil }
            return SongMoveTarget(index: index, name: set.displayName(index: index))
        }
    }

    private var addTargets: [SongMoveTarget] {
        guard let draft else { return [] }
        return draft.sets.enumerated().map { index, set in
            SongMoveTarget(index: index, name: set.displayName(index: index))
        }
    }

    private func dragPayloadForLibrarySong(_ song: SongOut) -> String {
        "library|\(song.id ?? -1)"
    }

    private func dragPayloadForSetSong(setIndex: Int, songIndex: Int, songId: Int) -> String {
        "set|\(setIndex)|\(songIndex)|\(songId)"
    }

    @ViewBuilder
    private func dragPreview(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 180, maxWidth: 260, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func setTimingSummary(for setIndex: Int) -> String? {
        guard let draft, draft.sets.indices.contains(setIndex) else { return nil }
        let set = draft.sets[setIndex]

        let setSeconds = set.songs.reduce(0) { partial, song in
            partial + (parseSongDurationToSeconds(song.duration) ?? 0)
        }

        let pauseSeconds: Int
        if setIndex < draft.sets.count - 1 {
            pauseSeconds = parsePauseToSeconds(set.pauseText) ?? 0
        } else {
            pauseSeconds = 0
        }

        let total = setSeconds + pauseSeconds
        guard total > 0 else { return nil }

        var summary = "Set: \(formatDuration(seconds: setSeconds))"
        if pauseSeconds > 0 {
            summary += " + Pause: \(formatDuration(seconds: pauseSeconds))"
        }
        summary += " = \(formatDuration(seconds: total))"
        return summary
    }

    private func totalTimingComponents() -> (sets: Int, pauses: Int, total: Int) {
        guard let draft else { return (0, 0, 0) }

        var setSeconds = 0
        var pauseSeconds = 0

        for (setIndex, set) in draft.sets.enumerated() {
            setSeconds += set.songs.reduce(0) { partial, song in
                partial + (parseSongDurationToSeconds(song.duration) ?? 0)
            }

            if setIndex < draft.sets.count - 1 {
                pauseSeconds += parsePauseToSeconds(set.pauseText) ?? 0
            }
        }

        return (setSeconds, pauseSeconds, setSeconds + pauseSeconds)
    }

    private func extrapolatedSetlistEndTime(begin: String?, additionalSeconds: Int) -> String? {
        guard let startSeconds = parseClockTimeToSeconds(begin) else { return nil }
        let absolute = startSeconds + additionalSeconds
        let daySeconds = 24 * 3600
        let dayOffset = absolute / daySeconds
        let timeOfDay = absolute % daySeconds

        let hours = timeOfDay / 3600
        let minutes = (timeOfDay % 3600) / 60
        let base = String(format: "%02d:%02d", hours, minutes)

        if dayOffset > 0 {
            return "\(base) (+\(dayOffset))"
        }
        return base
    }

    private func plannedGigDurationSeconds(begin: String?, end: String?) -> Int? {
        guard let beginSeconds = parseClockTimeToSeconds(begin),
              let endSeconds = parseClockTimeToSeconds(end) else {
            return nil
        }

        if endSeconds < beginSeconds {
            return (24 * 3600 - beginSeconds) + endSeconds
        }
        return endSeconds - beginSeconds
    }

    private func parseClockTimeToSeconds(_ value: String?) -> Int? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let parts = raw.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        let hour = numbers[0]
        let minute = numbers[1]
        let second = numbers.count == 3 ? numbers[2] : 0
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            return nil
        }

        return hour * 3600 + minute * 60 + second
    }

    private func parseSongDurationToSeconds(_ value: String?) -> Int? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let parts = raw.split(separator: ":").map(String.init)
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        switch numbers.count {
        case 2:
            let minutes = numbers[0]
            let seconds = numbers[1]
            guard minutes >= 0, (0...59).contains(seconds) else { return nil }
            return minutes * 60 + seconds
        case 3:
            let hours = numbers[0]
            let minutes = numbers[1]
            let seconds = numbers[2]
            guard hours >= 0, (0...59).contains(minutes), (0...59).contains(seconds) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return nil
        }
    }

    private func parsePauseToSeconds(_ value: String?) -> Int? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let parts = raw.split(separator: ":").map(String.init)
        let numbers = parts.compactMap(Int.init)
        guard numbers.count == parts.count else { return nil }

        switch numbers.count {
        case 2:
            let hours = numbers[0]
            let minutes = numbers[1]
            guard hours >= 0, (0...59).contains(minutes) else { return nil }
            return hours * 3600 + minutes * 60
        case 3:
            let hours = numbers[0]
            let minutes = numbers[1]
            let seconds = numbers[2]
            guard hours >= 0, (0...59).contains(minutes), (0...59).contains(seconds) else { return nil }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return nil
        }
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func mutateDraft(_ mutation: (inout EditableSetlist) -> Void) {
        guard var working = draft else { return }
        mutation(&working)
        draft = working
        normalizeSelectedSetIndex()
        scheduleAutoSave()
    }

    private func scheduleAutoSave() {
        pendingAutoSave?.cancel()
        pendingAutoSave = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await autoSaveDraft()
        }
    }

    private func saveSetNameIfNeeded(index: Int) {
        guard dirtySetNameIndices.contains(index) else { return }
        dirtySetNameIndices.remove(index)
        scheduleAutoSave()
    }

    private func savePauseIfNeeded(index: Int) {
        guard dirtyPauseIndices.contains(index) else { return }
        guard let currentDraft = draft, currentDraft.sets.indices.contains(index) else { return }
        let normalized = normalizedPauseEditorText(currentDraft.sets[index].pauseText)
        draft?.sets[index].pauseText = normalized
        dirtyPauseIndices.remove(index)
        scheduleAutoSave()
    }

    private func normalizedPauseEditorText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let digits = trimmed.filter(\.isNumber)
        if digits.count <= 2 {
            return digits
        }

        let hh = String(digits.prefix(2))
        let mm = String(digits.dropFirst(2).prefix(2))
        return mm.isEmpty ? hh : "\(hh):\(mm)"
    }

    @ViewBuilder
    private func endDropZone(setIndex: Int, songCount: Int) -> some View {
        let target = DropTarget(setIndex: setIndex, songIndex: songCount)
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.06))
            .overlay {
                Text("Am Ende ablegen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .overlay {
                if activeDropTarget == target {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
            .onDrop(of: SetSongDropDelegate.supportedTypeIdentifiers, delegate: SetSongDropDelegate(
                targetSetIndex: setIndex,
                targetSongIndex: songCount,
                onEntered: {
                    activeDropTarget = target
                },
                onExited: {
                    if activeDropTarget == target {
                        activeDropTarget = nil
                    }
                },
                onCompleted: {
                    activeDropTarget = nil
                },
                onPayload: { payload, destinationSetIndex, destinationSongIndex in
                    handleDroppedPayload(payload, toSetIndex: destinationSetIndex, toSongIndex: destinationSongIndex)
                }
            ))
    }

    @MainActor
    private func autoSaveDraft() async {
        guard let draft else { return }
        if let updated = await vm.save(gigId: gigId, draft: draft) {
            self.draft = EditableSetlist(from: updated)
            onSaved?(updated)
            normalizeSelectedSetIndex()
            return
        }

        if let conflict = vm.conflictSetlist {
            self.draft = EditableSetlist(from: conflict)
            onSaved?(conflict)
            normalizeSelectedSetIndex()
            showExternalUpdateAlert = true
        }
    }

    private func startSetlistPolling() {
        guard setlistPollingTask == nil else { return }

        setlistPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await checkForExternalSetlistUpdate()
            }
        }
    }

    @MainActor
    private func checkForExternalSetlistUpdate() async {
        guard !vm.isSaving, let currentDraft = draft else { return }
        guard let latest = await vm.fetchSetlist(gigId: gigId) else { return }

        let currentVersion = normalizedSetlistVersion(currentDraft.setlistVersion)
        let latestVersion = normalizedSetlistVersion(latest.setlist_version)
        guard let currentVersion, let latestVersion, currentVersion != latestVersion else { return }

        draft = EditableSetlist(from: latest)
        normalizeSelectedSetIndex()
        showExternalUpdateAlert = true
        onSaved?(latest)
    }

    private func normalizedSetlistVersion(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    @MainActor
    private func handleDroppedPayload(_ payload: String, toSetIndex destinationSetIndex: Int, toSongIndex destinationSongIndex: Int) -> Bool {
        if payload.hasPrefix("library|") {
            let parts = payload.split(separator: "|")
            guard parts.count == 2,
                  let songId = Int(parts[1]),
                  let song = vm.songs.first(where: { $0.id == songId })
            else {
                return false
            }

            mutateDraft { working in
                working.insertSong(
                    songId: songId,
                    title: song.title ?? "Ohne Titel",
                    duration: song.duration,
                    singerLead: song.singer_lead,
                    singerBackground: song.singer_background,
                    interpret: song.interpret,
                    genre: song.genre,
                    toneKey: song.tone_key,
                    ytlink: song.ytlink,
                    comment: song.comment,
                    brass: song.brass,
                    status: song.status,
                    toSetIndex: destinationSetIndex,
                    at: destinationSongIndex
                )
                selectedSetIndex = destinationSetIndex
            }
            return true
        }

        if payload.hasPrefix("set|") {
            let parts = payload.split(separator: "|")
            guard parts.count >= 4,
                  let sourceSet = Int(parts[1]),
                  let sourceSong = Int(parts[2])
            else {
                return false
            }

            mutateDraft { working in
                working.moveSong(fromSet: sourceSet, songIndex: sourceSong, toSet: destinationSetIndex, toSongIndex: destinationSongIndex)
                selectedSetIndex = destinationSetIndex
            }
            return true
        }

        return false
    }
}

@Observable
private final class SetlistEditorViewModel {
    var songs: [SongOut] = []
    var isLoading = false
    var isSaving = false
    var error: AppError?
    var conflictSetlist: GigSetlistOut?

    @MainActor
    func load(gigId: Int) async -> GigSetlistOut? {
        isLoading = true
        defer { isLoading = false }

        do {
            async let setlistTask: GigSetlistOut = APIClient.shared.get(path: "/gigs/\(gigId)/setlist")
            async let songsTask: [SongOut] = APIClient.shared.get(path: "/songs/")
            let (setlist, loadedSongs) = try await (setlistTask, songsTask)
            songs = loadedSongs.sorted { ($0.title ?? "") < ($1.title ?? "") }
            return setlist
        } catch let e as AppError {
            error = e
        } catch let e {
            error = .networkError(e)
        }

        return nil
    }

    @MainActor
    func save(gigId: Int, draft: EditableSetlist) async -> GigSetlistOut? {
        isSaving = true
        defer { isSaving = false }
        conflictSetlist = nil

        do {
            let body = GigSetlistUpdateIn(draft: draft)
            let updated: GigSetlistOut = try await APIClient.shared.put(path: "/gigs/\(gigId)/update_setlist/", body: body)
            return updated
        } catch let e as AppError {
            if case .serverError(let statusCode, _) = e, statusCode == 409 {
                if let latest = await fetchSetlist(gigId: gigId) {
                    conflictSetlist = latest
                }
                error = .serverError(statusCode: statusCode, detail: "Setliste wurde zwischenzeitlich geaendert. Bitte Aktion erneut ausfuehren.")
                return nil
            }
            error = e
        } catch let e {
            error = .networkError(e)
        }

        return nil
    }

    @MainActor
    func fetchSetlist(gigId: Int) async -> GigSetlistOut? {
        do {
            let setlist: GigSetlistOut = try await APIClient.shared.get(path: "/gigs/\(gigId)/setlist")
            return setlist
        } catch {
            return nil
        }
    }
}

private struct EditableSetlist {
    var id: Int
    var name: String
    var datum: String?
    var organizer: String?
    var kindOfGig: String?
    var venue: String?
    var doors: String?
    var begin: String?
    var end: String?
    var status: String?
    var publish: String?
    var setlistVersion: String?
    var sets: [EditableSet]

    init(from source: GigSetlistOut) {
        id = source.id
        name = source.name
        datum = source.datum
        organizer = source.organizer
        kindOfGig = source.kind_of_gig
        venue = source.venue
        doors = source.doors
        begin = source.begin
        end = source.end
        status = source.status
        publish = source.publish
        setlistVersion = source.setlist_version
        sets = source.sets.map { EditableSet(from: $0) }
        if sets.isEmpty {
            sets = [EditableSet.empty]
        }
    }

    mutating func addSet() {
        sets.append(.empty)
    }

    mutating func removeSet(at index: Int) {
        guard sets.indices.contains(index), sets.count > 1 else { return }
        sets.remove(at: index)
    }

    mutating func moveSet(from source: Int, to target: Int) {
        guard sets.indices.contains(source),
              sets.indices.contains(target),
              source != target
        else {
            return
        }

        let set = sets.remove(at: source)
        sets.insert(set, at: target)
    }

    mutating func addSong(
        songId: Int,
        title: String,
        duration: String?,
        singerLead: String?,
        singerBackground: String?,
        interpret: String?,
        genre: String?,
        toneKey: String?,
        ytlink: String?,
        comment: String?,
        brass: Int?,
        status: String?,
        toSetIndex setIndex: Int
    ) {
        guard sets.indices.contains(setIndex) else { return }
        sets[setIndex].songs.append(
            EditableSong(
                id: songId,
                songId: songId,
                title: title,
                duration: duration,
                singerLead: singerLead,
                singerBackground: singerBackground,
                interpret: interpret,
                genre: genre,
                toneKey: toneKey,
                ytlink: ytlink,
                comment: comment,
                brass: brass,
                status: status,
                position: nil,
                setsongId: nil
            )
        )
    }

    mutating func insertSong(
        songId: Int,
        title: String,
        duration: String?,
        singerLead: String?,
        singerBackground: String?,
        interpret: String?,
        genre: String?,
        toneKey: String?,
        ytlink: String?,
        comment: String?,
        brass: Int?,
        status: String?,
        toSetIndex setIndex: Int,
        at targetIndex: Int
    ) {
        guard sets.indices.contains(setIndex) else { return }
        let song = EditableSong(
            id: songId,
            songId: songId,
            title: title,
            duration: duration,
            singerLead: singerLead,
            singerBackground: singerBackground,
            interpret: interpret,
            genre: genre,
            toneKey: toneKey,
            ytlink: ytlink,
            comment: comment,
            brass: brass,
            status: status,
            position: nil,
            setsongId: nil
        )
        let safeTarget = min(max(targetIndex, 0), sets[setIndex].songs.count)
        sets[setIndex].songs.insert(song, at: safeTarget)
    }

    mutating func removeSong(setIndex: Int, songIndex: Int) {
        guard sets.indices.contains(setIndex), sets[setIndex].songs.indices.contains(songIndex) else { return }
        sets[setIndex].songs.remove(at: songIndex)
    }

    mutating func moveSongInSet(setIndex: Int, from source: Int, to target: Int) {
        guard sets.indices.contains(setIndex),
              sets[setIndex].songs.indices.contains(source),
              sets[setIndex].songs.indices.contains(target),
              source != target
        else {
            return
        }

        let song = sets[setIndex].songs.remove(at: source)
        sets[setIndex].songs.insert(song, at: target)
    }

    mutating func moveSongAcrossSets(fromSet sourceSet: Int, songIndex: Int, toSet targetSet: Int) {
        guard sets.indices.contains(sourceSet),
              sets.indices.contains(targetSet),
              sets[sourceSet].songs.indices.contains(songIndex),
              sourceSet != targetSet
        else {
            return
        }

        let song = sets[sourceSet].songs.remove(at: songIndex)
        sets[targetSet].songs.append(song)
    }

    mutating func moveSong(fromSet sourceSet: Int, songIndex sourceSongIndex: Int, toSet targetSet: Int, toSongIndex rawTargetIndex: Int) {
        guard sets.indices.contains(sourceSet),
              sets.indices.contains(targetSet),
              sets[sourceSet].songs.indices.contains(sourceSongIndex)
        else {
            return
        }

        let song = sets[sourceSet].songs.remove(at: sourceSongIndex)
        var targetIndex = rawTargetIndex
        if sourceSet == targetSet && sourceSongIndex < rawTargetIndex {
            targetIndex -= 1
        }
        let safeTarget = min(max(targetIndex, 0), sets[targetSet].songs.count)
        sets[targetSet].songs.insert(song, at: safeTarget)
    }
}

private struct EditableSet {
    var id: Int?
    var gigsetId: Int?
    var position: Int?
    var setId: Int?
    var setName: String
    var setlistName: String
    var pauseText: String
    var songs: [EditableSong]

    static let empty = EditableSet(id: nil, gigsetId: nil, position: nil, setId: nil, setName: "", setlistName: "", pauseText: "00:10", songs: [])

    init(from source: SetInGigOut) {
        id = source.id
        gigsetId = source.gigset_id
        position = source.position
        setId = source.set_id
        setName = source.set_name ?? ""
        setlistName = source.setlist_name ?? ""
        pauseText = PauseFormat.toEditor(source.pause)
        songs = source.songs.map(EditableSong.init)
    }

    init(id: Int?, gigsetId: Int?, position: Int?, setId: Int?, setName: String, setlistName: String, pauseText: String, songs: [EditableSong]) {
        self.id = id
        self.gigsetId = gigsetId
        self.position = position
        self.setId = setId
        self.setName = setName
        self.setlistName = setlistName
        self.pauseText = pauseText
        self.songs = songs
    }

    func displayName(index: Int) -> String {
        if !setlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return setlistName
        }
        if !setName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return setName
        }
        return "Set \(index + 1)"
    }
}

private struct EditableSong {
    var id: Int
    var songId: Int
    var title: String
    var duration: String?
    var singerLead: String?
    var singerBackground: String?
    var interpret: String?
    var genre: String?
    var toneKey: String?
    var ytlink: String?
    var comment: String?
    var brass: Int?
    var status: String?
    var position: Int?
    var setsongId: Int?

    init(
        id: Int,
        songId: Int,
        title: String,
        duration: String?,
        singerLead: String?,
        singerBackground: String?,
        interpret: String?,
        genre: String?,
        toneKey: String?,
        ytlink: String?,
        comment: String?,
        brass: Int?,
        status: String?,
        position: Int?,
        setsongId: Int?
    ) {
        self.id = id
        self.songId = songId
        self.title = title
        self.duration = duration
        self.singerLead = singerLead
        self.singerBackground = singerBackground
        self.interpret = interpret
        self.genre = genre
        self.toneKey = toneKey
        self.ytlink = ytlink
        self.comment = comment
        self.brass = brass
        self.status = status
        self.position = position
        self.setsongId = setsongId
    }

    init(from source: SongInSetOut) {
        id = source.id
        songId = source.song_id
        title = source.title
        duration = source.duration
        singerLead = source.singer_lead
        singerBackground = source.singer_background
        interpret = source.interpret
        genre = source.genre
        toneKey = source.tone_key
        ytlink = source.ytlink
        comment = source.comment
        brass = source.brass
        status = source.status
        position = source.position
        setsongId = source.setsong_id
    }
}

private struct SongMoveTarget: Identifiable {
    let index: Int
    let name: String

    var id: Int { index }
}

private struct DropTarget: Equatable {
    let setIndex: Int
    let songIndex: Int
}

private struct SetSongDropDelegate: DropDelegate {
    static let supportedTypeIdentifiers = [UTType.text.identifier, UTType.plainText.identifier]

    let targetSetIndex: Int
    let targetSongIndex: Int
    let onEntered: () -> Void
    let onExited: () -> Void
    let onCompleted: () -> Void
    let onPayload: @MainActor (_ payload: String, _ destinationSetIndex: Int, _ destinationSongIndex: Int) -> Bool

    func dropEntered(info: DropInfo) {
        onEntered()
    }

    func dropExited(info: DropInfo) {
        onExited()
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text.identifier])
            || info.hasItemsConforming(to: [UTType.plainText.identifier])
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: Self.supportedTypeIdentifiers)
        guard let provider = providers.first else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let payload = item as? String else { return }
            Task { @MainActor in
                _ = onPayload(payload, targetSetIndex, targetSongIndex)
                onCompleted()
            }
        }

        return true
    }
}

private struct GigSetlistUpdateIn: Encodable {
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
    let setlist_version: String?
    let sets: [SetInGigUpdateIn]

    init(draft: EditableSetlist) {
        id = draft.id
        name = draft.name
        datum = draft.datum
        organizer = draft.organizer
        kind_of_gig = draft.kindOfGig
        venue = draft.venue
        doors = draft.doors
        begin = draft.begin
        end = draft.end
        status = draft.status
        publish = draft.publish
        setlist_version = draft.setlistVersion
        sets = draft.sets.map(SetInGigUpdateIn.init)
    }
}

private struct SetInGigUpdateIn: Encodable {
    let id: Int?
    let gigset_id: Int?
    let position: Int?
    let set_id: Int?
    let set_name: String?
    let pause: String?
    let setlist_name: String?
    let songs: [SongInSetUpdateIn]

    init(from source: EditableSet) {
        id = source.id
        gigset_id = source.gigsetId
        position = source.position
        set_id = source.setId
        set_name = source.setName.isEmpty ? nil : source.setName
        pause = PauseFormat.toAPI(source.pauseText)
        setlist_name = source.setlistName.isEmpty ? nil : source.setlistName
        songs = source.songs.enumerated().map { index, song in
            SongInSetUpdateIn(song: song, position: index + 1)
        }
    }
}

private struct SongInSetUpdateIn: Encodable {
    let id: Int
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
    let setsong_id: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case song_id
        case position
        case title
        case duration
        case singer_lead
        case singer_background
        case interpret
        case genre
        case tone_key
        case ytlink
        case comment
        case brass
        case status
        case setsong_id
    }

    init(song: EditableSong, position: Int) {
        self.id = song.id
        self.song_id = song.songId
        self.position = position
        self.title = song.title
        self.duration = song.duration
        self.singer_lead = song.singerLead
        self.singer_background = song.singerBackground
        self.interpret = song.interpret
        self.genre = song.genre
        self.tone_key = song.toneKey
        self.ytlink = song.ytlink
        self.comment = song.comment
        self.brass = song.brass
        self.status = song.status
        self.setsong_id = song.setsongId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(song_id, forKey: .song_id)
        try container.encode(position, forKey: .position)
        try container.encode(title, forKey: .title)

        if let duration {
            try container.encode(duration, forKey: .duration)
        } else {
            try container.encodeNil(forKey: .duration)
        }
        if let singer_lead {
            try container.encode(singer_lead, forKey: .singer_lead)
        } else {
            try container.encodeNil(forKey: .singer_lead)
        }
        if let singer_background {
            try container.encode(singer_background, forKey: .singer_background)
        } else {
            try container.encodeNil(forKey: .singer_background)
        }
        if let interpret {
            try container.encode(interpret, forKey: .interpret)
        } else {
            try container.encodeNil(forKey: .interpret)
        }

        try container.encodeIfPresent(genre, forKey: .genre)
        try container.encodeIfPresent(tone_key, forKey: .tone_key)
        try container.encodeIfPresent(ytlink, forKey: .ytlink)
        try container.encodeIfPresent(comment, forKey: .comment)

        if let brass {
            try container.encode(brass, forKey: .brass)
        } else {
            try container.encodeNil(forKey: .brass)
        }

        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(setsong_id, forKey: .setsong_id)
    }
}

private enum PauseFormat {
    static func toEditor(_ raw: String?) -> String {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "00:10"
        }
        if raw.count >= 5 {
            return String(raw.prefix(5))
        }
        return raw
    }

    static func toAPI(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw.range(of: #"^\d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return raw
        }

        if raw.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return "\(raw):00"
        }

        return raw
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
