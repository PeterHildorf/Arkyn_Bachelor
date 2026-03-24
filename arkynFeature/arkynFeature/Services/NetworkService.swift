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

    // MARK: - Analyze Image
    func analyze(imageData: Data) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return data
    }
    
    // MARK: - Chat
    func sendChatMessage(message: String, imageData: Data? = nil, conversationId: String? = nil) async throws -> ChatResponse {
        guard let url = URL(string: "\(baseURL)/chat") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert image to Base64 if present
        let imageBase64 = imageData?.base64EncodedString()
        
        let chatRequest = ChatRequest(
            message: message,
            imageData: imageBase64,
            conversationId: conversationId
        )
        
        request.httpBody = try JSONEncoder().encode(chatRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        return chatResponse
    }
}
