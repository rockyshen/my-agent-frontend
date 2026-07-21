import SwiftUI

struct EasyAccountRootView: View {
    @EnvironmentObject private var vm: EasyAccountViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch vm.stage {
                case .bootstrapping:
                    CenterStatusView(text: "正在恢复登录状态…")
                case .login:
                    LoginView()
                case .connecting:
                    CenterStatusView(text: "正在连接记账助手…")
                case .live:
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(EATheme.background.ignoresSafeArea())
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(vm.stage == .live && !vm.connected ? EATheme.orange : EATheme.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("智能记账助手")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(EATheme.label)
                if let subtitle = vm.headerSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(EATheme.secondary)
                }
            }

            Spacer(minLength: 0)

            if vm.stage == .live || vm.stage == .connecting {
                Button("退出") { vm.logoutTapped() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EATheme.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(EATheme.background.opacity(0.92))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }
}

struct CenterStatusView: View {
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(EATheme.blue)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(EATheme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
