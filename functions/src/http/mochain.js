/**
 * MoChain AI Agent HTTP Endpoint
 * 
 * Handles chat interactions with MoChain, the AI assistant
 */

const functions = require('firebase-functions');
const { createAgent, chatWithAgent } = require('../ai/agent');
const admin = require('firebase-admin');

/**
 * Chat with MoChain (streaming)
 * 
 * POST /mochainChat
 * Body: {
 *   userId: string,
 *   conversationId: string (optional - for context),
 *   messages: [{role: 'user' | 'assistant', content: string}],
 *   stream: boolean (default: true)
 * }
 */
exports.mochainChat = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { userId, conversationId, messages, stream = true } = req.body;

    // Validate required fields
    if (!userId || !messages || !Array.isArray(messages)) {
      res.status(400).json({ 
        error: 'Missing required fields: userId and messages array required' 
      });
      return;
    }

    console.log(`🤖 MoChain chat request from user ${userId}`);
    console.log(`Messages: ${messages.length}`);

    // Use the user's current conversation or a default "mochain" conversation
    const contextConversationId = conversationId || await getOrCreateMoChainConversation(userId);

    if (stream) {
      // Streaming response
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      const streamResponse = await createAgent({
        userId,
        conversationId: contextConversationId,
        messages,
        onFinish: (completion) => {
          console.log('✅ MoChain streaming completed');
          // Save to conversation history
          saveMoChainMessage({
            userId,
            userMessage: messages[messages.length - 1].content,
            assistantMessage: completion.text,
          });
        },
      });

      // Pipe the stream to the response
      streamResponse.pipeTo(
        new WritableStream({
          write(chunk) {
            res.write(chunk);
          },
          close() {
            res.end();
          },
        })
      );
    } else {
      // Non-streaming response
      const result = await chatWithAgent({
        userId,
        conversationId: contextConversationId,
        messages,
      });

      // Save to conversation history
      await saveMoChainMessage({
        userId,
        userMessage: messages[messages.length - 1].content,
        assistantMessage: result.response,
      });

      res.json({
        response: result.response,
        usage: result.usage,
        toolCalls: result.toolCalls,
      });
    }
  } catch (error) {
    console.error('❌ Error in MoChain chat:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message,
    });
  }
});

/**
 * Get or create a dedicated MoChain conversation for the user
 */
async function getOrCreateMoChainConversation(userId) {
  const mochainId = 'mochain-assistant';
  const conversationId = `mochain-${userId}`;

  // Check if conversation exists
  const convRef = admin.database().ref(`conversations/${conversationId}`);
  const snapshot = await convRef.once('value');

  if (!snapshot.exists()) {
    // Create new MoChain conversation
    await convRef.set({
      id: conversationId,
      type: 'direct',
      participantIds: [userId, mochainId],
      participantMap: {
        [userId]: true,
        [mochainId]: true,
      },
      createdAt: Date.now(),
      lastMessage: 'Chat with MoChain, your AI assistant',
      lastMessageTimestamp: Date.now(),
      isMoChainChat: true,
    });

    console.log(`✅ Created MoChain conversation for user ${userId}`);
  }

  return conversationId;
}

/**
 * Save MoChain conversation message
 */
async function saveMoChainMessage({ userId, userMessage, assistantMessage }) {
  try {
    const conversationId = `mochain-${userId}`;
    const messagesRef = admin.database().ref(`conversations/${conversationId}/messages`);

    // Save user message
    const userMsgRef = messagesRef.push();
    await userMsgRef.set({
      id: userMsgRef.key,
      conversationId,
      senderId: userId,
      text: userMessage,
      timestamp: Date.now(),
      type: 'text',
      status: 'sent',
    });

    // Save assistant message
    const assistantMsgRef = messagesRef.push();
    await assistantMsgRef.set({
      id: assistantMsgRef.key,
      conversationId,
      senderId: 'mochain-assistant',
      senderName: 'MoChain',
      text: assistantMessage,
      timestamp: Date.now(),
      type: 'text',
      status: 'sent',
      isAIGenerated: true,
    });

    // Update conversation
    await admin.database().ref(`conversations/${conversationId}`).update({
      lastMessage: assistantMessage.substring(0, 100),
      lastMessageTimestamp: Date.now(),
    });

    console.log('✅ Saved MoChain conversation');
  } catch (error) {
    console.error('❌ Error saving MoChain message:', error);
  }
}

/**
 * Get MoChain conversation history
 * 
 * GET /mochainHistory?userId=xxx
 */
exports.mochainHistory = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const { userId } = req.query;

    if (!userId) {
      res.status(400).json({ error: 'userId required' });
      return;
    }

    const conversationId = `mochain-${userId}`;
    const messagesSnapshot = await admin.database()
      .ref(`conversations/${conversationId}/messages`)
      .orderByChild('timestamp')
      .limitToLast(50)
      .once('value');

    const messages = [];
    messagesSnapshot.forEach(child => {
      messages.push({
        id: child.key,
        ...child.val(),
      });
    });

    res.json({
      conversationId,
      messages,
      count: messages.length,
    });
  } catch (error) {
    console.error('❌ Error fetching MoChain history:', error);
    res.status(500).json({ error: error.message });
  }
});

