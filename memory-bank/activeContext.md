## Active Context

Date: 2025-10-24

### Current focus
- **MAJOR MIGRATION COMPLETE**: Migrated from Firestore to Firebase Realtime Database
- **ALL FEATURES IMPLEMENTED**: Restored full functionality with Realtime Database

### Recent changes
- Created `memory-bank/` with core files and populated initial content
- Added base project rules under `.cursor/rules/base.mdc`
- **Migrated entire app from Firestore to Realtime Database**:
  - Updated SPM dependencies (replaced FirebaseFirestore with FirebaseDatabase)
  - Refactored all services: AuthService, ChatService, PresenceService, PushNotificationService
  - Updated MessageAIApp initialization
  - Migrated Cloud Functions to use Realtime Database triggers
  - Updated imports across views and services
- **Implemented all features in ChatService**:
  - Message delivered/read tracking with privacy settings
  - Message editing (15min window) with edit history
  - Message deletion (for self and for everyone)
  - Reactions (toggle support for any emoji)
  - Message forwarding to multiple conversations
  - Message pinning (max 3 per conversation, admin-only for groups)
  - Message search (local cache)
  - Pagination (load older messages)
  - Media messages (image, video, voice) with Storage upload
  - Group management (add/remove participants, admins, permissions)
- **Enhanced ConversationDetailView** with:
  - Context menus for message actions
  - Reaction picker
  - Photo picker for images
  - Edit sheet
  - Delete confirmations
  - Typing indicators
  - Load more messages
  - Media display with thumbnails
  - Status indicators

### Next steps
- Test the migrated app to ensure Realtime Database integration works
- Update security rules for Realtime Database (currently using Firestore rules)
- Consider data migration strategy if existing Firestore data needs to be preserved

### Active decisions
- Use optimistic UI, debounced listeners, and batch writes as standard
- Keep performance instrumentation around message send paths
- **NEW**: Realtime Database paths use forward-slash notation (e.g., `users/userId/fcmTokens`)
- **NEW**: ServerValue.timestamp() replaces FieldValue.serverTimestamp()
- **NEW**: DatabaseHandle replaces ListenerRegistration for observers

### Risks/considerations
- Ensure documentation stays in sync with evolving code (treat Memory Bank as source of truth for context)
- **NEW**: Realtime Database has different querying capabilities than Firestore (no compound queries)
- **NEW**: Need to update database.rules.json for Realtime Database security
- **NEW**: Simplified ChatService may need additional methods restored (media, reactions, editing, etc.)


