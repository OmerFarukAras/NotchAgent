# NotchAgent Application Features

NotchAgent is more than just an AI assistant; it also acts as an interactive hub seamlessly integrated into the macOS notch area. This document outlines the non-AI, visual, and utility features of the application.

## User Interface & Surfaces

NotchAgent features a dynamic, expanding window shell that drops down from the notch. Depending on the context, different "Surfaces" (widgets) are displayed.

### 1. Settings Surface
Accessed via the menu bar icon or by asking the agent to open settings.
- **AI Settings**: Configure your active LLM provider (Ollama or OpenAI). You can specify custom models (e.g., `qwen2.5`) and base URLs for local inference.
- **Speech Engine**: Switch between Apple's native speech recognition and `whisper.cpp` for more accurate multilingual parsing.
- **Visual Options**: Toggle sounds, voice feedback, and the appearance of the "Agent Eyes" animation.

### 2. Music Player Surface
A clean, compact music widget that integrates natively with Spotify and Apple Music.
- Shows current track artwork, title, and artist.
- Provides play/pause, next, and previous playback controls.
- Automatically tracks your default music application preference.

### 3. Camera Mirror Surface
A quick utility widget that activates your Mac's camera (`AVCaptureSession`) so you can check your appearance before joining a meeting, all without opening Photo Booth or FaceTime.

### 4. Calendar Surface
Displays your upcoming daily schedule.
- Requests native macOS EventKit permissions.
- Fetches and visualizes events cleanly within the notch drop-down.

---

## Global Shortcuts & Triggers

NotchAgent stays out of your way until you need it.

- **Menu Bar Icon**: A minimalist icon resides in your menu bar. Clicking it provides quick access to Settings, manual Trigger options, and quitting the app.
- **Global Keyboard Shortcut**: You can define a system-wide hotkey to instantly reveal or hide the NotchAgent drop-down, no matter what application you are currently using.
- **Siri / AppIntents**: NotchAgent registers an `AppIntent` that allows you to trigger the listening mode using Apple's Shortcuts app or by saying "Hey Siri, Talk to NotchAgent".

---

## Animations & Aesthetics

- **Fluid Expanding Notch**: The window dynamically resizes using SwiftUI animations to mimic the behavior of the native macOS hardware notch expanding into a software UI.
- **Agent Eyes**: When processing complex commands, the notch displays a pair of animated "eyes" that look around, giving the assistant a friendly, lifelike personality.
- **Sound & Voice Feedback**: Optional sound effects play upon successful command execution, and the system's `NSSpeechSynthesizer` can read out answers verbally.
