import Foundation

struct Passwords {
    let hex: String           // 64 chars, 0-9 A-F
    let ascii: String         // 63 chars, printable ASCII including special chars
    let alphanumeric: String  // 63 chars, a-z A-Z 0-9 only
}

@MainActor
final class PasswordFetcher: ObservableObject {
    @Published var passwords: Passwords?
    @Published var isLoading = false
    @Published var error: String?

    private let sourceURL = URL(string: "https://www.grc.com/passwords.htm")!

    func fetch() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            defer { isLoading = false }
            do {
                var request = URLRequest(url: sourceURL)
                request.setValue(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                    forHTTPHeaderField: "User-Agent"
                )
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let html = String(data: data, encoding: .utf8)
                               ?? String(data: data, encoding: .isoLatin1) else {
                    error = "Could not decode server response."
                    return
                }
                if let parsed = parsePasswords(from: html) {
                    passwords = parsed
                } else {
                    error = "Could not parse passwords from page.\nThe page structure may have changed."
                }
            } catch {
                self.error = "Network error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Parsing

    private func parsePasswords(from html: String) -> Passwords? {
        let text = cleanHTML(html)

        // 1. Extract 64-char uppercase hex (256-bit)
        //    Must be surrounded by non-hex characters so we don't clip a longer run.
        guard let hex = firstMatch(
            pattern: #"(?<![0-9A-Fa-f])([0-9A-F]{64})(?![0-9A-Fa-f])"#,
            in: text, group: 1
        ) else { return nil }

        // 2. Extract 63-char alphanumeric (letters + digits only, no specials)
        guard let alnum = firstMatch(
            pattern: #"(?<![a-zA-Z0-9])([a-zA-Z0-9]{63})(?![a-zA-Z0-9])"#,
            in: text, group: 1
        ) else { return nil }

        // 3. Extract 63-char printable ASCII password (contains at least one special char)
        //    [!-~] = all printable ASCII from 0x21 (!) to 0x7E (~)
        guard let ascii = extractASCIIPassword(from: text, excluding: [hex, alnum]) else {
            return nil
        }

        return Passwords(hex: hex, ascii: ascii, alphanumeric: alnum)
    }

    /// Strips HTML tags and decodes common HTML entities.
    private func cleanHTML(_ html: String) -> String {
        var text = html
        // Drop script/style blocks first so their content doesn't pollute the search
        text = text.replacingOccurrences(
            of: #"<script[^>]*>[\s\S]*?</script>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"<style[^>]*>[\s\S]*?</style>"#, with: " ", options: .regularExpression)
        // Remove zero-width line-break hints (<wbr>, <wbr/>) with nothing — they appear
        // inside long password strings and would otherwise split them when tags are stripped.
        text = text.replacingOccurrences(
            of: #"<wbr\s*/?>"#, with: "", options: .regularExpression)
        // Strip all remaining HTML tags
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        // Decode common HTML entities (order matters: &amp; last to avoid double-decode)
        let entities: [(String, String)] = [
            ("&lt;",   "<"),
            ("&gt;",   ">"),
            ("&quot;", "\""),
            ("&#39;",  "'"),
            ("&apos;", "'"),
            ("&#96;",  "`"),
            ("&#124;", "|"),
            ("&nbsp;", " "),
            ("&shy;",  ""),   // soft hyphen — invisible line-break hint, strip it
            ("&#173;", ""),   // &shy; numeric form
            ("&amp;",  "&"),
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        // Decode numeric entities: &#NNN; and &#xHH;
        text = decodeNumericEntities(text)
        return text
    }

    private func decodeNumericEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"&#(x[0-9A-Fa-f]+|[0-9]+);"#) else {
            return text
        }
        var result = ""
        var lastEnd = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let matchRange = Range(match.range, in: text),
                  let valueRange = Range(match.range(at: 1), in: text) else { continue }
            result += text[lastEnd..<matchRange.lowerBound]
            let valueStr = String(text[valueRange])
            let codepoint: UInt32?
            if valueStr.hasPrefix("x") || valueStr.hasPrefix("X") {
                codepoint = UInt32(valueStr.dropFirst(), radix: 16)
            } else {
                codepoint = UInt32(valueStr)
            }
            if let cp = codepoint, let scalar = Unicode.Scalar(cp) {
                result += String(scalar)
            } else {
                result += text[matchRange]
            }
            lastEnd = matchRange.upperBound
        }
        result += text[lastEnd...]
        return result
    }

    private func firstMatch(pattern: String, in text: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let idx = group < match.numberOfRanges ? group : 0
        guard let swiftRange = Range(match.range(at: idx), in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func extractASCIIPassword(from text: String, excluding: [String]) -> String? {
        // Find 63-char sequences of printable ASCII that contain at least one special char
        guard let regex = try? NSRegularExpression(pattern: #"([!-~]{63})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let swiftRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[swiftRange])
            guard !excluding.contains(candidate) else { continue }
            // Must have at least one non-alphanumeric character
            if candidate.range(of: #"[^a-zA-Z0-9]"#, options: .regularExpression) != nil {
                return candidate
            }
        }
        return nil
    }
}
