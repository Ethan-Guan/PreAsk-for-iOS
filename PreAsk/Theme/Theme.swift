import SwiftUI

// MARK: - 极简编辑风配色体系
struct Theme {
    // 背景
    static let background = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let surface = Color.white
    static let surfaceAlt = Color(red: 0.97, green: 0.97, blue: 0.97)
    static let darkSection = Color.black                     // 黑色区块
    static let graySection = Color(red: 0.10, green: 0.10, blue: 0.10)    // 深灰色区块

    // 文字
    static let textPrimary = Color.black
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let textMuted = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let textOnDark = Color.white

    // 红色点缀
    static let red = Color(red: 0.95, green: 0.2, blue: 0.2)

    // 分隔
    static let divider = Color(red: 0.88, green: 0.88, blue: 0.88)

    // 圆角
    static let rMini: CGFloat = 4
    static let rSmall: CGFloat = 8
    static let rMedium: CGFloat = 16
    static let rLarge: CGFloat = 24
    static let rSheet: CGFloat = 28

    // MARK: 字体
    static func display(_ size: CGFloat = 64) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func heading(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    static func subheading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func bodyBold(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
    static func giantNumber(_ size: CGFloat = 80) -> Font {
        .system(size: size, weight: .ultraLight, design: .default)
    }

    // MARK: 稳定随机（避免每次重绘波动）
    static func stableWaveHeights(count: Int, min: CGFloat = 3, max: CGFloat = 28, seed: Int = 42) -> [CGFloat] {
        return (0..<count).map { i in
            var h = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
            h = h &* UInt64(bitPattern: Int64(i &+ 1)) &+ UInt64(bitPattern: Int64(seed))
            h = (h ^ (h &>> 33)) &* 0xff51afd7ed558ccd
            h = (h ^ (h &>> 33)) &* 0xc4ceb9fe1a85ec53
            h = h ^ (h &>> 33)
            let normalized = CGFloat(h % 10000) / 10000.0
            return min + (max - min) * normalized
        }
    }
}
