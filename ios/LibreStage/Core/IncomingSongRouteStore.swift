// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct AddSongPrefillRequest: Equatable {
    let id = UUID()
    let title: String
    let interpret: String
}

private enum AddSongHandoverConfig {
    static let appGroupID = "group.de.librestage.app"
    static let sharedPayloadKey = "add_song_handover_payload_v1"
}

private struct SharedAddSongPayload: Codable {
    let title: String
    let interpret: String
    let createdAt: TimeInterval
}

@Observable
final class IncomingSongRouteStore {
    var pendingAddSongPrefill: AddSongPrefillRequest?

    func handleIncomingURL(_ url: URL) {
        guard isAddSongURL(url) else { return }

        if let shared = consumeSharedHandoverIfAvailable() {
            pendingAddSongPrefill = shared
            return
        }

        if let request = parseAddSongRequest(from: url) {
            pendingAddSongPrefill = request
            return
        }

        // Fallback: open dialog without prefilled metadata.
        pendingAddSongPrefill = AddSongPrefillRequest(title: "", interpret: "")
    }

    func importSharedHandoverIfAvailable() {
        guard let shared = consumeSharedHandoverIfAvailable() else { return }
        pendingAddSongPrefill = shared
    }

    private func parseAddSongRequest(from url: URL) -> AddSongPrefillRequest? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let items = components.queryItems ?? []

        let title = value(forAnyOf: ["title", "song", "track"], in: items)
        let interpret = value(forAnyOf: ["interpret", "artist", "singer"], in: items)

        return AddSongPrefillRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            interpret: interpret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func isAddSongURL(_ url: URL) -> Bool {
        let lowerScheme = (url.scheme ?? "").lowercased()
        let lowerHost = (url.host ?? "").lowercased()
        let lowerPath = url.path.lowercased()

        let schemeAllowed = lowerScheme == "librestage-calle-2j4quq2xrg"
            || lowerScheme == "librestage"
            || lowerScheme == "libre-stage"
        let addSongHint = lowerHost.contains("add-song")
            || lowerHost.contains("addsong")
            || lowerPath.contains("add-song")
            || lowerPath.contains("addsong")
            || lowerPath.contains("new-song")
            || lowerPath.contains("song/new")

        return schemeAllowed && addSongHint
    }

    private func value(forAnyOf keys: [String], in items: [URLQueryItem]) -> String {
        for key in keys {
            if let value = items.first(where: { $0.name.caseInsensitiveCompare(key) == .orderedSame })?.value,
               !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func consumeSharedHandoverIfAvailable() -> AddSongPrefillRequest? {
        guard let defaults = UserDefaults(suiteName: AddSongHandoverConfig.appGroupID),
              let data = defaults.data(forKey: AddSongHandoverConfig.sharedPayloadKey),
              let payload = try? JSONDecoder().decode(SharedAddSongPayload.self, from: data) else {
            return nil
        }

        defaults.removeObject(forKey: AddSongHandoverConfig.sharedPayloadKey)

        let now = Date().timeIntervalSince1970
        guard abs(now - payload.createdAt) <= 120 else { return nil }

        return AddSongPrefillRequest(
            title: payload.title.trimmingCharacters(in: .whitespacesAndNewlines),
            interpret: payload.interpret.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

