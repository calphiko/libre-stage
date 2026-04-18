// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct SongDuplicateMatch {
    let score: Double
    let song: SongOut
}

enum SongDuplicateCheck {
    static func findBestSongDuplicate(candidate: SongDetailsDraft, songs: [SongOut]) -> SongDuplicateMatch? {
        let candidateTitle = normalizeSongText(candidate.title)
        let candidateInterpret = normalizeSongText(candidate.interpret)

        guard !candidateTitle.isEmpty, !candidateInterpret.isEmpty else {
            return nil
        }

        var bestMatch: SongDuplicateMatch?

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
                bestMatch = SongDuplicateMatch(score: combinedScore, song: song)
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

