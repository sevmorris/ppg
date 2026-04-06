import Foundation

// MARK: - Model

struct Passwords {
    let hex: String           // 64 chars, 0–9 A–F
    let ascii: String         // 63 chars, printable ASCII including special chars
    let alphanumeric: String  // 63 chars, a–z A–Z 0–9 only
}

// MARK: - Parser

/// Extracts the three passwords from a GRC.com/passwords.htm HTML response.
/// All methods are internal so they can be covered by unit tests.
struct PasswordParser {

    func parse(html: String) -> Passwords? {
        let text = cleanHTML(html)

        // 1. 64-char uppercase hex (256-bit)
        guard let hex = firstMatch(
            pattern: #"(?<![0-9A-Fa-f])([0-9A-F]{64})(?![0-9A-Fa-f])"#,
            in: text, group: 1
        ) else { return nil }

        // 2. 63-char alphanumeric (letters + digits only)
        guard let alnum = firstMatch(
            pattern: #"(?<![a-zA-Z0-9])([a-zA-Z0-9]{63})(?![a-zA-Z0-9])"#,
            in: text, group: 1
        ) else { return nil }

        // 3. 63-char printable ASCII (must contain at least one special character)
        guard let ascii = extractASCIIPassword(from: text, excluding: [hex, alnum]) else {
            return nil
        }

        let result = Passwords(hex: hex, ascii: ascii, alphanumeric: alnum)
        return validate(result) ? result : nil
    }

    // MARK: - HTML Cleaning

    func cleanHTML(_ html: String) -> String {
        var text = html
        // Drop script/style blocks so their content doesn't pollute the search
        text = text.replacingOccurrences(
            of: #"<script[^>]*>[\s\S]*?</script>"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"<style[^>]*>[\s\S]*?</style>"#, with: " ", options: .regularExpression)
        // Remove <wbr> tags without substitution — they appear inside long password strings
        text = text.replacingOccurrences(
            of: #"<wbr\s*/?>"#, with: "", options: .regularExpression)
        // Strip all remaining HTML tags
        text = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        // Decode numeric entities BEFORE &amp; to prevent double-decode:
        // &amp;#39; → (numeric pass: no match) → (named pass: &amp; → &) → &#39; (literal)
        // rather than &amp;#39; → (named: &amp; → &) → &#39; → (numeric: → ') which is wrong.
        text = decodeNumericEntities(text)
        // Strip soft hyphens now materialised from &#173; numeric entities
        text = text.replacingOccurrences(of: "\u{AD}", with: "")
        // Decode named entities; &amp; must come last to avoid interfering with others
        let entities: [(String, String)] = [
            ("&lt;",   "<"),
            ("&gt;",   ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&shy;",  ""),  // named soft hyphen — invisible line-break hint, strip it
            ("&amp;",  "&"),
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text
    }

    func decodeNumericEntities(_ text: String) -> String {
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
                result += text[matchRange]  // leave unrecognised entity as-is
            }
            lastEnd = matchRange.upperBound
        }
        result += text[lastEnd...]
        return result
    }

    // MARK: - Private Helpers

    private func firstMatch(pattern: String, in text: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        let idx = group < match.numberOfRanges ? group : 0
        guard let swiftRange = Range(match.range(at: idx), in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func extractASCIIPassword(from text: String, excluding: [String]) -> String? {
        // [!-~] = all printable ASCII from 0x21 (!) to 0x7E (~)
        guard let regex = try? NSRegularExpression(pattern: #"([!-~]{63})"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let swiftRange = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[swiftRange])
            guard !excluding.contains(candidate) else { continue }
            if candidate.range(of: #"[^a-zA-Z0-9]"#, options: .regularExpression) != nil {
                return candidate
            }
        }
        return nil
    }

    /// Post-hoc validation: confirms each extracted string actually matches its expected format.
    /// Catches parser bugs that produce plausible-looking but incorrect output.
    private func validate(_ passwords: Passwords) -> Bool {
        let hexChars = Set("0123456789ABCDEF")
        guard passwords.hex.count == 64,
              passwords.hex.allSatisfy({ hexChars.contains($0) }) else { return false }
        guard passwords.alphanumeric.count == 63,
              passwords.alphanumeric.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        guard passwords.ascii.count == 63,
              passwords.ascii.unicodeScalars.allSatisfy({ $0.value >= 0x21 && $0.value <= 0x7E }),
              passwords.ascii.contains(where: { !$0.isLetter && !$0.isNumber }) else { return false }
        return true
    }
}
