# TODO

## Ship a universal binary (Intel + Apple Silicon)

Every release so far, 1.0 through 1.6, has been arm64-only. Nothing said so
until 1.6 added "Apple Silicon" to the README's requirements, so an Intel user
downloading any earlier DMG got an app that simply would not open, with no
explanation anywhere.

`Package.swift` already declares `.macOS(.v13)`, and Ventura runs on Intel, so
the deployment target is not the obstacle — the build just never asked for the
second slice.

### What was tried

A universal build works today, as of 1.6:

```bash
swift build -c release --arch arm64 --arch x86_64
```

- `lipo -archs` on the result reports `x86_64 arm64`
- `vtool -show-build` reports `platform MACOS minos 13.0` for **both** slices,
  so the deployment target carries over correctly
- The toolchain warns that `x86_64 is deprecated for your deployment target
  (macOS 27.0)`. That warning is about the SDK's own default, not this package:
  the emitted slices are 13.0, as above. It is noise, but it will not go away.

### What this changes in `distribute.sh`

One real gotcha: a multi-arch build does **not** land in `.build/release/`.
It lands in `.build/out/Products/Release/`. The copy step

```sh
cp ".build/release/${BINARY_NAME}" "${APP_BUNDLE}/Contents/MacOS/${BINARY_NAME}"
```

would silently keep copying a stale single-arch binary from the old path if it
were left alone — the build would look universal and the DMG would not be. The
path has to move with the `--arch` flags, and the verify step should assert
`lipo -archs` on the app inside the finished DMG, the same way it already
asserts the version and the notarization.

### Still unverified

**Nobody has confirmed the x86_64 slice actually launches.** It compiles, it
is present, and it targets the right OS, but that is not the same as running.
Test it under Rosetta or on a real Intel Mac before shipping. Note that the
binary is a GUI app, so invoking it from a shell to test it will block rather
than return — launch it properly, via `open`, or it will look like a hang.

### Also needs doing

- Revert the "Apple Silicon" line added to the README's System Requirements
  in 1.6, and the same line in `README.txt` inside the DMG
- Expect the DMG to roughly double in size
- Re-check notarization: two slices, one signature, but worth confirming the
  stapled ticket still validates rather than assuming it
