/**
 * Vector Store abstraction for Pinecone
 * Handles message embeddings storage and retrieval
 */

const { Pinecone } = require("@pinecone-database/pinecone");

/**
 * Create and return a Pinecone vector store instance
 * @returns {VectorStore} Vector store interface
 */
function pineconeVectorStore() {
  const client = new Pinecone({ apiKey: process.env.PINECONE_API_KEY });
  const index = client.Index(process.env.PINECONE_INDEX || "messageai");

  return {
    /**
     * Upsert embeddings into Pinecone
     * @param {Array} items - Array of {id, values, metadata}
     * @returns {Promise<void>}
     */
    async upsertEmbedding(items) {
      await index.upsert(
        items.map((i) => ({
          id: i.id,
          values: i.values,
          metadata: {
            convId: i.metadata.convId,
            msgId: i.metadata.msgId,
            authorId: i.metadata.authorId || "",
            ts: i.metadata.ts || 0,
          },
        }))
      );
    },

    /**
     * Query similar vectors
     * @param {Object} params - Query parameters
     * @param {string} params.convId - Conversation ID to filter by
     * @param {number[]} params.queryEmbedding - Query vector
     * @param {number} params.topK - Number of results (default: 12)
     * @param {number} params.sinceTs - Optional timestamp filter
     * @returns {Promise<Array>} Array of {id, score, metadata}
     */
    async querySimilar({ convId, queryEmbedding, topK = 12, sinceTs }) {
      const filter = { convId };
      if (sinceTs) filter.ts = { $gte: sinceTs };

      const res = await index.query({
        vector: queryEmbedding,
        topK,
        includeMetadata: true,
        filter, // server-side metadata filter keeps it per-conv
      });

      return (
        res.matches?.map((m) => ({
          id: m.id,
          score: m.score,
          metadata: {
            convId: m.metadata.convId,
            msgId: m.metadata.msgId,
            authorId: m.metadata.authorId,
            ts: m.metadata.ts,
          },
        })) || []
      );
    },
  };
}

module.exports = { pineconeVectorStore };

/**
 * QDRANT ALTERNATIVE NOTES:
 *
 * To use Qdrant instead of Pinecone:
 * 1. npm install qdrant-openapi-typescript fetch-retry node-fetch
 * 2. Use /points/upsert and /points/search endpoints
 * 3. Metadata goes in payload with {convId, msgId, authorId, ts}
 * 4. Attach a must clause on convId and ts >= sinceTs
 */
