**Password Fetcher for macOS**

Perfect Passwords Grabber fetches cryptographically random passwords from [GRC.com's Ultra High Security Password Generator](https://www.grc.com/passwords.htm). Each refresh asks GRC's server to generate a completely new, independent set of three passwords. Nothing is stored, reused, or logged — every password is genuinely one-of-a-kind.

## Design Philosophy

Perfect Passwords Grabber does one thing: get strong passwords into your clipboard with as little friction as possible. It fetches, displays, and copies. No generation happens locally — the randomness comes from GRC's hardware entropy source, which is better than anything a laptop can produce.

## Download

**[Perfect Passwords Grabber v1.0 (DMG)](https://github.com/sevmorris/ppg/releases/latest)**

> ⚠️ **Important — Read Before First Launch**
>
> macOS will block the app with a malware warning because it is not notarized with Apple. After mounting the DMG and dragging Perfect Passwords Grabber to Applications, **you must run this command in Terminal:**
>
> ```
> xattr -cr "/Applications/Perfect Passwords Grabber.app"
> ```
>
> Without this step, macOS will refuse to open the app.

## Features

- **Three Password Formats**: 64-char hex (256-bit WPA key), 63-char printable ASCII, and 63-char alphanumeric
- **One-Click Copy**: Copy any password to the clipboard instantly
- **Refresh**: Fetch a fresh, independent set of passwords on demand
- **Selectable Text**: Select and copy partial passwords if you need a shorter key
- **Help Window**: Built-in help explains each password type and when to use it

## Password Types

| Format | Characters | Best For |
|--------|-----------|----------|
| 64-char Hex | `0–9`, `A–F` | WPA pre-shared keys on routers that accept raw hex input |
| 63-char Printable ASCII | `!` through `~` | Password managers, encrypted volumes, anything that accepts symbols |
| 63-char Alphanumeric | `a–z`, `A–Z`, `0–9` | Systems or devices that reject special characters |

## About the Password Source

All passwords are generated server-side by [GRC.com](https://www.grc.com/passwords.htm) (Gibson Research Corporation), operated by security researcher Steve Gibson. The generator draws entropy from a hardware random number generator seeded by multiple independent physical sources — atmospheric noise, thermal noise, and CPU timing jitter — with cryptographic whitening applied before output.

## System Requirements

- macOS 13.0 (Ventura) or later
- Internet connection

## Building

```bash
swift build -c release
```

Or use the included script:

```bash
./build.sh
```

Binary output: `.build/release/PasswordGen`

## License

Copyright © 2026. This app was designed and directed by Seven Morris, with code primarily generated through AI collaboration with Claude (Anthropic).

This program is free software: you can redistribute it and/or modify it under the terms of the [GNU General Public License v3.0](LICENSE).

## A Note on AI

I'm a freelance audio engineer, not a software developer. These tools exist because AI made it possible for me to build things I couldn't build alone. That's genuinely exciting — and genuinely complicated.

AI-assisted development raises real questions about labor displacement, resource consumption, and the concentration of power in a handful of tech companies. I don't have clean answers. I do think it matters that the people using these tools are honest about the trade-offs rather than pretending they don't exist.
