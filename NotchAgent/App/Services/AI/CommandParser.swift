//
//  CommandParser.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 19.06.2026.
//

import Foundation

enum CommandParser {
    static func localCommand(for transcript: String) -> ParsedCommand? {
        if let command = browserTabsCommand(for: transcript) {
            return command
        }

        if shouldUseLocalMusicParser(for: transcript), let musicQuery = musicSearchQuery(from: transcript) {
            return ParsedCommand(
                action: "search_music",
                target: musicQuery,
                script: nil,
                confidence: 0.92,
                summary: "Playing \(musicQuery)",
                needs_confirmation: false
            )
        }

        return nil
    }

    static func shouldUseLocalMusicParser(for transcript: String) -> Bool {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        
        let questionWords = ["how", "nasıl", "nasil", "where", "nerede", "neden", "niye", "what", "ne"]
        if questionWords.contains(where: { lowercased.contains($0) }) {
            return false // Let the LLM orchestrate questions
        }
        
        let hasExplicitProvider = lowercased.contains("spotify") || lowercased.contains("apple music")
        let hasKnownSpeechCorrection = [
            "lvbel", "label c5", "labelc5", "level c5", "levelc5",
            "love bell c5", "lovebel c5", "el ve bel c5",
            "l v bel c5", "l v b l c 5"
        ].contains { lowercased.contains($0) }

        return hasExplicitProvider || hasKnownSpeechCorrection
    }

    static func browserTabsCommand(for transcript: String) -> ParsedCommand? {
        let lowercased = transcript.lowercased()
        guard lowercased.contains("open") || lowercased.contains("aç") else { return nil }

        let browserAliases: [(alias: String, appName: String)] = [
            ("safari", "Safari"),
            ("chrome", "Google Chrome"),
            ("google chrome", "Google Chrome"),
            ("edge", "Microsoft Edge"),
            ("firefox", "Firefox"),
            ("arc", "Arc")
        ]

        guard let browser = browserAliases.first(where: { lowercased.contains($0.alias) }) else {
            return nil
        }

        let separators = CharacterSet(charactersIn: ",+&")
        let cleaned = lowercased
            .replacingOccurrences(of: "open", with: " ")
            .replacingOccurrences(of: "aç", with: " ")
            .replacingOccurrences(of: browser.alias, with: " ")
            .replacingOccurrences(of: "with", with: " ")
            .replacingOccurrences(of: "and", with: ",")
            .replacingOccurrences(of: "ile", with: " ")
            .replacingOccurrences(of: "ve", with: ",")

        let urls = cleaned
            .components(separatedBy: separators)
            .compactMap { normalizedURLString(from: $0) }

        guard urls.count >= 2 else { return nil }

        return ParsedCommand(
            action: "open_urls",
            target: browser.appName,
            script: urls.joined(separator: "\n"),
            confidence: 0.94,
            summary: "Opening \(urls.count) tabs",
            needs_confirmation: false
        )
    }

    static func musicSearchQuery(from transcript: String) -> String? {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        guard isMusicSearchIntent(lowercased) else { return nil }

        let providerPrefix: String
        if lowercased.contains("spotify") {
            providerPrefix = "spotify::"
        } else if lowercased.contains("apple music") || lowercased.contains("müzik uygulaması") || lowercased.contains("music uygulaması") {
            providerPrefix = "applemusic::"
        } else {
            providerPrefix = ""
        }

        var query = lowercased
        let replacements: [(String, String)] = [
            ("spotify'da", " "),
            ("spotify da", " "),
            ("spotifyda", " "),
            ("spotify", " "),
            ("apple music'te", " "),
            ("apple music te", " "),
            ("apple musicte", " "),
            ("apple music", " "),
            ("müzik uygulamasında", " "),
            ("music app", " "),
            ("please", " "),
            ("can you", " "),
            ("could you", " "),
            ("play", " "),
            ("open", " "),
            ("search", " "),
            ("put on", " "),
            ("açabilir misin", " "),
            ("açarmısın", " "),
            ("açar mısın", " "),
            ("aç", " "),
            ("çalabilir misin", " "),
            ("çalarmısın", " "),
            ("çalar mısın", " "),
            ("çal", " "),
            ("oynat", " "),
            ("başlat", " "),
            ("en iyi şarkılar", "best songs"),
            ("en sevilen şarkılar", "best songs"),
            ("popüler şarkılar", "popular songs"),
            ("şarkısını", " "),
            ("şarkısı", " "),
            ("şarkı", " "),
            ("parçasını", " "),
            ("parça", " "),
            ("playlistini", "playlist"),
            ("playlist'i", "playlist"),
            ("çalma listesini", "playlist"),
            ("listesini", " "),
            ("listesi", " "),
            ("radyosunu", "radio"),
            ("radyosu", "radio"),
            ("radyo", "radio"),
            (" radyoyu", " radio"),
            ("yi ", " "),
            ("yı ", " "),
            ("yu ", " "),
            ("yü ", " "),
            ("'yi", " "),
            ("'yı", " "),
            ("'yu", " "),
            ("'yü", " ")
        ]

        for (needle, replacement) in replacements {
            query = query.replacingOccurrences(of: needle, with: replacement)
        }

        query = query
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        query = stripTurkishObjectSuffixes(from: query)
        query = normalizeKnownMusicNames(query)

        guard isUsefulMusicQuery(query) else { return nil }
        return providerPrefix + titleCasedMusicQuery(query)
    }

    static func isMusicSearchIntent(_ lowercased: String) -> Bool {
        let musicWords = [
            "spotify", "apple music", "play", "çal", "oynat", "aç",
            "şarkı", "parça", "playlist", "çalma listesi", "radyo", "radyosu",
            "radio", "album", "albüm", "top 50", "top fifty", "motive",
            "lvbel", "label c5", "level c5"
        ]

        guard musicWords.contains(where: { lowercased.contains($0) }) else {
            return false
        }

        let nonMusicOpenTargets = ["safari", "chrome", "github", "youtube", "xcode", "cursor", "mail"]
        if lowercased.contains("aç") || lowercased.contains("open") {
            return !nonMusicOpenTargets.contains(where: { lowercased.contains($0) })
        }

        return true
    }
    
    static func normalizedURLString(from rawValue: String) -> String? {
        let token = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !token.isEmpty else { return nil }

        let aliases: [String: String] = [
            "youtube": "https://youtube.com",
            "you tube": "https://youtube.com",
            "github": "https://github.com",
            "git hub": "https://github.com",
            "google": "https://google.com",
            "gmail": "https://mail.google.com",
            "chatgpt": "https://chatgpt.com",
            "chat gpt": "https://chatgpt.com",
            "x": "https://x.com",
            "twitter": "https://x.com",
            "reddit": "https://reddit.com"
        ]

        if let alias = aliases[token] {
            return alias
        }

        if token.hasPrefix("http://") || token.hasPrefix("https://") {
            return token
        }

        if token.contains(".") && !token.contains(" ") {
            return "https://\(token)"
        }

        return nil
    }

    private static func normalizeKnownMusicNames(_ query: String) -> String {
        var normalized = query
        let knownReplacements: [(String, String)] = [
            ("level c5", "lvbelc5"),
            ("levelc5", "lvbelc5"),
            ("label c5", "lvbelc5"),
            ("labelc5", "lvbelc5"),
            ("lvbel c5", "lvbelc5"),
            ("love bell c5", "lvbelc5"),
            ("lovebel c5", "lvbelc5"),
            ("el ve bel c5", "lvbelc5"),
            ("l v bel c5", "lvbelc5"),
            ("l v b l c 5", "lvbelc5"),
            ("motive top fifty", "motive top 50"),
            ("top fifty", "top 50")
        ]

        for (needle, replacement) in knownReplacements {
            normalized = normalized.replacingOccurrences(of: needle, with: replacement)
        }

        return normalized
    }

    private static func stripTurkishObjectSuffixes(from query: String) -> String {
        query
            .split(separator: " ")
            .map { word -> String in
                var value = String(word).trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
                let suffixes = ["lerini", "larını", "ini", "ını", "unu", "ünü", "yi", "yı", "yu", "yü"]

                for suffix in suffixes where value.count > suffix.count + 1 && value.hasSuffix(suffix) {
                    value.removeLast(suffix.count)
                    break
                }

                return value
            }
            .joined(separator: " ")
    }

    private static func isUsefulMusicQuery(_ query: String) -> Bool {
        guard query.count >= 2 else { return false }
        let banned = Set(["spotify", "apple music", "music", "şarkı", "playlist", "radio", "radyo"])
        return !banned.contains(query)
    }

    private static func titleCasedMusicQuery(_ query: String) -> String {
        if query == "lvbelc5" { return "lvbelc5" }
        return query
            .split(separator: " ")
            .map { part in
                if part == "lvbelc5" { return String(part) }
                if part.allSatisfy(\Character.isNumber) { return String(part) }
                if part == "radio" || part == "playlist" { return String(part) }
                return part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}
