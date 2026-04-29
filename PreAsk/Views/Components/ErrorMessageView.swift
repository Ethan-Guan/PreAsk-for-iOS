import SwiftUI

struct ErrorMessageView: View {
    let errorText: String

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.red).frame(width: 6, height: 6)
            Text(errorText).font(Theme.body(14)).foregroundColor(Theme.red)
        }
        .padding(.horizontal, 24)
    }
}
