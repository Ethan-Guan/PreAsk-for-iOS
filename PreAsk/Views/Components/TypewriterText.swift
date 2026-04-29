import SwiftUI

struct TypewriterText: View {
    let text: String
    let isUser: Bool
    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0

    var body: some View {
        Text(displayedText)
            .font(Theme.body(15))
            .foregroundColor(isUser ? .white : Theme.textPrimary)
            .onAppear { startTyping() }
    }

    private func startTyping() {
        guard currentIndex < text.count else { return }
        let idx = text.index(text.startIndex, offsetBy: currentIndex)
        let char = String(text[idx])
        if !char.isWhitespace { displayedText += char }
        currentIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { startTyping() }
    }
}

extension String {
    var isWhitespace: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func trimLastLine() -> String {
        let c = components(separatedBy: "\n")
        guard var last = c.last else { return self }
        last = last.trimmingCharacters(in: .whitespaces)
        return (c.dropLast() + [last]).joined(separator: "\n")
    }
    func trimEachLine() -> String {
        components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }
    var containsEmoji: Bool {
        for s in unicodeScalars {
            switch s.value {
            case 0x1F600...0x1F64F, 0x1F300...0x1F5FF, 0x1F680...0x1F6FF,
                 0x1F1E0...0x1F1FF, 0x2600...0x26FF, 0x2700...0x27BF,
                 0xFE00...0xFE0F, 0x1F900...0x1F9FF: return true
            default: continue
            }
        }
        return false
    }
}
