import Foundation

// MARK: - Error

enum AIServiceError: LocalizedError {
    case networkUnavailable(underlying: Error)
    case serverError(statusCode: Int)
    case rateLimited(retryAfter: Int?)
    case invalidJSON(underlying: Error)
    case emptySteps
    case proxyURLMissing

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "ネットワーク接続を確認してください"
        case .serverError(let code):
            return "サーバーエラーが発生しました（\(code)）"
        case .rateLimited(let retry):
            if let retry {
                return "しばらく待ってから再度お試しください（\(retry)秒後）"
            }
            return "しばらく待ってから再度お試しください"
        case .invalidJSON:
            return "AIの応答を解釈できませんでした"
        case .emptySteps:
            return "ステップを生成できませんでした"
        case .proxyURLMissing:
            return "AIエンドポイントURLが設定されていません"
        }
    }
}

// MARK: - Service

/// Handles communication with the AI proxy endpoint.
enum AIService {

    /// Generate Step suggestions by calling the proxy endpoint.
    /// - Parameters:
    ///   - payload: The request payload (goal info).
    ///   - endpointURL: The proxy base URL string.
    /// - Returns: An array of AI step suggestions.
    static func generateSteps(
        payload: AIRequestPayload,
        endpointURL: String,
        authToken: String = ""
    ) async throws -> [AIStepResult] {
        guard let baseURL = URL(string: endpointURL),
              !endpointURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AIServiceError.proxyURLMissing
        }

        let url = baseURL.appendingPathComponent("generate-steps")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.networkUnavailable(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkUnavailable(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Int($0) }
            throw AIServiceError.rateLimited(retryAfter: retryAfter)
        case 400...499:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoded: AIResponse
        do {
            let decoder = JSONDecoder()
            decoded = try decoder.decode(AIResponse.self, from: data)
        } catch {
            throw AIServiceError.invalidJSON(underlying: error)
        }

        guard !decoded.steps.isEmpty else {
            throw AIServiceError.emptySteps
        }

        return decoded.steps
    }
}
