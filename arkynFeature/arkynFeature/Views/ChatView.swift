import AVKit
import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @FocusState private var isTextFieldFocused: Bool

    @AppStorage("preferredLanguage") private var preferredLanguage: String = "da"

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
                                MessageBubble(
                                    message: message,
                                    onAnalyze: { entity, context in
                                        Task {
                                            await viewModel.analyzeEntity(entity, context: context)
                                        }
                                    },
                                    onRetry: { id, context in
                                        Task {
                                            await viewModel.retry(messageId: id, context: context)
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.scrollTrigger) {
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
                            .textSelection(.enabled)
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
                    HStack {
                        Menu {
                            Button { preferredLanguage = "da" } label: {
                                Label("Dansk", systemImage: preferredLanguage == "da" ? "checkmark" : "")
                            }
                            Button { preferredLanguage = "en" } label: {
                                Label("English", systemImage: preferredLanguage == "en" ? "checkmark" : "")
                            }
                        } label: {
                            Image(systemName: "globe")
                        }
                        
                        Button {
                            viewModel.clearChat()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(viewModel.messages.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    image: $selectedImage,
                    videoURL: $selectedVideoURL,
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
            } else if selectedVideoURL != nil {
                HStack {
                    ZStack {
                        Color.black.opacity(0.8)
                        Image(systemName: "video.fill")
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    
                    Spacer()
                    Button {
                        selectedVideoURL = nil
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
                        isTextFieldFocused = false
                        let text = viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // If there is only a video and no text, run extractVideo
                        if let videoURL = selectedVideoURL, text.isEmpty {
                            let urlToUpload = videoURL
                            selectedVideoURL = nil
                            await viewModel.extractVideo(urlToUpload)
                        } else {
                            // Video in a chat message (with text) is currently not supported by backend chat endpoint
                            // So we just upload the image if present. We could ignore the video or handle it.
                            let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                            selectedImage = nil
                            selectedVideoURL = nil
                            await viewModel.sendMessage(withImage: imageData)
                        }
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
        !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedImage != nil || selectedVideoURL != nil
    }

    // MARK: - Send Initial Media
    private func sendInitialMedia(_ media: MediaType) async {
        switch media {
        case .image(let image):
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                await viewModel.extractImage(imageData)
            }

        case .video(let url):
            // Upload the full video directly to the server for processing
            await viewModel.extractVideo(url)
        }
    }

    // MARK: - Scroll Helper
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(last.id)
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
}

#Preview {
    ChatView {
        print("Dismissed")
    }
}
