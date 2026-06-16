# NotchAgent

<p align="center">
  <img src="docs/assets/icon.png" width="120" alt="NotchAgent Icon">
</p>

<p align="center">
  <img src="docs/assets/ss4.png" width="600" alt="NotchAgent Hero Image">
</p>

<p align="center">
  <b><a href="docs/screenshots.md">📸 View the full Screenshot Gallery here!</a></b>
</p>

NotchAgent is a local-first macOS notch companion that turns the top-center screen area into a compact control surface.

The project is an evolving SwiftUI application. It currently features a dynamic notch window shell, multiple widget surfaces (Settings, Calendar, Camera Mirror, Music), and a fully functional AI Command Pipeline with voice recognition (Push-to-Talk) backed by local Ollama models or OpenAI.

## What's New in v1.1.0

- Added a voice-first AI command pipeline with push-to-talk listening, live transcript updates, command parsing, confirmation flow, and native execution.
- Added local Ollama and OpenAI command providers, with a response cache for repeated commands.
- Added optional whisper.cpp transcription support for mixed Turkish/English speech. Apple Speech remains the default engine; Whisper can be enabled from Settings with a selected model file.
- Added a Whisper test action in Settings and Homebrew-friendly `whisper-cli` detection.
- Added smarter Turkish/English music commands for Spotify and Apple Music, including artist, playlist, radio, chart, and stylized artist-name correction such as `lvbelc5`.
- Added multi-tab browser commands such as opening Safari with YouTube and GitHub in one request.
- Added speech recognition permissions, app URL scheme metadata, and the native automation plumbing needed for AI actions.
- Updated the app version to `1.1.0` with build `6`.

## Current Features

- Top-center notch panel with compact and expanded states
- Menu bar app with settings access
- Local settings stored with `UserDefaults`
- Global shortcut toggle for notch visibility
- Music surface with native Spotify and Apple Music playback controls
- Camera mirror surface with `AVCaptureSession`
- Calendar surface using EventKit permissions
- Weather surface placeholder
- **Voice-first AI Command Pipeline:**
  - Push-to-talk speech recognition
  - Optional whisper.cpp transcription for mixed Turkish/English commands
  - Local AI model processing via Ollama (`qwen2.5` or others)
  - OpenAI provider support
  - Caching system for instant execution of previously learned commands
  - Natural language parsing to natively open apps and URLs (e.g., "open github.com")
  - Smart default music app tracking, Spotify/Apple Music search, and multi-turn conversational confirmation for ambiguous commands
- GitHub Releases update checks without a custom server

## Planned

- Text command input as an alternative to voice
- Rule matcher for offline, non-LLM command routing
- Learned command aliases and custom workflows
- Richer GitHub, Cursor, and Mail integrations

## Requirements

- macOS
- Xcode
- SwiftUI / AppKit-capable macOS target

Some features require macOS permissions:

- Camera access for the mirror surface
- Calendar access for upcoming events
- Automation access for Spotify and Apple Music controls

### whisper.cpp transcription

The app uses Apple Speech by default. It can optionally use whisper.cpp instead for final voice command transcription. In Settings -> AI, set `Speech engine` to `Whisper.cpp` and choose a Whisper model file.

- `Whisper model path`: path to a ggml model such as `ggml-base.bin` or `ggml-small.bin`

NotchAgent expects `whisper-cli` to be available on the app process path. Homebrew installs from `brew install whisper-cpp` are supported without entering a custom binary path.

Homebrew does not download model files:

```sh
brew install whisper-cpp ffmpeg
```

After installing, download a `.bin` model from the whisper.cpp model links shown by `brew info whisper-cpp`, then select that model in Settings. While recording in Whisper mode, NotchAgent can still show live transcript updates; the final transcript is replaced by whisper.cpp after you stop speaking.

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

This project is under active development. The notch shell and native system interactions are stabilizing, and the main focus is now on expanding the local, AI-powered agent capabilities and adding more app integrations.

## Author

Created by Omer Faruk Aras.

GitHub: [@omerfarukaras](https://github.com/omerfarukaras)

Repository: [omerfarukaras/NotchAgent](https://github.com/omerfarukaras/NotchAgent)

## License

MIT
