// libre-stage iOS Share Extension
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Konfiguration

private enum AddSongHandoverConfig {
    static let appGroupID       = "group.de.librestage.app"
    static let sharedPayloadKey = "add_song_handover_payload_v1"
    static let debugPayloadKey  = "share_debug_payload_v1"
}

// MARK: - Codable-Typen

private struct SharedAddSongPayload: Codable {
    let title: String
    let interpret: String
    let createdAt: TimeInterval
}

private struct ShareDebugPayload: Codable {
    let timestamp: TimeInterval
    let itemTitle: String?
    let itemBody: String?
    let texts: [String]
    let urlString: String?
    let typeIdentifiersPerProvider: [[String]]
}

// MARK: - ShareViewController
//
// UIViewController (nicht SLComposeServiceViewController), damit wir
// den open(url)-Aufruf vollständig selbst kontrollieren können.

final class ShareViewController: UIViewController {

    // MARK: - State

    private var resolvedMetadata: SongMetadata?

    // MARK: - UI

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 20
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "music.note.list"))
        iv.tintColor = .systemCyan
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let songLabel: UILabel = {
        let l = UILabel()
        l.text = "Lade Song-Info…"
        l.font = .preferredFont(forTextStyle: .headline)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let artistLabel: UILabel = {
        let l = UILabel()
        l.font = .preferredFont(forTextStyle: .subheadline)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let spinner = UIActivityIndicatorView(style: .medium)

    private lazy var openButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "In LibreStage öffnen"
        config.image = UIImage(systemName: "arrow.up.right.square")
        config.imagePadding = 8
        config.baseBackgroundColor = .systemCyan
        let b = UIButton(configuration: config)
        b.isEnabled = false
        b.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        return b
    }()

    private lazy var cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Abbrechen", for: .normal)
        b.tintColor = .secondaryLabel
        b.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()

        Task { @MainActor in
            let payload = await extractPayload()
            persistDebugPayload(payload)
            let metadata = resolveSongMetadata(from: payload)
            persistSharedHandover(title: metadata.title, artist: metadata.artist)
            resolvedMetadata = metadata
            applyMetadata(metadata)
        }
    }

    // MARK: - UI-Aufbau

    private func buildUI() {
        view.backgroundColor = .systemBackground

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(songLabel)
        stack.addArrangedSubview(artistLabel)
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(openButton)
        stack.addArrangedSubview(cancelButton)
        view.addSubview(stack)

        spinner.startAnimating()

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            openButton.widthAnchor.constraint(equalToConstant: 260),
        ])
    }

    private func applyMetadata(_ metadata: SongMetadata) {
        spinner.stopAnimating()
        spinner.isHidden = true
        songLabel.text   = metadata.title.isEmpty  ? "(kein Titel)"     : metadata.title
        artistLabel.text = metadata.artist.isEmpty ? "(kein Interpret)" : metadata.artist
        openButton.isEnabled = true
    }

    // MARK: - Aktionen

    /// Nutzer-initiierter Tap:
    /// 1. Lokale Benachrichtigung planen (garantierter Fokuswechsel, falls berechtigt)
    /// 2. open(url, completionHandler: nil) → öffnet LibreStage; kein Completion-Handler,
    ///    kein completeRequest – iOS übernimmt das Extension-Cleanup vollständig selbst,
    ///    sobald LibreStage im Vordergrund ist.
    @objc private func openTapped() {
        openButton.isEnabled = false
        let metadata = resolvedMetadata ?? SongMetadata(title: "", artist: "")
        guard let deepLink = makeDeepLink(title: metadata.title, artist: metadata.artist) else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        // Benachrichtigung als Fallback planen (feuert nach 1 s, falls open(url)
        // keinen Fokuswechsel auslöst).
        scheduleOpenNotificationIfPermitted(title: metadata.title, artist: metadata.artist)

        // Kein Completion-Handler, kein completeRequest –
        // iOS übernimmt Cleanup vollständig selbst sobald LibreStage vorne ist.
        // Die eigentliche Scene-Aktivierung per UIWindowScene.ActivationRequestOptions
        // erfolgt auf der Haupt-App-Seite (AppDelegate, iOS 17+).
        extensionContext?.open(deepLink, completionHandler: nil)
    }

    /// Benachrichtigung planen – nur wenn die Haupt-App bereits Berechtigung hat.
    /// Beim Antippen der Benachrichtigung bringt iOS LibreStage zuverlässig in
    /// den Vordergrund; MainTabView liest den Payload dann aus UserDefaults.
    private func scheduleOpenNotificationIfPermitted(title: String, artist: String) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Song zu LibreStage hinzufügen"
            content.body  = title.isEmpty ? "Erkannter Song hinzufügen"
                          : artist.isEmpty ? title : "\(title) – \(artist)"
            content.sound = .default
            content.userInfo = ["action": "add-song"]

            // 1 s Verzögerung: Extension-Sheet schließt sich zuerst
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "librestage-share-add-song",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Payload-Extraktion

    private func extractPayload() async -> SharedPayload {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return SharedPayload(texts: [], url: nil, itemTitle: nil, itemBody: nil, typeIdentifiersPerProvider: [])
        }
        let firstItem = items.first
        let itemTitle = firstItem?.attributedTitle?.string
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let itemBody = firstItem?.attributedContentText?.string
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        var allTexts: [String] = []
        var firstURL: URL?
        var typeIdentifiersPerProvider: [[String]] = []

        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                typeIdentifiersPerProvider.append(provider.registeredTypeIdentifiers)
                if let value = await loadString(from: provider), !value.isEmpty { allTexts.append(value) }
                if firstURL == nil, let value = await loadURL(from: provider) { firstURL = value }
            }
        }
        return SharedPayload(texts: allTexts, url: firstURL,
                             itemTitle: itemTitle, itemBody: itemBody,
                             typeIdentifiersPerProvider: typeIdentifiersPerProvider)
    }

    private func loadString(from provider: NSItemProvider) async -> String? {
        let hasPlain = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        let hasText  = provider.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        guard hasPlain || hasText else { return nil }
        let uti = hasPlain ? UTType.plainText.identifier : UTType.text.identifier
        return await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: uti, options: nil) { item, _ in
                if let s = item as? String   { cont.resume(returning: s) }
                else if let u = item as? URL { cont.resume(returning: u.absoluteString) }
                else                         { cont.resume(returning: nil) }
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }
        return await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let u = item as? URL               { cont.resume(returning: u) }
                else if let s = item as? String,
                        let u = URL(string: s)        { cont.resume(returning: u) }
                else                                  { cont.resume(returning: nil) }
            }
        }
    }

    // MARK: - Metadaten-Aufloesung

    private func resolveSongMetadata(from payload: SharedPayload) -> SongMetadata {
        if let url = payload.url, let pair = parseShazamURLFragment(url) { return pair }

        if let itemTitle = payload.itemTitle, !itemTitle.isEmpty {
            if let pair = parseTitleArtist(from: itemTitle) { return pair }
            if let bodyRaw = payload.itemBody, !bodyRaw.isEmpty {
                let a = stripArtistPrefix(bodyRaw)
                if !a.isEmpty { return SongMetadata(title: itemTitle, artist: a) }
            }
            for text in payload.texts {
                let a = extractArtist(fromText: text, knownTitle: itemTitle)
                if !a.isEmpty { return SongMetadata(title: itemTitle, artist: a) }
            }
            for text in payload.texts {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty, !t.lowercased().hasPrefix("http"), t.count <= 80,
                      !t.contains("\n"), t.caseInsensitiveCompare(itemTitle) != .orderedSame
                else { continue }
                return SongMetadata(title: itemTitle, artist: t)
            }
            if let url = payload.url, let a = extractArtistFromSlug(url, knownTitle: itemTitle), !a.isEmpty {
                return SongMetadata(title: itemTitle, artist: a)
            }
            return SongMetadata(title: itemTitle, artist: "")
        }

        let combined = payload.texts.joined(separator: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if let pair = parseTitleArtist(from: combined) { return pair }
        let lines = combined.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("http://") && !$0.hasPrefix("https://") }
        for line in lines { if let pair = parseTitleArtist(from: line) { return pair } }
        if let url = payload.url, let pair = parseShazamURL(url) { return pair }
        return SongMetadata(title: lines.first ?? "", artist: "")
    }

    private func extractArtist(fromText text: String, knownTitle: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [cleaned] + cleaned.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("http://") && !$0.hasPrefix("https://") }
        for c in candidates {
            guard let pair = parseTitleArtist(from: c),
                  pair.title.caseInsensitiveCompare(knownTitle) == .orderedSame,
                  !pair.artist.isEmpty else { continue }
            return pair.artist
        }
        return ""
    }

    private func parseTitleArtist(from source: String) -> SongMetadata? {
        for sep in [" - ", " \u{2013} ", " \u{2014} ", " by ", " von "] {
            let parts = source.components(separatedBy: sep)
            guard parts.count >= 2 else { continue }
            let title  = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = parts[1...].joined(separator: sep).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty || !artist.isEmpty { return SongMetadata(title: title, artist: artist) }
        }
        return nil
    }

    private func stripArtistPrefix(_ raw: String) -> String {
        for prefix in ["by ", "von ", "By ", "Von "] {
            if raw.hasPrefix(prefix) { return String(raw.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return raw
    }

    private func parseShazamURLFragment(_ url: URL) -> SongMetadata? {
        guard let host = url.host, host.contains("shazam.com"),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let fragment = comps.fragment, !fragment.isEmpty,
              let data = fragment.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        let title  = json["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = json["artist"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        return SongMetadata(title: title, artist: artist)
    }

    private func parseShazamURL(_ url: URL) -> SongMetadata? {
        guard let host = url.host, host.contains("shazam.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 3, parts[0] == "track" else { return nil }
        let slug = parts[2].replacingOccurrences(of: "-", with: " ").capitalized
        return slug.isEmpty ? nil : SongMetadata(title: slug, artist: "")
    }

    private func extractArtistFromSlug(_ url: URL, knownTitle: String) -> String? {
        guard let host = url.host, host.contains("shazam.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 3, parts[0] == "track" else { return nil }
        let slug = parts[2].lowercased()
        let titleSlug = knownTitle.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-")
        guard slug.hasSuffix(titleSlug), slug.count > titleSlug.count else { return nil }
        let artistSlug = String(slug.prefix(slug.count - titleSlug.count - 1))
        guard !artistSlug.isEmpty else { return nil }
        return artistSlug.components(separatedBy: "-").map { $0.capitalized }.joined(separator: " ")
    }

    // MARK: - Persistenz

    private func makeDeepLink(title: String, artist: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "librestage-calle-2j4quq2xrg"
        comps.host   = "add-song"
        var items: [URLQueryItem] = []
        if !title.isEmpty  { items.append(URLQueryItem(name: "title",  value: title))  }
        if !artist.isEmpty { items.append(URLQueryItem(name: "artist", value: artist)) }
        if !items.isEmpty  { comps.queryItems = items }
        return comps.url
    }

    private func persistDebugPayload(_ payload: SharedPayload) {
        guard let defaults = UserDefaults(suiteName: AddSongHandoverConfig.appGroupID) else { return }
        let debug = ShareDebugPayload(timestamp: Date().timeIntervalSince1970,
                                     itemTitle: payload.itemTitle, itemBody: payload.itemBody,
                                     texts: payload.texts, urlString: payload.url?.absoluteString,
                                     typeIdentifiersPerProvider: payload.typeIdentifiersPerProvider)
        guard let data = try? JSONEncoder().encode(debug) else { return }
        defaults.set(data, forKey: AddSongHandoverConfig.debugPayloadKey)
    }

    private func persistSharedHandover(title: String, artist: String) {
        guard let defaults = UserDefaults(suiteName: AddSongHandoverConfig.appGroupID) else { return }
        let payload = SharedAddSongPayload(title: title, interpret: artist, createdAt: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: AddSongHandoverConfig.sharedPayloadKey)
    }
}

// MARK: - Private Hilfstypen

private struct SharedPayload {
    let texts: [String]
    let url: URL?
    let itemTitle: String?
    let itemBody: String?
    let typeIdentifiersPerProvider: [[String]]
}

private struct SongMetadata {
    let title: String
    let artist: String
}


private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
