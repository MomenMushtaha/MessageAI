# Testing Checklist - MessageAI WhatsApp Clone

## ✅ Authentication Testing

### Sign Up
- [ ] Valid email and password (≥6 chars) → Account created
- [ ] Invalid email format → Error message shown
- [ ] Password < 6 characters → Error message shown
- [ ] Empty fields → Error message shown
- [ ] Duplicate email → Error message shown
- [ ] Network error during signup → Error message shown

### Login
- [ ] Valid credentials → Logged in successfully
- [ ] Invalid credentials → Error message shown
- [ ] Empty fields → Error message shown
- [ ] Network error during login → Error message shown

### Logout
- [ ] Logout button → Returns to login screen
- [ ] Presence set to offline on logout
- [ ] Data cleared properly

---

## ✅ Messaging Testing

### Direct Chat (1-on-1)
- [ ] User A sends message → User B receives instantly
- [ ] User B replies → User A receives instantly
- [ ] Messages persist after app restart
- [ ] Empty message prevented (button disabled)
- [ ] Long message (4000+ chars) → Character counter appears
- [ ] Message > 4096 chars → Error shown
- [ ] Rapid message sending (20+ messages) → No duplicates

### Group Chat (3+ users)
- [ ] Create group with 3+ users → All see group in chat list
- [ ] User A sends message → All participants receive
- [ ] Sender names appear above messages
- [ ] Group name displays correctly
- [ ] Tap group header → Participant list shown

### Message Status
- [ ] Message sent → Single checkmark ✓
- [ ] Recipient opens app → Double checkmark ✓✓
- [ ] Recipient opens conversation → Blue checkmark ✓✓ (cyan)
- [ ] Message sending failed → Red exclamation mark
- [ ] Status updates in real-time

---

## ✅ Offline/Online Testing

### Offline Behavior
- [ ] Enable airplane mode → "No Connection" banner appears
- [ ] Send message offline → Shows "sending" spinner
- [ ] Message queued locally
- [ ] Disable airplane mode → Message syncs to Firestore
- [ ] Banner disappears when online

### Sync Testing
- [ ] Force quit app → Relaunch → Messages still there
- [ ] Pending messages sync on reconnect
- [ ] No message loss during offline period
- [ ] Conversations load from local cache (instant)

---

## ✅ Presence Testing

### Online Status
- [ ] User A logs in → Marked online
- [ ] User B sees "Online" in conversation header
- [ ] Green dot appears on User A's avatar in chat list
- [ ] Heartbeat updates every 30 seconds

### Offline Status
- [ ] User A backgrounds app → Marked offline
- [ ] User B sees "Last seen X ago"
- [ ] Green dot disappears
- [ ] Force quit → Status updates to offline

### Last Seen
- [ ] "Last seen just now" (< 1 min)
- [ ] "Last seen 5m ago" (< 1 hour)
- [ ] "Last seen 2h ago" (< 1 day)
- [ ] "Last seen 3d ago" (< 1 week)
- [ ] Updates in real-time

---

## ✅ Notifications Testing

### In-App Notifications
- [ ] User A sends message → User B sees banner (if app open)
- [ ] Banner shows sender name, avatar, message preview
- [ ] Tap banner → Navigates to conversation
- [ ] Tap X → Banner dismisses
- [ ] Auto-dismiss after 4 seconds
- [ ] No notification if conversation already open
- [ ] No notification for own messages
- [ ] Works for both direct and group chats

---

## ✅ UI/UX Testing

### Message Bubbles
- [ ] Sent messages: Blue gradient, right-aligned
- [ ] Received messages: Gray, left-aligned
- [ ] Error messages: Red background
- [ ] Asymmetric corners (WhatsApp-style)
- [ ] Timestamp visible
- [ ] Status icons inside bubble corner

### Animations
- [ ] Messages slide up with spring animation
- [ ] Send button scales when text entered
- [ ] Smooth scrolling to bottom
- [ ] Chat list transitions smoothly
- [ ] 60fps performance (no lag)

### Input Validation
- [ ] Empty message → Button disabled
- [ ] Text entered → Button enabled and blue
- [ ] Character counter appears at 3500 chars
- [ ] Counter turns red > 4096 chars
- [ ] Multi-line text wraps properly

### Loading States
- [ ] Login shows progress indicator
- [ ] Sending message shows spinner
- [ ] Conversations load with smooth transition
- [ ] Empty states show helpful messages

---

## ✅ Edge Cases

### Long Messages
- [ ] 1000 char message → Displays properly
- [ ] 4000 char message → Shows counter
- [ ] 4096 char message → Maximum allowed
- [ ] 5000 char message → Error shown

### Rapid Actions
- [ ] Send 20 messages quickly → All delivered, no duplicates
- [ ] Switch conversations rapidly → No crashes
- [ ] Rapid tap on chat row → No navigation issues
- [ ] Fast scrolling → Smooth, no lag

### Large Datasets
- [ ] 50+ conversations → List scrolls smoothly
- [ ] 100+ messages → Pagination works (only loads last 100)
- [ ] Search with many results → Fast response
- [ ] Group with 10+ participants → Loads correctly

### Network Issues
- [ ] Slow connection → Messages eventually deliver
- [ ] Connection drops mid-send → Message marked as error
- [ ] Retry failed message → Works correctly
- [ ] Poor signal → Graceful degradation

### Empty States
- [ ] New user → "No Conversations" message
- [ ] New conversation → "No messages yet" message
- [ ] No search results → "No users found" message
- [ ] All empty states have helpful text

---

## ✅ Multi-Device Testing

### Two Simulators Side-by-Side
- [ ] Run on iPhone 17 (User A) and iPad (User B)
- [ ] Create accounts on both
- [ ] Start conversation from User A
- [ ] Send messages from both sides
- [ ] Verify real-time sync
- [ ] Test offline on one device
- [ ] Verify read receipts
- [ ] Test presence indicators

### Cross-Session
- [ ] User A logs in on device 1
- [ ] User A logs in on device 2
- [ ] Messages sync across both sessions
- [ ] Read status syncs
- [ ] Presence updates on both

---

## ✅ Performance Benchmarks

### Latency
- [ ] Message send latency < 500ms (on WiFi)
- [ ] Message receive latency < 1 second
- [ ] Read receipt update < 1 second
- [ ] Presence update < 2 seconds

### App Performance
- [ ] Cold start < 2 seconds to chat list
- [ ] Conversation opens < 300ms
- [ ] Scroll maintains 60fps
- [ ] Memory usage stays reasonable
- [ ] No memory leaks (check in Instruments)

### Network Efficiency
- [ ] Minimal bandwidth usage
- [ ] Efficient Firestore queries
- [ ] Local cache works offline
- [ ] No redundant requests

---

## ✅ Regression Testing

After each change, verify:
- [ ] Authentication still works
- [ ] Messaging still works
- [ ] Offline mode still works
- [ ] Presence still works
- [ ] Notifications still work
- [ ] No new crashes
- [ ] No performance degradation

---

## 🐛 Known Issues / Limitations

### Current Limitations
- Background push notifications require Apple Developer account (not implemented)
- Voice messages not implemented (post-MVP)
- Image attachments not implemented (post-MVP)
- Message search not implemented (post-MVP)
- Message reactions not implemented (post-MVP)

### Edge Cases to Improve (Optional)
- Very long conversation (500+ messages) could benefit from lazy loading
- Profile pictures not yet supported (using initials)
- Group admin features not implemented
- Message deletion not implemented
- Edit message not implemented

---

## 📊 Success Criteria

An MVP is considered stable when:
- ✅ All authentication flows work reliably
- ✅ Messages send/receive with < 1 second latency
- ✅ Offline mode works (messages queue and sync)
- ✅ Read receipts work accurately
- ✅ Presence indicators work in real-time
- ✅ No crashes under normal use
- ✅ UI is smooth (60fps)
- ✅ Edge cases handled gracefully
- ✅ Error messages are user-friendly
- ✅ Performance is acceptable

---

## 🧪 Testing Tools

### Manual Testing
- Use 2 simulators side-by-side
- Test on physical device if available
- Use Network Link Conditioner for slow network
- Use airplane mode for offline testing

### Xcode Tools
- Instruments (memory/performance profiling)
- Network Link Conditioner
- Debug View Hierarchy
- Console logs for debugging

### Firebase Console
- View Firestore data in real-time
- Check Authentication users
- Monitor read/write operations
- Verify data structure

---

## 📝 Test Report Template

### Test Session: [Date]
**Tester:** [Name]
**Environment:** iOS 17.0, Simulator/Device

#### Tests Passed: X / Y
- ✅ Authentication: All tests passed
- ✅ Messaging: All tests passed
- ✅ Offline Mode: All tests passed
- ⚠️ Presence: Minor delay observed
- ✅ Notifications: All tests passed

#### Issues Found:
1. [Issue description]
   - Severity: Low/Medium/High
   - Steps to reproduce
   - Expected vs Actual behavior

#### Overall Assessment:
[Ready for production / Needs fixes / Major issues]

