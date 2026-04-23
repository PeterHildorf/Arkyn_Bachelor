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
}

struct ChatMessage: Identifiable {
    let id: UUID
    let kind: MessageKind
    let isFromUser: Bool
    let timestamp: Date
    var imageData: Data?

    // Convenience: plain-text content
    var textContent: String {
        switch kind {
        case .text(let t):       return t
        case .extractedEntities(let e, _): return "Extracted \(e.count) entities"
        case .guidance(let g):   return g.equipmentContext
        case .flagged(let r):    return r
        }
    }

    init(id: UUID = UUID(), kind: MessageKind, isFromUser: Bool, timestamp: Date = Date(), imageData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.imageData = imageData
    }

    init(text: String, isFromUser: Bool, imageData: Data? = nil) {
        self.init(kind: .text(text), isFromUser: isFromUser, imageData: imageData)
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
    
    enum CodingKeys: String, CodingKey {
        case targetLabel = "target_label"
        case targetValue = "target_value"
        case machineModel = "machine_model"
        case context
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
    let uncertaintyLevel: String

    enum CodingKeys: String, CodingKey {
        case targetLabel = "target_label"
        case targetValue = "target_value"
        case equipmentContext = "equipment_context"
        case generalGuidance = "general_guidance"
        case safetyNotes = "safety_notes"
        case uncertaintyLevel = "uncertainty_level"
    }
}
