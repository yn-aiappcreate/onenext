import Foundation

// MARK: - Error

enum AIServiceError: LocalizedError {
    case networkUnavailable(underlying: Error)
    case serverError(statusCode: Int)
    case rateLimited(retryAfter: Int?)
    case invalidJSON(underlying: Error)
    case emptySteps
    case proxyURLMissing
    case creditsExhausted

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "ネットワーク接続を確認してください")
        case .serverError(let code):
            return String(localized: "サーバーエラーが発生しました（\(code)）")
        case .rateLimited(let retry):
            if let retry {
                return String(localized: "しばらく待ってから再度お試しください（\(retry)秒後）")
            }
            return String(localized: "しばらく待ってから再度お試しください")
        case .invalidJSON:
            return String(localized: "AIの応答を解釈できませんでした")
        case .emptySteps:
            return String(localized: "ステップを生成できませんでした")
        case .proxyURLMissing:
            return String(localized: "AIエンドポイントURLが設定されていません")
        case .creditsExhausted:
            return String(localized: "AIクレジットの残りがありません")
        }
    }
}

// MARK: - Service

/// Handles communication with the AI proxy endpoint.
enum AIService {

    /// Result returned by `generateSteps`, containing both the steps and optional remaining credits.
    struct GenerateResult {
        let steps: [AIStepResult]
        let remaining: Int?
    }

    /// Generate Step suggestions by calling the proxy endpoint.
    /// - Parameters:
    ///   - payload: The request payload (goal info).
    ///   - endpointURL: The proxy base URL string.
    /// - Returns: A `GenerateResult` containing AI step suggestions and optional remaining credits.
    static func generateSteps(
        payload: AIRequestPayload,
        endpointURL: String,
        authToken: String = ""
    ) async throws -> GenerateResult {
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
        // Send device preferred language so the Worker can generate prompts in the right language
        let preferredLang = Locale.preferredLanguages.first ?? "ja"
        request.setValue(preferredLang, forHTTPHeaderField: "Accept-Language")
        // Send client ID for credit tracking (M11 Proxy uses this)
        request.setValue(ClientId.current, forHTTPHeaderField: "X-Client-Id")
        // Send Pro status and purchased credits so Proxy can apply correct limits (MVP: trusted)
        let isPro = await EntitlementStore.shared.isPro
        request.setValue(isPro ? "true" : "false", forHTTPHeaderField: "X-Is-Pro")
        let purchased = await CreditsStore.shared.purchasedCredits
        request.setValue(String(purchased), forHTTPHeaderField: "X-Purchased-Credits")
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
        case 403:
            throw AIServiceError.creditsExhausted
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

        return GenerateResult(steps: decoded.steps, remaining: decoded.remaining)
    }
}
