# Production Deployment Guide - MessageAI

## ⚠️ CRITICAL: Security Checklist

Before deploying to production, you **MUST** complete the following security steps:

### 1. Firebase Security Rules Deployment

#### Firestore Rules
```bash
# Deploy Firestore security rules
firebase deploy --only firestore:rules

# Verify deployment
firebase firestore:rules:get
```

**What's Protected:**
- ✅ Users can only edit their own profiles
- ✅ Only conversation participants can read/write messages
- ✅ Only message senders can edit their own messages (within 15 min)
- ✅ Group admins have elevated permissions
- ✅ Comprehensive field validation
- ✅ Protection against unauthorized access

#### Storage Rules
```bash
# Deploy Storage security rules
firebase deploy --only storage:rules

# Verify deployment
firebase storage:rules:get
```

**What's Protected:**
- ✅ Users can only upload to their own folders
- ✅ File size limits (10MB images, 100MB videos, 20MB documents)
- ✅ File type validation (images, videos, documents only)
- ✅ Only authenticated users can access files

### 2. Firebase Configuration

#### Required Services to Enable:
1. **Authentication** - Email/Password provider
2. **Firestore Database** - Production mode (not test mode)
3. **Firebase Storage** - Production mode
4. **Cloud Functions** - For notifications and automation
5. **Firebase Messaging (FCM)** - Push notifications
6. **Crashlytics** - Error reporting (recommended)
7. **Analytics** - Usage tracking (recommended)

#### APNs Configuration (iOS Push Notifications):
1. Generate APNs Certificate in Apple Developer Portal
2. Upload APNs key to Firebase Console
   - Go to Project Settings → Cloud Messaging
   - Upload APNs Authentication Key (.p8 file)
   - Enter Key ID and Team ID

3. Enable capabilities in Xcode:
   - Push Notifications
   - Background Modes → Remote notifications

### 3. Environment Variables

Create a `.env` file (DO NOT commit to git):

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
FIREBASE_APP_ID=your-app-id

# Optional: Analytics
GOOGLE_ANALYTICS_ID=your-analytics-id
```

Ensure `GoogleService-Info.plist` is properly configured and **NOT** in version control (add to .gitignore if it contains sensitive data).

### 4. Deploy Cloud Functions

```bash
cd functions
npm install
npm run build

# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:sendMessageNotification
firebase deploy --only functions:cleanupOldTokens
```

**Verify functions are running:**
- Check Firebase Console → Functions
- Test notification sending
- Monitor function logs

### 5. Database Indexes

Deploy required Firestore indexes:

```bash
firebase deploy --only firestore:indexes
```

**Required Indexes (add to `firestore.indexes.json`):**

```json
{
  "indexes": [
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "conversations",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "participantIds", "arrayConfig": "CONTAINS" },
        { "fieldPath": "lastMessageAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "deliveredTo", "arrayConfig": "CONTAINS" },
        { "fieldPath": "status", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### 6. App Store Preparation

#### Info.plist Required Keys:

```xml
<!-- Camera access (for photo capture) -->
<key>NSCameraUsageDescription</key>
<string>MessageAI needs access to your camera to take photos for messages</string>

<!-- Photo Library (for photo selection) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>MessageAI needs access to your photos to share images in conversations</string>

<!-- Notifications -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

#### Build Configuration:
1. Set deployment target: iOS 15.0+
2. Configure App Icons (all sizes)
3. Configure Launch Screen
4. Set appropriate bundle identifier
5. Configure signing (Development/Distribution certificates)
6. Archive build for App Store

### 7. Security Best Practices

#### Do's ✅
- ✅ Use HTTPS for all network requests
- ✅ Validate all user inputs client-side
- ✅ Sanitize text inputs to prevent injection attacks
- ✅ Use Firebase security rules (deployed above)
- ✅ Enable Firebase App Check (additional security layer)
- ✅ Monitor Crashlytics for security-related crashes
- ✅ Implement rate limiting (see below)
- ✅ Use strong authentication (consider 2FA in future)

#### Don'ts ❌
- ❌ Never store API keys in code (use GoogleService-Info.plist)
- ❌ Never disable SSL certificate validation
- ❌ Never trust client-side data without server validation
- ❌ Never store sensitive data in UserDefaults
- ❌ Never log sensitive information (passwords, tokens)

### 8. Rate Limiting (Recommended)

Add rate limiting to prevent abuse:

**Client-side (already implemented in ValidationUtility):**
- Message length: max 4096 characters
- Display name: max 100 characters
- Group name: max 100 characters
- Bio: max 500 characters
- Image size: max 10MB
- Video size: max 100MB

**Server-side (implement in Cloud Functions):**
```javascript
// Example rate limiting in Cloud Function
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // limit each user to 100 requests per minute
  message: 'Too many requests, please try again later'
});

exports.sendMessage = functions.https.onCall(async (data, context) => {
  // Check rate limit here
  // Implement per-user rate limiting
});
```

### 9. Monitoring & Alerts

Set up monitoring in Firebase Console:

1. **Performance Monitoring:**
   - Track message send times
   - Monitor image upload duration
   - Track app startup time

2. **Crashlytics:**
   - Enable automatic crash reporting
   - Set up email alerts for crashes
   - Monitor crash-free users percentage (target: >99%)

3. **Analytics:**
   - Track daily active users
   - Monitor message volume
   - Track feature usage

4. **Budget Alerts:**
   - Set up billing alerts in Google Cloud Console
   - Monitor Firestore read/write operations
   - Monitor Storage usage
   - Monitor Cloud Function invocations

### 10. Pre-Launch Testing

Run comprehensive tests before production:

- [ ] Test user registration flow
- [ ] Test login/logout
- [ ] Test sending text messages
- [ ] Test sending images
- [ ] Test group creation
- [ ] Test group member management
- [ ] Test message editing
- [ ] Test message deletion
- [ ] Test push notifications
- [ ] Test offline functionality
- [ ] Test on poor network conditions
- [ ] Test with 1000+ messages in a conversation
- [ ] Test security rules (unauthorized access attempts)
- [ ] Load test with multiple concurrent users

### 11. Launch Checklist

Final steps before going live:

- [ ] All Firebase security rules deployed
- [ ] Cloud Functions deployed and verified
- [ ] Database indexes created
- [ ] APNs configured for push notifications
- [ ] App Store build archived and uploaded
- [ ] Privacy Policy published
- [ ] Terms of Service published
- [ ] Support email configured
- [ ] Crashlytics enabled
- [ ] Analytics enabled
- [ ] Rate limiting enabled
- [ ] Budget alerts configured
- [ ] All environment variables set correctly
- [ ] Test accounts created for QA
- [ ] Rollback plan documented

### 12. Post-Launch Monitoring

Monitor these metrics daily for the first week:

- Crash-free users percentage (target: >99%)
- API error rate (target: <1%)
- Push notification delivery rate (target: >95%)
- Average message delivery time (target: <2 seconds)
- Number of security rule violations (should be 0)
- User retention rate
- Active conversations
- Storage usage growth rate

### 13. Rollback Procedure

If critical issues are discovered:

1. **Immediate Actions:**
   - Monitor Firebase Console for error spikes
   - Check Crashlytics for crash patterns
   - Review Cloud Function logs

2. **Rollback Steps:**
   ```bash
   # Rollback Firestore rules
   firebase firestore:rules:set <previous-rules-file>

   # Rollback Cloud Functions
   firebase functions:delete <function-name>
   firebase deploy --only functions:<previous-version>
   ```

3. **Communication:**
   - Notify users of any downtime
   - Post status updates
   - Communicate ETA for fix

### 14. Emergency Contacts

Maintain a list of emergency contacts:
- Firebase support: [firebase.google.com/support](https://firebase.google.com/support)
- Apple Developer Support
- Team lead/CTO
- DevOps engineer

---

## Additional Resources

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/rules)
- [Firebase Cloud Functions Best Practices](https://firebase.google.com/docs/functions/best-practices)
- [iOS App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)

---

## Support

For issues or questions:
- Create an issue in the GitHub repository
- Contact the development team
- Review Firebase documentation

**Last Updated:** 2025-01-22
**Version:** 1.0.0
