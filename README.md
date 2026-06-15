# NotchAgent

NotchAgent is a local-first macOS notch companion that turns the top-center screen area into a compact control surface.

The project is currently an early SwiftUI prototype. The shell, notch window, widget surfaces, settings, Spotify and Apple Music controls, calendar preview, weather placeholder, and camera mirror surface are in progress. AI routing and model-backed commands are planned next.

## Current Features

- Top-center notch panel with compact and expanded states
- Menu bar app with settings access
- Local settings stored with `UserDefaults`
- Global shortcut toggle for notch visibility
- Music surface with selectable Spotify or Apple Music AppleScript playback controls
- Camera mirror surface with `AVCaptureSession`
- Calendar surface using EventKit permissions
- Weather surface placeholder
- Agent state demo surface for future AI command routing
- GitHub Releases update checks without a custom server

## Planned

- Text command input
- Rule matcher and app/plugin command routing
- Local AI model fallback, likely through Ollama
- Learned command aliases
- GitHub, Cursor, Mail, and richer music integrations
- Voice input as an optional command input method

## Requirements

- macOS
- Xcode
- SwiftUI / AppKit-capable macOS target

Some features require macOS permissions:

- Camera access for the mirror surface
- Calendar access for upcoming events
- Automation access for Spotify and Apple Music controls

## Development

Open `NotchAgent.xcodeproj` in Xcode and run the `NotchAgent` scheme.

From the command line:

```sh
xcodebuild -project NotchAgent.xcodeproj -scheme NotchAgent -configuration Debug build
```

## Release Builds

Create a local Release build and DMG:

```sh
scripts/build_release.sh
```

The generated installer image is written to `dist/NotchAgent.dmg`.

Tagged releases are built by GitHub Actions when a tag like `v1.0.0` is pushed. Public releases should be signed and notarized with an Apple Developer ID before broad distribution.

NotchAgent checks `https://api.github.com/repos/omerfarukaras/NotchAgent/releases/latest` for updates. When a newer release is available, the app shows an update prompt and opens the GitHub release page.

## Status

This is not a finished product yet. The current goal is to stabilize the notch shell and local command workflow before adding model-backed AI features.

## Author

Created by Omer Faruk Aras.

GitHub: [@omerfarukaras](https://github.com/omerfarukaras)

Repository: [omerfarukaras/NotchAgent](https://github.com/omerfarukaras/NotchAgent)

## License

MIT
