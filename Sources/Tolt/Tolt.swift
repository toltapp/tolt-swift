import Foundation

public final class Tolt: @unchecked Sendable {
    public static let shared = Tolt()

    public static let codeAttribute = "tolt_code"

    private let lock = NSLock()
    private var publicId: String?
    private var baseURL = URL(string: "https://platform.tolt.com")!
    private var session: URLSession = .shared
    private var firstSeen = FirstSeenStore(defaults: .standard)

    init() {}

    public static func configure(publicId: String, baseURL: URL? = nil) {
        shared.configure(publicId: publicId, baseURL: baseURL)
    }

    public static func claim(code: String, appUserId: String) async throws -> ClaimResult {
        try await shared.claim(code: code, appUserId: appUserId)
    }

    public static func revenueCatAttributes(code: String) -> [String: String] {
        [codeAttribute: code.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    func configure(publicId: String, baseURL: URL? = nil, session: URLSession = .shared, defaults: UserDefaults = .standard) {
        lock.lock()
        defer { lock.unlock() }
        self.publicId = publicId
        if let baseURL { self.baseURL = baseURL }
        self.session = session
        self.firstSeen = FirstSeenStore(defaults: defaults)
        _ = firstSeen.firstSeenAt()
    }

    func claim(code: String, appUserId: String) async throws -> ClaimResult {
        let (publicId, baseURL, session, firstSeenAt) = try snapshot()
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { throw ToltError.invalidInput("code") }
        guard !appUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ToltError.invalidInput("appUserId") }

        var request = URLRequest(url: baseURL.appendingPathComponent("client/claims"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ClaimRequest(
            publicId: publicId,
            appUserId: appUserId,
            code: trimmedCode,
            firstSeenAt: ISO8601DateFormatter().string(from: firstSeenAt)
        ))

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            let body = try JSONDecoder().decode(Envelope<ClaimResponse>.self, from: data)
            guard let result = ClaimResult.Status(rawValue: body.data.status) else {
                throw ToltError.server(status: status, message: "Unknown claim status \(body.data.status)")
            }
            return ClaimResult(status: result, appUserId: body.data.appUserId)
        case 404:
            throw ToltError.codeNotFound
        case 409:
            throw ToltError.codeConflict(errorMessage(data))
        case 429:
            throw ToltError.rateLimited
        default:
            throw ToltError.server(status: status, message: errorMessage(data))
        }
    }

    private func snapshot() throws -> (String, URL, URLSession, Date) {
        lock.lock()
        defer { lock.unlock() }
        guard let publicId else { throw ToltError.notConfigured }
        return (publicId, baseURL, session, firstSeen.firstSeenAt())
    }

    private func errorMessage(_ data: Data) -> String {
        (try? JSONDecoder().decode(ErrorBody.self, from: data).message) ?? ""
    }
}

private struct ClaimRequest: Encodable {
    let publicId: String
    let appUserId: String
    let code: String
    let firstSeenAt: String

    enum CodingKeys: String, CodingKey {
        case publicId = "public_id"
        case appUserId = "app_user_id"
        case code
        case firstSeenAt = "first_seen_at"
    }
}

private struct ClaimResponse: Decodable {
    let status: String
    let appUserId: String

    enum CodingKeys: String, CodingKey {
        case status
        case appUserId = "app_user_id"
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let data: T
}

private struct ErrorBody: Decodable {
    let message: String
}
