import SwiftUI

struct PlainTextBubble: View {
    let text: String
    let isFromUser: Bool
    let imageData: Data?
    let timestamp: Date

    var body: some View {
        HStack {
            if isFromUser { Spacer() }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                if let data = imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(12)
                        .clipped()
                }

                if !text.isEmpty {
                    Text(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isFromUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isFromUser ? .white : .primary)
                        .cornerRadius(16)
                }

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: isFromUser ? .trailing : .leading)

            if !isFromUser { Spacer() }
        }
    }
}
