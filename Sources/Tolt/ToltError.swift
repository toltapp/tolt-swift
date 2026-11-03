import Foundation

public enum ToltError: Error, Equatable {
    case notConfigured
    case invalidInput(String)
    case codeNotFound
    case codeConflict(String)
    case rateLimited
    case server(status: Int, message: String)
}
