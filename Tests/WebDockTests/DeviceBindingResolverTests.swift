import XCTest
@testable import WebDock

final class DeviceBindingResolverTests: XCTestCase {
    func testEmailMatchIgnoresLocalProfileNumberAndCase() {
        let profiles = [
            profile(directory: "Profile 3", email: "User@Example.com"),
            profile(directory: "Profile 12", email: "other@example.com")
        ]

        switch AccountProfileMatcher.match(
            targetEmail: "user@example.COM",
            profiles: profiles
        ) {
        case .one(let match):
            XCTAssertEqual(match.profileDirectory, "Profile 3")
        default:
            XCTFail("Expected one matching local profile")
        }
    }

    func testMissingEmailDoesNotGuessProfile() {
        let profiles = [profile(directory: "Default", email: "other@example.com")]

        switch AccountProfileMatcher.match(
            targetEmail: "missing@example.com",
            profiles: profiles
        ) {
        case .none:
            break
        default:
            XCTFail("Missing accounts must not be guessed")
        }
    }

    func testDuplicateEmailIsAmbiguous() {
        let profiles = [
            profile(directory: "Profile 2", email: "same@example.com"),
            profile(directory: "Profile 8", email: "same@example.com")
        ]

        switch AccountProfileMatcher.match(
            targetEmail: "same@example.com",
            profiles: profiles
        ) {
        case .ambiguous(let matches):
            XCTAssertEqual(matches.count, 2)
        default:
            XCTFail("Duplicate account identities must require a local override")
        }
    }

    func testEmailNormalizationDoesNotApplyGmailPlusOrDotRules() {
        XCTAssertNotEqual(
            normalizeAccountEmail("user+work@gmail.com"),
            normalizeAccountEmail("user@gmail.com")
        )
        XCTAssertNotEqual(
            normalizeAccountEmail("first.last@gmail.com"),
            normalizeAccountEmail("firstlast@gmail.com")
        )
    }

    private func profile(directory: String, email: String) -> BrowserProfileOption {
        BrowserProfileOption(
            browserBundleIdentifier: "com.google.Chrome",
            browserDisplayName: "Google Chrome",
            profileDirectory: directory,
            localProfileName: directory,
            accountDisplayName: nil,
            accountEmail: email,
            routingSupport: .verifiedChromiumWebloc
        )
    }
}
