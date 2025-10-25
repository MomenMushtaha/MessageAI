# MoChain AI Agent Setup Guide

## Overview

MoChain is an intelligent AI assistant built with the Vercel AI SDK that helps users manage their conversations, find information, and stay organized in MessageAI.

## Features

✨ **MoChain Can:**
- 🔍 Search through conversation history using semantic search (RAG with Pinecone)
- 📝 Summarize conversations in different time windows (today, week, month, all)
- ✅ Extract action items, tasks, and todos from messages
- 🌐 Translate messages between languages
- 👥 Get information about conversation participants
- 💬 Send messages on behalf of the user (when explicitly requested)

## Architecture

### Backend (Cloud Functions)

**Files Created:**
- `functions/src/ai/agent.js` - Vercel AI SDK agent with streaming support
- `functions/src/ai/agentTools.js` - Tool definitions for function calling
- `functions/src/http/mochain.js` - HTTP endpoints for chat and history

**Dependencies Added:**
```json
{
  "ai": "^3.4.32",
  "@ai-sdk/openai": "^1.0.8",
  "zod": "^3.23.8"
}
```

### Frontend (iOS)

**Files Created:**
- `MessageAI/Views/Chat/MoChainChatView.swift` - Chat interface for MoChain
- `MessageAI/Services/AppConfig.swift` - Added MoChain endpoint config

**Files Modified:**
- `MessageAI/Views/ChatList/ChatListView.swift` - Added MoChain card and button

## Installation Steps

### 1. Install Dependencies

```bash
cd functions
npm install
```

If you encounter permission errors, run:
```bash
sudo chown -R $(whoami) "/Users/$(whoami)/.npm"
npm install
```

### 2. Configure Environment Variables

Add to your `functions/.env` or Firebase config:

```bash
# OpenAI API Key (required for Vercel AI SDK)
OPENAI_API_KEY=your_openai_api_key_here

# Pinecone (required for RAG/semantic search)
PINECONE_API_KEY=your_pinecone_api_key_here
PINECONE_INDEX=messageai

# Optional: Model selection
OPENAI_MODEL=gpt-4o-mini  # Default model
```

### 3. Deploy Cloud Functions

```bash
cd functions
firebase deploy --only functions:mochainChat,functions:mochainHistory
```

This will deploy:
- `mochainChat` - Streaming chat endpoint
- `mochainHistory` - Get conversation history

### 4. Configure iOS App

Add to `Config.xcconfig`:

```
MOCHAIN_CHAT_ENDPOINT = https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/mochainChat
```

Replace `YOUR-PROJECT-ID` with your actual Firebase project ID.

### 5. Update Info.plist (Optional)

Add the endpoint to `Info.plist` for runtime configuration:

```xml
<key>MOCHAIN_CHAT_ENDPOINT</key>
<string>https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/mochainChat</string>
```

## Usage

### In the iOS App

1. **Access MoChain**: Tap the purple/blue gradient card at the top of the chat list
2. **Ask Questions**: Type any question about your messages or ask for help
3. **Use Suggestions**: Tap quick action buttons for common tasks

### Example Queries

```
"Search my messages for project updates"
"Summarize my conversations from this week"
"What are my action items?"
"Translate this message to Spanish: Hello, how are you?"
"Who is in the Team Alpha group chat?"
```

## API Endpoints

### POST /mochainChat

Chat with MoChain using streaming or non-streaming mode.

**Request:**
```json
{
  "userId": "user123",
  "conversationId": "conv456", // Optional, for context
  "messages": [
    {"role": "user", "content": "What did we discuss yesterday?"}
  ],
  "stream": true // Default: true
}
```

**Response (Non-Streaming):**
```json
{
  "response": "Based on your messages from yesterday...",
  "usage": {
    "promptTokens": 150,
    "completionTokens": 75,
    "totalTokens": 225
  },
  "toolCalls": ["searchMessages", "summarizeConversation"]
}
```

**Response (Streaming):**
Server-sent events (text/event-stream) format.

### GET /mochainHistory

Get conversation history with MoChain.

**Request:**
```
GET /mochainHistory?userId=user123
```

**Response:**
```json
{
  "conversationId": "mochain-user123",
  "messages": [...],
  "count": 10
}
```

## Tools Available to MoChain

MoChain has access to the following tools via function calling:

### 1. searchMessages
Search through conversation messages using semantic search (RAG).

### 2. summarizeConversation
Summarize conversations with different time windows and styles.

### 3. extractActionItems
Find tasks, todos, and action items from messages.

### 4. translateText
Translate text between languages.

### 5. getParticipants
Get information about conversation participants.

### 6. sendMessage
Send messages on behalf of the user (requires explicit permission).

## Customization

### Modify Agent Personality

Edit `functions/src/ai/agent.js`:

```javascript
const SYSTEM_PROMPT = `You are MoChain, an intelligent AI assistant...
// Customize personality, guidelines, and capabilities here
`;
```

### Add New Tools

1. Create tool in `functions/src/ai/agentTools.js`:
```javascript
const myNewTool = {
  description: 'Description of what this tool does',
  parameters: z.object({
    param1: z.string().describe('Parameter description'),
  }),
  execute: async ({ param1 }) => {
    // Implementation
    return { success: true, data: ... };
  },
};
```

2. Export the tool:
```javascript
module.exports = {
  // ...existing tools,
  myNewTool,
};
```

3. Add to agent in `agent.js`:
```javascript
tools: {
  // ...existing tools
  myNewTool: tool({
    description: tools.myNewTool.description,
    parameters: tools.myNewTool.parameters,
    execute: tools.myNewTool.execute,
  }),
}
```

### Customize UI

Edit `MessageAI/Views/Chat/MoChainChatView.swift` to modify:
- Colors and gradients
- Suggestion buttons
- Welcome message
- Avatar icon

## Testing

### Test with curl

```bash
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/mochainChat \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test123",
    "messages": [
      {"role": "user", "content": "Hello MoChain!"}
    ],
    "stream": false
  }'
```

### Test in iOS Simulator

1. Build and run the app
2. Log in with a test account
3. Tap the MoChain card
4. Try asking questions

## Troubleshooting

### "MoChain endpoint not configured"
- Check that `MOCHAIN_CHAT_ENDPOINT` is set in Config.xcconfig or Info.plist
- Verify the URL is correct

### "Error: Internal server error"
- Check Cloud Functions logs: `firebase functions:log`
- Ensure OpenAI API key is configured
- Verify Pinecone is set up if using search

### Messages not streaming
- Check that `stream: true` is set in the request
- Verify network connectivity
- Check that the endpoint supports SSE (Server-Sent Events)

### Tool calls failing
- Ensure Firebase Realtime Database has the required data
- Check that Pinecone index exists and has embeddings
- Verify user permissions in Firebase rules

## Cost Optimization

- **Model Selection**: Use `gpt-4o-mini` for cost-effective responses
- **Token Limits**: Set `maxTokens: 1000` to control response length
- **Caching**: MoChain automatically caches interaction history
- **Rate Limiting**: Implement rate limits to prevent abuse

## Security

- MoChain only accesses conversations the user is part of
- Respects user privacy settings
- Does not store sensitive information
- All API calls require user authentication

## Future Enhancements

Potential features to add:
- Voice input/output
- Image analysis
- Calendar integration
- Email drafting
- Custom workflows
- Multi-modal interactions
- Proactive suggestions

## Support

For issues or questions:
1. Check Cloud Functions logs
2. Review this documentation
3. Test with simple queries first
4. Verify all dependencies are installed

---

**MoChain is ready to help you be more productive in MessageAI!** 🚀

