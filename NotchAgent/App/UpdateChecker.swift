//
//  UpdateChecker.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

struct UpdateCheckResult {
    let isUpdateAvailable: Bool
    let latestVersion: String
    let releaseURL: URL
}

enum UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/omerfarukaras/NotchAgent/releases/latest")!

    static func checkForUpdates() async throws -> UpdateCheckResult {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("NotchAgent", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateCheckError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)

        guard let releaseURL = URL(string: release.htmlUrl) else {
            throw UpdateCheckError.invalidReleaseURL
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

        return UpdateCheckResult(
            isUpdateAvailable: isVersion(latestVersion, newerThan: currentVersion),
            latestVersion: latestVersion,
            releaseURL: releaseURL
        )
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = versionParts(lhs)
        let right = versionParts(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue > rightValue { return true }
            if leftValue < rightValue { return false }
        }

        return false
    }

    private static func versionParts(_ version: String) -> [Int] {
        version
            .split { character in
                character == "." || character == "-" || character == "_"
            }
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
}

enum UpdateCheckError: Error {
    case invalidResponse
    case invalidReleaseURL
}
