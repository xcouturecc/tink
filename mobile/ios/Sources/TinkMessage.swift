import Foundation

struct TinkMessage: Codable, Identifiable {
    let id: UInt64
    let title: String
    let body: String
    let group: String?
    let url: String?
    let createdAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, title, body, group, url
        case createdAt = "created_at"
    }

    var timestamp: Date? {
        guard let createdAt, createdAt > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(createdAt) / 1_000)
    }

    var safeURL: URL? {
        guard let url, let parsed = URL(string: url), parsed.scheme == "https" else { return nil }
        return parsed
    }
}

struct TinkEvent {
    var name = ""
    var id: String?
    var parts: [String] = []

    mutating func parse(_ line: String) {
        if line.hasPrefix("event:") {
            name = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("id:") {
            id = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let raw = String(line.dropFirst(5))
            parts.append(raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw)
        }
    }

    var notification: TinkMessage? {
        guard name == "notification", !parts.isEmpty else { return nil }
        return try? JSONDecoder().decode(TinkMessage.self, from: Data(parts.joined(separator: "\n").utf8))
    }
}
