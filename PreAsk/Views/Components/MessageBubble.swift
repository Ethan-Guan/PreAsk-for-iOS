import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        switch message.type {
        case .normal(let isUser):
            if isUser {
                HStack {
                    Spacer(minLength: 50)
                    Text(message.text)
                        .font(Theme.body(15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.rLarge)
                                .fill(Theme.darkSection)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                .padding(.horizontal, 24)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(Theme.red).frame(width: 6, height: 6)
                        Text("AI").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    }
                    Text(message.text)
                        .font(Theme.body(17))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 24)
            }
        case .error:
            HStack(spacing: 8) {
                Circle().fill(Theme.red).frame(width: 6, height: 6)
                Text(message.text).font(Theme.body(14)).foregroundColor(Theme.red)
            }
            .padding(.horizontal, 24)
        }
    }
}
