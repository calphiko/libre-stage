// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct SongsView: View {
    let onMenuTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = SongsViewModel()
    @State private var selectedSongForDetails: SongsDetailSheetItem?
    @State private var showCandidatesSheet = false
    @State private var showCreateSongSheet = false
    @State private var createSongPrefill: AddSongPrefillRequest?
    private var externalAddSongPrefill: Binding<AddSongPrefillRequest?>

    init(
        externalAddSongPrefill: Binding<AddSongPrefillRequest?> = .constant(nil),
        onMenuTap: (() -> Void)? = nil
    ) {
        self.externalAddSongPrefill = externalAddSongPrefill
        self.onMenuTap = onMenuTap
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NavigationStack {
                contentView
                .appShellBackground()
                .navigationTitle("Songs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Songs")
                            .font(.headline)
                            .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCandidatesSheet = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "hand.thumbsup")

                                if vm.openCandidateVotesCount > 0 {
                                    Text(badgeLabel(for: vm.openCandidateVotesCount))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.red, in: Capsule())
                                        .offset(x: 11, y: -8)
                                }
                            }
                        }
                        .accessibilityLabel("Song-Kandidaten bewerten")
                        .accessibilityValue(vm.openCandidateVotesCount > 0 ? "\(vm.openCandidateVotesCount) offene Abstimmungen" : "Keine offenen Abstimmungen")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            createSongPrefill = nil
                            showCreateSongSheet = true
                        } label: {
                            Label("Song hinzufuegen", systemImage: "plus")
                        }
                    }
                }
                .headerBodyBlend()
                .fullScreenCover(item: $selectedSongForDetails) { item in
                    NavigationStack {
                        SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
                    }
                }
                .fullScreenCover(isPresented: $showCandidatesSheet) {
                    NavigationStack {
                        CandidatesView(modalPresentation: true)
                    }
                }
                .fullScreenCover(isPresented: $showCreateSongSheet) {
                    AppModalContainer {
                        CreateSongSheet(vm: vm, initialPrefill: createSongPrefill)
                    }
                }
                .errorBanner($vm.error)
                .task {
                    consumeExternalAddSongPrefillIfNeeded()
                    await vm.loadSongFieldConfig()
                    await vm.loadSongs()
                    await vm.loadOpenCandidateVotesCount()
                }
                .onChange(of: externalAddSongPrefill.wrappedValue?.id) { _, _ in
                    consumeExternalAddSongPrefillIfNeeded()
                }
                .onChange(of: showCandidatesSheet) { _, isPresented in
                    guard !isPresented else { return }
                    Task {
                        await vm.loadOpenCandidateVotesCount()
                    }
                }
            }

            if let onMenuTap {
                AppMenuButton(action: onMenuTap)
                    .padding(.leading, 12)
                    .padding(.top, 0)
            }
        }
    }

    private func consumeExternalAddSongPrefillIfNeeded() {
        guard let request = externalAddSongPrefill.wrappedValue else { return }
        createSongPrefill = request
        showCreateSongSheet = true
        externalAddSongPrefill.wrappedValue = nil
    }

    @ViewBuilder
    private var contentView: some View {
        if vm.isLoading && vm.songs.isEmpty {
            SkeletonList()
        } else if vm.songs.isEmpty {
            ContentUnavailableView("Keine Songs", systemImage: "music.note")
        } else {
            List {
                if !vm.availableDanceStyles.isEmpty {
                    Section("Filter") {
                        Picker("Tanzstil", selection: $vm.selectedDanceStyleFilter) {
                            Text("Alle").tag("")
                            ForEach(vm.availableDanceStyles, id: \.self) { danceStyle in
                                Text(danceStyle).tag(danceStyle)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(AppTheme.rowBackground(for: colorScheme))
                }

                Section("Repertoire (\(vm.filtered.count))") {
                    ForEach(vm.filtered) { song in
                        songRow(for: song)
                    }
                }
                .listRowBackground(AppTheme.rowBackground(for: colorScheme))
            }
            .listStyle(.insetGrouped)
            .searchable(text: $vm.searchText, prompt: "Titel, Interpret oder Tanzstil suchen")
            .refreshable {
                await vm.loadSongs()
                await vm.loadOpenCandidateVotesCount()
            }
        }
    }

    private func badgeLabel(for count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }

    @ViewBuilder
    private func songRow(for song: SongOut) -> some View {
        if let songId = song.id {
            Button {
                selectedSongForDetails = SongsDetailSheetItem(id: songId, title: song.title)
            } label: {
                SongRow(song: song)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            SongRow(song: song)
        }
    }
}

private struct CreateSongSheet: View {
    @Bindable var vm: SongsViewModel
    let initialPrefill: AddSongPrefillRequest?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = SongDetailsDraft()
    @State private var isRecognizingSong = false
    @State private var recognitionResultHint = ""
    @State private var recognitionDebugHint = ""
    @State private var songRecognitionAvailable = SongRecognitionService.isRecognitionAvailable
    @State private var isMetadataLoading = false
    @State private var metadataResultHint = ""
    @State private var didApplyMetadataSuccessfully = false
    @State private var audioLevel: Double = 0
    @State private var recognitionTimeoutSeconds: Double = 20
    @State private var highlightedAutofillFields: Set<String> = []
    @State private var hasAppliedInitialPrefill = false
    @State private var duplicateMatch: SongOut?
    @State private var duplicateWarningPulse = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Auto-Erkennung") {
                    Button {
                        recognizeSong()
                    } label: {
                        HStack {
                            Label("Titel + Interpret automatisch erkennen", systemImage: "waveform.and.mic")
                            Spacer()
                            if isRecognizingSong {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!songRecognitionAvailable || isRecognizingSong || vm.isCreatingSong)

                    if !songRecognitionAvailable {
                        Text("Auf diesem Geraet ist die Song-Erkennung derzeit nicht verfuegbar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !recognitionResultHint.isEmpty {
                        Text(recognitionResultHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !recognitionDebugHint.isEmpty {
                        Text(recognitionDebugHint)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if isRecognizingSong {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: audioLevel, total: 1)
                                .tint(.accentColor)
                            Text(audioLevel > 0.03 ? "Mikrofon-Signal erkannt" : "Warte auf Audio-Signal...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Suche bis zu \(Int(recognitionTimeoutSeconds)) Sekunden")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) {
                            stopRecognition()
                        } label: {
                            Label("Zuhoeren beenden", systemImage: "stop.circle")
                        }
                    } else {
                        Picker("Dauer", selection: $recognitionTimeoutSeconds) {
                            Text("12s").tag(12.0)
                            Text("20s").tag(20.0)
                            Text("30s").tag(30.0)
                        }
                        .pickerStyle(.segmented)
                        .addModalFieldStyle()
                    }
                }
                .addModalSectionStyle()

                Section("Song") {
                    ForEach(vm.songFields) { field in
                        editorView(for: field)
                            .listRowBackground(
                                highlightedAutofillFields.contains(field.key)
                                ? Color.green.opacity(0.18)
                                : AppTheme.rowBackground(for: colorScheme)
                            )
                            .animation(.easeInOut(duration: 0.25), value: highlightedAutofillFields)

                        if field.key == "interpret", let duplicateMatch {
                            duplicateWarningView(for: duplicateMatch)
                                .padding(.top, 4)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .scaleEffect(duplicateWarningPulse ? 1.02 : 1.0)
                                .animation(
                                    reduceMotion
                                    ? .easeOut(duration: 0.01)
                                    : .spring(response: 0.28, dampingFraction: 0.66),
                                    value: duplicateWarningPulse
                                )
                        }

                        if field.key == "interpret", canFetchCrawlerMetadata {
                            Button {
                                fetchCrawlerMetadata()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isMetadataLoading ? "arrow.triangle.2.circlepath" : (didApplyMetadataSuccessfully ? "checkmark.circle.fill" : "wand.and.stars"))
                                        .font(.headline)
                                        .symbolEffect(.pulse, value: isMetadataLoading)
                                        .symbolEffect(.bounce, value: didApplyMetadataSuccessfully)
                                        .foregroundStyle(didApplyMetadataSuccessfully ? .green : .accent)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Metadaten automatisch laden")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text("Komponist, Texter, Dauer und YouTube-Link")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if isMetadataLoading {
                                        ProgressView()
                                    } else {
                                        Image(systemName: didApplyMetadataSuccessfully ? "sparkles" : "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(didApplyMetadataSuccessfully ? .green : .secondary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            didApplyMetadataSuccessfully ? Color.green.opacity(0.20) : Color.accentColor.opacity(0.18),
                                            didApplyMetadataSuccessfully ? Color.green.opacity(0.10) : Color.accentColor.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(didApplyMetadataSuccessfully ? Color.green.opacity(0.45) : Color.accentColor.opacity(0.35), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isMetadataLoading || vm.isCreatingSong)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98)))
                            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: canFetchCrawlerMetadata)

                            if !metadataResultHint.isEmpty {
                                Text(metadataResultHint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if field.key == "interpret", !hasFieldInConfig("composer") {
                            TextField("Komponist", text: binding(for: "composer"))
                                .addModalFieldStyle()
                                .listRowBackground(
                                    highlightedAutofillFields.contains("composer")
                                    ? Color.green.opacity(0.18)
                                    : AppTheme.rowBackground(for: colorScheme)
                                )
                                .animation(.easeInOut(duration: 0.25), value: highlightedAutofillFields)
                        }

                        if field.key == "interpret", !hasFieldInConfig("texter") {
                            TextField("Texter", text: binding(for: "texter"))
                                .addModalFieldStyle()
                                .listRowBackground(
                                    highlightedAutofillFields.contains("texter")
                                    ? Color.green.opacity(0.18)
                                    : AppTheme.rowBackground(for: colorScheme)
                                )
                                .animation(.easeInOut(duration: 0.25), value: highlightedAutofillFields)
                        }
                    }
                }
                .addModalSectionStyle()

                if vm.isCreatingSong {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    .addModalSectionStyle()
                }
            }
            .addModalFormStyle()
            .navigationTitle("Neuer Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        stopRecognitionIfNeeded()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        Task {
                            if await vm.createSong(draft: draft) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(vm.isCreatingSong)
                }
            }
            .task {
                songRecognitionAvailable = SongRecognitionService.isRecognitionAvailable
                if vm.songs.isEmpty {
                    await vm.loadSongs()
                }
                setDefaultValuesIfNeeded()
                applyInitialPrefillIfNeeded()
                checkDuplicate()
            }
            .onChange(of: initialPrefill?.id) { _, _ in
                applyInitialPrefillIfNeeded()
            }
            .onChange(of: draft.title) { _, _ in
                checkDuplicate()
            }
            .onChange(of: draft.interpret) { _, _ in
                checkDuplicate()
            }
            .onChange(of: vm.songs.count) { _, _ in
                checkDuplicate()
            }
            .onChange(of: duplicateMatchIdentity(duplicateMatch)) { _, newIdentity in
                guard newIdentity != nil else { return }
                triggerDuplicateWarningPulse()
            }
            .onDisappear {
                stopRecognitionIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func duplicateWarningView(for duplicateMatch: SongOut) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(
                "Dieser Song ist wahrscheinlich bereits vorhanden: " +
                "\(duplicateMatch.interpret ?? "-") - \(duplicateMatch.title ?? "-") " +
                "(Status: \(statusLabel(for: duplicateMatch.status))). Du kannst trotzdem speichern."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func recognizeSong() {
        Task {
            guard songRecognitionAvailable else {
                return
            }

            isRecognizingSong = true
            recognitionResultHint = "Hoere zu..."
            recognitionDebugHint = ""
            audioLevel = 0
            SongRecognitionService.shared.onAudioLevelChanged = { level in
                audioLevel = level
            }
            SongRecognitionService.shared.onStatusChanged = { status in
                recognitionDebugHint = status
            }
            defer {
                SongRecognitionService.shared.onAudioLevelChanged = nil
                SongRecognitionService.shared.onStatusChanged = nil
                audioLevel = 0
                isRecognizingSong = false
            }

            do {
                let match = try await SongRecognitionService.shared.recognizeCurrentSong(timeoutSeconds: recognitionTimeoutSeconds)
                var autofilledKeys: [String] = []

                if !match.title.isEmpty {
                    draft.setValue(match.title, for: "title")
                    autofilledKeys.append("title")
                }
                if !match.interpret.isEmpty {
                    draft.setValue(match.interpret, for: "interpret")
                    autofilledKeys.append("interpret")
                }

                checkDuplicate()

                flashAutofillHighlight(for: autofilledKeys)
                triggerAutofillHaptic(for: autofilledKeys)

                let title = match.title.isEmpty ? "(kein Titel)" : match.title
                let artist = match.interpret.isEmpty ? "(kein Interpret)" : match.interpret
                recognitionResultHint = "Erkannt und uebernommen: \(title) - \(artist)"
            } catch SongRecognitionError.cancelled {
                recognitionResultHint = "Zuhoeren beendet."
            } catch let error as SongRecognitionError {
                recognitionResultHint = recognitionHint(for: error)
            } catch {
                vm.error = .networkError(error)
                recognitionResultHint = "Erkennung fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    private var canFetchCrawlerMetadata: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !draft.interpret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func fetchCrawlerMetadata() {
        guard canFetchCrawlerMetadata else { return }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let interpret = draft.interpret.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            didApplyMetadataSuccessfully = false
            isMetadataLoading = true
            defer { isMetadataLoading = false }

            do {
                let metadata = try await vm.fetchSongCrawlerMetadata(interpret: interpret, title: title)
                var autofilledKeys: [String] = []

                if let duration = metadata.duration, !duration.isEmpty {
                    draft.setValue(duration, for: "duration")
                    autofilledKeys.append("duration")
                }
                if let composer = metadata.composer, !composer.isEmpty {
                    draft.setValue(composer, for: "composer")
                    autofilledKeys.append("composer")
                }
                if let texter = metadata.texter, !texter.isEmpty {
                    draft.setValue(texter, for: "texter")
                    autofilledKeys.append("texter")
                }
                if let ytlink = metadata.ytlink, !ytlink.isEmpty {
                    draft.setValue(ytlink, for: "ytlink")
                    autofilledKeys.append("ytlink")
                }

                flashAutofillHighlight(for: autofilledKeys)
                triggerAutofillHaptic(for: autofilledKeys)

                if autofilledKeys.isEmpty {
                    metadataResultHint = "Metadaten gefunden, aber keine uebernehmbaren Felder enthalten."
                } else {
                    metadataResultHint = "Metadaten uebernommen: \(autofilledKeys.joined(separator: ", "))"
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                        didApplyMetadataSuccessfully = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.4))
                        withAnimation(.easeOut(duration: 0.2)) {
                            didApplyMetadataSuccessfully = false
                        }
                    }
                }
            } catch let appError as AppError {
                if case .notFound = appError {
                    metadataResultHint = "Keine Metadaten gefunden."
                } else {
                    vm.error = appError
                    metadataResultHint = "Metadaten konnten nicht geladen werden."
                }
            } catch {
                vm.error = .networkError(error)
                metadataResultHint = "Metadaten konnten nicht geladen werden."
            }
        }
    }

    private func flashAutofillHighlight(for keys: [String]) {
        guard !keys.isEmpty else { return }
        let keySet = Set(keys)

        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedAutofillFields = keySet
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 0.35)) {
                highlightedAutofillFields.subtract(keySet)
            }
        }
    }

    private func triggerAutofillHaptic(for keys: [String]) {
        guard !keys.isEmpty else { return }

        if keys.contains("title") && keys.contains("interpret") {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        } else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    private func recognitionHint(for error: SongRecognitionError) -> String {
        switch error {
        case .timedOut:
            return "Kein Song erkannt (Timeout). Versuch's nochmal und halte das Geraet naeher an die Musik."
        case .invalidMatch:
            return "Song teilweise erkannt, aber ohne verwertbaren Titel/Interpret."
        case .microphonePermissionDenied:
            return "Mikrofonzugriff fehlt. Bitte in den iOS-Einstellungen freigeben."
        case .unavailable:
            return "Song-Erkennung nicht verfuegbar: Music-Recognition-Capability fehlt im Build/Provisioning-Profil."
        case .busy:
            return "Song-Erkennung laeuft bereits."
        case .cancelled:
            return "Zuhoeren beendet."
        }
    }

    private func stopRecognition() {
        SongRecognitionService.shared.stopRecognition()
    }

    private func stopRecognitionIfNeeded() {
        guard isRecognizingSong else { return }
        SongRecognitionService.shared.stopRecognition()
    }

    private func checkDuplicate() {
        let newMatch = SongsCreateDuplicateCheck.findBestSongDuplicate(candidate: draft, songs: vm.songs)?.song
        let oldIdentity = duplicateMatchIdentity(duplicateMatch)
        let newIdentity = duplicateMatchIdentity(newMatch)

        guard oldIdentity != newIdentity else { return }

        if reduceMotion {
            duplicateMatch = newMatch
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                duplicateMatch = newMatch
            }
        }
    }

    private func statusLabel(for statusKey: String?) -> String {
        guard let statusKey, !statusKey.isEmpty else { return "unbekannt" }
        let statusField = vm.songFields.first(where: { $0.key == "status" })
        return statusField?.options.first(where: { $0.key == statusKey })?.label ?? statusKey
    }

    private func duplicateMatchIdentity(_ song: SongOut?) -> String? {
        guard let song else { return nil }
        return "\(song.id.map(String.init) ?? "nil")|\(SongsCreateDuplicateCheck.normalizeSongText(song.title))|\(SongsCreateDuplicateCheck.normalizeSongText(song.interpret))"
    }

    private func triggerDuplicateWarningPulse() {
        guard !reduceMotion else { return }

        duplicateWarningPulse = false
        Task { @MainActor in
            duplicateWarningPulse = true
            try? await Task.sleep(for: .seconds(0.16))
            duplicateWarningPulse = false
        }
    }

    @ViewBuilder
    private func editorView(for field: SongFieldDefinition) -> some View {
        switch field.type {
        case .singerList:
            TextField(
                field.required ? "\(field.label) * (Name + Name)" : "\(field.label) (Name + Name)",
                text: binding(for: field.key)
            )
            .addModalFieldStyle()
        case .option:
            Picker(field.required ? "\(field.label) *" : field.label, selection: binding(for: field.key)) {
                if !field.required {
                    Text("-").tag("")
                }
                ForEach(field.options) { option in
                    Text(option.label).tag(option.key)
                }
            }
            .pickerStyle(.menu)
            .addModalFieldStyle()
        case .time:
            TextField(
                field.required ? "\(field.label) * (HH:MM:SS)" : "\(field.label) (HH:MM:SS)",
                text: binding(for: field.key)
            )
            .textInputAutocapitalization(.never)
            .addModalFieldStyle()
        case .date:
            TextField(
                field.required ? "\(field.label) * (YYYY-MM-DD)" : "\(field.label) (YYYY-MM-DD)",
                text: binding(for: field.key)
            )
            .textInputAutocapitalization(.never)
            .addModalFieldStyle()
        case .text:
            TextField(field.required ? "\(field.label) *" : field.label, text: binding(for: field.key))
                .addModalFieldStyle()
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { draft.value(for: key) },
            set: {
                draft.setValue($0, for: key)
                if key == "title" || key == "interpret" {
                    didApplyMetadataSuccessfully = false
                    metadataResultHint = ""
                    checkDuplicate()
                }
            }
        )
    }

    private func hasFieldInConfig(_ key: String) -> Bool {
        vm.songFields.contains { $0.key == key }
    }

    private func setDefaultValuesIfNeeded() {
        for field in vm.songFields where field.required && field.type == .option {
            let current = draft.value(for: field.key)
            guard current.isEmpty else { continue }

            if field.key == "status",
               let suggestion = field.options.first(where: { $0.key.lowercased() == "vorschlag" }) {
                draft.setValue(suggestion.key, for: field.key)
            } else if let first = field.options.first {
                draft.setValue(first.key, for: field.key)
            }
        }
    }

    private func applyInitialPrefillIfNeeded() {
        guard let initialPrefill else { return }
        guard !hasAppliedInitialPrefill else { return }
        hasAppliedInitialPrefill = true

        var autofilledKeys: [String] = []
        if !initialPrefill.title.isEmpty {
            draft.setValue(initialPrefill.title, for: "title")
            autofilledKeys.append("title")
        }
        if !initialPrefill.interpret.isEmpty {
            draft.setValue(initialPrefill.interpret, for: "interpret")
            autofilledKeys.append("interpret")
        }

        checkDuplicate()

        flashAutofillHighlight(for: autofilledKeys)
        triggerAutofillHaptic(for: autofilledKeys)
        if !autofilledKeys.isEmpty {
            let title = initialPrefill.title.isEmpty ? "(kein Titel)" : initialPrefill.title
            let artist = initialPrefill.interpret.isEmpty ? "(kein Interpret)" : initialPrefill.interpret
            recognitionResultHint = "Uebernommen aus Share-Link: \(title) - \(artist)"
        }
    }
}

private struct SongsDetailSheetItem: Identifiable {
    let id: Int
    let title: String?
}

private struct SongRow: View {
    let song: SongOut

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(song.title ?? "–").font(.body)
                Spacer()
                if let dur = song.duration_formatted, dur != "00:00" {
                    Text(dur)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                if let interpret = song.interpret {
                    Text(interpret).font(.caption).foregroundStyle(.secondary)
                }
                if let key = song.tone_key {
                    Text(key)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let genre = song.genre {
                    Text(genre)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let danceStyle = song.dance_styles,
                   !danceStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(danceStyle)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SongsDuplicateMatch {
    let score: Double
    let song: SongOut
}

private enum SongsCreateDuplicateCheck {
    static func findBestSongDuplicate(candidate: SongDetailsDraft, songs: [SongOut]) -> SongsDuplicateMatch? {
        let candidateTitle = normalizeSongText(candidate.title)
        let candidateInterpret = normalizeSongText(candidate.interpret)

        guard !candidateTitle.isEmpty, !candidateInterpret.isEmpty else {
            return nil
        }

        var bestMatch: SongsDuplicateMatch?

        for song in songs {
            let songTitle = normalizeSongText(song.title)
            let songInterpret = normalizeSongText(song.interpret)
            guard !songTitle.isEmpty, !songInterpret.isEmpty else {
                continue
            }

            let exact = candidateTitle == songTitle && candidateInterpret == songInterpret
            let titleScore = bestFieldScore(candidateTitle, songTitle)
            let interpretScore = bestFieldScore(candidateInterpret, songInterpret)
            let combinedScore = exact ? 1 : titleScore * 0.6 + interpretScore * 0.4

            let passesBalancedThreshold =
                exact ||
                (titleScore >= 0.84 && interpretScore >= 0.84) ||
                combinedScore >= 0.88

            guard passesBalancedThreshold else {
                continue
            }

            if bestMatch == nil || combinedScore > (bestMatch?.score ?? 0) {
                bestMatch = SongsDuplicateMatch(score: combinedScore, song: song)
            }
        }

        return bestMatch
    }

    static func normalizeSongText(_ value: String?) -> String {
        let base = (value ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))

        let alnumSeparated = base.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )

        return alnumSeparated
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func sortTokens(_ value: String) -> String {
        normalizeSongText(value)
            .split(separator: " ")
            .map(String.init)
            .sorted()
            .joined(separator: " ")
    }

    private static func similarity(_ left: String, _ right: String) -> Double {
        if left.isEmpty || right.isEmpty {
            return 0
        }
        if left == right {
            return 1
        }

        let maxLen = max(left.count, right.count)
        if maxLen == 0 {
            return 1
        }

        let distance = levenshteinDistance(left, right)
        return 1 - (Double(distance) / Double(maxLen))
    }

    private static func bestFieldScore(_ left: String, _ right: String) -> Double {
        let direct = similarity(normalizeSongText(left), normalizeSongText(right))
        let tokenSorted = similarity(sortTokens(left), sortTokens(right))
        return max(direct, tokenSorted)
    }

    private static func levenshteinDistance(_ left: String, _ right: String) -> Int {
        if left == right { return 0 }
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }

        let leftChars = Array(left)
        let rightChars = Array(right)

        var previous = Array(0...rightChars.count)
        var current = Array(repeating: 0, count: rightChars.count + 1)

        for (i, leftChar) in leftChars.enumerated() {
            current[0] = i + 1
            for (j, rightChar) in rightChars.enumerated() {
                let cost = leftChar == rightChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + cost
                )
            }
            swap(&previous, &current)
        }

        return previous[rightChars.count]
    }
}

