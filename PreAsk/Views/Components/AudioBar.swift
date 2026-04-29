import SwiftUI

struct AudioBar: View {
    @ObservedObject private var player = AudioPlayerManager.shared

    var body: some View {
        switch player.state {
        case .idle:
            EmptyView()
        case .loading:
            loadingView
        case .ready, .playing, .paused:
            playbackView
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - 加载中

    private var loadingView: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.red)
                .frame(width: 7, height: 7)
                .scaleEffect(1.2)
                .animation(.easeInOut(duration: 0.6).repeatForever(), value: true)

            Text("Generating voice...")
                .font(Theme.body(14))
                .foregroundColor(Theme.textOnDark.opacity(0.7))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Theme.darkSection)
    }

    // MARK: - 播放中 / 就绪 / 暂停

    private var playbackView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                playPauseButton

                VStack(spacing: 4) {
                    waveVisualization
                        .frame(height: 28)

                    HStack {
                        Text(player.synthesizedText)
                            .font(Theme.caption(13))
                            .foregroundColor(Theme.textOnDark.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        timeLabel
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            progressBar
        }
        .background(Theme.darkSection)
    }

    // MARK: - 播放/暂停按钮

    private var playPauseButton: some View {
        Button {
            switch player.state {
            case .playing: player.pause()
            case .ready, .paused: player.play()
            default: break
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Theme.red, lineWidth: 2)
                    .frame(width: 42, height: 42)

                Group {
                    if case .playing = player.state {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .padding(.leading, 2)
                    }
                }
                .foregroundColor(Theme.textOnDark)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 声波可视化

    private var waveVisualization: some View {
        GeometryReader { geo in
            let barCount = 24
            let barWidth: CGFloat = 2
            let spacing: CGFloat = 3
            let totalWidth = CGFloat(barCount) * (barWidth + spacing) - spacing
            let startX = (geo.size.width - totalWidth) / 2

            ZStack(alignment: .leading) {
                ForEach(0..<barCount, id: \.self) { i in
                    let fraction = CGFloat(i) / CGFloat(barCount - 1)
                    let baseH = sin(fraction * .pi) * 0.7 + 0.3
                    let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    let isPast = fraction <= progress

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPast ? Theme.red : Theme.textOnDark.opacity(0.25))
                        .frame(
                            width: barWidth,
                            height: baseH * geo.size.height
                        )
                        .position(
                            x: startX + CGFloat(i) * (barWidth + spacing) + barWidth / 2,
                            y: geo.size.height / 2
                        )
                        .animation(.easeOut(duration: 0.2), value: progress)
                }
            }
        }
    }

    // MARK: - 时间标签

    private var timeLabel: some View {
        Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Theme.textOnDark.opacity(0.5))
    }

    // MARK: - 进度条

    private var progressBar: some View {
        GeometryReader { geo in
            let progress = player.duration > 0 ? player.currentTime / player.duration : 0
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.textOnDark.opacity(0.1))
                    .frame(height: 2)

                Rectangle()
                    .fill(Theme.red)
                    .frame(width: max(0, geo.size.width * progress), height: 2)
                    .animation(.linear(duration: 0.05), value: player.currentTime)
            }
        }
        .frame(height: 2)
    }

    // MARK: - 错误状态

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.red)
                .frame(width: 6, height: 6)

            Text(message)
                .font(Theme.caption(13))
                .foregroundColor(Theme.red.opacity(0.8))
                .lineLimit(2)

            Spacer()

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textOnDark.opacity(0.5))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Theme.darkSection)
    }

    // MARK: - 格式化时间

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite else { return "0:00" }
        let min = Int(t) / 60
        let sec = Int(t) % 60
        return String(format: "%d:%02d", min, sec)
    }
}
