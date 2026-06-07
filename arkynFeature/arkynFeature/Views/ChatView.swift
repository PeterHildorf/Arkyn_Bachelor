import AVKit
import SwiftUI

struct ChatView: View {
    enum PickerSource: Identifiable {
        case camera
        case photoLibrary
        
        var id: Int {
            switch self {
            case .camera: return 1
            case .photoLibrary: return 2
            }
        }
        
        var uiKitType: UIImagePickerController.SourceType {
            switch self {
            case .camera: return .camera
            case .photoLibrary: return .photoLibrary
            }
        }
    }

    @StateObject private var viewModel = ChatViewModel()
    @State private var activePickerSource: PickerSource? = nil
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?

    @AppStorage("preferredLanguage") private var preferredLanguage: String = "da"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    if viewModel.messages.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "photo.viewfinder")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)
                            Text("Arkyn Analyse")
                                .font(.title3).bold()
                            Text("Start en ny maskinanalyse ved at vælge et billede eller en video af maskinens typeskilt.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                    } else {
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
                            if let targetId = viewModel.scrollTargetId, let anchor = viewModel.scrollAnchor {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(targetId, anchor: anchor)
                                }
                            } else {
                                scrollToBottom(proxy: proxy)
                            }
                        }
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
                    Group {
                        if let connected = viewModel.isServerConnected {
                            Image(systemName: "network")
                                .foregroundColor(connected ? .green : .red)
                                .font(.system(size: 18, weight: .semibold))
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
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
            .fullScreenCover(item: $activePickerSource) { source in
                ImagePicker(
                    image: $selectedImage,
                    videoURL: $selectedVideoURL,
                    sourceType: source.uiKitType
                )
                .ignoresSafeArea()
            }
            .task {
                await viewModel.checkServer()
            }
            .onChange(of: selectedImage) {
                if let image = selectedImage {
                    selectedImage = nil
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        Task {
                            await viewModel.extractImage(imageData)
                        }
                    }
                }
            }
            .onChange(of: selectedVideoURL) {
                if let url = selectedVideoURL {
                    selectedVideoURL = nil
                    Task {
                        await viewModel.extractVideo(url)
                    }
                }
            }
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 12) {
            // Kamera-knap
            Button {
                activePickerSource = .camera
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Kamera")
                }
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            
            // Galleri-knap
            Button {
                activePickerSource = .photoLibrary
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Galleri")
                }
                .font(.subheadline).bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Scroll Helper
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(last.id, anchor: .bottom)
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
    ChatView()
}
