import Foundation

@MainActor
final class PasswordFetcher: ObservableObject {
    @Published var passwords: Passwords?
    @Published var isLoading = false
    @Published var error: String?

    private let parser = PasswordParser()
    private let sourceURL = URL(string: "https://www.grc.com/passwords.htm")!

    /// Auto-fetch on init so the UI starts in a loading state with no blank flash.
    init() {
        fetch()
    }

    func fetch() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            defer { isLoading = false }
            do {
                var request = URLRequest(url: sourceURL)
                request.timeoutInterval = 15
                request.setValue(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
                    forHTTPHeaderField: "User-Agent"
                )
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    error = "Server returned \(http.statusCode)."
                    return
                }
                guard let html = String(data: data, encoding: .utf8)
                               ?? String(data: data, encoding: .isoLatin1) else {
                    error = "Could not decode server response."
                    return
                }
                if let parsed = parser.parse(html: html) {
                    passwords = parsed
                } else {
                    error = "Could not parse passwords from page.\nThe page structure may have changed."
                }
            } catch {
                if let urlErr = error as? URLError, urlErr.code == .notConnectedToInternet {
                    self.error = "No internet connection."
                } else if let urlErr = error as? URLError, urlErr.code == .timedOut {
                    self.error = "Request timed out. Check your connection and try again."
                } else {
                    self.error = "Network error: \(error.localizedDescription)"
                }
            }
        }
    }
}
