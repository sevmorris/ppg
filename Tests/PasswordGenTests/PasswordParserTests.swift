import XCTest
@testable import PasswordGen

final class PasswordParserTests: XCTestCase {
    private let parser = PasswordParser()

    // MARK: - cleanHTML

    func testCleanHTMLStripsTagsAndDecodesNamedEntities() {
        let html = "<p>Hello &amp; World &lt;test&gt;</p>"
        let result = parser.cleanHTML(html)
        XCTAssertTrue(result.contains("Hello & World <test>"))
        XCTAssertFalse(result.contains("<p>"))
    }

    func testCleanHTMLRemovesWbrTags() {
        // <wbr> tags appear inside password strings on GRC.com and must be removed
        // without substitution so they don't split a 64-char run into shorter pieces.
        let html = "AAAA<wbr>BBBB"
        XCTAssertEqual(parser.cleanHTML(html), "AAAABBBB")
        let html2 = "AAAA<wbr/>BBBB"
        XCTAssertEqual(parser.cleanHTML(html2), "AAAABBBB")
    }

    func testCleanHTMLStripsScriptAndStyleBlocks() {
        let html = "<style>body{color:red}</style><p>Keep this</p><script>alert(1)</script>"
        let result = parser.cleanHTML(html)
        XCTAssertTrue(result.contains("Keep this"))
        XCTAssertFalse(result.contains("color:red"))
        XCTAssertFalse(result.contains("alert(1)"))
    }

    func testCleanHTMLStripsSoftHyphens() {
        // &shy; and &#173; are invisible line-break hints that can appear inside passwords
        let html = "ABC&shy;DEF&#173;GHI"
        let result = parser.cleanHTML(html)
        XCTAssertEqual(result, "ABCDEFGHI")
    }

    // MARK: - decodeNumericEntities

    func testDecodeDecimalEntity() {
        XCTAssertEqual(parser.decodeNumericEntities("&#65;"), "A")
        XCTAssertEqual(parser.decodeNumericEntities("&#39;"), "'")
        XCTAssertEqual(parser.decodeNumericEntities("&#33;"), "!")
    }

    func testDecodeHexEntity() {
        XCTAssertEqual(parser.decodeNumericEntities("&#x41;"), "A")
        XCTAssertEqual(parser.decodeNumericEntities("&#x21;"), "!")
        // HTML5 requires lowercase x; &#X41; is non-standard and intentionally left as-is
        XCTAssertEqual(parser.decodeNumericEntities("&#X41;"), "&#X41;")
    }

    func testDecodeEntityInContext() {
        XCTAssertEqual(parser.decodeNumericEntities("say &#104;ello"), "say hello")
    }

    func testNoEntitiesUnchanged() {
        let text = "plain text without entities"
        XCTAssertEqual(parser.decodeNumericEntities(text), text)
    }

    // MARK: - Double-decode prevention

    func testAmpEntityDoesNotDoubleDecodeNumericEntities() {
        // &amp;#39; is a double-encoded sequence. It should produce &#39; (the literal four
        // characters), NOT ' — because numeric decoding runs before &amp; is resolved.
        let result = parser.cleanHTML("&amp;#39;")
        XCTAssertEqual(result, "&#39;")
    }

    // MARK: - parse(html:)

    func testParseExtractsAllThreePasswords() {
        let hex   = String(repeating: "A", count: 32) + String(repeating: "0", count: 32)  // 64 uppercase hex
        let alnum = String(repeating: "b", count: 32) + String(repeating: "2", count: 31)  // 63 alphanumeric
        let ascii = String(repeating: "c", count: 60) + "!@#"                              // 63 ASCII with specials

        let html = "<body><p> \(hex) </p><p> \(ascii) </p><p> \(alnum) </p></body>"
        let result = parser.parse(html: html)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.hex, hex)
        XCTAssertEqual(result?.alphanumeric, alnum)
        XCTAssertEqual(result?.ascii, ascii)
    }

    func testParseHandlesWbrInsidePasswordString() {
        let hex = String(repeating: "A", count: 32) + String(repeating: "0", count: 32)
        // Simulate GRC inserting <wbr> inside a 63-char alnum string
        let alnumRaw = String(repeating: "b", count: 32) + String(repeating: "2", count: 31)
        let alnumHtml = String(alnumRaw.prefix(20)) + "<wbr>" + String(alnumRaw.dropFirst(20))
        let ascii = String(repeating: "c", count: 60) + "!@#"

        let html = "<body> \(hex) \(ascii) \(alnumHtml) </body>"
        let result = parser.parse(html: html)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.alphanumeric, alnumRaw)
    }

    func testParseReturnsNilWhenHexMissing() {
        // No 64-char uppercase hex present
        let alnum = String(repeating: "b", count: 63)
        let ascii = String(repeating: "c", count: 60) + "!@#"
        let html  = "<body> \(alnum) \(ascii) </body>"
        XCTAssertNil(parser.parse(html: html))
    }

    func testParseReturnsNilWhenHexIsWrongLength() {
        let hex   = String(repeating: "A", count: 63)  // 63, not 64
        let alnum = String(repeating: "b", count: 63)
        let ascii = String(repeating: "c", count: 60) + "!@#"
        let html  = "<body> \(hex) \(ascii) \(alnum) </body>"
        XCTAssertNil(parser.parse(html: html))
    }

    func testParseRejectsLowercaseHex() {
        // Lowercase hex chars are not valid for the 64-char uppercase hex password
        let hex   = String(repeating: "a", count: 64)  // lowercase — invalid
        let alnum = String(repeating: "b", count: 63)
        let ascii = String(repeating: "c", count: 60) + "!@#"
        let html  = "<body> \(hex) \(ascii) \(alnum) </body>"
        XCTAssertNil(parser.parse(html: html))
    }

    func testParseRejectsASCIIPasswordWithNoSpecialChars() {
        let hex   = String(repeating: "A", count: 32) + String(repeating: "0", count: 32)
        let alnum = String(repeating: "b", count: 32) + String(repeating: "2", count: 31)
        // All-alphanumeric 63-char string — no special chars, cannot be the ASCII password
        let noSpecial = String(repeating: "d", count: 63)
        let html  = "<body> \(hex) \(noSpecial) \(alnum) </body>"
        // noSpecial would be consumed by the alnum extractor, not the ASCII extractor
        // so parse will fail to find a distinct ASCII password
        let result = parser.parse(html: html)
        // Either nil (no ascii found) or ascii ≠ noSpecial
        if let result { XCTAssertNotEqual(result.ascii, noSpecial) }
    }
}
