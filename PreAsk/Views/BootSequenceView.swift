import SwiftUI

struct BootSequenceView: View {
    @State private var titleOpacity: Double = 0
    @State private var dotOpacity: Double = 0
    @State private var statusOpacity: Double = 0
    @State private var statusText = "Connecting..."
    @Binding var hasCompleted: Bool
    let waveHeights: [CGFloat]

    var body: some View {
        ZStack {
            Theme.darkSection.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Text("PreAsk")
                        .font(Theme.display(64))
                        .foregroundColor(.white)
                        .opacity(titleOpacity)

                    HStack(spacing: 0) {
                        Text(".")
                            .font(Theme.display(64))
                            .foregroundColor(Theme.red)
                            .opacity(dotOpacity)
                    }
                    .padding(.leading, 230)
                }

                HStack(spacing: 2) {
                    ForEach(Array(waveHeights.enumerated()), id: \.offset) { _, h in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 2, height: h)
                    }
                }
                .frame(height: 24)
                .padding(.top, 40)
                .opacity(titleOpacity)

                Spacer()

                Text(statusText)
                    .font(Theme.caption(13))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(statusOpacity)
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear { startSequence() }
    }

    private func startSequence() {
        withAnimation(.easeOut(duration: 0.8)) {
            titleOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) { dotOpacity = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { statusOpacity = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { statusText = "Ready." }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.4)) { hasCompleted = true }
        }
    }
}
