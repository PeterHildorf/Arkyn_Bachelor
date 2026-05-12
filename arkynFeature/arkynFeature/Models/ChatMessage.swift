//
//  ChatMessage.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 17/03/2026.
//

import Foundation

// MARK: - Message Kind
enum MessageKind {
    case text(String)
    case extractedEntities(entities: [ExtractedEntity], context: [ExtractedEntity])
    case guidance(MaintenanceGuidance)
    case flagged(reason: String)
    case loading(hint: String)
    case error(reason: String, context: RetryContext)
}

enum RetryContext {
    case extractImage(imageData: Data)
    case extractVideo(videoURL: URL)
    case analyzeEntity(entity: ExtractedEntity, context: [ExtractedEntity])
    case sendChatMessage(text: String, imageData: Data?)
}

struct ChatMessage: Identifiable {
    let id: UUID
    let kind: MessageKind
    let isFromUser: Bool
    let timestamp: Date
    var imageData: Data?
    var videoURL: URL?

    // Convenience: plain-text content
    var textContent: String {
        switch kind {
        case .text(let t):       return t
        case .extractedEntities(let e, _): return "Extracted \(e.count) entities"
        case .guidance(let g):   return g.equipmentContext
        case .flagged(let r):    return r
        case .loading(let hint): return hint
        case .error(let reason, _): return reason
        }
    }

    init(id: UUID = UUID(), kind: MessageKind, isFromUser: Bool, timestamp: Date = Date(), imageData: Data? = nil, videoURL: URL? = nil) {
        self.id = id
        self.kind = kind
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.imageData = imageData
        self.videoURL = videoURL
    }

    init(text: String, isFromUser: Bool, imageData: Data? = nil, videoURL: URL? = nil) {
        self.init(kind: .text(text), isFromUser: isFromUser, imageData: imageData, videoURL: videoURL)
    }
}

// MARK: - New API Models

enum AllowedAction: String, Codable, Equatable {
    case copy = "copy"
    case maps = "maps"
    case search = "search"
    case analyze = "analyze"
}

struct ExtractedEntity: Codable, Identifiable, Equatable {
    var id: String { label }
    let label: String
    let value: String
    let actions: [AllowedAction]
}

struct ExtractionResult: Codable {
    let entities: [ExtractedEntity]
    let rawText: String
    let confidence: Double
    let flaggedForReview: Bool

    enum CodingKeys: String, CodingKey {
        case entities
        case rawText = "raw_text"
        case confidence
        case flaggedForReview = "flagged_for_review"
    }
}

struct AnalyzeRequest: Codable {
    let targetLabel: String
    let targetValue: String
    let machineModel: String
    let context: [ExtractedEntity]
    let language: String
    
    enum CodingKeys: String, CodingKey {
        case targetLabel = "target_label"
        case targetValue = "target_value"
        case machineModel = "machine_model"
        case context
        case language
    }
}

struct ChatResponse: Codable {
    let reply: String
}

struct MaintenanceGuidance: Codable {
    let targetLabel: String
    let targetValue: String
    let equipmentContext: String
    let generalGuidance: [String]
    let safetyNotes: [String]
    let sourceReferences: [String]?
    let uncertaintyLevel: String

    enum CodingKeys: String, CodingKey {
        case targetLabel = "target_label"
        case targetValue = "target_value"
        case equipmentContext = "equipment_context"
        case generalGuidance = "general_guidance"
        case safetyNotes = "safety_notes"
        case sourceReferences = "source_references"
        case uncertaintyLevel = "uncertainty_level"
    }
}
