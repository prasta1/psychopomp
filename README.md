# psychopomp

A native iOS companion for your self-hosted **[Hermes Agent](https://github.com/nousresearch/hermes-agent)**.
Connects to the agent's OpenAI-compatible API server, streams runs with live
tool-progress, and is styled after Nous Research's retro-terminal aesthetic.

> _psychopomp_ — a guide of souls. Hermes was the original. This app is your
> pocket-sized line to yours.

## Features

- **Streaming chat** against your Hermes agent via the Runs API (with automatic
  fallback to `/v1/chat/completions`).
- **Live tool-progress timeline** — see the agent's terminal / web / file steps inline.
- **Stop** a run mid-flight, and resolve **approval gates** for sensitive tools.
- **Model picker** populated from `GET /v1/models`.
- **Markdown + fenced code** rendering with copy buttons.
- **Image input** — attach photos, sent inline to multimodal Hermes.
- **Local history** — conversations persist on-device (SwiftData). Each thread
  carries a stable `X-Hermes-Session-Key` so agent memory stays per-conversation.
- **Dark, terminal-first** design; the API key is stored in the iOS Keychain.

## Requirements

- **Xcode 16+** (the project uses a file-system–synchronized group, `objectVersion 77`).
- **iOS 17+** target (SwiftData, the Observation framework, `PhotosPicker`).
- A running **hermes-agent** with its API server enabled.

## Run your Hermes agent

In `~/.hermes/.env`:

```
API_SERVER_ENABLED=true
API_SERVER_KEY=<choose-a-strong-key>
```

By default the server binds `127.0.0.1:8642`. To reach it from a simulator or a
physical device on your LAN, bind all interfaces and use your Mac's LAN IP
(e.g. `http://192.168.1.20:8642`). See the
[API Server docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server).

The app declares `NSAllowsLocalNetworking`, so plain-HTTP LAN endpoints work
without extra ATS configuration.

## Build & run

```bash
open Psychopomp.xcodeproj
```

1. Select the **Psychopomp** scheme and an iOS 17 simulator (or your device).
2. Set your **signing team** on the target (Signing & Capabilities). The bundle id
   defaults to `com.psychopomp.hermes` — change it to something under your team.
3. Build & Run.
4. On first launch, enter the **server URL** and **API key**, tap **Test connection**,
   then **Connect**.

## Project layout

```
Psychopomp/
├─ App/            PsychopompApp (entry, SwiftData container), Info.plist
├─ DesignSystem/   Theme tokens, terminal text styles, shared components
├─ Models/         Conversation, ChatMessage, ToolEvent, Attachment (SwiftData)
├─ Networking/     HermesClient, HermesConfig, Keychain, SSEParser, RunEvent, JSON
└─ Features/       Connection · Conversations · Chat (+ ViewModel) · Settings
```

## Notes on the Hermes API surface

The Runs API request body and SSE event names are not exhaustively documented
publicly, so `Networking/RunEvent.swift` and `SSEParser.swift` decode **defensively**:
multiple field spellings are accepted, unknown events are ignored, and the client
falls back to `/v1/chat/completions` streaming if the Runs endpoints aren't
available. If your server's event vocabulary differs, extend the `switch` in
`RunEventDecoder.decode`.

## Roadmap (out of scope for v1)

Background Jobs API / scheduled runs, push notifications, conversation branching
(`/api/sessions`), Nous Portal OAuth, and a light/parchment theme.
