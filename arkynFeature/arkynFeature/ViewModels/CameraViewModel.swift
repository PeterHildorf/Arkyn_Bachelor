//
//  CameraViewModel.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 10/03/2026.
//

import SwiftUI

enum MediaType {
    case image(UIImage)
    case video(URL)
}

final class CameraViewModel: ObservableObject {
    @Published var selectedMedia: MediaType? = nil
    @Published var showImagePicker = false
    
    func openCamera() {
        showImagePicker = true
    }
    
    func setImage(_ image: UIImage?) {
        guard let image else {return}
        selectedMedia = .image(image)
    }
    
    func setVideo(_ url: URL?) {
        guard let url else {return}
        selectedMedia = .video(url)
    }
    
    func clearMedia() {
        selectedMedia = nil
    }
}
