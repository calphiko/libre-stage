// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// MARK: - Datenmodell (spiegelt ShareDebugPayload aus der Extension)

private struct ShareDebugPayload: Codable {
    let timestamp: TimeInterval
    let itemTitle: String?
    let itemBody: String?
    let texts: [String]
    let urlString: String?
    let typeIdentifiersPerProvider: [[String]]
    let resolvedTitle: String?
    let resolvedArtist: String?
}

private enum ShareDebugConfig {
    static let appGroupID    = "group.de.librestage.app"
    static let debugKey      = "share_debug_payload_v1"
}

// MARK: - View

struct ShareDebugView: View {
    let modalPresentation: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var payload: ShareDebugPayload?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if let p = payload {
                    debugContent(p)
                } else {
                    ContentUnavailableView(
                        "Kein Debug-Dump vorhanden",
                        systemImage: "ladybug",
                        description: Text("Teile zuerst einen Song aus Shazam, Apple Music, Spotify oder TIDAL, dann erscheint hier der rohe Payload.")
                    )
                }
            }
            .appShellBackground()
            .navigationTitle("Share-Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if modalPresentation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if payload != nil {
                            Button(role: .none) {
                                copyToClipboard()
                            } label: {
                                Label("Kopieren", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                clearDebugDump()
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear { loadPayload() }
    }

    @ViewBuilder
    private func debugContent(_ p: ShareDebugPayload) -> some View {
        List {
            Section("Zeitstempel") {
                Text(Date(timeIntervalSince1970: p.timestamp).formatted(date: .complete, time: .complete))
                    .font(.caption.monospacedDigit())
            }

            Section("NSExtensionItem-Metadaten") {
                row(label: "attributedTitle",       value: p.itemTitle)
                row(label: "attributedContentText", value: p.itemBody)
            }

            Section("Aufgeloeste Songdaten") {
                row(label: "resolvedTitle",  value: p.resolvedTitle)
                row(label: "resolvedArtist", value: p.resolvedArtist)
            }

            Section("Text-Anhaenge (\(p.texts.count))") {
                if p.texts.isEmpty {
                    Text("(keine)").foregroundStyle(.secondary).italic()
                } else {
                    ForEach(Array(p.texts.enumerated()), id: \.offset) { idx, text in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("[\(idx)]").font(.caption2.bold()).foregroundStyle(.secondary)
                            Text(text).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                }
            }

            Section("URL") {
                if let url = p.urlString {
                    Text(url).font(.caption.monospaced()).textSelection(.enabled)
                } else {
                    Text("(keine)").foregroundStyle(.secondary).italic()
                }
            }

            Section("UTI-Typen je Provider (\(p.typeIdentifiersPerProvider.count))") {
                ForEach(Array(p.typeIdentifiersPerProvider.enumerated()), id: \.offset) { pIdx, types in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Provider \(pIdx)").font(.caption2.bold()).foregroundStyle(.secondary)
                        ForEach(types, id: \.self) { uti in
                            Text("• \(uti)").font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if copied {
                Section {
                    Label("In Zwischenablage kopiert", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .softCardContainer()
    }

    @ViewBuilder
    private func row(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
            if let v = value {
                Text(v).font(.caption.monospaced()).textSelection(.enabled)
            } else {
                Text("nil").font(.caption.monospaced().italic()).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Aktionen

    private func loadPayload() {
        guard
            let defaults = UserDefaults(suiteName: ShareDebugConfig.appGroupID),
            let data = defaults.data(forKey: ShareDebugConfig.debugKey),
            let decoded = try? JSONDecoder().decode(ShareDebugPayload.self, from: data)
        else {
            payload = nil
            return
        }
        payload = decoded
    }

    private func copyToClipboard() {
        guard let p = payload else { return }
        var lines: [String] = [
            "=== Share-Debug-Dump ===",
            "Zeit: \(Date(timeIntervalSince1970: p.timestamp).formatted())",
            "",
            "attributedTitle:       \(p.itemTitle ?? "nil")",
            "attributedContentText: \(p.itemBody ?? "nil")",
            "resolvedTitle:         \(p.resolvedTitle ?? "nil")",
            "resolvedArtist:        \(p.resolvedArtist ?? "nil")",
            "",
            "Text-Anhaenge (\(p.texts.count)):",
        ]
        p.texts.enumerated().forEach { lines.append("  [\($0.offset)] \($0.element)") }
        lines += ["", "URL: \(p.urlString ?? "nil")", "", "UTI-Typen je Provider:"]
        p.typeIdentifiersPerProvider.enumerated().forEach { pIdx, types in
            lines.append("  Provider \(pIdx):")
            types.forEach { lines.append("    • \($0)") }
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func clearDebugDump() {
        UserDefaults(suiteName: ShareDebugConfig.appGroupID)?
            .removeObject(forKey: ShareDebugConfig.debugKey)
        payload = nil
    }
}

