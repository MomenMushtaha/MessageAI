/**
 * AI Agent Service using Vercel AI SDK
 * 
 * Implements a conversational AI agent that can:
 * - Answer questions about conversations
 * - Search through message history
 * - Extract action items and summaries
 * - Translate messages
 * - Perform actions on behalf of the user
 */

const { streamText, tool, convertToCoreMessages } = require('ai');
const { openai } = require('@ai-sdk/openai');
const admin = require('firebase-admin');
const tools = require('./agentTools');

/**
 * MoChain AI Agent System Prompt
 */
const SYSTEM_PROMPT = `You are MoChain, an intelligent AI assistant for MessageAI.

Your name is MoChain, and you're here to help users manage their conversations, find information, and stay organized.

You have powerful capabilities:
- 🔍 Search through conversation history using semantic search
- 📝 Summarize conversations in different time windows (today, week, month, all)
- ✅ Extract action items, tasks, and todos from messages
- 🌐 Translate messages between languages
- 👥 Get information about conversation participants
- 💬 Send messages on behalf of the user (only when explicitly requested)

Your personality:
- Friendly, helpful, and efficient
- Professional but approachable
- Proactive in suggesting helpful actions
- Respectful of user privacy

Guidelines:
1. Introduce yourself as "MoChain" when greeting users
2. Use the searchMessages tool to find relevant information in their chats
3. Use summarizeConversation for summaries
4. Use extractActionItems for tasks and todos
5. Use translateText for translations
6. Only send messages when explicitly asked
7. Suggest helpful actions based on context
8. Ask for clarification when needed
9. Be concise but thorough

Remember: You're MoChain, the smart assistant that makes MessageAI users more productive!`;

/**
 * Create AI Agent with streaming support
 * 
 * @param {Object} params
 * @param {string} params.userId - The user making the request
 * @param {string} params.conversationId - The conversation context
 * @param {Array} params.messages - Array of {role: 'user'|'assistant', content: string}
 * @param {Function} params.onFinish - Callback when stream completes
 * @returns {ReadableStream} - Streaming response
 */
async function createAgent({ userId, conversationId, messages, onFinish }) {
  try {
    console.log(`🤖 Creating AI agent for user ${userId} in conversation ${conversationId}`);

    // Convert messages to Vercel AI SDK format
    const coreMessages = convertToCoreMessages(messages);

    // Create the streaming response
    const result = await streamText({
      model: openai('gpt-4o-mini'),
      system: SYSTEM_PROMPT,
      messages: coreMessages,
      tools: {
        searchMessages: tool({
          description: tools.searchMessages.description,
          parameters: tools.searchMessages.parameters,
          execute: async (params) => await tools.searchMessages.execute({
            ...params,
            conversationId,
          }),
        }),
        summarizeConversation: tool({
          description: tools.summarizeConversation.description,
          parameters: tools.summarizeConversation.parameters,
          execute: async (params) => await tools.summarizeConversation.execute({
            ...params,
            conversationId,
          }),
        }),
        extractActionItems: tool({
          description: tools.extractActionItems.description,
          parameters: tools.extractActionItems.parameters,
          execute: async (params) => await tools.extractActionItems.execute({
            ...params,
            conversationId,
          }),
        }),
        translateText: tool({
          description: tools.translateText.description,
          parameters: tools.translateText.parameters,
          execute: tools.translateText.execute,
        }),
        getParticipants: tool({
          description: tools.getParticipants.description,
          parameters: tools.getParticipants.parameters,
          execute: async (params) => await tools.getParticipants.execute({
            ...params,
            conversationId,
          }),
        }),
        sendMessage: tool({
          description: tools.sendMessage.description,
          parameters: tools.sendMessage.parameters,
          execute: async (params) => await tools.sendMessage.execute({
            ...params,
            conversationId,
            userId,
          }),
        }),
      },
      maxTokens: 1000,
      temperature: 0.7,
      onFinish: async (completion) => {
        console.log('✅ Agent response completed');
        console.log(`Tokens used: ${completion.usage.totalTokens}`);
        
        // Save agent interaction to database for history
        try {
          await saveAgentInteraction({
            userId,
            conversationId,
            messages: [
              ...messages,
              {
                role: 'assistant',
                content: completion.text,
              },
            ],
            usage: completion.usage,
            toolCalls: completion.toolCalls || [],
          });
        } catch (error) {
          console.error('Error saving agent interaction:', error);
        }

        if (onFinish) {
          onFinish(completion);
        }
      },
    });

    return result.toAIStreamResponse();
  } catch (error) {
    console.error('❌ Error creating AI agent:', error);
    throw error;
  }
}

/**
 * Non-streaming chat completion (for simpler use cases)
 */
async function chatWithAgent({ userId, conversationId, messages }) {
  try {
    const coreMessages = convertToCoreMessages(messages);

    const { text, usage, toolCalls } = await streamText({
      model: openai('gpt-4o-mini'),
      system: SYSTEM_PROMPT,
      messages: coreMessages,
      tools: {
        searchMessages: tool({
          description: tools.searchMessages.description,
          parameters: tools.searchMessages.parameters,
          execute: async (params) => await tools.searchMessages.execute({
            ...params,
            conversationId,
          }),
        }),
        summarizeConversation: tool({
          description: tools.summarizeConversation.description,
          parameters: tools.summarizeConversation.parameters,
          execute: async (params) => await tools.summarizeConversation.execute({
            ...params,
            conversationId,
          }),
        }),
        extractActionItems: tool({
          description: tools.extractActionItems.description,
          parameters: tools.extractActionItems.parameters,
          execute: async (params) => await tools.extractActionItems.execute({
            ...params,
            conversationId,
          }),
        }),
      },
      maxTokens: 1000,
      temperature: 0.7,
    });

    return {
      response: text,
      usage,
      toolCalls,
    };
  } catch (error) {
    console.error('❌ Error in agent chat:', error);
    throw error;
  }
}

/**
 * Save agent interaction to database for history tracking
 */
async function saveAgentInteraction({ userId, conversationId, messages, usage, toolCalls }) {
  const interactionRef = admin.database()
    .ref(`agentInteractions/${userId}/${conversationId}`)
    .push();

  await interactionRef.set({
    timestamp: Date.now(),
    messages: messages.slice(-2), // Last user message and assistant response
    usage: {
      promptTokens: usage.promptTokens,
      completionTokens: usage.completionTokens,
      totalTokens: usage.totalTokens,
    },
    toolsUsed: toolCalls.map(tc => tc.toolName),
  });
}

module.exports = {
  createAgent,
  chatWithAgent,
};

