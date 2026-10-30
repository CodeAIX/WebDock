import Foundation

struct BrowserProfileOption: Identifiable, Hashable {
    let browserBundleIdentifier: String
    let browserDisplayName: String
    let profileDirectory: String
    let localProfileName: String?
    let accountDisplayName: String?
    let accountEmail: String?
    let routingSupport: BrowserProfileRoutingSupport

    var id: String {
        "\(browserBundleIdentifier)::\(profileDirectory)"
    }

    var displayLabel: String {
        let local = normalized(localProfileName)
        let accountName = normalized(accountDisplayName)
        let email = normalized(accountEmail)

        var accountParts: [String] = []
        if let accountName {
            accountParts.append(accountName)
        }
        if let email, email.caseInsensitiveCompare(accountName ?? "") != .orderedSame {
            accountParts.append(email)
        }

        if !accountParts.isEmpty {
            let account = accountParts.joined(separator: " · ")
            if let local,
               local.caseInsensitiveCompare(accountName ?? "") != .orderedSame,
               local.caseInsensitiveCompare(email ?? "") != .orderedSame {
                return "\(account) — \(local) [\(profileDirectory)]"
            }
            return "\(account) — \(profileDirectory)"
        }

        if let local {
            return "\(local) — \(profileDirectory)"
        }

        return profileDirectory
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct BrowserProfileDiscovery {
    private let fileManager: FileManager
    private let homeDirectory: URL

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
    }

    func discoverProfiles(for browser: BrowserOption) throws -> [BrowserProfileOption] {
        guard let relativePath = browser.chromiumUserDataRelativePath else {
            return []
        }

        let userDataDirectory = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: true)
        let localStateURL = userDataDirectory.appendingPathComponent("Local State", isDirectory: false)

        // Attempt the read so macOS can request access. A preflight existence check may
        // return false for a protected directory and incorrectly report an empty account list.
        let data: Data
        do { data = try Data(contentsOf: localStateURL) }
        catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain,
               error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError {
                return []
            }
            throw error
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            throw BrowserProfileDiscoveryError.invalidLocalState(localStateURL)
        }

        var results: [BrowserProfileOption] = []
        for (profileDirectory, rawEntry) in infoCache {
            guard isSafeProfileDirectory(profileDirectory),
                  let entry = rawEntry as? [String: Any] else {
                continue
            }

            if (entry["is_ephemeral"] as? Bool) == true ||
                (entry["is_omitted"] as? Bool) == true ||
                (entry["is_omitted_from_profile_list"] as? Bool) == true {
                continue
            }

            let profileURL = userDataDirectory.appendingPathComponent(profileDirectory, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: profileURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let gaiaName = string(entry["gaia_name"])
            let gaiaGivenName = string(entry["gaia_given_name"])
            let accountDisplayName = gaiaName ?? gaiaGivenName

            results.append(
                BrowserProfileOption(
                    browserBundleIdentifier: browser.bundleIdentifier,
                    browserDisplayName: browser.displayName,
                    profileDirectory: profileDirectory,
                    localProfileName: string(entry["name"]),
                    accountDisplayName: accountDisplayName,
                    accountEmail: normalizeAccountEmail(string(entry["user_name"])),
                    routingSupport: browser.profileRoutingSupport
                )
            )
        }

        return results.sorted { lhs, rhs in
            compareProfileDirectories(lhs.profileDirectory, rhs.profileDirectory)
        }
    }

    private func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isSafeProfileDirectory(_ value: String) -> Bool {
        guard !value.isEmpty,
              value != ".",
              value != "..",
              !value.contains("/"),
              !value.contains("\\"),
              !value.contains("\0") else {
            return false
        }
        return true
    }

    private func compareProfileDirectories(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "Default" { return rhs != "Default" }
        if rhs == "Default" { return false }

        let lhsNumber = profileNumber(lhs)
        let rhsNumber = profileNumber(rhs)
        switch (lhsNumber, rhsNumber) {
        case let (left?, right?):
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    private func profileNumber(_ value: String) -> Int? {
        guard value.hasPrefix("Profile ") else { return nil }
        return Int(value.dropFirst("Profile ".count))
    }
}

enum BrowserProfileDiscoveryError: LocalizedError, Equatable {
    case invalidLocalState(URL)

    var errorDescription: String? {
        switch self {
        case .invalidLocalState(let url):
            L10n.tr("The browser profile metadata is not readable: %@.", url.path)
        }
    }
}
