# MeetsRecord

A macOS menu bar app that records meeting audio (system output + microphone), autosaves in real time, and transcribes locally using Whisper.

## Features

- **Menu bar app** — lives in the macOS toolbar, no Dock icon
- **Records system audio + microphone** — captures both sides of a call via ScreenCaptureKit
- **Start / Stop / Pause** controls with elapsed time display
- **Crash-safe autosave** — writes audio incrementally to CAF format (no data loss on crash)
- **Local transcription** — uses whisper.cpp (via SwiftWhisper) for offline, private transcription
- **Session management** — each recording saved in a timestamped folder with audio + transcript

## Requirements

- **macOS 15.0+** (Sequoia) — required for ScreenCaptureKit's `captureMicrophone` API
- **Apple Silicon or Intel Mac** (Apple Silicon recommended for faster transcription)
- **Screen Recording permission** — required to capture system audio
- **Microphone permission** — required to capture your voice

## Setup

### 1. Clone and open

```bash
git clone https://github.com/JamesEBall/MeetsRecord.git
cd MeetsRecord
open Package.swift  # Opens in Xcode
```

### 2. Download Whisper model

Download the `ggml-base.en.bin` model (~142 MB) and place it in `MeetsRecord/Resources/`:

```bash
curl -L -o MeetsRecord/Resources/ggml-base.en.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
```

### 3. Build and run

Open in Xcode, select the `MeetsRecord` scheme, and run. The app appears in the menu bar.

On first run, macOS will prompt for:
- **Screen Recording** permission (needed to capture system audio)
- **Microphone** permission

## How it works

1. Click the waveform icon in the menu bar
2. Toggle system audio and/or microphone capture
3. Click **Start Recording**
4. The menu bar icon changes to a red dot while recording
5. Click **Stop** when done
6. The app automatically transcribes the audio and saves both files

### Output

Recordings are saved to `~/Documents/MeetsRecord/`:

```
~/Documents/MeetsRecord/
  2026-02-15_14-30-00/
    recording.caf      # Audio file (playable in QuickTime, VLC, etc.)
    transcript.txt      # Timestamped transcript
  sessions.json         # Session manifest
```

## Architecture

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI MenuBarExtra (.window style) |
| Audio Capture | ScreenCaptureKit (system audio + mic) |
| Audio Format | CAF (Core Audio Format) — crash-safe, no size limit |
| Transcription | SwiftWhisper (whisper.cpp via SPM) |
| Model | ggml-base.en (~142 MB, English-only) |

## Project Structure

```
MeetsRecord/
  App/
    MeetsRecordApp.swift         — @main entry point
    Info.plist                   — LSUIElement, privacy descriptions
    MeetsRecord.entitlements     — Sandbox + audio permissions
  Views/
    RecordingView.swift          — Menu bar dropdown UI
  Audio/
    AudioRecorder.swift          — SCStream lifecycle
    AudioMixer.swift             — Mixes system + mic buffers
    AudioFileWriter.swift        — Crash-safe incremental CAF writer
  Transcription/
    TranscriptionService.swift   — SwiftWhisper integration
    AudioConverter.swift         — 48kHz stereo → 16kHz mono for Whisper
  Model/
    RecordingState.swift         — Observable app state
    RecordingSession.swift       — Session data model
  Services/
    SessionManager.swift         — Session lifecycle + file management
    PermissionManager.swift      — Permission checks
  Resources/
    ggml-base.en.bin             — Whisper model (not in git)
```

## License

MIT
