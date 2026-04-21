import Foundation

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "http://130.225.170.229:8080"

    private init() {}

    // MARK: - Health Check
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        let (_, response) = try await URLSession.shared.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Analyze OCR Text
    /// Sends ocr_text + confidence to POST /analyze and returns the structured response.
    func analyze(ocrText: String, confidence: Double, mimeType: String = "image/jpeg") async throws -> AnalyzeResponse {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // Claude kan tage ~40 sek

        let body = AnalyzeRequest(ocrText: ocrText, confidence: confidence, mimeType: mimeType)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            // Forsøg at parse fejlbesked fra server
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let message = errorBody["error"] {
                throw NetworkError.serverError(message)
            }
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AnalyzeResponse.self, from: data)
    }

    // MARK: - Legacy Chat (bevares til evt. brug)
    func sendChatMessage(message: String, imageData: Data? = nil, conversationId: String? = nil) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let imageBase64 = imageData?.base64EncodedString()
        let chatRequest = ChatRequest(message: message, imageData: imageBase64, conversationId: conversationId)
        request.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}

// MARK: - Custom Errors
enum NetworkError: LocalizedError {
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return "Serverfejl: \(msg)"
        }
    }
}
