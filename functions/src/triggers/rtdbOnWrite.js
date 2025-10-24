/**
 * Realtime Database triggers for automatic message embedding
 * Listens to new messages and creates vector embeddings
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { chunkText } = require("../ai/chunk");
const { embedText } = require("../ai/embeddings");
const { pineconeVectorStore } = require("../ai/vectorStore");

// Initialize Firebase Admin if not already done
if (!admin.apps.length) admin.initializeApp();

const db = admin.database();
let store = null;

/**
 * Get or create Pinecone vector store instance
 * @returns {Object} Vector store
 */
function getVectorStore() {
  if (!store) {
    store = pineconeVectorStore();
  }
  return store;
}

/**
 * RTDB message shape:
 * /conversations/{convId}/messages/{msgId} = {
 *   text?: string,
 *   type: "text" | "image" | "audio" | ...,
 *   senderId: string,
 *   timestamp: number,
 *   mediaUrl?: string (S3/CloudFront for images/audio - skipped for embeddings)
 * }
 */

/**
 * Automatically embed new text messages
 * Triggers on: /conversations/{convId}/messages/{msgId}
 *
 * Behavior:
 * - Chunks long messages into 1200-char segments with 150-char overlap
 * - Generates embeddings using OpenAI text-embedding-3-small
 * - Stores vectors in Pinecone with metadata (convId, msgId, authorId, ts)
 * - Skips non-text messages (images, audio, etc.)
 */
exports.onMessageCreate = functions.database
  .ref("/conversations/{convId}/messages/{msgId}")
  .onCreate(async (snap, ctx) => {
    const convId = ctx.params.convId;
    const msgId = ctx.params.msgId;
    const val = snap.val();

    console.log(`🔍 Processing message ${msgId} in conversation ${convId}`);

    // Skip non-text messages (images/audio handled via S3 + separate transcript OCR pipeline if desired)
    if (!val || !val.text || (val.type && val.type !== "text")) {
      console.log(`⏭️  Skipping non-text message type: ${val?.type || "unknown"}`);
      return null;
    }

    const text = String(val.text || "").trim();
    if (!text) {
      console.log("⏭️  Skipping empty message");
      return null;
    }

    try {
      // Chunk the text for embedding
      const chunks = chunkText(text);
      console.log(`📝 Split message into ${chunks.length} chunk(s)`);

      // Generate embeddings for all chunks
      const embeddings = await embedText(chunks);
      console.log(`✨ Generated ${embeddings.length} embedding(s)`);

      // Prepare items for upserting to vector store
      const items = embeddings.map((values, i) => ({
        id: `${convId}:${msgId}:${i}`,
        values,
        metadata: {
          convId,
          msgId,
          authorId: val.senderId || val.authorId || "",
          ts: val.timestamp || val.ts || Date.now(),
        },
      }));

      // Upsert to Pinecone
      await getVectorStore().upsertEmbedding(items);
      console.log(`✅ Upserted ${items.length} vector(s) to Pinecone`);

      return { success: true, chunks: chunks.length };
    } catch (error) {
      console.error(`❌ Error embedding message ${msgId}:`, error);
      // Don't throw - we don't want to retry and waste quota
      return { success: false, error: error.message };
    }
  });
