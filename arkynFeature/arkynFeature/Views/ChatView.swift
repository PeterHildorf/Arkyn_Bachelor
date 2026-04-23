//
//  ChatView.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 13/03/2026.
//
import SwiftUI
import AVKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @FocusState private var isTextFieldFocused: Bool

    let initialMedia: MediaType?
    let onDismiss: () -> Void

    init(initialMedia: MediaType? = nil, onDismiss: @escaping () -> Void = {}) {
        self.initialMedia = initialMedia
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, onAnalyze: { entity, context in
                                    Task {
                                        await viewModel.analyzeEntity(entity, context: context)
                                    }
                                })
                                    .id(message.id)
                            }

                            if viewModel.isLoading {
                                LoadingBubble()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isLoading) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isTextFieldFocused) {
                        if isTextFieldFocused { scrollToBottom(proxy: proxy) }
                    }
                }

                // Error Banner
                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.12))
                }

                Divider()
                inputArea
            }
            .navigationTitle("Arkyn Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Luk") { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    image: $selectedImage,
                    videoURL: .constant(nil),
                    sourceType: .photoLibrary
                )
            }
            .task {
                if let media = initialMedia, viewModel.messages.isEmpty {
                    await sendInitialMedia(media)
                }
            }
        }
    }

    // MARK: - Send Initial Media
    private func sendInitialMedia(_ media: MediaType) async {
        switch media {
        case .image(let image):
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                await viewModel.extractImage(imageData)
            }

        case .video(let url):
            if let thumbnail = await extractThumbnail(from: url),
               let imageData = thumbnail.jpegData(compressionQuality: 0.8) {
                await viewModel.extractImage(imageData)
            }
        }
    }

    // MARK: - Scroll Helper
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if viewModel.isLoading {
            // Scroll to a fixed anchor when loading indicator is visible
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("loading-indicator", anchor: .bottom)
            }
        } else if let last = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Extract Thumbnail
    private func extractThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1.0, preferredTimescale: 60)

        return await withCheckedContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                if let error = error {
                    print("Thumbnail extraction error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let cgImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 8) {
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    Spacer()
                    Button {
                        selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                }
                .padding(.vertical, 2)
                .disabled(viewModel.isLoading)

                TextField("Skriv en besked...", text: $viewModel.currentMessage, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)
                    .focused($isTextFieldFocused)

                Button {
                    Task {
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        isTextFieldFocused = false
                        await viewModel.sendMessage(withImage: imageData)
                        selectedImage = nil
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
                .disabled(!canSend || viewModel.isLoading)
                .padding(.vertical, 6)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
}

// MARK: - Loading Bubble
struct LoadingBubble: View {
    @State private var dotPhase = 0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary.opacity(dotPhase == i ? 1.0 : 0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: dotPhase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            Spacer()
        }
        .id("loading-indicator")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                dotPhase = 1
            }
        }
    }
}

// MARK: - Message Bubble (dispatcher)
struct MessageBubble: View {
    let message: ChatMessage
    let onAnalyze: (ExtractedEntity, [ExtractedEntity]) -> Void

    var body: some View {
        switch message.kind {
        case .text(let text):
            PlainTextBubble(text: text, isFromUser: message.isFromUser,
                            imageData: message.imageData, timestamp: message.timestamp)
                            
        case .extractedEntities(let entities, let context):
            EntitiesBubble(entities: entities, context: context, timestamp: message.timestamp, onAnalyze: onAnalyze)

        case .guidance(let response):
            GuidanceBubble(response: response, timestamp: message.timestamp)

        case .flagged(let reason):
            FlaggedBubble(reason: reason, timestamp: message.timestamp)
        }
    }
}

// MARK: - Plain Text Bubble
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

// MARK: - Entities Bubble
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
                            ScrollView(.horizontal, showsIndicators: false) {
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
                                    }
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

// MARK: - Guidance Bubble (struktureret AI-svar)
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

// MARK: - Flagged Bubble (lav OCR-confidence)
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

#Preview {
    ChatView {
        print("Dismissed")
    }
}
