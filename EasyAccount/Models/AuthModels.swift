import Foundation

struct AuthUser: Codable, Equatable, Identifiable {
    var id: String?
    var name: String?

    var displayName: String {
        (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name
    }

    init(id: String?, name: String?) {
        self.id = id
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decodeIfPresent(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = nil
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
    }
}

struct AuthSessionResponse: Codable {
    let token: String
    let user: AuthUser?
}

struct AuthErrorBody: Codable {
    let message: String?
}

struct APIError: Error, LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { message }
}
