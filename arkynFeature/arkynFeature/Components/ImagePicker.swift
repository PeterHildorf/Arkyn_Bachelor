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
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        
        picker.mediaTypes = [
            UTType.image.identifier,
            UTType.movie.identifier
        ]
        
        picker.videoQuality = .typeMedium
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
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
