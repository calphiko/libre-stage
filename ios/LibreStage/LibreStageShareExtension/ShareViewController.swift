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
    let resolvedTitle: String?
    let resolvedArtist: String?
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
            let metadata = await resolveSongMetadata(from: payload)
            persistDebugPayload(payload, resolved: metadata)
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
        persistSharedHandover(title: metadata.title, artist: metadata.artist)
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

    private func resolveSongMetadata(from payload: SharedPayload) async -> SongMetadata {
        let embeddedURL = payload.url ?? extractFirstURLFromPayload(payload)
        if let embeddedURL,
           let fetched = await fetchSongMetadataFromPublicPage(embeddedURL),
           !fetched.title.isEmpty || !fetched.artist.isEmpty {
            return fetched
        }

        if let url = payload.url, let pair = parseShazamURLFragment(url) { return pair }

        if let itemTitle = payload.itemTitle, !itemTitle.isEmpty {
            if let pair = parseAppleMusicShareText(itemTitle) { return pair }
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
        if let pair = parseAppleMusicShareText(combined) { return pair }
        if let pair = parseTitleArtist(from: combined) { return pair }
        if let titleOnly = parseStreamingPromptTitle(from: combined) {
            return SongMetadata(title: titleOnly, artist: "")
        }
        let lines = combined.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("http://") && !$0.hasPrefix("https://") }
        for line in lines { if let pair = parseTitleArtist(from: line) { return pair } }
        for line in lines {
            if let pair = parseAppleMusicShareText(line) { return pair }
        }
        if let url = payload.url, let pair = parseAppleMusicURL(url) { return pair }
        if let url = payload.url, let pair = parseShazamURL(url) { return pair }
        let fallbackTitle = normalizeStreamingShareText(lines.first ?? "")
        return SongMetadata(title: fallbackTitle, artist: "")
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
        let normalized = normalizeStreamingShareText(source)
        for sep in [" - ", " \u{2013} ", " \u{2014} ", " • ", " · ", " by ", " von "] {
            let parts = normalized.components(separatedBy: sep)
            guard parts.count >= 2 else { continue }
            let title  = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = parts[1...].joined(separator: sep).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty || !artist.isEmpty { return SongMetadata(title: title, artist: artist) }
        }
        return nil
    }

    private func normalizeStreamingShareText(_ raw: String) -> String {
        var value = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Bei Shares mit Text + URL nur die inhaltlichen Zeilen normalisieren.
        let contentLines = value
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("http://") && !$0.hasPrefix("https://") }
        if !contentLines.isEmpty {
            value = contentLines.joined(separator: " ")
        }

        // Marketing-Wrapper entfernen, wie er von Streaming-Apps haeufig in Share-Texten genutzt wird.
        value = droppingAnyCaseInsensitivePrefix(in: value, prefixes: [
            "Listen to ", "Check out ", "Hor dir ", "Hoer dir ", "Jetzt horen: "
        ])
        value = droppingAnyCaseInsensitiveSuffix(in: value, suffixes: [
            " auf deinem Streaming-Dienst an", " on your streaming service",
            " on Apple Music", " auf Apple Music", " | Apple Music",
            " on Spotify", " auf Spotify", " | Spotify",
            " on TIDAL", " auf TIDAL", " | TIDAL"
        ])

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func droppingAnyCaseInsensitivePrefix(in value: String, prefixes: [String]) -> String {
        for prefix in prefixes {
            guard let range = value.range(
                of: prefix,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive]
            ) else { continue }
            if range.lowerBound == value.startIndex {
                return String(value[range.upperBound...])
            }
        }
        return value
    }

    private func droppingAnyCaseInsensitiveSuffix(in value: String, suffixes: [String]) -> String {
        for suffix in suffixes {
            guard let range = value.range(
                of: suffix,
                options: [.caseInsensitive, .diacriticInsensitive, .backwards]
            ) else { continue }
            if range.upperBound == value.endIndex { return String(value[..<range.lowerBound]) }
        }
        return value
    }

    private func parseStreamingPromptTitle(from source: String) -> String? {
        let lineCandidates = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("http://") && !$0.hasPrefix("https://") }

        for line in lineCandidates {
            if let title = extractStreamingPromptTitleFromLine(line) {
                return title
            }
        }

        let normalized = normalizeStreamingShareText(source)
        guard !normalized.isEmpty,
              normalized.caseInsensitiveCompare(source.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame,
              !normalized.contains(" - ")
        else { return nil }
        return normalized
    }

    private func extractStreamingPromptTitleFromLine(_ line: String) -> String? {
        // Robust fuer Variationen wie "Hoer/Hoer", "Streaming-Dienst/Streaming–Dienst" etc.
        let pattern = "(?i)^(?:h[oö]r|hoer)\\s+dir\\s+(.+?)\\s+auf\\s+deinem\\s+streaming[\\-\\u{2010}\\u{2011}\\u{2012}\\u{2013}\\u{2014}]?dienst\\s+an\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)
        guard let match = regex.firstMatch(in: line, options: [], range: fullRange), match.numberOfRanges >= 2 else {
            return nil
        }
        let titleRange = match.range(at: 1)
        guard titleRange.location != NSNotFound else { return nil }
        let title = nsLine.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func extractFirstURLFromPayload(_ payload: SharedPayload) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let sources = [payload.itemTitle, payload.itemBody] + payload.texts
        for source in sources {
            guard let source else { continue }
            let nsSource = source as NSString
            let range = NSRange(location: 0, length: nsSource.length)
            if let match = detector?.firstMatch(in: source, options: [], range: range),
               let url = match.url {
                return url
            }
        }
        return nil
    }

    private func fetchSongMetadataFromPublicPage(_ url: URL) async -> SongMetadata? {
        let provider = StreamingProvider.from(url: url)
        guard provider != .unknown else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let rawTitle = firstMetaContent(named: "og:title", in: html) ??
                             firstMetaContent(named: "twitter:title", in: html) else {
            return nil
        }
        let rawDescription = firstMetaContent(named: "og:description", in: html)
            ?? firstMetaContent(named: "twitter:description", in: html)

        let title = decodeHTMLEntities(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = decodeHTMLEntities(rawDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if let providerResult = parseProviderSpecificPublicMetadata(provider: provider, title: title, description: description) {
            return providerResult
        }

        if let pair = parseTitleArtist(from: title) { return pair }
        if let byPair = parseByPattern(from: title) { return byPair }
        return SongMetadata(title: title, artist: "")
    }

    private func parseProviderSpecificPublicMetadata(provider: StreamingProvider, title: String, description: String) -> SongMetadata? {
        switch provider {
        case .tidal:
            if let dash = parseDashSeparated(source: title, artistFirst: true) { return dash }
            if let byPair = parseByPattern(from: title) { return byPair }
            return nil

        case .spotify:
            let cleanedTitle = stripStreamingServiceSuffixes(title)
            let artist = extractSpotifyArtist(from: description)
            guard !cleanedTitle.isEmpty || !artist.isEmpty else { return nil }
            return SongMetadata(title: cleanedTitle, artist: artist)

        case .appleMusic:
            if let pair = parseAppleMusicShareText(title) { return pair }
            if let dash = parseDashSeparated(source: stripStreamingServiceSuffixes(title), artistFirst: false) { return dash }
            let cleanedTitle = stripStreamingServiceSuffixes(title)
            let artist = extractAppleMusicArtist(from: description)
            guard !cleanedTitle.isEmpty || !artist.isEmpty else { return nil }
            return SongMetadata(title: cleanedTitle, artist: artist)

        case .unknown:
            return nil
        }
    }

    private func parseDashSeparated(source: String, artistFirst: Bool) -> SongMetadata? {
        for separator in [" - ", " – ", " — "] {
            let parts = source.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }
            let first = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let second = parts[1...].joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !first.isEmpty || !second.isEmpty else { continue }
            return artistFirst ? SongMetadata(title: second, artist: first) : SongMetadata(title: first, artist: second)
        }
        return nil
    }

    private func parseAppleMusicShareText(_ source: String) -> SongMetadata? {
        let normalized = normalizeStreamingShareText(source)
        let patterns = [
            "(?i)^(.+?)\\s+by\\s+(.+?)(?:\\s+on\\s+apple\\s+music)?$",
            "(?i)^(.+?)\\s+von\\s+(.+?)(?:\\s+auf\\s+apple\\s+music)?$",
            "(?i)^(?:listen\\s+to|h[oö]r\\s+dir|hoer\\s+dir)\\s+(.+?)\\s+(?:by|von)\\s+(.+?)(?:\\s+(?:on|auf)\\s+apple\\s+music)?$",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = normalized as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: normalized, options: [], range: range), match.numberOfRanges >= 3 else {
                continue
            }
            let title = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty || !artist.isEmpty { return SongMetadata(title: title, artist: artist) }
        }
        return nil
    }

    private func stripStreamingServiceSuffixes(_ source: String) -> String {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" | Spotify", " | Apple Music", " | TIDAL", " - Apple Music"] {
            if value.lowercased().hasSuffix(suffix.lowercased()) {
                value = String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return value
    }

    private func extractSpotifyArtist(from description: String) -> String {
        let cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        if let delimiterRange = cleaned.range(of: "  ") {
            return String(cleaned[..<delimiterRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let delimiterRange = cleaned.range(of: " • ") {
            return String(cleaned[..<delimiterRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func extractAppleMusicArtist(from description: String) -> String {
        let cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        for pattern in ["(?i)^.+?\\s+by\\s+(.+?)(?:\\s+on\\s+apple\\s+music)?$", "(?i)^.+?\\s+von\\s+(.+?)(?:\\s+auf\\s+apple\\s+music)?$"] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = cleaned as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: cleaned, options: [], range: range), match.numberOfRanges >= 2 else {
                continue
            }
            return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func stripArtistPrefix(_ raw: String) -> String {
        for prefix in ["by ", "von ", "By ", "Von "] {
            if raw.hasPrefix(prefix) {
                return String(raw.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
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

        let title = json["title"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    private func parseAppleMusicURL(_ url: URL) -> SongMetadata? {
        guard let host = url.host?.lowercased(), host.contains("music.apple.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let songIndex = parts.firstIndex(of: "song"), parts.indices.contains(songIndex + 1) else {
            return nil
        }

        let raw = parts[songIndex + 1]
        let decoded = raw.removingPercentEncoding ?? raw
        let title = decoded.replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        return title.isEmpty ? nil : SongMetadata(title: title, artist: "")
    }

    private func extractArtistFromSlug(_ url: URL, knownTitle: String) -> String? {
        guard let host = url.host, host.contains("shazam.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 3, parts[0] == "track" else { return nil }

        let slug = parts[2].lowercased()
        let titleSlug = knownTitle.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        guard slug.hasSuffix(titleSlug), slug.count > titleSlug.count else { return nil }

        let artistSlug = String(slug.prefix(slug.count - titleSlug.count - 1))
        guard !artistSlug.isEmpty else { return nil }
        return artistSlug.components(separatedBy: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private func firstMetaContent(named propertyName: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: propertyName)
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\\s*\(escaped)\\s*[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+(?:property|name)=[\"']\\s*\(escaped)\\s*[\"']",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let nsHTML = html as NSString
            let fullRange = NSRange(location: 0, length: nsHTML.length)
            guard let match = regex.firstMatch(in: html, options: [], range: fullRange), match.numberOfRanges >= 2 else {
                continue
            }
            return nsHTML.substring(with: match.range(at: 1))
        }
        return nil
    }

    private func parseByPattern(from source: String) -> SongMetadata? {
        let pattern = "^(.+?)\\s+by\\s+(.+?)(?:\\s+on\\s+.+)?$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsSource = source as NSString
        let fullRange = NSRange(location: 0, length: nsSource.length)
        guard let match = regex.firstMatch(in: source, options: [], range: fullRange), match.numberOfRanges >= 3 else {
            return nil
        }
        let title = nsSource.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = nsSource.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        return SongMetadata(title: title, artist: artist)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil).string) ?? text
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

    private func persistDebugPayload(_ payload: SharedPayload, resolved: SongMetadata) {
        guard let defaults = UserDefaults(suiteName: AddSongHandoverConfig.appGroupID) else { return }
        let debug = ShareDebugPayload(timestamp: Date().timeIntervalSince1970,
                                     itemTitle: payload.itemTitle, itemBody: payload.itemBody,
                                     texts: payload.texts, urlString: payload.url?.absoluteString,
                                     typeIdentifiersPerProvider: payload.typeIdentifiersPerProvider,
                                     resolvedTitle: resolved.title,
                                     resolvedArtist: resolved.artist)
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

private enum StreamingProvider {
    case tidal
    case spotify
    case appleMusic
    case unknown

    static func from(url: URL) -> StreamingProvider {
        let host = (url.host ?? "").lowercased()
        if host.contains("tidal.com") { return .tidal }
        if host.contains("open.spotify.com") { return .spotify }
        if host.contains("music.apple.com") { return .appleMusic }
        return .unknown
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
