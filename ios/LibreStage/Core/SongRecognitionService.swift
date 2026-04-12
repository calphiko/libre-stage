// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import ShazamKit

struct RecognizedSongMetadata {
    let title: String
    let interpret: String
}

enum SongRecognitionError: LocalizedError {
    case unavailable
    case microphonePermissionDenied
    case busy
    case cancelled
    case timedOut
    case invalidMatch

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Song-Erkennung ist auf diesem Geraet nicht verfuegbar."
        case .microphonePermissionDenied:
            return "Kein Mikrofonzugriff. Bitte den Zugriff in den iOS-Einstellungen erlauben."
        case .busy:
            return "Song-Erkennung laeuft bereits."
        case .cancelled:
            return "Song-Erkennung wurde abgebrochen."
        case .timedOut:
            return "Kein Song erkannt. Bitte erneut versuchen und das Geraet naeher zur Musik halten."
        case .invalidMatch:
            return "Song wurde erkannt, aber Titel oder Interpret fehlen."
        }
    }
}

@MainActor
final class SongRecognitionService: NSObject {
    static let shared = SongRecognitionService()
    // SHSession hat keine statische Availability-API; Laufzeitfehler werden ueber Delegate/Throws behandelt.
    static var isRecognitionAvailable: Bool { true }

    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()

    private var shazamSession: SHSession?
    private var continuation: CheckedContinuation<RecognizedSongMetadata, Error>?
    private var timeoutTask: Task<Void, Never>?
    var onAudioLevelChanged: ((Double) -> Void)?
    var onStatusChanged: ((String) -> Void)?
    private var noMatchPulseCount = 0
    private var peakAudioLevel: Double = 0

    private override init() {
        super.init()
    }

    func recognizeCurrentSong(timeoutSeconds: Double = 20) async throws -> RecognizedSongMetadata {
        guard continuation == nil else {
            throw SongRecognitionError.busy
        }

        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw SongRecognitionError.microphonePermissionDenied
        }

        noMatchPulseCount = 0
        peakAudioLevel = 0
        onStatusChanged?("Starte Audio-Session...")

        do {
            try startRecognitionPipeline()
        } catch {
            cleanupPipeline()
            throw error
        }

        onStatusChanged?("Hoere zu und suche Match...")
        if let routeHint = currentRouteHint() {
            onStatusChanged?(routeHint)
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RecognizedSongMetadata, Error>) in
            self.continuation = continuation
            timeoutTask = Task { [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: .seconds(timeoutSeconds))
                self.onStatusChanged?(
                    String(
                        format: "Kein Match nach %.0fs (Peak %.2f, Signaturen %d)",
                        timeoutSeconds,
                        self.peakAudioLevel,
                        self.noMatchPulseCount
                    )
                )
                self.finish(with: .failure(SongRecognitionError.timedOut))
            }
        }
    }

    func stopRecognition() {
        finish(with: .failure(SongRecognitionError.cancelled))
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startRecognitionPipeline() throws {
        let session = SHSession()
        session.delegate = self
        shazamSession = session

        // Messmodus reduziert Audio-Nachbearbeitung und liefert bessere Fingerprints.
        try audioSession.setCategory(.record, mode: .measurement, options: [.mixWithOthers])
        if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? audioSession.setPreferredInput(builtInMic)
        }
        try audioSession.setActive(true, options: [])

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, time in
            self?.shazamSession?.matchStreamingBuffer(buffer, at: time)
            self?.publishAudioLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func finish(with result: Result<RecognizedSongMetadata, Error>) {
        guard let continuation else {
            cleanupPipeline()
            return
        }

        timeoutTask?.cancel()
        timeoutTask = nil

        self.continuation = nil
        cleanupPipeline()
        continuation.resume(with: result)
    }

    private func cleanupPipeline() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

        shazamSession?.delegate = nil
        shazamSession = nil
        onAudioLevelChanged?(0)

        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func publishAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var squareSum: Float = 0
        for i in 0..<frameCount {
            let sample = channelData[i]
            squareSum += sample * sample
        }

        let rms = sqrt(squareSum / Float(frameCount))
        let normalized: Double
        if rms > 0 {
            let db = 20 * log10(rms)
            normalized = min(max(Double((db + 50) / 50), 0), 1)
        } else {
            normalized = 0
        }
        peakAudioLevel = max(peakAudioLevel, normalized)

        Task { @MainActor [weak self] in
            self?.onAudioLevelChanged?(normalized)
        }
    }

    private func currentRouteHint() -> String? {
        let outputs = audioSession.currentRoute.outputs.map(\ .portType)
        if outputs.contains(.headphones)
            || outputs.contains(.bluetoothA2DP)
            || outputs.contains(.bluetoothLE)
            || outputs.contains(.bluetoothHFP)
            || outputs.contains(.airPlay)
            || outputs.contains(.carAudio) {
            return "Hinweis: Ausgabe ueber Kopfhoerer/Bluetooth erkannt. Erkennung klappt besser mit externer Lautsprecherquelle in der Umgebung."
        }
        return nil
    }

}

extension SongRecognitionService: SHSessionDelegate {
    nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        let mediaItem = match.mediaItems.first
        let title = (mediaItem?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let interpret = (mediaItem?.artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !title.isEmpty || !interpret.isEmpty else {
                self.finish(with: .failure(SongRecognitionError.invalidMatch))
                return
            }
            let resolvedTitle = title.isEmpty ? "(kein Titel)" : title
            let resolvedInterpret = interpret.isEmpty ? "(kein Interpret)" : interpret
            self.onStatusChanged?("Match: \(resolvedTitle) - \(resolvedInterpret)")
            self.finish(with: .success(RecognizedSongMetadata(title: title, interpret: interpret)))
        }
    }

    nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        // Dieser Callback kann mehrfach waehrend des Streamings kommen.
        // Wir beenden hier NICHT, damit bis zum expliziten Timeout weiter zugehoert wird.
        // Harte Fehler kommen ueber didFailWithError.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.noMatchPulseCount += 1
            if self.noMatchPulseCount % 10 == 0 {
                self.onStatusChanged?("Noch kein Match (Signaturen: \(self.noMatchPulseCount))")
            }
        }
    }


    nonisolated func session(_ session: SHSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            let nsError = error as NSError
            self?.onStatusChanged?("Shazam-Fehler: \(nsError.domain) (\(nsError.code))")
            self?.finish(with: .failure(error))
        }
    }
}

