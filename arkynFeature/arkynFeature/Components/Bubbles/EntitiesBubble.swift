import SwiftUI

struct EntitiesBubble: View {
    let entities: [ExtractedEntity]
    let context: [ExtractedEntity]
    let timestamp: Date
    let onAnalyze: (ExtractedEntity, [ExtractedEntity]) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Ekstraherede Data")
                        .font(.footnote).bold()
                        .foregroundColor(.primary)
                }

                Divider()

                ForEach(entities) { entity in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entity.label)
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text(entity.value)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        if !entity.actions.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(entity.actions, id: \.self) { action in
                                    Button {
                                        handleAction(action, for: entity)
                                    } label: {
                                        Label(titleFor(action), systemImage: iconFor(action))
                                            .font(.caption2).bold()
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(colorFor(action).opacity(0.15))
                                            .foregroundColor(colorFor(action))
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if entity.id != entities.last?.id {
                            Divider().padding(.top, 4)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Text(timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }

    private func handleAction(_ action: AllowedAction, for entity: ExtractedEntity) {
        switch action {
        case .copy:
            UIPasteboard.general.string = entity.value
        case .maps:
            if let encoded = entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
        case .search:
            if let encoded = entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
        case .analyze:
            onAnalyze(entity, context)
        }
    }

    private func titleFor(_ action: AllowedAction) -> String {
        switch action {
        case .copy: return "Kopiér"
        case .maps: return "Kort"
        case .search: return "Søg"
        case .analyze: return "Analyser"
        }
    }

    private func iconFor(_ action: AllowedAction) -> String {
        switch action {
        case .copy: return "doc.on.doc"
        case .maps: return "map"
        case .search: return "magnifyingglass"
        case .analyze: return "sparkles"
        }
    }

    private func colorFor(_ action: AllowedAction) -> Color {
        switch action {
        case .copy: return .gray
        case .maps: return .green
        case .search: return .blue
        case .analyze: return .purple
        }
    }
}
