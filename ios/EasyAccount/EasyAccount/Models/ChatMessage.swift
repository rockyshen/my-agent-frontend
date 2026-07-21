import Foundation

enum ChatMessageKind: String, Equatable {
    case system
    case assistant
    case user
    case error
}

struct ChatMessage: Identifiable, Equatable {
    let id: Int
    var kind: ChatMessageKind
    var text: String
    var streaming: Bool = false
}

enum ServerEventType: String, Decodable {
    case connected
    case messageDelta = "message_delta"
    case messageEnd = "message_end"
    case error
}

struct ServerEvent: Decodable {
    let type: ServerEventType
    let content: String?
    let message: String?
}

struct ChatOutbound: Encodable {
    let type: String
    let content: String
}
