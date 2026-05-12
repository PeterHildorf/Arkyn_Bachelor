import SwiftUI

struct ErrorBubble: View {
    let reason: String
    let timestamp: Date
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    Text("Netværksfejl")
                        .font(.footnote).bold()
                        .foregroundColor(.red)
                }

                Text(reason)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    onRetry()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Prøv igen")
                    }
                    .font(.caption).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                }
                .padding(.top, 4)

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.red.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(16)
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }
}
