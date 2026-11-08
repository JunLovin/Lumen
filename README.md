# Lumen

Lumen makes an iPhone and a Mac feel like one surface. Drag a photo off the edge of the iPhone and it enters through the edge of the Mac at the same physical size, wrapped in light that takes its colors from the photo.

![An illustration of a photo crossing from an iPhone to a Mac in a wave of light](.github/assets/lumen-preview.gif)

_Animated illustration of the gesture, not a screen recording._

> **Status:** complete as a personal project. Lumen is not distributed through the App Store or TestFlight, so you build it yourself.

## Features

- **One gesture.** Hold a photo in Lumen's gallery, drag it off the edge facing the Mac and let go. It lands on a floating shelf, ready to drop into any app or folder.
- **The original file.** Photos and videos arrive as their originals, including your edits, verified with SHA-256 and resumed if the connection drops.
- **Both directions.** Drag a file from Finder to the edge of the Mac facing the iPhone, or send files from the iPhone with the file picker or the Share Extension. Any file type, several at once, and folders with subfolders.
- **Knows where your iPhone is.** Stereo ultrasound, device motion, drag history and Bluetooth proximity are fused into an estimate of which side of the Mac the iPhone is on. There is no setup screen.
- **Synchronized light.** A shared clock keeps both screens in step: the edge glow takes the photo's colors, the photo dissolves into particles as it leaves, condenses from light as it arrives and a wave of light crosses both screens when it lands.
- **Pair once.** Bring the devices close and compare a ring of four colors. They reconnect on their own afterwards.
- **Local only.** No server, no account, no cloud. Everything travels encrypted over your local network, and microphone audio is never stored or sent.
- **Considerate.** Spanish and English, Reduce Motion support, an optional landing sound and an optional lens effect that bends the desktop around the arriving photo.

## Stack

| Area     | Technology                                                        |
| -------- | ----------------------------------------------------------------- |
| iPhone   | React Native CLI (New Architecture), TypeScript, Reanimated, Skia |
| Mac      | Swift 6, SwiftUI + AppKit, Metal, menu bar app                    |
| Shared   | `LumenKit` Swift Package: DSP, protocol, transport, cryptography  |
| Protocol | Protocol Buffers, generated for Swift and TypeScript              |

Both apps follow a hexagonal architecture: the domain depends on nothing, adapters are the only code that touches platform APIs, and `pnpm check` rejects imports that cross those boundaries.

## How it works

- **Placement.** The Mac plays a pair of near-inaudible chirps from its left and right speakers. The iPhone measures which one arrives first, and a Bayesian resolver combines that with motion, Bluetooth signal and past drags.
- **Channels.** Pairing derives keys that protect three channels: TLS 1.2 with a pre-shared key for control messages, DTLS for real-time drag frames and TLS for files.
- **The gesture.** Drag frames leave the iPhone from the UI thread at the display's refresh rate, so JavaScript never sits in the gesture's path. The Mac interpolates them against the shared clock and draws the photo with Metal.

## Build and run

Requires iOS 18 and macOS 15 or later, a Mac with built-in speakers, and both devices on the same Wi-Fi network.

Tools: Node 24, pnpm, Xcode, CocoaPods, `protoc`, SwiftLint and SwiftFormat.

```bash
pnpm install
pnpm check
```

The project is signed with its author's Apple team. To run it on your own devices, change the development team, the bundle identifiers, the App Group (`group.com.junlovin.lumen`) and the keychain group in both Xcode projects and their entitlements.

- **iPhone:** run `pnpm --filter @lumen/ios pods`, open `apps/ios/ios/Lumen.xcworkspace` and run the `Lumen` scheme. Start Metro with `pnpm --filter @lumen/ios start`.
- **Mac:** run `pnpm mac`. The app appears in the menu bar, not the Dock.

Debug builds add labs for placement, latency, glow and motion tuning on both devices.

## Known limitations

- Drags start in Lumen's own gallery. iOS does not let an app see a drag that begins in Apple's Photos app.
- The iPhone must have Lumen open to receive files.
- Ultrasound needs the Mac's built-in speakers. With headphones or an external display's speakers, placement relies on motion and past drags.
- The iPhone usually takes several seconds to find the side of the Mac after it is moved.
- Drag frames were measured at 86.9 ms end to end at the 95th percentile, and were not measured again after a later change to their network priority.
- The gesture was profiled at 60 fps on an iPhone 14. It has not been profiled on a 120 Hz ProMotion display.

## License

[MIT](LICENSE)
