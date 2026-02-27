import SwiftUI

struct ContentView: View {
    @StateObject private var fetcher = PasswordFetcher()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
                .frame(minWidth: 700)
            Spacer(minLength: 0)
        }
        .onAppear { fetcher.fetch() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Perfect Password Grabber")
                    .font(.headline)
                Text("Each password is generated server-side by GRC.com from a hardware random number generator seeded with atmospheric noise, thermal noise, and CPU jitter — sources that are fundamentally unpredictable. The raw entropy is cryptographically whitened before being used, so no pattern or bias survives. Every page refresh produces a completely independent set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Button(action: { fetcher.fetch() }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(fetcher.isLoading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var content: some View {
        if fetcher.isLoading {
            HStack {
                ProgressView()
                Text("Fetching passwords…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else if let error = fetcher.error {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try Again") { fetcher.fetch() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else if let pw = fetcher.passwords {
            VStack(spacing: 0) {
                PasswordRow(
                    label: "64-char Hex",
                    description: "256 random bits — ideal for WPA pre-shared keys",
                    password: pw.hex,
                    color: .blue
                )
                Divider().padding(.leading, 20)
                PasswordRow(
                    label: "63-char ASCII",
                    description: "Full printable ASCII character set",
                    password: pw.ascii,
                    color: .purple
                )
                Divider().padding(.leading, 20)
                PasswordRow(
                    label: "63-char Alphanumeric",
                    description: "Letters and digits only — broadest device compatibility",
                    password: pw.alphanumeric,
                    color: .green
                )
            }
        } else {
            Color.clear.frame(height: 20)
        }
    }
}

// MARK: - PasswordRow

struct PasswordRow: View {
    let label: String
    let description: String
    let password: String
    let color: Color

    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                    Spacer()
                    copyButton
                }
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(password)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var copyButton: some View {
        Button(action: copyPassword) {
            Label(
                copied ? "Copied!" : "Copy",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(copied ? .green : .primary)
        .animation(.easeInOut(duration: 0.15), value: copied)
    }

    private func copyPassword() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

#Preview {
    ContentView()
}
