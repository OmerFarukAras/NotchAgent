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

NotchAgent is a local-first macOS notch companion that turns the top-center screen area into a compact control surface and a powerful AI Assistant.

The project is an evolving SwiftUI application. It currently features a dynamic notch window shell, multiple widget surfaces (Settings, Calendar, Camera Mirror, Music), and a fully functional AI Command Pipeline with voice recognition (Push-to-Talk) backed by local Ollama models or OpenAI.

## Latest Release

**v1.2.2** focuses on making the assistant more modular, more context-aware, and easier to guide visually. It adds the split command parser/executor pipeline, vector memory retrieval, background research, Ghost Cursor screen guidance, and a more direct Siri/AppIntents listening trigger.

Read the full release notes in [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md).

## Documentation

We have moved our detailed feature lists and usage guides to the `docs` folder. Please check them out to learn how to use NotchAgent to its fullest potential:

- 📖 **[AI Agent Usage Guide & Example Prompts](docs/AGENT_USAGE.md)**
  Learn how to talk to the agent, use screen awareness (vision), teach it facts (memory), and control your system.
- ⚙️ **[Application Features & Surfaces](docs/APP_FEATURES.md)**
  Learn about the Music, Calendar, Camera Mirror surfaces, Settings, and how to trigger the app via global shortcuts or Siri.

## Planned

- Text command input as an alternative to voice
- Rule matcher for offline, non-LLM command routing
- Learned command aliases and custom workflows
- Richer GitHub, Cursor, and Mail integrations

## Requirements

- macOS 15.0+
- Xcode 15+
- SwiftUI / AppKit-capable macOS target

Some features require macOS permissions:
- **Camera:** For the mirror surface
- **Calendar:** For upcoming events
- **Automation / AppleEvents:** For Spotify and Apple Music controls
- **Screen Recording:** For Vision context understanding
- **Accessibility:** For typing text macros

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

For versioned local release artifacts, use `dist/v1.2.2/NotchAgent-v1.2.2.dmg`.

Tagged releases are built by GitHub Actions when a tag like `v1.0.0` is pushed. Public releases should be signed and notarized with an Apple Developer ID before broad distribution.

NotchAgent checks `https://api.github.com/repos/omerfarukaras/NotchAgent/releases/latest` for updates. When a newer release is available, the app shows an update prompt and opens the GitHub release page.

This project is under active development. The notch shell and native system interactions are stabilizing, and the main focus is now on expanding the local, AI-powered agent capabilities and adding more app integrations.

## Author

Created by Omer Faruk Aras.

GitHub: [@omerfarukaras](https://github.com/omerfarukaras)

Repository: [omerfarukaras/NotchAgent](https://github.com/omerfarukaras/NotchAgent)

## Contributing

Contributions are welcome! If you'd like to help improve NotchAgent, please feel free to fork the repository, make your changes, and submit a pull request. 
Whether it's a bug fix, a new AI feature, or a UI enhancement, all contributions are appreciated.

## License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license.

You are free to download, use, and modify the source code for your own personal, non-commercial use. However, you may not sell, distribute commercially, or publish this software as a paid product. See the [LICENSE](LICENSE) file for more details.
