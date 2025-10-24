## System Patterns

### Architecture
- SwiftUI app entry at `MessageAI/MessageAIApp.swift` configures Firebase and SwiftData
- Service layer singletons (e.g., `AuthService.shared`, `ChatService.shared`) expose `@Published` state on `@MainActor`
- **Realtime Database observers** for conversations/messages with debounced UI updates
- Local persistence via SwiftData (`LocalMessage`, `LocalConversation`) through `LocalStorageService`
- AWS S3 + CloudFront for media; Cloud Functions in `functions/` for push notifications
- **Realtime Database structure**: flat paths like `users/{userId}`, `conversations/{convId}/messages/{msgId}`

### Design patterns
- Optimistic UI: create local message immediately, then confirm/rollback after Firestore write
- Batching: Firestore `batch` updates for message + conversation metadata
- Debounce: small `Task.sleep` delays to coalesce rapid snapshot updates
- Pagination: `limit(toLast:)` + manual older-load with `start(after:)`
- Caching: `CacheManager` for users and message lists; NSCache with limits
- Error recovery: `ErrorRecoveryService` with exponential backoff and rollback hooks
- Rate limiting: `RateLimiter` gating send frequency
- Performance monitoring: `PerformanceMonitor` for send durations and milestones
- Privacy-aware reads: conditional read receipts based on user settings

### Component relationships
- Views → Services (Auth/Chat/Presence/Notification/Media) → Firebase (Auth/Database/Messaging/Analytics) + S3 uploads for media
- `NotificationService` for in-app banners; `PushNotificationService` for badges/FCM
- `PresenceService` manages heartbeats and last seen timestamps

### Data modeling
- **Realtime Database paths**: `users/{userId}`, `conversations/{convId}`, `conversations/{convId}/messages/{msgId}`
- `Conversation`: participant IDs, admin IDs, pinned messages, unread counts
- `Message`: text, status, deliveredTo, readBy, edit history, reactions, media metadata
- Local mirror via SwiftData for instant load and offline access
- **Timestamps stored as milliseconds since epoch** (not Firestore Timestamp objects)

### Testing and reliability
- Integration tests under `MessageAITests/`
- Offline-first: writes queued locally, listeners reconcile state when online
- Rollbacks: local optimistic updates revert on server failure

