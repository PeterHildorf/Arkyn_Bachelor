//
//  ImagePicker.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 10/03/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var videoURL: URL?

    var sourceType: UIImagePickerController.SourceType = .camera

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType =
            UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary

        picker.mediaTypes = [
            UTType.image.identifier,
            UTType.movie.identifier,
        ]

        picker.videoQuality = .typeMedium
        picker.allowsEditing = false

        // Add UX Overlay if it's the camera
        if picker.sourceType == .camera {
            let overlayView = UIHostingController(rootView: CameraOverlayView())
            overlayView.view.backgroundColor = .clear
            // Pass touches through the overlay down to the camera controls
            overlayView.view.isUserInteractionEnabled = false

            // Set frame to UIScreen bounds to cover the camera area
            overlayView.view.frame = UIScreen.main.bounds

            picker.cameraOverlayView = overlayView.view
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {

            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
                parent.videoURL = nil
            } else if let selectedVideoURL = info[.mediaURL] as? URL {
                parent.videoURL = selectedVideoURL
                parent.image = nil
            }

            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Camera UX Overlay
struct CameraOverlayView: View {
    @State private var isVisible = true

    var body: some View {
        VStack {
            if isVisible {
                VStack(spacing: 12) {
                    // Et større ikon (du kan også prøve "panorama" for et andet fedt look)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)

                    Text("Panorer over store labels, fra venstre mod højre")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.orange.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.top, 60)  // Placed at the top, just below safe area
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .onAppear {
                    // Auto-hide after 6 seconds so it disappears before/while they film
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isVisible = false
                        }
                    }
                }
            }

            Spacer()
        }
    }
}
