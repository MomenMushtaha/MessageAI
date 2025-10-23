# 🔐 Firebase Security Rules Deployment Guide

## Overview

This guide will walk you through deploying and testing production-ready security rules for MessageAI.

**CRITICAL**: Your database is currently in TEST MODE (anyone can read/write). These rules will secure your data.

---

## 📋 Files Created

1. ✅ `firestore.rules` - Firestore Database security rules
2. ✅ `storage.rules` - Firebase Storage security rules

---

## 🚀 Deployment Methods

### Method 1: Firebase Console (Easiest) ⭐ RECOMMENDED

#### For Firestore Rules:

1. **Open Firebase Console**
   ```
   https://console.firebase.google.com/
   ```

2. **Navigate to Firestore Database**
   - Select your project: "MessageAI" (or whatever you named it)
   - Click "Firestore Database" in left sidebar
   - Click "Rules" tab at the top

3. **Copy & Paste Rules**
   - Open `/Users/momenmush/Downloads/MessageAI/firestore.rules`
   - Copy ALL the contents
   - Paste into the Firebase Console editor
   - Click "Publish"

4. **Wait for Confirmation**
   - You'll see "Rules published successfully"
   - Deployment takes ~30 seconds

#### For Storage Rules:

1. **Navigate to Storage**
   - Click "Storage" in left sidebar
   - Click "Rules" tab at the top

2. **Copy & Paste Rules**
   - Open `/Users/momenmush/Downloads/MessageAI/storage.rules`
   - Copy ALL the contents
   - Paste into the Firebase Console editor
   - Click "Publish"

---

### Method 2: Firebase CLI (Advanced)

#### Prerequisites:
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done)
cd /Users/momenmush/Downloads/MessageAI
firebase init
```

#### Deploy Rules:
```bash
# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Storage rules only
firebase deploy --only storage:rules

# Deploy both
firebase deploy --only firestore:rules,storage:rules
```

---

## 🧪 Testing Your Security Rules

### Test 1: Unauthenticated Access (Should FAIL)

Try to access Firestore without authentication:

```swift
// This should FAIL with permission denied
let db = Firestore.firestore()
db.collection("conversations").getDocuments { snapshot, error in
    // Should receive permission denied error
    print("Error: \(error?.localizedDescription ?? "Unknown")")
}
```

**Expected Result**: ❌ Permission denied error

---

### Test 2: Authenticated User Reading Own Data (Should SUCCEED)

```swift
// Login first
try await AuthService.shared.login(email: "test@example.com", password: "password")

// This should SUCCEED
let conversations = try await ChatService.shared.conversations
print("✅ Successfully loaded \(conversations.count) conversations")
```

**Expected Result**: ✅ Success

---

### Test 3: User Trying to Read Another User's Profile (Should SUCCEED)

Users can read other profiles (to display names/avatars):

```swift
let otherUser = try await ChatService.shared.getUser(userId: "other-user-id")
print("✅ Can read other user's profile: \(otherUser.displayName)")
```

**Expected Result**: ✅ Success (profiles are public for authenticated users)

---

### Test 4: User Trying to Edit Another User's Profile (Should FAIL)

```swift
// Try to update another user's profile
let db = Firestore.firestore()
try await db.collection("users").document("other-user-id").updateData([
    "displayName": "Hacked Name"
])
```

**Expected Result**: ❌ Permission denied error

---

### Test 5: User Sending Message to Conversation They're In (Should SUCCEED)

```swift
// User is a participant
try await ChatService.shared.sendMessage(
    conversationId: "valid-conversation-id",
    senderId: authService.currentUser!.id,
    text: "Hello!"
)
```

**Expected Result**: ✅ Success

---

### Test 6: User Sending Message to Conversation They're NOT In (Should FAIL)

```swift
// User is NOT a participant
try await ChatService.shared.sendMessage(
    conversationId: "other-conversation-id",
    senderId: authService.currentUser!.id,
    text: "Trying to hack!"
)
```

**Expected Result**: ❌ Permission denied error

---

### Test 7: User Editing Their Own Message (Should SUCCEED if <15 min)

```swift
// Within 15 minutes of sending
try await ChatService.shared.editMessage(
    messageId: "message-id",
    conversationId: "conversation-id",
    newText: "Edited text"
)
```

**Expected Result**: ✅ Success (if within 15 minutes)

---

### Test 8: User Editing Someone Else's Message (Should FAIL)

```swift
// Try to edit another user's message
try await ChatService.shared.editMessage(
    messageId: "other-user-message-id",
    conversationId: "conversation-id",
    newText: "Hacked text"
)
```

**Expected Result**: ❌ Permission denied error

---

### Test 9: Non-Admin Trying to Remove Group Member (Should FAIL)

```swift
// User is participant but NOT admin
try await ChatService.shared.removeParticipant(
    conversationId: "group-id",
    userId: "member-to-remove",
    adminId: "current-user-id" // Not actually admin
)
```

**Expected Result**: ❌ Permission denied error

---

### Test 10: Admin Removing Group Member (Should SUCCEED)

```swift
// User IS admin
try await ChatService.shared.removeParticipant(
    conversationId: "group-id",
    userId: "member-to-remove",
    adminId: "admin-user-id" // Actually admin
)
```

**Expected Result**: ✅ Success

---

## 🔍 Rule Breakdown

### What's Protected:

#### ✅ Users Collection
- ✅ Anyone can read user profiles (for displaying names)
- ✅ Users can only edit their own profile
- ✅ Can't change email or user ID
- ✅ Can't delete profiles

#### ✅ Conversations Collection
- ✅ Only participants can read conversations
- ✅ Anyone can create conversations (if they include themselves)
- ✅ Participants can update metadata (last message, etc.)
- ✅ Only admins can modify group settings
- ✅ Admins can delete groups, participants can delete direct chats

#### ✅ Messages Sub-Collection
- ✅ Only participants can read messages
- ✅ Only participants can send messages
- ✅ Senders can edit their own messages (within 15 min)
- ✅ Senders can delete their own messages
- ✅ Anyone can mark messages as deleted FOR THEMSELVES
- ✅ Recipients can mark messages as delivered/read
- ✅ Anyone can add/remove reactions

#### ✅ Typing Status
- ✅ Participants can see who's typing
- ✅ Users can only update their own typing status

#### ✅ Storage
- ✅ Profile images: Anyone can read, only owner can write
- ✅ Conversation media: Authenticated users can read, uploader can write/delete
- ✅ File size limits enforced (images: 10MB, videos: 100MB)
- ✅ File type validation (images, videos, documents only)

---

## ⚠️ Important Notes

### 1. Test Mode Warning

Your database is currently set to:
```javascript
allow read, write: if request.time < timestamp.date(2025, 11, 22);
```

**This EXPIRES on November 22, 2025!**

After deploying these rules, your database will be properly secured indefinitely.

---

### 2. Breaking Changes

After deploying these rules, some operations will fail if your app tries to:
- Access data without authentication
- Read conversations the user isn't part of
- Edit messages older than 15 minutes
- Modify data they don't have permission for

**Make sure your app handles these permission errors gracefully!**

---

### 3. Cloud Functions Impact

If you add Cloud Functions later, you'll need to use the Firebase Admin SDK which bypasses these rules.

Example:
```javascript
// Cloud Functions have full access
const admin = require('firebase-admin');
admin.initializeApp();

// This works even with rules
await admin.firestore().collection('users').doc(userId).update({...});
```

---

## 🐛 Troubleshooting

### Issue: "Permission denied" errors everywhere

**Cause**: User is not authenticated
**Fix**: Make sure user is logged in before accessing data

```swift
guard authService.currentUser != nil else {
    print("❌ User not authenticated")
    return
}
```

---

### Issue: Can't read conversations

**Cause**: User is not in `participantIds` array
**Fix**: Ensure conversation includes current user:

```swift
let conversationData = [
    "participantIds": [currentUserId, otherUserId], // ← Must include current user
    "type": "direct",
    "createdAt": FieldValue.serverTimestamp()
]
```

---

### Issue: Can't edit message

**Cause**: Message is older than 15 minutes
**Fix**: Check message age before allowing edit:

```swift
func canEdit(message: Message) -> Bool {
    let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
    return message.createdAt > fifteenMinutesAgo
}
```

---

### Issue: Group admin operations failing

**Cause**: `adminIds` array not set or user not in it
**Fix**: When creating groups, set admins:

```swift
let conversationData = [
    "type": "group",
    "participantIds": [user1, user2, user3],
    "adminIds": [user1], // ← Creator should be admin
    "groupName": "My Group"
]
```

---

## 📊 Monitoring Security Rules

### Firebase Console

1. Go to Firebase Console → Firestore → Rules
2. Click "View detailed rules execution history"
3. See which rules are being triggered
4. Identify permission denied errors

### Logs

Look for these in your app:
```
❌ Error: Permission denied
❌ Error: PERMISSION_DENIED
❌ Error: Missing or insufficient permissions
```

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] Test with 2+ user accounts
- [ ] Test all CRUD operations (Create, Read, Update, Delete)
- [ ] Test group admin operations
- [ ] Test message editing/deleting
- [ ] Test with unauthenticated requests (should fail)
- [ ] Test error handling in app
- [ ] Monitor Firebase Console for permission errors
- [ ] Document any custom rules you added

---

## 🚀 Next Steps

After deploying these rules:

1. ✅ Test thoroughly with multiple user accounts
2. ✅ Update error handling in your app
3. ✅ Monitor Firebase Console for issues
4. ✅ Create the 4 missing UI views
5. ✅ Deploy to TestFlight

---

## 📞 Need Help?

If you encounter issues:

1. Check Firebase Console logs
2. Use Firebase Emulator to test rules locally
3. Review the rule functions in `firestore.rules`
4. Make sure your app includes authentication tokens

---

## 🎉 Success Criteria

Your rules are working correctly when:

✅ Authenticated users can access their own data
✅ Users CANNOT access data they shouldn't have permission for
✅ All app features work as expected
✅ Firebase Console shows no permission errors
✅ Test Mode warning is gone

---

**Deployment Time**: ~5 minutes  
**Testing Time**: ~30 minutes  
**Security Level**: Production-ready ✅

Let's secure your app! 🔐

