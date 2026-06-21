# Release Notes

## v1.2.2

NotchAgent v1.2.2 tightens the assistant pipeline and adds stronger context-aware behaviors for day-to-day desktop use.

### Highlights

- Split the AI command flow into dedicated parser, prompt builder, and executor components so the command manager stays smaller and easier to evolve.
- Added vector memory retrieval backed by Apple's `NaturalLanguage` embeddings, allowing the assistant to recall relevant learned facts before answering or acting.
- Added background research support that fetches web context and summarizes results through the active LLM provider.
- Added Ghost Cursor visual guidance for screen-aware questions, letting the assistant point to UI elements instead of only describing them.
- Improved vision prompts so screen-based help returns structured commands and can guide workflows more directly.
- Improved Siri/AppIntents listening by posting an in-process start-listening notification instead of routing through the URL handler.
- Fixed Apple Music search URL handling by using the modern Music URL scheme.
- Moved detailed usage and feature documentation into the `docs` folder for cleaner onboarding.

### Build

- Version: `1.2.2`
- Build: `9`
- Local DMG artifact: `dist/v1.2.2/NotchAgent-v1.2.2.dmg`

### Notes

The app requires macOS permissions for camera, calendar, automation, screen recording, accessibility, and speech recognition depending on which surfaces and agent actions are used.
