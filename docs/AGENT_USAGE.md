# NotchAgent AI Usage Guide

NotchAgent transforms your macOS notch into a powerful AI-driven assistant that understands both voice commands and on-screen context. This document explains how the agent works, its capabilities, and provides example prompts to get you started.

## Core Capabilities

NotchAgent's AI pipeline is designed to be fast, local, and privacy-respecting. It uses local Ollama models (or optionally OpenAI) to parse your commands and interact with the macOS system.

- **Voice-First Interaction**: Press and hold the notch area, or say "Hey Siri, Talk to NotchAgent" to start listening.
- **Screen Awareness**: The agent can "see" your screen. If you ask about something you are looking at, it captures the screen and analyzes it to provide context-aware answers.
- **Long-Term Vector Memory**: NotchAgent remembers facts about you. It converts text to 512-dimensional vectors using Apple's native `NaturalLanguage` framework and uses Cosine Similarity to fetch relevant past memories before answering new questions.
- **Multi-Step Execution**: It can break down complex requests into a plan and execute them sequentially (e.g., searching for something and then typing the result).

---

## Agent Features & Example Prompts

### 1. General Knowledge & Answers
Ask the agent any question. It acts as a helpful local assistant.
- **"What is the capital of France?"** -> Answers directly via a notification or voice feedback.
- **"Explain quantum computing in simple terms."**

### 2. Screen Context & Vision (Ghost Cursor)
If your prompt includes words like "this", "here", "on screen" (or Turkish equivalents like "bunu", "buradaki"), the agent takes a screenshot to understand your context.
- **"How do I open the equalizer on Spotify?"** -> The agent analyzes the Spotify UI and uses the **Ghost Cursor** to visually point to the exact button you need to click.
- **"What is this code doing?"** -> Analyzes the code currently visible on your screen and explains it.

### 3. Application & System Control
Open applications, websites, or change basic settings natively.
- **"Open Safari and go to github.com"** -> Launches Safari and opens the URL.
- **"Mute the volume"** or **"Set brightness to 50%"**.
- **"Change my default music app to Spotify"** -> Updates local settings.

### 4. Background Research & Summarization
Ask the agent to research a topic. It will search the web in the background and use the LLM to summarize the findings.
- **"Research the latest news about macOS 15 and summarize them for me."** -> The agent will run a background search and send you a notification with a clean, concise summary.

### 5. Memory & Context
Teach the agent facts so it can provide personalized assistance later.
- **"Remember that my favorite programming language is Swift."** -> Saves to Vector Memory.
- Later: **"What language should I use for this new project?"** -> It will remember you prefer Swift and recommend it.

### 6. Intelligent Music Control
Control your media players semantically.
- **"Play some Turkish sad songs."** -> The agent will analyze your mood and ask for confirmation before randomly searching. It might say: *"Would you like me to open your 'Sad Turkish' playlist?"*
- **"Next song"** or **"Pause the music"**.

---

## How It Works Behind the Scenes

1. **Speech-to-Text**: Your voice is transcribed via Apple Speech or `whisper.cpp`.
2. **Memory Retrieval**: The agent searches its Vector Memory database for context related to your command.
3. **LLM Parsing**: The transcript (and memory context) is sent to the LLM with a strict JSON schema.
4. **Execution**: The LLM returns an action (e.g., `open_url`, `background_research`, `show_ghost_cursor`). The `CommandExecutor` then runs the native Swift code or AppleScript to fulfill the request.

*Tip: You can monitor all parsed commands and LLM responses in the Xcode console while debugging.*
