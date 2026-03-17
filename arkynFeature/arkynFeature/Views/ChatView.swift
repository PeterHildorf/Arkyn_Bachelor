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
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .padding(.horizontal, 8)
                                    Text("Tænker...")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        // Auto-scroll to latest message
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isTextFieldFocused) {
                        // Auto-scroll when keyboard appears
                        if isTextFieldFocused {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                }
                
                Divider()
                
                // Input Area
                inputArea
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Luk") {
                        onDismiss()
                    }
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
                // Send initial media when view appears
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
            viewModel.currentMessage = "Hvad kan du se på dette billede?"
            let imageData = image.jpegData(compressionQuality: 0.8)
            await viewModel.sendMessage(withImage: imageData)
            
        case .video(let url):
            // Extract thumbnail from video
            if let thumbnail = await extractThumbnail(from: url) {
                viewModel.currentMessage = "Hvad kan du se på denne video?"
                let imageData = thumbnail.jpegData(compressionQuality: 0.8)
                await viewModel.sendMessage(withImage: imageData)
            } else {
                viewModel.currentMessage = "Jeg har optaget en video. Hvad kan jeg gøre med den?"
                await viewModel.sendMessage()
            }
        }
    }
    
    // MARK: - Scroll Helper
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    // MARK: - Extract Thumbnail
    private func extractThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Try to get frame at 1 second, or at start if video is shorter
        let time = CMTime(seconds: 1.0, preferredTimescale: 60)
        
        return await withCheckedContinuation { continuation in
            imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                if let error = error {
                    print("Error extracting thumbnail: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let cgImage = cgImage else {
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
            // Selected Image Preview
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
                // Image Picker Button
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
                
                // Text Input
                TextField("Skriv en besked...", text: $viewModel.currentMessage, axis: .vertical)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)
                    .focused($isTextFieldFocused)
                
                
                // Send Button
                Button {
                    Task {
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        isTextFieldFocused = false // Luk tastaturet
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

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // Image if present
                if let imageData = message.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(12)
                        .clipped()
                }
                
                // Message text
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(message.isFromUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(message.isFromUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isFromUser ? .trailing : .leading)
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView {
        print("Dismissed")
    }
}
