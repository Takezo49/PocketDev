<div align="center">

<img src="https://img.shields.io/badge/PocketDev-v0.1.0-c6f91f?style=flat-square&labelColor=05080A" alt="Version">
<img src="https://img.shields.io/npm/v/devbox-daemon?style=flat-square&labelColor=05080A&color=c6f91f" alt="npm">
<img src="https://img.shields.io/github/license/Takezo49/PocketDev?style=flat-square&labelColor=05080A&color=c6f91f" alt="License">
<img src="https://img.shields.io/badge/platform-Android-c6f91f?style=flat-square&labelColor=05080A" alt="Platform">

<br><br>

# `</>` PocketDev

### Control your AI from your pocket.

Run **Claude Code**, **Aider**, **Codex** and more from your phone.<br>
One command to install. Scan QR to connect. Ship code from anywhere.

<br>

[Get Started](#-quick-start) &nbsp;&middot;&nbsp; [Features](#-features) &nbsp;&middot;&nbsp; [Architecture](#-architecture) &nbsp;&middot;&nbsp; [Landing Page](https://pocketdev.app)

<br>

</div>

---

## How it works

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Phone App  │◄──WSS──►│   Relay Server   │◄──WSS──►│  Your Desktop   │
│  (Flutter)  │         │  (Node.js)       │         │  (Daemon)       │
│             │         │                  │         │                 │
│  Anywhere   │         │  Auth + Bridge   │         │  Claude Code    │
│  on earth   │         │  Redis + Postgres│         │  Aider, Codex   │
└─────────────┘         └──────────────────┘         └─────────────────┘
```

**Same WiFi?** Connect directly — no server needed.<br>
**Remote?** The relay bridges your phone to your desktop from anywhere.

---

## ⚡ Quick Start

### 1. Install the daemon on your desktop

```bash
npx devbox-daemon
```

> Requires Node.js 18+. Works on macOS, Linux, Windows.

A QR code appears in your terminal. That's it.

### 2. Install the app on your phone

Download **PocketDev** from Google Play *(iOS coming soon)*.

### 3. Scan & code

Open the app → scan the QR code → start prompting.

```
You: Build a REST API with JWT auth
Claude: Creating files...
  + src/routes/auth.ts (42 lines)
  + src/middleware/jwt.ts (28 lines)
  Done in 4.2s — $0.0231
```

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Live streaming** | Token-by-token response streaming. See code appear in real-time. |
| **Code diffs** | Red/green diff view with line numbers. See exactly what changed. |
| **Model switching** | Switch between Opus, Sonnet, Haiku on the fly. |
| **Effort control** | Low, Medium, High — tune speed vs quality. |
| **Cost tracking** | Cumulative cost, tokens, cache stats per session. |
| **Tool cards** | Read, Write, Edit, Bash, Grep, Glob — all with live status. |
| **Cancel** | Stop mid-generation with one tap. |
| **Session resume** | Conversation persists across prompts. |
| **QR pairing** | Scan to connect. No passwords. |
| **Multi-tool** | Claude Code now. Aider, Codex, Antigravity coming soon. |

---

## 🛠 Supported AI Tools

| Tool | Status |
|------|--------|
| **Claude Code** | ✅ Available |
| **Antigravity** | 🔜 Coming soon |
| **Aider** | 🔜 Coming soon |
| **Codex CLI** | 🔜 Coming soon |

---

## 📐 Architecture

```
pocketdev/
├── devbox/
│   ├── packages/
│   │   ├── daemon/        # Desktop daemon (npm: devbox-daemon)
│   │   │   ├── src/
│   │   │   │   ├── claude-session.ts   # Claude CLI bridge
│   │   │   │   ├── server.ts           # WebSocket server
│   │   │   │   ├── session-manager.ts  # Multi-session handling
│   │   │   │   └── types.ts            # Protocol types
│   │   │   └── bin/cli.js              # CLI entry point
│   │   ├── relay/         # Auth + WebSocket relay server
│   │   │   ├── src/
│   │   │   │   ├── index.ts    # HTTP + WS server
│   │   │   │   ├── relay.ts    # Daemon ↔ App bridge
│   │   │   │   ├── auth.ts     # JWT + pairing + user auth
│   │   │   │   └── db.ts       # PostgreSQL schema + queries
│   │   │   ├── Dockerfile
│   │   │   └── docker-compose.yml
│   │   └── shared/        # Protocol type definitions
│   └── ...
├── devbox_flutter/        # Mobile app (Flutter)
│   └── lib/
│       ├── screens/
│       │   ├── auth_screen.dart       # Login / Register
│       │   ├── connect_screen.dart    # QR scan + pair code
│       │   ├── dashboard_screen.dart  # AI tool picker
│       │   └── session_screen.dart    # Claude session UI
│       ├── services/
│       │   ├── auth_service.dart      # Token storage + API
│       │   ├── connection.dart        # WebSocket client
│       │   └── session_state.dart     # Session + card state
│       ├── widgets/
│       │   ├── card_widget.dart       # Message/tool cards
│       │   └── tool_result_card.dart  # Diff viewer
│       └── theme/colors.dart          # True black + white
└── landing/               # SaaS landing page
    └── index.html         # Tailwind + vanilla JS
```

### Protocol

The daemon and app communicate over WebSocket with JSON messages:

```
Daemon → App:  stream:start, stream:delta, stream:tool_start,
               stream:tool_update, stream:tool_result, stream:tool_end,
               stream:end, card, session:update, status

App → Daemon:  command, session:create, session:kill, session:cancel,
               session:config, pair:verify
```

---

## 🐳 Self-hosting the relay

```bash
cd devbox/packages/relay
cp .env.example .env  # Edit with your secrets
docker compose up -d
```

Services:
- **Relay** — WebSocket bridge + REST API (port 3000)
- **PostgreSQL** — Users, devices, sessions (port 5433)
- **Redis** — Connection state, presence (port 6380)

Environment variables:
| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | `postgres://devbox:devbox@localhost:5432/devbox` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379` |
| `JWT_SECRET` | Secret for signing tokens | Required in production |
| `PORT` | HTTP/WS port | `3000` |

---

## 🎨 Design

True black (`#000000`) + white. Inspired by Grok. No unnecessary colors.

- Background: `#000000` / `#0A0A0A`
- Text: `#FFFFFF` / `#A0A0A0`
- Accent: `#FFFFFF` (white)
- Status only: green `#4ADE80`, red `#F87171`
- Font: System sans-serif, monospace for code

---

## 🔒 Security

- **Pairing secret** — 64-char random token, required for all connections
- **JWT auth** — Token-based authentication for relay mode
- **Rate limiting** — 5 pair attempts/minute per IP
- **Atomic pairing** — Database row-lock prevents race conditions
- **E2E ready** — Relay is a transparent pipe, E2E encryption can be layered
- **No stored credentials** — API keys stay on your machine
- **Parameterized queries** — SQL injection safe
- **Non-root Docker** — Containers run as `node` user

---

## 📱 App Screenshots

| Dashboard | Claude Session | Code Diff |
|-----------|---------------|-----------|
| AI tool picker with device status | Live streaming with tool cards | Red/green diff with line numbers |

---

## 🗺 Roadmap

- [x] Claude Code integration
- [x] Live streaming + tool cards
- [x] Code diff viewer (red/green)
- [x] Model & effort switching
- [x] Cost tracking
- [x] QR code pairing
- [x] User auth (login/register)
- [x] Dashboard with AI tool picker
- [x] Relay server for remote access
- [x] npm package (`npx devbox-daemon`)
- [x] Landing page
- [ ] Aider integration
- [ ] Antigravity integration
- [ ] Codex CLI integration
- [ ] Push notifications (FCM)
- [ ] Conversation history persistence
- [ ] File browser widget
- [ ] Voice input
- [ ] iOS app
- [ ] VS Code extension
- [ ] Standalone binary (no Node.js)

---

## 🤝 Contributing

```bash
# Clone
git clone https://github.com/Takezo49/PocketDev.git
cd PocketDev

# Daemon
cd devbox/packages/daemon
npm install
npm run dev

# Flutter app
cd devbox_flutter
flutter run

# Relay
cd devbox/packages/relay
npm install
docker compose up -d  # postgres + redis
npm run dev
```

---

## 📄 License

MIT — do whatever you want.

---

<div align="center">

**Built with obsession by [Takezo49](https://github.com/Takezo49)**

*Ship code from your couch.*

</div>
