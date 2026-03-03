import Foundation

// MARK: - Request

/// Payload sent to the AI proxy endpoint.
struct AIRequestPayload: Codable {
    let goalTitle: String
    let goalNote: String?
    let category: String?
    let constraints: String?
}

// MARK: - Response

/// Top-level response from the AI proxy.
struct AIResponse: Codable {
    let steps: [AIStepResult]
    /// Remaining AI credits returned by the Proxy (M11+). Nil when Proxy doesn't support it yet.
    let remaining: Int?
    /// How the Proxy verified Pro status (M12). e.g. "apple_jws_verified", "header_fallback", etc.
    let verificationMethod: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.steps = try container.decode([AIStepResult].self, forKey: .steps)
        self.remaining = try container.decodeIfPresent(Int.self, forKey: .remaining)
        self.verificationMethod = try container.decodeIfPresent(String.self, forKey: .verificationMethod)
    }

    private enum CodingKeys: String, CodingKey {
        case steps, remaining, verificationMethod
    }
}

/// A single Step suggestion returned by AI.
struct AIStepResult: Codable, Identifiable {
    var id = UUID()
    let title: String
    let type: String          // "調べる|予約する|用意する|行く|作る|連絡する"
    let durationMin: Int
    let dueSuggestion: String? // "today|this_week|none"
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title, type, durationMin, dueSuggestion, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(String.self, forKey: .type)
        self.durationMin = try container.decode(Int.self, forKey: .durationMin)
        self.dueSuggestion = try container.decodeIfPresent(String.self, forKey: .dueSuggestion)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    init(title: String, type: String, durationMin: Int, dueSuggestion: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.durationMin = durationMin
        self.dueSuggestion = dueSuggestion
        self.notes = notes
    }
}
