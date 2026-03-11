import SwiftUI
import AVKit

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var tempImage: UIImage?
    @State private var tempVideoURL: URL?
    @State private var isServerConnected: Bool? = nil  // nil = loading

    var body: some View {
        VStack(spacing: 24) {

            // Server status badge
            serverStatusBadge

            previewSection

            Button(action: {
                viewModel.openCamera()
            }) {
                Text("Tag media")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if viewModel.selectedMedia != nil {
                HStack(spacing: 12) {
                    Button("Tag nyt") {
                        viewModel.clearMedia()
                        viewModel.openCamera()
                    }

                    Button("Brug dette") {
                        print("Brug valgt media")
                    }

                    Button("Analyser") {
                        print("Analyser valgt media")
                    }
                }
            }
        }
        .padding()
        .task {
            await checkServer()
        }
        .fullScreenCover(isPresented: $viewModel.showImagePicker) {
            ImagePicker(
                image: Binding(
                    get: { tempImage },
                    set: { newImage in
                        tempImage = newImage
                        if let newImage {
                            viewModel.setImage(newImage)
                        }
                    }
                ),
                videoURL: Binding(
                    get: { tempVideoURL },
                    set: { newVideoURL in
                        tempVideoURL = newVideoURL
                        if let newVideoURL {
                            viewModel.setVideo(newVideoURL)
                        }
                    }
                ),
                sourceType: .camera
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Server Status Badge
    @ViewBuilder
    private var serverStatusBadge: some View {
        HStack(spacing: 6) {
            if let connected = isServerConnected {
                Circle()
                    .fill(connected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(connected ? "Server forbundet" : "Server utilgængelig")
                    .font(.caption)
                    .foregroundColor(connected ? .green : .red)
            } else {
                ProgressView().scaleEffect(0.6)
                Text("Forbinder...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(20)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Preview Section
    @ViewBuilder
    private var previewSection: some View {
        switch viewModel.selectedMedia {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)

        case .video(let url):
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 300)
                .cornerRadius(12)

        case nil:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 300)
                .overlay(
                    Text("Ingen media valgt")
                        .foregroundColor(.gray)
                )
        }
    }

    // MARK: - Network
    private func checkServer() async {
        do {
            isServerConnected = try await NetworkService.shared.checkHealth()
        } catch {
            isServerConnected = false
        }
    }
}

#Preview {
    CameraView()
}
