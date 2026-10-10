# Buckshot Mobile Personal Port

Private, offline iOS port recovered from the owner's local Steam installation.
Original game and assets are by Mike Klubnika. This repository is not an official release.

- Godot 4.7.2 stable, Compatibility renderer.
- iOS 16+, iPhone and iPad, landscape, ARM64 device build.
- Point-and-tap interaction only; no virtual joystick or free movement.
- Single-player content retained; Steam multiplayer and online services disabled.
- Mobile and Windows demo use Double or Nothing as the default and only mode.
  Old story checkpoints are discarded; endless checkpoints remain resumable.
- Five consecutive dealer taps during an idle player turn abandon the current
  run using the original shooting animation, a large-room reverb, and a
  three-second blackout before returning to a fresh bathroom.
- IPA is unsigned and must be signed by a sideloading tool before installation.

`port/` contains the source overlay. The private `recovered-assets` release stores
`game-assets.zip` and its SHA256. CI extracts the archive and applies the source
overlay before importing, exporting, and compiling with Xcode.

Run the **Build Unsigned iOS IPA** workflow to produce the IPA and build evidence.
Compilation, desktop integration tests, simulator launch, and physical-device
verification are separate checks. No real-device performance is implied by CI.

Windows integration test:

```powershell
$env:BUCKSHOT_TEST_OUTPUT = 'C:\path\to\evidence'
godot --path game --script res://mobile/smoke_test.gd -- --mobile-preview
```

