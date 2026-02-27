import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text("Perfect Password Grabber")
                    .font(.title2.bold())

                Divider()

                section("What It Does") {
                    Text("Perfect Password Grabber fetches cryptographically strong passwords from GRC.com's Ultra High Security Password Generator. Each refresh asks the server to generate a completely new, independent set of three passwords using a hardware random number generator. Nothing is stored, reused, or logged — every password is genuinely one-of-a-kind.")
                }

                section("The Three Password Types") {
                    passwordType("64-Character Hexadecimal", color: .blue,
                        text: "Encodes 256 bits of entropy using the characters 0–9 and A–F. This is the format required by Wi-Fi routers that accept a raw 64-character hex WPA pre-shared key (PSK). It gives you the maximum possible randomness in a fixed, predictable format.")

                    passwordType("63-Character Printable ASCII", color: .purple,
                        text: "Uses every printable ASCII character from ! through ~, including letters, digits, and special characters like @, #, $, and %. This maximises entropy per character and is the best choice for password managers, encrypted volumes, and any system that accepts the full symbol range.")

                    passwordType("63-Character Alphanumeric", color: .green,
                        text: "Restricted to letters (a–z, A–Z) and digits (0–9). Some devices, web forms, or legacy systems refuse special characters in passwords — this option trades a small amount of entropy for broad compatibility, while still providing excellent security.")
                }

                section("How To Use") {
                    step("Copy",
                         "Click the Copy button next to any password to place it on the clipboard. The button briefly shows a checkmark to confirm.")
                    step("Refresh",
                         "Click Refresh in the top-right corner to discard the current set and fetch a fresh, independent set of passwords from GRC.com.")
                    step("Select",
                         "Each password is selectable as text, so you can also click and drag to copy part of a password if you need a shorter key.")
                }

                section("About the Password Source") {
                    Text("All passwords are generated server-side by **GRC.com** (Gibson Research Corporation), operated by security researcher Steve Gibson. The generator draws entropy from a hardware random number generator seeded by multiple independent physical sources — atmospheric noise, thermal noise, and CPU timing jitter — and applies cryptographic whitening before producing output. The result is passwords that are indistinguishable from pure random data and impossible to predict.")
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: URL(string: "https://www.grc.com/passwords.htm")!) {
                        HStack(spacing: 5) {
                            Text("GRC Ultra High Security Password Generator")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.callout)
                    }
                    .padding(.top, 2)
                }

            }
            .padding(30)
        }
        .frame(minWidth: 560, minHeight: 460)
    }

    // MARK: - Helpers

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 12) { content() }
        }
    }

    private func passwordType(_ name: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).fontWeight(.semibold)
                Text(text).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func step(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .fontWeight(.semibold)
                .frame(width: 56, alignment: .leading)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HelpView()
}
