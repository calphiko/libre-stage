// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct SongsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = SongsViewModel()
    @State private var selectedSongForDetails: SongsDetailSheetItem?
    @State private var showCandidatesSheet = false
    @State private var showCreateSongSheet = false
    @State private var createSongPrefill: AddSongPrefillRequest?
    private var externalAddSongPrefill: Binding<AddSongPrefillRequest?>

    init(externalAddSongPrefill: Binding<AddSongPrefillRequest?> = .constant(nil)) {
        self.externalAddSongPrefill = externalAddSongPrefill
    }

    var body: some View {
        contentView
            .navigationTitle("Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Songs")
                            .font(.headline)
                            .foregroundStyle(AppTheme.onShellPrimary(for: colorScheme))
                    }
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
            .sheet(item: $selectedSongForDetails) { item in
                NavigationStack {
                    SongDetailsView(songId: item.id, initialTitle: item.title, modalPresentation: true)
                }
            }
            .sheet(isPresented: $showCandidatesSheet) {
                NavigationStack {
                    CandidatesView(modalPresentation: true)
                }
            }
            .sheet(isPresented: $showCreateSongSheet) {
                CreateSongSheet(vm: vm, initialPrefill: createSongPrefill)
            }
            .errorBanner($vm.error)
            .task {
                consumeExternalAddSongPrefillIfNeeded()
                await vm.loadSongFieldConfig()
                await vm.loadSongs()
            }
            .onChange(of: externalAddSongPrefill.wrappedValue?.id) { _, _ in
                consumeExternalAddSongPrefillIfNeeded()
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
                Section {
                    Button {
                        showCandidatesSheet = true
                    } label: {
                        Label("Song-Kandidaten bewerten", systemImage: "hand.thumbsup")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                Section("Repertoire (\(vm.filtered.count))") {
                    ForEach(vm.filtered) { song in
                        if let songId = song.id {
                            Button {
                                selectedSongForDetails = SongsDetailSheetItem(id: songId, title: song.title)
                            } label: {
                                SongRow(song: song)
                            }
                            .buttonStyle(.plain)
                        } else {
                            SongRow(song: song)
                        }
                    }
                }
            }
            .searchable(text: $vm.searchText, prompt: "Titel oder Interpret suchen")
            .refreshable { await vm.loadSongs() }
        }
    }
}

private struct CreateSongSheet: View {
    @Bindable var vm: SongsViewModel
    let initialPrefill: AddSongPrefillRequest?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SongDetailsDraft()
    @State private var isRecognizingSong = false
    @State private var recognitionResultHint = ""
    @State private var recognitionDebugHint = ""
    @State private var songRecognitionAvailable = SongRecognitionService.isRecognitionAvailable
    @State private var audioLevel: Double = 0
    @State private var recognitionTimeoutSeconds: Double = 20
    @State private var highlightedAutofillFields: Set<String> = []
    @State private var hasAppliedInitialPrefill = false

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
                    }
                }

                Section("Song") {
                    ForEach(vm.songFields) { field in
                        editorView(for: field)
                            .listRowBackground(
                                highlightedAutofillFields.contains(field.key)
                                ? Color.green.opacity(0.18)
                                : Color.clear
                            )
                            .animation(.easeInOut(duration: 0.25), value: highlightedAutofillFields)
                    }
                }

                if vm.isCreatingSong {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
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
                setDefaultValuesIfNeeded()
                applyInitialPrefillIfNeeded()
            }
            .onDisappear {
                stopRecognitionIfNeeded()
            }
        }
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

    @ViewBuilder
    private func editorView(for field: SongFieldDefinition) -> some View {
        switch field.type {
        case .singerList:
            TextField(
                field.required ? "\(field.label) * (Name + Name)" : "\(field.label) (Name + Name)",
                text: binding(for: field.key)
            )
        case .option:
            Picker(field.required ? "\(field.label) *" : field.label, selection: binding(for: field.key)) {
                if !field.required {
                    Text("-").tag("")
                }
                ForEach(field.options) { option in
                    Text(option.label).tag(option.key)
                }
            }
        case .time:
            TextField(
                field.required ? "\(field.label) * (HH:MM:SS)" : "\(field.label) (HH:MM:SS)",
                text: binding(for: field.key)
            )
            .textInputAutocapitalization(.never)
        case .date:
            TextField(
                field.required ? "\(field.label) * (YYYY-MM-DD)" : "\(field.label) (YYYY-MM-DD)",
                text: binding(for: field.key)
            )
            .textInputAutocapitalization(.never)
        case .text:
            TextField(field.required ? "\(field.label) *" : field.label, text: binding(for: field.key))
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { draft.value(for: key) },
            set: { draft.setValue($0, for: key) }
        )
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
        guard !hasAppliedInitialPrefill else { return }
        hasAppliedInitialPrefill = true
        guard let initialPrefill else { return }

        var autofilledKeys: [String] = []
        if !initialPrefill.title.isEmpty {
            draft.setValue(initialPrefill.title, for: "title")
            autofilledKeys.append("title")
        }
        if !initialPrefill.interpret.isEmpty {
            draft.setValue(initialPrefill.interpret, for: "interpret")
            autofilledKeys.append("interpret")
        }

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
            }
        }
        .padding(.vertical, 2)
    }
}

