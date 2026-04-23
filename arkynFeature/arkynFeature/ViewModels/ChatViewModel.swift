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

    // MARK: - Phase 1: Extract Image
    func extractImage(_ imageData: Data) async {
        // Show the captured image as a user message
        let userMessage = ChatMessage(
            kind: .text(""),
            isFromUser: true,
            imageData: imageData
        )
        messages.append(userMessage)
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.extract(imageData: imageData)

            let assistantMessage: ChatMessage
            if response.flaggedForReview {
                assistantMessage = ChatMessage(
                    kind: .flagged(reason: "Billedkvaliteten eller OCR-confidence er for lav. Tag et nyt, tydeligt billede."),
                    isFromUser: false
                )
            } else {
                assistantMessage = ChatMessage(
                    kind: .extractedEntities(entities: response.entities, context: response.entities),
                    isFromUser: false
                )
            }
            messages.append(assistantMessage)

        } catch {
            errorMessage = "Udtrækning fejlede: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Phase 2: Analyze Entity
    func analyzeEntity(_ entity: ExtractedEntity, context: [ExtractedEntity]) async {
        isLoading = true
        errorMessage = nil
        
        // Optionally show what the user requested
        messages.append(ChatMessage(text: "Analyser \(entity.label): \(entity.value)", isFromUser: true))

        do {
            let response = try await NetworkService.shared.analyze(
                targetLabel: entity.label,
                targetValue: entity.value,
                context: context
            )
            
            let assistantMessage = ChatMessage(
                kind: .guidance(response),
                isFromUser: false
            )
            messages.append(assistantMessage)
        } catch {
            errorMessage = "Analyse fejlede: \(error.localizedDescription)"
        }
        
        isLoading = false
    }

    // MARK: - Send Plain Text Message (legacy / chat endpoint)
    func sendMessage(withImage imageData: Data? = nil) async {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil else {
            return
        }

        // If image is provided and no text, route through /extract instead
        if let imageData = imageData, currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await extractImage(imageData)
            return
        }

        let userMessage = ChatMessage(text: currentMessage, isFromUser: true, imageData: imageData)
        messages.append(userMessage)

        let messageToSend = currentMessage
        currentMessage = ""
        isLoading = true
        errorMessage = nil

        do {
            let response = try await NetworkService.shared.sendChatMessage(
                message: messageToSend,
                imageData: imageData
            )
            let assistantMessage = ChatMessage(text: response.reply, isFromUser: false)
            messages.append(assistantMessage)
        } catch {
            errorMessage = "Kunne ikke sende besked: \(error.localizedDescription)"
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
}
