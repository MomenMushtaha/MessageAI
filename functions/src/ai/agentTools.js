/**
 * AI Agent Tools for MessageAI
 * 
 * Defines tools/functions that the AI agent can use to help users
 * Built with Vercel AI SDK tool calling
 */

const { z } = require('zod');
const admin = require('firebase-admin');
const { Pinecone } = require('@pinecone-database/pinecone');
const { embeddings } = require('./embeddings');

// Initialize Pinecone
const pinecone = new Pinecone({
  apiKey: process.env.PINECONE_API_KEY || '',
});

/**
 * Search messages using semantic search (RAG)
 */
const searchMessages = {
  description: 'Search through conversation messages using semantic search. Use this when the user asks about specific topics, people, or events mentioned in their messages.',
  parameters: z.object({
    query: z.string().describe('The search query to find relevant messages'),
    conversationId: z.string().describe('The conversation ID to search within'),
    limit: z.number().optional().describe('Maximum number of results to return (default: 5)'),
  }),
  execute: async ({ query, conversationId, limit = 5 }) => {
    try {
      console.log(`🔍 Agent searching messages: "${query}" in ${conversationId}`);

      // Generate embedding for the query
      const queryEmbedding = await embeddings.generateEmbedding(query);

      // Query Pinecone
      const index = pinecone.index(process.env.PINECONE_INDEX || 'messageai');
      const queryResponse = await index.namespace(conversationId).query({
        vector: queryEmbedding,
        topK: limit,
        includeMetadata: true,
      });

      // Format results
      const results = queryResponse.matches.map(match => ({
        messageId: match.id,
        text: match.metadata?.text || '',
        sender: match.metadata?.senderId || 'unknown',
        timestamp: match.metadata?.timestamp || null,
        score: match.score,
      }));

      return {
        success: true,
        results,
        count: results.length,
      };
    } catch (error) {
      console.error('❌ Error searching messages:', error);
      return {
        success: false,
        error: error.message,
        results: [],
      };
    }
  },
};

/**
 * Get conversation summary
 */
const summarizeConversation = {
  description: 'Summarize a conversation or specific time window. Use this when the user asks for a summary of their chats.',
  parameters: z.object({
    conversationId: z.string().describe('The conversation ID to summarize'),
    window: z.enum(['today', 'week', 'month', 'all']).describe('Time window to summarize'),
    style: z.enum(['brief', 'detailed', 'bullet']).describe('Summary style'),
  }),
  execute: async ({ conversationId, window = 'week', style = 'brief' }) => {
    try {
      console.log(`📝 Agent summarizing conversation ${conversationId} (${window}, ${style})`);

      // Get messages from the conversation
      const messagesRef = admin.database().ref(`conversations/${conversationId}/messages`);
      const snapshot = await messagesRef.once('value');

      if (!snapshot.exists()) {
        return {
          success: false,
          error: 'Conversation not found',
        };
      }

      const messages = [];
      snapshot.forEach(child => {
        messages.push({
          id: child.key,
          ...child.val(),
        });
      });

      // Filter by time window
      const now = Date.now();
      const timeWindows = {
        today: 24 * 60 * 60 * 1000,
        week: 7 * 24 * 60 * 60 * 1000,
        month: 30 * 24 * 60 * 60 * 1000,
        all: Infinity,
      };

      const windowMs = timeWindows[window] || timeWindows.week;
      const filteredMessages = messages.filter(msg => 
        (now - msg.timestamp) <= windowMs
      );

      // Create summary text
      const messageTexts = filteredMessages
        .map(msg => `${msg.senderName || 'User'}: ${msg.text || '[media]'}`)
        .join('\n');

      return {
        success: true,
        summary: messageTexts,
        messageCount: filteredMessages.length,
        window,
        style,
      };
    } catch (error) {
      console.error('❌ Error summarizing conversation:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

/**
 * Extract action items from messages
 */
const extractActionItems = {
  description: 'Extract tasks, todos, and action items from conversation messages. Use when user asks about tasks or things they need to do.',
  parameters: z.object({
    conversationId: z.string().describe('The conversation ID to analyze'),
    daysBack: z.number().optional().describe('How many days back to look (default: 7)'),
  }),
  execute: async ({ conversationId, daysBack = 7 }) => {
    try {
      console.log(`📋 Agent extracting action items from ${conversationId}`);

      // Get recent messages
      const messagesRef = admin.database().ref(`conversations/${conversationId}/messages`);
      const snapshot = await messagesRef.once('value');

      if (!snapshot.exists()) {
        return {
          success: false,
          error: 'Conversation not found',
        };
      }

      const messages = [];
      const cutoff = Date.now() - (daysBack * 24 * 60 * 60 * 1000);

      snapshot.forEach(child => {
        const msg = child.val();
        if (msg.timestamp >= cutoff) {
          messages.push({
            id: child.key,
            ...msg,
          });
        }
      });

      // Simple keyword-based action item detection
      // In production, you'd use an LLM to extract these
      const actionKeywords = [
        'todo', 'task', 'need to', 'should', 'must', 'don\'t forget',
        'remember to', 'action item', 'deadline', 'by tomorrow', 'by next'
      ];

      const actionItems = [];
      messages.forEach(msg => {
        if (!msg.text) return;

        const lowerText = msg.text.toLowerCase();
        const hasActionKeyword = actionKeywords.some(keyword => 
          lowerText.includes(keyword)
        );

        if (hasActionKeyword) {
          actionItems.push({
            text: msg.text,
            sender: msg.senderName || 'Unknown',
            timestamp: msg.timestamp,
            messageId: msg.id,
          });
        }
      });

      return {
        success: true,
        actionItems,
        count: actionItems.length,
        daysSearched: daysBack,
      };
    } catch (error) {
      console.error('❌ Error extracting action items:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

/**
 * Translate text
 */
const translateText = {
  description: 'Translate text from one language to another. Use when user asks to translate a message or phrase.',
  parameters: z.object({
    text: z.string().describe('The text to translate'),
    targetLanguage: z.string().describe('Target language code (e.g., "es" for Spanish, "fr" for French)'),
    sourceLanguage: z.string().optional().describe('Source language code (auto-detect if not provided)'),
  }),
  execute: async ({ text, targetLanguage, sourceLanguage = 'auto' }) => {
    console.log(`🌐 Agent translating: "${text}" to ${targetLanguage}`);

    // Note: In production, integrate with translation API
    // For now, return a placeholder
    return {
      success: true,
      originalText: text,
      translatedText: `[Translation to ${targetLanguage}]: ${text}`,
      sourceLanguage,
      targetLanguage,
      note: 'Translation API integration pending',
    };
  },
};

/**
 * Get conversation participants info
 */
const getParticipants = {
  description: 'Get information about participants in a conversation. Use when user asks about who is in the chat.',
  parameters: z.object({
    conversationId: z.string().describe('The conversation ID'),
  }),
  execute: async ({ conversationId }) => {
    try {
      console.log(`👥 Agent getting participants for ${conversationId}`);

      const convSnapshot = await admin.database()
        .ref(`conversations/${conversationId}`)
        .once('value');

      if (!convSnapshot.exists()) {
        return {
          success: false,
          error: 'Conversation not found',
        };
      }

      const conversation = convSnapshot.val();
      const participantIds = conversation.participantMap
        ? Object.keys(conversation.participantMap)
        : (conversation.participantIds || []);

      // Get user details for each participant
      const participants = [];
      for (const userId of participantIds) {
        const userSnapshot = await admin.database()
          .ref(`users/${userId}`)
          .once('value');

        if (userSnapshot.exists()) {
          const user = userSnapshot.val();
          participants.push({
            id: userId,
            name: user.displayName || 'Unknown',
            email: user.email || '',
            isOnline: user.isOnline || false,
            lastSeen: user.lastSeen || null,
          });
        }
      }

      return {
        success: true,
        participants,
        count: participants.length,
        conversationType: conversation.type || 'direct',
        groupName: conversation.groupName || null,
      };
    } catch (error) {
      console.error('❌ Error getting participants:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

/**
 * Send a message
 */
const sendMessage = {
  description: 'Send a message to a conversation on behalf of the user. Use only when explicitly asked to send a message.',
  parameters: z.object({
    conversationId: z.string().describe('The conversation ID to send to'),
    text: z.string().describe('The message text to send'),
    userId: z.string().describe('The user ID sending the message'),
  }),
  execute: async ({ conversationId, text, userId }) => {
    try {
      console.log(`💬 Agent sending message to ${conversationId} from ${userId}`);

      // Get user info
      const userSnapshot = await admin.database()
        .ref(`users/${userId}`)
        .once('value');

      const user = userSnapshot.exists() ? userSnapshot.val() : null;

      // Create message
      const messageRef = admin.database()
        .ref(`conversations/${conversationId}/messages`)
        .push();

      const message = {
        id: messageRef.key,
        conversationId,
        senderId: userId,
        senderName: user?.displayName || 'AI Assistant',
        text,
        timestamp: Date.now(),
        status: 'sent',
        type: 'text',
      };

      await messageRef.set(message);

      // Update conversation lastMessage
      await admin.database()
        .ref(`conversations/${conversationId}`)
        .update({
          lastMessage: text,
          lastMessageTimestamp: message.timestamp,
        });

      return {
        success: true,
        messageId: message.id,
        text: message.text,
        timestamp: message.timestamp,
      };
    } catch (error) {
      console.error('❌ Error sending message:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  },
};

module.exports = {
  searchMessages,
  summarizeConversation,
  extractActionItems,
  translateText,
  getParticipants,
  sendMessage,
};

