import SwiftUI
import UserNotifications

private enum TinkPalette {
    static let blue = Color(red: 0.21, green: 0.42, blue: 1)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

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
                TinkHomeView(model: model)
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

private struct TinkHomeView: View {
    @ObservedObject var model: TinkModel

    private var connected: Bool { model.status.contains("已连接") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image("TinkMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .accessibilityLabel("Tink Logo")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tink")
                            .font(.largeTitle.bold())
                        Text("你的消息，实时触达")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Text("服务器连接")
                            .font(.title3.bold())
                        Spacer()
                        Text(model.status)
                            .font(.caption.bold())
                            .foregroundStyle(connected ? Color.green : Color.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                connected ? Color.green.opacity(0.12) : Color.gray.opacity(0.12),
                                in: Capsule()
                            )
                    }

                    VStack(spacing: 12) {
                        TextField("https://tink.example.com", text: $model.serverInput)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .tinkInput(label: "服务器 HTTPS 地址")
                        SecureField("Bearer Secret Key", text: $model.tokenInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .tinkInput(label: "访问密钥")
                    }

                    Button {
                        model.saveAndConnect()
                    } label: {
                        Text("保存并连接")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TinkPalette.blue)

                    Button {
                        model.sendTest()
                    } label: {
                        Text("发送测试通知")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.serverInput.isEmpty || model.tokenInput.isEmpty)

                    if !model.errorText.isEmpty {
                        Label(model.errorText, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding(18)
                .background(TinkPalette.card, in: RoundedRectangle(cornerRadius: 22))

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(TinkPalette.blue)
                    Text("当前版本仅在 App 前台通过 SSE 接收消息。锁屏与后台推送将在后续版本接入。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TinkPalette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Text("消息中心")
                        .font(.title2.bold())
                    Spacer()
                    Text("共 \(model.messages.count) 条")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if model.messages.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 30))
                            .foregroundStyle(TinkPalette.blue)
                        Text("还没有新消息")
                            .font(.headline)
                        Text("连接服务器后发送一条测试通知")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(TinkPalette.card, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(message.title.isEmpty ? "Tink" : message.title)
                                    .font(.headline)
                                if !message.body.isEmpty {
                                    Text(message.body)
                                        .font(.subheadline)
                                }
                                if let group = message.group, !group.isEmpty {
                                    Text(group)
                                        .font(.caption.bold())
                                        .foregroundStyle(TinkPalette.blue)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(TinkPalette.card, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(TinkPalette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Tink Mobile")
                    .font(.headline)
            }
        }
    }
}

private struct TinkInputModifier: ViewModifier {
    let label: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
                .padding(13)
                .background(
                    Color(uiColor: .tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
    }
}

private extension View {
    func tinkInput(label: String) -> some View {
        modifier(TinkInputModifier(label: label))
    }
}
