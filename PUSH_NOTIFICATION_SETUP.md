# Push Notification Setup Guide

## Info.plist Configuration

Add the following entries to your Info.plist (or in Xcode Target Settings > Info):

### 1. User Notifications Privacy Description
**Key:** `NSUserNotificationsUsageDescription`
**Value:** "We need your permission to send you notifications when you receive new messages."

### 2. Remote Notifications Background Mode
**Key:** `UIBackgroundModes`
**Type:** Array
**Values:**
- `remote-notification` - Enables background push notifications

## Xcode Configuration Steps

### 1. Enable Push Notifications Capability
1. Open the project in Xcode
2. Select the MessageAI target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Push Notifications"

### 2. Enable Background Modes
1. In "Signing & Capabilities" tab
2. Click "+ Capability"
3. Add "Background Modes"
4. Check "Remote notifications"

### 3. Configure Firebase Cloud Messaging
1. Upload APNs Authentication Key to Firebase Console:
   - Go to Project Settings > Cloud Messaging
   - Upload your .p8 APNs Authentication Key
   - Or upload APNs Certificate (.p12)

## Testing Push Notifications

### Simulator Limitations
- **iOS Simulator does NOT support push notifications**
- Must test on a physical device

### Testing on Physical Device
1. Run app on physical device
2. Grant notification permissions when prompted
3. Check console for FCM token:
   ```
   ✅ FCM Token received: [your-token]
   ```
4. Copy the FCM token from console
5. Send test notification from Firebase Console:
   - Go to Cloud Messaging > Send test message
   - Paste the FCM token
   - Send notification

### Testing Deep Linking
1. Send notification with custom data:
   ```json
   {
     "notification": {
       "title": "New message",
       "body": "You have a new message"
     },
     "data": {
       "conversationId": "your-conversation-id"
     }
   }
   ```
2. Tap notification
3. App should open and navigate to the conversation

## Cloud Functions (Phase 5.2)

After completing Phase 5.1, implement Cloud Functions to automatically send notifications when new messages are created.

See IMPLEMENTATION_PLAN.md for details.
