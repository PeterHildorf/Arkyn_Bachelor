import SwiftUI

struct GuidanceBubble: View {
    let response: MaintenanceGuidance
    let timestamp: Date

    @State private var isGuidanceExpanded: Bool = true
    @State private var isSafetyExpanded: Bool = true
    @State private var isSourcesExpanded: Bool = false

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
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isGuidanceExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Label("Vejledning", systemImage: "list.bullet")
                                    .font(.caption).bold()
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: isGuidanceExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if isGuidanceExpanded {
                            ForEach(response.generalGuidance, id: \.self) { point in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.blue)
                                        .padding(.top, 6)
                                    Text(point)
                                        .font(.footnote)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                // ── Sikkerhedsadvarsler ──
                if !response.safetyNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSafetyExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Label("Sikkerhed", systemImage: "exclamationmark.shield.fill")
                                    .font(.caption).bold()
                                    .foregroundColor(.orange)
                                Spacer()
                                Image(systemName: isSafetyExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .buttonStyle(.plain)

                        if isSafetyExpanded {
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(10)
                }

                // ── Kilder ──
                if let sources = response.sourceReferences, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSourcesExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Label("Kilder", systemImage: "link")
                                    .font(.caption).bold()
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: isSourcesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if isSourcesExpanded {
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
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
