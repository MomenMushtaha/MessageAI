# MessageAI - Features Not Yet Implemented

**Last Updated:** 2025-10-22
**Source:** Cross-referenced against IMPLEMENTATION_PLAN.md and MICRO_STEP_IMPLEMENTATION_GUIDE.md

---

## ⚠️ Blocked Features (Require Dependencies)

### Phase 3: Media Support - BLOCKED
**Blocker:** Firebase Storage dependency not added to project

#### 3.1.3: Firebase Storage Upload (BLOCKED)
- [ ] Add FirebaseStorage to Package.swift/dependencies
- [ ] Uncomment MediaService.swift upload code (currently has TODO)
- [ ] Test image upload to Storage path: `/conversations/{id}/media/{messageId}`

#### 3.2: Image Messages Display
- [ ] Create `ImageMessageView.swift` component
- [ ] Add async image loading with AsyncImage
- [ ] Show loading indicator while downloading
- [ ] Cache images with NSCache (already have cache, need integration)
- [ ] Create `FullScreenImageView.swift` for tap-to-view
- [ ] Implement pinch-to-zoom
- [ ] Add "Save to Photos" option
- [ ] Request Photos library permission

#### 3.3: Video Messages
- [ ] Add video picker to photo picker
- [ ] Implement video compression (max 50MB, 720p)
- [ ] Generate video thumbnail (first frame)
- [ ] Upload video with progress indicator
- [ ] Create `VideoPlayerView.swift` with AVPlayer
- [ ] Add play/pause, seek, volume controls
- [ ] Display video thumbnail with play button overlay
- [ ] Cache videos (100MB limit)

#### 3.4: File Attachments
- [ ] Add document picker integration
- [ ] Support PDF, DOCX, XLSX, TXT file types
- [ ] Create `FileMessageView.swift` component
- [ ] Show file name, size, type icon
- [ ] Implement download and "Open with..." sheet
- [ ] Add file size validation (max 25MB)
- [ ] File type validation

---

## 🔧 Core Features - Not Implemented

### Phase 2.3: Message Forwarding - UI Integration Missing
**Backend complete, UI needs hookup:**
- [ ] Add "Load More Messages" UI button when scrolling to top
- [ ] Show loading indicator while fetching older messages
- [ ] Integrate `chatService.loadOlderMessages()` in ConversationDetailView
- [ ] Maintain scroll position after loading older messages
- [ ] Show "No more messages" when reaching beginning

### Phase 4.2: Group Settings & Customization
- [ ] Create "Edit Group" button (admins only)
- [ ] Allow changing group name (text field)
- [ ] Add group description field (optional)
- [ ] Implement group avatar upload (use MediaService)
- [ ] Add "Mute notifications" toggle (per user setting)
- [ ] Show member count in GroupDetailsView
- [ ] Show "Joined [date]" for each member
- [ ] "Leave Group" option for members
- [ ] Prevent admin from leaving if last admin

### Phase 4.3: Group Permissions & Message Controls
- [ ] Add `settings` object to Conversation model
- [ ] Add `onlyAdminsCanMessage: Bool` setting
- [ ] Add `onlyAdminsCanAddUsers: Bool` setting
- [ ] Create settings UI toggles in GroupDetailsView
- [ ] Enforce permissions in ChatService before sending
- [ ] Show error if non-admin tries to message
- [ ] Grey out text input if user can't message
- [ ] Show appropriate permission error messages

---

## 🎨 Advanced Features - Not Implemented

### Phase 6.2: User Profile Pages
- [ ] Create `Views/Profile/UserProfileView.swift`
- [ ] Show avatar, display name, email, joined date
- [ ] Add "Message" button to start direct chat from profile
- [ ] Create `Views/Profile/EditProfileView.swift`
- [ ] Implement avatar upload (reuse MediaService)
- [ ] Allow changing display name
- [ ] Add bio/status field (optional)
- [ ] Show shared groups list (if any)
- [ ] Add navigation from user avatars throughout app (tap avatar → profile)
- [ ] Add profile navigation from ChatListView menu

### Phase 6.3: Privacy Controls
- [ ] Add privacy settings to User model:
  - `showReadReceipts: Bool`
  - `showOnlineStatus: Bool`
  - `showLastSeen: Bool`
- [ ] Create `Views/Settings/PrivacySettingsView.swift`
- [ ] Add toggle switches for each privacy setting
- [ ] Modify ChatService to honor read receipt settings
- [ ] Modify PresenceService to honor online status settings
- [ ] Show generic "Read" instead of names if receipts disabled
- [ ] Save settings to Firestore `/users/{id}/settings`
- [ ] Block users feature
- [ ] Mute conversations feature

### Phase 6.4: Message Pinning
- [ ] Add `pinnedMessageIds: [String]` to Conversation model
- [ ] Add "Pin" to message long-press menu (admins only in groups)
- [ ] Implement `pinMessage()` and `unpinMessage()` in ChatService
- [ ] Show pinned message banner at top of conversation
- [ ] Limit to 3 pinned messages per conversation
- [ ] Create "View all pinned messages" sheet
- [ ] Show pin icon on pinned message bubbles
- [ ] Tap pinned banner to scroll to original message

### Phase 6.5: Accessibility & Localization
- [ ] Audit all views for VoiceOver support
- [ ] Add `.accessibilityLabel()` to all interactive elements
- [ ] Add `.accessibilityHint()` for complex gestures
- [ ] Test entire app with VoiceOver enabled
- [ ] Support Dynamic Type (larger text sizes)
- [ ] Add semantic colors for better Dark Mode
- [ ] Create `Localizable.strings` files
- [ ] Extract all user-facing strings
- [ ] Add language support: Spanish, French (or others)
- [ ] Test with screen reader
- [ ] Test gesture announcements

### Phase 6.6: Analytics & Crash Reporting
- [ ] Enable Firebase Analytics in project
- [ ] Enable Firebase Crashlytics
- [ ] Create `Services/AnalyticsService.swift`
- [ ] Track events:
  - User signup/login
  - Message sent/received count
  - Conversation created
  - Media uploaded
  - Screen views
- [ ] Add custom event parameters
- [ ] Set user properties
- [ ] Test analytics in Firebase Console
- [ ] Trigger test crash for Crashlytics
- [ ] Enable Analytics debug mode for testing

---

## 🔒 Production Hardening - Phase 7

### 7.1: Firestore Security Rules
- [ ] Create `firestore.rules` file
- [ ] Move from "test mode" to production rules
- [ ] Add authentication checks
- [ ] `/users` rules: users can only edit own profile
- [ ] `/conversations` rules: only participants can read/write
- [ ] `/messages` rules: only participants can read, only sender can edit
- [ ] Add field validation (types, required fields)
- [ ] Test rules with Firebase Emulator
- [ ] Deploy rules to production Firebase project

### 7.2: Rate Limiting & Abuse Prevention
**Cloud Functions:**
- [ ] Add rate limits:
  - Max 100 messages per minute per user
  - Max 10 conversations created per hour
  - Max 5 image uploads per minute
- [ ] Implement spam detection (repeated identical messages)
- [ ] Add cooldown after failed operations
- [ ] Log abuse attempts to Cloud Functions logs

**Client-side:**
- [ ] Client-side validation before sending
- [ ] Show user-friendly rate limit errors
- [ ] Implement message send cooldown UI

### 7.3: Error Recovery & Rollback
- [ ] Implement rollback for failed optimistic updates
- [ ] Add retry logic with exponential backoff
- [ ] Show specific error messages:
  - Network errors
  - Authentication errors
  - Permission errors
- [ ] Add error recovery UI (retry button)
- [ ] Log errors to Crashlytics
- [ ] Handle edge cases gracefully
- [ ] Test all failure scenarios

### 7.4: Performance Optimization
- [ ] Add Firestore composite indexes for complex queries
- [ ] Optimize image loading caching strategy
- [ ] Reduce Firestore reads with smarter caching
- [ ] Add Firebase Performance Monitoring SDK
- [ ] Add custom traces for:
  - Message send time
  - Conversation load time
  - Image upload time
- [ ] Monitor and alert on slow operations
- [ ] Optimize app bundle size
- [ ] Improve launch time
- [ ] Test with slow network (2G simulation)
- [ ] Profile with Instruments
- [ ] Monitor memory usage

### 7.5: Comprehensive Testing
- [ ] Write unit tests for:
  - ChatService
  - AuthService
  - PresenceService
  - MediaService
  - PushNotificationService
- [ ] Write UI tests for:
  - Login/signup flow
  - Send message flow
  - Create conversation flow
  - Group creation flow
- [ ] Test edge cases
- [ ] Regression testing on all features
- [ ] Test on multiple devices (iPhone, iPad)
- [ ] Test on different iOS versions (16, 17, 18)
- [ ] Test with different network conditions
- [ ] Accessibility audit
- [ ] Security audit
- [ ] Create test plan document
- [ ] Manual QA pass
- [ ] Achieve >80% code coverage

---

## 🚀 Phase 8: Optional Advanced Features

### 8.1: End-to-End Encryption
- [ ] Research Signal Protocol or similar
- [ ] Implement key exchange mechanism
- [ ] Encrypt messages client-side before upload
- [ ] Store encrypted messages in Firestore
- [ ] Decrypt on recipient device
- [ ] Handle key rotation
- [ ] Handle device changes
- [ ] Add "Verified" badge for encrypted chats
- [ ] Key safety number verification

### 8.2: Voice Messages
- [ ] Create voice recording UI with waveform
- [ ] Implement AVAudioRecorder for recording
- [ ] Add recording timer
- [ ] Compress audio (AAC format)
- [ ] Upload to Storage (reuse MediaService)
- [ ] Create audio player UI component
- [ ] Add playback controls (play/pause, seek)
- [ ] Show audio duration
- [ ] Generate and display waveform
- [ ] Auto-download vs manual download option
- [ ] Add microphone permission request

### 8.3: Video/Voice Calling
- [ ] Choose WebRTC framework (or Twilio/Agora SDK)
- [ ] Integrate calling SDK
- [ ] Implement call signaling via Firestore
- [ ] Create incoming call UI
- [ ] Create outgoing call UI
- [ ] Create active call UI
- [ ] Request microphone permission
- [ ] Request camera permission
- [ ] Implement call notifications
- [ ] Handle call state management
- [ ] Add speaker toggle
- [ ] Add mute toggle
- [ ] Add video on/off toggle
- [ ] Test on different networks (WiFi, 4G, 5G)
- [ ] Handle call interruptions

### 8.4: Stories/Status Updates
- [ ] Create Stories model (24-hour expiry)
- [ ] Add camera integration for story creation
- [ ] Add gallery picker for stories
- [ ] Implement story viewer UI
- [ ] Add story ring indicators on user avatars
- [ ] Implement auto-advance between stories
- [ ] Add view count
- [ ] Show viewer list to story creator
- [ ] Create Cloud Function for auto-delete after 24 hours
- [ ] Add "Reply to story" feature

### 8.5: Message Translation
- [ ] Integrate Google Translate API or Firebase ML Kit
- [ ] Add "Translate" option to message menu
- [ ] Detect message language automatically
- [ ] Translate to user's preferred language
- [ ] Show original + translation
- [ ] Cache translations in memory
- [ ] Handle translation errors gracefully
- [ ] Add language preference setting

### 8.6: Chatbots & AI Integration
- [ ] Create bot user accounts in Firestore
- [ ] Integrate OpenAI API or similar
- [ ] Create bot conversation handling
- [ ] Implement bot commands (e.g., /help, /weather)
- [ ] Add "Add Bot" UI in settings
- [ ] Handle bot responses asynchronously
- [ ] Add typing indicators for bots
- [ ] Create sample bots:
  - Assistant bot
  - Translator bot
  - Game bot
- [ ] Bot command auto-complete

---

## 📋 UI/UX Improvements Needed

### ConversationDetailView
- [ ] Add "Load More" button for pagination (currently only backend exists)
- [ ] Show "Scroll to bottom" button when scrolled up
- [ ] Add "New messages" separator line
- [ ] Improve message input with multi-line support
- [ ] Add "Cancel" button when editing message
- [ ] Show message timestamp on long-press
- [ ] Add haptic feedback for reactions

### ChatListView
- [ ] Add swipe to mark as read/unread
- [ ] Add archive conversation feature
- [ ] Show draft message preview
- [ ] Add conversation pinning to top
- [ ] Add last message timestamp formatting (e.g., "Yesterday", "Monday")
- [ ] Show sending/failed status in conversation preview

### GroupDetailsView
- [ ] Add participant search
- [ ] Show admin badge on admin users
- [ ] Add "Make Admin" option
- [ ] Add "Remove Admin" option
- [ ] Show participant join date
- [ ] Add media gallery tab (all images/videos)
- [ ] Add links tab (all shared links)
- [ ] Add documents tab

### General UI
- [ ] Create app settings page
- [ ] Add notification settings
- [ ] Add account settings (change email, password)
- [ ] Add about page
- [ ] Add privacy policy page
- [ ] Add terms of service page
- [ ] Add app version and build number display

---

## 🔔 Push Notification Enhancements

### Client-side
- [ ] Add "Reply" notification action
- [ ] Add "Mark as Read" notification action
- [ ] Implement quick reply from notification
- [ ] Add notification sounds selection
- [ ] Filter notifications when user is viewing conversation
- [ ] Group notifications: "3 new messages from Alice"

### Cloud Functions
- [ ] Don't notify if recipient is online in that conversation
- [ ] Add message grouping for multiple messages
- [ ] Add image thumbnails to notifications (rich media)
- [ ] Optimize badge count calculation (currently queries all conversations)

---

## 📱 Info.plist Requirements (Manual Xcode Setup)

These need to be added via Xcode Project Settings:

### Required Privacy Descriptions
- [ ] `NSPhotoLibraryUsageDescription` - "We need access to your photos to send images"
- [ ] `NSCameraUsageDescription` - "We need camera access to take photos and videos"
- [ ] `NSMicrophoneUsageDescription` - "We need microphone access for voice messages and calls"
- [ ] `NSUserNotificationsUsageDescription` - Already documented in PUSH_NOTIFICATION_SETUP.md

### Required Background Modes
- [ ] Remote notifications (already documented)
- [ ] Audio (for voice/video calls - Phase 8)
- [ ] VoIP (for video calling - Phase 8)

### Required Capabilities (Xcode)
- [ ] Push Notifications capability (already documented)
- [ ] Background Modes capability (already documented)
- [ ] Sign in with Apple (optional future feature)

---

## 🐛 Known Issues & Technical Debt

### High Priority
1. **Firebase Storage**: Not configured - blocks all media features
2. **Pagination UI**: Backend ready, UI hookup missing
3. **Message editing**: Edit option not showing in MessageActionsSheet (needs "Edit" button)

### Medium Priority
1. **Performance**: Large conversation (1000+ messages) not tested
2. **Offline sync**: Pending messages queue needs better UI feedback
3. **Error handling**: Some failures don't show user-friendly messages
4. **Group chat**: No system messages for admin actions (e.g., "User added to group")

### Low Priority
1. **Search**: No search in ChatListView (only in conversations)
2. **Timestamps**: Message timestamps only show on hover
3. **Dark Mode**: Some colors may not be optimized for dark mode
4. **iPadOS**: Not optimized for iPad split-screen

---

## 📊 Testing Gaps

### Unit Tests Needed
- [ ] ChatService tests
- [ ] AuthService tests
- [ ] PresenceService tests
- [ ] MediaService tests
- [ ] PushNotificationService tests
- [ ] LocalStorageService tests
- [ ] Message model tests
- [ ] Conversation model tests

### UI Tests Needed
- [ ] Login flow
- [ ] Signup flow
- [ ] Send message flow
- [ ] Create conversation
- [ ] Create group
- [ ] Delete message
- [ ] Edit message
- [ ] Forward message
- [ ] React to message

### Integration Tests Needed
- [ ] Message delivery end-to-end
- [ ] Read receipts
- [ ] Typing indicators
- [ ] Push notifications
- [ ] Offline sync
- [ ] Media upload/download

---

## 🎯 Next Recommended Steps

Based on priority and dependencies:

1. **Add Firebase Storage** (unblocks Phase 3)
   - Update Package.swift or Podfile
   - Uncomment MediaService code
   - Test image upload

2. **Complete Message Actions UI**
   - Add "Edit" button to MessageActionsSheet
   - Add "Load More" pagination UI
   - Test edit and pagination flows

3. **Group Settings** (Phase 4.2)
   - Relatively independent
   - High user value
   - Not blocked by dependencies

4. **User Profiles** (Phase 6.2)
   - High visibility feature
   - Can be done without media if Storage not ready
   - Good user experience improvement

5. **Security Rules** (Phase 7.1)
   - **CRITICAL for production**
   - Currently in test mode
   - Security risk if deployed as-is

---

## Summary Statistics

- **Completed Features:** ~45%
- **Blocked by Dependencies:** ~15% (Phase 3 Media)
- **Ready to Implement:** ~40%
- **Total Estimated Remaining:** ~8-10 weeks for Phases 3-7
- **Optional Features (Phase 8):** +4-8 weeks

**Critical Path to Production:**
1. Add Firebase Storage (1 day)
2. Complete Phase 3 Media (2-3 weeks)
3. Complete Phase 6 Advanced Features (2-3 weeks)
4. **Complete Phase 7 Production Hardening (1-2 weeks)** ← REQUIRED
5. Comprehensive testing (1 week)

**Estimated Time to Production-Ready:** 6-9 weeks
