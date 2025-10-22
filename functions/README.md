# MessageAI Cloud Functions

Firebase Cloud Functions for MessageAI push notifications and background tasks.

## Functions

### 1. sendMessageNotification
**Trigger:** Firestore onCreate - `conversations/{conversationId}/messages/{messageId}`

Sends push notifications to all participants when a new message is created.

**Features:**
- Excludes sender from notifications
- Supports both direct and group chats
- Includes sender name and message preview
- Handles image messages with emoji indicator
- Deep linking via conversationId in notification data
- Automatic cleanup of invalid FCM tokens

### 2. cleanupOldTokens
**Trigger:** Scheduled - Every 24 hours

Removes FCM tokens older than 90 days to keep the database clean.

## Setup

### Prerequisites
- Node.js 18 or higher
- Firebase CLI installed globally: `npm install -g firebase-tools`
- Firebase project initialized

### Installation

1. Install dependencies:
```bash
cd functions
npm install
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase (if not already done):
```bash
firebase init functions
```

Select:
- Use existing project
- JavaScript
- Use ESLint: No
- Install dependencies: Yes

## Development

### Local Testing
```bash
npm run serve
```

This starts the Firebase emulator suite for local testing.

### View Logs
```bash
npm run logs
```

## Deployment

### Deploy all functions:
```bash
npm run deploy
```

### Deploy specific function:
```bash
firebase deploy --only functions:sendMessageNotification
firebase deploy --only functions:cleanupOldTokens
```

## Monitoring

View function execution in Firebase Console:
1. Go to Firebase Console
2. Navigate to Functions section
3. Check logs and metrics

## Notification Payload Structure

```json
{
  "notification": {
    "title": "John Doe",
    "body": "Hello, how are you?",
    "sound": "default"
  },
  "data": {
    "conversationId": "conv-123",
    "messageId": "msg-456",
    "senderId": "user-789",
    "type": "new_message"
  }
}
```

## Error Handling

The function handles:
- Invalid FCM tokens (automatic cleanup)
- Missing conversations
- Missing users
- Network errors (automatic retry by Firebase)

## Performance Considerations

- Function timeout: 60 seconds (default)
- Memory: 256MB (default)
- Batches token operations for efficiency
- Removes invalid tokens to reduce failed sends
