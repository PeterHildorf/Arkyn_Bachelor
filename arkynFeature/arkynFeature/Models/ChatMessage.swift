//
//  ChatMessage.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 17/03/2026.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    var imageData: Data? // Til at sende billeder med beskeder
    
    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date(), imageData: Data? = nil) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.imageData = imageData
    }
}

// MARK: - API Request/Response Models
struct ChatRequest: Codable {
    let message: String
    let imageData: String? // Base64 encoded hvis der er et billede
    let conversationId: String?
}

struct ChatResponse: Codable {
    let reply: String
    let conversationId: String
    let timestamp: String
}
