import SwiftUI

struct FlaggedBubble: View {
    let reason: String
    let timestamp: Date

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("Manuel kontrol påkrævet")
                        .font(.footnote).bold()
                        .foregroundColor(.orange)
                }

                Text(reason)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Billedkvaliteten er for lav til automatisk analyse. Tag et nyt, tydeligt billede af maskinens label.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.orange.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(16)
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }
}
