import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var vm: EasyAccountViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: vm.messages) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            composer
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                vm.waitingReply ? "助手正在回复…" : "说点什么，例如：列出我的账户",
                text: $vm.inputText,
                axis: .vertical
            )
            .lineLimit(1...5)
            .disabled(vm.waitingReply || !vm.connected)
            .focused($inputFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .onSubmit {
                if vm.canSend { vm.sendChat() }
            }

            Button("发送") { vm.sendChat() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(EATheme.blue)
                .clipShape(Capsule())
                .opacity(vm.canSend ? 1 : 0.4)
                .disabled(!vm.canSend)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(EATheme.background.opacity(0.96))
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.kind {
        case .system:
            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(EATheme.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .center)

        case .assistant:
            VStack(alignment: .leading, spacing: 4) {
                Text("记账助手")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EATheme.green)
                    .tracking(0.4)
                Text(message.text + (message.streaming ? "▍" : ""))
                    .font(.system(size: 16))
                    .foregroundStyle(EATheme.label)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 18,
                    topTrailingRadius: 18,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 40)

        case .user:
            Text(message.text)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(EATheme.blue)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 6,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)

        case .error:
            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(EATheme.danger)
                .padding(12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
