# Quick Start Guide - After Realtime Database Migration

**Status:** ✅ Ready to Run  
**Date:** October 24, 2025

## Prerequisites

Before running the app, ensure Firebase Realtime Database is set up:

### 1. Enable Realtime Database in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Realtime Database** (left sidebar)
4. Click **"Create Database"**
5. Choose your location (preferably same region as before)
6. Select **"Start in test mode"** (temporary - we'll add security rules later)
7. Click **"Enable"**

You should see a URL like: `https://your-project-id-default-rtdb.firebaseio.com/`

### 2. Verify GoogleService-Info.plist

Your `GoogleService-Info.plist` should already have the database URL. Check that it contains:

```xml
<key>DATABASE_URL</key>
<string>https://your-project-id-default-rtdb.firebaseio.com</string>
```

If not, download a fresh `GoogleService-Info.plist` from Firebase Console.

## Running the App

### 1. Build and Run
```bash
open MessageAI.xcodeproj
# In Xcode: Product > Build (⌘B)
# Then: Product > Run (⌘R)
```

### 2. Test Login Flow

#### Option A: Create New Account
1. Tap "Sign Up"
2. Enter email, password, and display name
3. Tap "Sign Up"
4. ✅ Profile created in Realtime Database
5. ✅ Logged in automatically

#### Option B: Login with Existing Account
1. Enter your email and password (from Firestore era)
2. Tap "Log In"
3. ⚠️ App detects no Realtime Database profile
4. ✅ Auto-creates profile from Firebase Auth
5. ✅ Logged in successfully

**Check Console Logs:**
```
⚠️ User {userId} has no data in Realtime Database. Creating profile...
📝 Writing to Realtime Database: users/{userId}
✅ Realtime Database write successful
✅ Created user profile in Realtime Database
```

## What Works Now

After successful login:

✅ **Authentication**
- Email/password login
- Sign up
- Auto-migration of existing users
- Logout

✅ **Conversations**
- View conversation list
- Create direct chats
- Create group chats
- Real-time updates

✅ **Messaging**
- Send text messages
- Receive messages in real-time
- Optimistic UI (instant send feedback)
- Auto-scroll

✅ **Presence**
- Online/offline status
- Last seen timestamps
- Heartbeat tracking

✅ **Groups** (UI only - backend stubs)
- View group details
- See participants
- Admin badges
- Leave group UI

## What Doesn't Work Yet (Has Stubs)

⚠️ **Message Features**
- Edit messages
- Delete messages
- Reactions
- Forward messages
- Pin messages
- Search messages

⚠️ **Media**
- Image messages
- Video messages
- Voice messages

⚠️ **Group Management**
- Add participants
- Remove participants
- Make admin
- Update group info
- Update permissions

These features have stub methods that will show error messages when used. They can be implemented incrementally.

## Troubleshooting

### Issue: "Failed to load user data"
**Solution:** Make sure Realtime Database is enabled in Firebase Console

### Issue: Still can't login
**Steps:**
1. Check Firebase Console → Authentication
   - Verify your email/password account exists
2. Check Firebase Console → Realtime Database
   - Should see `users/` node after first login attempt
3. Check Xcode console for error messages
4. Try creating a new account instead

### Issue: "Permission denied"
**Solution:** Ensure Realtime Database is in **test mode** (temporarily)
```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

### Issue: App crashes on login
**Check:**
1. Console logs for error details
2. Ensure Firebase SDK is properly installed
3. Verify `GoogleService-Info.plist` has DATABASE_URL

## Verify Database Structure

After logging in, check Firebase Console → Realtime Database. You should see:

```
users/
  └─ {userId}/
      ├─ id: "..."
      ├─ displayName: "..."
      ├─ email: "..."
      ├─ createdAt: 1729814400000
      ├─ isOnline: true
      └─ lastSeen: 1729814400000
```

## Next Steps

Once login works:

1. **Test Core Features**
   - Send messages
   - Create conversations
   - View presence

2. **Add Security Rules**
   - Create `database.rules.json`
   - Restrict read/write access

3. **Implement Advanced Features**
   - Pick one stub method at a time
   - Implement with Realtime Database
   - Test thoroughly

4. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

## Success Indicators

✅ Login works  
✅ See conversation list  
✅ Can send text messages  
✅ See online/offline status  
✅ Messages appear in real-time  
✅ Console shows Realtime Database logs  

If all above work, your migration is successful! 🎉

