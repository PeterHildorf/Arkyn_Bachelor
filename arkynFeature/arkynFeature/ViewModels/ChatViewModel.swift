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

    // MARK: - Analyze Image via /analyze
    /// Main entry point when a technician sends a captured image.
    /// Phase 1: uses a placeholder OCR result (confidence 1.0).
    /// Phase 4 will replace this with on-device Apple Vision OCR.
    func analyzeImage(_ imageData: Data) async {
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
            // --- Phase 4 placeholder ---
            // When Vision OCR is added, extract real text + confidence here.
            // For now we send a hardcoded label text so the full pipeline can be tested end-to-end.
            let placeholderOCRText = "Siemens SIMOTICS 1LE1001-1CB43-4FA4, 3-phase induction motor, 11 kW, 400V, 50Hz, IP55, IE3"
            let placeholderConfidence = 0.95
            // --- End placeholder ---

            let response = try await NetworkService.shared.analyze(
                ocrText: placeholderOCRText,
                confidence: placeholderConfidence
            )

            let assistantMessage: ChatMessage
            if response.flaggedForReview {
                assistantMessage = ChatMessage(
                    kind: .flagged(reason: response.safetyNotes.first ?? "OCR-tekst er usikker – kontrollér billedet manuelt."),
                    isFromUser: false
                )
            } else {
                assistantMessage = ChatMessage(
                    kind: .guidance(response),
                    isFromUser: false
                )
            }
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

        // If image is provided and no text, route through /analyze instead
        if let imageData = imageData, currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await analyzeImage(imageData)
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
