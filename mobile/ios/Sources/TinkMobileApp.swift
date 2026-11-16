import SwiftUI
import UserNotifications

@main
struct TinkMobileApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = TinkModel()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section("连接设置") {
                        TextField("https://tink.example.com", text: $model.serverInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Bearer Secret Key", text: $model.tokenInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("保存并连接") { model.saveAndConnect() }
                        Button("发送测试消息") { model.sendTest() }
                            .disabled(model.serverInput.isEmpty || model.tokenInput.isEmpty)
                        Label(model.status, systemImage: "antenna.radiowaves.left.and.right")
                        if !model.errorText.isEmpty {
                            Text(model.errorText)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }

                    Section {
                        Text("当前版本仅在 App 前台通过 SSE 实时接收通知。熄屏及后台推送需要后续接入 APNs。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("消息记录 · 本机最多 250 条") {
                        if model.messages.isEmpty {
                            Text("暂无通知。连接后可发送测试消息。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.title.isEmpty ? "Tink" : message.title)
                                    .font(.headline)
                                if !message.body.isEmpty {
                                    Text(message.body)
                                        .font(.subheadline)
                                }
                                if let group = message.group, !group.isEmpty {
                                    Text(group)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let timestamp = message.timestamp {
                                    Text(timestamp, format: .dateTime.year().month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let url = message.safeURL {
                                    Link("打开链接", destination: url)
                                        .font(.footnote)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .navigationTitle("Tink Mobile")
            }
            .task { model.start() }
            .onChange(of: scenePhase) { _, newValue in
                switch newValue {
                case .active: model.start()
                case .background: model.stop()
                default: break
                }
            }
        }
    }
}
