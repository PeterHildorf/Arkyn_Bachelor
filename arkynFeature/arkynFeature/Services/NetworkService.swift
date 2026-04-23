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

    // MARK: - API v1: Extract Entities
    func extract(imageData: Data) async throws -> ExtractionResult {
        guard let url = URL(string: "\(baseURL)/api/v1/extract") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data), let msg = errorBody["error"] {
                throw NetworkError.serverError(msg)
            }
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ExtractionResult.self, from: data)
    }

    // MARK: - API v1: Analyze Target
    func analyze(targetLabel: String, targetValue: String, context: [ExtractedEntity]) async throws -> MaintenanceGuidance {
        guard let url = URL(string: "\(baseURL)/api/v1/analyze") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Find best machine model
        let modelEntity = context.first { $0.label.lowercased() == "model" || $0.label.lowercased() == "maskinmodel" }
        let machineModel = modelEntity?.value ?? targetValue

        let requestBody = AnalyzeRequest(
            targetLabel: targetLabel,
            targetValue: targetValue,
            machineModel: machineModel,
            context: context
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data), let msg = errorBody["error"] {
                throw NetworkError.serverError(msg)
            }
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(MaintenanceGuidance.self, from: data)
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
