import Foundation

struct TinkHTTPError: LocalizedError {
    let status: Int
    var errorDescription: String? { "Tink HTTP \(status)" }
    var authorizationFailed: Bool { status == 401 || status == 403 }
}

enum TinkAPI {
    static func request(
        server: URL,
        path: String,
        token: String,
        deviceID: String,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: server.appending(path: path))
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-ID")
        if let body {
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.timeoutInterval = 30
        return request
    }

    static func register(server: URL, token: String, deviceID: String) async throws {
        let payload = ["id": deviceID, "name": "iPhone / iPad"]
        let body = try JSONEncoder().encode(payload)
        let request = self.request(
            server: server, path: "/api/v1/devices", token: token, deviceID: deviceID, body: body
        )
        try await send(request)
    }

    static func test(server: URL, token: String, deviceID: String) async throws {
        let payload = TestPayload(
            title: "Tink iOS 测试",
            body: "客户端消息发送与接收测试",
            devices: [deviceID]
        )
        let request = self.request(
            server: server, path: "/api/v1/messages", token: token, deviceID: deviceID,
            body: try JSONEncoder().encode(payload)
        )
        try await send(request)
    }

    static func send(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(response.statusCode) else {
            throw TinkHTTPError(status: response.statusCode)
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.code == 0 else {
            throw TinkHTTPError(status: envelope.code)
        }
    }

    private struct Envelope: Decodable {
        let code: Int
    }

    private struct TestPayload: Encodable {
        let title: String
        let body: String
        let devices: [String]
    }
}
