import SwiftUI

struct GuidanceBubble: View {
    let response: MaintenanceGuidance
    let timestamp: Date

    var uncertaintyColor: Color {
        switch response.uncertaintyLevel.lowercased() {
        case "low":    return .green
        case "medium": return .orange
        case "high":   return .red
        default:       return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {

                // ── Header: udstyr ──
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(response.equipmentContext)
                        .font(.footnote).bold()
                        .foregroundColor(.primary)
                }

                Divider()

                // ── Vejledning ──
                if !response.generalGuidance.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Vejledning", systemImage: "list.bullet")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)

                        ForEach(response.generalGuidance, id: \.self) { point in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.top, 2)
                                Text(point)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // ── Sikkerhedsadvarsler ──
                if !response.safetyNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Sikkerhed", systemImage: "exclamationmark.shield.fill")
                            .font(.caption).bold()
                            .foregroundColor(.orange)

                        ForEach(response.safetyNotes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.top, 2)
                                Text(note)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
                }

                // ── Kilder ──
                if let sources = response.sourceReferences, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Kilder", systemImage: "link")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)

                        ForEach(sources, id: \.self) { source in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                                Text(source)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }

                // ── Usikkerhedsniveau ──
                HStack(spacing: 4) {
                    Circle()
                        .fill(uncertaintyColor)
                        .frame(width: 7, height: 7)
                    Text("Usikkerhed: \(response.uncertaintyLevel.capitalized)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

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
}
