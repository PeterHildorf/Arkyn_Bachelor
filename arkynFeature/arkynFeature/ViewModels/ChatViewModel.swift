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
    @Published var conversationId: String?
    @Published var errorMessage: String?
    
    // MARK: - Send Message
    func sendMessage(withImage imageData: Data? = nil) async {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil else {
            return
        }
        
        // Add user message to chat
        let userMessage = ChatMessage(
            content: currentMessage,
            isFromUser: true,
            imageData: imageData
        )
        messages.append(userMessage)
        
        let messageToSend = currentMessage
        currentMessage = "" // Clear input field
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkService.shared.sendChatMessage(
                message: messageToSend,
                imageData: imageData,
                conversationId: conversationId
            )
            
            // Update conversation ID if new
            if conversationId == nil {
                conversationId = response.conversationId
            }
            
            // Add assistant response
            let assistantMessage = ChatMessage(
                content: response.reply,
                isFromUser: false
            )
            messages.append(assistantMessage)
            
        } catch {
            errorMessage = "Kunne ikke sende besked: \(error.localizedDescription)"
            print("Chat error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        conversationId = nil
        currentMessage = ""
        errorMessage = nil
    }
    
    // MARK: - Delete Message
    func deleteMessage(_ message: ChatMessage) {
        messages.removeAll { $0.id == message.id }
    }
}
