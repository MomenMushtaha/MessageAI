## Product Context

### Why this exists
Provide a high-quality reference implementation of a modern iOS chat app using SwiftUI and Firebase, demonstrating real-time UX, offline-first behavior, and production patterns.

### Problems solved
- Reliable messaging despite flaky networks (offline cache + sync)
- Immediate feedback on send (optimistic UI)
- Group coordination (admin controls, participant management)
- Scalable media sharing with thumbnails and progress

### Users and scenarios
- New user: quick signup and onboarding to first conversation
- Everyday user: smooth daily messaging with media and reactions
- Group admin: manage members and permissions easily

### Experience principles
- Familiar: WhatsApp-like mental model and micro-interactions
- Fast: minimal perceived latency, responsive at scale
- Clear: readable status (sent/delivered/read) without clutter
- Robust: handles offline/online transitions and retries transparently

### Key flows (happy paths)
1. Signup/login → land on chat list → start a direct or group chat
2. Send text/media → see immediate local send → backend confirms
3. Receive messages → in-app banner → tap to deep link to conversation
4. Mark delivered/read → update badge counts and conversation unread counts

### Guardrails
- Respect user privacy settings (e.g., read receipts visibility)
- Avoid noisy updates: debounce listener-driven UI changes
- Keep memory under control via NSCache limits and cache clearing on logout


