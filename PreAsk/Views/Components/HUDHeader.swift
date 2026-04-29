import SwiftUI

struct HUDHeader: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(networkMonitor.apiReachable ? Theme.red : Theme.divider)
                .frame(width: 6, height: 6)
            Text(networkMonitor.apiReachable ? "Online" : "Offline")
                .font(Theme.caption())
                .foregroundColor(Theme.textSecondary)
        }
    }
}
