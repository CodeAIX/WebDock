import Foundation

func validateWebURL(_ url: URL) throws {
    guard let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          url.host != nil else {
        throw WebURLValidationError.invalidURL
    }
}

enum WebURLValidationError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        L10n.tr("Only valid HTTP and HTTPS website URLs are supported.")
    }
}
