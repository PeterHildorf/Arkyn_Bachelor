import SwiftUI

struct LoadingHintBubble: View {
    let hint: String
    @State private var dotPhase = 0

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(hint)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                HStack(spacing: 5) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.secondary.opacity(dotPhase == i ? 1.0 : 0.3))
                            .frame(width: 7, height: 7)
                            .animation(
                                .easeInOut(duration: 0.45).repeatForever(autoreverses: false).delay(Double(i) * 0.15),
                                value: dotPhase
                            )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            Spacer()
        }
        .onAppear {
            withAnimation {
                dotPhase = 1
            }
        }
    }
}
