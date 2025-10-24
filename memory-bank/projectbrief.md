## MessageAI Project Brief

### Purpose
Build a production-ready iOS messaging app that showcases modern SwiftUI patterns with a real-time, offline-first architecture powered by Firebase.

### Goals
- Real-time one-to-one and group messaging with message delivery/read status
- Offline-first experience with seamless sync when network restores
- Presence indicators (online/offline, last seen) with 30s heartbeat
- Media messaging (images, videos, voice) with upload progress and thumbnails
- Push and in-app notifications with deep linking
- WhatsApp-inspired, polished UI at 60fps
- Performance-focused: pagination, caching, minimal re-renders

### Non-Goals (current scope)
- End-to-end encryption
- Cross-platform clients (Android/Web)
- Complex admin tooling beyond in-app group admin flows

### Success Criteria
- Perceived send latency <200ms via optimistic UI
- Smooth scrolling at 60fps in large chats
- Significantly reduced Realtime Database reads via caching and selective listeners

### Constraints
- iOS 17+, Xcode 16+, Swift 5
- Firebase iOS SDK v11.15.0 (Auth, Realtime Database, Messaging, Analytics)
- Realtime Database with offline persistence enabled
- AWS S3 bucket + CloudFront distribution for media delivery

### Deliverables
- SwiftUI app with services under `MessageAI/Services/`
- Firebase Cloud Functions for notifications under `functions/`
- Integration tests in `MessageAITests/`

### High-Level Features
- Authentication: Email/Password
- Conversations: Direct and Group (admin permissions, pinned messages)
- Messages: Text, image, video, voice with reactions and editing (media persisted to S3/CloudFront)
- Presence: Online status, last seen, badge counts
- Notifications: In-app banners and FCM push
- Local Storage: SwiftData for messages and conversations
