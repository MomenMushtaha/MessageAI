/**
 * AI-powered conversation summarization endpoint
 * Uses RAG (Retrieval Augmented Generation) with hybrid search
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const OpenAI = require("openai");
const { pineconeVectorStore } = require("../ai/vectorStore");
const { embedText } = require("../ai/embeddings");

// Initialize Firebase Admin if not already done
if (!admin.apps.length) admin.initializeApp();

const db = admin.database();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const store = pineconeVectorStore();

/**
 * Require Firebase authentication
 * @param {functions.https.Request} req - Express request
 * @returns {Promise<string>} User ID
 * @throws {functions.https.HttpsError} If unauthenticated
 */
async function requireAuth(req) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) {
    throw new functions.https.HttpsError("unauthenticated", "Missing token");
  }
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded.uid;
}

/**
 * Hybrid retrieval: Vector search + Recent RTDB window
 * Combines semantic search with recency for best results
 *
 * @param {Object} params - Retrieval parameters
 * @param {string} params.convId - Conversation ID
 * @param {string} params.queryText - Query for semantic search
 * @param {number} params.topK - Number of results (default: 12)
 * @param {number} params.sinceDays - Days to look back (default: 30)
 * @param {number} params.recentLimit - Max recent messages (default: 200)
 * @returns {Promise<Array>} Merged and ranked results
 */
async function retrieveContext(params) {
  const {
    convId,
    queryText,
    topK = 12,
    sinceDays = 30,
    recentLimit = 200,
  } = params;

  const sinceTs = Date.now() - sinceDays * 24 * 60 * 60 * 1000;

  // 1) Vector search (if we have a query)
  const queryVec = queryText ? (await embedText([queryText]))[0] : undefined;
  const vectorHits = queryVec
    ? await store.querySimilar({ convId, queryEmbedding: queryVec, topK, sinceTs })
    : [];

  console.log(`🔍 Vector search found ${vectorHits.length} results`);

  // 2) Recent window from RTDB (keyword fallback + recency boost)
  const recentSnap = await db
    .ref(`/conversations/${convId}/messages`)
    .orderByChild("timestamp")
    .startAt(sinceTs)
    .limitToLast(recentLimit)
    .get();

  const recent = [];
  recentSnap.forEach((child) => {
    const v = child.val() || {};
    if (v.text) {
      recent.push({
        msgId: child.key,
        text: v.text,
        ts: v.timestamp || v.ts || 0,
        authorId: v.senderId || v.authorId,
      });
    }
  });

  console.log(`📅 Recent window found ${recent.length} messages`);

  // 3) Merge + re-rank (cosine similarity + recency score)
  const fromVector = vectorHits.map((h) => ({
    msgId: h.metadata.msgId,
    text: recent.find((r) => r.msgId === h.metadata.msgId)?.text || "",
    ts: h.metadata.ts || 0,
    score: h.score, // Cosine similarity score from Pinecone
  }));

  const keyword = (queryText || "").toLowerCase();
  const fromRecent = recent
    .filter((r) => !fromVector.some((v) => v.msgId === r.msgId))
    .map((r) => ({
      msgId: r.msgId,
      text: r.text,
      ts: r.ts,
      // Weak boost for keyword matches in recent messages
      score: keyword && r.text.toLowerCase().includes(keyword) ? 0.5 : 0.2,
    }));

  // Combine and sort by (score + recency_boost)
  // Recency boost: normalize timestamp to 0-1 range
  const merged = [...fromVector, ...fromRecent]
    .sort((a, b) => b.score + b.ts / 1e13 - (a.score + a.ts / 1e13))
    .slice(0, topK);

  console.log(`🔀 Merged and ranked to ${merged.length} results`);

  return merged;
}

/**
 * Summarize conversation endpoint
 * POST /summarize
 *
 * Request body:
 * {
 *   convId: string,
 *   window?: "day" | "week" | "all" (default: "week"),
 *   style?: "bullets" | "paragraph" (default: "bullets")
 * }
 *
 * Response:
 * {
 *   summary: string,
 *   sources: string[] (message IDs)
 * }
 */
exports.summarize = functions.https.onRequest(async (req, res) => {
  try {
    // Method check
    if (req.method !== "POST") {
      return res.status(405).json({ error: "POST only" });
    }

    // Auth check
    const userId = await requireAuth(req);
    console.log(`👤 Authenticated user: ${userId}`);

    // Parse request
    const { convId, window = "week", style = "bullets" } = req.body || {};
    if (!convId) {
      return res.status(400).json({ error: "convId required" });
    }

    console.log(`📊 Summarizing conversation ${convId} (window: ${window}, style: ${style})`);

    // Determine query text based on window
    const queryText =
      window === "day"
        ? "summary of the last day"
        : window === "all"
        ? "global summary of this conversation"
        : "summary of the last week";

    // Retrieve relevant context using hybrid search
    const snippets = await retrieveContext({ convId, queryText, topK: 14 });

    if (snippets.length === 0) {
      return res.status(200).json({
        summary: "No messages found in the specified time window.",
        sources: [],
      });
    }

    // Build context string
    const context = snippets.map((s) => `(${s.msgId}) ${s.text}`).join("\n");

    // System prompt
    const sys = [
      "You summarize a software team chat.",
      "Use ONLY the provided context.",
      "Output sections: Key Points; Open Questions; Next Steps.",
      "Cite message IDs in parentheses like (msgId:XYZ). Be brief and factual.",
    ].join("\n");

    // User prompt
    const prompt = [
      `Context:\n${context}\n`,
      `Constraints:\n- style=${style}\n- window=${window}\n`,
      "Now produce the summary.",
    ].join("\n");

    console.log(`🤖 Calling OpenAI GPT-4o-mini...`);

    // Call OpenAI
    const resp = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: sys },
        { role: "user", content: prompt },
      ],
      temperature: 0.2,
      max_tokens: 500,
    });

    const summary = resp.choices[0]?.message?.content || "";

    console.log(`✅ Summary generated (${summary.length} chars)`);

    // Return response
    return res.status(200).json({
      summary,
      sources: snippets.map((s) => s.msgId),
    });
  } catch (e) {
    console.error("❌ Summarize error:", e);
    const code = e?.code === "unauthenticated" ? 401 : 500;
    return res.status(code).json({ error: e?.message || "Internal error" });
  }
});
