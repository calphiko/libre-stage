// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

@Observable
final class AdminConfigViewModel {
    struct EditableOption: Identifiable, Equatable {
        let id = UUID()
        var key: String
        var label: String
    }

    var genres: [EditableOption] = []
    var gigTypes: [EditableOption] = []
    var songStatuses: [EditableOption] = []
    var gigStatuses: [EditableOption] = []
    var tonekeys: [EditableOption] = []
    var rehearsalSongStatuses: [String] = []

    var updatedAtRaw: String = ""
    var isLoading = false
    var isSaving = false
    var hasLoaded = false
    var error: AppError?

    private var originalState: EditorState?

    private struct EditorState {
        let genres: [EditableOption]
        let gigTypes: [EditableOption]
        let songStatuses: [EditableOption]
        let gigStatuses: [EditableOption]
        let tonekeys: [EditableOption]
        let rehearsalSongStatuses: [String]
    }

    var updatedAtDisplay: String {
        guard !updatedAtRaw.isEmpty else { return "" }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()

        let parsed = isoWithFraction.date(from: updatedAtRaw) ?? iso.date(from: updatedAtRaw)
        guard let date = parsed else { return updatedAtRaw }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var hasChanges: Bool {
        guard let originalState else { return false }
        return originalState.genres != genres
            || originalState.gigTypes != gigTypes
            || originalState.songStatuses != songStatuses
            || originalState.gigStatuses != gigStatuses
            || originalState.tonekeys != tonekeys
            || originalState.rehearsalSongStatuses != rehearsalSongStatuses
    }

    @MainActor
    func load() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response: SoftConfigAdminResponse = try await APIClient.shared.get(path: "/admin/config/soft")
            apply(softConfig: response.data)
            updatedAtRaw = response.meta.updatedAt
            originalState = snapshot()
            error = nil
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .networkError(error)
        }
    }

    @MainActor
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let payload = buildPayload()
            let response: SoftConfigUpdateResponse = try await APIClient.shared.put(path: "/admin/config/soft", body: payload)
            apply(softConfig: response.data)
            originalState = snapshot()
            error = nil
            return true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .networkError(error)
        }

        return false
    }

    func resetToLoadedState() {
        guard let state = originalState else { return }
        genres = state.genres
        gigTypes = state.gigTypes
        songStatuses = state.songStatuses
        gigStatuses = state.gigStatuses
        tonekeys = state.tonekeys
        rehearsalSongStatuses = state.rehearsalSongStatuses
    }

    func addOption(in list: ReferenceWritableKeyPath<AdminConfigViewModel, [EditableOption]>) {
        self[keyPath: list].append(EditableOption(key: "", label: ""))
    }

    func removeOption(in list: ReferenceWritableKeyPath<AdminConfigViewModel, [EditableOption]>, at index: Int) {
        guard self[keyPath: list].indices.contains(index) else { return }
        self[keyPath: list].remove(at: index)
    }

    func addRehearsalStatus() {
        rehearsalSongStatuses.append("")
    }

    func removeRehearsalStatus(at index: Int) {
        guard rehearsalSongStatuses.indices.contains(index) else { return }
        rehearsalSongStatuses.remove(at: index)
    }

    private func snapshot() -> EditorState {
        EditorState(
            genres: genres,
            gigTypes: gigTypes,
            songStatuses: songStatuses,
            gigStatuses: gigStatuses,
            tonekeys: tonekeys,
            rehearsalSongStatuses: rehearsalSongStatuses
        )
    }

    private func apply(softConfig: SoftConfigOut) {
        genres = softConfig.genres.map { EditableOption(key: $0.key.asString, label: $0.label) }
        gigTypes = softConfig.gigTypes.map { EditableOption(key: $0.key.asString, label: $0.label) }
        songStatuses = softConfig.songStatuses.map { EditableOption(key: $0.key.asString, label: $0.label) }
        gigStatuses = softConfig.gigStatuses.map { EditableOption(key: $0.key.asString, label: $0.label) }
        tonekeys = softConfig.tonekeys.map { EditableOption(key: $0.key.asString, label: $0.label) }
        rehearsalSongStatuses = softConfig.rehearsalSongStatuses
    }

    private func buildPayload() -> SoftConfigUpdateRequest {
        SoftConfigUpdateRequest(
            genres: normalizeOptions(genres),
            gigTypes: normalizeOptions(gigTypes),
            songStatuses: normalizeOptions(songStatuses),
            gigStatuses: normalizeOptions(gigStatuses),
            tonekeys: normalizeOptions(tonekeys, allowNilKey: true),
            rehearsalSongStatuses: rehearsalSongStatuses
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func normalizeOptions(_ list: [EditableOption], allowNilKey: Bool = false) -> [SoftConfigOptionPayload] {
        list.compactMap { item in
            let trimmedKey = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedKey.isEmpty && trimmedLabel.isEmpty {
                return nil
            }

            if allowNilKey && trimmedKey.isEmpty {
                return SoftConfigOptionPayload(key: nil, label: trimmedLabel)
            }

            let key = trimmedKey.isEmpty ? trimmedLabel : trimmedKey
            let label = trimmedLabel.isEmpty ? key : trimmedLabel
            return SoftConfigOptionPayload(key: key, label: label)
        }
    }
}


