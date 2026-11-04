import Foundation

enum ClaimReference: Equatable {
    static let codeParameter = "tolt_code"
    static let clickParameter = "tolt_click"

    case code(String)
    case click(String)

    init?(url: URL) {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let value = { (name: String) in
            items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let click = value(Self.clickParameter), !click.isEmpty {
            self = .click(click)
        } else if let code = value(Self.codeParameter), !code.isEmpty {
            self = .code(code)
        } else {
            return nil
        }
    }
}
