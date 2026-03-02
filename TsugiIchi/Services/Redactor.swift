import Foundation

/// Simple PII redactor for email, phone, and postal code patterns.
enum Redactor {

    struct RedactionResult {
        let masked: String
        let changes: [(original: String, replacement: String)]
    }

    /// Redact email, phone, and postal-code patterns from the input string.
    static func redact(_ text: String) -> RedactionResult {
        var result = text
        var changes: [(String, String)] = []

        // Email pattern
        let emailPattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let original = String(result[range])
                    let replacement = "[EMAIL]"
                    changes.append((original, replacement))
                    result.replaceSubrange(range, with: replacement)
                }
            }
        }

        // Japanese phone pattern (e.g. 090-1234-5678, 03-1234-5678)
        let phonePattern = #"0\d{1,4}[\-\s]?\d{1,4}[\-\s]?\d{3,4}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let original = String(result[range])
                    let replacement = "[PHONE]"
                    changes.append((original, replacement))
                    result.replaceSubrange(range, with: replacement)
                }
            }
        }

        // Japanese postal code pattern (e.g. 〒123-4567 or 123-4567)
        let postalPattern = #"〒?\d{3}-?\d{4}"#
        if let regex = try? NSRegularExpression(pattern: postalPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let range = Range(match.range, in: result) {
                    let original = String(result[range])
                    let replacement = "[ADDRESS]"
                    changes.append((original, replacement))
                    result.replaceSubrange(range, with: replacement)
                }
            }
        }

        return RedactionResult(masked: result, changes: changes)
    }
}
