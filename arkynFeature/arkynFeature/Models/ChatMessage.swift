//
//  ChatMessage.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 17/03/2026.
//

import Foundation

// MARK: - Message Kind
// A message can either be plain text or a structured guidance response from /analyze.
enum MessageKind {
    case text(String)
    case guidance(AnalyzeResponse)
    case flagged(reason: String)  // Low-confidence OCR, flagged for review
}

struct ChatMessage: Identifiable {
    let id: UUID
    let kind: MessageKind
    let isFromUser: Bool
    let timestamp: Date
    var imageData: Data?

    // Convenience: plain-text content for user messages or simple system messages
    var textContent: String {
        switch kind {
        case .text(let t):       return t
        case .guidance(let g):   return g.equipmentIdentification
        case .flagged(let r):    return r
        }
    }

    init(
        id: UUID = UUID(),
        kind: MessageKind,
        isFromUser: Bool,
        timestamp: Date = Date(),
        imageData: Data? = nil
    ) {
        self.id = id
        self.kind = kind
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.imageData = imageData
    }

    // Convenience init for plain-text messages (used frequently)
    init(text: String, isFromUser: Bool, imageData: Data? = nil) {
        self.init(kind: .text(text), isFromUser: isFromUser, imageData: imageData)
    }
}

// MARK: - /analyze Request Model
struct AnalyzeRequest: Codable {
    let ocrText: String
    let confidence: Double
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case ocrText     = "ocr_text"
        case confidence
        case mimeType    = "mime_type"
    }
}

// MARK: - /analyze Response Model
struct AnalyzeResponse: Codable {
    let status: String
    let equipmentIdentification: String
    let generalGuidance: [String]
    let safetyNotes: [String]
    let uncertaintyLevel: String
    let flaggedForReview: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case equipmentIdentification = "equipment_identification"
        case generalGuidance         = "general_guidance"
        case safetyNotes             = "safety_notes"
        case uncertaintyLevel        = "uncertainty_level"
        case flaggedForReview        = "flagged_for_review"
    }
}

// MARK: - Legacy Chat Models (behold til evt. /chat-endpoint)
struct ChatRequest: Codable {
    let message: String
    let imageData: String?
    let conversationId: String?
}

struct ChatResponse: Codable {
    let reply: String
    let conversationId: String
    let timestamp: String
}
