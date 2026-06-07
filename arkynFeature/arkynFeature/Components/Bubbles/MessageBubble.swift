import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    let onAnalyze: (ExtractedEntity, [ExtractedEntity]) -> Void
    let onRetry: (UUID, RetryContext) -> Void

    var body: some View {
        switch message.kind {
        case .text(let text):
            PlainTextBubble(
                text: text, isFromUser: message.isFromUser,
                imageData: message.imageData, videoURL: message.videoURL, timestamp: message.timestamp)

        case .extractedEntities(let entities, let context):
            EntitiesBubble(
                entities: entities, context: context, timestamp: message.timestamp,
                onAnalyze: onAnalyze)

        case .guidance(let response):
            GuidanceBubble(response: response, timestamp: message.timestamp)

        case .flagged(let reason):
            FlaggedBubble(reason: reason, timestamp: message.timestamp)

        case .loading(let hint):
            LoadingHintBubble(hint: hint)

        case .error(let reason, let context):
            ErrorBubble(
                reason: reason, timestamp: message.timestamp,
                onRetry: {
                    onRetry(message.id, context)
                })
        }
    }
}
