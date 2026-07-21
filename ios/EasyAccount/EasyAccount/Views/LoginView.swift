import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: EasyAccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                card
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 480)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [EATheme.green, EATheme.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: EATheme.green.opacity(0.25), radius: 14, y: 8)
                Text("¥")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 6)

            Text("智能记账")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(EATheme.label)

            Text(
                vm.authMode == .register
                    ? "注册账号后即可记账，账本按用户隔离。"
                    : "登录后查余额、记流水；账本按账号隔离。"
            )
            .font(.system(size: 15))
            .foregroundStyle(EATheme.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            authTabs

            VStack(alignment: .leading, spacing: 8) {
                Text("用户名")
                    .font(.system(size: 12))
                    .foregroundStyle(EATheme.secondary)
                TextField("例如 rocky", text: $vm.loginName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(vm.loginBusy)
                    .padding(12)
                    .background(Color(red: 249 / 255, green: 249 / 255, blue: 251 / 255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                Text("密码")
                    .font(.system(size: 12))
                    .foregroundStyle(EATheme.secondary)
                HStack(spacing: 8) {
                    Group {
                        if vm.showPassword {
                            TextField("支持英文、数字与符号", text: $vm.loginPassword)
                        } else {
                            SecureField("支持英文、数字与符号", text: $vm.loginPassword)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(vm.loginBusy)
                    .padding(12)
                    .background(Color(red: 249 / 255, green: 249 / 255, blue: 251 / 255))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )

                    Button(vm.showPassword ? "隐藏" : "显示") {
                        vm.showPassword.toggle()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(EATheme.blue)
                    .disabled(vm.loginBusy)
                }

                Button {
                    vm.submitAuth()
                } label: {
                    Text(primaryButtonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(EATheme.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .opacity(vm.canSubmitAuth ? 1 : 0.45)
                }
                .disabled(!vm.canSubmitAuth)
                .padding(.top, 4)
            }

            Button {
                vm.switchAuthMode(vm.authMode == .register ? .login : .register)
            } label: {
                Text(vm.authMode == .register ? "已有账号？去登录" : "没有账号？去注册")
                    .font(.system(size: 14))
                    .foregroundStyle(EATheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .disabled(vm.loginBusy)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.showAdvanced.toggle()
                }
            } label: {
                Text(vm.showAdvanced ? "收起设置" : "连接设置")
                    .font(.system(size: 14))
                    .foregroundStyle(EATheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            if vm.showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HTTP Base")
                        .font(.system(size: 12))
                        .foregroundStyle(EATheme.secondary)
                    TextField("http://127.0.0.1:8088", text: $vm.httpBase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(red: 249 / 255, green: 249 / 255, blue: 251 / 255))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("WebSocket")
                        .font(.system(size: 12))
                        .foregroundStyle(EATheme.secondary)
                    TextField("ws://127.0.0.1:8088", text: $vm.wsUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(red: 249 / 255, green: 249 / 255, blue: 251 / 255))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.top, 4)
            }

            if !vm.authError.isEmpty {
                Text(vm.authError)
                    .font(.system(size: 14))
                    .foregroundStyle(EATheme.danger)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(EATheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var authTabs: some View {
        HStack(spacing: 4) {
            tabButton(title: "登录", mode: .login)
            tabButton(title: "注册", mode: .register)
        }
        .padding(4)
        .background(EATheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tabButton(title: String, mode: AuthMode) -> some View {
        Button {
            vm.switchAuthMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(vm.authMode == mode ? EATheme.label : EATheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.authMode == mode ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: vm.authMode == mode ? .black.opacity(0.06) : .clear, radius: 2, y: 1)
        }
        .disabled(vm.loginBusy)
        .buttonStyle(.plain)
    }

    private var primaryButtonTitle: String {
        if vm.loginBusy {
            return vm.authMode == .register ? "注册中…" : "登录中…"
        }
        return vm.authMode == .register ? "注册并进入" : "登录"
    }
}
