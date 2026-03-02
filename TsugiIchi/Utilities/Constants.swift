import Foundation

enum Constants {
    /// Maximum number of Steps that can be scheduled in a single week.
    static let maxWeeklySlots = 10

    /// Number of Steps auto-placed during weekly review.
    static let reviewAutoPlaceCount = 3

    /// Default duration (minutes) for a manually created Step.
    static let defaultStepDurationMin = 30

    /// Default AI proxy endpoint URL (placeholder – user must configure their own proxy).
    static let defaultAIProxyURL = "https://your-proxy.example.com"

    /// Default AI proxy auth token (empty = no auth).
    static let defaultAIAuthToken = ""
}
