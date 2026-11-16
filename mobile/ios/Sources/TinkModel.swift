import Foundation
import SwiftUI
import UserNotifications

/** Tink iOS foreground connection. Background and terminated-state delivery needs APNs. */
@MainActor
final class TinkModel: ObservableObject {
    @Published var serverInput: String
    @Published var tokenInput: String
    @Published private(set) var status = "未连接"
    @Published private(set) var errorText = ""
    @Published private(set) var messages: [TinkMessage]

    private let preferences = UserDefaults.standard
    private var streamTask: Task<Void, Never>?
    private let historyKey = "tink_mobile_history"
    private let serverKey = "tink_mobile_server"
    private let deviceKey = "tink_mobile_device"
    private let cursorKey = "tink_mobile_cursor"

    init() {
        serverInput = UserDefaults.standard.string(forKey: "tink_mobile_server") ?? ""
        tokenInput = KeychainStore.read()
        if let data = UserDefaults.standard.data(forKey: "tink_mobile_history"),
           let stored = try? JSONDecoder().decode([TinkMessage].self, from: data) {
            messages = stored
        } else {
            messages = []
        }
    }

    var deviceID: String {
        if let existing = preferences.string(forKey: deviceKey) { return existing }
        let identifier = UUID().uuidString
        preferences.set(identifier, forKey: deviceKey)
        return identifier
    }

    private var server: URL? {
        let normalized = serverInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: normalized),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/"
        else { return nil }
        return url
    }

    func saveAndConnect() {
        guard let server, !tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "请填写 HTTPS 服务器根地址和 Bearer Secret Key"
            return
        }
        do {
            try KeychainStore.save(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            errorText = "无法将密钥存入 Keychain"
            return
        }
        stop()
        serverInput = server.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        preferences.set(serverInput, forKey: serverKey)
        preferences.set("0", forKey: cursorKey)
        messages = []
        persist()
        errorText = ""
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        start()
    }

    func start() {
        guard streamTask == nil else { return }
        guard server != nil, !KeychainStore.read().isEmpty else {
            status = "等待配置"
            return
        }
        status = "准备连接…"
        streamTask = Task { [weak self] in
            await self?.connectLoop()
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        status = "已暂停（后台）"
    }

    private func connectLoop() async {
        var failures = 0
        while !Task.isCancelled {
            guard let server else { break }
            let token = KeychainStore.read()
            let currentDevice = deviceID
            do {
                status = "注册设备…"
                try await TinkAPI.register(server: server, token: token, deviceID: currentDevice)
                var request = TinkAPI.request(
                    server: server, path: "/api/v1/events", token: token, deviceID: currentDevice
                )
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 3_600 // SSE heartbeat is 30s; avoid a 30s idle timeout.
                request.setValue(preferences.string(forKey: cursorKey) ?? "0", forHTTPHeaderField: "Last-Event-ID")
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                guard (200...299).contains(response.statusCode) else {
                    throw TinkHTTPError(status: response.statusCode)
                }
                status = "已连接（前台）"
                errorText = ""
                failures = 0
                var event = TinkEvent()
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    if line.trimmingCharacters(in: .newlines).isEmpty {
                        if let message = event.notification { receive(message, eventID: event.id) }
                        event = TinkEvent()
                    } else {
                        event.parse(line)
                    }
                }
                if !Task.isCancelled { errorText = "SSE 连接已关闭，正在重试" }
            } catch {
                if Task.isCancelled { break }
                if let failure = error as? TinkHTTPError, failure.authorizationFailed {
                    errorText = "认证失败，请检查 Bearer Secret Key"
                    status = "认证失败"
                    break
                }
                errorText = "暂时无法连接，将自动重试：" + error.localizedDescription
            }

            if Task.isCancelled { break }
            status = "重新连接…"
            let seconds = min(60, 1 << min(failures, 6))
            failures += 1
            try? await Task.sleep(for: .seconds(seconds))
        }
        if !Task.isCancelled { streamTask = nil }
    }

    private func receive(_ message: TinkMessage, eventID: String?) {
        if !messages.contains(where: { $0.id == message.id }) {
            messages.insert(message, at: 0)
            if messages.count > 250 { messages.removeLast(messages.count - 250) }
            persist()
            displayNotification(message)
        }
        preferences.set(eventID ?? String(message.id), forKey: cursorKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(messages) {
            preferences.set(data, forKey: historyKey)
        }
    }

    private func displayNotification(_ message: TinkMessage) {
        let content = UNMutableNotificationContent()
        content.title = message.title.isEmpty ? "Tink" : message.title
        content.body = message.body
        content.sound = .default
        if let url = message.safeURL { content.userInfo = ["url": url.absoluteString] }
        let request = UNNotificationRequest(
            identifier: "tink-" + String(message.id),
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    func sendTest() {
        guard let server else {
            errorText = "请先配置 HTTPS 服务器"
            return
        }
        Task {
            do {
                try await TinkAPI.test(
                    server: server, token: KeychainStore.read(), deviceID: deviceID
                )
                errorText = ""
            } catch {
                errorText = "测试消息发送失败：" + error.localizedDescription
            }
        }
    }
}
