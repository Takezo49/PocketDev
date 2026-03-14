# DevBox — Product Plan

## What It Is

A mobile app that lets developers use their desktop AI tools (Claude CLI, Cursor, Aider, any AI) directly from their phone. Your desktop does the work. Your phone is the control panel.

---

## How It Works (User Perspective)

### First Time Setup

1. Developer installs a small daemon on their desktop (one command)
2. A QR code appears on their desktop screen
3. They open the DevBox mobile app and scan the QR
4. Paired. Done. Never do this again.

### Daily Use

1. Developer is lying in bed / on a train / at a cafe
2. Opens DevBox on phone
3. Sees their desktop is online, sees active AI sessions
4. Taps into a Claude CLI session (or starts a new one)
5. Types or **speaks**: "Fix the failing test in the payment module"
6. Claude CLI **on their desktop** starts working
7. Phone shows what's happening in real-time:
   - Files being read (collapsible cards)
   - Code changes as clean diffs (green/red)
   - Commands being run with live output
   - Test results (pass/fail summary)
8. Claude asks for permission → phone buzzes, big **Approve / Reject** buttons appear
9. Developer taps **Approve**
10. Done. Code fixed, tests passing, pushed to git. All from bed.

---

## Core Features

### 1. Universal AI Tool Remote Control

- Works with **any** CLI-based AI tool: Claude CLI, Aider, Codex CLI, etc.
- Start, stop, and switch between multiple AI sessions from your phone
- Whatever AI tool you use on desktop — now you can use it from anywhere

### 2. Smart Mobile Interface (Not Raw Terminal)

- AI output is parsed and displayed as **mobile-native cards**:
  - **Message cards** — AI's text responses
  - **Diff cards** — file changes with proper syntax highlighting
  - **Command cards** — shell commands with output
  - **Test cards** — pass/fail summary
  - **Approval cards** — big tap-friendly approve/reject buttons
- Not a remote desktop. Not a tiny terminal. A proper mobile-first UI.

### 3. Voice-First Input

- Hold the mic button and **speak** your prompt
- "Add authentication middleware to the API routes"
- Phone transcribes → sends to your desktop AI tool
- You can review the transcription before sending
- Perfect for when you don't want to type on a small keyboard

### 4. Smart Notifications

- Give your AI a big task, close the app, go do something else
- Phone buzzes when it's done: *"Claude finished. 5 files edited, 12 tests pass. Tap to review."*
- Buzzes immediately when approval is needed — never blocks the AI from working
- Notification categories: done, needs approval, error, test failure

### 5. File Browser

- Browse your entire project file tree from your phone
- Tap any file to view with syntax highlighting
- See what files were changed in the current session
- Search files by name

### 6. Live Preview

- Your app runs on your desktop
- DevBox tunnels it to your phone
- See your actual running web app on your phone browser
- Hot reload — code changes reflect instantly

### 7. Session Persistence

- Close the app, come back hours later — everything is still there
- Full history of what the AI did while you were away
- Pick up exactly where you left off
- "Where was I?" is never a problem

### 8. Multi-Machine Support

- Connect to multiple desktops (work PC, home PC, cloud server)
- Switch between machines from the home screen
- Each machine has its own sessions and projects

### 9. Wake-on-LAN

- Your desktop is asleep at home
- Open DevBox → tap "Wake" → PC boots up → connected in 30 seconds
- Start working without being anywhere near your machine

### 10. Remote Access (Anywhere)

- Works on same WiFi instantly (local connection)
- Works from anywhere via secure tunnel (coffee shop, train, another country)
- Encrypted end-to-end
- No port forwarding or networking knowledge needed

---

## Advanced Features (Post-Launch)

### Workflow Automation

- Set up recurring tasks: *"Every morning at 9am: git pull, run tests, send me a summary"*
- Wake-up notification: *"3 projects green, 1 failing test in auth-service — tap to fix"*

### Collaborative Sessions

- Share a session link with a teammate
- They see everything you see — diffs, commands, AI conversation
- Pair program from two phones

### Quick Actions

- Pre-set common commands: "Run tests", "Git status", "Deploy to staging"
- One-tap execution without typing anything
- Customizable per project

### Apple Watch / Wear OS

- Glanceable: session status, test results
- Quick approve from your wrist
- Notification relay

---

## What Makes It Different

| Existing Tool | Problem | DevBox |
|---|---|---|
| Remote Desktop | Laggy pixels, desktop UI crammed on phone, unusable | Mobile-native cards, designed for touch |
| SSH apps (Termius) | Raw terminal text, no diff viewer, no AI awareness | Understands AI tool output, shows rich cards |
| Claude Mobile App | Can't run builds, can't access your files, can't test | Runs on YOUR machine with YOUR full environment |
| Cursor/Copilot Mobile (future) | Only works with THEIR AI | Works with ANY AI tool |

**DevBox is the only app that works with any AI tool you already use and gives you a mobile-native experience on your actual dev machine.**

---

## User Flows

### Flow 1: Fix a Bug From Bed

```
Notification: "CI failed on main"
→ Open DevBox
→ Tap Claude CLI session
→ Speak: "The CI is failing on main, check the logs and fix it"
→ Watch Claude work (read files, find bug, edit code, run tests)
→ See diff card: auth.ts — null check added
→ See test card: 24 passed, 0 failed
→ Tap "Approve & Push"
→ CI goes green
→ Go back to sleep
```

### Flow 2: Code Review From a Cafe

```
Open DevBox
→ Start new session: Claude CLI on frontend repo
→ Type: "Review the latest PR from John and summarize the issues"
→ Claude reads the diff, analyzes the code
→ See message card with review summary
→ Type: "Leave those comments on the PR"
→ Claude posts comments on GitHub
→ Sip coffee
```

### Flow 3: Build a Feature on the Train

```
Open DevBox
→ Speak: "Create a new API endpoint for user preferences
         with GET and PUT, use the same pattern as the
         existing settings endpoint"
→ Watch Claude scaffold the code
→ Review diffs card by card
→ Approve each change
→ Speak: "Write tests for it"
→ Watch tests being created and run
→ All green → Approve & Push
→ Created a feature without touching a keyboard
```

### Flow 4: Monitor Long-Running Task

```
Open DevBox
→ Type: "Upgrade all dependencies to latest and fix any breaking changes"
→ Close the app (this will take a while)
→ 20 minutes later, notification:
  "Claude finished. 12 files edited. 3 tests were fixed. All 89 tests pass."
→ Open app → scroll through all the diffs
→ Approve → Push
```

---

## Security

- **QR code pairing** — no passwords, no accounts to create
- **End-to-end encrypted** — all traffic encrypted
- **Permission levels** — you control what AI can do without asking:
  - Auto-approve: read files, git status, list dirs
  - Ask first: write files, run commands, git push
  - Always ask: delete files, sudo, access secrets
- **Device management** — see all paired devices, revoke any device instantly
- **Kill switch** — one tap to disconnect everything immediately
- **Local-first** — everything stays on your machine, nothing in the cloud (unless you opt into remote access)

---

## Business Model

| Tier | Price | What You Get |
|---|---|---|
| **Free** | $0 | App + daemon + local network + 1 machine + unlimited sessions |
| **Pro** | $9/mo | Remote access + push notifications + wake-on-LAN + 3 machines |
| **Team** | $19/user/mo | Shared machines + collaborative sessions + admin dashboard |

The daemon is **open source**. The app is **free**. Revenue comes from the remote access infrastructure and team features.

---

## Launch Plan

### Phase 1: Build MVP (Weeks 1-2)

- Daemon that wraps Claude CLI
- Mobile app with cards, approve/reject, voice input
- Local network connection + QR pairing

### Phase 2: Polish + Multi-Tool (Weeks 3-5)

- Add Aider support + generic fallback for any CLI tool
- Push notifications
- Session persistence
- File browser

### Phase 3: Remote Access (Weeks 6-7)

- Secure tunnel for remote connections
- Wake-on-LAN
- Connection quality handling

### Phase 4: Launch (Weeks 8-9)

- App Store + Play Store
- npm package for daemon
- Landing page
- Demo video: **"I just shipped a feature from my bed"**
- Launch on Product Hunt, HackerNews, Reddit, Twitter

### The Viral Moment

A 30-second video showing:

- Split screen: phone on left, desktop on right
- Developer in bed, speaks a prompt into phone
- Desktop: Claude CLI starts working automatically
- Phone: diffs appear as cards, tests pass
- Developer taps Approve
- Caption: **"Just fixed a production bug from my bed."**

This video is the entire marketing strategy.

---

## Growth Roadmap

```
Month 1    →  Launch, get first 1,000 users
Month 2-3  →  Add more AI tool parsers based on user requests
Month 4-6  →  Team features, collaborative sessions
Month 6-9  →  Workflow automation, IDE extensions
Month 9-12 →  Apple Watch, widgets, advanced integrations
```
