//
//  ChatViewModel.swift
//  arkynFeature
//
//  Created by Peter Hannibal Hildorf on 17/03/2026.
//

import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var scrollTrigger: Int = 0
    @Published var scrollTargetId: UUID?
    @Published var scrollAnchor: UnitPoint?
    @Published var isServerConnected: Bool? = nil

    @AppStorage("preferredLanguage") var preferredLanguage: String = "da"

    // MARK: - Phase 1: Extract Image
    func extractImage(_ imageData: Data, replaceMessageId: UUID? = nil) async {
        let placeholderId: UUID
        
        if let existingId = replaceMessageId {
            placeholderId = existingId
            let placeholder = ChatMessage(id: placeholderId, kind: .loading(hint: "Analyserer billede…"), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = placeholder
            }
        } else {
            let userMessage = ChatMessage(kind: .text(""), isFromUser: true, imageData: imageData)
            placeholderId = UUID()
            let placeholder = ChatMessage(
                id: placeholderId,
                kind: .loading(hint: "Analyserer billede…"),
                isFromUser: false
            )
            messages.append(contentsOf: [userMessage, placeholder])
        }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.extract(imageData: imageData)

            let result: ChatMessage
            if response.flaggedForReview {
                result = ChatMessage(
                    id: placeholderId,
                    kind: .flagged(reason: "Billedkvaliteten eller OCR-confidence er for lav. Tag et nyt, tydeligt billede."),
                    isFromUser: false
                )
            } else {
                result = ChatMessage(
                    id: placeholderId,
                    kind: .extractedEntities(entities: response.entities, context: response.entities),
                    isFromUser: false
                )
            }
            // Replace placeholder in-place — no new row, no flicker
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = result
                triggerScroll(forServerMessageId: placeholderId)
            }
        } catch {
            let errorMsg = ChatMessage(id: placeholderId, kind: .error(reason: "Udtrækning fejlede: \(error.localizedDescription)", context: .extractImage(imageData: imageData)), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = errorMsg
                triggerScroll(forServerMessageId: placeholderId)
            }
        }

        isLoading = false
    }

    // MARK: - Phase 1: Extract Video
    func extractVideo(_ videoURL: URL, replaceMessageId: UUID? = nil) async {
        let placeholderId: UUID
        
        if let existingId = replaceMessageId {
            placeholderId = existingId
            let placeholder = ChatMessage(id: placeholderId, kind: .loading(hint: "Analyserer video…"), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = placeholder
            }
        } else {
            let userMessage = ChatMessage(text: "", isFromUser: true, videoURL: videoURL)
            placeholderId = UUID()
            let placeholder = ChatMessage(
                id: placeholderId,
                kind: .loading(hint: "Analyserer video…"),
                isFromUser: false
            )
            messages.append(contentsOf: [userMessage, placeholder])
        }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.extract(videoURL: videoURL)

            let result: ChatMessage
            if response.flaggedForReview {
                result = ChatMessage(
                    id: placeholderId,
                    kind: .flagged(reason: "Billedkvaliteten eller OCR-confidence er for lav. Tag en ny, tydelig video."),
                    isFromUser: false
                )
            } else {
                result = ChatMessage(
                    id: placeholderId,
                    kind: .extractedEntities(entities: response.entities, context: response.entities),
                    isFromUser: false
                )
            }
            // Replace placeholder in-place
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = result
                triggerScroll(forServerMessageId: placeholderId)
            }
        } catch {
            let errorMsg = ChatMessage(id: placeholderId, kind: .error(reason: "Udtrækning fejlede: \(error.localizedDescription)", context: .extractVideo(videoURL: videoURL)), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = errorMsg
                triggerScroll(forServerMessageId: placeholderId)
            }
        }

        isLoading = false
    }

    // MARK: - Phase 2: Analyze Entity
    func analyzeEntity(_ entity: ExtractedEntity, context: [ExtractedEntity], replaceMessageId: UUID? = nil) async {
        let placeholderId: UUID
        
        if let existingId = replaceMessageId {
            placeholderId = existingId
            let placeholder = ChatMessage(id: placeholderId, kind: .loading(hint: "Henter vedligeholdelsesvejledning…"), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = placeholder
            }
        } else {
            let userMessage = ChatMessage(text: "Analyser \(entity.label): \(entity.value)", isFromUser: true)
            placeholderId = UUID()
            let placeholder = ChatMessage(
                id: placeholderId,
                kind: .loading(hint: "Henter vedligeholdelsesvejledning…"),
                isFromUser: false
            )
            messages.append(contentsOf: [userMessage, placeholder])
        }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.analyze(
                targetLabel: entity.label,
                targetValue: entity.value,
                context: context,
                language: preferredLanguage
            )
            let result = ChatMessage(id: placeholderId, kind: .guidance(response), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = result
                triggerScroll(forServerMessageId: placeholderId)
            }
        } catch {
            let errorMsg = ChatMessage(id: placeholderId, kind: .error(reason: "Analyse fejlede: \(error.localizedDescription)", context: .analyzeEntity(entity: entity, context: context)), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = errorMsg
                triggerScroll(forServerMessageId: placeholderId)
            }
        }

        isLoading = false
    }

    // MARK: - Send Plain Text Message
    func sendMessage(withImage imageData: Data? = nil, replaceMessageId: UUID? = nil) async {
        let text = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only guard against empty message if we are NOT retrying
        if replaceMessageId == nil {
            guard !text.isEmpty || imageData != nil else { return }
        }

        // Image-only → route through extract
        if let imageData, text.isEmpty && replaceMessageId == nil {
            await extractImage(imageData)
            return
        }

        let placeholderId: UUID
        if let existingId = replaceMessageId {
            placeholderId = existingId
            let placeholder = ChatMessage(id: placeholderId, kind: .loading(hint: "Sender besked…"), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = placeholder
            }
        } else {
            let userMessage = ChatMessage(text: text, isFromUser: true, imageData: imageData)
            placeholderId = UUID()
            let placeholder = ChatMessage(
                id: placeholderId,
                kind: .loading(hint: "Sender besked…"),
                isFromUser: false
            )
            messages.append(contentsOf: [userMessage, placeholder])
            currentMessage = ""
        }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.sendChatMessage(message: text, imageData: imageData)
            let result = ChatMessage(id: placeholderId, kind: .text(response.reply), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = result
                triggerScroll(forServerMessageId: placeholderId)
            }
        } catch {
            let errorMsg = ChatMessage(id: placeholderId, kind: .error(reason: "Kunne ikke sende besked: \(error.localizedDescription)", context: .sendChatMessage(text: text, imageData: imageData)), isFromUser: false)
            if let idx = messages.firstIndex(where: { $0.id == placeholderId }) {
                messages[idx] = errorMsg
                triggerScroll(forServerMessageId: placeholderId)
            }
        }

        isLoading = false
    }

    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        currentMessage = ""
        errorMessage = nil
    }

    // MARK: - Delete Message
    func deleteMessage(_ message: ChatMessage) {
        messages.removeAll { $0.id == message.id }
    }
    
    // MARK: - Retry
    func retry(messageId: UUID, context: RetryContext) async {
        switch context {
        case .extractImage(let imageData):
            await extractImage(imageData, replaceMessageId: messageId)
        case .extractVideo(let videoURL):
            await extractVideo(videoURL, replaceMessageId: messageId)
        case .analyzeEntity(let entity, let context):
            await analyzeEntity(entity, context: context, replaceMessageId: messageId)
        case .sendChatMessage(let text, let imageData):
            // Temporarily set currentMessage so sendMessage can read it
            let previousMessage = currentMessage
            currentMessage = text
            await sendMessage(withImage: imageData, replaceMessageId: messageId)
            currentMessage = previousMessage
        }
    }

    // MARK: - Health Check
    func checkServer() async {
        do {
            isServerConnected = try await NetworkService.shared.checkHealth()
        } catch {
            isServerConnected = false
        }
    }
    
    // MARK: - Scroll Helper
    private func triggerScroll(forServerMessageId serverId: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == serverId }) else { return }
        
        var targetId = serverId
        var anchor: UnitPoint = .bottom
        
        // Find the closest user message before this server message
        for i in (0..<idx).reversed() {
            if messages[i].isFromUser {
                targetId = messages[i].id
                anchor = .top
                break
            }
        }
        
        self.scrollTargetId = targetId
        self.scrollAnchor = anchor
        self.scrollTrigger += 1
    }
}

