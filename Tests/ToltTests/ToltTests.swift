import XCTest
@testable import Tolt

final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
    nonisolated(unsafe) static var lastBody: [String: Any]?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            Self.lastBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        let (status, body) = Self.handler?(request) ?? (500, "{}")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ToltTests: XCTestCase {
    private var tolt: Tolt!
    private var defaults: UserDefaults!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        defaults = UserDefaults(suiteName: "tolt-tests-\(UUID().uuidString)")
        tolt = Tolt()
        tolt.configure(publicId: "pk_123", baseURL: URL(string: "https://platform.tolt.dev")!, session: URLSession(configuration: config), defaults: defaults)
    }

    func testClaimPostsTheCodeAndFirstSeenDate() async throws {
        var seen: URLRequest?
        StubProtocol.handler = { request in
            seen = request
            return (200, #"{"success":true,"data":{"status":"claimed","app_user_id":"user_42"}}"#)
        }

        let result = try await tolt.claim(code: " ANNA20 ", appUserId: "user_42")

        XCTAssertEqual(result, ClaimResult(status: .claimed, appUserId: "user_42"))
        XCTAssertEqual(seen?.url?.absoluteString, "https://platform.tolt.dev/client/claims")
        XCTAssertEqual(seen?.httpMethod, "POST")
        XCTAssertEqual(StubProtocol.lastBody?["public_id"] as? String, "pk_123")
        XCTAssertEqual(StubProtocol.lastBody?["code"] as? String, "ANNA20")
        XCTAssertEqual(StubProtocol.lastBody?["app_user_id"] as? String, "user_42")
        XCTAssertNotNil(StubProtocol.lastBody?["first_seen_at"] as? String)
    }

    func testSendsTheAppUserIdUnchanged() async throws {
        StubProtocol.handler = { _ in (200, #"{"success":true,"data":{"status":"claimed","app_user_id":" user_42 "}}"#) }
        _ = try await tolt.claim(code: "A", appUserId: " user_42 ")
        XCTAssertEqual(StubProtocol.lastBody?["app_user_id"] as? String, " user_42 ")
    }

    func testAlreadyClaimedIsNotAnError() async throws {
        StubProtocol.handler = { _ in (200, #"{"success":true,"data":{"status":"already_claimed","app_user_id":"u"}}"#) }
        let result = try await tolt.claim(code: "A", appUserId: "u")
        XCTAssertEqual(result.status, .alreadyClaimed)
    }

    func testMapsErrors() async {
        StubProtocol.handler = { _ in (404, #"{"success":false,"message":"Code not found","code":"not_found"}"#) }
        await assertThrows(.codeNotFound)
        StubProtocol.handler = { _ in (409, #"{"success":false,"message":"The window to claim a code has closed for this user","code":"conflict"}"#) }
        await assertThrows(.codeConflict("The window to claim a code has closed for this user"))
        StubProtocol.handler = { _ in (429, "{}") }
        await assertThrows(.rateLimited)
    }

    func testRejectsBlankInputWithoutCallingTheServer() async {
        StubProtocol.handler = { _ in
            XCTFail("should not call the server")
            return (500, "{}")
        }
        await assertThrows(.invalidInput("code"), code: "  ")
    }

    func testRequiresConfiguration() async {
        do {
            _ = try await Tolt().claim(code: "A", appUserId: "u")
            XCTFail("expected notConfigured")
        } catch {
            XCTAssertEqual(error as? ToltError, .notConfigured)
        }
    }

    func testFirstSeenDateIsStoredOnce() {
        let store = FirstSeenStore(defaults: defaults)
        let first = store.firstSeenAt(now: Date(timeIntervalSince1970: 100))
        let later = store.firstSeenAt(now: Date(timeIntervalSince1970: 999))
        XCTAssertEqual(first, later)
    }

    func testRevenueCatAttributes() {
        XCTAssertEqual(Tolt.revenueCatAttributes(code: " ANNA20 "), ["tolt_code": "ANNA20"])
    }

    private func assertThrows(_ expected: ToltError, code: String = "A", file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await tolt.claim(code: code, appUserId: "u")
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? ToltError, expected, file: file, line: line)
        }
    }
}
