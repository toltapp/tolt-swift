import Foundation

public struct ClaimResult: Equatable, Sendable {
    public enum Status: String, Sendable {
        case claimed
        case alreadyClaimed = "already_claimed"
    }

    public let status: Status
    public let appUserId: String
}
