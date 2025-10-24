# AI/RAG Setup Guide

This guide walks you through setting up the AI/RAG features for MessageAI.

## Architecture Overview

- **Vector DB**: Pinecone (stores message embeddings)
- **Embeddings**: OpenAI `text-embedding-3-small`
- **LLM**: OpenAI GPT-4o-mini
- **Storage**: Firebase Realtime Database + AWS S3/CloudFront
- **Runtime**: Firebase Cloud Functions (Node.js 18)

## Prerequisites

1. **Pinecone Account**
   - Sign up at https://www.pinecone.io/
   - Create a new index named `messageai`
   - Dimension: `1536` (for text-embedding-3-small)
   - Metric: `cosine`
   - Copy your API key

2. **OpenAI Account**
   - Sign up at https://platform.openai.com/
   - Create an API key
   - Ensure you have credits/billing enabled

3. **Firebase Project** (already configured)
   - Realtime Database enabled
   - Cloud Functions deployed

## Installation Steps

### 1. Install Dependencies

```bash
cd functions
npm install
```

This will install:
- `@pinecone-database/pinecone` - Vector database client
- `openai` - OpenAI API client
- Other existing dependencies (Firebase, AWS SDK)

### 2. Configure Environment Variables

Create a `.env` file in the `functions/` directory:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

```env
PINECONE_API_KEY=pc_xxx...
PINECONE_INDEX=messageai
OPENAI_API_KEY=sk-proj-xxx...
```

**IMPORTANT**: Never commit `.env` to git! It's already in `.gitignore`.

### 3. Set Firebase Functions Config (Alternative to .env)

If you prefer using Firebase Functions config instead of `.env`:

```bash
firebase functions:config:set \
  pinecone.api_key="your_pinecone_key" \
  pinecone.index="messageai" \
  openai.api_key="your_openai_key"
```

View current config:
```bash
firebase functions:config:get
```

### 4. Deploy Cloud Functions

Deploy all functions (including new AI functions):

```bash
npm run deploy
```

Or deploy specific functions:

```bash
firebase deploy --only functions:embedNewMessage
firebase deploy --only functions:aiSummarize
```

### 5. Verify Deployment

Check function URLs:

```bash
firebase functions:list
```

You should see:
- `embedNewMessage` - RTDB trigger
- `aiSummarize` - HTTPS endpoint
- `sendMessageNotification` - RTDB trigger
- `cleanupOldTokens` - Scheduled function
- `generateUploadUrl` - HTTPS endpoint

## Testing

### Test 1: Seed Test Conversation

Create a test conversation with sample messages:

```bash
npm run seed conv_demo
```

This will:
1. Create a test conversation with 10 messages
2. Trigger `embedNewMessage` automatically
3. Generate embeddings in Pinecone

### Test 2: Verify Embeddings in Pinecone

1. Go to Pinecone dashboard: https://app.pinecone.io/
2. Select your `messageai` index
3. Check the "Vectors" tab
4. You should see vectors with IDs like `conv_demo:msgId:0`

### Test 3: Test Summarization Endpoint

Get a Firebase auth token first (from your iOS app or via Firebase Auth REST API):

```bash
# Replace $TOKEN with actual Firebase ID token
# Replace $FUNCTION_URL with your deployed function URL

curl -X POST https://us-central1-YOUR-PROJECT.cloudfunctions.net/aiSummarize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "convId": "conv_demo",
    "window": "week",
    "style": "bullets"
  }'
```

Expected response:

```json
{
  "summary": "## Key Points\n- Design review needed...\n\n## Open Questions\n...",
  "sources": ["msgId1", "msgId2", ...]
}
```

## How It Works

### Automatic Message Embedding

1. User sends a text message
2. Message saved to Realtime Database: `/conversations/{convId}/messages/{msgId}`
3. **`embedNewMessage` trigger fires** (RTDB onCreate)
4. Message text is chunked (1200 chars with 150 overlap)
5. Chunks are embedded using OpenAI API
6. Vectors are stored in Pinecone with metadata:
   ```js
   {
     id: "convId:msgId:chunkIndex",
     vector: [0.123, ...],  // 1536 dimensions
     metadata: { convId, msgId, authorId, ts }
   }
   ```

### AI Summarization (RAG)

1. Client calls `/aiSummarize` endpoint with auth token
2. **Hybrid retrieval**:
   - Vector search: Find semantically similar messages (Pinecone)
   - Recent window: Fetch last N messages (RTDB)
   - Merge and rank by relevance + recency
3. **Generate summary**:
   - Build context from top messages
   - Call OpenAI GPT-4o-mini with structured prompt
   - Return summary with source message IDs

## Cost Estimation

### OpenAI Costs
- **Embeddings**: $0.020 per 1M tokens (~$0.002 per 1000 messages)
- **GPT-4o-mini**: $0.150 per 1M input tokens + $0.600 per 1M output tokens
- **Typical summary**: ~$0.001 per request

### Pinecone Costs
- **Starter Plan**: Free tier (100K vectors, 1 index)
- **Standard Plan**: $70/month for 10M vectors

### Example Monthly Cost (10K messages, 100 summaries)
- Embeddings: $0.02
- Summaries: $0.10
- Pinecone: $0 (free tier)
- **Total: ~$0.12/month**

## Troubleshooting

### Error: "Missing token"
- Ensure you're sending `Authorization: Bearer <token>` header
- Token must be a valid Firebase ID token

### Error: "Pinecone API error"
- Check your `PINECONE_API_KEY` is correct
- Verify index name matches `PINECONE_INDEX`
- Ensure index dimension is 1536

### Error: "OpenAI API error"
- Check your `OPENAI_API_KEY` is correct
- Verify you have credits/billing enabled
- Check rate limits (free tier: 3 RPM)

### No embeddings created
- Check function logs: `firebase functions:log`
- Verify trigger is deployed: `firebase functions:list`
- Ensure message has `type: "text"` and non-empty `text` field

## Next Steps

### 1. Extract `retrieveContext` Utility

Move the retrieval logic to a shared utility:

```js
// functions/src/util/retrieveContext.js
module.exports = { retrieveContext };
```

Reuse in other endpoints: action items, decisions, priority extraction.

### 2. Add Caching

Cache summaries for 10 minutes to reduce costs:

```js
const cache = new Map(); // or Redis
const cacheKey = `summary:${convId}:${window}`;
```

### 3. Transcription Pipeline

For audio messages:
1. Audio uploaded to S3 → CloudFront
2. Cloud Function transcribes audio (Whisper API)
3. Transcript written to RTDB
4. Transcript embedded automatically
5. Shows up in search/summarize

### 4. Rate Limiting

Add per-user rate limits:

```js
const { RateLimiterMemory } = require('rate-limiter-flexible');
const limiter = new RateLimiterMemory({
  points: 10, // 10 requests
  duration: 60, // per minute
});
```

## Production Checklist

- [ ] API keys stored securely (Functions config, not .env)
- [ ] Rate limiting implemented
- [ ] Monitoring and alerting set up
- [ ] Cost alerts configured (OpenAI, Pinecone)
- [ ] Error handling and retry logic tested
- [ ] Logs reviewed for sensitive data leaks
- [ ] Pinecone index backups enabled
- [ ] iOS app UI for AI features implemented

## Support

For issues or questions:
1. Check function logs: `firebase functions:log`
2. Review this guide
3. Check `.claude/rules/ai-rag-implementation.md` for implementation details
