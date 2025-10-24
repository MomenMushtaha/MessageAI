## Tech Context

### Platforms & Tooling
- iOS 17+, Xcode 16+, Swift 5
- SwiftUI, Swift Concurrency (`async/await`), SwiftData
- Firebase iOS SDK v11.15.0: Auth, **Realtime Database**, Messaging, Analytics, Storage
- Firebase Cloud Functions (Node.js 18+)

### Dependencies & setup
- Managed via Swift Package Manager (SPM)
- Firebase configured with `GoogleService-Info.plist`
- **Realtime Database persistence enabled with `isPersistenceEnabled = true`**

### Local development
1. Open `MessageAI.xcodeproj`
2. Ensure Firebase plist exists and services enabled (Auth, **Realtime Database**, Messaging)
3. Build and run on iOS 17+ simulator/device

### Backend/emulators
- Cloud Functions: `functions/` with npm scripts for serve/deploy/logs
- Emulator usage available via Firebase CLI; see `functions/README.md`
- **Cloud Functions now use Realtime Database triggers**

### Key services
- `AuthService` – authentication, profile, privacy setting updates (uses Realtime Database)
- `ChatService` – conversations, messages (simplified version using Realtime Database)
- `PresenceService` – online presence + last seen (uses Realtime Database)
- `MediaService` – image/video/audio uploads to Storage
- `NotificationService`/`PushNotificationService` – in-app banners and FCM (uses Realtime Database)
- `LocalStorageService` – SwiftData-backed offline cache
- `CacheManager`, `RateLimiter`, `PerformanceMonitor`, `ErrorRecoveryService`

### Database Migration Notes
- **Migrated from Firestore to Realtime Database**
- Key API changes:
  - `Firestore.firestore()` → `Database.database().reference()`
  - `collection("x").document("y")` → `child("x").child("y")`
  - `setData()` → `setValue()`
  - `updateData()` → `updateChildValues()`
  - `getDocument()` → `getData()`
  - `addSnapshotListener` → `observe(.value)`
  - `FieldValue.serverTimestamp()` → `ServerValue.timestamp()`
  - `Timestamp` → TimeInterval (milliseconds since epoch)
  - `ListenerRegistration` → `DatabaseHandle`


