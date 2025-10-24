# MessageAI Cloud Functions

Firebase Cloud Functions for MessageAI: push notifications, AI/RAG features, and media uploads.

## Functions

### AI/RAG Functions

#### embedNewMessage
**Trigger:** Realtime Database onCreate - `conversations/{convId}/messages/{msgId}`

Automatically embeds new text messages for semantic search and AI features.

**Features:**
- Chunks long messages (1200 chars with 150 overlap)
- Generates embeddings using OpenAI text-embedding-3-small
- Stores vectors in Pinecone with metadata (convId, msgId, authorId, ts)
- Skips non-text messages (images, audio)

#### aiSummarize
**Trigger:** HTTPS endpoint (`POST`)

AI-powered conversation summarization using RAG (Retrieval Augmented Generation).

**Features:**
- Hybrid retrieval (vector search + recent RTDB window)
- Semantic search via Pinecone
- Structured summaries (Key Points, Open Questions, Next Steps)
- Cites source message IDs
- Auth-gated (requires Firebase ID token)

**Request:**
```json
{
  "convId": "string",
  "window": "day" | "week" | "all",
  "style": "bullets" | "paragraph"
}
```

**Response:**
```json
{
  "summary": "string",
  "sources": ["msgId1", "msgId2", ...]
}
```

---

### Push Notification Functions

#### 1. sendMessageNotification
**Trigger:** Realtime Database onCreate - `conversations/{conversationId}/messages/{messageId}`

Sends push notifications to all participants when a new message is created.

**Features:**
- Excludes sender from notifications
- Supports both direct and group chats
- Includes sender name and message preview
- Handles image messages with emoji indicator
- Deep linking via conversationId in notification data
- Automatic cleanup of invalid FCM tokens

#### 2. cleanupOldTokens
**Trigger:** Scheduled - Every 24 hours

Removes FCM tokens older than 90 days to keep the database clean.

---

### Media Upload Functions

#### 3. generateUploadUrl
**Trigger:** HTTPS callable (`POST`)

Generates short-lived pre-signed S3 upload URLs (one per requested file) and returns public CDN URLs (CloudFront if configured, otherwise S3).

## Setup

### Prerequisites
- Node.js 18 or higher
- Firebase CLI installed globally: `npm install -g firebase-tools`
- Firebase project initialized
- AWS IAM user/role with permissions to `s3:PutObject` on your media bucket

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

### AWS Credentials

The `generateUploadUrl` function requires AWS credentials with rights to issue `PutObject` operations on your media bucket.

1. Configure Firebase function config:
   ```bash
firebase functions:config:set \
  aws.bucket="your-bucket-name" \
  aws.region="your-region" \
  aws.cloudfront_domain="d123.cloudfront.net" \
  aws.access_key_id="YOUR_AWS_ACCESS_KEY_ID" \
  aws.secret_access_key="YOUR_AWS_SECRET_ACCESS_KEY"
```
If you are not using CloudFront, omit `aws.cloudfront_domain`.

2. (Optional) Instead of config variables, you can set environment variables `S3_BUCKET`, `AWS_REGION`, and `CLOUDFRONT_DOMAIN` before deploying or running the emulator.

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
firebase deploy --only functions:generateUploadUrl
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

---

## AI/RAG Setup

See **[AI_SETUP.md](./AI_SETUP.md)** for complete AI/RAG setup instructions, including:

- Pinecone configuration
- OpenAI API setup
- Environment variables
- Testing procedures
- Cost estimation
- Troubleshooting

### Quick Start

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your Pinecone and OpenAI keys
   ```

3. **Deploy functions:**
   ```bash
   npm run deploy
   ```

4. **Test with seed data:**
   ```bash
   npm run seed conv_demo
   ```

### Testing AI Summarization

```bash
curl -X POST https://us-central1-YOUR-PROJECT.cloudfunctions.net/aiSummarize \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"convId": "conv_demo", "window": "week", "style": "bullets"}'
```
